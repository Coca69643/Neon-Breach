#!/usr/bin/env python3
"""Fail the CI build if the APK identity, platform metadata, or scene assets drift."""
from __future__ import annotations

import hashlib
import struct
import sys
import zipfile
from pathlib import Path

NO_INDEX = 0xFFFFFFFF
TYPE_STRING = 0x03
TYPE_INT_DEC = 0x10
TYPE_INT_HEX = 0x11
TYPE_INT_BOOLEAN = 0x12


def read_length8(data: bytes, offset: int) -> tuple[int, int]:
    first = data[offset]
    if first & 0x80:
        return ((first & 0x7F) << 8) | data[offset + 1], offset + 2
    return first, offset + 1


def read_length16(data: bytes, offset: int) -> tuple[int, int]:
    value = struct.unpack_from("<H", data, offset)[0]
    if value & 0x8000:
        tail = struct.unpack_from("<H", data, offset + 2)[0]
        return ((value & 0x7FFF) << 16) | tail, offset + 4
    return value, offset + 2


def parse_string_pool(data: bytes, chunk_start: int) -> list[str]:
    _, header_size, chunk_size, count, _, flags, strings_start, _ = (
        struct.unpack_from("<HHIIIIII", data, chunk_start)
    )
    if header_size < 28 or chunk_start + chunk_size > len(data):
        raise ValueError("Invalid Android XML string pool.")

    offsets_start = chunk_start + header_size
    strings_base = chunk_start + strings_start
    utf8 = bool(flags & 0x100)
    strings: list[str] = []

    for index in range(count):
        relative = struct.unpack_from("<I", data, offsets_start + index * 4)[0]
        cursor = strings_base + relative
        if utf8:
            _, cursor = read_length8(data, cursor)  # UTF-16 code-unit count.
            byte_count, cursor = read_length8(data, cursor)
            raw = data[cursor:cursor + byte_count]
            strings.append(raw.decode("utf-8", "replace"))
        else:
            char_count, cursor = read_length16(data, cursor)
            raw = data[cursor:cursor + char_count * 2]
            strings.append(raw.decode("utf-16le", "replace"))
    return strings


def typed_value(data: bytes, offset: int, strings: list[str]) -> object:
    _, _, value_type, value_data = struct.unpack_from("<HBBI", data, offset)
    if value_type == TYPE_STRING:
        return strings[value_data]
    if value_type in (TYPE_INT_DEC, TYPE_INT_HEX):
        return value_data
    if value_type == TYPE_INT_BOOLEAN:
        return bool(value_data)
    return value_data


def parse_manifest(data: bytes) -> list[tuple[str, dict[str, object]]]:
    if len(data) < 8:
        raise ValueError("AndroidManifest.xml is truncated.")
    xml_type, _, declared_size = struct.unpack_from("<HHI", data, 0)
    if xml_type != 0x0003 or declared_size != len(data):
        raise ValueError("APK manifest is not a valid binary Android XML document.")

    strings: list[str] = []
    elements: list[tuple[str, dict[str, object]]] = []
    cursor = 8

    while cursor + 8 <= len(data):
        chunk_type, header_size, chunk_size = struct.unpack_from(
            "<HHI", data, cursor
        )
        if chunk_size < 8 or cursor + chunk_size > len(data):
            raise ValueError("Malformed Android XML chunk.")

        if chunk_type == 0x0001:  # RES_STRING_POOL_TYPE
            strings = parse_string_pool(data, cursor)

        elif chunk_type == 0x0102:  # RES_XML_START_ELEMENT_TYPE
            if not strings:
                raise ValueError("Android XML element appeared before its string pool.")
            namespace_index, name_index = struct.unpack_from("<II", data, cursor + 16)
            attribute_start, attribute_size, attribute_count = struct.unpack_from(
                "<HHH", data, cursor + 24
            )
            if name_index >= len(strings) or attribute_size < 20:
                raise ValueError("Malformed Android XML element header.")

            tag = strings[name_index]
            attributes: dict[str, object] = {}
            first_attribute = cursor + 16 + attribute_start

            for index in range(attribute_count):
                attribute = first_attribute + index * attribute_size
                _, name_index, raw_index = struct.unpack_from("<III", data, attribute)
                if name_index >= len(strings):
                    raise ValueError("Android XML attribute name is outside the string pool.")
                if raw_index != NO_INDEX:
                    if raw_index >= len(strings):
                        raise ValueError("Android XML raw value is outside the string pool.")
                    value: object = strings[raw_index]
                else:
                    value = typed_value(data, attribute + 12, strings)
                attributes[strings[name_index]] = value

            elements.append((tag, attributes))

        cursor += chunk_size

    return elements


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"APK validation failed: {message}")


def main() -> None:
    apk = Path(sys.argv[1]) if len(sys.argv) > 1 else (
        Path("build/app/outputs/flutter-apk/app-release.apk")
    )
    require(apk.is_file() and apk.stat().st_size > 0, f"APK not found: {apk}")

    try:
        with zipfile.ZipFile(apk) as archive:
            names = set(archive.namelist())
            elements = parse_manifest(archive.read("AndroidManifest.xml"))
    except (OSError, zipfile.BadZipFile, KeyError, ValueError) as error:
        raise SystemExit(f"APK validation failed: cannot inspect archive: {error}") from error

    manifest = next((attrs for tag, attrs in elements if tag == "manifest"), {})
    application = next((attrs for tag, attrs in elements if tag == "application"), {})
    uses_sdk = next((attrs for tag, attrs in elements if tag == "uses-sdk"), {})
    activities = [attrs for tag, attrs in elements if tag == "activity"]
    metadata = [attrs for tag, attrs in elements if tag == "meta-data"]

    require(manifest.get("package") == "com.duckdream.projectarena",
            f"unexpected applicationId: {manifest.get('package')!r}")
    require(manifest.get("versionName") == "1.7.2",
            f"unexpected versionName: {manifest.get('versionName')!r}")
    version_code = manifest.get("versionCode")
    require(isinstance(version_code, int) and version_code > 62,
            f"versionCode must be greater than 61, got {version_code!r}")
    require(application.get("label") == "Projeto Arena",
            f"unexpected launcher label: {application.get('label')!r}")

    min_sdk = uses_sdk.get("minSdkVersion")
    require(isinstance(min_sdk, int) and min_sdk >= 24,
            f"Flutter 3.47 requires minSdk 24 or newer, got {min_sdk!r}")

    landscape = [
        item for item in activities
        if str(item.get("name", "")).endswith("MainActivity")
    ]
    require(len(landscape) == 1 and landscape[0].get("screenOrientation") == 0,
            "MainActivity must be locked to landscape.")

    gpu_enabled = any(
        item.get("name") == "io.flutter.embedding.android.EnableFlutterGPU"
        and item.get("value") is True
        for item in metadata
    )
    require(gpu_enabled, "Flutter GPU is not enabled in the merged Android manifest.")

    expected_raw_assets = (
        "assets/flutter_assets/assets/heroes/lyra.glb",
        "assets/flutter_assets/assets/heroes/bastion.glb",
        "assets/flutter_assets/assets/heroes/kairo.glb",
        "assets/flutter_assets/assets/world/arena_terrain.glb",
        "assets/flutter_assets/assets/world/arena_menu_hub.glb",
    )
    for asset in expected_raw_assets:
        require(asset in names, f"required runtime asset is missing: {asset}")

    compiled_scenes = (
        "lyra", "bastion", "kairo", "arena_terrain",
        "tree_oak", "tree_pine", "tree_broadleaf", "bush_common",
        "arena_menu_hub",
    )
    for scene in compiled_scenes:
        prefix = f"assets/flutter_assets/flutter_scene_generated/scene.{scene}."
        require(any(name.startswith(prefix) and name.endswith(".fsceneb") for name in names),
                f"preprocessed Flutter Scene asset is missing: {scene}")

    native_libraries = [name for name in names if name.startswith("lib/") and name.endswith(".so")]
    abis = {name.split("/")[1] for name in native_libraries if len(name.split("/")) > 2}
    require(abis == {"arm64-v8a"}, f"expected an ARM64-only APK, got ABIs: {sorted(abis)}")
    require("lib/arm64-v8a/libapp.so" in names and
            "lib/arm64-v8a/libflutter.so" in names,
            "ARM64 Flutter runtime libraries are incomplete.")

    digest = hashlib.sha256(apk.read_bytes()).hexdigest()
    size_mib = apk.stat().st_size / (1024 * 1024)
    print(
        "APK verified: "
        f"package=com.duckdream.projectarena, "
        f"version=0.17.2+{version_code}, minSdk={min_sdk}, "
        f"orientation=landscape, ABI=arm64-v8a, "
        f"size={size_mib:.2f} MiB, sha256={digest}"
    )


if __name__ == "__main__":
    main()
