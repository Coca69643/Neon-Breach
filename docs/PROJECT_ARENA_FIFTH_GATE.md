# Project Arena — Fifth Gate: branded startup and humanized entry

## Intent

The fifth gate replaces the generic boot placeholder with a short Duck Dream Studios splash followed by a truthful, staged startup loader. It is layered above the existing app state machine and does not bypass manifest validation or runtime recovery.

## Startup sequence

1. **Brand splash:** transparent studio logo, brief scale/fade-in, then fade-out. The custom splash is intentionally short; it is not used to hide network delays.
2. **Player context:** restore local display name and avatar so the loader can greet the returning player.
3. **Package verification:** read the Flutter asset manifest and confirm every required content group plus the branding asset is packaged.
4. **3D runtime:** initialize shared Flutter Scene / Impeller static resources before any SceneView is mounted.
5. **Session services:** probe only the loopback TCP stack and initialize the Supabase client object. Neither action opens a room or signs in a guest.
6. **Hub:** enter the menu when core local content and the 3D runtime are ready. Network failures leave offline mode available.

## Memory and loading policy

The loader verifies the complete packaged catalog but does not decode every GLB, texture, and map chunk into RAM. Large scene content remains tied to match entry, where the existing match-loading phase can own its allocation and recovery. This avoids using the boot gate to retain the full battlefield while the player is still in the menu.

The LAN probe binds only to loopback on an ephemeral port and immediately closes it. It confirms that the local TCP stack can create a socket; it does **not** prove that another device is reachable over Wi-Fi. Physical two-device validation remains required.

The Supabase preparation step creates the client only. Authentication, private Realtime channel subscription, and Presence begin when the player explicitly opens or joins a room. A prepared client is not displayed as a connected player session.

## Humanized entry

The loading surface uses the player's saved display name and avatar, readable progress language, concise context, and a gameplay tip. It avoids a generic spinner or fake network percentage. Menu/game state and all simulation rules remain under the existing state machine.

## Validation

- flutter analyze
- flutter test
- Android profile build on the PR branch
- cold start, warm start, background/resume, airplane mode, and missing-asset recovery
- two physical Android devices on the same Wi-Fi for LAN; two guest sessions for Online
- sustained performance, memory and thermal review on the Realme C53

No release version or signing configuration is changed by this gate.

## References

- Flutter AssetManifest API: https://api.flutter.dev/flutter/services/AssetManifest-class.html
- Flutter image cache guidance: https://api.flutter.dev/flutter/widgets/precacheImage.html
- Android splash-screen guidance: https://developer.android.com/develop/ui/views/launch/splash-screen
- Supabase Realtime Presence: https://supabase.com/docs/guides/realtime/realtime-user-presence
