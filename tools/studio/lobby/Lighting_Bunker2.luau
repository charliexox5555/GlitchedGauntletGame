--!strict
-- Lighting_Bunker2.luau: lighting for the "Sunwell Bunker, redone" Lobby (rebuild 2026-11-04). Safe to re-run.
-- Underground hub: a near-overhead sun through the oculus onto the spawn dais, a cool readable base (not black),
-- warm practical pools from the build's PointLights, gentle bloom on the neon accents. Technology stays Future (set by
-- hand; scripts can't set it).
assert(game.PlaceId == 133387545285290, "not the Lobby")
local Lighting = game:GetService("Lighting")

Lighting.ClockTime = 12.4
Lighting.GeographicLatitude = 8
Lighting.Brightness = 2.2
Lighting.Ambient = Color3.fromRGB(84, 86, 96)
Lighting.OutdoorAmbient = Color3.fromRGB(108, 108, 116)
Lighting.EnvironmentDiffuseScale = 0.55
Lighting.EnvironmentSpecularScale = 0.5
Lighting.ShadowSoftness = 0.25
Lighting.ExposureCompensation = 0
Lighting.ColorShift_Top = Color3.fromRGB(255, 236, 210)
Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)

local function get(class: string, name: string): any
	local e = Lighting:FindFirstChild(name)
	if e and e.ClassName ~= class then
		e:Destroy()
		e = nil
	end
	if not e then
		e = Instance.new(class)
		e.Name = name
		e.Parent = Lighting
	end
	return e
end

local atmo = get("Atmosphere", "Atmosphere")
atmo.Density = 0.3
atmo.Offset = 0
atmo.Haze = 1.1
atmo.Glare = 0
atmo.Color = Color3.fromRGB(190, 182, 168)
atmo.Decay = Color3.fromRGB(92, 98, 110)

local bloom = get("BloomEffect", "Bloom")
bloom.Intensity = 0.45
bloom.Size = 22
bloom.Threshold = 1.6

local cc = get("ColorCorrectionEffect", "ColorCorrection")
cc.Brightness = 0.03
cc.Contrast = 0.12
cc.Saturation = 0.16
cc.TintColor = Color3.fromRGB(255, 244, 232)

local rays = get("SunRaysEffect", "SunRays")
rays.Intensity = 0.04
rays.Spread = 0.5

local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
if dof then
	dof.Enabled = false
end
get("StringValue", "LightingPreset").Value = "Bunker2 2026-11-05"
return "lighting set"
