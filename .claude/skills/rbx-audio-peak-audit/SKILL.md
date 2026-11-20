---
name: rbx-audio-peak-audit
description: Measure peak signal and clipped sample counts in a gameplay audio file for Roblox development using captured measurements or traces.
---

# Measure peak signal and clipped sample counts in a gameplay audio file

Capture the loudest representative game mix as uncompressed 16-bit PCM WAV. Set the maximum acceptable sample peak in dBFS. Place the WAV beside the manifest or specify its local path.

Copy [the working input fixture](references/example.json) and replace the example values with your capture. Run this command from the installed skill directory or point Python at the script.

```text
python scripts/check.py path/to/capture.json
```

A peak above target flags insufficient headroom. Full-scale samples may indicate clipping and should be checked in the waveform. The tool measures sample peaks and leaves true peak, loudness, and audible distortion to dedicated tools.
