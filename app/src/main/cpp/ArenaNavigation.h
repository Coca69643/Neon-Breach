#pragma once

#include "ArenaWorld17Generated.h"

#include <array>
#include <cmath>
#include <limits>
#include <string_view>

namespace arena_navigation {

struct Vec2 { float x; float z; };
inline constexpr int kNodeCount = static_cast<int>(arena_world_17::kNavigationNodes.size());
inline constexpr int kMaxNeighbors = 8;

struct Node {
    Vec2 position{};
    std::array<int, kMaxNeighbors> neighbors{};
    int neighborCount = 0;
};
struct Graph { std::array<Node, kNodeCount> nodes{}; };

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
inline int nodeIndex(std::string_view id) {
    for (int i = 0; i < kNodeCount; ++i) {
        if (arena_world_17::kNavigationNodes[static_cast<std::size_t>(i)].id == id) return i;
    }
    return -1;
}
inline Graph buildGraph() {
    Graph graph{};
    for (int i = 0; i < kNodeCount; ++i) {
        const auto &source = arena_world_17::kNavigationNodes[static_cast<std::size_t>(i)];
        graph.nodes[static_cast<std::size_t>(i)].position = {source.position.x, source.position.z};
    }
    for (const auto &link : arena_world_17::kNavigationLinks) {
        connect(graph, nodeIndex(link.from), nodeIndex(link.to));
    }
    return graph;
}
inline const Graph &mapGraph() {
    static const Graph graph = buildGraph();
    return graph;
}
inline int nearestNode(const Graph &graph, Vec2 position) {
    int best = 0;
    float bestDistance = std::numeric_limits<float>::max();
    for (int i = 0; i < kNodeCount; ++i) {
        const float d = distanceSquared(position, graph.nodes[static_cast<std::size_t>(i)].position);
        if (d < bestDistance) { bestDistance = d; best = i; }
    }
    return best;
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
