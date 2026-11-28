--!nocheck
-- Draft Duels / Edit mode. Hub lighting overhaul (2026-11-28, vault/02 Art/Lobby Lighting Pass.md).
-- Owner: "parts like in the middle where it is way too bright on the player". Players blew out because high
-- exposure (+0.1) and a low bloom threshold (1.4) sat on top of many long-range lamps stacking on the walk paths
-- (16 hub wall lamps B2.5/R64, 18 Duels rock lamps B3/R70-80, a deck SurfaceLight 9 studs over the player, Locker
-- fill points at head height). This pass lowers exposure and bloom, trims those lamps, and halves the shadow
-- casters in the hub and Duels (60 -> 42 in the lobby) for phones.
-- Run after BuildHub / BuildDuels / BalanceReleaseLighting / BuildLockerV*; rerunning those undoes this pass.
-- Every changed property keeps its old value as a "Pre_<Prop>" attribute (and the new one as "New_<Prop>"), so the
-- pass can be flipped back with RevertHubLightingPass below.
-- Lighting here is the lobby baseline: shared/MapLighting captures it before a match or the Range profile and
-- restores it after, so no code change is needed.

assert(game.PlaceId == 71551303511506, "Select the Draft Duels place")
local Lighting = game:GetService("Lighting")
local S = workspace.LobbyV5.Shell

local function keep(inst, props)
	for _, k in props do
		if inst:GetAttribute("Pre_" .. k) == nil then
			inst:SetAttribute("Pre_" .. k, inst[k])
		end
	end
end

local function set(inst, props)
	local names = {}
	for k in props do
		table.insert(names, k)
	end
	keep(inst, names)
	for k, v in props do
		inst[k] = v
		inst:SetAttribute("New_" .. k, v)
	end
end

-- Global: less exposure, softer warm top light, less sheen, bloom only on real emitters.
set(Lighting, {
	Brightness = 2.0, -- 2.4
	ExposureCompensation = -0.3, -- 0.1
	ColorShift_Top = Color3.fromRGB(255, 228, 198), -- 255,214,170 (tinted skin orange)
	EnvironmentSpecularScale = 0.15, -- 0.25
})
set(Lighting.Bloom, { Intensity = 0.35, Threshold = 2.2, Size = 20 }) -- 0.6 / 1.4 / 24

-- Hub: 16 rock-wall lamps aimed at the floor overlapped in the middle.
local i = 0
for _, lamp in S.Hub.Dressing.WallLamps:GetChildren() do
	local l = lamp:FindFirstChild("SpotLight", true)
	if l then
		i += 1
		set(l, { Brightness = 1.4, Range = 50, Shadows = i % 2 == 0 }) -- 2.5 / 64 / all shadows
	end
end

-- Duels: rock lamps, wall lamps and uplights all stacked on the deck.
local far, wall = 0, 0
for _, l in S.Duels.Lights:GetDescendants() do
	if l:IsA("Light") then
		local n = l.Parent.Parent.Name
		if n:match("^RockLamp_Far") then
			far += 1
			set(l, { Brightness = 1.6, Shadows = far % 2 == 1 }) -- 3, all shadows
		elseif n:match("^RockLamp_Side") then
			set(l, { Brightness = 1.6 }) -- 3
		elseif n:match("^ChasmGlow") then
			set(l, { Brightness = 1.8, Shadows = false }) -- 3, shadows
		elseif n:match("^WallLamp") then
			wall += 1
			set(l, { Brightness = 1.6, Range = 40, Shadows = wall % 2 == 1 }) -- 3 / 44 / all shadows
		elseif n:match("^Uplight") then
			set(l, { Brightness = 1.5 }) -- 2.5
		elseif n:match("^Fill") then
			set(l, { Brightness = 0.6 }) -- 0.9
		end
	end
end

-- Release route fills (SurfaceLights low over the walk paths): 55%.
for _, m in S.ReleaseRouteLighting:GetChildren() do
	local l = m:FindFirstChildWhichIsA("Light")
	if l then
		local base = l:GetAttribute("Pre_Brightness") or l.Brightness
		set(l, { Brightness = base * 0.55 })
	end
end

-- Locker: low ceiling, fill points at head height, pedestal accents right beside the player.
for _, l in S.Locker.Room:GetDescendants() do
	if l:IsA("Light") then
		local n = l.Parent.Name == "Lens" and l.Parent.Parent.Name or l.Parent.Name
		if n == "Fill" then
			set(l, { Brightness = 0.4 }) -- 0.73
		elseif n == "CeilingLight" then
			set(l, { Brightness = 1.0 }) -- 1.24
		end
	end
end
local circle = S.Locker:FindFirstChild("ArmoryV2") and S.Locker.ArmoryV2.Areas:FindFirstChild("GunCircle")
if circle then
	for _, l in circle:GetDescendants() do
		if l:IsA("PointLight") and l.Parent.Name == "Accent" then
			set(l, { Brightness = 0.3, Range = 4 }) -- 0.45 / 6
		end
	end
end

local shadows = 0
for _, d in workspace.LobbyV5:GetDescendants() do
	if d:IsA("Light") and d.Enabled and d.Shadows then
		shadows += 1
	end
end
print("[HubLightingPass] done, shadow-casting lights in LobbyV5:", shadows)

--[[ RevertHubLightingPass (paste on its own to go back):
local insts = { game.Lighting, game.Lighting.Bloom }
for _, d in workspace.LobbyV5:GetDescendants() do if d:IsA("Light") then table.insert(insts, d) end end
for _, x in insts do for a, v in x:GetAttributes() do local k = a:match("^Pre_(.+)$") if k then x[k] = v end end end
]]
