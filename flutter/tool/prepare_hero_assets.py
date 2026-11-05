#!/usr/bin/env python3
"""Build the three offline playable hero GLBs from pinned CC0 source assets."""
from __future__ import annotations

import hashlib
import json
import shutil
import struct
import tempfile
import urllib.request
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "app" / "src" / "main" / "assets" / "heroes"
OUTPUT_DIR = ROOT / "flutter" / "assets" / "heroes"
KAIRO_SOURCE_URL = (
    "https://raw.githubusercontent.com/schulerj89/vanta-city/"
    "a3fbd53398d6712742f34170a54cb450c90b1f80/"
    "public/assets/characters/animated-men/nox-layered-shirt.glb"
)
KAIRO_SOURCE_SHA256 = (
    "40c62848350df6d13cc6eed20f30c3406a7761542236d8a9f6c3a4060d005e97"
)
ALLOWED_CLIPS = {
    "HumanArmature|Female_Idle",
    "HumanArmature|Female_Walk",
    "HumanArmature|Female_Run",
    "HumanArmature|Female_SwordSlash",
    "HumanArmature|Female_Punch",
    "HumanArmature|Man_Idle",
    "HumanArmature|Man_Walk",
    "HumanArmature|Man_Run",
    "HumanArmature|Man_SwordSlash",
    "HumanArmature|Man_Punch",
}

KAIRO_PALETTE = {
    "Shirt2": [0.075, 0.23, 0.31, 1.0],
    "Shirt": [0.105, 0.38, 0.43, 1.0],
    "Pants": [0.055, 0.105, 0.16, 1.0],
    "Shoes": [0.035, 0.055, 0.075, 1.0],
    "Socks": [0.24, 0.31, 0.34, 1.0],
}


def decode_glb(raw: bytes) -> tuple[dict[str, Any], list[tuple[int, bytes]]]:
    if len(raw) < 20:
        raise RuntimeError("Hero GLB is truncated.")
    magic, version, declared_length = struct.unpack_from("<4sII", raw, 0)
    if magic != b"glTF" or version != 2 or declared_length != len(raw):
        raise RuntimeError("Hero source is not a valid GLB 2.0 container.")

    chunks: list[tuple[int, bytes]] = []
    offset = 12
    document: dict[str, Any] | None = None
    while offset < len(raw):
        if offset + 8 > len(raw):
            raise RuntimeError("Hero GLB contains a truncated chunk header.")
        length, chunk_type = struct.unpack_from("<II", raw, offset)
        offset += 8
        end = offset + length
        if end > len(raw):
            raise RuntimeError("Hero GLB contains a truncated chunk.")
        chunk = raw[offset:end]
        chunks.append((chunk_type, chunk))
        if chunk_type == 0x4E4F534A:
            document = json.loads(chunk.decode("utf-8").rstrip(" \t\r\n\0"))
        offset = end
    if document is None:
        raise RuntimeError("Hero GLB has no JSON scene chunk.")
    return document, chunks


def encode_glb(document: dict[str, Any], chunks: list[tuple[int, bytes]]) -> bytes:
    json_payload = json.dumps(
        document, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")
    json_payload += b" " * ((-len(json_payload)) % 4)

    output_chunks: list[tuple[int, bytes]] = [(0x4E4F534A, json_payload)]
    output_chunks.extend((kind, payload) for kind, payload in chunks if kind != 0x4E4F534A)
    total_length = 12 + sum(8 + len(payload) for _, payload in output_chunks)
    result = bytearray(struct.pack("<4sII", b"glTF", 2, total_length))
    for kind, payload in output_chunks:
        result.extend(struct.pack("<II", len(payload), kind))
        result.extend(payload)
    return bytes(result)


def fetch_kairo_source(destination: Path) -> None:
    request = urllib.request.Request(
        KAIRO_SOURCE_URL,
        headers={"User-Agent": "DuckDreamStudios-HeroAssetBake/1.0"},
    )
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            if response.status != 200:
                raise RuntimeError(f"Unexpected Kairo source HTTP status: {response.status}")
            payload = response.read()
    except OSError as error:
        raise RuntimeError(f"Could not fetch pinned male Kairo GLB: {error}") from error

    digest = hashlib.sha256(payload).hexdigest()
    if digest != KAIRO_SOURCE_SHA256:
        raise RuntimeError(
            "Pinned Kairo model changed: "
            f"expected {KAIRO_SOURCE_SHA256}, got {digest}"
        )
    decode_glb(payload)
    destination.write_bytes(payload)


def prepare_model(source: Path, destination: Path, *, kairo: bool = False) -> str:
    raw = source.read_bytes()
    document, chunks = decode_glb(raw)
    animations = document.get("animations", [])
    filtered = [
        animation for animation in animations
        if animation.get("name") in ALLOWED_CLIPS
    ]
    required = (
        {"HumanArmature|Man_Idle", "HumanArmature|Man_Walk", "HumanArmature|Man_Run", "HumanArmature|Man_SwordSlash"}
        if source.name == "bastion.glb" or kairo
        else {
            "HumanArmature|Female_Idle",
            "HumanArmature|Female_Walk",
            "HumanArmature|Female_Run",
            "HumanArmature|Female_SwordSlash",
        }
    )
    present = {animation.get("name") for animation in filtered}
    missing = required - present
    if missing:
        raise RuntimeError(f"{source.name} is missing required locomotion/combat clips: {sorted(missing)}")
    if kairo and any(name.startswith("HumanArmature|Female_") for name in present):
        raise RuntimeError("Kairo source must be a male-rig model, not the female Kairo GLB from the legacy branch.")

    document["animations"] = filtered
    if kairo:
        for material in document.get("materials", []):
            factor = KAIRO_PALETTE.get(material.get("name", ""))
            if factor is not None:
                material.setdefault("pbrMetallicRoughness", {})["baseColorFactor"] = factor
        document.setdefault("asset", {})["generator"] = (
            "Duck Dream Studios — Kairo male CC0 palette variant"
        )
        document.setdefault("extras", {})["heroId"] = "kairo"
        document["extras"]["visualRig"] = "male"
        document["extras"]["sourceModel"] = "Quaternius Animated Men Pack / Man-fjHyMd5Wxw (CC0)"

    built = encode_glb(document, chunks)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(built)
    return hashlib.sha256(built).hexdigest()


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, Any] = {
        "license": "CC0-1.0",
        "creator": "Quaternius",
        "runtime": "bundled-offline",
        "generatedBy": "flutter/tool/prepare_hero_assets.py",
        "kairoSource": {
            "repository": "schulerj89/vanta-city",
            "commit": "a3fbd53398d6712742f34170a54cb450c90b1f80",
            "asset": "Quaternius Animated Men Pack / Man-fjHyMd5Wxw",
            "sha256": KAIRO_SOURCE_SHA256,
            "license": "CC0-1.0",
        },
        "models": [],
    }

    with tempfile.TemporaryDirectory(prefix="project-arena-kairo-") as temp_dir:
        kairo_source = Path(temp_dir) / "kairo-source.glb"
        fetch_kairo_source(kairo_source)
        models = [
            ("lyra.glb", "Lyra", "Animated Women Pack / Woman Casual (CC0)", False),
            ("bastion.glb", "Bastion", "Animated Men Pack / Man in Long Sleeves (CC0)", False),
            ("kairo.glb", "Kairo", "Animated Men Pack / Man-fjHyMd5Wxw (CC0)", True),
        ]
        for filename, hero_id, source_name, kairo in models:
            source = kairo_source if kairo else SOURCE_DIR / filename
            destination = OUTPUT_DIR / filename
            digest = prepare_model(source, destination, kairo=kairo)
            manifest["models"].append({
                "id": hero_id,
                "file": filename,
                "source": source_name,
                "sha256": digest,
                "clips": sorted(
                    name for name in ALLOWED_CLIPS
                    if (("Man_" in name) if hero_id != "Lyra" else ("Female_" in name))
                ),
            })
            print(
                f"Prepared {hero_id}: {destination.stat().st_size:,} bytes, "
                f"sha256={digest}"
            )

    (OUTPUT_DIR / "cc0-manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(
        "Prepared 3 offline playable heroes; bundled clips include idle, "
        "walk, run, punch and sword slash."
    )

if __name__ == "__main__":
    main()
