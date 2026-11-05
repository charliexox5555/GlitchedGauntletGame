# Bugs & Ideas

Quick capture. Move items into the Game Plan or a fix list when they're scheduled.

## 🐛 Bugs
| # | Found | What happens | Steps to reproduce | Severity | Status |
|---|---|---|---|---|---|
| 1 | 2026-11-03 | "Attribute total payload exceeds 1024 bytes" spam from `Mods/Updraft` step; abilities stop working | Upgraded Dash + Updraft (+ statuses) on one character | High | ✅ Fixed 2026-11-03: attributes packed / nil instead of false (Mod System → Character attribute budget). Watch for it if more per-character state is added |
| 2 | 2026-11-04 | Output shows `ContentId: rbxassetid://203785492 failed due to: Asset type does not match requested type` ×3 in every playtest (both places) | Any Studio playtest | Low | Not the game: the asset is a sound ("Pop Close Sound") that a Studio plugin requests as another type; no script, place or package refers to it. Ignore (live servers won't show it) |

## 💡 Ideas
| Idea | Why it might be good | Parked until |
|---|---|---|
| **LihFolk gap review (2026-11-05):** 15 items: 2-player and lag tests, aim assist, death recap and spectating, saved data and settings, teammate markers, rematch, analytics, first session, leavers, hitboxes, comfort, hold/toggle, ping and volume, remote abuse tests; plus quick wins. Full list: [LihFolk Gap Review 2026-11-05](LihFolk%20Gap%20Review%202026-11-05.md) | The user approved the list as good, to be taken in phases | After the current phase (maps and UI concepts) |
| Loser picks one gun from the next tier up | Comeback lever (see Weapons) | Playtest #1 |
| Ranked split pools by input | Mobile/PC fairness | Ranked phase |
| **Decide (2026-11-03 upgrades):** rename one of the two "Crash" glitches (Updraft's *Crash Down*, Recall's *Crash Recovery*) | They read alike on draft cards | User's morning review |
| **Decide:** the Barrier ignores your own and your team's damage (a Molly at your feet burns through without using it up) | The Heal Orb session's call; the spec said "the next hit" | User's morning review |
| **Decide:** the Frost Wall Hinders enemies only (your team walks through freely) | The Firewall session's call; matches "slows enemies on contact" | User's morning review |
| **Decide:** Ghost's 0.35 s dodge window starts when the *server* runs the dash (a few frames after your press, by ping) | Server-authoritative; a hit right on the press can still land | Two-player test |
| **Watch (2026-11-03 review):** the Barrier's `BarrierHits` is a server-written attribute on the (predicted) character, which the WeaponService notes say can cause Server Authority corrections; `HinderedUntil` etc. already do the same | Look for rubber-banding on the shielded player when a hit is blocked; if so, move it to the Player | Two-player test |
| Q and T have only 2 abilities each, so the round 3 draft can show just 2 cards | Add Q/T abilities in the next set | Next ability set |
