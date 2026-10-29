# Lobby

**Status:** design locked 2026-10-29 · **phase 1 (build and art only) next**

> **Locked 2026-10-29:** the Lobby is a **new place named "Lobby" in the same experience**, and Claude works in both places. **Phase 1 is building and art only:** geometry, Blender kit, lighting and decorative scripts. **No game-structure code until the user approves the build** (phase 2). Prompt: [Lobby Build Prompt](../04%20Tech/Prompts/Lobby%20Build%20Prompt.md). Art plan and dimensioned layout: [Lobby Art Plan](../02%20Art/Lobby%20Art%20Plan.md) (approved 2026-10-29; greybox next).
**What it is:** the pre-game hub. Players spawn here in **third person**, hang out, slide around, queue (alone or with a party), shop, set their loadout, and practise in a separate **Range wing**. Matches happen in a different place.

---

## Places and flow
```
            ┌──────────── Experience ────────────┐
 Join  ──►  │  LOBBY place (start place, 30/server) │
            │   hub · queue pads · shop · locker   │
            │   Range wing (guns + abilities)      │
            └──────────────┬───────────────────────┘
                 match found │ TeleportAsync (reserved server)
                             ▼
            ┌──────────────────────────────────────┐
            │  MATCH place (private server per match)│
            └──────────────┬───────────────────────┘
                 match over  │ results → teleport back
                             ▼
                        LOBBY ("Queue again", party kept)
```
- **Lobby place** = a new place named **"Lobby"** in the same experience, which becomes the start place, **30 players per server**.
- **Start place swap (later, phase 2):** Roblox can't switch the start place directly. The official way is to back up the current game place (publish it as a new "Match" place), then open the Lobby and **File → Publish to Roblox As… → overwrite the start place**.
- **Match place** = one reserved (private) server per match. The current game place becomes the Match place.
- **After a match:** results screen → everyone teleports back to the lobby → a **"Queue again"** button; parties stay together.

## Look and feel
> **Changed 2026-10-29 (user):** a circular hub in an underground bunker replaced the rectangular glass hall with an outdoor courtyard. Dimensions and the full plan: [Lobby Art Plan](../02%20Art/Lobby%20Art%20Plan.md).
- **Theme:** a **modern tactical training facility built underground into rock** (a bunker): clean concrete, brushed and black steel, glass, warm oak, clean LED signage, with raw rock showing around the outer ring. Clean, never rundown. A classic gun game, no sci-fi.
- **Setting:** fully enclosed, **no courtyard**. A big round **skylight over the spawn rotunda** drops a sunbeam onto the spawn.
- **Lighting:** moody overall but bright where it matters (spawn, signs, pads). Each wing has its own light mood: **Duels dark and cold, like a horror-game lobby**; Market warm; Weapons neutral museum light; the Range bright daylight.
- **Camera:** **third person** in the hub, with an optional **shift-lock** toggle. The Range wing switches to **first person**, so practice feels like a match.

## Layout: circular hub with four wings
```
                     ┌──────── DUELS ────────┐
                     │ dark hall, queue pads │
                     │ + queue terminals     │
                     └───────────┬───────────┘
           ╭──────────── outer ring (slide loop, seats) ────────────╮
 MARKET ───┤          ( spawn rotunda + skylight + leaderboards )   ├─── WEAPONS + LOCKER
           ╰────────────────────────┬───────────────────────────────╯
                                RANGE wing
                      ramp down → viewing glass → gates → range
```
Rough sizes (greybox to tune): rotunda 88 across, ring 24 wide, hub about 250 across, Range shell 244 × 242 one level down. Full zone table: [Lobby Art Plan](../02%20Art/Lobby%20Art%20Plan.md).

| Area | First version |
|---|---|
| **Spawn rotunda** | Round hall under the skylight; you spawn on a dais in the sunbeam, **facing the Duels wing** |
| **Leaderboards** | Big screens around the rotunda (wins, rating, streaks, eliminations), visible from spawn |
| **Outer ring** | Wide concourse around the rotunda with a rock wall: the hang-out and **slide loop**, with seating alcoves cut into the rock |
| **Duels wing** | Straight ahead from spawn. A dark, dramatic hall with **queue pads** for **1v1, 2v2, 3v3** (stand on a pad to queue; party members on the same pad queue together), big signs with **live "X queued" counts**, plus **queue terminals** that open the queue menu. Bays for 4v4 and Gauntlet are built but closed until those modes ship |
| **Play button** | A menu button that queues from **anywhere**, including inside the Range |
| **Market wing** | Shops, the battle pass wall and featured items. First version: placeholder items (the economy comes later) |
| **Weapons wing** | Guns shown at a **big scale** on turntables and a giant hero gun (buying comes with the economy), plus the **Locker**: loadout and skins with a **3D preview of your character and guns** |
| **Range wing** | Behind spawn: a ramp **down** to a viewing gallery whose glass looks onto the range, then you walk through the gate into the range |

## Hub rules
- **Full movement:** sprint, **slide** and jump, like in matches. **No abilities** in the hub.
- **No guns and no PvP in the hub.** Guns and abilities only work inside the Range wing.
- **Social (first version):**
  - **party invites + party UI**, using Roblox's party features plus an in-game invite
  - an **emote wheel** (cosmetic emotes come later in the shop)

## Range wing
A **walled zone inside the lobby place** (not a separate place), one level down: walk down the Range wing past the viewing glass and through the ENTER gate, or press **"Range"**. No loading screen, friends can join you, and you **can still queue from inside**.
- **All access:** every gun and **every ability** usable for practice.
- **First person** inside, so it feels like a match.
- **One shooting range:**
  - firing lanes (targets at different distances)
  - dummies (static, moving, shooting back)
  - a **movement course**
  - an **ability test area** with dummies to throw, burn, hinder, reveal and heal
- **Reuse the existing test range code** (`TestRangeService`, `RangeBuilder`, the dummies, the weapon picker) here instead of rebuilding it.
- Leaving the wing (gate or button) puts you back in the hub in third person with your gun put away.

## Tech notes
- **Two places, one codebase:** a Rojo project file per place (e.g. `lobby.project.json` and `match.project.json`), both sharing `src/shared` (movement, config, weapons, abilities). The current `default.project.json` becomes the Match project.
- **Matchmaking v1:** pads and the Play button put players into in-server queues per mode; when a match fills, the server reserves a Match server (`ReserveServerAsync`) and sends everyone with `TeleportAsync` (the deprecated teleport calls are not allowed). Cross-server matchmaking (MemoryStore) comes later, when there's more than one full lobby (see the [Design Research Report](../03%20Research/Design%20Research%20Report.md)).
- **Teleport data** only carries a match ID. The Match server reads the real match details from the server side and never trusts teleport data.
- Third-person slide and run animations are needed for the hub (other players see them in matches too).
- 30 players: keep the hub performant (StreamingEnabled, instanced props, few dynamic lights).

## Build plan
**Phase 1: build and art only (no game code):** create the "Lobby" place, then steps 2 and 5 below, plus lighting and decorative ambience. See the [Lobby Build Prompt](../04%20Tech/Prompts/Lobby%20Build%20Prompt.md).
**Phase 2: code (after the build is approved):** steps 1, 3, 4 and 6.

1. **Places + Rojo:** swap the start place (see above) and split Rojo into lobby and match projects.
2. **Greybox:** block out the rotunda, ring, four wings and the Range shell with simple parts. Walk and slide test it, tune the sizes.
3. **Hub systems:** third-person camera + shift-lock, hub movement (no guns/abilities), queue pads + Play button + counts, teleport to and from the Match place, party invites, emotes.
4. **Range wing:** move the test range in, with first person, all guns and abilities, and the zone rules.
5. **Art pass in Blender:** a modular kit (rotunda and ring segments, rock, portals, floors, trims, signage, pads, terminals, shop kiosks, gun turntables, lockers, seating) in the tactical bunker style, with Blender preview renders first, then assembled in Studio. Skylight sunbeam and per-wing lighting.
6. **Shop/locker/leaderboard UIs** (placeholder data until the economy and stats exist).

## Build prompt
```text
Build the Lobby described in vault/01 Design/Lobby.md. Read CLAUDE.md, that note, vault/04 Tech/Architecture.md and the Art Direction first, and inspect the current project (default.project.json, src/, the TestRange code, movement) before changing anything.
Follow the note's "Build plan" one step at a time. After each step STOP, tell me exactly what to do and test in Studio (I may need to create the Lobby place and set it as the start place myself; tell me the exact clicks), and wait for my OK.
Step 5 (art) follows the same quality bar as the abilities: a Blender modular kit in the tactical facility style, Blender preview renders shown to me BEFORE importing, then Studio screenshots.
After each approved step: run stylua and selene, update the Lobby note if anything changed, update vault/00 Home.md Status and vault/04 Tech/Architecture.md, and commit and push.
```
