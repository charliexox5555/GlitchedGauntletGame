# Release Roadmap

**2026-11-18 · Full release plan from the owner's playtest list**

Everything below is planned for launch. Work down the numbered phases. Art and design can start while code dependencies are being built. The ranked list at the bottom is for deadline pressure. A feature is done when it works in the player-facing build and passes its checks. Use the [Game Plan](Game%20Plan.md) for earlier design notes.

**First three work sessions**

1. Run the solo match through results with normal voting enabled. Capture the exact attribute error, the place version and the round where it appears. Reproduce with a second real player if the issue shows up outside the solo bot path.
2. Fix the result or round-state failure and verify that Rematch, Play Again and Leave still work. Run the same test at least once with a longer match that fills the round history.
3. Lock the Classic, ammo and overtime rules. Write down what a complete match awards and what data should be available when the player reaches Lobby again.

## 1. Establish the release baseline and make the decisions that unblock work

- [ ] **Record the starting build.** Identify the Lobby V4 and Match edit, saved and published versions. Track which local changes and staged Studio assets belong in the candidate. Keep Lobby and Match separate for release. Treat “initiate merge” as final integration of the tested code and Studio content. [Developer Handoff](../04%20Tech/Developer%20Handoff.md)
- [ ] **Lock the round rules.** Write a one-page sequence for queue → vote → draft → combat → sudden death → round end → results. Decide round timing, retries, ties, forfeits and what happens when a player joins late. My interpretation of the Classic note is a drafted sidearm in the opening phase and Classic as the fallback in primary-weapon rounds. Confirm it before changing the existing rule where the drafted sidearm stays equipped. Decide when reserve ammo refills and what you get on spawn, reload and takeover.
- [ ] **Define the map target.** Write down what each number in `8-4-4-3` represents, then assign existing candidates to those categories. The vault currently records eight regular and five large candidates. Determine which gaps call for a new map and which can use a shared theme kit with a different footprint. [Recorded map roster](../01%20Design/Maps/00%20Maps.md)
- [ ] **Lock the launch devices.** Use keyboard/mouse, touch and gamepad as the working list. Write down the phones and controller hardware you'll use to verify them, along with a performance target for the lowest-end supported device.
- [ ] **Start the brand and product briefs.** Shortlist game names, review the Roblox listing and visual direction, then choose the name, logo direction, palette, type and icon style. Outline case tiers, pass skin line, charms, emotes, bundle contents and which catalog slots need new Mods. Do an asset-rights review before spending time on final production. [Style Bible](../02%20Art/Style%20Bible.md)

**Done when** the remaining work has a target build, an agreed match flow, a map roster draft, a device list and a content brief.

## 2. Repair rounds, Duels and multiplayer reliability

- [ ] **Fix the solo round and results bug.** Determine whether the round-end banner, match-end screen or server transition fails. The checkout already splits map-vote options and round history into shorter entries. Check the exact error against that fix and the published version. Also exercise the character and player attribute payload through long matches, upgrades and rematches. Record the reproduction and the successful retest. [Known bugs](Bugs%20%26%20Ideas.md) · [Earlier attribute issue](Playtests/2026-11-15%20Match%20Damage%20and%20Reset.md)
- [ ] **Redesign the round flow where needed.** Use the existing match state, draft and result services as the starting point. Walk through every transition, including an all-lock-in start, timeout, tie, reconnect or late join, bot replacement, final kill and reset. Make the result and post-match choices appear reliably even if replay fails. Confirm ammo, Mods, health, team scores and lingering effects reset at the right boundary. [Match Flow](../01%20Design/Match%20Flow.md)
- [ ] **Change Duels and add checks.** Verify pads, menu queueing, parties, cancellation, retry on failed teleport, and taking over a bot seat. Prevent duplicate queue joins and validate roster, mode and return intent on the server. Test all three modes, partial parties, players leaving during countdown or combat, rematch agreement and requeue. Keep step-off cancellation for searches started on Duels pads. [Lobby UI and Queue](../01%20Design/Lobby%20UI%20and%20Queue.md)
- [ ] **Fix movement lag and full-match performance.** Profile local movement, remote players and bots separately. Compare client frame time, server frame time and network behavior in 1v1 and a busy 3v3 on desktop and the target phone. Keep Automatic authority and client-owned player movement. Address the biggest costs in replication, animation, bots and effects first, then repeat the capture with the same scenario.
- [ ] **Finish spectate and replay.** Check entering spectate, switching targets, aiming, shooting, animations and skins from a real player's POV and a bot's. Record a final-kill replay with multiple clients and verify camera motion, hit feedback, UI timing and handoff to results. Keep a skip path to results for unavailable or failed replays. [Spectate Replay Fix Plan](Spectate%20Replay%20Fix%20Plan.md)
- [ ] **Finish bots.** Build on the current names, appearances and tactics. Improve human-like movement, aim pacing, cover use and dynamic reactions without making bot identities indistinguishable from real accounts. Test navigation and overtime on every eligible map, plus leaver fill and late takeover. Tune behavior in solo and full 3v3, and keep bots off player leaderboards. [Bots](../01%20Design/Bots.md)
- [ ] **Fix the server location display.** Check the shared lookup and its fallback in both places. Compare the label in published test servers with known region evidence. Use a neutral label when the lookup is unavailable or the reported location is unreliable.

**Done when** solo and party players can complete every enabled mode and use the correct post-match choices, with no blocking state errors and a measured performance baseline.

## 3. Build the data, item and reward foundation

- [ ] **Define a shared saved profile.** Include XP and level, actual match stats, Coins, owned item IDs, equipped skins/charms/emotes, Mod unlocks, settings, Tasks, login claims and Season Pass progress. Decide which stats count for human matches and bot-fill matches. Migrate verified `LockerV1` equips. Give Lobby and Match a clear handoff so an older server cannot overwrite a newer session.
- [ ] **Finish match-to-profile rewards.** Record the completed outcome once, with an ID shared across reward retries. Show the match recap and actual stat/XP changes in Lobby. Test repeated completion, rematch, server shutdown, load failure, rejoin and teleport. Check that existing saved equipment comes through.
- [ ] **Define the launch catalog and transactions.** Give every skin, charm, emote, Mod, case, pass reward and bundle a stable ID, acquisition rules, icon and optional 3D preview. Build shared server grant and spend paths for Tasks, purchases, cases and claims. Validate ownership and eligibility. Keep spending and granting consistent through concurrent requests and reconnects.
- [ ] **Add Inventory and finish Locker.** Put Inventory on the bottom bar and show owned items, with useful category filters and a route to equip. Improve the Locker background and the size, default zoom and detail of gun tiles and previews. Add Mod Collection cards for owned and available Mods, upgrade descriptions and the chosen unlock path. Show equipped and locked states for skins, charms and emotes. Check that items equipped in Lobby are visible in Match.
- [ ] **Replace the old rewards entry with Tasks.** Add starter and repeatable objectives tied to real play. Show progress, completion and claim state. Verify one representative path from completing a match to claiming and equipping a cosmetic. Define reset times and when Tasks grant Coins, XP or items.
- [ ] **Add analytics while wiring each system.** Track first join → queue → Match arrival → draft → first round → results → requeue. Use separate purchase and progression funnels where appropriate. Track ammo, maps, guns, Mods and match outcomes as focused custom events, with Coins earned/spent as economy events. Verify the dashboards in published testing. [Roblox funnel events](https://create.roblox.com/docs/production/analytics/funnel-events) · [Event types](https://create.roblox.com/docs/production/analytics/event-types)

**Done when** a match updates real stats, a Task grants an item once, the item can be equipped, and the profile is correct after teleporting and rejoining.

## 4. Finish maps, gunplay and Mods

- [ ] **Approve the built maps and fill the remaining roster.** Confirm the 13 documented candidates in saved Match Studio, then compare their IDs with the older entries in `Config/Match`. Finalize the `8-4-4-3` roster, add the missing maps and keep the shared themes stylized and less realistic. For each map, check fair spawns, sightlines, collision, bot routes, overtime, thumbnails, streaming and mode eligibility. Run normal voting with `ForceMap` cleared. [Map roster](../01%20Design/Maps/00%20Maps.md) · [Map build checks](../01%20Design/Maps/Overnight%20Run%202026-11-16.md)
- [ ] **Implement the ammo and Classic decisions.** Add finite reserves, update the HUD and confirm the server applies the same rules the client displays. Test empty magazines, partial reloads, weapon switches, phase changes and bot takeovers. Verify the Classic appears in the intended rounds.
- [ ] **Improve 3D animations and weapon fit.** Fix the slide animation and ADS alignment when the camera rolls. Check first- and third-person transitions into and out of slide, ADS and reload. Fix the sniper sight cap clipping or reflecting in ADS and the Giltfold Vandal magazine fit. Verify the repaired assets through the actual equip, reload and scoped camera paths.
- [ ] **Improve damage and zone feedback.** Reproduce the oversized damage indicator and check both the direction arc and the hit number. Set sizes and timings that work at real play distances and on phones. Make the shrinking zone easy to read, test its pace and damage, and confirm the visible boundary matches the server outcome.
- [ ] **Finish the current abilities.** Fix Recon and Shock Dart bow poses, release timing and the orb/detection zone. Prototype Frost and Molly conforming to ground around ramps, steps and ledges. Compare the visible area against the server's actual effect. Update ability descriptions to state exactly what changes on each upgrade and reuse them in the draft and collection. [Free pack playtest](Playtests/2026-11-17%20Free%20Pack%20Build.md)
- [ ] **Build the new Mods planned for launch.** Give each a role, draft slot, upgrade tree, model, icon, audio, VFX and initial tuning. Test the free roster and paid-unlock proposals together. Use guaranteed unlocks for Mods if they are sold. Compare the actual advantage conferred by exclusive Mods before signing off on bundles. [Mod System](../04%20Tech/Mod%20System.md)
- [ ] **Do the final balance pass.** Test the full launch roster of guns, Mods, ammo and maps once the rules and effects are stable. Review picks, win rates and weak/strong matchups by mode alongside human feedback. Check overtime, bot play and mixed inputs separately. Recheck affected matchups after tuning.

**Done when** every map can be voted into, completed and won, every launch Mod is understandable and works at its upgrade tiers, and guns feel consistent across the supported inputs.

## 5. Finish Lobby V4, onboarding, settings and devices

- [ ] **Finish the Lobby redesign and textures.** Review spawn, wayfinding, Duels, Locker, Shop and the Range entrance at player height. Improve lighting, surfaces, textures, silhouettes and signs using the existing V4 direction. Use the existing TV surfaces and fixtures for phase 8. Check collision, sightlines and frame time along the common routes. [Lobby V4 Build](../02%20Art/Lobby%20V4%20Build.md) · [V4 Theme](../02%20Art/Lobby%20V4%20Theme.md)
- [ ] **Fix Shop step interactions.** Walking onto the Shop or Pass pad opens it. Walking off leaves it open until explicit dismissal or an intentional screen transition. Check entering, backing out, reopening, switching menus, and being queued or teleported with a modal open.
- [ ] **Build and code the Range.** Open the V4 entrance, build or adapt practice lanes and wire entry/exit. Provide targets, a way to try weapons and Mods, and room to test sliding and ADS. Verify players can return cleanly to the hub and that practice activity leaves match stats and rewards accurate.
- [ ] **Build onboarding and the first player experience.** Show how to aim, fire, reload, slide and use a Mod. Then teach Play and the first draft with short prompts. Give experienced players a skip and allow reopening useful guidance. Test from clean profiles and track where first-time players stop.
- [ ] **Finish Settings.** Inventory the current controls and fill the gaps for input, audio, graphics or effects, reduced motion and crosshair selection. Add a live crosshair preview, polish settings animations, and verify the same preferences apply after moving between places or rejoining.
- [ ] **Finish the loading experience.** Verify the Lobby loading screen hands off to the Match receiver. Preload voting assets, first-draft models, core guns and Mod effects/audio needed for the first fight. Stream the rest as needed. On slow connections, verify readiness, timeout behavior and recovery.
- [ ] **Finish device compatibility.** Check touch layouts and tap targets, safe areas, controller focus and button prompts across Play, draft, combat, settings, results, Locker, Inventory, Shop, cases and pass. Verify physical phone and gamepad play from join to return, plus input switching where supported.
- [ ] **Polish shared UI sound, icons and motion.** Use a small consistent set of select, confirm, cancel, error and reward cues. Improve transitions where they communicate selection or progress. Cover Settings, Shop, Locker, Inventory, Tasks and results, including reduced-motion behavior. Finish the professional in-game icons in the chosen brand style. [Lobby UI overhaul](../02%20Art/UI%20Lobby%20Overhaul.md) · [Style Bible](../02%20Art/Style%20Bible.md)

**Done when** a first-time player can learn the basics, change preferences, queue, draft and finish a match on every enabled device.

## 6. Build the Shop, cases, bundles and item catalog

- [ ] **Finish Shop layout, motion and purchase states.** Use the existing Home, Bundles, Daily and Coins screens. Show real prices, owned states, contents, previews, shortages, purchase progress and clear fulfillment feedback. Verify the Shop remains usable during fast tab switching, pad exit and on every launch input. [Shop design](../02%20Art/UI%20Shop.md)
- [ ] **Wire purchases and improve Coin packs.** Keep the one Coins currency. Decide pack sizes, prices and bonus value. Add offers beyond Coins, such as clearly listed bundles or guaranteed cosmetic extras. Validate product IDs and receipt fulfillment through the platform's server receipt handling. Test cancel, claim retry, rejoin and duplicate delivery before enabling sales. [Roblox player data and purchasing](https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing)
- [ ] **Produce and install launch cosmetics.** Reserve skins for the three tiers, Daily rotation, two bundles and Season Pass. Make charms for packs and pass rewards, check mounts in previews and first person, and make a starter set of emotes with Locker slots and equip behavior. Give all items icons, names, rarity, thumbnails or previews, and real acquisition rules.
- [ ] **Build one complete case, then scale to three skin tiers.** Model the case family and author reveal/open animations, sounds, a skip and a result screen. Build the server-side open-and-grant path first, then add the remaining tiers and earnable charm packs. Sell elite and animated skins through the premium path you choose, with guaranteed bundle purchases as my recommendation. Verify grant recovery if a player leaves mid-animation.
- [ ] **Finish case contents and eligibility.** For Robux or Robux-buyable Coins, disclose every outcome and its actual numerical odds before purchase, using the same available-item pool as the roll. With the project's no-duplicate rule, recalculate for owned items, handle exhausted pools and enforce player eligibility at the purchase and opening entry points. Test restricted players and interrupted or repeated grants. [Roblox paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items)
- [ ] **Build both paid bundles.** Finish a Thanksgiving-exclusive bundle for a viable event window and the original Tempest-Strike bundle based on the existing Kuronami-inspired brief. For each, lock roster, price, preview, skins and any charm or Mod, then finish models, animation, audio and equip behavior. Schedule the seasonal offer separately if its event window falls after the release date. [Tempest-Strike build handoff](../02%20Art/Skins/TempestStrike/Build%20Handoff.md)
- [ ] **Wire Daily Shop after the catalog is ready.** Define the rotation pool and item weights, fill the current eight-slot layout, pin the reset timestamp, and handle ownership across rotation changes and different servers. Check expiry and affordability at the server when buying and test a rollover with active players.
- [ ] **Design and wire daily login rewards.** Decide day sequence, reset time, missed-day behavior and reward contents. Use the shared reward grant logic, then test time boundaries, time-zone display, rejoining and cross-place claims. Keep login claims distinct from Tasks in the UI.

**Done when** a player can preview, buy or earn, receive, equip and keep each launch item, including across reconnects and rotation changes.

## 7. Finish the Season Pass

- [ ] **Lock Season 1.** Choose the skin line from the existing Poolside and Rootglass work or approve a new theme. Set the season length, XP curve, free and premium tracks, and the reward per tier. Reserve the skin roster, charms, Coins, cases or emotes in the catalog before final assembly. [Season Pass UI](../02%20Art/UI%20Battle%20Pass.md) · [Skin build ledger](../02%20Art/Skins/Battle%20Pass%20Blender%20Build%20Ledger.md)
- [ ] **Wire the existing pass screens.** Show actual earned progress and reward availability. Award XP from approved play and Tasks, grant premium access, support claiming reached free and premium tiers, and wire tier purchases if offered. Define late premium purchases and what happens to unclaimed rewards when the season changes.
- [ ] **Test the full lifecycle.** Simulate the first tier, a midway premium upgrade, a repeat claim, a rejoin and the season boundary. Verify that the new season starts correctly while earned items and old purchase records remain available. Check policy eligibility anywhere a paid path includes a randomized reward.

**Done when** a fresh player can see the pass, earn progress, unlock premium, claim rewards and retain them after a season rollover.

## 8. Finish presentation and the last launch features

- [ ] **Ship the default match feedback set.** Finish custom headshot sound and visual feedback, a custom kill sound and banner, and a custom win sound. Mix them with gunfire, abilities and UI at real combat volume. Check overlapping cues when a quick series of kills turns into round end or match end.
- [ ] **Finish the custom victory cutscene.** Pick a clear fixed staging point or camera anchor per map. Finish winner poses and animations, sync the win sound and test the handoff from replay to results. Cover disconnects and missing actors with a simple results transition. Check 1v1 and full-team winners.
- [ ] **Give animated gun skins their own kill presentation.** For each animated gun skin, finish its unique kill sound and banner, add the per-skin headshot cue where the design calls for it, and verify stock fallback. Review it in combat, spectate and replay, including performance and sound levels.
- [ ] **Add leaderboards and Lobby TVs.** Choose the public stats and time window, populate leaderboards from real saved player data, and test updates, ties and empty states. Use the existing TVs for queue info, featured bundle or pass spots and game announcements. Test legibility from the paths players actually take.
- [ ] **Finish the emote pack.** Complete the emote roster and equip behavior first. Then group a worthwhile set into a pack, create its preview and artwork, wire its grant path and test the full flow. Reuse case fulfillment if you choose random contents and verify eligibility through the same checks.
- [ ] **Finish launch branding and listing assets.** Finalize game name, logo, experience icon, thumbnails and the visual design across Lobby signs, menus and listing art. Capture real launch maps, characters and skins for thumbnails. Review at small sizes and update final IDs and credited sources in the vault.

**Done when** players can recognize the game from its listing, understand kills and wins in play, and use the finished presentation features across the intended launch maps.

## 9. Integrate, review and release

- [ ] **Integrate the release candidate.** Coordinate the Git merge with the owner, then reconcile the Lobby and Match source, Studio-owned models and UI, saved versions and published test versions. Remove the release copies' reference material, unused staging props and unwanted debug content after checking dependencies. Record the versions and rollback path. [Developer Handoff](../04%20Tech/Developer%20Handoff.md) · [Setup Guide](../04%20Tech/Setup%20Guide.md)
- [ ] **Run Claude's final review.** Ask for a findings list covering script refactoring, unused code/models, folder and vault cleanup, bugs, asset provenance and potential DMCA problems, defensive validation, profile integrity and purchase handling. Fix blockers before publishing. Keep late refactors scoped to reviewed fixes and retest the affected paths.
- [ ] **Run technical checks.** Run `stylua --check src`, `selene src` and both Rojo builds for shared changes. Confirm asset permissions and all production toggles. Record failed checks and their disposition in the release playtest note.
- [ ] **Run the launch playtest matrix below in the integrated candidate.** Include Studio coverage and an authorized published test for real teleports, purchases, location display and analytics. Make a final call on any deadline cuts before repeating the release smoke test.
- [ ] **Publish the approved Lobby V4 and Match versions.** Coordinate publishing with the owner. Verify queue → Match → results → Lobby, the first profile save, and the enabled purchase paths once the intended versions are live.

| Release check | Cases to run |
| --- | --- |
| Match flow | Solo vs bots, real 1v1, parties in 2v2 and 3v3, long match with normal vote, timeout/overtime, leaver, late join, rematch, Play Again, Leave |
| Player setup | Fresh profile, returning profile, existing Locker save, level/XP, Tasks, inventory equip, settings saved across Lobby and Match, disconnect during save |
| Economy | Coin pack, direct bundle, case and restricted case path, no-duplicate and exhausted pool, Daily rotation, login claim, duplicate receipt or claim, free/premium pass and rollover |
| Content | Every launch map/config ID, spawn, zone, bot path, winning camera, current Mods and upgrades, sniper ADS, Giltfold reload, animated-skin presentation |
| Devices and performance | Keyboard/mouse, physical phone, gamepad, slow loading, 3v3 with bots and effects, input switching, reduced motion |
| Release and analytics | Real reserved-server teleport and return, region label, funnel and reward events, final Studio version IDs, production flags and rollback target |

## If the deadline moves, defer in this order

The full plan above is the target. Start at the top of this cut list if time runs short, then repeat the relevant release checks after hiding or simplifying anything you move.

1. **Emote pack.** Keep the starter emotes and equip flow. Move the paid or randomized pack until the lineup justifies it.
2. **Decorative TV ads.** Keep useful queue information on the TVs. Move custom promotional loops and extra placements.
3. **Thanksgiving exclusivity.** Move the themed bundle to the next suitable event window or release its contents as a regular bundle later.
4. **Per-skin kill banners and audio.** Keep the polished default feedback across all guns. Add custom presentation per animated skin in later drops.
5. **Full victory cutscene.** Keep the custom win sound and a short winner pose or clean results transition.
6. **Additional cases, maps or Mods beyond what passed review.** Keep one working skin case and a complete, balanced map and Mod roster. Add remaining case tiers, maps or Mods once their content and checks are ready.
7. **Extra economy surfaces.** If more time is needed, simplify Daily Shop depth and login streaks, then consider moving the global leaderboard or Season Pass as a whole. Hide entry points for deferred features.

Protect complete matches, progress saves, functional settings, first-time guidance, stable input support, validated purchases, asset rights and the final release checks throughout.
