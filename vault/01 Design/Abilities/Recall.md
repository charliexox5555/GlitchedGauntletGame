# Recall (was Rollback)

**Status:** spec locked 2026-10-29 · **built 2026-10-29** (overnight, waiting for the user's test)
**Inspiration:** Chamber's Rendezvous (Valorant). **Place an anchor**, and when you're in range, press the key to **teleport back to it**.
**Remove from the old Rollback:** rewinding to where you were 3 s ago.
**Later upgrade idea (not now):** a bigger teleport range.

> **Look & sound:** follow the [Look & sound standard](00%20Abilities.md#look--sound-standard-every-ability-this-is-not-optional): Blender models, Blender-rendered effect textures, real hand animations, placeholder sounds in every hook.

## How it works
| Rule | Value |
|---|---|
| Place | Press the key → the gun lowers and you hold the anchor with a **placement preview** (green = valid ground, red = invalid). **LMB plants it** where you look, **within ~10 studs** on walkable ground. Press again or swap weapons to cancel (costs nothing) |
| Teleport | Once the anchor is placed, press the key while **within 40 studs** of it → a **0.6 s wind-up**, then you appear on the anchor |
| Out of range | Pressing beyond 40 studs is refused ("Out of range" cue); nothing is spent |
| Move it | Before you've teleported, **hold the key ~0.5 s near the anchor** (within ~6 studs) to pick it up and place it again |
| Uses | The **anchor stays** after you teleport to it (Chamber-style): teleport again once the **15 s cooldown** is over (changed 2026-10-29). Pick it up any time, even on cooldown (unlimited charges in test mode) |
| Destroyable | **2 bullet hits** destroy the anchor: the teleport goes on its **full cooldown** (restarts if already cooling), then you plant again |
| Range ring | **Only you** see the teleport range as a subtle dashed violet ring on the floor around your anchor (and around the hologram while you aim the plant); it turns red while you're outside it |
| Gun | **You can't shoot during the 0.6 s wind-up.** You **arrive with the gun up** and can fire right away |
| During the wind-up | You can still be shot. Dying cancels the teleport |

## Server
- The server owns the anchor (position, HP) and the teleport.
- It validates: placement within range on walkable ground; that you're within 40 studs, alive and not mid-ability when you trigger the teleport.
- It runs the 0.6 s wind-up, then moves the character, working with the movement simulation the way Dash does.
- The anchor is a hittable target for the weapon system (2 HP worth of hits).

## First person
- **Hold anchor + place with preview:** the anchor in hand, a ghost preview on the ground, LMB plants it.
- **Wind-up:** the hand snaps/twists in a gesture and the **screen warps inward** toward the centre over 0.6 s, then you pop out at the anchor.
- **Arrival:** a quick violet flash and a slight camera settle.

## Look (Blender + VFX)
- **Anchor:** a compact tactical anchor device with a **cool violet** light, made in Blender (current tactical style). It glows softly so it's findable.
- **Teleport:** a violet shimmer on the player during the wind-up, then they vanish; a violet flash where they reappear.
- **Colours:** violet keeps it distinct from the other abilities (Heal Orb green-teal, Frost ice blue, Stim yellow, fire orange).

## What enemies see and hear
- The **anchor itself** (softly glowing), so they can find and shoot it.
- The **departure shimmer** during the wind-up.
- The **arrival flash** and sound at the anchor.

## Sound (hooks + placeholder sounds)
| Hook | What |
|---|---|
| `Recall_Equip` | Anchor out |
| `Recall_Place` | Anchor planted |
| `Recall_Idle` | Soft hum from the anchor (3D, ~20 studs) |
| `Recall_PickUp` | Anchor picked back up |
| `Recall_OutOfRange` | Refusal cue |
| `Recall_WindUp` | Teleport charging (3D, ~40 studs) |
| `Recall_Depart` | Vanish (3D) |
| `Recall_Arrive` | Appear at the anchor (3D, ~50 studs) |
| `Recall_Destroyed` | Anchor shot down (3D) |

### Placeholder sounds (ProSoundEffects, unauditioned)
Real recordings, all in `Config/ModSounds.luau` → `Recall`; swap the ids there.

| Hook | Id | Recording | Use |
|---|---|---|---|
| `Recall_Equip` | 9116722779 | Metal Latches 3 | cut 0.5 s, pitch 1.1 |
| `Recall_Place` | 9116527569 | Metal Box Set Down Metal Drawer 1 | cut 0.35 s, 3D 40 studs |
| `Recall_Idle` | 9112889082 | Transformer Hum 1 (Steady, Loop) | loop 1–35 s, 3D 20 studs |
| `Recall_PickUp` | 9116320625 | Locking Wrench 1 | cut 0.3 s, 3D |
| `Recall_OutOfRange` | 9119583983 | Static Many Various Length Bursts 24 | cut 0.45 s |
| `Recall_WindUp` | 9117882661 | Power Up Accelerating Motors 3 | from 0.8 s, cut 0.6 s, pitch 1.25, 3D 40 studs |
| `Recall_Depart` | 9125975673 | Spaceship Doors Air Release Some With Suck Hiss 2 | from 0.45 s, cut 0.8 s, 3D 40 studs |
| `Recall_Arrive` | 9126229255 | Whoosh By Fast Airy Swooshing Whipping Thuds 2 | from 0.05 s, cut 0.5 s, 3D 50 studs |
| `Recall_Destroyed` | 9116279560 + 9114593205 | Lightning Flashes Quick Electrical Bursts 56 + Glass Breaks 17 | cut 0.6 s / 0.4 s, 3D 40 studs |

Alternates the search found: Equip: Metal Latches 17 (9116725218), Seat Belt Latch Unlatch 4 (9125921121). Place: Robot Servo Fast Pneumatic B 3 (9118408408), Metal Box Set Down 5 (9116527992). Idle: Transformer Hum 3 (9112889325), Light Bulb Buzz 1 (9112823811). Pick-up: Metal Box Set Down 5 from 0.95 s (9116527992), Seat Belt Latch Unlatch 6 (9125921369). Out of range: Servo Labored Bursts 4 (9118916913), Static Bursts 23 (9119583974). Wind-up: Camera Motor 6 (flash recharge, 9113677456), Power Up Accelerating Motors 1 (9117882503). Depart: Robot Servo Fast Pneumatic B 10 (9118409287), Whoosh By Fast Airy 3 (9126229927). Arrive: Pop Paper Bag 1 (9117844225), Balloon Pops 1 (9113263811). Destroyed: Lightning Flashes 52 (9116279339), Glass Breaks 11 (9114592829).

## Build notes (2026-10-29)
- **Code:** `Mods/Recall.luau` (replaces Rollback), `Services/ModRecall.luau` (the anchor, the wind-up, the teleport, the pick-up), `Config/Mods.luau` → `Recall` (`placeRange` 10, `range` 40, `windup` 0.6, `pickupRange` 6, `pickupHold` 0.5, `hp` 2 hits, 1 charge). New remote `ModRecall(slot, "Teleport" | "PickUp")`, type-checked and rate-limited in `ModService`.
- **Plant:** the key holds the anchor (the finished model, small, in your hand) with the green/red hologram; LMB plants it (`Blocks/Placeable`, same check on both sides, plus room for you to arrive: a 2.5 × 5-stud space, `roomWidth` / `roomHeight`). Planting spends nothing (`module.spends`): the charge is the teleport. One anchor at a time (the server refuses a second).
- **Teleport:** with an anchor down the key teleports. Beyond 40 studs it's refused on the client ("Out of range" + cue) and on the server. The server runs the 0.6 s wind-up (`RecallWindupUntil` on the character, no shots accepted), then spends the charge, uses up the anchor and publishes `RecallTo` / `RecallSerial`. The move runs inside the movement simulation (`Recall.step`, like Dash), so it's predicted and server-authoritative. Dying (or a new character) cancels the wind-up; a destroyed anchor during the wind-up cancels it ("Anchor destroyed"), nothing spent.
- **Move it:** next to the anchor (≤ 6 studs) a tap still teleports and holding the key 0.5 s picks it up; then plant it again.
- **Anchor:** a Mod object with `CountsHits` (each bullet hit is 1 of its 2 HP, whatever the gun; your team can't damage it). It stays until used, picked up, destroyed, or you die. **Destroyed by enemies, the teleport is lost for the round** (the charge is spent; `ModEntities` marks why an object went with `RemovedWhy`). If something now blocks the spot, the teleport is refused ("No room at the anchor") and nothing is spent.
- **During the wind-up** no other Mod (or a second Recall) can be used on either side, so the gun never ends up holstered.
- **Gun:** shots are blocked during the wind-up without lowering the gun (`WeaponController.blockFire`, server `busyUntil`), so you arrive with it up and can fire at once.
- **Model:** Blender anchor (`tools/blender/build_mod_recall.py`): claw legs, a three-fin crown, a floating violet crystal in a ring, 2,883 tris. Upload 127396665934944; `ReplicatedStorage.Abilities.Recall`, backup `art-source/abilities/Studio/Recall.rbxm`. Drawn at 1.3× (`ModProps` `PLACED_SCALE`). The `*_Violet` parts keep their violet; the status light takes the team colour.
- **Effects:** `Util/RecallFx.luau`: the anchor's violet light, spinning ground halo and hum; the violet shimmer on anyone winding up (everyone sees it); for you, streaks pulling inward over the wind-up, the view narrowing and the hand twisting (`RecallTwist` gesture, `RECALL_DIP`); a pop where you leave, a flash and ring where you land, a violet screen flash and camera kick. Blender textures from `tools/vfx/make_recall_vfx.py` (`RECALL_*`). Third person plays the Cast clip on the wind-up.
- **Rollback removed:** its module, ghost trails, VHS rewind and sounds. `WeaponService.rewindAmmo` and its ammo history stay (unused for now).
- **Verified (playtest):** planting (no charge spent), teleport from 25 studs (server and client roots on the anchor, charge spent), pick-up by holding the key, out-of-range press refused with the anchor kept, a broken anchor spends the charge, another Mod's key during the wind-up refused, a shot fired straight after arriving. Not tested in Studio: actually shooting the anchor twice (the hit counting is code-checked only).


## Changes from the user's feedback (2026-10-29)
- **Reusable with a cooldown:** `Config/Mods` Recall L1 `cooldown` 0 → **15**. `ModRecall` no longer removes the anchor after a teleport; the teleport spends the charge and the cooldown starts. A broken anchor spends the charge (or restarts the cooldown if it's already cooling; no more spending below 0). Client: a pick-up works on cooldown, a teleport press on cooldown is refused ("Not ready").
- **Range ring:** `Util/RecallRing` (72 dashes, each on the floor found under it, so it follows stairs and drops; parts are `CanQuery = false`), driven by `ModController` for your own anchor or the hologram; rebuilt at most every 0.12 s while the hologram moves.
- **Verified (playtest):** ring around the anchor and the hologram, teleport onto it with the anchor kept, cooldown 15 s, a tap on cooldown refused, a hold picks it up on cooldown (ring gone).

## Mobile (provisional)
Tap to hold the anchor and **Fire** to place it. After that, tapping the Recall button teleports, and long-pressing near the anchor picks it up.

## Counter-play
Find and shoot the anchor (2 hits: it costs them the full cooldown). Shoot the player during the 0.6 s shimmer. Pre-aim the anchor, since you know where they'll appear.
