---
name: rbx-motion-breakdown
description: Break an animation into comparable motion curves for Roblox development using captured measurements or traces.
---

# Break an animation into comparable motion curves

Read the [animation workbench](references/animation-workbench.md) first. Align comparable motion phases and sample channels such as torso pitch, yaw and roll, hip bob, hand height, and root travel at the same normalized times. Separate deliberate changes from strict matches with `mode`; use `target_offset` for an expected signed difference.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

The report shows signed bias and RMS after the declared offset. Use the HTML chart to see where a channel drifts. A diagnostic channel produces measurements without a failure threshold. Keep travel diagnostic when comparing a moving reference with an in-place clip. Unwrap rotations for a legible chart.

Use `--report motion.html` to save the comparison chart. The [animation workbench](references/animation-workbench.md) includes blocking, easing, layered motion, and reference breakdown examples.
