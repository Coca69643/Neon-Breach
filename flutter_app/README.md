# Projeto Arena — Flutter foundation

This directory contains the independent Flutter/Dart runtime migration.
It is a foundation harness, not a playable release.

## Technology constraints

- Flutter is the mobile application framework.
- Dart owns gameplay rules, state, AI decisions, input mapping and the
  deterministic simulation.
- No Godot, Unity, Unreal, Flame, Flutter Scene or third-party game engine.
- 3D rendering is planned as a project-owned renderer on the official
  `flutter_gpu` low-level API.
- GPU work is isolated behind a renderer contract. The simulation and all
  state machines must run in unit tests without a GPU or Android device.
- Native platform code is restricted to Flutter's Android host and narrowly
  scoped platform interop if a measured requirement makes it necessary.

## State machines

The first foundation includes four independent finite state machines:

1. `AppFlowMachine`: boot, menu, character selection, match loading,
   gameplay, pause, results and recovery.
2. `MatchFlowMachine`: asset loading, countdown, active, pause, victory,
   defeat, failure and disposal.
3. `ActorStateMachine`: spawn, idle, movement, attack wind-up, attack,
   recovery, hit-stun, death and respawn.
4. `BotDecisionMachine`: lane patrol, engagement, base defense, neutral
   camp, objective contest, retreat, death and respawn.

Transitions are typed enums, not string labels. An invalid transition is
rejected without mutating the state or incrementing its revision. The renderer
cannot mutate these machines directly.

## Simulation contract

Gameplay updates use a bounded fixed step of 1/60 second. Rendering may run at
the display refresh rate and interpolates between simulation states. A long
frame stall is clamped and excess catch-up work is discarded, preventing an
unbounded catch-up loop.

## Renderer contract

The custom renderer will be added in a later milestone. It must:

- detect Flutter GPU availability before allocating scene resources;
- require the Android Flutter GPU opt-in in the manifest;
- validate Vulkan availability at runtime on Android;
- fail into an explicit renderer-unavailable state rather than hanging or
  preventing the rest of the application from opening;
- import/cook GLB assets before packaging and validate every resource URI;
- separate render resource lifetime from gameplay entity lifetime;
- use LOD, frustum culling, instancing and dynamic resolution as measured
  mobile optimizations, not as unverified claims.

The Realme C53 is the baseline device. Vulkan support must still be checked
on the physical device and driver before the renderer is considered accepted.

## Local verification

From this directory:

```sh
flutter pub get
flutter analyze --fatal-infos
flutter test
```

The CI workflow also creates the Android host project in its workspace and
builds a debug APK to verify the Flutter toolchain. That artifact is not a
player-facing build.
