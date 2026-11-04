# 2026-11-03 Draft Columns

**What:** the draft's new "one column per slot" rule ([Match Flow](../../01%20Design/Match%20Flow.md) → Abilities). Studio playtest, solo against the test opponent, driven from the client through the `DraftPick` remote.

| Round | Ability row (Q / E / T) | Pick |
|---|---|---|
| 1 | Stim (new) · Molly (new) · Frost (new) | Stim |
| 2 | **Stim A2 or B2** · Dash (new) · Firewall (new) | Stim:A2 |
| 3 | **Stim A3** · Dash (new) · Firewall (new) | — |

- ✅ Each column offers one card set for its own key; the owned slot shows its upgrades, the others new abilities.
- ✅ The A2 pick applied: round 3 offered the next level on path A.
- Output clean apart from the known `rbxassetid://203785492` type warning.
- Not tested: glitch rolls in a mixed row (same `rollUpgrades` as before), 2 real players, the new UI (not built yet).

## UI v1 in game (same day)
Studio playtest after building UI v1. Screenshots: `02 Art/References/ui-v1/ingame-*.jpg`.
- ✅ Draft round 1: three new-ability cards (role tint, icon, role tag, note, upgrade paths, charges), gun cards with renders and shield tags, key tabs, LOCK IN, enemy kit.
- ✅ Draft rounds 2–3: owned slots show stacked Path A / B cards with the stat change in gold ("CHARGES 1 → 2", "RECHARGES EVERY 15 S", "RADIUS 9 → 12 STUDS"); last round's gun stays selected (white outline + glow).
- ✅ Top bar: names (YOU / TEST OPPONENT), team health, score, first-to-5 diamonds, ROUND n // PHASE, clock; stays above the draft.
- ✅ HUD: shield badge + health, square Q/E/T slots with charge diamonds and ready bars, gun picture + ammo, ELIMINATED pop-up and kill feed (previewed with a client copy of `Util/KillFeed`: 2 rows, pop-up fades after 1.6 s).
- Fixed during the test: the draft canvas lost its UIScale on each new offer; `Ui.fit` now scales from the ScreenGui's size (the camera viewport didn't match it in Studio); the test opponent's name and health come from `Workspace.Dummies`; L1 notes no longer lose their first words.
- Not checked: clicking cards with the mouse (picks went through the remote), a real kill in the feed, round banners (seen only in code), phone and gamepad.
