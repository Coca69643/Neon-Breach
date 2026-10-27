#!/usr/bin/env python3
from pathlib import Path
import re
import sys

required = [
    "settings.gradle", "build.gradle", "gradle.properties", "app/build.gradle",
    "app/src/main/AndroidManifest.xml",
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

cpp = Path("app/src/main/cpp/game.cpp").read_text()
for token in (
    "#version 300 es", "layout(location=0)", "uMVP", "uModel",
    "perspective(48.0f", "glEnable(GL_DEPTH_TEST)", "createMeshes",
    "fixedUpdate", "resolveCollision", "makeFallbackProgram",
    "nativeSurfaceCreated", "nativeSurfaceChanged", "nativeDrawFrame", "nativeTouch",
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
              "ACTION_POINTER_DOWN", "ACTION_POINTER_UP", "movePointerId", "aimPointerId"):
    if token not in activity:
        raise SystemExit(f"Android renderer/input check failed: {token} missing")

print(f"Project structure and 3D static checks OK ({len(required)} required files found).")
print("This check does not replace Android compilation or on-device testing.")
