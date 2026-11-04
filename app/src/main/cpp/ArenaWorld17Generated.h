#pragma once

// Generated from world/arena_world_1_7.json by tools/generate_arena_world_17.py.
// Do not edit manually. Runtime migration to this contract is staged separately.
#include <array>
#include <string_view>

namespace arena_world_17 {
struct Point { float x; float z; };
struct ElevationControl { std::string_view id; Point position; float height; float radius; };
struct Base { std::string_view id; int team; Point position; std::array<Point, 3> gates; };
struct Lane { std::string_view id; float width; std::array<Point, 8> waypoints; };
struct RiverPoint { Point position; float halfWidth; };
struct Crossing { std::string_view id; std::string_view laneId; Point position; float deckWidth; float span; };
struct JungleRegion { std::string_view id; std::array<Point, 10> boundary; };
struct Camp { std::string_view id; std::string_view regionId; Point position; int tier; };
struct Objective { std::string_view id; Point position; float radius; };
struct NavigationNode { std::string_view id; Point position; };
struct NavigationLink { std::string_view from; std::string_view to; };

inline constexpr std::string_view kWorldId = "project_arena_1_7";
inline constexpr float kHalfWidthM = 90.0f;
inline constexpr float kHalfDepthM = 80.0f;
inline constexpr int kTerrainVerticesX = 193;
inline constexpr int kTerrainVerticesZ = 177;
inline constexpr float kMinHeightM = -4.0f;
inline constexpr float kMaxHeightM = 22.0f;
inline constexpr float kMaxWalkableSlopeDegrees = 28.0f;
inline constexpr float kRiverValleyDepthM = 5.5f;
inline constexpr unsigned int kBroadNoiseSeed = 1701;
inline constexpr unsigned int kDetailNoiseSeed = 1702;
inline constexpr float kBroadNoiseAmplitudeM = 2.8f;
inline constexpr float kDetailNoiseAmplitudeM = 0.65f;
inline constexpr std::string_view kArtTheme = "stylized_medieval_fantasy";
inline constexpr std::string_view kEnvironmentStyle = "organic_sculpted_world";

inline constexpr std::array<ElevationControl, 7> kElevationControls{{
    {"southwest_ridge", Point{-74.0f, -38.0f}, 18.0f, 25.0f},
    {"northwest_ridge", Point{-72.0f, 42.0f}, 17.0f, 26.0f},
    {"southeast_ridge", Point{74.0f, -36.0f}, 20.0f, 26.0f},
    {"northeast_ridge", Point{73.0f, 42.0f}, 18.5f, 25.0f},
    {"west_jungle_highland", Point{-35.0f, 8.0f}, 9.0f, 28.0f},
    {"east_jungle_highland", Point{35.0f, -8.0f}, 10.0f, 28.0f},
    {"central_river_valley", Point{0.0f, 3.0f}, -3.0f, 40.0f}
}};
inline constexpr std::array<Base, 2> kBases{{
    {"blue_base", 0, Point{0.0f, -73.0f}, std::array<Point, 3>{Point{-57.0f, -72.0f}, Point{0.0f, -72.0f}, Point{57.0f, -72.0f}}},
    {"red_base", 1, Point{0.0f, 73.0f}, std::array<Point, 3>{Point{-56.0f, 72.0f}, Point{0.0f, 72.0f}, Point{60.0f, 72.0f}}}
}};
inline constexpr std::array<Lane, 3> kLanes{{
    {"west", 9.5f, std::array<Point, 8>{Point{-57.0f, -72.0f}, Point{-60.0f, -54.0f}, Point{-56.0f, -36.0f}, Point{-51.0f, -16.0f}, Point{-52.0f, 4.0f}, Point{-58.0f, 24.0f}, Point{-60.0f, 48.0f}, Point{-56.0f, 72.0f}}},
    {"center", 10.0f, std::array<Point, 8>{Point{0.0f, -72.0f}, Point{3.0f, -54.0f}, Point{5.0f, -36.0f}, Point{1.0f, -16.0f}, Point{-3.0f, 4.0f}, Point{1.0f, 24.0f}, Point{4.0f, 48.0f}, Point{0.0f, 72.0f}}},
    {"east", 9.5f, std::array<Point, 8>{Point{57.0f, -72.0f}, Point{55.0f, -54.0f}, Point{54.0f, -36.0f}, Point{60.0f, -16.0f}, Point{63.0f, 4.0f}, Point{58.0f, 24.0f}, Point{55.0f, 48.0f}, Point{60.0f, 72.0f}}}
}};
inline constexpr std::array<RiverPoint, 13> kRiver{{
    {Point{-88.0f, -4.0f}, 4.5f},
    {Point{-72.0f, -7.0f}, 5.5f},
    {Point{-58.0f, -9.0f}, 6.5f},
    {Point{-44.0f, -6.0f}, 7.2f},
    {Point{-30.0f, -2.0f}, 8.0f},
    {Point{-15.0f, 2.0f}, 8.5f},
    {Point{0.0f, 4.0f}, 8.0f},
    {Point{15.0f, 2.0f}, 8.5f},
    {Point{30.0f, -2.0f}, 8.0f},
    {Point{44.0f, -5.0f}, 7.2f},
    {Point{60.0f, -4.0f}, 6.5f},
    {Point{75.0f, 1.0f}, 5.5f},
    {Point{88.0f, 5.0f}, 4.5f}
}};
inline constexpr std::array<Crossing, 3> kCrossings{{
    {"west_bridge", "west", Point{-52.0f, -8.0f}, 9.5f, 20.0f},
    {"center_bridge", "center", Point{-1.5f, 3.8f}, 10.0f, 22.0f},
    {"east_bridge", "east", Point{61.0f, -3.7f}, 9.5f, 18.0f}
}};
inline constexpr std::array<JungleRegion, 2> kJungles{{
    {"west_jungle", std::array<Point, 10>{Point{-48.0f, -46.0f}, Point{-22.0f, -52.0f}, Point{-12.0f, -31.0f}, Point{-15.0f, -10.0f}, Point{-12.0f, 12.0f}, Point{-22.0f, 40.0f}, Point{-35.0f, 48.0f}, Point{-49.0f, 40.0f}, Point{-54.0f, 14.0f}, Point{-51.0f, -14.0f}}},
    {"east_jungle", std::array<Point, 10>{Point{48.0f, -46.0f}, Point{22.0f, -52.0f}, Point{12.0f, -31.0f}, Point{15.0f, -10.0f}, Point{12.0f, 12.0f}, Point{22.0f, 40.0f}, Point{35.0f, 48.0f}, Point{49.0f, 40.0f}, Point{54.0f, 14.0f}, Point{51.0f, -14.0f}}}
}};
inline constexpr std::array<Camp, 12> kCamps{{
    {"west_camp_01", "west_jungle", Point{-34.0f, -38.0f}, 1},
    {"west_camp_02", "west_jungle", Point{-26.0f, -28.0f}, 1},
    {"west_camp_03", "west_jungle", Point{-41.0f, -12.0f}, 2},
    {"west_camp_04", "west_jungle", Point{-25.0f, 12.0f}, 1},
    {"west_camp_05", "west_jungle", Point{-35.0f, 32.0f}, 2},
    {"west_camp_06", "west_jungle", Point{-29.0f, 40.0f}, 1},
    {"east_camp_01", "east_jungle", Point{34.0f, -38.0f}, 1},
    {"east_camp_02", "east_jungle", Point{26.0f, -28.0f}, 1},
    {"east_camp_03", "east_jungle", Point{41.0f, -12.0f}, 2},
    {"east_camp_04", "east_jungle", Point{25.0f, 12.0f}, 1},
    {"east_camp_05", "east_jungle", Point{35.0f, 32.0f}, 2},
    {"east_camp_06", "east_jungle", Point{29.0f, 40.0f}, 1}
}};
inline constexpr std::array<Point, 62> kForestTreeAnchors{{
    Point{44.319f, -20.989f},
    Point{-27.794f, 26.761f},
    Point{-33.263f, 9.536f},
    Point{45.81f, 27.675f},
    Point{39.349f, -32.452f},
    Point{-45.033f, -44.196f},
    Point{27.019f, -15.097f},
    Point{20.552f, -38.902f},
    Point{15.589f, -33.729f},
    Point{-33.309f, 20.92f},
    Point{-14.672f, -21.672f},
    Point{26.333f, 27.688f},
    Point{44.824f, 39.719f},
    Point{20.945f, -21.282f},
    Point{45.147f, 33.924f},
    Point{15.114f, -26.21f},
    Point{-21.064f, 33.6f},
    Point{32.691f, -21.08f},
    Point{-20.384f, -44.175f},
    Point{-21.747f, -50.703f},
    Point{38.082f, 39.438f},
    Point{-21.055f, 20.718f},
    Point{44.665f, -38.603f},
    Point{-44.19f, -26.325f},
    Point{-32.471f, -21.592f},
    Point{-26.547f, -39.09f},
    Point{-15.88f, -32.16f},
    Point{-38.742f, 8.398f},
    Point{20.964f, -15.15f},
    Point{-38.606f, -27.434f},
    Point{39.199f, 45.342f},
    Point{38.2f, 14.128f},
    Point{45.25f, 14.945f},
    Point{27.672f, -50.315f},
    Point{50.842f, 8.164f},
    Point{-38.639f, 15.886f},
    Point{21.386f, 33.829f},
    Point{-14.241f, 15.685f},
    Point{-38.801f, -44.658f},
    Point{27.245f, -39.839f},
    Point{33.722f, -14.402f},
    Point{39.461f, -44.79f},
    Point{-21.584f, 26.971f},
    Point{-45.335f, 39.397f},
    Point{-32.886f, -26.928f},
    Point{21.839f, -44.723f},
    Point{-45.624f, 15.596f},
    Point{21.071f, 26.568f},
    Point{-44.908f, 9.859f},
    Point{-45.176f, -38.281f},
    Point{-32.278f, 15.598f},
    Point{33.044f, -27.335f},
    Point{44.353f, 8.291f},
    Point{-38.539f, 45.21f},
    Point{-39.558f, 39.174f},
    Point{-45.681f, 21.011f},
    Point{33.529f, 20.408f},
    Point{-44.853f, -32.076f},
    Point{45.031f, 21.677f},
    Point{27.105f, -21.12f},
    Point{-26.895f, 20.88f},
    Point{39.394f, 26.566f}
}};
inline constexpr std::array<Objective, 2> kObjectives{{
    {"west_neutral_objective", Point{-22.0f, -13.0f}, 7.0f},
    {"east_neutral_objective", Point{22.0f, 13.0f}, 7.0f}
}};
inline constexpr std::array<float, 3> kTowerDepthsFromBase{{18.0f, 38.0f, 58.0f}};
inline constexpr std::array<NavigationNode, 17> kNavigationNodes{{
    {"blue_base", Point{0.0f, -73.0f}},
    {"red_base", Point{0.0f, 73.0f}},
    {"west_south", Point{-57.0f, -56.0f}},
    {"west_bridge", Point{-52.0f, -8.0f}},
    {"west_north", Point{-58.0f, 48.0f}},
    {"center_south", Point{2.0f, -56.0f}},
    {"center_bridge", Point{-1.5f, 3.8f}},
    {"center_north", Point{2.0f, 48.0f}},
    {"east_south", Point{56.0f, -56.0f}},
    {"east_bridge", Point{61.0f, -3.7f}},
    {"east_north", Point{57.0f, 48.0f}},
    {"west_jungle_south", Point{-34.0f, -34.0f}},
    {"west_jungle_north", Point{-34.0f, 33.0f}},
    {"east_jungle_south", Point{34.0f, -34.0f}},
    {"east_jungle_north", Point{34.0f, 33.0f}},
    {"west_objective", Point{-22.0f, -13.0f}},
    {"east_objective", Point{22.0f, 13.0f}}
}};
inline constexpr std::array<NavigationLink, 26> kNavigationLinks{{
    {"blue_base", "west_south"},
    {"blue_base", "center_south"},
    {"blue_base", "east_south"},
    {"red_base", "west_north"},
    {"red_base", "center_north"},
    {"red_base", "east_north"},
    {"west_south", "west_bridge"},
    {"west_bridge", "west_north"},
    {"center_south", "center_bridge"},
    {"center_bridge", "center_north"},
    {"east_south", "east_bridge"},
    {"east_bridge", "east_north"},
    {"west_south", "west_jungle_south"},
    {"center_south", "west_jungle_south"},
    {"west_jungle_south", "west_jungle_north"},
    {"west_jungle_north", "west_north"},
    {"center_north", "west_jungle_north"},
    {"west_jungle_south", "west_objective"},
    {"west_jungle_north", "west_objective"},
    {"east_south", "east_jungle_south"},
    {"center_south", "east_jungle_south"},
    {"east_jungle_south", "east_jungle_north"},
    {"east_jungle_north", "east_north"},
    {"center_north", "east_jungle_north"},
    {"east_jungle_south", "east_objective"},
    {"east_jungle_north", "east_objective"}
}};
static_assert(kLanes.size() == 3);
static_assert(kCrossings.size() == 3);
static_assert(kJungles.size() == 2);
static_assert(kCamps.size() == 12);
static_assert(kForestTreeAnchors.size() == 62);
static_assert(kObjectives.size() == 2);
} // namespace arena_world_17
