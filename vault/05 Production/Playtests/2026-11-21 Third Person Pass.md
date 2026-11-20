# 2026-11-21 Third Person Pass (overnight, lane TP)

Plan and grades: [Overnight 2026-11-20 Animation Pass](../Overnight%202026-11-20%20Animation%20Pass.md) → TP. RIVALS study: [Body, Viewmodel, Guns and VFX](../../03%20Research/Rivals%20Reference/Body,%20Viewmodel,%20Guns%20and%20VFX.md) → "Deeper read". Everything is committed locally on main (no push). Grades are provisional until you play it.

## What changed, in one line each
- **Splines everywhere it mattered:** 17 one-shots re-keyed so motion flows through the keys instead of stopping on each one. That's slides in and out (rifle, pistol, knife), rifle and pistol reload, draw, knife heavy, throw, lob, cast, heal, place, Crash Down landing and death. The rifle reload used to stop dead 5 times; now it doesn't stop at all.
- **Holds breathe:** the 12 gun holds and the knife ready pose were dead still. They now take one slow breath every 2.4 s: a small chest lean, the gun riding on the fists, the head on target.
- **Knife heavy:** the coil creeps back, the thrust brakes into the hit, carries a little past it and settles. It used to stop dead at the hit and hold.
- **Throw:** a 60 ms snap (was 50), and the pointing arm tucks in as you throw.
- **Slides:** the free hand reaches for the floor more slowly (it dived at up to 72 studs/s).
- **IK prototype (OFF):** the RIVALS way, behind a switch. Your gun is placed from where you aim and the hands are put on it by IK. Clips stay as they are until you flip it.
- **A bug I caused and fixed overnight:** for about 12 minutes your own body wasn't posed in third person (`e1119203`). It's fixed.

## What to test (match place, Play)
Best seen from another client or a Studio second player. For your own body, set the Workspace StateValue `DevThirdPerson` = true (on the Server: `require(game.ReplicatedStorage.Shared.StateValues).set(workspace, "DevThirdPerson", true)`).
1. **Holds** (front-right of a range dummy, close):
   - [ ] Does the slow breath read as alive, or is it too small to notice? (`tp_clips.py BREATH`: 0.7° lean, 0.012-stud gun rise.)
   - [ ] Rifle from the front: the two forearm blocks still stack in front of the chest. Is that acceptable?
2. **Reloads:**
   - [ ] Rifle: does it flow (no pose-to-pose stops)? Does the slap still land as a hit? The stock still comes up near the chin.
   - [ ] Pistol reload: the free hand goes to the belt, comes up outside the chest and cups the gun.
3. **Swap (draw):** the gun comes up from low right and lands with a small overshoot.
4. **Slide** in and out with each kind (rifle, pistol, knife): the body goes down in one motion, and the hand reaches the floor as you settle.
5. **Knife heavy (RMB):** creep, thrust, a little past, settle. Does it still hit hard enough?
6. **Mods from outside:** throw (Molly LMB), lob (RMB), cast (Firewall), heal, place, Crash Down landing.
7. **Death:** the body starts from the exact hold, no hand jump.
8. **IK prototype A/B:** in a Studio playtest, on the Server: `workspace:SetAttribute("TpIk", true)`, then `false`. It fades both ways. Compare:
   - [ ] Level hip and sights: IK shows the whole gun above the forearms, pointing exactly where you aim.
   - [ ] Look up and down: IK raises the right arm across the face looking up (35°) and brings the stock to the neck looking down (30°); clips handle steep pitch better.
   - [ ] Reload, sprint, slide and Mods hand back to the clips smoothly.
   - To keep it on for good: `Config/TpIk.luau` → `ENABLED = true`.

## Known, not done
- `GripController` (not in this lane): the left hand steps 0.37 studs in one frame when it re-grips after a reload, in both modes.
- Backward walk: one touchdown frame slides 0.12 studs on the left foot.
- No second client, no bot match; the re-keyed clips were measured and sampled in the engine, not watched at full speed by a human.

## Round 2 (2026-11-21, after your play)
**TpIk is back OFF; the clips are the default.** After a fix it tied or slightly beat the clips from your angle, but you saw no difference, two IK-only problems turned up (bots' aim and weapon swaps, fixed in code but not checkable without a match), and its one clear win, the head looking down at the target, is now in the clips. The `TpIk` attribute in the match place was cleared in Edit: **save the place** to keep that. Why, in full: the plan note → TP: Round 2.

What changed: every third-person Mod clip was watched in the engine from the front-right and re-keyed where it didn't read. Two kneels were found burying a knee under the floor and were rebuilt.

## What to test, Round 2 (watch another player or a bot from the front-right, or your own body with `DevThirdPerson`)
1. **Throw (Molly LMB):**
   - [ ] the wind-up shows the item up above and behind the head, the free arm pointing at the target;
   - [ ] the snap and follow-through, then a clean way back to the gun.
2. **Lob (RMB):** [ ] the arm swings down wide of the hip and up; the free arm reaches out front (not a boxer's guard).
3. **Heal:** [ ] the device goes out front-right at shoulder height, the free arm out to the side. Does it read as a heal from your angle? (From the front the thrust still comes at you.)
4. **Cast (Firewall):** [ ] the body leans into the shove.
5. **Place:** [ ] down on the crouch stance, bent over to put the item on the floor, the free hand on the knee; no knee through the floor.
6. **Crash Down:** [ ] the dive, then a three-point landing on both feet with the fist by the floor (it used to kneel with the knee buried in the floor).
7. **Dash, every direction:** [ ] a quick drop and lunge that keeps moving through the burst, springs back and settles; the gun stays near level (it used to point at the floor).
8. **Updraft:** [ ] the knees keep coming up through the launch; the gun stays level.
9. **Flinch (get hit):** [ ] a sharp jolt, not a soft ease.
10. **Looking down with a gun (hip and sights):** [ ] the head now looks down at the target with the aim.

### Known, not done (Round 2)
- Sideways and diagonal crouch walks dip a knee 0.26-0.38 under the floor mid-step. It needs a knee floor limit in the gait solver, because lifting the knee breaks the foot lock.
- The slides sink a thigh's edge about 0.4; left as is, since you liked the slides.
