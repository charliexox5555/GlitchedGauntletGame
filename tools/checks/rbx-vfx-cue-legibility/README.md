---
name: rbx-vfx-cue-legibility
description: Audit which important visual cues survive low-quality settings for Roblox development using captured measurements or traces.
---

# Audit which important visual cues survive low-quality settings

List required device, graphics, and effect combinations. Capture each from normal play distance and record cue recognition results from deliberate observation or a simple blind clip test. Keep the same timing window across settings.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

A missing case or low recognition rate flags a cue that needs a simpler or earlier visual signal. Run a new clip after a change. This measures the recorded cohort and does not establish performance.
