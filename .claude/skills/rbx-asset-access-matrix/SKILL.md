---
name: rbx-asset-access-matrix
description: Identify assets that fail under normal player access for Roblox development using captured measurements or traces.
---

# Identify assets that fail under normal player access

Build the expected list of asset, destination, and viewer-role cases. In the actual test universe, record a result as `loaded` only when the relevant mesh, animation, audio, or image loaded during the scoped flow.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

Investigate failed player cases even if the owner succeeds. Capture the Studio Output error and check the destination's permission before replacing IDs. The matrix reports coverage and observed failures.
