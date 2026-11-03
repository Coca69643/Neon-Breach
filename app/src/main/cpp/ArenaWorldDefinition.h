#pragma once

#include <array>
#include <cstddef>
#include <cmath>

namespace arena_world {

struct Point {
    float x;
    float z;
};

inline constexpr int kLaneCount = 3;
inline constexpr int kTowerTiers = 3;
inline constexpr float kWorldMeshSize = 76.0f;
inline constexpr int kTerrainGridSteps = 136;

inline constexpr std::array<Point, 12> kRiverControlPoints{{
    {-34.0f, 1.10f}, {-28.0f, 0.55f}, {-21.0f, 0.05f}, {-15.0f, -0.45f},
    {-9.0f, -0.22f}, {-3.0f, 0.25f}, {4.0f, 0.38f}, {10.0f, 0.02f},
    {16.0f, -0.38f}, {23.0f, -0.18f}, {29.0f, 0.22f}, {34.0f, 0.80f}
}};

inline constexpr std::array<Point, 8> kCampPositions{{
    {-8.2f, -14.5f}, {8.2f, -14.5f}, {-20.2f, -10.0f}, {20.2f, -10.0f},
    {-8.2f, 14.5f}, {8.2f, 14.5f}, {-20.2f, 10.0f}, {20.2f, 10.0f}
}};

inline constexpr std::array<Point, 2> kObjectivePositions{{
    {-7.0f, 0.2f}, {7.0f, 0.2f}
}};

inline constexpr std::array<Point, 32> kForestTreePositions{{
    {-10.5f,-23.0f}, {-6.2f,-22.0f}, {-11.5f,-17.5f}, {-5.5f,-17.0f},
    {-10.2f,-10.0f}, {-6.4f,-8.0f}, {10.5f,-23.0f}, {6.2f,-22.0f},
    {11.5f,-17.5f}, {5.5f,-17.0f}, {10.2f,-10.0f}, {6.4f,-8.0f},
    {-22.8f,-18.0f}, {-26.0f,-13.0f}, {-22.4f,-6.0f}, {-18.5f,-20.0f},
    {22.8f,-18.0f}, {26.0f,-13.0f}, {22.4f,-6.0f}, {18.5f,-20.0f},
    {-10.5f,23.0f}, {-6.2f,22.0f}, {-11.5f,17.5f}, {-5.5f,17.0f},
    {-10.2f,10.0f}, {-6.4f,8.0f}, {10.5f,23.0f}, {6.2f,22.0f},
    {11.5f,17.5f}, {5.5f,17.0f}, {10.2f,10.0f}, {6.4f,8.0f}
}};

inline constexpr std::array<Point, 12> kJungleGrovePositions{{
    {-25.0f,-19.0f}, {-27.0f,-8.0f}, {-23.0f,8.0f}, {-26.0f,19.0f},
    {25.0f,-19.0f}, {27.0f,-8.0f}, {23.0f,8.0f}, {26.0f,19.0f},
    {-8.5f,-21.0f}, {8.5f,-21.0f}, {-8.5f,21.0f}, {8.5f,21.0f}
}};

inline constexpr float kWorldRadiusX = 35.0f;
inline constexpr float kWorldRadiusZ = 31.0f;

inline float worldEdgeFactor(float angle) noexcept {
    return 1.0f + 0.035f * std::sin(angle * 5.0f) +
        0.020f * std::sin(angle * 9.0f + 1.4f) +
        0.012f * std::cos(angle * 13.0f);
}

inline float normalizedWorldRadius(float x, float z) noexcept {
    const float nx = x / kWorldRadiusX;
    const float nz = z / kWorldRadiusZ;
    return std::sqrt(nx * nx + nz * nz);
}

inline bool insideIsland(float x, float z) noexcept {
    const float angle = std::atan2(z / kWorldRadiusZ, x / kWorldRadiusX);
    return normalizedWorldRadius(x, z) <= worldEdgeFactor(angle);
}

inline Point undergrowthPosition(int index) noexcept {
    const float base = index % 4 == 0 ? -10.1f :
        (index % 4 == 1 ? -6.1f : (index % 4 == 2 ? 6.1f : 10.1f));
    const float x = base + std::sin(static_cast<float>(index) * 1.71f) * 0.82f;
    const float z = -22.0f + static_cast<float>(index / 4) * 3.15f;
    return {x, z};
}

inline float riverCenterZ(float x) noexcept {
    for (std::size_t i = 0; i + 1 < kRiverControlPoints.size(); ++i) {
        const Point a = kRiverControlPoints[i];
        const Point b = kRiverControlPoints[i + 1];
        if (x <= b.x) {
            const float t = (x - a.x) / (b.x - a.x);
            const float u = t < 0.0f ? 0.0f : (t > 1.0f ? 1.0f : t);
            return a.z + (b.z - a.z) * u;
        }
    }
    return kRiverControlPoints.back().z;
}

inline float terrainHeight(float x, float z) noexcept {
    const float west = 2.35f * std::exp(-((x + 24.0f) * (x + 24.0f)) / 44.0f) *
        (0.58f + 0.42f * std::cos(z * 0.075f));
    const float east = 2.18f * std::exp(-((x - 24.0f) * (x - 24.0f)) / 48.0f) *
        (0.58f + 0.42f * std::cos(z * 0.07f));
    const float south = 1.55f * std::exp(-((z + 27.0f) * (z + 27.0f)) / 36.0f) *
        std::exp(-(x * x) / 420.0f);
    const float north = 1.55f * std::exp(-((z - 27.0f) * (z - 27.0f)) / 36.0f) *
        std::exp(-(x * x) / 420.0f);
    const float ax = std::abs(x);
    const float az = std::abs(z);
    const float knoll = 0.78f * std::exp(-((ax - 8.5f) * (ax - 8.5f)) / 8.5f) *
        std::exp(-((az - 14.0f) * (az - 14.0f)) / 42.0f);
    const float riverDistance = std::abs(z - riverCenterZ(x));
    const float bed = -0.58f * std::exp(-(riverDistance * riverDistance) / 8.5f);
    const float bank = 0.72f * std::exp(-((riverDistance - 2.55f) * (riverDistance - 2.55f)) / 1.9f);
    const float rolling = 0.26f * std::sin(x * 0.18f) * std::cos(z * 0.14f) +
        0.16f * std::sin((x + z) * 0.29f);
    const float shelf = 0.52f * std::exp(-((ax - 18.5f) * (ax - 18.5f)) / 5.5f) *
        std::exp(-((az - 13.0f) * (az - 13.0f)) / 110.0f);
    return rolling + west + east + south + north + knoll + bed + bank + shelf;
}

inline float laneCenterX(int lane, float z) noexcept {
    const float bend = std::sin((z + 4.0f) * 0.105f) * 1.15f;
    if (lane == 0) return -14.2f + bend;
    if (lane == 1) return 0.5f + std::sin(z * 0.12f) * 0.72f;
    return 14.2f - bend * 0.82f;
}

inline float towerZ(int team, int tier) noexcept {
    const float distance = tier == 0 ? 8.0f : (tier == 1 ? 15.0f : 22.0f);
    return team == 0 ? -distance : distance;
}

inline Point towerPosition(int team, int lane, int tier) noexcept {
    const float z = towerZ(team, tier);
    return {laneCenterX(lane, z), z};
}

inline Point corePosition(int team) noexcept {
    return {0.0f, team == 0 ? -27.2f : 27.2f};
}

} // namespace arena_world
