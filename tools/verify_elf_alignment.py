#!/usr/bin/env python3
"""Verify 16 KB ELF LOAD-segment and APK ZIP alignment for arm64 Android libraries."""
from __future__ import annotations

import pathlib
import struct
import subprocess
import sys
import tempfile
import zipfile


def fail(message: str) -> None:
    raise SystemExit(f"16 KB compatibility check failed: {message}")


def zip_data_offset(apk: pathlib.Path, info: zipfile.ZipInfo) -> int:
    with apk.open("rb") as stream:
        stream.seek(info.header_offset)
        header = stream.read(30)
    if len(header) != 30 or header[:4] != b"PK\x03\x04":
        fail(f"invalid ZIP local header for {info.filename}")
    name_len, extra_len = struct.unpack_from("<HH", header, 26)
    return info.header_offset + 30 + name_len + extra_len


def verify(apk_name: str) -> None:
    apk = pathlib.Path(apk_name)
    if not apk.is_file():
        fail(f"APK not found: {apk}")
    with zipfile.ZipFile(apk) as archive:
        libraries = [
            item for item in archive.infolist()
            if item.filename.startswith("lib/arm64-v8a/") and item.filename.endswith(".so")
        ]
        if not libraries:
            fail("no arm64-v8a shared libraries were packaged")

        for info in libraries:
            offset = zip_data_offset(apk, info)
            if offset % 16384:
                fail(f"{info.filename} ZIP data offset is {offset}, not 16 KB aligned")
            if info.compress_type != zipfile.ZIP_STORED:
                fail(f"{info.filename} is compressed inside the APK")

            with tempfile.NamedTemporaryFile(prefix="orion9-elf-", suffix=".so") as extracted:
                extracted.write(archive.read(info))
                extracted.flush()
                result = subprocess.run(
                    ["readelf", "-lW", extracted.name],
                    check=True,
                    capture_output=True,
                    text=True,
                )
            load_alignments = []
            for line in result.stdout.splitlines():
                columns = line.split()
                if columns and columns[0] == "LOAD":
                    try:
                        load_alignments.append(int(columns[-1], 0))
                    except ValueError:
                        fail(f"cannot parse LOAD alignment: {line}")
            if not load_alignments:
                fail(f"{info.filename} has no ELF LOAD segments")
            invalid = [value for value in load_alignments if value < 16384 or value % 16384]
            if invalid:
                formatted = ", ".join(hex(value) for value in load_alignments)
                fail(f"{info.filename} LOAD alignments are [{formatted}]")

    print(f"16 KB compatibility OK: {len(libraries)} arm64-v8a library/libraries checked in {apk.name}.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: verify_elf_alignment.py <APK>")
    verify(sys.argv[1])
