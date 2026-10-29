# Abilities: base redesign (one by one)

We're redesigning the **base (L1) version** of each of the 9 Mods, one at a time, Valorant-style. The specs pile up here and then **get built together in one Claude Code session**. Paths and glitches come later.

> These specs **override** the L1 sections in [Mods](../Mods.md) where they differ.
> **Theme (2026-10-28):** the digital/glitch theme is **shelved for now**. This is a classic gun game; names and looks are plain and readable. It may come back later.

> **All 9 base specs are locked (2026-10-29).** Next: paste the build prompt below into Claude Code.

## Status
| # | Ability | Was | Spec | Built |
|---|---|---|---|---|
| 1 | [Dash](Dash.md) | Blink | ✅ locked 2026-10-28 | ✅ 2026-10-29 |
| 2 | [Updraft](Updraft.md) | Launch Pad | ✅ locked 2026-10-28 | ✅ 2026-10-29 |
| 3 | [Molly](Molly.md) | Packet | ✅ locked 2026-10-28 | ✅ 2026-10-29 |
| 4 | [Firewall](Firewall.md) | Firewall (cover wall) | ✅ locked 2026-10-29 | ✅ 2026-10-29 |
| 5 | [Frost](Frost.md) | Lag Field | ✅ locked 2026-10-29 | ✅ 2026-10-29 |
| 6 | [Recon](Recon.md) | Ping | ✅ locked 2026-10-29 | ✅ 2026-10-29 |
| 7 | [Heal Orb](Heal%20Orb.md) | Patch Up | ✅ locked 2026-10-29 | ✅ 2026-10-29 |
| 8 | [Stim](Stim.md) | Overclock | ✅ locked 2026-10-29 | ⬜ |
| 9 | [Recall](Recall.md) | Rollback | ✅ locked 2026-10-29 | ⬜ |

## Rules for every base ability
- **Charges, not one cooldown rule for all.** Each ability sets its own: a number of **charges per round** (refilled at round start, no recharge) and/or a **cooldown**, like Valorant (Jett's dash vs Sova's dart). It's decided per ability below.
- **Test mode:** there's no round system yet, so the dev panel has a **"Test mode: unlimited charges"** toggle (on by default in Studio). RoundService will later call a "refill charges" function at round start.
- **Keys:** PC **Q / E / T** · gamepad LB / RB / D-pad up · mobile buttons. Instant abilities fire on press (mobile-friendly).
- **Mobile is provisional:** each spec has a basic mobile layout so it works; a full mobile controls/HUD pass comes later.
- **Status effects:** shared, server-enforced effects with an expiry time, reusable by any ability. **Hinder** (debuff, see [Frost](Frost.md)) and **Stimmed** (team buff, see [Stim](Stim.md)); they multiply when combined.
- **Friendly fire (2026-10-29):** damage from your own abilities to **you and your teammates is 50%** of the enemy damage (one config value). Exceptions are set per ability; e.g. you're immune to your own Firewall.
- **Readable for enemies:** clear look and a 3D sound others can hear.
- **Sound:** every ability gets named sound **hooks** in `Config/ModSounds` (separate slots, own volume and pitch, one ID to swap), each filled with a good placeholder (see the Look & sound standard). The user does the final sound design.
- Server-authoritative; movement abilities run in the movement simulation like the current Blink.

## Look & sound standard (every ability: this is not optional)
The current abilities were rejected mostly for **looking and sounding cheap** (plain Roblox parts, no real animation, weak sounds). Every ability must look and sound **professional, like a Valorant ability**.

**Blender is the main tool for visuals**:
- **Models:** every object (canister, launcher, beacon, anchor, orb core…) is **modelled in Blender** in the current tactical art style (matte, PBR, baked textures), never assembled from plain Roblox Parts. Use and extend `tools/blender/modkit.py`, `export_mods.py` and `render_mods.py`, then follow the import/upload pipeline in [Art Direction](../../02%20Art/Art%20Direction.md).
- **Effect textures:** fire, smoke, frost mist, electric arcs, light swirls, scan rings and shockwaves are **rendered in Blender as flipbook sprite sheets**: Mantaflow fire/smoke sims, or shader-based renders for energy and light effects. Procedural tools (`tools/vfx/make_mod_vfx.py`, `make_real_vfx.py`) are fine where they look as good or better.
- **Effect meshes:** shockwave rings, domes, trails, the fire-wall curtain profile and beam/ribbon shapes are made in Blender, with UVs laid out for scrolling textures.
- **In Roblox:** combine those textures and meshes with ParticleEmitters (flipbooks), Beams, Trails and lights, so effects are **layered** (core + glow + particles + light + distortion/haze), not a single flat effect.
- **Show your work:** before importing, **render a preview of every model and effect** (stills or a short contact sheet from Blender) and show them to the user. After importing, take Studio screenshots (first and third person).
- **Look up references:** for each ability, look up how the matching Valorant ability looks and sounds (videos and breakdowns) and match that **quality**, not the exact design. Also check Roblox VFX best practice (flipbooks, LightEmission, pooling).

**Animations:** real first-person hand/arm animation for every ability (equip, hold idle, use, recover) on the viewmodel rig, plus third-person poses others can see. No "gun just disappears" moments.

**Sound** (the user does the final sound design, but it must never be silent or cheap while testing):
- Every ability gets **all the named hooks** in its spec, in `Config/ModSounds`.
- Fill each hook with the **best placeholder you can find**: search Roblox's licensed Creator Store audio (give the user the search terms and IDs) and/or generate with `tools/audio/mod_sfx.py`. **Layer** sounds where it helps (e.g. whoosh + crackle).
- Set sensible 3D ranges (the spec gives them) and volumes.
- List every placeholder used in the ability note so the user knows what to replace.

**Performance:** pool every effect, keep particle counts sane, test with 8 players.

## Bench (ideas for later powers or upgrades)
- **Barrier:** a placeable cover wall you can hide behind (the old Firewall idea).
- **Recall range upgrade:** a bigger teleport range (a later level).

## Build prompt (paste into Claude Code when the specs are ready)
```text
Build the abilities whose spec is "locked" and built "⬜" in vault/01 Design/Abilities/00 Abilities.md. Read CLAUDE.md, that overview (especially "Look & sound standard") and each ability's note first; the notes override vault/01 Design/Mods.md for L1. Inspect the current Mod code (src/shared/Mods, Config/Mods.luau, ModService, ModController, ModFeelController, ModFxController, ViewmodelController, ModSounds) and the art/VFX/audio tools (tools/blender: modkit, export_mods, render_mods; tools/vfx; tools/audio; tools/opencloud) and build on them.

First, before any ability: add the per-ability charge system (charges per round and/or cooldown, as data in Config/Mods.luau), the "Test mode: unlimited charges" dev toggle, a refill function for the future RoundService, and the shared status effects (Hinder, Stimmed).

Then do ONE ability at a time, in the order of the table, in three passes, and STOP after each pass and tell me exactly what to test in Studio:
  1) GAMEPLAY: mechanics, server validation, charges (placeholder visuals OK).
  2) LOOK: models made in Blender, effects built from Blender-rendered flipbook textures and Blender meshes (layered particles, beams, trails, lights), first-person hand/arm animations and third-person poses. Show me Blender preview renders BEFORE importing, then Studio screenshots after. Look up the matching Valorant ability's visuals as a quality reference.
  3) SOUND: every hook in the spec, filled with the best placeholder sounds you can find (Roblox licensed audio and/or tools/audio/mod_sfx.py, layered where it helps), with 3D ranges; list the placeholders in the ability note.
After my OK on all three: run stylua and selene, tick "Built" in the overview, update the ability note if any number changed, update vault/00 Home.md Status and the Asset Tracker, and commit and push.
```
