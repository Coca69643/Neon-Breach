# Playable CC0 hero assets

Three independent, self-contained GLB 2.0 character models are bundled offline.

| Hero | File | Quaternius model | SHA-256 |
| --- | --- | --- | --- |
| Lyra | `lyra.glb` | Woman Casual — Animated Women Pack | `99c4df0aaabd19022809facc68f5fb5f564d35df3a9893c273a31fdaacf68e96` |
| Bastion | `bastion.glb` | Man in Long Sleeves — Animated Men Pack | `48536b0e0ea375f0831dbf5154b4c2eafda8b6c9c19ba0996dd298f2fcc9164c` |
| Kairo | `kairo.glb` | Woman in Tank Top — Animated Women Pack | `9809532f4562ebfd3976bd96eeebd1efc1008d781aa71a15048db5bf5ae7344c` |

Creator: Quaternius. License: CC0 1.0 Universal / Public Domain. CC0 permits
commercial use, modification and redistribution. Sources:
- [Official Animated Women Pack](https://quaternius.com/packs/animatedwomen.html)
- [Official Animated Men Pack](https://quaternius.com/packs/animatedmen.html)
- [Animated Women Pack bundle](https://poly.pizza/bundle/Animated-Women-Pack-HHSKxnk1mY)
- [Animated Men Pack bundle](https://poly.pizza/bundle/Animated-Men-Pack-DAC9SDgMQT)
- [CC0 1.0 legal code](https://creativecommons.org/publicdomain/zero/1.0/)

Copied from `schulerj89/vanta-city` at source commit
`a3fbd53398d6712742f34170a54cb450c90b1f80`. SHA-256 values are pinned in
`cc0-manifest.json` and checked by `tools/verify_project.py`. No network is
used by the game at runtime.

Each model contains its own `HumanArmature` skin and original material palette.
Only non-combat `Idle`, `Walk` and `Run` clips are selected. Source
coordinates are Y-up, front is -Z, and authored height is approximately 4.64
units; renderer normalizes to the current 2.12-unit hero presentation and
compensates for source facing.

Each hero loads as an independent FilamentAsset/instance. The legacy shared
Quaternius rig remains only for bots and lane troops.
