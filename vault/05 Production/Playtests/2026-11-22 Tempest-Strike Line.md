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

## Round 2: the owner's katana check (2026-11-22, Rojo connected)

**Owner's verdict:** "not bad, but … visual effects could be better, the draw should be better". The inspect "twirls the katana in like a 360 without moving the hand and just looks really unnatural". Sounds are a work in progress, so they are left as they are. The other guns are not checked yet.

### Inspect
The ring-spin toss is gone, and every turn now comes from the wrist and forearm. The knife solver's check keeps the arm within 16–18° of the shoulder line (the old knife inspect was at 42°).

The new sequence:
1. The blade is laid level across the view, pointing left with its face toward you, while a water wave runs down it.
2. A slow see-saw, as if balanced.
3. A dip, then the wrist snaps the blade up tip-high in front (0° off the shoulder) for a second wave and a splash.
4. Back to the hold.

### Thrust
The thrust (Slash3) lost its spin about the blade's own length, for the same reason: a blade can't turn inside a closed fist.

### Draw
The new draw is a wheel-up:
1. The fist rises from the low right with the blade hanging point-down.
2. The forearm swings the blade up through the left as the hand climbs. It leaves an arc trail, and the surge runs guard to tip (draw 0.3–0.5).
3. It passes the hold leaning right, drops back and settles.

The ring pommel spins as the hand closes on it.

### VFX
- **New glow-band texture:** `tools/vfx/make_katana_vfx.py`, `TEMPEST_GLOW_BAND`.
- **Sheath and core:** the edge glow is now an even sheath (width 0.2–0.28) with a white-hot core line down it. The edge Neon is brighter.
- **Swing arcs:** each swing leaves a soft arc from the outer blade plus a bright arc off its last fifth, built from the symmetric glow band.
- **Motes and drips:** sparkle motes drift off the blade (more of them in a surge), and water drips from the tip.
- **Hit flare:** every hit flares the blade, the core and the lights.

## Round 3: the owner's check of the line (2026-11-22, relayed by the Blender lane)
**Owner's notes:**
- **Katana:** the effects cover the knife body, and the lighting "didn't follow the knife" (the owner likes the look).
- **Bucky and Marshal:** the reloads are "very glitchy and choppy", and the sounds don't gel.
- **Stinger:** the front loops of energy are too much and block vision.
- **Sheriff:** good.
- **Next:** Vandal sounds from the Pro Sound library.

**Changes:**
- **Katana:**
  - The sheath is slimmer (0.075–0.1, down from 0.2–0.28, against a blade 0.14 tall) and fainter.
  - Thinner core and ribbons, a weaker ForceField skin, dimmer lights and a smaller hit flare. The edge Neon is darker.
  - Motes and drips are now locked to the blade; in world space they were left behind as the view turned.
- **Bucky and Marshal:**
  - The barrel roll on Start is gone; it fought the clip's own turn into the loading pose.
  - The per-shell push track is gone, as is the second Tempest shell-in sound on every round (`shellCue = false`).
  - What remains is a small, smooth tilt on Start and a soft wrist flick on End. The water bursts per round stay.
- **Stinger:**
  - The fore-end helix is at 0.6 width and clears the sight while aiming (`adsHide`).
  - The shot ring fires every third shot and not while aiming (`pulseEvery = 3`).

