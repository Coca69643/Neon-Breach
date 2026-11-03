#include "ArenaPhysics.h"
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
        constexpr std::array<std::array<float,2>,32> trees{{
            {{-10.5f,-23}},{{-6.2f,-22}},{{-11.5f,-17.5f}},{{-5.5f,-17}},
            {{-10.2f,-10}},{{-6.4f,-8}},{{10.5f,-23}},{{6.2f,-22}},
            {{11.5f,-17.5f}},{{5.5f,-17}},{{10.2f,-10}},{{6.4f,-8}},
            {{-22.8f,-18}},{{-26,-13}},{{-22.4f,-6}},{{-18.5f,-20}},
            {{22.8f,-18}},{{26,-13}},{{22.4f,-6}},{{18.5f,-20}},
            {{-10.5f,23}},{{-6.2f,22}},{{-11.5f,17.5f}},{{-5.5f,17}},
            {{-10.2f,10}},{{-6.4f,8}},{{10.5f,23}},{{6.2f,22}},
            {{11.5f,17.5f}},{{5.5f,17}},{{10.2f,10}},{{6.4f,8}}
        }};
        circles.reserve(160);
        for (const auto &p:trees) circles.push_back({p[0],p[1],0.78f});

        constexpr std::array<std::array<float,2>,8> camps{{
            {{-8.2f,-14.5f}},{{8.2f,-14.5f}},{{-20.2f,-10}},{{20.2f,-10}},
            {{-8.2f,14.5f}},{{8.2f,14.5f}},{{-20.2f,10}},{{20.2f,10}}
        }};
        for (std::size_t n=0;n<camps.size();++n) {
            for (int i=0;i<7;++i) {
                const float a=2*kPi*static_cast<float>(i)/7+static_cast<float>(n)*0.31f;
                circles.push_back({camps[n][0]+std::cos(a)*2.65f,
                    camps[n][1]+std::sin(a)*2.0f,0.27f});
            }
        }
        for (int objective=0;objective<2;++objective) {
            const float x=objective==0?-7.0f:7.0f;
            for (int i=0;i<12;++i) {
                const float a=2*kPi*static_cast<float>(i)/12;
                circles.push_back({x+std::cos(a)*4.55f,0.2f+std::sin(a)*3.75f,0.34f});
            }
            boxes.push_back({x,0.2f,1.55f,1.42f});
        }
        constexpr std::array<std::array<float,2>,12> groves{{
            {{-25,-19}},{{-27,-8}},{{-23,8}},{{-26,19}},{{25,-19}},{{27,-8}},
            {{23,8}},{{26,19}},{{-8.5f,-21}},{{8.5f,-21}},{{-8.5f,21}},{{8.5f,21}}
        }};
        for (std::size_t n=0;n<groves.size();++n) {
            for (int j=0;j<4;++j) {
                const float a=2*kPi*static_cast<float>(j)/4+static_cast<float>(n)*0.43f;
                circles.push_back({groves[n][0]+std::cos(a)*1.8f,
                    groves[n][1]+std::sin(a)*1.4f,0.26f});
            }
        }
        for (int i=0;i<56;++i) {
            const float base=(i%4==0)?-10.1f:(i%4==1)?-6.1f:(i%4==2)?6.1f:10.1f;
            const float x=base+std::sin(static_cast<float>(i)*1.71f)*0.82f;
            const float z=-22.0f+static_cast<float>(i/4)*3.15f;
            if (std::abs(z)<=24.0f && !(i%8<4 && z>0.0f))
                circles.push_back({x,z,0.21f});
        }
        const auto laneX=[](int lane,float z) {
            const float bend=std::sin((z+4.0f)*0.105f)*1.15f;
            return lane==0?-14.2f+bend:lane==1?0.5f+std::sin(z*0.12f)*0.72f:14.2f-bend*0.82f;
        };
        for (int team=0;team<2;++team) {
            const float sign=team==0?-1.0f:1.0f;
            boxes.push_back({0,sign*27.3f,2.6f,2.0f});
            boxes.push_back({-4.5f,sign*24.0f,1.25f,1.1f});
            boxes.push_back({4.5f,sign*24.0f,1.25f,1.1f});
            boxes.push_back({sign*8.0f,sign*25.3f,0.82f,0.82f});
            boxes.push_back({-7,sign*24.2f,2.6f,0.38f});
            boxes.push_back({7,sign*24.2f,2.6f,0.38f});
            for (int lane=0;lane<3;++lane) for (int tier=0;tier<3;++tier) {
                const float z=sign*(tier==0?8.0f:tier==1?15.0f:22.0f);
                circles.push_back({laneX(lane,z),z,0.62f});
            }
        }
    }
};
const Colliders &world(){static const Colliders c;return c;}

float riverZ(float x) {
    constexpr std::array<std::array<float,2>,12> p{{
        {{-34,1.1f}},{{-28,0.55f}},{{-21,0.05f}},{{-15,-0.45f}},
        {{-9,-0.22f}},{{-3,0.25f}},{{4,0.38f}},{{10,0.02f}},
        {{16,-0.38f}},{{23,-0.18f}},{{29,0.22f}},{{34,0.8f}}
    }};
    for(std::size_t i=0;i+1<p.size();++i) if(x<=p[i+1][0]) {
        const float t=std::clamp((x-p[i][0])/(p[i+1][0]-p[i][0]),0.0f,1.0f);
        return p[i][1]+(p[i+1][1]-p[i][1])*t;
    }
    return p.back()[1];
}
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
    const float west=2.35f*std::exp(-((x+24)*(x+24))/44.0f)*(0.58f+0.42f*std::cos(z*0.075f));
    const float east=2.18f*std::exp(-((x-24)*(x-24))/48.0f)*(0.58f+0.42f*std::cos(z*0.07f));
    const float south=1.55f*std::exp(-((z+27)*(z+27))/36.0f)*std::exp(-(x*x)/420.0f);
    const float north=1.55f*std::exp(-((z-27)*(z-27))/36.0f)*std::exp(-(x*x)/420.0f);
    const float ax=std::abs(x),az=std::abs(z);
    const float knoll=0.78f*std::exp(-((ax-8.5f)*(ax-8.5f))/8.5f)*std::exp(-((az-14)*(az-14))/42.0f);
    const float river=std::abs(z-riverZ(x));
    const float bed=-0.58f*std::exp(-(river*river)/8.5f);
    const float bank=0.72f*std::exp(-((river-2.55f)*(river-2.55f))/1.9f);
    const float rolling=0.26f*std::sin(x*0.18f)*std::cos(z*0.14f)+0.16f*std::sin((x+z)*0.29f);
    const float shelf=0.52f*std::exp(-((ax-18.5f)*(ax-18.5f))/5.5f)*std::exp(-((az-13)*(az-13))/110.0f);
    return rolling+west+east+south+north+knoll+bed+bank+shelf;
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
