# Project Arena — Hub and Character Selection Rework

## Visual direction

- Preserve the 2D command-tower hub and Flutter Scene 3D character previews.
- Increase environmental specificity with market frontage, awnings, illuminated windows, street lamps and a lower transit/canal layer.
- Keep the background as a static CustomPainter behind RepaintBoundary; no 3D scene or GLB imports are added to the hub.
- Place player identity in the upper-left corner: a player glyph, saved display name and equipped profile-frame accent.
- Reorganize hero selection around a prominent right-side hero preview and a left-side roster panel. Tapping a hero updates its details immediately; confirmation returns to the hub.

## Functional sub-screens

### Player profile
Local display name, avatar selection, match/win counters and cosmetic frame state. No account or network dependency is added.

### Chests
One guaranteed daily chest containing 100 local Arena credits. It can be claimed once per local calendar day. There is no random reward table or paid chest flow.

### Challenges
Three locally tracked milestones:
- First completed match: 60 credits.
- First victory: 90 credits.
- Five completed matches: 220 credits.

Progress updates only after the state machine accepts a match result. Each reward can be claimed once.

### Merchant
The merchant sells profile frames only. Frames change the profile appearance and never modify gameplay attributes. Credits are earned in-game; no purchase or external checkout is introduced. The in-match Quartermaster remains separate.

## Persistence and test seam

ArenaHubProgressStore uses SharedPreferencesAsync through a small ArenaHubPreferences adapter. The adapter lets unit tests use an in-memory implementation, covering daily claim limits, challenge rewards, cosmetic purchases and restore behavior without depending on the Android plugin.

## Mobile constraints

- Landscape-first, constraint-aware layouts.
- Lazy roster list and compact labels for smaller horizontal viewports.
- Static menu canvas, no additional GLB loads and no continuously animated background.
- The current hero 3D preview continues to use Flutter Scene at pixel ratio 1.0.
- Validate cold/warm navigation, sub-screen back behavior, one-time reward persistence, profile changes and performance on the Realme C53.

## UX references

- Brawl Stars selection and home-screen discoverability critique: https://ixd.prattsi.org/2025/02/design-critique-brawl-stars/
- Flutter performance practices: https://docs.flutter.dev/perf/best-practices
- Flutter RepaintBoundary: https://api.flutter.dev/flutter/widgets/RepaintBoundary-class.html
