#define CGLTF_IMPLEMENTATION
#include "third_party/cgltf.h"
#include "CharacterAnimation.h"
#include <cassert>
#include <cmath>
#include <vector>
using namespace project_arena::animation;
namespace {
bool near(float a,float b,float e=1.0e-3f){return std::abs(a-b)<=e;}
void linearAndStep(){
    AnimationTrack t;t.path=TrackPath::Translation;t.keys={{0,{}, {0,0,0,0},{}},{1,{}, {2,4,6,0},{}}};
    Vec4 v{};assert(sampleTrack(t,0.5f,v));assert(near(v.x,1)&&near(v.y,2)&&near(v.z,3));
    t.interpolation=Interpolation::Step;assert(sampleTrack(t,0.75f,v));assert(near(v.x,0)&&near(v.y,0));
}
void rotationSlerp(){
    AnimationTrack t;t.path=TrackPath::Rotation;t.keys={{0,{}, {0,0,0,1},{}},{1,{}, {0,0,1,0},{}}};
    Vec4 v{};assert(sampleTrack(t,0.5f,v));assert(near(v.z,std::sqrt(0.5f),0.002f));assert(near(v.w,std::sqrt(0.5f),0.002f));
}
void cubicSpline(){
    AnimationTrack t;t.interpolation=Interpolation::CubicSpline;
    t.keys={{0,{0,0,0,0},{0,0,0,0},{1,0,0,0}},{1,{-1,0,0,0},{1,0,0,0},{0,0,0,0}}};
    Vec4 v{};assert(sampleTrack(t,0.5f,v));assert(near(v.x,0.75f));
    t.path=TrackPath::Rotation;t.keys[0].value={0,0,0,1};t.keys[1].value={0,0,1,0};
    t.keys[0].outTangent={};t.keys[1].inTangent={};
    assert(sampleTrack(t,0.5f,v));
    assert(near(std::sqrt(v.x*v.x+v.y*v.y+v.z*v.z+v.w*v.w),1.0f));
}
void clipRestAndLoop(){
    CharacterRig rig;rig.nodes.resize(1);rig.nodes[0].bindPose.translation={4,0,0,0};
    AnimationClip clip;clip.duration=1;AnimationTrack t;t.nodeIndex=0;t.path=TrackPath::Translation;
    t.keys={{0,{}, {0,0,0,0},{}},{1,{}, {1,0,0,0},{}}};clip.tracks.push_back(t);
    std::vector<Transform>pose;assert(sampleClip(clip,rig,1.25f,true,pose));
    assert(pose.size()==1&&near(pose[0].translation.x,0.25f));
    assert(sampleClip(AnimationClip{},rig,0,false,pose));assert(near(pose[0].translation.x,4));
}
void jointPalette(){
    CharacterRig rig;rig.nodes.resize(2);rig.nodes[0].bindPose.translation={1,0,0,0};
    rig.nodes[1].parent=0;rig.nodes[1].bindPose.translation={0,2,0,0};
    rig.joints={0,1};rig.inverseBindMatrices={identityMatrix(),identityMatrix()};
    std::vector<Transform>pose{rig.nodes[0].bindPose,rig.nodes[1].bindPose};std::vector<Matrix4>palette;
    assert(buildJointPalette(rig,pose,0,palette));assert(palette.size()==2);
    assert(near(palette[0][12],0)&&near(palette[0][13],0));
    assert(near(palette[1][12],0)&&near(palette[1][13],2));
}
void decodeSkinNodes(){
    cgltf_node nodes[2]{};nodes[1].parent=&nodes[0];nodes[0].has_translation=1;nodes[0].translation[0]=1.5f;
    cgltf_node*joints[2]={&nodes[0],&nodes[1]};cgltf_skin skin{};skin.joints=joints;skin.joints_count=2;
    cgltf_skin skins[1]={skin};cgltf_data data{};data.nodes=nodes;data.nodes_count=2;data.skins=skins;data.skins_count=1;
    CharacterRig rig;assert(decodeCharacter(&data,0,rig));assert(rig.nodes.size()==2&&rig.joints.size()==2);
    assert(rig.nodes[1].parent==0&&near(rig.nodes[0].bindPose.translation.x,1.5f));
    assert(rig.inverseBindMatrices.size()==2);
}
void rejectHierarchyCycle(){
    CharacterRig rig;rig.nodes.resize(1);rig.nodes[0].parent=0;rig.joints={0};rig.inverseBindMatrices={identityMatrix()};
    std::vector<Transform>pose(1);std::vector<Matrix4>palette;assert(!buildJointPalette(rig,pose,0,palette));
}
}
int main(){linearAndStep();rotationSlerp();cubicSpline();clipRestAndLoop();jointPalette();decodeSkinNodes();rejectHierarchyCycle();return 0;}
