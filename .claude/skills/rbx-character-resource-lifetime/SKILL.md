---
name: rbx-character-resource-lifetime
description: Find resources that survive their owning character generation for Roblox development using captured measurements or traces.
---

# Find resources that survive their owning character generation

Instrument changed connections, tweens, and tasks using a stable resource ID and the owning character generation. Log acquire, release, and character end in actual execution order. After respawning, log a second teardown.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

A live resource at character end or registration after end identifies the owner path to fix. Measure only character-owned resources here. Player-session resources belong in a different lifecycle trace.
