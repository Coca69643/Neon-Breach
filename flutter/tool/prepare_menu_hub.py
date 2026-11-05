#!/usr/bin/env python3
"""Bake the original Project Arena floating-tower hub as one offline GLB."""
from __future__ import annotations

import json
import math
import struct
from array import array
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/world/arena_menu_hub.glb"

MATERIALS = {
    "stone":        ([0.48, 0.51, 0.55, 1], 0.0, 0.88, None),
    "stone_light":  ([0.72, 0.70, 0.63, 1], 0.0, 0.82, None),
    "stone_warm":   ([0.67, 0.49, 0.32, 1], 0.0, 0.78, None),
    "stone_dark":   ([0.19, 0.25, 0.31, 1], 0.0, 0.92, None),
    "gold":         ([0.82, 0.58, 0.24, 1], 0.55, 0.32, None),
    "teal":         ([0.09, 0.39, 0.43, 1], 0.15, 0.48, None),
    "grass":        ([0.21, 0.42, 0.28, 1], 0.0, 0.94, None),
    "rock":         ([0.26, 0.31, 0.37, 1], 0.0, 0.96, None),
    "water":        ([0.43, 0.09, 0.33, 1], 0.12, 0.28, None),
    "water_light":  ([0.73, 0.24, 0.54, 1], 0.08, 0.24, None),
    "cloud":        ([0.70, 0.82, 0.92, 1], 0.0, 1.0, None),
    "cloud_shadow": ([0.43, 0.57, 0.72, 1], 0.0, 1.0, None),
    "glow_cyan":    ([0.12, 0.72, 0.88, 1], 0.0, 0.25, [0.08, 0.58, 0.92]),
    "glow_pink":    ([0.84, 0.18, 0.58, 1], 0.0, 0.26, [0.72, 0.05, 0.42]),
    "banner":       ([0.13, 0.37, 0.46, 1], 0.0, 0.74, None),
}

class HubMesh:
    def __init__(self):
        self.groups = {name: [] for name in MATERIALS}

    @staticmethod
    def _sub(a, b):
        return (a[0] - b[0], a[1] - b[1], a[2] - b[2])

    @staticmethod
    def _cross(a, b):
        return (
            a[1] * b[2] - a[2] * b[1],
            a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0],
        )

    @staticmethod
    def _normalize(v):
        length = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
        if length < 1e-9:
            return (0.0, 1.0, 0.0)
        return (v[0] / length, v[1] / length, v[2] / length)

    def triangle(self, material, a, b, c, outward=None):
        normal = self._cross(self._sub(b, a), self._sub(c, a))
        if outward is not None:
            if normal[0] * outward[0] + normal[1] * outward[1] + normal[2] * outward[2] < 0:
                b, c = c, b
                normal = self._cross(self._sub(b, a), self._sub(c, a))
        normal = self._normalize(normal)
        for point in (a, b, c):
            self.groups[material].append((point, normal))

    def quad(self, material, a, b, c, d, outward):
        self.triangle(material, a, b, c, outward)
        self.triangle(material, a, c, d, outward)

    def cylinder(self, cx, cz, y0, y1, r0, r1, material, segments=16, phase=0.0):
        for i in range(segments):
            a = phase + 2 * math.pi * i / segments
            b = phase + 2 * math.pi * (i + 1) / segments
            am = (a + b) * 0.5
            outward = (math.cos(am), 0.0, math.sin(am))
            ba = (cx + math.cos(a) * r0, y0, cz + math.sin(a) * r0)
            bb = (cx + math.cos(b) * r0, y0, cz + math.sin(b) * r0)
            ta = (cx + math.cos(a) * r1, y1, cz + math.sin(a) * r1)
            tb = (cx + math.cos(b) * r1, y1, cz + math.sin(b) * r1)
            self.quad(material, ba, ta, tb, bb, outward)
            if r0 > 0:
                self.triangle(material, (cx, y0, cz), bb, ba, (0, -1, 0))
            if r1 > 0:
                self.triangle(material, (cx, y1, cz), ta, tb, (0, 1, 0))

    def ring_band(self, cx, cz, y0, y1, inner, outer, material, segments=36,
                  start=0.0, end=2 * math.pi):
        steps = max(2, int(segments * (end - start) / (2 * math.pi)))
        for i in range(steps):
            a = start + (end - start) * i / steps
            b = start + (end - start) * (i + 1) / steps
            am = (a + b) * 0.5
            radial = (math.cos(am), 0.0, math.sin(am))
            oa = (cx + outer * math.cos(a), y0, cz + outer * math.sin(a))
            ob = (cx + outer * math.cos(b), y0, cz + outer * math.sin(b))
            ot_a = (oa[0], y1, oa[2])
            ot_b = (ob[0], y1, ob[2])
            ia = (cx + inner * math.cos(a), y0, cz + inner * math.sin(a))
            ib = (cx + inner * math.cos(b), y0, cz + inner * math.sin(b))
            it_a = (ia[0], y1, ia[2])
            it_b = (ib[0], y1, ib[2])
            self.quad(material, oa, ot_a, ot_b, ob, radial)
            self.quad(material, ib, it_b, it_a, ia, (-radial[0], 0, -radial[2]))
            self.quad(material, ot_a, it_a, it_b, ot_b, (0, 1, 0))
            self.quad(material, ia, ib, ob, oa, (0, -1, 0))

    def box(self, cx, cy, cz, sx, sy, sz, material, yaw=0.0):
        right = (math.cos(yaw), 0.0, -math.sin(yaw))
        depth = (math.sin(yaw), 0.0, math.cos(yaw))
        up = (0.0, 1.0, 0.0)
        def p(rx, uy, dz):
            return (
                cx + right[0] * rx + up[0] * uy + depth[0] * dz,
                cy + right[1] * rx + up[1] * uy + depth[1] * dz,
                cz + right[2] * rx + up[2] * uy + depth[2] * dz,
            )
        x, y, z = sx * 0.5, sy * 0.5, sz * 0.5
        self.quad(material, p(-x,-y,z), p(x,-y,z), p(x,y,z), p(-x,y,z), depth)
        self.quad(material, p(x,-y,-z), p(-x,-y,-z), p(-x,y,-z), p(x,y,-z),
                  (-depth[0], 0, -depth[2]))
        self.quad(material, p(x,-y,z), p(x,-y,-z), p(x,y,-z), p(x,y,z), right)
        self.quad(material, p(-x,-y,-z), p(-x,-y,z), p(-x,y,z), p(-x,y,-z),
                  (-right[0], 0, -right[2]))
        self.quad(material, p(-x,y,z), p(x,y,z), p(x,y,-z), p(-x,y,-z), up)
        self.quad(material, p(-x,-y,-z), p(x,-y,-z), p(x,-y,z), p(-x,-y,z),
                  (0, -1, 0))

    def ellipsoid(self, cx, cy, cz, rx, ry, rz, material, rings=8, segments=12,
                  phase=0.0, irregularity=0.0):
        grid = []
        for j in range(rings + 1):
            latitude = -math.pi / 2 + math.pi * j / rings
            row = []
            for i in range(segments + 1):
                longitude = phase + 2 * math.pi * i / segments
                wobble = 1.0 + irregularity * (
                    0.55 * math.sin(longitude * 3.0 + latitude * 2.0)
                    + 0.3 * math.cos(longitude * 5.0 - latitude)
                )
                row.append((
                    cx + rx * math.cos(latitude) * math.cos(longitude) * wobble,
                    cy + ry * math.sin(latitude) * wobble,
                    cz + rz * math.cos(latitude) * math.sin(longitude) * wobble,
                ))
            grid.append(row)
        for j in range(rings):
            for i in range(segments):
                a, b = grid[j][i], grid[j][i + 1]
                c, d = grid[j + 1][i + 1], grid[j + 1][i]
                center = (cx, cy, cz)
                self.quad(material, a, b, c, d, self._normalize(self._sub(
                    ((a[0]+b[0]+c[0]+d[0])/4, (a[1]+b[1]+c[1]+d[1])/4,
                     (a[2]+b[2]+c[2]+d[2])/4), center)))

    def arch_frame(self, cx, y0, cz, width, height, depth, material, segments=9):
        # Two carved jambs and a segmented curved lintel, facing +Z.
        self.box(cx - width * 0.48, y0 + height * 0.5, cz, width * 0.12,
                 height, depth, material)
        self.box(cx + width * 0.48, y0 + height * 0.5, cz, width * 0.12,
                 height, depth, material)
        radius_x = width * 0.42
        radius_y = height * 0.42
        for i in range(segments):
            angle = math.pi * i / segments
            next_angle = math.pi * (i + 1) / segments
            mid = (angle + next_angle) * 0.5
            px = cx + radius_x * math.cos(mid)
            py = y0 + height * 0.58 + radius_y * math.sin(mid)
            self.box(px, py, cz, width * math.pi / segments * 0.9,
                     height * 0.12, depth * 1.12, material, yaw=-(mid - math.pi/2))

def make_hub(mesh: HubMesh):
    # Wide luminous sea and a broken floating island: the hub's foreground.
    mesh.box(0, -2.45, -1, 96, 0.25, 72, "water")
    mesh.ellipsoid(0, -1.35, 0, 14.0, 2.0, 10.9, "rock", rings=9, segments=32,
                   irregularity=0.045)
    mesh.ellipsoid(0, -0.32, 0, 13.0, 0.26, 10.0, "grass", rings=5, segments=32,
                   irregularity=0.025)
    # Pale stone shore plates break the island silhouette.
    for i in range(16):
        a = 2 * math.pi * i / 16
        x, z = 12.1 * math.cos(a), 9.2 * math.sin(a)
        mesh.ellipsoid(x, -0.27, z, 1.1, 0.22, 0.75, "stone_light",
                       rings=4, segments=8, phase=a)

    # Main tower: a stepped vertical landmark, broad at the base, narrow at top.
    mesh.cylinder(0, 0, -0.45, 1.25, 8.6, 7.7, "stone_dark", 16, math.pi/16)
    mesh.ring_band(0, 0, 1.10, 1.65, 7.35, 8.2, "gold", 32)
    mesh.cylinder(0, 0, 1.55, 3.35, 7.4, 6.35, "stone_light", 16, math.pi/16)
    mesh.ring_band(0, 0, 3.1, 3.65, 6.0, 7.25, "stone_warm", 32)
    mesh.ring_band(0, 0, 3.28, 3.48, 6.05, 7.1, "gold", 32)

    # First tower body, tapering slightly between carved balconies.
    mesh.cylinder(0, 0, 3.45, 10.2, 6.0, 5.25, "stone", 16, math.pi/16)
    mesh.ring_band(0, 0, 9.75, 10.55, 5.05, 6.0, "stone_light", 32)
    mesh.ring_band(0, 0, 10.12, 10.34, 5.08, 5.9, "gold", 32)

    # Buttresses and recessed light slits around the lower shaft.
    for i in range(12):
        angle = 2 * math.pi * i / 12 + math.pi/12
        radius = 5.42
        x, z = radius * math.cos(angle), radius * math.sin(angle)
        mesh.box(x, 6.8, z, 0.74, 6.3, 0.92, "stone_light", yaw=-angle)
        mesh.box(x, 6.4, z + 0.02, 0.28, 3.0, 0.98, "glow_cyan", yaw=-angle)
        mesh.box(x, 10.1, z, 0.98, 0.36, 1.1, "gold", yaw=-angle)

    # Second body, ringed balcony and a row of vertical windows.
    mesh.cylinder(0, 0, 10.45, 17.2, 4.95, 4.02, "stone_dark", 16, math.pi/16)
    mesh.ring_band(0, 0, 16.75, 17.5, 3.9, 5.0, "stone_light", 32)
    mesh.ring_band(0, 0, 17.05, 17.28, 3.95, 4.9, "gold", 32)
    for i in range(10):
        angle = 2 * math.pi * i / 10
        x, z = 4.18 * math.cos(angle), 4.18 * math.sin(angle)
        mesh.box(x, 13.75, z, 0.52, 2.2, 0.30, "stone_warm", yaw=-angle)
        mesh.box(x, 13.78, z + 0.035, 0.22, 1.58, 0.32, "glow_pink", yaw=-angle)
        mesh.box(x, 15.05, z + 0.04, 0.56, 0.18, 0.38, "gold", yaw=-angle)

    # Third body and its open colonnade.
    mesh.cylinder(0, 0, 17.4, 23.65, 3.82, 2.92, "stone", 16, math.pi/16)
    mesh.ring_band(0, 0, 23.1, 24.0, 2.82, 4.15, "stone_light", 32)
    mesh.ring_band(0, 0, 23.48, 23.76, 2.87, 4.05, "teal", 32)
    for i in range(10):
        angle = 2 * math.pi * i / 10
        radius = 3.28
        x, z = radius * math.cos(angle), radius * math.sin(angle)
        mesh.cylinder(x, z, 18.0, 22.95, 0.22, 0.16, "stone_warm", 8, angle)
        mesh.cylinder(x, z, 22.7, 23.12, 0.32, 0.24, "gold", 8, angle)
        mesh.ellipsoid(x, 20.5, z, 0.23, 0.18, 0.23, "glow_cyan", 5, 8)

    # Crown spire and a floating segmented halo.
    mesh.cylinder(0, 0, 23.85, 27.0, 3.25, 2.3, "stone_dark", 12, math.pi/12)
    mesh.ring_band(0, 0, 26.55, 27.12, 2.0, 3.9, "gold", 40)
    mesh.ring_band(0, 0, 26.68, 26.98, 2.1, 3.75, "teal", 40)

    # Floating broken outer ring; gaps are intentional.
    ring_arcs = [
        (0.05, 1.35), (1.58, 2.72), (2.92, 4.10), (4.30, 5.40), (5.58, 6.15)
    ]
    for start, end in ring_arcs:
        mesh.ring_band(0, 0, 29.1, 29.65, 4.5, 5.15, "stone_light", 40,
                       start=start, end=end)
        mesh.ring_band(0, 0, 29.17, 29.43, 4.55, 5.18, "gold", 40,
                       start=start, end=end)

    # Portal crown, built from a lit ring of carved stone keystones.
    portal_cy, portal_z = 31.2, -0.2
    for i in range(16):
        angle = 2 * math.pi * i / 16
        x = 2.35 * math.cos(angle)
        y = portal_cy + 3.0 * math.sin(angle)
        yaw = angle
        mesh.box(x, y, portal_z, 0.98, 0.72, 0.7, "stone_warm", yaw=yaw)
        if i % 2 == 0:
            mesh.box(x * 1.04, y, portal_z + 0.36, 0.20, 0.36, 0.16,
                     "glow_pink", yaw=yaw)
    mesh.ellipsoid(0, portal_cy, portal_z - 0.38, 1.92, 2.55, 0.12,
                   "glow_cyan", rings=8, segments=20)

    # The open portal is backed by a deep dark recess and luminous inner arch.
    mesh.ellipsoid(0, 30.9, -0.48, 1.67, 2.30, 0.16, "stone_dark",
                   rings=8, segments=20)
    mesh.ellipsoid(0, 30.9, -0.69, 1.35, 1.98, 0.12, "glow_pink",
                   rings=8, segments=20)

    # A strong ground-level entrance, framed by an original arch.
    mesh.box(0, 1.7, 6.1, 2.0, 3.8, 0.40, "stone_dark")
    mesh.box(0, 1.7, 6.34, 1.25, 2.9, 0.12, "glow_cyan")
    mesh.arch_frame(0, -0.15, 6.36, 3.25, 4.1, 0.74, "stone_light", 9)
    mesh.arch_frame(0, -0.1, 6.52, 2.62, 3.55, 0.22, "gold", 9)

    # Small flags and finials give the skyline a more organic silhouette.
    for side in (-1, 1):
        x = side * 4.2
        z = 1.2
        mesh.cylinder(x, z, 17.2, 20.5, 0.07, 0.05, "gold", 8)
        mesh.box(x - side * 0.62, 19.55, z, 1.15, 1.35, 0.10,
                 "banner", yaw=-side * 0.12)
        mesh.ellipsoid(x, 20.55, z, 0.16, 0.20, 0.16, "gold", 5, 8)

    # Floating stone fragments around the upper halo.
    fragments = [
        (-7.0, 25.5, -1.5, 1.2, 0.8, 0.7),
        (7.5, 27.4, -2.0, 1.0, 0.7, 0.8),
        (-5.9, 31.0, -1.0, 0.8, 1.0, 0.7),
        (6.2, 32.2, -0.8, 1.0, 0.8, 0.9),
        (-8.2, 22.0, 0.0, 0.7, 0.55, 0.6),
        (8.4, 23.2, 0.2, 0.8, 0.6, 0.7),
        (0.0, 34.4, -1.0, 1.15, 0.55, 0.75),
    ]
    for x, y, z, rx, ry, rz in fragments:
        mesh.ellipsoid(x, y, z, rx, ry, rz, "rock", 5, 7,
                       phase=x * 0.23, irregularity=0.24)

    # Distant floating cloud banks: a softer silhouette behind the tower.
    cloud_banks = [
        (-17, 15, -15, 6.5, 1.2, 2.6),
        (-12, 18, -18, 4.2, 1.1, 2.2),
        (16, 16, -17, 6.0, 1.4, 2.8),
        (11, 19, -20, 4.1, 1.0, 2.1),
        (-22, 20, -12, 3.6, 1.0, 1.8),
        (23, 21, -13, 3.7, 1.0, 2.0),
    ]
    for index, (x, y, z, rx, ry, rz) in enumerate(cloud_banks):
        mesh.ellipsoid(x, y - 0.36, z, rx * 0.96, ry * 0.84, rz * 0.96,
                       "cloud_shadow", 5, 9, phase=index * 0.4)
        mesh.ellipsoid(x, y, z, rx, ry, rz, "cloud", 6, 10,
                       phase=index * 0.31)

    # Short, curved water glints at the foot of the island.
    for i in range(9):
        x = -13 + i * 3.25
        z = 11.5 + math.sin(i * 0.72) * 1.2
        mesh.box(x, -2.26, z, 1.35, 0.035, 0.12, "water_light",
                 yaw=math.sin(i * 0.6) * 0.18)

def write_glb(mesh: HubMesh, output: Path):
    binary = bytearray()
    buffer_views = []
    accessors = []
    primitives = []

    def add_view(data: bytes, target: int):
        while len(binary) % 4:
            binary.append(0)
        offset = len(binary)
        binary.extend(data)
        buffer_views.append({
            "buffer": 0, "byteOffset": offset, "byteLength": len(data), "target": target,
        })
        return len(buffer_views) - 1

    for material_index, name in enumerate(MATERIALS):
        vertices = mesh.groups[name]
        if not vertices:
            continue
        positions = [v for point, _ in vertices for v in point]
        normals = [v for _, normal in vertices for v in normal]
        index_count = len(vertices)
        pos_array = array("f", positions)
        nor_array = array("f", normals)
        indices = array("I", range(index_count))
        if struct.pack("=I", 1) != struct.pack("<I", 1):
            pos_array.byteswap()
            nor_array.byteswap()
            indices.byteswap()

        pos_view = add_view(pos_array.tobytes(), 34962)
        nor_view = add_view(nor_array.tobytes(), 34962)
        idx_view = add_view(indices.tobytes(), 34963)

        def accessor(view, component, kind, count, minmax=None):
            result = {
                "bufferView": view,
                "componentType": component,
                "count": count,
                "type": kind,
            }
            if minmax:
                result["min"], result["max"] = minmax
            accessors.append(result)
            return len(accessors) - 1

        xs, ys, zs = positions[0::3], positions[1::3], positions[2::3]
        pa = accessor(pos_view, 5126, "VEC3", index_count,
                      ([min(xs), min(ys), min(zs)], [max(xs), max(ys), max(zs)]))
        na = accessor(nor_view, 5126, "VEC3", index_count)
        ia = accessor(idx_view, 5125, "SCALAR", index_count)
        primitives.append({
            "attributes": {"POSITION": pa, "NORMAL": na},
            "indices": ia,
            "material": material_index,
            "mode": 4,
        })

    materials = []
    for name, (color, metallic, roughness, emissive) in MATERIALS.items():
        material = {
            "name": name,
            "pbrMetallicRoughness": {
                "baseColorFactor": color,
                "metallicFactor": metallic,
                "roughnessFactor": roughness,
            },
            "doubleSided": True,
        }
        if emissive is not None:
            material["emissiveFactor"] = emissive
        materials.append(material)

    document = {
        "asset": {"version": "2.0", "generator": "Duck Dream Studios — original floating hub bake"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": "Project Arena — Bastião do Firmamento", "mesh": 0}],
        "meshes": [{"name": "Stylized tower island and sky fragments", "primitives": primitives}],
        "materials": materials,
        "bufferViews": buffer_views,
        "accessors": accessors,
        "buffers": [{"byteLength": len(binary)}],
        "extras": {
            "purpose": "main_menu_hub",
            "originalAsset": True,
            "dynamicShadows": False,
            "design": "floating fantasy tower, pink sea, broken halo and clouds",
        },
    }

    json_chunk = json.dumps(document, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    json_chunk += b" " * ((-len(json_chunk)) % 4)
    while len(binary) % 4:
        binary.append(0)
    total = 12 + 8 + len(json_chunk) + 8 + len(binary)
    payload = (
        struct.pack("<4sII", b"glTF", 2, total)
        + struct.pack("<II", len(json_chunk), 0x4E4F534A)
        + json_chunk
        + struct.pack("<II", len(binary), 0x004E4942)
        + binary
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(payload)

    magic, version, declared = struct.unpack_from("<4sII", payload, 0)
    if magic != b"glTF" or version != 2 or declared != len(payload):
        raise RuntimeError("Menu hub GLB container validation failed.")
    if len(primitives) < 10 or len(payload) < 100_000:
        raise RuntimeError("Menu hub GLB did not produce the expected scene detail.")
    print(f"Prepared original menu hub: {len(primitives)} material groups, "
          f"{len(payload):,} bytes, {sum(len(v) for v in mesh.groups.values()) // 3:,} triangles.")

def main():
    mesh = HubMesh()
    make_hub(mesh)
    write_glb(mesh, OUTPUT)

if __name__ == "__main__":
    main()
