---
name: rbx-foot-plant-drift
description: Measure foot sliding during an intended planted interval for Roblox development using captured measurements or traces.
---

# Measure foot sliding during an intended planted interval

On the actual animated rig, mark contact intervals from the first frame of planted contact to the last. Sample heel or foot marker positions in world space every few frames. Use platform-relative space on moving ground.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

The report gives maximum excursion from the first planted position and vertical bob. Retest the same intervals after tuning pose, stride, or IK. Include at least one interior sample to catch drift that returns by the last frame.

**Feet with no ankle that roll heel to toe (added 2026-11-20, GlitchedGauntletGame TP lane).** A block foot stands on its lowest corner and rolls onto the next one, so the contact point legitimately travels about a block length along the ground while nothing slips. Sampling "the lowest corner" each frame reads that roll as drift (our RunF showed 1.41 studs "lateral" with no slip at all). Feed **integrated slip** instead: start at the first contact point and add, each frame, how far the *same* corner (the one in contact at the earlier frame) moved over the ground between the two frames. That is the distance the sole's material slid; the limits keep their meaning. `tools/anim/tp_measure.py` does this for the game's clips.
