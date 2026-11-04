#include "ArenaPhysics.h"
#include "ArenaMapDefinition.h"
#include <algorithm>
#include <array>
#include <cmath>
#include <limits>
#include <vector>

namespace arena_physics {
namespace {
constexpr float kPi = 3.14159265358979323846f;
constexpr float kEpsilon = 0.00001f;
struct Circle { float x, z, r; };
struct Box { float x, z, hx, hz; };
struct Colliders {
    std::vector<Circle> circles;
    std::vector<Box> boxes;
    Colliders() {
        const float scale = arena_map::kWorldScale;
        circles.reserve(256);
        for (const auto &tree : arena_map::kTreeBlockers) {
            circles.push_back({tree.x * scale, tree.z * scale, 0.78f});
        }
        for (std::size_t i = 0; i < arena_map::kCampPositions.size(); ++i) {
            const auto &camp = arena_map::kCampPositions[i];
            circles.push_back({camp.x * scale, camp.z * scale, 0.82f});
            for (int rock = 0; rock < 6; ++rock) {
                const float angle = 2.0f * kPi * static_cast<float>(rock) / 6.0f +
                    static_cast<float>(i) * 0.27f;
                circles.push_back({
                    (camp.x + std::cos(angle) * 2.7f) * scale,
                    (camp.z + std::sin(angle) * 2.15f) * scale,
                    0.28f
                });
            }
        }
        for (std::size_t i = 0; i < arena_map::kObjectivePositions.size(); ++i) {
            const auto &objective = arena_map::kObjectivePositions[i];
            const float radius = arena_map::kObjectiveRadii[i];
            for (int segment = 0; segment < 12; ++segment) {
                const float angle = 2.0f * kPi * static_cast<float>(segment) / 12.0f;
                circles.push_back({
                    (objective.x + std::cos(angle) * radius) * scale,
                    (objective.z + std::sin(angle) * radius * 0.82f) * scale,
                    0.36f
                });
            }
        }
        for (int team = 0; team < 2; ++team) {
            const auto &base = arena_world_17::kBases[static_cast<std::size_t>(team)];
            boxes.push_back({
                base.position.x * scale, base.position.z * scale,
                2.0f * scale, 2.0f * scale
            });
            for (int lane = 0; lane < 3; ++lane) {
                for (int tier = 0; tier < 3; ++tier) {
                    const auto point = arena_map::towerPosition(team, lane, tier);
                    circles.push_back({point.x * scale, point.z * scale, 1.12f});
                }
            }
        }
    }
};
const Colliders &world() { static const Colliders colliders; return colliders; }

float organicEdge(float angle) {
    return 1.0f + 0.016f * std::sin(angle * 5.0f) +
        0.009f * std::sin(angle * 9.0f + 1.4f) +
        0.006f * std::cos(angle * 13.0f);
}
void confine(Body &body) {
    const float halfX = arena_map::kHalfExtentX;
    const float halfZ = arena_map::kHalfExtentZ;
    const float angle = std::atan2(body.z / halfZ, body.x / halfX);
    const float edge = organicEdge(angle);
    const float nx = std::abs(body.x / halfX);
    const float nz = std::abs(body.z / halfZ);
    const float metric = std::pow(nx, 4.0f) + std::pow(nz, 4.0f);
    const float limit = std::pow(std::max(0.0f, edge - body.radius / halfZ), 4.0f);
    if (metric > limit && metric > kEpsilon) {
        const float factor = std::pow(limit / metric, 0.25f);
        body.x *= factor;
        body.z *= factor;
    }
}
void hitCircle(Body &body, const Circle &circle) {
    const float dx = body.x - circle.x, dz = body.z - circle.z;
    const float minimum = body.radius + circle.r;
    const float d2 = dx * dx + dz * dz;
    if (d2 >= minimum * minimum) return;
    const float d = std::sqrt(std::max(d2, kEpsilon));
    const float nx = d2 <= kEpsilon ? 1.0f : dx / d;
    const float nz = d2 <= kEpsilon ? 0.0f : dz / d;
    body.x += nx * (minimum - d); body.z += nz * (minimum - d);
    const float inward = body.vx * nx + body.vz * nz;
    if (inward < 0.0f) { body.vx -= inward * nx; body.vz -= inward * nz; }
}
void hitBox(Body &body, const Box &box) {
    const float left = box.x-box.hx-body.radius, right = box.x+box.hx+body.radius;
    const float nearZ = box.z-box.hz-body.radius, farZ = box.z+box.hz+body.radius;
    if (body.x <= left || body.x >= right || body.z <= nearZ || body.z >= farZ) return;
    const std::array<float,4> d{{body.x-left,right-body.x,body.z-nearZ,farZ-body.z}};
    const std::size_t side = static_cast<std::size_t>(
        std::min_element(d.begin(),d.end())-d.begin());
    if(side==0){body.x=left;body.vx=std::max(0.0f,body.vx);}
    else if(side==1){body.x=right;body.vx=std::min(0.0f,body.vx);}
    else if(side==2){body.z=nearZ;body.vz=std::max(0.0f,body.vz);}
    else {body.z=farZ;body.vz=std::min(0.0f,body.vz);}
}
void slideUphill(Body &body,float maxSlope) {
    constexpr float e=0.12f;
    const float gx=(terrainHeight(body.x+e,body.z)-terrainHeight(body.x-e,body.z))/(2.0f*e);
    const float gz=(terrainHeight(body.x,body.z+e)-terrainHeight(body.x,body.z-e))/(2.0f*e);
    const float slope=std::sqrt(gx*gx+gz*gz);
    const float cap=std::tan(maxSlope*kPi/180.0f);
    if(slope<=cap||slope<=kEpsilon)return;
    const float nx=gx/slope,nz=gz/slope,uphill=body.vx*nx+body.vz*nz;
    if(uphill>0.0f){body.vx-=uphill*nx;body.vz-=uphill*nz;}
}
struct RiverClosest { float distance; float halfWidth; };
RiverClosest closestRiver(float x,float z) {
    float best=std::numeric_limits<float>::max();
    float width=arena_world_17::kRiver.front().halfWidth;
    for(std::size_t i=0;i+1<arena_world_17::kRiver.size();++i) {
        const auto &a=arena_world_17::kRiver[i]; const auto &b=arena_world_17::kRiver[i+1];
        const float dx=b.position.x-a.position.x,dz=b.position.z-a.position.z;
        const float denominator=std::max(dx*dx+dz*dz,0.0001f);
        const float t=std::clamp(((x-a.position.x)*dx+(z-a.position.z)*dz)/denominator,0.0f,1.0f);
        const float px=a.position.x+dx*t,pz=a.position.z+dz*t;
        const float d2=(x-px)*(x-px)+(z-pz)*(z-pz);
        if(d2<best){best=d2;width=a.halfWidth+(b.halfWidth-a.halfWidth)*t;}
    }
    return {std::sqrt(best),width};
}
} // namespace

float terrainHeight(float x,float z) {
    float ridge=0.0f,valleyControl=0.0f;
    for(const auto &control:arena_world_17::kElevationControls) {
        const float dx=x-control.position.x,dz=z-control.position.z;
        const float influence=std::exp(-(dx*dx+dz*dz)/
            std::max(control.radius*control.radius*0.50f,0.001f));
        if(control.height>=0.0f) ridge=std::max(ridge,control.height*influence);
        else valleyControl+=control.height*influence;
    }
    const RiverClosest river=closestRiver(x,z);
    const float channel=-arena_world_17::kRiverValleyDepthM*
        std::exp(-(river.distance*river.distance)/
            std::max(river.halfWidth*river.halfWidth*1.60f,0.001f));
    const float broadPhase=static_cast<float>(arena_world_17::kBroadNoiseSeed%97u)*0.013f;
    const float detailPhase=static_cast<float>(arena_world_17::kDetailNoiseSeed%97u)*0.013f;
    const float broadNoise=arena_world_17::kBroadNoiseAmplitudeM*(
        0.58f*std::sin((x+broadPhase)*0.031f)*std::cos((z-broadPhase)*0.027f)+
        0.42f*std::sin((x+z)*0.019f+broadPhase));
    const float detailNoise=arena_world_17::kDetailNoiseAmplitudeM*
        std::sin(x*0.19f+z*0.13f+detailPhase)*std::cos(z*0.17f-x*0.11f-detailPhase);
    return std::clamp(ridge+valleyControl+channel+broadNoise+detailNoise,
        arena_world_17::kMinHeightM,arena_world_17::kMaxHeightM);
}
float terrainSlope(float x,float z) {
    constexpr float e=0.12f;
    const float gx=(terrainHeight(x+e,z)-terrainHeight(x-e,z))/(2.0f*e);
    const float gz=(terrainHeight(x,z+e)-terrainHeight(x,z-e))/(2.0f*e);
    return std::sqrt(gx*gx+gz*gz);
}
void resolveWorld(Body &body) {
    const auto &colliders=world();
    for(int pass=0;pass<3;++pass) {
        for(const auto &circle:colliders.circles)hitCircle(body,circle);
        for(const auto &box:colliders.boxes)hitBox(body,box);
        confine(body);
    }
}
void avoidObstacles(const Body &body,float &desiredX,float &desiredZ) {
    const float speed=std::sqrt(desiredX*desiredX+desiredZ*desiredZ);
    if(speed<0.08f)return;
    const float dx=desiredX/speed,dz=desiredZ/speed;
    const float lookAhead=std::clamp(speed*0.58f,1.15f,2.65f);
    float bestProjection=lookAhead+1.0f,steerX=0.0f,steerZ=0.0f;
    const auto consider=[&](float x,float z,float radius) {
        const float ox=x-body.x,oz=z-body.z,along=ox*dx+oz*dz;
        if(along<0.10f||along>lookAhead+radius)return;
        const float lateral=std::abs(dx*oz-dz*ox);
        const float clearance=body.radius+radius+0.18f;
        if(lateral>=clearance||along>=bestProjection)return;
        const float cross=dx*oz-dz*ox;
        const float side=std::abs(cross)>0.025f?(cross>0.0f?-1.0f:1.0f):
            (std::fmod(std::abs(x*13.0f+z*7.0f),2.0f)<1.0f?1.0f:-1.0f);
        const float reach=std::clamp(1.0f-along/(lookAhead+radius),0.0f,1.0f);
        const float overlap=std::clamp(1.0f-lateral/clearance,0.0f,1.0f);
        const float strength=0.35f+1.55f*reach*overlap;
        steerX=-dz*side*strength;steerZ=dx*side*strength;bestProjection=along;
    };
    const auto &colliders=world();
    for(const Circle &circle:colliders.circles)consider(circle.x,circle.z,circle.r);
    for(const Box &box:colliders.boxes)consider(box.x,box.z,std::sqrt(box.hx*box.hx+box.hz*box.hz));
    if(steerX==0.0f&&steerZ==0.0f)return;
    const float outX=dx+steerX,outZ=dz+steerZ;
    const float outLength=std::sqrt(outX*outX+outZ*outZ);
    if(outLength>kEpsilon){desiredX=speed*outX/outLength;desiredZ=speed*outZ/outLength;}
}
void move(Body &b,float desiredX,float desiredZ,float dt,float acceleration,float braking,float maxSlopeDegrees) {
    if(dt<=0)return;
    dt=std::clamp(dt,0.0f,0.05f);
    const float desired=std::sqrt(desiredX*desiredX+desiredZ*desiredZ);
    if(desired>9.6f){const float s=9.6f/desired;desiredX*=s;desiredZ*=s;}
    const float rate=desired>0.08f?acceleration:braking;
    const float speed=std::max(std::sqrt(b.vx*b.vx+b.vz*b.vz),desired);
    const int steps=std::clamp(static_cast<int>(std::ceil(dt*speed/0.12f)),1,4);
    const float h=dt/static_cast<float>(steps);
    for(int i=0;i<steps;++i) {
        const float limit=rate*h;
        b.vx+=std::clamp(desiredX-b.vx,-limit,limit);
        b.vz+=std::clamp(desiredZ-b.vz,-limit,limit);
        slideUphill(b,maxSlopeDegrees);
        const float x=b.x,z=b.z;
        b.x+=b.vx*h;b.z+=b.vz*h;
        resolveWorld(b);
        b.vx=(b.x-x)/h;b.vz=(b.z-z)/h;
    }
}
void separate(Body &a,Body &b) {
    const float dx=b.x-a.x,dz=b.z-a.z,min=a.radius+b.radius,d2=dx*dx+dz*dz;
    if(d2>=min*min)return;
    const float d=std::sqrt(std::max(d2,kEpsilon));
    const float nx=d2<=kEpsilon?1.0f:dx/d,nz=d2<=kEpsilon?0.0f:dz/d;
    const float push=(min-d)*0.5f;
    a.x-=nx*push;a.z-=nz*push;b.x+=nx*push;b.z+=nz*push;
    const float relative=(a.vx-b.vx)*nx+(a.vz-b.vz)*nz;
    if(relative>0){a.vx-=relative*0.5f*nx;a.vz-=relative*0.5f*nz;b.vx+=relative*0.5f*nx;b.vz+=relative*0.5f*nz;}
    resolveWorld(a);resolveWorld(b);
}
} // namespace arena_physics
