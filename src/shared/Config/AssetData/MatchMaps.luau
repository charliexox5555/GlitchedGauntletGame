--!strict
-- Authored MatchMaps defaults. Apply the entry key and GauntletAuthoredData as CollectionService tags.
-- Shared rows let cloned assets retain their configuration.
-- stylua: ignore
return {
	GGAsset_MatchMaps_11 = { ["Ambient"] = Color3.new(0.50196081399917603, 0.51764708757400513, 0.55686277151107788), ["Brightness"] = 3, ["ClockTime"] = 13.199999999999999, ["EnvironmentDiffuseScale"] = 0.40000000000000002, ["EnvironmentSpecularScale"] = 0.10000000000000001, ["ExposureCompensation"] = 0.10000000000000001, ["OutdoorAmbient"] = Color3.new(0.65882354974746704, 0.68235296010971069, 0.73725491762161255) }, -- Workspace.Arena.Lighting (+1)
	GGAsset_MatchMaps_12 = { ["Ambient"] = Color3.new(0.50196081399917603, 0.51764708757400513, 0.55686277151107788), ["Brightness"] = 3, ["ClockTime"] = 13.5, ["ExposureCompensation"] = 0.10000000000000001, ["OutdoorAmbient"] = Color3.new(0.65882354974746704, 0.68235296010971069, 0.73725491762161255) }, -- Workspace.Pier.Lighting
	GGAsset_MatchMaps_17 = { ["Ambient"] = Color3.new(0.50196081399917603, 0.51764708757400513, 0.55686277151107788), ["Brightness"] = 3, ["ClockTime"] = 17.199999999999999, ["ExposureCompensation"] = 0.10000000000000001, ["OutdoorAmbient"] = Color3.new(0.65882354974746704, 0.68235296010971069, 0.73725491762161255) }, -- Workspace.Dockyard.Lighting
	GGAsset_MatchMaps_269 = { ["KillDepth"] = 30, ["LayoutVersion"] = "greybox v1 2026-11-16" }, -- Workspace.Dockyard (+1)
	GGAsset_MatchMaps_271 = { ["KillDepth"] = 40, ["LayoutVersion"] = "v2 2026-11-16 grid-snapped" }, -- Workspace.Arena (+1)
	GGAsset_MatchMaps_283 = { ["Kind"] = "baffle" }, -- Workspace.Arena.Greybox.Spawn.Spawn screen (+7)
	GGAsset_MatchMaps_299 = { ["Kind"] = "deck" }, -- Workspace.Arena.Greybox.Heights.Corner deck (+37)
	GGAsset_MatchMaps_309 = { ["Kind"] = "frame" }, -- Workspace.Arena.Greybox.Frames.Frame lintel (+3)
	GGAsset_MatchMaps_310 = { ["Kind"] = "full" }, -- Workspace.Arena.Greybox.Beacon.Beacon wing (+73)
	GGAsset_MatchMaps_317 = { ["Kind"] = "low" }, -- Workspace.Arena.Greybox.LowCover.Frame sill (+15)
	GGAsset_MatchMaps_340 = { ["Kind"] = "pillar" }, -- Workspace.Arena.Greybox.Beacon.Beacon pylon (+15)
	GGAsset_MatchMaps_341 = { ["Kind"] = "plinth" }, -- Workspace.Arena.Greybox.Beacon.Beacon plinth (+13)
	GGAsset_MatchMaps_362 = { ["KitGroup"] = "Kit" }, -- Workspace.Dockyard.Art.Bollards.Bollard (+41)
	GGAsset_MatchMaps_396 = { ["Range"] = 140 }, -- Workspace.CanyonOutpost.World.Life.ReleaseFx.Dust_01.Dust (+8)
	GGAsset_MatchMaps_397 = { ["Range"] = 170 }, -- Workspace.Dockyard.Life.ReleaseFx.Glints_01.Glints (+3)
	GGAsset_MatchMaps_398 = { ["Sound"] = "AC" }, -- Workspace.Rooftops4.Ambience.AC_01 (+3)
	GGAsset_MatchMaps_399 = { ["Sound"] = "CarHorn" }, -- Workspace.Rooftops4.Ambience.CarHorn_07 (+1)
	GGAsset_MatchMaps_400 = { ["Sound"] = "CraneHum" }, -- Workspace.Dockyard.Ambience.CraneHum_09 (+1)
	GGAsset_MatchMaps_401 = { ["Sound"] = "Creak" }, -- Workspace.CanyonOutpost.Ambience.Creak_01
	GGAsset_MatchMaps_403 = { ["Sound"] = "Gulls" }, -- Workspace.Dockyard.Ambience.Gulls_07 (+5)
	GGAsset_MatchMaps_404 = { ["Sound"] = "Horn" }, -- Workspace.Dockyard.Ambience.Horn_10 (+1)
	GGAsset_MatchMaps_405 = { ["Sound"] = "Pigeon" }, -- Workspace.Greenhouse4.Ambience.Pigeon_02 (+5)
	GGAsset_MatchMaps_406 = { ["Sound"] = "Siren" }, -- Workspace.Rooftops4.Ambience.Siren_09
	GGAsset_MatchMaps_407 = { ["Sound"] = "Water" }, -- Workspace.Dockyard.Ambience.Water_01 (+13)
	GGAsset_MatchMaps_411 = { ["KillDepth"] = 6, ["LayoutVersion"] = "v1 2026-11-20 RIVALS Docks flow" }, -- Workspace.Wharf
	GGAsset_MatchMaps_412 = { ["Ambient"] = Color3.fromRGB(122, 128, 142), ["Brightness"] = 3, ["ClockTime"] = 10.5, ["ColorShift_Top"] = Color3.fromRGB(255, 240, 220), ["EnvironmentDiffuseScale"] = 0.45, ["EnvironmentSpecularScale"] = 0.1, ["ExposureCompensation"] = 0.2, ["GeographicLatitude"] = 30, ["OutdoorAmbient"] = Color3.fromRGB(160, 170, 190), ["ShadowSoftness"] = 0.2 }, -- Workspace.Wharf.Lighting
	GGAsset_MatchMaps_413 = { ["KillDepth"] = 20, ["LayoutVersion"] = "v1 2026-11-20 RIVALS Big Station flow" }, -- Workspace.Metro4
	GGAsset_MatchMaps_414 = { ["Ambient"] = Color3.fromRGB(124, 128, 138), ["Brightness"] = 3, ["ClockTime"] = 14.5, ["ColorShift_Top"] = Color3.fromRGB(255, 242, 224), ["EnvironmentDiffuseScale"] = 0.45, ["EnvironmentSpecularScale"] = 0.1, ["ExposureCompensation"] = 0.05, ["GeographicLatitude"] = 35, ["OutdoorAmbient"] = Color3.fromRGB(164, 172, 188), ["ShadowSoftness"] = 0.2 }, -- Workspace.Metro4.Lighting
	GGAsset_MatchMaps_415 = { ["KillDepth"] = 20, ["LayoutVersion"] = "v1 2026-11-20 Snowpeak2 vibe, open middle (RIVALS Village flow)" }, -- Workspace.Snowpeak4
	GGAsset_MatchMaps_416 = { ["Ambient"] = Color3.fromRGB(128, 136, 152), ["Brightness"] = 3, ["ClockTime"] = 10.2, ["ColorShift_Top"] = Color3.fromRGB(255, 238, 214), ["EnvironmentDiffuseScale"] = 0.5, ["EnvironmentSpecularScale"] = 0.12, ["ExposureCompensation"] = -0.1, ["GeographicLatitude"] = 40, ["OutdoorAmbient"] = Color3.fromRGB(168, 180, 204), ["ShadowSoftness"] = 0.25 }, -- Workspace.Snowpeak4.Lighting
	GGAsset_MatchMaps_417 = { ["KillDepth"] = 20, ["LayoutVersion"] = "v1 2026-11-21 Collina hill town (OldTown2 vibe)" }, -- Workspace.OldTown4
	GGAsset_MatchMaps_418 = { ["Ambient"] = Color3.fromRGB(128, 112, 104), ["Brightness"] = 2.6, ["ClockTime"] = 17.1, ["ColorShift_Top"] = Color3.fromRGB(255, 214, 168), ["EnvironmentDiffuseScale"] = 0.45, ["EnvironmentSpecularScale"] = 0.12, ["ExposureCompensation"] = 0.1, ["GeographicLatitude"] = 32, ["OutdoorAmbient"] = Color3.fromRGB(172, 150, 134), ["ShadowSoftness"] = 0.3 }, -- Workspace.OldTown4.Lighting
	GGAsset_MatchMaps_419 = { ["KillDepth"] = 20, ["LayoutVersion"] = "v1 2026-11-21 city block at blue hour (Rooftops remade)" }, -- Workspace.Rooftops4
	GGAsset_MatchMaps_420 = { ["Ambient"] = Color3.fromRGB(100, 100, 128), ["Brightness"] = 1.6, ["ClockTime"] = 18.35, ["ColorShift_Top"] = Color3.fromRGB(255, 170, 140), ["EnvironmentDiffuseScale"] = 0.5, ["EnvironmentSpecularScale"] = 0.2, ["ExposureCompensation"] = 0.35, ["GeographicLatitude"] = 40, ["OutdoorAmbient"] = Color3.fromRGB(150, 150, 186), ["ShadowSoftness"] = 0.4 }, -- Workspace.Rooftops4.Lighting
	GGAsset_MatchMaps_421 = { ["KillDepth"] = 20, ["LayoutVersion"] = "v1 2026-11-21 Victorian conservatory in a walled garden (Greenhouse remade)" }, -- Workspace.Greenhouse4
	GGAsset_MatchMaps_422 = { ["Ambient"] = Color3.fromRGB(110, 115, 108), ["Brightness"] = 2.6, ["ClockTime"] = 10.6, ["ColorShift_Top"] = Color3.fromRGB(255, 236, 210), ["EnvironmentDiffuseScale"] = 0.5, ["EnvironmentSpecularScale"] = 0.2, ["ExposureCompensation"] = 0.1, ["GeographicLatitude"] = 35, ["OutdoorAmbient"] = Color3.fromRGB(150, 156, 148), ["ShadowSoftness"] = 0.3 }, -- Workspace.Greenhouse4.Lighting
	GGAsset_MatchMaps_423 = { ["KillDepth"] = 6, ["LayoutVersion"] = "v1 2026-11-21 steel works at night, RIVALS style (Foundry remade)" }, -- Workspace.Foundry4
	GGAsset_MatchMaps_424 = { ["Ambient"] = Color3.fromRGB(92, 94, 108), ["Brightness"] = 1.5, ["ClockTime"] = 0.5, ["ColorShift_Top"] = Color3.fromRGB(170, 184, 220), ["EnvironmentDiffuseScale"] = 0.4, ["EnvironmentSpecularScale"] = 0.15, ["ExposureCompensation"] = 0.6, ["GeographicLatitude"] = 40, ["OutdoorAmbient"] = Color3.fromRGB(118, 126, 152), ["ShadowSoftness"] = 0.35 }, -- Workspace.Foundry4.Lighting
	GGAsset_MatchMaps_425 = { ["KillDepth"] = 20, ["LayoutVersion"] = "v1 2026-11-21 sun-baked mining outpost in a red canyon, RIVALS style" }, -- Workspace.CanyonOutpost
	GGAsset_MatchMaps_426 = { ["Ambient"] = Color3.fromRGB(138, 112, 96), ["Brightness"] = 3, ["ClockTime"] = 14.2, ["ColorShift_Top"] = Color3.fromRGB(255, 226, 190), ["EnvironmentDiffuseScale"] = 0.45, ["EnvironmentSpecularScale"] = 0.1, ["ExposureCompensation"] = 0.05, ["GeographicLatitude"] = 30, ["OutdoorAmbient"] = Color3.fromRGB(176, 146, 124), ["ShadowSoftness"] = 0.2 }, -- Workspace.CanyonOutpost.Lighting
	GGAsset_MatchMaps_427 = { ["Sound"] = "Furnace" }, -- Workspace.Foundry4.Ambience.Furnace_01 (+1)
	GGAsset_MatchMaps_428 = { ["Sound"] = "Fountain" }, -- Workspace.Greenhouse4.Ambience.Fountain_01 (+2)
	GGAsset_MatchMaps_429 = { ["Sound"] = "TrackHum" }, -- Workspace.Metro4.Ambience.TrackHum_01 (+1)
	GGAsset_MatchMaps_430 = { ["Range"] = 300 }, -- Workspace.Foundry4.World.Life.ReleaseFx.Chimney_04.Chimney (+1)
}
