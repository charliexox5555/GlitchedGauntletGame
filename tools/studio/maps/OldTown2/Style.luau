--!strict
-- OldTown2 style pass (vault/01 Design/Maps/OldTown2.md -> Palette): runs after Greybox and Art in one bundle
--   python tools/studio/maps/bundle.py OldTown2 Greybox Art Style Lighting -o oldtown2.luau
-- and puts the whole map on the single palette table: the OT2_* MaterialVariants by Roblox material (procedural
-- textures, tools/textures/make_oldtown2_textures.py; Image ids from the Decal uploads), Old Town's colours remapped
-- to the concept palette, and no Roblox Metal anywhere (it mirrors the sky; Map Quality Standard section 3).

local MaterialService = game:GetService("MaterialService")

-- name: BaseMaterial, StudsPerTile, ColorMap, NormalMap
-- stylua: ignore start
local VARIANTS: { [string]: { any } } = {
	OT2_Stucco = { "Plaster", 12, "73274454631456", "83978894951341" }, -- r1: plain render (no worn patches)
	OT2_Ashlar = { "Limestone", 8, "91135123666290", "114086842361323" },
	OT2_Paving = { "Limestone", 8, "130608433991662", "79330650895421" },
	OT2_Terracotta = { "ClayRoofTiles", 4, "72153638601772", "83433689734180" },
	OT2_Cobble = { "Cobblestone", 8, "75509828854751", "119871129625203" },
	OT2_Plank = { "WoodPlanks", 6, "103283221566373", "79445504335406" },
}
-- Old Town colour -> OldTown2 palette colour (hex, upper case, no #)
local REMAP: { [string]: string } = {
	E9DCC0 = "E8D6B0", E0BE8A = "DDB57C", DDAA8F = "D9A08A", -- stucco tones: cream, ochre, rose
	D3C3A0 = "D8C6A0", B9A584 = "BFA884", D6C3A0 = "D8C6A0", CDB894 = "C9B48E", -- stone, plinth, arcade, low walls
	AD5230 = "A86A4E", B4532F = "A86A4E", -- terracotta, r1: muted (the tiles read saturated orange)
	["9E5A40"] = "A65A3E", -- tower brick
	["2B2A28"] = "3A3633", -- ironwork
	["2F6BB3"] = "4A6A96", ["4E8A3E"] = "62845A", -- r1: side accents a step calmer (shutters read loud)
	D8C9AA = "D9C7A4", E2D4B6 = "D9C7A4", -- paving, slabs
	["9C8D7A"] = "9C8E7C", -- cobbles
}
-- stylua: ignore end

for name, v in VARIANTS do
	local found = MaterialService:FindFirstChild(name)
	local mv: MaterialVariant
	if found and found:IsA("MaterialVariant") then
		mv = found
	else
		mv = Instance.new("MaterialVariant")
		mv.Name = name
		mv.Parent = MaterialService
	end
	mv.BaseMaterial = (Enum.Material :: any)[v[1]]
	mv.StudsPerTile = v[2]
	mv.ColorMap = "rbxassetid://" .. v[3]
	mv.NormalMap = "rbxassetid://" .. v[4]
	mv.RoughnessMap = ""
	mv.MaterialPattern = Enum.MaterialPattern.Regular
end

local FLOOR_NAMES: { [string]: boolean } = {}
for _, n in
	{
		"PlazaFloor_A",
		"PlazaFloor_B",
		"ForecourtFloor_A",
		"ForecourtFloor_B",
		"CloisterFloor_A",
		"CloisterFloor_B",
	}
do
	FLOOR_NAMES[n] = true
end

local map = root()
local styled, metal, recoloured = 0, 0, 0
for _, d in map:GetDescendants() do
	if not d:IsA("BasePart") or d.Material == Enum.Material.Neon or d.Transparency >= 1 then
		continue
	end
	local hex = string.upper(d.Color:ToHex())
	local to = REMAP[hex]
	if to then
		d.Color = Color3.fromHex(to)
		recoloured += 1
	end
	local m = d.Material
	if m == Enum.Material.Fabric or m == Enum.Material.Grass or m == Enum.Material.LeafyGrass then
		-- r2: Roblox's fabric and grass textures read fuzzy / photo-real next to the modelled stone
		d.Material = Enum.Material.SmoothPlastic
		continue
	end
	if m == Enum.Material.Metal then
		d.Material = Enum.Material.SmoothPlastic
		metal += 1
	elseif m == Enum.Material.Plaster then
		d.MaterialVariant = "OT2_Stucco"
	elseif m == Enum.Material.Limestone then
		local flat = FLOOR_NAMES[d.Name]
			or d:GetAttribute("Kind") == "floor"
			or (d.Size.Y < 0.5 and d.Size.X > 6 and d.Size.Z > 6)
		d.MaterialVariant = if flat then "OT2_Paving" else "OT2_Ashlar"
	elseif m == Enum.Material.ClayRoofTiles then
		d.MaterialVariant = "OT2_Terracotta"
	elseif m == Enum.Material.Cobblestone then
		d.MaterialVariant = "OT2_Cobble"
	elseif m == Enum.Material.WoodPlanks then
		d.MaterialVariant = "OT2_Plank"
	elseif m == Enum.Material.Wood then
		-- r2: Roblox's Wood grain read loud (stalls, carts, shutters); our calm plank variant instead
		d.Material = Enum.Material.WoodPlanks
		d.MaterialVariant = "OT2_Plank"
	else
		continue
	end
	styled += 1
end

-- r2: the cloister front wall each spawn faces gets two lit wall lanterns and two side banners (it read as a
-- blank wall), facing the spawn.
local dressed = 0
local function faceYaw(n: Vector3): number
	return math.deg(math.atan2(-n.Z, n.X))
end
local origin = W(CFrame.identity)
for _, part in map:GetDescendants() do
	if
		part:IsA("BasePart")
		and string.sub(part.Name, 1, 13) == "CloisterFront"
		and part.Size.X > 12
	then
		local rel = origin:PointToObjectSpace(part.Position)
		local sz = if rel.Z < 0 then -1 else 1
		local n = Vector3.new(0, 0, sz)
		local faceZ = rel.Z + sz * (part.Size.Z / 2 + 0.04)
		local yaw = faceYaw(n)
		local floorY = rel.Y - part.Size.Y / 2
		for _, dx in { -2.75, 2.75 } do -- between the three windows
			if
				put(
					section("Art", "SpawnDress"),
					"WallLantern",
					at(rel.X + dx, floorY + 7.0, faceZ, yaw)
				)
			then
				dressed += 1
			end
		end
		for _, dx in { -10.2, 10.2 } do
			if
				put(
					section("Art", "SpawnDress"),
					"Banner",
					at(rel.X + dx, floorY + 10.9, faceZ, yaw)
				)
			then
				dressed += 1
			end
		end
	end
end

report(string.format("OldTown2 spawn dress: %d pieces", dressed))
report(
	string.format(
		"OldTown2 style: %d parts textured, %d recoloured, %d off Metal",
		styled,
		recoloured,
		metal
	)
)
