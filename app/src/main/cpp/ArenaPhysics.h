#pragma once
namespace arena_physics {
struct Body { float x=0, z=0, vx=0, vz=0, radius=0.35f; };
float terrainHeight(float x, float z);
float terrainSlope(float x, float z);
void resolveWorld(Body &body);
void move(Body &body, float desiredVelocityX, float desiredVelocityZ,
          float deltaTime, float acceleration=22.0f, float braking=28.0f,
          float maxSlopeDegrees=44.0f);
void separate(Body &a, Body &b);
}