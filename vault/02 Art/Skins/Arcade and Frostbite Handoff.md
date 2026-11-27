# Arcade and Frostbite skins handoff (Season 1 battle pass)

2026-11-27. The two battle pass skin lines, built in a new Claude (Opus) chat, **one skin first**: the owner approves it before the rest. What the pass gives and why: [Battle Pass Season 1 Contents](../../01%20Design/Battle%20Pass%20Season%201%20Contents.md). Other pass work: [Handoff - Battle Pass Build](../../05%20Production/Handoff%20-%20Battle%20Pass%20Build%202026-11-27.md).

## Paste this into the new chat

> Read `vault/02 Art/Skins/Arcade and Frostbite Handoff.md` and do it. We're making the Season 1 battle pass skin lines, starting with ONE skin: **Arcade on the Havoc (Vandal)**. Build it in Blender to our build rules with every check and a self-grade of 9+, show me the renders, and stop for my approval before anything else. Start by loading the skills and reading the notes the handoff lists. Ask me the questions in its "Ask the owner first" section. Tell me which Blender MCP instance and port you're using before you model anything.

## The two lines (owner, 2026-11-26/27)
- **Arcade (Rare: a shape change, not animated).**
  - A neon arcade cabinet look: coin-slot and joystick-and-button details, pixel-screen panels, cabinet side art in bold flat colours.
  - Each gun keeps its stock silhouette and changes shape in parts (like Sealwork, Inkshift, Payload, Giltfold).
  - Free tier 15 plus 7 premium tiers. **Pass skins now go to a random gun the player owns** (`Lobby/SeasonRewards.resolve`), so Arcade is wanted on **all 14 active guns** (`src/shared/Config/Loadout.luau`):
    - primaries Vandal (Havoc), Spectre (Prowler), Stinger (Hornet), Bucky (Pump), Bulldog (Lancer), Guardian (Marksman), Marshal (Scout), Phantom (Spirit), Odin (Mauler), Operator (Deadeye);
    - secondaries Classic, Sheriff, Shorty, Ghost (Hush).
- **Frostbite (Legendary: animation and its own sounds, the chase line).**
  - Faceted ice crystal over dark metal, a cold blue-white glow.
  - Ice grows on inspect and cracks on a kill.
  - Premium tiers 15, 24 and 29, plus the **Frostbite Knife** at tier 30 (fixed, with the FROSTBITTEN title).
- **The Outlaw (TwinShot) was removed from the game** on 2026-11-27. Don't build it.
- Neither line goes into cases.

## Ask the owner first
1. **Frostbite's gun count.**
   - Option 1 (recommended): Frostbite only on its 3 guns (Phantom, Guardian, Vandal) plus the Knife, and the random roll for a Frostbite tier picks only among guns that have a Frostbite model. That's a one-line change in `SeasonRewards.rollGun`: also require `Shared/Locker.hasSkin(gun, line)`.
   - Option 2: Frostbite on all 14 guns, which is 14 Legendary skins with animation and sounds.
2. **Concept sheet first, or straight to Blender?** The usual path is a concept sheet from ChatGPT ([README](README.md), `_Template/`), then Blender. The theme is clear enough to block out in Blender and show renders instead. Ask which the owner wants for the Havoc.
3. The **line names** "Arcade" and "Frostbite" are placeholders. Keep them as ids unless the owner renames them.

## Read before modelling
- **Skills:** `gauntlet-build-style` and `gauntlet-model-joins` (they're mandatory), and `blender-director` first for Blender work.
- **Rules:** [Style Bible](../Style%20Bible.md) and [Art Direction](../Art%20Direction.md) (the gun model standard: bones, `CharmPoint`, Neon parts as separate MeshParts).
- **Pitfalls:** [Skin Build Pitfalls](Skin%20Build%20Pitfalls.md). Run its checks before showing anything.
- **The closest existing Rare process:** [Rare Line Rework Handoff](Rare%20Line%20Rework%20Handoff.md). Copy its gates and bookkeeping.
- **Installing:** [Moderate Skin Deployment](Moderate%20Skin%20Deployment.md) and [Blender and Studio Handoff](Blender%20and%20Studio%20Handoff.md).
- **Stock sources:** `art-source/weapons/RemasterV2/<Gun>/` (the Vandal: `Vandal_RemasterV2_v05.blend`) and `art-source/weapons/ModelSheets/<Gun>_model_sheet.png`. Take dimensions and camera alignment from the stock asset.
- **Owner taste (memory):**
  - A clear ADS window: nothing new in the sight picture.
  - No Glass material near the camera.
  - Sights named `*Sight*`.
  - No flush layers.
  - Buried joins.
  - Skins connect to the gun.

## The first skin: Arcade Havoc
- Build from the Vandal's stock Blender file into `art-source/weapons/Skins/Arcade/Vandal/v01/`. Keep the stock bones and rig so the stock animations play.
- Keep `CharmPoint` and the charm ring where the stock gun has them, because charms are being built at the same time ([Handoff - Charms](../../05%20Production/Handoff%20-%20Charms%202026-11-27.md)).
- **Show the owner:**
  - side, 3/4 and top renders;
  - a first-person view from the held camera;
  - an ADS view;
  - your self-grade with the checks you ran.
- **Stop and wait for approval.** On "yes":
  1. Install it in the game: `Config/Skins` line entry, `SkinStore` manifest, `Shared/Locker.COLORS` / `EMBLEMS` for the line.
  2. Test it in the Locker and in a bot match.
  3. Then ask whether to go on with the other 13 Arcade guns, one at a time, each with the same checks.

## Bookkeeping
- A build ledger: `vault/02 Art/Skins/Arcade/Build Ledger.md` (copy the Prism / Redline ledger form).
- After each approved skin: the Asset Tracker row, and the Home Status entry.
- **Git:** stage exact paths only, never `.rbxl`. No push unless the owner says.
- **Studio:** remind the owner to save the place after Studio edits.
