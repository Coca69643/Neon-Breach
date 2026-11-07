# Project Arena — Native Renderer POC

Status: source implementation added; Android CI compilation and physical-device validation are pending.

## Architectural objective

Validate a route away from third-party game engines and scene runtimes.

This standalone proof of concept uses only:
- Android SDK / framework APIs;
- Android Canvas for the static 2D menu artwork;
- GLSurfaceView and raw OpenGL ES 2.0 for a static 3D city block;
- Java 17;
- Android Gradle Plugin 9.5.0.

It has no Flutter, Flutter Scene, Filament, Unity, Unreal, Godot, scene graph, physics engine, external renderer, or runtime asset dependency.

## What is implemented

- Full-screen 2D city composition painted with Android Canvas.
- Landscape-only standalone Android activity.
- Native button that opens the 3D scene.
- Static urban block assembled from low-poly cuboids.
- Single interleaved static vertex buffer and one draw call.
- Basic directional lighting in GLES 2.0 shaders.
- Touch orbit for inspection of the static environment.
- RENDERMODE_WHEN_DIRTY to avoid continuous rendering while the camera is idle.
- GLSurfaceView pause/resume handling.

The scene contains no playable character, combat, weapons, AI, network service, physics or gameplay simulation. It is strictly a rendering and application-lifecycle spike.

## Why GLES 2.0

Android documents GLES 2.0 support from API level 8 onward. The prototype targets the lowest broadly available programmable graphics baseline rather than assuming GLES 3.x support. The actual GPU capability and sustained performance still need to be measured on the Realme C53.

Official reference: https://developer.android.com/develop/ui/views/graphics/opengl/about-opengl

## Build verification

The dedicated workflow installs Android API 37 and runs:
- app:assembleDebug;
- app:lintDebug.

It does not upload, publish or distribute an APK artifact.

A successful CI build proves compilation only. It does not prove visual quality, frame pacing, thermal stability, memory use or compatibility on the physical Realme C53.

## Acceptance gate

- [ ] Android CI compiles the standalone project.
- [ ] Lint completes without errors.
- [ ] Menu uses correct landscape composition on the target aspect ratio.
- [ ] The city block renders with correct perspective and no missing faces.
- [ ] Drag orbit remains smooth and bounded.
- [ ] Background/resume restores the GL surface without a black screen.
- [ ] Physical Realme C53 test records FPS, memory, temperature and battery impact.
- [ ] Only after these checks may this renderer be evaluated as the foundation for the full native runtime.

## Explicit non-goals

This spike does not replace the current game runtime and does not alter the stable app, the active Flutter branch, the gameplay simulation or the current pull request. It is an isolated architecture experiment. No existing project code is deleted or migrated by this change.
