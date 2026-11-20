---
name: rbx-frame-time-regression
description: Compare repeatable frame-time captures before and after a change for Roblox development using captured measurements or traces.
---

# Compare repeatable frame-time captures before and after a change

Record baseline and candidate frame durations in milliseconds on the same route, device class, graphics and scene state. Capture enough frames to make the chosen percentile meaningful. Set the allowed p95 regression and candidate frame budget.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

Check p95 and the budget together. Higher tail latency with unchanged median usually calls for inspecting spikes. A single device trace cannot establish release-wide performance.
