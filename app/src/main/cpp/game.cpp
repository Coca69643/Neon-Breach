#include <jni.h>
#include <GLES3/gl3.h>
#include <android/log.h>
#include <algorithm>
#include <cmath>

namespace {
GLuint program=0, vao=0;
GLint resLoc=-1,timeLoc=-1,playerLoc=-1;
int width=1,height=1;
float px=-0.55f, py=0.0f, elapsed=0.0f;
float downX=0.0f,downY=0.0f,moveX=0.0f,moveY=0.0f;
bool dragging=false, firing=false;
struct Unit { float x,y,hp; };
struct Shot { float x,y,vx,vy,life; };
Unit enemies[4]={{0.95f,0.48f,1.0f},{0.98f,-0.42f,1.0f},{-0.95f,0.48f,1.0f},{0.35f,0.62f,1.0f}};
Shot shots[8]{};
float targetX=1.1f,targetY=0.0f,fireCooldown=0.0f;
float health=1.0f;
int kills=0;
bool missionComplete=false;

GLuint compileShader(GLenum type,const char* source){
  GLuint shader=glCreateShader(type); glShaderSource(shader,1,&source,nullptr); glCompileShader(shader);
  GLint ok=GL_FALSE; glGetShaderiv(shader,GL_COMPILE_STATUS,&ok);
  if(!ok){ GLint n=0; glGetShaderiv(shader,GL_INFO_LOG_LENGTH,&n); if(n>1){char log[1024];GLsizei written=0;glGetShaderInfoLog(shader,std::min(n,1023),&written,log);__android_log_print(ANDROID_LOG_ERROR,"NeonBreach","Shader compile: %s",log);} glDeleteShader(shader); return 0; }
  return shader;
}
GLuint makeProgram(){
  const char* vs=R"(#version 300 es
  void main(){vec2 p[3]=vec2[3](vec2(-1.0,-1.0),vec2(3.0,-1.0),vec2(-1.0,3.0));gl_Position=vec4(p[gl_VertexID],0.0,1.0);})";
  const char* fs=R"(#version 300 es
  precision mediump float;
  uniform vec2 uRes; uniform float uTime; uniform vec2 uPlayer; uniform vec4 uEnemies[4]; uniform vec4 uBullets[8]; uniform vec4 uHud;
  out vec4 outColor;
  float disc(vec2 p,vec2 c,float r){return 1.0-smoothstep(r-0.008,r+0.008,length(p-c));}
  float line(float d,float w){return 1.0-smoothstep(w,w+0.008,abs(d));}
  void main(){
    vec2 uv=gl_FragCoord.xy/uRes;
    float aspect=uRes.x/uRes.y;
    vec2 p=vec2((uv.x*2.0-1.0)*aspect,uv.y*2.0-1.0);
    vec3 col=vec3(0.012,0.022,0.047);
    float vignette=1.0-smoothstep(0.35,1.9,length(p*vec2(0.65,1.0)));
    col+=vec3(0.008,0.026,0.05)*vignette;
    // Sector floor: modular metal panels and luminous seams.
    vec2 tile=abs(fract((p+vec2(1.8,1.0))*vec2(4.2,5.0))-0.5);
    float seams=max(step(0.485,tile.x),step(0.485,tile.y));
    col+=seams*vec3(0.012,0.055,0.078);
    float arena=step(abs(p.x),1.62)*step(abs(p.y),0.78);
    float border=max(line(abs(p.x)-1.62,0.012),line(abs(p.y)-0.78,0.012));
    col+=border*vec3(0.02,0.72,0.98);
    col=mix(col,col*0.48,1.0-arena);
    // Cover blocks and terminal stations.
    for(int i=0;i<4;i++){
      float fi=float(i);
      vec2 b=vec2(-1.12+fi*0.73,0.42*sin(fi*2.0));
      vec2 d=abs(p-b);
      float block=step(d.x,0.13)*step(d.y,0.075);
      float trim=block*max(line(d.x-0.13,0.008),line(d.y-0.075,0.008));
      col=mix(col,vec3(0.035,0.095,0.13),block);
      col+=trim*vec3(0.02,0.38,0.52);
    }
    vec2 term1=vec2(1.35,0.47),term2=vec2(0.92,-0.52),term3=vec2(-1.35,-0.48);
    float terminals=disc(p,term1,0.065)+disc(p,term2,0.065)+disc(p,term3,0.065);
    col+=terminals*vec3(0.0,0.55,0.9);
    // Hostile drones orbit the room; their positions are animated.
    for(int i=0;i<4;i++){
      vec4 data=uEnemies[i]; vec2 e=data.xy;
      float alive=step(0.1,data.z);
      float halo=disc(p,e,0.105)*0.22*alive;
      float enemy=disc(p,e,0.052)*alive;
      float core=disc(p,e,0.019)*alive;
      float hpbar=line(p.y-(e.y+0.075),0.006)*step(abs(p.x-e.x),0.055)*alive;
      col+=halo*vec3(1.0,0.025,0.16);
      col=mix(col,vec3(0.72,0.035,0.15),enemy);
      col=mix(col,vec3(1.0,0.45,0.38),core);
      col=mix(col,vec3(1.0,0.12,0.2),hpbar);
    }
    for(int i=0;i<8;i++){
      vec4 b=uBullets[i]; float visibleMask=step(0.0,b.z);
      float shot=disc(p,b.xy,0.022)*visibleMask;
      col+=shot*vec3(0.25,0.95,1.0);
      col+=disc(p,b.xy-vec2(b.w*0.018,0.0),0.035)*visibleMask*vec3(0.0,0.18,0.24);
    }
    // Compact combat HUD: health, remaining hostiles, extraction state.
    vec2 hpPos=vec2(-aspect+0.42,0.83);
    float hpFrame=step(abs(p.x-hpPos.x),0.31)*step(abs(p.y-hpPos.y),0.035);
    float hpFill=step(abs(p.x-(hpPos.x-0.31+0.31*uHud.x)),0.31*uHud.x)*step(abs(p.y-hpPos.y),0.022);
    col=mix(col,vec3(0.04,0.10,0.15),hpFrame);
    col=mix(col,vec3(0.0,0.88,0.95),hpFill);
    for(int i=0;i<4;i++){
      vec2 pip=vec2(-aspect+0.10+float(i)*0.10,0.72);
      float visibleMask=step(float(i)+0.5,uHud.y);
      col+=disc(p,pip,0.025)*mix(vec3(0.25,0.04,0.08),vec3(1.0,0.12,0.2),visibleMask);
    }
    // Player unit with a direction chevron and cyan energy ring.
    float ring=1.0-smoothstep(0.008,0.018,abs(length(p-uPlayer)-0.105));
    float player=disc(p,uPlayer,0.062);
    col+=ring*vec3(0.0,0.48,0.72);
    col=mix(col,vec3(0.12,0.92,1.0),player);
    col+=disc(p,uPlayer+vec2(0.012,0.008),0.018)*vec3(0.8,1.0,1.0);
    // Extraction pad pulses in the upper-right sector.
    vec2 exitPos=vec2(1.37,-0.57);
    float exitRing=1.0-smoothstep(0.012,0.025,abs(length(p-exitPos)-0.105));
    col+=exitRing*(0.45+0.25*sin(uTime*3.0))*vec3(0.0,0.8,0.65);
    col+=disc(p,exitPos,0.025)*vec3(0.0,0.8,0.55);
    // Touch-stick visual.
    vec2 stickCenter=vec2(-aspect+0.38,-0.63);
    float stickOuter=disc(p,stickCenter,0.19);
    float stickInner=disc(p,stickCenter,0.09);
    col+=stickOuter*vec3(0.025,0.11,0.16);
    col+=stickInner*vec3(0.02,0.27,0.36);
    col+=max(0.0,stickOuter-stickInner)*vec3(0.0,0.3,0.42);
    outColor=vec4(col,1.0);
  })";
  GLuint v=compileShader(GL_VERTEX_SHADER,vs), f=compileShader(GL_FRAGMENT_SHADER,fs);
  if(!v||!f){if(v)glDeleteShader(v);if(f)glDeleteShader(f);return 0;}
  GLuint p=glCreateProgram();glAttachShader(p,v);glAttachShader(p,f);glLinkProgram(p);glDeleteShader(v);glDeleteShader(f);
  GLint ok=GL_FALSE;glGetProgramiv(p,GL_LINK_STATUS,&ok);
  if(!ok){GLint n=0;glGetProgramiv(p,GL_INFO_LOG_LENGTH,&n);if(n>1){char log[1024];GLsizei written=0;glGetProgramInfoLog(p,std::min(n,1023),&written,log);__android_log_print(ANDROID_LOG_ERROR,"NeonBreach","Program link: %s",log);}glDeleteProgram(p);return 0;}
  return p;
}
}
GLuint makeFallbackProgram(){
  const char* vs=R"(#version 300 es
  void main(){vec2 p[3]=vec2[3](vec2(-1.0,-1.0),vec2(3.0,-1.0),vec2(-1.0,3.0));gl_Position=vec4(p[gl_VertexID],0.0,1.0);})";
  const char* fs=R"(#version 300 es
  precision mediump float;
  uniform vec2 uRes;
  out vec4 outColor;
  void main(){
    vec2 uv=gl_FragCoord.xy/max(uRes,vec2(1.0));
    vec2 cell=fract(uv*vec2(14.0,8.0));
    float grid=max(step(0.96,cell.x),step(0.96,cell.y));
    vec3 col=mix(vec3(0.008,0.018,0.04),vec3(0.015,0.08,0.12),uv.y);
    col+=grid*vec3(0.0,0.20,0.30);
    float marker=1.0-smoothstep(0.02,0.035,length(uv-vec2(0.5,0.5)));
    col+=marker*vec3(0.0,0.7,1.0);
    outColor=vec4(col,1.0);
  })";
  GLuint v=compileShader(GL_VERTEX_SHADER,vs), f=compileShader(GL_FRAGMENT_SHADER,fs);
  if(!v||!f){if(v)glDeleteShader(v);if(f)glDeleteShader(f);return 0;}
  GLuint p=glCreateProgram();glAttachShader(p,v);glAttachShader(p,f);glLinkProgram(p);glDeleteShader(v);glDeleteShader(f);
  GLint ok=GL_FALSE;glGetProgramiv(p,GL_LINK_STATUS,&ok);
  if(!ok){GLint n=0;glGetProgramiv(p,GL_INFO_LOG_LENGTH,&n);if(n>1){char log[1024];GLsizei written=0;glGetProgramInfoLog(p,std::min(n,1023),&written,log);__android_log_print(ANDROID_LOG_ERROR,"NeonBreach","Fallback link: %s",log);}glDeleteProgram(p);return 0;}
  return p;
}
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_NativeRenderer_nativeSurfaceCreated(JNIEnv*,jobject){
  if(program)glDeleteProgram(program);
  program=makeProgram();
  if(!program){
    __android_log_print(ANDROID_LOG_ERROR,"NeonBreach","Main shader failed; using visible fallback renderer");
    program=makeFallbackProgram();
  }
  if(vao)glDeleteVertexArrays(1,&vao);
  vao=0;glGenVertexArrays(1,&vao);glBindVertexArray(vao);
  const GLubyte* version=glGetString(GL_VERSION);
  __android_log_print(ANDROID_LOG_INFO,"NeonBreach","OpenGL initialized: %s",version?(const char*)version:"unknown");
  glDisable(GL_DEPTH_TEST);glDisable(GL_CULL_FACE);
  glClearColor(program?0.012f:0.25f,program?0.022f:0.015f,program?0.047f:0.015f,1.0f);
}
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_NativeRenderer_nativeSurfaceChanged(JNIEnv*,jobject,jint w,jint h){
  width=std::max(1,(int)w);height=std::max(1,(int)h);glViewport(0,0,width,height);
}
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_NativeRenderer_nativeDrawFrame(JNIEnv*,jobject){
  const float dt=1.0f/60.0f; elapsed+=dt;
  if(dragging){
    float dx=(moveX-downX)/std::max(1.0f,(float)height);
    float dy=(moveY-downY)/std::max(1.0f,(float)height);
    px+=std::clamp(dx*2.8f,-0.075f,0.075f);
    py-=std::clamp(dy*2.8f,-0.075f,0.075f);
    downX=moveX;downY=moveY;
  }
  px=std::clamp(px,-1.48f,1.48f);py=std::clamp(py,-0.66f,0.66f);
  fireCooldown=std::max(0.0f,fireCooldown-dt);
  int alive=0;
  for(int i=0;i<4;i++){
    if(enemies[i].hp<=0.0f) continue;
    alive++;
    float dx=px-enemies[i].x,dy=py-enemies[i].y;
    float d=std::sqrt(dx*dx+dy*dy);
    if(d>0.15f){enemies[i].x+=dx/d*0.20f*dt;enemies[i].y+=dy/d*0.20f*dt;}
    if(d<0.105f){health=std::max(0.0f,health-0.12f*dt);}
  }
  if(firing && fireCooldown<=0.0f && health>0.0f && !missionComplete){
    int slot=-1;for(int i=0;i<8;i++)if(shots[i].life<=0.0f){slot=i;break;}
    if(slot>=0){
      float dx=targetX-px,dy=targetY-py,d=std::sqrt(dx*dx+dy*dy);
      if(d<0.01f){dx=1.0f;dy=0.0f;d=1.0f;}
      shots[slot]={px,py,dx/d*2.7f,dy/d*2.7f,0.8f};fireCooldown=0.16f;
    }
  }
  for(auto &s:shots){
    if(s.life<=0.0f)continue;
    s.x+=s.vx*dt;s.y+=s.vy*dt;s.life-=dt;
    for(int i=0;i<4;i++){
      if(enemies[i].hp<=0.0f)continue;
      float dx=s.x-enemies[i].x,dy=s.y-enemies[i].y;
      if(dx*dx+dy*dy<0.008f){enemies[i].hp=0.0f;s.life=0.0f;kills++;break;}
    }
  }
  if(alive==0)missionComplete=true;
  glClear(GL_COLOR_BUFFER_BIT);if(!program)return;
  glUseProgram(program);
  glUniform2f(glGetUniformLocation(program,"uRes"),(float)width,(float)height);
  glUniform1f(glGetUniformLocation(program,"uTime"),elapsed);
  glUniform2f(glGetUniformLocation(program,"uPlayer"),px,py);
  GLint el=glGetUniformLocation(program,"uEnemies[0]");
  float enemyData[16];for(int i=0;i<4;i++){enemyData[i*4]=enemies[i].x;enemyData[i*4+1]=enemies[i].y;enemyData[i*4+2]=enemies[i].hp;enemyData[i*4+3]=0.0f;}
  glUniform4fv(el,4,enemyData);
  GLint bl=glGetUniformLocation(program,"uBullets[0]");
  float bulletData[32];for(int i=0;i<8;i++){bulletData[i*4]=shots[i].x;bulletData[i*4+1]=shots[i].y;bulletData[i*4+2]=shots[i].life>0.0f?1.0f:0.0f;bulletData[i*4+3]=shots[i].vx>0?1.0f:-1.0f;}
  glUniform4fv(bl,8,bulletData);
  glUniform4f(glGetUniformLocation(program,"uHud"),health,(float)(4-kills),missionComplete?1.0f:0.0f,0.0f);
  glBindVertexArray(vao);glDrawArrays(GL_TRIANGLES,0,3);
}
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_MainActivity_00024GameSurface_nativeTouch(JNIEnv*,jobject,jint action,jfloat x,jfloat y,jfloat,jfloat){
  const bool rightSide=x>width*0.48f;
  if(action==0){
    if(rightSide){firing=true;targetX=(x/(float)width*2.0f-1.0f)*(float)width/(float)height;targetY=1.0f-y/(float)height*2.0f;}
    else{dragging=true;downX=moveX=x;downY=moveY=y;}
  } else if(action==1){
    if(firing && rightSide){targetX=(x/(float)width*2.0f-1.0f)*(float)width/(float)height;targetY=1.0f-y/(float)height*2.0f;}
    if(dragging && !rightSide){moveX=x;moveY=y;}
  } else if(action==2){dragging=false;firing=false;moveX=moveY=downX=downY=0.0f;}
}
