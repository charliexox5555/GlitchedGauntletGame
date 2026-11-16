# Flash (free pack)

**Status: built 2026-11-17, every level checked in Play** ([playtest](../../05%20Production/Playtests/2026-11-17%20Free%20Pack%20Build.md)). Spec: [2026-11-17 New Abilities (Free Pack)](../../04%20Tech/Prompts/2026-11-17%20New%20Abilities%20(Free%20Pack).md).

Control, Projectile. **Q** (slot 1).

## How it works
A held throw. LMB throws it (75 studs/s, walls bounce it) and it **pops 0.9 s after leaving the hand**, wherever it is; RMB tosses it a step ahead and it pops after 0.3 s (round a corner). The server decides who is blinded: every live combatant within 30 studs with a clear line from the pop to their head. **The rule (owner 2026-11-17): if the pop is on your screen, you are flashed**: the default 80° camera's view, ±56° across and ±40° up and down from your look, 1.75 s in the middle down to 1.25 s at the screen's edge. Off screen but within 100° of your look: a 0.35 s glance. Behind you: nothing. Enemies, teammates and **you** alike.

Where someone looks (`Target.lookOf`): the server's camera copy when there is one, else the body's facing tilted by the replicated `AimPitch` (Server Authority is off, so this is the client's claim: see Security).

| | L1 |
|---|---|
| Charges | 1 per round, no recharge |
| Range | 30 studs, line of sight (no walls) |
| Blind | on screen: 1.75 s (centre) → 1.25 s (edge); off screen within 100°: 0.35 s; behind: none |

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

## What a blinded player sees (`Util/FlashFx`, v2 2026-11-17)
Valorant's recipe in our colours (`Config/Mods` FLASH_FEEL; research summary in the playtest note): a 0.05 s ramp to a **warm near-white** (`FFF8EA`, never pure white), held, then the last 40% (at least 0.35 s) clears from the edges inward while a glow pinned to **where it popped** (projected every frame, so it stays on the flash as you turn) shrinks into that spot and the colour turns **gold** (`FFC24D`, owner's pick). A glance is a short, weaker version. Sound muffled (60% of the full EQ) and a low thump; no ringing (Valorant has none). The v1 angled white plates were replaced (owner: "not just white out... kind of like a colour").

## Built
- Server: `src/shared/Mods/Flash.luau` (`blindFor`, `reaches` for the wall count). ModFx `FlashThrow` (path, `land` = the fuse) and `FlashPop` (`at`, `range`, `exposure`, `hits`).
- World pop (`Util/BlastFx.flashPop`): one glow 50 → 1 studs over 0.5 s, a hard four-point sparkle, a light (RIVALS FlashbangEffect numbers, our look). Exposure: a cold sparkle (first two frames magenta) and a `ScanRing` in team colour running out to the range.
- Model v2 (2026-11-17, owner's interview pick "faceted flare canister"): Blender, `tools/blender/freepack/fp_flash.py`, source `art-source/abilities/FreePack/v01/Flash.blend`, asset 105163066204555, 688 tris, audit clean. An 8-facet canister with a foot step, three grip rings, a thin team light band (`Band_Energy`), a metal collar, a dark crown with four guard teeth round a stepped faceted **gold lens** (`Lens_Fire`, keeps its colour), a spoon lever hooked over the collar and a pin ring. Hold: `ITEM_HOLDS.Flash` (scale 1.3).

## Sound (`Config/ModSounds` → `Flash`, ProSoundEffects, picked 2026-11-17, not yet heard by the owner)
`equip` "Grenade Pull Pin 2" (the pin as it comes up) · `flight` "Fireworks Fast 2" (a fuse whistle) · `pop` "Synth Thunder Cracks Individual Explosion Booms 5" pitched up (the crack) + `popThump` "Mortar Explosion 3" pitched up (the body) · `blinded` "Mortar Explosion 5" pitched down (2D thump) · `throw` / `throwLob` / `bounce` / `exposure` as before. Store rips of other games' flashbangs were skipped on purpose.

## Bots
`BotMods`: an enemy seen in the last 4 s but out of sight, 8-30 studs away: thrown at where they were.

## Security
The blind is decided on the server from its own line of sight. The look direction comes from the client's own body and `AimPitch` (Server Authority off, owner's decision 2026-11-11): a cheat could claim to look away. Parked with the anti-cheat (Bugs & Ideas).
