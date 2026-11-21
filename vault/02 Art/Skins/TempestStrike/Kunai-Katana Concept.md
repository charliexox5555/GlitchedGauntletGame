# Tempest-Strike Katana (melee): owner concept

**2026-11-22 redesign.** After the playtest the owner dropped the kunai: "honestly maybe get rid of the kunai and make a new one … like a katana". The new sheet is at `refs/style/Tempest-Strike Katana Reference.jpg` ("TEMPEST-STRIKE KATANA").

The owner's verdict on the kunai build (s04x): it was the worst of the line. The VFX didn't line up with the blade, and it needed more light: "it should look like a lightsaber with the blade over the whole thing and look much better more like a katana."

**Owner's rule for the brief:** treat it as direction, not a spec. Build the VFX, animation and sound the way the Vandal was built: our VFX skills, the Studio runtime, our own textures and motion rules.

## The design (from the katana sheet)
- **Blade:**
  - a curved, single-edged katana blade, about 4.2–4.5 studs overall;
  - matte-black body, brushed-silver spine and bevel;
  - a translucent glowing cyan **water cutting edge** along the whole length, brightest near the tip and along the fuller;
  - an etched lightning line on the spine.
- **Hilt:**
  - crescent **tsuba** (steel);
  - dark-brown leather **diamond-wrapped tsuka** (cross-wrapped bands with diamond windows);
  - steel collar;
  - CNC **shinobi ring pommel**;
  - a small **shuriken charm** hanging from the ring.
- **Palette:**
  - matte black 1C1E23
  - brushed silver (about 4E525A)
  - dark indigo 181E30
  - leather brown 7F4E30
  - cyan glow (about 40F5D4)
  - electric white E3FEFE
  - storm blue 1D2544
- The sheet quotes about 2,140 tris.
- **Chromas (later):**
  - Storm Shadow (base)
  - Amethyst Gale
  - Mist Ivory
  - Midnight Eclipse

## How it plays (direction)
- **One form** (no kunai toggle).
- **Equip:** an iaijutsu flash-draw. The pommel ring spins once into the palm, and a water/spark surge runs from guard to tip.
- **Idle:** held low, angled across the right side, crosshair clear. Water ribbons run from guard to tip, and hair-thin arcs flicker on the spine.
- **Light combo** (3 hits):
  1. a diagonal down cut;
  2. a rising backhand;
  3. a spinning forward thrust.

  Each cut leaves a crescent wave of water and static.
- **Heavy (Tempest Cleave):** a hip draw-back as the blade flares white-cyan, then a horizontal flash-slash with a wide crescent wave.
- **Inspect:**
  1. spin by the pommel ring;
  2. balance the flat of the blade horizontally;
  3. run two fingers along the spine, sending a water-and-lightning wave down it;
  4. snap back.
- **Impacts:** cyan droplets plus a static slash mark.
- **Sound:** equip, swings, heavy, inspect, impact. The owner designs the sounds and auditions them.

## Reference videos (owner, 2026-11-22)
- **Video 1** (long curved sword, gold with a cyan energy edge). The owner likes its **inspect and slashes**:
  - The blade is held low across the bottom of the screen, pointing left.
  - Inspect: the blade turns flat across the view, the off hand comes in under it with open fingers, and the blade turns tip-up near the face, then settles back.
  - Slashes leave a thin, bright crescent arc on screen (one clean stroke, no smoke).
- **Video 2** (shorter blade). The owner prefers its **holding**:
  - a forward grip on the right, with the blade rising up and forward at about 60°, edge glowing the whole length;
  - a two-handed cut that brings both forearms through the view;
  - a horizontal presentation of the blade across the screen.
- **Our pick:**
  - idle and draw use video 2's raised forward grip, kept low enough to leave the crosshair clear;
  - inspect and combo arcs follow video 1;
  - all of it is built in our own art and motion (study, don't copy).

## Split of work
- **Blender:** the katana model and rig, in the [Line Blender Handoff](Line%20Blender%20Handoff.md) pipeline, plus the blade stations for the runtime. Done by the Blender lane session.
- **Studio (Vandal session):**
  - draw, idle, combo, heavy and inspect tracks (`Config/Viewmodel` screen tracks, solved by `tools/studio/knife_fp_keys.py`);
  - the blade VFX in `Util/TempestKunai` (rewritten for the katana);
  - the install (MatchSkins row 346).
