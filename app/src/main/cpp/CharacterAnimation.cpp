#include "CharacterAnimation.h"
#include "third_party/cgltf.h"
#include <algorithm>
#include <cmath>
#include <functional>
#include <limits>
#include <utility>

namespace project_arena::animation {
namespace {
constexpr float kEpsilon=1.0e-6f;
bool finite(float v) noexcept { return std::isfinite(v); }
bool finite(const Vec4& v) noexcept { return finite(v.x)&&finite(v.y)&&finite(v.z)&&finite(v.w); }
Vec4 add(const Vec4&a,const Vec4&b) noexcept { return {a.x+b.x,a.y+b.y,a.z+b.z,a.w+b.w}; }
Vec4 mul(const Vec4&v,float s) noexcept { return {v.x*s,v.y*s,v.z*s,v.w*s}; }
float dot4(const Vec4&a,const Vec4&b) noexcept { return a.x*b.x+a.y*b.y+a.z*b.z+a.w*b.w; }
Vec4 normalizeQuat(const Vec4&q) noexcept {
    const float n=dot4(q,q);
    return (!finite(n)||n<=kEpsilon*kEpsilon)?Vec4{0,0,0,1}:mul(q,1.0f/std::sqrt(n));
}
Vec4 lerp(const Vec4&a,const Vec4&b,float t) noexcept { return add(mul(a,1.0f-t),mul(b,t)); }
Vec4 slerp(const Vec4&from,const Vec4&to,float t) noexcept {
    Vec4 a=normalizeQuat(from),b=normalizeQuat(to);
    float c=dot4(a,b);
    if(c<0){b=mul(b,-1);c=-c;}
    c=std::clamp(c,-1.0f,1.0f);
    if(c>0.9995f)return normalizeQuat(lerp(a,b,t));
    const float angle=std::acos(c),s=std::sin(angle);
    if(std::abs(s)<=kEpsilon)return a;
    return normalizeQuat(add(mul(a,std::sin((1-t)*angle)/s),mul(b,std::sin(t*angle)/s)));
}
Matrix4 multiplyMatrix(const Matrix4&a,const Matrix4&b) noexcept {
    Matrix4 out{};
    for(int c=0;c<4;c++)for(int r=0;r<4;r++)for(int k=0;k<4;k++)
        out[static_cast<std::size_t>(c*4+r)]+=a[static_cast<std::size_t>(k*4+r)]*b[static_cast<std::size_t>(c*4+k)];
    return out;
}
Matrix4 compose(const Transform&t) noexcept {
    const Vec4 q=normalizeQuat(t.rotation);
    const float x=q.x,y=q.y,z=q.z,w=q.w,sx=t.scale.x,sy=t.scale.y,sz=t.scale.z;
    Matrix4 m=identityMatrix();
    m[0]=(1-2*(y*y+z*z))*sx; m[1]=(2*(x*y+z*w))*sx; m[2]=(2*(x*z-y*w))*sx;
    m[4]=(2*(x*y-z*w))*sy; m[5]=(1-2*(x*x+z*z))*sy; m[6]=(2*(y*z+x*w))*sy;
    m[8]=(2*(x*z+y*w))*sz; m[9]=(2*(y*z-x*w))*sz; m[10]=(1-2*(x*x+y*y))*sz;
    m[12]=t.translation.x; m[13]=t.translation.y; m[14]=t.translation.z;
    return m;
}
bool invertMatrix(const Matrix4&in,Matrix4&out) noexcept {
    float a[4][8]{};
    for(int r=0;r<4;r++){for(int c=0;c<4;c++)a[r][c]=in[static_cast<std::size_t>(c*4+r)];a[r][r+4]=1;}
    for(int p=0;p<4;p++){
        int best=p;
        for(int r=p+1;r<4;r++)if(std::abs(a[r][p])>std::abs(a[best][p]))best=r;
        if(!finite(a[best][p])||std::abs(a[best][p])<=kEpsilon)return false;
        if(best!=p)for(int c=0;c<8;c++)std::swap(a[best][c],a[p][c]);
        const float d=a[p][p];for(int c=0;c<8;c++)a[p][c]/=d;
        for(int r=0;r<4;r++)if(r!=p){const float f=a[r][p];for(int c=0;c<8;c++)a[r][c]-=f*a[p][c];}
    }
    for(int r=0;r<4;r++)for(int c=0;c<4;c++)out[static_cast<std::size_t>(c*4+r)]=a[r][c+4];
    return true;
}
bool unpack(const cgltf_accessor*a,std::vector<float>&out) {
    if(!a)return false;
    const cgltf_size count=cgltf_accessor_unpack_floats(a,nullptr,0);
    if(count==0||count>4u*1024u*1024u)return false;
    out.resize(static_cast<std::size_t>(count));
    return cgltf_accessor_unpack_floats(a,out.data(),count)==count;
}
bool decodeBindPose(const cgltf_node&node,RigNode&out) {
    out.matrixBased=node.has_matrix!=0;
    cgltf_node_transform_local(&node,out.bindLocal.data());
    if(!finite(out.bindLocal[0])||!finite(out.bindLocal[5])||!finite(out.bindLocal[10])||
       !finite(out.bindLocal[12])||!finite(out.bindLocal[13])||!finite(out.bindLocal[14]))return false;
    if(!out.matrixBased){
        if(node.has_translation)out.bindPose.translation={node.translation[0],node.translation[1],node.translation[2],0};
        if(node.has_rotation)out.bindPose.rotation={node.rotation[0],node.rotation[1],node.rotation[2],node.rotation[3]};
        if(node.has_scale)out.bindPose.scale={node.scale[0],node.scale[1],node.scale[2],0};
    }
    return finite(out.bindPose.translation)&&finite(out.bindPose.rotation)&&finite(out.bindPose.scale);
}
} // namespace

Matrix4 identityMatrix() noexcept {
    Matrix4 m{};m[0]=m[5]=m[10]=m[15]=1;return m;
}
bool sampleTrack(const AnimationTrack&t,float time,Vec4&value) noexcept {
    if(t.keys.empty()||!finite(time))return false;
    if(time<=t.keys.front().time){value=t.keys.front().value;return finite(value);}
    if(time>=t.keys.back().time){value=t.keys.back().value;return finite(value);}
    const auto upper=std::upper_bound(t.keys.begin(),t.keys.end(),time,
        [](float v,const Keyframe&k){return v<k.time;});
    if(upper==t.keys.begin()||upper==t.keys.end())return false;
    const Keyframe&b=*upper;const Keyframe&a=*(upper-1);
    const float dt=b.time-a.time;if(!finite(dt)||dt<=kEpsilon)return false;
    const float u=std::clamp((time-a.time)/dt,0.0f,1.0f);
    if(t.interpolation==Interpolation::Step)value=a.value;
    else if(t.interpolation==Interpolation::Linear)
        value=t.path==TrackPath::Rotation?slerp(a.value,b.value,u):lerp(a.value,b.value,u);
    else {
        const float u2=u*u,u3=u2*u;
        value=add(add(mul(a.value,2*u3-3*u2+1),mul(a.outTangent,dt*(u3-2*u2+u))),
                  add(mul(b.value,-2*u3+3*u2),mul(b.inTangent,dt*(u3-u2))));
        if(t.path==TrackPath::Rotation)value=normalizeQuat(value);
    }
    return finite(value);
}
bool sampleClip(const AnimationClip&clip,const CharacterRig&rig,float time,bool loop,std::vector<Transform>&pose) {
    if(rig.nodes.empty()||!finite(time))return false;
    pose.resize(rig.nodes.size());
    for(std::size_t i=0;i<rig.nodes.size();i++)pose[i]=rig.nodes[i].bindPose;
    float t=time;
    if(loop&&finite(clip.duration)&&clip.duration>kEpsilon){t=std::fmod(t,clip.duration);if(t<0)t+=clip.duration;}
    else if(t<0)t=0;
    for(const auto&track:clip.tracks){
        if(track.nodeIndex>=rig.nodes.size()||rig.nodes[track.nodeIndex].matrixBased)return false;
        Vec4 v{};if(!sampleTrack(track,t,v))return false;
        auto&dst=pose[track.nodeIndex];
        switch(track.path){case TrackPath::Translation:dst.translation=v;break;case TrackPath::Rotation:dst.rotation=normalizeQuat(v);break;case TrackPath::Scale:dst.scale=v;break;}
    }
    return true;
}
bool buildJointPalette(const CharacterRig&rig,const std::vector<Transform>&pose,std::size_t meshNode,std::vector<Matrix4>&palette) {
    const std::size_t n=rig.nodes.size();
    if(n==0||pose.size()!=n||meshNode>=n||rig.joints.empty()||rig.joints.size()>kMaximumSkinJoints||rig.inverseBindMatrices.size()!=rig.joints.size())return false;
    std::vector<Matrix4>world(n);std::vector<std::uint8_t>state(n,0);
    std::function<bool(std::size_t)>visit=[&](std::size_t i){
        if(i>=n||state[i]==1)return false;if(state[i]==2)return true;state[i]=1;
        const auto&node=rig.nodes[i];if(node.parent < -1||node.parent>=static_cast<std::int32_t>(n))return false;
        const Matrix4 local=node.matrixBased?node.bindLocal:compose(pose[i]);
        if(node.parent>=0){const auto p=static_cast<std::size_t>(node.parent);if(!visit(p))return false;world[i]=multiplyMatrix(world[p],local);}
        else world[i]=local;
        state[i]=2;return true;
    };
    for(std::size_t i=0;i<n;i++)if(!visit(i))return false;
    Matrix4 invMesh{};if(!invertMatrix(world[meshNode],invMesh))return false;
    palette.resize(rig.joints.size());
    for(std::size_t i=0;i<rig.joints.size();i++){if(rig.joints[i]>=n)return false;palette[i]=multiplyMatrix(invMesh,multiplyMatrix(world[rig.joints[i]],rig.inverseBindMatrices[i]));}
    return true;
}
bool decodeCharacter(const cgltf_data*data,std::size_t skinIndex,CharacterRig&rig) {
    if(!data||!data->nodes||data->nodes_count==0||!data->skins||skinIndex>=data->skins_count||data->nodes_count>4096)return false;
    const cgltf_skin&skin=data->skins[skinIndex];
    if(!skin.joints||skin.joints_count==0||skin.joints_count>kMaximumSkinJoints)return false;
    CharacterRig decoded;decoded.nodes.resize(data->nodes_count);
    for(cgltf_size i=0;i<data->nodes_count;i++){
        const cgltf_node&node=data->nodes[i];auto&dst=decoded.nodes[static_cast<std::size_t>(i)];
        if(!decodeBindPose(node,dst))return false;
        if(node.parent){const cgltf_ssize p=node.parent-data->nodes;if(p<0||static_cast<cgltf_size>(p)>=data->nodes_count)return false;dst.parent=static_cast<std::int32_t>(p);}
    }
    for(cgltf_size i=0;i<skin.joints_count;i++){
        const cgltf_ssize j=skin.joints[i]-data->nodes;if(j<0||static_cast<cgltf_size>(j)>=data->nodes_count)return false;
        const auto index=static_cast<std::uint32_t>(j);
        if(std::find(decoded.joints.begin(),decoded.joints.end(),index)!=decoded.joints.end())return false;
        decoded.joints.push_back(index);
    }
    decoded.inverseBindMatrices.assign(skin.joints_count,identityMatrix());
    if(skin.inverse_bind_matrices){
        const auto*a=skin.inverse_bind_matrices;
        if(a->type!=cgltf_type_mat4||a->component_type!=cgltf_component_type_r_32f||a->count<skin.joints_count)return false;
        std::vector<float>values;if(!unpack(a,values)||values.size()<skin.joints_count*16u)return false;
        for(cgltf_size i=0;i<skin.joints_count;i++)std::copy_n(values.data()+i*16u,16u,decoded.inverseBindMatrices[static_cast<std::size_t>(i)].begin());
    }
    if(data->animations_count&&!data->animations)return false;
    for(cgltf_size ai=0;ai<data->animations_count;ai++){
        const auto&src=data->animations[ai];if(src.channels_count&&!src.channels)return false;
        AnimationClip clip;clip.name=src.name?src.name:"clip_"+std::to_string(ai);
        for(cgltf_size ci=0;ci<src.channels_count;ci++){
            const auto&ch=src.channels[ci];if(!ch.target_node||!ch.sampler)return false;
            TrackPath path;std::size_t comps=0;
            switch(ch.target_path){case cgltf_animation_path_type_translation:path=TrackPath::Translation;comps=3;break;case cgltf_animation_path_type_rotation:path=TrackPath::Rotation;comps=4;break;case cgltf_animation_path_type_scale:path=TrackPath::Scale;comps=3;break;case cgltf_animation_path_type_weights:continue;default:return false;}
            const cgltf_ssize nodeIndex=ch.target_node-data->nodes;
            if(nodeIndex<0||static_cast<cgltf_size>(nodeIndex)>=data->nodes_count||decoded.nodes[static_cast<std::size_t>(nodeIndex)].matrixBased)return false;
            const auto&s=*ch.sampler;AnimationTrack track;track.nodeIndex=static_cast<std::uint32_t>(nodeIndex);track.path=path;
            switch(s.interpolation){case cgltf_interpolation_type_step:track.interpolation=Interpolation::Step;break;case cgltf_interpolation_type_linear:track.interpolation=Interpolation::Linear;break;case cgltf_interpolation_type_cubic_spline:track.interpolation=Interpolation::CubicSpline;break;default:return false;}
            if(!s.input||!s.output||s.input->type!=cgltf_type_scalar||s.output->type!=(comps==4?cgltf_type_vec4:cgltf_type_vec3))return false;
            std::vector<float>times,values;if(!unpack(s.input,times)||!unpack(s.output,values))return false;
            const std::size_t factor=track.interpolation==Interpolation::CubicSpline?3u:1u;
            if(times.size()!=s.input->count||values.size()!=times.size()*comps*factor||times.empty())return false;
            float previous=-std::numeric_limits<float>::infinity();track.keys.reserve(times.size());
            for(std::size_t k=0;k<times.size();k++){
                if(!finite(times[k])||times[k]<0||times[k]<=previous)return false;previous=times[k];
                Keyframe key;key.time=times[k];
                auto read=[&](std::size_t sample,Vec4&v){const std::size_t o=sample*comps;v={values[o],comps>1?values[o+1]:0,comps>2?values[o+2]:0,comps>3?values[o+3]:0};return finite(v);};
                if(track.interpolation==Interpolation::CubicSpline){if(!read(k*3,key.inTangent)||!read(k*3+1,key.value)||!read(k*3+2,key.outTangent))return false;}
                else if(!read(k,key.value))return false;
                if(path==TrackPath::Rotation&&track.interpolation!=Interpolation::CubicSpline)key.value=normalizeQuat(key.value);
                track.keys.push_back(key);
            }
            clip.duration=std::max(clip.duration,track.keys.back().time);clip.tracks.push_back(std::move(track));
        }
        if(!clip.tracks.empty())decoded.clips.push_back(std::move(clip));
    }
    rig=std::move(decoded);return true;
}
bool decodeSkinInfluences(const cgltf_primitive&primitive,std::size_t jointCount,std::vector<SkinInfluence>&influences) {
    if(jointCount==0||jointCount>kMaximumSkinJoints)return false;
    const auto*j=cgltf_find_accessor(&primitive,cgltf_attribute_type_joints,0);
    const auto*w=cgltf_find_accessor(&primitive,cgltf_attribute_type_weights,0);
    if(!j||!w||j->type!=cgltf_type_vec4||w->type!=cgltf_type_vec4||j->count==0||j->count!=w->count||
       cgltf_find_accessor(&primitive,cgltf_attribute_type_joints,1)||cgltf_find_accessor(&primitive,cgltf_attribute_type_weights,1))return false;
    std::vector<float>jv,wv;if(!unpack(j,jv)||!unpack(w,wv)||jv.size()!=j->count*4u||wv.size()!=w->count*4u)return false;
    std::vector<SkinInfluence>decoded(j->count);
    for(cgltf_size i=0;i<j->count;i++){
        auto&inf=decoded[static_cast<std::size_t>(i)];float sum=0;
        for(std::size_t c=0;c<4;c++){
            const float raw=jv[i*4u+c],weight=wv[i*4u+c];
            if(!finite(raw)||raw<0||raw>=static_cast<float>(jointCount)||!finite(weight)||weight<0)return false;
            inf.joints[c]=static_cast<std::uint16_t>(std::lround(raw));
            if(std::abs(raw-static_cast<float>(inf.joints[c]))>0.001f)return false;
            switch(c){case 0:inf.weights.x=weight;break;case 1:inf.weights.y=weight;break;case 2:inf.weights.z=weight;break;default:inf.weights.w=weight;break;}
            sum+=weight;
        }
        if(sum<=kEpsilon){inf.joints={{0,0,0,0}};inf.weights={1,0,0,0};}
        else inf.weights=mul(inf.weights,1.0f/sum);
    }
    influences=std::move(decoded);return true;
}
} // namespace project_arena::animation
