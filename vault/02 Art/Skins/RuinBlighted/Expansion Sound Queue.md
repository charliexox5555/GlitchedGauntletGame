# Ruin-Blighted sound production checklist

Audited 2026-11-19 against the Match Studio Edit DataModel and the playback code. The review models are Vandal v07, Guardian v15, Spectre v10, Operator v10, Ghost v10 and Ruined Reaver v09. All five guns use the Vandal's original first-person handling recordings where named below. The Vandal has all 30 owner takes in its bank and needs **zero new files** for this pass. The custom Vandal report and rack hooks currently run in the Match Studio preview.

[Vandal](#vandal) · [Guardian](#guardian) · [Spectre](#spectre) · [Operator](#operator) · [Ghost](#ghost) · [Ruined Reaver](#ruined-reaver) · [Stock Knife](#stock-knife) · [Export and review](#export-and-review)

The names in backticks are the files or take families to look for. A range includes every numbered take. Use the [owner's Vandal WAVs](../../../06%20Assets/RuinBlighted/Vandal), the [processed stock WAVs](../../../../art-source/audio/ProPack/standalone) or the [original gun recordings](../../../06%20Assets/NewGunSounds/Guns). The [stock asset bank](../../../../src/shared/Config/GunSoundAssets.luau) and [Vandal asset bank](../../../../src/shared/Config/ShadowMistAudio.luau) map names to the exact Roblox asset IDs.

**Third-person rule.** Keep the skin's static model, color and emissive finish visible. Other players see the stock third-person motion and hear the stock spatial reports and melee sounds. The custom draw, shard motion, reload, inspect and handling audio belong to the equipped player's first-person view. The current world shot route already uses the stock fire clip and stock audio bank. This is the bundle rule for future wiring too, so there is no distant mix or third-person audio deliverable.

## Vandal

**Files to make · None.** This is the approved reference for the whole bundle. The 507 ms audition mix `94301133893352` is a load fallback for a custom report, before the stock bank. Keep the approved quiet decay and all current handling files.

| Action | What plays now | What to do |
| --- | --- | --- |
| Opening shot | Owner `Shot01_first.wav`. | **Keep.** |
| Repeat shots | Owner `Shot01.wav`–`Shot08.wav`. | **Keep all eight.** |
| Shot tail | Owner `Shot_00_Tail_only_01.wav`. It starts with each shot other than the last. The next shot fades it. | **Keep separate.** |
| Last round | Owner `Lastwithtail.wav`, with its own decay. | **Keep.** |
| Draw pickup | `gun_rifle_grab_pickup_01`, `gun_shotgun_pickup_01–02` | **Keep.** This exact pool also plays on Guardian and Spectre. |
| Draw shard gather | Vandal `Draw_air.wav`. Stock `whoosh_swish_small_01–04` is the fallback. | **Reuse the Vandal WAV.** |
| Draw shard lock | Vandal `Draw shard lock and reload seat accent.wav`. Stock `impact_hard` is the fallback. | **Reuse the same Vandal lock.** It covers the stock draw rack. |
| Tactical or empty reload, old mag out | Vandal `MagUnload01.wav`–`MagUnload04.wav`. Stock `gun_semi_auto_rifle_magazine_unload_01–04` is the fallback. | **Reuse the Vandal takes.** The same files cover both reloads. |
| New mag starts forming | Vandal `MagMaterializing.wav`. Stock `whoosh_swish_small_01` is the fallback. | **Reuse the Vandal WAV.** |
| Grab and throw | Vandal `MagGrabbedandthrown.wav` starts at the grab and carries into the throw. | **Reuse the Vandal WAV.** Keep the hand movement in one file. |
| Mag seats | Vandal `MagSeats01.wav`–`MagSeats05.wav` plus the same shared lock at lower gain. Stock `gun_semi_auto_rifle_magazine_load_01–05` is the fallback. | **Reuse the Vandal latch takes and quiet lock.** |
| Chamber or slide | Owner `Cock1.wav`–`Cock4.wav` on tactical and empty reloads. Stock `gun_semi_auto_rifle_cock_01–05` is the fallback. | **Keep all four owner takes.** Guardian shares the stock family as a base, while Vandal already has its own replacements. |
| Inspect entry | Vandal `StartingInspect.wav`. Stock `gun_semi_auto_rifle_safety_switch_01–03` is the fallback. | **Reuse the Vandal WAV.** |
| Inspect opening and hold | Vandal `DuringInspect.wav`. | **Reuse the Vandal WAV.** Its level stays below the entry and final lock. |
| Inspect lock | Same Vandal `Draw shard lock and reload seat accent.wav` as draw, played more quietly. | **Reuse the same lock.** Interruptions fade the entry and bed and skip the lock if it has yet to fire. |
| Aim in | `foley_cloth_light_fast_movement_13` and `14`. | **Keep the stock cue.** |
| Aim out | `foley_cloth_light_fast_movement_06` and `15`. | **Keep the stock cue.** |
| Dry trigger | `gun_semi_auto_rifle_dry_fire_01–04`. | **Keep the stock click.** |
| Low ammo | `gun_semi_auto_rifle_safety_switch_03` or `gun_rifle_safety_switch_01` after a shot with 1–7 remaining. | **Keep.** |
| World strike | `impact_hard`, `impact_metal` for metal and glass, `impact_wood`, `impact_soft`. | **Keep.** Same shared material cues as the Vandal. |
| Hit, headshot, kill and damage feedback | Shared hit marker, headshot, kill and headshot kill cues. The victim hears shared damage feedback. | **Keep.** Same cues as the Vandal. See the exact IDs under [Shared combat cues](#shared-combat-cues). |
| Other visual beats | Idle, holster, muzzle flash, tracer, case ejection and case bounce have no dedicated weapon cue. | No files to make. |
| Third-person firing | Stock `gun_semi_auto_rifle_shot_00_first_01`, `gun_semi_auto_rifle_shot_01–08` and `gun_semi_auto_rifle_shot_00_tail_only_01`. | **Keep.** |

## Guardian

**Files to make · Three local reports**, `Guardian_Shot_01.wav`–`Guardian_Shot_03.wav`. Use three different `gun_rifle_shot` takes as your bases. Keep the Vandal session layout, reuse a short piece of its clang and pull the whoosh down until the rifle crack leads. Let a short stone resonance follow each shot.

| Action | What plays now | What to do |
| --- | --- | --- |
| Opening, repeat and last shot | Stock `gun_rifle_shot_01–04` for every shot. One pool and no separate tail asset. | **Layer three takes.** The new pool can cover the opener and last shot too. |
| Draw pickup | `gun_rifle_grab_pickup_01`, `gun_shotgun_pickup_01–02` | **Keep.** Exact Vandal pickup pool. |
| Draw shard gather | Vandal `Draw_air.wav`. Stock `whoosh_swish_small_01–04` is the fallback. | **Reuse the Vandal WAV.** |
| Draw shard lock | Vandal `Draw shard lock and reload seat accent.wav`. Stock `impact_hard` is the fallback. | **Reuse the same Vandal lock.** It covers the stock draw rack. |
| Tactical or empty reload, old mag out | Vandal `MagUnload01.wav`–`MagUnload04.wav`. Stock `gun_semi_auto_rifle_magazine_unload_01–04` is the fallback. | **Reuse the Vandal takes.** The same files cover both reloads. |
| New mag starts forming | Vandal `MagMaterializing.wav`. Stock `whoosh_swish_small_01` is the fallback. | **Reuse the Vandal WAV.** |
| Grab and throw | Vandal `MagGrabbedandthrown.wav` starts at the grab and carries into the throw. | **Reuse the Vandal WAV.** Keep the hand movement in one file. |
| Mag seats | Vandal `MagSeats01.wav`–`MagSeats05.wav` plus the same shared lock at lower gain. Stock `gun_semi_auto_rifle_magazine_load_01–05` is the fallback. | **Reuse the Vandal latch takes and quiet lock.** |
| Chamber or slide | Stock `gun_semi_auto_rifle_cock_01–05` on the empty reload only. | **Keep.** Same stock source as the Vandal rack fallback. If it later needs a skin accent, layer only a short stone tick from the Vandal session. |
| Inspect entry | Vandal `StartingInspect.wav`. Stock `gun_semi_auto_rifle_load_bullet_01–07` is the fallback. | **Reuse the Vandal WAV.** |
| Inspect opening and hold | Vandal `DuringInspect.wav`. | **Reuse the Vandal WAV.** Its level stays below the entry and final lock. |
| Inspect lock | Same Vandal `Draw shard lock and reload seat accent.wav` as draw, played more quietly. | **Reuse the same lock.** Interruptions fade the entry and bed and skip the lock if it has yet to fire. |
| Aim in | `foley_cloth_light_fast_movement_13` and `14`. | **Keep the stock cue.** |
| Aim out | `foley_cloth_light_fast_movement_06` and `15`. | **Keep the stock cue.** |
| Dry trigger | `gun_semi_auto_rifle_dry_fire_01–04`, same as Vandal. | **Keep the stock click.** |
| Low ammo | `gun_semi_auto_rifle_safety_switch_03` or `gun_rifle_safety_switch_01` after a shot with 1–3 remaining. | **Keep.** |
| World strike | `impact_hard`, `impact_metal` for metal and glass, `impact_wood`, `impact_soft`. | **Keep.** Same shared material cues as the Vandal. |
| Hit, headshot, kill and damage feedback | Shared hit marker, headshot, kill and headshot kill cues. The victim hears shared damage feedback. | **Keep.** Same cues as the Vandal. See the exact IDs under [Shared combat cues](#shared-combat-cues). |
| Other visual beats | Idle, holster, muzzle flash, tracer, case ejection and case bounce have no dedicated weapon cue. | No files to make. |
| Third-person firing | Stock `gun_rifle_shot_01–04`. | **Keep.** |

## Spectre

**Files to make · Seven local WAVs.** Export `Spectre_Shot_First.wav`, `Spectre_Shot_01.wav`–`Spectre_Shot_04.wav`, `Spectre_Tail.wav`, and `Spectre_Shot_Last.wav`. Start from the Spectre's stock SMG clips. Use the Vandal session as a layout and turn the clang into a tiny tick. Keep the airy layer short enough to sit under a full spray at 75 ms between shots.

| Action | What plays now | What to do |
| --- | --- | --- |
| Opening shot | Stock `gun_submachine_auto_shot_00_first_01`. | **Layer the opener.** Add a small dark click and a little air behind the suppressed attack. |
| Repeat shots | Stock `gun_submachine_auto_shot_01–09`. | **Layer four different takes.** Use the same light accents across the pool. |
| Shot tail | Stock `gun_submachine_auto_shot_00_tail_only_01`. The next shot fades it. | **Make one separate quiet decay.** Let a released tap finish without building up in a spray. |
| Last round | Stock `gun_submachine_auto_shot_00_last_with_tail_01`. | **Make one final report** with the quiet taper baked in. |
| Draw pickup | `gun_rifle_grab_pickup_01`, `gun_shotgun_pickup_01–02` | **Keep.** Exact Vandal and Guardian pickup pool. |
| Draw shard gather | Vandal `Draw_air.wav`. Stock `whoosh_swish_small_01–04` is the fallback. | **Reuse the Vandal WAV.** |
| Draw shard lock | Vandal `Draw shard lock and reload seat accent.wav`. Stock `impact_hard` is the fallback. | **Reuse the same Vandal lock.** It covers the stock draw rack. |
| Tactical or empty reload, old mag out | Vandal `MagUnload01.wav`–`MagUnload04.wav`. Stock `gun_submachine_auto_magazine_unload_01–03` is the fallback. | **Reuse the Vandal takes.** The same files cover both reloads. |
| New mag starts forming | Vandal `MagMaterializing.wav`. Stock `whoosh_swish_small_01` is the fallback. | **Reuse the Vandal WAV.** |
| Grab and throw | Vandal `MagGrabbedandthrown.wav` starts at the grab and carries into the throw. | **Reuse the Vandal WAV.** Keep the hand movement in one file. |
| Mag seats | Vandal `MagSeats01.wav`–`MagSeats05.wav` plus the same shared lock at lower gain. Stock `gun_submachine_auto_magazine_load_01–04` is the fallback. | **Reuse the Vandal latch takes and quiet lock.** |
| Chamber or slide | Stock `gun_submachine_auto_cock_01–04` on the empty reload only. | **Keep.** This action is specific to the Spectre. |
| Inspect entry | Vandal `StartingInspect.wav`. Stock `gun_submachine_auto_load_bullet_01–04` is the fallback. | **Reuse the Vandal WAV.** |
| Inspect opening and hold | Vandal `DuringInspect.wav`. | **Reuse the Vandal WAV.** Its level stays below the entry and final lock. |
| Inspect lock | Same Vandal `Draw shard lock and reload seat accent.wav` as draw, played more quietly. | **Reuse the same lock.** Interruptions fade the entry and bed and skip the lock if it has yet to fire. |
| Aim in | `foley_cloth_light_fast_movement_13` and `14`. | **Keep the stock cue.** |
| Aim out | `foley_cloth_light_fast_movement_06` and `15`. | **Keep the stock cue.** |
| Dry trigger | `gun_submachine_auto_dry_fire_01–03`. | **Keep the stock click.** |
| Low ammo | `gun_semi_auto_rifle_safety_switch_03` or `gun_rifle_safety_switch_01` after a shot with 1–8 remaining. | **Keep.** |
| World strike | `impact_hard`, `impact_metal` for metal and glass, `impact_wood`, `impact_soft`. | **Keep.** Same shared material cues as the Vandal. |
| Hit, headshot, kill and damage feedback | Shared hit marker, headshot, kill and headshot kill cues. The victim hears shared damage feedback. | **Keep.** Same cues as the Vandal. See the exact IDs under [Shared combat cues](#shared-combat-cues). |
| Other visual beats | Idle, holster, muzzle flash, tracer, case ejection and case bounce have no dedicated weapon cue. | No files to make. |
| Third-person firing | Stock `gun_submachine_auto_shot_00_first_01`, `gun_submachine_auto_shot_01–09`, and `gun_submachine_auto_shot_00_tail_only_01` at the stock suppressed range. | **Keep.** |

## Operator

**Files to make · Three local reports**, `Operator_Shot_01.wav`–`Operator_Shot_03.wav`. Swap in the Operator sniper recordings. Keep their large attack, add a short low stone accent and a deeper, longer decay. Reuse the Vandal's air and metal stems at lower gain. Leave the bolt out of the report so its later movement stays clear.

| Action | What plays now | What to do |
| --- | --- | --- |
| Opening, repeat and last shot | Stock `gun_rifle_sniper_shot_01–04` for every shot. Each report carries its decay. | **Layer three takes.** Keep the natural decay inside each WAV. |
| Draw pickup | `gun_rifle_grab_pickup_01`. | **Keep.** It is the same rifle pickup found in the Vandal and Guardian pool. |
| Draw shard gather | Vandal `Draw_air.wav`. Stock `whoosh_swish_small_01–04` is the fallback. | **Reuse the Vandal WAV.** |
| Draw shard lock | Vandal `Draw shard lock and reload seat accent.wav`. Stock `impact_hard` is the fallback. | **Reuse the same Vandal lock.** It covers the stock draw rack. |
| Tactical or empty reload, old mag out | Vandal `MagUnload01.wav`–`MagUnload04.wav`. Stock `gun_rifle_magazine_unload_01–05` is the fallback. | **Reuse the Vandal takes.** The same files cover both reloads. |
| New mag starts forming | Vandal `MagMaterializing.wav`. Stock `whoosh_swish_small_01` is the fallback. | **Reuse the Vandal WAV.** |
| Grab and throw | Vandal `MagGrabbedandthrown.wav` starts at the grab and carries into the throw. | **Reuse the Vandal WAV.** Keep the hand movement in one file. |
| Mag seats | Vandal `MagSeats01.wav`–`MagSeats05.wav` plus the same shared lock at lower gain. Stock `gun_rifle_magazine_load_01–04` is the fallback. | **Reuse the Vandal latch takes and quiet lock.** |
| Chamber or slide | Stock `gun_rifle_sniper_cock_01–04` on the empty reload, with no bolt cue on tactical. | **Keep.** Use the same stock bolt pool for the post-shot action below. |
| Post-shot bolt | Same `gun_rifle_sniper_cock_01–04` about 0.58 s after a shot when rounds remain. | **Keep.** If replacing it later, reuse the one new bolt pool on both events. |
| Inspect entry | Vandal `StartingInspect.wav`. Stock `gun_rifle_sniper_scope_zoom_lens_01–07` is the fallback. | **Reuse the Vandal WAV.** |
| Inspect opening and hold | Vandal `DuringInspect.wav`. | **Reuse the Vandal WAV.** Its level stays below the entry and final lock. |
| Inspect lock | Same Vandal `Draw shard lock and reload seat accent.wav` as draw, played more quietly. | **Reuse the same lock.** Interruptions fade the entry and bed and skip the lock if it has yet to fire. |
| Aim in | `gun_rifle_sniper_scope_zoom_lens_01–07`, also the stock inspect fallback. | **Keep the stock cue.** |
| Aim out | `foley_cloth_light_fast_movement_06` and `15`. | **Keep the stock cue.** |
| Dry trigger | `gun_rifle_sniper_dry_fire_01–02`. | **Keep the stock click.** |
| Low ammo | `gun_semi_auto_rifle_safety_switch_03` or `gun_rifle_safety_switch_01` after a shot with 1–2 remaining. | **Keep.** |
| World strike | `impact_hard`, `impact_metal` for metal and glass, `impact_wood`, `impact_soft`. | **Keep.** Same shared material cues as the Vandal. |
| Hit, headshot, kill and damage feedback | Shared hit marker, headshot, kill and headshot kill cues. The victim hears shared damage feedback. | **Keep.** Same cues as the Vandal. See the exact IDs under [Shared combat cues](#shared-combat-cues). |
| Other visual beats | Idle, holster, muzzle flash, tracer, case ejection and case bounce have no dedicated weapon cue. | No files to make. |
| Loose cartridge insert | The stock bank has `gun_rifle_sniper_load_bullet_01–05`. The current magazine reloads have no insert cue. | No file to make. |
| Third-person firing | Stock `gun_rifle_sniper_shot_01–04`. | **Keep.** |

## Ghost

**Files to make · Three local reports**, `Ghost_Shot_01.wav`–`Ghost_Shot_03.wav`. Use three `gun_pistol_shot_silenced` bases. Borrow a trace of the Vandal air. Use a small mechanical tick in place of the louder rifle clang and keep the decay short.

| Action | What plays now | What to do |
| --- | --- | --- |
| Opening, repeat and last shot | Stock `gun_pistol_shot_silenced_01–04` for every shot. One pool and no separate tail asset. | **Layer three takes.** Keep the suppressed pop audible ahead of the accent. |
| Draw pickup | `gun_pistol_general_handling_05–10`. | **Keep.** This is the Ghost's own pickup pool. |
| Draw shard gather | Vandal `Draw_air.wav`. Stock `whoosh_swish_small_01–04` is the fallback. | **Reuse the Vandal WAV.** |
| Draw shard lock | Vandal `Draw shard lock and reload seat accent.wav`. Stock `impact_hard` is the fallback. | **Reuse the same Vandal lock.** It covers the stock draw rack. |
| Tactical or empty reload, old mag out | Vandal `MagUnload01.wav`–`MagUnload04.wav`. Stock `gun_pistol_remove_mag_01–06` is the fallback. | **Reuse the Vandal takes.** The same files cover both reloads. |
| New mag starts forming | Vandal `MagMaterializing.wav`. Stock `whoosh_swish_small_01` is the fallback. | **Reuse the Vandal WAV.** |
| Grab and throw | Vandal `MagGrabbedandthrown.wav` starts at the grab and carries into the throw. | **Reuse the Vandal WAV.** Keep the hand movement in one file. |
| Mag seats | Vandal `MagSeats01.wav`–`MagSeats05.wav` plus the same shared lock at lower gain. Stock `gun_pistol_insert_mag_01–05` is the fallback. | **Reuse the Vandal latch takes and quiet lock.** |
| Chamber or slide | Stock `gun_pistol_slide_fast_01–06` on both tactical and empty reloads. | **Keep the pistol slide.** The Vandal rack is a different action. |
| Inspect entry | Vandal `StartingInspect.wav`. Stock `gun_pistol_general_handling_02–04` is the fallback. | **Reuse the Vandal WAV.** |
| Inspect opening and hold | Vandal `DuringInspect.wav`. | **Reuse the Vandal WAV.** Its level stays below the entry and final lock. |
| Inspect lock | Same Vandal `Draw shard lock and reload seat accent.wav` as draw, played more quietly. | **Reuse the same lock.** Interruptions fade the entry and bed and skip the lock if it has yet to fire. |
| Aim in | No ADS on Ghost. | No file to make. |
| Aim out | No ADS on Ghost. | No file to make. |
| Dry trigger | `gun_pistol_dry_fire_01–06`. | **Keep the stock click.** |
| Low ammo | `gun_semi_auto_rifle_safety_switch_03` or `gun_rifle_safety_switch_01` after a shot with 1–4 remaining. | **Keep.** |
| World strike | `impact_hard`, `impact_metal` for metal and glass, `impact_wood`, `impact_soft`. | **Keep.** Same shared material cues as the Vandal. |
| Hit, headshot, kill and damage feedback | Shared hit marker, headshot, kill and headshot kill cues. The victim hears shared damage feedback. | **Keep.** Same cues as the Vandal. See the exact IDs under [Shared combat cues](#shared-combat-cues). |
| Other visual beats | Idle, holster, muzzle flash, tracer, case ejection and case bounce have no dedicated weapon cue. | No files to make. |
| Third-person firing | Stock `gun_pistol_shot_silenced_01–04` at the stock suppressed range. | **Keep.** |

## Ruined Reaver

**Files to make · Six local WAVs.** Export `Reaver_Slash_01.wav`–`Reaver_Slash_03.wav`, `Reaver_Heavy.wav`, `Reaver_Inspect_Grip.wav`, and `Reaver_Inspect_Split_Resonance.wav`. Keep the stock attack recordings as dry air sources if they help. Put the weight in a brief stone texture and restrained bronze ring, so a missed cut still sounds like a clean swing.

| Action | What plays now | What to do |
| --- | --- | --- |
| Draw pickup | Stock `whoosh_swish_small_01–04`, same as the stock Knife pickup. | **Keep for now.** This is the remaining stock swish on the draw. |
| Draw gather | Vandal `Draw_air.wav` under the rise. | **Reuse.** Same exact recording as the guns. |
| Draw assembly | Vandal shard lock at 0.58 s. | **Reuse** `Draw shard lock and reload seat accent.wav`. |
| Light 1, descending diagonal | Stock `knife_whoosh` four-take pool. Contact marker 0.168 s. | **Make Slash 01.** Quick, dry slice with a low stone edge. |
| Light 2, rising return | Same stock pool with the second step pitched a semitone higher. Contact 0.231 s. | **Make Slash 02.** Light start and a rising finish. Use the same stone texture more quietly. |
| Light 3, level cut | Same stock pool with the third step pitched two semitones higher. Contact 0.29 s. | **Make Slash 03.** Broader air pass with a short, quiet tail. |
| Heavy windup | Vandal `Draw_air.wav` at reduced gain. | **Reuse the Vandal air** while the sword lifts. |
| Heavy overhead release | Stock `knife_whoosh_heavy`, four takes. Contact marker 0.30 s. | **Make Heavy.** Slow the weight into the cut and peak the release at contact. Keep wall and body impacts separate. |
| Inspect entry at 0.10 s | Vandal `StartingInspect.wav`. | **Replace with Inspect Grip.** Record a close wrap rub and one small bronze contact. Start with the contact immediately available at the marker. |
| Inspect opening and hold at 1.13 s | Vandal `DuringInspect.wav` at reduced gain. | **Replace with Inspect Split Resonance.** Use two or three short stone separation ticks into a quiet, low resonant shimmer that fades naturally. Leave the main sweep of air to the attacks. |
| Inspect reassembly at 3.88 s | Vandal `Draw shard lock and reload seat accent.wav`. | **Reuse the existing lock.** Leave space before the impact. Keep entry, bed and lock separate so inspect cancellation can fade the first two. |
| Blade hits a character | `punch_grit_wet_impact_01–05`, plus shared combat confirmation when damage lands. | **Keep for this pass.** These are the physical contact takes. |
| Blade hits a wall or prop | `impact_hard`, `impact_metal` for metal and glass, `impact_wood`, `impact_soft`. | **Keep.** Same surface families as the guns. |
| Hit, headshot, kill and damage feedback | Shared hit marker, headshot, kill and headshot kill cues. The victim hears shared damage feedback. | **Keep.** Same cues as the Vandal. See the exact IDs under [Shared combat cues](#shared-combat-cues). |
| Third-person swing | Stock `knife_whoosh` spatial pool. The spectate shot route also uses that stock light pool. | **Keep.** The same stock pool covers the base Knife and Reaver. |
| Other actions | Idle, holster and blade trail have no dedicated cue. The knife has no reload, ammo warning, dry trigger or ADS. | No files to make. |

## Stock Knife

This is the plain Knife first-person bank. It uses the same attack and contact source pools that the Reaver currently borrows. The useful stock-only polish is two inspect recordings if you want the change on the base Knife too. The Reaver's two new inspect files stay separate.

| Action | What plays now | What to do |
| --- | --- | --- |
| Draw pickup | `whoosh_swish_small_01–04`, also Reaver's pickup. | **Keep.** |
| Draw pull-out accent | `whoosh_swish_high_fast_01–04`. | **Keep.** Reaver uses the Vandal draw air for that accent. |
| Light 1, 2 and 3 | `knife_whoosh` four-take pool with pitch variation. The combo steps climb by zero, one and two semitones. | **Keep.** These are the air bases for the new Reaver takes. |
| Heavy release | `knife_whoosh_heavy`, four takes. | **Keep** the base Knife take pool. |
| Inspect start | `whoosh_swish_small_01–04`. | **Replace if polishing stock inspect.** `Knife_Inspect_Grip.wav` can be cloth, a grip adjustment and a short metal tick. |
| Inspect first catch at 1.60 s | Same `whoosh_swish_small_01–04` pool at reduced level. | **Replace if polishing stock inspect.** `Knife_Inspect_Catch.wav` can be a dry, light catch with very little tail. |
| Inspect second catch at 3.00 s | Same small swish pool at reduced level. | **Reuse the first catch WAV.** A lower playback gain can mark the return to idle. |
| Blade hits a character | `punch_grit_wet_impact_01–05`, plus shared combat confirmation when damage lands. | **Keep for this pass.** These are the physical contact takes. |
| Blade hits a wall or prop | `impact_hard`, `impact_metal` for metal and glass, `impact_wood`, `impact_soft`. | **Keep.** Same surface families as the guns. |
| Hit, headshot, kill and damage feedback | Shared hit marker, headshot, kill and headshot kill cues. The victim hears shared damage feedback. | **Keep.** Same cues as the Vandal. See the exact IDs under [Shared combat cues](#shared-combat-cues). |
| Third-person swing | Stock `knife_whoosh` spatial pool. The spectate shot route also uses that stock light pool. | **Keep.** The same stock pool covers the base Knife and Reaver. |
| Other actions | Idle, holster and blade trail have no dedicated cue. The knife has no reload, ammo warning, dry trigger or ADS. | No files to make. |

## Shared combat cues

Keep `impact_hard`, `impact_metal`, `impact_wood` and `impact_soft`. Each is a three-take pool. Glass uses the metal cue. The hit marker is `rbxassetid://125235091454234`, headshot is `hit_head_F` (three takes), both kill cues use `kill_F`, and the victim hears `damage`. These already cover all weapons. [Shared cue config](../../../../src/shared/Config/Sounds.luau) · [Exact take IDs](../../../../src/shared/Config/GunSoundAssets.luau)

## Edit to the action

Seconds from the start of the animation at normal speed. These are guide marks derived from the current tracks and clip data. The game schedules separate files on each beat and can move the beats when action speed changes. The inspect entry fires at the start on all five guns.

| Weapon | Draw air / lock | Tactical mag out / form / grab / seat / rack | Empty mag out / form / grab / seat / rack | Inspect bed / lock |
| --- | --- | --- | --- | --- |
| Vandal | 0.29 / 0.74 | 0.37 / 0.68 / 1.18 / 1.58 / 2.14 | 0.41 / 0.76 / 1.32 / 1.76 / 2.51 | 1.19 / 4.86 |
| Guardian | 0.33 / 0.83 | 0.43 / 0.66 / 0.96 / 1.40 / — | 0.36 / 0.67 / 1.07 / 1.65 / 2.36 | 0.97 / 3.96 |
| Spectre | 0.26 / 0.66 | 0.39 / 0.56 / 0.82 / 1.24 / — | 0.34 / 0.56 / 0.92 / 1.48 / 2.19 | 0.80 / 3.29 |
| Operator | 0.46 / 1.16 | 0.59 / 0.93 / 1.41 / 1.98 / — | 0.50 / 0.93 / 1.56 / 2.29 / 3.13 | 1.07 / 4.37 |
| Ghost | 0.18 / 0.46 | 0.33 / 0.48 / 0.70 / 1.03 / 1.51 | 0.32 / 0.51 / 0.77 / 1.18 / 1.47 | 0.73 / 2.97 |

## Export and review

1. **Keep one editable session per weapon.** Duplicate the Vandal session and keep the base report, metal transient, movement layer and decay on separate tracks. Change the base report for each gun and adjust the layers by ear against that gun's stock shot.
2. **Export each named cue as one WAV.** Bring the transient close to the beginning and leave its natural low-level tail. For the Reaver, use the peaks in the stock swing recordings as guides. The current scheduler expects the light peak roughly 60 ms into the take and the heavy peak roughly 90 ms in. Inspect grip and split already have their own game markers.
3. **Check one draft before repeating the whole pack.** Compare a tap, short burst and full mag at the same in-game volume. Listen for overlapping tails on Spectre, a clear bolt after the Operator report, and a Reaver miss that has air without an impact. Test inspect cancellation before the lock.

**First delivery · 22 new WAVs** across Guardian (3), Spectre (7), Operator (3), Ghost (3) and Reaver (6). The two stock Knife inspect WAVs are optional. Shared Vandal recordings can be reused directly.

[Vandal cue sheet](Sound%20Cue%20Sheet.md) · [Report routing](../../../../src/client/Util/GunAudio.luau) · [Gun action audio](../../../../src/client/Util/ShadowMistActions.luau) · [Reaver action audio](../../../../src/client/Util/RuinedReaver.luau) · [Stock world playback](../../../../src/client/Controllers/EffectsController.luau) · [Combat sound design notes](../../../LihFolk/07%20Lighting%20VFX%20and%20Audio/Combat%20Sound%20Design%20and%20Feedback.md)
