You are building the **charms** for Draft Duels (repo: GlitchedGauntletGame), a Roblox run-and-gun duel game. The project is in this folder: Rojo + strict Luau. You have Blender MCP, and should have Roblox Studio MCP too. Work through every step below, check your own work as you go, and stop to ask the owner only where this prompt says to.

## 0. Read first (in this order)
1. `AGENTS.md` and `CLAUDE.md`: project rules. The **Code rules**, **Git** and **Vault upkeep** sections are mandatory.
2. `vault/05 Production/Handoff - Charms 2026-11-27.md`: the brief this prompt comes from (decisions, facts, open questions).
3. `vault/01 Design/Battle Pass Season 1 Contents.md` → "Charms": the approved list.
4. `vault/02 Art/Style Bible.md`, `.claude/skills/gauntlet-build-style/SKILL.md`, `.claude/skills/gauntlet-model-joins/SKILL.md`: the modelling rules. They're not optional.
5. `vault/02 Art/Art Direction.md`: the gun model standard, including the charm loop and `CharmPoint`.

## 1. What a charm is (owner decisions, 2026-11-27)
- A small keychain-style trinket that hangs from the **charm ring on the back-left of every gun** and swings as you move, turn and shoot.
- **One charm goes on one gun.**
  - The player owns a set of charms and puts each one on **one** gun of their choice; that is saved.
  - Putting a charm on another gun takes it off the first.
  - Each gun holds at most one charm.
- Charms work on **all 14 active guns** (`src/shared/Config/Loadout.luau`: 10 primaries + 4 secondaries) and on **every skin** of those guns. The knife has no charm ring and gets no charm.
- Season 1 gets 8 charms through the battle pass. A **charm pack** (like the SURGE power pack) comes later; don't build it now.

## 2. The 8 charms
| Id | Name | Rarity | Pass tier | Look | Extra |
|---|---|---|---|---|---|
| `ArcadeToken` | ARCADE TOKEN | Common | Free 6 | an arcade coin token: a faceted disc with an embossed star or "1UP" mark | none |
| `IceCube` | ICE CUBE | Rare | Free 25 | a faceted ice cube, slightly translucent pale blue, chipped corners | none |
| `Joystick` | JOYSTICK | Rare | Premium 2 | a mini arcade stick: square base, shaft, faceted ball top | the stick tilts with the swing |
| `PixelHeart` | PIXEL HEART | Rare | Premium 8 | a heart made of stepped pixel blocks, red with a light edge | none |
| `SnowflakeShard` | SNOWFLAKE SHARD | Rare | Premium 17 | a flat six-armed ice snowflake, faceted arms | none |
| `GameCartridge` | GAME CARTRIDGE | Epic | Premium 12 | a small game cartridge with a label panel and contact edge | a small glint or spark every few seconds |
| `ThunderOrb` | THUNDER ORB | Epic | Premium 23 | a **faceted** (not round) orb in a little cage, electric blue-violet core | crackles with small electric arcs; a bigger crackle on a kill |
| `HighScore` | HIGH SCORE | Legendary | Premium 28 | a tiny handheld pixel screen | the screen shows **this match's kills** and ticks up on each kill (server-sent count only) |

The names are placeholders the owner may change. Keep the ids stable.

## 3. Modelling in Blender (Blender MCP)
- Follow the build-style and model-joins skills to the letter:
  - **No round curves or spheres**: curves are made from angled plates, and spheres are faceted low-segment solids.
  - **No blunt cutoffs**: union before bevel; details seated into the body, never floating or flush-layered.
  - Crisp, faceted, stylised, "RIVALS-clean". Never realistic, never cartoon-blobby.
- Each charm = **a small ring/link + a short chain (2-3 faceted links) + the body**. The top link must sit exactly on the gun's ring (`CharmPoint` is the ring's inner bottom).
- **Size:** the whole charm about **0.40 studs tall**, the body at most **0.28 studs** across. It must read clearly in first person but never cover the sights or the ADS view. Check it on the smallest gun (Classic) and the biggest (Odin, Operator).
- **Budget:**
  - At most about **600 triangles** per charm, at most 3 materials (body, accent, Neon for glowing parts).
  - Glowing parts are separate Neon pieces, so they can be recoloured.
- **Pivot:** the origin at the top of the first link, which is the hang point. +Z up in Blender.
- Render a turntable preview of each charm (3/4 front, side, close-up) and **show the owner all 8 before export**. Fix anything they don't like. Their bar is 9/10 or better.
- **Save:**
  - Blender source: `art-source/charms/<Id>/<Id>.blend`.
  - Export: `art-source/charms/<Id>/<Id>.fbx`.
  - Renders: `art-source/charms/<Id>/review/`.

## 4. Into Roblox
- Upload the meshes (Studio's importer, or `tools/opencloud/upload_models.py` / `upload_asset.py`, group `11116787`).
- Rojo can't sync MeshParts, so the finished charm Models live in a **Studio-owned folder `ReplicatedStorage.Charms`** (one Model per id, PrimaryPart = `Hang`, a tiny invisible part at the hang point). Remind the owner to **save the place**.
- Each charm Model:
  - `Hang` (anchored = false, CanCollide/CanQuery/CanTouch = false, Massless).
  - The body parts welded to a `Body` joint part.
  - Effect emitters for the Epic and Legendary extras, disabled by default.

## 5. Data and server (Luau, `--!strict`)
- **`src/shared/Config/Charms.luau` (new):** the list above (`id`, `name`, `rarity`, `extra`), plus the swing tuning numbers. No hard-coded numbers in code.
- **`src/shared/PlayerData.luau`:**
  - Change `charms` from `{ owned, on }` to `{ owned = { id }, guns = { [gunId] = id } }`.
  - Clean it: drop unknown ids, unowned ids and non-active guns; keep a charm on one gun only (first wins).
  - No live save has charms yet (the pass isn't open), so no migration is needed beyond the clean.
  - `PlayerDataService.transact` writes a fixed list of fields; `charms` is already on it. Check it still copies the new shape.
- **`src/lobby/shared/SeasonCatalog.luau`:** the `charm()` helper gets an `id`, and `SeasonRewards.grant` stores the **id** (today it stores the display name).
- **Equip:** in `src/lobby/server/Services/LockerService.luau`, add `LockerRequest ("charm", gunId, charmId or "")`. Copy the `"title"` action already there:
  - Type and length checks.
  - Lobby only.
  - The charm owned, the gun in the active set.
  - One `PlayerDataService.transact`.
  - Moving it takes it off the old gun.
  - Then run the `lihfolk:roblox-secure-remotes` review checklist (in the LihFolk vault if you can read it; otherwise: rate limit first, type and value checks, context, lock, act, silent rejects counted).
- **Publish:** add a JSON StringValue `LockerCharms` (the `guns` map) in `PlayerData.publish`, like `LockerSkins`, so every client can draw other players' charms.
- **Kills for High Score:** use the server's existing per-match kill count if there is one (search `Kills` in `src/server`); otherwise add a server-set player attribute. The client never decides the number.

## 6. Runtime (client)
- Draw the charm on:
  - the **first-person viewmodel** (`src/client/Controllers/ViewmodelController.luau`);
  - the **third-person gun** on every player and bot holding a gun (find where the held gun model is built: `WeaponService` / `WeaponController`);
  - the **Locker preview** (`LockerController` / `SkinPreviewController`);
  - the **battle pass screen**, where a Charm reward shows its 3D model in the `ItemStage` instead of the coloured card (`BattlePassController.showPicture`).
- Find the mount with `gun:FindFirstChild("CharmPoint", true)`. **Skins are whole replacement models** (`Shared/Locker.skinModel`). If a skin model has no `CharmPoint`, fall back to the stock gun's `CharmPoint` offset from the Handle, and list which skins lacked it.
- **Swing:**
  - A client-side spring pendulum (2 axes, damped) driven by the gun's movement, turning and a recoil kick on each shot.
  - **No Roblox physics constraints** on the viewmodel, and **no network traffic per frame**.
  - Every client simulates every visible charm itself.
  - It settles in about 1 s, and the swing angle is capped around 35°.
  - Tuning goes in `Config/Charms`.
- **Extras:** pooled, low particle counts, phone-safe. Game Cartridge: a small glint every 3-5 s. Thunder Orb: small arcs plus a bigger crackle on a kill. High Score: a SurfaceGui pixel number (the kill count), a small pop when it goes up. Follow `vault/02 Art/Art Direction.md` → VFX (stylised, Valorant-like, never photoreal).
- **Clean up:** one charm instance per gun model, pooled; disconnected and destroyed on unequip, gun swap, death and leave. No leaked connections.

## 7. The Locker: putting a charm on a gun
- In the Locker, on a selected gun: a **CHARM** slot. It opens the owned charms, where picking one puts it on this gun, and NONE takes it off. A charm already on another gun shows "ON <GUN>" and moves when picked.
- Build the UI pieces in Studio (owner rule: real ScreenGui objects, edited in Studio), in the Locker's existing style (`.claude/skills/gauntlet-ui-style/SKILL.md`: Rubik Heavy/Bold, soft plates with one cut corner, no outlines or glow).
- The Locker screen lives in `ServerStorage.LobbyUI`; check where the Locker template is before editing.

## 8. Test in Studio (all must pass; write the results down)
- **Test setup:**
  - Back up the test save first (DataStore `PlayerDataV2_Studio`, key `u_<userId>`) and restore it afterwards.
  - Set Workspace attribute `BattlePassTest = true` while testing the pass, and remove it afterwards.
  - MCP scripts get their own copy of modules, so drive the game through remotes and the DataStore. Mouse input uses real viewport pixels; prefer `instance_path` clicks.
- **Every charm** on every one of the 14 guns, in stock and in at least one skin: it hangs from the ring, doesn't clip into the gun, and doesn't cover the sights in first person or in ADS. Take screenshots: first person, third person, Locker.
- **Swing:** walk, sprint, jump, turn fast, fire full-auto (Odin), fire the sniper (Operator). It looks natural and settles; no jitter when standing still.
- **Extras:** they work, and High Score counts up in a bot match (Workspace `ServerRole = "Match"`, `BotMatch = "1v1"`; set them back to `ServerRole = "Lobby"` and clear `BotMatch` afterwards).
- **Pass:** claiming the 8 charms from the pass grants them (`SeasonRequest`).
- **Equip:** a charm on one gun, moved to another gun, then NONE. All of it saves across a rejoin. A forged request (an unowned charm, a bad gun id, NaN) is rejected.
- **Phone:** check at 844x390 that the Locker charm UI fits. The Device Emulator needs the owner, so ask them.
- **Code:** `stylua --check src`, `selene src` (0 warnings) and `rojo build default.project.json -o <a temp file outside the repo>` all pass.

## 9. Finish
- **Commit** small working steps on `main`, staging exact paths only (never `git add -A` or `git add vault`). Don't commit `.blend` files over 50 MB or any `.rbxl`. Don't push.
- **Vault:**
  - A results section in `vault/05 Production/Handoff - Charms 2026-11-27.md`.
  - The `vault/04 Tech/Battle Pass Build Plan.md` progress (phase 6).
  - The `vault/00 Home.md` Status entry.
  - `vault/04 Tech/Code Map.md` lines for anything new (Config/Charms, the `charm` Locker action, `LockerCharms`, the charm controller).
- **Tell the owner:**
  - what was built;
  - the screenshots;
  - what wasn't tested;
  - **save the place in Studio**.
- **Ask the owner** the open questions in the handoff note if they're still open.
