# Range v5: levels, live dummies, loadout terminals (plan, 2026-11-25)

**Owner (2026-11-25, before leaving):** "start working on the range making it fully functional." Not enough height and levels. Dummies "just stand there", they need hit animations and a pulse, and there should be more of them. They should be orange/gold or blue, full body, "kind of glowing like rivals". The loadout selectors should look more professional (Blender is open). A working loadout selector menu, which can also open the Locker. "As polished and finished as possible."

Builds on [Lobby V5 Plan](../02%20Art/Lobby%20V5%20Plan.md) → "Range v4" and "Final lobby cleanup". The range stays closed in live servers (`Release.RANGE_OPEN = false`); Studio reaches it with F6 or the hub gate.

## 1. Height and levels (Studio, `tools/studio/lobby_v5/BuildRangeV5.luau`)
The yard is 270 × 250 with 45-stud walls, but almost everything sits under 15 studs. Add a second and third tier on the empty edges, without crowding the open floor:
- **North gallery:** a 12-wide catwalk along the north wall at deck height 16, with stairs at both ends, a parapet with cut tops, dummies along it (shooting up).
- **West terraces:** two stacked balconies on the west wall (decks 12 and 24), joined by a switchback stair, so a player can climb to 24 and look over the yard.
- **Sniper perch:** a deck at 30 in the north-east corner, reached from the gallery by a stair. The longest sightline in the yard (to the alcove, ~230 studs).
- Same kit as v4 (LobbyWay `K.lpart`, grid texture, `STRUCT` / `BLOCK` greys); chamfered parapet caps, piers under every deck, no plain floating slabs. Audits: no overlaps, no floating, humanoid can walk every stair.

## 2. Dummies v2
- **Look (final, owner 2026-11-25 evening):** the regular blocky R15 body and head (face kept), one matte blue over everything (`Config/RangeDummies.COLOR`, SmoothPlastic). The first pass (glowing Neon gold / blue with a block head and visor) was "glowing way too much" and is gone. Applied by the server (`Range/RangeBots` → `shared/RangeDummyLook`).
- **Idle:** the game's own third-person clips, played by the server: the Core idle under the unarmed upper body (what a lobby player plays), each bot started at a random point; the head also looks about now and then (client).
- **More of them:** 19 → about 40, spread over all three tiers; groups on the gallery, terraces and perch.
- **Hit reactions (client, `Controllers/DummyLifeController.luau`):** procedural, spring-driven (coil, snap, brake, overshoot, settle): the torso kicks away from the shot, the head snaps on a headshot, arms lag, repeated hits stack and wobble. Direction and zone come from the server: RangeService's hit listener stamps `HitAt` / `HitFrom` / `HitHead` on the bot.
- **Pulse:** each hit flashes the body toward white and settles; a kill flashes white, then DeathFxController's fall; the respawn rises out of white.
- **Strafers:** bots with `Behaviour = "Strafe"` (and `Sway`, `Speed`) walk side to side on the server (Humanoid movement, unanchored) with the game's RunL / RunR clips and the unarmed run arms, blended by speed (weights sent ~10/s).
- The **damage dummy** keeps counting (board optional) and never falls; the **moving dummy** rides its carriage From → To.

## 3. Loadout terminal v3 (Blender)
A more professional terminal: a faceted kiosk with a leaning screen head, side cheeks, a lit gun bay with a rack silhouette, a plinth, cable gland. `tools/blender/lobby_v5/v5_loadout.py`, uploaded through Open Cloud, swapped onto the six `RangeLoadout` spots.

## 4. Loadout menu (`LoadoutController`, Router menu "Loadout")
- Opens at a terminal (tag `RangeLoadout`), only in the range.
- Three slot tabs (PRIMARY / SECONDARY / MELEE) with the current gun on each; a grid of every installed gun for the chosen slot, grouped by class, with the gun's render; click equips it (the existing `PickWeapon` remote, already server-checked for the Range zone).
- A **LOCKER** button opens the Locker (skins), coming back to the loadout when it closes.
- Style: `gauntlet-ui-style` (soft plates with one cut corner, Rubik, no pills, no outlines, no glow).

## 5. Done when
- The yard has three readable tiers, every stair walkable, audits clean.
- 40-ish gold/blue glowing dummies; every hit visibly kicks and pulses; kills drop and respawn.
- New terminal in all six spots; the menu equips guns and opens the Locker.
- `stylua`, `selene` clean; a Studio playtest with no errors; captures in this note; place saved.

## Results (2026-11-25, place saved v1243)
Tested in a Studio playtest (F6 into the range): no errors in the output.

**Levels** (`tools/studio/lobby_v5/BuildRangeV5.luau`, `Yard.Levels`, overlap check: none). Walkable floors now at 0, 12, 15, 24, 25, 40:
- **North gallery** (deck 12, x −78..70 along the north wall): piers with dark heads and feet, a fascia band, a teal glow line under the edge, low parapets with chamfered (wedge) ends, two stairs from the yard (east and middle).
- **Sniper perch** (deck 24, north-east corner): two full-height piers, parapets, a stair up from the gallery along the wall.
- **West terrace** (deck 15, x −130..−118): joins the bunker roof (its north parapet segment went), a stair from the yard, a stair on to the hangar roof (25).
- Not walked by a player yet: the stairs were checked by geometry only.

**Dummies** (`Range/RangeBots` server, `Controllers/DummyLifeController` client, `Config/RangeDummies`): 39 bots (was 19 + 2 inert specials): 18 new across the gallery (5), perch (2), terrace (3) and the floor (4 still, 4 strafers); the damage dummy and the carriage rider are real bots now.
- Real shots measured: 3 rifle hits (headshot 78) stamp `HitAt` / `HitHead` / `HitDealt`; the head snaps back ~0.5 studs and settles (~0.35 s); the body flashes; a kill respawns 2.5 s later dressed and flashing in.
- Strafers ADAD ±6 studs (sampled x 30.0 → 40.2 → back); the carriage glides From → To on the server clock; the damage dummy is healed straight back and its bar reads `DMG · DPS · HITS` (not shot-tested yet).
- **Fixed on the way:** the range health bars never appeared (pre-existing): the bots stream in as empty models (the range is far from the lobby) and the bar code gave up. Bots now stream `Atomic`, and the bars / poses retry when parts land. 39 bars in play.

**Loadout terminal v3:** asset 103199802564419 in all six spots (`tools/studio/lobby_v5/PlaceLoadoutV3.luau`, kit `ServerStorage.V5Kit.Terminal3`): grey body, charcoal trim, gunmetal cradles, teal bay glow with a light, and a SurfaceGui screen (RANGE ARMORY / LOADOUT / G CHOOSE YOUR GUNS) on a thin face part over the 15° screen.

**Loadout menu** (`UI.Lobby.Loadout`, backup `tools/studio/BuildLoadoutMenu.luau`; `LobbyClient/Controllers/LoadoutController`):
- Walk up to a terminal: a hint plate shows over it; **G** / D-pad right / tap opens the menu. (ProximityPrompts never show inside the armed range, even a fresh one; see Bugs & Ideas. E is Mod 2 there anyway.)
- PRIMARY / SECONDARY / MELEE tabs (or 1 / 2 / 3, or the slot cards on the left); the Locker's gun cards in your equipped skin; a click equips through the existing `PickWeapon` remote (the server checks the Range zone, the id and the model). Verified: picking Spirit equipped it and the HUD followed.
- **LOCKER** opens the Locker; closing it comes back to the loadout. Verified in play.
- Any lobby menu open in the range frees the mouse and pauses match input (`GameSettingsOpen`, the Settings menu's switch); closing re-locks it. Verified.
- First captures showed the slot cards on the left empty (the button helper wraps each card in a holder of the same name) and the LOCKER button over the hotbar. Fixed and re-captured: the slots show the held gun in its skin (HAVOC / CLASSIC / KNIFE), LOCKER sits on the tabs' row.

**Open / next:**
- The owner's walk-through: stair feel, sightlines from the perch, whether 39 is the right count.
- Shoot the damage dummy once to confirm its counter.
- Export `UI.Lobby.Loadout` into the UI backup (`art-source/ui/UI.rbxmx`) with the next UI export.

### Loadout terminal v3 (Blender)
Built 2026-11-25 by `tools/blender/lobby_v5/v5_loadout.py` (`build()`, `review()`, `export()`; helpers from `v5_props.py`) in the live Blender (collection `V5LoadoutV3`, review set in `V5LoadoutV3_Review`). **Asset id `103199802564419`** ("GG Range Loadout Terminal v3", group 11116787), FBX `art-source/lobby/V5_LoadoutTerminal.fbx` (same export settings as `V5_RangeKit.fbx`: default axes, `FBX_SCALE_UNITS`, 1 unit = 1 stud).

- **Form:** charcoal plinth (4.7 × 3.1, 0.48 tall, chamfered toe) with an inset shadow-gap band; a grey body 3.6 wide whose front leans back 3.4°, side cheeks 0.14 proud all round (one size up) repeating the body's big cut top-front and back corners; a chin that juts out into a **screen head leaning back 15°** with an even 0.16 grey margin, a charcoal bezel ring 0.03 under the face and the screen 0.035 under the bezel; a **gun bay** 2.7 × 2.85 lined as one charcoal piece (front edge 0.05 behind the leaning face), two steel cradles (mount plate seated in the liner, gusset heel, V saddle, raised lip), a glow strip in a channel in the bay ceiling. Edge detail only: steel kick plate in a pocket, status lamp (steel hex ring + glow lens) on the right cheek, 4 exhaust slots and a bolted service-hatch groove on the back, 3 vent slots low on each cheek, a conduit from a back gland through a faceted elbow into a floor flange behind the plinth.
- **Meshes** (Studio frame, model pivot at floor centre, front -Z; size X × Y × Z → bbox centre offset): `Terminal3_Body` 4.16 × 6.60 × 2.75 → (0, 3.92, -0.085) · `Terminal3_Trim` (plinth + band, bay liner, bezel ring) 4.70 × 6.73 × 3.10 → (0, 3.364, -0.05) · `Terminal3_Steel` 3.47 × 5.09 × 3.21 → (0.294, 2.543, 0.429) · `Terminal3_Glow` (bay strip + lamp lens) 3.08 × 0.26 × 0.66 → (0.459, 4.029, -0.788) · `Terminal3_Screen` own size 3.04 × 1.71 × 0.035, centre (0, 5.779, -0.930), `CFrame.Angles(math.rad(15.03), 0, 0)` (top tips back); its front is the same side as the terminal's front (SurfaceGui Face = Front when the terminal faces -Z). Total height 7.22 (cheek tops).
- **Orientation caveat:** modelled front = Blender -Y like every V5 kit piece. With these export settings the file's front is +Z, so if the import keeps file axes the model lands facing +Z: rotate the whole Model 180° about Y (offsets above then flip X and Z) and the screen SurfaceGui goes on the face that points the same way as the bay. Check the Screen MeshPart kept its 15° tilt on import; if the importer baked it, set the CFrame above.
- **Budget / checks:** 2,960 tris (Body 1,144 · Trim 524 · Steel 1,216 · Glow 32 · Screen 44). Every mesh 0 non-manifold edges, all shells outward; Body is one unioned shell, Trim 3, Steel 9 (2 cradles, kick plate, lamp ring, conduit assembly, 4 bolts), Glow 2. No subdivision, flat shading, 1-segment angle-limited (30-35°) bevels after the unions, round parts are 6/8-sided prisms.
- **Renders** (R15 5.5-stud block stand-in): [3/4 front](../02%20Art/References/range-v5/terminal3_front34.png) · [joins close-up](../02%20Art/References/range-v5/terminal3_joins.png) · [bay](../02%20Art/References/range-v5/terminal3_bay.png) · [back 3/4](../02%20Art/References/range-v5/terminal3_back34.png).
- **Self-grade 8/10** (my grades run high): reads as a built kiosk, joins are stepped or seated everywhere, quiet panel middles. Weak spots: the back panel is a big plain plane (only the hatch groove, slots and bolts), the kick plate is a plain bar, preview colours are not the Studio ones. Studio still needs: colours (Body grey, Trim charcoal, Steel gunmetal, Glow Neon range teal `#2BD9A8`), a PointLight/SurfaceLight under the glow strip, the SurfaceGui on the screen, collisions (Box on Body/Trim, off on Glow/Screen/Steel), swap onto the six `RangeLoadout` spots.
