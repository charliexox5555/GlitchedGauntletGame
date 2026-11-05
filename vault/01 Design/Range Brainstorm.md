# Range Brainstorm

**Status:** brainstorm only (2026-11-04, lane A). Nothing here is built or decided. The user picks a direction later; until then the existing real range (`Workspace.Lobby.Greybox.RangeFar` + `Art.RangeFar`, x −122…122, z 1010…1298, arrival point `RangeArrivalPoint` at (0, 0.5, 1278)) stays as it is and keeps working.

Reference point: the RIVALS range is a **larger enclosed white-box room with dummies** you step into from the lobby. Players open it before queueing to warm up and to try guns. What makes it work: one bright room, everything visible at once, no walking between "stations", instant access to every gun.

## What every option needs (whatever the look)
- **Instant gun swap** (weapon picker UI or racks you touch) and every Mod/ability usable.
- **Distance you can read:** floor grid (4-stud cells, a heavier line every 16) plus big distance numbers at 25 / 50 / 100 / 150 studs.
- **Dummy types:** static, strafing, crouch-peek, shooting back (low damage), armoured / high HP for TTK tests, a "Mod dummy" group to throw, burn, hinder, reveal and heal.
- **Feedback board:** last hit damage, headshot %, time-to-kill, DPS, reset button.
- **Movement:** a slide lane, jump boxes, a ledge or two, so the movement feel is practised too.
- **Exit:** one obvious EXIT portal back to the lobby, plus queueing from inside (the Play button).
- **First person** inside, like a match. Reuse `TestRangeService`, `RangeBuilder`, the dummies and the weapon picker.

## Options

### A. White-box training hall (closest to RIVALS)
One enclosed hall about **200 × 140 × 40**, light grey surfaces with a soft grid texture, bright neutral light, a few coloured accents for stations.
- Layout: firing lanes along the long axis (targets at 25–150), a dummy plaza on one side, a movement strip along the other wall, a Mod test pit in a corner.
- Good: fastest to build, best readability, honest for aim practice (no visual noise), cheap on phones.
- Risk: can feel sterile; needs signage and colour accents so it isn't a blank box.

### B. Bunker test cells
The range as part of the bunker: a corridor with **4 cells** (Lanes, Dummies, Mods, Movement) behind glass, doors between them.
- Good: strong theme continuity with the lobby; each cell can have its own lighting mood.
- Risk: walking between cells; you can't see everything at once; more geometry and doors to maintain.

### C. Cavern range
A huge natural cavern under the bunker, with daylight through a crack in the roof, built ramps and platforms in the rock, long sightlines for snipers.
- Good: memorable, beautiful screenshots, real long-range practice.
- Risk: rock and cave lighting make targets harder to read; most expensive to model; heavier on phones.

### D. Hybrid: white-box core in a bunker shell (suggested starting point)
Option A's bright grid hall for everything that needs to read cleanly (lanes, dummies, movement), wrapped in bunker architecture at the edges (concrete frame, a viewing gallery, the same signs and trims as the lobby), with subtle glitch accents (dummies "materialise" with a pixel effect, the reset button glitches the room for a moment).
- Good: practice stays readable, the place still feels like part of the same game.
- Risk: needs discipline so the shell's detail doesn't creep into the play space.

## Open questions for the user
1. Which option (A–D)? Or the RIVALS look as-is (A)?
2. Size: one hall everyone shares (30 players per server), or a private instance per party?
3. Should dummies shoot back by default, or only in a "challenge" lane?
4. A score / challenge mode (for example "hit 20 targets fast") with a small leaderboard, or pure practice?
5. Keep the in-place teleport (no loading screen), or walk in through a long corridor?
