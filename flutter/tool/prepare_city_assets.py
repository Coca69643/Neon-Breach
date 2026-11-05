#!/usr/bin/env python3
"""Fetch pinned CC0 Kenney city/interior GLBs and bundle them for offline play."""
from __future__ import annotations

import hashlib
import json
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "world" / "city"
SOURCE_REPOSITORY = "Hidencod/tge-assets"
SOURCE_COMMIT = "ea2f2aa1ca8da0898330c97df8a5489976b051d0"
RAW_ROOT = (
    "https://raw.githubusercontent.com/"
    f"{SOURCE_REPOSITORY}/{SOURCE_COMMIT}/"
)

# The GLBs are pinned by their Git blob SHA-1, then re-hashed with SHA-256
# for the release manifest. No network access is required by the game at runtime.
ASSETS = {
    "commercial_building_a.glb": (
        "packs/city-kit-commercial/building-a.glb",
        "351d7193acdde07877fc92ce6a7e60de092355c0",
    ),
    "commercial_building_c.glb": (
        "packs/city-kit-commercial/building-c.glb",
        "25296a35058fb056e0c777fe132d3f05c877ebc3",
    ),
    "commercial_building_e.glb": (
        "packs/city-kit-commercial/building-e.glb",
        "4443371e51be1d82100a6984211a0f7bc8daae74",
    ),
    "commercial_low_a.glb": (
        "packs/city-kit-commercial/low-detail-building-a.glb",
        "06f67ee309fa75379b87bf3ad4f1c8a5fc02c827",
    ),
    "commercial_low_b.glb": (
        "packs/city-kit-commercial/low-detail-building-b.glb",
        "154a72960ae868189ad8e47f84ef597bfa8ae7d5",
    ),
    "commercial_low_c.glb": (
        "packs/city-kit-commercial/low-detail-building-c.glb",
        "edc6434291d3b0f88d0db97e4507ae32dbde58e2",
    ),
    "commercial_low_d.glb": (
        "packs/city-kit-commercial/low-detail-building-d.glb",
        "7f3494de0860a428d94ada4512d02e6f864b3714",
    ),
    "road_straight.glb": (
        "packs/city-kit-roads/road-straight.glb",
        "8707b6f3bf7c6f5fda3bb01f164a9ef0b09f6eb2",
    ),
    "road_crossroad.glb": (
        "packs/city-kit-roads/road-crossroad.glb",
        "5e0204d012bbd64e861eb10699c0ddac915dadb6",
    ),
    "road_bend.glb": (
        "packs/city-kit-roads/road-bend.glb",
        "241878bb63fec4d0dbf6f338bbf0cc3eb89dbc9d",
    ),
    "road_side.glb": (
        "packs/city-kit-roads/road-side.glb",
        "b458ef693cf4f59e93fa23cc8e66b682567bc452",
    ),
    "interior_floor.glb": (
        "packs/furniture-kit/floorfull.glb",
        "3861276342492222b1019aea63ed50e6e52e83b3",
    ),
    "interior_wall.glb": (
        "packs/furniture-kit/wall.glb",
        "ba5b8d2a16bdb6042750d1bef5e7afe78c9b0091",
    ),
    "interior_doorway_wide.glb": (
        "packs/furniture-kit/walldoorwaywide.glb",
        "76c658e0919d2acfd77630efc1851358579a964f",
    ),
    "interior_wall_window.glb": (
        "packs/furniture-kit/wallwindow.glb",
        "19a394ffdd7a8398ae5cffcea3b7d33f40efecf9",
    ),
    "interior_stairs.glb": (
        "packs/furniture-kit/stairs.glb",
        "6416fcab01eab2a1d0ec5b9ebecd1b29f9b1cf26",
    ),
    "interior_doorway_open.glb": (
        "packs/furniture-kit/doorwayopen.glb",
        "4e787d1972d84cf3f59825d194c0ba439f5bee65",
    ),
    "interior_desk.glb": (
        "packs/furniture-kit/desk.glb",
        "8ca187070cd666239ab1d93dda2e98105f7de776",
    ),
    "interior_bench.glb": (
        "packs/furniture-kit/bench.glb",
        "7897dd0652ad3c6e94ae1dbdbbfc6180dab6b4e8",
    ),
    "interior_chair.glb": (
        "packs/furniture-kit/chair.glb",
        "2d57af4fef2a32910e3af9283d1e45f177068d63",
    ),
    "interior_computer_screen.glb": (
        "packs/furniture-kit/computerscreen.glb",
        "c509093d35ee40bb6791dde9ad8e9de4bc3348dd",
    ),
}

LICENSE_TEXT = """\
All models in this bundle were created by Kenney (www.kenney.nl) and are
released under Creative Commons Zero (CC0 1.0 Universal):
http://creativecommons.org/publicdomain/zero/1.0/

You can use them for personal, educational and commercial purposes.
Crediting Kenney is appreciated but not required.
Source conversion: https://github.com/Hidencod/tge-assets
"""


def fetch(url: str, attempts: int = 4) -> bytes:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "DuckDreamStudios-OfflineAssetBake/1.0"},
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
    raise RuntimeError(f"Failed to fetch pinned asset {url}: {last_error}")


def git_blob_sha1(payload: bytes) -> str:
    header = f"blob {len(payload)}\0".encode("ascii")
    return hashlib.sha1(header + payload).hexdigest()


def validate_glb(payload: bytes, filename: str) -> dict:
    if len(payload) < 20:
        raise RuntimeError(f"GLB is truncated: {filename}")
    import struct

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
        payload[20 : 20 + json_length].decode("utf-8").rstrip(" \t\r\n\0")
    )
    if not document.get("meshes"):
        raise RuntimeError(f"GLB has no meshes: {filename}")
    if not document.get("materials"):
        raise RuntimeError(f"GLB has no materials: {filename}")
    return document


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    manifest: dict = {
        "runtime": "bundled-offline",
        "creator": "Kenney",
        "license": "CC0-1.0",
        "sourceRepository": SOURCE_REPOSITORY,
        "sourceCommit": SOURCE_COMMIT,
        "assets": [],
        "layoutPolicy": (
            "Three-lane urban MOBA; enterable ground-floor interiors; "
            "no survival, crafting or gathering loop."
        ),
    }
    total_bytes = 0

    for filename, (source_path, expected_git_sha) in ASSETS.items():
        destination = OUTPUT / filename
        payload = fetch(RAW_ROOT + source_path)
        actual_git_sha = git_blob_sha1(payload)
        if actual_git_sha != expected_git_sha:
            raise RuntimeError(
                f"Pinned asset changed: {source_path}; "
                f"expected {expected_git_sha}, got {actual_git_sha}"
            )
        document = validate_glb(payload, filename)
        destination.write_bytes(payload)
        digest = hashlib.sha256(payload).hexdigest()
        total_bytes += len(payload)
        manifest["assets"].append({
            "file": filename,
            "source": source_path,
            "gitBlobSha1": actual_git_sha,
            "sha256": digest,
            "bytes": len(payload),
            "meshCount": len(document["meshes"]),
        })

    (OUTPUT / "CC0-KENNEY-LICENSE.txt").write_text(
        LICENSE_TEXT, encoding="utf-8"
    )
    (OUTPUT / "city-assets-manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(
        f"Prepared {len(ASSETS)} pinned Kenney CC0 urban GLBs "
        f"({total_bytes:,} bytes) for offline gameplay."
    )


if __name__ == "__main__":
    main()
