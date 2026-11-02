#!/usr/bin/env python3
"""Static smoke tests for the produced Android APK; does not replace device execution."""
from __future__ import annotations

import base64
import json
import struct
import sys
from pathlib import Path
from zipfile import BadZipFile, ZipFile

JNI_METHODS = (
    "Java_com_duckdream_neonbreach_MainActivity_nativeReset",
    "Java_com_duckdream_neonbreach_MainActivity_nativeSelectHero",
    "Java_com_duckdream_neonbreach_MainActivity_nativeActivateDash",
    "Java_com_duckdream_neonbreach_MainActivity_nativeCastPulse",
    "Java_com_duckdream_neonbreach_MainActivity_nativeActivateShield",
    "Java_com_duckdream_neonbreach_MainActivity_nativeBasicAttack",
    "Java_com_duckdream_neonbreach_MainActivity_nativeStep",
)
ABIS = {
    "arm64-v8a": (2, 183),      # ELF64, EM_AARCH64
    "armeabi-v7a": (1, 40),     # ELF32, EM_ARM
}
FILAMENT_LIBS = (
    "libarena_sim.so",
    "libfilament-jni.so",
    "libfilament-utils-jni.so",
    "libgltfio-jni.so",
)
WORLD_MODELS = (
    "castle_blue", "castle_red", "tower_blue", "tower_red",
    "home_blue", "home_red", "church_blue", "church_red",
    "bridge_a", "trees_a", "flag_blue", "flag_red",
)


def fail(message: str) -> None:
    raise SystemExit("APK smoke test failed: " + message)


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: verify_apk.py path/to/app.apk")
    apk_path = Path(sys.argv[1])
    if not apk_path.is_file() or apk_path.stat().st_size < 8_000_000:
        fail("APK missing or implausibly small")

    try:
        archive = ZipFile(apk_path)
    except BadZipFile as error:
        fail("invalid ZIP/APK archive: " + str(error))

    with archive:
        bad_entry = archive.testzip()
        if bad_entry:
            fail("CRC check failed for " + bad_entry)

        names = archive.namelist()
        name_set = set(names)
        if len(names) != len(name_set):
            fail("archive contains duplicate entry names")
        required = ("AndroidManifest.xml", "resources.arsc", "classes.dex")
        for entry in required:
            if entry not in name_set:
                fail("required APK entry missing: " + entry)
        dex_files = [n for n in names if n.startswith("classes") and n.endswith(".dex")]
        if not dex_files:
            fail("no DEX bytecode found")

        for abi, (expected_class, expected_machine) in ABIS.items():
            for library in FILAMENT_LIBS:
                entry = f"lib/{abi}/{library}"
                if entry not in name_set:
                    fail("native library missing: " + entry)
                data = archive.read(entry)
                if len(data) < 1024 or data[:4] != b"\x7fELF":
                    fail("invalid ELF library: " + entry)
                elf_class = data[4]
                elf_data = data[5]
                if elf_data != 1:
                    fail("expected little-endian ELF: " + entry)
                machine = struct.unpack_from("<H", data, 18)[0]
                if (elf_class, machine) != (expected_class, expected_machine):
                    fail(f"wrong ELF architecture for {entry}: class={elf_class}, machine={machine}")
                if library == "libarena_sim.so":
                    missing_symbols = [symbol for symbol in JNI_METHODS if symbol.encode() not in data]
                    if missing_symbols:
                        fail("JNI exports missing from " + entry + ": " + ", ".join(missing_symbols))

        character_entry = "assets/characters/quaternius-character.glb.b64"
        if character_entry not in name_set:
            fail("rigged character asset is missing")
        character_text = archive.read(character_entry).strip()
        try:
            character_data = base64.b64decode(character_text, validate=True)
        except Exception as error:
            fail("rigged character asset is not valid base64: " + str(error))
        if len(character_data) < 400_000 or character_data[:4] != b"glTF":
            fail("rigged character GLB is invalid or incomplete")

        world_root = "assets/world/kaykit/"
        for model in WORLD_MODELS:
            entry = world_root + model + ".gltf"
            if entry not in name_set:
                fail("required world model missing: " + entry)
            try:
                data = json.loads(archive.read(entry).decode("utf-8"))
            except Exception as error:
                fail("invalid glTF JSON " + entry + ": " + str(error))
            for resource in data.get("buffers", []) + data.get("images", []):
                uri = resource.get("uri")
                if uri and world_root + uri not in name_set:
                    fail(f"glTF resource {uri} required by {model} is missing")
        atlas = world_root + "hexagons_medieval.png"
        if atlas not in name_set or len(archive.read(atlas)) < 1000:
            fail("shared KayKit texture atlas is missing or truncated")

    size_mb = apk_path.stat().st_size / (1024 * 1024)
    print(
        f"APK smoke test passed: {size_mb:.2f} MiB, "
        f"{len(dex_files)} DEX files, 2 Android ABIs, "
        f"{len(FILAMENT_LIBS)} native libraries per ABI, "
        f"{len(WORLD_MODELS)} loaded glTF models, JNI contract intact."
    )


if __name__ == "__main__":
    main()
