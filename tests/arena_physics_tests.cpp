#include "../app/src/main/cpp/ArenaPhysics.h"
#include "../app/src/main/cpp/ArenaMapDefinition.h"
#include "../app/src/main/cpp/ArenaNavigation.h"
#include "../app/src/main/cpp/ArenaCampCombat.h"

#include <cassert>
#include <cmath>
#include <algorithm>
#include <iostream>

namespace {
float distance(float ax,float az,float bx,float bz) {
    const float x=bx-ax,z=bz-az;
    return std::sqrt(x*x+z*z);
}
void testNeutralCampCombatRules() {
    assert(arena_camp::canAggro(180.0f,7.0f,12.0f,10.0f));
    assert(!arena_camp::canAggro(0.0f,1.0f,12.0f,10.0f));
    assert(!arena_camp::canAggro(180.0f,10.5f,12.0f,10.0f));
    assert(arena_camp::canStrike(180.0f,0.0f,2.2f,2.8f,10.0f));
    assert(!arena_camp::canStrike(180.0f,0.1f,2.2f,2.8f,10.0f));
    assert(!arena_camp::canStrike(180.0f,0.0f,3.2f,2.8f,10.0f));
    assert(!arena_camp::canStrike(0.0f,0.0f,1.0f,2.8f,10.0f));
    assert(!arena_camp::canStrike(180.0f,0.0f,1.0f,2.8f,0.8f));
}

void testArenaNavigationGraph() {
    const auto &graph=arena_navigation::mapGraph();
    assert(graph.nodes.size()==static_cast<std::size_t>(arena_navigation::kNodeCount));
    for(int node=0;node<arena_navigation::kNodeCount;++node) {
        const auto &entry=graph.nodes[static_cast<std::size_t>(node)];
        assert(entry.neighborCount>0);
        for(int edge=0;edge<entry.neighborCount;++edge) {
            const int neighbor=entry.neighbors[static_cast<std::size_t>(edge)];
            assert(neighbor>=0 && neighbor<arena_navigation::kNodeCount);
            const auto &other=graph.nodes[static_cast<std::size_t>(neighbor)];
            bool reciprocal=false;
            for(int reverse=0;reverse<other.neighborCount;++reverse) {
                if(other.neighbors[static_cast<std::size_t>(reverse)]==node) reciprocal=true;
            }
            assert(reciprocal);
        }
    }
    const auto westCrossing=graph.nodes[4].position;
    const auto eastCrossing=graph.nodes[22].position;
    const auto firstStep=arena_navigation::nextWaypoint(westCrossing,eastCrossing);
    const auto westObjective=graph.nodes[arena_navigation::kObjectiveNodeStart].position;
    assert(distance(firstStep.x,firstStep.z,westObjective.x,westObjective.z)<0.001f);

    const auto camp=graph.nodes[arena_navigation::kCampNodeStart].position;
    const auto objective=graph.nodes[arena_navigation::kObjectiveNodeStart+1].position;
    const auto jungleStep=arena_navigation::nextWaypoint(camp,objective);
    assert(std::isfinite(jungleStep.x) && std::isfinite(jungleStep.z));
    assert(distance(camp.x,camp.z,jungleStep.x,jungleStep.z)>0.5f);
    const auto shortStep=arena_navigation::nextWaypoint(
        {objective.x+1.0f,objective.z},objective);
    assert(distance(shortStep.x,shortStep.z,objective.x,objective.z)<0.0001f);
}

void testSharedArenaMapCatalog() {
    assert(arena_map::kLanes.size()==3);
    assert(arena_map::kCampPositions.size()==8);
    assert(arena_map::kObjectivePositions.size()==2);
    assert(arena_map::kRiverCenterline.size()==12);
    float minimumRiverWidth=100.0f, maximumRiverWidth=0.0f;
    for(const auto &point:arena_map::kRiverCenterline) {
        assert(std::abs(point.x)<arena_map::kHalfExtentX);
        assert(std::abs(point.z)<arena_map::kHalfExtentZ);
        assert(point.halfWidth>=0.65f && point.halfWidth<=2.0f);
        minimumRiverWidth=std::min(minimumRiverWidth,point.halfWidth);
        maximumRiverWidth=std::max(maximumRiverWidth,point.halfWidth);
    }
    assert(maximumRiverWidth-minimumRiverWidth>1.0f);
    assert(std::abs(arena_map::riverCenterZ(-15.0f)+0.45f)<0.0001f);
    assert(std::abs(arena_map::riverHalfWidth(-15.0f)-1.68f)<0.0001f);
    assert(arena_map::kGroveCenters.size()==12);
    assert(arena_map::kTreeBlockers.size()==32);
    assert(std::abs(arena_map::kWorldScale-1.15f)<0.0001f);
    assert(arena_map::kHalfExtentX*arena_map::kWorldScale>40.0f);
    assert(arena_map::kHalfExtentZ*arena_map::kWorldScale>35.5f);
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
    const float scale=arena_map::kWorldScale;
    arena_physics::Body body{-12.2f*scale,-23.0f*scale,0.0f,0.0f,0.43f};
    for(int i=0;i<120;++i) arena_physics::move(body,3.0f,0.0f,1.0f/60.0f);
    assert(distance(body.x,body.z,-10.5f*scale,-23.0f*scale)>=1.19f);
    assert(std::isfinite(body.x)&&std::isfinite(body.z));
}
void testStructureCollision() {
    const float scale=arena_map::kWorldScale;
    const auto tower=arena_map::towerPosition(1,1,2);
    const float towerZ=22.0f*scale;
    const float towerX=tower.x*scale;
    arena_physics::Body body{towerX,19.0f*scale,0.0f,0.0f,0.43f};
    for(int i=0;i<180;++i) arena_physics::move(body,0.0f,4.0f,1.0f/60.0f);
    assert(body.z>19.0f);
    assert(distance(body.x,body.z,towerX,towerZ)>=1.049f);
}
void testWorldBoundary() {
    const float scale=arena_map::kWorldScale;
    arena_physics::Body body{40.0f*scale,0.0f,0.0f,0.0f,0.45f};
    arena_physics::resolveWorld(body);
    assert(std::abs(body.x)<36.0f*scale);
}
void testBraking() {
    arena_physics::Body body{0.0f,-5.0f,0.0f,0.0f,0.35f};
    for(int i=0;i<30;++i) arena_physics::move(body,3.0f,0.0f,1.0f/60.0f);
    for(int i=0;i<90;++i) arena_physics::move(body,0.0f,0.0f,1.0f/60.0f);
    assert(std::sqrt(body.vx*body.vx+body.vz*body.vz)<0.15f);
}
void testCampGuardianCollision() {
    const float scale=arena_map::kWorldScale;
    const auto &camp=arena_map::kCampPositions[0];
    const float campX=camp.x*scale;
    const float campZ=camp.z*scale;
    arena_physics::Body body{campX-1.8f,campZ,0.0f,0.0f,0.43f};
    for(int i=0;i<120;++i) arena_physics::move(body,3.0f,0.0f,1.0f/60.0f);
    assert(distance(body.x,body.z,campX,campZ)>=1.12f);
}

void testObstacleSteering() {
    const float scale=arena_map::kWorldScale;
    arena_physics::Body body{-12.2f*scale,-23.0f*scale,0.0f,0.0f,0.43f};
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
    testNeutralCampCombatRules();
    testArenaNavigationGraph();
    testSharedArenaMapCatalog();
    testTerrainSurface();
    testTreeCollisionAndSliding();
    testStructureCollision();
    testWorldBoundary();
    testBraking();
    testObstacleSteering();
    testCampGuardianCollision();
    testCharacterSeparation();
    std::cout<<"Arena physics tests passed (terrain, obstacles, structures, bounds, braking, AI steering, actor separation).\n";
    return 0;
}
