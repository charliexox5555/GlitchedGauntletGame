---
name: rbx-camera-handoff-audit
description: Check control restoration after camera ownership changes for Roblox development using captured measurements or traces.
---

# Check control restoration after camera ownership changes

Record a sample after each skip, death, missing target, or replacement transition. Read the current camera mode, current subject identity, and movement-enabled state. The subject identity should distinguish an old character from its respawn.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

Use the failed field to trace camera cleanup, subject rebinding, or input unlock. Collect the result at the expected handoff rather than waiting indefinitely for some later recovery.
