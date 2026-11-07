#!/usr/bin/env python3
"""Bake the irregular six-district Project Arena battlefield.

The offline GLB has a 224 × 188 navigable footprint, a curved canal with five
crossings, three combat corridors, six enterable interiors and side routes.
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
WORLD_SCALE = 1.0
# Expanded six-district combat footprint; polygon is mirrored in Dart.
HALF_X = 112.0
HALF_Z = 94.0
GRID_X = 224
GRID_Z = 188
WORLD_BOUNDARY = [
    (-72.0, -86.0), (-40.0, -92.0), (8.0, -89.0), (48.0, -93.0),
    (82.0, -84.0), (101.0, -69.0), (109.0, -44.0), (104.0, -17.0),
    (111.0, 10.0), (104.0, 37.0), (91.0, 60.0), (71.0, 82.0),
    (42.0, 87.0), (8.0, 82.0), (-24.0, 88.0), (-56.0, 82.0),
    (-82.0, 70.0), (-101.0, 48.0), (-108.0, 22.0), (-103.0, -6.0),
    (-109.0, -34.0), (-97.0, -62.0), (-84.0, -78.0),
]
BRIDGES = (-72.0, -36.0, 0.0, 36.0, 72.0)

# Meandering canal follows the edge between the six city districts.
RIVER = [
    (-90.0, -4.0, 1.55), (-60.0, -2.0, 1.85),
    (-30.0, 1.5, 2.05), (0.0, 0.5, 2.15),
    (30.0, -1.5, 2.05), (60.0, 1.8, 1.85),
    (90.0, 3.0, 1.55),
]
LANES = [
    [(-36.0, -70), (-36.5, -52), (-35.8, -35), (-36.2, -18),
     (-35.8, 0), (-36.2, 18), (-35.8, 35), (-36.5, 52), (-36.0, 70)],
    [(0.0, -70), (0.4, -52), (-0.3, -35), (0.3, -18),
     (-0.2, 0), (0.3, 18), (-0.3, 35), (0.4, 52), (0.0, 70)],
    [(36.0, -70), (36.5, -52), (35.8, -35), (36.2, -18),
     (35.8, 0), (36.2, 18), (35.8, 35), (36.5, 52), (36.0, 70)],
]

# Curved connectors lead from the three main combat corridors to six buildings.
ACCESS_PATHS = [
    [(-36, -36), (-46, -36), (-56, -36), (-64, -36)],
    [(36, -36), (46, -36), (56, -36), (64, -36)],
    [(-36, 36), (-46, 36), (-56, 36), (-64, 36)],
    [(36, 36), (46, 36), (56, 36), (64, 36)],
    [(-64, -36), (-70, -26), (-70, -12), (-56, -8), (-36, -8)],
    [(64, -36), (70, -26), (70, -12), (56, -8), (36, -8)],
    [(-64, 36), (-70, 26), (-70, 12), (-56, 8), (-36, 8)],
    [(64, 36), (70, 26), (70, 12), (56, 8), (36, 8)],
    [(-36, -18), (-52, -18), (-70, -18), (-88, -18)],
    [(36, 18), (52, 18), (70, 18), (88, 18)],
    [(-92, -40), (-92, -24), (-88, -18)],
    [(92, 40), (92, 24), (88, 18)],
    [(-88, -18), (-92, -4), (-92, 12), (-76, 24), (-64, 36)],
    [(88, 18), (92, 4), (92, -12), (76, -24), (64, -36)],
]

SIDE_APPROACH_ANCHORS = [
    (-58.0, -38.0), (58.0, -38.0),
    (-58.0, 38.0), (58.0, 38.0),
    (-68.0, -12.0), (68.0, -12.0),
    (-68.0, 12.0), (68.0, 12.0),
    (-92.0, -30.0), (92.0, 30.0),
    (-92.0, 30.0), (92.0, -30.0),
    (-72.0, -72.0), (72.0, 72.0),
    (-42.0, 76.0), (42.0, -76.0),
]
ASPHALT_SURFACE_LIFT = 0.11
ASPHALT_CROWN_LIFT = 0.025
CONCRETE_SURFACE_LIFT = 0.16


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
    # Continuous base terrain; paved roads and sidewalks are separate raised overlays.
    rolling = (
        0.045 * math.sin(x * 0.085) * math.cos(z * 0.072)
        + 0.028 * math.sin((x + z) * 0.12)
        + 0.018 * math.cos((x - z) * 0.16)
    )
    river_distance = abs(z - river_center_z(x))
    river_width = river_half_width(x)
    canal_bed = -0.42 * math.exp(
        -(river_distance * river_distance) / (river_width * river_width * 1.8)
    )
    curb_bank = 0.12 * math.exp(
        -((river_distance - river_width - 0.75) ** 2) / 2.8
    )
    return rolling + canal_bed + curb_bank


def normal_at(x: float, z: float) -> tuple[float, float, float]:
    epsilon = 0.08
    dx = (height(x + epsilon, z) - height(x - epsilon, z)) / (2.0 * epsilon * WORLD_SCALE)
    dz = (height(x, z + epsilon) - height(x, z - epsilon)) / (2.0 * epsilon * WORLD_SCALE)
    nx, ny, nz = -dx, 1.0, -dz
    length = math.sqrt(nx * nx + ny * ny + nz * nz)
    return nx / length, ny / length, nz / length


def inside_island(x: float, z: float) -> bool:
    # Ray casting over the same irregular polygon as ArenaWorldCatalog.contains.
    if abs(x) > HALF_X or abs(z) > HALF_Z:
        return False
    inside = False
    j = len(WORLD_BOUNDARY) - 1
    for i, (xi, zi) in enumerate(WORLD_BOUNDARY):
        xj, zj = WORLD_BOUNDARY[j]
        crosses = ((zi > z) != (zj > z)) and (
            x < (xj - xi) * (z - zi) / (zj - zi) + xi
        )
        if crosses:
            inside = not inside
        j = i
    return inside


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
        "grass": [], "moss": [], "asphalt": [], "concrete": [], "water": [],
        "stone": [], "accent_blue": [], "accent_gold": [], "markings": [],
    }
    material_names = [
        "grass", "moss", "asphalt", "concrete", "water",
        "stone", "accent_blue", "accent_gold", "markings",
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

    raised_vertex_cache: dict[tuple[int, int], int] = {}

    def add_raised_surface_cell(
        group_name: str,
        base_indices: tuple[int, int, int, int],
        lift: float,
    ) -> None:
        # Reuse vertices for equal millimeter-quantized lifts.
        lift_mm = round(lift * 1000.0)
        raised_indices = []
        for source_index in base_indices:
            cache_key = (source_index, lift_mm)
            target_index = raised_vertex_cache.get(cache_key)
            if target_index is None:
                source_offset = source_index * 3
                source_uv = source_index * 2
                target_index = len(positions) // 3
                raised_vertex_cache[cache_key] = target_index
                positions.extend((
                    positions[source_offset],
                    positions[source_offset + 1] + lift,
                    positions[source_offset + 2],
                ))
                normals.extend(normals[source_offset:source_offset + 3])
                texcoords.extend(texcoords[source_uv:source_uv + 2])
            raised_indices.append(target_index)
        a, b, c, d = raised_indices
        groups[group_name].extend((a, c, b, b, c, d))

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
            on_bridge = (
                river_distance < river_width + 3.0
                and any(abs(cx - bridge_x) <= 2.2 for bridge_x in BRIDGES)
            )
            if river_distance < river_width + 1.0 and not on_bridge:
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

            anchor_concrete = any(
                (cx - anchor_x) ** 2 + (cz - anchor_z) ** 2 <= 3.2 ** 2
                for anchor_x, anchor_z in SIDE_APPROACH_ANCHORS
            )
            if on_bridge:
                material = "moss" if (
                    math.sin(cx * 0.11 - cz * 0.17)
                    + math.cos(cx * 0.19 + cz * 0.13) < -0.55
                ) else "grass"
            elif lane_dist <= 4.8 or access_dist <= 3.0:
                material = "asphalt"
            elif (
                lane_dist <= 7.4 or access_dist <= 4.4
                or anchor_concrete
                or river_distance < river_width + 2.8
            ):
                material = "concrete"
            elif (
                math.sin(cx * 0.11 - cz * 0.17) + math.cos(cx * 0.19 + cz * 0.13) < -0.55
            ):
                material = "moss"
            else:
                material = "grass"

            i00 = zi * vertex_rows + xi
            i10 = i00 + 1
            i01 = i00 + vertex_rows
            i11 = i01 + 1
            base_indices = (i00, i01, i10, i11)
            groups[material].extend((i00, i01, i10, i10, i01, i11))

            if material == "asphalt":
                nearest_gap = min(lane_dist, access_dist)
                nearest_width = 4.8 if lane_dist <= access_dist else 3.0
                crown = max(0.0, min(1.0, 1.0 - nearest_gap / nearest_width))
                add_raised_surface_cell(
                    "asphalt", base_indices,
                    ASPHALT_SURFACE_LIFT + ASPHALT_CROWN_LIFT * crown,
                )
            elif material == "concrete":
                add_raised_surface_cell("concrete", base_indices, CONCRETE_SURFACE_LIFT)

    def add_road_edges(points: list[tuple[float, float]], half_width: float) -> None:
        for index in range(len(points) - 1):
            ax, az = points[index]
            bx, bz = points[index + 1]
            dx, dz = bx - ax, bz - az
            segment_length = math.hypot(dx, dz)
            if segment_length < 1e-4:
                continue
            normal_x, normal_z = -dz / segment_length, dx / segment_length
            yaw = math.atan2(dx, dz)
            midpoint_x, midpoint_z = (ax + bx) * 0.5, (az + bz) * 0.5
            for side in (-1.0, 1.0):
                curb_x = midpoint_x + normal_x * (half_width + 0.12) * side
                curb_z = midpoint_z + normal_z * (half_width + 0.12) * side
                add_box("stone", curb_x, height(curb_x, curb_z) + 0.12,
                        curb_z, 0.16, 0.22, segment_length + 0.08, yaw)

            dash_count = max(1, round(segment_length / 8.0))
            dash_length = min(1.55, segment_length / dash_count * 0.38)
            for dash_index in range(dash_count):
                fraction = (dash_index + 0.5) / dash_count
                mark_x = ax + dx * fraction
                mark_z = az + dz * fraction
                if any(
                    abs(mark_x - bridge_x) <= 4.0
                    and abs(mark_z - river_center_z(bridge_x))
                    <= river_half_width(bridge_x) + 3.0
                    for bridge_x in BRIDGES
                ):
                    continue
                add_box("markings", mark_x, height(mark_x, mark_z) + 0.145,
                        mark_z, 0.12, 0.012, dash_length, yaw)

    for lane in LANES:
        add_road_edges(lane, 4.8)
    for access_path in ACCESS_PATHS:
        add_road_edges(access_path, 3.0)

    # No cliff skirt: the urban district meets its surrounding city plane.

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

        # Moss and concrete each form two strips, one on either side of the channel.
        bands = (
            ("moss", half_width * 0.70, half_width * 0.92),
            ("concrete", half_width * 0.92, half_width + 0.82),
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

    # Five broad, walkable bridges connect the six districts across the canal.
    for lane_x in BRIDGES:
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

        for row_side in (-1.0, 1.0):
            crossing_z = river_z + row_side * (river_width + 1.10)
            for stripe_index in range(8):
                stripe_x = lane_x - 1.48 + stripe_index * 0.42
                add_box("markings", stripe_x, deck_y + 0.222, crossing_z,
                        0.25, 0.014, 0.12)

    # Opposing base compounds sit farther apart at the expanded north/south ends.
    for base_z, accent_group in ((-63.0, "accent_blue"), (63.0, "accent_gold")):
        base_y = height(0.0, base_z) + 0.24
        add_box("stone", 0.0, base_y, base_z, 18.0, 0.28, 13.0)
        add_box("stone", 0.0, base_y + 0.2, base_z, 12.0, 0.18, 8.0)
        add_box(accent_group, 0.0, base_y + 0.55, base_z, 2.4, 0.85, 2.4)

    # Flank approaches remain open and traversable. They are secondary
    # routes through the side courtyards, not jungle camps/objectives.

    # Enterable interiors are composed from real CC0 modular wall/floor assets
    # by MobaMatchView. Keep the terrain shell clear so the doors remain visible.

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
        "grass": 0, "moss": 1, "asphalt": 2, "concrete": 3, "water": 4,
        "stone": 5, "accent_blue": 6, "accent_gold": 7, "markings": 8,
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

    for material_name in ("grass", "moss", "asphalt", "concrete"):
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
    materials.append({
        "name": "Road Markings",
        "pbrMetallicRoughness": {
            "baseColorFactor": [0.78, 0.79, 0.75, 1.0],
            "metallicFactor": 0.0,
            "roughnessFactor": 0.92,
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
            "layout": "224x188 irregular six-district city battlefield with one continuous height-following terrain mesh, baked asphalt corridors, concrete sidewalks, a meandering canal, five bridges, six enterable interiors and CC0 city/park dressing",
            "roadSurface": "separate-raised-surface-mesh",
            "roadGeometry": "raised asphalt and concrete overlays over continuous ground, with raised curbs, lane dashes and bridge crossings; no independent scaled road tile slabs",
            "surfaceOffsets": {
                "asphaltBase": ASPHALT_SURFACE_LIFT,
                "asphaltCrown": ASPHALT_CROWN_LIFT,
                "concrete": CONCRETE_SURFACE_LIFT,
            },
            "mapShape": "irregular-six-district-polygon",
            "laneCount": 3,
            "bridgeCount": 5,
            "districtCount": 6,
            "enterableGroundFloorCount": 6,
            "sideApproachCount": 14,
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
    if len(primitives) != 9 or len(images) != 8 or any(not groups[name] for name in material_names):
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
        "Prepared offline world: continuous ground, raised paved surfaces, "
        f"curbs/markings, 4 CC0 nature GLBs and {total_bytes:,} bytes."
    )


if __name__ == "__main__":
    main()
