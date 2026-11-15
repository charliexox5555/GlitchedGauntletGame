# First-person melee animation

**Current version (2026-11-12, night):** written by hand after the owner rejected the ChatGPT (Codex) pass. His words: "the way the arms move looks really off, and the way it spins looks off... it shouldn't move the knife or bat weirdly, like there's fingers, because there isn't. It should just be very simple." Also in [Third Person Overhaul](../../01%20Design/Third%20Person%20Overhaul.md) §9.

**Update (2026-11-12, later):** the knife's fist uses `VM.MELEE_HAND` again (the ChatGPT pass had swapped in the rifle hand, so the knife sat above the fist). The bat is on splines through its keys plus follow-through springs instead of per-segment easing (which stopped at every key: "robotic"). Measured smooth: the largest change of the tip's step between frames is 2.5 studs in a swing (at the strike), 0.48 in the smash, 0.21 in the inspect. See [Third Person Overhaul](../../01%20Design/Third%20Person%20Overhaul.md) §11.

**Update (2026-11-12, later still):** from a Valorant melee video study, the weapon now stays across the fist through every swing (bat: at least 65 degrees from the forearm; knife: 62), and the bat's swings are diagonals (forehand high right to low left, backhand low left to high right). Pressing inspect again restarts it. See [Third Person Overhaul](../../01%20Design/Third%20Person%20Overhaul.md) §12.

## Rules
- **The fist is a block.** The weapon sits rigid in it at one grip point and never slides, rolls or turns in the hand.
- **The arm runs from the fist straight to its shoulder** (`VM.MELEE_SHOULDER`; bat `RIGHT_SHOULDER` / `LEFT_SHOULDER`).
- **A few hand-placed keys per move, eased between them:**
  - the windup eases out into the coil;
  - the strike leaves the coil fast and eases out after contact;
  - then follow-through and a slower settle.
  - No baked samples.
- **Swings travel on arcs** (a middle key), and the bat is flat across the view at contact.

## Knife (stock)
- Back to the hold from before the ChatGPT pass: `holdWith` with the shoulder override.
- ChatGPT's `ViewmodelArms.grip` (it turned the forearm off the handle axis) and its -0.04 grip offset are removed.
- The tracks are unchanged (`Config/Viewmodel` Slash1-3, HeavyStab, Inspect).

## PopCircuit Bat (`src/client/Util/PopCircuitBat.luau`)
- **Space:** the viewmodel frame (camera plus bob and sway). The bat's pivot is its Handle, its axis -Z, and the right fist grips 0.27 up the handle.
- **Idle:** the fist is low right and the bat leans out to the right and away, so the handle crosses the fist with the knob below it. It breathes slowly.
- **SlashLeft / SlashRight** (alternating, 0.5 s, contact at 30%):
  - cocked back over one shoulder;
  - a flat sweep through the crosshair;
  - wrap round, then settle back to idle.
- **Smash** (heavy, 0.9 s, contact at 44%):
  - both fists on the handle (left below right);
  - raised up and out of the top of the view, with a held beat;
  - straight down the centre line and through.
- **Inspect** (2.8 s):
  - turn the bat across the view to show its art;
  - dip;
  - flick: the bat leaves the hand and flies a parabola, spinning once end over end about its centre of mass (1.35 up the handle);
  - the hand waits under it and catches;
  - absorb the weight, settle to idle.
- **Draw** (pull-out, 0.55 s at speed 1, fitted to the equip time): up from low right, barrel leading, a touch past the idle, settle.
- **Trail:** on between 18% and 42% of a slash (34% to 52% of the smash).
- **Studio review:** the Workspace attribute `DevBatScrub` (0..1) holds the current move at that point. Use it with DevAction "fire" / "inspect" and DevHeavy.
- **Removed:** `PopCircuitBatPoses.luau` (ChatGPT's 48 fps samples; `tools/blender/sample_popcircuit_bat.py` can rebuild them if ever wanted).

## Knife-slot skins (2026-11-14)
- **Giltfold Fan** (`src/client/Util/FanMotion.luau`, numbers in `Config/MeleeSkins.FAN`): the stock knife tracks move the fist and the fan; FanMotion only opens and closes the leaf by writing the rib Motor6Ds' Transform (read by `ViewmodelRig.solve`; stepped right after the gun's GunAnimator). Draw: up shut, spreads open (Blender Fan_Open, overshoot and settle). Slash: small fold on the windup, flick past open at contact. Heavy: shut for the thrust (Fan_Close), reopens on the recovery. Inspect: shut and reopen, then two fanning pulses. First-person size 0.8 (`MeleeSkins.VIEWMODEL_SCALE`, by the variant's `SkinItem`). Studio scrub: `Workspace.DevFanScrub` (0..1).
- **Inkshift Blade:** stock moves; measured clear of the camera (closest 0.46 studs).
- **Sealwork and Moltframe daggers:** stock moves; hold checked.

## Checked
In a Studio playtest with the PopCircuit line, frames held with `DevBatScrub`: the idle, the backhand coil, the forehand contact and the toss at mid-flight (the bat upside down above the waiting hand).

**Not checked in motion:** the swings and the inspect at full speed (only held frames); the smash after its coil was raised (that change wasn't re-captured). The owner should play the inspect (Y) and a few swings.

## References
- LihFolk: [Weapon Swing Design](../../LihFolk/08%20Animation/03%20Authoring/Weapon%20Swing%20Design.md), [Timing Spacing and Frame Charts](../../LihFolk/08%20Animation/03%20Authoring/Timing%20Spacing%20and%20Frame%20Charts.md), [First-Person Viewmodels](../../LihFolk/08%20Animation/05%20Systems/First-Person%20Viewmodels%20-%20Arms%20Rig%2C%20Sway%20and%20Camera%20Binding.md), *Procedural Weapon Motion* (a spin about a pivot, a toss as a parabola).
- DevForum: [flipping tool animation](https://devforum.roblox.com/t/how-to-do-a-flipping-tool-animation/307169) (flip, spin in the air, catch).
- [Gunplay Feel Pass 3](../../05%20Production/Playtests/2026-11-12%20Gunplay%20Feel%20Pass%203.md) (the knife's earlier pass).
