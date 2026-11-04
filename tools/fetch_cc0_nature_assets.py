#!/usr/bin/env python3
"""Fetch pinned Quaternius CC0 nature assets and bake low-draw-call arena GLBs."""
from __future__ import annotations

import hashlib
import json
import math
import os
import struct
import urllib.request
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "app/src/main/assets/world/nature"
SOURCE = "https://raw.githubusercontent.com/anandin/the-wild-between/001ecddebd9a5ed64cfadcccde0daf9342397a1b/assets/quaternius-nature/"
WORLD = json.loads((ROOT / "world/arena_world_1_7.json").read_text(encoding="utf-8"))
WORLD_SCALE = 1.0
SOURCE_COMMIT = "001ecddebd9a5ed64cfadcccde0daf9342397a1b"

EXPECTED = {
    "Fern_1.gltf": "2be91c742acf0c19f6b5a5195ac5070e9dbd56b2",
    "Fern_1.bin": "8712382dcdcf5a335e0bba000060acf285e918a0",
    "Grass_Common_Tall.gltf": "b1314703515f5adf748fee70369484881039b229",
    "Grass_Common_Tall.bin": "69b3c7f801ce454fd318e45b4fbfcc588b51be17",
    "Grass_Wispy_Short.gltf": "9e73049370b967ee6bba43fa5c60be6bfead9a0f",
    "Grass_Wispy_Short.bin": "bb62b3768f54b700c1334980aa57c5543f447c56",
    "Flower_3_Group.gltf": "e1e083986d17ba0362349e83256e1f38bf8b8d30",
    "Flower_3_Group.bin": "faa36e37db8a5fb8b0a29e382b27b2184a832be6",
    "Rock_Medium_1.gltf": "10896291ed3b58a2c51fe2e9cb8f912705e5b239",
    "Rock_Medium_2.gltf": "353d1d80729226b73ac5bc22b227da7d50dfdc8a",
    "Rock_Medium_1.bin": "3b8d132a71b30b62787e206ee6b517097370267a",
    "Rock_Medium_2.bin": "064074dca1028d3eb965b93be24da19710f44b55",
    "Mushroom_Common.gltf": "b0cc681e6630187d3fc1bb984f3f375997935135",
    "Mushroom_Common.bin": "b99724f959a5cb70937d8c6f830484d13e04b100",
    "Leaves.png": "4c9072464b9bdaf10798806cadd207d83fe2c321",
    "Grass.png": "e8c8c3c17178e0ef7964650d1a700e42d949ee07",
    "Flowers.png": "13311ad19c97096ff21670b41c3efbb49fc0f3f0",
    "Rocks_Diffuse.jpg": "9a2c80b7254d6b2368f82d0b8e9e708f2b947d2e",
    "Mushrooms.jpg": "c2e8f4191e39f300ed93e05912751d133871e09f",
}

MODELS = (
    "Fern_1",
    "Grass_Common_Tall",
    "Grass_Wispy_Short",
    "Flower_3_Group",
    "Mushroom_Common",
    "Rock_Medium_1",
    "Rock_Medium_2",
)

RIVER = [
    (float(point["x"]), float(point["z"]), float(point["half_width_m"]))
    for point in WORLD["river"]["centerline"]
]
LANES = [
    ([(float(point["x"]), float(point["z"])) for point in lane["waypoints"]],
     float(lane["width_m"]))
    for lane in WORLD["lanes"]
]
CAMPS = [
    (float(camp["position"]["x"]), float(camp["position"]["z"]))
    for camp in WORLD["camps"]
]
OBJECTIVES = [
    (float(item["position"]["x"]), float(item["position"]["z"]), float(item["radius_m"]))
    for item in WORLD["objectives"]
]
JUNGLES = [
    (region["id"], [(float(point["x"]), float(point["z"])) for point in region["boundary"]])
    for region in WORLD["jungle_regions"]
]
CROSSINGS = [
    (float(item["position"]["x"]), float(item["position"]["z"]), float(item["deck_width_m"]))
    for item in WORLD["river"]["crossings"]
]

COMPONENTS = {
    5120: ("b", 1, True), 5121: ("B", 1, False),
    5122: ("h", 2, True), 5123: ("H", 2, False),
    5125: ("I", 4, False), 5126: ("f", 4, False),
}
TYPE_WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def git_blob_sha(data: bytes) -> str:
    header = b"blob " + str(len(data)).encode("ascii") + b"\0"
    return hashlib.sha1(header + data).hexdigest()


def fetch_assets() -> dict[str, bytes]:
    downloaded: dict[str, bytes] = {}
    for name, expected in EXPECTED.items():
        request = urllib.request.Request(
            SOURCE + name,
            headers={"User-Agent": "DuckDreamStudios-ProjectArena/1.7"},
        )
        with urllib.request.urlopen(request, timeout=45) as response:
            data = response.read()
        actual = git_blob_sha(data)
        if actual != expected:
            raise SystemExit(f"CC0 source blob mismatch for {name}: {actual}")
        downloaded[name] = data
    return downloaded


def hash01(ix: int, iz: int, seed: int) -> float:
    value = (ix * 73856093) ^ (iz * 19349663) ^ (seed * 83492791)
    value &= 0xFFFFFFFF
    value ^= value >> 13
    value = (value * 1274126177) & 0xFFFFFFFF
    value ^= value >> 16
    return value / 0xFFFFFFFF


def distance_to_segment(x: float, z: float, a: tuple[float, float],
                        b: tuple[float, float]) -> float:
    dx, dz = b[0] - a[0], b[1] - a[1]
    denominator = max(dx * dx + dz * dz, 0.0001)
    t = max(0.0, min(1.0, ((x - a[0]) * dx + (z - a[1]) * dz) / denominator))
    return math.hypot(x - (a[0] + dx * t), z - (a[1] + dz * t))


def distance_to_polyline(x: float, z: float, points: list[tuple[float, float]]) -> float:
    return min(
        distance_to_segment(x, z, a, b)
        for a, b in zip(points, points[1:])
    )


def point_in_polygon(x: float, z: float, polygon: list[tuple[float, float]]) -> bool:
    inside = False
    for a, b in zip(polygon, polygon[1:] + polygon[:1]):
        if (a[1] > z) != (b[1] > z):
            crossing_x = (b[0] - a[0]) * (z - a[1]) / (b[1] - a[1]) + a[0]
            if x < crossing_x:
                inside = not inside
    return inside


def river_nearest(x: float, z: float) -> tuple[float, float, float, float]:
    best_distance = float("inf")
    best_width = RIVER[0][2]
    best_x, best_z = x, z
    for a, b in zip(RIVER, RIVER[1:]):
        dx, dz = b[0] - a[0], b[1] - a[1]
        denominator = max(dx * dx + dz * dz, 0.0001)
        t = max(0.0, min(1.0, ((x - a[0]) * dx + (z - a[1]) * dz) / denominator))
        px, pz = a[0] + dx * t, a[1] + dz * t
        distance = math.hypot(x - px, z - pz)
        if distance < best_distance:
            best_distance = distance
            best_width = a[2] + (b[2] - a[2]) * t
            best_x, best_z = px, pz
    return best_distance, best_width, best_x, best_z


def terrain_height(x: float, z: float) -> float:
    ridge = 0.0
    valley_control = 0.0
    for control in WORLD["terrain"]["elevation_controls"]:
        dx = x - float(control["position"]["x"])
        dz = z - float(control["position"]["z"])
        height = float(control["height_m"])
        radius = float(control["radius_m"])
        influence = math.exp(-(dx * dx + dz * dz) / max(radius * radius * 0.50, 0.001))
        if height >= 0.0:
            ridge = max(ridge, height * influence)
        else:
            valley_control += height * influence
    distance, half_width, _, _ = river_nearest(x, z)
    channel = -float(WORLD["terrain"]["river_valley_depth_m"]) * math.exp(
        -(distance * distance) / max(half_width * half_width * 1.60, 0.001)
    )
    broad_phase = (int(WORLD["terrain"]["broad_noise_seed"]) % 97) * 0.013
    detail_phase = (int(WORLD["terrain"]["detail_noise_seed"]) % 97) * 0.013
    broad_amp = float(WORLD["terrain"]["broad_noise_amplitude_m"])
    detail_amp = float(WORLD["terrain"]["detail_noise_amplitude_m"])
    broad_noise = broad_amp * (
        0.58 * math.sin((x + broad_phase) * 0.031) * math.cos((z - broad_phase) * 0.027)
        + 0.42 * math.sin((x + z) * 0.019 + broad_phase)
    )
    detail_noise = detail_amp * math.sin(x * 0.19 + z * 0.13 + detail_phase) * math.cos(
        z * 0.17 - x * 0.11 - detail_phase
    )
    low = float(WORLD["terrain"]["height_min_m"])
    high = float(WORLD["terrain"]["height_max_m"])
    return max(low, min(high, ridge + valley_control + channel + broad_noise + detail_noise))


def build_placements() -> dict[str, list[tuple[float, float, float, float, float]]]:
    result: dict[str, list[tuple[float, float, float, float, float]]] = {
        name: [] for name in MODELS
    }

    def add(model: str, x: float, z: float, scale: float, yaw: float,
            lift: float = 0.035) -> None:
        result[model].append((x, z, scale, yaw, lift))

    # Scatter light groundcover through both authored jungle polygons.
    # Lanes, river, camp clearings, crossings and objective arenas remain readable.
    spacing = 5.5
    accepted = 0
    for region_index, (region_id, polygon) in enumerate(JUNGLES):
        min_x, max_x = min(p[0] for p in polygon), max(p[0] for p in polygon)
        min_z, max_z = min(p[1] for p in polygon), max(p[1] for p in polygon)
        x = math.floor(min_x / spacing) * spacing + spacing * 0.5
        while x <= max_x:
            z = math.floor(min_z / spacing) * spacing + spacing * 0.5
            while z <= max_z:
                gx, gz = round(x * 10), round(z * 10)
                px = x + (hash01(gx, gz, 1703) - 0.5) * 1.8
                pz = z + (hash01(gx, gz, 1705) - 0.5) * 1.8
                if point_in_polygon(px, pz, polygon):
                    river_distance, river_width, _, _ = river_nearest(px, pz)
                    lane_clear = all(
                        distance_to_polyline(px, pz, points) >= width * 0.5 + 2.4
                        for points, width in LANES
                    )
                    camp_clear = all(math.hypot(px - cx, pz - cz) >= 5.8 for cx, cz in CAMPS)
                    objective_clear = all(
                        math.hypot(px - ox, pz - oz) >= radius + 3.0
                        for ox, oz, radius in OBJECTIVES
                    )
                    crossing_clear = all(
                        math.hypot(px - bx, pz - bz) >= deck_width * 0.5 + 2.0
                        for bx, bz, deck_width in CROSSINGS
                    )
                    density = hash01(gx, gz, 1709)
                    if (
                        river_distance >= river_width + 1.7 and lane_clear and
                        camp_clear and objective_clear and crossing_clear and density < 0.62
                    ):
                        accepted += 1
                        yaw = hash01(gx, gz, 1711) * math.tau
                        add("Fern_1", px - 0.46, pz + 0.38,
                            0.15 + hash01(gx, gz, 1713) * 0.10, yaw)
                        add("Grass_Wispy_Short", px + 0.48, pz - 0.33,
                            0.48 + hash01(gx, gz, 1717) * 0.32, yaw + 1.7)
                        if hash01(gx, gz, 1721) < 0.34:
                            add("Grass_Common_Tall", px + 0.18, pz + 0.78,
                                0.36 + hash01(gx, gz, 1723) * 0.22, yaw + 0.9)
                        if hash01(gx, gz, 1727) < 0.095:
                            add("Flower_3_Group", px - 0.64, pz - 0.56,
                                0.34 + hash01(gx, gz, 1729) * 0.20, yaw + 2.2)
                        if hash01(gx, gz, 1733) < 0.055:
                            add("Mushroom_Common", px + 0.82, pz + 0.36,
                                0.78 + hash01(gx, gz, 1739) * 0.44, yaw + 0.45)
                z += spacing
            x += spacing

    # Small organic vegetation halos frame camps but never cover their gameplay clearings.
    for index, (x, z) in enumerate(CAMPS):
        angle = index * 0.31
        for slot in range(2):
            side = angle + slot * math.pi
            add("Fern_1", x + math.cos(side) * 5.0, z + math.sin(side) * 4.6,
                0.17, side)
            add("Mushroom_Common", x + math.cos(side + 1.0) * 5.3,
                z + math.sin(side + 1.0) * 4.8, 0.82, side + 1.0)

    # Riverbank vegetation follows the authored spline, not a legacy straight strip.
    for index in (1, 3, 5, 7, 9, 11):
        x, z, width = RIVER[index]
        for side in (-1.0, 1.0):
            px, pz = x, z + side * (width + 1.0)
            add("Fern_1", px, pz, 0.16, index * 0.61 + side)
            if index % 2 == 1:
                add("Grass_Wispy_Short", px + side * 0.7, pz, 0.62, index * 0.83)

    # Objective debris remains asymmetric and readable from the lane entrances.
    rocks: list[tuple[str, float, float, float, float, float]] = []
    # The six visible camp rocks share the exact positions used by native collision.
    # This prevents the familiar "looks solid but can be walked through" mismatch.
    for index, (x, z) in enumerate(CAMPS):
        for slot in range(6):
            angle = index * 0.27 + slot * (2.0 * math.pi / 6.0)
            model = "Rock_Medium_1" if (index + slot) % 2 == 0 else "Rock_Medium_2"
            rocks.append((
                model,
                x + math.cos(angle) * 2.7,
                z + math.sin(angle) * 2.15,
                0.29 + (slot % 2) * 0.025,
                angle,
                0.045
            ))
    for index, (x, z, radius) in enumerate(OBJECTIVES):
        for slot in range(6):
            angle = index * 0.19 + slot * (2.0 * math.pi / 6.0)
            model = "Rock_Medium_1" if slot % 2 == 0 else "Rock_Medium_2"
            rocks.append((model, x + math.cos(angle) * (radius + 1.1),
                          z + math.sin(angle) * (radius + 0.5), 0.34, angle, 0.04))
    for index in (2, 5, 8, 11):
        x, z, width = RIVER[index]
        side = -1.0 if index % 2 == 0 else 1.0
        model = "Rock_Medium_1" if index % 2 == 0 else "Rock_Medium_2"
        rocks.append((model, x, z + side * (width + 1.35), 0.26, index * 0.77, 0.05))
    for model, x, z, scale, yaw, lift in rocks:
        result[model].append((x, z, scale, yaw, lift))

    total_ground = sum(len(result[name]) for name in MODELS if not name.startswith("Rock_"))
    total_rocks = sum(len(result[name]) for name in MODELS if name.startswith("Rock_"))
    if accepted < 55 or total_ground < 150 or total_rocks < 48:
        raise SystemExit(
            f"Canonical jungle scatter is too sparse: cells={accepted}, "
            f"ground={total_ground}, rocks={total_rocks} (collision-aligned camp rocks included)"
        )
    return result

def read_accessor(doc: dict, binary: bytes, accessor_index: int) -> list[tuple[float, ...]]:
    accessor = doc["accessors"][accessor_index]
    component = accessor["componentType"]
    fmt, component_size, signed = COMPONENTS[component]
    width = TYPE_WIDTH[accessor["type"]]
    view = doc["bufferViews"][accessor["bufferView"]]
    stride = view.get("byteStride", component_size * width)
    offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    normalized = accessor.get("normalized", False)
    values: list[tuple[float, ...]] = []
    unpacker = struct.Struct("<" + fmt * width)
    for row in range(accessor["count"]):
        raw = unpacker.unpack_from(binary, offset + row * stride)
        if normalized and component != 5126:
            if signed:
                converted = tuple(max(-1.0, value / float((1 << (component_size * 8 - 1)) - 1)) for value in raw)
            else:
                converted = tuple(value / float((1 << (component_size * 8)) - 1) for value in raw)
        else:
            converted = tuple(float(value) for value in raw)
        values.append(converted)
    return values


def read_indices(doc: dict, binary: bytes, accessor_index: int) -> list[int]:
    accessor = doc["accessors"][accessor_index]
    fmt, component_size, _ = COMPONENTS[accessor["componentType"]]
    view = doc["bufferViews"][accessor["bufferView"]]
    stride = view.get("byteStride", component_size)
    offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    unpacker = struct.Struct("<" + fmt)
    return [int(unpacker.unpack_from(binary, offset + i * stride)[0]) for i in range(accessor["count"])]


def align4(buffer: bytearray) -> None:
    while len(buffer) % 4:
        buffer.append(0)


def build_glb(name: str, group_data: OrderedDict, image_data: dict[str, bytes], destination: Path) -> tuple[int, int]:
    binary = bytearray()
    views = []
    accessors = []
    materials = []
    images = []
    textures = []
    primitives = []
    sampler = {"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}

    def add_view(data: bytes, target: int | None = None) -> int:
        align4(binary)
        offset = len(binary)
        binary.extend(data)
        view = {"buffer": 0, "byteOffset": offset, "byteLength": len(data)}
        if target is not None:
            view["target"] = target
        views.append(view)
        return len(views) - 1

    image_index_by_uri = {}
    for key in group_data.keys():
        texture_uri = key[0]
        if texture_uri not in image_index_by_uri:
            data = image_data[texture_uri]
            view_index = add_view(data)
            mime = "image/png" if data.startswith(b"\x89PNG\r\n\x1a\n") else "image/jpeg"
            image_index_by_uri[texture_uri] = len(images)
            images.append({"name": Path(texture_uri).stem, "bufferView": view_index, "mimeType": mime})
            textures.append({"sampler": 0, "source": image_index_by_uri[texture_uri]})

    for material_index, (key, group) in enumerate(group_data.items()):
        texture_uri, alpha_mode, alpha_cutoff = key
        double_sided = group["double_sided"]
        texture_index = image_index_by_uri[texture_uri]
        material = {
            "name": group["name"],
            "pbrMetallicRoughness": {
                "baseColorFactor": [1.0, 1.0, 1.0, 1.0],
                "baseColorTexture": {"index": texture_index},
                "metallicFactor": 0.0,
                "roughnessFactor": 0.92 if "Rock" in group["name"] else 0.88,
            },
        }
        if alpha_mode != "OPAQUE":
            material["alphaMode"] = alpha_mode
            material["alphaCutoff"] = alpha_cutoff
        if double_sided:
            material["doubleSided"] = True
        materials.append(material)

        attrs = {}
        for semantic in ("POSITION", "NORMAL", "TEXCOORD_0", "COLOR_0"):
            if semantic not in group["attributes"]:
                continue
            rows = group["attributes"][semantic]
            flat = [component for row in rows for component in row]
            packed = struct.pack("<" + "f" * len(flat), *flat)
            view_index = add_view(packed, 34962)
            components = len(rows[0])
            accessor_type = {2: "VEC2", 3: "VEC3", 4: "VEC4"}[components]
            accessor = {
                "bufferView": view_index,
                "componentType": 5126,
                "count": len(rows),
                "type": accessor_type,
            }
            if semantic == "POSITION":
                accessor["min"] = [min(row[i] for row in rows) for i in range(3)]
                accessor["max"] = [max(row[i] for row in rows) for i in range(3)]
            accessors.append(accessor)
            attrs[semantic] = len(accessors) - 1
        index_bytes = struct.pack("<" + "I" * len(group["indices"]), *group["indices"])
        index_view = add_view(index_bytes, 34963)
        accessors.append({
            "bufferView": index_view,
            "componentType": 5125,
            "count": len(group["indices"]),
            "type": "SCALAR",
        })
        primitives.append({
            "attributes": attrs,
            "indices": len(accessors) - 1,
            "material": material_index,
            "mode": 4,
        })

    if not primitives:
        raise SystemExit(f"No geometry was generated for {name}")
    align4(binary)
    bin_payload = bytes(binary)
    gltf = {
        "asset": {
            "version": "2.0",
            "generator": "DuckDreamStudios-CC0-Nature-Baker",
            "extras": {
                "source": "Quaternius Stylized Nature MegaKit (CC0-1.0)",
                "sourceRepository": "anandin/the-wild-between",
                "sourceCommit": SOURCE_COMMIT,
                "renderBatches": len(primitives),
            },
        },
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": name, "mesh": 0}],
        "meshes": [{"name": name, "primitives": primitives}],
        "materials": materials,
        "textures": textures,
        "images": images,
        "samplers": [sampler],
        "buffers": [{"byteLength": len(bin_payload)}],
        "bufferViews": views,
        "accessors": accessors,
    }
    json_chunk = json.dumps(gltf, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    json_chunk += b" " * ((4 - len(json_chunk) % 4) % 4)
    bin_chunk = bin_payload + b"\0" * ((4 - len(bin_payload) % 4) % 4)
    total_length = 12 + 8 + len(json_chunk) + 8 + len(bin_chunk)
    glb = (
        struct.pack("<4sII", b"glTF", 2, total_length)
        + struct.pack("<II", len(json_chunk), 0x4E4F534A)
        + json_chunk
        + struct.pack("<II", len(bin_chunk), 0x004E4942)
        + bin_chunk
    )
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(glb)
    vertex_count = sum(len(group["attributes"]["POSITION"]) for group in group_data.values())
    return len(primitives), vertex_count


def bake(models: dict[str, tuple[dict, bytes]], placements: dict[str, list[tuple[float, float, float, float, float]]],
         image_data: dict[str, bytes], category: str) -> OrderedDict:
    groups: OrderedDict = OrderedDict()
    for model_name in MODELS:
        if category == "rocks" and not model_name.startswith("Rock_"):
            continue
        if category == "ground" and model_name.startswith("Rock_"):
            continue
        doc, mesh_binary = models[model_name]
        model_placements = placements[model_name]
        for node in doc.get("nodes", []):
            if node.get("mesh") is None:
                continue
            if any(node.get(key) not in (None, [0, 0, 0], [1, 1, 1], [0, 0, 0, 1]) for key in ("translation", "scale", "rotation")):
                raise SystemExit(f"Non-identity source node transform is unsupported: {model_name}")
            mesh = doc["meshes"][node["mesh"]]
            for primitive in mesh["primitives"]:
                if primitive.get("mode", 4) != 4:
                    raise SystemExit(f"Unexpected non-triangle primitive in {model_name}")
                mat = doc["materials"][primitive["material"]]
                pbr = mat.get("pbrMetallicRoughness", {})
                texture = pbr.get("baseColorTexture", {}).get("index")
                if texture is None:
                    raise SystemExit(f"Texture-backed material required: {model_name}")
                source_image = doc["textures"][texture]["source"]
                texture_uri = doc["images"][source_image]["uri"]
                alpha_mode = mat.get("alphaMode", "OPAQUE")
                alpha_cutoff = round(float(mat.get("alphaCutoff", 0.5)), 4)
                key = (texture_uri, alpha_mode, alpha_cutoff)
                if key not in groups:
                    groups[key] = {
                        "name": mat.get("name", Path(texture_uri).stem),
                        "attributes": OrderedDict(),
                        "indices": [],
                        "double_sided": bool(mat.get("doubleSided", False)),
                    }
                group = groups[key]
                group["double_sided"] = group["double_sided"] or bool(mat.get("doubleSided", False))
                attr_source = primitive["attributes"]
                source_attributes = {}
                for semantic in ("POSITION", "NORMAL", "TEXCOORD_0", "COLOR_0"):
                    if semantic in attr_source:
                        source_attributes[semantic] = read_accessor(doc, mesh_binary, attr_source[semantic])
                required = ("POSITION", "NORMAL", "TEXCOORD_0")
                if any(semantic not in source_attributes for semantic in required):
                    raise SystemExit(f"Missing required vertex attribute in {model_name}")
                if not group["attributes"]:
                    for semantic, rows in source_attributes.items():
                        group["attributes"][semantic] = []
                if set(group["attributes"]) != set(source_attributes):
                    raise SystemExit(f"Vertex attribute layout differs inside merged material {key}")
                source_indices = read_indices(doc, mesh_binary, primitive["indices"])
                for anchor_x, anchor_z, scale, yaw, lift in model_placements:
                    base_index = len(group["attributes"]["POSITION"])
                    cosine, sine = math.cos(yaw), math.sin(yaw)
                    base_y = terrain_height(anchor_x, anchor_z) + lift
                    for vertex_index, pos in enumerate(source_attributes["POSITION"]):
                        lx, ly, lz = pos
                        rx = (lx * cosine + lz * sine) * scale
                        rz = (-lx * sine + lz * cosine) * scale
                        group["attributes"]["POSITION"].append((
                            (anchor_x * WORLD_SCALE) + rx * WORLD_SCALE,
                            base_y + ly * scale,
                            (anchor_z * WORLD_SCALE) + rz * WORLD_SCALE,
                        ))
                        normal = source_attributes["NORMAL"][vertex_index]
                        nx = normal[0] * cosine + normal[2] * sine
                        nz = -normal[0] * sine + normal[2] * cosine
                        length = math.sqrt(nx * nx + normal[1] * normal[1] + nz * nz) or 1.0
                        group["attributes"]["NORMAL"].append((nx / length, normal[1] / length, nz / length))
                        group["attributes"]["TEXCOORD_0"].append(source_attributes["TEXCOORD_0"][vertex_index])
                        if "COLOR_0" in source_attributes:
                            group["attributes"]["COLOR_0"].append(source_attributes["COLOR_0"][vertex_index])
                    group["indices"].extend(base_index + value for value in source_indices)
    return groups



def source_vertex_costs(models: dict[str, tuple[dict, bytes]]) -> dict[str, int]:
    """Count source POSITION vertices replicated by one baked placement of each model."""
    costs: dict[str, int] = {}
    for model_name, (doc, _) in models.items():
        total = 0
        for node in doc.get("nodes", []):
            mesh_index = node.get("mesh")
            if mesh_index is None:
                continue
            for primitive in doc["meshes"][mesh_index]["primitives"]:
                position_accessor = primitive["attributes"]["POSITION"]
                total += int(doc["accessors"][position_accessor]["count"])
        if total <= 0:
            raise SystemExit(f"Source model has no POSITION vertices: {model_name}")
        costs[model_name] = total
    return costs


def trim_placements_to_vertex_budget(
    models: dict[str, tuple[dict, bytes]],
    placements: dict[str, list[tuple[float, float, float, float, float]]],
    target_vertices: int = 95_000,
    minimum_ground_placements: int = 150,
) -> tuple[dict[str, list[tuple[float, float, float, float, float]]], dict[str, int]]:
    """Deterministically thin only secondary groundcover while preserving gameplay rocks."""
    costs = source_vertex_costs(models)
    rock_names = [name for name in MODELS if name.startswith("Rock_")]
    ground_names = [name for name in MODELS if not name.startswith("Rock_")]
    rock_vertices = sum(len(placements[name]) * costs[name] for name in rock_names)
    ground_candidates = [
        (name, index, item)
        for name in ground_names
        for index, item in enumerate(placements[name])
    ]
    original_ground_vertices = sum(len(placements[name]) * costs[name] for name in ground_names)
    original_total = rock_vertices + original_ground_vertices

    if rock_vertices >= target_vertices:
        raise SystemExit(
            f"Gameplay rocks alone exceed the nature vertex target: "
            f"{rock_vertices} > {target_vertices}"
        )
    if original_total <= target_vertices:
        return {name: list(items) for name, items in placements.items()}, {
            "original_vertices": original_total,
            "kept_vertices": original_total,
            "original_ground": len(ground_candidates),
            "kept_ground": len(ground_candidates),
        }

    # Fern silhouettes are the primary low vegetation read. Fine grass remains common;
    # flowers and mushrooms are accents and are thinned first when a device budget is hit.
    visual_weights = {
        "Fern_1": 2.40,
        "Grass_Wispy_Short": 2.10,
        "Grass_Common_Tall": 1.50,
        "Flower_3_Group": 1.00,
        "Mushroom_Common": 0.90,
    }
    model_seed = {name: 1801 + index * 97 for index, name in enumerate(MODELS)}
    target = {
        name: list(placements[name]) if name in rock_names else []
        for name in MODELS
    }

    def candidate(scale: float):
        chosen: dict[str, list[tuple[float, float, float, float, float]]] = {
            name: list(placements[name]) if name in rock_names else []
            for name in MODELS
        }
        kept_ground = 0
        projected = rock_vertices
        for model_name in ground_names:
            probability = min(1.0, visual_weights[model_name] * scale)
            for index, item in enumerate(placements[model_name]):
                x, z = item[0], item[1]
                score = hash01(
                    round(x * 10),
                    round(z * 10),
                    model_seed[model_name] + index * 13
                )
                if score < probability:
                    chosen[model_name].append(item)
                    kept_ground += 1
                    projected += costs[model_name]
        return chosen, projected, kept_ground

    low, high = 0.0, 4.0
    best = None
    for _ in range(34):
        middle = (low + high) * 0.5
        chosen, projected, kept_ground = candidate(middle)
        if projected <= target_vertices and kept_ground >= minimum_ground_placements:
            best = (chosen, projected, kept_ground)
            low = middle
        else:
            high = middle

    if best is None:
        minimum = candidate(4.0)
        costs_report = ", ".join(
            f"{name}:{len(placements[name])}x{costs[name]}"
            for name in MODELS
        )
        raise SystemExit(
            f"Cannot fit the 100k nature budget while retaining {minimum_ground_placements} "
            f"ground placements. rocks={rock_vertices}, modelCosts=[{costs_report}]"
        )

    chosen, projected, kept_ground = best
    if projected > target_vertices or kept_ground < minimum_ground_placements:
        raise SystemExit("Deterministic nature budget optimizer violated its target")
    kept_counts = {name: len(chosen[name]) for name in MODELS}
    print(
        "Nature LOD budget: "
        f"{original_total} -> {projected} vertices, "
        f"ground placements {len(ground_candidates)} -> {kept_ground}, "
        f"retained per model={kept_counts}"
    )
    return chosen, {
        "original_vertices": original_total,
        "kept_vertices": projected,
        "original_ground": len(ground_candidates),
        "kept_ground": kept_ground,
    }



def main() -> None:
    raw = fetch_assets()
    models: dict[str, tuple[dict, bytes]] = {}
    image_data = {}
    for model_name in MODELS:
        doc = json.loads(raw[model_name + ".gltf"].decode("utf-8"))
        buffers = doc.get("buffers", [])
        if len(buffers) != 1 or buffers[0].get("uri") is None:
            raise SystemExit(f"Expected one external source buffer in {model_name}")
        mesh_name = buffers[0]["uri"]
        models[model_name] = (doc, raw[mesh_name])
        for image in doc.get("images", []):
            uri = image.get("uri")
            if not uri or uri not in raw:
                raise SystemExit(f"Missing image dependency {uri} for {model_name}")
            image_data[uri] = raw[uri]

    placements = build_placements()
    placements, budget = trim_placements_to_vertex_budget(models, placements)
    ground = bake(models, placements, image_data, "ground")
    rocks = bake(models, placements, image_data, "rocks")
    ground_batches, ground_vertices = build_glb(
        "forest_groundcover", ground, image_data, OUT / "forest_groundcover.glb"
    )
    rock_batches, rock_vertices = build_glb(
        "forest_rocks", rocks, image_data, OUT / "forest_rocks.glb"
    )
    total_vertices = ground_vertices + rock_vertices
    if ground_batches != 4 or rock_batches != 1:
        raise SystemExit(f"Unexpected nature draw batch count: ground={ground_batches}, rocks={rock_batches}")
    if total_vertices > 100_000:
        raise SystemExit(f"Nature geometry exceeded the 100k vertex budget: {total_vertices}")
    for filename in ("forest_groundcover.glb", "forest_rocks.glb"):
        if (OUT / filename).stat().st_size > 6_000_000:
            raise SystemExit(f"Packed nature GLB exceeds 6 MB: {filename}")
    print(
        "Baked CC0 nature: "
        f"{sum(map(len, placements.values()))} optimized placements "
        f"(from {budget['original_ground'] + sum(len(placements[name]) for name in MODELS if name.startswith('Rock_'))} before budget) -> "
        f"{ground_batches + rock_batches} draw batches, {total_vertices} vertices."
    )


if __name__ == "__main__":
    main()
