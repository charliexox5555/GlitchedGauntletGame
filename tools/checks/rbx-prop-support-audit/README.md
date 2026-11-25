---
name: rbx-prop-support-audit
description: Check for floating or buried set dressing at its support points for Roblox development using captured measurements or traces.
---

# Check for floating or buried set dressing at its support points

Pick the intended contact points under each decoration. Measure each contact's world Y and the support surface Y at the same X and Z, using a downward ray that filters the prop itself. Record a sample per foot on benches or shelters.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

Positive deltas flag floating feet. Negative deltas flag possible burial. Accept explicit sunk joints at their chosen budget and route-test collision separately.
