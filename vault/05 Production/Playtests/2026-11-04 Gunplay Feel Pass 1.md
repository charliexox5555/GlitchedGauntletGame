# 2026-11-04 Gunplay Feel Pass 1

**What:** the first feel pass ([Gunplay](../../01%20Design/Gunplay.md) §5 → Feel pass 1). Studio playtest, solo against the test opponent, input sent with real keypresses.

- ✅ Slide (W + Shift, then C): MoveState Sprint → Slide with dust on, FOV 84 → 90.8 (the punch) → back; roll 3°. (The slide hit a crate after 0.2 s, so the full slide length wasn't seen.)
- ✅ Jump and land: Air → Idle, no error (a small hop doesn't reach the dip threshold, by design).
- ✅ Hit flash: a headshot point on the test opponent put an amber Highlight on it (fill 0.5), via a client copy of `EffectsController.hitFlash`.
- ✅ UI pops now grow from the centre (clock, scores, banners, draft, LOCK IN, ability slots).
- Output clean (only the known `rbxassetid://203785492` warning).
- **Not checked live:** the world-gun kick and the flinch need someone shooting (a 2-player test), the slide and land sounds weren't heard (no audio through the MCP), smoother third-person aim needs a second player to watch.

## Health and jump (same day)
- ✅ Dev "Hurt me" ×3 in a match: shield 25 → 0 and HP 100 → 75 → 25 → 0, then `Downed`; Roblox `Humanoid.Health` stayed 100; WalkSpeed 0; screen saturation −0.85; the round ended (team out).
- ✅ Next round: a fresh character (HP 100, not downed), colour back.
- ✅ A downed dummy: the real body is hidden on the client (LocalTransparencyModifier 1) and the falling copy was spawned. The fall itself was only glimpsed (the guns covered it), so judge it in play.
- Jump 5.6 + fall gravity 1.3: built, not measured in this run.
