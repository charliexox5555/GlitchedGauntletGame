--!strict
-- Lobby MaterialVariants (phase 1 step 5): creates or updates the six Lobby_* variants
-- in MaterialService that the Lobby Kit references by name. Stand-alone: run it as-is
-- through the Studio MCP (execute_luau) or the command bar; it is safe to re-run.
--
-- Textures: tools/textures/make_lobby_textures.py -> art-source/lobby/textures/*.png,
-- uploaded as Decals (tools/opencloud/upload_asset.py); the ids below are the Image
-- assets behind those Decals (InsertService:LoadAsset(decalId) -> Decal.Texture).
-- StudsPerTile must match TILE in make_lobby_textures.py.
--
-- BasePart.Color multiplies the ColorMap (checked in Studio), so the colour maps are
-- near-neutral light greys and each part's Color (the style-sheet colour) sets the hue.
-- No base-material overrides are set on MaterialService.

assert(game.PlaceId == 133387545285290, "not the Lobby")

local MaterialService = game:GetService("MaterialService")

type Spec = {
	base: Enum.Material,
	studs: number,
	color: string,
	normal: string,
	roughness: string,
}

local function img(id: number): string
	return "rbxassetid://" .. tostring(id)
end

local VARIANTS: { [string]: Spec } = {
	-- 4 x 2 formwork panels (3.2 x 6.4) per tile.
	Lobby_ConcreteBoard = {
		base = Enum.Material.Concrete,
		studs = 12.8,
		color = img(73909008132012),
		normal = img(91252089022464),
		roughness = img(123640351027597),
	},
	Lobby_ConcretePolished = {
		base = Enum.Material.Concrete,
		studs = 16,
		color = img(121027185599602),
		normal = img(99649055460266),
		roughness = img(90439066251243),
	},
	-- 4 x 4 saw-cut cells of 5 studs per tile.
	Lobby_ConcreteDark = {
		base = Enum.Material.Concrete,
		studs = 20,
		color = img(124812022087643),
		normal = img(74000748525744),
		roughness = img(102040484366574),
	},
	Lobby_Terrazzo = {
		base = Enum.Material.Concrete,
		studs = 12,
		color = img(134489940518013),
		normal = img(115627889317006),
		roughness = img(91995919876503),
	},
	-- Pass 2 maps: split-granite chips in the normal map, salt-and-pepper crystals.
	Lobby_Rock = {
		base = Enum.Material.Slate,
		studs = 16,
		color = img(112743048244039),
		normal = img(99866886731542),
		roughness = img(82013202403349),
	},
	-- Grain along U, boards 1 stud wide in V.
	Lobby_Oak = {
		base = Enum.Material.Wood,
		studs = 8,
		color = img(90752891594772),
		normal = img(71395833493369),
		roughness = img(117572282035099),
	},
}

local made = {}
for name, spec in VARIANTS do
	local v = MaterialService:FindFirstChild(name)
	if v and not v:IsA("MaterialVariant") then
		v:Destroy()
		v = nil
	end
	local variant: MaterialVariant = (v :: MaterialVariant?) or Instance.new("MaterialVariant")
	variant.Name = name
	variant.BaseMaterial = spec.base
	variant.StudsPerTile = spec.studs
	variant.MaterialPattern = Enum.MaterialPattern.Regular
	variant.ColorMap = spec.color
	variant.NormalMap = spec.normal
	variant.RoughnessMap = spec.roughness
	variant.MetalnessMap = ""
	variant.Parent = MaterialService
	table.insert(made, string.format("%s (%s, %g studs)", name, spec.base.Name, spec.studs))
end
table.sort(made)
local line = "MaterialVariants: " .. table.concat(made, ", ")
print(line)
return line
