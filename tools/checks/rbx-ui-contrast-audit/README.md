---
name: rbx-ui-contrast-audit
description: Measure contrast for text and state cues on rendered backgrounds for Roblox development using captured measurements or traces.
---

# Measure contrast for text and state cues on rendered backgrounds

Sample foreground and adjacent background sRGB from rendered captures. Use opaque six-digit hex values after compositing. Give each pair its target ratio. Include hovered, disabled, and runtime overlay states where they matter to the task.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

The tool compares the least-separated sampled pair against the target. For mixed backgrounds, sample several locations. Contrast figures measure light-dark separation and leave symbol recognition and behavior to observation.
