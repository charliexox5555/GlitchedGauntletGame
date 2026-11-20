---
name: rbx-npc-stuck-recovery
description: Find NPCs that stay stuck too long before recovering for Roblox development using captured measurements or traces.
---

# Find NPCs that stay stuck too long before recovering

Record consecutive time and world-position samples of an NPC with a stable movement goal. Mark samples `should_move=false` for deliberate waiting. Sample often enough that the allowed stall window contains multiple samples.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

Each segment with movement rate below the threshold counts toward a stall. Inspect starts and ends against path invalidation or blocked waypoints. Runs standing still on purpose should be excluded by the flag.
