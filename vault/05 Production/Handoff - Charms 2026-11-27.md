# Handoff: charms (2026-11-27, for Antigravity)

The owner sends this build to Gemini Antigravity (with Blender MCP). **The prompt to paste:** [2026-11-27 Charms (Antigravity)](../04%20Tech/Prompts/2026-11-27%20Charms%20(Antigravity).md) (copy the whole file). This note holds the decisions and facts behind it. The other pass briefs are in [Handoff - Battle Pass Build](Handoff%20-%20Battle%20Pass%20Build%202026-11-27.md).

## Owner decisions (2026-11-27)
- **Each charm goes on one gun.** The player owns charms and puts each on one gun of their choice; that's saved. A gun holds one charm. Moving a charm to another gun takes it off the first.
- Charms are for **all guns** (the 14 in `Config/Loadout`) and every skin. The knife has no charm.
- The build covers everything: model all 8 in Blender, check they look good, attach them to every gun, add them to the game, swing physics, VFX for the Epic and Legendary ones, the battle pass rewards, and the Locker equip.
- **Next, after charms:** a **charm pack** (not a case: a pack like the SURGE power pack), with its own look. Goodie bags then give charm packs.

## Facts checked (2026-11-27, Studio)
- All 14 active guns in `ReplicatedStorage.Weapons` have `CharmPoint` on their `Charm` joint part, and an empty `Buddy` folder meant for a charm. The knife has neither.
- Skins are whole replacement models (`Shared/Locker.skinModel` → `SkinStore`). Whether every skin keeps `CharmPoint` is **not checked**; the prompt asks for a fallback and a list.
- `data.charms` today is `{ owned, on }`, granted by display name (`JOYSTICK`). The prompt changes it to `{ owned = { id }, guns = { [gunId] = id } }` with stable ids. No live save has charms (the pass isn't open).
- Equip pattern to copy: `LockerRequest ("title", name)` in `Services/LockerService` (phase 5).
- The Outlaw (TwinShot) was removed from the game on 2026-11-27. It isn't in `Config/Loadout`.

## Open questions for the owner (the builder asks if still open)
1. **Duplicates later:** when charm packs exist, can a player own two of the same charm, so it can go on two guns, or is a duplicate turned into coins?
2. **Locker placement** of the CHARM slot: under the skin list, or its own tab.

## Results
(The builder fills this in: what was built, screenshots, tests, what wasn't tested.)
