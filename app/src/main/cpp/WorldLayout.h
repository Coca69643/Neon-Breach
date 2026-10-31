#pragma once
#include <array>
#include <cstddef>
namespace neonbreach {
inline constexpr std::size_t kRoomCount=4;
inline constexpr float kRoomHalfExtent=10.0f;
// Effective horizontal capsule radius (0.29 m shape radius + Jolt contact padding, rounded up).
inline constexpr float kPlayerCollisionRadius=0.33f;
inline constexpr float kGateHalfThickness=0.20f;
inline constexpr float kDoorwayHalfSpan=2.10f;
inline constexpr float kRoomTransitionOffset=kPlayerCollisionRadius+kGateHalfThickness+0.16f;
inline constexpr float kStairsOffsetX=-4.4f;
inline constexpr float kStairsOffsetZ=-3.2f;
inline constexpr float kStairsFootprintHalfExtent=0.90f;
inline constexpr float kStairsCollisionHalfHeight=0.55f;
inline constexpr float kStairsVisualScale=0.34f;
inline constexpr std::array<float,kRoomCount> kRoomCenterX{{0.0f,20.0f,20.0f,0.0f}};
inline constexpr std::array<float,kRoomCount> kRoomCenterZ{{0.0f,0.0f,20.0f,20.0f}};
struct RoomLink { int from=0,to=0,axis=0,fromSide=1,toSide=-1; float plane=0.0f,crossCenter=0.0f,halfSpan=kDoorwayHalfSpan; bool open=false; };
inline constexpr std::array<RoomLink,kRoomCount> kFacilityRoomLinks{{
 {0,1,0, 1,-1,10.0f, 0.0f,kDoorwayHalfSpan,false},
 {1,2,1, 1,-1,10.0f,20.0f,kDoorwayHalfSpan,false},
 {2,3,0,-1, 1,10.0f,16.0f,kDoorwayHalfSpan,false},
 {3,0,1,-1, 1,10.0f, 0.0f,kDoorwayHalfSpan,false}
}};
} // namespace neonbreach
