#!/usr/bin/env python3
"""Fetch a pinned, size- and Git-blob-verified set of CC0 GLB life assets for offline Android packaging."""
from __future__ import annotations

import hashlib
import json
import struct
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "app/src/main/assets/life"
SOURCE_REPO = "crisleyhguimaraes/space-ship"
SOURCE_COMMIT = "c53b865c698d201fae129640f0a14f98f37e081b"
RAW = f"https://raw.githubusercontent.com/{SOURCE_REPO}/{SOURCE_COMMIT}/public/models"

ASSETS = {
    "deer": ("adventurers/deer.glb", 117676, "af7c09239feb1b675ae3ad469bbcacd7b56975f2"),
    "wolf": ("adventurers/wolf.glb", 109892, "3f9d10d5be54c3ccfa99a45325e4ea2d77187d7c"),
    "bird": ("adventurers/bird.glb", 18656, "7033ea31f7cc21fcc6483b6e2d4e27ff15217702"),
    "mushroom": ("monsters/mushroom.glb", 29612, "ff80d2ea1eaeb3eedbcd6ce43eda1957a8e6b9b4"),
    "walking-tree": ("monsters/walking-tree.glb", 33932, "bba02505207afab93f9f507950d2267456b73537"),
    "ghost": ("monsters/ghost.glb", 31792, "78f4c6bee009ec8808aa555cdf9083a2c80554c1"),
}


def git_blob_sha(data: bytes) -> str:
    header = b"blob " + str(len(data)).encode("ascii") + b"\0"
    return hashlib.sha1(header + data).hexdigest()


def parse_glb(data: bytes, name: str) -> dict:
    if len(data) < 20 or data[:4] != b"glTF":
        raise RuntimeError(f"{name}: invalid GLB magic/header")
    version, total = struct.unpack_from("<II", data, 4)
    if version != 2 or total != len(data):
        raise RuntimeError(f"{name}: invalid GLB version/length ({version}, {total}, {len(data)})")
    json_length, json_type = struct.unpack_from("<II", data, 12)
    if json_type != 0x4E4F534A or 20 + json_length > len(data):
        raise RuntimeError(f"{name}: missing glTF JSON chunk")
    doc = json.loads(data[20:20 + json_length].decode("utf-8").rstrip(" \t\r\n\0"))
    if doc.get("asset", {}).get("version") != "2.0":
        raise RuntimeError(f"{name}: not glTF 2.0")
    if not doc.get("meshes") or not doc.get("nodes"):
        raise RuntimeError(f"{name}: missing mesh/node geometry")
    # Keep the APK self-contained; every buffer/image must live inside the GLB.
    for buffer in doc.get("buffers", []):
        if buffer.get("uri", "").startswith("data:"):
            continue
        if "uri" in buffer:
            raise RuntimeError(f"{name}: external buffer URI would break offline packaging")
    for image in doc.get("images", []):
        if image.get("uri", "").startswith("data:"):
            continue
        if "uri" in image:
            raise RuntimeError(f"{name}: external image URI would break offline packaging")
    animations = [a.get("name", f"animation_{i}") for i, a in enumerate(doc.get("animations", []))]
    return {
        "meshes": len(doc.get("meshes", [])),
        "nodes": len(doc.get("nodes", [])),
        "skins": len(doc.get("skins", [])),
        "animations": animations,
    }


def download(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "DuckDreamStudios-ProjectArena-CI/1.0"})
    last_error = None
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                return response.read()
        except Exception as exc:  # retry transient GitHub raw/CDN errors
            last_error = exc
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"download failed after retries: {url}: {last_error}")


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    manifest = {
        "license": "CC0-1.0",
        "source_repository": SOURCE_REPO,
        "source_commit": SOURCE_COMMIT,
        "assets": {},
    }
    for name, (relative, expected_size, expected_sha) in ASSETS.items():
        url = f"{RAW}/{relative}"
        data = download(url)
        actual_sha = git_blob_sha(data)
        if len(data) != expected_size or actual_sha != expected_sha:
            raise RuntimeError(
                f"{name}: pinned source mismatch size={len(data)}/{expected_size} "
                f"git_blob_sha={actual_sha}/{expected_sha}"
            )
        metadata = parse_glb(data, name)
        target = DEST / f"{name}.glb"
        target.write_bytes(data)
        manifest["assets"][name] = {
            "path": f"life/{name}.glb",
            "size_bytes": len(data),
            "git_blob_sha1": actual_sha,
            **metadata,
        }
        print(
            f"{name}: {len(data)} bytes, meshes={metadata['meshes']}, "
            f"animations={len(metadata['animations'])} {metadata['animations']}"
        )
    (DEST / "cc0-manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(f"Fetched and verified {len(ASSETS)} CC0 GLB models into {DEST}")


if __name__ == "__main__":
    main()
