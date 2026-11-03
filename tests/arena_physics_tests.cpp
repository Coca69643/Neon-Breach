#include "../app/src/main/cpp/ArenaPhysics.h"
#include "../app/src/main/cpp/ArenaMapDefinition.h"

#include <cassert>
#include <cmath>
#include <algorithm>
#include <iostream>

namespace {
float distance(float ax,float az,float bx,float bz) {
    const float x=bx-ax,z=bz-az;
    return std::sqrt(x*x+z*z);
}
void testSharedArenaMapCatalog() {
    assert(arena_map::kLanes.size()==3);
    assert(arena_map::kCampPositions.size()==8);
    assert(arena_map::kObjectivePositions.size()==2);
    assert(arena_map::kGroveCenters.size()==12);
    assert(arena_map::kTreeBlockers.size()==32);
    for(std::size_t lane=0;lane<arena_map::kLanes.size();++lane) {
        const auto &points=arena_map::kLanes[lane].points;
        for(std::size_t i=0;i<points.size();++i) {
            assert(std::abs(arena_map::laneCenterX(static_cast<int>(lane),points[i].z)-points[i].x)<0.0001f);
            if(i>0) assert(points[i].z>points[i-1].z);
        }
    }
    for(const auto &camp:arena_map::kCampPositions) {
        assert(std::abs(camp.x)<arena_map::kHalfExtentX);
        assert(std::abs(camp.z)<arena_map::kHalfExtentZ);
    }
    for(const auto &tree:arena_map::kTreeBlockers) {
        assert(std::abs(tree.x)<arena_map::kHalfExtentX);
        assert(std::abs(tree.z)<arena_map::kHalfExtentZ);
    }
    for(int lane=0;lane<3;++lane) for(int tier=0;tier<3;++tier) {
        const auto blue=arena_map::towerPosition(0,lane,tier);
        const auto red=arena_map::towerPosition(1,lane,tier);
        assert(std::abs(blue.x-arena_map::laneCenterX(lane,blue.z))<0.0001f);
        assert(std::abs(red.x-arena_map::laneCenterX(lane,red.z))<0.0001f);
        assert(std::abs(blue.z+red.z)<0.0001f);
    }
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
void testTreeCollisionAndSliding() {
    arena_physics::Body body{-12.2f,-23.0f,0.0f,0.0f,0.43f};
    for(int i=0;i<120;++i) arena_physics::move(body,3.0f,0.0f,1.0f/60.0f);
    assert(distance(body.x,body.z,-10.5f,-23.0f)>=1.19f);
    assert(std::isfinite(body.x)&&std::isfinite(body.z));
}
void testStructureCollision() {
    const float towerZ=22.0f;
    const float towerX=arena_map::towerPosition(1,1,2).x;
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
    testSharedArenaMapCatalog();
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
