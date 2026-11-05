--!strict
-- Materials_V2.luau: the stylized bunker MaterialVariants (Lobby rebuild 2026-11-04). Safe to re-run.
-- Textures: tools/textures/make_lobby_textures_v2.py -> art-source/lobby/textures/Bunker_*.png, uploaded as Decals;
-- the ids below are the Image assets behind them. StudsPerTile must match TILE in that script.
-- BasePart.Color multiplies the ColorMap, so each part's Color sets the hue.
assert(game.PlaceId == 133387545285290, "not the Lobby")
local MaterialService = game:GetService("MaterialService")

local VARIANTS = {
	Bunker_Concrete = { Enum.Material.Concrete, 16, "104737392584669", "93691597282176", "95184551126688" },
	Bunker_Floor = { Enum.Material.Slate, 16, "73383285439881", "99655568297239", "99239709018479" },
	Bunker_Metal = { Enum.Material.Metal, 8, "108704579785681", "123918256871933", "132089430474107" },
	Bunker_Grate = { Enum.Material.DiamondPlate, 4, "119119110235077", "128288039114085", "132404926483451" },
}

for name, v in VARIANTS do
	local mv = MaterialService:FindFirstChild(name)
	if not (mv and mv:IsA("MaterialVariant")) then
		mv = Instance.new("MaterialVariant")
		mv.Name = name
		mv.Parent = MaterialService
	end
	assert(mv and mv:IsA("MaterialVariant"))
	mv.BaseMaterial = v[1]
	mv.StudsPerTile = v[2]
	mv.ColorMap = "rbxassetid://" .. v[3]
	mv.NormalMap = "rbxassetid://" .. v[4]
	mv.RoughnessMap = "rbxassetid://" .. v[5]
	mv.MaterialPattern = Enum.MaterialPattern.Regular
end
return "Bunker variants ready"
