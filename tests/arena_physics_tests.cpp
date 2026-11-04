#include "../app/src/main/cpp/ArenaPhysics.h"
#include "../app/src/main/cpp/ArenaMapDefinition.h"
#include "../app/src/main/cpp/ArenaWorld17Generated.h"
#include "../app/src/main/cpp/ArenaNavigation.h"
#include "../app/src/main/cpp/ArenaCampCombat.h"
#include <algorithm>
#include <cassert>
#include <cmath>
#include <iostream>
namespace {
float distance(float ax,float az,float bx,float bz){const float x=bx-ax,z=bz-az;return std::sqrt(x*x+z*z);}
int node(std::string_view id){return arena_navigation::nodeIndex(id);}
void testGeneratedArenaWorld17Contract(){
 using namespace arena_world_17;
 assert(kWorldId=="project_arena_1_7");assert(kHalfWidthM==90.0f&&kHalfDepthM==80.0f);
 assert(kTerrainVerticesX==193&&kTerrainVerticesZ==177);assert(kLanes.size()==3&&kLanes[0].waypoints.size()==8);
 assert(kRiver.size()==13&&kCrossings.size()==3&&kJungles.size()==2);
 assert(kCamps.size()==12&&kObjectives.size()==2);assert(kNavigationNodes.size()==17&&kNavigationLinks.size()==26);
 assert(kTowerDepthsFromBase[0]==18.0f&&kTowerDepthsFromBase[2]==58.0f);
 for(const auto &lane:kLanes){assert(lane.width>=9.5f&&lane.width<=10.0f);
  for(const auto &point:lane.waypoints)assert(std::abs(point.x)<=kHalfWidthM&&std::abs(point.z)<=kHalfDepthM);}
 for(const auto &river:kRiver)assert(river.halfWidth>=4.5f&&river.halfWidth<=8.5f);
 for(const auto &camp:kCamps)assert(std::abs(camp.position.x)<kHalfWidthM&&std::abs(camp.position.z)<kHalfDepthM);
}
void testNeutralCampCombatRules(){
 assert(arena_camp::canAggro(180.0f,7.0f,12.0f,10.0f));assert(!arena_camp::canAggro(0.0f,1.0f,12.0f,10.0f));
 assert(!arena_camp::canAggro(180.0f,10.5f,12.0f,10.0f));assert(arena_camp::canStrike(180.0f,0.0f,2.2f,2.8f,10.0f));
 assert(!arena_camp::canStrike(180.0f,0.1f,2.2f,2.8f,10.0f));assert(!arena_camp::canStrike(180.0f,0.0f,3.2f,2.8f,10.0f));
 assert(!arena_camp::canStrike(0.0f,0.0f,1.0f,2.8f,10.0f));assert(!arena_camp::canStrike(180.0f,0.0f,1.0f,2.8f,0.8f));
}
void testArenaNavigationGraph(){
 const auto &graph=arena_navigation::mapGraph();assert(graph.nodes.size()==static_cast<std::size_t>(arena_navigation::kNodeCount));
 for(int index=0;index<arena_navigation::kNodeCount;++index){
  const auto &entry=graph.nodes[static_cast<std::size_t>(index)];assert(entry.neighborCount>0);
  for(int edge=0;edge<entry.neighborCount;++edge){
   const int neighbor=entry.neighbors[static_cast<std::size_t>(edge)];assert(neighbor>=0&&neighbor<arena_navigation::kNodeCount);
   const auto &other=graph.nodes[static_cast<std::size_t>(neighbor)];bool reciprocal=false;
   for(int reverse=0;reverse<other.neighborCount;++reverse)if(other.neighbors[static_cast<std::size_t>(reverse)]==index)reciprocal=true;
   assert(reciprocal);
  }
 }
 const int westSouth=node("west_south"),westJungleSouth=node("west_jungle_south");
 const int westJungleNorth=node("west_jungle_north"),westObjective=node("west_objective");
 assert(westSouth>=0&&westJungleSouth>=0&&westJungleNorth>=0&&westObjective>=0);
 const auto start=graph.nodes[static_cast<std::size_t>(westSouth)].position;
 const auto destination=graph.nodes[static_cast<std::size_t>(westJungleNorth)].position;
 const auto first=arena_navigation::nextWaypoint(start,destination);bool firstIsNeighbor=false;
 const auto &startNode=graph.nodes[static_cast<std::size_t>(westSouth)];
 for(int edge=0;edge<startNode.neighborCount;++edge){
  const auto candidate=graph.nodes[static_cast<std::size_t>(startNode.neighbors[static_cast<std::size_t>(edge)])].position;
  if(distance(first.x,first.z,candidate.x,candidate.z)<0.001f)firstIsNeighbor=true;
 }
 assert(firstIsNeighbor);
 const auto camp=graph.nodes[static_cast<std::size_t>(westJungleSouth)].position;
 const auto objective=graph.nodes[static_cast<std::size_t>(westObjective)].position;
 const auto objectiveStep=arena_navigation::nextWaypoint(camp,objective);
 assert(std::isfinite(objectiveStep.x)&&std::isfinite(objectiveStep.z));
 assert(distance(objectiveStep.x,objectiveStep.z,objective.x,objective.z)<0.001f);
 const auto shortStep=arena_navigation::nextWaypoint({objective.x+1.0f,objective.z},objective);
 assert(distance(shortStep.x,shortStep.z,objective.x,objective.z)<0.0001f);
}
void testSharedArenaMapCatalog(){
 assert(arena_map::kWorldScale==1.0f&&arena_map::kHalfExtentX==90.0f&&arena_map::kHalfExtentZ==80.0f);
 assert(arena_map::kLanes.size()==3&&arena_map::kCampPositions.size()==12);
 assert(arena_map::kObjectivePositions.size()==2&&arena_map::kRiverCenterline.size()==13);
 assert(arena_map::kGroveCenters.size()==12&&arena_map::kTreeBlockers.size()==24);
 float minimumRiverWidth=100.0f,maximumRiverWidth=0.0f;
 for(const auto &point:arena_map::kRiverCenterline){
  assert(std::abs(point.x)<arena_map::kHalfExtentX&&std::abs(point.z)<arena_map::kHalfExtentZ);
  assert(point.halfWidth>=4.5f&&point.halfWidth<=8.5f);
  minimumRiverWidth=std::min(minimumRiverWidth,point.halfWidth);maximumRiverWidth=std::max(maximumRiverWidth,point.halfWidth);
 }
 assert(maximumRiverWidth-minimumRiverWidth>1.0f);
 assert(std::isfinite(arena_map::riverCenterZ(-15.0f))&&arena_map::riverHalfWidth(-15.0f)>=4.5f);
 for(std::size_t lane=0;lane<arena_map::kLanes.size();++lane){
  const auto &points=arena_map::kLanes[lane].points;assert(points.size()==8);
  for(std::size_t i=0;i<points.size();++i){
   assert(std::abs(arena_map::laneCenterX(static_cast<int>(lane),points[i].z)-points[i].x)<0.0001f);
   if(i>0)assert(points[i].z>points[i-1].z);
  }
 }
 for(const auto &camp:arena_map::kCampPositions)assert(std::abs(camp.x)<90.0f&&std::abs(camp.z)<80.0f);
 for(const auto &tree:arena_map::kTreeBlockers)assert(std::abs(tree.x)<90.0f&&std::abs(tree.z)<80.0f);
 for(int lane=0;lane<3;++lane)for(int tier=0;tier<3;++tier){
  const auto blue=arena_map::towerPosition(0,lane,tier),red=arena_map::towerPosition(1,lane,tier);
  assert(std::abs(arena_map::laneCenterX(lane,blue.z)-blue.x)<0.001f);
  assert(std::abs(arena_map::laneCenterX(lane,red.z)-red.x)<0.001f);
  assert(std::abs(blue.x)<=90.0f&&std::abs(blue.z)<=80.0f);
  assert(std::abs(red.x)<=90.0f&&std::abs(red.z)<=80.0f);
 }
}
void testTerrainSurface(){
 float low=100.0f,high=-100.0f,maxSlope=0.0f;
 for(float x=-87.0f;x<=87.0f;x+=3.0f)for(float z=-77.0f;z<=77.0f;z+=3.0f){
  const float height=arena_physics::terrainHeight(x,z),slope=arena_physics::terrainSlope(x,z);
  assert(std::isfinite(height)&&std::isfinite(slope));
  assert(height>=arena_world_17::kMinHeightM-0.001f&&height<=arena_world_17::kMaxHeightM+0.001f);
  low=std::min(low,height);high=std::max(high,height);maxSlope=std::max(maxSlope,slope);
 }
 assert(high-low>3.2f);assert(maxSlope<std::tan(55.0f*3.14159265f/180.0f));
 for(const auto &lane:arena_world_17::kLanes)for(const auto &point:lane.waypoints)
  assert(arena_physics::terrainSlope(point.x,point.z)<std::tan(43.0f*3.14159265f/180.0f));
}
void testTreeCollisionAndSliding(){
 const auto &tree=arena_map::kTreeBlockers.front();arena_physics::Body body{tree.x-3.0f,tree.z,0.0f,0.0f,0.43f};
 for(int i=0;i<120;++i)arena_physics::move(body,3.0f,0.0f,1.0f/60.0f);
 assert(distance(body.x,body.z,tree.x,tree.z)>=1.19f);assert(std::isfinite(body.x)&&std::isfinite(body.z));
}
void testStructureCollision(){
 const auto tower=arena_map::towerPosition(1,1,2);arena_physics::Body body{tower.x,tower.z-5.0f,0.0f,0.0f,0.43f};
 for(int i=0;i<180;++i)arena_physics::move(body,0.0f,4.0f,1.0f/60.0f);
 assert(distance(body.x,body.z,tower.x,tower.z)>=1.54f);
}
void testWorldBoundary(){
 arena_physics::Body body{108.0f,0.0f,0.0f,0.0f,0.45f};arena_physics::resolveWorld(body);
 assert(std::abs(body.x)<92.0f);
}
void testBraking(){
 arena_physics::Body body{0.0f,-5.0f,0.0f,0.0f,0.35f};
 for(int i=0;i<30;++i)arena_physics::move(body,3.0f,0.0f,1.0f/60.0f);
 for(int i=0;i<90;++i)arena_physics::move(body,0.0f,0.0f,1.0f/60.0f);
 assert(std::sqrt(body.vx*body.vx+body.vz*body.vz)<0.15f);
}
void testCampGuardianCollision(){
 const auto &camp=arena_map::kCampPositions[0];arena_physics::Body body{camp.x-1.8f,camp.z,0.0f,0.0f,0.43f};
 for(int i=0;i<120;++i)arena_physics::move(body,3.0f,0.0f,1.0f/60.0f);
 assert(distance(body.x,body.z,camp.x,camp.z)>=1.24f);
}
void testObstacleSteering(){
 const auto &tree=arena_map::kTreeBlockers.front();arena_physics::Body body{tree.x-2.0f,tree.z,0.0f,0.0f,0.43f};
 float desiredX=3.0f,desiredZ=0.0f;arena_physics::avoidObstacles(body,desiredX,desiredZ);
 assert(desiredX>0.0f&&std::abs(desiredZ)>0.1f);
 assert(std::abs(std::sqrt(desiredX*desiredX+desiredZ*desiredZ)-3.0f)<0.001f);
}
void testCharacterSeparation(){
 arena_physics::Body a{0.0f,-5.0f,2.0f,0.0f,0.43f},b{0.2f,-5.0f,0.0f,0.0f,0.38f};
 arena_physics::separate(a,b);assert(distance(a.x,a.z,b.x,b.z)>=a.radius+b.radius-0.001f);
}
}
int main(){
 testGeneratedArenaWorld17Contract();testNeutralCampCombatRules();testArenaNavigationGraph();
 testSharedArenaMapCatalog();testTerrainSurface();testTreeCollisionAndSliding();
 testStructureCollision();testWorldBoundary();testBraking();testObstacleSteering();
 testCampGuardianCollision();testCharacterSeparation();
 std::cout<<"Arena v1.7 world contract/terrain/physics/navigation tests passed.\n";return 0;
}
