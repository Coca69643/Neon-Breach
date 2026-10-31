#!/usr/bin/env python3
from pathlib import Path
import re
import sys
import json

required = [
    "settings.gradle", "build.gradle", "gradle.properties", "app/build.gradle",
    "app/src/main/AndroidManifest.xml", "app/src/main/res/drawable/ic_launcher.xml",
    "app/src/main/java/com/duckdream/neonbreach/MainActivity.kt",
    "app/src/main/cpp/CMakeLists.txt", "app/src/main/cpp/game.cpp",
    "app/src/main/cpp/ProgressionManager.h", "app/src/main/cpp/ProgressionManager.cpp",
    "app/src/main/cpp/third_party/cgltf.h", "app/src/main/cpp/third_party/stb_image.h",
    "app/src/main/assets/world/kenney/room-large.glb", "app/src/main/assets/world/kenney/room-wide.glb",
    "app/src/main/assets/world/kenney/room-corner.glb", "app/src/main/assets/world/kenney/corridor-wide.glb",
    "app/src/main/assets/world/kenney/corridor-corner.glb", "app/src/main/assets/world/kenney/gate-door.glb",
    "app/src/main/assets/world/kenney/cables.glb", "app/src/main/assets/world/kenney/stairs-wide.glb",
    "app/src/main/assets/world/kenney/Textures/colormap.png", "app/src/main/assets/world/kenney/LICENSE.txt",
    "app/src/main/cpp/third_party/CGltf-LICENSE.txt", "app/src/main/cpp/third_party/STB-LICENSE.txt",
    "tools/validate_shaders.py",
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
    "projectileBlocked", "ARENA_LAYOUT_B", "ARENA_LAYOUT_C",
    "dodgeCooldown", "enemyShotCooldown", "enemyWindup", "organicMesh", "drawCreature", "nearFieldPod", "nearActiveHazard", "HAZARD_X", "moveDirZ=dy/mag",
    "operativeClass", "operativeMoveSpeed", "operativeShotDamage", "operativeDamageTakenMultiplier", "nativeSetOperative", "SITE ORION-9",
    "ORION INDUSTRIAL MODULES", "updateCameraSpring", "cameraFocusX", "cameraFocusZ",
    "band=diffuse>0.72?1.0:(diffuse>0.34?0.72:0.43)", "makePostProgram",
    "createSceneTarget", "GL_FRAMEBUFFER_COMPLETE", "GL_RGBA8", "vec2 chromaticOffset",
    "smoothstep(0.18,1.20,radiusSq)", "postprocessReady",
    "updateCameraSpring", "cameraVelocityX", "cameraVelocityZ", "stiffness=72.0f",
    "updateCameraShake", "valueNoise", "triggerPlayerShotFeedback", "cameraShakeOffsetX",
    "playerSquashEnvelope", "playerSquashAge", "drawPlayerHealthBar", "barWidth=0.78f", "requiredHold=2.0f", "updateHeldInteraction", "interactionHeld", "interactionTimer", "LOOT_OVERCLOCK", "LOOT_NANO_SHIELD", "LOOT_PIERCING_ROUNDS", "rewardRoll(LOOT_OVERCLOCK,LOOT_PIERCING_ROUNDS)", "nanoShieldCooldown=10.0f", "piercesRemaining>0", "drawLootChest", "chestSpawned=true", "ROOM_COUNT=4", "std::array<Room,ROOM_COUNT> rooms", "drawRoomShell", "drawRoomEnergyDoor", "drawRoomArrow", "roomLinkOpening", "updateRoomTransition", "processRoomClear", "wavesTotal=(i==0||i==3)?2:1", "uniform int uActiveRoom", "unexplored", "squashX=1.0f+0.105f*squash",
    "squashZ=1.0f-0.080f*squash", "triggerCameraShake(0.13f,0.19f)",
    "#include <random>", "#include \"ProgressionManager.h\"", "ProgressionManager", "progression.registerElimination()", "TOTAL_MISSION_ELIMINATIONS=24", "spawnEnemyWave", "touchSensitivity", "nativeSetTouchSensitivity", "nativeSetSoundEnabled", "uSectorPalette", "std::mt19937 aiRandomEngine", "enemyReactionTimer",
    "enemyThinkInterval", "enemySlalomPhase", "enemySlalomFrequency", "enemySlalomStrength",
    "enemySteerX", "randomRange(0.0f,0.13f)", "enemySlalomFrequency[(size_t)i]",
    "createProjectileRenderer", "drawProjectilesInstanced", "glDrawElementsInstanced",
    "glVertexAttribDivisor", "GL_DYNAMIC_DRAW",
    "loadWorldAssets", "loadImportedModel", "readAndroidAsset", "cgltf_parse", "cgltf_load_buffers",
    "stbi_load_from_memory", "drawImportedModel", "MODEL_ROOM_LARGE", "MODEL_ROOM_WIDE",
    "MODEL_CORRIDOR_WIDE", "MODEL_GATE_DOOR", "AAssetManager_fromJava", "uBaseTexture",
    "uUseBaseTexture", "uRoomBounds[4]", "uVisitedRoomMask", "roomInsideTopDownFrustum",
    "roomLinkOpening", "RoomLink", "roomLinks[0]={0,1,0,1,-1,10.0f", "centersZ[4]={0.0f,0.0f,20.0f,20.0f", "room.halfWidth=10.0f;room.halfDepth=10.0f;", "roomIndex==0?1.0f:1.6666667f", "roomLinks[1]={1,2,1,1,-1,10.0f",
    "roomLinks[2]={2,3,0,-1,1,10.0f", "roomLinks[3]={3,0,1,-1,1,10.0f",
    "camera{cameraFocusX,16.0f", "unexplored",
    "nativeSurfaceCreated", "#include \"PhysicsWorld.h\"", "facilityPhysics.moveCharacter", "facilityPhysics.setGateOpen", "nativeSurfaceChanged", "nativeDrawFrame", "nativeTouch",
    "nativeSetMode", "nativeStartNewMission", "nativeGetSnapshot",
    "relayMask==0x7", "action==7", "if(action==8)", "if(action==9)", "firing&&shotCooldown<=0.0f", "publishedSnapshot",
):
    if token not in cpp:
        raise SystemExit(f"3D renderer check failed: {token} missing")
scene_start = cpp.index("void drawScene")
scene_end = cpp.index("bool projectileBlocked", scene_start)
scene = cpp[scene_start:scene_end]
if "drawTree(" in scene or "drawPlant(" in scene:
    raise SystemExit("Old forest props remain in the active scene renderer")

if re.search(r"uResolutionY|vec2\s+q\s*=", cpp):
    raise SystemExit("Stale/incomplete shader code detected")
if re.search(r"\bactive\b", cpp):
    raise SystemExit("GLSL ES reserved identifier 'active' detected")
if "glBufferData" not in cpp or "glVertexAttribPointer" not in cpp:
    raise SystemExit("3D mesh vertex-buffer setup missing")

activity = Path("app/src/main/java/com/duckdream/neonbreach/MainActivity.kt").read_text()
for token in ("setEGLContextClientVersion(3)", "RENDERMODE_CONTINUOUSLY",
              "ACTION_POINTER_DOWN", "ACTION_POINTER_UP", "movePointerId", "aimPointerId",
              "INICIAR OPERAÇÃO", "CONFIGURAÇÕES", "PAUSA",
              "SEGURE 2S  /  RELÉ", "KIT MÉDICO", "SELECIONE SEU OPERADOR", "ESCOLHER OPERADOR", "NEON-VANGUARD", "STELLAR-REAPER",
              "SITE ORION-9  •  0.8", "SOM DE JOGO", "SENSIBILIDADE DO TOQUE", "Faixa ajustável de 50% a 150%.", "class DodgeControlButton", "drawText(\"ATIRAR\"", "ESQUIVA", "RELÉS  $relaysDone/3  +${relaysDone * 15}% DANO", "SALA ${room + 1}/4", "PORTA ABERTA  /  SIGA A SETA", "SEGURE INTERAGIR POR 2S", "BAÚ DISPONÍVEL  /  SEGURE PARA ABRIR", "beginInteraction()", "endInteraction()", "INTERAGIR", "ALERTA  /  EVITE A ÁREA", "ATIRAR", "FireControlButton", "Mantenha pressionado para disparo contínuo.", "ARRASTE O LADO DIREITO", "gameView.setFiring(shouldFire)", "ACTION_CANCEL, MotionEvent.ACTION_OUTSIDE", "dp(76)", "ESQUIVA", "Joystick de movimento",
              "EXTRAÇÃO CONCLUÍDA", "AMEAÇAS", "VIBRAÇÃO DE INTERFACE"):
    if token not in activity:
        raise SystemExit(f"Android UI/input check failed: {token} missing")

build = Path("app/build.gradle").read_text()
if "versionName '0.9'" not in build or "versionCode 24" not in build:
    raise SystemExit("Version 0.4 metadata missing")
if not re.search(r"targetSdk\s+35", build):
    raise SystemExit("Android target SDK 35 is not configured")

asset_dir = Path("app/src/main/assets/world/kenney")
for asset_name in ("room-large.glb", "room-wide.glb", "room-corner.glb", "corridor-wide.glb", "corridor-corner.glb", "gate-door.glb", "cables.glb", "stairs-wide.glb"):
    asset_path = asset_dir / asset_name
    data = asset_path.read_bytes()
    if len(data) < 20 or data[:4] != b"glTF" or int.from_bytes(data[4:8], "little") != 2:
        raise SystemExit(f"Invalid glTF 2.0 asset: {asset_path}")
    json_length = int.from_bytes(data[12:16], "little")
    document = json.loads(data[20:20 + json_length].decode("utf-8").rstrip(" \\t\\r\\n\\0"))
    if not document.get("meshes") or not document.get("accessors"):
        raise SystemExit(f"GLB has no mesh/accessor content: {asset_path}")
texture = (asset_dir / "Textures/colormap.png").read_bytes()
if not texture.startswith(bytes([137, 80, 78, 71, 13, 10, 26, 10])):
    raise SystemExit("Kenney environment texture atlas is not a valid PNG")
if "CC0" not in (asset_dir / "LICENSE.txt").read_text():
    raise SystemExit("Kenney CC0 license is missing")
if "MIT" not in Path("app/src/main/cpp/third_party/CGltf-LICENSE.txt").read_text():
    raise SystemExit("cgltf MIT license is missing")
print("Native glTF 2.0 loader, CC0 room assets, atlas texture, 2x2 room graph, frustum culling and mobile LOD checks OK.")
print(f"Project structure, icon, playable operative classes, containment outpost, objective flow, touch controls and Android UI checks OK ({len(required)} required files found).")
cmake = Path("app/src/main/cpp/CMakeLists.txt").read_text()
if "-O3" not in cmake:
    raise SystemExit("Native optimized build flag -O3 is missing")
manager_header = Path("app/src/main/cpp/ProgressionManager.h").read_text()
manager = Path("app/src/main/cpp/ProgressionManager.cpp").read_text()
if "KILLS_PER_SECTOR = 20" not in manager_header or "sectorIndex_" not in manager:
    raise SystemExit("Sector progression manager does not define the 20-elimination unlock")
if "FALHA DE CONTENÇÃO" in activity or "healthBar" in activity or "healthValue" in activity:
    raise SystemExit("Legacy briefing panel or corner health HUD remains")
if "briefing" in activity:
    raise SystemExit("Legacy right-side menu briefing container remains")
if "std::array<Room,ROOM_COUNT> rooms" not in cpp or "void drawRoomEnergyDoor" not in cpp:
    raise SystemExit("Four-room dungeon data or energy-door renderer is missing")
if "uVisitedRoomMask" not in cpp or "unexplored" not in cpp or "uRoomBounds[4]" not in cpp:
    raise SystemExit("Visited-room exploration fog shader is missing")
if "processRoomClear" not in cpp or "updateRoomTransition" not in cpp:
    raise SystemExit("Room-local waves or transition logic is missing")
if "for(int i=0;i<3;i++){if(relayMask&(1<<i))continue;" in cpp:
    raise SystemExit("Relays must no longer restore on a single tap")
if "fun beginInteraction() = sendTouch(11" not in activity or "fun endInteraction() = sendTouch(12" not in activity:
    raise SystemExit("Held interaction JNI lifecycle is missing")
if "if(action==11)" not in cpp or "if(action==12)" not in cpp:
    raise SystemExit("Native held interaction begin/end actions are missing")
if "rooms[3].chestOpened" not in cpp or "LOOT_NANO_SHIELD" not in cpp:
    raise SystemExit("Final chest or loot modifier effects are missing")
print("Two-second relay hold, +15% relay damage, final supply chest and randomized permanent loot checks OK.")
print("Four connected rooms, locked energy doors, local waves, floor arrows and exploration fog checks OK.")
print("Minimal menu, text-only HUD, diegetic health bar and outline action controls checks OK.")
print("Progression, sectors, character abilities, native settings and optimized build checks OK.")
print("This check does not replace Android compilation or on-device testing.")
