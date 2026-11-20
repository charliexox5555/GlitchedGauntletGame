---
name: rbx-import-calibration
description: Detect mesh scale and facing changes during Roblox import for Roblox development using captured measurements or traces.
---

# Detect mesh scale and facing changes during Roblox import

Provide expected and observed bounding dimensions and the local unit direction of the front in a common coordinate convention. Measure in Studio after import. Include a known-size dimension anchor in the source model.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

Per-axis ratios identify uniform versus nonuniform scale and a rotated facing identifies orientation problems. Inspect exporter axis and scale settings and reimport the same asset. Pivot placement and rig deformation require separate checks.
