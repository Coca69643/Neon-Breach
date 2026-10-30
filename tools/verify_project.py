#!/usr/bin/env python3
from pathlib import Path
import re
import sys

required = [
    "settings.gradle", "build.gradle", "gradle.properties", "app/build.gradle",
    "app/src/main/AndroidManifest.xml", "app/src/main/res/drawable/ic_launcher.xml",
    "app/src/main/java/com/duckdream/neonbreach/MainActivity.kt",
    "app/src/main/cpp/CMakeLists.txt", "app/src/main/cpp/game.cpp",
    "app/src/main/cpp/ProgressionManager.h", "app/src/main/cpp/ProgressionManager.cpp",
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
    "playerSquashEnvelope", "playerSquashAge", "drawPlayerHealthBar", "barWidth=0.78f", "requiredHold=2.0f", "updateHeldInteraction", "interactionHeld", "interactionTimer", "LOOT_OVERCLOCK", "LOOT_NANO_SHIELD", "LOOT_PIERCING_ROUNDS", "rewardRoll(LOOT_OVERCLOCK,LOOT_PIERCING_ROUNDS)", "nanoShieldCooldown=10.0f", "piercesRemaining>0", "drawLootChest", "chestSpawned=true", "ROOM_COUNT=4", "std::array<Room,ROOM_COUNT> rooms", "drawRoomShell", "drawRoomEnergyDoor", "drawRoomArrow", "roomGatePassable", "updateRoomTransition", "processRoomClear", "wavesTotal=(i==0||i==3)?2:1", "uniform int uActiveRoom", "explorationFog", "squashX=1.0f+0.105f*squash",
    "squashZ=1.0f-0.080f*squash", "triggerCameraShake(0.13f,0.19f)",
    "#include <random>", "#include \"ProgressionManager.h\"", "ProgressionManager", "progression.registerElimination()", "TOTAL_MISSION_ELIMINATIONS=24", "spawnEnemyWave", "touchSensitivity", "nativeSetTouchSensitivity", "nativeSetSoundEnabled", "uSectorPalette", "std::mt19937 aiRandomEngine", "enemyReactionTimer",
    "enemyThinkInterval", "enemySlalomPhase", "enemySlalomFrequency", "enemySlalomStrength",
    "enemySteerX", "randomRange(0.0f,0.13f)", "enemySlalomFrequency[(size_t)i]",
    "createProjectileRenderer", "drawProjectilesInstanced", "glDrawElementsInstanced",
    "glVertexAttribDivisor", "GL_DYNAMIC_DRAW",
    "nativeSurfaceCreated", "nativeSurfaceChanged", "nativeDrawFrame", "nativeTouch",
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
              "SITE ORION-9  •  0.7", "SOM DE JOGO", "SENSIBILIDADE DO TOQUE", "Faixa ajustável de 50% a 150%.", "class DodgeControlButton", "drawText(\"ATIRAR\"", "ESQUIVA", "RELÉS  $relaysDone/3  +${relaysDone * 15}% DANO", "SALA ${room + 1}/4", "PORTA ABERTA  /  SIGA A SETA", "SEGURE INTERAGIR POR 2S", "BAÚ DISPONÍVEL  /  SEGURE PARA ABRIR", "beginInteraction()", "endInteraction()", "INTERAGIR", "ALERTA  /  EVITE A ÁREA", "ATIRAR", "FireControlButton", "Mantenha pressionado para disparo contínuo.", "ARRASTE O LADO DIREITO", "gameView.setFiring(shouldFire)", "ACTION_CANCEL, MotionEvent.ACTION_OUTSIDE", "dp(76)", "ESQUIVA", "Joystick de movimento",
              "EXTRAÇÃO CONCLUÍDA", "AMEAÇAS", "VIBRAÇÃO DE INTERFACE"):
    if token not in activity:
        raise SystemExit(f"Android UI/input check failed: {token} missing")

build = Path("app/build.gradle").read_text()
if "versionName '0.7'" not in build or "versionCode 22" not in build:
    raise SystemExit("Version 0.4 metadata missing")
if not re.search(r"targetSdk\s+35", build):
    raise SystemExit("Android target SDK 35 is not configured")

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
if "uActiveRoom" not in cpp or "explorationFog" not in cpp:
    raise SystemExit("Exploration fog shader is missing")
if "processRoomClear" not in cpp or "updateRoomTransition" not in cpp:
    raise SystemExit("Room-local waves or transition logic is missing")
if "for(int i=0;i<3;i++){if(relayMask&(1<<i))continue;" in cpp:
    raise SystemExit("Relays must no longer restore on a single tap")
if "nativeTouch(11" not in activity or "nativeTouch(12" not in activity:
    raise SystemExit("Held interaction JNI lifecycle is missing")
if "rooms[3].chestOpened" not in cpp or "LOOT_NANO_SHIELD" not in cpp:
    raise SystemExit("Final chest or loot modifier effects are missing")
print("Two-second relay hold, +15% relay damage, final supply chest and randomized permanent loot checks OK.")
print("Four connected rooms, locked energy doors, local waves, floor arrows and exploration fog checks OK.")
print("Minimal menu, text-only HUD, diegetic health bar and outline action controls checks OK.")
print("Progression, sectors, character abilities, native settings and optimized build checks OK.")
print("This check does not replace Android compilation or on-device testing.")
