#pragma once

// Generated from world/arena_world_1_7.json by tools/generate_arena_world_17.py.
// Do not edit manually. Runtime migration to this contract is staged separately.
#include <array>
#include <string_view>

namespace arena_world_17 {
struct Point { float x; float z; };
struct ElevationControl { std::string_view id; Point position; float height; float radius; };
struct Gate { std::string_view id; Point position; };
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
inline constexpr float kHalfWidthM = 90f;
inline constexpr float kHalfDepthM = 80f;
inline constexpr int kTerrainVerticesX = 193;
inline constexpr int kTerrainVerticesZ = 177;
inline constexpr float kMinHeightM = -4f;
inline constexpr float kMaxHeightM = 22f;
inline constexpr float kMaxWalkableSlopeDegrees = 28f;
inline constexpr float kRiverValleyDepthM = 5.5f;
inline constexpr unsigned int kBroadNoiseSeed = 1701;
inline constexpr unsigned int kDetailNoiseSeed = 1702;
inline constexpr float kBroadNoiseAmplitudeM = 2.8f;
inline constexpr float kDetailNoiseAmplitudeM = 0.65f;
inline constexpr std::string_view kArtTheme = "stylized_medieval_fantasy";
inline constexpr std::string_view kEnvironmentStyle = "organic_sculpted_world";

inline constexpr std::array<ElevationControl, 7> kElevationControls{{
    {"southwest_ridge", {-74f, -38f}, 18f, 25f},
    {"northwest_ridge", {-72f, 42f}, 17f, 26f},
    {"southeast_ridge", {74f, -36f}, 20f, 26f},
    {"northeast_ridge", {73f, 42f}, 18.5f, 25f},
    {"west_jungle_highland", {-35f, 8f}, 9f, 28f},
    {"east_jungle_highland", {35f, -8f}, 10f, 28f},
    {"central_river_valley", {0f, 3f}, -3f, 40f}
}};
inline constexpr std::array<Base, 2> kBases{{
    {"blue_base", 0, {0f, -73f}, {{{-57f, -72f}, {0f, -72f}, {57f, -72f}}}},
    {"red_base", 1, {0f, 73f}, {{{-56f, 72f}, {0f, 72f}, {60f, 72f}}}}
}};
inline constexpr std::array<Lane, 3> kLanes{{
    {"west", 9.5f, {{{x.waypoints.map(cPoint).join(", ")}}}},
    {"center", 10f, {{{x.waypoints.map(cPoint).join(", ")}}}},
    {"east", 9.5f, {{{x.waypoints.map(cPoint).join(", ")}}}}
}};
inline constexpr std::array<RiverPoint, 13> kRiver{{
    {{-88f, -4f}, 4.5f},
    {{-72f, -7f}, 5.5f},
    {{-58f, -9f}, 6.5f},
    {{-44f, -6f}, 7.2f},
    {{-30f, -2f}, 8f},
    {{-15f, 2f}, 8.5f},
    {{0f, 4f}, 8f},
    {{15f, 2f}, 8.5f},
    {{30f, -2f}, 8f},
    {{44f, -5f}, 7.2f},
    {{60f, -4f}, 6.5f},
    {{75f, 1f}, 5.5f},
    {{88f, 5f}, 4.5f}
}};
inline constexpr std::array<Crossing, 3> kCrossings{{
    {"west_bridge", "west", {-52f, -8f}, 9.5f, 20f},
    {"center_bridge", "center", {-1.5f, 3.8f}, 10f, 22f},
    {"east_bridge", "east", {61f, -3.7f}, 9.5f, 18f}
}};
inline constexpr std::array<JungleRegion, 2> kJungles{{
    {"west_jungle", {{{x.boundary.map(cPoint).join(", ")}}}},
    {"east_jungle", {{{x.boundary.map(cPoint).join(", ")}}}}
}};
inline constexpr std::array<Camp, 12> kCamps{{
    {"west_camp_01", "west_jungle", {-34f, -38f}, 1},
    {"west_camp_02", "west_jungle", {-26f, -28f}, 1},
    {"west_camp_03", "west_jungle", {-41f, -12f}, 2},
    {"west_camp_04", "west_jungle", {-25f, 12f}, 1},
    {"west_camp_05", "west_jungle", {-35f, 32f}, 2},
    {"west_camp_06", "west_jungle", {-29f, 40f}, 1},
    {"east_camp_01", "east_jungle", {34f, -38f}, 1},
    {"east_camp_02", "east_jungle", {26f, -28f}, 1},
    {"east_camp_03", "east_jungle", {41f, -12f}, 2},
    {"east_camp_04", "east_jungle", {25f, 12f}, 1},
    {"east_camp_05", "east_jungle", {35f, 32f}, 2},
    {"east_camp_06", "east_jungle", {29f, 40f}, 1}
}};
inline constexpr std::array<Objective, 2> kObjectives{{
    {"west_neutral_objective", {-22f, -13f}, 7f},
    {"east_neutral_objective", {22f, 13f}, 7f}
}};
inline constexpr std::array<float, 3> kTowerDepthsFromBase{{
    18f, 38f, 58f
}};
inline constexpr std::array<NavigationNode, 17> kNavigationNodes{{
    {"blue_base", {0f, -73f}},
    {"red_base", {0f, 73f}},
    {"west_south", {-57f, -56f}},
    {"west_bridge", {-52f, -8f}},
    {"west_north", {-58f, 48f}},
    {"center_south", {2f, -56f}},
    {"center_bridge", {-1.5f, 3.8f}},
    {"center_north", {2f, 48f}},
    {"east_south", {56f, -56f}},
    {"east_bridge", {61f, -3.7f}},
    {"east_north", {57f, 48f}},
    {"west_jungle_south", {-34f, -34f}},
    {"west_jungle_north", {-34f, 33f}},
    {"east_jungle_south", {34f, -34f}},
    {"east_jungle_north", {34f, 33f}},
    {"west_objective", {-22f, -13f}},
    {"east_objective", {22f, 13f}}
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
static_assert(kObjectives.size() == 2);
} // namespace arena_world_17
