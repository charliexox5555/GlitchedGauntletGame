# Lobby Lighting Pass (2026-11-28)

**Owner (2026-11-28):** "Let's improve the lighting in the hub; there are some parts like in the middle where it is way too bright on the player and such, so just an overhaul to improve it please."

**Status:** applied in Studio (Edit) and checked in Play solo. **Waiting on the owner's OK; the owner must save the place.** Not published.

Builder: `tools/studio/lobby_v5/HubLightingPass.luau` (Edit mode, re-runnable). Captures: `Lobby V5/2026-11-28/` (sheet `00 Lighting before-after sheet.jpg`).

## What was wrong (measured)
- **Global:** `ExposureCompensation` +0.1 and Bloom `Threshold` 1.4. Any pale skin or shirt under two or three lamps went past the bloom threshold and glowed. The torso showed as a white blob with a halo (Duels deck, Locker, Range gate).
- **Stacked long-range lamps on the walk paths.** I summed brightness × (1 − d/range) at torso height:
  - hub middle ≈ 6–7 (16 rock-wall lamps at B2.5/R64, all casting shadows, overlapping in the middle);
  - Duels deck ≈ 6–7 (9 RockLamp_Far, 5 ChasmGlow and 4 Side lamps at B3/R70–80, 12 wall lamps at B3/R44, 4 uplights at B2.5), plus the `ReleaseRouteLighting.DuelsDeck` SurfaceLight 9 studs over the player;
  - the Shop ≈ 2, which was fine.
- **Locker:** a low ceiling with fill PointLights at head height (y 10). The gun-circle accent PointLights sit about 2 studs from where players stand.
- Shadow-casting lights in LobbyV5: **60**.
- The sun is high (ClockTime 14.6) and falls into the open-top hub pit. **Left as is:** it gives the hub its outdoor read. The fix was the stacking and the exposure, not the sun.

## What changed
| What | Before | After |
|---|---|---|
| Lighting.Brightness | 2.4 | 2.0 |
| Lighting.ExposureCompensation | +0.1 | **−0.3** |
| Lighting.ColorShift_Top | 255,214,170 (orange skin) | 255,228,198 |
| Lighting.EnvironmentSpecularScale | 0.25 | 0.15 |
| Bloom Intensity / Threshold / Size | 0.6 / 1.4 / 24 | 0.35 / **2.2** / 20 |
| Hub WallLamps (16 SpotLights) | B2.5 R64, all shadows | B1.4 R50, shadows on every other one |
| Duels RockLamp_Far (9) | B3, all shadows | B1.6, shadows on every other one |
| Duels RockLamp_Side (4) | B3 | B1.6 |
| Duels ChasmGlow (5) | B3, shadows | B1.8, no shadows |
| Duels WallLamp (12) | B3 R44, all shadows | B1.6 R40, shadows on every other one |
| Duels Uplight (4) / Fill (6) | B2.5 / B0.9 | B1.5 / B0.6 |
| ReleaseRouteLighting SurfaceLights (7) | B0.85–1.2 | × 0.55 |
| Locker Room Fill (3) / CeilingLight (6) | B0.73 / B1.24 | B0.4 / B1.0 |
| Locker GunCircle accents (8) | B0.45 R6 | B0.3 R4 |

- Shadow-casting lights: **60 → 42**. That is cheaper on phones; Technology is unchanged.
- **Unchanged:** the sky, Atmosphere, HubGrade, ambients, every room's accent colour, the hologram and Shop display lights, and the signs.
- Every changed property keeps its old value in a `Pre_<Prop>` attribute and the new one in `New_<Prop>`. The revert snippet is at the bottom of the builder.
- **Rerunning** `BuildHub`, `BuildDuels`, `BalanceReleaseLighting` or a `BuildLocker*` builder brings the old lamp values back. Run `HubLightingPass` after them.

## Range and matches
- No code change was needed.
- `shared/MapLighting.capture()` reads the Studio Lighting as the lobby baseline before a match or the Range profile, and `restore()` puts it back. So the new values are the lobby values players return to.
- **Matches** (`Config/MatchLighting`) set every Lighting property this pass touched and suspend the lobby bloom.
- **The Range** (`Config/RangeLighting`) also sets every one of those properties. Only the gentler bloom carries into it.
- **Play check:** the client read exposure −0.30 and bloom 0.35/2.2 in the lobby. The owner's avatar (white outfit) kept its detail in the hub middle and on the Duels deck (`06`, `07`).
- **Not walked:** the Range round trip in Play (the reasoning above covers it).

## Result
- No pale avatar blows out in the hub middle, Duels deck, Shop, Locker or at the Range gate.
- The holograms, the SHOOTING RANGE sign and the queue signs still read. The rock walls keep their warm light.
- The Duels back wall is a little darker than before.
