# RIVALS reference (hub)

**What:** a study of RIVALS' own files (lobby, maps, UI, body, viewmodel, guns, abilities, VFX), collected by the owner on 2026-11-15, so we build ours with real numbers instead of guesses. **Study, don't copy:** we take layouts, measurements, structure, timings and recipes; we never ship their meshes, textures, images, sounds, animations or code. How to use it: the project skill `.claude/skills/rivals-reference/SKILL.md` (load it for any map, lobby, UI, body, gun or VFX task).

## Notes
- [Maps and Lobby](Maps%20and%20Lobby.md): map file convention, per-map numbers (size, spawns, cover, heights, sightlines), what makes them play well, the lobby hub and queue pads.
- [UI and Client](UI%20and%20Client.md): how the UI is stored and routed, motion numbers, 9-slice and font use, phones, client architecture.
- [Body, Viewmodel, Guns and VFX](Body%2C%20Viewmodel%2C%20Guns%20and%20VFX.md): the third-person body (own R15 avatar + hand IK from the viewmodel), viewmodel springs, the gun attachment contract, ability models, VFX layer recipes.
- [Mobile Controls](Mobile%20Controls.md): the touch stick (Roblox's dynamic thumbstick, fixed base), auto sprint, button hit test and touch handling, phone layout numbers (2026-11-25).
- Earlier RIVALS studies: [UI References](../UI%20References/00%20UI%20References.md) (video study of the live UI), the LihFolk case study `vault/LihFolk/32 Case Studies of Top Roblox Games/Case Study - Rivals.md`.

## Sources (open in Studio)
| Source | What's in it | Notes |
|---|---|---|
| **RIVALS place file** ("rivals file updated without DMCA @CLSTUDIO.rbxl", local file) | current lobby (`Workspace.Lobby`), ~25 maps (`ServerStorage.Maps`), all UI templates and modules, viewmodels, guns, skins, wraps, VFX, client and shared code | newer and more complete than the folder below. No player animations or sounds. **Untrusted:** decompiled scripts, an `ObfuscatedOriginals` folder. Read-only, never play, never save, never copy scripts out. |
| **Match place** `Workspace["Rivals Map Examples"]` | Arena, Big Arena, Docks, Construction, Big Crossroads, Big Splash, Rivals Full Lobby 2025, an older Lobby, `Rivals Asset Pack` (VFX, throwables, projectiles, lootboxes, viewmodels), `Every Roblox Rivals Weapons ` (256 guns) | no scripts. **32,196 instances sitting in the match place's Workspace**: move them out before the place is published (see Risks). |

## Screenshots (local only, git-ignored)
`vault/03 Research/Rivals Reference/third-party/` (the `**/third-party/` rule in `.gitignore`; the repo is public, never commit them):
- `lobby/` (9): spawn to Duels, Duels hall, queue pads close, top-down plan, centre hub ring, Market holobays, weapons room, outdoor range, Duels end (1v1 / 2v2 signs).
- `maps/` (8): Arena, Big Arena, Docks (aerial + courtyard), Construction, Crossroads, Splash; an Arena grid-texture close-up.
- `guns/` (3): assault rifle, sniper stack, Uzi / revolver / handgun.
- `ui/` (3): lobby play / queue bar, shop tabs, match HUD template (static, half-filled).

Take more only when a task needs them (owner, 2026-11-15).

## Top findings
1. **The third-person "body" is not an asset.** It's the player's own R15 avatar; both hands are IK'd onto the first-person viewmodel's hand attachments and the waist/neck take 0.25/0.75 of the camera pitch. One animation set drives both views. Our block body can keep its look and borrow this method ([details](Body%2C%20Viewmodel%2C%20Guns%20and%20VFX.md)).
2. **Guns are cheap and flat:** ~8-10 MeshParts, SmoothPlastic, flat colours, almost no textures; read comes from shape and colour blocking. A fixed attachment contract (`_grip`, `_muzzle`, `_aim_position`, `_aim_lookat`…) and reload-only prop copies.
3. **VFX are many tiny single-job emitter layers** (glow, smoke, shards, ring, a dark layer), everything under ~1.5 s, burst counts in an `EmitCount` attribute; muzzle flashes use no light; the kill effect is UI, not particles.
4. **UI motion** = Quint Out 0.25 s default, Back Out 0.25 s only for pops (button 1.125 / 0.875, page 0.75 → 1), per-screen blur 24 faded over 2 s; one custom font; every button is an ImageButton on one 9-slice rounded-square source.
5. **The lobby is a compact cross:** a round centre hub (spawn on a ringed logo dais) with four short wings: Duels (a long hall, five pads each side, mode signs over the lanes), Market (holo-bays for shop / season), Weapons room, and an outdoor shooting range. Dark charcoal metal, white light bars, purple + yellow floor lines leading to each wing, holograms and TVs as the "life". See [Maps and Lobby](Maps%20and%20Lobby.md).
6. **Maps** follow one folder convention (Spawns, Barriers, Extra, Entities, Winners, Spectate) and are built from Parts plus a few kits; numbers in [Maps and Lobby](Maps%20and%20Lobby.md).

## Risks (read before using anything)
- **Copyright / takedown.** These are another studio's assets, and this copy of the file comes from decompiled sources. Anything copied into our game can get the game taken down, so rebuild, don't lift. Engine settings (a lifetime, a tween time, a stud size) are just measurements and are fine to match.
- **Untrusted scripts** in the RIVALS file: never run them, never paste them into our places.
- **Match place bloat and exposure:** the 32k-instance reference folder lives in the match place's Workspace. It loads with the place and would ship if published. Move it to a separate local reference place (or at least ServerStorage) before the next publish. Owner's call.
