--!strict
-- Execute in gameplay Studio Edit after the approved v01 maps are uploaded.
-- Clone installed stock meshes; never re-import/rebuild the proven rig.
assert(
	game:GetService("RunService"):IsStudio() and game.PlaceId == 133387545285290,
	"Gameplay Studio only"
)
local RS = game:GetService("ReplicatedStorage")
local function folder(parent: Instance, name: string): Instance
	local old = parent:FindFirstChild(name)
	if old then
		return old
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end
local skins = folder(RS, "WeaponSkins")
local prism = folder(skins, "Prism")
local old = prism:FindFirstChild("Vandal")
assert(not old, "Prism Vandal already exists; version the asset before reinstalling")
local model = RS.Weapons.Vandal:Clone()
local maps = {
	ColorMap = "rbxassetid://77624555416238",
	NormalMap = "rbxassetid://107157365554423",
	RoughnessMap = "rbxassetid://114381284203909",
	MetalnessMap = "rbxassetid://106721959126044",
}
local pbr, neon = 0, 0
for _, part in model:GetChildren() do
	if not part:IsA("MeshPart") then
		continue
	end
	-- Brass/ammunition and the rear aperture remain exactly stock.
	if part.Name == "Mag_Brass" or part.Name == "RearSight" then
		continue
	end
	if part.Material == Enum.Material.Neon then
		part.Color = Color3.fromHex("FF79B8")
		neon += 1
	else
		for _, child in part:GetChildren() do
			if child:IsA("SurfaceAppearance") then
				child:Destroy()
			end
		end
		local sa = Instance.new("SurfaceAppearance")
		sa.Name = "Prism_v01"
		sa.ColorMap = maps.ColorMap
		sa.NormalMap = maps.NormalMap
		sa.RoughnessMap = maps.RoughnessMap
		sa.MetalnessMap = maps.MetalnessMap
		part.TextureID = ""
		part.Color = Color3.new(1, 1, 1)
		part.Reflectance = 0
		sa.Parent = part
		pbr += 1
	end
end
model:SetAttribute("SkinLine", "Prism")
model:SetAttribute("SkinVersion", "v01")
model:SetAttribute("SkinReady", true)
model.Parent = prism
game:GetService("ChangeHistoryService"):SetWaypoint("Install isolated Prism Vandal v01")
return { path = model:GetFullName(), pbrParts = pbr, neonParts = neon }
