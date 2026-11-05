#!/usr/bin/env python3
"""Bake Vale das Coroas as a broad MOBA arena, not an oval island.

The offline GLB has an expanded rounded-rectangle footprint, three curved lanes,
a diagonal S-river, three walkable bridges and four open flank approaches.
"""
from __future__ import annotations

import base64
import json
import math
from io import BytesIO
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
# The old 88 x 58 oval is replaced by a 120 x 84 super-rectangle.
# Grid density stays close to the previous mobile vertex density.
HALF_X = 60.0
HALF_Z = 42.0
GRID_X = 180
GRID_Z = 126
FOOTPRINT_EXPONENT = 5.2

RIVER = [
    (-59.0, -17.0, 1.75), (-48.0, -13.0, 2.05),
    (-36.0, -8.0, 2.35), (-24.0, -1.0, 2.65),
    (-12.0, 7.0, 2.95), (0.0, 15.0, 3.15),
    (12.0, 17.0, 3.10), (24.0, 12.5, 2.85),
    (36.0, 4.5, 2.55), (48.0, -6.5, 2.15),
    (59.0, -14.0, 1.75),
]
LANES = [
    [(-22.5, -40), (-22.9, -30), (-22.2, -20), (-22.7, -10),
     (-22.1, 0), (-22.6, 10), (-22.2, 20), (-22.5, 30), (-22.5, 40)],
    [(0.0, -40), (0.5, -30), (-0.4, -20), (0.3, -10),
     (-0.3, 0), (0.4, 10), (-0.4, 20), (0.3, 30), (0.0, 40)],
    [(22.5, -40), (22.9, -30), (22.2, -20), (22.7, -10),
     (22.1, 0), (22.6, 10), (22.2, 20), (22.5, 30), (22.5, 40)],
]

# Secondary traversable flank paths create side approaches and open courtyards;
# they are not jungle camps and carry no survival/resource loop.
ACCESS_PATHS = [
    [(-22.5, -33), (-31, -34), (-40, -31), (-47, -25), (-48, -19),
     (-43, -15), (-34, -15), (-22.5, -18)],
    [(22.5, -33), (31, -34), (40, -31), (47, -25), (48, -19),
     (43, -15), (34, -15), (22.5, -18)],
    [(-22.5, 33), (-31, 34), (-40, 31), (-47, 25), (-48, 19),
     (-43, 15), (-34, 15), (-22.5, 18)],
    [(22.5, 33), (31, 34), (40, 31), (47, 25), (48, 19),
     (43, 15), (34, 15), (22.5, 18)],
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
    # Two long side ridges frame the lanes without enclosing the side routes.
    west_ridge = 2.65 * math.exp(-((x + 38.0) ** 2) / 92.0) * (
        0.64 + 0.36 * math.cos(z * 0.052)
    )
    east_ridge = 2.45 * math.exp(-((x - 38.0) ** 2) / 98.0) * (
        0.64 + 0.36 * math.cos(z * 0.049)
    )
    south_highland = 1.35 * math.exp(-((z + 36.0) ** 2) / 68.0) * math.exp(
        -(x * x) / 860.0
    )
    north_highland = 1.45 * math.exp(-((z - 36.0) ** 2) / 72.0) * math.exp(
        -(x * x) / 900.0
    )
    flank_mounds = 0.58 * math.exp(-((abs(x) - 31.5) ** 2) / 20.0) * math.exp(
        -((abs(z) - 21.0) ** 2) / 90.0
    )
    river_distance = abs(z - river_center_z(x))
    river_width = river_half_width(x)
    river_bed = -0.92 * math.exp(
        -(river_distance * river_distance) / (river_width * river_width * 0.92)
    )
    bank_distance = river_distance - (river_width + 0.82)
    river_bank = 0.54 * math.exp(-(bank_distance * bank_distance) / 3.2)
    rolling = (
        0.34 * math.sin(x * 0.12) * math.cos(z * 0.105)
        + 0.22 * math.sin((x + z) * 0.18)
        + 0.12 * math.cos((x - z) * 0.24)
    )
    terrace = 0.34 * math.exp(-((abs(x) - 23.0) ** 2) / 18.0) * math.exp(
        -((abs(z) - 11.0) ** 2) / 220.0
    )
    return (
        rolling + west_ridge + east_ridge + south_highland + north_highland
        + flank_mounds + river_bed + river_bank + terrace
    )


def normal_at(x: float, z: float) -> tuple[float, float, float]:
    epsilon = 0.08
    dx = (height(x + epsilon, z) - height(x - epsilon, z)) / (2.0 * epsilon * WORLD_SCALE)
    dz = (height(x, z + epsilon) - height(x, z - epsilon)) / (2.0 * epsilon * WORLD_SCALE)
    nx, ny, nz = -dx, 1.0, -dz
    length = math.sqrt(nx * nx + ny * ny + nz * nz)
    return nx / length, ny / length, nz / length


def edge_wobble(angle: float) -> float:
    return (
        1.0 + 0.022 * math.sin(angle * 5.0)
        + 0.014 * math.sin(angle * 9.0 + 1.4)
        + 0.010 * math.cos(angle * 13.0)
        + 0.006 * math.sin(angle * 17.0 + 0.8)
    )


def inside_island(x: float, z: float) -> bool:
    exponent = FOOTPRINT_EXPONENT
    angle = math.atan2(z / HALF_Z, x / HALF_X)
    edge = edge_wobble(angle)
    extent = (abs(x) / HALF_X) ** exponent + (abs(z) / HALF_Z) ** exponent
    return extent <= edge ** exponent


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


def normalize_scene_glb(payload: bytes, source_name: str) -> bytes:
    """Convert unsupported embedded WebP images to PNG and remove EXT_texture_webp."""
    from PIL import Image

    if len(payload) < 20:
        raise RuntimeError(f"GLB is too small to parse: {source_name}")
    magic, version, declared_length = struct.unpack_from("<4sII", payload, 0)
    if magic != b"glTF" or version != 2 or declared_length != len(payload):
        raise RuntimeError(f"Invalid GLB 2.0 source model: {source_name}")

    json_doc: dict | None = None
    binary = bytearray()
    offset = 12
    while offset + 8 <= len(payload):
        chunk_length, chunk_type = struct.unpack_from("<II", payload, offset)
        start = offset + 8
        end = start + chunk_length
        if end > len(payload):
            raise RuntimeError(f"Truncated GLB chunk in {source_name}")
        chunk = payload[start:end]
        if chunk_type == 0x4E4F534A:
            json_doc = json.loads(chunk.rstrip(b" \t\r\n\0").decode("utf-8"))
        elif chunk_type == 0x004E4942:
            binary = bytearray(chunk)
        else:
            raise RuntimeError(f"Unsupported GLB chunk type in {source_name}: {chunk_type}")
        offset = end

    if json_doc is None:
        raise RuntimeError(f"GLB JSON chunk missing: {source_name}")
    buffer_views = json_doc.get("bufferViews", [])
    images = json_doc.get("images", [])
    converted = 0

    for image_index, image in enumerate(images):
        if image.get("mimeType") != "image/webp":
            continue
        if "bufferView" not in image:
            raise RuntimeError(
                f"WebP image {image_index} in {source_name} is not embedded in a bufferView"
            )
        view_index = image["bufferView"]
        view = buffer_views[view_index]
        if view.get("buffer", 0) != 0:
            raise RuntimeError(f"Unsupported external GLB buffer in {source_name}")
        image_start = view.get("byteOffset", 0)
        image_end = image_start + view["byteLength"]
        webp_data = bytes(binary[image_start:image_end])
        if len(webp_data) != view["byteLength"]:
            raise RuntimeError(f"Truncated WebP texture in {source_name}")

        with Image.open(BytesIO(webp_data)) as source_image:
            source_image.load()
            has_alpha = (
                "A" in source_image.getbands()
                or "transparency" in source_image.info
            )
            converted_image = source_image.convert("RGBA" if has_alpha else "RGB")
            png_stream = BytesIO()
            converted_image.save(
                png_stream,
                format="PNG",
                optimize=True,
                compress_level=9,
            )
            png_data = png_stream.getvalue()

        while len(binary) % 4:
            binary.append(0)
        new_view_index = len(buffer_views)
        new_offset = len(binary)
        binary.extend(png_data)
        buffer_views.append({
            "buffer": 0,
            "byteOffset": new_offset,
            "byteLength": len(png_data),
        })
        image["bufferView"] = new_view_index
        image["mimeType"] = "image/png"
        converted += 1

    for texture in json_doc.get("textures", []):
        extensions = texture.get("extensions", {})
        webp_extension = extensions.pop("EXT_texture_webp", None)
        if webp_extension is not None:
            texture.setdefault("source", webp_extension["source"])
        if not extensions:
            texture.pop("extensions", None)

    for extension_field in ("extensionsUsed", "extensionsRequired"):
        extensions = json_doc.get(extension_field, [])
        extensions = [name for name in extensions if name != "EXT_texture_webp"]
        if extensions:
            json_doc[extension_field] = extensions
        else:
            json_doc.pop(extension_field, None)

    if any(image.get("mimeType") == "image/webp" for image in images):
        raise RuntimeError(f"WebP texture remained after conversion: {source_name}")
    if any(
        "EXT_texture_webp" in texture.get("extensions", {})
        for texture in json_doc.get("textures", [])
    ):
        raise RuntimeError(f"EXT_texture_webp remained in {source_name}")

    if json_doc.get("buffers"):
        json_doc["buffers"][0]["byteLength"] = len(binary)

    json_chunk = json.dumps(
        json_doc, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")
    json_chunk += b" " * ((-len(json_chunk)) % 4)
    while len(binary) % 4:
        binary.append(0)

    total_length = 12 + 8 + len(json_chunk) + 8 + len(binary)
    normalized = (
        struct.pack("<4sII", b"glTF", 2, total_length)
        + struct.pack("<II", len(json_chunk), 0x4E4F534A)
        + json_chunk
        + struct.pack("<II", len(binary), 0x004E4942)
        + bytes(binary)
    )
    if converted:
        print(f"Converted {converted} WebP texture(s) to PNG in {source_name}.")
    return normalized


def build_terrain_glb(output: Path) -> None:
    # Each material group is a separate primitive but shares one vertex buffer.
    positions: list[float] = []
    normals: list[float] = []
    texcoords: list[float] = []
    groups: dict[str, list[int]] = {
        "grass": [], "moss": [], "soil": [], "rock": [], "water": [],
        "stone": [], "accent_blue": [], "accent_gold": [],
    }
    material_names = [
        "grass", "moss", "soil", "rock", "water",
        "stone", "accent_blue", "accent_gold",
    ]
    vertex_rows = GRID_X + 1

    def add_box(group_name: str, cx: float, cy: float, cz: float,
                sx: float, sy: float, sz: float, yaw: float = 0.0) -> None:
        cosine, sine = math.cos(yaw), math.sin(yaw)
        hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5

        def point(px: float, py: float, pz: float) -> tuple[float, float, float]:
            return (cx + px * cosine + pz * sine, cy + py,
                    cz - px * sine + pz * cosine)

        faces = (
            (((-hx,-hy,hz),(hx,-hy,hz),(hx,hy,hz),(-hx,hy,hz)), (0,0,1)),
            (((hx,-hy,-hz),(-hx,-hy,-hz),(-hx,hy,-hz),(hx,hy,-hz)), (0,0,-1)),
            (((hx,-hy,hz),(hx,-hy,-hz),(hx,hy,-hz),(hx,hy,hz)), (1,0,0)),
            (((-hx,-hy,-hz),(-hx,-hy,hz),(-hx,hy,hz),(-hx,hy,-hz)), (-1,0,0)),
            (((-hx,hy,hz),(hx,hy,hz),(hx,hy,-hz),(-hx,hy,-hz)), (0,1,0)),
            (((-hx,-hy,-hz),(hx,-hy,-hz),(hx,-hy,hz),(-hx,-hy,hz)), (0,-1,0)),
        )
        for vertices, local_normal in faces:
            nx, ny, nz = local_normal
            normal = (nx * cosine + nz * sine, ny, -nx * sine + nz * cosine)
            base = len(positions) // 3
            for px, py, pz in vertices:
                wx, wy, wz = point(px, py, pz)
                positions.extend((wx * WORLD_SCALE, wy, wz * WORLD_SCALE))
                normals.extend(normal)
                texcoords.extend((wx / 3.8, wz / 3.8))
            groups[group_name].extend((base, base + 1, base + 2,
                                       base, base + 2, base + 3))

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
            if river_distance < river_width + 1.0 and abs(cx) < 57.0:
                continue

            nx, _, nz = normal_at(cx, cz)
            slope = math.sqrt(nx * nx + nz * nz)
            noise = math.sin(cx * 0.43 + cz * 0.17) + math.cos(cz * 0.31 - cx * 0.12)
            lane_dist = lane_distance(cx, cz)
            access_dist = min(
                point_segment_distance(cx, cz, path[i], path[i + 1])
                for path in ACCESS_PATHS
                for i in range(len(path) - 1)
            )

            if lane_dist < 3.0 + 0.24 * noise or access_dist < 1.75:
                material = "soil"
            elif slope > 0.33 or (abs(cx) > 32 and abs(cz) < 31 and noise > 0.55):
                material = "rock"
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
            exponent = FOOTPRINT_EXPONENT
            wobble = edge_wobble(angle)
            cosine, sine = math.cos(angle), math.sin(angle)
            norm = (abs(cosine) ** exponent + abs(sine) ** exponent) ** (1.0 / exponent)
            scale = wobble / norm
            x = HALF_X * scale * cosine
            z = HALF_Z * scale * sine
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

    # The river is built as three continuous ribbons: a single water surface
    # and two independent banks on each side. All triangles are wound upward.
    previous: dict[str, tuple[int, ...]] = {}

    def add_up_triangle(group_name: str, a: int, b: int, c: int) -> None:
        ax, az = positions[a * 3], positions[a * 3 + 2]
        bx, bz = positions[b * 3], positions[b * 3 + 2]
        cx, cz = positions[c * 3], positions[c * 3 + 2]
        normal_y = (bz - az) * (cx - ax) - (bx - ax) * (cz - az)
        if normal_y >= 0.0:
            groups[group_name].extend((a, b, c))
        else:
            groups[group_name].extend((a, c, b))

    for sample_index in range(181):
        t = sample_index / 180.0
        cx, cz, half_width = catmull_rom(RIVER, t)
        before = catmull_rom(RIVER, max(0.0, t - 0.003))
        after = catmull_rom(RIVER, min(0.999999, t + 0.003))
        dx, dz = after[0] - before[0], after[1] - before[1]
        tangent_length = max(1e-5, math.hypot(dx, dz))
        side_x, side_z = -dz / tangent_length, dx / tangent_length
        water_y = height(cx, cz) + 0.56

        # Water: one continuous strip from left bank to right bank.
        water_indices = []
        water_half_width = half_width * 0.70
        for side in (1.0, -1.0):
            x = cx + side_x * water_half_width * side
            z = cz + side_z * water_half_width * side
            water_indices.append(len(positions) // 3)
            positions.extend((x * WORLD_SCALE, water_y, z * WORLD_SCALE))
            normals.extend((0.0, 1.0, 0.0))
            texcoords.extend((sample_index / 32.0, 0.0 if side > 0 else 1.0))

        if "water" in previous:
            prev = previous["water"]
            add_up_triangle("water", prev[0], water_indices[0], prev[1])
            add_up_triangle("water", water_indices[0], water_indices[1], prev[1])
        previous["water"] = tuple(water_indices)

        # Moss and soil each form two strips, one on either side of the channel.
        bands = (
            ("moss", half_width * 0.70, half_width * 0.92),
            ("soil", half_width * 0.92, half_width + 0.82),
        )
        for group_name, inner, outer in bands:
            current_indices = []
            for side in (1.0, -1.0):
                for is_inner, distance in ((True, inner), (False, outer)):
                    x = cx + side_x * distance * side
                    z = cz + side_z * distance * side
                    if group_name == "moss" and is_inner:
                        y = water_y - 0.035
                    else:
                        lift = 0.07 if is_inner else 0.035
                        y = height(x, z) + lift
                    current_indices.append(len(positions) // 3)
                    positions.extend((x * WORLD_SCALE, y, z * WORLD_SCALE))
                    normals.extend((0.0, 1.0, 0.0))
                    texcoords.extend((sample_index / 32.0, 0.0 if distance == inner else 1.0))

            # left-inner, left-outer, right-inner, right-outer
            if group_name in previous:
                prev = previous[group_name]
                cur = current_indices
                # Left bank quad.
                add_up_triangle(group_name, prev[0], cur[0], prev[1])
                add_up_triangle(group_name, cur[0], cur[1], prev[1])
                # Right bank quad.
                add_up_triangle(group_name, prev[2], prev[3], cur[2])
                add_up_triangle(group_name, prev[3], cur[3], cur[2])
            previous[group_name] = tuple(current_indices)

    # Three wide, walkable crossings connect each route across the river.
    for lane_x in (-22.5, 0.0, 22.5):
        river_z = river_center_z(lane_x)
        river_width = river_half_width(lane_x)
        bank_a = height(lane_x, river_z - river_width - 1.25)
        bank_b = height(lane_x, river_z + river_width + 1.25)
        deck_y = max(bank_a, bank_b) + 0.28
        deck_length = river_width * 2.0 + 3.5
        add_box("stone", lane_x, deck_y, river_z, 4.4, 0.42, deck_length)
        add_box("stone", lane_x - 2.02, deck_y + 0.34, river_z,
                0.28, 0.55, deck_length)
        add_box("stone", lane_x + 2.02, deck_y + 0.34, river_z,
                0.28, 0.55, deck_length)

    # Opposing base compounds sit farther apart at the expanded north/south ends.
    for base_z, accent_group in ((-35.5, "accent_blue"), (35.5, "accent_gold")):
        base_y = height(0.0, base_z) + 0.24
        add_box("stone", 0.0, base_y, base_z, 14.0, 0.52, 10.5)
        add_box("stone", 0.0, base_y + 0.52, base_z, 8.6, 0.42, 6.8, math.pi / 4)
        add_box("stone", 0.0, base_y + 1.18, base_z, 5.2, 0.92, 4.5)
        add_box(accent_group, 0.0, base_y + 1.95, base_z, 2.0, 1.1, 2.0)

    # Flank approaches remain open and traversable. They are secondary
    # routes through the side courtyards, not jungle camps/objectives.

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
        "stone": 5, "accent_blue": 6, "accent_gold": 7,
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
    materials.append({
        "name": "Carved Base Stone",
        "pbrMetallicRoughness": {
            "baseColorFactor": [0.40, 0.44, 0.48, 1.0],
            "metallicFactor": 0.08,
            "roughnessFactor": 0.78,
        },
        "doubleSided": True,
    })
    materials.append({
        "name": "Blue Base Core",
        "pbrMetallicRoughness": {
            "baseColorFactor": [0.08, 0.32, 0.56, 1.0],
            "metallicFactor": 0.18,
            "roughnessFactor": 0.28,
        },
        "emissiveFactor": [0.05, 0.28, 0.72],
        "doubleSided": True,
    })
    materials.append({
        "name": "Gold Base Core",
        "pbrMetallicRoughness": {
            "baseColorFactor": [0.66, 0.34, 0.09, 1.0],
            "metallicFactor": 0.34,
            "roughnessFactor": 0.32,
        },
        "emissiveFactor": [0.55, 0.18, 0.025],
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
            "layout": "expanded 120x84 rounded-rectangle MOBA arena with three lanes, side approaches and diagonal S-river",
            "mapShape": "expanded-rounded-rectangle-superellipse",
            "laneCount": 3,
            "bridgeCount": 3,
            "sideApproachCount": 4,
            "walkableSideCourtyards": True,
            "baseCount": 2,
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
    if len(primitives) != 8 or len(images) != 8 or any(not groups[name] for name in material_names):
        raise RuntimeError("Terrain GLB is missing a material group, route structure or embedded texture.")


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
        normalized_payload = normalize_scene_glb(payload, source_name)
        magic, version, declared_length = struct.unpack_from("<4sII", normalized_payload, 0)
        if magic != b"glTF" or version != 2 or declared_length != len(normalized_payload):
            raise RuntimeError(f"Normalized GLB validation failed: {source_name}")
        (output_nature / f"{output_name}.glb").write_bytes(normalized_payload)

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
