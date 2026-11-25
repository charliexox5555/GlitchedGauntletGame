---
name: rbx-gamepad-focus-paths
description: Find unreachable gamepad controls and focus traps for Roblox development using captured measurements or traces.
---

# Find unreachable gamepad controls and focus traps

Using actual D-pad inputs, record which control receives focus for each tested direction from each visible state. Provide the starting control, required reachable controls, and safe escape states such as a close button.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

The directed graph reports unreachable buttons and reachable states from which an escape cannot be reached. Test simultaneous modal or dynamic list states as separate captures.
