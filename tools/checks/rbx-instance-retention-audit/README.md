---
name: rbx-instance-retention-audit
description: Detect steady instance growth after repeated gameplay cycles for Roblox development using captured measurements or traces.
---

# Detect steady instance growth after repeated gameplay cycles

Record instance counts scoped to the affected system after each cycle has fully settled. Keep the same cooldown and baseline marker. Capture more than three cycles for a real diagnosis, especially if there is legitimate warm-up.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

Increasing settled counts suggest cleanup or pooling behavior worth inspecting. The tool flags baseline growth and a positive fitted trend using thresholds from the task. It measures instance counts and does not diagnose Lua memory or leaks outside the logged system.
