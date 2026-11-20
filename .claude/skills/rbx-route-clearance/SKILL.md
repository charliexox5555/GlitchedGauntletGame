---
name: rbx-route-clearance
description: Find the tightest avatar clearance along a route for Roblox development using captured measurements or traces.
---

# Find the tightest avatar clearance along a route

Measure clear width and overhead height at labeled stations along the intended collision path. Record the bounding width and height of the target avatar or vehicle and the clearance to keep on each side and above it.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

Fix negative margins at their named stations. Measure corners, changing terrain, or tilted geometry at extra stations because this check covers the sampled cross-sections.
