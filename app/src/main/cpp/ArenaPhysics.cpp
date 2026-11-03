#include "ArenaPhysics.h"
#include "ArenaWorldDefinition.h"
#include <algorithm>
#include <array>
#include <cmath>
#include <vector>

namespace arena_physics {
namespace {
constexpr float kPi=3.14159265358979323846f;
constexpr float kEpsilon=0.00001f;
struct Circle { float x,z,r; };
struct Box { float x,z,hx,hz; };
struct Colliders {
    std::vector<Circle> circles;
    std::vector<Box> boxes;
    Colliders() {
        circles.reserve(192);
        for (const auto &point : arena_world::kForestTreePositions) {
            circles.push_back({point.x, point.z, 0.78f});
        }

        for (std::size_t n = 0; n < arena_world::kCampPositions.size(); ++n) {
            const auto point = arena_world::kCampPositions[n];
            for (int i = 0; i < 7; ++i) {
                const float a = 2 * kPi * static_cast<float>(i) / 7 + static_cast<float>(n) * 0.31f;
                circles.push_back({point.x + std::cos(a) * 2.65f,
                    point.z + std::sin(a) * 2.0f, 0.27f});
            }
        }
        for (int objective=0;objective<2;++objective) {
            const float x=arena_world::kObjectivePositions[static_cast<std::size_t>(objective)].x;
            const float centerZ=arena_world::kObjectivePositions[static_cast<std::size_t>(objective)].z;
            for (int i=0;i<12;++i) {
                const float a=2*kPi*static_cast<float>(i)/12;
                circles.push_back({x+std::cos(a)*4.55f,centerZ+std::sin(a)*3.75f,0.34f});
            }
            boxes.push_back({x,centerZ,1.55f,1.42f});
        }
        for (std::size_t n = 0; n < arena_world::kJungleGrovePositions.size(); ++n) {
            const auto point = arena_world::kJungleGrovePositions[n];
            for (int j = 0; j < 4; ++j) {
                const float a = 2 * kPi * static_cast<float>(j) / 4 + static_cast<float>(n) * 0.43f;
                circles.push_back({point.x + std::cos(a) * 1.8f,
                    point.z + std::sin(a) * 1.4f, 0.26f});
            }
        }
        for (int i=0;i<56;++i) {
            const float base=(i%4==0)?-10.1f:(i%4==1)?-6.1f:(i%4==2)?6.1f:10.1f;
            const float x=base+std::sin(static_cast<float>(i)*1.71f)*0.82f;
            const float z=-22.0f+static_cast<float>(i/4)*3.15f;
            if (std::abs(z)<=24.0f && !(i%8<4 && z>0.0f))
                circles.push_back({x,z,0.21f});
        }
        for (int team=0;team<2;++team) {
            const float sign=team==0?-1.0f:1.0f;
            boxes.push_back({0,sign*27.3f,2.6f,2.0f});
            boxes.push_back({-4.5f,sign*24.0f,1.25f,1.1f});
            boxes.push_back({4.5f,sign*24.0f,1.25f,1.1f});
            boxes.push_back({sign*8.0f,sign*25.3f,0.82f,0.82f});
            boxes.push_back({-7,sign*24.2f,2.6f,0.38f});
            boxes.push_back({7,sign*24.2f,2.6f,0.38f});
            for (int lane=0;lane<3;++lane) for (int tier=0;tier<3;++tier) {
                const float z=arena_world::towerZ(team,tier);
                circles.push_back({arena_world::laneCenterX(lane,z),z,0.62f});
            }
        }
    }
};
const Colliders &world(){static const Colliders c;return c;}

void confine(Body &b) {
    const float a=std::atan2(b.z/31.0f,b.x/35.0f);
    const float edge=1.0f+0.035f*std::sin(a*5.0f)+0.020f*std::sin(a*9.0f+1.4f)+0.012f*std::cos(a*13.0f);
    const float r=std::sqrt((b.x/35.0f)*(b.x/35.0f)+(b.z/31.0f)*(b.z/31.0f));
    const float limit=std::max(0.0f,edge-b.radius/33.0f);
    if(r>limit && r>kEpsilon){const float s=limit/r;b.x*=s;b.z*=s;}
}
void hitCircle(Body &b,const Circle &c) {
    const float dx=b.x-c.x,dz=b.z-c.z,min=b.radius+c.r,d2=dx*dx+dz*dz;
    if(d2>=min*min)return;
    const float d=std::sqrt(std::max(d2,kEpsilon));
    const float nx=d2<=kEpsilon?1.0f:dx/d,nz=d2<=kEpsilon?0.0f:dz/d;
    b.x+=nx*(min-d);b.z+=nz*(min-d);
    const float inward=b.vx*nx+b.vz*nz;
    if(inward<0){b.vx-=inward*nx;b.vz-=inward*nz;}
}
void hitBox(Body &b,const Box &c) {
    const float l=c.x-c.hx-b.radius,r=c.x+c.hx+b.radius;
    const float n=c.z-c.hz-b.radius,f=c.z+c.hz+b.radius;
    if(b.x<=l||b.x>=r||b.z<=n||b.z>=f)return;
    const std::array<float,4> d{{b.x-l,r-b.x,b.z-n,f-b.z}};
    const std::size_t side=static_cast<std::size_t>(std::min_element(d.begin(),d.end())-d.begin());
    if(side==0){b.x=l;b.vx=std::max(0.0f,b.vx);}
    else if(side==1){b.x=r;b.vx=std::min(0.0f,b.vx);}
    else if(side==2){b.z=n;b.vz=std::max(0.0f,b.vz);}
    else {b.z=f;b.vz=std::min(0.0f,b.vz);}
}
void slideUphill(Body &b,float maxSlope) {
    constexpr float e=0.08f;
    const float gx=(terrainHeight(b.x+e,b.z)-terrainHeight(b.x-e,b.z))/(2*e);
    const float gz=(terrainHeight(b.x,b.z+e)-terrainHeight(b.x,b.z-e))/(2*e);
    const float slope=std::sqrt(gx*gx+gz*gz),cap=std::tan(maxSlope*kPi/180.0f);
    if(slope<=cap||slope<=kEpsilon)return;
    const float nx=gx/slope,nz=gz/slope,up=b.vx*nx+b.vz*nz;
    if(up>0){b.vx-=up*nx;b.vz-=up*nz;}
}
} // namespace

float terrainHeight(float x,float z) {
    return arena_world::terrainHeight(x,z);
}
float terrainSlope(float x,float z) {
    constexpr float e=0.08f;
    const float gx=(terrainHeight(x+e,z)-terrainHeight(x-e,z))/(2*e);
    const float gz=(terrainHeight(x,z+e)-terrainHeight(x,z-e))/(2*e);
    return std::sqrt(gx*gx+gz*gz);
}
void resolveWorld(Body &b) {
    const auto &c=world();
    for(int pass=0;pass<3;++pass) {
        for(const auto &v:c.circles)hitCircle(b,v);
        for(const auto &v:c.boxes)hitBox(b,v);
        confine(b);
    }
}
void avoidObstacles(const Body &body,float &desiredX,float &desiredZ) {
    const float speed=std::sqrt(desiredX*desiredX+desiredZ*desiredZ);
    if(speed<0.08f)return;
    const float dx=desiredX/speed,dz=desiredZ/speed;
    const float lookAhead=std::clamp(speed*0.58f,1.15f,2.65f);
    float bestProjection=lookAhead+1.0f;
    float steerX=0.0f,steerZ=0.0f;
    const auto consider=[&](float x,float z,float radius) {
        const float ox=x-body.x,oz=z-body.z;
        const float along=ox*dx+oz*dz;
        if(along<0.10f||along>lookAhead+radius)return;
        const float lateral=std::abs(dx*oz-dz*ox);
        const float clearance=body.radius+radius+0.18f;
        if(lateral>=clearance||along>=bestProjection)return;
        const float cross=dx*oz-dz*ox;
        float side;
        if(std::abs(cross)>0.025f) side=cross>0.0f?-1.0f:1.0f;
        else side=(std::fmod(std::abs(x*13.0f+z*7.0f),2.0f)<1.0f)?1.0f:-1.0f;
        const float reach=std::clamp(1.0f-along/(lookAhead+radius),0.0f,1.0f);
        const float overlap=std::clamp(1.0f-lateral/clearance,0.0f,1.0f);
        const float strength=0.35f+1.55f*reach*overlap;
        steerX=-dz*side*strength;
        steerZ=dx*side*strength;
        bestProjection=along;
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
