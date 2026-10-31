# ORION-9 v0.9 — Vertical slice implementation contract

## Current production target

A native Android sci-fi action roguelite / dungeon crawler. The first vertical slice is a connected facility wing with a central atrium, research wing, power wing and containment wing.

## Runtime architecture

- Android/Kotlin: lifecycle, menus, operator selection, settings and touch.
- JNI: narrow input/configuration boundary.
- C++17/OpenGL ES 3.0: renderer, simulation, effects and content streaming.
- Jolt Physics 5.6.0: character controller, static collision and energy gates.
- glTF: modular architecture, props and animated character assets.

C++17 remains conditional on measurable production value. The team will compare iteration speed, content pipeline, visual quality, APK size, memory and sustained performance before committing to a long-term renderer/engine direction.

## Current implementation in this branch

- The player movement path now calls the existing Jolt CharacterVirtual controller.
- Room floors, segmented perimeter walls, cover and energy gates are built into the same physics world from room/link metadata.
- Doorway openings are generated as wall gaps; closed doors are separate Jolt gate bodies.
- The stair mesh has a matching conservative solid collider until a measured ramp collider is authored; players cannot pass through it.
- Jolt gravity is applied once by `CharacterVirtual::ExtendedUpdate`, avoiding a double-gravity update.
- Camera position changed from (focusX, 26, focusZ + 6) to (focusX, 16, focusZ + 11), approximately 55 degrees elevation above the horizontal plane.
- A CC0 asset acquisition manifest defines candidate packs and import constraints.

## Acceptance tests before APK release

1. Walk into every wall and cover object from multiple angles; no tunneling or visual/physical mismatch.
2. Cross every open doorway; no invisible wall, no side clipping and no room transition before crossing the threshold.
3. Attempt closed doors; movement is blocked by the physical gate.
4. Traverse the stair module; if it has no matching ramp collider, it must be treated as a solid obstacle until authored correctly.
5. Test diagonal movement, dodge, pause/resume and EGL context recreation.
6. Capture screenshots at the same camera framing in all four rooms.
7. Run a 20-minute session on Realme C53 and record average/1% low FPS, thermal behavior, memory and battery drain.

A successful Gradle build is necessary but not sufficient for acceptance. Do not label the vertical slice complete until the device tests and screenshots pass.
