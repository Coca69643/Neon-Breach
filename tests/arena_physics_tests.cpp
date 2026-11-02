#include "../app/src/main/cpp/ArenaPhysics.h"

#include <cassert>
#include <cmath>
#include <iostream>

namespace {
float distance(float ax,float az,float bx,float bz) {
    const float x=bx-ax,z=bz-az;
    return std::sqrt(x*x+z*z);
}
void testTerrainSurface() {
    const float a=arena_physics::terrainHeight(0.0f,-20.0f);
    const float b=arena_physics::terrainHeight(24.0f,-20.0f);
    assert(std::isfinite(a)&&std::isfinite(b));
    assert(arena_physics::terrainSlope(24.0f,-20.0f)>=0.0f);
}
void testTreeCollisionAndSliding() {
    arena_physics::Body body{-12.2f,-23.0f,0.0f,0.0f,0.43f};
    for(int i=0;i<120;++i) arena_physics::move(body,3.0f,0.0f,1.0f/60.0f);
    assert(distance(body.x,body.z,-10.5f,-23.0f)>=1.19f);
    assert(std::isfinite(body.x)&&std::isfinite(body.z));
}
void testStructureCollision() {
    arena_physics::Body body{0.99f,19.0f,0.0f,0.0f,0.43f};
    for(int i=0;i<180;++i) arena_physics::move(body,0.0f,4.0f,1.0f/60.0f);
    assert(body.z>20.80f&&body.z<=20.96f);
}
void testWorldBoundary() {
    arena_physics::Body body{40.0f,0.0f,0.0f,0.0f,0.45f};
    arena_physics::resolveWorld(body);
    assert(std::abs(body.x)<35.0f);
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
