#!/usr/bin/env python3
"""Fetch a pinned CC0 medieval environment subset and optimize it for offline Android use."""
from __future__ import annotations

import hashlib
import json
import time
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "app/src/main/assets/world/vale"
SOURCE_REPO = "J-Ponzo/gltf-medieval-village-megakit"
SOURCE_COMMIT = "21104b4045261c28fc312360841ed1a7b0ac8782"
RAW = f"https://raw.githubusercontent.com/{SOURCE_REPO}/{SOURCE_COMMIT}"

# GitHub Git-blob SHA-1 and original byte length from the pinned source tree.
SOURCES = {
    "models/Wall_Arch.gltf": ("glTF/Wall_Arch.gltf", 2163, "eeb87453aa572b543388f8bd8ff7e993c13f9181"),
    "models/Wall_Arch.bin": ("glTF/Wall_Arch.bin", 9496, "680d970784f9fbd2edcd8b2a1ce27a86f7f7127e"),
    "models/Wall_Plaster_Straight.gltf": ("glTF/Wall_Plaster_Straight.gltf", 4169, "fb8b38f935a4ec0ef9f5069d153e52e796324da7"),
    "models/Wall_Plaster_Straight.bin": ("glTF/Wall_Plaster_Straight.bin", 5876, "55b39191caee09d6e2f2ea2d1525eb37671f4edf"),
    "models/Wall_UnevenBrick_Straight.gltf": ("glTF/Wall_UnevenBrick_Straight.gltf", 5392, "5b88693146ead782474d3a4f8a6b48d7f5"),
    "models/Wall_UnevenBrick_Straight.bin": ("glTF/Wall_UnevenBrick_Straight.bin", 2768, "e81f1781287b137ab2ea1a57cedd979f28f0f3fc"),
    "models/Stairs_Exterior_Straight.gltf": ("glTF/Stairs_Exterior_Straight.gltf", 3820, "29a21d2372ee53036a377f3d39e3154812593dd2"),
    "models/Stairs_Exterior_Straight.bin": ("glTF/Stairs_Exterior_Straight.bin", 4148, "10137f7d620a2bd40dbf24c4cfec8b7af382c946"),
    "models/Prop_Vine1.gltf": ("glTF/Prop_Vine1.gltf", 1979, "c8a31ddbce14cf7c272697e5f4da301a98f88a0c"),
    "models/Prop_Vine1.bin": ("glTF/Prop_Vine1.bin", 5580, "b7737f593c9f2385d0d2f72632c02868caa1b79f"),
    "models/Roof_RoundTiles_4x4.gltf": ("glTF/Roof_RoundTiles_4x4.gltf", 4337, "d1ca604799ebb49cb4a0abca7e250e0932bd165f"),
    "models/Roof_RoundTiles_4x4.bin": ("glTF/Roof_RoundTiles_4x4.bin", 107176, "617878d038c7577dffc0a019020112d058f5f559"),
    "models/T_WoodTrim_BaseColor.png": ("glTF/T_WoodTrim_BaseColor.png", 2082310, "3547da835b7b1aa89e27e98c68b1582bd203ef93"),
    "models/T_Plaster_BaseColor.png": ("glTF/T_Plaster_BaseColor.png", 3316410, "14ff755f0dc786a775faea8eb9d51ef1e4dcd613"),
    "models/T_UnevenBrick_BaseColor.png": ("glTF/T_UnevenBrick_BaseColor.png", 2945342, "fd30c5496aa1c44fa6f22ed3281e7412091bc17f"),
    "models/T_RockTrim_BaseColor.png": ("glTF/T_RockTrim_BaseColor.png", 1908835, "66d38c3389b53c261dca7253a8898a5fa92cecfe"),
    "models/T_Brick_BaseColor.png": ("glTF/T_Brick_BaseColor.png", 2447169, "fdef46f78d9ccaeaf3b1efee6ca7cbca5b0769d1"),
    "models/T_VineLeaf_png.png": ("glTF/T_VineLeaf_png.png", 162432, "64d615c88f6a8c7dfa5e4c1836f18713eaabe9a4"),
    "models/T_RoundTiles_BaseColor.png": ("glTF/T_RoundTiles_BaseColor.png", 4352034, "1499f2b4d6eda2da8ca7512c342ed29632cf3d1e"),
    "CC0-1.0.txt": ("LICENSE", 7048, "0e259d42c996742e9e3cba14c677129b2c1b6311"),
}

MODELS = (
    "Wall_Arch",
    "Wall_Plaster_Straight",
    "Wall_UnevenBrick_Straight",
    "Stairs_Exterior_Straight",
    "Prop_Vine1",
    "Roof_RoundTiles_4x4",
)


def git_blob_sha(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\0" + data).hexdigest()


def download(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "DuckDreamStudios-ProjectArena-CI/1.0"})
    last_error = None
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                return response.read()
        except Exception as exc:
            last_error = exc
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"download failed after retries: {url}: {last_error}")


def sanitize_gltf(raw: bytes, model_name: str) -> tuple[bytes, list[str]]:
    doc = json.loads(raw.decode("utf-8"))
    if doc.get("asset", {}).get("version") != "2.0":
        raise RuntimeError(f"{model_name}: source is not glTF 2.0")

    used_texture_indices = set()
    for material in doc.get("materials", []):
        material.pop("normalTexture", None)
        pbr = material.get("pbrMetallicRoughness", {})
        pbr.pop("metallicRoughnessTexture", None)
        texture = pbr.get("baseColorTexture")
        if texture:
            used_texture_indices.add(int(texture["index"]))

    old_textures = doc.get("textures", [])
    texture_order = sorted(used_texture_indices)
    texture_index_map = {old: new for new, old in enumerate(texture_order)}
    selected_textures = [dict(old_textures[index]) for index in texture_order]

    image_order = sorted({int(texture["source"]) for texture in selected_textures})
    image_index_map = {old: new for new, old in enumerate(image_order)}
    old_images = doc.get("images", [])
    selected_images = [dict(old_images[index]) for index in image_order]

    for texture in selected_textures:
        texture["source"] = image_index_map[int(texture["source"])]

    for material in doc.get("materials", []):
        pbr = material.get("pbrMetallicRoughness", {})
        texture = pbr.get("baseColorTexture")
        if texture:
            texture["index"] = texture_index_map[int(texture["index"])]

    doc["textures"] = selected_textures
    doc["images"] = selected_images
    image_names = [image.get("uri", "") for image in selected_images]
    if any(not name or name.startswith("data:") or "/" in name or "\\" in name for name in image_names):
        raise RuntimeError(f"{model_name}: expected local, flat texture filenames")

    # The selected kit uses one shared sampler; preserve sampler 0 when textures remain.
    if selected_textures:
        doc["samplers"] = doc.get("samplers", [])[:1]
        for texture in selected_textures:
            texture["sampler"] = 0

    for buffer in doc.get("buffers", []):
        if not buffer.get("uri") or "/" in buffer["uri"]:
            raise RuntimeError(f"{model_name}: expected a local .bin buffer")
    if not doc.get("meshes") or not doc.get("nodes"):
        raise RuntimeError(f"{model_name}: missing mesh or node geometry")
    return (json.dumps(doc, separators=(",", ":"), ensure_ascii=False) + "\n").encode("utf-8"), image_names


def optimize_texture(path: Path) -> dict:
    with Image.open(path) as source:
        source.load()
        original_dimensions = source.size
        image = source.copy()
        image.thumbnail((512, 512), Image.Resampling.LANCZOS)
        if image.mode not in ("RGB", "RGBA"):
            image = image.convert("RGBA" if "A" in image.getbands() else "RGB")
        image.save(path, format="PNG", optimize=True, compress_level=9)
        return {
            "original_dimensions": list(original_dimensions),
            "runtime_dimensions": list(image.size),
            "runtime_bytes": path.stat().st_size,
            "runtime_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "mode": image.mode,
        }


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    fetched: dict[str, bytes] = {}
    source_manifest = {}
    for target_relative, (source_relative, expected_size, expected_sha) in SOURCES.items():
        data = download(f"{RAW}/{source_relative}")
        actual_sha = git_blob_sha(data)
        if len(data) != expected_size or actual_sha != expected_sha:
            raise RuntimeError(
                f"pinned source mismatch for {source_relative}: "
                f"size={len(data)}/{expected_size} git_sha={actual_sha}/{expected_sha}"
            )
        fetched[target_relative] = data
        source_manifest[target_relative] = {
            "source_path": source_relative,
            "source_size": len(data),
            "source_git_blob_sha1": actual_sha,
        }

    for target_relative, data in fetched.items():
        if target_relative.endswith(".gltf"):
            continue
        target = DEST / target_relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)

    texture_manifest = {}
    for texture_path in sorted((DEST / "models").glob("*.png")):
        texture_manifest[texture_path.name] = optimize_texture(texture_path)

    model_manifest = {}
    for model_name in MODELS:
        source_relative = f"models/{model_name}.gltf"
        target = DEST / source_relative
        sanitized, texture_names = sanitize_gltf(fetched[source_relative], model_name)
        target.write_bytes(sanitized)
        missing = [name for name in texture_names if not (DEST / "models" / name).is_file()]
        if missing:
            raise RuntimeError(f"{model_name}: missing color textures: {missing}")
        model_manifest[model_name] = {
            "gltf_path": f"world/vale/{source_relative}",
            "buffer": f"world/vale/models/{model_name}.bin",
            "base_color_textures": texture_names,
            "gltf_bytes": len(sanitized),
        }

    manifest = {
        "pack": "Quaternius Medieval Village MegaKit — Standard free subset",
        "pack_author": "Quaternius",
        "source_repository": SOURCE_REPO,
        "source_commit": SOURCE_COMMIT,
        "license": "CC0-1.0",
        "license_file": "world/vale/CC0-1.0.txt",
        "retrieved_on": "2026-11-03",
        "runtime_texture_policy": "Base-color only; non-color PBR maps removed; maximum 512x512.",
        "source_files": source_manifest,
        "runtime_textures": texture_manifest,
        "models": model_manifest,
    }
    (DEST / "cc0-manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )

    total = sum(path.stat().st_size for path in DEST.rglob("*") if path.is_file())
    print(f"Verified {len(MODELS)} CC0 environment models; runtime asset payload={total:,} bytes")
    for name, info in texture_manifest.items():
        print(f"texture {name}: {info['original_dimensions']} -> {info['runtime_dimensions']} ({info['runtime_bytes']:,} bytes)")


if __name__ == "__main__":
    main()
