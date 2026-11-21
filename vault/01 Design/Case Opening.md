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

**Everyone else:** the server sends `CaseShow` to every other player after a successful opening (`Services/ShopService`); `Controllers/CaseShowController` plays the same sequence at the opener (skipped beyond 140 studs), at half volume, with their name on the card. Cosmetic only; the roll and the grant already happened on the server.

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
| Legendary / Exclusive | 0.8 s | 110 (+2 waves) | 3 | 1.6x | 1.5 | 50 % | PSE Tailgate boom (low) + GUI Notification High (up) |

## Round 4: sound picks (owner, 2026-11-20)
| Moment | Sound | Status |
|---|---|---|
| Case lands, latches, collect | as before (PSE Plastic Cooler Hits 3, PSE Plastic Switch 14, GUI Equip + Notification High) | picked |
| Each shake | old thump + a 0.4 s slice of PSE "Metal Lid Movements Over Box 6" (`SOUNDS.Rattle`, `cut`) | new, on F4 → SHAKE |
| Lid burst | old whoosh + hit + swell, plus APM "Deep Boom 06" (`SOUNDS.LidBoom`) for more umph | new, on F4 → LID BURST |
| Reveal: Common | Roblox GUI Equip | picked |
| Reveal: Rare | APM Universal Flip - Hit | picked |
| Reveal: Epic | APM Get Up And Go - Hit | picked |
| Reveal: Legendary / Exclusive | short build: Roblox UI Tonal Stinger (1.5 s) + PSE Tailgate boom + Notification High | new, on F4 → REVEAL: LEGENDARY |

The F4 CASE tab now only holds the three open rows. A sound spec takes `cut` (seconds, then a 0.1 s fade) so a slice of a longer recording can be used.

**Bug fixed:** opening a second case while the first was still animating broke it (the server's reply cleared the lock while the crate played on). OPEN now refuses while a crate is alive ("Wait for this case to finish opening" toast + the denied sound). Tested: Apex opening, second OPEN on Standard refused and kept, then it opened fine after.

## Tested (2026-11-20, Lobby place)
- Apex at full speed: tossed, opened, Playback Ares (Epic), back in the Backpack with the result, no errors.
- Elite slowed to 0.12 and captured: in the air, landed facing the player, latches and lid open (right direction), Moltframe Ares (Rare) risen with its card, cleanup (crate and skin gone) and the result panel.
- The other-player view (played locally as someone else's): "CHARLIE UNBOXED · SEALWORK VANDAL · RARE" over the open Apex crate.
- Fixed from the captures: the flash washed the player out white (peak 6 → 2.2), the skin read small next to the card (3.4 → 4.4 studs; card 7 → 6.6 studs wide), the card clipped long names at 5.6 studs, the result panel was blank for lines without a picture (now the line's initial).
- Not tested: two real players (Studio MCP runs one client); video capture isn't available in this Studio.

## Open (owner)
- **Sounds:** pick on F4 → CASE: SHAKE, LID BURST, REVEAL: LEGENDARY (button 1 is what plays now).
- Feel: toss length, shake count, hold time, flash strength per tier; higher tiers could get a longer build-up (RIVALS chests run 8 s).
- Pictures for every skin (renders, not viewports) so the result panel never falls back to a letter.
- **Save the Lobby place.**
