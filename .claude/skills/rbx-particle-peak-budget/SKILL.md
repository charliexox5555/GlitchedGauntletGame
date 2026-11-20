---
name: rbx-particle-peak-budget
description: Estimate peak live particles under overlapping bursts for Roblox development using captured measurements or traces.
---

# Estimate peak live particles under overlapping bursts

Record burst timestamp, particle count, and conservative maximum lifetime from the actual effect. Include simultaneous players or chained actions. Convert continuous emission into conservative per-interval batches if used.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

The sweep estimates peak live particles assuming no early death. Reduce overlapping lifetimes or counts at the peak time. This is a count model and does not measure frame time or fill rate.
