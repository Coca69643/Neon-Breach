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

cpp = Path("app/src/main/cpp/game.cpp").read_text()
for token in ("#version 300 es", "gl_VertexID", "nativeSurfaceCreated", "nativeSurfaceChanged", "nativeDrawFrame", "nativeTouch", "uEnemies[4]", "uBullets[8]", "firing && fireCooldown", "enemies[i].x+=dx/d*0.20f", "health=std::max", "uHud") :
    if token not in cpp:
        raise SystemExit(f"Native renderer check failed: {token} missing")
if re.search(r"uResolutionY|vec2\s+q\s*=", cpp):
    raise SystemExit("Stale/incomplete shader code detected")
if re.search(r"\bactive\b", cpp):
    raise SystemExit("GLSL ES reserved identifier 'active' detected; rename it before building")
if "makeFallbackProgram" not in cpp:
    raise SystemExit("Visible fallback renderer missing; shader failures must not silently leave a black screen")

activity = Path("app/src/main/java/com/duckdream/neonbreach/MainActivity.kt").read_text()
if "setEGLContextClientVersion(3)" not in activity or "RENDERMODE_CONTINUOUSLY" not in activity:
    raise SystemExit("OpenGL ES 3.0 continuous renderer setup missing")

print(f"Project structure and static checks OK ({len(required)} required files found).")
print("This check does not replace Android compilation or on-device testing.")
