# Duck Dream Studios — Engineering Protocol (Mandatory)

This document is the persistent engineering checklist for every ORION-9 change. Read it before editing source. It exists to prevent rushed implementation, unsupported completion claims, and regressions.

## Non-negotiable rule

Do not optimize for the number of changes or the speed of version releases. Optimize for verified, stable progress. A task is not complete because code was written or an APK compiled.

## Required sequence

### 1. Repository and runtime audit
- Read the current branch, recent commits, working tree, relevant source files, build configuration, and existing tests.
- Trace the real call path and lifecycle of every system being changed.
- Identify current behavior, known defects, dependencies, and constraints before proposing edits.
- Do not infer implementation from filenames, comments, prior summaries, or a previous assistant response.

### 2. Research and evidence
- Research only the decisions that need external evidence: APIs, libraries, rendering practices, asset licenses, platform constraints, and comparable shipped products.
- Prefer official documentation and primary creator/license pages.
- Record source URLs, the date checked, and what the source actually establishes.
- Separate confirmed facts from assumptions and design proposals.

### 3. Diagnosis and acceptance criteria
- State the root cause, not only the symptom.
- List affected systems/files and likely regression paths.
- Define observable acceptance criteria before implementation.
- For visual/gameplay changes, specify what must be observable in a running build; a source-token check is not an acceptance criterion.

### 4. Small, controlled implementation
- Work on a dedicated branch.
- Make a coherent, reviewable change set; avoid unrelated edits and version churn.
- Preserve existing behavior unless the change intentionally replaces it.
- Keep one authoritative state for each gameplay fact (especially player position, physics state, room links, and door state).
- Derive visual geometry and collision geometry from shared data where possible.
- Never describe a planned or partially implemented feature as complete.

### 5. Independent code review
- Review the actual diff after implementation.
- Check API contracts, coordinate spaces, state synchronization, lifecycle/resume behavior, resource ownership, error paths, and performance costs.
- Resolve all high-severity findings. Record any intentionally deferred limitation and its impact.
- Do not weaken or rewrite tests merely to make a new implementation pass.

### 6. Layered validation
Run in this order, and report each result separately:
1. Formatting/static checks and asset/license validation.
2. Unit or deterministic logic tests for changed systems.
3. Native/Gradle compilation and shader validation.
4. APK inspection: package ID, version, ABI, assets, signature, and artifact checksum.
5. Runtime smoke tests for startup, menu, pause/resume, EGL/context recreation, and save/state behavior where applicable.
6. Gameplay acceptance tests for movement, collision, gates, room transitions, stairs, combat interactions, and camera.
7. Sustained-device testing on the Realme C53 for frame pacing, memory, heat, and interruptions.

A green CI run proves only the checks that actually ran. It does not prove visual quality, gameplay correctness, or device performance.

### 7. Release and truthful handoff
- Verify the exact commit SHA used by CI and ensure the APK was built from that SHA.
- Verify the artifact exists, is non-empty, inspectable, and downloadable before sharing it.
- Distinguish debug APKs from release-signed APKs; distinguish CI success from on-device validation.
- Report completed, failed, blocked, and untested criteria explicitly.
- Never claim a successful install, gameplay test, or Realme C53 performance result without direct evidence.

## Stop conditions

Stop and fix the current stage when:
- the source of truth for a state is ambiguous;
- rendered geometry and physical collision disagree;
- tests are stale, brittle, or only assert literal source strings;
- the build is green but the changed behavior has not been validated;
- a required artifact cannot be verified;
- a review finding with meaningful gameplay impact remains unresolved.

## Definition of done

A change is done only when its acceptance criteria are met, its regressions are checked, the exact build artifact is verified, and the report clearly identifies anything that still requires physical-device testing.

**No shortcuts. No premature success claims. No feature-count releases.**
