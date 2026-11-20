# Shadow Mist Vandal sound cue sheet

The installed Vandal set is complete for this pass. Use the [per-weapon sound production checklist](Expansion%20Sound%20Queue.md) for current playback, reuse decisions and the exact files still needed for the rest of the line.

2026-11-18. All 30 owner WAVs are uploaded as private group audio. The [Shadow Mist audio bank](../../../../src/shared/Config/ShadowMistAudio.luau) lists each WAV, Roblox asset ID, length, and mix gain. The sources are under `vault/06 Assets/RuinBlighted/Vandal/`. The earlier 507 ms audition mix `94301133893352` is the first-person shot fallback if the dedicated report cannot load. Distant reports still use the regular Vandal bank.

## Installed cues

| WAV | Match Studio use |
| --- | --- |
| `Shots/Shot01_first.wav` | Tap or first shot after a pause |
| `Shots/Shot01.wav` through `Shot08.wav` | Eight reports in the existing shuffle bag |
| `Shots/Shot_00_Tail_only_01.wav` | Quiet separate tail under each non-empty shot. The next round fades it. |
| `Shots/Lastwithtail.wav` | Last round of the magazine, with its own decay |
| `Draw_air.wav` and `Draw shard lock and reload seat accent.wav` | Shard gathering and lock on draw. A quieter copy of the lock plays at the mag seat. |
| `MagUnload01.wav` through `MagUnload04.wav` | Mag release and dissolve |
| `MagMaterializing.wav` and `MagGrabbedandthrown.wav` | Start of the mist cast and the support-hand grab leading into the throw |
| `MagSeats01.wav` through `MagSeats05.wav` | Mag latch, on the same frame as the lock accent |
| `Cock1.wav` through `Cock4.wav` | Late chamber action on tactical and empty reload |
| `StartingInspect.wav`, `DuringInspect.wav`, and the shard lock recording | Inspect entry, opening, and one impact when the armor reseats. An interruption fades the entry or opening sound and skips the impact. |

The stock draw pickup, ADS, dry fire, low-ammo warning, surface impacts and combat confirmations cover the cues that had no new exports. The custom shard lock replaces the stock draw rack.

Use the stock rifle recording for the punch of the shot and stock hand and cloth recordings for contact. Build the sounds for shard movement, mag magic, and the moving sight around what each animation actually does. Use the same stone, metal and air recordings across those cues at different weights so the skin has one recognizable sound.

## Stock sources and pre-upload design notes

This section records the starting sounds and the original recording brief. Use the installed-cue table and current checklist for what plays today.

The names below are the cue names in the [gun bank](../../../../src/shared/Config/GunSounds.luau) and [standalone asset manifest](../../../../src/shared/Config/GunSoundAssets.luau). The local processed WAVs are in `art-source/audio/ProPack/standalone/`. The purchased raw rifle WAVs are in `vault/06 Assets/NewGunSounds/Guns/`. A numbered range includes every take in that range. An impact cue maps to three standalone WAV takes.

| Cue | Stock source or current Shadow Mist layer | Shadow Mist direction |
| --- | --- | --- |
| Opening shot after a pause | `gun_semi_auto_rifle_shot_00_first_01` | **Layer.** The approved 507 ms mix is the reference. Keep the rifle attack and the weight of the metal hit. |
| Automatic follow-ups | `gun_semi_auto_rifle_shot_01`–`08` | **Layer.** Start with three different stock repeats and the same clang and whoosh. Match perceived punch. Rebalance the tail only if the spray masks the attacks. |
| Tail when the trigger is released | `gun_semi_auto_rifle_shot_00_tail_only_01` | **Keep the approved decay.** The preview already plays it as part of every report. If future mixes build up in a spray, export the spectral decay as an isolated layer so the stock-style tail fade can make room for the next shot. |
| Last round that empties the magazine | `gun_semi_auto_rifle_shot_00_last_with_tail_01` | **Layer.** Keep the same shot family. Use a small falling shard tick or a slightly different decay to mark empty. Keep the attack level consistent. |
| 3D shot heard by other players | Same repeat takes `01`–`08`, with the stock opening shot and tail logic | **Keep the stock spatial reports.** |
| Draw and hand pickup | `gun_rifle_grab_pickup_01`, `gun_shotgun_pickup_01`–`02` | **Keep quietly.** Put the glove and grip contact under the draw. |
| Draw air | `whoosh_swish_small_01`–`04` | **Replace.** Use reverse cloth or a brushed-metal swell as the fragments gather. |
| Charging handle on draw and both reloads | `gun_semi_auto_rifle_cock_01`–`05` | **Replace for this skin.** Let the shard lock cover the draw beat. Recast the late reload beat as a short chamber-seal tick. The regular reload also has a rack beat. |
| Draw shard lock and reload seat accent | `impact_hard` (existing Shadow Mist placeholder) | **Replace.** Give the draw a dense stone thud and a short metal snap. Use a smaller version at the mag seat under the latch. Give the two versions different weight and keep each to one clear impact. |
| Mag out | `gun_semi_auto_rifle_magazine_unload_01`–`04` | **Layer.** Keep a short release-latch click. Add a dry band snap and a little crumbling air as the mag drops and dissolves. |
| Mag materializes in the support hand | `whoosh_swish_small_01` (existing Shadow Mist placeholder) | **Replace.** Try a soft reverse breath and small stone ticks that gather into the shape. Start from the hand cast and let it peak when the mag becomes solid. |
| Mag grabbed and thrown toward the well | Visual beat, currently no separate cue | **Create.** Try a quiet contact tick as the hand closes and a short directional swish as the wrist flicks. |
| Mag seats | `gun_semi_auto_rifle_magazine_load_01`–`05`, with the same Shadow Mist `impact_hard` accent | **Layer.** Keep the clearest latch transient and add a short, low stone impact. Align them at the same seat frame. |
| Inspect starts | `gun_semi_auto_rifle_safety_switch_01`–`03` | **Replace.** Try a restrained grip scrape and the first faint shard separation. |
| Inspect opens, hovers and closes | Visual beats, currently no separate cues | **Create.** Let a few stone scrapes and a soft airy bed follow the opening. Keep the open hold quiet. End with a brief inward rush and a smaller version of the draw lock. Use separate cues so a cancelled inspect can stop the bed and skip the close. |
| Aim down sights | `foley_cloth_light_fast_movement_13` and `14` | **Layer.** Keep the cloth flick and add a tiny ceramic tick when the rear-sight pieces settle. |
| Leave ADS | `foley_cloth_light_fast_movement_06` and `15` | **Keep or lightly layer.** Use the cloth release with a touch of air if the sight movement needs it. |
| Low-ammo warning | `gun_semi_auto_rifle_safety_switch_03`, `gun_rifle_safety_switch_01` | **Keep this pass.** The shared tick comes in at seven rounds remaining and gets louder as the magazine empties. If reskinned later, audition a clearly separate hollow click. |
| Dry trigger | `gun_semi_auto_rifle_dry_fire_01`–`04` | **Keep or lightly layer.** Keep the clear dead click. A tiny energy sputter can give it character without sounding like a shot. |

## Shared cues and optional additions

- **Surface hit.** Keep the shared 3D impact families `impact_hard`, `impact_metal` (also used for glass), `impact_wood`, and `impact_soft`. If the wall scorch needs sound, add a quiet, short exhale only where the scorch appears. Keep the surface strike audible.
- **Combat confirmations.** The body hit marker is `125235091454234`. The headshot uses `hit_head_F` (three takes). Kills and headshot kills both use `kill_F` with the existing streak pitch ladder. Receiving damage uses `damage` on the victim's client. Keep these shared cues for the later feedback pass.
- **Idle, muzzle flash, tracer and casing.** There is no separate Shadow Mist sound for these now. The report already covers the flash. A separate tracer sound or casing tick would add repeated noise to every spray. If the idle needs sound after listening to the full set, try a very quiet, seamless held-only breath with a fade on equip and holster.

## Animation timing at normal speed

Session checked in Match Studio Solo. Times are relative to the start of each action. Equip or reload speed modifiers can move the times, so export individual WAVs with the attack ready for the animation cue.

| Event | Time |
| --- | --- |
| Draw | 1.12 s. The fragments gather from about 0.29 to 0.74 s. The inherited rack lands around 0.62 s and the shard lock at 0.74 s. |
| Tactical reload | 2.50 s. Old magazine releases at 0.37 s, mist cast begins at 0.68 s, replacement is visible around 0.90 s, hand closes at 1.18 s, throw at 1.30 s, seat at 1.58 s, inherited rack at 2.14 s. |
| Empty reload | 2.80 s. Release at 0.41 s, mist at 0.76 s, replacement around 1.01 s, grab at 1.32 s, throw at 1.46 s, seat at 1.76 s, inherited rack at 2.51 s. |
| Inspect | 5.40 s. The visible opening burst is at 1.19 s, the mid-inspect pulse at 2.54 s, and the shards accelerate inward from 4.16 s to a flash and impact at 4.86 s. The gun settles back into the hold. |

Start with three report variations, then the draw gather and lock, then mag snap, form, throw, seat and seal. Build inspect and ADS after those are audible in the range. Export each cue as its own WAV and keep the rifle, clang, air and decay layers separate in the edit session. Level-match the shot attacks and compare a tap, a short burst and a full magazine in Studio.

[Action audio and timing](../../../../src/client/Util/ShadowMistActions.luau) · [Shared feedback cues](../../../../src/shared/Config/Sounds.luau) · [Match Studio audio playtest](../../../05%20Production/Playtests/2026-11-18%20Shadow%20Mist%20Action%20Polish.md#shot-audio-preview)
