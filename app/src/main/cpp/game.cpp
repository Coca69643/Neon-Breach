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
struct Shot { float x,y,z,vx,vz,life; };

GLuint program=0, fallbackProgram=0, fallbackVao=0;
GLint mvpLoc=-1, modelLoc=-1, colorLoc=-1, glowLoc=-1, cameraLoc=-1;
GLint fallbackResLoc=-1;
Mesh cubeMesh, sphereMesh;
int screenW=1, screenH=1;
float playerX=-3.55f, playerZ=-2.15f, playerHealth=1.0f;
float moveOriginX=0, moveOriginY=0, moveX=0, moveY=0;
bool moving=false, aiming=false;
float aimX=2.0f, aimZ=0.0f, aimOriginX=0.0f, aimOriginY=0.0f, shotCooldown=0.0f;
float elapsed=0.0f, accumulator=0.0f;
bool won=false, lost=false;
int defeated=0;
int gameMode=0; // 0 menu, 1 playing, 2 pause, 3 settings, 4 victory, 5 defeat, 6 suspended menu
int relayMask=0;
std::atomic<int> publishedSnapshot{0};
std::chrono::steady_clock::time_point previousFrame=std::chrono::steady_clock::now();
std::array<Shot,12> shots{};
std::array<Enemy,4> enemies{{
  {3.55f, 2.15f, 1.0f, 1.0f, 1.05f, 0.34f, 0, PI},
  {3.35f,-1.75f, 2.0f, 2.0f, 0.70f, 0.43f, 1, PI},
  {-0.35f,2.55f, 1.0f, 1.0f, 1.45f, 0.28f, 2, PI},
  {1.05f,-2.45f,1.0f,1.0f,0.92f,0.32f,0,PI}
}};
const std::array<Obstacle,4> obstacles{{
  {-2.65f, 1.45f, 0.95f, 0.50f, 0.70f},
  {-0.10f, 2.55f, 0.90f, 0.46f, 0.65f},
  { 1.50f,-1.25f, 0.92f, 0.52f, 0.62f},
  { 3.12f, 0.20f, 0.88f, 0.46f, 0.72f}
}};
constexpr float RELAY_X[3]={-3.72f,0.0f,3.70f};
constexpr float RELAY_Z[3]={2.58f,-0.58f,1.82f};

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
  std::vector<Vertex>s;const int rings=12,sectors=18;
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
  __android_log_print(ANDROID_LOG_INFO,"NeonBreach","3D meshes ready: cube=%d sphere=%d",cubeMesh.count,sphereMesh.count);
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
    col+=uGlow+rim*(0.035+0.095*dot(uColor,vec3(0.333)));
    float fog=clamp((length(uCamera-vWorld)-9.0)/25.0,0.0,0.42);
    col=mix(col,vec3(0.006,0.012,0.026),fog);
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
void resetMission(){
  playerX=-3.55f;playerZ=-2.15f;playerHealth=1.0f;aimX=playerX+5.0f;aimZ=playerZ;elapsed=0;accumulator=0;
  moving=false;aiming=false;shotCooldown=0;won=false;lost=false;defeated=0;relayMask=0;
  shots.fill({});
  enemies={{{3.55f,2.15f,1,1,1.05f,0.34f,0,PI},{3.35f,-1.75f,2,2,0.70f,0.43f,1,PI},{-0.35f,2.55f,1,1,1.45f,0.28f,2,PI},{1.05f,-2.45f,1,1,0.92f,0.32f,0,PI}}};
}
void resolveCollision(float&x,float&z,float radius){
  x=std::clamp(x,-4.55f+radius,4.55f-radius);z=std::clamp(z,-3.05f+radius,3.05f-radius);
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
void drawHumanoid(V3 at,float yaw,float phase,float gait,int archetype,bool isPlayer,V3 armor,V3 trim,V3 glow,const Mat4&view,const Mat4&proj,V3 cam){
  const bool heavy=archetype==1, agile=archetype==2;
  const float bodyScale=heavy?1.10f:(agile?0.92f:1.0f), widthScale=heavy?1.22f:(agile?0.84f:1.0f);
  const float legSwing=std::sin(phase)*gait, armSwing=-legSwing;
  const float bob=0.010f*std::sin(phase*2.0f)+0.025f*std::abs(legSwing);
  const V3 forward{std::sin(yaw),0.0f,std::cos(yaw)}, right{std::cos(yaw),0.0f,-std::sin(yaw)};
  auto point=[&](float side,float front,float y)->V3{return {at.x+right.x*side+forward.x*front,at.y+y+bob,at.z+right.z*side+forward.z*front};};
  const V3 dark=isPlayer?V3{0.018f,0.055f,0.075f}:V3{0.055f,0.014f,0.025f};
  const V3 metal=isPlayer?V3{0.055f,0.14f,0.18f}:V3{0.12f,0.025f,0.045f};
  orb({at.x,0.026f,at.z},{heavy?0.86f:0.72f,0.034f,heavy?0.78f:0.68f},{0.008f,0.014f,0.022f},{0,0,0},view,proj,cam);
  for(int sign : {-1,1}){
    const float side=(float)sign, swing=legSwing*side;
    poseOrb(point(side*0.13f*widthScale,swing*0.055f,0.245f),{0.155f*widthScale,0.245f*bodyScale,0.155f*bodyScale},armor,glow,yaw,swing*0.62f,side*0.025f,view,proj,cam);
    poseOrb(point(side*0.13f*widthScale,swing*0.105f,0.105f),{0.125f*widthScale,0.205f*bodyScale,0.125f*bodyScale},metal,glow,yaw,-swing*0.24f,side*0.015f,view,proj,cam);
    poseBox(point(side*0.14f*widthScale,swing*0.12f+0.035f,0.052f),{0.17f*widthScale,0.085f,0.235f},dark,glow,yaw,0.0f,side*0.015f,view,proj,cam);
  }
  poseOrb(point(0,0,0.365f),{0.30f*widthScale,0.20f*bodyScale,0.235f*bodyScale},metal,glow,yaw,0.0f,0.0f,view,proj,cam);
  poseBox(point(0,0.015f,0.405f),{0.34f*widthScale,0.075f,0.255f},dark,glow,yaw,0.0f,0.0f,view,proj,cam);
  poseOrb(point(0,agile?0.015f:-0.015f,0.585f),{0.335f*widthScale,0.355f*bodyScale,0.245f*bodyScale},armor,glow,yaw,agile?0.10f:0.0f,legSwing*0.035f,view,proj,cam);
  poseBox(point(0,0.155f,0.595f),{0.34f*widthScale,0.255f,0.085f},trim,glow,yaw,agile?0.08f:0.0f,0.0f,view,proj,cam);
  poseBox(point(0,0.205f,0.59f),{0.105f,0.12f,0.035f},isPlayer?V3{0.20f,0.93f,1.0f}:trim,glow,yaw,0.0f,0.0f,view,proj,cam);
  poseBox(point(0,-0.145f,0.57f),{0.245f*widthScale,0.29f,0.16f},dark,glow,yaw,0.0f,0.0f,view,proj,cam);
  for(int sign : {-1,1}){
    const float side=(float)sign;
    poseBox(point(side*0.30f*widthScale,0.0f,0.665f),{0.22f*widthScale,0.145f,0.20f},metal,glow,yaw,armSwing*0.10f,side*0.08f,view,proj,cam);
    poseOrb(point(side*0.345f*widthScale,-armSwing*0.045f,0.525f),{0.125f*widthScale,0.225f*bodyScale,0.13f},armor,glow,yaw,armSwing*0.52f,side*0.20f,view,proj,cam);
    poseOrb(point(side*0.36f*widthScale,-armSwing*0.085f,0.355f),{0.105f*widthScale,0.205f*bodyScale,0.115f},metal,glow,yaw,armSwing*0.38f,side*0.12f,view,proj,cam);
    poseOrb(point(side*0.37f*widthScale,-armSwing*0.10f,0.225f),{0.105f,0.095f,0.105f},dark,glow,yaw,0.0f,side*0.08f,view,proj,cam);
  }
  poseOrb(point(0,0,0.995f),{0.235f,0.265f*bodyScale,0.225f},metal,glow,yaw,0.0f,0.0f,view,proj,cam);
  poseBox(point(0,0.176f,1.005f),{0.285f,0.115f,0.055f},dark,glow,yaw,0.0f,0.0f,view,proj,cam);
  poseBox(point(0,0.211f,1.01f),{0.205f,0.026f,0.024f},isPlayer?V3{0.38f,0.96f,1.0f}:trim,isPlayer?V3{0.10f,0.28f,0.34f}:glow,yaw,0.0f,0.0f,view,proj,cam);
  poseBox(point(-0.105f,0,1.245f),{0.035f,0.105f,0.035f},trim,glow,yaw,0.0f,0.0f,view,proj,cam);
  poseOrb(point(-0.105f,0,1.305f),{0.07f,0.07f,0.07f},trim,glow,yaw,0.0f,0.0f,view,proj,cam);
  poseBox(point(0.16f,0.355f,0.435f),{0.12f,0.115f,0.34f},dark,glow,yaw,0.0f,0.0f,view,proj,cam);
  poseBox(point(0.16f,0.38f,0.445f),{0.055f,0.045f,0.245f},isPlayer?V3{0.035f,0.38f,0.48f}:trim,glow,yaw,0.0f,0.0f,view,proj,cam);
  if(isPlayer&&aiming&&shotCooldown>0.10f)poseOrb(point(0.16f,0.57f,0.435f),{0.075f,0.075f,0.075f},{0.22f,0.88f,1.0f},{0.0f,0.35f,0.5f},yaw,0.0f,0.0f,view,proj,cam);
}
bool allEnemiesDefeated(){for(const auto&e:enemies)if(e.hp>0.0f)return false;return true;}
int activeEnemyCount(){int count=0;for(const auto&e:enemies)if(e.hp>0.0f)count++;return count;}
bool nearActiveRelay(){
  for(int i=0;i<3;i++){
    if(relayMask&(1<<i))continue;
    float dx=playerX-RELAY_X[i],dz=playerZ-RELAY_Z[i];
    if(dx*dx+dz*dz<1.05f*1.05f)return true;
  }
  return false;
}
void publishSnapshot(){
  int hp=(int)std::round(std::clamp(playerHealth,0.0f,1.0f)*100.0f);
  int packed=(gameMode&7)|((hp&127)<<3)|((relayMask&7)<<10)|((activeEnemyCount()&7)<<13)|(nearActiveRelay()?1<<16:0);
  publishedSnapshot.store(packed,std::memory_order_relaxed);
}
void drawScene(const Mat4&view,const Mat4&proj,V3 cam){
  // Solid floor with real depth and modular metal seams.
  box({0,-0.18f,0},{10.0f,0.34f,7.2f},{0.025f,0.045f,0.075f},{0.0f,0.006f,0.012f},0,view,proj,cam);
  for(int i=-6;i<=6;i++){
    box({(float)i*0.76f,0.006f,0},{0.018f,0.014f,7.0f},{0.025f,0.10f,0.14f},{0.0f,0.09f,0.13f},0,view,proj,cam);
  }
  for(int i=-4;i<=4;i++){
    box({0,0.007f,(float)i*0.76f},{9.8f,0.014f,0.018f},{0.025f,0.10f,0.14f},{0.0f,0.075f,0.12f},0,view,proj,cam);
  }
  // Raised walls, illuminated trim and corner posts make the arena genuinely volumetric.
  box({-4.94f,0.40f,0},{0.22f,0.82f,7.22f},{0.045f,0.10f,0.16f},{0.0f,0.18f,0.28f},0,view,proj,cam);
  box({ 4.94f,0.40f,0},{0.22f,0.82f,7.22f},{0.045f,0.10f,0.16f},{0.0f,0.18f,0.28f},0,view,proj,cam);
  box({0,0.40f,-3.54f},{9.85f,0.82f,0.22f},{0.045f,0.10f,0.16f},{0.0f,0.18f,0.28f},0,view,proj,cam);
  box({0,0.40f, 3.54f},{9.85f,0.82f,0.22f},{0.045f,0.10f,0.16f},{0.0f,0.18f,0.28f},0,view,proj,cam);
  box({-4.94f,0.86f,0},{0.28f,0.08f,7.28f},{0.0f,0.43f,0.65f},{0.0f,0.34f,0.50f},0,view,proj,cam);
  box({ 4.94f,0.86f,0},{0.28f,0.08f,7.28f},{0.0f,0.43f,0.65f},{0.0f,0.34f,0.50f},0,view,proj,cam);
  box({0,0.86f,-3.54f},{9.9f,0.08f,0.28f},{0.0f,0.43f,0.65f},{0.0f,0.34f,0.50f},0,view,proj,cam);
  box({0,0.86f, 3.54f},{9.9f,0.08f,0.28f},{0.0f,0.43f,0.65f},{0.0f,0.34f,0.50f},0,view,proj,cam);
  // Cover blocks are physical colliders as well as 3D objects.
  for(const auto&o:obstacles){
    box({o.x,o.h*0.5f,o.z},{o.sx,o.h,o.sz},{0.065f,0.13f,0.19f},{0.0f,0.10f,0.18f},0,view,proj,cam);
    box({o.x,o.h+0.025f,o.z},{o.sx+0.05f,0.05f,o.sz+0.05f},{0.0f,0.35f,0.50f},{0.0f,0.22f,0.32f},0,view,proj,cam);
    box({o.x,o.h+0.065f,o.z},{o.sx*0.52f,0.025f,o.sz*0.58f},{0.12f,0.20f,0.25f},{0.0f,0.025f,0.04f},0,view,proj,cam);
  }
  // Distributed relay consoles change both the mission state and visible network lighting.
  for(int i=0;i<3;i++){
    const float x=RELAY_X[i],z=RELAY_Z[i];
    const bool disabled=(relayMask&(1<<i))!=0;
    const V3 body=disabled?V3{0.035f,0.15f,0.11f}:V3{0.055f,0.10f,0.16f};
    const V3 panel=disabled?V3{0.04f,0.72f,0.36f}:V3{0.95f,0.16f,0.045f};
    const V3 glow=disabled?V3{0.0f,0.16f,0.06f}:V3{0.32f,0.025f,0.0f};
    box({x,0.018f,0},{0.038f,0.022f,6.62f},disabled?V3{0.025f,0.22f,0.12f}:V3{0.20f,0.04f,0.055f},disabled?V3{0.0f,0.10f,0.04f}:V3{0.18f,0.015f,0.025f},0,view,proj,cam);
    box({x,0.34f,z},{0.58f,0.62f,0.42f},body,glow,0,view,proj,cam);
    box({x,0.47f,z-0.23f},{0.36f,0.23f,0.045f},panel,glow,0,view,proj,cam);
    orb({x,0.77f,z-0.23f},{0.13f,0.13f,0.13f},panel,glow,view,proj,cam);
    box({x,0.83f,z},{0.48f,0.055f,0.055f},panel,glow,0,view,proj,cam);
  }
  // Extraction opens only after all three relays are offline and the hostiles are neutralized.
  const bool objectiveComplete=allEnemiesDefeated()&&relayMask==0x7;
  V3 exitColor=objectiveComplete?V3{0.02f,0.85f,0.42f}:V3{0.02f,0.20f,0.28f};
  V3 exitGlow=objectiveComplete?V3{0.0f,0.5f,0.20f}:V3{0.0f,0.035f,0.06f};
  for(int i=0;i<24;i++){
    float a=2*PI*(float)i/24.0f;
    box({4.02f+std::cos(a)*0.57f,0.065f,-2.48f+std::sin(a)*0.57f},{0.14f,0.055f,0.10f},exitColor,exitGlow,a,view,proj,cam);
  }
  box({4.02f,0.18f,-2.48f},{0.78f,0.12f,0.78f},{0.025f,0.12f,0.15f},{0.0f,0.07f,0.1f},0,view,proj,cam);
  box({4.02f,0.58f,-2.48f},{0.10f,0.80f,0.10f},exitColor,exitGlow,0,view,proj,cam);
  orb({4.02f,1.08f+0.08f*std::sin(elapsed*2.2f),-2.48f},{0.24f,0.24f,0.24f},exitColor,exitGlow,view,proj,cam);
  // Player: procedural humanoid armor, visor, backpack, weapon and walk cycle.
  float playerYaw=std::atan2(aimX-playerX,aimZ-playerZ);
  float inputDx=(moveX-moveOriginX)/(float)std::max(1,screenH);
  float inputDy=(moveY-moveOriginY)/(float)std::max(1,screenH);
  float inputMagnitude=std::sqrt(inputDx*inputDx+inputDy*inputDy);
  float playerGait=moving?std::clamp(inputMagnitude/0.16f,0.0f,1.0f):0.0f;
  drawHumanoid({playerX,0.0f,playerZ},playerYaw,elapsed*9.4f,playerGait,0,true,{0.035f,0.24f,0.34f},{0.025f,0.49f,0.62f},{0.0f,0.075f,0.12f},view,proj,cam);
  box({playerX,1.53f,playerZ},{0.78f,0.055f,0.075f},{0.10f,0.035f,0.06f},{0.02f,0.0f,0.0f},0,view,proj,cam);
  if(playerHealth>0.001f)box({playerX-0.39f+0.39f*playerHealth,1.535f,playerZ},{0.78f*playerHealth,0.065f,0.08f},{0.0f,0.78f,0.84f},{0.0f,0.18f,0.24f},0,view,proj,cam);
  // Three enemy archetypes share the rig but have distinct proportions and colors.
  for(const auto&e:enemies){
    if(e.hp<=0.0f)continue;
    const float distanceToPlayer=std::sqrt((playerX-e.x)*(playerX-e.x)+(playerZ-e.z)*(playerZ-e.z));
    const float enemyGait=distanceToPlayer>e.radius+0.48f?0.72f:0.12f;
    const V3 enemyArmor=e.type==1?V3{0.22f,0.045f,0.07f}:(e.type==2?V3{0.13f,0.028f,0.12f}:V3{0.17f,0.035f,0.06f});
    const V3 enemyTrim=e.type==1?V3{0.95f,0.22f,0.10f}:(e.type==2?V3{0.95f,0.16f,0.38f}:V3{0.98f,0.09f,0.17f});
    const V3 enemyGlow=e.type==1?V3{0.16f,0.008f,0.012f}:(e.type==2?V3{0.14f,0.004f,0.05f}:V3{0.12f,0.006f,0.015f});
    drawHumanoid({e.x,0.0f,e.z},e.yaw,elapsed*(6.2f+e.speed),enemyGait,e.type,false,enemyArmor,enemyTrim,enemyGlow,view,proj,cam);
    const float barY=1.50f+0.02f*std::sin(elapsed*8.0f+e.x);
    box({e.x,barY,e.z},{0.62f,0.05f,0.07f},{0.12f,0.02f,0.04f},{0.02f,0.0f,0.0f},0,view,proj,cam);
    box({e.x-0.31f+(0.62f*e.hp/e.maxHp)*0.5f,barY+0.005f,e.z},{0.62f*e.hp/e.maxHp,0.06f,0.075f},enemyTrim,{0.16f,0.0f,0.02f},0,view,proj,cam);
  }
  // Aim indicator follows the right-hand touch direction in world space.
  if(aiming&&!won&&!lost){
    orb({aimX,0.055f,aimZ},{0.18f,0.045f,0.18f},{0.04f,0.72f,0.90f},{0.0f,0.24f,0.34f},view,proj,cam);
    for(int i=0;i<12;i++){float a=2*PI*(float)i/12.0f;box({aimX+std::cos(a)*0.26f,0.055f,aimZ+std::sin(a)*0.26f},{0.08f,0.035f,0.045f},{0.12f,0.76f,0.9f},{0.0f,0.18f,0.27f},a,view,proj,cam);}
  }
  // Bright energy pellets use real depth and move through the world.
  for(const auto&s:shots)if(s.life>0.0f){
    orb({s.x,0.34f,s.z},{0.19f,0.19f,0.19f},{0.10f,0.85f,1.0f},{0.0f,0.30f,0.48f},view,proj,cam);
  }
  // Small status beacons show remaining targets without a flat HUD overlay.
  for(int i=0;i<4;i++){
    bool alive=enemies[i].hp>0.0f;
    orb({-4.25f+0.25f*(float)i,0.93f,-2.94f},{0.13f,0.13f,0.13f},
      alive?V3{1.0f,0.10f,0.17f}:V3{0.05f,0.42f,0.30f},
      alive?V3{0.24f,0.0f,0.02f}:V3{0.0f,0.12f,0.07f},view,proj,cam);
  }
}
void fixedUpdate(float dt){
  if(gameMode!=1){publishSnapshot();return;}
  elapsed+=dt;
  if(!won&&!lost){
    if(moving){
      float dx=(moveX-moveOriginX)/(float)screenH;
      float dy=(moveY-moveOriginY)/(float)screenH;
      float mag=std::sqrt(dx*dx+dy*dy);
      if(mag>0.02f){
        float nx=dx/std::max(0.15f,mag),ny=dy/std::max(0.15f,mag);
        float strength=std::min(1.0f,mag/0.15f);
        playerX+=nx*3.35f*strength*dt;
        playerZ-=ny*3.35f*strength*dt;
        resolveCollision(playerX,playerZ,0.30f);
      }
    }
    shotCooldown=std::max(0.0f,shotCooldown-dt);
    if(aiming&&shotCooldown<=0.0f&&playerHealth>0.0f){
      int slot=-1;for(int i=0;i<(int)shots.size();i++)if(shots[i].life<=0.0f){slot=i;break;}
      if(slot>=0){
        float dx=aimX-playerX,dz=aimZ-playerZ,d=std::sqrt(dx*dx+dz*dz);
        if(d<0.01f){dx=1.0f;dz=0.0f;d=1.0f;}
        shots[slot]={playerX,0.34f,playerZ,dx/d*7.0f,dz/d*7.0f,1.15f};shotCooldown=0.20f;
      }
    }
    for(auto&e:enemies){
      if(e.hp<=0.0f)continue;
      float dx=playerX-e.x,dz=playerZ-e.z,d=std::sqrt(dx*dx+dz*dz);
      if(d>e.radius+0.38f){
        float step=std::min(e.speed*dt,d-e.radius-0.36f);
        if(d>0.001f){e.x+=dx/d*step;e.z+=dz/d*step;}
        e.yaw=std::atan2(dx,dz);
        resolveCollision(e.x,e.z,e.radius);
      }else playerHealth=std::max(0.0f,playerHealth-0.14f*dt);
    }
    for(auto&s:shots){
      if(s.life<=0.0f)continue;
      s.x+=s.vx*dt;s.z+=s.vz*dt;s.life-=dt;
      if(s.x<-5||s.x>5||s.z<-3.7f||s.z>3.7f){s.life=0;continue;}
      for(auto&e:enemies){
        if(e.hp<=0.0f)continue;
        float dx=s.x-e.x,dz=s.z-e.z;
        if(dx*dx+dz*dz<(e.radius+0.11f)*(e.radius+0.11f)){
          e.hp=std::max(0.0f,e.hp-1.0f);s.life=0.0f;
          if(e.hp<=0.0f)defeated++;
          break;
        }
      }
    }
    if(playerHealth<=0.0f){lost=true;moving=false;aiming=false;gameMode=5;}
    if(allEnemiesDefeated()&&relayMask==0x7){
      float dx=playerX-4.02f,dz=playerZ+2.48f;
      if(dx*dx+dz*dz<0.72f*0.72f){won=true;moving=false;aiming=false;gameMode=4;}
    }
  }
  publishSnapshot();
}
} // namespace

extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_NativeRenderer_nativeSurfaceCreated(JNIEnv*,jobject){
  // EGL can recreate the context after resume: rebuild every GL object.
  program=0;fallbackProgram=0;fallbackVao=0;cubeMesh={};sphereMesh={};
  program=make3DProgram();
  if(!program){__android_log_print(ANDROID_LOG_ERROR,"NeonBreach","3D renderer failed, showing diagnostic fallback");fallbackProgram=makeFallbackProgram();}
  if(program){mvpLoc=glGetUniformLocation(program,"uMVP");modelLoc=glGetUniformLocation(program,"uModel");colorLoc=glGetUniformLocation(program,"uColor");glowLoc=glGetUniformLocation(program,"uGlow");cameraLoc=glGetUniformLocation(program,"uCamera");createMeshes();}
  else if(fallbackProgram){fallbackResLoc=glGetUniformLocation(fallbackProgram,"uRes");glGenVertexArrays(1,&fallbackVao);}
  const GLubyte*version=glGetString(GL_VERSION);
  __android_log_print(ANDROID_LOG_INFO,"NeonBreach","Renderer startup: GLES=%s 3D=%s",version?(const char*)version:"unknown",program?"enabled":"fallback");
  glEnable(GL_DEPTH_TEST);glDepthFunc(GL_LEQUAL);glDisable(GL_CULL_FACE);glDisable(GL_BLEND);
  glClearColor(0.004f,0.008f,0.018f,1.0f);previousFrame=std::chrono::steady_clock::now();publishSnapshot();
}
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_NativeRenderer_nativeSurfaceChanged(JNIEnv*,jobject,jint w,jint h){
  screenW=std::max(1,(int)w);screenH=std::max(1,(int)h);glViewport(0,0,screenW,screenH);
}
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_NativeRenderer_nativeDrawFrame(JNIEnv*,jobject){
  auto now=std::chrono::steady_clock::now();
  float frame=std::chrono::duration<float>(now-previousFrame).count();previousFrame=now;
  frame=std::clamp(frame,0.0f,0.05f);accumulator+=frame;
  const float step=1.0f/60.0f;
  while(accumulator>=step){fixedUpdate(step);accumulator-=step;}
  glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
  if(!program){
    if(fallbackProgram){glUseProgram(fallbackProgram);glUniform2f(fallbackResLoc,(float)screenW,(float)screenH);glBindVertexArray(fallbackVao);glDrawArrays(GL_TRIANGLES,0,3);}
    return;
  }
  V3 camera{0.0f,8.6f,11.2f};
  Mat4 view=lookAt(camera,{0.0f,0.0f,0.0f},{0.0f,1.0f,0.0f});
  Mat4 proj=perspective(44.0f*PI/180.0f,(float)screenW/(float)screenH,0.1f,60.0f);
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
    if(mode!=1){moving=false;aiming=false;}
    previousFrame=std::chrono::steady_clock::now();
    publishSnapshot();
  }
}
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_NativeRenderer_nativeStartNewMission(JNIEnv*,jobject){
  resetMission();gameMode=1;previousFrame=std::chrono::steady_clock::now();publishSnapshot();
}
extern "C" JNIEXPORT jint JNICALL Java_com_duckdream_neonbreach_NativeRenderer_nativeGetSnapshot(JNIEnv*,jobject){
  return (jint)publishedSnapshot.load(std::memory_order_relaxed);
}
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_MainActivity_00024GameSurface_nativeTouch(JNIEnv*,jobject,jint action,jfloat x,jfloat y,jfloat w,jfloat h){
  screenW=std::max(1,(int)w);screenH=std::max(1,(int)h);
  if(gameMode!=1)return;
  if(action==7){
    for(int i=0;i<3;i++){
      if(relayMask&(1<<i))continue;
      float dx=playerX-RELAY_X[i],dz=playerZ-RELAY_Z[i];
      if(dx*dx+dz*dz<1.25f*1.25f){relayMask|=(1<<i);__android_log_print(ANDROID_LOG_INFO,"NeonBreach","Relay %d disabled; mask=%d",i+1,relayMask);publishSnapshot();return;}
    }
    publishSnapshot();return;
  }
  switch(action){
    case 0: moving=true;moveOriginX=moveX=x;moveOriginY=moveY=y;break;
    case 1: if(moving){moveX=x;moveY=y;}break;
    case 2: moving=false;break;
    case 3:
      aiming=true;aimOriginX=x;aimOriginY=y;
      break;
    case 4:
      if(aiming){
        float dx=(x-aimOriginX)/(float)screenH,dz=-(y-aimOriginY)/(float)screenH;
        float mag=std::sqrt(dx*dx+dz*dz);
        if(mag>0.035f){aimX=playerX+dx/mag*5.0f;aimZ=playerZ+dz/mag*5.0f;}
      }
      break;
    case 5: aiming=false;break;
    case 6: moving=false;aiming=false;break;
  }
  publishSnapshot();
}
