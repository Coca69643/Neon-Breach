#include "../app/src/main/cpp/ArenaPhysics.h"
#include "../app/src/main/cpp/ArenaWorldDefinition.h"

#include <cassert>
#include <cmath>
#include <algorithm>
#include <iostream>

namespace {
float distance(float ax,float az,float bx,float bz) {
    const float x=bx-ax,z=bz-az;
    return std::sqrt(x*x+z*z);
}
void testTerrainSurface() {
    float low=100.0f,high=-100.0f,maxSlope=0.0f;
    for(float x=-30.0f;x<=30.0f;x+=1.0f) {
        for(float z=-28.0f;z<=28.0f;z+=1.0f) {
            const float height=arena_physics::terrainHeight(x,z);
            const float slope=arena_physics::terrainSlope(x,z);
            assert(std::isfinite(height)&&std::isfinite(slope));
            low=std::min(low,height);high=std::max(high,height);
            maxSlope=std::max(maxSlope,slope);
        }
    }
    assert(high-low>3.2f); // Terrain must read as distinct highlands and a river valley.
    assert(maxSlope<std::tan(43.0f*3.14159265f/180.0f));
}
void testCanonicalWorldDefinition() {
    assert(arena_world::kCampPositions.size() == 8);
    assert(arena_world::kObjectivePositions.size() == 2);
    assert(arena_world::kForestTreePositions.size() == 32);
    assert(arena_world::kJungleGrovePositions.size() == 12);
    assert(arena_world::insideIsland(0.0f, 0.0f));
    assert(!arena_world::insideIsland(60.0f, 0.0f));

    for (int team = 0; team < 2; ++team) {
        const auto castle = arena_world::castlePosition(team);
        const auto church = arena_world::churchPosition(team);
        const auto gate = arena_world::baseGatePavingPosition(team);
        assert(std::abs(castle.x) < 0.001f);
        assert(std::abs(castle.z + arena_world::castlePosition(1 - team).z) < 0.001f);
        assert(std::abs(church.x + arena_world::churchPosition(1 - team).x) < 0.001f);
        assert(std::abs(church.z + arena_world::churchPosition(1 - team).z) < 0.001f);
        assert(std::abs(gate.x) < 0.001f);
        assert(std::abs(gate.z + arena_world::baseGatePavingPosition(1 - team).z) < 0.001f);
        for (int side = 0; side < 2; ++side) {
            const auto home = arena_world::homePosition(team, side);
            const auto wall = arena_world::baseWallPosition(team, side);
            assert(std::abs(home.x - arena_world::homePosition(1 - team, side).x) < 0.001f);
            assert(std::abs(home.z + arena_world::homePosition(1 - team, side).z) < 0.001f);
            assert(std::abs(wall.x - arena_world::baseWallPosition(1 - team, side).x) < 0.001f);
            assert(std::abs(wall.z + arena_world::baseWallPosition(1 - team, side).z) < 0.001f);
        }
    }
    assert(arena_world::kBaseLandmarkPositions.size() == 14);

    for (int i = 0; i < 56; ++i) {
        const auto point = arena_world::undergrowthPosition(i);
        assert(std::isfinite(point.x) && std::isfinite(point.z));
    }

    for (float z = -30.0f; z <= 30.0f; z += 5.0f) {
        const float left = arena_world::laneCenterX(0, z);
        const float middle = arena_world::laneCenterX(1, z);
        const float right = arena_world::laneCenterX(2, z);
        assert(left + 10.0f < middle);
        assert(middle + 10.0f < right);
    }

    for (std::size_t i = 0; i < 4; ++i) {
        const auto west = arena_world::kCampPositions[i * 2];
        const auto east = arena_world::kCampPositions[i * 2 + 1];
        assert(std::abs(west.x + east.x) < 0.001f);
        assert(std::abs(west.z - east.z) < 0.001f);
    }

    for (int team = 0; team < 2; ++team) {
        for (int lane = 0; lane < arena_world::kLaneCount; ++lane) {
            for (int tier = 0; tier < arena_world::kTowerTiers; ++tier) {
                const auto tower = arena_world::towerPosition(team, lane, tier);
                assert(std::abs(tower.x - arena_world::laneCenterX(lane, tower.z)) < 0.001f);
                assert((team == 0 && tower.z < 0.0f) || (team == 1 && tower.z > 0.0f));
            }
        }
    }

    for (float x = -32.0f; x <= 32.0f; x += 4.0f) {
        const float riverZ = arena_world::riverCenterZ(x);
        assert(std::isfinite(riverZ));
        for (float z = -28.0f; z <= 28.0f; z += 4.0f) {
            const float canonical = arena_world::terrainHeight(x, z);
            const float physics = arena_physics::terrainHeight(x, z);
            assert(std::isfinite(canonical));
            assert(std::abs(canonical - physics) < 0.00001f);
        }
    }
}
void testTreeCollisionAndSliding() {
    arena_physics::Body body{-12.2f,-23.0f,0.0f,0.0f,0.43f};
    for(int i=0;i<120;++i) arena_physics::move(body,3.0f,0.0f,1.0f/60.0f);
    assert(distance(body.x,body.z,-10.5f,-23.0f)>=1.19f);
    assert(std::isfinite(body.x)&&std::isfinite(body.z));
}
void testStructureCollision() {
    const float towerZ=22.0f;
    const float towerX=0.5f+std::sin(towerZ*0.12f)*0.72f;
    arena_physics::Body body{towerX,19.0f,0.0f,0.0f,0.43f};
    for(int i=0;i<180;++i) arena_physics::move(body,0.0f,4.0f,1.0f/60.0f);
    assert(body.z>19.0f);
    assert(distance(body.x,body.z,towerX,towerZ)>=1.049f);
}
void testWorldBoundary() {
    arena_physics::Body body{40.0f,0.0f,0.0f,0.0f,0.45f};
    arena_physics::resolveWorld(body);
    assert(std::abs(body.x)<36.0f);
}
void testBraking() {
    arena_physics::Body body{0.0f,-5.0f,0.0f,0.0f,0.35f};
    for(int i=0;i<30;++i) arena_physics::move(body,3.0f,0.0f,1.0f/60.0f);
    for(int i=0;i<90;++i) arena_physics::move(body,0.0f,0.0f,1.0f/60.0f);
    assert(std::sqrt(body.vx*body.vx+body.vz*body.vz)<0.15f);
}
void testObstacleSteering() {
    arena_physics::Body body{-12.2f,-23.0f,0.0f,0.0f,0.43f};
    float desiredX=3.0f,desiredZ=0.0f;
    arena_physics::avoidObstacles(body,desiredX,desiredZ);
    assert(desiredX>0.0f);
    assert(std::abs(desiredZ)>0.1f);
    const float speed=std::sqrt(desiredX*desiredX+desiredZ*desiredZ);
    assert(std::abs(speed-3.0f)<0.001f);
}
void testCharacterSeparation() {
    arena_physics::Body a{0.0f,-5.0f,2.0f,0.0f,0.43f};
    arena_physics::Body b{0.2f,-5.0f,0.0f,0.0f,0.38f};
    arena_physics::separate(a,b);
    assert(distance(a.x,a.z,b.x,b.z)>=a.radius+b.radius-0.001f);
}
}
int main() {
    testCanonicalWorldDefinition();
    testTerrainSurface();
    testTreeCollisionAndSliding();
    testStructureCollision();
    testWorldBoundary();
    testBraking();
    testObstacleSteering();
    testCharacterSeparation();
    std::cout<<"Arena physics tests passed (terrain, obstacles, structures, bounds, braking, AI steering, actor separation).\n";
    return 0;
}
