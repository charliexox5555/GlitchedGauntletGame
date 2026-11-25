---
name: rbx-round-transition-audit
description: Detect illegal or stale round phase transitions for Roblox development using captured measurements or traces.
---

# Detect illegal or stale round phase transitions

Log server phase changes as chronological events carrying a round identity, a from state, and a to state. Define the allowed graph and the required final phase. Start a replay from the same initial phase and round snapshot.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

A wrong from state often means old asynchronous work fired after a reset. Inspect the first mismatch and repeat the same transition sequence. Round identity may advance only when a phase enters the declared start phase.
