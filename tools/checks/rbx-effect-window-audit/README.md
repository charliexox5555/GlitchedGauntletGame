---
name: rbx-effect-window-audit
description: Catch active trails or emitters that survive an interrupted action for Roblox development using captured measurements or traces.
---

# Catch active trails or emitters that survive an interrupted action

Log actual enabled and disabled transitions by effect instance. Mark the test cutoff time and maximum allowed active seconds. Record a second test for interruption during the enabled window with cutoff at the required cleanup deadline.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

A missing disable, extra enable, or long active window identifies an ownership or cancellation bug. Trails and particles may legitimately decay after disabled. Verify tails in the visual test separately.
