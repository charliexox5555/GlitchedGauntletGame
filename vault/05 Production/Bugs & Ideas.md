# Bugs & Ideas

Quick capture. Move items into the Game Plan or a fix list when they're scheduled.

## 🐛 Bugs
| # | Found | What happens | Steps to reproduce | Severity | Status |
|---|---|---|---|---|---|
| 1 | 2026-11-03 | "Attribute total payload exceeds 1024 bytes" spam from `Mods/Updraft` step; abilities stop working | Upgraded Dash + Updraft (+ statuses) on one character | High | ✅ Fixed 2026-11-03: attributes packed / nil instead of false (Mod System → Character attribute budget). Watch for it if more per-character state is added |
| 2 | 2026-11-04 | Output shows `ContentId: rbxassetid://203785492 failed due to: Asset type does not match requested type` ×3 in every playtest (both places) | Any Studio playtest | Low | Not the game: the asset is a sound ("Pop Close Sound") that a Studio plugin requests as another type; no script, place or package refers to it. Ignore (live servers won't show it) |
| 3 | 2026-11-05 | Output: `Attribute string value exceeds 50 character limit ("FireReject")` from `WeaponService.onFire` | Studio playtest, a long shot-reject reason | Low (Studio-only debug attribute) | ✅ Fixed 2026-11-05: the reason is cut to 50 characters |
| 5 | 2026-11-07 | After going down, the gun stayed in your hands and the death camera didn't start: the `Downed` attribute's change signal didn't fire on your own (simulated) character in a Studio test | Studio match, go down | High | ✅ Fixed 2026-11-07: polled in `WeaponController`, `ModController`, `SpectateController` (DeathFx already polled). Other `Health.onDowned` users on your own character may have the same gap |
| 4 | 2026-11-06 | The match place's `Lighting` had 65,536 empty StringValues named `LightingPreset` (they'd replicate to every client on join) | Found by lane F overnight; no repo code creates an empty one, so most likely ad-hoc MCP code from a map lane | Medium | ✅ Cleaned 2026-11-06 02:0x (Lighting back to 5 children). Watch: if the count grows again, find the creator |

- **Guns over the triangle budget (2026-11-11):** Vandal 5,171 (5K), Outlaw 5,069 (5K), Sheriff 3,066 (3K), Bucky 3,030 (3K) after the final pass's sealed faces and charm ring. Trim when one of them is next opened ([note](Weapon%20Final%20Pass%202026-11-11.md)).
- **Gun `.rbxm` backups are stale (2026-11-11):** `art-source/weapons/Studio/<Id>.rbxm` still holds the pre-RemasterV2 guns: `WeaponBuilder.publish` can't reach `receive_server.py` (HttpService blocks 127.0.0.1:34999). The place and `ServerStorage.WeaponsBackup_*` are the only copies of the built guns.
- **`WeaponBuilder` sets `CollisionFidelity = Box` in a `pcall` that never takes effect** (a loaded MeshPart's fidelity can't be changed from a script), so guns keep `Default` colliders. Harmless today; the aim sight-line check relies on those colliders.

## 💡 Ideas
| Idea | Why it might be good | Parked until |
|---|---|---|
| **Video research, part 2 (2026-11-12):** with the [Video Analyzer](../04%20Tech/Video%20Analyzer.md): (a) Roblox FPS architecture talks (FastCast vs hitscan, lag compensation, viewmodel replication, round state machines); (b) Valorant round/economy pacing for our draft + tier loop; (c) RIVALS kill cam, match end, phone locker and Touch settings; (d) console UI. The owner's first brief asked for these; this pass did UI only | Grounds gunplay and match-flow work in measured references | After the owner reviews UI v4 |
| **Mobile HUD layout editor (2026-11-12):** per-button position / size (85-130%) / opacity, presets (Default, Minimal, Claw), left-handed mirror, reset; every non-default RIVALS mobile player edits theirs ([Rivals Mobile UI](../03%20Research/UI%20References/Rivals%20Mobile%20UI.md)) | Mobile retention; LihFolk *Mobile Button Layout Editor* has the recipe | UI v4 build |
| **LihFolk gap review (2026-11-05):** 15 items: 2-player and lag tests, aim assist, death recap and spectating, saved data and settings, teammate markers, rematch, analytics, first session, leavers, hitboxes, comfort, hold/toggle, ping and volume, remote abuse tests; plus quick wins. Full list: [LihFolk Gap Review 2026-11-05](LihFolk%20Gap%20Review%202026-11-05.md) | The user approved the list as good, to be taken in phases | After the current phase (maps and UI concepts) |
| **Death recap card (2026-11-07):** who killed you, with which gun, damage each way, shown after the death camera | Part of the Match Structure Revamp, held off by the user | After the match structure revamp |
| Loser picks one gun from the next tier up | Comeback lever (see Weapons) | Playtest #1 |
| Ranked split pools by input | Mobile/PC fairness | Ranked phase |
| **Decide (2026-11-03 upgrades):** rename one of the two "Crash" glitches (Updraft's *Crash Down*, Recall's *Crash Recovery*) | They read alike on draft cards | User's morning review |
| **Decide:** the Barrier ignores your own and your team's damage (a Molly at your feet burns through without using it up) | The Heal Orb session's call; the spec said "the next hit" | User's morning review |
| **Decide:** the Frost Wall Hinders enemies only (your team walks through freely) | The Firewall session's call; matches "slows enemies on contact" | User's morning review |
| **Decide:** Ghost's 0.35 s dodge window starts when the *server* runs the dash (a few frames after your press, by ping) | Server-authoritative; a hit right on the press can still land | Two-player test |
| **Watch (2026-11-03 review):** the Barrier's `BarrierHits` is a server-written attribute on the (predicted) character, which the WeaponService notes say can cause Server Authority corrections; `HinderedUntil` etc. already do the same | Look for rubber-banding on the shielded player when a hit is blocked; if so, move it to the Player | Two-player test |
| Q and T have only 2 abilities each, so the round 3 draft can show just 2 cards | Add Q/T abilities in the next set | Next ability set |

- **Aiming hides whole merged parts (2026-11-11):** `ViewmodelController.findOccluders` hides every non-`Sight` part on the eye-to-`AimPoint` line, and parts are merged per material, so one stray piece can blank a whole mesh (the Stinger's neon). The models are clean now and `tools/studio/AdsSightLine.luau` checks it; a sturdier rule (only hide parts tagged for it) is worth doing before skins add geometry.
