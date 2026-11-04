# 2026-11-04 Gunplay Feel Pass 1

**What:** the first feel pass ([Gunplay](../../01%20Design/Gunplay.md) §5 → Feel pass 1). Studio playtest, solo against the test opponent, input sent with real keypresses.

- ✅ Slide (W + Shift, then C): MoveState Sprint → Slide with dust on, FOV 84 → 90.8 (the punch) → back; roll 3°. (The slide hit a crate after 0.2 s, so the full slide length wasn't seen.)
- ✅ Jump and land: Air → Idle, no error (a small hop doesn't reach the dip threshold, by design).
- ✅ Hit flash: a headshot point on the test opponent put an amber Highlight on it (fill 0.5), via a client copy of `EffectsController.hitFlash`.
- ✅ UI pops now grow from the centre (clock, scores, banners, draft, LOCK IN, ability slots).
- Output clean (only the known `rbxassetid://203785492` warning).
- **Not checked live:** the world-gun kick and the flinch need someone shooting (a 2-player test), the slide and land sounds weren't heard (no audio through the MCP), smoother third-person aim needs a second player to watch.
