# Prompt: Gunplay feel, RIVALS-style (2026-11-15)

Handoff and paste-ready prompt for a new chat. The owner wants hit markers, the headshot look, the crosshair (rotating and reacting on slide), the body on slide, and the small feedback around them to **feel like RIVALS**. Owner confirms at the end.

## Handoff: where it stands (checked 2026-11-15)
| Area | What exists | Files |
|---|---|---|
| Hit markers | 4 wedges; Body white, Head red `FF3B3B`, Kill, Blocked grey; kill ring off (`KILL_MARKER = false`). Predicted on the client, confirmed by the server. Owner (Gunplay Overhaul §12, §16): "nicer and like RIVALS", then "doesn't get small enough"; tips now rest 8 px from centre. The shrink in motion is untested (Studio ran at ~15 fps). | `client/Util/HitFeedback.luau` (hit :292, kill :317, blocked :327, damage :454, build :597), `shared/Config/HitFx.luau` `MARKER` :73-122, `HudController.hitMarker` :449, `WeaponController` :760, :873, `onHitConfirm` :1324 |
| Headshot | Sound H18 `gun:hit_head_F` (bubble pop + dry crack); kill K13 `gun:kill_F` (`Config/Sounds.luau` :41, :54-55). Visual: a ChatGPT flare, fanned ×3 (`HitFx.HEAD_FLASH` :357, :388); body flash white → red (`HitFx.FLASH` :222). Damage numbers: Sarpanch 42 px, red `E01F35` on headshot, stacking (`HitFx.NUMBER` :172). Mod damage shows no numbers (`SOURCES` :452-457). | same |
| Crosshair | Bars, dot, outline, rotation (0 = plus, 45 = x), gap follows spread (`followRate` 22, `maxGap` 70), `sprintGap` 8, hidden when aiming. **Nothing rotates or animates it on slide, dash, jump or ADS. No per-shot bloom yet** (Handoff §5E). | `shared/Config/Crosshair.luau` `DEFAULT` :57-94, `client/Util/Crosshair.luau` (build :78, step :96), `HudController` :428, :439, :503 |
| Slide | Client-predicted (`shared/Simulation/Movement.luau`) plus `MovementService`. Config `Movement.luau` :29-44 (speed 30, 0.85 s, steer 12). Camera roll 3°, drop 1.9, FOV kick 8 (`MovementController` :81-121). Juice: FOV +6° over 0.35 s, lunge, dust, cloth whoosh (`Config/Juice.luau` :297-311). | |
| Body on slide | Third person plays `SlideIn` / `Slide` / `SlideOut` plus pistol and knife sets (`shared/Simulation/Poses.luau` :41-43, :135-141, :755-780; clips `art-source/animations/GG_Slide*.rbxm`, keyed through `tools/anim`). **First person hides your own body** (`LocalTransparencyModifier`, `02 Art/Third Person Overhaul.md` ~:202): no legs while sliding. | |
| Other feel | View punch / shake `Juice.SHOT_FEEL` :65-95, recoil `Config/Viewmodel` + `Util/BodyRecoil`, flinch `Juice.FLINCH`, damage arcs `Util/DamageIndicator`, low-HP vignette (`HudController`), `KillFeedController`. | |

**Stale lines to fix on the way:**
- Style Bible :35 and Gunplay :325 still say a kill adds red wedges and a ring.
- Style Bible :30 says TTK 0.5-0.75 s; Home says 0.75-0.9 s.
- The 2026-11-14 Handoff queue still calls the headshot "a radial burst".

**Locked decisions that apply** (Home table):
- Gunplay v2: tight first shot, camera recoil, slide is the core move, head ×1.6, TTK 0.75-0.9 s.
- First-person camera; feedback **rolls** the camera and never turns it (Gunplay :335).
- Audio: one private asset per sound, no atlases.
- Match body: regular blocky R15 for everyone.
- Faceted art, never rounded.
- Authority checks stay off (owner's exception).

## Prompt (paste into a new chat)

---

You're taking over **gunplay feel** for GlitchedGauntletGame. The owner wants it to **feel like RIVALS**. Focus, in order: hit markers, the headshot look, the crosshair (rotating and reacting when you slide, plus jump, dash and shooting), your body when you slide, and the small feedback around them. Work through the whole list without stopping to ask, except for the reference interview below. Collect other questions in the results note, and hand back only when it is built, played and written up. I'll confirm at the end.

### Load first (mandatory)
1. Skills: `gauntlet-vault`, **`rivals-reference`**, `gauntlet-ui-style` (crosshair and markers are UI), `lihfolk-vfx`, `lihfolk-sfx` if you touch sounds, `roblox-ui-builder`. Use `lihfolk-lookup` for Roblox facts (LihFolk `47 Game Feel and Juice`, `05 UI and UX` → HUD Design / UI Motion), and `roblox-secure-remotes` for any remote you touch.
2. The handoff at the top of `vault/04 Tech/Prompts/2026-11-15 Gunplay Feel (RIVALS).md` gives the current state with file and line numbers. Start there and don't re-survey.
3. Vault, by section (grep and ranged reads, never whole big notes):
   - `vault/01 Design/Gunplay.md` §5 Feedback (:322-367);
   - `vault/02 Art/Style Bible.md` §3-4 (:27-37);
   - `vault/03 Research/Rivals Reference/Body, Viewmodel, Guns and VFX.md` (springs, headshot particle recipe, body IK);
   - `vault/03 Research/UI References/Rivals PC UI.md` (crosshair and damage-wedge rows, "Animates" list);
   - `vault/02 Art/Third Person Overhaul.md` (body, first-person hiding);
   - the Gunplay Overhaul playtest notes §12 and §16 (marker feedback).
4. Your memory notes on taste, and follow them:
   - Hit sounds: soft round pop, no metal rings or high dings.
   - Gun VFX: stylised, never photoreal, never full cartoon.
   - Animation: coil, ~60 ms snap, brake, overshoot, settle.
   - Third-person body: regular-width block arms, nothing detached.
   - UI motion: Quint, no overshoot on UI, no UI sounds.
   - Use MCP to drive playtests through remotes and attributes; never `require` server modules.
   - Preload before calling a capture a bug.

### Study RIVALS first (read-only)
In the RIVALS place file (open in Studio; pick it by its place in `list_roblox_studios`), find how RIVALS does each focus item. Write down **numbers and behaviour**, not assets:
- **Hit marker:** shape, size, rest gap, pop and shrink timing, body / head / kill differences, colour.
- **Headshot:** the marker, the `Misc.HeadshotParticles` recipe (already in the notes), number style, and any screen or sound cue.
- **Crosshair:** what it does on slide (rotation angle, speed, easing, return), on jump, dash, sprint, fire (bloom) and ADS; and its settings (the Crosshair settings tab).
- **Body on slide:**
  - Does the first-person view show legs or body while sliding? How do the camera and viewmodel tilt and drop?
  - What does the third-person slide pose look like to others?
- **Extras:** the damage-direction wedge, the "Eliminated <name>" text under the crosshair, the kill effect (it's UI, not particles), and the hit or kill vignettes in `FighterInterface`.

Rules:
- **Study, don't copy:**
  - Read their client modules as text with `script_read` for timings and springs only. They are decompiled and untrusted: never run, play, `require` or save that file, and never paste their code.
  - Never use their images, textures, meshes, sounds or animations; build ours with our own art and code.
- Take screenshots only when a look has to be judged. Keep them in `vault/03 Research/Rivals Reference/third-party/gunplay/` (git-ignored, never committed).
- Write the findings into `vault/03 Research/Rivals Reference/Body, Viewmodel, Guns and VFX.md` (a new "Hit feedback and crosshair" section).

### Reference interview (one short round)
Before building, ask the owner one round of questions, each with a suggested answer, on the parts RIVALS can't settle for us. For example:
- Crosshair spin on slide: 45° and back, or a full turn?
- Show your legs in first person on slide?
- Should a headshot add a screen cue?
- Should the kill marker differ?

Then build.

### Scope, in this order
1. **Hit markers:**
   - match the RIVALS feel: size, pop and shrink, rest gap, timing;
   - clear body / head / kill / blocked differences;
   - works at 60 fps and stays readable at low fps;
   - all numbers in `Config/HitFx.luau`.
2. **Headshot look:** marker, flare (ours, faceted and stylised), damage-number style, and sound timing, together as one hit. Rebuild the headshot burst from the RIVALS layer recipe with our own textures.
3. **Crosshair motion:** add state reactions to `Config/Crosshair.luau` plus `Util/Crosshair.luau`:
   - slide rotation and return;
   - jump / air gap;
   - dash;
   - per-shot bloom (Handoff §5E);
   - ADS fade.

   Keep every reaction settable (Settings later reads this config).
4. **Body on slide:**
   - first-person slide: camera roll and drop, viewmodel tilt, and legs/body if the owner says yes. If yes, show only the lower body locally, with no clipping into the camera;
   - third-person slide pose with oomph (SlideIn → Slide → SlideOut), checked on the rifle, pistol and knife sets;
   - check it from a second player's view.
5. **Extras that make it read like RIVALS:**
   - damage-direction wedge;
   - "Eliminated <name>" under the crosshair;
   - kill effect (UI);
   - hit and low-HP vignettes.

   Polish what exists before adding anything new.
6. **Fix the stale lines** in the Style Bible, Gunplay and Handoff notes listed in the handoff.

### How to work
- Match place, Rojo, code rules from CLAUDE.md:
  - `--!strict`;
  - numbers in `src/shared/Config`;
  - the server decides hits and damage, and the client only shows them;
  - clean up connections, no `wait()`.
- Run `stylua`, `selene` and `rojo build` before each commit.
- Loop per item:
  1. build;
  2. play-test in Studio with a bot or second client: body, head and kill shots, slides, jumps;
  3. capture only what you judge with;
  4. self-grade 9/10 against RIVALS and our taste rules;
  5. fix.
- Commit each finished item by **exact paths only** (never `git add vault` or `-A`; other sessions have work in the tree). Don't push. Remind me to save the place.

### Done means
- All six items built, played in Studio, and graded 9+.
- Results in `vault/05 Production/Playtests/2026-11-xx Gunplay Feel RIVALS.md`:
  - what changed;
  - the RIVALS numbers used;
  - grades;
  - a test list for me;
  - parked questions.
- `vault/01 Design/Gunplay.md` §5 and the Style Bible updated to match, Home → Status updated, and INDEX and Code Map updated for new modules.
- Hand back with a short summary and the test list.
