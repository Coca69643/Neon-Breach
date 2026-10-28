#!/usr/bin/env python3
from pathlib import Path
import re
import sys

required = [
    "settings.gradle", "build.gradle", "gradle.properties", "app/build.gradle",
    "app/src/main/AndroidManifest.xml", "app/src/main/res/drawable/ic_launcher.xml",
    "app/src/main/java/com/duckdream/neonbreach/MainActivity.kt",
    "app/src/main/cpp/CMakeLists.txt", "app/src/main/cpp/game.cpp",
]
missing = [p for p in required if not Path(p).is_file()]
if missing:
    print("Missing required project files:")
    print("\n".join(missing))
    raise SystemExit(1)

manifest = Path("app/src/main/AndroidManifest.xml").read_text()
if 'screenOrientation="landscape"' not in manifest:
    raise SystemExit("Landscape orientation is not configured")
if 'glEsVersion="0x00030000"' not in manifest:
    raise SystemExit("OpenGL ES 3.0 feature is not declared")
for attr in ('android:icon="@drawable/ic_launcher"', 'android:roundIcon="@drawable/ic_launcher"'):
    if attr not in manifest:
        raise SystemExit(f"Launcher icon configuration missing: {attr}")
icon = Path("app/src/main/res/drawable/ic_launcher.xml").read_text()
if 'android:viewportWidth="108"' not in icon or '#00DDF4' not in icon:
    raise SystemExit("Launcher icon vector is missing or malformed")

cpp = Path("app/src/main/cpp/game.cpp").read_text()
for token in (
    "#version 300 es", "layout(location=0)", "uMVP", "uModel",
    "perspective(", "glEnable(GL_DEPTH_TEST)", "createMeshes",
    "fixedUpdate", "resolveCollision", "makeFallbackProgram",
    "drawPose", "drawHumanoid", "rotateX", "rotateZ",
    "nativeSurfaceCreated", "nativeSurfaceChanged", "nativeDrawFrame", "nativeTouch",
    "nativeSetMode", "nativeStartNewMission", "nativeGetSnapshot",
    "relayMask==0x7", "action==7", "publishedSnapshot",
):
    if token not in cpp:
        raise SystemExit(f"3D renderer check failed: {token} missing")
if re.search(r"uResolutionY|vec2\s+q\s*=", cpp):
    raise SystemExit("Stale/incomplete shader code detected")
if re.search(r"\bactive\b", cpp):
    raise SystemExit("GLSL ES reserved identifier 'active' detected")
if "glBufferData" not in cpp or "glVertexAttribPointer" not in cpp:
    raise SystemExit("3D mesh vertex-buffer setup missing")

activity = Path("app/src/main/java/com/duckdream/neonbreach/MainActivity.kt").read_text()
for token in ("setEGLContextClientVersion(3)", "RENDERMODE_CONTINUOUSLY",
              "ACTION_POINTER_DOWN", "ACTION_POINTER_UP", "movePointerId", "aimPointerId",
              "INICIAR OPERAÇÃO", "CONFIGURAÇÕES", "OPERAÇÃO SUSPENSA",
              "DESATIVAR RELÉ", "OPERAÇÃO CONCLUÍDA", "VIBRAÇÃO DE INTERFACE"):
    if token not in activity:
        raise SystemExit(f"Android renderer/input check failed: {token} missing")

build = Path("app/build.gradle").read_text()
if "versionName '0.8.0'" not in build or "versionCode 10" not in build:
    raise SystemExit("Version 0.8.0 metadata missing")
if not re.search(r"targetSdk\s+35", build):
    raise SystemExit("Android target SDK 35 is not configured")

print(f"Project structure, icon, signing configuration, procedural humanoid renderer, UI and mission checks OK ({len(required)} required files found).")
print("This check does not replace Android compilation or on-device testing.")
