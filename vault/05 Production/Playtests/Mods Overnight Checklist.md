# Mods overnight checklist

What to test in Studio for the Mod system, stage by stage. Built by the code session overnight 2026-10-26; how it works is in [Mod System](../../04%20Tech/Mod%20System.md), the design in [Mods](../../01%20Design/Mods.md).

**Before you start:** `rojo serve`, click **Connect** in the Rojo plugin, then **Play** (solo). The place needs **no save** for the Mods (everything is code). Stop and Play again after Rojo syncs a change: a running playtest doesn't reload scripts.

## Stage 1: framework + Blink, Packet, Patch Up

You start with **Q Blink · E Packet · T Patch Up** (Studio and test-mode servers only).

### HUD
- [ ] 3 slots bottom-centre with key chips **Q / E / T**, a glyph (placeholder icon) and the name under each.
- [ ] Use a Mod: a dark wedge with a pale cyan fill sweeps round clockwise, with the seconds in the middle (decimals under 1 s).
- [ ] When it's ready again the slot pulses and a cyan ring grows out of it.
- [ ] Pressing a Mod that isn't ready: red border shake and "Not ready" above the slots.
- [ ] With a gamepad, the key chips change to **LB / RB / D-Pad Up**.

### Blink (Q)
- [ ] Standing still: a quick dash forward (about 11 studs), with an FOV kick. Moving: it dashes the way you move (strafe left = dash left).
- [ ] Facing a wall up close: no dash and no cooldown spent. Dashing toward a wall stops short of it.
- [ ] 7 s cooldown. It works while holding Packet or Patch Up (the held Mod is put away).
- [ ] No rubber-banding after the dash (it runs in the Server Authority simulation).

### Packet (E)
- [ ] Press E: the gun drops, a grenade comes up in the right hand, a dotted cyan arc and a blast ring show where it lands. Hint: "LMB Throw · RMB Lob · E Cancel".
- [ ] LMB throws far, RMB lobs short. The grenade bounces once, blinks faster, and explodes after 1.2 s with a flash, a ring and some shake.
- [ ] F8 → **Spawn enemy**: a grenade at its feet does 50 at the centre down to 20 at 8 studs. A wall between the blast and the dummy blocks the damage.
- [ ] **Spawn teammate**: Packet never hurts it, and never hurts you.
- [ ] E again (or 1/2/3, or Q/T) cancels without a cooldown. While holding, LMB never fires the gun.
- [ ] 14 s cooldown starts on the throw, not on the press.

### Patch Up (T)
- [ ] Press T at full health, then RMB: "Full health" and nothing is spent.
- [ ] F8 → **Hurt me (-50)**, then T and RMB: +40 over 2 s, the gun comes back right away and you can shoot while it heals.
- [ ] F8 → **Spawn teammate**, shoot it a few times (guns still hurt teammates for now), hold T and look at it: cyan outline on it, hint "LMB Heal ally". LMB: beam + "+40", it heals over 2 s.
- [ ] Look away from the teammate and LMB: "No ally in your crosshair", nothing spent. Behind a wall: also refused.
- [ ] **Clear dummies** (no teammates): the hint says "LMB Heal self" and LMB heals you (1v1 rule).

### Dev panel (F8)
- [ ] F8 opens it (mouse free, gun lowered); F8 closes it.
- [ ] Pick a slot, then a Mod: the slot changes at once. Unbuilt Mods are greyed out (Stage 2 fills them in).
- [ ] Levels: **A2** on Blink gives 2 charges (2 pips under the slot). Levels above L1 only change numbers until Phase 2.
- [ ] Reset cooldowns, No cooldown (spam Q/E/T), Quick-cast (E throws at once, T heals yourself at once).
- [ ] Spawn enemy (orange-red outline) / Spawn teammate (cyan outline), Clear dummies. Dummies respawn 3 s after dying. Hurt me takes 50 HP (never kills).

### Phone / gamepad (not run by the code session: the Studio MCP can't emulate them)
- [ ] Device emulator (phone): 3 round Mod buttons in an arc above-left of FIRE. Tap one to hold, FIRE uses it, the context button (LOB / HEAL SELF) appears next to FIRE, tap the Mod again to cancel.
- [ ] Gamepad: LB / RB / D-pad up for the Mods, RT use, LT alternate; the weapon picker moved to **D-pad left**.

### Known for now
- Placeholder grenade and heal device (built in code), no Mod sounds yet, no third-person view of a held Mod for other players.
- Guns ignore teams until rounds/teams exist (you can shoot the teammate dummy).
- A 2-player test (Test → Clients and Servers, 2 players) puts the players on teams 1 and 2.

### Nothing to save
Stage 1 adds no Studio-owned content: nothing to save in the place.

## Stage 2: Launch Pad, Firewall, Lag Field, Ping, Overclock, Rollback

All 9 Mods are now built at L1. Use **F8** to put any of them in any slot (the start loadout is still Blink / Packet / Patch Up). **No cooldown** makes testing much faster.

### Launch Pad (held place)
- [ ] Press its key: the gun drops, a puck comes up, and a **green** box shows where the pad goes (red, with the reason on LMB, when it can't: no ground, no room, can't see there). Hint: "LMB Place".
- [ ] LMB places a flat pad in your team colour. Walk onto it: you're thrown about 25 studs up and 30 forward, in a straight, predictable arc. It lasts 15 s; placing a second one removes the first (1 at a time at L1).
- [ ] Look straight down and place it under your feet: instant launch.
- [ ] No rubber-banding during the launch (it runs in the Server Authority simulation).

### Firewall (held place)
- [ ] An 8x6 hologram across your aim, up to 8 studs out; red if it would overlap someone (it never traps people).
- [ ] LMB deploys a see-through team-coloured wall for 6 s. F8 → Spawn enemy behind it and shoot: the shots stop on the wall, the enemy takes nothing.
- [ ] A Packet thrown at the wall bounces off it and its blast doesn't go through.
- [ ] Your own shots don't damage your own wall (only enemies' shots and Packets do: 150 HP). Needs a 2-player test to see an enemy break it.

### Lag Field (held throw)
- [ ] Hold: arc preview and a 10-stud ring where the orb lands. LMB throw / RMB lob.
- [ ] The orb opens a cyan dome for 4 s (orange-red for the enemy). F8 → Spawn enemy and throw it at the dummy: **SLOWED** over the dummy while it's inside.
- [ ] Your own field never slows you. In a 2-player test the enemy moves 40% slower inside and sees "SLOWED" above their slots.

### Ping (instant)
- [ ] Press: a pulse sphere grows from you; enemies within 30 studs get an orange-red outline **through walls** for 2 s (only your team sees it). F8 → Spawn enemy, stand behind cover, Ping.
- [ ] A thin bar above the slot drains while the effect runs.

### Overclock (instant)
- [ ] Press: a cyan glow round the screen edge for 5 s, and your gun fires 25% faster (hold LMB on the Vandal). No shots are refused (Studio: the player attribute `FireReject` stays empty).
- [ ] In a 2-player test the other player sees your gun glow.

### Rollback (instant, predicted)
- [ ] Shoot a few rounds, move or Blink away, then press it within 3 s: you snap back to where you were 3 s ago (facing where you face now), with the ammo you had then, plus a short grey "VHS" wash and an FOV pull.
- [ ] While it's ready, a dotted ghost trail shows your last 3 s of path (others see yours too: the counter-play).
- [ ] 22 s cooldown. No rubber-banding.

### All Mods
- [ ] Dying or respawning removes your pads, walls and zones.
- [ ] Every held Mod: same key cancels, nothing is spent; LMB never fires the gun while holding.

### Known for now
- Placeholder pads, walls, orbs and pucks (built in code), no Mod sounds yet.
- Blink's charge refills when you respawn (its charges live on the character).
- Guns still ignore teams; you can't damage your own Mod objects.

### Nothing to save
Stage 2 adds no Studio-owned content either: nothing to save in the place.

## Stage 3: icons, finished models, stylized VFX

> **⚠ Save the place first (File → Save, or Ctrl+S).** The finished Mod models now live in the Studio-owned **`ReplicatedStorage.Abilities`** (Firewall, LagField, LaunchPad, ModVFX, Packet, PatchUp), built overnight but **not saved**. If Studio closes without saving they're gone: restore each with right-click `ReplicatedStorage.Abilities` → Insert from File → `art-source/abilities/Studio/<Id>.rbxm`. Without them the game falls back to the code placeholders (nothing breaks).

### Icons
- [ ] The 9 approved icons show in the HUD slots (white glyphs) and dim while cooling down. On a phone, the Mod buttons show them too.

### Finished models
- [ ] **Patch Up:** the heal device in your right hand while held (the Blender model, cyan energy).
- [ ] **Packet / Lag Field:** the real grenade and orb in your hand and in flight; the Packet's fuse light blinks faster before the blast; the Lag Field orb hovers and spins in the middle of its zone.
- [ ] **Launch Pad:** the hex pad with three chevrons chasing toward the launch direction (they point the way you'll fly).
- [ ] **Firewall:** the framed energy panel (see-through), cyan for you, orange-red for enemies; it flashes white when an enemy shoots it.
- [ ] Held puck for Launch Pad / Firewall is still a code placeholder (their finished models are the deployed objects).

### Stylized VFX (Util/ModVfx, textures from `tools/vfx/make_mod_vfx.py`)
- [ ] **Packet:** a dashed, turning danger ring where it will land; the blast is a hot core, a shockwave ring racing out along the ground, a glow and sparks.
- [ ] **Lag Field:** a dome (Blender mesh) over a hex floor, a turning dashed rim, an opening ring + sparks.
- [ ] **Ping:** a scan band and a scan wave sweeping out across the ground.
- [ ] **Patch Up:** team-coloured crosses rising off the healed player, a ring at their feet, the beam from the healer.
- [ ] Placing a pad / wall pops a ring and sparks; breaking or expiry bursts.
- [ ] Everything is cyan for you and your team, orange-red for enemies (check in a 2-player test).
- [ ] No frame drops with several effects at once (everything is pooled).

### Known for now
- No Mod sounds yet (the audio shortlist is waiting for approval).
- The Firewall panel is quite bright at its standard Transparency 0.5; tune in Blender/the builder if it hides too much.
- Viewmodel throw / place / heal animations are still a simple push (Stage 4).
