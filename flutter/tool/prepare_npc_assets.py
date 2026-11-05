#!/usr/bin/env python3
"""Fetch pinned Kenney Mini Characters GLBs for offline NPC and lane-unit visuals."""
from __future__ import annotations

import hashlib
import json
import struct
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "npcs"
SOURCE_REPOSITORY = "Hidencod/tge-assets"
SOURCE_COMMIT = "ea2f2aa1ca8da0898330c97df8a5489976b051d0"
RAW_ROOT = (
    "https://raw.githubusercontent.com/"
    f"{SOURCE_REPOSITORY}/{SOURCE_COMMIT}/"
)

# Git blob SHA-1 pins the source bytes; SHA-256 is recorded in the manifest.
ASSETS = {
    "npc_male_a.glb": (
        "packs/mini-characters/character-male-a.glb",
        "b752cc09ffe99ec901c8b731a4dc77903a96b4e7",
    ),
    "npc_male_b.glb": (
        "packs/mini-characters/character-male-b.glb",
        "d007708fdcec68d32668852276a83bf5307f98db",
    ),
    "npc_male_c.glb": (
        "packs/mini-characters/character-male-c.glb",
        "8add211babadcf4a72484430850675b2e9704b53",
    ),
    "npc_female_a.glb": (
        "packs/mini-characters/character-female-a.glb",
        "dc94d308984605963779180b8cb891f5aac04fc4",
    ),
    "npc_female_b.glb": (
        "packs/mini-characters/character-female-b.glb",
        "176fabdacad758ec267d7ab8e81f206936a25a38",
    ),
    "npc_female_c.glb": (
        "packs/mini-characters/character-female-c.glb",
        "5f34730fa680acc1cb2bd957008c95e71cb91b7c",
    ),
}

# Keep only safe locomotion and social response clips in the runtime assets.
ALLOWED_CLIPS = {"static", "idle", "walk", "sprint", "emote-yes"}


def fetch(url: str, attempts: int = 4) -> bytes:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "DuckDreamStudios-NpcAssetBake/1.0"},
    )
    last_error: Exception | None = None
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(request, timeout=35) as response:
                if response.status != 200:
                    raise RuntimeError(f"Unexpected HTTP status {response.status}: {url}")
                return response.read()
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            last_error = error
            if attempt + 1 < attempts:
                time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"Failed to fetch pinned NPC asset {url}: {last_error}")


def git_blob_sha1(payload: bytes) -> str:
    header = f"blob {len(payload)}\0".encode("ascii")
    return hashlib.sha1(header + payload).hexdigest()


def decode_glb(payload: bytes, filename: str) -> tuple[dict, bytes]:
    if len(payload) < 20:
        raise RuntimeError(f"GLB is truncated: {filename}")
    magic, version, declared, json_length, chunk_type = struct.unpack_from(
        "<4sIIII", payload, 0
    )
    if (
        magic != b"glTF" or version != 2 or declared != len(payload)
        or chunk_type != 0x4E4F534A or 20 + json_length > len(payload)
    ):
        raise RuntimeError(f"Invalid GLB 2.0 header: {filename}")
    document = json.loads(
        payload[20:20 + json_length].decode("utf-8").rstrip(" \t\r\n\0")
    )
    binary_offset = 20 + json_length
    binary_offset += (-binary_offset) % 4
    if binary_offset + 8 > len(payload):
        raise RuntimeError(f"GLB has no binary chunk: {filename}")
    binary_length, binary_type = struct.unpack_from("<II", payload, binary_offset)
    if binary_type != 0x004E4942 or binary_offset + 8 + binary_length > len(payload):
        raise RuntimeError(f"Invalid GLB binary chunk: {filename}")
    binary = payload[binary_offset + 8:binary_offset + 8 + binary_length]
    return document, binary


def encode_glb(document: dict, binary: bytes) -> bytes:
    json_payload = json.dumps(
        document, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")
    json_payload += b" " * ((-len(json_payload)) % 4)
    binary_payload = binary + b" " * ((-len(binary)) % 4)
    total_length = 12 + 8 + len(json_payload) + 8 + len(binary_payload)
    return (
        struct.pack("<4sII", b"glTF", 2, total_length)
        + struct.pack("<II", len(json_payload), 0x4E4F534A)
        + json_payload
        + struct.pack("<II", len(binary_payload), 0x004E4942)
        + binary_payload
    )


def prepare_asset(filename: str, source_path: str, expected_sha1: str) -> dict:
    payload = fetch(RAW_ROOT + source_path)
    actual_sha1 = git_blob_sha1(payload)
    if actual_sha1 != expected_sha1:
        raise RuntimeError(
            f"Pinned Kenney model changed: {source_path}; "
            f"expected {expected_sha1}, got {actual_sha1}"
        )

    document, binary = decode_glb(payload, filename)
    clips = document.get("animations", [])
    by_name = {clip.get("name"): clip for clip in clips}
    required = {"idle", "walk", "sprint"}
    missing = required - by_name.keys()
    if missing:
        raise RuntimeError(f"{filename} is missing locomotion clips: {sorted(missing)}")
    if not any(image.get("bufferView") is not None for image in document.get("images", [])):
        raise RuntimeError(f"{filename} has no embedded character texture.")

    document["animations"] = [
        clip for clip in clips if clip.get("name") in ALLOWED_CLIPS
    ]
    document.setdefault("asset", {})["generator"] = (
        "Duck Dream Studios — Kenney Mini Characters CC0 runtime variant"
    )
    document.setdefault("extras", {})["visualRole"] = "npc"
    built = encode_glb(document, binary)
    target = OUTPUT / filename
    target.write_bytes(built)

    # Re-parse the output so malformed GLB output fails the build immediately.
    result, _ = decode_glb(built, filename)
    result_clips = {clip.get("name") for clip in result.get("animations", [])}
    if not required.issubset(result_clips):
        raise RuntimeError(f"{filename} lost a required locomotion clip.")
    return {
        "file": filename,
        "source": source_path,
        "sourceGitBlobSha1": actual_sha1,
        "sha256": hashlib.sha256(built).hexdigest(),
        "bytes": len(built),
        "clips": sorted(result_clips),
    }


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    manifest = {
        "creator": "Kenney",
        "license": "CC0-1.0",
        "sourceRepository": SOURCE_REPOSITORY,
        "sourceCommit": SOURCE_COMMIT,
        "runtime": "bundled-offline",
        "models": [],
    }
    for filename, (source_path, expected_sha1) in ASSETS.items():
        entry = prepare_asset(filename, source_path, expected_sha1)
        manifest["models"].append(entry)
        print(f"Prepared {filename}: {entry['bytes']:,} bytes")

    (OUTPUT / "CC0-KENNEY-MINI-CHARACTERS-LICENSE.txt").write_text(
        "Kenney Mini Characters — CC0 1.0 Universal.\n"
        "Source: https://kenney.nl/assets/mini-characters\n"
        "The models, embedded textures and included animation data are "
        "released under CC0 1.0 Universal.\n",
        encoding="utf-8",
    )
    (OUTPUT / "npc-assets-manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"Prepared {len(ASSETS)} pinned Kenney CC0 NPC GLBs for offline play.")


if __name__ == "__main__":
    main()
