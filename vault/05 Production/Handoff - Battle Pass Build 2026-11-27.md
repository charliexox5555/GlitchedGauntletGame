# Handoff: the rest of the battle pass build (2026-11-27)

Briefs for whichever AI builds the rest of Season 1's pass. Each section stands on its own: give the builder that section plus the shared rules below. What's built and why is in [Battle Pass Build Plan](../04%20Tech/Battle%20Pass%20Build%20Plan.md) (phases and progress), [Battle Pass Season 1 Contents](../01%20Design/Battle%20Pass%20Season%201%20Contents.md) (what's in it, owner decisions) and [UI Battle Pass](../02%20Art/UI%20Battle%20Pass.md) (the screen). The earlier [Handoff - Battle Pass 2026-11-27](Handoff%20-%20Battle%20Pass%202026-11-27.md) covers the game around it (owned guns, power deck, gun levels).

## Where it stands
| Part | State |
|---|---|
| 1 Data, tier maths, payouts | Done |
| 2 Progress from matches | Done |
| 3 Robux: Premium 689 (`3736724862`), +5 Levels 499 (`3736724879`) | Done |
| 4 The pass screen on the real save | Done, except the phone layout (F) |
| 5 Titles | Done: data, equip, profile card, lobby player list. Name tags (A) and the match scoreboard / end screen (B) are briefs here. |
| Random-gun skins, raised coins | Done (2026-11-27) |
| 6 Charms | Brief C |
| 7 Powers (Smoke, Electric Shock) | Brief D |
| Goodie bags | Brief E (needs owner answers first) |
| 8 Art | Brief G |
| 9 Season end and launch | Brief H |

## Rules for every brief (paste with each one)
- **Read first:**
  - `CLAUDE.md` / `AGENTS.md`.
  - Load the `gauntlet-vault` skill, and check LihFolk for anything non-trivial in Roblox.
  - Anything players see starts from the [Style Bible](../02%20Art/Style%20Bible.md): `gauntlet-ui-style` for UI; `gauntlet-build-style` and `gauntlet-model-joins` for models.
- **Code:**
  - `--!strict`; tabs and StyLua.
  - Server-authoritative: the client sends intent only.
  - Every remote type-checks, rejects NaN/inf, is rate-limited (`Lobby/Config.RATE`) and is reviewed with `lihfolk:roblox-secure-remotes`.
  - Numbers live in config.
  - Save changes only through `PlayerDataService.transact` with a txId. Its writer copies a **fixed list of fields**: a new save field must be added there, or it's silently dropped (this bit phase 1).
- **Studio:**
  - Test in Play on the Server datamodel. MCP scripts get their **own copy** of modules, so drive the game through remotes, `ServerStorage.RobuxTestReceipt`, or the DataStore (`PlayerDataV2_Studio`, key `u_<userId>`; read with `DataStoreGetOptions.UseCache = false`).
  - Back up the test save before changing it and restore it after.
  - Set Workspace `BattlePassTest = true` to see the pass in Studio, and remove it afterwards.
  - Remind the owner to **save the place** after Studio edits.
  - Mouse input uses real viewport pixels, while screenshots are scaled; prefer `instance_path` clicks.
- **Git:** small commits on `main`, exact paths only (never `git add -A` / `git add vault`), no push unless the owner says.
- **Vault:** Build Plan progress, Home Status, Code Map lines for new services, controllers and remotes, INDEX for new notes.

---

## A. Name tags above heads in the lobby
**Goal (owner 2026-11-27):** RIVALS-style tags above every player in the lobby showing **level**, **equipped title**, and **win streak** when they have one.
- **Data, all already published on every player:**
  - `StateValues` `Level`, `WinStreak` and `Title` (the title text; `""` = none).
  - Read the title with `Shared/PlayerData.title(player)` (upper case, nil when none).
- **Build:**
  - A client controller in `src/lobby/client/Controllers` that adds a BillboardGui to each character in the lobby (PlayZone `Lobby`) and updates on `StateValues.anyChanged`.
  - Hide it in the Range and in matches, and never on your own character in first person.
  - Pool or clean up on CharacterRemoving and PlayerRemoving.
  - Make the template in Studio (owner rule: UI is real Studio objects), e.g. `ServerStorage.LobbyUI` or the UI templates folder.
- **Look:**
  - Study the RIVALS reference first (`rivals-reference` skill; read-only, study don't copy).
  - Rubik Heavy/Bold, soft plates with one cut corner, no outlines or glow (`gauntlet-ui-style`).
  - The title in gold `#FFC83D`; the streak in the bar's streak orange `#FF7026`.
  - Readable at 30 studs, MaxDistance about 80, `AlwaysOnTop` off.
- **Done when:**
  - Tags show for 2+ players in Studio (Local Server test), update live on a title change, and hide in the Range.
  - No connection leaks across 5 respawns.
  - The owner OKs a screenshot.

## B. Titles on the match scoreboard and end screen
**Goal:** the equipped title shows next to names in matches.
- **Data:**
  - Match servers run `PlayerDataService` too, so `StateValues` `Title` is on every player in a match; use `PlayerData.title(player)`.
  - Bots have no title.
- **Files:**
  - `src/client/Controllers/ScoreboardController.luau`
  - `src/client/Controllers/MatchEndController.luau`
  - Their Studio templates in `StarterPlayerScripts.UI.Match`.
- **Build:** a small gold line under the name, or after it, in the same style as the lobby player list (`Util/LobbyHudView`: `TITLE · IN LOBBY` in gold). Don't make rows taller if the scoreboard is tight; truncate long titles.
- **Done when:**
  - A bot match in Studio (`ServerRole = Match`, `BotMatch = 1v1`; set both back after) shows your title on both screens, and bots show none.
  - Phone size 844x390 has no overlap (Device Emulator: the owner checks).

## C. Charms (build plan phase 6)
**Goal:** a charm hangs from the gun and swings.
- **Data that exists:**
  - `data.charms = { owned, on }`, granted by pass claims (`SeasonRewards.grant`, kind `Charm`, by name such as `JOYSTICK`).
  - Every gun has a `CharmPoint` attachment.
- **Build:**
  - **Equip:** `LockerRequest ("charm", name or "")`, like the title equip in `Services/LockerService` (one charm on all guns, owner can change).
  - **Publish:** `on` as a `Charm` StateValue (copy how `Title` is published in `PlayerData.publish`).
  - **Locker slot:** a charm slot in the Locker.
  - **Runtime:**
    - Hang the charm model from `CharmPoint` on the viewmodel and the third-person gun, with a spring swing from movement, turning and recoil.
    - Epic charms get a small effect.
    - High Score shows this match's kills from a server-set attribute.
    - Pool the models and clean up on unequip.
  - **Models:** the 8 charm models are art (brief G). Until then use a simple stand-in clearly named `Placeholder` (owner rule: no placeholder bricks in shipped art, so it must be replaced before launch).
- **Done when:** all 8 charms swing in first and third person in Studio, equip saves across a rejoin, and there are no leaked connections.

## D. Powers: Smoke and Electric Shock (build plan phase 7)
**Goal:** the two pass powers, locked to the pass.
- **Facts:**
  - `Config/Season.POWER_UNLOCKS`: Smoke = free tier 10, ElectricShock = premium tier 20.
  - Claiming grants them as owned and equipped Mods (`data.mods`), and `Shared/ModLoadout.eligible` already accepts owned and equipped.
  - The SURGE pack already skips both.
  - **Neither id exists in `Config/Mods` yet:** add them with `free = false`.
- **Specs (owner 2026-11-26, in the Contents note → Powers):**
  - **Smoke:** a dome about 12 studs across, about 10 s; it blocks sight, aim assist and auto-shoot through it.
  - **Electric Shock:** a lock-on orb that latches onto an enemy within about 4 studs, a 0.5 s warning ring, then a strike for about 70 damage plus a short Hinder. Slight pay-to-win is accepted by the owner.
- **Build:** use the ability build prompt in [00 Abilities](../01%20Design/Abilities/00%20Abilities.md), with its gameplay, look and sound passes, the existing Mods as patterns, and `Upgrade Paths.md` for their A/B upgrades. Server-side damage and hit checks.
- **Done when:** a player who hasn't claimed them never sees them in a draft; both pass the three passes in a bot match; and the owner OKs the feel.

## E. Goodie bags
**Owner 2026-11-27:** add goodie bags to Season 1. Like RIVALS' bags that open into wrap boxes, finisher packs and charm capsules. **Needs owner answers before building:**
1. **What a bag holds.** Proposal: 1 roll from a table, e.g. 55% coins (300-800), 25% a Standard Case, 15% a random charm not owned (from a pool of extra charms), 5% a random-gun Arcade skin.
2. **How many and where.** Proposal: 3 bags, replacing premium 2 Tickets (tier 14), free Standard Case (tier 18) and premium Elite Case (tier 19).
3. **Opened straight away on claim, or kept in the Backpack** to open later like cases. Proposal: kept in the Backpack (`data.items`, a new `Inventory.ITEMS` entry), opened with the case-opening flow.
4. **Odds shown?** A bag from the pass isn't bought directly, but premium is paid. Show the odds anyway, as cases do (`Util/OddsList`).

**Build after the answers:**
- An `Inventory.ITEMS` entry (`BagSeason1`), a roll table in config, and a `Bag` reward kind in `SeasonCatalog` / `SeasonRewards.grant`.
- The open action in `ShopService` (`openCase` is the pattern: roll, grant and use the item in one write).
- The Backpack shows it, with odds.

**Done when:** claim → Backpack → open pays one roll, a double-open pays once, and the odds panel shows.

## F. Pass screen: phone layout, CLAIM ALL, the Shop card
- **Phone:** the pass canvas (`ServerStorage.LobbyUI.BattlePass`) uses the shared Fit scale, which is about 0.36x on a 390 px-tall phone. Add `PhoneBoost` and Phone* attributes per `Shared/UiLayout` (the Shop does this) so the cells and text read on 667x375 and 844x390. The owner checks in the Device Emulator.
- **CLAIM ALL:** the server action exists (`SeasonRequest ("claimAll")`). Add a button that shows when 2+ rewards are claimable, in `BattlePassController` and the Studio screen.
- **Shop card:** in the launch Shop layout the Season Pass card sits half off the right edge. It needs a slot on the Home page (`ShopController`, `Release.SHOP_FULL_LAYOUT` and the Studio `LaunchOnly` / `FullOnly` attributes).
- **Done when:** all three are visible in Studio, and the owner OKs the phone screenshot.

## G. Art (build plan phase 8)
- **First, an owner question.** On 2026-11-27 the owner said "I'm not gonna make new skins for things". Ask whether Arcade (Rare) and Frostbite (Legendary) are still made, or whether pass skins reuse existing lines. Pass skins are now random-gun, so a line needs a model for **every gun in `Config/Loadout`** (10 primaries + 4 secondaries), or `SeasonRewards.rollGun` must only roll guns that have the line's model (`Shared/Locker.valid(gun, line)`). Pick one before launch: today it rolls any active gun.
- **8 charm models.**
- Blender pipeline: `gauntlet-build-style`, `gauntlet-model-joins`, the Style Bible, and the owner's weapon art bar (self-grade 9+). Neither line goes into cases.
- **Done when:** the owner OKs the renders, then sees them in Studio.

## H. Season end and launch (build plan phase 9)
- **Season end:** at `Season.endsAt()`, unclaimed rewards already reached are paid on the next join or save (`SeasonRewards.claimAll` inside one write), then the season locks. Changing `Season.ID` wipes progress, so pay first.
- **Admin tools, Studio only:** set tier, give premium, reset season (the AdminService pattern, with an allowlist).
- **Launch:**
  - Set `Season.STARTS_AT` (UTC).
  - Set `Release.BATTLE_PASS_OPEN = true`.
  - The Shop card (F).
  - A playtest note in `05 Production/Playtests/`.
  - Check that every reward kind has its art (G) and that the two powers are built (D).
- **Done when:** a forced season end in Studio pays leftovers exactly once.

## Owner answers still needed
1. Goodie bags: contents, count and placement, kept or opened at once (E).
2. Arcade and Frostbite: still made, or reuse existing skins (G)?
3. Charms: one charm on all guns, or one per gun (C)?
