#pragma once

#include "ArenaWorld17Generated.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <string_view>

namespace arena_map {

using Point = arena_world_17::Point;
struct RiverPoint { float x; float z; float halfWidth; };
struct Lane { float width; std::array<Point, 8> points; };

inline constexpr float kWorldScale = 1.0f;
inline constexpr float kHalfExtentX = arena_world_17::kHalfWidthM;
inline constexpr float kHalfExtentZ = arena_world_17::kHalfDepthM;

inline constexpr auto kLanes = [] {
    std::array<Lane, 3> result{};
    for (std::size_t i = 0; i < result.size(); ++i) {
        result[i].width = arena_world_17::kLanes[i].width;
        result[i].points = arena_world_17::kLanes[i].waypoints;
    }
    return result;
}();

inline constexpr auto kRiverCenterline = [] {
    std::array<RiverPoint, arena_world_17::kRiver.size()> result{};
    for (std::size_t i = 0; i < result.size(); ++i) {
        const auto &source = arena_world_17::kRiver[i];
        result[i] = {source.position.x, source.position.z, source.halfWidth};
    }
    return result;
}();

inline constexpr auto kCampPositions = [] {
    std::array<Point, arena_world_17::kCamps.size()> result{};
    for (std::size_t i = 0; i < result.size(); ++i) result[i] = arena_world_17::kCamps[i].position;
    return result;
}();

inline constexpr auto kObjectivePositions = [] {
    std::array<Point, arena_world_17::kObjectives.size()> result{};
    for (std::size_t i = 0; i < result.size(); ++i) result[i] = arena_world_17::kObjectives[i].position;
    return result;
}();

inline constexpr auto kObjectiveRadii = [] {
    std::array<float, arena_world_17::kObjectives.size()> result{};
    for (std::size_t i = 0; i < result.size(); ++i) result[i] = arena_world_17::kObjectives[i].radius;
    return result;
}();

inline constexpr auto kGroveCenters = kCampPositions;

// Four collision trunks around each canonical camp. Their placement is derived, never separately authored.
inline constexpr auto kTreeBlockers = [] {
    constexpr std::array<Point, 4> offsets{{
        {-4.8f, -3.8f}, {4.8f, -3.8f}, {-4.8f, 3.8f}, {4.8f, 3.8f}
    }};
    std::array<Point, arena_world_17::kCamps.size() * offsets.size()> result{};
    for (std::size_t i = 0; i < arena_world_17::kCamps.size(); ++i) {
        const auto center = arena_world_17::kCamps[i].position;
        for (std::size_t j = 0; j < offsets.size(); ++j) {
            result[i * offsets.size() + j] = {center.x + offsets[j].x, center.z + offsets[j].z};
        }
    }
    return result;
}();

inline int riverSegment(float x) {
    if (x <= kRiverCenterline.front().x) return 0;
    for (std::size_t i = 0; i + 1 < kRiverCenterline.size(); ++i) {
        if (x <= kRiverCenterline[i + 1].x) return static_cast<int>(i);
    }
    return static_cast<int>(kRiverCenterline.size()) - 2;
}
inline float riverCenterZ(float x) {
    const int index = riverSegment(x);
    const auto &a = kRiverCenterline[static_cast<std::size_t>(index)];
    const auto &b = kRiverCenterline[static_cast<std::size_t>(index + 1)];
    const float t = std::clamp((x - a.x) / (b.x - a.x), 0.0f, 1.0f);
    return a.z + (b.z - a.z) * t;
}
inline float riverHalfWidth(float x) {
    const int index = riverSegment(x);
    const auto &a = kRiverCenterline[static_cast<std::size_t>(index)];
    const auto &b = kRiverCenterline[static_cast<std::size_t>(index + 1)];
    const float t = std::clamp((x - a.x) / (b.x - a.x), 0.0f, 1.0f);
    return a.halfWidth + (b.halfWidth - a.halfWidth) * t;
}

inline float laneCenterX(int lane, float z) {
    const auto &points = kLanes[static_cast<std::size_t>(std::clamp(lane, 0, 2))].points;
    const float sampleZ = std::clamp(z, points.front().z, points.back().z);
    for (std::size_t i = 0; i + 1 < points.size(); ++i) {
        const Point &a = points[i];
        const Point &b = points[i + 1];
        if (sampleZ <= b.z) {
            const float t = std::clamp((sampleZ - a.z) / (b.z - a.z), 0.0f, 1.0f);
            return a.x + (b.x - a.x) * t;
        }
    }
    return points.back().x;
}

inline Point towerPosition(int team, int lane, int tier) {
    team = std::clamp(team, 0, 1);
    lane = std::clamp(lane, 0, 2);
    tier = std::clamp(tier, 0, 2);
    const auto &base = arena_world_17::kBases[static_cast<std::size_t>(team)];
    const Point gate = base.gates[static_cast<std::size_t>(lane)];
    const auto &route = kLanes[static_cast<std::size_t>(lane)].points;
    const float gateDx = gate.x - base.position.x;
    const float gateDz = gate.z - base.position.z;
    float remaining = arena_world_17::kTowerDepthsFromBase[static_cast<std::size_t>(tier)] -
        std::sqrt(gateDx * gateDx + gateDz * gateDz);
    Point previous = gate;
    for (std::size_t step = 0; step < route.size(); ++step) {
        const Point current = team == 0 ? route[step] : route[route.size() - 1 - step];
        const float dx = current.x - previous.x;
        const float dz = current.z - previous.z;
        const float segment = std::sqrt(dx * dx + dz * dz);
        if (segment > 0.0001f && remaining <= segment) {
            const float t = std::clamp(remaining / segment, 0.0f, 1.0f);
            return {previous.x + dx * t, previous.z + dz * t};
        }
        remaining -= segment;
        previous = current;
    }
    return previous;
}

} // namespace arena_map
