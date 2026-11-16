# Weapon remaster handoff — 2026-11-07

**USER ART REVIEW: REJECTED.** This first pass is superseded. Its technical checks and exports are historical records, not approval. Follow the [Astra rebuild handoff](../../../../vault/05%20Production/Astra%20Weapon%20Rebuild%20Handoff%202026-11-07.md) for the fresh direction. The user will review a new Vandal concept before that direction is handed over or applied to the remaining roster.

18 assets are built: 17 guns and the Knife. Akimbo is skipped. Vandal and Classic were the style pilot, followed by rifles, SMGs, remaining sidearms, shotguns, snipers, machine guns and Knife.

Start with [hero render gallery 1](review-gallery-01.png) and [hero render gallery 2](review-gallery-02.png). Each weapon has a full-size nine-view review sheet linked below.

Also available: [the same-scale lineup grid](lineup-grid.png), [the horizontal lineup](lineup.png), and [the pilot style sheet](style-sheet.png). The lineup scene is saved as [Lineup.blend](Lineup.blend).

## Deliverables

Each `Remaster/<Id>/` contains `concept.png`, `<Id>.blend`, nine review PNGs, `renders/review-sheet.png`, `<Id>.fbx`, `<Id>.json`, and local audit reports. The JSON is generated through the existing project exporter and includes bones, attachment matrices, material roles, per-frame animation transforms and event markers.

The shared [Library.blend](Library.blend) contains the seven role materials, packed clean colour/roughness trim images, eight `Round_<Type>` models, eight `Casing_<Type>` models, and the reference arm pair. Round types are Pistol, HeavyPistol, SMG, Rifle, Shell, Sniper, Operator and Belt. Operator ammunition is the largest. The PNG trim sources are [clean-trim.png](clean-trim.png) and [roughness-trim.png](roughness-trim.png).

| Weapon | Tris | Actions | Review | Blender | FBX | Animation data |
|---|---:|---:|---|---|---|---|
| Vandal | 3,300 | 5 | [Sheet](../Vandal/renders/review-sheet.png) | [.blend](../Vandal/Vandal.blend) | [.fbx](../Vandal/Vandal.fbx) | [.json](../Vandal/Vandal.json) |
| Classic | 2,632 | 6 | [Sheet](../Classic/renders/review-sheet.png) | [.blend](../Classic/Classic.blend) | [.fbx](../Classic/Classic.fbx) | [.json](../Classic/Classic.json) |
| Bulldog | 3,308 | 5 | [Sheet](../Bulldog/renders/review-sheet.png) | [.blend](../Bulldog/Bulldog.blend) | [.fbx](../Bulldog/Bulldog.fbx) | [.json](../Bulldog/Bulldog.json) |
| Phantom | 3,344 | 5 | [Sheet](../Phantom/renders/review-sheet.png) | [.blend](../Phantom/Phantom.blend) | [.fbx](../Phantom/Phantom.fbx) | [.json](../Phantom/Phantom.json) |
| Guardian | 3,408 | 5 | [Sheet](../Guardian/renders/review-sheet.png) | [.blend](../Guardian/Guardian.blend) | [.fbx](../Guardian/Guardian.fbx) | [.json](../Guardian/Guardian.json) |
| Stinger | 3,368 | 5 | [Sheet](../Stinger/renders/review-sheet.png) | [.blend](../Stinger/Stinger.blend) | [.fbx](../Stinger/Stinger.fbx) | [.json](../Stinger/Stinger.json) |
| Spectre | 3,276 | 5 | [Sheet](../Spectre/renders/review-sheet.png) | [.blend](../Spectre/Spectre.blend) | [.fbx](../Spectre/Spectre.fbx) | [.json](../Spectre/Spectre.json) |
| Shorty | 1,916 | 5 | [Sheet](../Shorty/renders/review-sheet.png) | [.blend](../Shorty/Shorty.blend) | [.fbx](../Shorty/Shorty.fbx) | [.json](../Shorty/Shorty.json) |
| Ghost | 2,920 | 5 | [Sheet](../Ghost/renders/review-sheet.png) | [.blend](../Ghost/Ghost.blend) | [.fbx](../Ghost/Ghost.fbx) | [.json](../Ghost/Ghost.json) |
| Sheriff | 2,800 | 5 | [Sheet](../Sheriff/renders/review-sheet.png) | [.blend](../Sheriff/Sheriff.blend) | [.fbx](../Sheriff/Sheriff.fbx) | [.json](../Sheriff/Sheriff.json) |
| Judge | 3,480 | 5 | [Sheet](../Judge/renders/review-sheet.png) | [.blend](../Judge/Judge.blend) | [.fbx](../Judge/Judge.fbx) | [.json](../Judge/Judge.json) |
| Bucky | 3,380 | 8 | [Sheet](../Bucky/renders/review-sheet.png) | [.blend](../Bucky/Bucky.blend) | [.fbx](../Bucky/Bucky.fbx) | [.json](../Bucky/Bucky.json) |
| Marshal | 3,656 | 8 | [Sheet](../Marshal/renders/review-sheet.png) | [.blend](../Marshal/Marshal.blend) | [.fbx](../Marshal/Marshal.fbx) | [.json](../Marshal/Marshal.json) |
| Outlaw | 3,280 | 5 | [Sheet](../Outlaw/renders/review-sheet.png) | [.blend](../Outlaw/Outlaw.blend) | [.fbx](../Outlaw/Outlaw.fbx) | [.json](../Outlaw/Outlaw.json) |
| Operator | 4,468 | 5 | [Sheet](../Operator/renders/review-sheet.png) | [.blend](../Operator/Operator.blend) | [.fbx](../Operator/Operator.fbx) | [.json](../Operator/Operator.json) |
| Ares | 3,720 | 5 | [Sheet](../Ares/renders/review-sheet.png) | [.blend](../Ares/Ares.blend) | [.fbx](../Ares/Ares.fbx) | [.json](../Ares/Ares.json) |
| Odin | 4,148 | 5 | [Sheet](../Odin/renders/review-sheet.png) | [.blend](../Odin/Odin.blend) | [.fbx](../Odin/Odin.fbx) | [.json](../Odin/Odin.json) |
| Knife | 658 | 9 | [Sheet](../Knife/renders/review-sheet.png) | [.blend](../Knife/Knife.blend) | [.fbx](../Knife/Knife.fbx) | [.json](../Knife/Knife.json) |

## Verified locally

- All 18 Blender audits pass, including pairwise skin UV triangle intersection checks. No overlapping skin UV triangle pairs or material-role violations remain.
- 57,062 triangles across the set; every weapon is within its class budget. Every hard-surface chamfer is included in that count.
- 101 armature Actions across the set, with NLA tracks and timeline event markers. Existing bone names, event times and actual source clip lengths are preserved. Root motion has a slightly stronger snap and magazine extraction is more readable.
- Every required attachment and existing extra is present. Root and RightGrip are at the grip origin. +X is the bore direction, +Z is up, and 1 unit is 1 stud. Muzzle is at the original bore exit and points down the barrel.
- Length and overall height stay within about 10% of the originals; thickness is increased where needed. Physical sight heights vary per design.
- The eye exclusion radius is clear for every weapon: minimum clearance 0.165 studs, above the 0.16-stud requirement.
- All main shell UVs use a 2048px atlas at 128 pixels per stud. Broad planar shell faces have their own islands; bevel islands are separate and padded. `UVMap` is the skin layout, and `TrimUV` addresses the shared Default material trim. Texture images are packed in every .blend.
- All 18 FBX files were re-imported into the isolated Blender worker. Triangle totals, bone names, required locators and the expected `Rig|<Clip>` animation takes survived. Full reports are `audit.json` and `export-check.json` beside each asset.

## Viewing and integration

The weapon collection is named exactly for its ID. Meshes use `<Part>_<Role>` names and rigid bone parenting, matching this project's per-part Motor6D pipeline. Reference arms, lights, cameras and rendered locator labels are outside the weapon collection and excluded from the FBX/JSON export.

NLA tracks are muted in the authored .blend so the gun opens at rest. Select its armature and choose an Action in the Action Editor to inspect a clip, or enable one NLA track at a time. The Knife's Reload and ReloadEmpty are utility regrip motions; its attack clips are Slash1–3 and HeavyStab with Hit markers.

Studio import, viewmodel hold offsets, ADS tuning, lighting in the game, and final artistic approval remain for the user. No Studio session was opened or modified. The existing source .blend files, GunTest.blend, game code and original build/animation scripts were left untouched.

## Documented substitutions and authorization

The built-in image generator rejected the initial Vandal concept request with a violence filter. No generated raster concept was returned. Rather than wait while the user was away, each weapon received a Blender-rendered blockout concept sheet **before** its final model was built. This differs from the brief's requested AI image-generation step; it is recorded in every result row. See [the image-generation attempt](imagegen-attempt.md) for the original prompt and tool result.

The brief originally prohibited export. The user's latest message explicitly permitted it ("if you can export them, you can export them"), so optional FBX and pipeline JSON exports were created here. No files were uploaded.

## Reproducibility

All modeling, UV, rig, animation, rendering and export work ran through the installed Blender MCP addon's local execute protocol, in a separate **background Blender worker**. The open interactive Blender scene and its unsaved work were not used. Consequently the interactive Blender lock was not needed.

The scripts in this folder are scoped to `Remaster/` and the results section of the production brief. `remaster.py` builds the designs; `run_remaster.py` orchestrates concept-first generation and the results table; `audit_export.py` audits and uses the original exporter with its output path redirected here. `source_contracts.json` records the read-only source dimensions and skeleton/attachment contract. These are editable source files for further art iteration.
