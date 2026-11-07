# Project Arena — runtime QA gate

Status: Profile ARM64 QA pipeline added to pull-request CI. Physical-device acceptance is pending.

## QA artifact identity

- Android application ID: `com.duckdream.projectarena.qa`
- Launcher label: `Projeto Arena QA`
- Build mode: Flutter `profile`
- Target ABI: `arm64-v8a`
- Signing: ephemeral Flutter/Android debug signing from the PR runner
- Artifact: `project-arena-1.8.0-arm64-profile-qa`
- Retention: 7 days

The package suffix allows the QA build to coexist with the stable `com.duckdream.projectarena` installation. Its app data is isolated. It is not an update package and must never be uploaded as a release.

The PR-only job does not load the persistent production keystore, create a release tag, publish a GitHub Release, or modify the stable app's data.

## Automated artifact checks

The PR workflow:

1. Generates the Android host and Flutter GPU manifest.
2. Changes the generated host's package identity to the isolated QA ID and updates its launcher label.
3. Builds an ARM64 Profile APK.
4. Runs the APK verifier against package, version, landscape orientation, minSdk, Flutter GPU metadata, expected CC0 assets, compiled scenes and ARM64-only native libraries.
5. Verifies the APK signature.
6. Publishes the APK and SHA-256 as a short-retention Actions artifact.

The standard release verifier remains unchanged in behavior for release builds; the `--qa-profile` option switches only the expected QA package ID and launcher label.

## Realme C53 acceptance procedure

Install the QA artifact alongside the stable app. Do not uninstall or overwrite the stable package.

Capture actual gameplay, not editor previews:

- West-north block from the normal gameplay camera.
- Southern entrance and its full route into the interior.
- Western avenue sidewalk with the adjacent building footprint.
- Reserva Verde capture point and grass movement area.
- A short continuous clip while walking around the building corners, entering/exiting the interior and crossing the park.

Inspect:

- Buildings, doors, walls and props at human gameplay scale.
- No visible floating, clipping, partial facades or geometry intruding into roads.
- Door opening and interior traversal match the collision footprint.
- The Reserva Verde point remains accessible and its capture area is not obstructed.
- Player movement remains responsive around corners and through doors.
- No crashes or state loss during pause/resume and app interruption.

For mobile performance, run a sustained session on the physical Realme C53 and record frame pacing/stutter, memory pressure, thermal rise, battery drain and recovery after background/resume. The target for the scenario gate is 30 FPS sustained; CI does not measure this.

## Evidence required to close M1

Attach unedited screenshots from the physical device and a short gameplay recording. Report device model, Android version, session duration and any observed hitching/overheating. Automated build success is only a prerequisite.

Only after M1 visual and device acceptance may work proceed to M2 (connecting the remaining districts). No release, merge or APK publication is authorized by this QA pipeline.
