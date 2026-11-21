--!nocheck
-- Lobby V5 polish, 2026-11-21 evening (vault/02 Art/Lobby V5 Plan.md, "Range v4, Locker v3, Duels banners").
-- ONE-TIME record of the small in-place edits; the big ones are BuildRangeV4.luau and BuildLockerV3.luau.

local K = require(game.ServerStorage.V5Kit.LobbyWay:Clone()).K
local V = Vector3.new
local O = CFrame.new(0, 0, -1600)

-- 1. DUELS: the four how-to screens on the bulkhead (owner: "I don't really know what's going on with these screens")
--    become hanging team banners: a steel rod on two arms, a cloth in team gold / blue with two stripes and the duels
--    emblem, a weight bar at the hem.
local D = workspace.LobbyV5.Shell.Duels.Decor
for _, c in D:GetChildren() do
	if string.find(c.Name, "Board_") or c.Name == "Banner" then
		c:Destroy()
	end
end
local steel = K.look("Metal 2022", Color3.fromRGB(78, 80, 86))
local TEAMS = {
	{ Color3.fromRGB(176, 120, 34), Color3.fromRGB(226, 170, 64) },
	{ Color3.fromRGB(30, 98, 128), Color3.fromRGB(64, 160, 196) },
}
for i, x in { -60, -44, 44, 60 } do
	local team = TEAMS[(i % 2) + 1]
	local m = K.model(D, "Banner")
	local zW = -60.3 -- the bulkhead's face
	for _, sx in { -2.6, 2.6 } do
		K.lpart(O, m, "Arm", V(x + sx - 0.15, 15.25, zW - 0.95), V(x + sx + 0.15, 15.55, zW), steel)
	end
	K.lpart(O, m, "Rod", V(x - 2.9, 15.25, zW - 1.25), V(x + 2.9, 15.55, zW - 0.95), steel)
	local cloth = K.lpart(
		O,
		m,
		"Cloth",
		V(x - 2.3, 6.0, zW - 1.15),
		V(x + 2.3, 15.25, zW - 1.05),
		K.look(nil, team[1], Enum.Material.Fabric)
	)
	K.lpart(O, m, "Weight", V(x - 2.45, 5.7, zW - 1.2), V(x + 2.45, 6.0, zW - 1.0), steel)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.LightInfluence = 1
	g.Parent = cloth
	for _, y in { 0.06, 0.89 } do
		local band = Instance.new("Frame")
		band.BorderSizePixel = 0
		band.BackgroundColor3 = team[2]
		band.Position = UDim2.fromScale(0, y)
		band.Size = UDim2.fromScale(1, 0.05)
		band.Parent = g
	end
	local ic = Instance.new("ImageLabel")
	ic.BackgroundTransparency = 1
	ic.Image = K.AREA.duels.icon
	ic.ImageColor3 = Color3.fromRGB(240, 236, 226)
	ic.AnchorPoint = Vector2.new(0.5, 0.5)
	ic.Position = UDim2.fromScale(0.5, 0.42)
	ic.Size = UDim2.fromScale(0.7, 0.7)
	ic.SizeConstraint = Enum.SizeConstraint.RelativeXX
	ic.Parent = g
end

-- 2. LOCKER: the north wall belt is split where the Armorer's gun rack covers it (x 105.9 .. 120.1), so the two never
--    share a face.
