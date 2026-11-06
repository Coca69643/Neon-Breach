#!/usr/bin/env python3
"""Generate deterministic, tileable terrain albedo and normal maps (no runtime work)."""
from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "app/src/main/assets/world/terrain"
SIZE = 256


def clamp(value: float, low: float = 0.0, high: float = 255.0) -> int:
    return int(max(low, min(high, value)) + 0.5)


def periodic(u: float, v: float, ax: int, ay: int, phase: float = 0.0) -> float:
    return math.sin(2.0 * math.pi * (ax * u + ay * v) + phase)


def png_rgb(width: int, height: int, pixels: bytes) -> bytes:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    rows = b"".join(b"\0" + pixels[y * width * 3:(y + 1) * width * 3] for y in range(height))
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(rows, 9))
        + chunk(b"IEND", b"")
    )


def surface_pixel(kind: str, u: float, v: float) -> tuple[tuple[int, int, int], float]:
    broad = 0.55 * periodic(u, v, 2, 3, 0.27) + 0.30 * periodic(u, v, 5, 2, 1.31)
    mid = 0.48 * periodic(u, v, 13, 9, 0.91) + 0.26 * periodic(u, v, 19, 7, 2.07)
    fine = 0.50 * periodic(u, v, 47, 31, 0.38) + 0.32 * periodic(u, v, 61, 43, 1.82)
    grain = 0.50 * periodic(u, v, 97, 83, 2.24) + 0.35 * periodic(u, v, 113, 71, 0.63)

    if kind == "grass":
        # General city ground: worn concrete, not a grass carpet.
        height = 0.025 * broad + 0.018 * mid + 0.010 * fine + 0.006 * grain
        light = 5.5 * broad + 3.2 * mid + 2.0 * fine + 1.5 * grain
        color = (91 + light, 98 + light, 101 + light)
    elif kind == "moss":
        # Small park pockets remain green; the map is not a forest biome.
        moss = max(0.0, periodic(u, v, 5, 3, 1.9)) ** 4
        height = 0.045 * broad + 0.026 * mid + 0.013 * fine
        light = 6.5 * broad + 3.6 * mid + 2.3 * fine + 4.0 * moss + 1.5 * grain
        color = (48 + light * 0.72, 68 + light, 38 + light * 0.67)
    elif kind == "asphalt":
        # Main avenues and alleys: dark aggregate asphalt.
        pebble = max(0.0, periodic(u, v, 23, 17, 0.7)) ** 12
        height = 0.030 * broad + 0.020 * mid + 0.012 * fine + 0.008 * pebble
        light = 6.0 * broad + 3.6 * mid + 2.0 * fine + 4.0 * pebble + 1.5 * grain
        color = (36 + light, 42 + light, 47 + light)
    elif kind == "concrete":
        # Sidewalks and canal retaining edges: pale poured stone.
        strata = periodic(u, v, 4, 1, 0.8) + 0.38 * periodic(u, v, 9, 2, 1.4)
        seams = max(0.0, periodic(u, v, 8, 8, 0.4)) ** 20
        height = 0.040 * broad + 0.026 * mid + 0.014 * fine + 0.006 * seams
        light = 7.0 * broad + 4.0 * mid + 2.5 * fine + 1.8 * grain + 2.0 * strata
        color = (145 + light, 150 + light, 152 + light)
    else:
        raise ValueError(kind)
    return tuple(clamp(channel) for channel in color), height


def build_maps(kind: str) -> tuple[bytes, bytes]:
    albedo = bytearray(SIZE * SIZE * 3)
    heights = [[0.0] * SIZE for _ in range(SIZE)]
    for y in range(SIZE):
        v = y / SIZE
        for x in range(SIZE):
            u = x / SIZE
            color, height = surface_pixel(kind, u, v)
            offset = (y * SIZE + x) * 3
            albedo[offset:offset + 3] = bytes(color)
            heights[y][x] = height

    normal = bytearray(SIZE * SIZE * 3)
    strength = 5.0 if kind in ("grass", "moss") else 3.8
    for y in range(SIZE):
        yp, ym = (y + 1) % SIZE, (y - 1) % SIZE
        for x in range(SIZE):
            xp, xm = (x + 1) % SIZE, (x - 1) % SIZE
            dx = (heights[y][xp] - heights[y][xm]) * strength
            dz = (heights[yp][x] - heights[ym][x]) * strength
            nx, ny, nz = -dx, 1.0, -dz
            length = math.sqrt(nx * nx + ny * ny + nz * nz)
            offset = (y * SIZE + x) * 3
            normal[offset] = clamp((nx / length * 0.5 + 0.5) * 255.0)
            normal[offset + 1] = clamp((ny / length * 0.5 + 0.5) * 255.0)
            normal[offset + 2] = clamp((nz / length * 0.5 + 0.5) * 255.0)
    return png_rgb(SIZE, SIZE, bytes(albedo)), png_rgb(SIZE, SIZE, bytes(normal))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    total = 0
    for material in ("grass", "moss", "asphalt", "concrete"):
        albedo, normal = build_maps(material)
        for suffix, payload in (("albedo", albedo), ("normal", normal)):
            path = OUT / f"{material}_{suffix}.png"
            path.write_bytes(payload)
            total += len(payload)
    print(f"Generated 8 seamless terrain maps (256x256), {total} bytes total.")


if __name__ == "__main__":
    main()
