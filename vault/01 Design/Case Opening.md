# Case Opening

Owner (2026-11-20): open cases **in the world, RIVALS style**: the crate comes out next to you in the lobby, animates and opens there, and others can see it. Picked over a CS:GO strip and a separate showcase stage ([Skin Tiers and Cases](Skin%20Tiers%20and%20Cases.md) → the opening itself).

## RIVALS study (structure and numbers only, nothing copied)
From the RIVALS file's `Modules.Functions.LootboxEffect` and `Assets.Lootboxes` (read only; [Rivals Reference](../03%20Research/Rivals%20Reference/00%20Rivals%20Reference.md)):
- The box is tossed from the player to a spot ~7 studs out (several openings fan around in a ring), 2 s, eased glide (1 − (1 − u)^5) with ~1.5 decaying bounces.
- It plays its own keyframed opening (an AnimationController clip per box with `Duration` / `RevealDelay` attributes) and a per-box sound set. Skin case: reveal **2.0 s** after landing, **4.85 s** total; weapon crate 2.25 / 5.55; chests and wheels 4-15 s.
- At the reveal: the reward card floats ~8 studs above the box (a 10 x 10 stud BillboardGui), grows in 0.5 s Quint Out, a trail in the rarity colour, one stinger per rarity.
- Holds 4 s, shrinks (Back In), the effect flies into the player (1.9 s Quint In) and bursts into collect particles.
- Everyone sees it; someone else's opening plays at half volume.
- Their skin case is ~6.4 x 2.0 x 3.4 studs (ours is 3.1 long, scaled 1.6x for the opening).

## Our sequence (built 2026-11-20)
`src/lobby/client/Util/CaseOpening.luau`, numbers in `src/shared/Config/CaseOpening.luau`.
1. **OPEN** in the Backpack popup closes the menu and the crate is **tossed right away** from your chest to a clear floor spot 6.5 studs ahead (tries other angles when a wall is in the way), front facing you, 1.0 s with ~1.5 bounces and a turn. This hides the server's round trip.
2. **Shakes** every 0.55 s, growing (4 / 7 / 9 degrees, small hops, the handle swinging) until the result is in and at least 2 have played. No answer in 10 s, or a refusal: it **sinks** away with a dust puff.
3. **Latches** snap down one after the other (0.1 s apart, back-ease overshoot), a dip (anticipation), then the **lid bursts** open (105 degrees, overshoot) with a tier-coloured flash (glow + sparks, more for higher tiers), a point light, the lid whoosh, a low swell and the **tier stinger**.
4. The **skin rises** out (4.4 studs long, 0.9 s Quint Out), turns once and keeps turning slowly; the **card** floats above it (dark plate, name in the tier colour, tier tag; "NAME UNBOXED" on top for everyone else).
5. Holds 3.2 s, the card shrinks, the skin **flies into you** (0.85 s Quint In) with a spark burst and the equip pop; the crate sinks into the floor.
6. The Backpack comes back on the result panel (EQUIP / NICE).

**Everyone else** sees the opening within 140 studs. The server sends the reward models and the `CaseShow` event after the inventory write. `Controllers/CaseShowController` plays the sequence at half volume with the opener's name on each reward card.

### OPEN 3 (2026-11-23)

Three crates toss into a forward arc at 0° and ±48°, 11 studs from the opener. Blocked slots search the full circle at several distances for separated landing spots. Crates hover around the opener when there's too little floor space. The lids open together using the longest build-up in the batch. Each granted skin rises from its own crate, and a crate that returned Tickets opens empty in a partial batch. The highest-tier reward plays the stinger and drives the opener's camera kick. The Backpack pages through the granted skins after the animation.

The opening can wait up to six seconds from the server's result for the exact unlocked models to arrive. If a model still hasn't arrived by the reveal, its portrait and name appear on the reward card. Owner playtest pending.

**Review knob (Studio only):** the workspace value `CaseTimeScale` (StateValues) slows the whole sequence, e.g. 0.12, to capture each beat.

## Round 2: more payoff (2026-11-20)
Owner: "people are going to be paying money for these cases, it needs to be satisfying"; the card should look much better; the fly-in should look better and more satisfying.
- **Build-up scales with the tier:** Common 2 shakes, Rare 3, Epic 4, Legendary 5 (`TIER_SHAKES`), each bigger (4 → 12 degrees). From the second-to-last shake the **seams glow in the tier colour** (the light strip and a light inside, throbbing with each shake, a short swell): the tease before the lid. The lid strains against the latches during the dip.
- **Lid burst:** layered whoosh + a low case hit + the swell + the tier stinger; sparks and glow (more for higher tiers), a **floor shockwave ring** and a **light beam** straight up in the tier colour; **camera kick and FOV punch** for the opener only.
- **The hold:** the skin turns in a soft glow with sparkles (more for higher tiers) and its own light.
- **Card:** the skin's **portrait spilling over a tier-coloured tile** beside the name and tier tag, pops in (Back Out) with **one shine sweep**; "NAME UNBOXED" on top for others.
- **Fly-in:** the skin **arcs up and into your chest** (3.5-stud arc), spinning twice and shrinking, with a **trail** in the tier colour; on arrival a spark burst, a floor ring at your feet, the equip pop + a bright ping, a small camera kick.
- **Sounds on the F4 board, CASE tab** (lobby): case lands, latches, lid burst, a reveal per tier, collect. Not level-matched yet; pick by number.
- The result panel uses the new portrait.

## Round 3 (owner notes, 2026-11-20)
- **It just ends:** after the skin flies into you there's no panel; the Backpack and result panel only come back if no crate could be placed (no room).
- **Higher tiers hit harder** (`Config/CaseOpening.TIER_FX`):

| Tier | Held beat before the lid | Sparks (waves) | Floor rings | Beam | Camera kick | Screen flash | Extra sounds |
|---|---|---|---|---|---|---|---|
| Common | none | 30 | 1 | none | 0.6 | none | — |
| Rare | 0.15 s | 50 | 1 | 0.8x | 0.85 | none | — |
| Epic | 0.45 s, trembling, glow ramps, riser | 75 (+1 wave) | 2 | 1.2x | 1.15 | 35 % | — |
| Legendary / Exclusive | 0.8 s | 110 (+2 waves) | 3 | 1.6x | 1.5 | 50 % | PSE Tailgate boom (low) |

## Round 4: sound picks (owner, 2026-11-20)
| Moment | Sound | Status |
|---|---|---|
| Case lands, latches, collect | as before (PSE Plastic Cooler Hits 3, PSE Plastic Switch 14, GUI Equip + Notification High) | picked |
| Each shake | old thump + a 0.4 s slice of PSE "Metal Lid Movements Over Box 6" (`SOUNDS.Rattle`, `cut`) | picked |
| Lid burst | old whoosh + hit + swell, plus APM "Deep Boom 06" (`SOUNDS.LidBoom`) for more umph | picked |
| Reveal: Common | Roblox GUI Equip | picked |
| Reveal: Rare | APM Universal Flip - Hit | picked |
| Reveal: Epic | APM Get Up And Go - Hit | picked |
| Reveal: Legendary / Exclusive | APM "Hustler Sting 2" (4.4 s, sports brass) + PSE Tailgate boom. The short build was rejected ("we can't have a sound that is less than the Epic one… it needs to be a stinger like that"). | picked (owner 2026-11-20: "#1"); the CASE tab is off F4 now |

The F4 CASE tab is gone (every case sound picked). A sound spec takes `cut` (seconds, then a 0.1 s fade) so a slice of a longer recording can be used.

**Bug fixed:** opening a second case while the first was still animating broke it (the server's reply cleared the lock while the crate played on). OPEN now refuses while a crate is alive ("Wait for this case to finish opening" toast + the denied sound). Tested: Apex opening, second OPEN on Standard refused and kept, then it opened fine after.

## Tested (2026-11-20, Lobby place)
- Apex at full speed: tossed, opened, Playback Ares (Epic), back in the Backpack with the result, no errors.
- Elite slowed to 0.12 and captured: in the air, landed facing the player, latches and lid open (right direction), Moltframe Ares (Rare) risen with its card, cleanup (crate and skin gone) and the result panel.
- The other-player view (played locally as someone else's): "CHARLIE UNBOXED · SEALWORK VANDAL · RARE" over the open Apex crate.
- Fixed from the captures: the flash washed the player out white (peak 6 → 2.2), the skin read small next to the card (3.4 → 4.4 studs; card 7 → 6.6 studs wide), the card clipped long names at 5.6 studs, the result panel was blank for lines without a picture (now the line's initial).
- Not tested: two real players (Studio MCP runs one client); video capture isn't available in this Studio.

## Final polish (2026-11-23)

- **Floating unlock card fix (`Util/CaseOpening`):** `revealSkin()` previously omitted `tier.order` when calling `card(anchor, r, tier.color, tier.name, tier.order, who, sizeScale)`, shifting `sizeScale` to `nil` inside `RenderStepped` so the floating `CaseCard` billboard never spawned. Fixed argument order.
- **Hosted-lobby `SkinDelivery` & art preloading (`Services/SkinStoreService`, `client/init.client`, `Util/CaseOpening`):** Players spawning directly into a hosted match (`ServerRole.isHosted()`) received `PlayerGui.SkinDelivery` after the match snapshot, so returning to Lobby (`cleanUp()`) destroyed the client container while the server kept `sent[player]` populated and refused re-delivery. Marked `SkinDelivery` with `KeepGui = true`, exempted `"SkinDelivery"` in `cleanUp()`, preloaded all `Config/CaseOpening` sound IDs once on start, and preloaded `SkinArt.portrait` + `SkinArt.side` images via `ContentProvider:PreloadAsync` inside `reveal()`.
- **Sound upgrade (`Config/CaseOpening`, `Util/CaseOpening`):** Replaced plastic cooler shakes/switch latch/generic swell with Pro Sound Effects / APM assets verified via Studio `PreloadAsync` (`Success`, `loaded=true`):
  - `Land` / `Burst`: `9119075953` (PSE *Shield Impacts 18*)
  - `Shake`: `9119110904` (PSE *Shotgun Drop 10*, escalating pitch & gain per shake)
  - `Rattle`: `9114895481` (PSE *Junk Rattle Box Of Miscellaneous Items 1*)
  - `Latch`: `9117028600` (PSE *Moviola Toggle Switch Single Clicks Sharp 8*, `1.0` / `1.12` stereo-style pitch step between `LatchL` and `LatchR`)
  - `Strain`: `9116341721` (PSE *Machine Gun 7*, metallic ratchet tension during Rare+ `hold`)
  - `RISER`: `9039693361` (APM *Gobstopper Sucker*, `start = 1.75 s` suckback to lid burst; added `start` `TimePosition` support in `sound()`)
- **Verification note:** Static checks (`selene src`, `rojo build`, `stylua --check` on edited files), Rojo Studio sync, and Edit-mode `PreloadAsync` audio load checks pass; live Studio Play check pending owner F5/restart due to wedged Studio MCP `start_stop_play`.

## Round 5: louder and more fun (owner, 2026-11-25)
Owner: "louder and more fun", better shake sounds, a more satisfying win. Loudness measured in Studio (PlaybackLoudness at Volume 0.5) before mixing.
- **Louder:** `LOCAL_VOLUME = 1.35` on your own opening; most volumes up 25-60 %; `ROLLOFF` min 8 → 16 studs so the camera behind you hears it at full; a 5-case batch splits loudness by sqrt(5), not 5.
- **Shakes:** each shake now also knocks the case on the floor: `SOUNDS.Knock` (PSE "Plastic Cooler Hits 8", hollow thump, 0.35 s slice, slight random pitch) + `SOUNDS.ShakeBoom` (PSE "Truck Tailgate 3", pitched 0.75, low resonant boom). Gain grows faster per shake (0.8 + 0.14 × shake) and the pitch still climbs.
- **Win:** Common gets a real APM hit ("Totally Go For It - Hit4") instead of the UI equip click; Rare adds a short PSE "Fairy Dust 1" sparkle; Epic chime + longer sparkle; Legendary / Exclusive add the sparkle and a crowd roar (PSE "Wrestling Crowd 3", 3 s). Collect louder.
- **F4 → CASE tab** is back: it plays a whole opening (Standard Common / Rare, Starter Epic, Apex Legendary, Knife, ×5 batch) with sample skins, nothing bought (`CaseShowController` Studio preview).
- Checked in Studio: a Legendary preview fires every layer in order (5 shakes × 4 layers, rising; full reveal stack at 5.35 s). Not heard by Claude: owner to listen.

## Bundle opening (owner 2026-11-25)
Owner: buying a bundle should feel better. "spawn all the cases at once that it includes in a different colored case and then it opens them", then "a menu with every gun to equip ... so it is easy for a person to equip what they just bought".
- **Crates:** one per item (up to `MAX_CRATES` = 6), thrown together in a wider arc (`WIDE_STEP` 26°, `WIDE_DISTANCE` 17, cards at `WIDE_CARD_SCALE` 0.74). Each bundle has its own crate colours with gold hardware (`Config/Crates` 5 Ruin-Blighted teal, 6 Tempest-Strike blue; `ShopCatalog` bundle `crate`). All lids burst on the same beat with the Exclusive sound stack. The stinger plays once, on the lead crate.
- **Server:** `RobuxService` records the bundle skins the buyer didn't own (in the receipt's write) and sends them as `results` + `crate`. `ShopService.showOpening` delivers the models and plays the same opening for nearby players, which is free advertising in the lobby. A bundle the buyer already owned entirely still pays out coins with the YOU GOT popup.
- **After:** the Backpack reveal shows each skin big (NEW SKIN · 1 OF 6) with a strip of all of them under the panel (click one to jump to it; EQUIPPED marks). The buttons are EQUIP · **EQUIP ALL** (gold) · NEXT. EQUIP ALL puts every one on, toasts "6 SKINS EQUIPPED" and closes the Backpack. The strip and EQUIP ALL also show after an OPEN 3.
- **Test:** F4 board → CASE → "Bundle bought: Tempest-Strike / Ruin-Blighted" (Studio only, nothing bought). Checked in Studio Play: 6 crates in each bundle's colours, a clean reveal, the strip and buttons laid out, no errors. Not tested: a real Robux receipt (the Studio test hook writes the save).

## Open (owner)
- **Sounds:** Round 5 approved (owner 2026-11-25: "Sounds great").
- **Bundle opening:** approved as is (owner 2026-11-25: "Nah thats good I like it", ~11 s to the equip screen kept). Still to do: a real purchase test.
- Feel: toss length, shake count, hold time, flash strength per tier; higher tiers could get a longer build-up (RIVALS chests run 8 s).
- Pictures for every skin (renders, not viewports) so the result panel never falls back to a letter.
- **Save the Lobby place.**
