---
name: rbx-interaction-cardinality
description: Catch duplicate or lost gameplay commits from a single action for Roblox development using captured measurements or traces.
---

# Catch duplicate or lost gameplay commits from a single action

Assign a test intent ID to each legitimate action or retry group. Log durable or authoritative commits for those intents at the mutation site, including any unexpected duplicate. Mark the expected number of commits after retry or cancellation.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

Inspect input handling when one gesture produces multiple intent IDs. Inspect server deduplication or missing acknowledgement when one intent ID commits more than planned. Use one observed end state per test run.
