# Release plan (2026-11-27)

Everything between today and a public Draft Duels launch, in order. It builds on [Release Plan 2026-11-22](Release%20Plan%202026-11-22.md), [Launch Hardening](Launch%20Hardening%202026-11-27.md) and [Handoff - Battle Pass Build](Handoff%20-%20Battle%20Pass%20Build%202026-11-27.md). Where they disagree, this note is newer. Tags: **[O]** is the owner's to do or decide, **[C]** Claude can build, **[C+O]** Claude builds and the owner checks.

## Where we are
**Built and Studio-tested (not published)**
- the merged place and Lobby V5;
- the queue with bot fallback;
- the power deck: 12 powers, starter deck Dash, Updraft, Molly, Frost;
- gun levels 1–50;
- the Locker v3, the Shop and cases;
- onboarding (funnel v3);
- launch hardening;
- the battle pass core: data, progress, Robux products (premium 689 R$ `3736724862`, +5 levels 499 R$ `3736724879`), the pass screen, titles and the random-gun skin reel;
- 32 charms with blind boxes and rendered icons;
- **the Arcade line on all 14 guns**, with effects, sounds, portraits and an emblem.

**Switched off for launch** (`Config/Release`)
- `BATTLE_PASS_OPEN = false`
- `SHOP_FULL_LAYOUT = false`
- `Season.STARTS_AT = 0`: no season dates set yet.

## Status check: what's left for release #1 (late 2026-11-27)
The owner wants this update to be the polished first release. Checked against the code and Studio.

**Done since this plan was written:**
- Smoke and Electric Shock, with all paths, ChatGPT icons and card art.
- Name tags; titles on the scoreboard and end screen.
- Goodie bags; the Shop's pass card.
- 32 charms with blind boxes.
- Arcade on all 14 guns.
- Frostbite: in progress in its own sessions.
- The RIVALS and staging containers are gone from the place.
- **Today:** pass **CLAIM ALL** (one write, one summary toast), the **season-end payout** (H: leftovers paid on join and every minute after `Season.endsAt()`, claims then refused; Studio switch Workspace `SeasonEndNow`), and the Studio hook `ServerStorage.SeasonTest`. Studio-tested: 18 rewards in one claim-all; a forced end paid tiers 13-20 once and refused a later claim.

**Power upgrades** (code audit, all 14 powers × 7 levels): every level has code. Small gaps:
- Dash B3/G3: the cloak doesn't hide you from bots or aim assist.
- Heal Orb G2/G3: the held orb doesn't get a Barrier look (`Heal Orb.md:116`).
- Smoke G2 Toxic Cloud: no sound of its own.
- Most power sounds are unauditioned library takes. Ready/Denied/Cancel are stand-ins and ModRaise has no sound.
- The Hindered and Stimmed HUD readouts are temporary.
- `Upgrade Paths.md` says Shock Dart G3 is 7 studs; the code is 11.

**Progress (2026-11-28):**
- **Owner decisions:**
  - No odds needed on coin packs or the Starter Bundle: the cases inside show their own.
  - **Starter Bundle v2:** the Lancer, the Payload Lancer, a Standard Case, a Strike Box and 1,500 coins. Coins replace anything already owned, and replace the case and box where paid random items aren't allowed. Built; the Studio test and new Shop art (prompt in [Release 1 ChatGPT Prompts](../02%20Art/Release%201%20ChatGPT%20Prompts.md)) are still to do. The Roblox product description is updated with the new art (Open Cloud needs an icon in the same call).
- **Security review:** no critical or high findings. Fixed: an Electric Shock orb outliving its thrower or the round; pass powers ignoring the deck size; a goodie-bag item prize on a full stack. **Owner decision (2026-11-28): the admin panel stays live** (UserId allowlist), so the owner can fix player saves in the live game. Keep the owner account secured (2-step verification).
- **Data safety review:** no duplication or load-overwrite paths. Fixed:
  - `PlayerData.VERSION` 2: older servers can't strip new nested fields. **On publish: shut down all servers.**
  - Unknown charm ids are kept.
  - txId memory raised to 60.
  - The Studio Locker store is split from live.

  Left for Season 2: keep the old season as `seasonPrev` and pay it on the next load, instead of wiping it when `Season.ID` changes.
- **Error logging:** Roblox's Creator Dashboard Error Report already collects server and client errors, and `HealthLog` covers the loading stages, so nothing new was built.
- **Audio:** the power UI cues (ready, denied, cancel, a new raise) and the Toxic Cloud's own pop and loop are designed, uploaded and wired ([Mod Audio](../02%20Art/Mod%20Audio.md#release-1-pass-2026-11-28)), waiting for the owner's audition. The older powers' library sounds are still placeholders.
- **Own sessions:** third-person animations (fun locomotion, the restarting upper body) and RIVALS-style name tags.

**Must do before publishing:**
1. **Finish Frostbite** (its sessions).
2. **Compliance [C]:**
   - Odds on coin packs 4-6 and the Starter Bundle.
   - Shop Robux prices from `GetProductInfo` (none today).
   - Every paid random item shows its odds (cases, charm blind boxes, bags).
   - The `roblox-monetization-compliance` audit.
3. **Data safety [C]:** review, plus a kill-the-server test mid-purchase and mid-claim.
4. **Security [C]:** review the remotes added since the last audit: Season (claim, claimAll), the Locker title and charm actions, blind boxes, bags, `ModTrigger`, admin.
5. **Error logging [C]:** nothing reports server or client errors today (no `ScriptContext.Error` / `LogService` hook).
6. **Phones [C+O]:** the pass screen phone layout (F). A real-phone and controller match covering every new screen: name tags, the Locker charm slot, bag opening, the pass.
7. **Place cleanup [C+O]:**
   - Delete `ServerStorage.PlateMigrationBackup` (3.2k), `UiBackups` (1.6k), `BotAvatarBackups` (1k) and the empty `WeaponSyncBackup` after you OK it.
   - The RIVALS-kit meshes in Greenhouse4, Foundry4 and CanyonOutpost, and the RIVALS map textures, stay by your earlier call; that's still an IP risk.
8. **Owner decisions [O]:**
   - the Operator against the one-shot rule;
   - the Ruined Reaver in the bundle;
   - ship all 14 guns;
   - server sizes;
   - **whether the pass opens at launch, or a soft launch with it closed (the earlier locked plan)**.
9. **Save the place, push, publish [O].**

**Polish that makes it feel finished:**
- an audio audition pass for the powers;
- the Barrier orb look;
- the Toxic Cloud sound;
- the final Hindered and Stimmed HUD;
- pass claim stamp and shine;
- title-reward art;
- a mobile MicroProfiler pass (30 fps target);
- phone text at least 12 px.

**Store and launch [O + C]:**
- icon and 3 thumbnails (an Arcade skins one, a power moment);
- the description with sound credits;
- the questionnaire;
- a 30 s trailer;
- a group or Discord;
- pass analytics (view → buy);
- set `Season.STARTS_AT` and `BATTLE_PASS_OPEN`.

## Final check before release #1 (2026-11-28)
**Verified in Studio:**
- **Battle pass end to end:** a fresh pass with premium at tier 30, then CLAIM ALL, paid 44 rewards on both tracks.
  - Coins: +7,000 from the tracks, plus 500 for each Arcade tier this test save already owned.
  - 3 goodie bags, 2 Standard Cases, 1 Elite Case, 1 Apex Case, 3 Tickets.
  - Smoke and Electric Shock.
  - The 8 pass charms.
  - 4 Frostbite skins, the Frostbite Knife included, plus the FROSTBITTEN title equipped.
  - Arcade and Frostbite have models and portraits on all 14 guns (the Knife too). Arcade rolls only pick owned guns. No pass reward is missing art. All 32 charms are in `ReplicatedStorage.Charms`.
  - The pass screen has its phone layout (Phone* attributes).
- **Starter Bundle v2** granted correctly and only once. The Shop-load bug is fixed.
- **Join:** a cold join has data at +0.1 s and the loading screen done at +5.4 s.
- **Lint and build:** stylua, selene (0 warnings) and rojo build pass.
- **Removed:** the RIVALS name tag reference (`Workspace.NametagGui`, it would have shipped), `PlateMigrationBackup` and `WeaponSyncBackup`.

**Before publishing, in order:**
1. ~~Pass at launch~~ **Done (owner 2026-11-28: open at launch).** `BATTLE_PASS_OPEN = true`, `Season.STARTS_AT` = 2026-11-28 00:00 UTC, and the season ends 2027-01-09. (The soft launch already happened.)
   - **Friction fixes:** the Shop's red dot now counts pass rewards waiting, and one toast per lobby visit says they're waiting. Before, a tier gained in a match was never mentioned, and the pass's only way in is the Shop's card.
   - **Moderation:** samples from every new line came back Approved (Frostbite, Arcade, charms, the goodie bag, the power and UI sounds).
2. **[O+C] Release art:** all four PNGs are ready in the [art handoff](../02%20Art/Release%201%20ChatGPT%20Prompts.md#finished-files). **[O]** uses the Season 1 thumbnails in Creator Dashboard and ads. **[C]** uploads the Starter Bundle shop art, swaps `ShopCatalog.ART.starterContents`, and updates the product description and icon in one Open Cloud call.
3. **[O] Charm swing tuning:** uncommitted changes in `CharmRig`, `GunAnimator`, `ViewmodelRig` and `tools/studio/FixCharmPoints` (the charms work). Rojo already syncs them into Studio, so they ship. Keep (commit) or drop them.
4. **[O] Your checks:**
   - a 2-player Local Server (name tags, titles);
   - a real phone and a controller through a match and the new screens;
   - the audio reel `art-source/audio/release1/_Reel.wav`;
   - the unexplained `Workspace.Arrows` part (an invisible Beam part at z −1634).
5. **[O] Save the place** (many Studio edits: CLAIM ALL, the profile TITLE plate, name tags, the cleanups).
6. **[O] Push `main`** (180+ commits).
7. **[O] Publish, then shut down all servers** (Creator Dashboard → Servers): `PlayerData.VERSION` is 2, so old servers can't write new saves.
8. **[O] Store page:** the description (in the prompts note), the new thumbnails, and the maturity questionnaire.
9. **After:** watch the Creator Dashboard Error Report, `Onboarding_v3`, D1 and playtime for 2-3 days. Run Play Ads with the new thumbnails against the 4.5% winner.

## Phase 1: finish Season 1 content (the battle pass has to be complete before it opens)
1. **The two pass powers [C+O]** (built 2026-11-27, icons and card art in; left: the owner's sound audition). Smoke (free tier 10) and Electric Shock (premium tier 20). Each power needs:
   - design numbers in `01 Design/Abilities/`;
   - server logic in the Mods system, with the validation rules;
   - the effect, built mesh-first (`lihfolk-vfx`);
   - sounds;
   - a ChatGPT icon;
   - draft card art;
   - a bot behaviour;
   - a Range test station.

   About one session per power.
2. **Frostbite skin line [C+O]:** Legendary, the pass's chase line, on 14 guns plus the Frostbite Knife, with tiers 15, 24 and 29 and the knife at 30 with the FROSTBITTEN title. Build it like Arcade:
   - a ChatGPT concept for the Havoc first, then the Havoc in Blender for your approval;
   - then 13 guns in parallel Blender instances, with the same gates and gap sweep;
   - then install, portraits and emblem.

   Being Legendary, it needs more than Arcade:
   - an ice-growth animation on inspect and a crack effect on a kill (mesh-first, local);
   - its own shot, inspect and kill sounds (licensed ProPack plus design);
   - a knife with its own animation.

   The biggest item left. Budget it like the Slipframe Epic pass ×2.
3. **Pass leftovers from the build handoff** (name tags, match titles and goodie bags done 2026-11-27):
   - name tags (A);
   - match scoreboard and end-screen titles (B);
   - goodie bags (E: 3 bags, odds 60 / 25 / 10 / 5, odds shown);
   - the phone layout of the pass screen (F);
   - CLAIM ALL;
   - the Shop's pass card (G);
   - the season end and the payout of leftovers (H). [C]
4. **Pass screen finish [C+O]:**
   - claim animation: the check stamp pops and the tile flashes;
   - a one-time shine on claimable tiles;
   - the reel on the detail view;
   - art for TITLE rewards (a title plate) and for unbuilt powers;
   - ~~fix the Shop's pass card, cut off past the right edge~~: done 2026-11-27 (Shop Home layout v3: cases 2 x 2 + the pass card).
5. **Charm follow-ups [C]:** check the Charms handoff's empty Results section against what is installed, and fill it in.
6. **The other Rare lines [C, optional for launch]:** rebuild Kilnlock and Stacklight to the Arcade standard (Blender already exists, needs the rebuild and gates). Not needed for launch. Good case content for week 2.

## Phase 2: launch blockers (must be done before publish)
1. **Clean the live place [C+O].** Remove the legacy RIVALS and staging containers (`LobbyRivals`, `ShootingRangeRivals`, V3 `Lobby`, `LobbyV4Staging`, `SunwellStaging`, `Texture Pack`, backups, about 52.5k instances). They're an **IP risk and a load cost.** Also remove `ServerStorage.PlateMigrationBackup` once confirmed unused. The RIVALS-kit meshes in Greenhouse4, Foundry4 and CanyonOutpost need replacing or the maps parking. [O decides which maps ship]
2. **Monetization compliance [C].**
   - Odds disclosure on coin packs 4–6 and the Starter Bundle.
   - Use `GetProductInfoAsync` for displayed prices instead of hard-coded ones.
   - Keep the PolicyService gate on paid random items, and check every paid random item (cases, charm boxes, goodie bags) shows its odds.
   - Run the `lihfolk:roblox-monetization-compliance` audit.
3. **Data safety [C].**
   - Reconcile session locking (the Release Plan says yes; the Inventory note says the per-change write makes it unnecessary) and write down the decision.
   - Run the `lihfolk:roblox-datastore-safety` review, then a kill-the-server test mid-purchase and mid-claim.
4. **Security pass [C].** A `lihfolk:roblox-secure-remotes` review of every remote added since the last audit: Season, charms, blind boxes, Locker, the Arcade claim payload, admin.
5. **Owner decisions [O]:**
   - the Operator's body and leg damage (95/76) against the one-shot rule;
   - whether the Ruined Reaver is in the 999 R$ bundle;
   - the proposed gun cut (8 + 4) versus shipping all 14;
   - server sizes per mode (research: 2–8; no 4v4 at launch).
6. **Lint [C]:** the open Operator, Ruin-Blighted and BattlePassController items.

## Phase 3: quality and devices
1. **Real devices [O + C].**
   - Test a real phone (lowest you own) and a controller through a whole match. Claude fixes what you find.
   - Run a mobile MicroProfiler pass and agree a low-end target (for example, 30 fps on an iPhone 8-class device in a full match).
2. **Error logging [C]:** server and client error reporting to a log, plus a crash or loss-of-data alert. Release Plan item 7 isn't confirmed done.
3. **Bots and empty servers [C]:** check the bot fallback fills every mode at 3am-quiet player counts, and set the AFK kick and rejoin behaviour.
4. **Accessibility [C]:**
   - the reduced-motion setting;
   - colour-blind-safe team colours (ally `2FD3E6` / enemy `FF5A4E` already carry shape or text);
   - minimum text size 12 px on phone.
5. **Localisation [O decides]:** turn on Roblox auto-translation for menus at least (UI has 30–40% headroom). Hand-translate the store page for the top 3 languages later.

## Phase 4: store page and marketing
1. **Listing [O].**
   - The experience questionnaire (maturity: aim Mild).
   - Genre and tags, the description with credits and licences (sounds are licensed: list them), and social links.
   - The icon and 3 thumbnail variants: the best CTR so far is 3.1% against a target of 4%+. **Make one thumbnail showing the Arcade skins and one showing a power moment.**
2. **Trailer [C+O]:** 30 s, captured in Studio (draft, guns, skins, powers, the pass reel).
3. **Group and community [O]:** a Roblox group (for the "Hear about new seasons" reward), Discord or socials, update notes.
4. **Promo [O]:** a sponsored-ad budget after the soft launch shows healthy D1 and playtime.

## Phase 5: soft launch → launch
1. **Soft launch** (owner's locked decision): publish with `BATTLE_PASS_OPEN = false`, so the pass isn't sold yet. Watch Onboarding_v3, D1, playtime and errors for 3–7 days.
   - Targets: average playtime over 8 min, D1 over 15%, the qualified play-through funnel improving on 0.26–0.69%.
2. **Open Season 1:**
   - set `Season.STARTS_AT` and the season end (about 6–8 weeks);
   - set `BATTLE_PASS_OPEN = true`;
   - run a Studio pass test with a fresh save and a bought premium;
   - publish.
3. **Live ops [C+O]:** a weekly patch, daily Shop rotation (already automatic), a mid-season event (the Thanksgiving bundle line was planned), and the Season 2 lines started by mid-season.

## Things we haven't talked about yet (Claude's adds)
- **Reporting and moderation:** names, titles and charms are fixed text, which is safe. Keep any player-typed text (party names, if added) through `TextService` filtering. Add a report-player hook or rely on Roblox's own.
- **Refund handling:** a product granted twice or not at all (`ProcessReceipt` idempotency) is in the data-safety review. Add a support path: a group wall or Discord ticket.
- **Season rollover test:** fake a season end in Studio and check leftovers pay out and the state resets cleanly (H in the pass handoff).
- **Analytics events:** pass views, premium purchase funnel (view → click → prompt → bought), reel claims, and which powers get drafted. These tell you what Season 2 should be.
- **Anti-exploit check on the client-owned movement** (`AuthorityMode = Automatic` is the owner's call): add server-side sanity limits on speed and teleport so a movement exploit can't ruin ranked lobbies, without turning the client checks back on.
- **Backup and rollback:** before every publish, save a place version note in the vault (the version number) so a bad update can be rolled back in one click.

## Suggested order and sessions
1. **This week, in parallel** (separate Blender, Studio and file areas):
   - Frostbite Havoc concept → Blender;
   - Smoke and Electric Shock;
   - place cleanup;
   - the compliance, data and security reviews.
2. **Next:** the Frostbite roster, the pass leftovers (A, B, E, F, H) and devices.
3. **Then:** the store page, the trailer and the soft launch.
4. **Then:** open the season.
