---
name: rbx-dual-rig-contact
description: Check maintained contacts between actors or props across a choreography window for Roblox development using captured measurements or traces.
---

# Check maintained contacts between actors or props across a choreography window

Add a marker at each intended contact point. Sample both world positions and their desired compatible direction vectors while the contact is held. Include beginning, middle, and end, and record sample times in the same playback run.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

A drifting gap points to mismatched performer or prop spacing. A sustained angular mismatch points to orientation or constraints. Solve the acting poses and shared anchor before adding secondary motion. Check clipping on the actual rigs after adjustment.
