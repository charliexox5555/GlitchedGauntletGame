# Ability rework (2026-11-15): plan and status

Brief: [2026-11-15 Ability Rework](../04%20Tech/Prompts/2026-11-15%20Ability%20Rework.md) (the owner's playtest feedback on all nine Mods). The owner rejected both Codex art passes (v01, v02), so props and VFX start again from scratch. The current game is the gameplay baseline.

Rules used: [Style Bible](../02%20Art/Style%20Bible.md), skill `gauntlet-build-style`, [Vandal](../02%20Art/References/vandal-blender-check.jpg) and [Phantom](../02%20Art/References/phantom-blender-check.jpg) as construction references, `art-source/abilities/README.md` for the Studio interface.

## Who runs what
| Work | Model | How |
|---|---|---|
| Plan, visual consistency, Studio integration, final verification | Opus 5.5 (since 2026-11-16) | this parent chat |
| Props, VFX building, animation, wiring, checks | Opus 5.5 | one session or agent each, tight briefs |
| Locking things in: the shared effects language, the final consistency review, a problem Opus failed twice | Fable 5.2 | one agent at a time, never in parallel |
| Lookups, bookkeeping, repeatable checks | Haiku / Sonnet | sub-agents |

Changed 2026-11-16 by the owner ([follow-up](../04%20Tech/Prompts/2026-11-16%20Ability%20Rework%20Follow-up.md)) after the first day ran several Fable agents at once and hit the usage limit. Day 1 as it actually ran: parent and four agents on Fable (wind strokes, skinned body, first-person gestures, VFX mesh kit), props on Opus 5.5, fixes and notes on Sonnet / Haiku. Also new: each Mod's effect starts from a RIVALS study (numbers and recipes only), written into `03 Research/Rivals Reference/Body, Viewmodel, Guns and VFX.md` → "Ability VFX".

**Routing limit:** a true fork (a copy of the parent chat) always runs on the parent's model, so it can't be Opus 5.5. The prop chats are therefore fresh Opus 5.5 sessions that get a full written brief instead of the parent's history.

## Blender: live MCP only
- One live Blender 5.2 instance. Work file: `art-source/abilities/Rework/v03/AbilityRework_v03.blend`, **one scene per fork** (`RW_MollyFrost`, `RW_Recon`, `RW_Stim`, `RW_Recall`, `RW_VFX`).
- Shared core: `tools/blender/rework/rw_core.py` (palette, faceted primitives, planar cut, exact boolean, geometry audit, render rig, export, per-prop source write). Every MCP call loads it and names its scene first, so calls from different forks can interleave safely. No fork opens or reverts files.
- Palette: the guns' RemasterV2 roles (Body `383D48`, Panel `555C69`, Dark `1C1E23`, Grip `25272D`, Metal `62676F`, Accent `AEB4BC`) plus one identity colour per prop (Molly warm `D56A2C`, Frost cold `8CCBEB`, Recon scan `3FA9C4`, Stim yellow, Recall violet).
- Axes: Blender +X forward, +Y left, +Z up, 1 unit = 1 stud. Origin: thrown = centre, handheld = grip, placed = floor centre.
- The rejected Codex session that was open and unsaved in Blender is kept as review history: `art-source/abilities/_history/2026-11-15-codex-pass-rejected-unsaved-session.blend` (its "Prop Review" scene was linked from `Rework/v02/Gauntlet_Mod_Rework_v02.blend`, still on disk).

## Interfaces the new props must keep (from the current build)
| Prop | Kind | Names the game looks up | New moving parts and locators |
|---|---|---|---|
| Molly | thrown, origin centre | part `Pin` (hidden after the pull), attachment `Fuse` (flight embers), `Fuse_Energy`, `Handle` | `Latch` + `LatchPivot`, `Pin` + `PinOut`, `ArmPad` + `ArmPadDown` |
| Frost | thrown, origin centre | attachment `Fuse`, `Fuse_Energy`, `Handle` | `Latch` + `LatchPivot`, `Pin` + `PinOut` |
| Recon | handheld, origin grip | `Charge_Energy`, `Bounce1_Energy`, `Bounce2_Energy`, any `Dart*` part (hidden on fire), `Handle` | `LimbTop`, `LimbBottom` + pivots, string segments, `Nock`, bolt |
| ReconDart | thrown, origin at the TIP, pointing +X | model `ReconDart`, `Handle` at the tip | `Light_Energy`, `Light`, `Tail` |
| Stim | placed, origin floor centre | attachment `Top`, part suffix `_Yellow` (coil keeps its colour), `Floor` | wider base, readable coil |
| Recall | placed, origin floor centre | part suffix `_Violet` (core keeps its colour), `Top`, `Floor` | core, facing mark |

Sizes now in game (studs, Roblox X × Y × Z): Molly 0.22 × 0.56 × 0.24, Frost 0.21 × 0.56 × 0.23, Recon 0.24 × 0.85 × 1.24, ReconDart 0.20 × 0.20 × 1.00, Stim 0.68 × 1.20 × 0.68, Recall 0.72 × 1.10 × 0.63.

## Phases
1. **Baseline and shared core.** Done: connections checked, core written and tested, interface facts gathered.
2. **Molly test piece.** One Molly in Blender, close-ups, audit, export, into Studio, checked in hand. Gate: the parent's in-hand review before the style goes to the rest of the set.
3. **Rest of the props.** Frost (same session as Molly), Recon bow and bolt, Stim, Recall.
4. **VFX language.** Wind, fire, ice, healing and teleport each read through their own motion, shape and timing; glitch only as a rare accent. Mesh layers and authored textures for the big beats.
5. **Shared fixes.** Body-blocking collision groups, HEALING and DETECTED status, ability hits without floating numbers, the outline on the skinned match body.
6. **Gameplay.** Crash Down on a second Q press (carry, 8 vs 10 stud trial), Dash as a quick dodge (12 / 16 / 18 trial), Recon bounce cycling during the draw, Stim forward toss, Recall re-key (reach unchanged).
7. **Studio.** Import, rig, animate moving parts and holds, wire VFX and HUD.
8. **Verification.** Two Studio clients, captures of casts, holds, impacts and fixes, measured Dash and Crash Down trials, review note.

## Found on the way: predicted Mods did nothing on the server
Server Authority is off (`Workspace.AuthorityMode = Automatic`), so each client simulates its own Dash and Updraft and the attributes they write never reach the server or other clients. In the build as it was, for real players:
- **Crash Down dealt no damage** (the server's landing hook never saw a landing; only bots' slams hit).
- **Ghost blocked nothing** (the dodge window lived only on the dasher's client), and nobody else saw a dash, a launch, a dive or a **Desync decoy**.

Fix (2026-11-15): a report path. The owner's client reports each predicted event (`ModSim` remote: cast, dive, landing; `Controllers/ModSimController`). The server (`Services/ModSim`) pays each cast from its own charge count, does the server part from its own view of the character (slam damage and centre, Ghost window, the gun-down gate), and relays what other clients need to draw (`ModSimFx`), which they write as local attributes in their own clock, so the existing effects code runs unchanged. Reviewed by the security reviewer; its findings are fixed (a slam needs a launch the server saw rise, an armed dive that took time, a landing in reach; Ghost lowers the gun on the server; charges stay in step across a respawn). Limits: `Config/Mods SIM_REPORT`.

Checked in Studio (one client, enemy dummy 4 studs away): a real G3 slam dealt 45 and Hindered; three reports fired in one burst while standing dealt 0; with limited charges the second press spent nothing.

## Crash Down (Updraft G2 / G3)
- **Second press of the Updraft key slams** (was Crouch). The first press launches; until you land, a press of that key is always the slam and never another launch, with or without a charge left. An early press waits for the arm time (0.15 s). The prompt under the crosshair shows the Updraft key.
- Measured: launch, second press 0.13 s later → queued → dive at 0.15 s → landed 0.10 s later; a key held for 2.5 s did not slam or relaunch.
- **Carry:** the dive keeps up to 16 studs/s of horizontal speed (`slamCarry`); it moved 1.5 studs during a dive from 11 studs up. Radius still 8 (10 is the trial value), damage 30 / 45: open for the owner's playtest.

## Dash trial (L1, same lane, same inputs, duration 0.15 s)
| Distance | Travel at the end of the dash | Gun back | Travel 0.35 s after (key held) |
|---|---|---|---|
| 12 | 10.7 to 12 | +0.23 s | 17.1 |
| 16 | 13.6 to 15.6 | +0.23 s | 20.9 |
| 18 | 15.9 to 16 (two of four runs stopped by lane walls) | +0.23 s | 21.6 |

The gun comes back at the same moment for all three, so distance is free on that side; 18 mostly bought wall stops. A full slide covers about 12 studs in its first half second; a 16-stud dash with the exit speed covers about 21. **Set: L1 16, A2 22, A3 28** (Long Dash keeps its +6 steps). Needs the owner's feel check.

## Shared fixes
- **Body blocking:** collision group `Bodies` (no collision with itself, collides with `Default`) on every spawn path (`CharacterService`, `Config/Collision`). Checked in Play: all 58 body parts in the group.
- **Ability hits:** crosshair marker, no floating numbers, nothing drawn on a victim the attacker can't see (`Config/HitFx` sources, `WeaponController.onHitConfirm`). Not playtested yet.
- **HEALING / DETECTED:** the server publishes `HealingUntil` + `HealingSource` from real healing (Heal Orb's heal over time, Heal Zone ticks that add HP); the tray shows HEALING; REVEALED reads DETECTED. Not playtested yet.

## Molly test piece (phase 2): passed the in-hand gate
- Built in the live Blender session: a squat faceted fuel can, 0.32 x 0.38 x 0.40 studs, 15 parts, about 2,000 triangles, audit clean. Moving parts with pivots: `Latch` (`LatchPivot`, 0 to 70 degrees), `Pin` (`PinOut`, 0.14 travel), `ArmPad` (`ArmPadDown`, 0.016). Notes: `art-source/abilities/Rework/v03/Molly/PARTS.md`.
- Renders: [hero](../02%20Art/References/mods/rework-v03/molly-blender-hero-v1.jpg), [hand view](../02%20Art/References/mods/rework-v03/molly-blender-hand-v1.jpg). In the player's hand in Studio: [capture](../02%20Art/References/mods/rework-v03/molly-in-hand-v1.jpg).
- In hand: silhouette, orange jacket, latch, ring and fuse light read. It sits small and the fist hides the lower half, so it is being scaled up 1.2x and the hold raised. The owner has not seen it yet.
- Studio: uploaded as a new version of asset 81883123985254 and staged; `ReplicatedStorage.Abilities.Molly` is the new canister, the old one is kept at `ServerStorage.ImportStaging.Molly_Baseline`. Place not saved, `.rbxm` backup not written yet (after the owner's yes).

## Props in Studio (2026-11-16)
| Prop | Size (studs) | Tris | In the hand | Captures |
|---|---|---|---|---|
| Molly (scaled 1.2x) | 0.38 x 0.45 x 0.46 | 1,976 | Reads; the fist still hides the lower half until the hold is lifted | [in hand](../02%20Art/References/mods/rework-v03/molly-in-hand-v2.jpg), [pair render](../02%20Art/References/mods/rework-v03/molly-frost-pair-blender.jpg) |
| Frost | 0.32 x 0.31 x 0.60 | 1,832 | Tall pale cell with blue vent slots, clearly not Molly; same hold issue | [in hand](../02%20Art/References/mods/rework-v03/frost-in-hand-v1.jpg) |
| Recon bow | 1.0 x 0.21 x 1.53 | 2,314 | Loads with all 27 parts; shown edge-on and through the arm because the hold is still the launcher's. Needs its own canted hold and draw | [in hand, unposed](../02%20Art/References/mods/rework-v03/recon-bow-in-hand-v1-unposed.jpg), [render](../02%20Art/References/mods/rework-v03/recon-bow-blender-hero.jpg), [full draw](../02%20Art/References/mods/rework-v03/recon-bow-blender-full-draw.jpg) |
| Recon bolt | 1.0 long, 0.13 across | 466 | Not checked in flight yet | |

| Stim | 1.02 x 1.02 x 1.16 | 3,046 (over the ~2,600 target) | Deployed in the range: legs out, yellow coil glowing, reads at 10 studs | [placed, with Recall](../02%20Art/References/mods/rework-v03/stim-recall-placed-v1.jpg), [render](../02%20Art/References/mods/rework-v03/stim-blender-hero.jpg) |
| Recall | 0.70 x 0.78 x 1.02 | 2,140 | Planted in the range: violet core in three prongs, facing chevron | [render](../02%20Art/References/mods/rework-v03/recall-blender-hero.jpg) |

**First-person gesture pass (Opus, 2026-11-16):** holds lifted (Molly about 80% above the fist, Frost about 85%), Molly pad / pin / latch and Frost pin / latch animate on equip, throw / lob / javelin re-keyed with a windup and snap, Stim toss now 8 studs on a 2.2 arc, Recall twist re-keyed (0.6 s kept), Firewall push and guide. Worker's grades 6.5 to 8; Firewall's push not confirmed by eye. Captures `fp-*.jpg` in the same folder.

**VFX mesh kit (Opus, to the locked spec):** 19 meshes, 415 triangles, plus `T_FlameSheet.png`; uploaded as asset 139137930819171 (`ReworkVFX`), not staged in Studio yet. Sheet: `art-source/abilities/Rework/v03/Renders/VFX_kit_sheet.jpg`.

All six props are uploaded as new versions of their existing assets and installed in `ReplicatedStorage.Abilities`; the old models are kept in `ServerStorage.ImportStaging` as `<Id>_Baseline`. Place not saved, `.rbxm` backups not written. Sessions' part sheets: `art-source/abilities/Rework/v03/<Mod>/PARTS.md`.

Found while checking: the interrupted first-person gesture pass had left held items broken (it read a config table it had not written yet). Patched so items show; the pass is being finished on Opus.

## Status
- 2026-11-16: routing changed to Opus-first; RIVALS ability VFX study written ([Ability VFX Numbers](../03%20Research/Rivals%20Reference/Ability%20VFX%20Numbers.md)); effects map for the builders ([Ability Effects Map](../04%20Tech/Ability%20Effects%20Map.md)); day 1's finished code committed (`b937dd10`). Running: Stim and Recall props, the effects-language lock (one Fable agent), the gesture pass. Waiting: VFX kit and effect rewrites, the skinned-body fix, the Recon bow hold and draw, third-person clips, the two-client test.
- 2026-11-15: phases 1 and 2 done. Phase 3 running in three Opus 5.5 sessions (Recon bow and bolt, Stim, Recall) plus Frost in Molly's session. Phases 5 and 6 partly done in code (above). Also running: wind strokes for Dash and Updraft (code done, Play checks left), skinned-body outline and Desync decoy, first-person gesture pass, the shared VFX mesh kit. Owner asked (mid-run) to keep usage down: new sub-tasks go to Opus 5.5 or lighter.
- Not started: effect rewrites on the new kit (fire, ice, heal, teleport, scan, impact), Studio import of the remaining props, third-person clips, the two-client verification (needs the owner to start a 2-player test in Studio: the MCP can't).
