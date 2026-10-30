#include <jni.h>
#include "ProgressionManager.h"
#include <GLES3/gl3.h>
#include <android/log.h>
#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstddef>
#include <random>
#include <vector>

namespace {
constexpr float PI = 3.14159265358979323846f;
struct V3 { float x, y, z; };
struct Mat4 { float v[16]; };
struct Vertex { float px, py, pz, nx, ny, nz; };
struct Mesh { GLuint vao=0, vbo=0; GLsizei count=0; };
struct Obstacle { float x,z,sx,sz,h; };
constexpr int ROOM_COUNT=4;
constexpr float ROOM_WIDTH=12.0f, ROOM_HALF_WIDTH=6.0f, ROOM_HALF_DEPTH=4.5f;
constexpr float ROOM_DOOR_HALF_WIDTH=1.19f;
struct Room {
  float centerX=0.0f,minX=0.0f,maxX=0.0f,minZ=-ROOM_HALF_DEPTH,maxZ=ROOM_HALF_DEPTH;
  int wavesTotal=1,wavesSpawned=0;
  bool visited=false,cleared=false,doorOpen=false;
  std::array<Obstacle,4> cover{};
};
struct Enemy { float x,z,hp,maxHp,speed,radius; int type; float yaw; };
struct Shot { float x,y,z,vx,vz,life; bool hostile=false; float damage=1.0f; };
struct ProjectileInstance { float x,y,z,radius,r,g,b,glow; };

GLuint program=0, fallbackProgram=0, fallbackVao=0;
GLint sectorPaletteLoc=-1, activeRoomLoc=-1;
neonbreach::ProgressionManager progression;
std::array<Room,ROOM_COUNT> rooms{};
int activeRoom=0;
bool roomWorldInitialized=false;
int activeWave=0;
float touchSensitivity=1.0f;
bool nativeSoundEnabled=true;
GLuint postProgram=0, postVao=0, sceneFramebuffer=0, sceneColorTexture=0, sceneDepthBuffer=0;
GLuint projectileProgram=0, projectileVao=0, projectileQuadVbo=0, projectileIndexBuffer=0, projectileInstanceVbo=0;
GLint mvpLoc=-1, modelLoc=-1, colorLoc=-1, glowLoc=-1, cameraLoc=-1;
GLint fallbackResLoc=-1, postSceneLoc=-1, postResolutionLoc=-1;
GLint projectileViewLoc=-1, projectileProjectionLoc=-1;
int sceneTargetW=0, sceneTargetH=0;
Mesh cubeMesh, sphereMesh, organicMesh;
int screenW=1, screenH=1;
float playerX=-5.15f, playerZ=-3.25f, playerHealth=1.0f;
float moveOriginX=0, moveOriginY=0, moveX=0, moveY=0;
bool moving=false, aiming=false, firing=false;
float aimX=-5.15f, aimZ=-8.25f, aimOriginX=0.0f, aimOriginY=0.0f, shotCooldown=0.0f;
float facingYaw=PI, moveDirX=0.0f, moveDirZ=-1.0f;
float dodgeTime=0.0f, dodgeCooldown=0.0f, dodgeDirX=0.0f, dodgeDirZ=-1.0f;
float elapsed=0.0f, accumulator=0.0f, visualTime=0.0f;
float cameraFocusX=0.0f, cameraFocusZ=0.0f;
float cameraVelocityX=0.0f, cameraVelocityZ=0.0f;
float cameraShakeAmplitude=0.0f, cameraShakeDecay=0.10f;
float cameraShakeOffsetX=0.0f, cameraShakeOffsetY=0.0f;
float playerSquashAge=0.15f;
bool playerSquashActive=false;
int missionSerial=0, arenaVariant=0;
int operativeClass=0; // 0 Neon-Vanguard, 1 Stellar-Reaper
std::array<float,4> enemyShotCooldown{};
std::array<float,4> enemyWindup{};
std::array<float,4> enemyAttackCooldown{};
std::array<float,4> enemyReactionTimer{};
std::array<float,4> enemyThinkInterval{};
std::array<float,4> enemySlalomPhase{};
std::array<float,4> enemySlalomFrequency{};
std::array<float,4> enemySlalomStrength{};
std::array<float,4> enemySteerX{};
std::array<float,4> enemySteerZ{};
std::array<float,4> enemyMoveScale{1.0f,1.0f,1.0f,1.0f};
std::mt19937 aiRandomEngine{std::random_device{}()};
std::uniform_real_distribution<float> aiUnitDistribution{0.0f,1.0f};
float randomRange(float minimum,float maximum){return minimum+(maximum-minimum)*aiUnitDistribution(aiRandomEngine);}
bool won=false, lost=false;
int defeated=0;
int gameMode=0; // 0 menu, 1 playing, 2 pause, 3 settings, 4 victory, 5 defeat, 6 suspended menu
int relayMask=0;
std::atomic<int> publishedSnapshot{0};
std::chrono::steady_clock::time_point previousFrame=std::chrono::steady_clock::now();
std::array<Shot,18> shots{};
std::array<Enemy,4> enemies{{
  {-3.85f,2.95f,1.0f,1.0f,1.10f,0.36f,0,PI},
  {0.85f,2.90f,2.0f,2.0f,0.72f,0.48f,1,PI},
  {3.90f,0.15f,1.0f,1.0f,1.35f,0.31f,2,PI},
  {-1.45f,-2.45f,1.0f,1.0f,1.62f,0.31f,3,PI}
}};
constexpr std::array<Obstacle,4> ARENA_LAYOUT_A{{
  {-2.95f,0.15f,1.05f,0.78f,0.62f},
  {-0.45f,2.00f,0.92f,0.70f,0.72f},
  { 2.20f,0.10f,1.08f,0.84f,0.58f},
  { 1.65f,-2.72f,0.88f,1.00f,0.65f}
}};
std::array<Obstacle,4> obstacles=ARENA_LAYOUT_A;
constexpr std::array<Obstacle,4> ARENA_LAYOUT_B{{
  {-2.55f,-0.40f,1.12f,0.76f,0.70f},
  {-0.85f,2.45f,0.86f,0.82f,0.62f},
  {1.48f,0.30f,1.18f,0.72f,0.78f},
  {3.45f,-2.30f,0.92f,0.84f,0.58f}
}};
constexpr std::array<Obstacle,4> ARENA_LAYOUT_C{{
  {-3.15f,0.65f,0.86f,1.10f,0.76f},
  {-1.10f,2.35f,1.16f,0.72f,0.60f},
  {0.95f,-0.90f,1.14f,0.82f,0.68f},
  {3.25f,1.35f,0.94f,0.90f,0.72f}
}};
constexpr float RELAY_X[3]={-4.15f,0.05f,4.22f};
constexpr float RELAY_Z[3]={2.65f,-0.55f,2.35f};
constexpr float EXIT_X=5.15f;
constexpr float EXIT_Z=-3.52f;
constexpr int TOTAL_MISSION_ELIMINATIONS=24;
float activeExtractionX(){return rooms[3].centerX+4.15f;}
float activeExtractionZ(){return -3.05f;}
constexpr float POD_X[2]={-2.95f,3.55f};
constexpr float POD_Z[2]={-3.32f,0.10f};
constexpr float HAZARD_X[2]={-1.20f,3.85f};
constexpr float HAZARD_Z[2]={-1.55f,-1.35f};
std::array<bool,2> podCollected{{false,false}};
std::array<float,2> hazardCooldown{{0.0f,0.0f}};
float operativeMoveSpeed(){return operativeClass==1?5.10f:4.25f;}
float operativeFireInterval(){return operativeClass==1?0.18f:0.15f;}
float operativeShotDamage(){return 1.0f;}
float operativeDamageTakenMultiplier(){return 1.0f;}
float operativeDodgeCooldown(){return operativeClass==1?0.98f:0.88f;}
float operativeMedicalHeal(){return 0.24f;}
float operativeRelayInteractionRadius(){return 1.25f;}
void triggerCameraShake(float impulse,float decay){
  if(impulse>=cameraShakeAmplitude)cameraShakeDecay=std::max(0.035f,decay);
  cameraShakeAmplitude=std::max(cameraShakeAmplitude,impulse);
}
void triggerPlayerShotFeedback(){
  playerSquashAge=0.0f;
  playerSquashActive=true;
  triggerCameraShake(0.026f,0.085f);
}
void hurtPlayer(float amount){
  const float previousHealth=playerHealth;
  playerHealth=std::max(0.0f,playerHealth-amount*operativeDamageTakenMultiplier());
  if(playerHealth<previousHealth)triggerCameraShake(0.13f,0.19f);
}

V3 add(V3 a,V3 b){return {a.x+b.x,a.y+b.y,a.z+b.z};}
V3 sub(V3 a,V3 b){return {a.x-b.x,a.y-b.y,a.z-b.z};}
V3 mul(V3 a,float s){return {a.x*s,a.y*s,a.z*s};}
float dot(V3 a,V3 b){return a.x*b.x+a.y*b.y+a.z*b.z;}
V3 cross(V3 a,V3 b){return {a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x};}
V3 norm(V3 a){float d=std::sqrt(std::max(1e-9f,dot(a,a)));return mul(a,1.0f/d);}
Mat4 identity(){Mat4 m{};m.v[0]=m.v[5]=m.v[10]=m.v[15]=1.0f;return m;}
Mat4 multiply(const Mat4&a,const Mat4&b){
  Mat4 o{};
  for(int c=0;c<4;c++)for(int r=0;r<4;r++)
    for(int k=0;k<4;k++)o.v[c*4+r]+=a.v[k*4+r]*b.v[c*4+k];
  return o;
}
Mat4 translate(float x,float y,float z){Mat4 m=identity();m.v[12]=x;m.v[13]=y;m.v[14]=z;return m;}
Mat4 scale(float x,float y,float z){Mat4 m=identity();m.v[0]=x;m.v[5]=y;m.v[10]=z;return m;}
Mat4 rotateY(float a){Mat4 m=identity();float c=std::cos(a),s=std::sin(a);m.v[0]=c;m.v[2]=-s;m.v[8]=s;m.v[10]=c;return m;}
Mat4 rotateX(float a){Mat4 m=identity();float c=std::cos(a),s=std::sin(a);m.v[5]=c;m.v[6]=s;m.v[9]=-s;m.v[10]=c;return m;}
Mat4 rotateZ(float a){Mat4 m=identity();float c=std::cos(a),s=std::sin(a);m.v[0]=c;m.v[1]=s;m.v[4]=-s;m.v[5]=c;return m;}
Mat4 perspective(float fov,float aspect,float nearP,float farP){
  Mat4 m{};float f=1.0f/std::tan(fov*0.5f);
  m.v[0]=f/std::max(0.1f,aspect);m.v[5]=f;
  m.v[10]=(farP+nearP)/(nearP-farP);m.v[11]=-1.0f;
  m.v[14]=(2.0f*farP*nearP)/(nearP-farP);return m;
}
Mat4 lookAt(V3 eye,V3 center,V3 up){
  V3 f=norm(sub(center,eye)),s=norm(cross(f,up)),u=cross(s,f);Mat4 m=identity();
  m.v[0]=s.x;m.v[4]=s.y;m.v[8]=s.z;
  m.v[1]=u.x;m.v[5]=u.y;m.v[9]=u.z;
  m.v[2]=-f.x;m.v[6]=-f.y;m.v[10]=-f.z;
  m.v[12]=-dot(s,eye);m.v[13]=-dot(u,eye);m.v[14]=dot(f,eye);
  return m;
}
float valueNoise(float coordinate,float seed){
  const float cell=std::floor(coordinate);
  float blend=coordinate-cell;
  blend=blend*blend*(3.0f-2.0f*blend);
  auto hash=[](float x,float salt){
    const float raw=std::sin(x*127.1f+salt*311.7f)*43758.5453f;
    return (raw-std::floor(raw))*2.0f-1.0f;
  };
  const float a=hash(cell,seed),b=hash(cell+1.0f,seed);
  return a+(b-a)*blend;
}
void updateCameraSpring(float dt,float targetX,float targetZ){
  // Semi-implicit damped spring; substeps keep it stable across variable mobile frame times.
  const int substeps=std::max(1,(int)std::ceil(dt/(1.0f/120.0f)));
  const float h=dt/(float)substeps;
  constexpr float stiffness=72.0f;
  constexpr float damping=15.2f; // close to critical damping, with a small elastic lag
  for(int i=0;i<substeps;i++){
    const float ax=(targetX-cameraFocusX)*stiffness-cameraVelocityX*damping;
    const float az=(targetZ-cameraFocusZ)*stiffness-cameraVelocityZ*damping;
    cameraVelocityX+=ax*h;
    cameraVelocityZ+=az*h;
    cameraFocusX+=cameraVelocityX*h;
    cameraFocusZ+=cameraVelocityZ*h;
  }
}
void updateCameraShake(float dt){
  if(cameraShakeAmplitude<=0.00035f){
    cameraShakeAmplitude=0.0f;
    cameraShakeOffsetX=0.0f;
    cameraShakeOffsetY=0.0f;
    return;
  }
  // Two smoothly interpolated noise streams avoid harsh frame-to-frame random jumps.
  cameraShakeOffsetX=valueNoise(visualTime*31.0f,1.7f)*cameraShakeAmplitude;
  cameraShakeOffsetY=valueNoise(visualTime*37.0f,8.3f)*cameraShakeAmplitude*0.72f;
  cameraShakeAmplitude*=std::exp(-dt/std::max(0.035f,cameraShakeDecay));
}
float playerSquashEnvelope(){
  if(!playerSquashActive)return 0.0f;
  return std::exp(-playerSquashAge/0.045f);
}
void addVertex(std::vector<Vertex>&v,V3 p,V3 n){v.push_back({p.x,p.y,p.z,n.x,n.y,n.z});}
void addTri(std::vector<Vertex>&v,V3 a,V3 b,V3 c,V3 n){addVertex(v,a,n);addVertex(v,b,n);addVertex(v,c,n);}
void face(std::vector<Vertex>&v,V3 a,V3 b,V3 c,V3 d,V3 n){
  addTri(v,a,b,c,n);addTri(v,a,c,d,n);
}
void uploadMesh(Mesh&m,const std::vector<Vertex>&vertices){
  m.count=(GLsizei)vertices.size();
  glGenVertexArrays(1,&m.vao);glGenBuffers(1,&m.vbo);
  glBindVertexArray(m.vao);glBindBuffer(GL_ARRAY_BUFFER,m.vbo);
  glBufferData(GL_ARRAY_BUFFER,(GLsizeiptr)(vertices.size()*sizeof(Vertex)),vertices.data(),GL_STATIC_DRAW);
  glEnableVertexAttribArray(0);glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,sizeof(Vertex),(void*)offsetof(Vertex,px));
  glEnableVertexAttribArray(1);glVertexAttribPointer(1,3,GL_FLOAT,GL_FALSE,sizeof(Vertex),(void*)offsetof(Vertex,nx));
  glBindVertexArray(0);
}
void createMeshes(){
  std::vector<Vertex> c;
  const float a=-0.5f,b=0.5f;
  face(c,{b,a,a},{b,b,a},{b,b,b},{b,a,b},{1,0,0});
  face(c,{a,a,b},{a,b,b},{a,b,a},{a,a,a},{-1,0,0});
  face(c,{a,b,a},{a,b,b},{b,b,b},{b,b,a},{0,1,0});
  face(c,{a,a,b},{a,a,a},{b,a,a},{b,a,b},{0,-1,0});
  face(c,{b,a,b},{b,b,b},{a,b,b},{a,a,b},{0,0,1});
  face(c,{a,a,a},{a,b,a},{b,b,a},{b,a,a},{0,0,-1});
  uploadMesh(cubeMesh,c);
  std::vector<Vertex>s;const int rings=18,sectors=26;
  auto point=[](float t,float p){return V3{0.5f*std::sin(t)*std::cos(p),0.5f*std::cos(t),0.5f*std::sin(t)*std::sin(p)};};
  auto normal=[](V3 p){return norm(p);};
  for(int i=0;i<rings;i++){
    float t1=PI*(float)i/rings,t2=PI*(float)(i+1)/rings;
    for(int j=0;j<sectors;j++){
      float p1=2*PI*(float)j/sectors,p2=2*PI*(float)(j+1)/sectors;
      V3 a1=point(t1,p1),b1=point(t2,p1),c1=point(t2,p2),d1=point(t1,p2);
      addTri(s,a1,b1,c1,normal(a1));addTri(s,a1,c1,d1,normal(a1));
    }
  }
  uploadMesh(sphereMesh,s);
  // A second, gently irregular surface gives creatures and stone forms a softer silhouette.
  std::vector<Vertex> organic;
  const int organicRings=18, organicSectors=26;
  auto organicPoint=[](float t,float p){
    const float wave=0.060f*std::sin(3.0f*t+0.65f)*std::cos(5.0f*p)
      +0.032f*std::sin(7.0f*p+1.3f)*std::sin(t)
      +0.020f*std::cos(4.0f*t-2.0f*p);
    // Multiscale value noise displaces generated vertices to break perfect silhouettes.
    const float vertexNoise=0.052f*valueNoise(t*8.0f+p*12.0f,3.7f)
      +0.024f*valueNoise(t*19.0f-p*17.0f,9.4f);
    const float r=1.0f+wave+vertexNoise;
    return V3{0.5f*r*std::sin(t)*std::cos(p),0.5f*r*std::cos(t),0.5f*r*std::sin(t)*std::sin(p)};
  };
  for(int i=0;i<organicRings;i++){
    const float t1=PI*(float)i/organicRings,t2=PI*(float)(i+1)/organicRings;
    for(int j=0;j<organicSectors;j++){
      const float p1=2*PI*(float)j/organicSectors,p2=2*PI*(float)(j+1)/organicSectors;
      V3 a=organicPoint(t1,p1),b=organicPoint(t2,p1),c=organicPoint(t2,p2),d=organicPoint(t1,p2);
      addTri(organic,a,b,c,norm(a));addTri(organic,a,c,d,norm(a));
    }
  }
  uploadMesh(organicMesh,organic);
  __android_log_print(ANDROID_LOG_INFO,"NeonBreach","Procedural meshes ready: cube=%d sphere=%d organic=%d",cubeMesh.count,sphereMesh.count,organicMesh.count);
}
GLuint compileShader(GLenum type,const char*source){
  GLuint sh=glCreateShader(type);glShaderSource(sh,1,&source,nullptr);glCompileShader(sh);
  GLint ok=GL_FALSE;glGetShaderiv(sh,GL_COMPILE_STATUS,&ok);
  if(!ok){GLint n=0;glGetShaderiv(sh,GL_INFO_LOG_LENGTH,&n);if(n>1){char log[2048];GLsizei w=0;glGetShaderInfoLog(sh,std::min(n,2047),&w,log);__android_log_print(ANDROID_LOG_ERROR,"NeonBreach","Shader compile failed: %s",log);}glDeleteShader(sh);return 0;}return sh;
}
GLuint linkProgram(const char*vs,const char*fs,const char*label){
  GLuint v=compileShader(GL_VERTEX_SHADER,vs),f=compileShader(GL_FRAGMENT_SHADER,fs);
  if(!v||!f){if(v)glDeleteShader(v);if(f)glDeleteShader(f);return 0;}
  GLuint p=glCreateProgram();glAttachShader(p,v);glAttachShader(p,f);glBindAttribLocation(p,0,"aPosition");glBindAttribLocation(p,1,"aNormal");glLinkProgram(p);glDeleteShader(v);glDeleteShader(f);
  GLint ok=GL_FALSE;glGetProgramiv(p,GL_LINK_STATUS,&ok);
  if(!ok){GLint n=0;glGetProgramiv(p,GL_INFO_LOG_LENGTH,&n);if(n>1){char log[2048];GLsizei w=0;glGetProgramInfoLog(p,std::min(n,2047),&w,log);__android_log_print(ANDROID_LOG_ERROR,"NeonBreach","%s link failed: %s",label,log);}glDeleteProgram(p);return 0;}return p;
}
GLuint make3DProgram(){
  const char*vs=R"(#version 300 es
  layout(location=0) in vec3 aPosition;
  layout(location=1) in vec3 aNormal;
  uniform mat4 uMVP;uniform mat4 uModel;
  out vec3 vWorld;out vec3 vNormal;
  void main(){
    vec4 world=uModel*vec4(aPosition,1.0);vWorld=world.xyz;
    vec3 sc=vec3(length(uModel[0].xyz),length(uModel[1].xyz),length(uModel[2].xyz));
    vNormal=normalize(mat3(uModel)*(aNormal/max(sc,vec3(0.0001))));
    gl_Position=uMVP*vec4(aPosition,1.0);
  })";
  const char*fs=R"(#version 300 es
  precision highp float;
  in vec3 vWorld;in vec3 vNormal;
  uniform vec3 uColor;uniform vec3 uGlow;uniform vec3 uCamera;uniform vec3 uSectorPalette;uniform int uActiveRoom;
  out vec4 outColor;
  void main(){
    vec3 n=normalize(vNormal);vec3 light=normalize(vec3(-0.42,0.88,0.34));
    float diffuse=max(dot(n,light),0.0);
    // Three hard diffuse bands replace smooth Lambert shading: shadow, midtone and light.
    float band=diffuse>0.72?1.0:(diffuse>0.34?0.72:0.43);
    vec3 viewDir=normalize(uCamera-vWorld);
    float specularResponse=pow(max(dot(reflect(-light,n),viewDir),0.0),20.0);
    float spec=step(0.84,specularResponse)*0.12;
    float fillLight=max(dot(n,normalize(vec3(0.72,0.28,-0.44))),0.0)*0.08;
    float rim=pow(1.0-max(dot(n,viewDir),0.0),2.7);
    vec3 col=uColor*(0.22+0.68*band+fillLight)+vec3(spec);
    // Deterministic world-space grain adds material variation without downloaded textures.
    vec2 grainCell=floor(vWorld.xz*vec2(19.0,17.0));
    float grain=fract(sin(dot(grainCell,vec2(12.9898,78.233)))*43758.5453);
    float mottling=0.94+0.11*grain;
    col*=mottling;
    col+=uGlow+rim*(0.035+0.095*dot(uColor,vec3(0.333)));
    col+=uSectorPalette*0.035;
    float distanceFog=clamp((length(uCamera-vWorld)-9.0)/25.0,0.0,0.42);
    float worldRoom=floor((vWorld.x+6.0+0.001)/12.0);
    float undiscoveredRoom=step(float(uActiveRoom)+0.5,worldRoom);
    float activeGateEdge=1.0-smoothstep(0.20,0.58,abs(vWorld.x-(float(uActiveRoom)*12.0+6.0)));
    float explorationFog=undiscoveredRoom*(1.0-0.82*activeGateEdge);
    float fog=max(distanceFog,explorationFog*0.985);
    col=mix(col,vec3(0.002,0.006,0.010),fog);
    outColor=vec4(col,1.0);
  })";
  return linkProgram(vs,fs,"3D scene");
}
GLuint makePostProgram(){
  const char*vs=R"(#version 300 es
  out vec2 vUV;
  void main(){
    vec2 p[3]=vec2[3](vec2(-1.0,-1.0),vec2(3.0,-1.0),vec2(-1.0,3.0));
    vec2 position=p[gl_VertexID];
    gl_Position=vec4(position,0.0,1.0);
    vUV=position*0.5+0.5;
  })";
  const char*fs=R"(#version 300 es
  precision highp float;
  in vec2 vUV;
  uniform sampler2D uScene;
  uniform vec2 uResolution;
  out vec4 outColor;
  void main(){
    vec2 centered=vUV*2.0-1.0;
    float aspect=uResolution.x/max(uResolution.y,1.0);
    vec2 radial=vec2(centered.x*aspect,centered.y);
    float radiusSq=dot(radial,radial);
    float edge=smoothstep(0.18,1.20,radiusSq);
    // RGB channels shift by at most about one render pixel, only near the lens edge.
    vec2 radialDirection=normalize(centered+vec2(0.00001));
    vec2 chromaticOffset=radialDirection*(vec2(1.10)/uResolution)*smoothstep(0.12,1.20,radiusSq);
    vec2 redUV=clamp(vUV+chromaticOffset,vec2(0.001),vec2(0.999));
    vec2 blueUV=clamp(vUV-chromaticOffset,vec2(0.001),vec2(0.999));
    vec3 color;
    color.r=texture(uScene,redUV).r;
    color.g=texture(uScene,vUV).g;
    color.b=texture(uScene,blueUV).b;
    // Restrained 16% edge falloff preserves gameplay readability.
    color*=1.0-0.16*edge;
    outColor=vec4(color,1.0);
  })";
  return linkProgram(vs,fs,"stylized lens post-process");
}
void destroySceneTarget(){
  if(sceneFramebuffer)glDeleteFramebuffers(1,&sceneFramebuffer);
  if(sceneColorTexture)glDeleteTextures(1,&sceneColorTexture);
  if(sceneDepthBuffer)glDeleteRenderbuffers(1,&sceneDepthBuffer);
  sceneFramebuffer=sceneColorTexture=sceneDepthBuffer=0;
  sceneTargetW=sceneTargetH=0;
}
bool createSceneTarget(int width,int height){
  if(!postProgram||!postVao||width<=0||height<=0)return false;
  const float renderScale=std::min(1.0f,std::min(1600.0f/(float)width,900.0f/(float)height));
  const int targetW=std::max(1,(int)std::lround((float)width*renderScale));
  const int targetH=std::max(1,(int)std::lround((float)height*renderScale));
  if(sceneFramebuffer&&sceneTargetW==targetW&&sceneTargetH==targetH)return true;
  destroySceneTarget();
  glGenFramebuffers(1,&sceneFramebuffer);
  glBindFramebuffer(GL_FRAMEBUFFER,sceneFramebuffer);
  glGenTextures(1,&sceneColorTexture);
  glBindTexture(GL_TEXTURE_2D,sceneColorTexture);
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
  glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA8,targetW,targetH,0,GL_RGBA,GL_UNSIGNED_BYTE,nullptr);
  glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,sceneColorTexture,0);
  glGenRenderbuffers(1,&sceneDepthBuffer);
  glBindRenderbuffer(GL_RENDERBUFFER,sceneDepthBuffer);
  glRenderbufferStorage(GL_RENDERBUFFER,GL_DEPTH_COMPONENT24,targetW,targetH);
  glFramebufferRenderbuffer(GL_FRAMEBUFFER,GL_DEPTH_ATTACHMENT,GL_RENDERBUFFER,sceneDepthBuffer);
  const GLenum status=glCheckFramebufferStatus(GL_FRAMEBUFFER);
  glBindTexture(GL_TEXTURE_2D,0);
  glBindRenderbuffer(GL_RENDERBUFFER,0);
  glBindFramebuffer(GL_FRAMEBUFFER,0);
  if(status!=GL_FRAMEBUFFER_COMPLETE){
    __android_log_print(ANDROID_LOG_ERROR,"NeonBreach","Post-process framebuffer incomplete: 0x%x; using direct rendering",(unsigned int)status);
    destroySceneTarget();
    return false;
  }
  sceneTargetW=targetW;
  sceneTargetH=targetH;
  __android_log_print(ANDROID_LOG_INFO,"NeonBreach","Stylized post-process target: %dx%d (display %dx%d)",sceneTargetW,sceneTargetH,width,height);
  return true;
}
GLuint makeProjectileProgram(){
  const char*vs=R"(#version 300 es
  layout(location=0) in vec2 aCorner;
  layout(location=1) in vec3 iPosition;
  layout(location=2) in float iRadius;
  layout(location=3) in vec3 iColor;
  layout(location=4) in float iGlow;
  uniform mat4 uView;uniform mat4 uProjection;
  out vec2 vCorner;out vec3 vColor;out float vGlow;
  void main(){
    vec4 centerView=uView*vec4(iPosition,1.0);
    centerView.xy+=aCorner*iRadius;
    gl_Position=uProjection*centerView;
    vCorner=aCorner;vColor=iColor;vGlow=iGlow;
  })";
  const char*fs=R"(#version 300 es
  precision mediump float;
  in vec2 vCorner;in vec3 vColor;in float vGlow;
  out vec4 outColor;
  void main(){
    float radiusSq=dot(vCorner,vCorner);
    if(radiusSq>1.0)discard;
    float sphereDepth=sqrt(max(0.0,1.0-radiusSq));
    float highlight=0.58+0.42*sphereDepth;
    vec3 color=vColor*highlight+vColor*vGlow*(0.65+0.35*sphereDepth);
    float alpha=1.0-smoothstep(0.78,1.0,radiusSq);
    outColor=vec4(color,alpha);
  })";
  return linkProgram(vs,fs,"instanced projectiles");
}
void createProjectileRenderer(){
  projectileProgram=makeProjectileProgram();
  if(!projectileProgram)return;
  projectileViewLoc=glGetUniformLocation(projectileProgram,"uView");
  projectileProjectionLoc=glGetUniformLocation(projectileProgram,"uProjection");
  const float corners[]={-1.0f,-1.0f,1.0f,-1.0f,-1.0f,1.0f,1.0f,1.0f};
  const GLushort indices[]={0,1,2,2,1,3};
  glGenVertexArrays(1,&projectileVao);glBindVertexArray(projectileVao);
  glGenBuffers(1,&projectileQuadVbo);glBindBuffer(GL_ARRAY_BUFFER,projectileQuadVbo);
  glBufferData(GL_ARRAY_BUFFER,sizeof(corners),corners,GL_STATIC_DRAW);
  glEnableVertexAttribArray(0);glVertexAttribPointer(0,2,GL_FLOAT,GL_FALSE,2*sizeof(float),(void*)0);
  glGenBuffers(1,&projectileIndexBuffer);glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,projectileIndexBuffer);
  glBufferData(GL_ELEMENT_ARRAY_BUFFER,sizeof(indices),indices,GL_STATIC_DRAW);
  glGenBuffers(1,&projectileInstanceVbo);glBindBuffer(GL_ARRAY_BUFFER,projectileInstanceVbo);
  glBufferData(GL_ARRAY_BUFFER,(GLsizeiptr)(sizeof(ProjectileInstance)*shots.size()),nullptr,GL_DYNAMIC_DRAW);
  const GLsizei stride=(GLsizei)sizeof(ProjectileInstance);
  glEnableVertexAttribArray(1);glVertexAttribPointer(1,3,GL_FLOAT,GL_FALSE,stride,(void*)offsetof(ProjectileInstance,x));glVertexAttribDivisor(1,1);
  glEnableVertexAttribArray(2);glVertexAttribPointer(2,1,GL_FLOAT,GL_FALSE,stride,(void*)offsetof(ProjectileInstance,radius));glVertexAttribDivisor(2,1);
  glEnableVertexAttribArray(3);glVertexAttribPointer(3,3,GL_FLOAT,GL_FALSE,stride,(void*)offsetof(ProjectileInstance,r));glVertexAttribDivisor(3,1);
  glEnableVertexAttribArray(4);glVertexAttribPointer(4,1,GL_FLOAT,GL_FALSE,stride,(void*)offsetof(ProjectileInstance,glow));glVertexAttribDivisor(4,1);
  glBindVertexArray(0);glBindBuffer(GL_ARRAY_BUFFER,0);
}
bool drawProjectilesInstanced(const Mat4&view,const Mat4&projection){
  if(!projectileProgram||!projectileVao||!projectileInstanceVbo)return false;
  std::array<ProjectileInstance,18> batch{};
  GLsizei count=0;
  for(const auto&shot:shots){
    if(shot.life<=0.0f)continue;
    const bool hostile=shot.hostile;
    const V3 tint=hostile?V3{1.0f,0.09f,0.267f}:V3{0.0f,0.902f,0.463f};
    batch[(size_t)count++]={shot.x,0.34f,shot.z,hostile?0.085f:0.090f,tint.x,tint.y,tint.z,hostile?0.24f:0.19f};
  }
  if(count==0)return true;
  glUseProgram(projectileProgram);
  glUniformMatrix4fv(projectileViewLoc,1,GL_FALSE,view.v);
  glUniformMatrix4fv(projectileProjectionLoc,1,GL_FALSE,projection.v);
  glBindBuffer(GL_ARRAY_BUFFER,projectileInstanceVbo);
  glBufferSubData(GL_ARRAY_BUFFER,0,(GLsizeiptr)(sizeof(ProjectileInstance)*(size_t)count),batch.data());
  glBindVertexArray(projectileVao);
  const GLboolean blendWasEnabled=glIsEnabled(GL_BLEND);
  GLboolean depthWriteWasEnabled=GL_TRUE;glGetBooleanv(GL_DEPTH_WRITEMASK,&depthWriteWasEnabled);
  glEnable(GL_BLEND);glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);glDepthMask(GL_FALSE);
  glDrawElementsInstanced(GL_TRIANGLES,6,GL_UNSIGNED_SHORT,(void*)0,count);
  glDepthMask(depthWriteWasEnabled);
  if(!blendWasEnabled)glDisable(GL_BLEND);
  glBindVertexArray(0);glUseProgram(program);
  return true;
}
GLuint makeFallbackProgram(){
  const char*vs=R"(#version 300 es
  void main(){vec2 p[3]=vec2[3](vec2(-1.0,-1.0),vec2(3.0,-1.0),vec2(-1.0,3.0));gl_Position=vec4(p[gl_VertexID],0.0,1.0);})";
  const char*fs=R"(#version 300 es
  precision mediump float;uniform vec2 uRes;out vec4 outColor;
  void main(){vec2 uv=gl_FragCoord.xy/max(uRes,vec2(1.0));vec2 cellCoord=fract(uv*vec2(18.0,10.0));float g=max(step(0.97,cellCoord.x),step(0.97,cellCoord.y));vec3 c=vec3(0.006,0.014,0.03)+g*vec3(0.0,0.22,0.34);float d=1.0-smoothstep(0.015,0.04,length(uv-vec2(0.5)));c+=d*vec3(0.0,0.6,0.9);outColor=vec4(c,1.0);})";
  return linkProgram(vs,fs,"fallback");
}
void spawnEnemyWave(int wave);
void enterRoom(int roomIndex);
void configureArena(){
  arenaVariant=missionSerial%3;missionSerial++;
  for(int i=0;i<ROOM_COUNT;i++){
    Room&room=rooms[(size_t)i];
    room.centerX=(float)i*ROOM_WIDTH;
    room.minX=room.centerX-ROOM_HALF_WIDTH;
    room.maxX=room.centerX+ROOM_HALF_WIDTH;
    room.minZ=-ROOM_HALF_DEPTH;
    room.maxZ=ROOM_HALF_DEPTH;
    room.wavesTotal=(i==0||i==3)?2:1;
    room.wavesSpawned=0;room.visited=false;room.cleared=false;room.doorOpen=false;
    const int layout=(i+arenaVariant)%3;
    const std::array<Obstacle,4>*source=layout==0?&ARENA_LAYOUT_A:(layout==1?&ARENA_LAYOUT_B:&ARENA_LAYOUT_C);
    room.cover=*source;
    for(auto&o:room.cover)o.x+=room.centerX;
  }
  obstacles=rooms[0].cover;
  activeRoom=0;
  roomWorldInitialized=true;
}
void resetMission(){
  progression.reset();activeWave=0;
  configureArena();
  playerX=-5.15f;playerZ=-3.25f;playerHealth=1.0f;
  cameraFocusX=std::clamp(playerX*0.68f,-3.8f,3.8f);cameraFocusZ=std::clamp(playerZ*0.55f,-2.25f,2.25f);
  cameraVelocityX=cameraVelocityZ=0.0f;
  cameraShakeAmplitude=cameraShakeOffsetX=cameraShakeOffsetY=0.0f;
  playerSquashAge=0.15f;playerSquashActive=false;
  aimX=playerX;aimZ=playerZ-5.0f;elapsed=0;accumulator=0;
  moving=false;aiming=false;firing=false;shotCooldown=0;facingYaw=PI;moveDirX=0.0f;moveDirZ=-1.0f;
  dodgeTime=0.0f;dodgeCooldown=0.0f;dodgeDirX=0.0f;dodgeDirZ=-1.0f;
  won=false;lost=false;defeated=0;relayMask=0;podCollected={{false,false}};hazardCooldown.fill(0.0f);
  enemyShotCooldown.fill(0.8f);enemyWindup.fill(0.0f);enemyAttackCooldown.fill(0.0f);
  enemyReactionTimer.fill(0.0f);enemyThinkInterval.fill(0.10f);
  enemySlalomPhase.fill(0.0f);enemySlalomFrequency.fill(1.0f);enemySlalomStrength.fill(0.15f);
  enemySteerX.fill(0.0f);enemySteerZ.fill(0.0f);enemyMoveScale.fill(1.0f);
  shots.fill({});
  enterRoom(0);
}
bool roomGatePassable(int gateIndex,float z,float radius){
  return gateIndex>=0&&gateIndex<ROOM_COUNT-1
      &&rooms[(size_t)gateIndex].doorOpen
      &&std::abs(z)<ROOM_DOOR_HALF_WIDTH-radius;
}
void resolveCollision(float&x,float&z,float radius){
  const Room&room=rooms[(size_t)activeRoom];
  const bool westDoorOpen=activeRoom>0&&roomGatePassable(activeRoom-1,z,radius);
  const bool eastDoorOpen=activeRoom<ROOM_COUNT-1&&roomGatePassable(activeRoom,z,radius);
  z=std::clamp(z,room.minZ+radius,room.maxZ-radius);
  if(!westDoorOpen)x=std::max(x,room.minX+radius);
  if(!eastDoorOpen)x=std::min(x,room.maxX-radius);
  for(const auto&o:room.cover){
    float qx=std::clamp(x,o.x-o.sx*0.5f,o.x+o.sx*0.5f),qz=std::clamp(z,o.z-o.sz*0.5f,o.z+o.sz*0.5f);
    float dx=x-qx,dz=z-qz,d2=dx*dx+dz*dz;
    if(d2<radius*radius){
      if(d2>1e-6f){float d=std::sqrt(d2),push=radius-d+0.002f;x+=dx/d*push;z+=dz/d*push;}
      else{
        float left=std::abs(x-(o.x-o.sx*0.5f)),right=std::abs((o.x+o.sx*0.5f)-x);
        float top=std::abs(z-(o.z-o.sz*0.5f)),bottom=std::abs((o.z+o.sz*0.5f)-z);
        float mn=std::min(std::min(left,right),std::min(top,bottom));
        if(mn==left)x=o.x-o.sx*0.5f-radius-0.002f;
        else if(mn==right)x=o.x+o.sx*0.5f+radius+0.002f;
        else if(mn==top)z=o.z-o.sz*0.5f-radius-0.002f;
        else z=o.z+o.sz*0.5f+radius+0.002f;
      }
    }
  }
}
void draw(Mesh&m,V3 pos,V3 size,V3 color,V3 glow,float yaw,const Mat4&view,const Mat4&proj,V3 camera){
  if(!program||!m.vao)return;
  Mat4 model=multiply(translate(pos.x,pos.y,pos.z),multiply(rotateY(yaw),scale(size.x,size.y,size.z)));
  Mat4 mvp=multiply(proj,multiply(view,model));
  glUniformMatrix4fv(mvpLoc,1,GL_FALSE,mvp.v);glUniformMatrix4fv(modelLoc,1,GL_FALSE,model.v);
  glUniform3f(colorLoc,color.x,color.y,color.z);glUniform3f(glowLoc,glow.x,glow.y,glow.z);
  glUniform3f(cameraLoc,camera.x,camera.y,camera.z);
  glBindVertexArray(m.vao);glDrawArrays(GL_TRIANGLES,0,m.count);
}
void box(V3 p,V3 s,V3 c,V3 glow,float yaw,const Mat4&v,const Mat4&pjt,V3 cam){draw(cubeMesh,p,s,c,glow,yaw,v,pjt,cam);}
void orb(V3 p,V3 s,V3 c,V3 glow,const Mat4&v,const Mat4&pjt,V3 cam){draw(sphereMesh,p,s,c,glow,0,v,pjt,cam);}
void drawPose(Mesh&m,V3 pos,V3 size,V3 color,V3 glow,float yaw,float pitch,float roll,const Mat4&view,const Mat4&proj,V3 camera){
  if(!program||!m.vao)return;
  Mat4 model=multiply(translate(pos.x,pos.y,pos.z),multiply(rotateY(yaw),multiply(rotateZ(roll),multiply(rotateX(pitch),scale(size.x,size.y,size.z)))));
  Mat4 mvp=multiply(proj,multiply(view,model));
  glUniformMatrix4fv(mvpLoc,1,GL_FALSE,mvp.v);glUniformMatrix4fv(modelLoc,1,GL_FALSE,model.v);
  glUniform3f(colorLoc,color.x,color.y,color.z);glUniform3f(glowLoc,glow.x,glow.y,glow.z);glUniform3f(cameraLoc,camera.x,camera.y,camera.z);
  glBindVertexArray(m.vao);glDrawArrays(GL_TRIANGLES,0,m.count);
}
void poseBox(V3 p,V3 s,V3 c,V3 glow,float yaw,float pitch,float roll,const Mat4&v,const Mat4&pjt,V3 cam){drawPose(cubeMesh,p,s,c,glow,yaw,pitch,roll,v,pjt,cam);}
void poseOrb(V3 p,V3 s,V3 c,V3 glow,float yaw,float pitch,float roll,const Mat4&v,const Mat4&pjt,V3 cam){drawPose(sphereMesh,p,s,c,glow,yaw,pitch,roll,v,pjt,cam);}
// Procedural character rig: every visible part uses native meshes and runtime transforms.
void poseOrganic(V3 p,V3 s,V3 c,V3 glow,float yaw,float pitch,float roll,const Mat4&v,const Mat4&pjt,V3 cam){
  drawPose(organicMesh,p,s,c,glow,yaw,pitch,roll,v,pjt,cam);
}
// The field operative uses rounded armor, fabric-like masses and soft equipment volumes.
void drawHumanoid(V3 at,float yaw,float phase,float gait,int archetype,bool isPlayer,V3 armor,V3 trim,V3 glow,float squashX,float squashZ,const Mat4&view,const Mat4&proj,V3 cam){
  if(isPlayer){
    if(archetype==0){armor={0.0f,0.42f,0.52f};trim={0.0f,0.898f,1.0f};glow={0.0f,0.18f,0.24f};}
    else{armor={0.48f,0.34f,0.0f};trim={1.0f,0.839f,0.0f};glow={0.24f,0.16f,0.0f};}
  }
  const float widthScale=(isPlayer&&archetype==1)?1.17f:((isPlayer&&archetype==2)?1.02f:0.94f);
  const float swing=std::sin(phase)*gait;
  const float bob=0.018f*std::sin(phase*2.0f)*gait;
  const V3 forward{std::sin(yaw),0.0f,std::cos(yaw)},right{std::cos(yaw),0.0f,-std::sin(yaw)};
  const float bodyScaleX=isPlayer?squashX:1.0f,bodyScaleZ=isPlayer?squashZ:1.0f;
  auto point=[&](float side,float front,float y)->V3{
    return {at.x+right.x*side*bodyScaleX+forward.x*front*bodyScaleZ,at.y+y+bob,at.z+right.z*side*bodyScaleX+forward.z*front*bodyScaleZ};
  };
  // Scale each rounded body section in local width/depth, not the ground shadow.
  auto bodyOrb=[&](V3 p,V3 size,V3 color,V3 partGlow,float partYaw,float pitch,float roll,const Mat4&v,const Mat4&pjt,V3 camera){
    size.x*=bodyScaleX;size.z*=bodyScaleZ;
    poseOrb(p,size,color,partGlow,partYaw,pitch,roll,v,pjt,camera);
  };
  auto bodyOrganic=[&](V3 p,V3 size,V3 color,V3 partGlow,float partYaw,float pitch,float roll,const Mat4&v,const Mat4&pjt,V3 camera){
    size.x*=bodyScaleX;size.z*=bodyScaleZ;
    poseOrganic(p,size,color,partGlow,partYaw,pitch,roll,v,pjt,camera);
  };
  const V3 cloth{0.18f,0.20f,0.14f},leather{0.24f,0.15f,0.085f},dark{0.075f,0.085f,0.065f};
  orb({at.x,0.018f,at.z},{0.66f,0.028f,0.58f},{0.025f,0.030f,0.020f},{0,0,0},view,proj,cam);
  for(int sign : {-1,1}){
    const float side=(float)sign,leg=swing*side;
    bodyOrb(point(side*0.14f,leg*0.07f,0.245f),{0.17f,0.26f,0.17f},armor,glow,yaw,leg*0.22f,side*0.025f,view,proj,cam);
    bodyOrb(point(side*0.14f,leg*0.13f,0.115f),{0.135f,0.20f,0.14f},cloth,{0.006f,0.008f,0.004f},yaw,-leg*0.17f,side*0.02f,view,proj,cam);
    bodyOrb(point(side*0.145f,leg*0.17f+0.10f,0.055f),{0.20f,0.095f,0.23f},leather,{0.01f,0.004f,0.0f},yaw,0.0f,0.0f,view,proj,cam);
  }
  bodyOrganic(point(0,-0.025f,0.40f),{0.34f,0.24f,0.28f},dark,{0.005f,0.006f,0.003f},yaw,0.0f,0.0f,view,proj,cam);
  bodyOrganic(point(0,0.015f,0.585f),{0.42f*widthScale,0.43f,0.32f*widthScale},armor,glow,yaw,-0.04f,0.0f,view,proj,cam);
  bodyOrb(point(0,0.135f,0.59f),{0.33f,0.30f,0.17f},cloth,{0.004f,0.006f,0.002f},yaw,0.0f,0.0f,view,proj,cam);
  bodyOrb(point(0,0.205f,0.61f),{0.13f,0.11f,0.06f},trim,{0.028f,0.035f,0.008f},yaw,0.0f,0.0f,view,proj,cam);
  bodyOrganic(point(0,-0.19f,0.60f),{0.27f,0.31f,0.18f},leather,{0.008f,0.005f,0.001f},yaw,0.0f,0.0f,view,proj,cam);
  for(int sign : {-1,1}){
    const float side=(float)sign,arm=swing*side;
    bodyOrganic(point(side*0.30f*widthScale,0.0f,0.67f),{0.24f*widthScale,0.20f,0.23f*widthScale},armor,glow,yaw,0.0f,side*0.12f,view,proj,cam);
    bodyOrb(point(side*0.34f,-arm*0.06f,0.52f),{0.15f,0.23f,0.15f},cloth,{0.006f,0.007f,0.004f},yaw,arm*0.25f,side*0.17f,view,proj,cam);
    bodyOrb(point(side*0.35f,-arm*0.10f,0.37f),{0.13f,0.20f,0.13f},armor,glow,yaw,arm*0.34f,side*0.11f,view,proj,cam);
    bodyOrb(point(side*0.36f,-arm*0.12f,0.245f),{0.12f,0.12f,0.12f},leather,{0.005f,0.003f,0.0f},yaw,0.0f,side*0.08f,view,proj,cam);
  }
  // A hooded field helmet and a small glass-like visor replace the old square robot head.
  bodyOrganic(point(0,0,0.995f),{0.27f,0.26f,0.25f},leather,{0.008f,0.005f,0.001f},yaw,0.0f,0.0f,view,proj,cam);
  bodyOrb(point(0,0.085f,1.045f),{0.26f,0.205f,0.22f},armor,glow,yaw,0.0f,0.0f,view,proj,cam);
  bodyOrb(point(0,0.15f,1.055f),{0.18f,0.064f,0.055f},{0.19f,0.22f,0.13f},{0.025f,0.03f,0.006f},yaw,0.0f,0.0f,view,proj,cam);
  bodyOrb(point(0,0.165f,1.063f),{0.11f,0.027f,0.027f},{0.52f,0.59f,0.38f},{0.04f,0.045f,0.015f},yaw,0.0f,0.0f,view,proj,cam);
  bodyOrganic(point(-0.23f,-0.12f,0.69f),{0.24f,0.31f,0.24f},leather,{0.008f,0.004f,0.0f},yaw,-0.06f,-0.12f,view,proj,cam);
  bodyOrganic(point(0.17f,-0.36f,0.56f),{0.25f,0.33f,0.22f},dark,{0.004f,0.004f,0.002f},yaw,0.02f,0.08f,view,proj,cam);
  bodyOrb(point(0.19f,0.25f,0.43f),{0.085f,0.085f,0.28f},dark,{0.002f,0.003f,0.001f},yaw,0.0f,0.0f,view,proj,cam);
  bodyOrb(point(0.19f,0.36f,0.45f),{0.07f,0.07f,0.20f},trim,{0.018f,0.025f,0.003f},yaw,0.0f,0.0f,view,proj,cam);
}
// Three creatures use different silhouettes: a low crawler, an armored grazer and a floating spore.
void drawCreature(V3 at,float yaw,float phase,float gait,int type,V3 armor,V3 trim,V3 glow,const Mat4&view,const Mat4&proj,V3 cam){
  const float bob=0.025f*std::sin(phase*1.7f);
  const V3 f{std::sin(yaw),0.0f,std::cos(yaw)},r{std::cos(yaw),0.0f,-std::sin(yaw)};
  auto point=[&](float side,float front,float y)->V3{
    return {at.x+r.x*side+f.x*front,at.y+y+bob,at.z+r.z*side+f.z*front};
  };
  orb({at.x,0.022f,at.z},{type==1?1.12f:0.82f,0.03f,type==1?0.92f:0.75f},{0.025f,0.026f,0.017f},{0,0,0},view,proj,cam);
  if(type==0){
    poseOrganic(point(0,-0.10f,0.43f),{0.68f,0.34f,0.88f},armor,glow,yaw,0.0f,0.0f,view,proj,cam);
    poseOrganic(point(0,0.46f,0.36f),{0.43f,0.32f,0.48f},trim,glow,yaw,0.03f,0.0f,view,proj,cam);
    poseOrganic(point(0,0.65f,0.29f),{0.31f,0.22f,0.30f},armor,glow,yaw,0.0f,0.0f,view,proj,cam);
    for(int sideSign : {-1,1}){
      const float side=(float)sideSign;
      poseOrb(point(side*0.18f,0.67f,0.43f),{0.10f,0.085f,0.075f},{0.78f,0.60f,0.26f},{0.04f,0.022f,0.002f},yaw,0.0f,0.0f,view,proj,cam);
      for(int leg=0;leg<3;leg++){
        const float front=0.36f-(float)leg*0.36f;
        const float kick=std::sin(phase*1.5f+(float)leg*1.4f+side)*0.11f*gait;
        poseOrb(point(side*(0.32f+std::abs(kick)),front,0.22f),{0.12f,0.105f,0.34f},armor,{0.005f,0.006f,0.002f},yaw,kick*side,side*0.45f,view,proj,cam);
        poseOrb(point(side*0.43f,front+kick,0.105f),{0.15f,0.09f,0.18f},trim,glow,yaw,0.0f,side*0.12f,view,proj,cam);
      }
    }
    for(int k=0;k<3;k++)poseOrganic(point(0.0f,-0.24f-(float)k*0.16f,0.67f-(float)k*0.035f),{0.22f-(float)k*0.035f,0.16f,0.23f},trim,glow,yaw,0.0f,0.0f,view,proj,cam);
  }else if(type==1){
    poseOrganic(point(0,-0.03f,0.43f),{0.94f,0.53f,0.88f},armor,glow,yaw,0.10f,0.0f,view,proj,cam);
    poseOrganic(point(0,-0.05f,0.77f),{0.90f,0.62f,0.82f},trim,glow,yaw,0.18f,0.0f,view,proj,cam);
    poseOrganic(point(0,0.52f,0.43f),{0.43f,0.38f,0.40f},armor,glow,yaw,0.0f,0.0f,view,proj,cam);
    for(int sideSign : {-1,1}){
      const float side=(float)sideSign;
      poseOrb(point(side*0.22f,0.66f,0.48f),{0.12f,0.10f,0.08f},{0.95f,0.63f,0.24f},{0.04f,0.018f,0.0f},yaw,0.0f,0.0f,view,proj,cam);
      poseOrganic(point(side*0.54f,0.32f,0.47f),{0.32f,0.30f,0.32f},trim,glow,yaw,0.0f,side*0.16f,view,proj,cam);
      poseOrb(point(side*0.58f,0.20f,0.23f),{0.25f,0.24f,0.30f},armor,glow,yaw,0.0f,side*0.25f,view,proj,cam);
      poseOrb(point(side*0.41f,-0.30f,0.22f),{0.27f,0.22f,0.32f},armor,{0.004f,0.004f,0.001f},yaw,0.0f,side*0.30f,view,proj,cam);
    }
    for(int k=0;k<4;k++){
      const float a=2.0f*PI*(float)k/4.0f;
      poseOrganic(point(std::cos(a)*0.35f,-0.28f+std::sin(a)*0.38f,0.91f),{0.18f,0.23f,0.18f},trim,glow,yaw,a*0.08f,std::sin(a)*0.25f,view,proj,cam);
    }
  }else if(type==2){
    poseOrganic(point(0,0.0f,0.86f),{0.55f,0.61f,0.53f},armor,glow,yaw,0.0f,0.0f,view,proj,cam);
    poseOrb(point(0,0.09f,1.08f),{0.30f,0.29f,0.29f},trim,glow,yaw,0.0f,0.0f,view,proj,cam);
    for(int k=0;k<4;k++){
      const float a=2.0f*PI*(float)k/4.0f+phase*0.12f;
      const float sx=std::cos(a),sz=std::sin(a);
      poseOrganic({at.x+sx*0.38f,at.y+0.82f+0.10f*std::sin(phase+a),at.z+sz*0.38f},{0.20f,0.38f,0.19f},trim,glow,a,0.22f*sz,-0.28f*sx,view,proj,cam);
      poseOrb({at.x+sx*0.58f,at.y+0.62f,at.z+sz*0.58f},{0.09f,0.20f,0.09f},armor,{0.006f,0.008f,0.002f},a,0.0f,0.0f,view,proj,cam);
    }
    poseOrganic(point(0,0.03f,0.45f),{0.24f,0.28f,0.22f},armor,glow,yaw,0.0f,0.0f,view,proj,cam);
  }else{
    // The skitter has a low, segmented profile and constantly shifts laterally.
    poseOrganic(point(0,-0.30f,0.34f),{0.36f,0.30f,0.52f},armor,glow,yaw,0.0f,0.0f,view,proj,cam);
    poseOrganic(point(0,0.08f,0.34f),{0.32f,0.27f,0.42f},trim,glow,yaw,0.0f,0.0f,view,proj,cam);
    poseOrganic(point(0,0.42f,0.30f),{0.27f,0.24f,0.30f},armor,glow,yaw,0.0f,0.0f,view,proj,cam);
    poseOrb(point(0,0.60f,0.23f),{0.19f,0.10f,0.12f},trim,glow,yaw,0.0f,0.0f,view,proj,cam);
    for(int sign : {-1,1})for(int k=0;k<3;k++){
      const float side=(float)sign;
      const float front=0.24f-(float)k*0.30f;
      const float twitch=std::sin(phase*2.8f+(float)k*1.2f+side)*0.07f*gait;
      poseOrb(point(side*(0.24f+std::abs(twitch)),front,0.20f),{0.10f,0.09f,0.27f},armor,glow,yaw,twitch,side*0.53f,view,proj,cam);
    }
  }
}
bool allEnemiesDefeated(){for(const auto&e:enemies)if(e.hp>0.0f)return false;return true;}
int activeEnemyCount(){int count=0;for(const auto&e:enemies)if(e.hp>0.0f)count++;return count;}
void spawnEnemyWave(int wave){
  Room&room=rooms[(size_t)activeRoom];
  const int roomWave=room.wavesSpawned++;
  activeWave=wave;
  obstacles=room.cover;
  const float x0[4]={-3.85f,-0.85f,3.55f,1.15f};
  const float z0[4]={2.75f,3.15f,0.15f,-2.55f};
  const float healthScale=1.0f+0.11f*(float)(wave-1);
  const float speedScale=1.0f+0.035f*(float)(roomWave+activeRoom);
  for(size_t i=0;i<enemies.size();i++){
    const int type=((int)i+wave+activeRoom)%4;
    const float hpBase=type==1?2.4f:1.0f;
    const float speedBase=type==0?1.10f:(type==1?0.72f:(type==2?1.35f:1.62f));
    const float radius=type==1?0.48f:((type==2||type==3)?0.31f:0.36f);
    const float jitter=0.18f*std::sin((float)wave*1.7f+(float)i*2.4f+(float)activeRoom);
    enemies[i]={room.centerX+x0[i]+jitter,z0[i]+0.18f*std::cos((float)wave+(float)i+roomWave),hpBase*healthScale,hpBase*healthScale,speedBase*speedScale,radius,type,PI};
    enemyShotCooldown[i]=randomRange(0.45f,1.10f);
    enemyWindup[i]=0.0f;enemyAttackCooldown[i]=randomRange(0.25f,0.75f);
    enemyThinkInterval[i]=randomRange(0.075f,0.145f);enemyReactionTimer[i]=randomRange(0.0f,0.13f);
    enemySlalomPhase[i]=randomRange(0.0f,2.0f*PI);enemySlalomFrequency[i]=randomRange(0.82f,1.42f);
    enemySlalomStrength[i]=randomRange(0.10f,0.23f);enemySteerX[i]=0.0f;enemySteerZ[i]=0.0f;enemyMoveScale[i]=1.0f;
  }
  shots.fill({});
}
void enterRoom(int roomIndex){
  activeRoom=std::clamp(roomIndex,0,ROOM_COUNT-1);
  Room&room=rooms[(size_t)activeRoom];
  obstacles=room.cover;
  if(!room.cleared&&activeRoom>0)rooms[(size_t)(activeRoom-1)].doorOpen=false;
  if(!room.visited){
    room.visited=true;
    spawnEnemyWave(activeWave+1);
  }
  triggerCameraShake(0.095f,0.24f);
}
void updateRoomTransition(){
  if(activeRoom<ROOM_COUNT-1){
    const Room&room=rooms[(size_t)activeRoom];
    if(room.doorOpen&&playerX>room.maxX+0.24f&&std::abs(playerZ)<ROOM_DOOR_HALF_WIDTH-0.30f){
      enterRoom(activeRoom+1);
      return;
    }
  }
  if(activeRoom>0){
    const Room&previous=rooms[(size_t)(activeRoom-1)];
    if(previous.doorOpen&&playerX<rooms[(size_t)activeRoom].minX-0.24f&&std::abs(playerZ)<ROOM_DOOR_HALF_WIDTH-0.30f){
      enterRoom(activeRoom-1);
    }
  }
}
void processRoomClear(){
  if(!allEnemiesDefeated())return;
  Room&room=rooms[(size_t)activeRoom];
  if(room.cleared)return;
  if(room.wavesSpawned<room.wavesTotal){
    triggerCameraShake(0.045f,0.13f);
    spawnEnemyWave(activeWave+1);
    return;
  }
  room.cleared=true;
  if(activeRoom>0)rooms[(size_t)(activeRoom-1)].doorOpen=true;
  if(activeRoom<ROOM_COUNT-1){
    room.doorOpen=true;
    triggerCameraShake(0.17f,0.34f);
  }else{
    triggerCameraShake(0.22f,0.42f);
  }
}
bool nearActiveRelay(){
  for(int i=0;i<3;i++){
    if(relayMask&(1<<i))continue;
    float dx=playerX-RELAY_X[i],dz=playerZ-RELAY_Z[i];
    const float range=operativeRelayInteractionRadius()-0.20f;
    if(dx*dx+dz*dz<range*range)return true;
  }
  return false;
}
bool nearFieldPod(){
  for(int i=0;i<2;i++)if(!podCollected[(size_t)i]){
    const float dx=playerX-POD_X[i],dz=playerZ-POD_Z[i];
    if(dx*dx+dz*dz<0.85f*0.85f)return true;
  }
  return false;
}
bool nearActiveHazard(){
  for(int i=0;i<2;i++){
    const float cycle=std::fmod(elapsed+(float)i*1.55f,3.8f);
    if(cycle<2.4f||cycle>3.15f)continue;
    const float dx=playerX-HAZARD_X[i],dz=playerZ-HAZARD_Z[i];
    if(dx*dx+dz*dz<1.18f*1.18f)return true;
  }
  return false;
}
void publishSnapshot(){
  int hp=(int)std::round(std::clamp(playerHealth,0.0f,1.0f)*100.0f);
  int packed=(gameMode&7)|((hp&127)<<3)|((relayMask&7)<<10)|((activeEnemyCount()&7)<<13)
    |(nearActiveRelay()?1<<16:0)|(dodgeCooldown<=0.0f?1<<17:0)|(nearFieldPod()?1<<18:0)|(nearActiveHazard()?1<<19:0)
    |((defeated&31)<<20)|((activeRoom&3)<<25)|(rooms[(size_t)activeRoom].doorOpen?1<<27:0);
  publishedSnapshot.store(packed,std::memory_order_relaxed);
}
void drawPlayerHealthBar(const Mat4&view,const Mat4&proj,V3 cam){
  if(gameMode!=1)return;
  const float health=std::clamp(playerHealth,0.0f,1.0f);
  constexpr float barWidth=0.78f;
  constexpr float barDepth=0.075f;
  const V3 accent=operativeClass==0?V3{0.0f,0.86f,0.96f}:V3{1.0f,0.80f,0.0f};
  box({playerX,1.43f,playerZ},{barWidth,0.035f,barDepth},
      {0.025f,0.035f,0.040f},{0.001f,0.002f,0.003f},0,view,proj,cam);
  if(health>0.002f){
    const float filledWidth=barWidth*health;
    const float leftEdge=playerX-barWidth*0.5f;
    box({leftEdge+filledWidth*0.5f,1.455f,playerZ},
        {filledWidth,0.024f,barDepth*0.70f},accent,
        {accent.x*0.055f,accent.y*0.055f,accent.z*0.055f},0,view,proj,cam);
  }
}
void drawRoomArrow(const Room&room,const Mat4&view,const Mat4&proj,V3 cam){
  const float x=room.maxX-2.55f;
  const V3 arrowColor{0.0f,0.78f,0.92f},arrowGlow{0.0f,0.075f,0.10f};
  for(int stripe=0;stripe<2;stripe++){
    const float offset=(float)stripe*0.72f;
    box({x+offset,0.040f,0.0f},{0.48f,0.026f,0.11f},arrowColor,arrowGlow,0,view,proj,cam);
  }
  box({room.maxX-1.42f,0.045f,-0.30f},{0.88f,0.030f,0.085f},arrowColor,arrowGlow,-0.72f,view,proj,cam);
  box({room.maxX-1.42f,0.045f,0.30f},{0.88f,0.030f,0.085f},arrowColor,arrowGlow,0.72f,view,proj,cam);
}
void drawRoomEnergyDoor(int roomIndex,const Mat4&view,const Mat4&proj,V3 cam){
  if(roomIndex<0||roomIndex>=ROOM_COUNT-1)return;
  const Room&room=rooms[(size_t)roomIndex];
  const float edge=room.maxX;
  const V3 frame{0.15f,0.20f,0.23f},frameGlow{0.003f,0.008f,0.012f};
  box({edge,0.78f,-3.05f},{0.28f,1.56f,2.90f},{0.075f,0.095f,0.12f},{0.002f,0.005f,0.008f},0,view,proj,cam);
  box({edge,0.78f, 3.05f},{0.28f,1.56f,2.90f},{0.075f,0.095f,0.12f},{0.002f,0.005f,0.008f},0,view,proj,cam);
  for(float side : {-1.0f,1.0f}){
    box({edge,0.82f,side*1.30f},{0.34f,1.72f,0.22f},frame,frameGlow,0,view,proj,cam);
    box({edge,0.84f,side*1.48f},{0.38f,1.52f,0.055f},{0.82f,0.31f,0.065f},{0.042f,0.007f,0.001f},0,view,proj,cam);
  }
  box({edge,1.70f,0.0f},{0.34f,0.18f,2.85f},frame,frameGlow,0,view,proj,cam);
  if(!room.doorOpen){
    const V3 energy{0.88f,0.12f,0.045f},glow{0.19f,0.012f,0.001f};
    box({edge,0.84f,0.0f},{0.16f,1.48f,2.38f},{0.22f,0.035f,0.045f},glow,0,view,proj,cam);
    for(int band=0;band<5;band++){
      const float y=0.28f+(float)band*0.27f;
      box({edge-0.095f,y,0.0f},{0.035f,0.028f,2.22f},energy,glow,0,view,proj,cam);
    }
    for(int side : {-1,1})box({edge-0.115f,0.82f,(float)side*0.93f},{0.035f,1.15f,0.045f},{1.0f,0.36f,0.08f},{0.10f,0.018f,0.001f},0,view,proj,cam);
  }else{
    box({edge,0.035f,0.0f},{0.24f,0.035f,2.44f},{0.0f,0.43f,0.52f},{0.0f,0.045f,0.065f},0,view,proj,cam);
  }
}
void drawRoomShell(int roomIndex,const Mat4&view,const Mat4&proj,V3 cam){
  const Room&room=rooms[(size_t)roomIndex];
  const float x=room.centerX;
  const V3 floorColor=(roomIndex==0)?V3{0.14f,0.17f,0.18f}:
      (roomIndex==1?V3{0.16f,0.14f,0.12f}:(roomIndex==2?V3{0.11f,0.15f,0.18f}:V3{0.16f,0.12f,0.14f}));
  const V3 floorGlow=(roomIndex==0)?V3{0.003f,0.006f,0.008f}:
      (roomIndex==1?V3{0.010f,0.004f,0.001f}:(roomIndex==2?V3{0.001f,0.006f,0.012f}:V3{0.010f,0.002f,0.004f}));
  box({x,-0.25f,0.0f},{12.15f,0.44f,9.55f},{0.045f,0.055f,0.068f},{0.002f,0.004f,0.008f},0,view,proj,cam);
  box({x,-0.006f,0.0f},{11.90f,0.035f,9.20f},floorColor,floorGlow,0,view,proj,cam);
  for(int row=-2;row<=2;row++){
    const float z=(float)row*1.48f;
    box({x,0.014f,z},{11.65f,0.012f,0.022f},{0.055f,0.070f,0.082f},{0.001f,0.002f,0.004f},0,view,proj,cam);
  }
  for(int column=-2;column<=2;column++){
    const float px=x+(float)column*2.0f;
    box({px,0.014f,0.0f},{0.022f,0.012f,8.95f},{0.055f,0.070f,0.082f},{0.001f,0.002f,0.004f},0,view,proj,cam);
  }
  for(int side : {-1,1}){
    const float z=(float)side*4.62f;
    box({x,0.78f,z},{12.08f,1.56f,0.28f},{0.075f,0.095f,0.12f},{0.002f,0.005f,0.008f},0,view,proj,cam);
    box({x,1.82f,z-(float)side*0.17f},{11.95f,0.10f,0.12f},{0.20f,0.25f,0.28f},{0.004f,0.008f,0.011f},0,view,proj,cam);
    for(int panel=0;panel<5;panel++){
      const float px=x-4.65f+(float)panel*2.30f;
      box({px,0.88f,z-(float)side*0.16f},{0.95f,1.20f,0.045f},
          (panel+roomIndex)%2==0?V3{0.11f,0.14f,0.16f}:V3{0.075f,0.10f,0.12f},
          {0.001f,0.003f,0.005f},0,view,proj,cam);
      if(panel%2==0)box({px,1.35f,z-(float)side*0.205f},{0.42f,0.045f,0.025f},
          {0.84f,0.30f,0.065f},{0.035f,0.006f,0.001f},0,view,proj,cam);
    }
  }
  for(int beam=0;beam<3;beam++){
    const float px=x-3.8f+(float)beam*3.8f;
    box({px,2.03f,0.0f},{0.12f,0.13f,8.30f},{0.19f,0.23f,0.26f},{0.003f,0.006f,0.008f},0,view,proj,cam);
    box({px,1.955f,0.0f},{0.055f,0.025f,7.70f},
        roomIndex%2==0?V3{0.13f,0.61f,0.66f}:V3{0.76f,0.28f,0.07f},
        roomIndex%2==0?V3{0.008f,0.045f,0.052f}:V3{0.035f,0.006f,0.001f},0,view,proj,cam);
  }
  for(size_t i=0;i<room.cover.size();i++){
    const auto&o=room.cover[i];const float yaw=(float)i*0.17f;
    box({o.x,o.h*0.43f,o.z},{o.sx*1.12f,o.h*0.86f,o.sz*1.10f},{0.105f,0.135f,0.15f},{0.006f,0.010f,0.012f},yaw,view,proj,cam);
    box({o.x,o.h*0.87f,o.z},{o.sx*0.84f,0.075f,o.sz*0.83f},{0.23f,0.27f,0.27f},{0.003f,0.004f,0.004f},yaw,view,proj,cam);
    box({o.x,o.h*0.62f,o.z+o.sz*0.54f},{o.sx*0.64f,0.055f,0.035f},{0.80f,0.31f,0.08f},{0.035f,0.008f,0.001f},yaw,view,proj,cam);
  }
  const float consoleX=x+((roomIndex%2==0)?-4.9f:4.9f);
  box({consoleX,0.72f,-1.85f},{0.48f,1.05f,0.76f},{0.055f,0.075f,0.09f},{0.002f,0.005f,0.008f},0,view,proj,cam);
  box({consoleX,1.05f,-1.85f},{0.035f,0.38f,0.48f},
      roomIndex==0?V3{0.10f,0.65f,0.72f}:V3{0.80f,0.29f,0.08f},
      {0.008f,0.035f,0.045f},0,view,proj,cam);
}
void drawScene(const Mat4&view,const Mat4&proj,V3 cam){
  // SITE ORION-9 — ORION INDUSTRIAL MODULES: four connected, procedurally textured containment rooms.
  for(int i=0;i<ROOM_COUNT;i++)drawRoomShell(i,view,proj,cam);
  box({rooms[0].minX,0.80f,0.0f},{0.30f,1.60f,9.35f},{0.075f,0.095f,0.12f},{0.002f,0.005f,0.008f},0,view,proj,cam);
  box({rooms[3].maxX,0.80f,0.0f},{0.30f,1.60f,9.35f},{0.075f,0.095f,0.12f},{0.002f,0.005f,0.008f},0,view,proj,cam);
  for(int gate=0;gate<ROOM_COUNT-1;gate++){
    drawRoomEnergyDoor(gate,view,proj,cam);
    if(gate==activeRoom&&rooms[(size_t)gate].doorOpen)drawRoomArrow(rooms[(size_t)gate],view,proj,cam);
  }
  for(int i=0;i<3;i++){
    const float x=RELAY_X[i],z=RELAY_Z[i];const bool complete=(relayMask&(1<<i))!=0;
    const V3 signal=complete?V3{0.10f,0.78f,0.82f}:V3{0.93f,0.36f,0.10f};
    const V3 glow=complete?V3{0.008f,0.11f,0.13f}:V3{0.095f,0.018f,0.001f};
    box({x,0.09f,z},{0.90f,0.18f,0.78f},{0.075f,0.095f,0.105f},{0.004f,0.006f,0.008f},0,view,proj,cam);
    box({x,0.34f,z},{0.43f,0.42f,0.40f},{0.17f,0.21f,0.23f},{0.003f,0.006f,0.008f},0,view,proj,cam);
    box({x,0.58f,z},{0.53f,0.12f,0.48f},{0.25f,0.28f,0.28f},{0.004f,0.006f,0.006f},0,view,proj,cam);
    box({x-0.26f,0.36f,z},{0.065f,0.34f,0.07f},signal,glow,0,view,proj,cam);
    box({x+0.26f,0.36f,z},{0.065f,0.34f,0.07f},signal,glow,0,view,proj,cam);
    poseOrb({x,0.76f+0.035f*std::sin(visualTime*1.7f+(float)i),z},{0.17f,0.19f,0.17f},signal,glow,0,0,0,view,proj,cam);
    if(!complete)for(int k=0;k<4;k++){const float a=2.0f*PI*(float)k/4.0f;poseOrb({x+std::cos(a)*0.48f,0.045f,z+std::sin(a)*0.40f},{0.075f,0.04f,0.075f},{0.86f,0.36f,0.10f},{0.025f,0.006f,0.001f},0,0,0,view,proj,cam);}
  }
  for(int i=0;i<2;i++){
    const float cycle=std::fmod(elapsed+(float)i*1.55f,3.8f);
    const bool dangerous=cycle>2.4f&&cycle<3.15f;
    const float radius=(dangerous?0.80f:0.62f)+0.035f*std::sin(visualTime*2.0f+(float)i);
    const V3 sporeColor=dangerous?V3{0.83f,0.35f,0.075f}:V3{0.31f,0.29f,0.16f};
    const V3 sporeGlow=dangerous?V3{0.055f,0.012f,0.001f}:V3{0.002f,0.003f,0.001f};
    for(int k=0;k<8;k++){
      const float a=2.0f*PI*(float)k/8.0f;
      poseOrb({HAZARD_X[i]+std::cos(a)*radius,0.042f,HAZARD_Z[i]+std::sin(a)*radius},{0.14f,0.055f,0.14f},sporeColor,sporeGlow,0,0,0,view,proj,cam);
    }
    poseOrganic({HAZARD_X[i],0.12f+0.025f*std::sin(visualTime*1.8f+(float)i),HAZARD_Z[i]},
      {0.38f,0.24f,0.38f},dangerous?V3{0.61f,0.31f,0.10f}:V3{0.25f,0.25f,0.14f},
      sporeGlow,visualTime*0.08f,0,0,view,proj,cam);
  }
  for(int i=0;i<2;i++){
    if(podCollected[(size_t)i])continue;
    const float x=POD_X[i],z=POD_Z[i];
    box({x,0.10f,z},{0.42f,0.20f,0.38f},{0.12f,0.15f,0.16f},{0.004f,0.008f,0.010f},0,view,proj,cam);
    box({x,0.24f,z},{0.30f,0.10f,0.27f},{0.28f,0.34f,0.33f},{0.003f,0.006f,0.006f},0,view,proj,cam);
    box({x,0.32f,z},{0.07f,0.13f,0.07f},{0.12f,0.80f,0.82f},{0.015f,0.10f,0.12f},0,view,proj,cam);
    poseOrb({x,0.43f+0.035f*std::sin(visualTime*1.6f+(float)i),z},{0.11f,0.14f,0.11f},{0.70f,0.88f,0.86f},{0.02f,0.08f,0.075f},0,0,0,view,proj,cam);
  }
  const bool objectiveComplete=defeated>=TOTAL_MISSION_ELIMINATIONS&&rooms[3].cleared&&relayMask==0x7;
  box({activeExtractionX(),0.025f,activeExtractionZ()},{1.55f,0.10f,1.25f},{0.075f,0.105f,0.12f},{0.003f,0.006f,0.009f},0,view,proj,cam);
  box({activeExtractionX(),0.085f,activeExtractionZ()},{1.28f,0.035f,0.98f},{0.15f,0.19f,0.20f},{0.003f,0.005f,0.006f},0,view,proj,cam);
  for(int i=0;i<5;i++){
    const float dx=((float)i-2.0f)*0.22f;
    box({activeExtractionX()+dx,0.11f,activeExtractionZ()-0.40f},{0.12f,0.035f,0.08f},
        objectiveComplete?V3{0.10f,0.78f,0.82f}:V3{0.88f,0.32f,0.07f},
        objectiveComplete?V3{0.01f,0.10f,0.12f}:V3{0.055f,0.008f,0.001f},0,view,proj,cam);
  }
  poseOrb({activeExtractionX(),0.34f+0.05f*std::sin(visualTime*1.6f),activeExtractionZ()},{0.15f,0.22f,0.15f},
      objectiveComplete?V3{0.15f,0.86f,0.84f}:V3{0.90f,0.40f,0.10f},
      objectiveComplete?V3{0.015f,0.12f,0.12f}:V3{0.07f,0.013f,0.001f},0,0,0,view,proj,cam);

  const float playerYaw=aiming?std::atan2(aimX-playerX,aimZ-playerZ):facingYaw;
  const float inputDx=(moveX-moveOriginX)/(float)std::max(1,screenH);
  const float inputDy=(moveY-moveOriginY)/(float)std::max(1,screenH);
  const float inputMagnitude=std::sqrt(inputDx*inputDx+inputDy*inputDy);
  const float playerGait=moving?std::clamp(inputMagnitude/0.13f,0.0f,1.0f):0.0f;
  const float squash=playerSquashEnvelope();
  const float squashX=1.0f+0.105f*squash;
  const float squashZ=1.0f-0.080f*squash;
  drawHumanoid({playerX,0.0f,playerZ},playerYaw,elapsed*8.0f,playerGait,operativeClass,true,
    {0.28f,0.34f,0.20f},{0.59f,0.51f,0.27f},{0.012f,0.018f,0.003f},squashX,squashZ,view,proj,cam);
  drawPlayerHealthBar(view,proj,cam);
  for(size_t i=0;i<enemies.size();i++){
    const auto&e=enemies[i];if(e.hp<=0.0f)continue;
    const float distanceToPlayer=std::sqrt((playerX-e.x)*(playerX-e.x)+(playerZ-e.z)*(playerZ-e.z));
    const float enemyGait=distanceToPlayer>e.radius+0.48f?0.88f:0.20f;
    const V3 enemyArmor{1.0f,0.09f,0.267f},enemyTrim{1.0f,0.25f,0.36f},enemyGlow{0.10f,0.004f,0.018f};
    drawCreature({e.x,0.0f,e.z},e.yaw,elapsed*(4.6f+e.speed),enemyGait,e.type,enemyArmor,enemyTrim,enemyGlow,view,proj,cam);
    const int healthBeads=(int)std::ceil(3.0f*e.hp/std::max(1.0f,e.maxHp));
    for(int bead=0;bead<healthBeads;bead++){
      const float a=2.0f*PI*(float)bead/3.0f;
      poseOrb({e.x+std::cos(a)*0.30f,1.38f,e.z+std::sin(a)*0.30f},{0.085f,0.075f,0.085f},enemyTrim,{0.008f,0.004f,0.001f},0,0,0,view,proj,cam);
    }
    if(e.type==1&&enemyWindup[i]>0.04f){
      const float ring=0.65f+0.25f*std::clamp(enemyWindup[i]/0.42f,0.0f,1.0f);
      for(int k=0;k<8;k++){
        const float a=2.0f*PI*(float)k/8.0f;
        poseOrb({e.x+std::cos(a)*ring,0.035f,e.z+std::sin(a)*ring},{0.12f,0.035f,0.12f},{0.78f,0.29f,0.075f},{0.03f,0.006f,0.001f},0,0,0,view,proj,cam);
      }
    }
  }
  if(aiming&&!won&&!lost){
    poseOrb({aimX,0.045f,aimZ},{0.12f,0.035f,0.12f},{0.66f,0.78f,0.40f},{0.015f,0.02f,0.002f},0,0,0,view,proj,cam);
    for(int i=0;i<4;i++){
      const float a=2.0f*PI*(float)i/4.0f;
      poseOrb({aimX+std::cos(a)*0.20f,0.045f,aimZ+std::sin(a)*0.20f},{0.055f,0.035f,0.055f},{0.72f,0.81f,0.47f},{0.01f,0.015f,0.002f},0,0,0,view,proj,cam);
    }
  }
  if(!drawProjectilesInstanced(view,proj)){
    for(const auto&shot:shots)if(shot.life>0.0f){
      if(shot.hostile)orb({shot.x,0.34f,shot.z},{0.15f,0.15f,0.15f},{1.0f,0.09f,0.267f},{0.045f,0.004f,0.012f},view,proj,cam);
      else orb({shot.x,0.34f,shot.z},{0.16f,0.16f,0.16f},{0.0f,0.902f,0.463f},{0.0f,0.025f,0.012f},view,proj,cam);
    }
  }
}
bool projectileBlocked(float x,float z){
  const Room&room=rooms[(size_t)activeRoom];
  if(z<room.minZ||z>room.maxZ)return true;
  if(x<room.minX&&!roomGatePassable(activeRoom-1,z,0.02f))return true;
  if(x>room.maxX&&!roomGatePassable(activeRoom,z,0.02f))return true;
  for(const auto&o:room.cover)if(std::abs(x-o.x)<=o.sx*0.5f+0.055f&&std::abs(z-o.z)<=o.sz*0.5f+0.055f)return true;
  if(activeRoom<ROOM_COUNT-1&&!room.doorOpen&&x>=room.maxX-0.16f&&std::abs(z)<ROOM_DOOR_HALF_WIDTH)return true;
  return false;
}
void fixedUpdate(float dt){
  if(playerSquashActive){
    playerSquashAge+=dt;
    if(playerSquashAge>=0.15f){playerSquashAge=0.15f;playerSquashActive=false;}
  }
  if(gameMode!=1){publishSnapshot();return;}
  elapsed+=dt;
  const bool invulnerableNow=dodgeTime>0.0f;
  dodgeCooldown=std::max(0.0f,dodgeCooldown-dt);dodgeTime=std::max(0.0f,dodgeTime-dt);shotCooldown=std::max(0.0f,shotCooldown-dt);
  for(int i=0;i<4;i++){enemyShotCooldown[i]=std::max(0.0f,enemyShotCooldown[i]-dt);enemyAttackCooldown[i]=std::max(0.0f,enemyAttackCooldown[i]-dt);}
  if(!won&&!lost){
    for(int i=0;i<2;i++){
      hazardCooldown[(size_t)i]=std::max(0.0f,hazardCooldown[(size_t)i]-dt);
      const float cycle=std::fmod(elapsed+(float)i*1.55f,3.8f);
      if(cycle<2.4f||cycle>3.15f||hazardCooldown[(size_t)i]>0.0f)continue;
      const float hx=playerX-HAZARD_X[i],hz=playerZ-HAZARD_Z[i];
      if(hx*hx+hz*hz<0.88f*0.88f&&!invulnerableNow){
        hurtPlayer(0.13f);
        hazardCooldown[(size_t)i]=0.90f;
      }
    }
    float inputStrength=0.0f;
    if(moving){
      const float dx=(moveX-moveOriginX)/(float)std::max(1,screenH),dy=(moveY-moveOriginY)/(float)std::max(1,screenH);
      const float mag=std::sqrt(dx*dx+dy*dy);
      if(mag>0.012f){moveDirX=dx/mag;moveDirZ=dy/mag;inputStrength=std::clamp(mag/0.15f,0.0f,1.0f);if(!aiming)facingYaw=std::atan2(moveDirX,moveDirZ);}
    }
    if(dodgeTime>0.0f){playerX+=dodgeDirX*8.2f*dt;playerZ+=dodgeDirZ*8.2f*dt;resolveCollision(playerX,playerZ,0.30f);updateRoomTransition();}
    else if(moving&&inputStrength>0.0f){playerX+=moveDirX*operativeMoveSpeed()*inputStrength*dt;playerZ+=moveDirZ*operativeMoveSpeed()*inputStrength*dt;resolveCollision(playerX,playerZ,0.30f);updateRoomTransition();}
    if(aiming){const float ax=aimX-playerX,az=aimZ-playerZ;if(std::abs(ax)+std::abs(az)>0.001f)facingYaw=std::atan2(ax,az);}

    // Dedicated hold-to-fire; aim drag only steers the weapon.
    if(firing&&shotCooldown<=0.0f&&playerHealth>0.0f){
      float dx,dz;
      if(aiming){dx=aimX-playerX;dz=aimZ-playerZ;const float d=std::sqrt(dx*dx+dz*dz);if(d>0.001f){dx/=d;dz/=d;}else{dx=std::sin(facingYaw);dz=std::cos(facingYaw);}}
      else{dx=std::sin(facingYaw);dz=std::cos(facingYaw);}
      const float baseAngle=std::atan2(dx,dz);
      const int pelletCount=operativeClass==0?2:3;
      for(int pellet=0;pellet<pelletCount;pellet++){
        int slot=-1;for(int i=0;i<(int)shots.size();i++)if(shots[(size_t)i].life<=0.0f){slot=i;break;}
        if(slot<0)break;
        float shotDx=dx,shotDz=dz,shotX=playerX+dx*0.48f,shotZ=playerZ+dz*0.48f;
        if(operativeClass==0){
          const float lateral=pellet==0?-0.105f:0.105f;
          shotX+=std::cos(baseAngle)*lateral;shotZ-=std::sin(baseAngle)*lateral;
        }else{
          const float spread=(float)(pellet-1)*0.20f;
          const float angle=baseAngle+spread;shotDx=std::sin(angle);shotDz=std::cos(angle);
        }
        shots[(size_t)slot]={shotX,0.45f,shotZ,shotDx*8.3f,shotDz*8.3f,1.12f,false,operativeShotDamage()};
      }
      shotCooldown=operativeFireInterval();
      triggerPlayerShotFeedback();
    }
    // Each unit refreshes tactical decisions on its own randomized frame phase.
    // Movement and collision integration remain continuous at the fixed simulation rate.
    for(int i=0;i<(int)enemies.size();i++){
      auto&e=enemies[(size_t)i];if(e.hp<=0.0f)continue;
      enemyReactionTimer[(size_t)i]-=dt;
      if(enemyReactionTimer[(size_t)i]<=0.0f){
        enemyReactionTimer[(size_t)i]=enemyThinkInterval[(size_t)i];
        const float dx=playerX-e.x,dz=playerZ-e.z;
        const float d=std::sqrt(dx*dx+dz*dz);
        const float safeD=std::max(0.001f,d);
        if(d>0.001f)e.yaw=std::atan2(dx,dz);
        float steerX=0.0f,steerZ=0.0f,moveScale=1.0f;
        if(e.type==2){
          if(d>3.25f){steerX=dx/safeD;steerZ=dz/safeD;}
          else if(d<2.15f){steerX=-dx/safeD;steerZ=-dz/safeD;}
          else{const float strafe=std::sin(elapsed*1.15f+(float)i*2.1f)*0.55f;steerX=(-dz/safeD)*strafe;steerZ=(dx/safeD)*strafe;}
          if(d<6.0f&&enemyShotCooldown[(size_t)i]<=0.0f){
            int slot=-1;for(int k=0;k<(int)shots.size();k++)if(shots[(size_t)k].life<=0.0f){slot=k;break;}
            if(slot>=0&&d>0.1f){shots[(size_t)slot]={e.x,0.38f,e.z,dx/safeD*4.6f,dz/safeD*4.6f,2.0f,true};enemyShotCooldown[(size_t)i]=1.55f;}
          }
        }else if(e.type==1){
          if(d>1.22f){steerX=dx/safeD;steerZ=dz/safeD;enemyWindup[(size_t)i]=std::max(0.0f,enemyWindup[(size_t)i]-enemyThinkInterval[(size_t)i]*2.5f);}
          else if(enemyAttackCooldown[(size_t)i]<=0.0f){
            enemyWindup[(size_t)i]+=enemyThinkInterval[(size_t)i];
            if(enemyWindup[(size_t)i]>=0.42f){
              if(d<1.72f&&!invulnerableNow){hurtPlayer(0.24f);if(d>0.001f){playerX-=dx/safeD*0.22f;playerZ-=dz/safeD*0.22f;resolveCollision(playerX,playerZ,0.30f);}}
              enemyAttackCooldown[(size_t)i]=1.55f;enemyWindup[(size_t)i]=0.0f;
            }
          }else enemyWindup[(size_t)i]=0.0f;
        }else if(e.type==3){
          const float orbit=std::sin(elapsed*2.7f+(float)i*1.8f);
          steerX=(dx/safeD)*0.44f+(-dz/safeD)*orbit*0.92f;
          steerZ=(dz/safeD)*0.44f+(dx/safeD)*orbit*0.92f;
          moveScale=(d>2.0f)?1.0f:(0.34f+0.48f*std::abs(orbit));
          if(d<=0.68f){steerX=0.0f;steerZ=0.0f;moveScale=0.0f;if(enemyAttackCooldown[(size_t)i]<=0.0f){if(!invulnerableNow)hurtPlayer(0.085f);enemyAttackCooldown[(size_t)i]=0.72f;}}
        }else{
          if(d>e.radius+0.43f){steerX=dx/safeD;steerZ=dz/safeD;enemyWindup[(size_t)i]=0.0f;}
          else{enemyWindup[(size_t)i]=0.0f;if(enemyAttackCooldown[(size_t)i]<=0.0f){if(!invulnerableNow)hurtPlayer(0.12f);enemyAttackCooldown[(size_t)i]=0.82f;}}
        }
        enemySteerX[(size_t)i]=steerX;enemySteerZ[(size_t)i]=steerZ;enemyMoveScale[(size_t)i]=moveScale;
      }
      const float baseX=enemySteerX[(size_t)i],baseZ=enemySteerZ[(size_t)i];
      const float baseLength=std::sqrt(baseX*baseX+baseZ*baseZ);
      if(baseLength>0.001f){
        const float dirX=baseX/baseLength,dirZ=baseZ/baseLength;
        const float slalomPhase=elapsed*enemySlalomFrequency[(size_t)i]+enemySlalomPhase[(size_t)i];
        const float lateralWave=0.72f*std::sin(slalomPhase)+0.28f*std::cos(slalomPhase*0.5f+enemySlalomPhase[(size_t)i]*0.25f);
        const float lateral=lateralWave*enemySlalomStrength[(size_t)i];
        const float moveX=baseX-dirZ*lateral,moveZ=baseZ+dirX*lateral;
        e.x+=moveX*e.speed*enemyMoveScale[(size_t)i]*dt;
        e.z+=moveZ*e.speed*enemyMoveScale[(size_t)i]*dt;
        resolveCollision(e.x,e.z,e.radius);
      }
    }
    // Projectiles stop on cover; enemy shots only hurt the player.
    for(auto&s:shots){
      if(s.life<=0.0f)continue;
      s.x+=s.vx*dt;s.z+=s.vz*dt;s.life-=dt;
      if(s.life<=0.0f||projectileBlocked(s.x,s.z)){s.life=0.0f;continue;}
      if(s.hostile){const float dx=s.x-playerX,dz=s.z-playerZ;if(dx*dx+dz*dz<0.30f*0.30f){if(!invulnerableNow)hurtPlayer(0.10f);s.life=0.0f;}}
      else for(auto&e:enemies){if(e.hp<=0.0f)continue;const float dx=s.x-e.x,dz=s.z-e.z;if(dx*dx+dz*dz<(e.radius+0.12f)*(e.radius+0.12f)){e.hp=std::max(0.0f,e.hp-s.damage);s.life=0.0f;if(e.hp<=0.0f){defeated++;progression.registerElimination();}break;}}
    }
    processRoomClear();
    if(playerHealth<=0.0f){lost=true;moving=false;aiming=false;firing=false;gameMode=5;}
    if(activeRoom==ROOM_COUNT-1&&rooms[3].cleared&&defeated>=TOTAL_MISSION_ELIMINATIONS&&relayMask==0x7){float dx=playerX-activeExtractionX(),dz=playerZ-activeExtractionZ();if(dx*dx+dz*dz<0.82f*0.82f){won=true;moving=false;aiming=false;firing=false;gameMode=4;}}
  }
  publishSnapshot();
}
} // namespace

extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_NativeRenderer_nativeSurfaceCreated(JNIEnv*,jobject){
  // Initialize dungeon metadata once; EGL context recreation must not reset mission progress.
  if(!roomWorldInitialized)configureArena();
  // EGL can recreate the context after resume: rebuild every GL object.
  // EGL can recreate the context after resume: rebuild every GL object from a clean state.
  program=0;fallbackProgram=0;fallbackVao=0;postProgram=0;postVao=0;
  projectileProgram=0;projectileVao=0;projectileQuadVbo=0;projectileIndexBuffer=0;projectileInstanceVbo=0;
  sceneFramebuffer=0;sceneColorTexture=0;sceneDepthBuffer=0;sceneTargetW=sceneTargetH=0;
  cubeMesh={};sphereMesh={};organicMesh={};
  program=make3DProgram();
  if(!program){__android_log_print(ANDROID_LOG_ERROR,"NeonBreach","3D renderer failed, showing diagnostic fallback");fallbackProgram=makeFallbackProgram();}
  if(program){
    mvpLoc=glGetUniformLocation(program,"uMVP");modelLoc=glGetUniformLocation(program,"uModel");
    sectorPaletteLoc=glGetUniformLocation(program,"uSectorPalette");
    activeRoomLoc=glGetUniformLocation(program,"uActiveRoom");
    colorLoc=glGetUniformLocation(program,"uColor");glowLoc=glGetUniformLocation(program,"uGlow");
    cameraLoc=glGetUniformLocation(program,"uCamera");
    postProgram=makePostProgram();
    createProjectileRenderer();
    if(postProgram){
      postSceneLoc=glGetUniformLocation(postProgram,"uScene");
      postResolutionLoc=glGetUniformLocation(postProgram,"uResolution");
      glGenVertexArrays(1,&postVao);
    }
    createMeshes();
  }else if(fallbackProgram){fallbackResLoc=glGetUniformLocation(fallbackProgram,"uRes");glGenVertexArrays(1,&fallbackVao);}
  const GLubyte*version=glGetString(GL_VERSION);
  __android_log_print(ANDROID_LOG_INFO,"NeonBreach","Renderer startup: GLES=%s 3D=%s",version?(const char*)version:"unknown",program?"enabled":"fallback");
  glEnable(GL_DEPTH_TEST);glDepthFunc(GL_LEQUAL);glDisable(GL_CULL_FACE);glDisable(GL_BLEND);
  glClearColor(0.024f,0.032f,0.040f,1.0f);previousFrame=std::chrono::steady_clock::now();publishSnapshot();
}
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_NativeRenderer_nativeSurfaceChanged(JNIEnv*,jobject,jint w,jint h){
  screenW=std::max(1,(int)w);screenH=std::max(1,(int)h);
  glBindFramebuffer(GL_FRAMEBUFFER,0);glViewport(0,0,screenW,screenH);
  if(program&&postProgram&&postVao)createSceneTarget(screenW,screenH);
}
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_NativeRenderer_nativeDrawFrame(JNIEnv*,jobject){
  auto now=std::chrono::steady_clock::now();
  float frame=std::chrono::duration<float>(now-previousFrame).count();previousFrame=now;
  frame=std::clamp(frame,0.0f,0.05f);visualTime+=frame;accumulator+=frame;
  const float step=1.0f/60.0f;
  while(accumulator>=step){fixedUpdate(step);accumulator-=step;}
  const float desiredFocusX=gameMode==1?playerX*0.84f:((gameMode==0||gameMode==3||gameMode==6)?0.0f:cameraFocusX);
  const float desiredFocusZ=gameMode==1?std::clamp(playerZ*0.55f,-2.25f,2.25f):((gameMode==0||gameMode==3||gameMode==6)?0.0f:cameraFocusZ);
  updateCameraSpring(frame,desiredFocusX,desiredFocusZ);
  updateCameraShake(frame);
  const bool postprocessReady=program&&postProgram&&postVao&&sceneFramebuffer&&sceneColorTexture;
  glBindFramebuffer(GL_FRAMEBUFFER,postprocessReady?sceneFramebuffer:0);
  glViewport(0,0,postprocessReady?sceneTargetW:screenW,postprocessReady?sceneTargetH:screenH);
  glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
  if(!program){
    if(fallbackProgram){glUseProgram(fallbackProgram);glUniform2f(fallbackResLoc,(float)screenW,(float)screenH);glBindVertexArray(fallbackVao);glDrawArrays(GL_TRIANGLES,0,3);}
    return;
  }
  V3 camera{cameraFocusX,10.2f,cameraFocusZ+11.6f};
  Mat4 view=lookAt(camera,{cameraFocusX,0.0f,cameraFocusZ},{0.0f,1.0f,0.0f});
  // Screen-space view translation is inherited by every object MVP in this frame.
  view.v[12]+=cameraShakeOffsetX;
  view.v[13]+=cameraShakeOffsetY;
  Mat4 proj=perspective(46.0f*PI/180.0f,(float)screenW/(float)screenH,0.1f,60.0f);
  glUseProgram(program);
  if(sectorPaletteLoc>=0){
    const V3 roomPalettes[4]={{0.025f,0.16f,0.22f},{0.28f,0.12f,0.025f},{0.04f,0.15f,0.27f},{0.24f,0.045f,0.075f}};
    const V3 tint=roomPalettes[(size_t)activeRoom];
    glUniform3f(sectorPaletteLoc,tint.x,tint.y,tint.z);
  }
  if(activeRoomLoc>=0)glUniform1i(activeRoomLoc,activeRoom);
  drawScene(view,proj,camera);
  if(lost||won){
    V3 color=won?V3{0.0f,0.9f,0.38f}:V3{1.0f,0.04f,0.10f};
    V3 glow=won?V3{0.0f,0.48f,0.12f}:V3{0.35f,0.0f,0.015f};
    for(int i=0;i<28;i++){float a=2*PI*(float)i/28.0f;orb({std::cos(a)*0.75f,1.05f+0.05f*std::sin(elapsed*3),std::sin(a)*0.75f},{0.12f,0.12f,0.12f},color,glow,view,proj,camera);}
  }
  if(postprocessReady){
    glBindFramebuffer(GL_FRAMEBUFFER,0);
    glViewport(0,0,screenW,screenH);
    glDisable(GL_DEPTH_TEST);
    glUseProgram(postProgram);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D,sceneColorTexture);
    glUniform1i(postSceneLoc,0);
    glUniform2f(postResolutionLoc,(float)sceneTargetW,(float)sceneTargetH);
    glBindVertexArray(postVao);
    glDrawArrays(GL_TRIANGLES,0,3);
    glBindVertexArray(0);
    glBindTexture(GL_TEXTURE_2D,0);
    glEnable(GL_DEPTH_TEST);
  }
}
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_NativeRenderer_nativeSetMode(JNIEnv*,jobject,jint mode){
  if(mode>=0&&mode<=6){
    gameMode=mode;
    if(mode!=1){moving=false;aiming=false;firing=false;dodgeTime=0.0f;}
    previousFrame=std::chrono::steady_clock::now();
    publishSnapshot();
  }
}
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_NativeRenderer_nativeStartNewMission(JNIEnv*,jobject){
  resetMission();gameMode=1;previousFrame=std::chrono::steady_clock::now();publishSnapshot();
}
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_MainActivity_00024GameSurface_nativeSetOperative(JNIEnv*,jobject,jint selected){
  operativeClass=std::clamp((int)selected,0,1);publishSnapshot();
}
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_MainActivity_00024GameSurface_nativeSetTouchSensitivity(JNIEnv*,jobject,jfloat sensitivity){
  touchSensitivity=std::clamp((float)sensitivity,0.5f,1.5f);
}
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_MainActivity_00024GameSurface_nativeSetSoundEnabled(JNIEnv*,jobject,jboolean enabled){
  nativeSoundEnabled=enabled==JNI_TRUE;
}
extern "C" JNIEXPORT jint JNICALL Java_com_duckdream_neonbreach_NativeRenderer_nativeGetSnapshot(JNIEnv*,jobject){
  return (jint)publishedSnapshot.load(std::memory_order_relaxed);
}
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_MainActivity_00024GameSurface_nativeTouch(JNIEnv*,jobject,jint action,jfloat x,jfloat y,jfloat w,jfloat h){
  screenW=std::max(1,(int)w);screenH=std::max(1,(int)h);
  if(gameMode!=1)return;
  if(action==7){
    for(int i=0;i<2;i++){
      if(podCollected[(size_t)i])continue;
      const float px=playerX-POD_X[i],pz=playerZ-POD_Z[i];
      if(px*px+pz*pz<0.85f*0.85f){
        podCollected[(size_t)i]=true;
        playerHealth=std::min(1.0f,playerHealth+operativeMedicalHeal());
        __android_log_print(ANDROID_LOG_INFO,"NeonBreach","Field pod collected; health=%f",playerHealth);
        publishSnapshot();return;
      }
    }
    for(int i=0;i<3;i++){if(relayMask&(1<<i))continue;float dx=playerX-RELAY_X[i],dz=playerZ-RELAY_Z[i];const float range=operativeRelayInteractionRadius();if(dx*dx+dz*dz<range*range){relayMask|=(1<<i);__android_log_print(ANDROID_LOG_INFO,"NeonBreach","Containment relay %d restored; mask=%d",i+1,relayMask);publishSnapshot();return;}}
    publishSnapshot();return;
  }
  if(action==8){firing=true;publishSnapshot();return;}
  if(action==9){firing=false;publishSnapshot();return;}
  if(action==10){
    if(dodgeCooldown<=0.0f){dodgeDirX=moveDirX;dodgeDirZ=moveDirZ;if(!moving){dodgeDirX=std::sin(facingYaw);dodgeDirZ=std::cos(facingYaw);}dodgeTime=0.20f;dodgeCooldown=operativeDodgeCooldown();}
    publishSnapshot();return;
  }
  switch(action){
    case 0: moving=true;moveOriginX=moveX=x;moveOriginY=moveY=y;break;
    case 1: if(moving){moveX=moveOriginX+(x-moveOriginX)*touchSensitivity;moveY=moveOriginY+(y-moveOriginY)*touchSensitivity;}break;
    case 2: moving=false;break;
    case 3:
      aiming=true;aimOriginX=x;aimOriginY=y;
      aimX=playerX+std::sin(facingYaw)*5.0f;
      aimZ=playerZ+std::cos(facingYaw)*5.0f;
      break;
    case 4: if(aiming){float dx=(x-aimOriginX)*touchSensitivity/(float)screenH,dz=(y-aimOriginY)*touchSensitivity/(float)screenH;float mag=std::sqrt(dx*dx+dz*dz);if(mag>0.035f){aimX=playerX+dx/mag*5.0f;aimZ=playerZ+dz/mag*5.0f;}}break;
    case 5: if(aiming)facingYaw=std::atan2(aimX-playerX,aimZ-playerZ);aiming=false;break;
    case 6: moving=false;aiming=false;firing=false;break;
  }
  publishSnapshot();
}
