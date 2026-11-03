# Big Whitebox

The [Whitebox](Whitebox.md) look scaled up for **3v3–4v4** (and 2v2), the way RIVALS pairs Arena with Big Arena: same white panel kit, same cover heights (low 3, full 7+), a bigger room with more cover. See [Maps](00%20Maps.md) for the roster.

**Status (2026-11-03):** greybox **built** by script and playtested as a match (spawns, barriers, the test opponent, first-person look). Not reviewed by the user yet.

## As built
- **Script:** `tools/studio/maps/BigWhitebox/Greybox.luau` on MapKit (`python tools/studio/maps/bundle.py BigWhitebox Greybox -o big.luau`, run in the match place). Re-runnable: it rebuilds `Workspace.BigWhitebox`.
- **Where:** world origin (0, 200, -1500). Backup `art-source/maps/BigWhitebox/BigWhitebox.rbxm`.
- **Size:** room 120 × 176, spawn alcoves 40 × 18 at each end (212 studs end to end, about 6.6 s from the alcove mouth to the middle at walking speed), walls 48 tall. 78 parts, all Parts (no meshes).
- **Symmetry:** 180° rotation. Team A (blue bands) spawns at -Z, team B (yellow) at +Z; 4 spawns each, a barrier across each alcove mouth.
- **Layout (each half):** a baffle in front of the alcove; **left lane** a perch (26 × 22, 7 up, ramp from the middle side) with a low wall, a slab and a wall box; **middle** a mid wall, a low wall and a block leading to a 20-stud diamond (14 tall, turned 45°) and two of the four tall pillars; **right lane** a window frame (shoot through, walk round), a slab, a low wall and a small perch with its own ramp; a side block on the halfway line on each wall.
- **Look:** Whitebox's panel texture (image 104451231800023) on every face; team bands on the alcove backs, the baffles and the pillars. Lighting: the place's (Whitebox) lighting, no per-map override.
- **In the pool:** `Config/Match MAPS` (3v3–4v4).

## To do
- User review, then a layout pass after real 3v3s (the right lane may be too open).
- A layout-check script like `whitebox_layout.py` if it changes much.
