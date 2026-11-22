# Release Map Audit (2026-11-21)

Steps 2-4 of the owner's [release plan](Map%20Lineup%202026-11-21.md#release-plan-owner-2026-11-21): audit the 12 release maps, delete the legacy maps, and add sounds and effects where they fit. Done in the match place (placeId 133387545285290). **Saved as v1022.** The last save before this work was v1018, so the place's version history is the backup of everything deleted here.

Lineup (`Config/Match` MAPS): regular Arena, Pier, Wharf, Snowpeak4, Rooftops4, Greenhouse4, Foundry4, CanyonOutpost; large BigArena, Dockyard, Metro4, OldTown4.

## Audit

How: a structure scan per map (contract folders, tags, anchoring, CanTouch, loose parts, MaterialVariants, lights, scripts), then `tools/studio/maps/Audit.luau` (z-fighting), `FloatAudit.luau` (floating groups) and `SlopeAudit.luau` (coincident slopes) once per map.

| Map | Parts | Contract | Textures | Z-fight / float / slope | Fixed here | SFX / VFX added |
|---|---|---|---|---|---|---|
| Arena | 52 | Spawns 4/4, Lighting + LightingFx; older contract (no Bounds) | plain RIVALS parts (by design) | 0 / 0 / 0 | CanTouch off (44 parts), WinnerStage added | none (by design) |
| Pier | 101 | Spawns 4/4, KillDepth, Lighting; older contract | Port kit + plain parts | 0 / 1* / 0 | CanTouch off (33), WinnerStage, ambience box added | water ×4, gulls ×2; water glints ×2 |
| Wharf | 1,690 | full (Spawns 4/4, Bounds, WinnerStage, Lighting, LightingFx, KillDepth) | Concrete-02a 430, Corrugated_01a 119, Diamond Plate 28, WoodPlank01a 19 | 0 / 0 / 0 | – | water ×4, gulls ×2, crane hum, far ship horn |
| Snowpeak4 | 1,962 | full, 5/5 | Ice_01b 329, WoodPlank01a_Big 336, Snow_01a 257, Wood01a 106 | 0 / 0 / 0 | – | none new (snowfall, chimney smoke and two fire pits already) |
| Rooftops4 | 5,182 | full, 5/5; 50 lights | Concrete-01a 2,124, Metal 2022 1,249, RV_Brick10 88, ConcretePanels-02a 41 | 0 / 0 / 0 | CanTouch off on 8 wedges (stair ramps, step cheeks), builder too | AC ×4, pigeons ×2, car horns ×2 (street), far siren; vent steam ×4 |
| Greenhouse4 | 3,350 | full, 5/5 | Concrete-01a 1,129, G4_Foliage 292, Wood01a 227, Metal 2022 180, RV_Brick10 142 | 0 / 0 / 0 † | – | pond trickle, pigeons ×2 (boiler chimneys); dust motes in the palm house |
| Foundry4 | 1,486 | full, 5/5; 27 lights | Metal 2022 686, Concrete-01a 74, Corrugated_01a 68, Wood03a 67 | 0 / 0 / 0 † | – | furnace + pour-pit roar; embers off the runner ×3, chimney plumes ×2 |
| CanyonOutpost | 1,822 | full, 5/5 | Wood01a 668, Concrete-01a 323, Wood03a 84, Metal 2022 69, Sand_01a 63 | 0 / 0 / 0 † | – | water-tower creak; low dust puffs over the floor |
| BigArena | 98 | Spawns 5/5, Lighting; older contract | plain RIVALS parts | 0 / 0 / 0 | CanTouch off (88), WinnerStage | none (by design) |
| Dockyard | 185 | Spawns 5/5, KillDepth, Lighting; older contract | Port kit + plain parts | 0 / 1* / 0 | CanTouch off (63), WinnerStage, ambience box fixed | water ×6, gulls ×2, gantry hum, far ship horn; glints ×2 |
| Metro4 | 3,046 | full, 5/5 | Concrete-01a 1,186, Metro_Facade2 90, WoodPlank01a 52, Diamond Plate 51 | 0 / 0 / 0 | – | rail hum at both tunnel mouths |
| OldTown4 | 6,710 | full, 5/5 | Concrete-01a 3,258, Concrete-02a 822, WoodPlank01a 564, Fabric2022 130 | 0 / 0 / 0 | – | both fountains, pigeons ×2 on the clock tower |

\* The one "floating group" on Pier and Dockyard is the whole deck: it stands about 1 stud above the water plane (the lowest visible part). By design.
† Some kit meshes could not be read by EditableMesh and were tested as boxes (Greenhouse4 17, CanyonOutpost 11, Foundry4 6).

**Everywhere:** all parts anchored; `Barriers` folders are empty on all 12 (ghost hold, by design). The 8 newer maps have CanTouch off on every part and one loose part each (their `WinnerStage`). No temp ModuleScripts (`RT4_`, `GH4_`, `FD4_`, `CO_`, `TX_`, `*DevBuild`) were left in ServerStorage. Removed: 17 `_ReachProbe` parts in Workspace and an empty `ServerStorage._OT4Audit`.

**Kits:** every builder's libraries are in `ServerStorage.MapKit`: Port (Pier, Dockyard), Wharf + Props, Snowpeak4, Rooftops4, Greenhouse4 + Greenhouse4Rivals, Foundry4 + Foundry4Rivals, CanyonOutpost + CanyonOutpostRivals, Metro4, OldTown4.

**The four older maps** (Arena, BigArena, Pier, Dockyard) keep the 2026-11-16 Greybox contract: no `Bounds` folder (invisible walls and ceiling). Their new `WinnerStage` (Studio only; the Greybox builders predate the tag) stands at team A's spawn centroid facing the middle; before, the win scene fell back to the Baseplate stage.

**Bug fixed:** `Config/Ambience` placed Dockyard's sound box at (-1500, 210, 0), where the old Dockyard stood; the map is at (5500, 200, -1500), so its harbour beds never played. Pier had no entry. Both are fixed.

**Source fixes:** `tools/studio/maps/MapKit.luau` makes Greybox parts CanTouch false; `tools/studio/maps/Rooftops4/Build.luau` sets CanTouch false on its three hand-made wedges.

## Legacy cleanup

**Deleted from Workspace (24 models):** Whitebox, BigWhitebox, Rooftops, Rooftops2, Rooftops3, Bunker, Bunker2, Bunker3, Greenhouse, Greenhouse2, Greenhouse3, Foundry, Snowpeak, Snowpeak2, Snowpeak3, OldTown, OldTown2, OldTown3, Metro, Metro2, Metro3, Courtyard, ModelKit, Dockyard2.

**Deleted from `ServerStorage.MapKit` (22 libraries):** Dockyard (the old 2026-11-03 Dockyard kit; today's Dockyard uses Port), Metro, OldTown, Bunker, Greenhouse, Rooftops, Snowpeak, Dockyard2, Rooftops2, Bunker2, Metro2, Greenhouse2, Snowpeak2, OldTown2, Rooftops3, Town, Foundry, Snowpeak3, ModelKit, Bunker3, Metro3, Greenhouse3.

**Deleted from `ServerStorage.MapBackups` (the folder):** Rooftops2_v1, Rooftops2_Pigeons, Dockyard_PreJumpFix_2026-11-13. `ServerStorage.Maps` doesn't exist in edit (MapService makes it at run time).

That is 42,528 parts. It matters for live servers: `MapService.stashMaps` moves every Workspace model with tagged spawns into ServerStorage.Maps, so every server was carrying all the old maps.

**Code:** nothing in `src/` loaded the old ids. Removed: 8 dead `Config/Ambience` map entries (Dockyard2, Rooftops, OldTown, Snowpeak, Metro, Bunker, Greenhouse, Rooftops2) and 386 `AssetData/MatchMaps` rows no instance used any more (44 kept, comments now name the current users). The `Config/Match` comment now says the legacy maps are gone. The old builders in `tools/studio/maps/` stay (git history; their kits are gone from the place).

## Left for the owner

- **RIVALS copies that ship with the place:** `Workspace.Docks` (2,514 parts) and `Workspace.Museum` (2,183 parts), each with a RIVALS ModuleScript (`MapVersion_Docks` / `MapVersion_Museum`); `Workspace["Rivals Asset Pack"]` (4,209 parts); `ServerStorage.MapsRivals` (22 maps). Workspace content streams to players, so the first three probably shouldn't go out with a release. Not touched.
- `Workspace.R15` / `R6` dummies, `Baseplate` and `SpawnLocation` (the Baseplate is the win scene's fallback stage). Not touched.
- Sounds our library doesn't have: a church bell (OldTown4), birdsong (Greenhouse4), steam hiss (Foundry4, Rooftops4), a train passing (Metro4). They need licensed recordings through the sound pipeline before they can go in.
- Terrain at the old map spots wasn't checked.

## SFX / VFX

Built by `tools/studio/maps/ReleaseFx.luau` (re-runnable): sound emitters in `<Map>.Ambience` (invisible 1-stud parts tagged `AmbienceEmitter`), effects in `<Map>.World.Life.ReleaseFx` (`<Map>.Life.ReleaseFx` on Pier and Dockyard), tagged `LifeEmitter` so MapLifeController sleeps them past their range and halves them on low graphics. Positions mirror between the halves, so both teams hear the same thing. Fields come from shared AssetData rows: the existing `Sound` rows (398-407) and three new ones (427 Furnace, 428 Fountain, 429 TrackHum), plus `Range` rows 396 (140), 397 (170) and a new 430 (300, Foundry's chimney plumes).

**Sounds** are our existing ambience library (`Config/SharedSoundAssets`, CC0 recordings at a common loudness, mixed well under the guns). New `Config/Ambience` SPOTS, all made from existing recordings:
- `Furnace`: AmbHum at 0.45 pitch, volume 0.5, range 55, loop;
- `Fountain`: AmbWater at 1.18 pitch, volume 0.4, range 32, loop;
- `TrackHum`: AmbHum at 0.55 pitch, volume 0.32, range 60, loop.

The controller plays only the 4 nearest loops (MAX_LOOPS).

**Effects** use our own stylised textures (Config/VfxTextures), at low rates:
- Steam: the Rooftops2 vent steam, unchanged ("improve, don't replace"), rate 2.4-3.
- Embers: MOLLY_EMBER, orange to red, 5 a second per 40-stud run.
- Chimney plumes: dark MOLLY_SMOKE at 1.4 a second, 85 studs up.
- Glints: the Dockyard2 sun sparkle on the water, 12 a second over 150-200 × 40 studs.
- Dust: DASH_PUFF puffs, 80% transparent or more, 1.2 a second, ground level.
- Motes: the Bunker2 sun-dust, 4 a second.

Arena, BigArena and Snowpeak4 get nothing new.

## What to test (owner playtest)
- Each map: nothing in the ambience masks footsteps or gunfire. Loops: Foundry4 furnace, OldTown4 fountains, Rooftops4 AC, the water on Wharf, Pier and Dockyard.
- Foundry4: the embers read as sparks over the runner and don't hide anyone on the bridges. Particles don't show in edit-mode stills, so these were only checked by their numbers.
- CanyonOutpost dust and Greenhouse4 motes: barely there, never a smoke screen.
- Dockyard: the harbour beds play now.
- Win scene on Arena, BigArena, Pier and Dockyard: the winners stand at team A's spawn.

Files: `src/shared/Config/Ambience.luau`, `Config/AssetData/MatchMaps.luau`, `Config/Match.luau`, `Config/MapLife.luau` (comment), `tools/studio/maps/ReleaseFx.luau`, `MapKit.luau`, `Rooftops4/Build.luau`. Rojo synced the `src/` changes into the match place.
