# Recon bow: first-person hold and draw rebuilt (2026-11-16)

Owner: "fix the bow not fully loading, the animations being bad, should look like a good two hand first person draw back"; then "the bow parts look like they are gone and it is empty", "looks backwards… the string is not attached", "you see the gaps".

Captures: `2026-11-16 bow captures/` (1 before, 2-3 the model bug, 4-5 after).

## What was wrong
1. **The limbs were installed backwards (the main bug).** In `ReplicatedStorage.Abilities.Recon` both `LimbTop` and `LimbBottom` meshes came out of the FBX turned 180° about their own Y: they curved toward the arrowhead while the tip caps and string sat behind them, so the string looked detached and the bow backwards (capture 2). The Blender renders were right. Every other part was fine.
2. **The hold:** the bow in the right hand, turned 58° across the view; the bolt pointed sideways and the left hand tugged the string sideways a little (capture 1, grade ~3).
3. **Limb bend:** each limb is a rigid curved mesh turned about its pocket; bent hard it pulls out of the pocket (gaps).

## Fixes
- **Model:** both limbs turned 180° in Studio, their Welds re-solved (C0) so the third-person / world copies hold too (capture 3). Durable: `tools/studio/make_ability_build_data.py` `MESH_TURN_Y` → `turnY` in `BuildData/Recon.json`, applied by `AbilityBuilder` (`part.CFrame = … * rot * Angles(0, turnY, 0)`). **The place needs saving.**
- **Hold** (`Config/Viewmodel` `ITEM_HOLDS.Recon`, new `side`, `from`, `scale` fields): a right-handed archer, the bow in the LEFT hand, drawn with the right. Scale 1.35, 2.4 studs out, yaw +25, roll -42 (top canted right), riser just below left of the crosshair.
- **Draw hand** (`ViewmodelHeldMods.stepBowHand`): out of view at rest, up to the string in 0.14 s when LMB goes down, pulls straight back with the nock toward the right cheek, follows through toward the ear on release, rides the string forward on a cancel.
- **Bend** `BOW.flex` 16° (was 12; 26 opened the pockets).

## Why these numbers (so nobody repeats the dead ends)
- The bow, string and bolt lie in one plane; you only see the bow's face when the camera is off that plane. A bolt running exactly down the view puts the whole bow on one line through the centre (a stick). Yawing it +25° with the nock low right of centre and the top canted RIGHT shows the face at ~22°; canting left or putting the nock left turned it back into a stick.
- With our block arms, forearms must go DOWN out of the frame (like the gun and Molly holds); pointed back at the camera they fill the screen. The bow arm goes down a little right so the lower limb (down left) stays visible.
- Hands under ~1.3 studs from the camera make the blocks huge: the bow sits 2.4 out and is scaled up instead.

## Grade
Before ~3. After ~7: a whole bow, string attached, a clear two-hand draw with the limbs bending and the V of the string. Still to judge in motion: the raise, the release follow-through, and the 0.14 s reach to the string.
