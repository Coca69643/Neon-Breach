#pragma once
#include <array>
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

struct cgltf_data;
struct cgltf_primitive;

namespace project_arena::animation {
constexpr std::size_t kMaximumSkinJoints = 128;
struct Vec4 { float x=0, y=0, z=0, w=0; };
using Matrix4 = std::array<float,16>;
enum class TrackPath : std::uint8_t { Translation, Rotation, Scale };
enum class Interpolation : std::uint8_t { Linear, Step, CubicSpline };
struct Transform {
    Vec4 translation{0,0,0,0};
    Vec4 rotation{0,0,0,1};
    Vec4 scale{1,1,1,0};
};
struct RigNode {
    std::int32_t parent=-1;
    Transform bindPose{};
    Matrix4 bindLocal{};
    bool matrixBased=false;
};
struct Keyframe { float time=0; Vec4 inTangent{}, value{}, outTangent{}; };
struct AnimationTrack {
    std::uint32_t nodeIndex=0;
    TrackPath path=TrackPath::Translation;
    Interpolation interpolation=Interpolation::Linear;
    std::vector<Keyframe> keys;
};
struct AnimationClip { std::string name; float duration=0; std::vector<AnimationTrack> tracks; };
struct SkinInfluence {
    std::array<std::uint16_t,4> joints{{0,0,0,0}};
    Vec4 weights{1,0,0,0};
};
struct CharacterRig {
    std::vector<RigNode> nodes;
    std::vector<std::uint32_t> joints;
    std::vector<Matrix4> inverseBindMatrices;
    std::vector<AnimationClip> clips;
};

Matrix4 identityMatrix() noexcept;
bool sampleTrack(const AnimationTrack& track, float time, Vec4& value) noexcept;
bool sampleClip(const AnimationClip& clip, const CharacterRig& rig, float time,
                bool loop, std::vector<Transform>& pose);
bool buildJointPalette(const CharacterRig& rig, const std::vector<Transform>& pose,
                       std::size_t meshNodeIndex, std::vector<Matrix4>& palette);
// Call only after cgltf_load_buffers() succeeds. Supports four JOINTS_0/WEIGHTS_0 influences.
bool decodeCharacter(const cgltf_data* data, std::size_t skinIndex, CharacterRig& rig);
bool decodeSkinInfluences(const cgltf_primitive& primitive, std::size_t jointCount,
                          std::vector<SkinInfluence>& influences);
} // namespace project_arena::animation
