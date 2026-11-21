# Tempest-Strike Kunai-Katana (melee): owner concept

2026-11-22. The owner's knife concept for the Tempest-Strike line (brief pasted in chat plus a model sheet image). **Image:** save the owner's sheet as `refs/style/Tempest-Strike Kunai-Katana Reference.png` (owner to drop it in; the description below covers it until then).

**Owner's rule for the brief:** it is direction, not a spec. Build VFX, animation and sound the way the Vandal was built (our VFX skills, Studio runtime, our own textures and motion rules), and make it look good once in Studio.

## The design (from the sheet)
- **Physical kunai core** (always visible): matte-black kunai blade, leaf/diamond-shaped with a raised centre spine and **brushed-silver bevelled edges**; an etched lightning crack along the spine (top detail). Round **disc guard** in steel/silver. **Leather grip** (brown) with a **diamond-wrap** pattern (cross-wrapped bands showing diamond windows). Steel collar, then a large **ring pommel** (shinobi ring, steel).
- **Hydro-katana extension**: a long, thin, translucent cyan **water blade** that extends forward from the kunai tip, roughly three times the kunai blade's length, with a slight katana curve and a sharp tip. Laminar water ribbons spiral round it from the guard to the tip, and thin white lightning arcs run along it.
- **Sheet palette**: matte black 1C1E22, brushed silver 4E525A, dark indigo 1B1236, leather brown 7F4E30, a darker leather/black (value unreadable on the sheet), steel 6B7280, cyan glow 40F5D4, electric white E2FEFE, storm blue 1D2A44. The sheet quotes 2,140 triangles for the base model.

## How it plays (direction)
- **Two forms, toggled with Inspect**: Form A compact kunai (fast reverse-grip shinobi stance, quick jabs); Form B extended water katana (one-handed sword stance). Inspect toggles: kunai to katana = toss, catch mid-spin, wrist thrust, the blade extrudes with a pressurised whoosh and a lightning flash; katana to kunai = spin the hilt, snap, the water blade shatters into falling droplets.
- **Draw**: twirl by the pommel ring on the index finger, snap to a forward grip, water spirals down and lights the edge.
- **Idle**: held low and angled across the screen, minimal obstruction; water ribbons flow guard to tip, hair-thin arcs flicker along the spine every couple of seconds.
- **Light combo** (3 hits): diagonal slash (upper right to lower left) with a thin crescent water arc and sparks; reverse backhand sweep; pommel-spin forward thrust.
- **Heavy (Storm Cleave)**: 0.35 s iaijutsu draw-back to the hip while the blade surges with white lightning, then a 0.1 s horizontal flash-slash with a wide crescent hydro-lightning arc and a thunderclap.
- **Impacts**: crisp water droplets, a brief electric-blue spark flash.
- **Sound**: equip = clean steel ring "ting-shing" plus a pressurised water splash; light swings = razor air cuts with water-whip snaps (no clunky clangs); heavy = katana draw ring, tight thunder crack, water surge; transform = liquid surge + electric hum (extend), crystalline water-shatter chime (retract); impact = surgical slice "shhk" + static zap + splash.
- **Chromas** (later): Storm Shadow (base), Amethyst Gale (obsidian, royal-purple water, violet arcs), Mist Ivory (porcelain white and silver, seafoam water), Midnight Eclipse (blackout alloy, electric-white veins).

## Split of work
- **Blender (now, [Line Blender Handoff](Line%20Blender%20Handoff.md))**: the kunai core and the water-blade mesh, rigged for the extension.
- **Studio (later, Vandal session)**: two-form toggle, stances, draw / idle / combo / heavy / inspect tracks, water and lightning VFX (our runtime: water coat, ribbons, arcs, rings), sounds, chromas. Gameplay effects of the two forms (reach, speed) need a design decision first; until then the toggle is cosmetic.
