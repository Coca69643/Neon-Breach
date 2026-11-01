#!/usr/bin/env python3
"""Structural checks for the first native mobile arena slice."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    file = ROOT / path
    if not file.is_file():
        raise SystemExit(f"Missing required file: {path}")
    return file.read_text(encoding="utf-8", errors="replace")

gradle = read("app/build.gradle")
manifest = read("app/src/main/AndroidManifest.xml")
main = read("app/src/main/java/com/duckdream/neonbreach/MainActivity.kt")
renderer = read("app/src/main/java/com/duckdream/neonbreach/FilamentGameRenderer.kt")
world = read("app/src/main/java/com/duckdream/neonbreach/WorldGlbBuilder.kt")
native = read("app/src/main/cpp/ArenaSimulation.cpp")
cmake = read("app/src/main/cpp/CMakeLists.txt")
readme = read("README.md")
license_text = read("ASSETS/Quaternius-Universal-Base-Characters-LICENSE.txt")
avatar = ROOT / "app/src/main/assets/characters/quaternius-character.glb.b64"

assert "versionName '0.1.0'" in gradle
assert "versionCode 31" in gradle
assert "filament-android:1.77.3" in gradle
assert "gltfio-android:1.77.3" in gradle
assert "filament-utils-android:1.77.3" in gradle
assert "C++20" in readme and "-std=c++20" in gradle and "cxx_std_20" in cmake
assert 'android:screenOrientation="landscape"' in manifest
assert 'android:required="false"' in manifest and "android.hardware.vulkan.version" in manifest
assert "Engine.Backend.VULKAN" in renderer and "Engine.Backend.OPENGL" in renderer
assert "Camera.Projection.ORTHO" in renderer and "WorldGlbBuilder.build()" in renderer
assert "ResourceLoader" in renderer and "AssetLoader" in renderer
assert "thigh_l" in renderer and "upperarm_r" in renderer
assert "terrainMesh()" in world and "ribbon(" in world and "treesAndShrubs()" in world
assert "natural_rocks" in world and "central_stone_shrine" in world
assert "nativeActivateDash" in main and "TouchStick" in main and "AppState" in main
assert "resolveCollisions" in native and "kCaptureDuration" in native
assert "kObstacles" in native and "gBoostCooldown" in native
assert "CC0 1.0 Universal" in license_text
assert avatar.is_file() and avatar.stat().st_size > 500_000
if re.search(r"(fireButton|nativeFire|shootProjectile|weaponDamage)", main + native, re.I):
    raise SystemExit("Legacy weapon controls were detected in the new playable path")

print("Project Arena 0.1 structure verified.")
print(f"Humanoid CC0 payload: {avatar.stat().st_size:,} bytes (base64).")
