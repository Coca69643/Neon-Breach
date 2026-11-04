#pragma once

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>

namespace arena_map {

struct Point { float x; float z; };
struct RiverPoint { float x; float z; float halfWidth; };
struct Lane {
    float width;
    std::array<Point, 9> points;
};

inline constexpr float kWorldScale = 1.15f;
inline constexpr float kHalfExtentX = 35.0f;
inline constexpr float kHalfExtentZ = 31.0f;

inline constexpr std::array<Lane, 3> kLanes{{
    {2.42f, {{
        {-14.2f,-31.0f}, {-15.2f,-23.0f}, {-14.6f,-15.0f},
        {-13.4f,-7.0f}, {-13.0f,0.0f}, {-13.7f,8.0f},
        {-14.8f,16.0f}, {-14.2f,24.0f}, {-14.2f,31.0f}
    }}},
    {2.36f, {{
        {0.5f,-31.0f}, {0.1f,-23.0f}, {-0.1f,-15.0f},
        {-0.25f,-7.0f}, {0.5f,0.0f}, {0.3f,8.0f},
        {-0.2f,16.0f}, {0.4f,24.0f}, {0.5f,31.0f}
    }}},
    {2.42f, {{
        {14.2f,-31.0f}, {15.2f,-23.0f}, {14.6f,-15.0f},
        {13.4f,-7.0f}, {13.0f,0.0f}, {13.7f,8.0f},
        {14.8f,16.0f}, {14.2f,24.0f}, {14.2f,31.0f}
    }}}
}};

inline constexpr std::array<RiverPoint, 12> kRiverCenterline{{
    {-34.0f,1.1f,0.78f}, {-28.0f,0.55f,1.15f},
    {-21.0f,0.05f,1.48f}, {-15.0f,-0.45f,1.68f},
    {-9.0f,-0.22f,1.92f}, {-3.0f,0.25f,1.58f},
    {4.0f,0.38f,1.82f}, {10.0f,0.02f,1.95f},
    {16.0f,-0.38f,1.62f}, {23.0f,-0.18f,1.62f},
    {29.0f,0.22f,1.15f}, {34.0f,0.8f,0.78f}
}};

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

inline constexpr std::array<Point, 8> kCampPositions{{
    {-8.2f,-14.5f}, {8.2f,-14.5f}, {-20.2f,-10.0f}, {20.2f,-10.0f},
    {-8.2f,14.5f}, {8.2f,14.5f}, {-20.2f,10.0f}, {20.2f,10.0f}
}};

inline constexpr std::array<Point, 2> kObjectivePositions{{
    {-7.0f,0.2f}, {7.0f,0.2f}
}};
inline constexpr std::array<float, 2> kObjectiveRadii{{4.55f, 4.55f}};

inline constexpr std::array<Point, 12> kGroveCenters{{
    {-25.0f,-19.0f}, {-27.0f,-8.0f}, {-23.0f,8.0f}, {-26.0f,19.0f},
    {25.0f,-19.0f}, {27.0f,-8.0f}, {23.0f,8.0f}, {26.0f,19.0f},
    {-8.5f,-21.0f}, {8.5f,-21.0f}, {-8.5f,21.0f}, {8.5f,21.0f}
}};

inline constexpr std::array<Point, 32> kTreeBlockers{{
    {-10.5f,-23.0f}, {-6.2f,-22.0f}, {-11.5f,-17.5f}, {-5.5f,-17.0f},
    {-10.2f,-10.0f}, {-6.4f,-8.0f}, {10.5f,-23.0f}, {6.2f,-22.0f},
    {11.5f,-17.5f}, {5.5f,-17.0f}, {10.2f,-10.0f}, {6.4f,-8.0f},
    {-22.8f,-18.0f}, {-26.0f,-13.0f}, {-22.4f,-6.0f}, {-18.5f,-20.0f},
    {22.8f,-18.0f}, {26.0f,-13.0f}, {22.4f,-6.0f}, {18.5f,-20.0f},
    {-10.5f,23.0f}, {-6.2f,22.0f}, {-11.5f,17.5f}, {-5.5f,17.0f},
    {-10.2f,10.0f}, {-6.4f,8.0f}, {10.5f,23.0f}, {6.2f,22.0f},
    {11.5f,17.5f}, {5.5f,17.0f}, {10.2f,10.0f}, {6.4f,8.0f}
}};

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

inline float towerZ(int team, int tier) {
    const float z = tier == 0 ? 8.0f : (tier == 1 ? 15.0f : 22.0f);
    return team == 0 ? -z : z;
}

inline Point towerPosition(int team, int lane, int tier) {
    const float z = towerZ(team, tier);
    return {laneCenterX(lane, z), z};
}

} // namespace arena_map
