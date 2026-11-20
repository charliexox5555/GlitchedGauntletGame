---
name: rbx-streaming-reentry
description: Detect missed bindings across streamed area reentry for Roblox development using captured measurements or traces.
---

# Detect missed bindings across streamed area reentry

Capture chronological bind and unbind events for the scoped client-side prompt or decoration. Use a stable logical ID across streaming cycles and log real lifecycle transitions. Set `expected` to completed cycles exercised per ID.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

A second bind while active means duplicate subscriptions or a missed teardown. An incomplete cycle means the area test or cleanup is incomplete. Reenter the same place and confirm the prompt is usable again.
