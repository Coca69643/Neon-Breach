#!/usr/bin/env python3
"""Bake the original grounded Project Arena civic tower as one offline GLB."""
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
    "glass_blue":   ([0.045, 0.15, 0.22, 1], 0.42, 0.22, None),
    "metal":        ([0.20, 0.27, 0.32, 1], 0.68, 0.38, None),
    "concrete":     ([0.57, 0.60, 0.61, 1], 0.04, 0.88, None),
    "paving_dark":  ([0.18, 0.24, 0.29, 1], 0.12, 0.84, None),
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
    # Grounded civic command tower in a paved urban plaza.
    # The tower is an original architectural landmark, not a floating hub.
    mesh.box(0, -0.28, 0, 72, 0.56, 56, "stone_dark")
    mesh.box(0, 0.02, 0, 68, 0.12, 52, "concrete")
    mesh.box(0, 0.105, 9.5, 34, 0.08, 21, "stone_light")
    mesh.box(0, 0.11, -11.0, 42, 0.08, 17, "paving_dark")

    # A broad stepped foundation makes the tower visibly meet the ground.
    mesh.box(0, 0.42, 0, 25, 0.52, 21, "stone_dark")
    mesh.box(0, 0.78, 0, 22.8, 0.22, 18.8, "stone_light")
    mesh.box(0, 1.05, 0, 19.6, 0.36, 16.0, "stone_warm")

    # Low service wings extend the plaza horizontally.
    for side in (-1, 1):
        x = side * 14.0
        mesh.box(x, 2.1, -1.0, 8.5, 3.4, 12.0, "stone")
        mesh.box(x, 3.92, -1.0, 9.0, 0.26, 12.5, "stone_light")
        for offset in (-3.0, 0.0, 3.0):
            mesh.box(x + offset, 2.5, 5.08, 1.05, 1.55, 0.12, "stone_dark")
            mesh.box(x + offset, 2.5, 5.18, 0.18, 1.82, 0.10, "glass_blue")
            mesh.box(x + offset - 0.78, 2.5, 5.12, 0.10, 1.82, 0.15, "gold")

    # Main podium: wide lower block, recessed windows and a clear front entry.
    mesh.box(0, 3.25, 0, 17.8, 4.2, 14.4, "stone_light")
    mesh.box(0, 5.42, 0, 18.8, 0.28, 15.2, "stone_dark")
    mesh.box(0, 5.62, 0, 18.1, 0.16, 14.7, "stone_warm")
    for x in (-7.0, -4.2, -1.4, 1.4, 4.2, 7.0):
        mesh.box(x, 3.45, 7.27, 1.45, 2.1, 0.10, "stone_dark")
        mesh.box(x, 3.48, 7.34, 1.08, 1.72, 0.08, "glass_blue")
        mesh.box(x - 0.78, 3.45, 7.30, 0.12, 2.25, 0.16, "gold")
        mesh.box(x + 0.78, 3.45, 7.30, 0.12, 2.25, 0.16, "gold")

    # Deep entrance recess with an authored stone frame and restrained signage.
    mesh.box(0, 2.85, 7.30, 3.9, 3.5, 0.16, "stone_dark")
    mesh.box(0, 2.8, 7.42, 2.65, 2.95, 0.10, "glass_blue")
    mesh.arch_frame(0, 1.0, 7.48, 4.8, 4.2, 0.7, "stone_warm", 10)
    mesh.box(0, 5.45, 7.42, 5.2, 0.22, 0.22, "gold")
    mesh.box(0, 4.95, 7.48, 2.15, 0.10, 0.12, "glow_cyan")

    # Vertical command shaft: staggered masses, fins and dark glazing.
    mesh.box(0, 10.5, -0.4, 13.5, 8.8, 11.4, "stone")
    mesh.box(0, 15.05, -0.4, 14.8, 0.32, 12.2, "stone_light")
    mesh.box(0, 15.32, -0.4, 13.9, 0.16, 11.7, "gold")
    for side in (-1, 1):
        x = side * 6.2
        mesh.box(x, 10.6, 5.35, 0.78, 8.2, 0.46, "metal")
        mesh.box(x - side * 0.12, 10.6, 5.62, 0.16, 6.8, 0.12, "glow_cyan")
    for y in (8.2, 10.3, 12.4):
        for x in (-3.9, -1.3, 1.3, 3.9):
            mesh.box(x, y, 5.36, 1.58, 1.45, 0.12, "stone_dark")
            mesh.box(x, y, 5.44, 1.18, 1.08, 0.08, "glass_blue")

    # Upper observation level is offset and slimmer, with a clear roof edge.
    mesh.box(0.7, 19.0, -0.8, 9.8, 7.1, 8.8, "stone_dark")
    mesh.box(0.7, 22.65, -0.8, 10.7, 0.34, 9.6, "stone_light")
    mesh.box(0.7, 22.92, -0.8, 10.0, 0.16, 9.0, "gold")
    for x in (-3.0, -0.5, 2.0, 4.5):
        mesh.box(x, 19.15, 3.68, 1.15, 3.85, 0.12, "glass_blue")
        mesh.box(x - 0.68, 19.15, 3.62, 0.10, 4.1, 0.16, "metal")
        mesh.box(x + 0.68, 19.15, 3.62, 0.10, 4.1, 0.16, "metal")

    # Rooftop communications mast and compact service equipment.
    mesh.box(0.7, 24.6, -0.8, 3.2, 3.0, 3.2, "stone")
    mesh.cylinder(0.7, -0.8, 26.0, 31.2, 0.18, 0.10, "gold", 10)
    mesh.box(0.7, 29.4, -0.8, 4.4, 0.16, 0.16, "stone_warm")
    mesh.box(0.7, 30.3, -0.8, 2.6, 0.12, 0.12, "glow_cyan")
    mesh.box(0.7, 31.0, -0.8, 0.12, 0.9, 0.12, "gold")
    for side in (-1, 1):
        mesh.box(0.7 + side * 2.5, 25.0, -0.8, 0.14, 2.0, 0.14, "stone_warm")

    # Ground-level plaza details: benches, planters and lamps anchor the scale.
    for side in (-1, 1):
        for z in (-13.0, 13.0):
            x = side * 23.0
            mesh.box(x, 0.75, z, 5.0, 0.22, 1.35, "stone_warm")
            mesh.box(x, 1.05, z, 4.6, 0.42, 0.9, "stone_dark")
            mesh.box(x, 0.55, z + side * 4.0, 3.7, 0.9, 2.0, "stone")
            for dx in (-1.0, 0.0, 1.0):
                mesh.ellipsoid(x + dx, 1.2, z + side * 4.0,
                               0.62, 0.82, 0.62, "grass", 5, 7,
                               phase=dx * 0.5)
        lamp_x = side * 29.0
        for z in (-8.0, 8.0):
            mesh.cylinder(lamp_x, z, 0.0, 5.4, 0.11, 0.08, "stone_dark", 8)
            mesh.box(lamp_x, 5.35, z, 0.9, 0.22, 0.9, "glow_cyan")
            mesh.box(lamp_x, 5.58, z, 1.2, 0.10, 1.2, "stone_warm")

    # Short paving strips lead into the entrance; all geometry rests on the plaza.
    for x in (-6.0, -3.0, 0.0, 3.0, 6.0):
        mesh.box(x, 0.18, 13.2, 1.8, 0.06, 8.0, "paving_dark")
    mesh.box(0, 0.19, 18.2, 18.0, 0.08, 1.2, "concrete")



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
        "asset": {"version": "2.0", "generator": "Duck Dream Studios — grounded civic tower bake"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": "Project Arena — Civic Command Tower", "mesh": 0}],
        "meshes": [{"name": "Grounded civic tower and public plaza", "primitives": primitives}],
        "materials": materials,
        "bufferViews": buffer_views,
        "accessors": accessors,
        "buffers": [{"byteLength": len(binary)}],
        "extras": {
            "purpose": "main_menu_hub",
            "originalAsset": True,
            "dynamicShadows": False,
            "design": "grounded urban command tower with stepped concrete volumes, vertical glazing, plaza, service wings and communications mast",
            "floatingGeometry": False,
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
