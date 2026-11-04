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
WORLD_SCALE = 1.15
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
    "Rock_Medium_1.bin": "3b8d132a71b30b62787e206ee6b517097370267a",
    "Rock_Medium_2.gltf": "353d1d80729226b73ac5bc22b227da7d50dfdc8a",
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

GROVES = (
    (-25.0, -19.0), (-27.0, -8.0), (-23.0, 8.0), (-26.0, 19.0),
    (25.0, -19.0), (27.0, -8.0), (23.0, 8.0), (26.0, 19.0),
    (-8.5, -21.0), (8.5, -21.0), (-8.5, 21.0), (8.5, 21.0),
)
CAMPS = (
    (-8.2, -14.5), (8.2, -14.5), (-20.2, -10.0), (20.2, -10.0),
    (-8.2, 14.5), (8.2, 14.5), (-20.2, 10.0), (20.2, 10.0),
)
OBJECTIVES = ((-7.0, 0.2, 4.55), (7.0, 0.2, 4.55))
RIVER = (
    (-34.0, 1.1, 0.78), (-28.0, 0.55, 1.15), (-21.0, 0.05, 1.48),
    (-15.0, -0.45, 1.68), (-9.0, -0.22, 1.92), (-3.0, 0.25, 1.58),
    (4.0, 0.38, 1.82), (10.0, 0.02, 1.95), (16.0, -0.38, 1.62),
    (23.0, -0.18, 1.62), (29.0, 0.22, 1.15), (34.0, 0.8, 0.78),
)

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
            headers={"User-Agent": "DuckDreamStudios-ProjectArena/0.16"},
        )
        with urllib.request.urlopen(request, timeout=45) as response:
            data = response.read()
        actual = git_blob_sha(data)
        if actual != expected:
            raise SystemExit(f"CC0 source blob mismatch for {name}: {actual}")
        downloaded[name] = data
    return downloaded


def river_sample(x: float, field: int) -> float:
    x = min(max(x, RIVER[0][0]), RIVER[-1][0])
    for index in range(len(RIVER) - 1):
        a, b = RIVER[index], RIVER[index + 1]
        if x <= b[0]:
            t = (x - a[0]) / (b[0] - a[0])
            return a[field] + (b[field] - a[field]) * t
    return RIVER[-1][field]


def terrain_height(x: float, z: float) -> float:
    west = 2.35 * math.exp(-((x + 24.0) ** 2) / 44.0) * (0.58 + 0.42 * math.cos(z * 0.075))
    east = 2.18 * math.exp(-((x - 24.0) ** 2) / 48.0) * (0.58 + 0.42 * math.cos(z * 0.07))
    south = 1.55 * math.exp(-((z + 27.0) ** 2) / 36.0) * math.exp(-(x ** 2) / 420.0)
    north = 1.55 * math.exp(-((z - 27.0) ** 2) / 36.0) * math.exp(-(x ** 2) / 420.0)
    jungle = 0.78 * math.exp(-((abs(x) - 8.5) ** 2) / 8.5) * math.exp(-((abs(z) - 14.0) ** 2) / 42.0)
    distance = abs(z - river_sample(x, 1))
    width = river_sample(x, 2)
    bed = -0.76 * math.exp(-(distance * distance) / (width * width * 0.82))
    bank_distance = distance - (width + 0.66)
    bank = 0.48 * math.exp(-(bank_distance * bank_distance) / 2.4)
    rolling = 0.26 * math.sin(x * 0.18) * math.cos(z * 0.14) + 0.16 * math.sin((x + z) * 0.29)
    shelf = 0.52 * math.exp(-((abs(x) - 18.5) ** 2) / 5.5) * math.exp(-((abs(z) - 13.0) ** 2) / 110.0)
    return rolling + west + east + south + north + jungle + bed + bank + shelf


def build_placements() -> dict[str, list[tuple[float, float, float, float, float]]]:
    result: dict[str, list[tuple[float, float, float, float, float]]] = {name: [] for name in MODELS}

    def add(model: str, x: float, z: float, scale: float, yaw: float, lift: float = 0.035) -> None:
        result[model].append((x, z, scale, yaw, lift))

    for index, (x, z) in enumerate(GROVES):
        add("Fern_1", x - 0.95, z + 0.55, 0.22, index * 0.91)
        add("Grass_Common_Tall", x + 1.08, z - 0.65, 0.55, index * 1.37)
        add("Grass_Wispy_Short", x + 0.12, z + 1.30, 0.92, index * 1.71)
        if index % 2 == 0:
            add("Flower_3_Group", x + 0.82, z + 0.92, 0.57, index * 0.73)
        if index % 3 == 1:
            add("Mushroom_Common", x - 1.05, z - 1.05, 1.35, index * 1.13)

    for index, (x, z) in enumerate(CAMPS):
        side = -1.0 if index % 2 == 0 else 1.0
        add("Fern_1", x - side * 2.2, z - 1.35, 0.20, index * 0.87)
        add("Mushroom_Common", x + side * 2.15, z + 1.45, 1.2, index * 1.41)

    for index, x in enumerate((-26.0, -18.0, -10.0, -2.0, 6.0, 14.0, 22.0, 30.0)):
        center_z = river_sample(x, 1)
        side = -1.0 if index % 2 == 0 else 1.0
        add("Fern_1", x, center_z + side * 2.25, 0.19, index * 0.59)
        add("Grass_Wispy_Short", x + 0.65, center_z - side * 2.15, 0.74, index * 1.09)

    for index, (x, z, radius) in enumerate(OBJECTIVES):
        add("Flower_3_Group", x + (1.45 if index == 0 else -1.45), z + 3.85, 0.50, index * 1.2)

    rocks = []
    for index, (x, z) in enumerate(CAMPS):
        for slot in range(3):
            angle = index * 0.31 + slot * (2.0 * math.pi / 3.0)
            model = "Rock_Medium_1" if (index + slot) % 2 == 0 else "Rock_Medium_2"
            rocks.append((model, x + math.cos(angle) * 2.55, z + math.sin(angle) * 2.0,
                          0.38 + (slot % 2) * 0.035, angle, 0.055))
    for index, (x, z) in enumerate(GROVES):
        for slot in range(2):
            angle = index * 0.43 + slot * math.pi
            model = "Rock_Medium_1" if (index + slot) % 2 == 0 else "Rock_Medium_2"
            rocks.append((model, x + math.cos(angle) * 2.0, z + math.sin(angle) * 1.55,
                          0.31 + (slot * 0.025), angle, 0.045))
    for index, (x, z, radius) in enumerate(OBJECTIVES):
        for slot in range(6):
            angle = index * 0.19 + slot * (2.0 * math.pi / 6.0)
            model = "Rock_Medium_1" if slot % 2 == 0 else "Rock_Medium_2"
            rocks.append((model, x + math.cos(angle) * (radius + 0.1),
                          z + math.sin(angle) * 3.8, 0.34, angle, 0.04))
    for index, x in enumerate((-26.0, -18.0, -10.0, -2.0, 6.0, 14.0, 22.0, 30.0)):
        center_z = river_sample(x, 1)
        side = -1.0 if index % 2 == 0 else 1.0
        model = "Rock_Medium_1" if index % 2 == 0 else "Rock_Medium_2"
        rocks.append((model, x, center_z + side * 2.25, 0.24, index * 0.77, 0.06))

    for model, x, z, scale, yaw, lift in rocks:
        result[model].append((x, z, scale, yaw, lift))
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
        f"{sum(map(len, placements.values()))} source placements -> "
        f"{ground_batches + rock_batches} draw batches, {total_vertices} vertices."
    )


if __name__ == "__main__":
    main()
