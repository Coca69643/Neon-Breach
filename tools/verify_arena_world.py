#!/usr/bin/env python3
"""Validate the canonical Project Arena 1.7.0 world source without third-party packages."""
from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "world" / "arena_world_1_7.json"

def fail(message: str) -> None:
    raise SystemExit("Arena 1.7.0 world validation failed: " + message)

def point(value: dict, label: str) -> tuple[float, float]:
    try:
        x = float(value["x"])
        z = float(value["z"])
    except (KeyError, TypeError, ValueError):
        fail(label + " must contain numeric x and z coordinates")
    if not math.isfinite(x) or not math.isfinite(z):
        fail(label + " contains non-finite coordinates")
    return x, z

def distance(a: tuple[float, float], b: tuple[float, float]) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])

def in_bounds(p: tuple[float, float], half_width: float, half_depth: float) -> bool:
    return abs(p[0]) <= half_width and abs(p[1]) <= half_depth

def interpolate_z(points: list[dict], x: float) -> tuple[float, float]:
    if x <= float(points[0]["x"]):
        return float(points[0]["z"]), float(points[0]["half_width_m"])
    for left, right in zip(points, points[1:]):
        lx, rx = float(left["x"]), float(right["x"])
        if x <= rx:
            t = max(0.0, min(1.0, (x - lx) / (rx - lx)))
            z = float(left["z"]) + (float(right["z"]) - float(left["z"])) * t
            width = float(left["half_width_m"]) + (
                float(right["half_width_m"]) - float(left["half_width_m"])
            ) * t
            return z, width
    return float(points[-1]["z"]), float(points[-1]["half_width_m"])

def lane_x_at_z(waypoints: list[dict], z: float) -> float:
    if z <= float(waypoints[0]["z"]):
        return float(waypoints[0]["x"])
    for left, right in zip(waypoints, waypoints[1:]):
        lz, rz = float(left["z"]), float(right["z"])
        if z <= rz:
            t = max(0.0, min(1.0, (z - lz) / (rz - lz)))
            return float(left["x"]) + (float(right["x"]) - float(left["x"])) * t
    return float(waypoints[-1]["x"])

def polygon_area(poly: list[tuple[float, float]]) -> float:
    return abs(sum(
        a[0] * b[1] - b[0] * a[1]
        for a, b in zip(poly, poly[1:] + poly[:1])
    )) * 0.5

def point_in_polygon(p: tuple[float, float], poly: list[tuple[float, float]]) -> bool:
    x, z = p
    inside = False
    for a, b in zip(poly, poly[1:] + poly[:1]):
        ax, az = a
        bx, bz = b
        if ((az > z) != (bz > z)):
            crossing_x = (bx - ax) * (z - az) / (bz - az) + ax
            if x < crossing_x:
                inside = not inside
    return inside

def require_unique(items: list[dict], label: str) -> None:
    ids = [item.get("id") for item in items]
    if any(not isinstance(value, str) or not value for value in ids):
        fail(label + " contains an empty or invalid id")
    if len(set(ids)) != len(ids):
        fail(label + " contains duplicate ids")

def main() -> None:
    if not SOURCE.is_file():
        fail("missing world/arena_world_1_7.json")
    try:
        data = json.loads(SOURCE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail("cannot read canonical JSON: " + str(error))

    if data.get("schema_version") != 1 or data.get("world_id") != "project_arena_1_7":
        fail("unsupported schema version or world id")
    if data.get("units") != "meters":
        fail("world coordinates must use meters")
    axes = data.get("coordinate_system", {})
    if axes.get("origin") != "arena_center" or axes.get("north") != "+z":
        fail("coordinate system must use centered origin and +z north")

    bounds = data.get("bounds", {})
    width = float(bounds.get("width_m", 0))
    depth = float(bounds.get("depth_m", 0))
    half_width = float(bounds.get("half_width_m", 0))
    half_depth = float(bounds.get("half_depth_m", 0))
    if width <= 0 or depth <= 0 or abs(width - 2 * half_width) > 0.001 or abs(depth - 2 * half_depth) > 0.001:
        fail("map bounds are inconsistent")
    if abs(width - 180.0) > 0.001 or abs(depth - 160.0) > 0.001:
        fail("initial map target must remain 180 x 160 meters")
    legacy_area = 80.5 * 71.3
    area_ratio = (width * depth) / legacy_area
    if area_ratio < 5.0:
        fail("new map envelope must be at least five times the legacy envelope")

    terrain = data.get("terrain", {})
    resolution = terrain.get("heightfield_vertices", [])
    if len(resolution) != 2 or min(int(v) for v in resolution) < 129:
        fail("heightfield resolution must contain at least 129 vertices per axis")
    if float(terrain.get("height_min_m", 0)) >= float(terrain.get("height_max_m", 0)):
        fail("terrain height range is invalid")
    if not 15.0 <= float(terrain.get("max_walkable_slope_degrees", 0)) <= 35.0:
        fail("walkable slope limit must be bounded for character navigation")

    bases = data.get("bases", [])
    require_unique(bases, "bases")
    if len(bases) != 2 or {int(base.get("team", -1)) for base in bases} != {0, 1}:
        fail("exactly two bases, one per team, are required")
    base_by_team = {int(base["team"]): base for base in bases}
    for base in bases:
        p = point(base.get("position", {}), base["id"])
        if not in_bounds(p, half_width, half_depth):
            fail(base["id"] + " lies outside map bounds")
        gates = base.get("lane_gates", {})
        if set(gates) != {"west", "center", "east"}:
            fail(base["id"] + " must expose gates for all three lanes")
        for gate_name, gate in gates.items():
            if not in_bounds(point(gate, base["id"] + "/" + gate_name), half_width, half_depth):
                fail(base["id"] + " has an out-of-bounds lane gate")

    lanes = data.get("lanes", [])
    require_unique(lanes, "lanes")
    if len(lanes) != 3 or {lane["id"] for lane in lanes} != {"west", "center", "east"}:
        fail("the map must have three named lanes: west, center and east")
    lane_by_id = {lane["id"]: lane for lane in lanes}
    for lane in lanes:
        width_m = float(lane.get("width_m", 0))
        waypoints = lane.get("waypoints", [])
        if not 8.0 <= width_m <= 13.0 or len(waypoints) < 8:
            fail(lane["id"] + " lane needs a substantial width and at least eight authored waypoints")
        previous_z = -float("inf")
        for index, wp in enumerate(waypoints):
            p = point(wp, lane["id"] + "/waypoint")
            if not in_bounds(p, half_width, half_depth):
                fail(lane["id"] + " waypoint is outside the arena")
            if p[1] <= previous_z:
                fail(lane["id"] + " waypoints must progress monotonically from south to north")
            previous_z = p[1]
            if index and distance(p, point(waypoints[index - 1], lane["id"])) < 2.0:
                fail(lane["id"] + " contains redundant waypoints")
        start = point(waypoints[0], lane["id"] + "/start")
        end = point(waypoints[-1], lane["id"] + "/end")
        blue_gate = point(base_by_team[0]["lane_gates"][lane["id"]], "blue gate")
        red_gate = point(base_by_team[1]["lane_gates"][lane["id"]], "red gate")
        if distance(start, blue_gate) > 1.0 or distance(end, red_gate) > 1.0:
            fail(lane["id"] + " does not connect to both base gates")

    lane_x_at_mid = [lane_x_at_z(lane["waypoints"], 0.0) for lane in lanes]
    if min(abs(lane_x_at_mid[i] - lane_x_at_mid[j]) for i in range(3) for j in range(i + 1, 3)) < 25.0:
        fail("lane centerlines are too close; preserve wide rotation space")

    river = data.get("river", {})
    river_points = river.get("centerline", [])
    if len(river_points) < 12:
        fail("river needs at least twelve authored centerline points")
    previous_x = -float("inf")
    widths = []
    for sample in river_points:
        p = point(sample, "river centerline")
        half_water = float(sample.get("half_width_m", 0))
        if p[0] <= previous_x or not in_bounds(p, half_width, half_depth):
            fail("river centerline must be increasing in x and remain inside the arena")
        if not 4.0 <= half_water <= 10.0:
            fail("river width is outside the approved range")
        previous_x = p[0]
        widths.append(half_water)
    if river_points[0]["x"] > -85 or river_points[-1]["x"] < 85 or max(widths) - min(widths) < 2.0:
        fail("river must span the battlefield and vary visibly in width")

    crossings = river.get("crossings", [])
    require_unique(crossings, "river crossings")
    if len(crossings) != 3:
        fail("exactly three designed river crossings are required")
    for crossing in crossings:
        lane_id = crossing.get("lane_id")
        if lane_id not in lane_by_id:
            fail(crossing["id"] + " refers to an unknown lane")
        p = point(crossing.get("position", {}), crossing["id"])
        river_z, river_half = interpolate_z(river_points, p[0])
        if abs(p[1] - river_z) > 1.25:
            fail(crossing["id"] + " does not align with the river centerline")
        lane_x = lane_x_at_z(lane_by_id[lane_id]["waypoints"], p[1])
        if abs(p[0] - lane_x) > 6.0:
            fail(crossing["id"] + " does not join its lane")
        if float(crossing.get("span_m", 0)) < 2.0 * river_half + 3.0:
            fail(crossing["id"] + " span is too short for the river channel")
        if abs(float(crossing.get("deck_width_m", 0)) - float(lane_by_id[lane_id]["width_m"])) > 2.0:
            fail(crossing["id"] + " deck width is inconsistent with the lane")

    jungles = data.get("jungle_regions", [])
    require_unique(jungles, "jungle regions")
    if len(jungles) != 2 or {zone["id"] for zone in jungles} != {"west_jungle", "east_jungle"}:
        fail("exactly two distinct jungle regions are required")
    zone_by_id = {}
    for zone in jungles:
        poly = [point(p, zone["id"] + "/boundary") for p in zone.get("boundary", [])]
        if len(poly) < 8 or polygon_area(poly) < 1000.0:
            fail(zone["id"] + " must have a substantial authored organic boundary")
        if any(not in_bounds(p, half_width, half_depth) for p in poly):
            fail(zone["id"] + " boundary leaves map bounds")
        zone_by_id[zone["id"]] = poly

    camps = data.get("camps", [])
    require_unique(camps, "camps")
    if len(camps) != 12:
        fail("the first layout needs twelve camps, six in each jungle")
    camp_counts = {zone_id: 0 for zone_id in zone_by_id}
    for camp in camps:
        zone_id = camp.get("region_id")
        if zone_id not in zone_by_id:
            fail(camp["id"] + " belongs to an unknown jungle")
        p = point(camp.get("position", {}), camp["id"])
        if not in_bounds(p, half_width, half_depth) or not point_in_polygon(p, zone_by_id[zone_id]):
            fail(camp["id"] + " is not inside its declared jungle")
        if int(camp.get("tier", 0)) not in (1, 2, 3):
            fail(camp["id"] + " has an unsupported tier")
        camp_counts[zone_id] += 1
    if any(count != 6 for count in camp_counts.values()):
        fail("each jungle must contain exactly six initial camps")

    objectives = data.get("objectives", [])
    require_unique(objectives, "objectives")
    if len(objectives) != 2:
        fail("exactly two neutral objectives are required")
    for objective in objectives:
        p = point(objective.get("position", {}), objective["id"])
        if not in_bounds(p, half_width, half_depth):
            fail(objective["id"] + " lies outside map bounds")
        river_z, river_half = interpolate_z(river_points, p[0])
        if abs(p[1] - river_z) < river_half + 1.0:
            fail(objective["id"] + " overlaps the river channel")
        if float(objective.get("radius_m", 0)) < 5.0:
            fail(objective["id"] + " needs enough space for an objective encounter")

    tower_depths = data.get("tower_depths_from_base_m", [])
    if len(tower_depths) != 3 or not (0 < float(tower_depths[0]) < float(tower_depths[1]) < float(tower_depths[2]) < 70):
        fail("three ordered tower tiers are required per lane and team")

    controls = terrain.get("elevation_controls", [])
    require_unique(controls, "elevation controls")
    if len(controls) < 6:
        fail("terrain needs multiple broad elevation anchors")
    for control in controls:
        p = point(control.get("position", {}), control["id"])
        if not in_bounds(p, half_width, half_depth) or float(control.get("radius_m", 0)) < 8.0:
            fail(control["id"] + " has invalid terrain control bounds or radius")

    navigation = data.get("navigation", {})
    nodes = navigation.get("nodes", [])
    require_unique(nodes, "navigation nodes")
    node_ids = {node["id"] for node in nodes}
    if len(nodes) < 15:
        fail("navigation graph needs route, bridge, jungle and objective anchors")
    for node in nodes:
        if not in_bounds(point(node.get("position", {}), node["id"]), half_width, half_depth):
            fail(node["id"] + " navigation anchor lies outside map bounds")
    adjacency = {node_id: set() for node_id in node_ids}
    links = navigation.get("links", [])
    if not links:
        fail("navigation graph has no links")
    seen_links = set()
    for link in links:
        if len(link) != 2 or link[0] not in node_ids or link[1] not in node_ids or link[0] == link[1]:
            fail("navigation link has invalid endpoints")
        edge = tuple(sorted(link))
        if edge in seen_links:
            fail("navigation graph contains duplicate links")
        seen_links.add(edge)
        adjacency[link[0]].add(link[1])
        adjacency[link[1]].add(link[0])
    start = next(iter(node_ids))
    visited = {start}
    stack = [start]
    while stack:
        current = stack.pop()
        for neighbor in adjacency[current] - visited:
            visited.add(neighbor)
            stack.append(neighbor)
    if visited != node_ids:
        fail("navigation graph is disconnected: " + ", ".join(sorted(node_ids - visited)))

    art = data.get("art_direction", {})
    required = {"grass", "soil", "stone", "wood", "river_water", "foliage"}
    if art.get("theme") != "stylized_medieval_fantasy" or art.get("environment_style") != "organic_sculpted_world":
        fail("art direction must describe the approved organic medieval-fantasy world")
    if not required.issubset(set(art.get("required_material_families", []))):
        fail("approved environment material families are incomplete")

    print("Arena 1.7.0 canonical world source validated.")
    print(f"Envelope: {width:.0f} x {depth:.0f} m ({area_ratio:.2f}x legacy area)")
    print(f"Topology: {len(lanes)} lanes, {len(jungles)} jungles, {len(crossings)} crossings, {len(camps)} camps")
    print(f"Navigation: {len(nodes)} nodes, {len(links)} links, fully connected")
    print("This validates map data only; no renderer, physics, gameplay or device test is implied.")

if __name__ == "__main__":
    main()
