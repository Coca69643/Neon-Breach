#!/usr/bin/env python3
"""Generate typed Kotlin and C++ contracts from world/arena_world_1_7.json."""
from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "world/arena_world_1_7.json"
KOTLIN = ROOT / "app/src/main/java/com/duckdream/neonbreach/ArenaWorld17Generated.kt"
CPP = ROOT / "app/src/main/cpp/ArenaWorld17Generated.h"

def q(value):
    return json.dumps(value, ensure_ascii=False)

def number(value):
    rendered = f"{float(value):.3f}".rstrip("0").rstrip(".")
    if "." not in rendered:
        rendered += ".0"
    return rendered + "f"

def kotlin_point(point):
    return f"Point({number(point['x'])}, {number(point['z'])})"

def cpp_point(point):
    return f"Point{{{number(point['x'])}, {number(point['z'])}}}"

def joined(values, render, indent="        "):
    return ",\n".join(indent + render(value) for value in values)

def generate(world):
    f = number
    kp = kotlin_point
    cp = cpp_point
    kotlin = f'''package com.duckdream.neonbreach

/**
 * Generated from world/arena_world_1_7.json by tools/generate_arena_world_17.py.
 * Do not edit manually. Typed 1.7.0 world contract; runtime migration is staged separately.
 */
internal object ArenaWorld17Generated {{
    data class Point(val x: Float, val z: Float)
    data class ElevationControl(val id: String, val position: Point, val height: Float, val radius: Float)
    data class Gate(val id: String, val position: Point)
    data class Base(val id: String, val team: Int, val position: Point, val gates: List<Gate>)
    data class Lane(val id: String, val width: Float, val waypoints: List<Point>)
    data class RiverPoint(val position: Point, val halfWidth: Float)
    data class Crossing(val id: String, val laneId: String, val position: Point, val deckWidth: Float, val span: Float)
    data class JungleRegion(val id: String, val boundary: List<Point>)
    data class Camp(val id: String, val regionId: String, val position: Point, val tier: Int)
    data class Objective(val id: String, val position: Point, val radius: Float)
    data class NavigationNode(val id: String, val position: Point)
    data class NavigationLink(val from: String, val to: String)

    const val WORLD_ID = {q(world["world_id"])}
    const val HALF_WIDTH_M = {f(world["bounds"]["half_width_m"])}
    const val HALF_DEPTH_M = {f(world["bounds"]["half_depth_m"])}
    const val TERRAIN_VERTICES_X = {world["terrain"]["heightfield_vertices"][0]}
    const val TERRAIN_VERTICES_Z = {world["terrain"]["heightfield_vertices"][1]}
    const val MIN_HEIGHT_M = {f(world["terrain"]["height_min_m"])}
    const val MAX_HEIGHT_M = {f(world["terrain"]["height_max_m"])}
    const val MAX_WALKABLE_SLOPE_DEGREES = {f(world["terrain"]["max_walkable_slope_degrees"])}
    const val RIVER_VALLEY_DEPTH_M = {f(world["terrain"]["river_valley_depth_m"])}
    const val BROAD_NOISE_SEED = {world["terrain"]["broad_noise_seed"]}
    const val DETAIL_NOISE_SEED = {world["terrain"]["detail_noise_seed"]}
    const val BROAD_NOISE_AMPLITUDE_M = {f(world["terrain"]["broad_noise_amplitude_m"])}
    const val DETAIL_NOISE_AMPLITUDE_M = {f(world["terrain"]["detail_noise_amplitude_m"])}
    const val ART_THEME = {q(world["art_direction"]["theme"])}
    const val ENVIRONMENT_STYLE = {q(world["art_direction"]["environment_style"])}

    val elevationControls = listOf(
{joined(world["terrain"]["elevation_controls"], lambda x: f"ElevationControl({q(x['id'])}, {kp(x['position'])}, {f(x['height_m'])}, {f(x['radius_m'])})")}
    )
    val bases = listOf(
{joined(world["bases"], lambda x: "Base(" + q(x["id"]) + f", {x['team']}, {kp(x['position'])}, listOf(" + ", ".join(f"Gate({q(key)}, {kp(value)})" for key,value in x["lane_gates"].items()) + "))")}
    )
    val lanes = listOf(
{joined(world["lanes"], lambda x: f"Lane({q(x['id'])}, {f(x['width_m'])}, listOf(" + ", ".join(kp(p) for p in x["waypoints"]) + "))")}
    )
    val river = listOf(
{joined(world["river"]["centerline"], lambda x: f"RiverPoint({kp(x)}, {f(x['half_width_m'])})")}
    )
    val crossings = listOf(
{joined(world["river"]["crossings"], lambda x: f"Crossing({q(x['id'])}, {q(x['lane_id'])}, {kp(x['position'])}, {f(x['deck_width_m'])}, {f(x['span_m'])})")}
    )
    val jungles = listOf(
{joined(world["jungle_regions"], lambda x: f"JungleRegion({q(x['id'])}, listOf(" + ", ".join(kp(p) for p in x["boundary"]) + "))")}
    )
    val camps = listOf(
{joined(world["camps"], lambda x: f"Camp({q(x['id'])}, {q(x['region_id'])}, {kp(x['position'])}, {x['tier']})")}
    )
    val objectives = listOf(
{joined(world["objectives"], lambda x: f"Objective({q(x['id'])}, {kp(x['position'])}, {f(x['radius_m'])})")}
    )
    val towerDepthsFromBase = floatArrayOf({", ".join(f(x) for x in world["tower_depths_from_base_m"])})
    val navigationNodes = listOf(
{joined(world["navigation"]["nodes"], lambda x: f"NavigationNode({q(x['id'])}, {kp(x['position'])})")}
    )
    val navigationLinks = listOf(
{joined(world["navigation"]["links"], lambda x: f"NavigationLink({q(x[0])}, {q(x[1])})")}
    )
}}
'''
    cpp = f'''#pragma once

// Generated from world/arena_world_1_7.json by tools/generate_arena_world_17.py.
// Do not edit manually. Runtime migration to this contract is staged separately.
#include <array>
#include <string_view>

namespace arena_world_17 {{
struct Point {{ float x; float z; }};
struct ElevationControl {{ std::string_view id; Point position; float height; float radius; }};
struct Base {{ std::string_view id; int team; Point position; std::array<Point, 3> gates; }};
struct Lane {{ std::string_view id; float width; std::array<Point, 8> waypoints; }};
struct RiverPoint {{ Point position; float halfWidth; }};
struct Crossing {{ std::string_view id; std::string_view laneId; Point position; float deckWidth; float span; }};
struct JungleRegion {{ std::string_view id; std::array<Point, 10> boundary; }};
struct Camp {{ std::string_view id; std::string_view regionId; Point position; int tier; }};
struct Objective {{ std::string_view id; Point position; float radius; }};
struct NavigationNode {{ std::string_view id; Point position; }};
struct NavigationLink {{ std::string_view from; std::string_view to; }};

inline constexpr std::string_view kWorldId = {q(world["world_id"])};
inline constexpr float kHalfWidthM = {f(world["bounds"]["half_width_m"])};
inline constexpr float kHalfDepthM = {f(world["bounds"]["half_depth_m"])};
inline constexpr int kTerrainVerticesX = {world["terrain"]["heightfield_vertices"][0]};
inline constexpr int kTerrainVerticesZ = {world["terrain"]["heightfield_vertices"][1]};
inline constexpr float kMinHeightM = {f(world["terrain"]["height_min_m"])};
inline constexpr float kMaxHeightM = {f(world["terrain"]["height_max_m"])};
inline constexpr float kMaxWalkableSlopeDegrees = {f(world["terrain"]["max_walkable_slope_degrees"])};
inline constexpr float kRiverValleyDepthM = {f(world["terrain"]["river_valley_depth_m"])};
inline constexpr unsigned int kBroadNoiseSeed = {world["terrain"]["broad_noise_seed"]};
inline constexpr unsigned int kDetailNoiseSeed = {world["terrain"]["detail_noise_seed"]};
inline constexpr float kBroadNoiseAmplitudeM = {f(world["terrain"]["broad_noise_amplitude_m"])};
inline constexpr float kDetailNoiseAmplitudeM = {f(world["terrain"]["detail_noise_amplitude_m"])};
inline constexpr std::string_view kArtTheme = {q(world["art_direction"]["theme"])};
inline constexpr std::string_view kEnvironmentStyle = {q(world["art_direction"]["environment_style"])};

inline constexpr std::array<ElevationControl, {len(world["terrain"]["elevation_controls"])}> kElevationControls{{{{
{joined(world["terrain"]["elevation_controls"], lambda x: "{" + q(x["id"]) + ", " + cp(x["position"]) + ", " + f(x["height_m"]) + ", " + f(x["radius_m"]) + "}", "    ")}
}}}};
inline constexpr std::array<Base, {len(world["bases"])}> kBases{{{{
{joined(world["bases"], lambda x: "{" + q(x["id"]) + f", {x['team']}, " + cp(x["position"]) + ", std::array<Point, 3>{" + ", ".join(cp(v) for v in x["lane_gates"].values()) + "}}", "    ")}
}}}};
inline constexpr std::array<Lane, {len(world["lanes"])}> kLanes{{{{
{joined(world["lanes"], lambda x: "{" + q(x["id"]) + ", " + f(x["width_m"]) + ", std::array<Point, 8>{" + ", ".join(cp(p) for p in x["waypoints"]) + "}}", "    ")}
}}}};
inline constexpr std::array<RiverPoint, {len(world["river"]["centerline"])}> kRiver{{{{
{joined(world["river"]["centerline"], lambda x: "{" + cp(x) + ", " + f(x["half_width_m"]) + "}", "    ")}
}}}};
inline constexpr std::array<Crossing, {len(world["river"]["crossings"])}> kCrossings{{{{
{joined(world["river"]["crossings"], lambda x: "{" + q(x["id"]) + ", " + q(x["lane_id"]) + ", " + cp(x["position"]) + ", " + f(x["deck_width_m"]) + ", " + f(x["span_m"]) + "}", "    ")}
}}}};
inline constexpr std::array<JungleRegion, {len(world["jungle_regions"])}> kJungles{{{{
{joined(world["jungle_regions"], lambda x: "{" + q(x["id"]) + ", std::array<Point, 10>{" + ", ".join(cp(p) for p in x["boundary"]) + "}}", "    ")}
}}}};
inline constexpr std::array<Camp, {len(world["camps"])}> kCamps{{{{
{joined(world["camps"], lambda x: "{" + q(x["id"]) + ", " + q(x["region_id"]) + ", " + cp(x["position"]) + f", {x['tier']}" + "}", "    ")}
}}}};
inline constexpr std::array<Objective, {len(world["objectives"])}> kObjectives{{{{
{joined(world["objectives"], lambda x: "{" + q(x["id"]) + ", " + cp(x["position"]) + ", " + f(x["radius_m"]) + "}", "    ")}
}}}};
inline constexpr std::array<float, {len(world["tower_depths_from_base_m"])}> kTowerDepthsFromBase{{{{{", ".join(f(x) for x in world["tower_depths_from_base_m"])}}}}};
inline constexpr std::array<NavigationNode, {len(world["navigation"]["nodes"])}> kNavigationNodes{{{{
{joined(world["navigation"]["nodes"], lambda x: "{" + q(x["id"]) + ", " + cp(x["position"]) + "}", "    ")}
}}}};
inline constexpr std::array<NavigationLink, {len(world["navigation"]["links"])}> kNavigationLinks{{{{
{joined(world["navigation"]["links"], lambda x: "{" + q(x[0]) + ", " + q(x[1]) + "}", "    ")}
}}}};
static_assert(kLanes.size() == 3);
static_assert(kCrossings.size() == 3);
static_assert(kJungles.size() == 2);
static_assert(kCamps.size() == 12);
static_assert(kObjectives.size() == 2);
}} // namespace arena_world_17
'''
    return kotlin, cpp

def main() -> None:
    world = json.loads(SOURCE.read_text(encoding="utf-8"))
    kotlin, cpp = generate(world)
    KOTLIN.parent.mkdir(parents=True, exist_ok=True)
    CPP.parent.mkdir(parents=True, exist_ok=True)
    KOTLIN.write_text(kotlin, encoding="utf-8")
    CPP.write_text(cpp, encoding="utf-8")

if __name__ == "__main__":
    main()
