# Weapon model sheets

One page per weapon, made from the final-pass models (`RemasterV2/<Gun>/<Gun>_RemasterV2_v05.blend`, 2026-11-11). Each `<Gun>_model_sheet.png` (3890 x 2400) is meant to be dropped into ChatGPT as the base when asking for a new skin or a new gun in the same style.

What is on a sheet:
- the name, class, triangle count and the nine colour roles with their hex values (a skin recolours or patterns these roles);
- the turnaround: three-quarter left (the side the player sees), left, right, top, bottom, front, back, three-quarter rear right;
- the magazine out of the gun (or the drum, belt, cylinder, shells or rounds) and a close-up of the round;
- the first-person angle, the aim-down-sights picture (iron-sight guns) or a view from above, the rear sight or scope, and the charm mount.

In the left, top and bottom views the muzzle points left.

## Prompt starter
> This is the base model sheet of the **<Gun>** from my game. Design a **<theme>** skin for it. Keep the exact silhouette, proportions and every part where it is (sights, magazine, charm mount, controls). Only change colours, materials and surface pattern, and keep it stylised low-poly with flat colour areas. Show the result as the same kind of sheet: three-quarter left, left side, right side, top, the magazine and the round.

## Rebuild
The panels are rendered in Blender (the gun loaded with `_Library/final_pass.py`) by `_Library/model_sheet.py` into `panels/<Gun>/`, then laid out with:

```bash
python art-source/weapons/RemasterV2/_Library/model_sheet_layout.py art-source/weapons/ModelSheets/panels/<Gun> art-source/weapons/ModelSheets/panels/<Gun>/meta.json art-source/weapons/ModelSheets/<Gun>_model_sheet.png
```

`panels/` is not committed (72 MB of single renders); the sheets are.
