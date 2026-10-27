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
bool dragging=false;

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
  uniform vec2 uRes; uniform float uTime; uniform vec2 uPlayer;
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
      float fi=float(i);
      vec2 e=vec2(sin(uTime*(0.22+fi*0.025)+fi*2.1)*1.18,cos(uTime*0.31+fi*1.65)*0.54);
      float halo=disc(p,e,0.095)*0.20;
      float enemy=disc(p,e,0.047);
      float core=disc(p,e,0.018);
      col+=halo*vec3(1.0,0.025,0.16);
      col=mix(col,vec3(0.72,0.035,0.15),enemy);
      col=mix(col,vec3(1.0,0.45,0.38),core);
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
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_NativeRenderer_nativeSurfaceCreated(JNIEnv*,jobject){
  if(program)glDeleteProgram(program); program=makeProgram();
  if(!vao)glGenVertexArrays(1,&vao); glBindVertexArray(vao);
  glDisable(GL_DEPTH_TEST);glDisable(GL_CULL_FACE);glClearColor(0.012f,0.022f,0.047f,1.0f);
}
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_NativeRenderer_nativeSurfaceChanged(JNIEnv*,jobject,jint w,jint h){
  width=std::max(1,(int)w);height=std::max(1,(int)h);glViewport(0,0,width,height);
}
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_NativeRenderer_nativeDrawFrame(JNIEnv*,jobject){
  elapsed+=1.0f/60.0f;
  if(dragging){
    float dx=(moveX-downX)/std::max(1.0f,(float)width);
    float dy=(moveY-downY)/std::max(1.0f,(float)height);
    px+=std::clamp(dx*3.8f,-0.055f,0.055f);
    py-=std::clamp(dy*3.8f,-0.055f,0.055f);
    downX=moveX;downY=moveY;
  }
  px=std::clamp(px,-1.48f,1.48f);py=std::clamp(py,-0.66f,0.66f);
  glClear(GL_COLOR_BUFFER_BIT);if(!program)return;
  glUseProgram(program);
  glUniform2f(glGetUniformLocation(program,"uRes"),(float)width,(float)height);
  glUniform1f(glGetUniformLocation(program,"uTime"),elapsed);
  glUniform2f(glGetUniformLocation(program,"uPlayer"),px,py);
  glBindVertexArray(vao);glDrawArrays(GL_TRIANGLES,0,3);
}
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_MainActivity_00024GameSurface_nativeTouch(JNIEnv*,jobject,jint action,jfloat x,jfloat y,jfloat,jfloat){
  if(action==0){dragging=true;downX=moveX=x;downY=moveY=y;}
  else if(action==1&&dragging){moveX=x;moveY=y;}
  else if(action==2){dragging=false;moveX=moveY=downX=downY=0.0f;}
}
