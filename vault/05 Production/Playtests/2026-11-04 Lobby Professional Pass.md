# Lobby art refinement — 2026-11-04

Built in **Lobby | Gauntlet game**, place **133387545285290**. Review pass, not published.

## Direction
Grounded tactical bunker materials, Valorant-like clean shapes and typography, and restrained RIVALS-style colour and display energy. The existing circular structure is preserved. The ten user screenshots in `01 Design/RivalsMapConcepts` were used for composition, destination identity and display hierarchy, with original models and graphics.

## Changes
- Six original Blender pieces: chamfered entrance header, architectural fin, versus crest, raised-gauntlet trophy, equipment case and key display. Shared kit: **3,948 triangles** before placement.
- Three rebuilt entrance presentations: Duels, Market and Weapons. Mounted text panels, clear main titles, small metadata and contrasting emblems.
- Four structured leaderboard faces and **16 numbered duel-bay signs**, floor medallions, aisle chevrons and party-size motifs. Existing placeholder scores remain marked EXHIBITION.
- A championship trophy at the far Duels dais, a ceiling-mounted title with physical hangers, and restrained chamber lighting. The upper gauntlet gently swivels through the existing streaming-aware ambience script.
- Original case/key models replace three blank Market item props. Equipment cases dress the Armoury entry.
- Typography updated across the non-range world labels. No menus, purchases, matchmaking, combat, teleport or queue systems added.

## Overlap repairs
A Blender triangle-level scan found coplanar overlaps in the existing non-range kits. The repair subtracts intersecting face regions and preserves UVs, instead of deleting objects from bounding-box matches. **42 unique meshes** repaired and applied to **193 placed instances**, plus their kit templates. A full four-kit verification, combining repaired and unchanged pieces, reports **0 coplanar overlap groups above 0.03 square studs of projected area**. Selected floor graphics and inlays also have explicit depth separation.

This verifies the repaired kit geometry; it is not a claim that every possible cross-model intersection or camera angle in the entire map has been exhausted. Both range areas were excluded from the repair.

## Verification
- All **four protected range folders** match their before/after fingerprints.
- The complete **1,293-part collision layout** matches its original fingerprint.
- All **239 new decorative parts** are anchored, non-colliding, non-querying and non-touching; no new scripts were added.
- Play-mode walk from spawn to the first bay and through the hall to the chamber passed. Trophy rotation measured 1.74 degrees over 1.5 seconds when nearby; dormant at spawn because of distance culling.
- No new script errors. Studio reports an unrelated content-type warning for asset 203785492, outside the new kit.
- StyLua checks and `git diff --check` passed. A physical phone performance pass remains unmeasured.

## Sources and recovery
Blender: `art-source/lobby/Kit_Professional.blend`, `Kit_SurfaceRepair.blend`. Builders: `tools/blender/build_lobby_professional.py`, `repair_lobby_coplanar.py`, `audit_lobby_coplanar.py`.

Install order for rebuilding from the existing lobby: install Professional kit with `kit_bundle.py Professional`, run `Art_Professional.luau`, then `ApplySurfaceRepair.luau`. Do not re-run the old art builders afterward without reapplying this pass. The existing ambience setup clears tags, so if it is rebuilt, run `Art_Professional.luau` again afterward.

Backups under `art-source/lobby/Studio/`:
- `Lobby_BeforeProfessional_20261104.rbxm`: complete Lobby before changes.
- `Lobby_Professional_20261104.rbxm`: complete final Lobby.
- `ProfessionalPass_20261104.rbxm`: new decor alone (existing sign and mesh edits are in the complete backup).
- `LobbyKit_Professional_20261104.rbxm`: final kit library.

No unrelated edits to `art-source/weapons/GunTest.blend` or `tools/studio/maps/Snowpeak/Art.luau` were touched. The current Studio place still needs to be saved by the creator; it has not been published.

## Review images
![Spawn](../../02%20Art/References/lobby/professional-20261104/lobby-spawn.png)
![Duel hall](../../02%20Art/References/lobby/professional-20261104/lobby-duels.png)
![Gauntlet](../../02%20Art/References/lobby/professional-20261104/lobby-trophy.png)
