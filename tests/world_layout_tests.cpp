#include "WorldLayout.h"
#include <array>
#include <cassert>
#include <cmath>
#include <queue>
namespace {
bool near(float a,float b){return std::abs(a-b)<=0.001f;}
void testRoomLinksMeetTheirRoomEdges(){
 for(const auto &link:neonbreach::kFacilityRoomLinks){
  assert(link.from>=0&&link.from<static_cast<int>(neonbreach::kRoomCount));
  assert(link.to>=0&&link.to<static_cast<int>(neonbreach::kRoomCount));
  assert(link.from!=link.to&&link.axis>=0&&link.axis<=1);
  assert(link.fromSide==-link.toSide);
  assert(link.halfSpan>neonbreach::kPlayerCollisionRadius+0.5f);
  if(link.axis==0){
   assert(near(neonbreach::kRoomCenterX[link.from]+link.fromSide*neonbreach::kRoomHalfExtent,link.plane));
   assert(near(neonbreach::kRoomCenterX[link.to]+link.toSide*neonbreach::kRoomHalfExtent,link.plane));
   assert(std::abs(link.crossCenter-neonbreach::kRoomCenterZ[link.from])+link.halfSpan<=neonbreach::kRoomHalfExtent);
   assert(std::abs(link.crossCenter-neonbreach::kRoomCenterZ[link.to])+link.halfSpan<=neonbreach::kRoomHalfExtent);
  }else{
   assert(near(neonbreach::kRoomCenterZ[link.from]+link.fromSide*neonbreach::kRoomHalfExtent,link.plane));
   assert(near(neonbreach::kRoomCenterZ[link.to]+link.toSide*neonbreach::kRoomHalfExtent,link.plane));
   assert(std::abs(link.crossCenter-neonbreach::kRoomCenterX[link.from])+link.halfSpan<=neonbreach::kRoomHalfExtent);
   assert(std::abs(link.crossCenter-neonbreach::kRoomCenterX[link.to])+link.halfSpan<=neonbreach::kRoomHalfExtent);
  }
 }
}
void testFacilityGraphConnected(){
 std::array<bool,neonbreach::kRoomCount> visited{};
 std::queue<int> pending;pending.push(0);visited[0]=true;
 while(!pending.empty()){
  const int current=pending.front();pending.pop();
  for(const auto &link:neonbreach::kFacilityRoomLinks){
   int next=-1;if(link.from==current)next=link.to;else if(link.to==current)next=link.from;
   if(next>=0&&!visited[static_cast<std::size_t>(next)]){visited[static_cast<std::size_t>(next)]=true;pending.push(next);}
  }
 }
 for(bool value:visited)assert(value);
}
void testGateTransitionHasClearance(){
 assert(neonbreach::kRoomTransitionOffset>neonbreach::kPlayerCollisionRadius+neonbreach::kGateHalfThickness);
 assert(neonbreach::kDoorwayHalfSpan>neonbreach::kPlayerCollisionRadius+1.0f);
}
}
int main(){testRoomLinksMeetTheirRoomEdges();testFacilityGraphConnected();testGateTransitionHasClearance();return 0;}
