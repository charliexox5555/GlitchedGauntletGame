# Weapon RemasterV2 (fresh weapon art rebuild, 2026-11-07)

Opus rebuilds the 17 guns and the Knife (no Akimbo) in Blender through **live Blender MCP only** (the visible interactive session; no background Blender). The brief is [Astra Weapon Rebuild Handoff](Astra%20Weapon%20Rebuild%20Handoff%202026-11-07.md). The first Codex remaster stays rejected (`art-source/weapons/Remaster/`); originals and `GunTest.blend` are untouched. Nothing here is imported into Studio, exported or committed yet.

**Review gate changed by the user (2026-11-07, mid-session):** "You don't need my requesting for review… grade it yourself. And if you think it's good, you move on to the next weapon." So each weapon is self-graded against the handoff's checkpoints and the next one starts; the user reviews the set later. Order: Vandal (pilot) → Classic → the rest of the roster (below).

## Method (shared by every weapon)
- Each weapon builds into its **own scene** (`<Id>_RemasterV2_Review`) with independent data; the user's unsaved `Scene` (Cube/Light/Camera) is never touched. The `.blend` is written with `bpy.data.libraries.write` (only that scene's data), so the live session keeps no file path and nothing of the user's is saved or changed.
- Fresh library `art-source/weapons/RemasterV2/_Library/`: `v2kit.py` (profile × section intersections, chamfer helpers, exact booleans, hidden-face cull between closed pieces, the 7 shared material roles `Body Panel Dark Metal Grip Accent Neon`, rig/locator helpers), `review_stage.py` (neutral studio lights, flat grey world, review cameras, an ADS range with targets), `contact_sheet.py` (Pillow, not Blender). Not derived from the rejected `remaster.py`.
- **ADS camera = the game's eye:** `adsDistance / Viewmodel.SCALE` behind `AimPoint`, `adsFov` vertical, clip `0.1/0.75`. Parts the game fades in ADS (`ADS_FADE_PREFIXES`, rule copied from `ViewmodelController.findNearPlaneParts`) are hidden in that render only; nothing else.
- Original actions are copied onto the new rig (same bone names, axes and rest orientation), so the clip contract carries over; reload clearance is checked from frames.
- Locks: `.claude-locks/blender.lock` held by this session while modelling.

## Vandal v01: done, self-graded 7.5 / 10 (moved on)
Files (`art-source/weapons/RemasterV2/Vandal/`): `Vandal_RemasterV2_v01.blend` (scene `Vandal_RemasterV2_Review`), builder `build_vandal_v2.py`, `anim_vandal_v2.py`, `review_vandal_v2.py`, renders in `renders/` (final `v01_*`, checkpoints in `renders/checkpoints/`).
- Review sheet: [Vandal_v01_review_sheet.png](../../art-source/weapons/RemasterV2/Vandal/Vandal_v01_review_sheet.png), original vs rebuild at the same lights/cameras: [Vandal_v01_vs_original.png](../../art-source/weapons/RemasterV2/Vandal/Vandal_v01_vs_original.png).

**What changed against the concept and the old model**
- Same identity and length (muzzle 2.647 → buttpad −1.252, 3.90 studs; bore z 0.285; sight line z 0.5598). Thicker everywhere: receiver half-width 0.072 → 0.092, handguard 0.075 → 0.098, grip 0.052 → 0.064, mag 0.047 → 0.058, stock 0.058 → 0.068, with chamfered sections (octagonal handguard, stepped dust cover shoulder).
- **Magazine and well designed together:** a well with a flared mouth lip and a rear step, cavity 0.004 bigger than the mag, a catch paddle whose hook rests on a lug on the mag, a top round that is only seen with the mag out. Reload frames 13/15/17: the mag leaves cleanly (MagOut 15).
- **Charging:** a channel cut in the left receiver with a carrier and an anodised knob; the full −0.25 retract (ReloadEmpty f82) stays inside the channel. Bolt visible through a chamfered port with a deflector (right).
- **Trigger** is its own part in a slotted housing plate with 0.024 clearance to the guard; **selector** lever with an accent tip.
- **Charm eyelet:** an integral tab on the trunnion's left side, two screws, a 0.031 hole that sits below the receiver, so a hook clears it. `Charm` bone and `CharmPoint` moved to the hole (0.93, 0.1005, 0.148).
- **Sights:** rear 12-sided open ring (r 0.066 / 0.05) on a short stem between two low ears; front: a thin post whose tip is exactly on the sight line, inside a deep ring hood on a tapered A-frame tower (the old thin stick is gone). ADS at the game eye: open window, post centred on the target, receiver below the window.
- **Materials:** graphite coated body, lighter inset panels, dark polymer, satin steel with a faint brushed roughness, stippled grip panels, steel-blue accent controls, the concept's blue neon (separate meshes). No grime or noise.

**Contract kept:** grip origin, +X/+Z/+Y axes, 1 unit = 1 stud; bones Root/Mag/ChargingHandle/Bolt/Trigger/FireSelector/Flash/Charm with the original heads (Charm moved); locators `Vandal_Muzzle/RightGrip/LeftGrip/AimPoint/Eject/CharmPoint` + new `Vandal_Socket_Muzzle/Optic/Under`; Actions `Vandal_Fire/Reload/ReloadEmpty/Draw/Inspect` (24 fps, 12/97/97/36/67, `gg_markers` MagOut 15 / MagIn 30, semantic NLA tracks). **4,885 tris** (≤ 5K; the original was 5,240). One UV atlas, all islands in 0–1, uniform texel density on every part (0.261 UV/stud), 43 % packing.

**Self-grade 7.5 / 10.** Strong: thickness, the well/catch junction, the sight picture, the charm tab, clean material separation, budget. Weaker: medium-detail density is still close to the original (handguard and barrel group are plain), the muzzle brake is simple, and the concept's mono-dark finish leaves little tonal "life".

**Not done (honest):** UVs are an automatic smart-project (no hand-placed seams) and no baked texture set yet; actions are the original clips, not re-timed to the new parts (the mag path and handle travel were checked, the Draw/Inspect clips were not reviewed frame by frame); the held view is approximate (viewmodel offset only, no arms, no sway); no export, no Studio build, nothing committed.

## Classic v01: done, self-graded 7.5 / 10 (moved on)
Files (`art-source/weapons/RemasterV2/Classic/`): `Classic_RemasterV2_v01.blend`, `build_classic_v2.py`, `review_classic_v2.py`, renders in `renders/`. Review sheet: [Classic_v01_review_sheet.png](../../art-source/weapons/RemasterV2/Classic/Classic_v01_review_sheet.png); original vs rebuild: [Classic_v01_vs_original.png](../../art-source/weapons/RemasterV2/Classic/Classic_v01_vs_original.png).
- From the concept sheet (`02 Art/References/Gun-Image-Concepts/Classic Pistol Two-View Concept Sheet.png`), at the original length (slide rear −0.267 → muzzle 1.0005) and bore (z 0.3654). Thicker: slide half-width 0.062 → 0.070, frame 0.065 → 0.072, grip 0.057 → 0.066.
- Slide: big top chamfers, edge breaks sized for the held distance (LihFolk: about d/520), six deep forward-leaning rear serrations, front seam, open-top port that shows the barrel hood (and re-exposes it with the slide back), a sight groove along the top, a recessed rear plate.
- **Sights (no ADS on the Classic):** square-notch rear and a post front with three neon dots facing the shooter; the held view (SIDEARM_VM / SIDEARM_SCALE, FOV 80) reads front dot between the rear dots.
- Narrow trigger guard (half-width 0.034) with a free trigger and an accent safety tab (0.028 clearance below, pull clears the guard); ribbed accent mag release on the grip; slide catch with thumb ridge; takedown and trigger pins; rail grooves and a cross slot.
- Grip leans back like the concept (the first blockout had it leaning the wrong way, caught at checkpoint 1), stippled side panels, a **hollow magazine well with a flared rim** (added after the reload frame showed a solid grip). Steel magazine with a top round, two-tier base plate with neon.
- Charm: a sideways tab with a vertical through-hole, a base plate on the frame and a gusset (the first version, a block with a fore-aft hole, didn't read); `Charm`/`CharmPoint` at the hole (−0.2125, 0.094, 0.2235).
- Contract: bones Root/Slide/Barrel/Mag/Trigger/SlideCatch/MagRelease/Flash/Charm (original heads, Charm moved), locators `Classic_Muzzle` (Barrel), `RightGrip`, `LeftGrip` (0, 0, −0.08), `Eject` (Slide), `CharmPoint` + `Socket_Muzzle/Optic/Under`; the original 6 clips (Fire, DryFire, Reload, ReloadEmpty, Draw, Inspect; MagOut 12 / MagIn 24). **2,244 tris** (≤ 3K; original 2,048). One atlas, uniform density 0.389 UV/stud, 52 % packing.

**Self-grade 7.5 / 10.** Strong: held-view readability, the sight picture, port/hood, controls, grip/well. Weaker: the frame's long flat sides and the slide's left face are still plain next to the concept's subtle steps; the grip has no palm swell.
**Not done:** same as the Vandal (auto UVs, no bake, original clips not re-timed, no arms in the held view, nothing exported).

## Ghost v01: done, self-graded 7.5 / 10 (moved on)
Files (`art-source/weapons/RemasterV2/Ghost/`): `Ghost_RemasterV2_v01.blend`, `build_ghost_v2.py`, renders; [review sheet](../../art-source/weapons/RemasterV2/Ghost/Ghost_v01_review_sheet.png), [vs original](../../art-source/weapons/RemasterV2/Ghost/Ghost_v01_vs_original.png). Built on the new shared driver (`_Library/v2build.py`, `review_generic.py`: auto-framed cameras, held/ADS cameras from the weapon config, original comparison).
- Same length (slide −0.213 → 1.126, suppressor to the Muzzle at 2.054, bore 0.2964). Thicker: slide 0.059 → 0.066, frame 0.052 → 0.062, grip → 0.064.
- Slide: the concept's neon double slash (inset), seven rear serrations, open-top port with hood, sight groove, rear plate, 3-dot sights. Frame: rail grooves + cross slot, guard with three finger grooves on its front, slide catch + takedown lever side by side, ribbed release, hollow mag well, two-tier flush base plate. Hanging charm tab under the dust cover (hole across Y, two screws), `CharmPoint` (0.86, 0.067, 0.14).
- Suppressor fixed to the frame (never moves with the slide): stepped rear neck, thread collar, satin seam band, chamfered closed end cap with face ring and bore (the first pass's recessed-face cut opened the cap into a pipe; fixed).
- **Fixed from the original:** its trigger tip passed through the guard bottom; now 0.03 clearance.
- Contract: original bone heads (Charm moved), locators incl. `Eject` on Slide, clips Fire/Reload/ReloadEmpty/Draw/Inspect (MagOut 12 / MagIn 24, slide lock −0.13). **2,868 tris** (≤ 3K; original 2,412). UV density 0.364, 50 % packing.
- **Self-grade 7.5 / 10.** Weaker: the suppressor is a plain tube by design (concept), slide left face plain apart from the slash.

## Sheriff v01: done, self-graded 7 / 10 (moved on)
Files (`art-source/weapons/RemasterV2/Sheriff/`): `Sheriff_RemasterV2_v01.blend`, `build_sheriff_v2.py`; [review sheet](../../art-source/weapons/RemasterV2/Sheriff/Sheriff_v01_review_sheet.png), [vs original](../../art-source/weapons/RemasterV2/Sheriff/Sheriff_v01_vs_original.png).
- Revolver contract kept exactly: muzzle 1.495, bore 0.2782, cylinder axis z 0.1898 (x 0.3172–0.6292, r 0.143, chambers on r 0.088, chamber 1 = bore), crane hinge (0.6292, 0.04, 0.026), bones Root/Crane/Cylinder/EjectorRod/Rounds/Speedloader/Hammer/Trigger/CylinderRelease/Flash/Charm, locators CylinderAxis, Chamber_01..06, EjectorReference, ReloadInsertPoint, no Eject.
- Frame with a real window round the cylinder and a hammer slot, stepped shoulder where the barrel enters, octagonal barrel with crowned bore and the concept's stepped underlug; fluted cylinder (six flutes, chamber mouths, rear chambers holding the case heads), serrated hammer spur, round accent release in a surround, rounder guard with trigger clearance (the original's tip sat 0.006 above the guard), checkered grip panels, hanging charm tab under the front block.
- Sights: front blade with a neon insert on its top and upper rear face (first pass buried it inside the blade; caught on the sight-line render), rear notch with two dots.
- Reload checked from frames: crane swings the cylinder out left, ejector rod out, rounds leave, speedloader comes in. **2,886 tris** (the original was over budget at 3,432). UV density 0.41, 52 % packing.
- **Self-grade 7 / 10.** Weaker: frame sides plain (no sideplate seam), grip blockier than the concept's sculpted one.

**Rig fix applied to every rebuild (found on the Sheriff):** the rebuilt pose bones defaulted to quaternion rotation, so the copied clips' `rotation_euler` keys (crane swing, cylinder index, hammer, trigger pull, mag tilt, charm sway) did nothing. The kit now sets Euler XYZ like the originals; Vandal, Classic and Ghost were fixed in the live scenes and their `.blend` files re-written.

## Shorty v01: done, self-graded 7 / 10 (moved on)
Files (`art-source/weapons/RemasterV2/Shorty/`): `Shorty_RemasterV2_v01.blend`, `build_shorty_v2.py`; [review sheet](../../art-source/weapons/RemasterV2/Shorty/Shorty_v01_review_sheet.png), [vs original](../../art-source/weapons/RemasterV2/Shorty/Shorty_v01_vs_original.png).
- **Layout kept side-by-side** (the user's round-2 call and the rig: "Upper" = left barrel, fires first), with the concept sheet's finish: a chamfered barrel housing with ringed muzzles standing proud, rib valley + front post, breech band with two chambers, textured fore-end, round hinge caps, windowed latch, side panel recess, grip with stippled panels, neon strips and a base cap.
- Contract: muzzles x 1.4482 at y ±0.05, bore 0.26, hinge (0.546, 0, 0.1144), bones/locators as the original (Charm moved to a rear-left tab with a vertical hole). Trigger clearance fixed (original tip sat 0.008 above the guard). Break-open checked: barrels drop, empty chambers show, shells return.
- Sights: rear notch with two dots, front post with a dot (added after the first sight-line render showed only the rear pair). **2,484 tris** (≤ 3K; original 2,426).
- **Self-grade 7 / 10.** Weaker: side-by-side reads less like the concept's stacked look (by design); grip still a simple slab.

## Phantom v01: done, self-graded 7.5 / 10 (moved on)
Files (`art-source/weapons/RemasterV2/Phantom/`): `Phantom_RemasterV2_v01.blend`, `build_phantom_v2.py`; [review sheet](../../art-source/weapons/RemasterV2/Phantom/Phantom_v01_review_sheet.png), [vs original](../../art-source/weapons/RemasterV2/Phantom/Phantom_v01_vs_original.png).
- Same length and datums (Muzzle 2.5024, buttpad −1.098, bore 0.352, AimPoint 0.1536/0.5784, LeftGrip on the handguard). Thicker: upper 0.068 → 0.084, lower 0.064 → 0.08, handguard 0.072 → 0.088, grip → 0.062, mag 0.042 → 0.054, stock → 0.066.
- Flared magwell (cavity 0.004 bigger than the mag, front ridges, accent release on the right, neon square), straight mag with ribs, base plate and a top round; charging channel (measured travel −0.17 stays inside it); port with deflector and bolt; side recess panels; bolt catch; selector with accent tip; textured stippled grip panels; trigger clearance fixed (the original's tip went below the guard bar's top).
- Rear ring on a base with ears, front post inside a hood on a tapered tower; ADS at the game eye (0.42/0.75 behind AimPoint, FOV 68): open window, post on the target, stock faded by the game's rule.
- Suppressor: front section with chamfered closed cap + face ring + bore, rear section, satin seam band, mount collar. Hanging charm tab under the lower's front. **4,212 tris** (≤ 5K; original 5,012).
- **Self-grade 7.5 / 10.** Weaker: the stock is a plain wedge with an inset; the receiver language is close to the Vandal's (fine for a companion gun, less distinct).

## Bulldog v01: done, self-graded 7 / 10 (moved on)
Files (`art-source/weapons/RemasterV2/Bulldog/`): `Bulldog_RemasterV2_v01.blend`, `build_bulldog_v2.py`; [review sheet](../../art-source/weapons/RemasterV2/Bulldog/Bulldog_v01_review_sheet.png), [vs original](../../art-source/weapons/RemasterV2/Bulldog/Bulldog_v01_vs_original.png).
- Bullpup contract kept (Muzzle 1.4378, buttpad −1.4586, bore 0.3614, AimPoint −0.1976/0.5838 with the ring on a tall post, front post 0.8736, LeftGrip on the lower handguard, port behind the grip, forward side charging handle racking −0.2 inside its channel).
- Thicker shell/handguard/stock/grip/mag; faceted shell with slot pair, front plate, raised side plate with two neon bars, textured lower handguard, flash hider with vents and collar, stock magwell with cavity and flared lip, ribbed mag with base and top round, sling slot, grooved buttpad, hanging charm tab under the front plate, trigger clearance fixed (original 0.01).
- **Culling fix found here:** the hidden-face pass had deleted the receiver's rear face because the stock covers it, so with the stock faded in ADS (the game's rule) you looked into an open shell. Parts the game fades (Stock*) no longer act as occluders (`v2build.assemble`). **3,480 tris** (original 3,412). ADS checked at the game eye after the fix; held view from the config offset (0.44, −0.246, −0.85).
- **Self-grade 7 / 10.** Weaker: the stock is a large plain block with a recess; the magazine is shorter than the concept's.

## Guardian v01: done, self-graded 7 / 10 (moved on)
Files (`art-source/weapons/RemasterV2/Guardian/`): `Guardian_RemasterV2_v01.blend`, `build_guardian_v2.py`; [review sheet](../../art-source/weapons/RemasterV2/Guardian/Guardian_v01_review_sheet.png), [vs original](../../art-source/weapons/RemasterV2/Guardian/Guardian_v01_vs_original.png). Finalised with the new shared `_Library/finalize.py` (UV, renders, poses, comparison, save, sheets in one call).
- Contract kept (Muzzle 2.9984, buttpad −1.245, bore 0.368, AimPoint 0.1376/0.4984, front post 2.2576, LeftGrip on the handguard, BoltCatch part). Long two-row slotted handguard with a front block, receiver with charging channel/port/bolt/deflector, a lipped magwell for the short 10-round box mag (window, neon strip, base, top round), skeleton stock with a triangular window, cheek riser and grooved pad, octagonal brake with three ports, open ring + hooded post, hanging charm tab, trigger clearance fixed (the original's tip went 0.006 below the guard opening).
- ADS at the game eye (0.33/0.75, FOV 58): open window, post on the target, stock faded by the game rule. **4,197 tris** (original 4,144). The first pass mirrored the neon bar into the right-side port; now left only.
- **Self-grade 7 / 10.** Weaker: the receiver is a fairly plain two-box form; the long handguard repeats one slot shape.

## Stinger v01: done, self-graded 7 / 10 (moved on)
Files (`art-source/weapons/RemasterV2/Stinger/`): `Stinger_RemasterV2_v01.blend`, `build_stinger_v2.py`; [review sheet](../../art-source/weapons/RemasterV2/Stinger/Stinger_v01_review_sheet.png), [vs original](../../art-source/weapons/RemasterV2/Stinger/Stinger_v01_vs_original.png).
- Contract kept (Muzzle 1.14, buttplate −1.53, bore 0.294, AimPoint −0.408/0.4778, front post 0.8355, LeftGrip on the handguard). Box receiver thickened 0.072 → 0.08 with chamfered top, long left cocking groove with a serrated accent knob, top cover, front block with ears around the hooded post, rear ring with ears, ridged textured handguard, slotted flash hider, neon squares, grip hollow for the long magazine (mag shows below it, hollow when out), chunky folding stock (hinge block with pin caps, top beam, strut, open buttplate frame), hanging charm tab, trigger clearance fixed.
- ADS at the game eye (0.30/0.75, FOV 72): open window, post on the target. **2,972 tris** (original 3,038).
- **Self-grade 7 / 10.** Weaker: receiver sides are big flat planes; the "knob back" review frame (82) isn't the clip's furthest-back frame, so it shows the knob forward.

## Spectre v01: done, self-graded 7.5 / 10 (moved on)
Files (`art-source/weapons/RemasterV2/Spectre/`): `Spectre_RemasterV2_v01.blend`, `build_spectre_v2.py`; [review sheet](../../art-source/weapons/RemasterV2/Spectre/Spectre_v01_review_sheet.png), [vs original](../../art-source/weapons/RemasterV2/Spectre/Spectre_v01_vs_original.png).
- Contract kept (Muzzle 1.9012, buttpad −1.0668, bore 0.3528, AimPoint −0.0532/0.5236, front post 1.0164, LeftGrip on the handguard). Thicker upper/lower/handguard/grip/mag; octagonal handguard with long slots; HK-style accent loop handle in its slot (racks −0.16, checked at f85); magwell cavity with flared mouth for the forward-curving mag (window, base, top round); port + bolt + deflector; accent mag release; skeleton stock with ribbed pad; suppressor on a hex nut with seam band and closed cap; rear ring + hooded post between ears carrying the concept's neon squares; hanging charm tab; trigger clearance fixed (original tip sat on the guard).
- ADS at the game eye (0.37/0.75, FOV 72): open window, post on the target. **3,147 tris** (original 3,554).
- **Self-grade 7.5 / 10.** Weaker: grip is a simple slab; receiver flats.

## Judge v01: done, self-graded 7 / 10 (moved on)
Files (`art-source/weapons/RemasterV2/Judge/`): `Judge_RemasterV2_v01.blend`, `build_judge_v2.py`; [review sheet](../../art-source/weapons/RemasterV2/Judge/Judge_v01_review_sheet.png), [vs original](../../art-source/weapons/RemasterV2/Judge/Judge_v01_vs_original.png).
- Contract kept (Muzzle 2.1173, buttpad −1.02, bore 0.5022, LeftGrip on the handguard, Mag bone = the drum, ChargingHandle = top cocking slide). **Design change:** the drum turns its round face to the side like the concept (the original ran its axis along the barrel, which read as a box); rims, six flat clips, hub, feed tower into a lipped well, a shell on top.
- Receiver with the concept's angled side wing (recessed panel) and neon trapezoid, port + bolt + deflector, lower with a real guard opening (trigger clearance fixed: the original's tip went 0.012 below the floor), slotted handguard with a lower rail, heavy muzzle collar, skeleton stock with grooved pad, hanging charm tab.
- **Sight line fixed twice on the checkpoints:** the front post first stood 0.03 above the rear notch, then the top slide's knob sat dead in the sight line; the post now meets the notch floor and the knob is on the slide's left edge. **3,842 tris** (original 4,248).
- **Self-grade 7 / 10.** Weaker: the held view is dominated by the stock (that's the config hold); the drum faces are plain.

## Bucky v01: done, self-graded 7 / 10 (moved on)
Files (`art-source/weapons/RemasterV2/Bucky/`): `Bucky_RemasterV2_v01.blend`, `build_bucky_v2.py`; [review sheet](../../art-source/weapons/RemasterV2/Bucky/Bucky_v01_review_sheet.png), [vs original](../../art-source/weapons/RemasterV2/Bucky/Bucky_v01_vs_original.png).
- Contract kept (Muzzle 2.832, buttpad −0.951, bore 0.369, tube 0.216, LeftGrip rides the Pump, ShellLoadPoint, Shell bone; all 8 clips incl. ReloadStart/Insert/End with ShellIn markers).
- Receiver thickened 0.066 → 0.078 with the concept's angled side panel and neon bar, port + bolt + deflector, loading port; octagonal ribbed pump (0.084) on metal action bars (racks −0.26), heavier barrel with a crown band, tube with a cap, barrel clamp, skeleton stock with slotted pad, hanging charm tab, trigger clearance fixed (original 0.003).
- Sights: the first pass hid the front insert below the rear notch floor; the post now rises into the notch (sight line checked). The resting shell in the loading port is now a dark panel tone instead of the bright accent. **2,998 tris** (original 2,810).
- **Self-grade 7 / 10.** Weaker: receiver is a simple slab with one panel; the long tube/barrel pair is plain by nature.

## Marshal v01: done, self-graded 7 / 10 (moved on)
Files (`art-source/weapons/RemasterV2/Marshal/`): `Marshal_RemasterV2_v01.blend`, `build_marshal_v2.py`; [review sheet](../../art-source/weapons/RemasterV2/Marshal/Marshal_v01_review_sheet.png), [vs original](../../art-source/weapons/RemasterV2/Marshal/Marshal_v01_vs_original.png).
- Contract kept (Muzzle 3.1977, buttplate −1.241, bore 0.2046, tube 0.1155, scope axis 0.3333, AimPoint at the eyepiece, ScopeAxis, LoadPoint gate, LeftGrip on the fore-end; Lever/Bolt/Hammer/Trigger/Shell bones; 8 clips). Scoped: the game hides the gun past `SCOPE_AT` and shows its overlay, so the check is a coherent fixed optic, not an iron-sight picture.
- Satin receiver (0.055 → 0.066) with a side recess, neon slot and right-side loading gate; toothed rail; lofted scope (eyepiece, tube, objective bell) with focus/objective rings, two clamp rings on bases with screws, elevation/windage/parallax turrets, coated (accent) lens part; textured fore-end with the neon diamond; barrel band, crown band, tube cap, front blade; lever loop (swings on Fire) with the trigger clear of it (original 0.004); serrated hammer; stock with an inset; hanging charm tab. **3,739 tris** (original 3,446).
- **Self-grade 7 / 10.** Weaker: the right-side slot and gate crowd each other; the stock is a long plain form.

## Outlaw v01: done, self-graded 7 / 10 (moved on)
Files (`art-source/weapons/RemasterV2/Outlaw/`): `Outlaw_RemasterV2_v01.blend`, `build_outlaw_v2.py`; [review sheet](../../art-source/weapons/RemasterV2/Outlaw/Outlaw_v01_review_sheet.png), [vs original](../../art-source/weapons/RemasterV2/Outlaw/Outlaw_v01_vs_original.png).
- Contract kept (Muzzle/MuzzleLower on Barrels, hinge, breech 1.0302, scope axis 0.6256, AimPoint, ScopeAxis, LeftGrip on Barrels, chamber/eject locators, RoundUpper/RoundLower/BreechLatch). Receiver (already 0.106 wide from round 2) now sectioned with a side panel, neon parallelogram and the concept's two knuckle caps with pins; breech block with two chambers; barrels with crowned rings, vent rib, web and an octagonal front clamp; textured fore-end; lofted scope on rings/bases over a rail with three turrets and coated glass; stock with textured wrist and side panel, grooved pad; accent breech latch; trigger clearance fixed; hanging charm tab. Break-open checked (barrels drop, chambers open). **4,801 tris** (original 4,858).
- **Self-grade 7 / 10.** Weaker: the stock is a large slab (as the original/concept, but plainer); receiver right side mirrors the left.

## Operator v01: done, self-graded 7 / 10 (moved on)
Files (`art-source/weapons/RemasterV2/Operator/`): `Operator_RemasterV2_v01.blend`, `build_operator_v2.py`; [review sheet](../../art-source/weapons/RemasterV2/Operator/Operator_v01_review_sheet.png), [vs original](../../art-source/weapons/RemasterV2/Operator/Operator_v01_vs_original.png).
- Contract kept (Muzzle 3.521, buttpad −1.3195, bore 0.385, bolt axis 0.3885, scope axis 0.602, AimPoint, ScopeAxis, LeftGrip; Bolt lift about X then −0.3 slide, checked at f20). Receiver 0.086 → 0.09 with bolt ports both sides and an inner channel, lower recess, neon, toothed rail, lipped magwell; bolt with shroud and a longer right-side handle leaning out to an accent knob (first pass was a stub that barely cleared the side); lofted scope with eyepiece grip ribs, turret saddle and three turrets, rings on bases, coated glass; slotted handguard with neon and a front stud; octagonal three-port brake; skeleton stock with a monopod notch and a riser on posts; trigger clearance fixed; hanging charm tab. **4,476 tris** (budget 6K; original 5,952).
- **Self-grade 7 / 10.** Weaker: receiver flats; the "bolt lifted" review frame (12) isn't the lift peak.

## Ares v01: done, self-graded 7 / 10 (moved on)
Files (`art-source/weapons/RemasterV2/Ares/`): `Ares_RemasterV2_v01.blend`, `build_ares_v2.py`; [review sheet](../../art-source/weapons/RemasterV2/Ares/Ares_v01_review_sheet.png), [vs original](../../art-source/weapons/RemasterV2/Ares/Ares_v01_vs_original.png).
- Contract kept (Muzzle 3.0752, buttpad −1.232, bore 0.3712, AimPoint 0.1088/0.6392, front post 2.1056, LeftGrip on the handguard, drum = Mag on the barrel axis as in the concept; knob racks −0.18). Upper 0.091 → 0.096 with a left charging slot (accent knob), right port + bolt + deflector, neon capsules (left only; the first pass mirrored one into the port), panel lines; trunnion block with screws; lower with a lipped feed well; vented handguard with a lower rail, front block, gas block; banded drum with a spoked face plate, hub and feed neck; flash hider; rear ring on a tower with ears and a drum, hooded front post; skeleton stock with slots and grooved pad; trigger clearance fixed (original 0.003); hanging charm tab.
- ADS at the game eye (0.40/0.75, FOV 70): open window, post on the target. **4,832 tris** (budget 6K; original 5,668).
- **Self-grade 7 / 10.** Weaker: the receiver sides are large flats with only lines and capsules.

## Odin v01: done, self-graded 7 / 10 (moved on)
Files (`art-source/weapons/RemasterV2/Odin/`): `Odin_RemasterV2_v01.blend`, `build_odin_v2.py`; [review sheet](../../art-source/weapons/RemasterV2/Odin/Odin_v01_review_sheet.png), [vs original](../../art-source/weapons/RemasterV2/Odin/Odin_v01_vs_original.png).
- Contract kept (Muzzle 3.3635, buttpad −1.2425, bore 0.371, AimPoint 0.021/0.6503, front post 2.4325, LeftGrip under the plate, AmmoBox → FeedBelt, FeedCover hinge, BeltFeedPoint). Shroud/feed/rear receiver 0.096 → 0.1 with armour plates carrying the concept's neon slashes, sling loop, left feed window with five linked rounds (FeedBelt), ammo box (lid band, raised X, handle, clip), hinged feed cover with ears and an accent latch, rear receiver with the charging slot (handle moved forward so the −0.2 rack stays in the slot; the original's knob ran past it), port + bolt + deflector, end block with neon (lowered after the ADS check), rear rail; octagonal hider and collars; ring + hooded post on the front sight block; skeleton stock; hanging charm tab under the shroud.
- Reload checked (cover up, box and belt out). ADS at the game eye (0.39/0.75, FOV 70). **4,360 tris** (budget 6K; original 4,936).
- **Self-grade 7 / 10.** Weaker: the ammo box is the light panel tone (the sheet's olive is outside the family palette); rounds are steel rather than brass.

## Knife v01: done, self-graded 7 / 10
Files (`art-source/weapons/RemasterV2/Knife/`): `Knife_RemasterV2_v01.blend`, `build_knife_v2.py`; [review sheet](../../art-source/weapons/RemasterV2/Knife/Knife_v01_review_sheet.png), [vs original](../../art-source/weapons/RemasterV2/Knife/Knife_v01_vs_original.png).
- Contract kept: one rigid assembly on Root (0,0,0), tip +X, edge −Z, gun-left +Y; locators RightGrip, BladeBase (0.364, 0, −0.0065), BladeTip (1.2714, 0, 0.0156); same 1.72-stud length. Clips copied: Draw, Fire, Inspect, Slash1/2/3, HeavyStab (Hit markers 5/6/9/11 kept). No muzzle, eject, ADS or charm (charms hang from `CharmPoint`, which the Knife never had, so none was added).
- Blade with a real cross-section: spine 0.032 thick (was 0.024), satin flat, a charcoal sabre grind, a light satin cutting bevel down to a 0.003 edge, a clip point that thins to the tip, a plunge step at the ricasso and a cut choil. Thicker chamfered guard plate; octagon-section handle with finger swells and two recessed textured panels; lofted faceted pommel with a through lanyard hole; the concept's blue inset near the pommel (gun-left).
- **1,404 tris** (the original was 860; the sidearm budget is 3K). One UV atlas, uniform density.
- **Self-grade 7 / 10.** Weaker: the satin edge is only one tone lighter (the role palette has no bright steel), the handle is a little straighter than the concept's, and the Root-only clips barely move the model on their own, so the pose renders look close to rest (the swing is in the viewmodel).

## Set summary (all 18 done, 2026-11-07)
Vandal 7.5, Classic 7.5, Ghost 7.5, Sheriff 7, Shorty 7, Phantom 7.5, Bulldog 7, Guardian 7, Stinger 7, Spectre 7.5, Judge 7, Bucky 7, Marshal 7, Outlaw 7, Operator 7, Ares 7, Odin 7, Knife 7. Every weapon is within its triangle budget and has a `.blend`, a review sheet and a before/after sheet.

**Not done (honest gaps, for the user's review):**
- UVs are automatic (smart project + pack, one atlas each); nothing is baked and there are no textures beyond the material roles.
- The original clips are reused on the new rigs (same bones), not re-timed to the new shapes.
- The held view is approximate: no arms and no sway, and there is no hip render for the Knife.
- Nothing is exported, uploaded, built in Studio or committed.
- The Vandal and Classic builders predate the "stock is not an occluder" culling rule. Their ADS looked solid, but a rebuild would confirm it.
- Some pose frames aren't the motion peak (Stinger knob, Operator lift).

**Next (user's call):** review the sheets, then pick which guns go to export → Studio (Art Direction → Import pipeline).


## v02 quality pass (2026-11-08, user feedback)
The user's notes on v01: grades of 7 are too low; aim much higher (10 is ideal), with cleaner geometry closer to the references; the Vandal ADS looked weird with floating parts; **each gun's sights should be its own** (similar quality, not copies); every gun loads its own ammo (shotgun shells, bigger sniper rounds that fit the Outlaw and Operator); the Outlaw must break open further, the whole barrel group swinging down so the shooter picks the rounds out and loads new ones.

**Bar for v02 (self-grade 9+):** no floating or unsupported parts in any view, including the ADS picture (every sight piece joins its base); a sight picture unique to the gun; ammo of the right family and size, seen in the reloads; moving parts checked frame by frame for clipping (`_Library/clearance.py`, BVH overlap of movers against the static parts); within the triangle budget; closer silhouette and detail to the concept.

**Shared additions:** `_Library/ammo.py` (sniper, rifle and pistol rounds, shotgun shells; lathed, brass cases); an 8th material role **Brass** (`A8844E`, Metal; the exporter reads each material's own look, so no code change); `_Library/anim_author.py` (keys new clips into muted NLA tracks the exporter bakes); `_Library/clearance.py`.

### Vandal v02 (self-grade 8.5)
- ADS fixed: the rear sight is one solid aperture block (base, leaf with a 0.05 window, guard wings fused to both); the front is an AK-style tower with two ears and the post between them, plus a cross hole, as on the concept. The old ring-on-a-stem, loose ears and ring hood are gone. ADS at the game eye: round window, post centred between the ears, nothing floating.
- Now built through the shared `assemble` (stock no longer hides other parts' faces). 5,009 tris (9 over the 5K budget; trim pending).
- Files: `Vandal_RemasterV2_v02.blend`, `Vandal_v02_review_sheet.png`, `Vandal_v02_vs_original.png`.

### Outlaw v02 (self-grade 8.5)
- **Hinge moved** from (0.935, 0.2346), inside the receiver, to the receiver's bottom-front corner (1.045, 0.152). A barrel lug (disc around the pin, joined to the block and fore-end) turns in a pocket in the receiver; pin caps on the sides. Every barrel part now sits ahead of and above the pin, so the barrels swing forward-down clear of the receiver at any angle. The decorative knuckle caps stay where the concept has them. Only the reload clips use the pivot (Fire/Draw/Inspect are unchanged); the rest pose is identical.
- **Rounds:** full-size bottleneck sniper cartridges (brass case, rim and groove, steel ogive), 0.45 long, about twice the old round.
- **New clips** (`anim_outlaw_v2.py`): `Reload` (60 f, over 2.3 s) and new `ReloadEmpty` (92 f, over 3.8 s; the game plays it when the gun has it). The barrels open to 72° (was 46°) with a settle; the ejector pops the rounds; each round swings out sideways about the chamber mouth (the scope sits over the breech, so a long round can't come straight out), is pulled clear and taken to the lower left; fresh rounds come back the same way, are lined up and pushed home, upper then lower; the barrels shut with a small bounce. Markers Open / RoundOut / RoundIn / Close. Clearance check: **0 clipping frames** in both clips (the scope bell and barrel rib were trimmed so they no longer touch at rest).
- 4,935 tris. Files: `Outlaw_RemasterV2_v02.blend`, `Outlaw_v02_review_sheet.png`.

### Ammo (v02, every gun)
- Sniper rounds: Outlaw (full size, two in the barrels), Operator (0.8 scale on the mag's feed lips, plus the stack in deeper witness windows), Marshal (0.56, the lever gun's loading round).
- Shotgun shells (steel-blue hull, brass head and rim, rolled crimp): Shorty (both chambers), Bucky (loading shell, now the right way round with the brass to the rear; v01 had it backwards), Judge (top shell on the drum's feed tower).
- Rifle rounds on the mag top (seen when the mag drops): Vandal, Phantom, Bulldog (0.85), Guardian (1.05, full power). Odin belt: brass cases with steel bullets.
- Pistol rounds on the mag top: Classic, Ghost (1.4), Spectre, Stinger (1.3). Sheriff: brass case heads in the cylinder.

### Sight pictures (v02, each gun its own; none floating)
| Gun | Rear | Front |
|---|---|---|
| Vandal | solid aperture block, round window, fused guard wings | AK-style tower, two ears, post |
| Phantom | square-notch blade | post with a neon dot in a square box hood |
| Bulldog | diamond-window plate | round hood over the post |
| Guardian | carry handle: closed peep housing, sighting channel | post between two winged guards |
| Spectre | HK-style rotary drum diopter | round hood over the post (neon squares on the base) |
| Stinger | low V-notch blade | neon bead on a short post |
| Ares | U-notch leaf on the rear ramp | wide open blade on the tower |
| Odin | ladder frame with a V-notch slider | post in a square box hood |
| Classic, Ghost, Sheriff | 3-dot / notch pistol sights (already their own) | |
| Outlaw, Operator, Marshal | scopes (the game shows its overlay) | |
Library: `_Library/sights.py`. All ADS renders at the game eye: `<Gun>/renders/v02_ads.png`.

### v02 status and grades (self-grade, against the 9+ bar)
- All 17 guns re-saved as `<Gun>_RemasterV2_v02.blend` with `v02` review and before/after sheets (the Knife stays v01: no sights or ammo). Batch runner: `_Library/batch_v02.py`.
- Grades now: Vandal 8.5, Outlaw 8.5, Operator 8, Guardian 8, Bulldog 8, Odin 8, Phantom 8, Spectre 8, Stinger 8, Ares 8, Shorty 8, Bucky 8, Judge 7.5, Marshal 7.5, Classic 7.5, Ghost 7.5, Sheriff 7.5, Knife 7.
- **Why not 9+ yet:** the sights, ammo and the Outlaw action are at the bar, but most bodies are still the v01 shapes. To reach 9+, each gun needs a geometry pass against its concept sheet (silhouette, panel breakup, mag/grip shapes, fewer plain boxes). Not done this round.
- Triangles: all within budget (Vandal 4,945, Outlaw 4,935, Operator 4,804, Guardian 4,541, Odin 4,506, Ares 4,740).

## v03 geometry pass (2026-11-08, the user: "get it up to 9s ... misaligned and floating parts ... the Bulldog ADS looks weird")
**New check, `_Library/parts_check.py`:** every loose island of every part must touch or sit in another (gap <= 0.0025 studs) at rest. The batch runner (`batch_v02.py run(gun, version="v03")`) now runs it on every build and reports `floating`. It found and fixed:
- Phantom: front box-hood walls stood beside the narrow tower top (gap 0.0036); tower top widened.
- Odin: the same on its front hood (gap 0.01); tower top widened, hood narrowed.
- Spectre, Judge, Shorty: triggers hung below the frame (0.005 to 0.015); triggers now run up into the frame.
- Classic, Ghost, Sheriff, Shorty, Bucky, Judge: neon sight dots stood 0.004 to 0.015 off sloped sight faces; they now lie in the faces (sloped strips on the posts).
- Ghost: magazine base plate (0.011); Shorty: grip base cap (0.0095); Sheriff: hammer floated in its slot (now seated on the slot floor).
- Bucky: the loading shell floated in an over-wide port. The port is now shell-wide, so the rim rests on its walls (the reload still passes the shell up through it).
- Only remaining flag: the Marshal's loading round, which is sealed inside the receiver at rest (never seen).

**Sights:** Bulldog v02's diamond plate read oddly and blocked the view. It is now a protected ghost ring: a thin wide ring tied by short arms into two tall pillars, plus a web to the base (`sights.ghost_ring`), over the round-hooded front post. Wide window, post centred.

**Shape changes against the concepts:**
- Marshal: one-tone stock with a wrist that tapers into the butt, textured wrist panels, a butt facet, and a grooved recoil pad with a spacer line (v01's big light panel is gone); rounder D lever loop; front band joining barrel and tube.
- Judge: wider drum with a raised rim, a recessed face split by three ribs, a metal hub with a winding knob, and six chunky clips (v02's light rims read as a hubcap); grip with finger grooves and a flared base.
- Classic: beavertail.
- Ghost: full-length grip, magazine and base plate (the grip was stubby).
- Sheriff: long raked revolver grip with finger grooves; slimmer octagonal barrel round the bore; one narrow underlug with an angled front (v02's two-step slab is gone); front sight on a ramp; rounder trigger guard.
- Bulldog: real barrel (0.022 -> 0.034) and an octagonal ported brake; the stock's light slab became a quiet dark recess.
- Guardian: heavier barrel (0.03 -> 0.04) and a bigger brake; full-length DMR magazine with a base plate.
- Spectre: long curved SMG magazine (concept) with a base plate at its new length.

**For Studio, animation and reskins:** every moving part is its own mesh on its own bone (unchanged contract: bone names and heads, locators; the Outlaw hinge is the one documented exception). Every surface uses one of the 8 shared material roles (Body, Panel, Dark, Metal, Grip, Accent, Neon, Brass), so a skin is a role-to-colour/texture swap. One UV atlas per gun, islands inside 0-1.

**v03 files:** `<Gun>_RemasterV2_v03.blend` plus `<Gun>_v03_review_sheet.png` and `<Gun>_v03_vs_original.png` for Marshal, Judge, Classic, Ghost, Sheriff, Bulldog, Guardian, Spectre, Phantom, Odin, Shorty, Bucky. The others stay at v02: Vandal, Outlaw, Operator, Ares, Stinger (all passed the check), and the Knife at v01.

**Self-grades now:** Vandal 8.5, Outlaw 8.5, Sheriff 8.5, Judge 8.5, Marshal 8.5, Operator 8, Guardian 8.5, Bulldog 8.5, Spectre 8.5, Phantom 8, Odin 8, Stinger 8, Ares 8, Shorty 8, Bucky 8, Classic 8, Ghost 8, Knife 7.

### v03, round 2 (same day, after Blender restarts)
- **Palette (polish without textures, the user's ask):** cooler graphite body `383D48`, clearly lighter inset panels `555C69`, darker polymer `1C1E23`, brighter satin steel `62676F`, richer steel-blue accent `3C66B8` (`v2kit.ROLE_SPEC`). Every gun re-saved with it. Skins still swap per role.
- **More shape work:** Phantom open skeleton stock (QD sockets moved onto the top bar); Odin heavy barrel (0.068 -> 0.08) with a bigger collar, ring and hider, plus a wider front block; Ares heavier barrel (0.046 -> 0.056) and brake; Bulldog ghost ring tied in with arms.
- **Bug found: cuts into an already-bevelled solid can fail silently.** The Phantom stock window never cut, and neither did the Marshal's wrist panels and butt facet. Both are now bevelled after cutting. **Audit next:** every builder that cuts a `solid(..., edge)` should cut first and bevel after.
- **All 17 guns are at v03** (`<Gun>_RemasterV2_v03.blend` plus v03 review and before/after sheets); the floating check is clean on all of them except the Marshal's sealed internal round. Roster overview: [RemasterV2_v03_roster.png](../../art-source/weapons/RemasterV2/RemasterV2_v03_roster.png).
- Batch runner: `batch_v02.run(gun, version)` re-appends the originals in a fresh session; `cleanup(gun)` frees a finished gun's scenes and data (long passes were the likely cause of Blender shutting down).

### v03, round 3: cut audit and detail
- **Cut audit:** `v2kit.cut()` now checks every cut. It intersects first to get the volume that should go, then confirms that volume really went. If not, it retries with plain EXACT, then the MANIFOLD solver, and logs the result in `K.CUT_LOG`. Running all 18 builders found one more silent failure (the Marshal butt facet, line 117), healed by MANIFOLD. Every other cut was fine. A silent cut can't come back unnoticed.
- **Bulldog:** the stock's comb steps down to the pad and the heel angles up (concept); v02 was one rectangle.
- **Operator:** heavy fluted barrel (0.052 -> 0.062, flutes on the sides and top) and a bigger ported brake.
- **Knife (v03):** the cutting edge is now the bright satin steel, with a steel-grey flat and charcoal grind, so the edge reads brightest, as on the concept.
- All 18 assets are at v03. Roster sheet refreshed; the floating check is clean, as before.

### v03, round 4: Shorty barrels, panel lines
- **Shorty:** the shroud now covers only the breech end. Two full barrel tubes run to the muzzle rings, joined by a web and a vented sighting rib (the front post stands on it), with a clamp band near the muzzle. The fore-end is raised to meet the barrels. 2,714 tris (v02 hid the barrels in a solid block).
- **Panel lines** (0.008 wide, 0.004 deep seams, both sides) on the flat receivers: Stinger (upper/lower seam and two verticals), Spectre (two verticals), Guardian (front and rear verticals plus a low horizontal seam).
- Floating and cut checks clean on all three. Roster sheet refreshed.

### Final geometry audit (export readiness, 2026-11-08)
`_Library/final_check.py audit(gun)` loads the saved `<Gun>_RemasterV2_v03.blend` (not a rebuild) and checks every mesh: fully triangulated; no degenerate faces or zero-length edges; no loose verts or edges; no edges shared by 3+ faces; no duplicate verts; closed islands wound outward; UVs present, inside 0-1, no zero-area UV tris; only the 8 material roles; unit scale; no `.001` names; Roblox limits (<= 20k tris and <= 10k verts per mesh after the exporter's per-material split). At the gun level: one rig, bones in Euler XYZ, every mesh parented to the rig, NLA clip tracks present, locators present.

**Result: all 18 pass.** Two needed fixes:
- Shorty barrels: 12 sliver faces. Through-vents left a 0.002 strip under the rib; they are now blind slots from the top.
- Guardian receiver: 6 slivers and 2 non-manifold edges from a 0.0004-stud bevel corner at the magwell.

Kit hardening, for every future build: `finish_mesh` merges verts within 0.0004 studs (the smallest real detail is 0.0015) and flips the longest edge of any zero-area triangle after triangulation.

Open edges remain by design: faces buried inside another static part are removed (the hidden-face cull). They are never visible and never revealed by animation, because only static parts are culled and moving parts never hide static faces from the cull.

**Export note:** `tools/blender/export_weapons.py` still targets `GunTest.blend` and is run as background Blender. For the test batch it will be adapted to read `RemasterV2/<Gun>/<Gun>_RemasterV2_v03.blend` and run through Blender MCP. It keeps the per-material split, the NLA-strip bake (clips) and the modifiers applied (weighted normals).

## Order from here
Next: export a test batch (exporter adapted to the RemasterV2 files, run through Blender MCP), then look at it in Studio and fix what Roblox lighting shows.

## Imported into Studio (2026-11-08, afternoon)
The owner asked for the whole roster in, then a first-person pass judged by Claude, with their per-gun sign-off afterwards. Nothing is published.

**Backups first:** `art-source/weapons/Exports/_pre_remasterV2_2026-11-08/` (old FBX + JSON + `WeaponAnimations_src`), `art-source/weapons/Studio/_pre_remasterV2_2026-11-08/` (old `.rbxm`), and in the place `ServerStorage.WeaponsBackup_PreRemasterV2_2026-11-08` (all 19 old models). To roll one gun back: drag its model from that folder into `ReplicatedStorage.Weapons` and run `git checkout -- src/shared/WeaponAnimations/<Gun>.luau`.

**Export:** all 18 v03 files went through the live Blender session without touching the open scene. Each gun was appended into a temporary scene, run through `export_weapons.export_gun`, then every datablock it added was removed. The session was saved first as a copy. The collections' `pbr` flag was dropped, so no part gets the old baked texture maps. The contract matches the old exports: same bones, Muzzle and AimPoint unchanged; only `Socket_*` locators were added. Every Muzzle sits exactly on its barrel or suppressor tip.

**Upload and build:** `upload_models.py` added a new version to each gun's existing asset. `make_build_data.py` and `make_weapon_anims.py` ran, and `WeaponBuilder.publish` built all 18 into `ReplicatedStorage.Weapons` with no missing parts. Akimbo is still the old model. The validator gives the same results as before: pistols and the Knife are flagged only because they have no `Body_`/`Receiver_` parts, and the Sheriff has no `Eject` (the old one didn't either). The `.rbxm` save inside `publish` can't reach `receive_server` from the Studio MCP, so `art-source/weapons/Studio/<Id>.rbxm` still holds the old guns. Re-save them from Studio, or drop them.

**Play test:** both a 1v1 bot match and the test range equip and fire with clean Output.

**First-person pass (Claude's judgement):**
- **Method:** a client sampler measured the closest gun part to the camera every frame through draw, reload, empty reload and inspect for all 18 guns. Clipping starts at 0.1 studs. There were screenshots per gun: the sight picture for iron-sight guns, mid-reload for unique reloads, mid-inspect for pistols and shotguns.
- **Clipping:** none. The closest approaches are the Bulldog stock in its reloads (0.11–0.13; a bullpup with the mag in the stock, which reads fine on screen) and Ares/Guardian/Judge stocks in inspect (0.22–0.23).
- **Sight pictures:** Vandal, Phantom, Guardian, Bulldog, Spectre, Stinger and Ares are all centred, with the post on the crosshair. The Spectre's hooded aperture is small but readable. The Marshal scope overlay works.
- **Muzzle:** guns with a flare (Classic and others) show a hot star, a side flame and an ejected case. Vandal-class guns with `muzzleDevice` show a grey puff by design.
- **Fixed:** the Outlaw's new hand-loaded reloads hid the open breech behind the scope at the bottom edge. In `Outlaw_RemasterV2_v04.blend` (v03 untouched) the open hold of `Reload`/`ReloadEmpty` gets a clockwise cant of +0.30 rad, a lift of +0.18 and a nudge of +0.05 toward the centre. The breech and brass now show above the ability bar, and the camera rolls about 2–3° with it. Re-exported, with the animation module regenerated. No re-upload was needed; `Exports/Outlaw.fbx` now differs from the uploaded asset only in baked animation.
- **Left for the owner:** in inspect on the long shotguns (Bucky, Judge), the blocky hands sit under the gun in the side-on frame instead of on the grip. This comes from the shared `Inspect` track and the block arms, both unchanged by the import. The Operator mag swap happens below the frame. The Knife blade reads almost black in first person, because the light cutting bevel is thin.

**Gun review mode** (`GunReviewController`, `Config/GunReview`; Studio and test-mode servers only):
- F6 opens a panel with the 18 guns in review order.
- `[` and `]` switch gun (PickWeapon). N replays the draw, G the reload and B the empty reload.
- Z cycles slow motion (1 / 0.3 / 0.1), X freezes.
- K marks a gun "looks good" and J "needs work". The verdicts print to Output as `[GunReview] <Gun>: …`.
- The game's own keys still work: LMB fire, RMB aim, R reload, Y inspect.
- Use the test range: Studio Play with the Workspace `TestMode` attribute on, or P in a match.

**Studio state:** Rojo serve was started for the owner, and the plugin was syncing. Workspace `TestMode` is back to `false`. **Save the place.** Nothing is committed.

## Owner feedback round 1 (2026-11-08, evening)
The owner went through every gun with the F6 panel and asked for changes. Their answers: slow the equips; flashes on Vandal, Guardian, Bulldog, Ares, Odin and Operator (Phantom, Spectre and Stinger keep none); Sheriff ADS works like the rifles; and do everything before one review. Nothing is published or committed.

**All guns**
- Hold: `Viewmodel.HIP_SHIFT` (0.05 right, 0.05 up, 0.035 closer; per gun `hipShift`) and `SCALE` 0.75 → 0.8. Bigger, more right and higher (Valorant-like). The sight pictures stay centred.
- Draws: every `drawTime` ×1.25. The shared `Draw` track uses Sine eases, no snap, and the muzzle tips up as the handle is let go.
- Reloads: the `Reload`/`ReloadEmpty` tracks have a harder roll, a flick as the mag comes off and a slap as it seats. The old mag is thrown off and forward (`MAG_DROP.throw`, spin 11).
- Inspect: the gun is held further out and higher.
- Shot feel: `Juice.SHOT_FEEL` adds an FOV punch, a small roll and a stronger shake per shot (scaled by `recoil.up`, less when aimed). Viewmodel kick is 0.065 back and 0.045 rotate. `viewmodelKick` is a per-gun multiplier (Sheriff 1.8).
- ADS: reloading drops the sights and keeps them down. Bolt and lever guns drop them while they cycle after a shot. A scoped gun with an empty mag (the Outlaw after both barrels) can't aim.
- Arms are drawn ×1.45 longer (`ARM_LENGTH_SCALE`), so their cut ends stay off screen.
- Rounds no longer pop in (`carry` + `Util/RoundCarry`, Shorty, Outlaw and Sheriff). The spent round shows on its way out and is hidden at the turnaround. The left hand carries the fresh round in. The Sheriff's rounds and speedloader are hidden at rest (`carryHideAtRest`).
- Shell loops (Bucky, Marshal): the loading hand reaches the gate during ReloadStart, stays there for every ReloadInsert and leaves it in ReloadEnd. There's no more jumping back to the pump (`SHELL_GATE_REACH`).

**Per gun (Blender v04 files beside v03, which is untouched)**
- Classic and Ghost: the draw is a real slide rack (−0.13 in the middle of the draw), and the tactical reload racks the slide at the end. Reload times are +0.25 s (Classic 1.85 / 2.15, Ghost 1.75 / 2.0).
- Knife: a swipe-out `DrawMelee` track replaces the Blender twirl. The inspect has no spins and the free hand drops out of view. The idle shows both hands: a raised left guard and a new grip angle. The heavy stab coils at the middle of the body, and the free hand blends onto the handle (`FREE_HAND_BLEND`).
- Sheriff: ADS works (a new `AimPoint` locator at the rear sight, and `adsDistance` 0.42). The draw thumb-cocks the hammer, and the kick is stronger.
- Bucky: the shell-loading tilt is ×1.35.
- Judge: the blue charging-handle piece is now Dark.
- Odin: the belt hops a link on every shot.
- Model fixes: the Phantom suppressor front is capped (dark disc; it was see-through), and the Operator stock now reaches into the receiver (it had a 0.10 gap). Both, plus the Judge, were re-uploaded and rebuilt.

**Checked:** Output is clean in Play. No near-plane clipping at the new hold (Bulldog reload 0.18, Guardian inspect 0.16). Screenshots were checked for the Sheriff ADS, Sheriff and Shorty reloads, knife idle and Stinger ADS.
**Not checked by eye:** the new draw and reload feel on every gun, the knife slashes, the sniper ADS drop and the Odin belt. These are for the owner's F6 pass.

## Final pass (2026-11-11)
Sights, see-through and floating parts, charm mounts, the accent colour and the model sheets: [Weapon Final Pass 2026-11-11](Weapon%20Final%20Pass%202026-11-11.md). The current models are `<Gun>_RemasterV2_v05.blend`.
