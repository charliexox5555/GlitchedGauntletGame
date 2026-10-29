# Lobby

**Status:** design locked 2026-10-29 · not built
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
- **Lobby place** = the experience's start place, **30 players per server**.
- **Match place** = one reserved (private) server per match. The current game place becomes the Match place.
- **After a match:** results screen → everyone teleports back to the lobby → a **"Queue again"** button; parties stay together.

## Look and feel
- **Theme:** a **modern tactical training facility**: concrete, brushed steel, big glass walls, clean LED signage. A classic gun game, no sci-fi.
- **Setting:** mixed. A bright **indoor central hall** that opens through glass doors onto an **outdoor courtyard**.
- **Lighting:** **bright late afternoon**, with warm sun pouring through the glass. Inviting, readable on phones, and good for thumbnails.
- **Camera:** **third person** in the hub, with an optional **shift-lock** toggle. The Range wing switches to **first person**, so practice feels like a match.

## Layout: central queue hall
```
              [ outdoor courtyard: benches, planters, slide ramps, open space ]
                              ║ glass doors ║
   ┌──────────────────────────────────────────────────────────┐
   │  SHOP          ┌─── LEADERBOARDS (main wall) ───┐   LOCKER   │
   │  (counter,     │                                │  (loadout, │
   │   displays)    │   [1v1]    [2v2]    [3v3]     │   skins,   │
   │                │      queue pads + counts       │   preview) │
   │                └────────────────────────────────┘            │
   │                         SPAWN                              │
   │                 ══ RANGE WING GATE (back) ══                │
   └──────────────────────────────────────────────────────────┘
```
Rough sizes (greybox to tune): hall ~120 × 90 studs with a ~40-stud ceiling; courtyard ~150 × 100 studs.

| Area | First version |
|---|---|
| **Spawn** | Facing the pads and the leaderboard wall, so new players see "play here" immediately |
| **Queue pads** | **1v1, 2v2, 3v3** pads in the centre, with big signs and **live "X queued" counts**. Stand on a pad to join (party members on the same pad queue together). 4v4 and Gauntlet get added later |
| **Play button** | A menu button that queues from **anywhere**, including inside the Range wing |
| **Shop** | Counter + display stands. First version: browse cosmetics, placeholder items (the economy comes later) |
| **Locker** | Set your loadout and skins, with a **3D preview of your character and guns** |
| **Leaderboards** | Big screens on the main wall: wins, levels (ranked ladder later) |
| **Courtyard** | Open space to hang out and slide around: benches, planters, a few ramps |
| **Range wing gate** | The door to the Range wing at the back of the hall |

## Hub rules
- **Full movement:** sprint, **slide** and jump, like in matches. **No abilities** in the hub.
- **No guns and no PvP in the hub.** Guns and abilities only work inside the Range wing.
- **Social (first version):**
  - **party invites + party UI**, using Roblox's party features plus an in-game invite
  - an **emote wheel** (cosmetic emotes come later in the shop)

## Range wing
A **walled zone inside the lobby place** (not a separate place): walk through the gate or press **"Range"** to enter. No loading screen, friends can join you, and you **can still queue from inside**.
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
1. **Places + Rojo:** create the Lobby place in the experience (set it as the start place) and split Rojo into lobby and match projects.
2. **Greybox:** block out the hall, courtyard and Range wing with simple parts. Walk and slide test it, tune the sizes.
3. **Hub systems:** third-person camera + shift-lock, hub movement (no guns/abilities), queue pads + Play button + counts, teleport to and from the Match place, party invites, emotes.
4. **Range wing:** move the test range in, with first person, all guns and abilities, and the zone rules.
5. **Art pass in Blender:** a modular kit (walls, floors, glass, trims, signage, pads, shop counter, lockers, benches, planters) in the tactical facility style, with Blender preview renders first, then assembled in Studio. Late-afternoon lighting.
6. **Shop/locker/leaderboard UIs** (placeholder data until the economy and stats exist).

## Build prompt
```text
Build the Lobby described in vault/01 Design/Lobby.md. Read CLAUDE.md, that note, vault/04 Tech/Architecture.md and the Art Direction first, and inspect the current project (default.project.json, src/, the TestRange code, movement) before changing anything.
Follow the note's "Build plan" one step at a time. After each step STOP, tell me exactly what to do and test in Studio (I may need to create the Lobby place and set it as the start place myself; tell me the exact clicks), and wait for my OK.
Step 5 (art) follows the same quality bar as the abilities: a Blender modular kit in the tactical facility style, Blender preview renders shown to me BEFORE importing, then Studio screenshots.
After each approved step: run stylua and selene, update the Lobby note if anything changed, update vault/00 Home.md Status and vault/04 Tech/Architecture.md, and commit and push.
```
