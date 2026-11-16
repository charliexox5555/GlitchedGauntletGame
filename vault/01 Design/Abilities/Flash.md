# Flash (free pack)

**Status: built 2026-11-17, every level checked in Play** ([playtest](../../05%20Production/Playtests/2026-11-17%20Free%20Pack%20Build.md)). Spec: [2026-11-17 New Abilities (Free Pack)](../../04%20Tech/Prompts/2026-11-17%20New%20Abilities%20(Free%20Pack).md).

Control, Projectile. **Q** (slot 1).

## How it works
A held throw. LMB throws it (75 studs/s, walls bounce it) and it **pops 0.9 s after leaving the hand**, wherever it is; RMB tosses it a step ahead and it pops after 0.3 s (round a corner). **No range** (owner 2026-11-17: "there's no radius to the flash"): whoever has a clear line from the pop to their head and has it **on their screen** is flashed, like Valorant. On screen means the default 80° camera's view (±56° across, ±40° up and down from their look). Well inside it (to 80% of the way to the edge): the full flash, 1.75 s in the middle to 1.5 s. Near the edge (to 130%): a **short glance** (0.35 s, weaker) that goes away right away. Off screen or behind: nothing. Enemies, teammates and **you** alike.

Where someone looks (`Target.lookOf`): the server's camera copy when there is one, else the body's facing tilted by the replicated `AimPitch` (Server Authority is off, so this is the client's claim: see Security).

| | L1 |
|---|---|
| Charges | 1 per round, no recharge |
| Range | none: line of sight only (no walls) |
| Blind | well on screen: 1.75 s (centre) → 1.5 s; at the screen's edge: a 0.35 s glance; off screen or behind: none |

| Level | Effect |
|---|---|
| A2 More Flashes | 2 a round |
| A3 More Flashes | 3 a round |
| B2 Recharge | back 15 s after use |
| B3 Recharge | back 6 s after use |
| G2 Exposure ⚡ | no blind: every **enemy** who would have been blinded is revealed (Recon's outline for your team, DETECTED for them) 3 s; recharges in 15 s |
| G3 Exposure ⚡ | reveal 5 s, and it reaches through one wall (up to 6 studs thick) |

## Blinded (new status)
`Config/StatusEffects.blinded`: `BlindedUntil` (server time), `BlindStrength` (0..1: seconds / 1.75) and `BlindedAt` on the character, written only by `StatusService.blind` (a new flash only extends the time and the strength). Not a multiplier: the victim's screen, the status tray (BLINDED, Flash icon), and bots (`Bots/Brain`: a blinded bot doesn't engage, aim or shoot).

## What a blinded player sees (`Util/FlashFx`, v4 2026-11-17)
From the owner's Valorant screenshot and their round-4 notes ("looks a little sloppy", "where it came from shouldn't move as you move", "some pulsing, not fully"), `Config/Mods` FLASH_FEEL:
- **The whole screen covered** (a full flash is opaque; a glance only partly) in a deep cool wash (`2C4F53`).
- **A burst fixed on your screen where the flash went off**: the spot is taken once, when the blind starts, and stays put as you turn. Off screen, it sits just past that edge.
- **Clean layers** (`tools/vfx/make_flash_layers.py`, our own): wide soft beams (cool, pale, turning slowly), fine crisp streaks (warm gold, turning the other way), a soft halo and a hot core. The burst pops in a little big and settles over about 0.1 s.
- **A soft pulse**: the core breathes (±7%), the halo swells (±5%) and the beams shimmer at 2.4 beats a second. Gentle, not a strobe.
- It ramps in over 0.05 s, holds, then clears over the last 35% (at least 0.3 s): the burst shrinks away and the wash fades. The sound is muffled (60% EQ).

Earlier versions: v1 angled white plates, v2 a warm white that turned gold, v3 one ray sheet that followed the flash as you turned.

## Who you flashed (everyone else's view)
While a player (or dummy) is blinded, everyone else sees **a small burst of the gold streaks with a white core over their face** (a BillboardGui pushed toward the viewer so the head never hides it, 4.2 studs, pulsing and turning, fading out as their blind runs out), like Valorant's flashed marker.

## Built
- Server: `src/shared/Mods/Flash.luau` (`blindFor`, `reaches` for the wall count). ModFx `FlashThrow` (path, `land` = the fuse) and `FlashPop` (`at`, `range`, `exposure`, `hits`).
- World pop (`Util/BlastFx.flashPop`): one glow 50 → 1 studs over 0.5 s, a hard four-point sparkle, a light (RIVALS FlashbangEffect numbers, our look). Exposure: a cold sparkle (first two frames magenta) and a `ScanRing` in team colour running out to the range.
- Model v2 (2026-11-17, owner's interview pick "faceted flare canister"): Blender, `tools/blender/freepack/fp_flash.py`, source `art-source/abilities/FreePack/v01/Flash.blend`, asset 105163066204555, 688 tris, audit clean. An 8-facet canister with a foot step, three grip rings, a thin team light band (`Band_Energy`), a metal collar, a dark crown with four guard teeth round a stepped faceted **gold lens** (`Lens_Fire`, keeps its colour), a spoon lever hooked over the collar and a pin ring. Hold: `ITEM_HOLDS.Flash` (scale 1.3).

## Sound (`Config/ModSounds` → `Flash`, ProSoundEffects; v2 2026-11-17, waiting for the owner's ear)
- `equip`: "Grenade Pull Pin 2" (the pin as it comes up).
- `flight`: "Fireworks Fast 2" (a fuse whistle).
- **The pop, four layers:**
  - `pop`: "Synth Thunder Cracks Individual Explosion Booms 5", pitched up (the crack).
  - `popThump`: "Mortar Explosion 3", pitched up (the body).
  - `popFlash`: "Camera Flash 4", a Canon Speedlite's sharp electronic pop.
  - `popZap`: "Whoosh Explosion 1", a dry metallic zap tail.
- **Blinded, you only:**
  - `blinded`: "Mortar Explosion 5", pitched down (a low thump).
  - `blindedShimmer`: "Magic Tone Falling Shimmer Flanged 3" (a soft falling sparkle under the white-out, no ringing).
- `throw` / `throwLob` / `bounce` / `exposure`: as before.

Store rips of other games' flashbangs were skipped on purpose.

## Bots
`BotMods`: an enemy seen in the last 4 s but out of sight, 8-30 studs away: thrown at where they were.

## Security
The blind is decided on the server from its own line of sight. The look direction comes from the client's own body and `AimPitch` (Server Authority off, owner's decision 2026-11-11): a cheat could claim to look away. Parked with the anti-cheat (Bugs & Ideas).
