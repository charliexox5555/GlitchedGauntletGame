--!strict
-- Edit-mode evidence shots with a map's own lighting (maps v5 fixed cameras,
-- vault/01 Design/Maps/00 Maps.md). Run in the match place, edit mode:
--
--   loadstring(<this file>)("Rooftops2", "apply")    -- before captures
--   loadstring(<this file>)("Rooftops2", "restore")  -- after
--
-- apply: keeps the place's Lighting properties and children in
-- ServerStorage._PreviewLightingKeep, sets the map's "Lighting" Configuration
-- attributes, clones its "LightingFx" folder into Lighting, and hides the
-- map's Barriers. restore puts all of it back. MapService does the same at
-- runtime; this is only for screen_capture in edit mode.

local ARGS = { ... }
local MAP: string = ARGS[1] or "Rooftops2"
local MODE: string = ARGS[2] or "apply"

local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")

local map = workspace:FindFirstChild(MAP)
assert(map, "no map " .. MAP)
local KEEP = "_PreviewLightingKeep"

if MODE == "apply" then
	assert(not ServerStorage:FindFirstChild(KEEP), "already applied: restore first")
	local keep = Instance.new("Configuration")
	keep.Name = KEEP
	local config = map:FindFirstChild("Lighting")
	if config then
		for name, value in config:GetAttributes() do
			local L: any = Lighting
			keep:SetAttribute(name, L[name])
			L[name] = value
		end
	end
	local saved = Instance.new("Folder")
	saved.Name = "Children"
	saved.Parent = keep
	local fx = map:FindFirstChild("LightingFx")
	if fx then
		for _, c in Lighting:GetChildren() do
			if c:IsA("Sky") or c:IsA("Atmosphere") or c:IsA("PostEffect") or c:IsA("Clouds") then
				c.Parent = saved
			end
		end
		for _, c in fx:GetChildren() do
			local clone = c:Clone()
			clone:SetAttribute("PreviewLighting", true)
			clone.Parent = Lighting
		end
	end
	local barriers = map:FindFirstChild("Barriers")
	if barriers then
		for _, p in barriers:GetDescendants() do
			if p:IsA("BasePart") then
				p:SetAttribute("PreviewT", p.Transparency)
				p.Transparency = 1
			end
		end
	end
	keep.Parent = ServerStorage
	return "applied " .. MAP
end

local keep = ServerStorage:FindFirstChild(KEEP)
assert(keep, "nothing to restore")
local L: any = Lighting
for name, value in keep:GetAttributes() do
	L[name] = value
end
for _, c in Lighting:GetChildren() do
	if c:GetAttribute("PreviewLighting") then
		c:Destroy()
	end
end
local saved = keep:FindFirstChild("Children")
if saved then
	for _, c in saved:GetChildren() do
		c.Parent = Lighting
	end
end
local barriers = map:FindFirstChild("Barriers")
if barriers then
	for _, p in barriers:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("PreviewT") ~= nil then
			p.Transparency = p:GetAttribute("PreviewT") :: number
			p:SetAttribute("PreviewT", nil)
		end
	end
end
keep:Destroy()
return "restored"
