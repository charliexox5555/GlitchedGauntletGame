# Ruin-Blighted audio

The owner approved the five guns in the running Match Studio playtest on 2026-11-20. The active `WeaponController`, `GunAudio` and `ShadowMistAudio` matched the saved source byte for byte after newline normalization. Match Client loaded all 35 unique report and tail assets across the five weapon profiles. Commit `3804053d` saves the routing, mix and upload manifest. Commit `8b251865` archives the 24 new source WAVs. The Vandal recording set was previously committed.

## Ruined Reaver

Mix [Pro Sound Effects recordings from the Roblox Creator Store](https://create.roblox.com/docs/audio/assets) in the client. The original air sound carries the swing. A trimmed blade scrape leads with a little stone grit underneath. The second slash is faster and higher, the third has a broader tail, and the heavy swing pitches both layers down. The layers begin 55 ms before each animation contact marker. Existing character and surface sounds handle actual contact.

The inspect starts with a grip slap and short bronze accent at 0.10 s. Stone movement and a quiet shimmer enter as the blade opens at 1.13 s. Both fade on cancellation. The existing shard lock lands at 3.88 s. Draw and windup keep the bundle's existing air cue. See [mix and trims](../../../src/shared/Config/RuinedReaverAudio.luau).

| Layer | Creator Store recording |
| --- | --- |
| Stone grit | [Gravel Shovel And Scrape 1](https://create.roblox.com/store/asset/9114657970/Gravel-Shovel-And-Scrape-1-SFX) |
| Blade edge | [Scissor Scrape Sharpening Blades Metal Shing](https://create.roblox.com/store/asset/9125900174/Scissor-Scrape-Sharpening-Blades-Metal-Shing-SFX) |
| Grip | [Knife Grab 901](https://create.roblox.com/store/asset/9116193501) |
| Bronze | [Anvil Hits Blacksmith Exterior 36](https://create.roblox.com/store/asset/9113132124/Anvil-Hits-Blacksmith-Exterior-36-SFX) |
| Shards | [Rock Movement Large Stone Rattling In Place](https://create.roblox.com/store/asset/9125874341/Rock-Movement-Large-Stone-Rattling-In-Place-SFX) |
| Shimmer | [Magic Twirling Small High Pitch Spinning Chi](https://create.roblox.com/store/asset/9125644410/Magic-Twirling-Small-High-Pitch-Spinning-Chi-SFX) |

## Verification

In the existing Match Studio **Client** DataModel, isolated muted copies of the changed modules verified that all six assets loaded and played, the four swing poses hit their scheduled markers, seeking and fade-stopping worked, and canceling inspect stopped the resonance. The owner's live playtest continued during the check. The normal first-person mix is ready for an audible check on the next synced Match Studio playtest. StyLua, Selene and both Rojo builds passed.
