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
