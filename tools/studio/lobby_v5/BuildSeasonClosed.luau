--!strict
-- Shop V2: the Season Pass wing is closed for now (owner 2026-11-21: "should just be closed and say under
-- construction or something cool so people feel anticipated"). A sealed blast door in the passage, a
-- construction notice board in front, a spinning amber beacon, building materials (V5Kit props).
-- Run in the Lobby place (Edit) through the Studio MCP. Re-runnable: clears Passage_SeasonPass.Closed.

local SS = game:GetService("ServerStorage")
local Kit = SS:WaitForChild("V5Kit")
local W = require(Kit:WaitForChild("LobbyWay") :: ModuleScript) :: any
local P = require(Kit:WaitForChild("LobbyProps") :: ModuleScript) :: any

local Shop = workspace:WaitForChild("LobbyV5"):WaitForChild("Shell"):WaitForChild("Shop")
local passage = Shop:WaitForChild("Passage_SeasonPass")
local old = passage:FindFirstChild("Closed")
if old then
	old:Destroy()
end
local root = Instance.new("Model")
root.Name = "Closed"
root.Parent = passage

local HAZARD = "rbxassetid://75158634706115"
local GUN = Color3.fromRGB(78, 80, 86)
local DARK = Color3.fromRGB(34, 35, 39)
local STEEL = Color3.fromRGB(120, 124, 130)
local AMBER = Color3.fromRGB(255, 166, 40)
local PURPLE = Color3.fromRGB(150, 96, 230)

-- passage frame: x across (right as seen from the junction), y up, z toward the viewer; door plane 1.6 in
local J1, J2 = Vector3.new(-134.4, 0, -1612.2), Vector3.new(-125.2, 0, -1621.4)
local d = Vector3.new(-1, 0, -1).Unit
local C = (J1 + J2) / 2 + d * 1.6
local PF = CFrame.lookAt(C, C + d)

local function part(
	name: string,
	x0: number,
	x1: number,
	y0: number,
	y1: number,
	z0: number,
	z1: number,
	col: Color3,
	mat: Enum.Material?,
	parent: Instance?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanTouch = false
	p.Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0)
	p.CFrame = PF * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	p.Color = col
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or root
	return p
end

local function hazard(p: BasePart, face: Enum.NormalId, studs: number)
	local t = Instance.new("Texture")
	t.Texture = HAZARD
	t.Face = face
	t.StudsPerTileU = studs
	t.StudsPerTileV = studs
	t.Parent = p
end

-- frame: jambs and head (sit over the wainscot), dark core behind the leaves
local door = Instance.new("Model")
door.Name = "BlastDoor"
door.Parent = root
for _, s in { -1, 1 } do
	part(
		"Jamb",
		s > 0 and 5.2 or -6.0,
		s > 0 and 6.0 or -5.2,
		0,
		14.0,
		-0.55,
		0.55,
		GUN,
		Enum.Material.Metal,
		door
	)
	part(
		"JambNose",
		s > 0 and 5.05 or -5.25,
		s > 0 and 5.25 or -5.05,
		0,
		12.6,
		0.35,
		0.5,
		DARK,
		nil,
		door
	)
end
part("Head", -6.0, 6.0, 12.6, 14.0, -0.55, 0.55, GUN, Enum.Material.Metal, door)
part("Core", -5.2, 5.2, 0, 12.6, -0.5, -0.2, DARK, nil, door)
-- two leaves, each three plates split by shadow gaps, a hazard band set into a groove
for _, s in { -1, 1 } do
	local a, b = s > 0 and 0.06 or -5.2, s > 0 and 5.2 or -0.06
	part("Leaf", a, b, 0, 12.6, -0.25, 0.2, GUN, Enum.Material.Metal, door)
	for _, r in { { 0.15, 4.9 }, { 6.6, 9.4 }, { 9.55, 12.45 } } do
		part("Plate", a + 0.15, b - 0.15, r[1], r[2], 0.2, 0.32, STEEL, Enum.Material.Metal, door)
	end
	local band =
		part("Band", a + 0.15, b - 0.15, 5.05, 6.45, 0.14, 0.26, Color3.new(1, 1, 1), nil, door)
	hazard(band, Enum.NormalId.Back, 2.8)
end
-- lock housing straddling the seam, a red status lamp
part("Lock", -0.55, 0.55, 6.6, 8.6, 0.3, 0.6, DARK, Enum.Material.Metal, door)
local lamp = part(
	"LockLamp",
	-0.22,
	0.22,
	7.95,
	8.35,
	0.58,
	0.66,
	Color3.fromRGB(255, 70, 60),
	Enum.Material.Neon,
	door
)
local lampLight = Instance.new("PointLight")
lampLight.Color = Color3.fromRGB(255, 80, 60)
lampLight.Range = 5
lampLight.Brightness = 0.8
lampLight.Parent = lamp
-- hazard sill on the floor in front
hazard(
	part("Sill", -5.9, 5.9, 0, 0.05, 0.6, 1.5, Color3.new(1, 1, 1), nil, root),
	Enum.NormalId.Top,
	2.8
)

-- amber beacon on the head: bracket, housing, a lens that turns (LobbySpin) with its own spot
local beacon = Instance.new("Model")
beacon.Name = "Beacon"
beacon.Parent = root
part("Bracket", -0.5, 0.5, 12.15, 12.6, 0.55, 1.35, DARK, Enum.Material.Metal, beacon)
part("Base", -0.42, 0.42, 11.75, 12.15, 0.55, 1.39, GUN, Enum.Material.Metal, beacon)
local rot = Instance.new("Model")
rot.Name = "Rotor"
rot.Parent = beacon
local lens = part("Lens", -0.32, 0.32, 11.15, 11.75, 0.65, 1.29, AMBER, Enum.Material.Neon, rot)
lens.Transparency = 0.1
local spot = Instance.new("SpotLight")
spot.Face = Enum.NormalId.Front
spot.Angle = 50
spot.Range = 18
spot.Brightness = 3
spot.Color = AMBER
spot.Parent = lens
rot.PrimaryPart = lens
rot:SetAttribute("SpinSpeed", 120)
game:GetService("CollectionService"):AddTag(rot, "LobbySpin")

-- construction notice board in front of the door: two posts on base plates, a framed screen
local board = Instance.new("Model")
board.Name = "NoticeBoard"
board.Parent = root
local BZ = 3.4
for _, x in { -3.5, 3.5 } do
	part(
		"Foot",
		x - 0.55,
		x + 0.55,
		0,
		0.18,
		BZ - 0.55,
		BZ + 0.55,
		DARK,
		Enum.Material.Metal,
		board
	)
	part("Post", x - 0.2, x + 0.2, 0.18, 7.0, BZ - 0.2, BZ + 0.2, GUN, Enum.Material.Metal, board)
end
part("Frame", -3.3, 3.3, 2.6, 6.9, BZ - 0.15, BZ + 0.15, DARK, Enum.Material.Metal, board)
local face =
	part("Screen", -3.1, 3.1, 2.8, 6.7, BZ + 0.15, BZ + 0.2, Color3.fromRGB(22, 23, 27), nil, board)
local g = Instance.new("SurfaceGui")
g.Face = Enum.NormalId.Back
g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
g.PixelsPerStud = 60
g.LightInfluence = 0
g.Brightness = 1.4
g.Parent = face
local icon = nil
local hang = Shop:FindFirstChild("Fit") and Shop.Fit:FindFirstChild("Sign_SEASONPASS")
if hang then
	for _, dsc in hang:GetDescendants() do
		if dsc:IsA("ImageLabel") and dsc.Image ~= "" then
			icon = dsc.Image
			break
		end
	end
	for _, dsc in hang:GetDescendants() do
		if dsc:IsA("TextLabel") and string.find(dsc.Text, "REWARDS") then
			dsc.Text = "COMING SOON"
		end
	end
end
W.board(
	g,
	{
		title = "COMING SOON",
		sub = "SEASON PASS",
		foot = "AREA UNDER CONSTRUCTION",
		col = PURPLE,
		icon = icon,
		px = 3.9 * 60,
	}
)

-- building materials left by the crew
local O = CFrame.new(0, 0, -1600)
local mats = Instance.new("Model")
mats.Name = "Materials"
mats.Parent = root
local function put(name: string, scheme: string, x: number, z: number, yaw: number, y: number?)
	local m = P.place(
		mats,
		name,
		scheme,
		O:Inverse() * PF * CFrame.new(x, y or 0, z) * CFrame.Angles(0, math.rad(yaw), 0)
	)
	m.Name = name
end
put("Drum", "Hazard", -4.3, 2.0, 0)
put("Drum", "Charcoal", -4.6, 4.5, 20)
put("CableSpool", "Charcoal", 4.1, 1.9, 90)
put("AmmoCan", "Olive", 4.4, 4.6, -15)

return root
