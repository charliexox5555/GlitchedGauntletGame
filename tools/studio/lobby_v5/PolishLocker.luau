--!nocheck
-- Lobby V5 LOCKER polish (vault/02 Art/Lobby V5 Plan.md, "Entrances and the shop"). ONE-TIME placement record run
-- through the Studio MCP after BuildLocker.luau and BuildGateways.luau. Owner 2026-11-20: "it's just kind of boring
-- and we should add on to it, but it does look pretty good". Adds, without moving what is there: the room's accent
-- (cyan, the HUD's Locker colour) on the floor lines; a painted floor emblem at the entry; a belt line and painted
-- bay labels over the lockers; steel I-beams and two octagonal air ducts under the ceiling; kit bags, helmets and
-- boxes on the benches and in the corners; and the gun wall's lightbox replaced by the area badge.

local K = require(game:GetService("ServerStorage").V5Kit.LobbyKit:Clone())
local V = Vector3.new
local L = K.L
local locker = workspace.LobbyV5.Shell.Locker
local old = locker:FindFirstChild("Polish")
if old then
	old:Destroy()
end
local pol = K.model(locker, "Polish")
local CYAN = K.AREA.locker.col
local cyanPaint = K.paint(Color3.fromRGB(58, 174, 188))
local RX0, RX1, RZ, RH = 55, 103, 22, 18

-- 1. accent: the yellow floor lines become the room's cyan (the workbench's hazard sides stay hazard yellow)
for _, p in locker:GetDescendants() do
	if
		p:IsA("BasePart")
		and (
			p.Name == "Line_N"
			or p.Name == "Line_S"
			or (p.Name == "Line" and p.Parent.Name == "FloorBox")
		)
	then
		p.Color = cyanPaint.col
	end
end

-- 2. painted floor emblem at the entry: the Locker icon in a cut-corner square outline
local em = K.model(pol, "FloorEmblem")
local EX = 62.5
local face = K.part(
	em,
	"Paint",
	V(4.6, 0.02, 4.6),
	CFrame.lookAt(K.O + V(EX, 0.03, 0), K.O + V(EX + 1, 0.03, 0)),
	K.paint(Color3.new(0, 0, 0))
)
face.Transparency = 1
K.ghost(face)
local g = Instance.new("SurfaceGui")
g.Face = Enum.NormalId.Top
g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
g.PixelsPerStud = 50
g.LightInfluence = 1
g.Parent = face
local img = Instance.new("ImageLabel")
img.BackgroundTransparency = 1
img.Size = UDim2.fromScale(1, 1)
img.Image = K.AREA.locker.icon
img.ImageColor3 = cyanPaint.col
img.ImageTransparency = 0.15
img.Parent = g
local S, C, T = 3.4, 1.0, 0.3 -- outline half size, corner cut, bar width
for _, b in
	{
		{ V(EX - S + C, 0, -S), V(EX + S - C, 0, -S + T) },
		{ V(EX - S + C, 0, S - T), V(EX + S - C, 0, S) },
		{ V(EX - S, 0, -S + C), V(EX - S + T, 0, S - C) },
		{ V(EX + S - T, 0, -S + C), V(EX + S, 0, S - C) },
	}
do
	K.box(em, "Bar", b[1], b[2] + V(0, 0.04, 0), cyanPaint)
end
for _, sx in { -1, 1 } do
	for _, sz in { -1, 1 } do
		local a = V(EX + sx * (S - C), 0.02, sz * S)
		local b = V(EX + sx * S, 0.02, sz * (S - C))
		local d = (b - a)
		local n = V(-d.Z, 0, d.X).Unit
		if n:Dot(V(EX, 0, 0) - (a + b) / 2) < 0 then
			n = -n
		end
		K.part(
			em,
			"Bar",
			V(d.Magnitude + 0.25, 0.04, T),
			CFrame.fromMatrix(K.O + (a + b) / 2 + n * T / 2, d.Unit, K.UP),
			cyanPaint
		)
	end
end

-- 3. belt line and painted bay labels on the north and south walls over the lockers
for _, w in { { "N", -RZ, 1, "BAY A  ·  01–18" }, { "S", RZ, -1, "BAY B  ·  19–36" } } do
	local z, inward, text = w[2], w[3], w[4]
	K.box(
		pol,
		"Belt_" .. w[1],
		V(RX0 + 1.5, 9.6, z),
		V(RX1 - 3.5, 9.85, z + inward * 0.06),
		cyanPaint
	)
	local lab = K.part(
		pol,
		"Label_" .. w[1],
		V(22, 3, 0.02),
		CFrame.lookAt(K.O + V(79, 12, z + inward * 0.02), K.O + V(79, 12, z + inward)),
		K.paint(Color3.new(0, 0, 0))
	)
	lab.Transparency = 1
	K.ghost(lab)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.LightInfluence = 1
	sg.Parent = lab
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.FontFace = K.RUBIK_H
	t.TextSize = 64
	t.TextColor3 = Color3.fromRGB(64, 64, 66)
	t.TextTransparency = 0.1
	t.Text = text
	t.Parent = sg
end

-- 4. ceiling: three steel I-beams across the room, two octagonal air ducts along it
local beams = K.model(pol, "Beams")
for _, x in { 60, 79, 98 } do
	local b = K.model(beams, "IBeam")
	K.box(b, "Top", V(x - 0.45, RH - 0.15, -RZ + 3.4), V(x + 0.45, RH, RZ - 3.4), L.dark)
	K.box(b, "Web", V(x - 0.14, RH - 0.85, -RZ + 3.4), V(x + 0.14, RH - 0.15, RZ - 3.4), L.dark)
	K.box(b, "Bottom", V(x - 0.45, RH - 1.0, -RZ + 3.4), V(x + 0.45, RH - 0.85, RZ - 3.4), L.dark)
end
local ducts = K.model(pol, "Ducts")
local DY, DD = RH - 1.0 - 0.75, 1.5 -- centre y (the duct's top touches the beams' bottom flange), diameter
for _, z in { -13, 13 } do
	local d = K.model(ducts, "Duct")
	K.pipe(d, "Run", V(RX0 + 3, DY, z), V(RX1 - 3, DY, z), DD, L.steel)
	for _, x in { RX0 + 3.2, RX1 - 3.2 } do
		K.mesh(
			d,
			"WallFlange",
			"V5_Flange8",
			V(0.4, DD * 1.3, DD * 1.3),
			CFrame.fromMatrix(K.O + V(x, DY, z), Vector3.xAxis, K.UP),
			L.dark
		)
	end
	for _, x in { 60, 79, 98 } do
		K.mesh(
			d,
			"Clamp",
			"V5_Flange8",
			V(0.35, DD * 1.18, DD * 1.18),
			CFrame.fromMatrix(K.O + V(x, DY, z), Vector3.xAxis, K.UP),
			L.dark
		)
	end
	for _, x in { 69.5, 88.5 } do -- vents on the duct's underside
		K.box(
			d,
			"Vent",
			V(x - 1.2, DY - DD / 2 - 0.08, z - 0.45),
			V(x + 1.2, DY - DD / 2 + 0.25, z + 0.45),
			L.dark
		)
	end
end

-- 5. gear: kit bags and a helmet on the benches, box stacks in the corners by the door (the locker tops are sloped
-- crowns, nothing sits on them)
local gear = K.model(pol, "Gear")
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { locker.Lockers, locker.Room }
local function topAt(x, z)
	local hit = workspace:Raycast(K.O + V(x, 14, z), V(0, -16, 0), rp)
	return hit and (hit.Position.Y - K.O.Y) or 0
end
local olive = K.look(nil, Color3.fromRGB(78, 84, 66), Enum.Material.Fabric)
local function bag(x, z)
	local y = topAt(x, z)
	local m = K.model(gear, "KitBag")
	local d = 1.05
	K.pipe(m, "Body", V(x - 1.3, y + d / 2, z), V(x + 1.3, y + d / 2, z), d, olive)
	for _, s in { -0.6, 0.6 } do
		K.mesh(
			m,
			"Strap",
			"V5_Flange8",
			V(0.18, d * 1.06, d * 1.06),
			CFrame.fromMatrix(K.O + V(x + s, y + d / 2, z), Vector3.xAxis, K.UP),
			L.rubber
		)
	end
end
local function box(parent, x, z, w, h, d, lk, y)
	y = y or topAt(x, z)
	local m = K.model(parent, "Box")
	K.box(m, "Body", V(x - w / 2, y, z - d / 2), V(x + w / 2, y + h, z + d / 2), lk)
	K.box(
		m,
		"Lid",
		V(x - w / 2 - 0.05, y + h, z - d / 2 - 0.05),
		V(x + w / 2 + 0.05, y + h + 0.12, z + d / 2 + 0.05),
		L.dark
	)
	return y + h + 0.12
end
local function helmet(x, z, facing, y) -- facing: +1 = the visor looks +z
	y = y or topAt(x, z)
	local m = K.model(gear, "Helmet")
	local shell = K.look(nil, Color3.fromRGB(70, 76, 62), Enum.Material.SmoothPlastic)
	K.box(m, "Dome", V(x - 0.5, y + 0.1, z - 0.55), V(x + 0.5, y + 0.75, z + 0.55), shell)
	for _, sx in { -1, 1 } do
		K.tri(
			m,
			"Side",
			V(x + sx * 0.5, y + 0.1, z),
			K.UP,
			0.55,
			V(sx, 0, 0),
			0.22,
			Vector3.zAxis,
			1.1,
			shell
		)
	end
	K.box(m, "Brim", V(x - 0.62, y, z - 0.68), V(x + 0.62, y + 0.1, z + 0.68), shell)
	K.box(
		m,
		"Visor",
		V(x - 0.5, y + 0.3, z + facing * 0.55),
		V(x + 0.5, y + 0.55, z + facing * 0.6),
		K.paint(Color3.fromRGB(30, 34, 38))
	)
end
local boxLk = K.look("Metal 2022", Color3.fromRGB(62, 66, 58))
bag(70.5, -16.6) -- the benches run along x at z = +-16.6
helmet(85.5, -16.6, 1)
bag(92, 16.6)
local st = K.model(gear, "Stack_N")
local t1 = box(st, 57.2, -15.6, 2.0, 1.2, 1.5, boxLk, 0)
box(st, 57.3, -15.5, 1.5, 0.8, 1.2, K.paint(Color3.fromRGB(52, 54, 50)), t1)
local st2 = K.model(gear, "Stack_S")
helmet(57.2, 15.6, -1, box(st2, 57.2, 15.6, 2.0, 1.2, 1.5, boxLk, 0))

-- 6. softer key lights (white outfits blew out under the 2.3 ceiling spots in play), a little more warm fill
for _, l in locker.Room:GetDescendants() do
	if
		l:IsA("SpotLight")
		and l.Parent.Name == "Lens"
		and l.Parent.Parent.Name == "CeilingLight"
	then
		l.Brightness = 1.7
	elseif l:IsA("PointLight") and l.Parent.Name == "Fill" then
		l.Brightness = 1.0
	end
end

-- 7. the gun wall's lightbox becomes the area badge on the soffit face
local gw = locker.GunWall
local sign = gw:FindFirstChild("Sign")
if sign then
	sign:Destroy()
end
K.badge(K.frame(V(RX1 - 3, 16.2, 0), V(-1, 0, 0)), gw, {
	word = "LOCKER",
	sub = "LOADOUT  ·  SKINS",
	col = CYAN,
	icon = K.AREA.locker.icon,
	h = 3.0,
	stand = 0.1,
	glow = 0.4,
})

local n = 0
for _, d in pol:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
return ("locker polish: %d pieces"):format(n)
