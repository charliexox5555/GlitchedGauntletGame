--!strict
-- The range's own lighting (vault/01 Design/Range v5.md). Owner 2026-11-26: "the lighting in the range could be
-- improved ... there's some dark spots and light spots, which I don't really like". The lobby's warm low sun (amber
-- top light, dark brown shade, hard edges) made sunlit floor glare next to near-black shade under every deck. Here:
-- a high, near-neutral sun, a shade only a little darker than the light (high, neutral ambients and more sky fill),
-- soft shadow edges, and no hub colour grade. Picked in Studio side by side (2026-11-26, captures in the vault note).
-- Applied on the client while the player is in the Range zone (Controllers/MatchLightingController via
-- shared/MapLighting.applyProfile); the lobby's own lighting comes back when they leave.

return table.freeze({
	props = table.freeze({
		Ambient = Color3.fromRGB(104, 106, 112),
		OutdoorAmbient = Color3.fromRGB(122, 125, 132),
		Brightness = 2.5,
		ClockTime = 13.3,
		GeographicLatitude = 24,
		ColorShift_Top = Color3.fromRGB(255, 247, 234),
		ColorShift_Bottom = Color3.fromRGB(30, 31, 34),
		EnvironmentDiffuseScale = 0.6,
		EnvironmentSpecularScale = 0.12,
		ExposureCompensation = -0.2,
		ShadowSoftness = 0.75,
	}),
	-- Lobby effects taken out while in the range.
	suspend = { "HubGrade" },
})
