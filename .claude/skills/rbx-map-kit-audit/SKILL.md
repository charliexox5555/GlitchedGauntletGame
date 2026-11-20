---
name: rbx-map-kit-audit
description: Measure Roblox modular map joins and replace hand-waved clearance checks with a repeatable player route. Use for snapped wall kits, path transitions, roofs, or other pieces that must meet after rotation.
---

# Map kit audit

Pick a representative assembly before duplicating the kit. Include one rotated join and any height transitions present in the design. Designate matching seam anchors as Attachments when the project already uses them or when adding placement metadata is in scope. Each anchor's forward axis points outward and its up axis points toward the same side of the seam as its mate.

Open [the snapshot instructions](references/studio-snapshot.md). Use the read-only Studio command to capture named pairs from the actual map. The checker reports the gap in studs and facing or twist error in degrees. Tune tolerances to the smallest gap or tilt the art pipeline can accept. Do not reuse a tolerance to cover a known broken join.

```text
python <skill-directory>/scripts/check_joins.py joins.json
```

After correcting a connector or transform, take a fresh snapshot and rerun the same pairs. At the affected module, view the seam in neutral and normal lighting to check for geometry or shading problems beyond the anchors.

For a traversable join, run the normal route in Studio at gameplay scale on the target avatar. Start before the seam and go through it in both directions at normal speed. Include nearby inclines, low overhangs, and collision boundaries present in the actual route. Record where the camera or avatar snags and whether collision approximates visible geometry. Report measured joins and the player run separately.
