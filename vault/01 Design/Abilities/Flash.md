# Flash (free pack)

**Status: built 2026-11-17, every level checked in Play** ([playtest](../../05%20Production/Playtests/2026-11-17%20Free%20Pack%20Build.md)). Spec: [2026-11-17 New Abilities (Free Pack)](../../04%20Tech/Prompts/2026-11-17%20New%20Abilities%20(Free%20Pack).md).

Control, Projectile. **Q** (slot 1).

## How it works
A held throw. LMB throws it (75 studs/s, walls bounce it) and it **pops 0.9 s after leaving the hand**, wherever it is; RMB tosses it a step ahead and it pops after 0.3 s (round a corner). The server decides who is blinded: every live combatant within 30 studs with a clear line from the pop to their head. Where they look sets how long: **1.75 s straight on, falling to 0.6 s at 90°, held to 110°, nothing past it** (behind you). Enemies, teammates and **you** alike.

Where someone looks (`Target.lookOf`): the server's camera copy when there is one, else the body's facing tilted by the replicated `AimPitch` (Server Authority is off, so this is the client's claim: see Security).

| | L1 |
|---|---|
| Charges | 1 per round, no recharge |
| Range | 30 studs, line of sight (no walls) |
| Blind | 1.75 s → 0.6 s by angle |

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

## What a blinded player sees (`Util/FlashFx`)
Nine angled white plates close in from the edges in 0.06 s (the centre last), held while it runs, then break away outward over 0.4 s (Quint). They draw inside one CanvasGroup, whose transparency is the hold's see-through (`1 - (0.35 + 0.65 × strength)`): straight on is a full white-out, a glance shows the scene faintly. The game's sound is muffled (an EQ on the Combat master group), and a low thump plays.

## Built
- Server: `src/shared/Mods/Flash.luau` (`blindFor`, `reaches` for the wall count). ModFx `FlashThrow` (path, `land` = the fuse) and `FlashPop` (`at`, `range`, `exposure`, `hits`).
- World pop (`Util/BlastFx.flashPop`): one glow 50 → 1 studs over 0.5 s, a hard four-point sparkle, a light (RIVALS FlashbangEffect numbers, our look). Exposure: a cold sparkle (first two frames magenta) and a `ScanRing` in team colour running out to the range.
- Model: `Abilities.Flash` (Kind `thrown`): an octagonal canister (two boxes, no cylinder), chamfered caps, two team-coloured bands, a pale lens, the spoon and a square pin ring. Studio-built 2026-11-17. Hold: `ITEM_HOLDS.Flash` (Frost-style, scale 1.3).

## Sound (placeholders: `Config/ModSounds` → `Flash`)
`equip`, `throw` / `throwLob` (Molly's), `flight` (a short whine), `bounce`, `pop` ("Grenade Launcher 2" pitched up), `blinded` (a low thump, 2D), `exposure` (the sonar throb).

## Bots
`BotMods`: an enemy seen in the last 4 s but out of sight, 8-30 studs away: thrown at where they were.

## Security
The blind is decided on the server from its own line of sight. The look direction comes from the client's own body and `AimPitch` (Server Authority off, owner's decision 2026-11-11): a cheat could claim to look away. Parked with the anti-cheat (Bugs & Ideas).
