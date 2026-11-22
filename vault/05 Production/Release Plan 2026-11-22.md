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

## Related
- [Game Plan](Game%20Plan.md)
- [Home](../00%20Home.md)
- [Release Map Audit 2026-11-21](../01%20Design/Maps/Release%20Map%20Audit%202026-11-21.md)
