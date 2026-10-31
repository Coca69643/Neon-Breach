# ORION-9 — Technology compatibility and repository strategy

Research and repository audit: 31 October 2026.

## Executive decision

Do not add several major technologies in one release. The current architecture is a native Android application with Kotlin + JNI + C++17 + OpenGL ES 3.0, a Jolt Physics world, and an in-house glTF/GLB asset loader. Improve the contracts between these existing layers before adding a second renderer, a second physics engine, a full ECS, or several middleware packages.

The Realme C53 is the reference device. All performance decisions must be verified on the actual device; a successful desktop build or emulator run is not a mobile performance result.

## 1. Repository audit — current implementation

Verified from the current `main` branch:

| Layer | Existing implementation | Compatibility implication |
|---|---|---|
| Android shell and UI | Kotlin `MainActivity`; custom `GLSurfaceView`; landscape manifest; API calls through JNI | Keep Android lifecycle, touch, menus, settings and system integration in Kotlin |
| Native runtime | C++17 shared library `neonbreach`; `game.cpp` contains simulation and renderer code | Preserve JNI contract while extracting subsystems gradually |
| Renderer | OpenGL ES 3.0 / GLESv3, custom shaders, meshes, postprocess and instanced projectile drawing | Keep GLES 3.0 as the baseline renderer for the current target until profiling justifies another backend |
| Physics | Jolt Physics v5.6.0 from CMake FetchContent; `PhysicsWorld` uses `CharacterVirtual` | Keep Jolt as the only physics authority; do not add Bullet/PhysX or duplicate player movement in parallel |
| Asset import | cgltf reads GLB; stb_image loads PNG textures; imported geometry is uploaded to GL buffers | glTF/GLB is already the established asset interchange path; improve the offline pipeline instead of replacing the runtime |
| World/gameplay | Four room definitions and links, fixed room layout, player/combat/progression state in C++ | The world should become data-driven through typed room/module definitions and shared sockets |
| Build | AGP 8.7.3, Kotlin plugin 2.0.21, compile/target SDK 35, CMake 3.22.1, NDK 27.2.12479018 in CI, JDK 17, C++17 | Upgrade toolchains in isolated commits and keep the exact CI/local versions aligned |

The native source is still concentrated in a large `game.cpp`. The asset importer currently proves static mesh/texture import; do not assume that glTF skeletal animation, a complete PBR material pipeline, navigation meshes, world streaming, or Vulkan are already implemented.

## 2. Recommended architecture boundaries

Maintain one direction of dependency:

```
Kotlin Android shell
  ├─ lifecycle, touch, settings, system UI
  └─ JNI adapter
       └─ C++ game runtime
            ├─ GameState / fixed-step simulation
            ├─ WorldModel / room graph / module sockets
            ├─ Jolt PhysicsWorld
            ├─ RendererGL (OpenGL ES 3.0)
            ├─ AssetCatalog / GLB + texture loading
            └─ Progression / save data
```

Rules:
- Kotlin communicates through a small, versioned JNI surface; it must not implement a second copy of gameplay state.
- C++ simulation owns the authoritative world and character state.
- The renderer reads simulation state; it must not secretly move gameplay objects.
- All player teleports, knockback, respawns, room transitions and collision corrections must synchronize through one authoritative physics transform.
- A room/module definition owns one transform and a set of sockets. Rendered walls, door apertures, gate colliders and navigation links derive from those same sockets.
- Keep platform-specific code out of gameplay rules. Keep GL calls out of Jolt. Keep asset parsing out of combat and progression code.

## 3. Incremental technology plan

### Phase A — stabilize existing systems first

1. Separate the monolithic C++ file gradually into `GameSimulation`, `WorldLayout`, `RendererGL`, `AssetLoader` and JNI adapter units. Move one subsystem at a time, preserving behavior with tests.
2. Make a single `RoomDefinition` / `ModuleSocket` data model the source for room placement, wall openings, doors, gate state and collision generation.
3. Make `PhysicsWorld` the sole authority for the player's physical transform. Route knockback, respawn, teleport and door changes through explicit API methods.
4. Add deterministic C++ logic tests for map connectivity, room bounds, door/gate state, collision aperture alignment and progression conditions. Prefer a dependency-free test executable first; add a test framework only when it materially helps.
5. Replace brittle literal-source checks in `verify_project.py` with executable behavior tests where possible. Keep static checks for project structure, licenses, package metadata and shader validation.
6. Add required pull-request status checks and protect `main`; do not merge when high-impact review findings or acceptance criteria remain unresolved.

### Phase B — establish an asset pipeline

1. Use Blender or another authoring tool only offline. Export approved models to GLB; the game remains a native runtime and does not acquire an editor/game-engine dependency.
2. Keep an immutable source archive and a provenance manifest per asset: pack, exact version, source URL, retrieval date, license, SHA-256, original filename, transform/scale, material and collision role.
3. Run offline checks for GLB validity, mesh/accessor presence, triangle count, dimensions, pivots, texture size, material count, naming and duplicate resources.
4. Build collision proxies separately from render meshes. Prefer low-cost boxes/capsules/convex pieces for structural modules; use triangle meshes only where necessary and measured.
5. Use a coherent material budget and texture atlas per environment family. Add ETC2 as the broadly compatible GLES 3 path and ASTC only after runtime capability detection; maintain a tested fallback. Android documentation describes ASTC as a preferred modern format and ETC2 as a fallback for devices without ASTC.
6. Import only selected optimized assets into the APK. Do not copy whole asset packs into runtime assets.

### Phase C — rendering improvements that fit GLES 3.0

Prioritize in this order:
1. Profile CPU and GPU frame time separately on the Realme C53.
2. Reduce draw calls with instancing and mesh/material batching.
3. Frustum-cull room modules and props; add simple LOD for large geometry.
4. Bound texture memory and use compressed texture formats with fallback.
5. Prefer baked/static lighting and a small controlled number of dynamic lights for fixed architecture.
6. Add effects only when their cost and readability have been measured.

Do not migrate the renderer to Vulkan merely because Vulkan is newer. Android's guidance says Vulkan can reduce CPU/driver overhead for scenes with many draw calls, but it also recommends checking exact device capabilities and retaining an OpenGL ES fallback where older or unreliable Vulkan implementations are in scope. Prototype Vulkan only after profiling demonstrates a renderer bottleneck that batching cannot solve, then compare the same scene on the target device and at least one other Android GPU.

### Phase D — physics, movement and navigation

- Keep the current Jolt version pinned and update it as a separate dependency-only change with regression tests.
- Use Jolt `CharacterVirtual` consistently for the player; test slopes, step height, grounding, doorway clearance and moving/teleport synchronization.
- Use static collision shapes for architectural modules and separate dynamic bodies only for objects that truly move.
- For the current small room graph, start with room-level connectivity plus local steering. Do not add a navigation-mesh library until multi-level geometry and enemy pathing demonstrate the need.
- If Recast/Detour is later introduced, keep it as a pathfinding layer only; it must not become another physics or transform authority.

### Phase E — animation and content systems

- Extend the existing cgltf-based path only when a validated character asset is available. glTF 2.0 includes skins and keyframe animations, but the project must implement joint transforms, skinning data, animation sampling and the GLES vertex path before such assets can animate.
- First support a small, fixed skeleton and a limited set of clips. Validate joint count, texture/vertex bandwidth, CPU sampling time and memory on the target phone.
- Keep procedural animation as a fallback for low-cost or temporary entities.
- Add save/version migration only after the gameplay data model is stable; version the save schema independently from the APK version.

## 4. Build and repository discipline

Current observed settings:
- Gradle Android plugin: 8.7.3
- Kotlin Gradle plugin: 2.0.21
- JDK 17
- Android compile/target SDK: 35
- CMake: 3.22.1
- CI NDK: 27.2.12479018
- Jolt: CMake FetchContent tag v5.6.0

Rules:
- Keep CI and local toolchain versions identical.
- Upgrade Android Gradle Plugin, Kotlin, Gradle, NDK or CMake one at a time; do not combine toolchain upgrades with gameplay changes.
- Pin third-party versions. Consider pinning GitHub Actions to immutable commit SHAs as a separate supply-chain hardening task.
- Keep licenses and notices beside the corresponding dependencies/assets.
- Use feature branches and pull requests, required CI checks, an inspectable diff and an artifact tied to an exact commit SHA.
- Store secrets only in repository/environment secret storage; never commit signing keys or credentials.
- Separate application version, save-schema version, repository slug and marketing title. They are different identifiers.
- The current README heading still says 0.8 while Gradle metadata is 0.9; the mobile build guide also contains old version-code guidance. Keep this documentation synchronized from a single version source.

## 5. Does renaming the GitHub repository break the app?

**Renaming only the GitHub repository from `Neon-Breach` does not, by itself, change the Android application ID or the installed APK identity.**

Verified current Android identifiers:
- Gradle `applicationId`: `com.duckdream.neonbreach`
- Gradle `namespace`: `com.duckdream.neonbreach`
- Kotlin package: `com.duckdream.neonbreach`
- Native CMake target/library: `neonbreach`
- Root Gradle project label: `NeonBreach`

These are independent of the GitHub repository slug. Do not change them just to rename the repository. Android app updates depend on the application ID, matching signing certificate and a non-decreasing versionCode—not the GitHub URL.

### Repository-specific rename audit

Found:
- The README and `BUILD_ON_GITHUB_MOBILE.md` contain links to `https://github.com/Coca69643/Neon-Breach`; update them to the new canonical URL after a rename.
- The project tree has no GitHub Pages site configuration.
- The current in-repository workflow uses GitHub-hosted actions and does not call this repository as a reusable action.

Potential risks:
- GitHub documents automatic redirects for normal repository pages and old `git clone/fetch/push` URLs. It recommends updating local clone remotes anyway.
- GitHub explicitly does **not** redirect calls to an Action hosted in a renamed repository; external workflows using `Coca69643/Neon-Breach@ref` would need updating. No such self-reference was found in the current repository workflow, but external consumers cannot be audited from this repository alone.
- GitHub Pages project-site URLs are an exception to the general redirect behavior. No Pages configuration was found in the current tree.
- Update badges, README links, release/download instructions, local Git remotes, external documentation and any connected automation that stores the old slug.
- Do not create a new repository later with the old slug; GitHub warns that reusing it breaks the old-name redirects.

### Safe rename sequence

1. Choose the final canonical repository slug first. Do not rename repeatedly.
2. Merge or close the open documentation PR, then record the current main commit SHA.
3. Search the repository and external automation for the old slug; update links and badges in a dedicated PR.
4. Rename the repository in GitHub Settings.
5. Update any local clone remote:
   `git remote set-url origin https://github.com/Coca69643/NEW-REPOSITORY-NAME.git`
6. Run CI on the renamed repository; verify checkout, build, artifact upload and direct download.
7. Verify the existing APK can still be updated in place using the same application ID and signing certificate.
8. Keep the old slug unused.

Do not rename the Android package or native library as part of a GitHub repository rename. A product-title/package migration is a separate, higher-risk operation and requires its own compatibility plan.

## 6. Source references

- Android Vulkan device selection and OpenGL ES fallback guidance: https://developer.android.com/games/develop/vulkan/native-engine-support
- Android Vulkan overview: https://developer.android.com/games/develop/vulkan/overview
- Android texture compression: https://developer.android.com/games/optimize/textures
- Android Frame Pacing / Swappy: https://developer.android.com/games/sdk/frame-pacing
- Jolt Physics CharacterVirtual API: https://github.com/jrouwe/JoltPhysics/blob/master/Jolt/Physics/Character/CharacterVirtual.h
- Jolt Physics architecture and character controllers: https://github.com/jrouwe/JoltPhysics/blob/master/Docs/Architecture.md
- Khronos glTF 2.0 specification: https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html
- GitHub repository rename behavior: https://docs.github.com/en/repositories/creating-and-managing-repositories/renaming-a-repository
- Android application update identity requirements: https://developer.android.com/google/play/app-updates
