# RIVALS loading screen (study, 2026-11-22)

Read-only look at the RIVALS place file's `ReplicatedFirst` (structure and numbers only; nothing copied, their sounds and art not used). Used for [Loading screen v2](../../05%20Production/Handoff%20-%20Stability%2C%20Loading%20and%20Preload.md#phase-2-plan-2026-11-22).

| Part | What RIVALS does |
|---|---|
| Where | A Studio-built `ScreenGui` under a ReplicatedFirst script, moved to PlayerGui first thing; a `BlurEffect` (Size 56) in Lighting; the camera held Scriptable while it shows. |
| Studio mark | Their studio logo spirals in (rotation ease over ~1.7 s) and **fills bottom-up with white as the real progress** (each step tweened 0.x s Quint Out). The progress *is* the logo, no separate bar. |
| Game logo | After loading: the game logo pops from full screen to 60% (Back Out 0.5 s) with a sting, held ~0.5 s. |
| Footer | A status line ("Loading"), a timer and rotating fun facts along the bottom. A device picker (PC / console / phone) can appear mid-load. |
| Close | Logo shrinks and drops (In Quint 1.5 s), blur 56 → 0 over ~2 s, and the client **tells the server it is done** (a remote), so the server knows who has really loaded. |

Takeaways for ours: real stages drive the progress; one sting on the logo beat; status + tips footer; blur/fade out rather than a cut; the client's "done" matters to the server (ours: `MatchReady` token, Phase 1).
