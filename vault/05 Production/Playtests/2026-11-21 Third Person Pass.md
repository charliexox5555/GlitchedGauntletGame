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
6. **Mods from outside:** throw (Molly LMB), lob (RMB), cast (Firewall), heal, place, Crash Down landing. Known: on cast a forearm passes through the chest for a few frames.
7. **Death:** the body starts from the exact hold, no hand jump.
8. **IK prototype A/B:** in a Studio playtest, on the Server: `workspace:SetAttribute("TpIk", true)`, then `false`. It fades both ways. Compare:
   - [ ] Level hip and sights: IK shows the whole gun above the forearms, pointing exactly where you aim.
   - [ ] Look up and down: IK raises the right arm across the face looking up (35°) and brings the stock to the neck looking down (30°); clips handle steep pitch better.
   - [ ] Reload, sprint, slide and Mods hand back to the clips smoothly.
   - To keep it on for good: `Config/TpIk.luau` → `ENABLED = true`.

## Known, not done
- `GripController` (not in this lane): the left hand steps 0.37 studs in one frame when it re-grips after a reload, in both modes.
- Backward walk: one touchdown frame slides 0.12 studs on the left foot.
- Cast: a forearm passes through the chest on 6 frames.
- No second client, no bot match; the re-keyed clips were measured and sampled in the engine, not watched at full speed by a human.
