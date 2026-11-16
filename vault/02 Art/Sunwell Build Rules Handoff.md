# Sunwell Build Rules Handoff

This note collects every rule, taste call and build method from the Sunwell hub sessions (2026-11-12 to 2026-11-13, rounds 1-24). A new chat can start from it. Details and history: [Sunwell Hub Upgrade](Sunwell%20Hub%20Upgrade.md), [Sunwell Works Build](Sunwell%20Works%20Build.md), [Style Bible](Style%20Bible.md) §7, the `gauntlet-build-style` skill.

## 1. Always
- **Work from the vault.** Load `gauntlet-vault` first, then the LihFolk router (`lihfolk-worldbuilding`, `roblox-blender-modeling`), then the [Style Bible](Style%20Bible.md) and `gauntlet-build-style`.
- **Plans and results go in the vault.** Put this rule in every agent brief.
- **Loop:** Review, Plan, Execute, Grade, repeat. The goal is quality, not finishing: grades should reach 9-10.
- **Work in phases.** Do only the focus the owner picked, and park other ideas in Bugs & Ideas.
- **Keep usage lean:**
  - give agents tight briefs;
  - grep and ranged reads, not whole notes;
  - no screenshot fumbling.

## 2. Hard shape rules (owner)
- **No round curves or spheres.** Curves are angled plates:
  - pipes are 8-sided;
  - rings and turbines are 12-gons;
  - plinths and posts are octagons;
  - arches are four flat plates.
- **No blunt cutoffs or harsh corners.** Use chamfered or cut corners (`cham_rect`), bevel steps and flared feet.
- **Transitions at every joint.**
  - A pipe enters a wall through a flange, and passes a pier through a collar on both faces.
  - A clamp wraps the pipe: wall plate, stand-off, band.
  - Lights hang from housings, not floating slabs.
- **Nothing floating, nothing see-through, no glitches.** No z-fighting: visible coplanar faces fail the audit. Colliders are inset from the visual edges (pilaster colliders inset 0.18), or they show through as dark strips.
- **Every object is a standalone piece** that the owner can move in Studio without moving anything else.
- **Blocky in spirit, but soft and tactical.** Not neon, not glitch, not a RIVALS copy (study, don't copy).

## 3. Look and palette: de-steampunk (owner's friends, 2026-11-13)
- **Rejected as steampunk:** brass, bronze metal, ochre pipes, wood tops, valve hand wheels, amber lamp lenses, one warm sepia cast. Also rejected: blue-teal structure, rounded "AI" shapes, wide flat washes.
- **Palette (`sw_core.LOOKS`):**

  | Use | Name and colour |
  |---|---|
  | Walls | Wall `#929597`, Cast/CastTrim `#BDBFBF`, WallShade `#86898B` |
  | Wainscot, belt and base | WallLow (slate) `#50565B`, Belt `#34383C`, WallBase `#2B2E32` |
  | Ceiling | Ceil `#8E9297` |
  | Floors | Floor `#6B6F74`, Walk `#B0B2B3` |
  | Metal | Petrol `#41454A`, PetrolDark `#2F3236`, Charcoal `#26292C`, Graphite `#3A3E42` |
  | Sign letters | Cream `#F2F2EE` (clean white) |
  | Gold accents | Stripe and Bronze, flat SmoothPlastic `#D8A530` |

- **One accent colour per room:**

  | Room | Accent |
  |---|---|
  | Duels | orange |
  | Locker | blue |
  | Range | mint |
  | Shop | amber |
  | Hall | gold lines |

  Doorway floor pools use the wing colour: Duels `#FF9F66`, Locker `#A8CCFF`, Range `#A6EDC6`, Shop `#FFC46E`.
- **Owner taste:**
  - walls need trim, not texture;
  - fixtures with character (the bulkhead lamp, now with small cut corners so it doesn't read as a capsule);
  - uniform, ordered queue pads;
  - SurfaceGui boards;
  - a clear hero (the turbine bay: stepped dark frame, angled corner plates, gold rim, lit dais).

## 4. Lighting lessons (Roblox)
- **Light walls clip to white.** Lower the exposure or the fills first, or colour changes never show.
- **Neon lighter than about `#8C877F` clips to white.** Keep the emissive materials dim: E_Opal `#808284`, E_Lamp `#8F8E8A`.
- **Local lights dominate interiors.** Use spot pools on the floor, not wide washes. Every amber light colour maps to a neutral white (`S.NEUTRAL`).
- **Current settings (`Build_SW1.luau`, `use("Sunwell")`):**
  - Exposure -0.75, Ambient 52,56,64, OutdoorAmbient 90,96,110, Brightness 2.3, EnvironmentDiffuseScale 0.2, ShadowSoftness 1.
  - Grade: contrast 0.16, saturation 0.02.
  - Atmosphere: haze 0.15, density 0.22.
  - Bloom 0.6 / 18 / 1.6.
  - Point lights only, scaled per area by `M.POINT_MULT`: hall 0.55, Shop 0.75, Locker 0.8, Duels 0.9.
- **Rejected:** a lower-key test (dark ceiling `#6E7277`, exposure -0.5) scored 7.08 and read as dead, flat ceilings.

## 5. Build pipeline
- **Blender, live MCP only.**
  - Port 9876 (a second instance for lobby V4 uses 9934). No background Blender for map assets.
  - File: `art-source/lobby/SunwellWorks.blend`.
  - Builders: `tools/blender/sunwell_p1/` (`sw_core`, `sw_hall`, `sw_doors`, `sw_props`, `sw_hub`, `sw_shop`, `sw_locker`, `sw_duels`, `sw_export`, `sw_run`) on top of `tools/blender/lobby_v3/lv3_core.py`.
  - Run, in order: `sw_run.build_all(cams=False)`, `sw_run.audit()`, `sw_export.run()`, `sw_run.save()`.
  - Retry `sw_export.run()` when Windows locks an FBX (`OSError 22`).
  - Audit gate: 0 leaks, 0 zero-face meshes, no new visible coplanar pairs. Open edges on text are known.
- **Pieces:** wrap each object in `with S.grp(name, M, inst=True, reuse=False):`. Identical pieces share one mesh. Mesh names count per area (`Kit.SEQS`).
- **Upload all areas every time** (a partial upload once emptied the Locker and Duels):
  - `python tools/opencloud/upload_models.py --lobby --group 11116787 SW1_Hall SW1_Doors SW1_Props SW1_Locker SW1_Shop SW1_Duels SW1_Hub`
  - `python tools/studio/sunwell_p1/upload_data.py --group 11116787` (asset 137338720894061)
  - The key comes from `ROBLOX_ASSETS_KEY`; never print it.
- **Studio** (Lobby place, Edit mode):
  1. Wait about 10 s, then `InsertService:LoadAsset(137338720894061)`.
  2. Replace `ServerStorage.SW1Data`.
  3. `require(SW1Data.Build:Clone())`, then `.rebuild()` and `.use("Sunwell")`.
  4. Expect "missing 0".
  - `use("V3")` rolls back.
  - Don't `require` server gameplay modules through MCP; it breaks the remotes.
- **Captures:**
  - Move `workspace.CurrentCamera` and wait about 2 s before `screen_capture`, or the boards render black. Preload before calling a missing mesh a bug.
  - Put R15 stand-ins in `workspace.ScaleDummies` for scale, then remove them.
  - Standard views: spawn, enter, reverse, turbine, duels, shop, locker. Camera positions are in the hub note.
  - Save as `References/lobby/sunwell-works/hub-upgrade/rNN-xx-name.jpg`.
- **The owner saves the place.** Don't save or publish it; remind the owner.

## 6. Grading
- **Panels:** 2 blind panels × 3 lenses.
  - Panel A: art director, environment artist, lighting artist.
  - Panel B: level designer, Roblox art lead, UX/flow designer.
  - Each panel sees only the captures, plus a steampunk yes/no and a glitch list.
  - Screens, billboards and case contents are placeholders: reviewers ignore them.
- **Rubric:**
  - W1 composition ×3, W2 navigation ×3, W3 cohesion ×2, W4 lighting ×2, W5 detail ×1, W6 scale ×1.
  - Score = weighted median / 12 → out of 10.
- **Stop rule** ([Map Quality Standard](../01%20Design/Maps/Map%20Quality%20Standard.md) §6): roll back a change that scores clearly worse. Stop when the median holds across rounds and the panels only ask for new dressing.
- **History:**

  | Rounds | Blind score |
  |---|---|
  | 16-19 (warm palette) | 8.75 |
  | 20 (de-steampunk) | 8.33 |
  | 21 (rolled back) | 7.08 |
  | 22-24 | about 8.0 (W4 lighting and W5 dressing at 7) |

- **Check the reviewers' glitch claims in Studio before fixing them.** The "floating" Shop ceiling lights were really flush.

## 7. Open owner calls
1. What the turbine bay is for: an event podium, a party-up pad, or stop the chevrons at the Sun Well.
2. The Locker shutter reads as a curtain. Option: a segmented metal shutter with a blue edge light.
3. The Range's green reads off-palette.
4. Shop dressing and cases come later (placeholders for now).

## 8. Git and vault upkeep
- **Commit on main and push at the end of the session.**
  - Stage exact paths only. Never `git add -A` or `git add vault`: the repo is public and third-party screenshots live in the vault.
  - In shared notes (Asset Tracker), stage only your own hunks.
  - No `.rbxl` or secrets.
  - Commit messages end with the Co-Authored-By line.
- **After each task:**
  - update Home → Status (keep it short; move old entries to Status History);
  - update the Asset Tracker Lobby row;
  - update the hub note;
  - add new notes to INDEX.
- **ChatGPT/Codex:** give the owner prompts to paste. No computer use unless asked.
