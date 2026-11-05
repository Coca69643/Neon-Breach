#!/usr/bin/env python3
"""Prepare pinned CC0 MOBA actors and structures from the repository asset pack."""
from __future__ import annotations

import base64
import hashlib
import json
import re
import shutil
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
OUTPUT = ROOT / "assets/match"
KAYKIT_SOURCE = REPO / "app/src/main/assets/world/kaykit"
CHARACTER_SOURCE = REPO / "app/src/main/assets/characters/quaternius-character.glb.b64"
LICENSE_SOURCE = REPO / "ASSETS/KayKit-Medieval-Hexagon-LICENSE.txt"

MODEL_FILES = (
    "tower_blue.gltf",
    "tower_red.gltf",
    "castle_blue.gltf",
    "castle_red.gltf",
    "home_blue.gltf",
    "home_red.gltf",
    "bridge_a.gltf",
)

def glb_json(path: Path) -> dict:
    raw = path.read_bytes()
    if len(raw) < 20:
        raise SystemExit(f"GLB truncated: {path}")
    magic, version, declared, chunk_len, chunk_type = struct.unpack_from("<4sIIII", raw)
    if magic != b"glTF" or version != 2 or declared != len(raw) or chunk_type != 0x4E4F534A:
        raise SystemExit(f"Invalid GLB 2.0 container: {path}")
    return json.loads(raw[20:20 + chunk_len].decode("utf-8").rstrip(" \t\r\n\0"))

def convert_gltf_to_glb(source: Path, target: Path) -> None:
    document = json.loads(source.read_text(encoding="utf-8"))
    buffers = document.get("buffers", [])
    if len(buffers) != 1:
        raise SystemExit(f"Expected one binary buffer in {source.name}")
    buffer_uri = buffers[0].get("uri")
    if not buffer_uri or buffer_uri.startswith("data:"):
        raise SystemExit(f"Expected a pinned external binary buffer in {source.name}")
    binary_path = source.parent / buffer_uri
    if not binary_path.is_file():
        raise SystemExit(f"Missing glTF binary dependency: {binary_path}")
    binary = bytearray(binary_path.read_bytes())

    for image in document.get("images", []):
        uri = image.get("uri")
        if not uri:
            continue
        if uri.startswith("data:"):
            raise SystemExit(f"Unexpected embedded image URI in {source.name}")
        image_path = source.parent / uri
        if not image_path.is_file():
            raise SystemExit(f"Missing glTF image dependency: {image_path}")
        while len(binary) % 4:
            binary.append(0)
        offset = len(binary)
        payload = image_path.read_bytes()
        binary.extend(payload)
        image["bufferView"] = len(document.setdefault("bufferViews", []))
        document["bufferViews"].append({
            "buffer": 0,
            "byteOffset": offset,
            "byteLength": len(payload),
        })
        image["mimeType"] = "image/png"
        image.pop("uri", None)

    document["buffers"] = [{"byteLength": len(binary)}]
    json_payload = json.dumps(
        document, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")
    json_payload += b" " * ((-len(json_payload)) % 4)
    while len(binary) % 4:
        binary.append(0)
    total_size = 12 + 8 + len(json_payload) + 8 + len(binary)
    glb = (
        struct.pack("<4sII", b"glTF", 2, total_size)
        + struct.pack("<II", len(json_payload), 0x4E4F534A)
        + json_payload
        + struct.pack("<II", len(binary), 0x004E4942)
        + binary
    )
    target.write_bytes(glb)
    parsed = glb_json(target)
    if not parsed.get("meshes"):
        raise SystemExit(f"Converted model has no meshes: {target.name}")


def copy_gltf_closure(name: str, copied: set[str]) -> None:
    source = KAYKIT_SOURCE / name
    if not source.is_file():
        raise SystemExit(f"Missing pinned CC0 model: {source}")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    target = OUTPUT / f"{source.stem}.glb"
    convert_gltf_to_glb(source, target)
    copied.add(target.name)

def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    copied: set[str] = set()
    for model in MODEL_FILES:
        copy_gltf_closure(model, copied)

    if not CHARACTER_SOURCE.is_file():
        raise SystemExit(f"Missing pinned Quaternius character source: {CHARACTER_SOURCE}")
    encoded = re.sub(r"\s+", "", CHARACTER_SOURCE.read_text(encoding="ascii"))
    try:
        minion_bytes = base64.b64decode(encoded, validate=True)
    except ValueError as error:
        raise SystemExit(f"Invalid Quaternius base64 source: {error}") from error

    minion_path = OUTPUT / "quaternius_minion.glb"
    minion_path.write_bytes(minion_bytes)
    minion_doc = glb_json(minion_path)

    if not LICENSE_SOURCE.is_file():
        raise SystemExit(f"KayKit CC0 notice missing: {LICENSE_SOURCE}")
    shutil.copy2(LICENSE_SOURCE, OUTPUT / "KAYKIT-CC0-LICENSE.txt")

    manifest = {
        "runtime": "bundled-offline",
        "license": "CC0-1.0",
        "character": {
            "creator": "Quaternius",
            "source": "Legacy Quaternius character GLB from the repository asset pack",
            "file": minion_path.name,
            "sha256": hashlib.sha256(minion_bytes).hexdigest(),
            "animations": [clip.get("name", "") for clip in minion_doc.get("animations", [])],
        },
        "structures": {
            "creator": "Kay Lousberg / KayKit",
            "license": "CC0-1.0",
            "models": sorted(MODEL_FILES),
            "files": sorted(copied),
        },
        "gameplay_policy": "lane-MOBA only; no survival, gathering, or crafting loop",
    }
    manifest_path = OUTPUT / "match-asset-manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    if len(minion_bytes) < 100_000 or not minion_doc.get("meshes"):
        raise SystemExit("Quaternius minion model failed structural validation.")
    if len(copied) != len(MODEL_FILES):
        raise SystemExit("The self-contained CC0 structure set is incomplete.")

    print(
        "Prepared offline MOBA assets: "
        f"{len(copied)} KayKit source files, "
        f"Quaternius minion {len(minion_bytes):,} bytes, "
        f"clips={manifest['character']['animations']}"
    )

if __name__ == "__main__":
    main()
