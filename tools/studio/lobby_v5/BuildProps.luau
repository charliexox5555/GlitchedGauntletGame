--!strict
-- Lobby V5 decor props (owner 2026-11-21: cases, boxes, barrels built in Blender, not part-assembled).
-- Source meshes: tools/blender/lobby_v5/v5_props.py → art-source/lobby/v5/Exports/V5_Props.fbx,
-- uploaded as model asset 90719517602535 (art-source/uploads.json).
-- Run in the Lobby place (Edit) through the Studio MCP:
--   1. makeKit()  loads the asset and makes ServerStorage.V5Kit.Props.<Prop> (pivot = floor centre, front = -Z)
--   2. place(parent, name, scheme, localCF)  clones a prop in a colour scheme at hub-local CFrame
-- The hub clusters are placed by the call at the bottom; the owner moves them freely afterwards.

local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")

local ASSET = 90719517602535 -- v2 (v1 71038212676390 rejected: rounded, stuck-on parts)
local O = CFrame.new(0, 0, -1600) -- hub-local origin

type Scheme = { [string]: Color3 }
local YEL = Color3.fromRGB(214, 168, 48)
local SCHEMES: { [string]: Scheme } = {
	Charcoal = {
		Body = Color3.fromRGB(74, 78, 85),
		Trim = Color3.fromRGB(44, 46, 51),
		Hardware = Color3.fromRGB(150, 154, 160),
		Accent = YEL,
		Rubber = Color3.fromRGB(30, 31, 34),
	},
	Olive = {
		Body = Color3.fromRGB(86, 92, 70),
		Trim = Color3.fromRGB(52, 56, 44),
		Hardware = Color3.fromRGB(150, 154, 160),
		Accent = YEL,
		Rubber = Color3.fromRGB(30, 31, 34),
	},
	Hazard = {
		Body = YEL,
		Trim = Color3.fromRGB(44, 46, 51),
		Hardware = Color3.fromRGB(150, 154, 160),
		Accent = Color3.fromRGB(44, 46, 51),
		Rubber = Color3.fromRGB(30, 31, 34),
	},
	Slate = {
		Body = Color3.fromRGB(104, 110, 118),
		Trim = Color3.fromRGB(58, 61, 67),
		Hardware = Color3.fromRGB(160, 164, 170),
		Accent = YEL,
		Rubber = Color3.fromRGB(30, 31, 34),
	},
}
local MATERIAL: { [string]: Enum.Material } = {
	Body = Enum.Material.SmoothPlastic,
	Trim = Enum.Material.SmoothPlastic,
	Hardware = Enum.Material.Metal,
	Accent = Enum.Material.SmoothPlastic,
	Rubber = Enum.Material.Plastic,
}
local COLLIDE: { [string]: boolean } = { Body = true, Trim = true }

local M = {}

function M.makeKit(): Folder
	local kit = ServerStorage:WaitForChild("V5Kit") :: Folder
	local old = kit:FindFirstChild("Props")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Props"
	local raw = InsertService:LoadAsset(ASSET)
	local groups: { [string]: Model } = {}
	for _, p in raw:GetDescendants() do
		if p:IsA("MeshPart") then
			local prop, role = string.match(p.Name, "^(.-)_(%a+)$")
			if prop and role then
				local m = groups[prop]
				if not m then
					m = Instance.new("Model")
					m.Name = prop
					m.Parent = folder
					groups[prop] = m
				end
				p.Name = role
				p.Anchored = true
				p.CanCollide = COLLIDE[role] == true
				p.CanTouch = false
				p.CanQuery = COLLIDE[role] == true
				p.Material = MATERIAL[role] or Enum.Material.SmoothPlastic
				p:SetAttribute("Role", role)
				p.Parent = m
			end
		end
	end
	for _, m in groups do
		local cf, size = m:GetBoundingBox()
		local base = CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z)
		m.WorldPivot = base
		m:PivotTo(CFrame.new())
	end
	raw:Destroy()
	folder.Parent = kit
	return folder
end

function M.paint(m: Model, scheme: string)
	local s = SCHEMES[scheme]
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			local role = p:GetAttribute("Role") :: string?
			if role and s[role] then
				p.Color = s[role]
			end
		end
	end
	m:SetAttribute("Scheme", scheme)
end

function M.place(parent: Instance, name: string, scheme: string, at: CFrame): Model
	local props = ServerStorage:WaitForChild("V5Kit"):WaitForChild("Props")
	local src = props:FindFirstChild(name)
	assert(src and src:IsA("Model"), "no prop " .. name)
	local m = src:Clone()
	M.paint(m, scheme)
	m:PivotTo(O * at)
	m.Parent = parent
	return m
end

-- yaw in degrees about Y; y lifts a prop onto another (pallet deck 0.52, crate top 3.04, low crate 1.64)
function M.at(x: number, z: number, yaw: number, y: number?): CFrame
	return CFrame.new(x, y or 0, z) * CFrame.Angles(0, math.rad(yaw), 0)
end

-- First hub layout (2026-11-21). Props are pushed toward the hub centre until clear of the rock afterwards.
function M.hubClusters(props: Instance)
	local at = M.at
	local function cluster(name: string, list: { { any } })
		local m = Instance.new("Model")
		m.Name = name
		m.Parent = props
		for _, e in list do
			M.place(m, e[1], e[2], at(e[3], e[4], e[5], e[6])).Name = e[1]
		end
	end
	local d = 1.1 * 1.414
	cluster("Cluster_SW", {
		{ "Pallet", "Charcoal", -29.5, 29.5, -45 },
		{ "CargoBox", "Olive", -29.5, 29.5, -45, 0.52 },
		{ "AmmoCan", "Olive", -29.5, 29.5, -30, 0.52 + 3.68 },
		{ "WeaponCrate", "Olive", -23.5, 33.5, -45 },
		{ "Drum", "Charcoal", -34.2, 24.8, 0 },
		{ "Drum", "Hazard", -31.6, 22.6, 40 },
	})
	cluster("Cluster_SE", {
		{ "CableSpool", "Charcoal", 28.5, 28.5, 45 },
		{ "Drum", "Charcoal", 33.4, 24.0, 10 },
		{ "FlatCase", "Charcoal", 23.8, 34.2, 45 },
		{ "AmmoCan", "Charcoal", 23.2, 34.6, 60, 1.3 },
		{ "AmmoCan", "Olive", 24.6, 33.4, 35, 1.3 },
	})
	cluster("Cluster_NE", {
		{ "PowerBox", "Slate", 32.1, -28.5, 135 },
		{ "ToolChest", "Charcoal", 28.3, -32.1, 135 },
		{ "WeaponCrate", "Charcoal", 34.8, -22.8, 120 },
		{ "FlatCase", "Olive", 34.8, -22.8, 125, 2.98 },
	})
	cluster("Cluster_NW", {
		{ "Pallet", "Charcoal", -29.5, -29.5, -135 },
		{ "Drum", "Charcoal", -29.5, -29.5 - d, 0, 0.52 },
		{ "Drum", "Hazard", -29.5 + d, -29.5, 15, 0.52 },
		{ "Drum", "Charcoal", -29.5 - d, -29.5, 30, 0.52 },
		{ "Drum", "Charcoal", -29.5, -29.5 + d, 45, 0.52 },
		{ "CargoBox", "Charcoal", -23.6, -34.4, -135 },
		{ "AmmoCan", "Olive", -23.6, -34.4, -120, 3.68 },
	})
end

return M
