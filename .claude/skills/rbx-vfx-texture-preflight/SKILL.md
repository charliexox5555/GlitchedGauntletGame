---
name: rbx-vfx-texture-preflight
description: Source a Roblox VFX texture and inspect real alpha edges, tile dimensions, and flipbook frames before importing it. Use for impact, smoke, trail, beam, and other particle texture candidates.
---

# VFX texture preflight

Write one sentence for the missing texture: its role in the effect, desired silhouette, intended screen size, and format (static image, tile, or flipbook). Search by those terms in Creator Store and creator-owned catalogs. Check previews and the original usage terms. Keep only candidates a client can actually load or the team can import.

For local candidate sheets, copy [the sample manifest](references/textures.example.json) and record the image file, expected columns and rows, source, and usage evidence. The helper needs Python and Pillow in the working environment:

```text
python <skill-directory>/scripts/preflight.py textures.json textures.html
```

The contact sheet shows each cell on light and dark backgrounds. It flags non-divisible grids, blank cells, weak or missing transparency, and visible alpha touching frame edges. Edge contact can be intentional for a loop or full-frame mask. Check the actual preview and record the decision. A Roblox asset ID without a local image can be checked on a disposable Studio emitter instead.

If useful web candidates run out, open VFX Studio's installed library and audition the relevant category. If it is missing and installation is authorized, use the [VFX Studio Creator Store listing](https://create.roblox.com/store/asset/135581141962270/VFX-Studio), asset ID 135581141962270, through Roblox's signed-in free install flow. Confirm it appears in Studio before using it. If sign-in, pricing, or UI access blocks installation, report the blocker and continue with available sources.

Test the chosen texture at the target gameplay distance and lifetime in Studio. Verify that it loads in the target experience. Hand off the asset ID or source file, usage evidence, and the chosen atlas settings.
