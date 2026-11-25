---
name: rbx-reference-coverage
description: Compare references against a Roblox build with a feature ledger, matched Studio captures, and measured landmark drift. Use when recreating a supplied map, model, or shot where visible details are getting missed.
---

# Reference coverage

Inventory visible features before the build is edited. Use one entry per independently fixable feature and identify where it belongs. For a row of gates, record the expected count, approach direction, and placement landmarks as separate observations when each can fail independently. Preserve the original source frames. Record approved deviations in the brief before changing acceptance criteria.

Capture the actual build from the same aspect ratio, framing, angle, and gameplay state where possible. Record each feature against a named view. Count instances and include observations with their locations. For a comparable view, mark corresponding landmarks in normalized image coordinates (x rightward, y downward, both 0–1). A screenshot with no suitable matching view can establish neither a precise screen-space pass nor the absence of an occluded object.

Copy [the sample manifest](references/coverage.example.json) into the task workspace. Set the capture paths relative to it. Generate the standalone inspection report:

```text
python <skill-directory>/scripts/coverage.py coverage.json coverage.html
```

Open the report to inspect side-by-side images and the optional overlay. The script flags missing observations, count differences, and distances above the supplied tolerance. An image path alone cannot establish a manual feature match. Use an observation that explains the visible evidence.

Fix the first blocking discrepancy, replace only the build capture and observations, then rerun the same manifest. Hand off the HTML and any remaining missing or unverified features. For project-level QA, continue using the project's existing review tools.
