---
name: rbx-rig-channel-coverage
description: Find animation tracks that do not bind to the target Roblox rig for Roblox development using captured measurements or traces.
---

# Find animation tracks that do not bind to the target Roblox rig

Export or transcribe channel paths used by the clip and bone or joint paths from the destination rig using a consistent root convention. List required channels and allowed extras separately. Use full relative paths to distinguish repeated joint names.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

Unbound tracks need a retarget or corrected rig path. A required channel absent from the clip may be an export selection issue. Play a known clip on the destination rig after making changes.
