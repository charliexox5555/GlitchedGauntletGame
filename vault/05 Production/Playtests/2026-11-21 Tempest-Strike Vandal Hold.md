# Tempest-Strike Vandal: first-person hold check

2026-11-21, match place, Studio solo play (test range). Model s07 (asset 83574942668717). [Hero plan and log](../../02%20Art/Skins/TempestStrike/Vandal%20Hero%20Plan.md)

## Fix found on the way
The viewmodel kept showing the stock Vandal. Model data now comes from tagged AssetData rows ([State values and asset data](../../04%20Tech/State%20Values%20and%20Asset%20Data.md)), but `InstallFlatSkin` still writes raw attributes, and the cloned model inherited the stock Vandal's tag (`GGAsset_MatchWeapons_13`), so `SkinReady` / `PreviewGeometry` were invisible to `StateValues`. Fixed the documented way: row `GGAsset_MatchSkins_341` in `src/shared/Config/AssetData/MatchSkins.luau` (stock Vandal fields + skin fields, like Ruin-Blighted's Vandal row), model retagged (`GauntletAuthoredData` + `GGAsset_MatchSkins_341`), attributes cleared. **Follow-up:** `InstallFlatSkin` should write the AssetData row and tags itself (parked in Bugs & Ideas).

## Results
- **Preview:** the `PreviewSkinLine` remote with `TempestStrike` swaps the camera gun to the 23 `SK_*` parts (Studio-only line).
- **Hip:** the gun reads as the Tempest-Strike Vandal: dark enamel body, brushed silver blades (Roblox Metal), cyan lines, leather. Under the range's midday sun the silver reads very bright (close to white on the handguard blade); leather reads warm brown.
- **ADS:** the open crescent is a big clear window, the blade post sits centred, the cyan horn caps stay outside the aim point, nothing faded wrongly (sight parts keep their names).
- **Inspect:** the stock inspect turns the whole gun with every part attached (magazine, bolt, handle on their bones). The reload did not start (magazine full), so reload staging is untested.
- No errors from the skin in the output (the sound-permission warnings are pre-existing).

## What to test next / open
- Owner look in play: is the silver too white under the sun? (Option: Panel colour a step darker or SmoothPlastic + reflectance instead of Metal.)
- Reload after firing a few shots (magazine leaves and returns with its wraps).
- Then the idle VFX pass (water ribbons, vent sparks), the fire pass and the actions.
