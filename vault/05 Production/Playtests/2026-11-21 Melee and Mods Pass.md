# 2026-11-21 Melee and Mods Pass (overnight, lane MELEE + MODS)

Plan and grades: [Overnight 2026-11-20 Animation Pass](../Overnight%202026-11-20%20Animation%20Pass.md) → MELEE + MODS. Everything is committed locally on main (no push). Grades are provisional until you play it.

## What changed, in one line each
- **Ruined Reaver:** every attack re-keyed as coil → ~60 ms strike that is fastest *on* the contact → braking follow-through → past the hold → settle. New hold at 0.84 size: the forearm reaches in from the lower right at the hold and on every contact. On the stock knife's own line the arm ran up the middle of the screen on contact. The idle never stops moving. It now drags on a hit like the knife and bat, and its draw and inspect lock onto the hold with a snap.
- **PopCircuit Bat:** fixed three one-frame pops (the backhand whip, a 180° roll flip, a 113° flip at the arm clamp). The swings are re-keyed so the bat points at the crosshair on contact. The idle never freezes.
- **Giltfold Fan:** the leaf moves on a smooth curve (no stop at every key), the ribs ripple out from the centre, a new move picks the leaf up where it was, and the slash flick lands on each swing's contact.
- **Stock knife:** the camera's lead roll now peaks on the contact (it was 14 ms late), and a slash cut short by a weapon switch no longer draws its streak over the new gun.
- **Camera (all melee):** each knife-slot skin leads by its own amount (Reaver and Bat a little stronger). A hit's roll now carries on from the lead roll instead of snapping it back to level (that snap happened on every melee hit).
- **Mods:** every keyed Mod move is smooth by default. That removed 15 mid-move stops: the Dash, Updraft and Stim dips, the four Dash hands, Updraft's hand, Heal and the chest orb. On the bow, the string's ring after release now starts at the snap's speed (it halved in one frame), and the drawing hand's follow-through creeps on instead of freezing.

## What to test (match place, Play)
Preview a line with the skin preview, equip the knife slot (3), then:
1. **Ruined Reaver** (preview `RuinBlighted`):
   - [ ] Idle: the blade sits like the stock knife (forearm reaching in from the lower right, blade leaning in). Is the size right? (0.84; `Config/MeleeSkins` VIEWMODEL_SCALE.)
   - [ ] Spam LMB through 1 → 2 → 3: does each slash feel like it snaps through the crosshair, not a staged wind-up?
   - [ ] RMB heavy: the coil creeps back, then a hard thrust.
   - [ ] Hit a dummy: the swing should slow for a moment on the hit (new), and the camera roll should never jump back to level.
   - [ ] Draw (switch to it) and inspect (Y): the blade locks onto the hold with a small settle. Is the lock sound on the snap?
   - [ ] The swing sounds still sit on the strike (contacts unchanged).
2. **Bat** (preview `PopCircuit`):
   - [ ] Forehand, backhand, smash: no single-frame flips or whips.
   - [ ] **Your call:** on contact the bat points into the screen, so it looks short (foreshortened). The rule that keeps the bat 65° off the forearm (`BAT_MIN_ANGLE`, from your "weird angles" note) pushes a side-on bat down. A side-on contact needs a lower limit (~50°) or a different shoulder point for the bat. I tried 50° and it made a whip, so I left it. Do you want the bat side-on at contact?
   - [ ] Idle: the bat keeps a slow sway.
3. **Fan** (preview `Giltfold`):
   - [ ] Slashes: the flick lands on each slash's contact. Does the leaf read as a wave (the ripple)?
   - [ ] Heavy, then a quick light slash: the leaf opens from where it was, no pop.
   - [ ] Inspect: no still holds in the leaf.
4. **Stock knife** (preview `Prism`, then back to `Stock`):
   - [ ] Slash, then switch to the rifle before contact: no streak over the rifle.
5. **Mods** (F8 dev panel → SetSlot):
   - [ ] Dash in all four directions and Updraft: the free hand leaves the gun smoothly (it used to jump off in one frame) and pushes through without a hitch.
   - [ ] Heal orb on yourself and thrown: no stop halfway.
   - [ ] Recon bow: draw, hold, release. Does the string snap and ring cleanly, and does the drawing hand follow through and drop?

## Evidence (summary; numbers and checker output in the plan note)
- Ruined Reaver, Before: in all four attacks the speed peak came 42-173 ms *before* contact, and the blade was at 53-67% of its peak speed on contact. After: peak on contact, 93-100% of it (`rbx-curve-easing-audit` with its new contact check: 4/4 FAIL → 4/4 PASS).
- Bat, Before: contact at 31-64% of peak speed, plus three one-frame pops. After: 100% on contact (3/3 FAIL → 3/3 PASS). Idle: a 0.65 s dead hold → none (FAIL → PASS).
- Recorded in play (Studio, `WorldToViewportPoint` per frame): the Reaver's tip crosses the crosshair ~20 ms before contact. The camera roll eases in from contact − 84 ms, peaks at 2.0° on contact and is back to level by +0.32 s, with no pop. The trail runs from contact − 94 ms to + 90 ms. The Fan's outer rib peaks ~18 ms after the inner one.

## Not verified
- How any of it *feels* at speed (your call). Hits on a real target (the drag and the hit roll) were checked in code, not on a dummy.
- The bow was traced in play (raise, draw, tremble, release kick and settle: clean). The other Mods' new splines were checked from data, not each in play.
- The stock knife streak cancel was traced in play (gone one frame after a weapon switch).

## Round 2 (after your play, 2026-11-21)
Plan and evidence: the Round 2 table under MELEE + MODS in [Overnight 2026-11-20 Animation Pass](../Overnight%202026-11-20%20Animation%20Pass.md). The Bat and Fan are now the FP lane's.

**What changed:**
- **Mods.** Every Mod was played and traced frame by frame; three pops were found and fixed:
  - After a throw, lob or chest-heal, the hand and item snapped back up in one frame. Now they stay at the end of the move until the item goes.
  - The bow hand (and every held item's hand) jumped off the gun in one frame when the item came up and when it went. Now it eases across as the gun lowers and rises.
  - A gesture's free hand jumped off the gun. Fixed last round, confirmed now.
  - Held items now sway a little more (they were nearly still). The Firewall's burning hand no longer freezes while you hold it. The held Roller is smaller and sits below and right of the crosshair (it covered it). Held items sit down in the fist end instead of perched on top. When you set the Roller or the Recall down, the one in your hand disappears at the bottom of the move (there used to be two for a moment).
- **Ruined Reaver.** The blade now keeps travelling after each slash and the heavy, and slows down gradually (the follow-through is about 2.5× longer, turning another 70-100° instead of stopping). Hit timing and sounds are unchanged.
- **Stock knife.** The idle hold never goes still (it sat nearly frozen half the time).

**What to test:**
- [ ] Dash in every direction, Updraft, Stim: the hand leaves the gun smoothly and comes back with no jump.
- [ ] Molly / Frost / Flash: throw (LMB) and lob (RMB). After the release, nothing should jump back up.
- [ ] Recon and ShockDart bows: raise, draw, release, put away (E). No snap of the bow hand when it comes up or goes.
- [ ] HealOrb on yourself and on an ally. Roller and Recall: set down and plant.
- [ ] Firewall: hold the burning hand for a few seconds. Does it feel alive (a gentle sway) without being distracting?
- [ ] Held items in general: is the new sway the right amount?
- [ ] **Your call:** with block arms (no fingers), how should an item look held? The reviewers still read the items as sitting on the arm's end. Sinking them further hides them behind the forearm.
- [ ] Throws: does the canister leave your hand when the projectile appears? (The hand releases about 0.2 s after the click; check it doesn't fly before the hand lets go.) Should the wind-up be bigger?
- [ ] Ruined Reaver: do the slashes and the heavy now carry through far enough? Is it too floaty? (It's one number to tune: the follow-through time constant, 0.09 s.)
- [ ] Stock knife idle: a slow sway, never frozen.
