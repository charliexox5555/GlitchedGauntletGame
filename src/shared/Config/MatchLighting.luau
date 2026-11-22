--!strict
-- The lighting every match map starts from (shared/MapLighting), before its own "Lighting" config and "LightingFx"
-- go on top. These are the retired match place's own Lighting values (read 2026-11-21), with no effects: since the
-- place merge the place's Lighting is the lobby's (sky, atmosphere, hub grade ...), which maps were never built on.

return table.freeze({
	Ambient = Color3.new(0.360784, 0.368627, 0.423529),
	Brightness = 1.5,
	ClockTime = 0.5,
	ColorShift_Bottom = Color3.new(0, 0, 0),
	ColorShift_Top = Color3.new(0.666667, 0.721569, 0.862745),
	EnvironmentDiffuseScale = 0.4,
	EnvironmentSpecularScale = 0.15,
	ExposureCompensation = 0.6,
	FogColor = Color3.new(0.752941, 0.752941, 0.752941),
	FogEnd = 100000,
	FogStart = 0,
	GeographicLatitude = 40,
	GlobalShadows = true,
	OutdoorAmbient = Color3.new(0.462745, 0.494118, 0.596078),
	ShadowSoftness = 0.35,
})
