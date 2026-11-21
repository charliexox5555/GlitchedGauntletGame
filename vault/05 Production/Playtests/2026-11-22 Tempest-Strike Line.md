# Playtest 2026-11-22: Tempest-Strike line (owner)

The owner's first play of the line after the Studio port. Everything below was built in Edit mode with no playtest (the map lane was using Studio). The owner checks it next.

## Owner's notes and what was done

### Vandal
- **Note:** "Already reviewed, good."
- **Done:** no change.

### Stinger
- **Note:** the VFX doesn't sit flush with the gun.
  - **Done:** all four guns refitted from a measured outline. Each gun was ray-cast in Blender every 0.05 along the bore.
  - The water helix, the draw and inspect rings, the sweep and the shot pulse now follow those stations.
  - New `fit` profiles: see `Config/TempestProfiles` and `TempestIdle` `hull()`.
- **Note:** the odd moving or opening part when shooting.
  - **Done:** the vent flaps are no longer driven.
  - In s03x the Blender lane dropped the vent bones and made the vents fixed plates.
- **Note:** a glitching part of the action.
  - **Done:** the Blender lane fixed the bolt in s03x (6,170 tris).
  - Uploaded and installed (asset 122767468165673, MatchSkins row 342).
- **Note:** the reload makes the hand move unnaturally.
  - **Done:** new `ReloadTempestStinger`, with half the tilt and roll of the Vandal's and no yaw swing.
  - The off hand on the mag stays in its range.
- **Done (fit):** an own inspect roll pivot (`InspectTempestStinger`), so the gun turns inside its ring.

### Marshal
- **Note:** the VFX doesn't sit flush.
  - **Done:** refit. The helix now wraps the barrel and tube stack (it was 4 cm high).
  - Its own inspect pivot.
- **Note:** a custom cock-back.
  - **Done:** `CycleTempestMarshal` over every shot's lever cycle.
  - The gun rolls out and dips as the lever swings down, then snaps back past the hold.
- **Note:** a custom reload.
  - **Done:** shell-by-shell tracks.
  - Start: a barrel roll into the side-gate pose.
  - Insert: a thumb push on each round, with a water burst at the gate.
  - End: a wrist flick with a water lock splash (`TempestIdle.beat "Settle"`).

### Bucky
- **Note:** a custom reload that fits the theme.
  - **Done:** the same shell-by-shell set: roll into the loading pose, a push per shell, a flick back.
  - Refit, plus its own inspect pivot.

### Sheriff
- **Note:** the VFX doesn't sit flush.
  - **Done:** refit. The helix now covers the barrel and underlug only.
- **Note:** the inspect looks unnatural or impossible.
  - **Done:** new `InspectTempestSheriff`, with no toss and every turn in a wrist's range:
    1. right side, then the top;
    2. rolled toward you as its clip swings the cylinder out, with a water ring round the open cylinder;
    3. a wrist flick shuts it.
- **Note:** a new reload that fits the theme.
  - **Done:** `ReloadTempestSheriff` on the clip's own beats:
    1. lift as the cylinder opens;
    2. a jolt as the cases eject;
    3. turn to the loader and push as the rounds seat;
    4. a flick shut.

### Knife
- **Note:** the worst of the line. The VFX doesn't line up with the blade; it needs more light, "like a lightsaber with the blade over the whole thing … more like a katana."
  - **Done:** the kunai is gone. It was rebuilt as the **Tempest-Strike Katana** from the owner's sheet.
  - Blender lane: s05x, 3.97 studs long, 3,080 tris, 9/10 ([Line Build Ledger](../../02%20Art/Skins/TempestStrike/Line%20Build%20Ledger.md)).
  - Uploaded and installed (asset 120180022604213, MatchSkins row 346).
  - New runtime `Util/TempestKatana`:
    - the edge burns as Neon water under a ForceField skin;
    - a glowing sheath runs over the edge from guard to tip;
    - two laminar ribbons, spine lightning, two lights;
    - full-blade crescent trails with a static edge;
    - the Cleave flares white, then throws a wide crescent;
    - a draw surge, an inspect wave, and a charm that swings from the ring.
  - All of it is placed from the blade's measured stations.
- **Note:** custom swinging, inspect and draw.
  - **Done:** new screen tracks `KatanaDraw`, `KatanaSlash1-3`, `KatanaHeavyStab` and `KatanaInspect`, solved by `tools/studio/knife_fp_keys.py`:
    - **Draw:** an iaijutsu rising flash cut from the left hip; the ring spins once into the palm.
    - **Slash1:** a diagonal down cut.
    - **Slash2:** a rising backhand.
    - **Slash3:** a spinning forward thrust.
    - **Heavy (Tempest Cleave):** a hip draw-back, then a flat flash-cut.
    - **Inspect:** two spins by the ring pommel, the blade laid level with the spine to you while a wave runs down it, then back.
  - Lengths and hit times match the knife's (server timing unchanged).
  - **Reference clips:** inspect and slashes from video 1; the raised forward grip from video 2 (the knife's hold already matches it).

## To check (owner)
1. **Reconnect Rojo** in Studio. The code is in the repo, not yet in Studio. The Stinger s03 and Katana s05 models are installed in Studio already.
2. Save the match place when the map lane is done.
3. In play:
   - the ring and pulse fit on all four guns;
   - Stinger: the reload hand, and the action;
   - Marshal: the lever cycle;
   - Bucky and Marshal: the shell reloads;
   - Sheriff: the reload and inspect;
   - Katana: the look, draw, combo, heavy and inspect.
4. **Katana sizing:** about 4 studs long. Check it in third person too.

## Not done
- **Katana impacts** (cyan droplets plus a static slash mark on hit): the knife still uses the shared melee impact.
- **Katana sounds:** they reuse the `tempest:` foley cues. The owner designs the sounds.
- **Chromas:** none yet.
