---
name: rbx-spatial-audio-range
description: Find gameplay sounds that carry too far or vanish too early for Roblox development using captured measurements or traces.
---

# Find gameplay sounds that carry too far or vanish too early

Record isolated output levels in dBFS for an approved test sound at the listed listener distances. Use the same gain, source, and background across captures. Provide audibility bands that fit the cue's role.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

Low close levels can hide a critical cue. High far levels can distract players outside the area. Repeat after changing the attenuation curve and verify against the full scene mix.
