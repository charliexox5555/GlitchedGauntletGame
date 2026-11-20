---
name: rbx-replication-audience
description: Audit who actually receives shared or private gameplay state for Roblox development using captured measurements or traces.
---

# Audit who actually receives shared or private gameplay state

Use Studio with the server and multiple clients. Give each payload or visible state change a trace ID. Record required and forbidden recipients, then list clients that logged receipt for each interaction under test.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

Missing and forbidden observers are separate failures. For a missing receipt, trace the server decision and inspect the observing client. Include late-join cases under their own trace IDs when the feature has a snapshot path.
