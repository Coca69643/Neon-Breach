#include <jni.h>
#include <GLES3/gl3.h>
#include <android/log.h>
#include <algorithm>
#include <cmath>
#include <vector>

namespace {
GLuint program=0, vao=0, vbo=0; GLint resolutionLoc=-1, timeLoc=-1, playerLoc=-1;
int width=1,height=1; float px=0.0f,py=0.0f,stickX=0.0f,stickY=0.0f; bool dragging=false; float elapsed=0.0f;
const char* vs=R"( #version 300 es
layout(location=0) in vec2 aPos; uniform vec2 uResolution; void main(){ vec2 p=aPos/uResolution*2.0-1.0; gl_Position=vec4(p.x,-p.y,0.0,1.0); })";
const char* fs=R"( #version 300 es
precision mediump float; uniform float uTime; uniform vec2 uPlayer; out vec4 fragColor;
void main(){ vec2 p=gl_FragCoord.xy; vec2 q=vec2(p.x, uResolutionY-p.y); }
)";
GLuint compile(GLenum type,const char* src){ GLuint s=glCreateShader(type); glShaderSource(s,1,&src,nullptr); glCompileShader(s); GLint ok=0; glGetShaderiv(s,GL_COMPILE_STATUS,&ok); if(!ok){ glDeleteShader(s); return 0;} return s; }
GLuint makeProgram(){ const char* vert=R"(#version 300 es
layout(location=0) in vec2 aPos; void main(){gl_Position=vec4(aPos,0.0,1.0);})";
const char* frag=R"(#version 300 es
precision mediump float; uniform vec2 uRes; uniform float uTime; uniform vec2 uPlayer; out vec4 color;
float circ(vec2 p,vec2 c,float r){return smoothstep(r,r-0.012,length(p-c));}
void main(){vec2 uv=gl_FragCoord.xy/uRes; vec2 p=uv*2.0-1.0; p.x*=uRes.x/uRes.y;
float grid=step(0.985,fract((p.x+1.0)*9.0))*0.12+step(0.985,fract((p.y+1.0)*6.0))*0.12;
float edge=step(0.93,abs(p.x))*0.35+step(0.92,abs(p.y))*0.35;
float arena=step(abs(p.x),1.42)*step(abs(p.y),0.78);
vec3 c=vec3(0.025,0.04,0.09)+grid*vec3(0.0,0.5,0.8); c+=edge*vec3(0.0,0.5,0.9);
vec2 pl=uPlayer; float player=circ(p,pl,0.095); c=mix(c,vec3(0.1,0.95,1.0),player);
for(int i=0;i<5;i++){float fi=float(i); vec2 e=vec2(sin(uTime*0.35+fi*2.1)*0.95,cos(uTime*0.27+fi*1.7)*0.48); float enemy=circ(p,e,0.06); c=mix(c,vec3(1.0,0.15,0.38),enemy);}
float terminal=circ(p,vec2(-0.95,0.42),0.07)+circ(p,vec2(0.0,-0.48),0.07)+circ(p,vec2(0.95,0.42),0.07); c+=terminal*vec3(0.1,0.55,0.8);
color=vec4(c*arena,1.0);})";
GLuint v=compile(GL_VERTEX_SHADER,vert),f=compile(GL_FRAGMENT_SHADER,frag); if(!v||!f)return 0; GLuint p=glCreateProgram(); glAttachShader(p,v);glAttachShader(p,f);glLinkProgram(p);glDeleteShader(v);glDeleteShader(f);GLint ok=0;glGetProgramiv(p,GL_LINK_STATUS,&ok);if(!ok){glDeleteProgram(p);return 0;}return p; }
}
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_NativeRenderer_nativeSurfaceCreated(JNIEnv*,jobject){ program=makeProgram(); glClearColor(0.02f,0.03f,0.08f,1.0f); }
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_NativeRenderer_nativeSurfaceChanged(JNIEnv*,jobject,jint w,jint h){width=std::max(1,(int)w);height=std::max(1,(int)h);glViewport(0,0,width,height);}
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_NativeRenderer_nativeDrawFrame(JNIEnv*,jobject){elapsed+=0.016f; if(dragging){px+=stickX*0.008f;py-=stickY*0.008f;}px=std::clamp(px,-1.25f,1.25f);py=std::clamp(py,-0.65f,0.65f);glClear(GL_COLOR_BUFFER_BIT);if(!program)return;glUseProgram(program);glUniform2f(glGetUniformLocation(program,"uRes"),(float)width,(float)height);glUniform1f(glGetUniformLocation(program,"uTime"),elapsed);glUniform2f(glGetUniformLocation(program,"uPlayer"),px,py);glDrawArrays(GL_TRIANGLES,0,3);}
extern "C" JNIEXPORT void JNICALL Java_com_duckdream_neonbreach_GameSurface_nativeTouch(JNIEnv*,jobject,jint action,jfloat x,jfloat y,jfloat w,jfloat h){if(action==0){dragging=true;stickX=0;stickY=0;}else if(action==1&&dragging){stickX=std::clamp((x-w*0.18f)/(w*0.14f),-1.0f,1.0f);stickY=std::clamp((y-h*0.72f)/(h*0.18f),-1.0f,1.0f);}else if(action==2){dragging=false;stickX=stickY=0;}}
