#pragma once

#include "ArenaMapDefinition.h"

#include <array>
#include <cmath>
#include <limits>

namespace arena_navigation {

struct Vec2 { float x; float z; };

inline constexpr int kLaneNodeCount = 27;
inline constexpr int kCampNodeStart = kLaneNodeCount;
inline constexpr int kObjectiveNodeStart = kCampNodeStart + 8;
inline constexpr int kBaseNodeStart = kObjectiveNodeStart + 2;
inline constexpr int kNodeCount = kBaseNodeStart + 2;
inline constexpr int kMaxNeighbors = 8;

struct Node {
    Vec2 position{};
    std::array<int, kMaxNeighbors> neighbors{};
    int neighborCount = 0;
};

struct Graph {
    std::array<Node, kNodeCount> nodes{};
};

inline float distanceSquared(Vec2 a, Vec2 b) {
    const float dx = a.x - b.x;
    const float dz = a.z - b.z;
    return dx * dx + dz * dz;
}

inline void connect(Graph &graph, int a, int b) {
    if (a == b || a < 0 || b < 0 || a >= kNodeCount || b >= kNodeCount) return;
    auto add = [](Node &node, int other) {
        for (int i = 0; i < node.neighborCount; ++i) {
            if (node.neighbors[static_cast<std::size_t>(i)] == other) return;
        }
        if (node.neighborCount < kMaxNeighbors) {
            node.neighbors[static_cast<std::size_t>(node.neighborCount++)] = other;
        }
    };
    add(graph.nodes[static_cast<std::size_t>(a)], b);
    add(graph.nodes[static_cast<std::size_t>(b)], a);
}

inline int nearestNode(const Graph &graph, Vec2 position) {
    int best = 0;
    float bestDistance = std::numeric_limits<float>::max();
    for (int i = 0; i < kNodeCount; ++i) {
        const float d = distanceSquared(position, graph.nodes[static_cast<std::size_t>(i)].position);
        if (d < bestDistance) {
            bestDistance = d;
            best = i;
        }
    }
    return best;
}

inline Graph buildGraph() {
    Graph graph{};
    const float scale = arena_map::kWorldScale;

    // Each lane follows its nine authored points, including its own river bridge.
    for (int lane = 0; lane < 3; ++lane) {
        const auto &points = arena_map::kLanes[static_cast<std::size_t>(lane)].points;
        for (int point = 0; point < 9; ++point) {
            const auto &source = points[static_cast<std::size_t>(point)];
            const int index = lane * 9 + point;
            graph.nodes[static_cast<std::size_t>(index)].position = {source.x * scale, source.z * scale};
            if (point > 0) connect(graph, index - 1, index);
        }
    }

    auto connectToNearestTwoLaneNodes = [&graph](int landmarkNode, Vec2 position) {
        int first = -1;
        int second = -1;
        float firstDistance = std::numeric_limits<float>::max();
        float secondDistance = std::numeric_limits<float>::max();
        for (int laneNode = 0; laneNode < kLaneNodeCount; ++laneNode) {
            const float d = distanceSquared(position, graph.nodes[static_cast<std::size_t>(laneNode)].position);
            if (d < firstDistance) {
                second = first;
                secondDistance = firstDistance;
                first = laneNode;
                firstDistance = d;
            } else if (d < secondDistance) {
                second = laneNode;
                secondDistance = d;
            }
        }
        connect(graph, landmarkNode, first);
        connect(graph, landmarkNode, second);
    };

    for (std::size_t i = 0; i < arena_map::kCampPositions.size(); ++i) {
        const auto &camp = arena_map::kCampPositions[i];
        const Vec2 position{camp.x * scale, camp.z * scale};
        const int node = kCampNodeStart + static_cast<int>(i);
        graph.nodes[static_cast<std::size_t>(node)].position = position;
        connectToNearestTwoLaneNodes(node, position);
    }

    // Direct paths across each jungle quadrant create rotations around the river.
    constexpr std::array<std::array<int, 2>, 4> campLinks{{
        {{0, 2}}, {{1, 3}}, {{4, 6}}, {{5, 7}}
    }};
    for (const auto &link : campLinks) {
        connect(graph, kCampNodeStart + link[0], kCampNodeStart + link[1]);
    }

    // Neutral objectives connect adjacent lanes without inventing a straight river shortcut.
    for (std::size_t i = 0; i < arena_map::kObjectivePositions.size(); ++i) {
        const auto &objective = arena_map::kObjectivePositions[i];
        const Vec2 position{objective.x * scale, objective.z * scale};
        const int node = kObjectiveNodeStart + static_cast<int>(i);
        graph.nodes[static_cast<std::size_t>(node)].position = position;
        connectToNearestTwoLaneNodes(node, position);
    }

    for (int team = 0; team < 2; ++team) {
        const float z = (team == 0 ? -27.2f : 27.2f) * scale;
        const int coreNode = kBaseNodeStart + team;
        graph.nodes[static_cast<std::size_t>(coreNode)].position = {0.0f, z};
        const int endpoint = team == 0 ? 0 : 8;
        for (int lane = 0; lane < 3; ++lane) {
            connect(graph, coreNode, lane * 9 + endpoint);
        }
    }

    return graph;
}

inline const Graph &mapGraph() {
    static const Graph graph = buildGraph();
    return graph;
}

inline Vec2 nextWaypoint(Vec2 current, Vec2 destination) {
    if (distanceSquared(current, destination) <= 6.25f) return destination;

    const Graph &graph = mapGraph();
    const int start = nearestNode(graph, current);
    const int goal = nearestNode(graph, destination);
    if (start == goal) return destination;

    std::array<float, kNodeCount> costs{};
    std::array<int, kNodeCount> previous{};
    std::array<bool, kNodeCount> visited{};
    costs.fill(std::numeric_limits<float>::max());
    previous.fill(-1);
    costs[static_cast<std::size_t>(start)] = 0.0f;

    for (int iteration = 0; iteration < kNodeCount; ++iteration) {
        int currentNode = -1;
        float bestCost = std::numeric_limits<float>::max();
        for (int i = 0; i < kNodeCount; ++i) {
            const std::size_t index = static_cast<std::size_t>(i);
            if (!visited[index] && costs[index] < bestCost) {
                currentNode = i;
                bestCost = costs[index];
            }
        }
        if (currentNode < 0 || currentNode == goal) break;
        visited[static_cast<std::size_t>(currentNode)] = true;

        const Node &node = graph.nodes[static_cast<std::size_t>(currentNode)];
        for (int edge = 0; edge < node.neighborCount; ++edge) {
            const int neighbor = node.neighbors[static_cast<std::size_t>(edge)];
            const std::size_t next = static_cast<std::size_t>(neighbor);
            if (visited[next]) continue;
            const float weight = std::sqrt(distanceSquared(
                node.position, graph.nodes[next].position));
            const float candidate = bestCost + weight;
            if (candidate < costs[next]) {
                costs[next] = candidate;
                previous[next] = currentNode;
            }
        }
    }

    if (previous[static_cast<std::size_t>(goal)] < 0) return destination;
    int step = goal;
    while (previous[static_cast<std::size_t>(step)] != start) {
        step = previous[static_cast<std::size_t>(step)];
        if (step < 0) return destination;
    }
    return graph.nodes[static_cast<std::size_t>(step)].position;
}

} // namespace arena_navigation
