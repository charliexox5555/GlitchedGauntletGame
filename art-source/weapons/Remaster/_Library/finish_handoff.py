from pathlib import Path
import json
from run_remaster import ORDER, update_results, style_sheet
BASE=Path(__file__).resolve().parent.parent
reports=[json.loads((BASE/g/'review.json').read_text()) for g in ORDER]
audits=[json.loads((BASE/g/'audit.json').read_text()) for g in ORDER]
exports=[json.loads((BASE/g/'export-check.json').read_text()) for g in ORDER]
assert all(r['passed'] for r in audits), 'Unresolved Blender audit'
assert all(r['passed'] for r in exports), 'Unresolved FBX audit'
for g in ORDER:
    for p in ['concept.png',g+'.blend',g+'.fbx',g+'.json','renders/review-sheet.png']:
        assert (BASE/g/p).exists(), (g,p)
update_results(); style_sheet()
rows=['| Weapon | Tris | Actions | Review | Blender | FBX | Animation data |','|---|---:|---:|---|---|---|---|']
for r in reports:
    g=r['gun']; stem='../'+g+'/'
    rows.append(f"| {g} | {r['tris']:,} | {len(r['clips'])} | [Sheet]({stem}renders/review-sheet.png) | [.blend]({stem}{g}.blend) | [.fbx]({stem}{g}.fbx) | [.json]({stem}{g}.json) |")
total=sum(r['tris'] for r in reports); actions=sum(len(r['clips']) for r in reports)
text=f'''# Weapon remaster handoff — 2026-11-07

18 assets are built: 17 guns and the Knife. Akimbo is skipped. Vandal and Classic were the style pilot, followed by rifles, SMGs, remaining sidearms, shotguns, snipers, machine guns and Knife.

Start with [hero render gallery 1](review-gallery-01.png) and [hero render gallery 2](review-gallery-02.png). Each weapon has a full-size nine-view review sheet linked below.

Also available: [the same-scale lineup grid](lineup-grid.png), [the horizontal lineup](lineup.png), and [the pilot style sheet](style-sheet.png). The lineup scene is saved as [Lineup.blend](Lineup.blend).

## Deliverables

Each `Remaster/<Id>/` contains `concept.png`, `<Id>.blend`, nine review PNGs, `renders/review-sheet.png`, `<Id>.fbx`, `<Id>.json`, and local audit reports. The JSON is generated through the existing project exporter and includes bones, attachment matrices, material roles, per-frame animation transforms and event markers.

The shared [Library.blend](Library.blend) contains the seven role materials, packed clean colour/roughness trim images, eight `Round_<Type>` models, eight `Casing_<Type>` models, and the reference arm pair. Round types are Pistol, HeavyPistol, SMG, Rifle, Shell, Sniper, Operator and Belt. Operator ammunition is the largest. The PNG trim sources are [clean-trim.png](clean-trim.png) and [roughness-trim.png](roughness-trim.png).

{chr(10).join(rows)}

## Verified locally

- All 18 Blender audits pass, including pairwise skin UV triangle intersection checks. No overlapping skin UV triangle pairs or material-role violations remain.
- {total:,} triangles across the set; every weapon is within its class budget. Every hard-surface chamfer is included in that count.
- {actions} armature Actions across the set, with NLA tracks and timeline event markers. Existing bone names, event times and actual source clip lengths are preserved. Root motion has a slightly stronger snap and magazine extraction is more readable.
- Every required attachment and existing extra is present. Root and RightGrip are at the grip origin. +X is the bore direction, +Z is up, and 1 unit is 1 stud. Muzzle is at the original bore exit and points down the barrel.
- Length and overall height stay within about 10% of the originals; thickness is increased where needed. Physical sight heights vary per design.
- The eye exclusion radius is clear for every weapon: minimum clearance {min(r['eye_clearance'] for r in reports):.3f} studs, above the 0.16-stud requirement.
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
'''
(BASE/'_Library/README.md').write_text(text,encoding='utf-8')
summary={'weapons':18,'guns':17,'knife':1,'skipped':['Akimbo'],'total_tris':total,'total_actions':actions,'review_renders':18*9,
    'blender_audits_passed':18,'fbx_roundtrips_passed':18,'minimum_eye_clearance':min(r['eye_clearance'] for r in reports),
    'concept_method':'Blender sheets substituted after built-in image generation rejection','studio_validation':'Pending user'}
(BASE/'_Library/completion.json').write_text(json.dumps(summary,indent=2))
print(json.dumps(summary,indent=2))
