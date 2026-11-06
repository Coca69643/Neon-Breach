#!/usr/bin/env python3
"""Fetch pinned Quaternius CC0 hand weapons for the three playable heroes."""
from __future__ import annotations

import hashlib
import json
import struct
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "weapons"
SOURCE_REPOSITORY = "Islandyout/engine"
SOURCE_COMMIT = "1d2102d8fe37bba4c562756cefccc8f161ee57e6"
RAW_ROOT = (
    "https://raw.githubusercontent.com/"
    f"{SOURCE_REPOSITORY}/{SOURCE_COMMIT}/"
)

# These are unmodified source GLBs. Each Git blob SHA-1 pins the upstream
# file and SHA-256 matches the provenance table recorded in the source repo.
ASSETS = {
    "lyra_sword.glb": {
        "source": "assets/source/kit/weapons/sword-golden.glb",
        "git_blob_sha1": "283303c890ba2d081ecd9cc01cef541b541572b3",
        "sha256": "5d49392aa725967e36accaddac4740183a092570efc6977db280b884cd607269",
        "pack": "Quaternius Medieval Weapons Pack",
    },
    "bastion_sword.glb": {
        "source": "assets/source/kit/weapons/sword-big.glb",
        "git_blob_sha1": "5485c518b599d6ef0cc8dea6a02e3cadca9849d2",
        "sha256": "2cc50215b851e80821559e76ba7b1d459dfa3fe59a4c9f3bedb61b330f14c222",
        "pack": "Quaternius Medieval Weapons Pack",
    },
    "kairo_sword.glb": {
        "source": "assets/source/kit/weapons/sword.glb",
        "git_blob_sha1": "37609dd2aeaadc969673d0cf11c9f2fd27280bf4",
        "sha256": "eca13ae89d844d32ccc639c55e9d5c6077217c885bd5b0b3cf6b96d7ca0470b8",
        "pack": "Quaternius Ultimate RPG Items Bundle",
    },
}

LICENSE_TEXT = """\
Playable hero weapons by Quaternius.
- Lyra: Sword_Golden — Quaternius Medieval Weapons Pack.
- Bastion: Sword_Big — Quaternius Medieval Weapons Pack.
- Kairo: Sword — Quaternius Ultimate RPG Items Bundle.

Both source packs are released under Creative Commons Zero 1.0 Universal
(CC0 1.0). The weapon GLBs are copied unmodified from the pinned source
repository commit recorded in weapon-assets-manifest.json.
CC0 legal code: https://creativecommons.org/publicdomain/zero/1.0/
Creator: https://quaternius.com/
"""


def fetch(url: str, attempts: int = 4) -> bytes:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "DuckDreamStudios-WeaponAssetBake/1.0"},
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
    raise RuntimeError(f"Failed to fetch pinned weapon {url}: {last_error}")


def git_blob_sha1(payload: bytes) -> str:
    header = f"blob {len(payload)}\0".encode("ascii")
    return hashlib.sha1(header + payload).hexdigest()


def validate_glb(payload: bytes, filename: str) -> dict:
    if len(payload) < 20:
        raise RuntimeError(f"GLB is truncated: {filename}")
    magic, version, declared_length, json_length, chunk_type = struct.unpack_from(
        "<4sIIII", payload, 0
    )
    if (
        magic != b"glTF"
        or version != 2
        or declared_length != len(payload)
        or chunk_type != 0x4E4F534A
        or 20 + json_length > len(payload)
    ):
        raise RuntimeError(f"Invalid GLB 2.0 header: {filename}")
    document = json.loads(
        payload[20 : 20 + json_length].decode("utf-8").rstrip(" \\t\\r\\n\\0")
    )
    if not document.get("meshes") or not document.get("materials"):
        raise RuntimeError(f"Weapon GLB has no meshes or materials: {filename}")
    return document


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    manifest = {
        "runtime": "bundled-offline",
        "creator": "Quaternius",
        "license": "CC0-1.0",
        "sourceRepository": SOURCE_REPOSITORY,
        "sourceCommit": SOURCE_COMMIT,
        "attachment": "Palm.R",
        "weapons": [],
    }
    total_bytes = 0
    for filename, source_info in ASSETS.items():
        payload = fetch(RAW_ROOT + source_info["source"])
        actual_git_sha1 = git_blob_sha1(payload)
        actual_sha256 = hashlib.sha256(payload).hexdigest()
        if actual_git_sha1 != source_info["git_blob_sha1"]:
            raise RuntimeError(
                f"Upstream Git blob changed for {filename}: {actual_git_sha1}"
            )
        if actual_sha256 != source_info["sha256"]:
            raise RuntimeError(
                f"Upstream SHA-256 changed for {filename}: {actual_sha256}"
            )
        document = validate_glb(payload, filename)
        (OUTPUT / filename).write_bytes(payload)
        total_bytes += len(payload)
        manifest["weapons"].append({
            "file": filename,
            "source": source_info["source"],
            "pack": source_info["pack"],
            "gitBlobSha1": actual_git_sha1,
            "sha256": actual_sha256,
            "bytes": len(payload),
            "meshCount": len(document["meshes"]),
            "materialCount": len(document["materials"]),
        })

    (OUTPUT / "CC0-QUATERNIUS-LICENSE.txt").write_text(
        LICENSE_TEXT, encoding="utf-8"
    )
    manifest_path = OUTPUT / "weapon-assets-manifest.json"
    manifest_payload = json.dumps(manifest, indent=2, ensure_ascii=False)
    # Fail the asset bake if serialization ever produces a malformed manifest.
    json.loads(manifest_payload)
    manifest_path.write_text(manifest_payload + "\n", encoding="utf-8")
    json.loads(manifest_path.read_text(encoding="utf-8"))
    print(
        f"Prepared {len(ASSETS)} pinned Quaternius CC0 hero weapons "
        f"({total_bytes:,} bytes)."
    )


if __name__ == "__main__":
    main()
