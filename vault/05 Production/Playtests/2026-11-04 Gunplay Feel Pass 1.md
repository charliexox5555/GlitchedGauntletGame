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

## Slide streaks and third-person slide (same day)
- ✅ Slide start shows the wind streaks (lowest streak transparency 0.63, about a 45% Dash), no blur; Output clean.
- ✅ Third-person slide clips (`MakeSlideAnimations.luau`): SlideIn (0.28 s), the Slide hold (0.26 s loop, rate 0.99 at full slide speed) and SlideOut (0.30 s) all played at weight > 0.3 on one Sprint → Slide → Sprint, on the **first** slide of a fresh session (after adding the clip preload; before it, the first slide's one-shots had length 0 and skipped).
- Still poses checked in a side view (stride, kick, drop, hold, plant, rise). The motion in play still needs the user's look from a second player's view.
- Test note: under Server Authority, `Humanoid:Move` / `Player:Move` from the MCP don't move the character. Use real keypresses (about 3 s input lag through the MCP; a crate about 13 studs ahead of the spawn stops long run-ups).
