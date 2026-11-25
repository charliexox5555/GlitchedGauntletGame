---
name: rbx-impact-grounding
description: Check that effects sit on the intended surface after contact for Roblox development using captured measurements or traces.
---

# Check that effects sit on the intended surface after contact

Record the observed impact origin, the surface point hit by the gameplay ray, and the effect's up direction. Record the contact normal from the same frame. Repeat on a slope and a wall if the effect supports them.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

A positional offset suggests an origin, ray, or attachment error. A large angle suggests incorrect normal alignment. Inspect emitter orientation and sign where the effect deliberately points into a surface.
