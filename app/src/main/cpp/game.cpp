#include <jni.h>
#include <GLES3/gl3.h>
#include <android/log.h>
#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstddef>
#include <vector>

namespace {
constexpr float PI = 3.14159265358979323846f;
struct V3 { float x, y, z; };
struct Mat4 { float v[16]; };
struct Vertex { float px, py, pz, nx, ny, nz; };
struct Mesh { GLuint vao=0, vbo=0; GLsizei count=0; };
struct Obstacle { float x,z,sx,sz,h; };
struct Enemy { float x,z,hp,maxHp,speed,radius; int type; float yaw; };
struct Shot { float x,y,z,vx,vz,life; bool hostile=false; float damage=1.0f; };

GLuint program=0, fallbackProgram=0, fallbackVao=0;
GLint mvpLoc=-1, modelLoc=-1, colorLoc=-1, glowLoc=-1, cameraLoc=-1;
GLint fallbackResLoc=-1;
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
int missionSerial=0, arenaVariant=0;
int operativeClass=0; // 0 Kestrel, 1 Bastion, 2 Patch
std::array<float,4> enemyShotCooldown{};
std::array<float,4> enemyWindup{};
std::array<float,4> enemyAttackCooldown{};
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
std::array<Obstacle,4> obstacles{{
  {-2.95f,0.15f,1.05f,0.78f,0.62f},
  {-0.45f,2.00f,0.92f,0.70f,0.72f},
  { 2.20f,0.10f,1.08f,0.84f,0.58f},
  { 1.65f,-2.72f,0.88f,1.00f,0.65f}
}};
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
constexpr float POD_X[2]={-2.95f,3.55f};
constexpr float POD_Z[2]={-3.32f,0.10f};
constexpr float HAZARD_X[2]={-1.20f,3.85f};
constexpr float HAZARD_Z[2]={-1.55f,-1.35f};
std::array<bool,2> podCollected{{false,false}};
std::array<float,2> hazardCooldown{{0.0f,0.0f}};
float operativeMoveSpeed(){return operativeClass==0?4.25f:(operativeClass==1?2.95f:3.55f);}
float operativeFireInterval(){return operativeClass==0?0.13f:(operativeClass==1?0.26f:0.105f);}
float operativeShotDamage(){return operativeClass==1?1.45f:(operativeClass==2?0.72f:1.0f);}
float operativeDamageTakenMultiplier(){return operativeClass==1?0.65f:1.0f;}
float operativeDodgeCooldown(){return operativeClass==0?0.82f:(operativeClass==1?1.45f:1.15f);}
float operativeMedicalHeal(){return operativeClass==2?0.40f:0.24f;}
float operativeRelayInteractionRadius(){return operativeClass==2?1.70f:1.25f;}
void hurtPlayer(float amount){playerHealth=std::max(0.0f,playerHealth-amount*operativeDamageTakenMultiplier());}

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
    const float r=1.0f+wave;
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
  uniform vec3 uColor;uniform vec3 uGlow;uniform vec3 uCamera;
  out vec4 outColor;
  void main(){
    vec3 n=normalize(vNormal);vec3 light=normalize(vec3(-0.42,0.88,0.34));
    float diffuse=max(dot(n,light),0.0);
    vec3 viewDir=normalize(uCamera-vWorld);
    float spec=pow(max(dot(reflect(-light,n),viewDir),0.0),20.0)*0.16;
    float fillLight=max(dot(n,normalize(vec3(0.72,0.28,-0.44))),0.0)*0.16;
    float rim=pow(1.0-max(dot(n,viewDir),0.0),2.7);
    vec3 col=uColor*(0.22+0.68*diffuse+fillLight)+spec;
    // Deterministic world-space grain adds material variation without downloaded textures.
    vec2 grainCell=floor(vWorld.xz*vec2(19.0,17.0));
    float grain=fract(sin(dot(grainCell,vec2(12.9898,78.233)))*43758.5453);
    float mottling=0.94+0.11*grain;
    col*=mottling;
    col+=uGlow+rim*(0.035+0.095*dot(uColor,vec3(0.333)));
    float fog=clamp((length(uCamera-vWorld)-9.0)/25.0,0.0,0.42);
    col=mix(col,vec3(0.018,0.027,0.040),fog);
    outColor=vec4(col,1.0);
  })";
  return linkProgram(vs,fs,"3D scene");
}
GLuint makeFallbackProgram(){
  const char*vs=R"(#version 300 es
  void main(){vec2 p[3]=vec2[3](vec2(-1.0,-1.0),vec2(3.0,-1.0),vec2(-1.0,3.0));gl_Position=vec4(p[gl_VertexID],0.0,1.0);})";
  const char*fs=R"(#version 300 es
  precision mediump float;uniform vec2 uRes;out vec4 outColor;
  void main(){vec2 uv=gl_FragCoord.xy/max(uRes,vec2(1.0));vec2 cellCoord=fract(uv*vec2(18.0,10.0));float g=max(step(0.97,cellCoord.x),step(0.97,cellCoord.y));vec3 c=vec3(0.006,0.014,0.03)+g*vec3(0.0,0.22,0.34);float d=1.0-smoothstep(0.015,0.04,length(uv-vec2(0.5)));c+=d*vec3(0.0,0.6,0.9);outColor=vec4(c,1.0);})";
  return linkProgram(vs,fs,"fallback");
}
void configureArena(){
  arenaVariant=missionSerial%3;missionSerial++;
  if(arenaVariant==1)obstacles=ARENA_LAYOUT_B;
  else if(arenaVariant==2)obstacles=ARENA_LAYOUT_C;
  else obstacles={{
    {-2.65f,1.45f,0.95f,0.50f,0.70f},
    {-0.10f,2.55f,0.90f,0.46f,0.65f},
    {1.50f,-1.25f,0.92f,0.52f,0.62f},
    {3.12f,0.20f,0.88f,0.46f,0.72f}
  }};
}
void resetMission(){
  configureArena();
  playerX=-5.15f;playerZ=-3.25f;playerHealth=1.0f;
  cameraFocusX=std::clamp(playerX*0.68f,-3.8f,3.8f);cameraFocusZ=std::clamp(playerZ*0.55f,-2.25f,2.25f);
  aimX=playerX;aimZ=playerZ-5.0f;elapsed=0;accumulator=0;
  moving=false;aiming=false;firing=false;shotCooldown=0;facingYaw=PI;moveDirX=0.0f;moveDirZ=-1.0f;
  dodgeTime=0.0f;dodgeCooldown=0.0f;dodgeDirX=0.0f;dodgeDirZ=-1.0f;
  won=false;lost=false;defeated=0;relayMask=0;podCollected={{false,false}};hazardCooldown.fill(0.0f);
  enemyShotCooldown.fill(0.8f);enemyWindup.fill(0.0f);enemyAttackCooldown.fill(0.0f);
  shots.fill({});
  if(arenaVariant==0){
    enemies={{{-3.85f,2.95f,1,1,1.10f,0.36f,0,PI},{0.85f,2.90f,2,2,0.72f,0.48f,1,PI},{3.90f,0.15f,1,1,1.35f,0.31f,2,PI},{-1.45f,-2.45f,1,1,1.62f,0.31f,3,PI}}};
  }else if(arenaVariant==1){
    enemies={{{-4.40f,1.45f,1,1,1.10f,0.36f,0,PI},{1.45f,2.90f,2,2,0.72f,0.48f,1,PI},{3.35f,-0.40f,1,1,1.35f,0.31f,2,PI},{-0.75f,-2.30f,1,1,1.62f,0.31f,3,PI}}};
  }else{
    enemies={{{-2.75f,3.35f,1,1,1.10f,0.36f,0,PI},{2.05f,2.40f,2,2,0.72f,0.48f,1,PI},{4.00f,0.60f,1,1,1.35f,0.31f,2,PI},{0.45f,-3.10f,1,1,1.62f,0.31f,3,PI}}};
  }
}
void resolveCollision(float&x,float&z,float radius){
  x=std::clamp(x,-6.10f+radius,6.10f-radius);z=std::clamp(z,-4.30f+radius,4.30f-radius);
  for(const auto&o:obstacles){
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
void drawHumanoid(V3 at,float yaw,float phase,float gait,int archetype,bool isPlayer,V3 armor,V3 trim,V3 glow,const Mat4&view,const Mat4&proj,V3 cam){
  if(isPlayer){
    if(archetype==0){armor={0.16f,0.25f,0.31f};trim={0.96f,0.38f,0.12f};glow={0.012f,0.075f,0.12f};}
    else if(archetype==1){armor={0.22f,0.25f,0.28f};trim={0.96f,0.58f,0.18f};glow={0.07f,0.032f,0.006f};}
    else{armor={0.10f,0.27f,0.27f};trim={0.62f,0.87f,0.78f};glow={0.008f,0.10f,0.095f};}
  }
  const float widthScale=(isPlayer&&archetype==1)?1.17f:((isPlayer&&archetype==2)?1.02f:0.94f);
  const float swing=std::sin(phase)*gait;
  const float bob=0.018f*std::sin(phase*2.0f)*gait;
  const V3 forward{std::sin(yaw),0.0f,std::cos(yaw)},right{std::cos(yaw),0.0f,-std::sin(yaw)};
  auto point=[&](float side,float front,float y)->V3{
    return {at.x+right.x*side+forward.x*front,at.y+y+bob,at.z+right.z*side+forward.z*front};
  };
  const V3 cloth{0.18f,0.20f,0.14f},leather{0.24f,0.15f,0.085f},dark{0.075f,0.085f,0.065f};
  orb({at.x,0.018f,at.z},{0.66f,0.028f,0.58f},{0.025f,0.030f,0.020f},{0,0,0},view,proj,cam);
  for(int sign : {-1,1}){
    const float side=(float)sign,leg=swing*side;
    poseOrb(point(side*0.14f,leg*0.07f,0.245f),{0.17f,0.26f,0.17f},armor,glow,yaw,leg*0.22f,side*0.025f,view,proj,cam);
    poseOrb(point(side*0.14f,leg*0.13f,0.115f),{0.135f,0.20f,0.14f},cloth,{0.006f,0.008f,0.004f},yaw,-leg*0.17f,side*0.02f,view,proj,cam);
    poseOrb(point(side*0.145f,leg*0.17f+0.10f,0.055f),{0.20f,0.095f,0.23f},leather,{0.01f,0.004f,0.0f},yaw,0.0f,0.0f,view,proj,cam);
  }
  poseOrganic(point(0,-0.025f,0.40f),{0.34f,0.24f,0.28f},dark,{0.005f,0.006f,0.003f},yaw,0.0f,0.0f,view,proj,cam);
  poseOrganic(point(0,0.015f,0.585f),{0.42f*widthScale,0.43f,0.32f*widthScale},armor,glow,yaw,-0.04f,0.0f,view,proj,cam);
  poseOrb(point(0,0.135f,0.59f),{0.33f,0.30f,0.17f},cloth,{0.004f,0.006f,0.002f},yaw,0.0f,0.0f,view,proj,cam);
  poseOrb(point(0,0.205f,0.61f),{0.13f,0.11f,0.06f},trim,{0.028f,0.035f,0.008f},yaw,0.0f,0.0f,view,proj,cam);
  poseOrganic(point(0,-0.19f,0.60f),{0.27f,0.31f,0.18f},leather,{0.008f,0.005f,0.001f},yaw,0.0f,0.0f,view,proj,cam);
  for(int sign : {-1,1}){
    const float side=(float)sign,arm=swing*side;
    poseOrganic(point(side*0.30f*widthScale,0.0f,0.67f),{0.24f*widthScale,0.20f,0.23f*widthScale},armor,glow,yaw,0.0f,side*0.12f,view,proj,cam);
    poseOrb(point(side*0.34f,-arm*0.06f,0.52f),{0.15f,0.23f,0.15f},cloth,{0.006f,0.007f,0.004f},yaw,arm*0.25f,side*0.17f,view,proj,cam);
    poseOrb(point(side*0.35f,-arm*0.10f,0.37f),{0.13f,0.20f,0.13f},armor,glow,yaw,arm*0.34f,side*0.11f,view,proj,cam);
    poseOrb(point(side*0.36f,-arm*0.12f,0.245f),{0.12f,0.12f,0.12f},leather,{0.005f,0.003f,0.0f},yaw,0.0f,side*0.08f,view,proj,cam);
  }
  // A hooded field helmet and a small glass-like visor replace the old square robot head.
  poseOrganic(point(0,0,0.995f),{0.27f,0.26f,0.25f},leather,{0.008f,0.005f,0.001f},yaw,0.0f,0.0f,view,proj,cam);
  poseOrb(point(0,0.085f,1.045f),{0.26f,0.205f,0.22f},armor,glow,yaw,0.0f,0.0f,view,proj,cam);
  poseOrb(point(0,0.15f,1.055f),{0.18f,0.064f,0.055f},{0.19f,0.22f,0.13f},{0.025f,0.03f,0.006f},yaw,0.0f,0.0f,view,proj,cam);
  poseOrb(point(0,0.165f,1.063f),{0.11f,0.027f,0.027f},{0.52f,0.59f,0.38f},{0.04f,0.045f,0.015f},yaw,0.0f,0.0f,view,proj,cam);
  poseOrganic(point(-0.23f,-0.12f,0.69f),{0.24f,0.31f,0.24f},leather,{0.008f,0.004f,0.0f},yaw,-0.06f,-0.12f,view,proj,cam);
  poseOrganic(point(0.17f,-0.36f,0.56f),{0.25f,0.33f,0.22f},dark,{0.004f,0.004f,0.002f},yaw,0.02f,0.08f,view,proj,cam);
  poseOrb(point(0.19f,0.25f,0.43f),{0.085f,0.085f,0.28f},dark,{0.002f,0.003f,0.001f},yaw,0.0f,0.0f,view,proj,cam);
  poseOrb(point(0.19f,0.36f,0.45f),{0.07f,0.07f,0.20f},trim,{0.018f,0.025f,0.003f},yaw,0.0f,0.0f,view,proj,cam);
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
    |(nearActiveRelay()?1<<16:0)|(dodgeCooldown<=0.0f?1<<17:0)|(nearFieldPod()?1<<18:0)|(nearActiveHazard()?1<<19:0);
  publishedSnapshot.store(packed,std::memory_order_relaxed);
}
void drawScene(const Mat4&view,const Mat4&proj,V3 cam){
  // ORION INDUSTRIAL MODULES: layered steel, service conduits and containment hardware.
  box({0.0f,-0.25f,0.0f},{17.0f,0.44f,13.0f},{0.052f,0.064f,0.080f},{0.002f,0.004f,0.008f},0,view,proj,cam);
  box({0.0f,-0.006f,0.0f},{14.3f,0.035f,10.5f},{0.16f,0.18f,0.20f},{0.003f,0.005f,0.008f},0,view,proj,cam);

  // Flush floor-panel seams create scale and a readable industrial layout.
  for(int row=-2;row<=2;row++){
    const float z=(float)row*1.72f;
    box({0.0f,0.014f,z},{13.9f,0.012f,0.022f},{0.055f,0.070f,0.082f},{0.001f,0.002f,0.004f},0,view,proj,cam);
  }
  for(int column=-3;column<=3;column++){
    const float x=(float)column*1.72f;
    box({x,0.014f,0.0f},{0.022f,0.012f,10.1f},{0.055f,0.070f,0.082f},{0.001f,0.002f,0.004f},0,view,proj,cam);
  }
  // A marked transfer lane leads from the entry toward the containment zone.
  for(int i=0;i<5;i++){
    const float z=-3.95f+(float)i*0.43f;
    box({-3.35f,0.026f,z},{0.055f,0.014f,0.22f},{0.20f,0.66f,0.69f},{0.003f,0.025f,0.028f},0,view,proj,cam);
  }
  // Amber restricted-zone bars are placed along the rear service boundary, not through combat lanes.
  for(int i=0;i<7;i++){
    const float x=-5.25f+(float)i*1.75f;
    box({x,0.027f,4.16f},{0.46f,0.016f,0.085f},(i%2==0)?V3{0.80f,0.34f,0.075f}:V3{0.12f,0.14f,0.15f},
      (i%2==0)?V3{0.030f,0.006f,0.001f}:V3{0.001f,0.002f,0.003f},0,view,proj,cam);
  }

  // Structural perimeter and bulkhead. The central doorway is a visual landmark.
  box({-6.55f,0.78f,0.0f},{0.24f,1.56f,9.65f},{0.075f,0.095f,0.11f},{0.002f,0.005f,0.008f},0,view,proj,cam);
  box({ 6.55f,0.78f,0.0f},{0.24f,1.56f,9.65f},{0.075f,0.095f,0.11f},{0.002f,0.005f,0.008f},0,view,proj,cam);
  box({-3.75f,0.76f,4.88f},{5.55f,1.52f,0.28f},{0.095f,0.12f,0.14f},{0.003f,0.006f,0.009f},0,view,proj,cam);
  box({ 3.70f,0.76f,4.88f},{5.65f,1.52f,0.28f},{0.095f,0.12f,0.14f},{0.003f,0.006f,0.009f},0,view,proj,cam);
  // Reinforced door jambs and header surround the decontamination shutter.
  box({-1.12f,0.77f,4.62f},{0.18f,1.54f,0.36f},{0.19f,0.23f,0.25f},{0.004f,0.007f,0.010f},0,view,proj,cam);
  box({ 1.12f,0.77f,4.62f},{0.18f,1.54f,0.36f},{0.19f,0.23f,0.25f},{0.004f,0.007f,0.010f},0,view,proj,cam);
  box({0.0f,1.55f,4.62f},{2.42f,0.20f,0.36f},{0.19f,0.23f,0.25f},{0.004f,0.007f,0.010f},0,view,proj,cam);
  box({0.0f,0.80f,4.69f},{1.86f,1.25f,0.06f},{0.045f,0.060f,0.075f},{0.001f,0.003f,0.006f},0,view,proj,cam);
  box({0.0f,1.36f,4.64f},{1.55f,0.06f,0.07f},{0.80f,0.31f,0.065f},{0.045f,0.008f,0.001f},0,view,proj,cam);

  // Repeated wall ribs and emergency status lights establish a facility rhythm.
  for(int i=0;i<6;i++){
    const float z=-3.72f+(float)i*1.48f;
    box({-6.36f,0.78f,z},{0.10f,1.62f,0.13f},{0.16f,0.19f,0.21f},{0.002f,0.004f,0.006f},0,view,proj,cam);
    box({ 6.36f,0.78f,z},{0.10f,1.62f,0.13f},{0.16f,0.19f,0.21f},{0.002f,0.004f,0.006f},0,view,proj,cam);
    if(i%2==0){
      box({-6.29f,1.24f,z},{0.035f,0.12f,0.30f},{0.84f,0.29f,0.065f},{0.038f,0.006f,0.001f},0,view,proj,cam);
      box({ 6.29f,1.24f,z},{0.035f,0.12f,0.30f},{0.84f,0.29f,0.065f},{0.038f,0.006f,0.001f},0,view,proj,cam);
    }
  }

  // Exposed service pipes run above the playable lanes and turn into the side bulkheads.
  box({-5.82f,1.86f,0.20f},{0.13f,0.13f,8.95f},{0.20f,0.25f,0.28f},{0.004f,0.008f,0.011f},0,view,proj,cam);
  box({-5.57f,1.70f,0.20f},{0.08f,0.08f,8.95f},{0.48f,0.24f,0.095f},{0.015f,0.005f,0.001f},0,view,proj,cam);
  box({ 5.82f,1.86f,0.20f},{0.13f,0.13f,8.95f},{0.20f,0.25f,0.28f},{0.004f,0.008f,0.011f},0,view,proj,cam);
  box({ 5.57f,1.70f,0.20f},{0.08f,0.08f,8.95f},{0.48f,0.24f,0.095f},{0.015f,0.005f,0.001f},0,view,proj,cam);
  box({0.0f,1.96f,4.26f},{10.9f,0.14f,0.14f},{0.20f,0.25f,0.28f},{0.004f,0.008f,0.011f},0,view,proj,cam);
  box({0.0f,1.80f,4.02f},{10.9f,0.08f,0.08f},{0.48f,0.24f,0.095f},{0.015f,0.005f,0.001f},0,view,proj,cam);

  // Industrial ceiling light housings: restrained glow, with open sky above the camera view.
  for(int i=0;i<3;i++){
    const float x=-4.0f+(float)i*4.0f;
    box({x,2.12f,0.75f},{0.92f,0.14f,0.34f},{0.085f,0.12f,0.15f},{0.003f,0.009f,0.014f},0,view,proj,cam);
    box({x,2.035f,0.75f},{0.68f,0.025f,0.12f},{0.17f,0.72f,0.77f},{0.018f,0.075f,0.082f},0,view,proj,cam);
  }

  // Wall-mounted diagnostics: simple geometry but unmistakably facility equipment.
  for(int i=0;i<2;i++){
    const float side=i==0?-1.0f:1.0f;
    const float x=side*6.16f;
    const float z=i==0?1.15f:-1.85f;
    box({x,1.07f,z},{0.12f,0.60f,0.82f},{0.055f,0.075f,0.095f},{0.002f,0.006f,0.010f},0,view,proj,cam);
    box({x-side*0.07f,1.12f,z},{0.025f,0.31f,0.52f},{0.10f,0.47f,0.55f},{0.006f,0.035f,0.042f},0,view,proj,cam);
    for(int led=0;led<3;led++)box({x-side*0.09f,1.30f-(float)led*0.13f,z+0.27f},{0.025f,0.045f,0.045f},
      led==0?V3{0.88f,0.32f,0.07f}:V3{0.12f,0.68f,0.55f},led==0?V3{0.035f,0.006f,0.001f}:V3{0.004f,0.02f,0.015f},0,view,proj,cam);
  }
  // Utility consoles with hazard markings are cover; they also keep their collision geometry.
  for(size_t i=0;i<obstacles.size();i++){
    const auto&o=obstacles[i];const float yaw=(float)i*0.16f;
    box({o.x,o.h*0.43f,o.z},{o.sx*1.12f,o.h*0.86f,o.sz*1.10f},{0.105f,0.135f,0.15f},{0.006f,0.010f,0.012f},yaw,view,proj,cam);
    box({o.x,o.h*0.87f,o.z},{o.sx*0.84f,0.075f,o.sz*0.83f},{0.23f,0.27f,0.27f},{0.003f,0.004f,0.004f},yaw,view,proj,cam);
    box({o.x,o.h*0.62f,o.z+o.sz*0.54f},{o.sx*0.64f,0.055f,0.035f},{0.80f,0.31f,0.08f},{0.035f,0.008f,0.001f},yaw,view,proj,cam);
  }
  // Three containment relays have hardware silhouettes and amber/cyan states.
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
  // Amber spore beds pulse in cycles. Their color and radius telegraph when the patch is dangerous.
  for(int i=0;i<2;i++){
    const float cycle=std::fmod(elapsed+(float)i*1.55f,3.8f);
    const bool dangerous=cycle>2.4f&&cycle<3.15f;
    const float radius=(dangerous?0.80f:0.62f)+0.035f*std::sin(visualTime*2.0f+(float)i);
    const V3 sporeColor=dangerous?V3{0.83f,0.35f,0.075f}:V3{0.31f,0.29f,0.16f};
    const V3 sporeGlow=dangerous?V3{0.055f,0.012f,0.001f}:V3{0.002f,0.003f,0.001f};
    for(int k=0;k<8;k++){
      const float a=2.0f*PI*(float)k/8.0f;
      poseOrb({HAZARD_X[i]+std::cos(a)*radius,0.042f,HAZARD_Z[i]+std::sin(a)*radius},
        {0.14f,0.055f,0.14f},sporeColor,sporeGlow,0,0,0,view,proj,cam);
    }
    poseOrganic({HAZARD_X[i],0.12f+0.025f*std::sin(visualTime*1.8f+(float)i),HAZARD_Z[i]},
      {0.38f,0.24f,0.38f},dangerous?V3{0.61f,0.31f,0.10f}:V3{0.25f,0.25f,0.14f},
      sporeGlow,visualTime*0.08f,0,0,view,proj,cam);
  }
  // Medical capsules provide readable health recovery.
  for(int i=0;i<2;i++){
    if(podCollected[(size_t)i])continue;const float x=POD_X[i],z=POD_Z[i];
    box({x,0.10f,z},{0.42f,0.20f,0.38f},{0.12f,0.15f,0.16f},{0.004f,0.008f,0.010f},0,view,proj,cam);
    box({x,0.24f,z},{0.30f,0.10f,0.27f},{0.28f,0.34f,0.33f},{0.003f,0.006f,0.006f},0,view,proj,cam);
    box({x,0.32f,z},{0.07f,0.13f,0.07f},{0.12f,0.80f,0.82f},{0.015f,0.10f,0.12f},0,view,proj,cam);
    poseOrb({x,0.43f+0.035f*std::sin(visualTime*1.6f+(float)i),z},{0.11f,0.14f,0.11f},{0.70f,0.88f,0.86f},{0.02f,0.08f,0.075f},0,0,0,view,proj,cam);
  }
  // Extraction is a marked transfer pad, unlocked after relays and threats are handled.
  const bool objectiveComplete=allEnemiesDefeated()&&relayMask==0x7;
  box({EXIT_X,0.025f,EXIT_Z},{1.55f,0.10f,1.25f},{0.075f,0.105f,0.12f},{0.003f,0.006f,0.009f},0,view,proj,cam);
  box({EXIT_X,0.085f,EXIT_Z},{1.28f,0.035f,0.98f},{0.15f,0.19f,0.20f},{0.003f,0.005f,0.006f},0,view,proj,cam);
  for(int i=0;i<5;i++){const float dx=((float)i-2.0f)*0.22f;box({EXIT_X+dx,0.11f,EXIT_Z-0.40f},{0.12f,0.035f,0.08f},objectiveComplete?V3{0.10f,0.78f,0.82f}:V3{0.88f,0.32f,0.07f},objectiveComplete?V3{0.01f,0.10f,0.12f}:V3{0.055f,0.008f,0.001f},0,view,proj,cam);}
  poseOrb({EXIT_X,0.34f+0.05f*std::sin(visualTime*1.6f),EXIT_Z},{0.15f,0.22f,0.15f},objectiveComplete?V3{0.15f,0.86f,0.84f}:V3{0.90f,0.40f,0.10f},objectiveComplete?V3{0.015f,0.12f,0.12f}:V3{0.07f,0.013f,0.001f},0,0,0,view,proj,cam);
  // The player's outfit is rounded and field-worn; the camera keeps the whole clearing readable.
  const float playerYaw=aiming?std::atan2(aimX-playerX,aimZ-playerZ):facingYaw;
  const float inputDx=(moveX-moveOriginX)/(float)std::max(1,screenH);
  const float inputDy=(moveY-moveOriginY)/(float)std::max(1,screenH);
  const float inputMagnitude=std::sqrt(inputDx*inputDx+inputDy*inputDy);
  const float playerGait=moving?std::clamp(inputMagnitude/0.13f,0.0f,1.0f):0.0f;
  drawHumanoid({playerX,0.0f,playerZ},playerYaw,elapsed*8.0f,playerGait,operativeClass,true,
    {0.28f,0.34f,0.20f},{0.59f,0.51f,0.27f},{0.012f,0.018f,0.003f},view,proj,cam);
  // Four creatures use different anatomies and behaviors rather than a shared robot rig.
  for(size_t i=0;i<enemies.size();i++){
    const auto&e=enemies[i];if(e.hp<=0.0f)continue;
    const float distanceToPlayer=std::sqrt((playerX-e.x)*(playerX-e.x)+(playerZ-e.z)*(playerZ-e.z));
    const float enemyGait=distanceToPlayer>e.radius+0.48f?0.88f:0.20f;
    const V3 enemyArmor=e.type==1?V3{0.30f,0.18f,0.095f}:(e.type==2?V3{0.23f,0.30f,0.13f}:(e.type==3?V3{0.33f,0.23f,0.10f}:V3{0.20f,0.27f,0.12f}));
    const V3 enemyTrim=e.type==1?V3{0.75f,0.43f,0.16f}:(e.type==2?V3{0.72f,0.72f,0.38f}:(e.type==3?V3{0.63f,0.37f,0.16f}:V3{0.52f,0.57f,0.22f}));
    const V3 enemyGlow=e.type==1?V3{0.035f,0.014f,0.001f}:(e.type==2?V3{0.024f,0.035f,0.005f}:V3{0.015f,0.019f,0.002f});
    drawCreature({e.x,0.0f,e.z},e.yaw,elapsed*(4.6f+e.speed),enemyGait,e.type,enemyArmor,enemyTrim,enemyGlow,view,proj,cam);
    const int healthBeads=(int)std::ceil(3.0f*e.hp/std::max(1.0f,e.maxHp));
    for(int bead=0;bead<healthBeads;bead++){
      const float a=2.0f*PI*(float)bead/3.0f;
      poseOrb({e.x+std::cos(a)*0.30f,1.38f,e.z+std::sin(a)*0.30f},{0.085f,0.075f,0.085f},
        enemyTrim,{0.008f,0.004f,0.001f},0,0,0,view,proj,cam);
    }
    if(e.type==1&&enemyWindup[i]>0.04f){
      const float ring=0.65f+0.25f*std::clamp(enemyWindup[i]/0.42f,0.0f,1.0f);
      for(int k=0;k<8;k++){
        const float a=2.0f*PI*(float)k/8.0f;
        poseOrb({e.x+std::cos(a)*ring,0.035f,e.z+std::sin(a)*ring},{0.12f,0.035f,0.12f},
          {0.78f,0.29f,0.075f},{0.03f,0.006f,0.001f},0,0,0,view,proj,cam);
      }
    }
  }
  // A small soft reticle makes drag-aim readable without a segmented neon ring.
  if(aiming&&!won&&!lost){
    poseOrb({aimX,0.045f,aimZ},{0.12f,0.035f,0.12f},{0.66f,0.78f,0.40f},{0.015f,0.02f,0.002f},0,0,0,view,proj,cam);
    for(int i=0;i<4;i++){
      const float a=2.0f*PI*(float)i/4.0f;
      poseOrb({aimX+std::cos(a)*0.20f,0.045f,aimZ+std::sin(a)*0.20f},{0.055f,0.035f,0.055f},
        {0.72f,0.81f,0.47f},{0.01f,0.015f,0.002f},0,0,0,view,proj,cam);
    }
  }
  for(const auto&s:shots)if(s.life>0.0f){
    if(s.hostile)orb({s.x,0.34f,s.z},{0.15f,0.15f,0.15f},{0.85f,0.33f,0.10f},{0.045f,0.007f,0.001f},view,proj,cam);
    else orb({s.x,0.34f,s.z},{0.16f,0.16f,0.16f},{0.73f,0.85f,0.45f},{0.02f,0.025f,0.004f},view,proj,cam);
  }
  // Subtle count markers sit inside the ground-cover rather than floating over a blue grid.
  for(size_t i=0;i<enemies.size();i++){
    const bool alive=enemies[i].hp>0.0f;
    poseOrb({-5.45f+0.32f*(float)i,0.055f,-4.02f},{0.10f,0.07f,0.10f},
      alive?V3{0.60f,0.27f,0.11f}:V3{0.24f,0.45f,0.17f},
      alive?V3{0.015f,0.003f,0.0f}:V3{0.003f,0.008f,0.001f},0,0,0,view,proj,cam);
  }
}
bool projectileBlocked(float x,float z){
  if(x<-4.78f||x>4.78f||z<-3.34f||z>3.34f)return true;
  for(const auto&o:obstacles)if(std::abs(x-o.x)<=o.sx*0.5f+0.055f&&std::abs(z-o.z)<=o.sz*0.5f+0.055f)return true;
  return false;
}
void fixedUpdate(float dt){
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
    if(dodgeTime>0.0f){playerX+=dodgeDirX*8.2f*dt;playerZ+=dodgeDirZ*8.2f*dt;resolveCollision(playerX,playerZ,0.30f);}
    else if(moving&&inputStrength>0.0f){playerX+=moveDirX*operativeMoveSpeed()*inputStrength*dt;playerZ+=moveDirZ*operativeMoveSpeed()*inputStrength*dt;resolveCollision(playerX,playerZ,0.30f);}
    if(aiming){const float ax=aimX-playerX,az=aimZ-playerZ;if(std::abs(ax)+std::abs(az)>0.001f)facingYaw=std::atan2(ax,az);}

    // Dedicated hold-to-fire; aim drag only steers the weapon.
    if(firing&&shotCooldown<=0.0f&&playerHealth>0.0f){
      int slot=-1;for(int i=0;i<(int)shots.size();i++)if(shots[i].life<=0.0f){slot=i;break;}
      if(slot>=0){
        float dx,dz;
        if(aiming){dx=aimX-playerX;dz=aimZ-playerZ;const float d=std::sqrt(dx*dx+dz*dz);if(d>0.001f){dx/=d;dz/=d;}else{dx=std::sin(facingYaw);dz=std::cos(facingYaw);}}
        else{dx=std::sin(facingYaw);dz=std::cos(facingYaw);}
        shots[slot]={playerX+dx*0.48f,0.45f,playerZ+dz*0.48f,dx*8.3f,dz*8.3f,1.12f,false,operativeShotDamage()};shotCooldown=operativeFireInterval();
      }
    }
    // Chasers close distance; heavy units telegraph a lunge; ranged units strafe and shoot.
    for(int i=0;i<(int)enemies.size();i++){
      auto&e=enemies[i];if(e.hp<=0.0f)continue;
      float dx=playerX-e.x,dz=playerZ-e.z,d=std::sqrt(dx*dx+dz*dz);
      if(d>0.001f)e.yaw=std::atan2(dx,dz);
      if(e.type==2){
        float vx=0.0f,vz=0.0f;
        if(d>3.25f){vx=dx/std::max(0.001f,d);vz=dz/std::max(0.001f,d);}
        else if(d<2.15f){vx=-dx/std::max(0.001f,d);vz=-dz/std::max(0.001f,d);}
        else{const float strafe=std::sin(elapsed*1.15f+(float)i*2.1f)*0.55f;vx=(-dz/std::max(0.001f,d))*strafe;vz=(dx/std::max(0.001f,d))*strafe;}
        e.x+=vx*e.speed*dt;e.z+=vz*e.speed*dt;resolveCollision(e.x,e.z,e.radius);
        if(d<6.0f&&enemyShotCooldown[i]<=0.0f){
          int slot=-1;for(int k=0;k<(int)shots.size();k++)if(shots[k].life<=0.0f){slot=k;break;}
          if(slot>=0&&d>0.1f){shots[slot]={e.x,0.38f,e.z,dx/d*4.6f,dz/d*4.6f,2.0f,true};enemyShotCooldown[i]=1.55f;}
        }
      }else if(e.type==1){
        if(d>1.22f){const float step=std::min(e.speed*dt,std::max(0.0f,d-1.08f));if(d>0.001f){e.x+=dx/d*step;e.z+=dz/d*step;}enemyWindup[i]=std::max(0.0f,enemyWindup[i]-dt*2.5f);resolveCollision(e.x,e.z,e.radius);}
        else if(enemyAttackCooldown[i]<=0.0f){
          enemyWindup[i]+=dt;
          if(enemyWindup[i]>=0.42f){
            if(d<1.72f&&!invulnerableNow){hurtPlayer(0.24f);if(d>0.001f){playerX-=dx/d*0.22f;playerZ-=dz/d*0.22f;resolveCollision(playerX,playerZ,0.30f);}}
            enemyAttackCooldown[i]=1.55f;enemyWindup[i]=0.0f;
          }
        }else enemyWindup[i]=0.0f;
      }else if(e.type==3){
        // Fast skitter circles toward the player's flank and darts inward in short bursts.
        const float safeD=std::max(0.001f,d);
        const float orbit=std::sin(elapsed*2.7f+(float)i*1.8f);
        float vx=(dx/safeD)*0.44f+(-dz/safeD)*orbit*0.92f;
        float vz=(dz/safeD)*0.44f+(dx/safeD)*orbit*0.92f;
        const float burst=(d>2.0f)?1.0f:(0.34f+0.48f*std::abs(orbit));
        if(d>0.68f){
          e.x+=vx*e.speed*burst*dt;e.z+=vz*e.speed*burst*dt;
          resolveCollision(e.x,e.z,e.radius);
        }else if(enemyAttackCooldown[i]<=0.0f){
          if(!invulnerableNow)hurtPlayer(0.085f);
          enemyAttackCooldown[i]=0.72f;
        }
      }else{
        if(d>e.radius+0.43f){const float step=std::min(e.speed*dt,std::max(0.0f,d-e.radius-0.40f));if(d>0.001f){e.x+=dx/d*step;e.z+=dz/d*step;}resolveCollision(e.x,e.z,e.radius);enemyWindup[i]=0.0f;}
        else if(enemyAttackCooldown[i]<=0.0f){if(!invulnerableNow)hurtPlayer(0.12f);enemyAttackCooldown[i]=0.82f;}
      }
    }
    // Projectiles stop on cover; enemy shots only hurt the player.
    for(auto&s:shots){
      if(s.life<=0.0f)continue;
      s.x+=s.vx*dt;s.z+=s.vz*dt;s.life-=dt;
      if(s.life<=0.0f||projectileBlocked(s.x,s.z)){s.life=0.0f;continue;}
      if(s.hostile){const float dx=s.x-playerX,dz=s.z-playerZ;if(dx*dx+dz*dz<0.30f*0.30f){if(!invulnerableNow)hurtPlayer(0.10f);s.life=0.0f;}}
      else for(auto&e:enemies){if(e.hp<=0.0f)continue;const float dx=s.x-e.x,dz=s.z-e.z;if(dx*dx+dz*dz<(e.radius+0.12f)*(e.radius+0.12f)){e.hp=std::max(0.0f,e.hp-s.damage);s.life=0.0f;if(e.hp<=0.0f)defeated++;break;}}
    }
    if(playerHealth<=0.0f){lost=true;moving=false;aiming=false;firing=false;gameMode=5;}
    if(allEnemiesDefeated()&&relayMask==0x7){float dx=playerX-4.02f,dz=playerZ+2.48f;if(dx*dx+dz*dz<0.72f*0.72f){won=true;moving=false;aiming=false;firing=false;gameMode=4;}}
  }
  publishSnapshot();
}
} // namespace

extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_NativeRenderer_nativeSurfaceCreated(JNIEnv*,jobject){
  // EGL can recreate the context after resume: rebuild every GL object.
  program=0;fallbackProgram=0;fallbackVao=0;cubeMesh={};sphereMesh={};organicMesh={};
  program=make3DProgram();
  if(!program){__android_log_print(ANDROID_LOG_ERROR,"NeonBreach","3D renderer failed, showing diagnostic fallback");fallbackProgram=makeFallbackProgram();}
  if(program){mvpLoc=glGetUniformLocation(program,"uMVP");modelLoc=glGetUniformLocation(program,"uModel");colorLoc=glGetUniformLocation(program,"uColor");glowLoc=glGetUniformLocation(program,"uGlow");cameraLoc=glGetUniformLocation(program,"uCamera");createMeshes();}
  else if(fallbackProgram){fallbackResLoc=glGetUniformLocation(fallbackProgram,"uRes");glGenVertexArrays(1,&fallbackVao);}
  const GLubyte*version=glGetString(GL_VERSION);
  __android_log_print(ANDROID_LOG_INFO,"NeonBreach","Renderer startup: GLES=%s 3D=%s",version?(const char*)version:"unknown",program?"enabled":"fallback");
  glEnable(GL_DEPTH_TEST);glDepthFunc(GL_LEQUAL);glDisable(GL_CULL_FACE);glDisable(GL_BLEND);
  glClearColor(0.024f,0.032f,0.040f,1.0f);previousFrame=std::chrono::steady_clock::now();publishSnapshot();
}
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_NativeRenderer_nativeSurfaceChanged(JNIEnv*,jobject,jint w,jint h){
  screenW=std::max(1,(int)w);screenH=std::max(1,(int)h);glViewport(0,0,screenW,screenH);
}
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_NativeRenderer_nativeDrawFrame(JNIEnv*,jobject){
  auto now=std::chrono::steady_clock::now();
  float frame=std::chrono::duration<float>(now-previousFrame).count();previousFrame=now;
  frame=std::clamp(frame,0.0f,0.05f);visualTime+=frame;accumulator+=frame;
  const float cameraFollow=1.0f-std::exp(-frame*4.6f);
  const float desiredFocusX=gameMode==1?std::clamp(playerX*0.68f,-3.8f,3.8f):((gameMode==0||gameMode==3||gameMode==6)?0.0f:cameraFocusX);
  const float desiredFocusZ=gameMode==1?std::clamp(playerZ*0.55f,-2.25f,2.25f):((gameMode==0||gameMode==3||gameMode==6)?0.0f:cameraFocusZ);
  cameraFocusX+=(desiredFocusX-cameraFocusX)*cameraFollow;
  cameraFocusZ+=(desiredFocusZ-cameraFocusZ)*cameraFollow;
  const float step=1.0f/60.0f;
  while(accumulator>=step){fixedUpdate(step);accumulator-=step;}
  glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
  if(!program){
    if(fallbackProgram){glUseProgram(fallbackProgram);glUniform2f(fallbackResLoc,(float)screenW,(float)screenH);glBindVertexArray(fallbackVao);glDrawArrays(GL_TRIANGLES,0,3);}
    return;
  }
  V3 camera{cameraFocusX,10.2f,cameraFocusZ+11.6f};
  Mat4 view=lookAt(camera,{cameraFocusX,0.0f,cameraFocusZ},{0.0f,1.0f,0.0f});
  Mat4 proj=perspective(46.0f*PI/180.0f,(float)screenW/(float)screenH,0.1f,60.0f);
  glUseProgram(program);drawScene(view,proj,camera);
  if(lost||won){
    // Volumetric outcome signal: a large bright ring above the arena center.
    V3 color=won?V3{0.0f,0.9f,0.38f}:V3{1.0f,0.04f,0.10f};
    V3 glow=won?V3{0.0f,0.48f,0.12f}:V3{0.35f,0.0f,0.015f};
    for(int i=0;i<28;i++){float a=2*PI*(float)i/28.0f;orb({std::cos(a)*0.75f,1.05f+0.05f*std::sin(elapsed*3),std::sin(a)*0.75f},{0.12f,0.12f,0.12f},color,glow,view,proj,camera);}
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
  operativeClass=std::clamp((int)selected,0,2);publishSnapshot();
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
    case 1: if(moving){moveX=x;moveY=y;}break;
    case 2: moving=false;break;
    case 3:
      aiming=true;aimOriginX=x;aimOriginY=y;
      aimX=playerX+std::sin(facingYaw)*5.0f;
      aimZ=playerZ+std::cos(facingYaw)*5.0f;
      break;
    case 4: if(aiming){float dx=(x-aimOriginX)/(float)screenH,dz=(y-aimOriginY)/(float)screenH;float mag=std::sqrt(dx*dx+dz*dz);if(mag>0.035f){aimX=playerX+dx/mag*5.0f;aimZ=playerZ+dz/mag*5.0f;}}break;
    case 5: if(aiming)facingYaw=std::atan2(aimX-playerX,aimZ-playerZ);aiming=false;break;
    case 6: moving=false;aiming=false;firing=false;break;
  }
  publishSnapshot();
}
