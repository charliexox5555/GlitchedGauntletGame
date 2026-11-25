---
name: rbx-locomotion-rate-fit
description: Check in-place locomotion playback rate against actual movement speed for Roblox development using captured measurements or traces.
---

# Check in-place locomotion playback rate against actual movement speed

Measure the intended ground distance associated with one authored cycle and its duration. Record standalone root drift from the in-place clip. In Studio log observed horizontal speed alongside applied track rate at slow and normal movement.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

For a constant-stride clip, expected playback rate is actual speed divided by authored speed. A changed stride blend or clamped rate needs its own target curve. A rate pass still leaves foot plant and blend behavior to visual review.
