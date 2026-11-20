---
name: rbx-spawn-travel-balance
description: Compare spawn-to-objective travel times for Roblox development using captured measurements or traces.
---

# Compare spawn-to-objective travel times

Record repeat runs from each team's actual spawn to the same neutral objective using equivalent movement options. Include each team as a key in `times_s`. Keep map variant and start state fixed.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

The median spread identifies which team arrives earlier. Investigate route length, movement buffs, and doors separately. Match the objective state and repeat the same route after editing.
