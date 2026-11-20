---
name: rbx-hit-feedback-agreement
description: Catch visible hit feedback that disagrees with confirmed outcomes for Roblox development using captured measurements or traces.
---

# Catch visible hit feedback that disagrees with confirmed outcomes

Collect paired server and client observations for ordinary gameplay interactions in a test place. For each event ID, record authoritative outcome, presented outcome, and frame or time latency. Include clear hit and clear miss cases.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

Wrong presentation is a correctness issue even with low delay. A matching result with too much delay points to feedback scheduling or replication. Use the same test fixtures and clock convention.
