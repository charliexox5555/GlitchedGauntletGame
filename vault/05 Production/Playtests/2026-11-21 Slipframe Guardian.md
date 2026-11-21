# Slipframe Guardian r05fx in Match Studio

2026-11-21. Solo Play in Match Studio (`133387545285290`) with the practice range enabled. Selected Guardian through the regular `PickWeapon` remote and Slipframe through the Studio skin picker route. The camera viewmodel and the third-person model both used `Slipframe/Guardian` r05fx. The camera alone had the sliding panel joint and the glint. Both Studio places loaded all 20 MeshParts and matched all eight stock motors and nine locators in Edit.

| Check | Observed in Play |
| --- | --- |
| Draw and hip hold | Left hand sits below the shroud and the side panel reads in the practice-range light. The skin selector says Slipframe. |
| Inspect (`Y`) | The insert lifted 0.0152 studs and slid 0.020 studs at 0.8× viewmodel scale. The ice-blue stroke traversed the recessed channel. The panel and glint returned to rest when inspect completed. [Inspect frame](../../02%20Art/Skins/Slipframe/out/studio_r05fx/guardian_inspect.jpg) |
| ADS | Clear rear aperture and stock post at the center of the actual first-person view, about 1.3 px from the viewport center in the sampled frame. [ADS frame](../../02%20Art/Skins/Slipframe/out/studio_r05fx/guardian_ads.jpg) |
| Fire | Actual trigger input showed a forward-moving seam stroke and cleared it within the 0.10 s pulse window. Sampled peak opacity 0.46 from the hip and 0.11 at settled ADS. The panel stayed seated. |
| Reload (`R`) | Actual partial-mag reload showed one short stationary flash on the magazine-seat cue. The 0.15 s cue faded out and the panel stayed seated. |
| Interrupt and fall back | Aiming during the open inspect seated the panel and hid the glint. Selecting Stock restored the standard Guardian without a glint part. |

The inspect frame uses the existing Studio visual slow-motion control to hold a frame. The ADS inspection used `DevAim` to hold aim in the same local session. Both temporary overrides were cleared. Live behavior was checked on Match. Lobby verification covered its static template and preload in Edit. Sound uses Guardian's existing presentation. The owner will approve the hero before the remaining guns and catalog release.

Both Rojo builds, formatting on the changed Luau files, and scoped Selene checks passed. The full-tree formatting check still reports `SettingsController` and `PlayerSettings`. Full-tree Selene still reports the existing `Content` global in Lobby's `PlayMenuController`.
