# Projeto Arena — migração para Flutter sem game engine

## Decision

The Project Arena runtime is moving to Flutter + Dart. No third-party game
engine is part of the architecture.

- Flutter handles Android application lifecycle, input surfaces and UI.
- Dart owns the game simulation, AI, state machines and gameplay systems.
- The project will own its 3D renderer using Flutter's low-level
  `flutter_gpu` API.
- Native interop is permitted only for small, measured platform requirements;
  it must not become a hidden game engine.
- The previous Kotlin/C++/Filament runtime remains preserved as reference
  material until the new runtime passes acceptance. The default branch is not
  modified by this migration.

## Machine-of-states requirement

State machines are mandatory architecture, not optional UI state management:

| Machine | Responsibility |
|---|---|
| Application flow | boot, menu, character selection, loading, match, pause, results, recovery |
| Match flow | asset loading, countdown, active, paused, victory/defeat, failed, disposed |
| Actor state | spawn, idle, move, attack wind-up, attack, recovery, hit-stun, death |
| Bot decision | lane patrol, engage, defend, neutral camp, objective, retreat, death |

All transitions are typed and event-driven. Unknown transitions must be rejected.
State changes are recorded with a monotonically increasing revision. Rendering
must never own the authoritative game state.

## Simulation

A bounded fixed-step clock is established at 60 Hz. Physics, movement, cooldowns,
combat, bot decisions and minion waves advance on the same simulation clock.
Rendering interpolation is separate from simulation state.

## GPU and renderer risk

Flutter's `flutter_gpu` API is low-level and requires an Android opt-in. It
does not provide a ready-made game loop, physics world, asset pipeline or scene
editor. Those responsibilities remain in project-owned modules.

The custom renderer is not accepted until all of these checks pass:

1. Vulkan/Impeller capability is detected on the target Android device.
2. A minimal shader and render target initialize repeatedly without a crash.
3. A static test mesh renders with depth testing and correct orientation.
4. A GLB test model imports with validated vertex/index/material references.
5. A skinned hero plays idle/walk/run animations.
6. A 5v5 scene passes a sustained performance and thermal test on Realme C53.

If Vulkan or the GPU API is unavailable, the application must still open and
display a controlled renderer-recovery state. It must not hang or crash.

## Migration phases

1. Flutter application shell, typed state machines and deterministic clock.
2. GPU capability probe and project-owned renderer contract.
3. GLB import/cooking and one animated hero.
4. Open battlefield and camera.
5. Touch controls, deterministic simulation and actor combat.
6. Bots, minions, towers, objectives and match flow.
7. Android packaging, sustained device testing and migration acceptance.

The 1.7.0 native application remains the archived reference; the Flutter
migration is not considered a replacement until the acceptance gates pass.
