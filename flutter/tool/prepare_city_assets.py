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
    "commercial_building_b.glb": (
        "packs/city-kit-commercial/building-b.glb",
        "a71ea2a4ccdca22181b6506a194094cac60f35e2",
    ),
    "commercial_building_f.glb": (
        "packs/city-kit-commercial/building-f.glb",
        "9953090f076e84e41894bcfe0badde5be3a66e16",
    ),
    "commercial_building_h.glb": (
        "packs/city-kit-commercial/building-h.glb",
        "ba87000b72e5b18262438a4c028c1fbf22bb951c",
    ),
    "commercial_building_d.glb": (
        "packs/city-kit-commercial/building-d.glb",
        "a2cc6e10c0b0037b08bb2bf95d849007d07df265",
    ),
    "commercial_building_g.glb": (
        "packs/city-kit-commercial/building-g.glb",
        "92c348b70ded73914249c6a77753efac23875f33",
    ),
    "commercial_building_i.glb": (
        "packs/city-kit-commercial/building-i.glb",
        "50b396aacabc301b1ebf4f3c1db5b9adb0c9affb",
    ),
    "commercial_building_j.glb": (
        "packs/city-kit-commercial/building-j.glb",
        "7bb1e67b24f7bd5d45658c287f891f6108bba538",
    ),
    "commercial_skyscraper_a.glb": (
        "packs/city-kit-commercial/building-skyscraper-a.glb",
        "fc0b37efa6588889e74bd2199633a536526b9bd6",
    ),
    "suburban_building_a.glb": (
        "packs/city-kit-suburban/building-type-a.glb",
        "4aa2f0d0014f1383fad54acebd53cdf73baa2837",
    ),
    "suburban_building_c.glb": (
        "packs/city-kit-suburban/building-type-c.glb",
        "defa674771e61714a07e13a55758f6125bd0a7a5",
    ),
    "suburban_building_e.glb": (
        "packs/city-kit-suburban/building-type-e.glb",
        "781540fa66867080ff6a136cfac4468f554f4eb4",
    ),
    "suburban_building_g.glb": (
        "packs/city-kit-suburban/building-type-g.glb",
        "5c55720d08b8121a4c9015fc3f8090907db9e06b",
    ),
    "road_roundabout.glb": (
        "packs/city-kit-roads/road-roundabout.glb",
        "80de836555b5a85287767291816e804515b44cb1",
    ),
    "road_curve.glb": (
        "packs/city-kit-roads/road-curve.glb",
        "7eb1e51f6d9a29d167d907f49d326b16c8a95b0c",
    ),
    "road_intersection_path.glb": (
        "packs/city-kit-roads/road-intersection-path.glb",
        "aad639451fe824fe872f72ac245ee43e705ebf0c",
    ),
    "road_side_entry.glb": (
        "packs/city-kit-roads/road-side-entry.glb",
        "82ca54fff3ea43acd29652455af0ee21df6b8bfa",
    ),
    "road_bridge.glb": (
        "packs/city-kit-roads/road-bridge.glb",
        "cfe174e7de28e9ebb79c7dde1ec90cb2016d7240",
    ),
    "park_tree_oak.glb": (
        "packs/nature-kit/tree-oak.glb",
        "b136723ada4b5574b71f727120ab21fa579bf2fb",
    ),
    "park_tree_palm.glb": (
        "packs/nature-kit/tree-palm.glb",
        "f9bcf4d90cfde7ef2863258442545e983740b2e4",
    ),
    "park_tree_default.glb": (
        "packs/nature-kit/tree-default.glb",
        "13247443438a210c252d3324c511aba3cb3b392a",
    ),
    "park_tree_small.glb": (
        "packs/nature-kit/tree-small.glb",
        "0b60a75ecd52fa91e44964c90c8f04a77caf813c",
    ),
    "park_tree_pine.glb": (
        "packs/nature-kit/tree-pinedefaulta.glb",
        "f1217a9ee5b1d8f2027d39fe6bd151d20be5ab84",
    ),
    "street_light_square.glb": (
        "packs/city-kit-roads/light-square.glb",
        "6ab94fd35afa21760581242a15be5252c59d0c66",
    ),
    "traffic_light.glb": (
        "packs/city-kit-roads/traffic-light.glb",
        "39d39733a048bf5c83b9dda85203c926ae5bc258",
    ),
    "road_sign_street.glb": (
        "packs/city-kit-roads/road-sign-street.glb",
        "9a396210dd01ea14cb34525109cbd88aba84da6b",
    ),
    "road_sign_warning.glb": (
        "packs/city-kit-roads/road-sign-warning.glb",
        "596cbf05cd1cf7b5c556ea417dd14f0ac5d4dd29",
    ),
    "road_crossing.glb": (
        "packs/city-kit-roads/road-crossing.glb",
        "240ac05f10d5912cb5a8fb9fbc4dcb58ce82b82e",
    ),
    "detail_awning_wide.glb": (
        "packs/city-kit-commercial/detail-awning-wide.glb",
        "9af27263aacc873c8cafe25b258d1f56beda9d9d",
    ),
    "detail_parasol_a.glb": (
        "packs/city-kit-commercial/detail-parasol-a.glb",
        "e3da3ba15d5363df700734cddd89ffb6bab07043",
    ),
    "city_planter.glb": (
        "packs/city-kit-suburban/planter.glb",
        "f6ed826fcc9eddb524a6483b2df28eb66d229f90",
    ),
    "tree_large.glb": (
        "packs/city-kit-suburban/tree-large.glb",
        "a22d9deb8057735da24a4f88b24291dae3545e36",
    ),
    "interior_trashcan.glb": (
        "packs/furniture-kit/trashcan.glb",
        "7c7d381cd693c9ffcc37a520750f5eb6de56f462",
    ),
    "interior_plant.glb": (
        "packs/furniture-kit/plantsmall1.glb",
        "6c64ddaef49e831446cf673d9d8c6c37e446928b",
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
    "construction_barrier.glb": (
        "packs/city-kit-roads/construction-barrier.glb",
        "f11e89081e7fa88dad4716b5e3b9042497f3019b",
    ),
    "construction_fence.glb": (
        "packs/city-kit-roads/construction-fence.glb",
        "5a2ce85eb9feeceb7d972557be6d91b47f8e2933",
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

# Local GLB bounds used by the match's shared render/navigation/Rapier
# facade footprints: (half width X, half depth Z, full height Y).
# The source models are centered on X/Z and stand on Y=0.
COMMERCIAL_LOCAL_BOUNDS = {
    "commercial_building_b.glb": (0.48500001, 0.47000000, 1.29300000),
    "commercial_building_c.glb": (0.44179396, 0.54500005, 0.89300001),
    "commercial_building_f.glb": (0.42000002, 0.51500010, 1.69300008),
    "commercial_building_h.glb": (0.44179392, 0.50394556, 1.29299998),
    "commercial_building_d.glb": (0.42000002, 0.45000000, 1.29299998),
    "commercial_building_g.glb": (0.48500001, 0.46100010, 1.69300008),
    "suburban_building_a.glb": (0.64999998, 0.51406890, 0.83354098),
    "suburban_building_c.glb": (0.64319015, 0.51406890, 1.03354096),
    "commercial_building_i.glb": (0.62000003, 0.65100002, 1.68000007),
    "commercial_building_j.glb": (1.04179400, 0.67000002, 1.69300008),
}


def position_bounds(document: dict, filename: str) -> tuple[float, float, float]:
    """Return (half X, half Z, full Y) from the GLB POSITION accessors."""
    position_accessors = []
    for mesh in document.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            accessor_index = primitive.get("attributes", {}).get("POSITION")
            if accessor_index is None:
                continue
            accessor = document.get("accessors", [])[accessor_index]
            if "min" not in accessor or "max" not in accessor:
                raise RuntimeError(
                    f"POSITION accessor has no bounds for collision asset: {filename}"
                )
            position_accessors.append(accessor)

    if not position_accessors:
        raise RuntimeError(f"No POSITION accessor found for collision asset: {filename}")

    minimum = [
        min(accessor["min"][axis] for accessor in position_accessors)
        for axis in range(3)
    ]
    maximum = [
        max(accessor["max"][axis] for accessor in position_accessors)
        for axis in range(3)
    ]
    values = (
        (maximum[0] - minimum[0]) * 0.5,
        (maximum[2] - minimum[2]) * 0.5,
        maximum[1] - minimum[1],
    )
    expected = COMMERCIAL_LOCAL_BOUNDS[filename]
    for axis, (actual, pinned) in enumerate(zip(values, expected)):
        if abs(actual - pinned) > 0.002:
            raise RuntimeError(
                f"Commercial GLB bounds changed for {filename} axis {axis}: "
                f"expected {pinned:.6f}, got {actual:.6f}"
            )
    if any(abs(minimum[axis]) > 0.002 for axis in (0, 2)) or abs(minimum[1]) > 0.002:
        raise RuntimeError(
            f"Commercial GLB origin is no longer centered/on-ground: {filename}"
        )
    return values


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
            "District Control map foundation: irregular 220 x 172 urban footprint, five canal crossings, "
            "curved connector roads, six enterable service interiors, commercial and residential "
            "blocks, plus a readable park/greenbelt district; no survival or gathering loop."
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
        local_bounds = (
            position_bounds(document, filename)
            if filename in COMMERCIAL_LOCAL_BOUNDS
            else None
        )
        destination.write_bytes(payload)
        digest = hashlib.sha256(payload).hexdigest()
        total_bytes += len(payload)
        asset_entry = {
            "file": filename,
            "source": source_path,
            "gitBlobSha1": actual_git_sha,
            "sha256": digest,
            "bytes": len(payload),
            "meshCount": len(document["meshes"]),
        }
        if local_bounds is not None:
            asset_entry["collisionLocalBounds"] = {
                "halfWidthX": local_bounds[0],
                "halfDepthZ": local_bounds[1],
                "heightY": local_bounds[2],
            }
        manifest["assets"].append(asset_entry)

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
