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

## Phase 1: finish Season 1 content (the battle pass has to be complete before it opens)
1. **The two pass powers [C+O]** (built 2026-11-27; left: ChatGPT icons and card art, the owner's sound audition). Smoke (free tier 10) and Electric Shock (premium tier 20) aren't in `Config/Mods`. Each power needs:
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
