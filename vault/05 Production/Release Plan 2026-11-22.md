# Release Plan (2026-11-22)

Owner's roadmap reviewed against the vault (Home status, Game Plan, Release Map Audit). This is the plan to launch Draft Duels, with what is cut, what is added, and the order of work.

**Date check:** the Game Plan still targets Wed 25 Nov 2026 (Thanksgiving week). That is 3 days away. The roadmap below is several weeks of work. Launch date is an owner decision; see Open decisions.

## 1. Verdict on the roadmap

**Agree to defer now (out of the release):**
- Leaderboards (deferred already).
- Tasks for rewards (deferred already).
- Charms (deferred).
- Winstreak revive ($$): ship the winstreak counter only, no paid revive.
- 2v2 beginner mode: the Game Plan already says Duels-first; keep it out.
- Dynamic bot levels by device and skill: defer. Ship one fill-bot setting that works.
- Battle Pass and Shooting Range: the roadmap says disabled for release. **Check this:** the range is now a lobby feature with a teleport (RangeService) and the merged place uses it. Owner to confirm: hide it, or ship it as a free extra.
- Robux buying: already parked by the owner. Coins only at launch.

**Missing from the roadmap (add these):**
1. **Data safety gate.** Everyone's skins were wiped once already. Before launch: session locking, save on leave and on server close, retry and backoff, a test that a rejoin keeps the wallet, inventory and settings. Use the `roblox-datastore-safety` and `roblox-datastores` skills.
2. **Remote security review** of every RemoteEvent touched by shop, cases, settings, locker and abilities (CLAUDE.md rule 7).
3. **Coin income.** The Shop sells cases for coins. Check that match play earns enough coins to buy things, or new players get stuck on day one. Part of Progression.
4. **Analytics and funnels.** The roadmap puts funnels last. The owner needs them to answer "will it do well", so they go in before launch, not after. Minimum events: joined, first duel started, first round finished, opened shop, opened case, bought, left, and session length. Use the place's own data (a DataStore log or an analytics service), not a third-party tool.
5. **Credits and licences.** The body is a credited community body, and the sounds are licensed. A credits line in the game and the description is needed before public launch.
6. **Publish basics:** game icon, thumbnails, description, name change to Draft Duels everywhere (game settings, place names, title strings), age and content settings, and the server-matching path (PLAY across servers) tested with two real servers.
7. **Crash and error logging.** Log server errors to a place we can read after release (a DataStore log or a Discord webhook from the server, no secrets in the client).
8. **Controller and phone pass.** The UI Part 5 notes say "not tested with a real controller or phone yet." That is a launch gate.

**Trim from the roadmap:**
- "Full game optimization: everything you can think of" is not finishable. Replace with a bounded pass: MicroProfiler on a 10-player match, memory after 5 rounds, load time in the loading screen. Fix the top 3 costs and stop.
- "Full bot optimization" becomes: bots fill empty slots fast enough that a player never waits 30 s to see a match start (or the 30 s wait is hidden behind the loading screen).
- "Better images/packs" in the Shop: the bundle banners and charm art can wait. Launch with the art that exists.

## 2. Plan in steps

Owner lane (you): maps, building fixes, lobby textures, playtests, phone and controller tests, the Roblox page, the launch decision.
Claude lane: code systems (abilities, progression, data, analytics, loading), with Studio checks.
Codex lane (if you use it for UI): shop window and locker UI, settings wiring, loading screen art and layout. Each lane gets its own files; do not share a file across lanes at the same time. Commit only the paths you changed.

**Step 0 - Decide (today).** Owner: pick launch date, the range question, and the cut list above. Output: the Home Locked decisions table updated.

**Step 1 - Safety first (about 2-3 days).**
- Data saving checks (section 1, item 1).
- Remote security review on the touched remotes.
- Two-server PLAY test and a real teleport test.
- Gate: a player can leave, rejoin and keep everything.

**Step 2 - Core content (about 4-5 days).**
- Abilities: the collect system in the locker; abilities in the two paid bundles; fix Darts; final checks on every Mod; full in-game description text for each upgrade.
- Progression: XP and levels with simple rewards (cosmetic or coins). Winstreak counter only.
- Coin income from matches (section 1, item 3).
- Shop restructure for release: the NPC shop window (the owner's "armorer-style" plan). Daily reward: one simple version (a claim button and a streak counter).

**Step 3 - Settings honesty (about 1 day).** Wire every setting that appears in the menu. Hide any that cannot be wired yet. Do not ship a setting that does nothing.

**Step 4 - Loading and logo (about 2 days).**
- Logo and loading screen at match start and game start.
- Preload the match assets during the loading screen.
- Start the match only when every player reports loaded (or after a timeout), so no one starts half-loaded.

**Step 5 - Maps and building (owner, runs in parallel with 2-4).** Cracks, collisions, winner-area moves, RIVALS textures on lobby (only if time). Each map is checked with the existing build audits (z-fight, float, slope) before it goes in rotation.

**Step 6 - Onboarding and analytics (about 2 days).** Analytics events (section 1, item 4). A short first-run prompt: how to play, how to draft a Mod, first duel with a bot. The 2v2 beginner mode stays cut.

**Step 7 - Bounded optimization (about 2 days).** The profile pass from section 1, fix the top costs, and re-measure. Stop when the three targets are met, not when the list is empty.

**Step 8 - Gate tests (about 2 days, owner-heavy).**
- Phone and controller playthrough, full match.
- Closed playtest with 10-20 people, through the real publish path.
- Read the analytics and crash log after the playtest.

**Step 9 - Launch.** Publish with credits, icon, thumbnails and description. Soft launch first (not promoted) if the playtest shows problems. Public launch after the crash log stays clean for a day.

## 3. Rough order and gates

Steps 1-4 are the critical path. Steps 2 and 5 can run in parallel. Step 8 is where the owner decides "is this ready" from real data. No launch without Steps 1, 3 and 8 passing.

## Decided (owner, 2026-11-22)
- **Range closed for this update** and **Battle Pass out of the first update** (archived, not deleted). Code: `src/shared/Config/Release.luau` (`RANGE_OPEN`, `BATTLE_PASS_OPEN`, both false). Battle Pass build script moved to `tools/studio/archive/BuildBattlePass.luau`; the Studio Battle Pass trigger zones moved to `ServerStorage.Archive`. **Studio pass done 2026-11-22 (Lobby place v1002):** range sign now reads CLOSED, caption "OPENS IN A LATER UPDATE", hologram + projector moved to `ServerStorage.Archive.Range`, a corrugated shutter (`Hub.RangeBay.ClosedShutter` + `ShutterBand`, RIVALS `Corrugated_01a`) blocks the opening (delete it to reopen). Battle Pass builds archived: `Shop.Wing_SeasonPass.Fit` and `Hub.SeasonMounts` are in `ServerStorage.Archive.BattlePass` (each has an `ArchivedFrom` attribute); its adverts refilled: hub screens SEASON 1 → DUELS, shop gateway sign → ITEMS · CASES, shop Bay 02 → LOCKER ("EQUIP YOUR SKINS IN THE LOCKER"), the closed passage notice → STORAGE. Locker: guns were upside down because sightless guns and the sideways skin copies had no reliable up; `LobbyGunDisplays` now falls back to the muzzle height (checked on all 226 gun/line models, play capture shows every wall gun upright). Wall layout: snipers Fill 7.6, rifles 4.6 (rows y 12.6 / 10.1), shotguns 5.6 so they stay in their bay, knife 5.4 centred. Textures: the last non-RIVALS lobby surfaces moved to ExtraTextures (265 parts; `PrevVariant` attribute on each for rollback): Lobby_ConcreteBoard → ConcretePanels-02a, Lobby_ConcretePolished → Concrete-01a, Lobby_Rock → Slate02c, plain Fabric → Fabric2022. Not yet seen by the owner: the shutter close-up and the retextured rock.
- **Soft launch first.** The first publish is unpromoted while the gate tests run (Step 8). Public launch comes after the gate passes. The 25 Nov Game Plan date no longer means public launch.

## Open decisions (owner)
1. (Decided: soft launch first. See above.)
2. Shooting Range: hidden at launch, or a free extra?
3. Which two bundles get abilities, and the coin income rate?
4. Is a soft launch (unlisted or unpromoted) acceptable for the first week?

## Soft-launch handoff (2026-11-23)

This review covers the current checkout and the open Edit DataModel for Draft Duels (`71551303511506`). The live published version and Creator Dashboard settings still need owner confirmation.

### Before inviting testers

1. **Ship the current asset set.** Owner decision, 2026-11-23. The existing inventory remains in place. The earlier audit records ownership and reference history. [Asset ownership audit](Handoff%20-%20Onboarding%20and%20Bots.md#old-lobbies-and-rivals-pieces-removed-2026-11-22-owner-remove-all-rivals-assets-and-other-old-lobbies--besides-the-textures)
2. **Validate the paid Shop paths for the pilot.** Buy Bundle now opens the Roblox purchase prompt directly. Saved shared-price skin intents stay tied to the exact skin until a matching cancellation or receipt. Run live receipt and cancel/retry checks before enabling monetization for testers. If regional pricing is enabled, prices need client-fetched developer product pricing and Dynamic Price Check. Give buyers access to the actual odds before buying Starter and case-bearing coin packs, and check the displayed grant for restricted accounts. [Regional pricing](https://create.roblox.com/docs/production/monetization/regional-pricing) · [Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items)
3. **Save and publish the merged place for the pilot cohort.** Keep the release layout, Range closed and Battle Pass closed. For normal Studio tests, set `Workspace.TestMode` to false and delete `HostedTest` (the open place had an empty string and any string selects the hosted test role in Studio). Clear other one-off Studio overrides. Record the last good place version for rollback. In Creator Hub, confirm access and content rating, enter the approved icon, thumbnails, description and credits, and start with Playtesters access and zero promotion. [Publish and access settings](https://create.roblox.com/docs/production/publishing/publish-games-and-places#target-audience)

### Owner acceptance pass

- Use a fresh non-owner account and a returning non-owner account on a cold published server. Verify spawn, Beginner 2v2 onboarding, and load completion. Equip a skin, change a setting, finish a match, then rejoin to verify progress, wallet, inventory and settings.
- Queue PLAY from two public lobby servers. Complete the hosted match through map vote, draft, results, rematch or requeue, then return via To Hub. Check one local pad duel twice in a row. Include a phone and a controller and verify a non-owner can load the active meshes, audio and animations.
- Walk into and out of all four Shop bays. Rotate through both bundles and select skins and melee items. Check the lighting, reduced-motion behavior and touch drag. Verify free daily claim and case open/rejoin. If Robux is enabled, verify real receipt delivery, retry behavior and the restricted case path.
- Check Creator Dashboard Error Report and the Onboarding, Matchmaking, Match and Case opening funnels during the pilot. Confirm the new-user path through Starter progression and review queue times, Shop opens, purchases and save readiness. Roblox Analytics requires a published server. [Error Report](https://create.roblox.com/docs/production/analytics/error-report) · [Analytics event types](https://create.roblox.com/docs/production/analytics/event-types)

### Release code and Studio checks (2026-11-23)

- All twelve map previews are JPEG captures of the actual release arenas. The uploaded child image IDs loaded in Studio ImageLabels. The original exports are in `art-source/ui/mapvote/release/`, and the selector reads `Config.Match.MAPS`.
- Removed combat audio and Shop art bulk preloads from startup, and retired the blanket background download of owned skin models. Equipped and opened previews still request their assets. Equipped weapon audio warms when drawn, skin cues stage on demand with stock fallback, floor probes can complete while spawn streaming is in flight, and returning to Lobby gives animations a bounded head start. The local loading screen closed in 5.3 s for Lobby and 5.5 s for hosted Studio play. Studio recorded a transient Rubik family read warning and an asset-type warning for the public Pop Close Sound ID `203785492`. The latter was absent from repository source and from the authored place properties scanned.
- A local hosted 2v2 reached Live with Automatic authority. Settings opened and paused combat input, sprint/slide/jump moved the fighter, and a server-command relocation outside the map returned to the last accepted point. In one seven-second local server sample, Heartbeat intervals were 4.0 ms median, 7.1 ms at the 95th percentile and 14.9 ms maximum. Hosted Studio ModFx and Replay test events rendered a Frost projectile and Molly zone, then cleared both with the replay. Live cross-server tests and mobile frame times remain pilot checks.
- Biggest authored render candidates were Lobby V5 Shell (5,175 BaseParts and 60 shadowed lights), OldTown4 (6,714 BaseParts) and Rooftops4 (5,195 BaseParts). Arena spawn and barrier tag lists are cached once per loaded map. The first mobile MicroProfiler pass should cover the Shop approach, the first round on OldTown/Rooftops, and the cutscene or return to the lobby.
- Server checks now cover the arena envelope and impossible movement, round fire/Mod locks, teleport source and roster admission, queue state transitions, and economy transaction ownership. Movement corrections preserve client network ownership. All nine owner-provided fallback IDs feed the avatar candidate pool.


### Owner playtest follow-up

- The lobby can open while equipped cosmetic models are still arriving. Combat warmup starts from the match loadout and covers the first shot, hit feedback and knife whooshes and impacts. In Studio, the first body-hit played with its Sound already loaded, and the first quick slash created the loaded Riftforge Knife firing voice. Shop bundle previews show the skin portrait during a bounded warmup of the selected mesh.
- Third-person pose updates follow the local character from a persistent client host. Automatic authority uses `PreAnimation`, which avoids the simulation callback write failure in Studio. The return overlay checks the server-stamped Lobby spawn. A Pier pad duel and a Dockyard hosted match both returned to a local lobby with the unarmed idle playing on the fresh character.
- Bot perception and navigation use the active arena. Heard positions project onto valid floor, failed routes release attention and bots can fall back to a short local patrol. Pier and Dockyard play samples showed movement and heading changes. Four complete fallback looks are stored in `ServerStorage.BotAvatarBackups`. The builder lives at `tools/studio/BuildBotAvatarBackups.luau`.
- The 12 selector cards now use closer in-arena compositions, with an identifiable feature and no lobby scenery. The new group-owned images loaded in Studio. Sources are in `art-source/ui/mapvote/release-v2/`.
- Studio route lighting now fills the Shop and Duels aisle shadows with unshadowed light and softens the Locker ceiling lights. Tempest-Strike ribbons and Ruin-Blighted neon are stronger, and Ruin-Blighted's authored shards idle in the Shop stage and on nearby props.

### Release polish pass (2026-11-23)

- **Match Settings button top-left on mobile:** Fixed `StarterPlayerScripts.UI.Match.MatchSettingsTopbar.Bar` sizing (`44×44`), `SafeAreaCompatibility = None`, and `src/lobby/client/Controllers/MatchSettingsButton.luau` placement (top-left beside `GuiService.TopbarInset` on touch/phone, top-right on desktop). Verified in Studio Play on desktop (`1538×604`, `(1482, -51)`) and phone (`(220, -51)`).
- **Weapon renaming:** Updated player-facing `displayName`s in `src/shared/Config/Weapons.luau` (keeping internal `id` keys unchanged so saves/models/animations remain intact): `Ghost` → `Hush`, `Stinger` → `Hornet`, `Spectre` → `Prowler`, `Bulldog` → `Lancer`, `Vandal` → `Havoc`, `Phantom` → `Spirit`, `Outlaw` → `TwinShot`, `Operator` → `Deadeye`, `Ares` → `Barrage` (keeping `Classic`, `Shorty`, `Sheriff`, `Pump`, `Buckshot`, `Marksman`, `Scout`, `Mauler`, `Knife`). Cleaned `AdminPanelController.luau`, Studio `StarterPlayerScripts.UI`, and `tools/studio/Build*.luau` placeholders; Studio scan confirmed zero visible Valorant weapon names across `UI` and `Workspace`.
- **Mod upgrades & Draft cards:** Restored the original art-forward Draft card visuals (`src/client/Util/DraftScreen.luau`) per owner review while fixing `DraftController.statLine()` (`src/client/Controllers/DraftController.luau`) and `src/shared/Config/Mods.luau` `card` strings so every Glitch and multi-part upgrade surfaces both parts cleanly without truncation. Fixed `Title`/`Tag`/`Stat` scaling (`MinTextSize = 1`), `OR` divider centering, `LockIn.Picks` clearance vs `ENTER`, and Phone `CustomFit` scaling (`src/shared/UiLayout.luau` exemption). Verified `TextFits == true` across all 84 Mod cards at `1280×720`, `1538×604`, and `667×375` (`Gun1`..`LockIn` within `y = 68..342`).
- **Case Opening & Shop Reward FX polish:** Escalated `TIER_FX` hold/sparks/waves/rings/beams/pitch cues (`src/shared/Config/CaseOpening.luau`, `src/lobby/client/Util/CaseOpening.luau`), enabled the `Reveal` popup with tier borders and `NEW SKIN · X OF Y` kicker for both `OPEN 1` and `OPEN 3` (`BackpackController.luau`), and upgraded `ShopRewardFx.luau` (`Config/ShopFx.luau`, `Config/UiSounds.luau`, `ShopController.luau`) with rarity-scaled starburst rays, sparkles, art shine sweeps, double rings, coin count-up guarantees, and `UiMotion.reduced()` guards.
- **Cross-device UI & overlap fixes:** Hid `BottomHud` automatically during Touch controls (`src/client/Util/BottomHud.luau`), moved owner `ADMIN [F8]` toggle below `Touch.TopLeft` during touch matches (`AdminPanelController.luau`), fixed `Lobby/Settings` bottom overflow on phone (`PhoneSize`), set `ConsoleBoost = 1` on `MapVote`, `Settings`, `PlayMenu`, `PartyMenu`, `Rewards`, `Locker`, and `BattlePass`, tuned `Shop.Canvas.PhoneBoost = 1.4`, boosted `Scoreboard` (`PhoneBoost = 1.4`) and sub-12px `TopBar.Info` / `Scoreboard.Round` / `LobbyPlayerList` labels, and verified zero real clipping across 6 viewports (`667×375` to `1920×1080` Console).
- **Tooling & Studio state:** `selene src` passed (`0 errors, 0 warnings`); `rojo build default.project.json` succeeded; all edited files passed `stylua --check` (aside from untouched pre-existing dirty lines in `ShopController.luau`). `HostedTest`, `GauntletState`, and temp previews were cleaned (`TestMode = false`, `AuthorityMode = Automatic`). *Note:* Studio MCP `start_stop_play` wedged on `"Start play hasn't finished yet"` before final live Lobby F5 playback, so final live visual check of Lobby Case Opening / Shop Reward FX animations remains for the owner's F5/pilot check.

## Related
- [Game Plan](Game%20Plan.md)
- [Home](../00%20Home.md)
- [Release Map Audit 2026-11-21](../01%20Design/Maps/Release%20Map%20Audit%202026-11-21.md)
