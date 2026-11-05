#!/usr/bin/env python3
"""Prepare the offline, textured Vale das Coroas scene for Flutter Scene.

The source trees are pinned CC0 GLBs already stored in the repository as base64.
The terrain is baked once at build time into one textured GLB: smooth heightfield,
variable-width river, material zones, and a low polygon-count island edge.
"""
from __future__ import annotations

import base64
import json
import math
import struct
import subprocess
import sys
from array import array
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FLUTTER_ASSETS = ROOT / "flutter" / "assets" / "world"
NATURE_SOURCE = ROOT / "app/src/main/assets/world/nature"
TERRAIN_SOURCE = ROOT / "app/src/main/assets/world/terrain"
WORLD_SCALE = 1.15
HALF_X = 35.0
HALF_Z = 31.0
GRID_X = 120
GRID_Z = 108

RIVER = [
    (-34.0, 1.10, 0.78), (-28.0, 0.55, 1.15),
    (-21.0, 0.05, 1.48), (-15.0, -0.45, 1.68),
    (-9.0, -0.22, 1.92), (-3.0, 0.25, 1.58),
    (4.0, 0.38, 1.82), (10.0, 0.02, 1.95),
    (16.0, -0.38, 1.62), (23.0, -0.18, 1.62),
    (29.0, 0.22, 1.15), (34.0, 0.80, 0.78),
]
LANES = [
    [(-14.2, -31), (-15.2, -23), (-14.6, -15), (-13.4, -7), (-13, 0),
     (-13.7, 8), (-14.8, 16), (-14.2, 24), (-14.2, 31)],
    [(0.5, -31), (0.1, -23), (-0.1, -15), (-0.25, -7), (0.5, 0),
     (0.3, 8), (-0.2, 16), (0.4, 24), (0.5, 31)],
    [(14.2, -31), (15.2, -23), (14.6, -15), (13.4, -7), (13, 0),
     (13.7, 8), (14.8, 16), (14.2, 24), (14.2, 31)],
]


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def river_segment(x: float) -> int:
    if x <= RIVER[0][0]:
        return 0
    for index in range(len(RIVER) - 1):
        if x <= RIVER[index + 1][0]:
            return index
    return len(RIVER) - 2


def river_center_z(x: float) -> float:
    index = river_segment(x)
    a, b = RIVER[index], RIVER[index + 1]
    t = min(1.0, max(0.0, (x - a[0]) / (b[0] - a[0])))
    return lerp(a[1], b[1], t)


def river_half_width(x: float) -> float:
    index = river_segment(x)
    a, b = RIVER[index], RIVER[index + 1]
    t = min(1.0, max(0.0, (x - a[0]) / (b[0] - a[0])))
    return lerp(a[2], b[2], t)


def height(x: float, z: float) -> float:
    west_ridge = 2.35 * math.exp(-((x + 24.0) ** 2) / 44.0) * (
        0.58 + 0.42 * math.cos(z * 0.075)
    )
    east_ridge = 2.18 * math.exp(-((x - 24.0) ** 2) / 48.0) * (
        0.58 + 0.42 * math.cos(z * 0.07)
    )
    south_highland = 1.55 * math.exp(-((z + 27.0) ** 2) / 36.0) * math.exp(
        -(x * x) / 420.0
    )
    north_highland = 1.55 * math.exp(-((z - 27.0) ** 2) / 36.0) * math.exp(
        -(x * x) / 420.0
    )
    jungle_knolls = 0.78 * math.exp(-((abs(x) - 8.5) ** 2) / 8.5) * math.exp(
        -((abs(z) - 14.0) ** 2) / 42.0
    )
    river_distance = abs(z - river_center_z(x))
    river_width = river_half_width(x)
    river_bed = -0.76 * math.exp(
        -(river_distance * river_distance) / (river_width * river_width * 0.82)
    )
    bank_distance = river_distance - (river_width + 0.66)
    river_bank = 0.48 * math.exp(-(bank_distance * bank_distance) / 2.4)
    rolling = (
        0.26 * math.sin(x * 0.18) * math.cos(z * 0.14)
        + 0.16 * math.sin((x + z) * 0.29)
    )
    shelf = 0.52 * math.exp(-((abs(x) - 18.5) ** 2) / 5.5) * math.exp(
        -((abs(z) - 13.0) ** 2) / 110.0
    )
    return (
        rolling + west_ridge + east_ridge + south_highland + north_highland
        + jungle_knolls + river_bed + river_bank + shelf
    )


def normal_at(x: float, z: float) -> tuple[float, float, float]:
    epsilon = 0.08
    dx = (height(x + epsilon, z) - height(x - epsilon, z)) / (2.0 * epsilon * WORLD_SCALE)
    dz = (height(x, z + epsilon) - height(x, z - epsilon)) / (2.0 * epsilon * WORLD_SCALE)
    nx, ny, nz = -dx, 1.0, -dz
    length = math.sqrt(nx * nx + ny * ny + nz * nz)
    return nx / length, ny / length, nz / length


def inside_island(x: float, z: float) -> bool:
    angle = math.atan2(z / HALF_Z, x / HALF_X)
    edge = (
        1.0 + 0.035 * math.sin(angle * 5.0)
        + 0.020 * math.sin(angle * 9.0 + 1.4)
        + 0.012 * math.cos(angle * 13.0)
    )
    radius = math.sqrt((x / HALF_X) ** 2 + (z / HALF_Z) ** 2)
    return radius <= edge


def point_segment_distance(px: float, pz: float, a: tuple[float, float],
                           b: tuple[float, float]) -> float:
    dx, dz = b[0] - a[0], b[1] - a[1]
    length_sq = dx * dx + dz * dz
    if length_sq <= 1e-9:
        return math.hypot(px - a[0], pz - a[1])
    t = min(1.0, max(0.0, ((px - a[0]) * dx + (pz - a[1]) * dz) / length_sq))
    return math.hypot(px - (a[0] + dx * t), pz - (a[1] + dz * t))


def lane_distance(x: float, z: float) -> float:
    return min(
        point_segment_distance(x, z, lane[i], lane[i + 1])
        for lane in LANES
        for i in range(len(lane) - 1)
    )


def catmull_rom(values: list[tuple[float, float, float]], t: float) -> tuple[float, float, float]:
    f = min(0.999999, max(0.0, t)) * (len(values) - 1)
    i = int(math.floor(f))
    u = f - i
    p0 = values[max(0, i - 1)]
    p1 = values[i]
    p2 = values[min(len(values) - 1, i + 1)]
    p3 = values[min(len(values) - 1, i + 2)]

    def cat(a: float, b: float, c: float, d: float) -> float:
        return 0.5 * (
            2.0 * b + (-a + c) * u
            + (2.0 * a - 5.0 * b + 4.0 * c - d) * u * u
            + (-a + 3.0 * b - 3.0 * c + d) * u * u * u
        )

    return (
        cat(p0[0], p1[0], p2[0], p3[0]),
        cat(p0[1], p1[1], p2[1], p3[1]),
        min(2.0, max(0.68, cat(p0[2], p1[2], p2[2], p3[2]))),
    )


def float_bytes(values: list[float]) -> bytes:
    data = array("f", values)
    if sys.byteorder != "little":
        data.byteswap()
    return data.tobytes()


def uint_bytes(values: list[int]) -> bytes:
    data = array("I", values)
    if data.itemsize != 4:
        raise RuntimeError("This build host requires 32-bit unsigned integers.")
    if sys.byteorder != "little":
        data.byteswap()
    return data.tobytes()


def build_terrain_glb(output: Path) -> None:
    # Each material group is a separate primitive but shares one vertex buffer.
    positions: list[float] = []
    normals: list[float] = []
    texcoords: list[float] = []
    groups: dict[str, list[int]] = {
        "grass": [], "moss": [], "soil": [], "rock": [],
        "water": [],
    }
    material_names = ["grass", "moss", "soil", "rock", "water"]
    vertex_rows = GRID_X + 1

    for zi in range(GRID_Z + 1):
        z = -HALF_Z + (2.0 * HALF_Z * zi / GRID_Z)
        for xi in range(GRID_X + 1):
            x = -HALF_X + (2.0 * HALF_X * xi / GRID_X)
            y = height(x, z)
            nx, ny, nz = normal_at(x, z)
            positions.extend((x * WORLD_SCALE, y, z * WORLD_SCALE))
            normals.extend((nx, ny, nz))
            texcoords.extend((x / 3.8, z / 3.8))

    for zi in range(GRID_Z):
        z0 = -HALF_Z + (2.0 * HALF_Z * zi / GRID_Z)
        z1 = -HALF_Z + (2.0 * HALF_Z * (zi + 1) / GRID_Z)
        for xi in range(GRID_X):
            x0 = -HALF_X + (2.0 * HALF_X * xi / GRID_X)
            x1 = -HALF_X + (2.0 * HALF_X * (xi + 1) / GRID_X)
            cx, cz = (x0 + x1) * 0.5, (z0 + z1) * 0.5
            if not inside_island(cx, cz):
                continue

            river_distance = abs(cz - river_center_z(cx))
            river_width = river_half_width(cx)
            if river_distance < river_width + 0.82 and abs(cx) < 34.2:
                continue

            nx, _, nz = normal_at(cx, cz)
            slope = math.sqrt(nx * nx + nz * nz)
            noise = math.sin(cx * 0.43 + cz * 0.17) + math.cos(cz * 0.31 - cx * 0.12)
            lane_dist = lane_distance(cx, cz)

            if slope > 0.30 or (abs(cx) > 18 and abs(cz) < 23 and noise > 0.25):
                material = "rock"
            elif lane_dist < 1.12 + 0.16 * noise:
                material = "soil"
            elif (
                river_distance < river_width + 5.5 and noise < 0.75
            ) or (
                math.sin(cx * 0.21 - cz * 0.33) + math.cos(cx * 0.37 + cz * 0.28) < -0.86
            ):
                material = "moss"
            else:
                material = "grass"

            i00 = zi * vertex_rows + xi
            i10 = i00 + 1
            i01 = i00 + vertex_rows
            i11 = i01 + 1
            groups[material].extend((i00, i01, i10, i10, i01, i11))

    # A short, textured cliff skirt closes the irregular edge of the island.
    skirt_segments = 220
    for i in range(skirt_segments):
        a0 = 2.0 * math.pi * i / skirt_segments
        a1 = 2.0 * math.pi * (i + 1) / skirt_segments

        def edge_point(angle: float) -> tuple[float, float, float]:
            wobble = (
                1.0 + 0.035 * math.sin(angle * 5.0)
                + 0.020 * math.sin(angle * 9.0 + 1.4)
                + 0.012 * math.cos(angle * 13.0)
            )
            x = HALF_X * wobble * math.cos(angle)
            z = HALF_Z * wobble * math.sin(angle)
            return x, height(x, z) - 0.02, z

        top_a = edge_point(a0)
        top_b = edge_point(a1)
        bottom_a = (top_a[0] * 1.025, -3.8, top_a[2] * 1.025)
        bottom_b = (top_b[0] * 1.025, -3.8, top_b[2] * 1.025)
        center_angle = (a0 + a1) * 0.5
        outward = (math.cos(center_angle), 0.0, math.sin(center_angle))
        base_index = len(positions) // 3
        for vertex, v in enumerate((top_a, top_b, bottom_a, bottom_b)):
            positions.extend((v[0] * WORLD_SCALE, v[1], v[2] * WORLD_SCALE))
            normals.extend(outward)
            texcoords.extend((i / 18.0, 0.0 if vertex < 2 else 1.0))
        groups["rock"].extend((
            base_index, base_index + 1, base_index + 2,
            base_index + 1, base_index + 3, base_index + 2,
        ))

    # The river is built as three continuous ribbons: reflective water, shallow
    # margins, and irregular sand/mud banks. The ground mesh leaves this channel open.
    previous: dict[str, tuple[int, int]] = {}
    for sample_index in range(181):
        t = sample_index / 180.0
        cx, cz, half_width = catmull_rom(RIVER, t)
        before = catmull_rom(RIVER, max(0.0, t - 0.003))
        after = catmull_rom(RIVER, min(0.999999, t + 0.003))
        dx, dz = after[0] - before[0], after[1] - before[1]
        tangent_length = max(1e-5, math.hypot(dx, dz))
        side_x, side_z = -dz / tangent_length, dx / tangent_length
        water_y = height(cx, cz) + 0.56

        bands = {
            "water": (0.0, half_width * 0.70),
            "moss": (half_width * 0.70, half_width * 0.92),
            "soil": (half_width * 0.92, half_width + 0.82),
        }

        for group_name, (inner, outer) in bands.items():
            current_indices = []
            for side in (1.0, -1.0):
                inner_x = cx + side_x * inner * side
                inner_z = cz + side_z * inner * side
                outer_x = cx + side_x * outer * side
                outer_z = cz + side_z * outer * side

                if group_name == "water":
                    inner_y = outer_y = water_y
                elif group_name == "moss":
                    inner_y = water_y - 0.035
                    outer_y = height(outer_x, outer_z) + 0.07
                else:
                    inner_y = height(inner_x, inner_z) + 0.07
                    outer_y = height(outer_x, outer_z) + 0.035

                # Append the two band edges in left/right order.
                for x, y, z, side_v in (
                    (inner_x, inner_y, inner_z, 0.0),
                    (outer_x, outer_y, outer_z, 1.0),
                ):
                    vertex_index = len(positions) // 3
                    positions.extend((x * WORLD_SCALE, y, z * WORLD_SCALE))
                    normals.extend((0.0, 1.0, 0.0))
                    texcoords.extend((sample_index / 32.0, side_v))
                    current_indices.append(vertex_index)

            # current order: left-inner, left-outer, right-inner, right-outer
            if group_name in previous:
                prev = previous[group_name]
                cur = current_indices
                groups[group_name].extend((
                    prev[0], cur[0], prev[2],
                    cur[0], cur[2], prev[2],
                ))
                # Outer half of the same ribbon.
                groups[group_name].extend((
                    prev[1], cur[1], prev[0],
                    cur[1], cur[0], prev[0],
                    prev[2], cur[2], prev[3],
                    cur[2], cur[3], prev[3],
                ))
            previous[group_name] = (
                current_indices[0], current_indices[1],
                current_indices[2], current_indices[3],
            )

    # Pack GPU buffers and GLB accessors.
    binary = bytearray()
    buffer_views: list[dict] = []
    accessors: list[dict] = []

    def add_view(payload: bytes, target: int | None = None) -> int:
        while len(binary) % 4:
            binary.append(0)
        offset = len(binary)
        binary.extend(payload)
        view = {"buffer": 0, "byteOffset": offset, "byteLength": len(payload)}
        if target is not None:
            view["target"] = target
        buffer_views.append(view)
        return len(buffer_views) - 1

    def add_accessor(payload: bytes, component_type: int, accessor_type: str,
                     count: int, target: int | None = None,
                     minimum: list[float] | None = None,
                     maximum: list[float] | None = None) -> int:
        view_index = add_view(payload, target)
        accessor = {
            "bufferView": view_index,
            "componentType": component_type,
            "count": count,
            "type": accessor_type,
        }
        if minimum is not None:
            accessor["min"] = minimum
        if maximum is not None:
            accessor["max"] = maximum
        accessors.append(accessor)
        return len(accessors) - 1

    xs = positions[0::3]
    ys = positions[1::3]
    zs = positions[2::3]
    position_accessor = add_accessor(
        float_bytes(positions), 5126, "VEC3", len(positions) // 3, 34962,
        [min(xs), min(ys), min(zs)], [max(xs), max(ys), max(zs)],
    )
    normal_accessor = add_accessor(
        float_bytes(normals), 5126, "VEC3", len(normals) // 3, 34962,
    )
    texcoord_accessor = add_accessor(
        float_bytes(texcoords), 5126, "VEC2", len(texcoords) // 2, 34962,
    )

    primitive_materials = {
        "grass": 0, "moss": 1, "soil": 2, "rock": 3, "water": 4,
    }
    primitives = []
    for group_name in material_names:
        indices = groups[group_name]
        if not indices:
            continue
        index_accessor = add_accessor(
            uint_bytes(indices), 5125, "SCALAR", len(indices), 34963,
        )
        primitives.append({
            "attributes": {
                "POSITION": position_accessor,
                "NORMAL": normal_accessor,
                "TEXCOORD_0": texcoord_accessor,
            },
            "indices": index_accessor,
            "material": primitive_materials[group_name],
            "mode": 4,
        })

    images: list[dict] = []
    textures: list[dict] = []
    materials: list[dict] = []
    sampler = {"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}

    for material_name in ("grass", "moss", "soil", "rock"):
        albedo_path = TERRAIN_SOURCE / f"{material_name}_albedo.png"
        normal_path = TERRAIN_SOURCE / f"{material_name}_normal.png"
        if not albedo_path.is_file() or not normal_path.is_file():
            raise FileNotFoundError(f"Missing generated terrain textures for {material_name}")

        image_indices = []
        for suffix, image_path in (("albedo", albedo_path), ("normal", normal_path)):
            image_view = add_view(image_path.read_bytes())
            image_index = len(images)
            images.append({
                "name": f"{material_name}_{suffix}",
                "bufferView": image_view,
                "mimeType": "image/png",
            })
            textures.append({
                "name": f"{material_name}_{suffix}",
                "sampler": 0,
                "source": image_index,
            })
            image_indices.append(len(textures) - 1)

        roughness = 0.88 if material_name in ("grass", "moss") else 0.93
        materials.append({
            "name": material_name.title(),
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": image_indices[0]},
                "metallicFactor": 0.0,
                "roughnessFactor": roughness,
            },
            "normalTexture": {"index": image_indices[1], "scale": 0.8},
        })

    materials.append({
        "name": "River Water",
        "pbrMetallicRoughness": {
            "baseColorFactor": [0.045, 0.22, 0.29, 1.0],
            "metallicFactor": 0.12,
            "roughnessFactor": 0.19,
        },
        "doubleSided": True,
    })

    document = {
        "asset": {
            "version": "2.0",
            "generator": "Duck Dream Studios - Vale das Coroas terrain bake",
        },
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": "Vale das Coroas - Organic Terrain", "mesh": 0}],
        "meshes": [{"name": "Organic terrain and river", "primitives": primitives}],
        "materials": materials,
        "samplers": [sampler],
        "textures": textures,
        "images": images,
        "bufferViews": buffer_views,
        "accessors": accessors,
        "buffers": [{"byteLength": len(binary)}],
        "extras": {
            "offline": True,
            "worldScale": WORLD_SCALE,
            "grid": [GRID_X, GRID_Z],
            "dynamicShadows": False,
        },
    }

    json_chunk = json.dumps(document, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    json_chunk += b" " * ((-len(json_chunk)) % 4)
    while len(binary) % 4:
        binary.append(0)
    total_length = 12 + 8 + len(json_chunk) + 8 + len(binary)
    glb = (
        struct.pack("<4sII", b"glTF", 2, total_length)
        + struct.pack("<II", len(json_chunk), 0x4E4F534A)
        + json_chunk
        + struct.pack("<II", len(binary), 0x004E4942)
        + bytes(binary)
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(glb)

    # Structural verification before handing the file to Flutter Scene's build hook.
    magic, version, declared_length = struct.unpack_from("<4sII", glb, 0)
    if magic != b"glTF" or version != 2 or declared_length != len(glb):
        raise RuntimeError("Generated terrain GLB failed its container checks.")
    if len(primitives) != 5 or len(images) != 8:
        raise RuntimeError("Terrain GLB is missing a material group or embedded texture.")


def main() -> None:
    output_nature = FLUTTER_ASSETS / "nature"
    output_nature.mkdir(parents=True, exist_ok=True)

    # Decode existing self-contained Quaternius CC0 models; do not fetch assets
    # during build or at runtime.
    models = {
        "tree_oak": "tree_oak.glb.b64",
        "tree_pine": "tree_pine.glb.b64",
        "tree_broadleaf": "tree_broadleaf.glb.b64",
        "bush_common": "bush_common.glb.b64",
    }
    for output_name, source_name in models.items():
        source = NATURE_SOURCE / source_name
        if not source.is_file():
            raise FileNotFoundError(f"Missing pinned CC0 model: {source}")
        encoded = b"".join(source.read_bytes().split())
        payload = base64.b64decode(encoded, validate=True)
        if len(payload) < 20:
            raise RuntimeError(f"Decoded model is unexpectedly small: {source_name}")
        magic, version, declared_length = struct.unpack_from("<4sII", payload, 0)
        if magic != b"glTF" or version != 2 or declared_length != len(payload):
            raise RuntimeError(f"Invalid GLB 2.0 source model: {source_name}")
        (output_nature / f"{output_name}.glb").write_bytes(payload)

    # Reuse the project's deterministic, tileable CC0-compatible terrain-map baker.
    subprocess.run(
        [sys.executable, str(ROOT / "tools/generate_terrain_materials.py")],
        check=True,
        cwd=ROOT,
    )
    terrain_path = FLUTTER_ASSETS / "arena_terrain.glb"
    build_terrain_glb(terrain_path)

    total_bytes = terrain_path.stat().st_size + sum(
        (output_nature / f"{name}.glb").stat().st_size for name in models
    )
    print(
        "Prepared offline world: 1 organic terrain GLB, 4 CC0 nature GLBs, "
        f"5 terrain material groups, {total_bytes:,} bytes."
    )


if __name__ == "__main__":
    main()
