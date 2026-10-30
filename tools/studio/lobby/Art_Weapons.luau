--!strict
-- Lobby art pass: the Weapons + Locker wing (phase 1 step 5). Dresses Greybox.Wing_Weapons with
-- the "Weapons" kit group (tools/blender/build_lobby_kit_weapons.py) and the real game guns
-- (KitGroup "GunDisplay", built by tools/studio/lobby/gun_display_bundle.py), and rebuilds
-- Workspace.Lobby.Art.Weapons:
--   Structure  armoury piers and ribs, drum head with the uplight cornice, lantern, floor ring
--   Chapels    8 gun chapels: shell, turntable, the display gun on rods, trophy wall with
--              real-size guns, sloped name plaque
--   Hero       two-step dais, the 7x Vandal on museum mounts (plinth, column, collar, cradle),
--              lectern
--   Corridor   the two steel squeeze frames
--   Locker     oak slat apse and cheeks, back-lit panel, brass pedestal, mannequin, terminals
--   Signs      kit sign frames and the text carriers (SurfaceGuis)
--   Lights     11 dynamic lights: the hero key (the one shadow caster) and rim, the locker
--              spot and one point light per chapel (all shadowless but the key)
-- The greybox stays the collision: parts the kit replaces are hidden (they keep CanCollide),
-- the rest get a finished look. Re-runnable: publishArt replaces the folder and hide/finish are
-- idempotent.
--
-- Fix pass (art review + performance audit, 2026-10-29):
--   * Hero Vandal raised to the plan's y 10-17 so it frames the Locker instead of covering it,
--     on slim brushed-steel museum mounts (column, plinth, collar, cradle) whose cradles meet the
--     gun's real underside (the minimum over the cradle's length: no clipping).
--   * Every display gun (hero, chapels, trophies) uses a flat "museum" finish instead of its
--     baked SurfaceAppearance: lighter, it reads under the neutral key, and the wing no longer
--     loads 19 PBR texture sets (0 SurfaceAppearances in Art.Weapons).
--   * Trophy walls hold 5 (rifle chapels, 3 + 2 staggered) or 4 (pistol bays, 2 x 2) guns of the
--     chapel's class, some in GOLD / ARCTIC / CRIMSON skin finishes, each with a name tab.
--   * Lights: hero key re-aimed at the receiver + a cool rim from behind; one shadowless point
--     light per chapel (gun + trophy wall) replaces the 4 fin fills; the locker spot is
--     on the figure; light satin mannequin on a brass ring against a toned-down light box.
--   * EXIT TO HUB moved up the drum face (y 26) so it clears the raised hero from the Locker.
--   * SurfaceGuis: PixelsPerStud <= 25 (40 on tabs under 2 square studs), MaxDistance by sightline.
--   * Ambience tags (Lobby_Turntable on the chapel guns, Lobby_Pulse on the hero accents) are
--     carried over from the previous build and re-applied here, so a rebuild keeps them.
--   * Run tools/studio/lobby/Weapons_KitFidelity.luau once after (re)installing the kit groups:
--     it puts the kit MeshParts (and so these clones) on CollisionFidelity Box.
-- Run: python tools/studio/lobby/bundle.py Art_Weapons -o art_weapons.luau

local W = grey("Wing_Weapons")
assert(W, "no Greybox.Wing_Weapons (run Wing_Weapons first)")

local CX = 136
local NEUTRAL = Color3.fromHex("F2F0EA")
local TEXT = Color3.fromHex("F4F4F2")
local DIM = Color3.fromRGB(170, 174, 182)
local UP = Vector3.yAxis
local DECK = 3.4 -- turntable deck top (greybox turntable top)
local DAIS_TOP = Color3.fromHex("8E8A83") -- hero dais treads (polished, a step darker than the floor)

-- A trophy: a game gun (Trophy_/Display_/Hero_ kit model, scaled to `len` studs), optionally
-- in a skin finish (SKINS). The wall lays them out top row first (3 + 2 deep, 2 + 2 shallow).
type Trophy = { gun: string, skin: string? }
type Bay = {
	b0: number,
	deep: boolean,
	gun: string,
	title: string,
	class: string,
	trophies: { Trophy },
}
local function T(gun: string, skin: string?): Trophy
	return { gun = gun, skin = skin }
end

-- Greybox Bay1..Bay8 in order (Wing_Weapons.luau BAYS). The pistol bays flank the entry.
local BAYS: { Bay } = {
	{
		b0 = 292.5,
		deep = false,
		gun = "Classic",
		title = "CLASSIC",
		class = "SIDEARM",
		trophies = { T("Ghost"), T("Shorty"), T("Classic", "GOLD"), T("Ghost", "ARCTIC") },
	},
	{
		b0 = 326.25,
		deep = true,
		gun = "Phantom",
		title = "PHANTOM",
		class = "ASSAULT RIFLE",
		trophies = {
			T("Vandal"),
			T("Phantom", "GOLD"),
			T("Bulldog"),
			T("Vandal", "ARCTIC"),
			T("Phantom", "CRIMSON"),
		},
	},
	{
		b0 = 0,
		deep = true,
		gun = "Guardian",
		title = "GUARDIAN",
		class = "MARKSMAN RIFLE",
		trophies = {
			T("Marshal"),
			T("Guardian", "GOLD"),
			T("Bulldog", "ARCTIC"),
			T("Guardian", "CRIMSON"),
			T("Marshal", "GOLD"),
		},
	},
	{
		b0 = 33.75,
		deep = true,
		gun = "Spectre",
		title = "SPECTRE",
		class = "SMG",
		trophies = {
			T("Stinger"),
			T("Spectre", "GOLD"),
			T("Stinger", "ARCTIC"),
			T("Spectre", "CRIMSON"),
			T("Stinger", "GOLD"),
		},
	},
	{
		b0 = 112.5,
		deep = true,
		gun = "Judge",
		title = "JUDGE",
		class = "AUTO SHOTGUN",
		trophies = {
			T("Bucky"),
			T("Judge", "GOLD"),
			T("Bucky", "ARCTIC"),
			T("Judge", "CRIMSON"),
			T("Bucky", "GOLD"),
		},
	},
	{
		b0 = 146.25,
		deep = true,
		gun = "Operator",
		title = "OPERATOR",
		class = "SNIPER RIFLE",
		trophies = {
			T("Outlaw"),
			T("Operator", "GOLD"),
			T("Marshal"),
			T("Outlaw", "ARCTIC"),
			T("Operator", "CRIMSON"),
		},
	},
	{
		b0 = 180,
		deep = true,
		gun = "Odin",
		title = "ODIN",
		class = "HEAVY MACHINE GUN",
		trophies = {
			T("Ares"),
			T("Odin", "GOLD"),
			T("Ares", "ARCTIC"),
			T("Odin", "CRIMSON"),
			T("Ares", "GOLD"),
		},
	},
	{
		b0 = 213.75,
		deep = false,
		gun = "Sheriff",
		title = "SHERIFF",
		class = "REVOLVER",
		trophies = {
			T("Knife"),
			T("Sheriff", "GOLD"),
			T("Sheriff", "ARCTIC"),
			T("Knife", "CRIMSON"),
		},
	},
}
local SPAN = 33.75
local PIERS = { 292.5, 326.25, 0, 33.75, 67.5, 112.5, 146.25, 180, 213.75, 247.5 }

local function at(r: number, b: number, y: number): Vector3
	local x, z = polar(r, b)
	return Vector3.new(CX + x, y, z)
end

local function dir(b: number): Vector3
	local x, z = polar(1, b)
	return Vector3.new(x, 0, z)
end

-- ------------------------------------------------------------------ greybox: hide / finish

local FINISH: { [string]: string } = {
	Floor = "Terrazzo",
	CorridorFloor = "Terrazzo",
	InlayRing = "ConcretePolished",
	CorridorRunner = "ConcreteHoned",
	LockerRunner = "ConcreteHoned",
	CarpetFront = "ConcreteHoned",
	CarpetRound = "ConcreteHoned",
	CorridorRoof = "ConcreteShade",
	Roof = "ConcreteShade",
	CorridorWallN = "ConcreteBoard",
	CorridorWallS = "ConcreteBoard",
	ShoulderN = "ConcreteBoard",
	ShoulderS = "ConcreteBoard",
	FrontWallN = "ConcreteBoard",
	FrontWallS = "ConcreteBoard",
	FrontLintel = "ConcreteBoard",
	LanternGlass = "Glass",
}
local KEEP: { [string]: boolean } = { EdgeLightN = true, EdgeLightS = true, CoveLight = true }
local HIDE_PREFIX = {
	"Pier_",
	"Rib_",
	"Fin_",
	"WallHead_",
	"EntryLintel_",
	"ApseLintel_",
	"Lantern_",
	"Frame",
	"Bay",
	"Hero",
	"ApseWall_",
	"Cheek",
	"BackPanel",
	"Pedestal",
	"Mannequin",
	"Terminal",
	"ArmourySign",
	"ExitSign",
	"LockerSign",
}

local unhandled = {}
for _, p in W:GetChildren() do
	if not p:IsA("BasePart") then
		continue
	end
	local n = p.Name
	local look = FINISH[n] or (string.match(n, "^Roof_%d+$") and "ConcreteShade") or nil
	if look then
		finish(p, look)
		if n == "LanternGlass" then
			p.Transparency = 0.55
			p.CastShadow = false
		end
		continue
	end
	if KEEP[n] then
		continue
	end
	local hidden = false
	for _, pre in HIDE_PREFIX do
		if string.sub(n, 1, #pre) == pre then
			hide(p)
			hidden = true
			break
		end
	end
	if not hidden then
		table.insert(unhandled, n)
	end
end
if #unhandled > 0 then
	table.insert(REPORT, "Weapons unhandled greybox: " .. table.concat(unhandled, ","))
end

-- ------------------------------------------------------------------ helpers

local root = artSection("Weapons")
local function folder(name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f
end
local Structure = folder("Structure")
local Chapels = folder("Chapels")
local Hero = folder("Hero")
local Corridor = folder("Corridor")
local Locker = folder("Locker")
local Signs = folder("Signs")
local Lights = folder("Lights")

local function atomic(m: Model): Model
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	return m
end

type TextLine = { text: string, cap: number, sub: boolean?, color: Color3?, rich: boolean? }

-- An invisible, non-colliding carrier part (w x h) at cf whose Front face (-Z) shows the lines:
-- GothamBlack titles, GothamBold sub lines, scaled to fit and never above the planned cap.
local function textPanel(
	parent: Instance,
	name: string,
	w: number,
	h: number,
	cf: CFrame,
	lines: { TextLine },
	maxDist: number?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(w, h, 0.05)
	p.CFrame = cf
	local maxFont, stack = 0, 0
	for _, l in lines do
		local font = l.cap / 0.72
		maxFont = math.max(maxFont, font)
		stack += font * 1.12
	end
	local k = math.min(1, h * 0.9 / stack)
	-- Texture budget (performance audit): <= 25 px/stud, 40 on tiny tabs (< 2 square studs).
	local pps = math.clamp(math.floor(95 / (maxFont * k)), 4, if w * h < 2 then 40 else 25)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.MaxDistance = maxDist or 60
	gui.ClipsDescendants = true
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui
	for i, l in lines do
		local font = l.cap / 0.72 * k
		local t = Instance.new("TextLabel")
		t.Name = "Line" .. i
		t.LayoutOrder = i
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0, math.ceil(font * pps * 1.12))
		t.Font = if l.sub then Enum.Font.GothamBold else Enum.Font.GothamBlack
		t.TextColor3 = l.color or (if l.sub then DIM else TEXT)
		t.Text = l.text
		t.RichText = l.rich == true
		t.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = math.max(1, math.floor(font * pps))
		limit.Parent = t
		t.Parent = gui
	end
	gui.Parent = p
	p.Parent = parent
	return p
end

-- Front face of a carrier looking along `front` (horizontal).
local function facing(pos: Vector3, front: Vector3): CFrame
	return CFrame.lookAt(pos, pos + front, UP)
end

-- Kit sign frame with the text panel on it. pos = centre of the text panel, front = the way
-- the sign faces. Frame sizes: SignFrame_<w>x<h> (panel w x h, panel centre 0.7 + h/2 above
-- the frame origin, panel face 0.45 in front of the back).
local FRAME_PANEL: { [string]: { number } } = {
	SignFrame_20x2 = { 20, 2.4 },
	SignFrame_16x3 = { 16, 3 },
	SignFrame_16x6 = { 16, 6 },
	SignFrame_5x1 = { 5, 1.2 },
}
local function framedSign(
	name: string,
	piece: string,
	back: Vector3,
	front: Vector3,
	lines: { TextLine },
	maxDist: number?
)
	local wh = FRAME_PANEL[piece]
	local f = Vector3.new(front.X, 0, front.Z).Unit
	local origin = back - UP * (0.7 + wh[2] / 2)
	atomic(put(Signs, piece, faceCF(origin, f), name .. "_Frame"))
	textPanel(Signs, name, wh[1] - 0.2, wh[2] - 0.1, facing(back + f * 0.48, f), lines, maxDist)
end

-- Underside of a display gun (studs below its pivot) at axial distance a toward the muzzle.
type Profile = { a0: number, da: number, v: { number? } }
local function profileOf(m: Model): Profile
	local s = m:GetAttribute("UnderProfile")
	assert(typeof(s) == "string", "display gun without UnderProfile: " .. m.Name)
	local parts = string.split(s, ";")
	local v: { number? } = {}
	for i, x in string.split(parts[3], ",") do
		v[i] = tonumber(x)
	end
	return { a0 = tonumber(parts[1]) :: number, da = tonumber(parts[2]) :: number, v = v }
end
local function underAt(p: Profile, a: number): number?
	local i = math.floor((a - p.a0) / p.da + 0.5) + 1
	return p.v[i]
end
-- The highest underside in [a1, a2] (a flat-ish stretch of receiver, handguard or stock).
local function bestStation(p: Profile, a1: number, a2: number): (number?, number?)
	local bestA, bestU = nil, nil
	local a = a1
	while a <= a2 do
		local u = underAt(p, a)
		if u and (bestU == nil or u > bestU) then
			bestA, bestU = a, u
		end
		a += p.da
	end
	return bestA, bestU
end

local rodPart = kit("DisplayRod"):FindFirstChildWhichIsA("BasePart") :: BasePart
local pylonPart = kit("HeroPylon"):FindFirstChildWhichIsA("BasePart") :: BasePart

-- A vertical kit column (rod or pylon) from y0 to y1 at (x, z): the 1-stud master scaled.
local function column(
	parent: Instance,
	master: BasePart,
	name: string,
	x: number,
	z: number,
	y0: number,
	y1: number
)
	local c = master:Clone()
	c.Name = name
	local h = math.max(0.05, y1 - y0)
	c.Size = Vector3.new(master.Size.X, h, master.Size.Z)
	c.CFrame = CFrame.new(x, (y0 + y1) / 2, z) * master.CFrame.Rotation
	c.CastShadow = false
	c.Parent = parent
	return c
end

-- Places a display gun model with its muzzle along `muzzle` (horizontal), right side toward
-- the viewer who looks along muzzle:Cross(UP)... i.e. muzzle to the viewer's right.
local function placeGun(
	parent: Instance,
	name: string,
	piece: string,
	pos: Vector3,
	muzzle: Vector3
): Model
	local m = kit(piece):Clone()
	m.Name = name
	m:PivotTo(CFrame.fromMatrix(pos, muzzle:Cross(UP), UP))
	m.Parent = parent
	return m
end

-- Museum finish for every display gun (the baked SurfaceAppearances go: lighter flat looks read
-- under the neutral key, and the wing stops loading a PBR texture set per gun). The game guns
-- share one palette (Metal 303237, polymer 222327, panels 3C3F46, Neon accents), so parts map by
-- material / name; Neon and anything off-palette (lenses) keep their own look.
type Finish = {
	metal: Color3,
	panel: Color3,
	panelMetal: boolean?,
	dark: Color3,
	accent: Color3?,
	label: string?,
}
local MUSEUM: Finish = {
	metal = Color3.fromHex("4A4E56"),
	panel = Color3.fromHex("5C6068"),
	dark = Color3.fromHex("2E3036"),
}
local SKINS: { [string]: Finish } = {
	GOLD = {
		metal = Color3.fromHex("8C6E36"),
		panel = Color3.fromHex("C9A55A"),
		panelMetal = true,
		dark = Color3.fromHex("2C2C30"),
		accent = Color3.fromHex("FFC83D"),
		label = "#E2B85C",
	},
	ARCTIC = {
		metal = Color3.fromHex("B9C1CB"),
		panel = Color3.fromHex("F2F4F7"),
		dark = Color3.fromHex("5F6874"),
		accent = Color3.fromHex("7FD8FF"),
		label = "#9FDFFF",
	},
	CRIMSON = {
		metal = Color3.fromHex("34353B"),
		panel = Color3.fromHex("B3262E"),
		dark = Color3.fromHex("1D1E22"),
		accent = Color3.fromHex("FF5A5F"),
		label = "#FF6A70",
	},
}
local PALETTE_METAL = Color3.fromHex("303237")
local PALETTE_DARK = Color3.fromHex("222327")
local PALETTE_PANEL = Color3.fromHex("3C3F46")
local function near(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.03
end
local saRemoved = 0
local function finishGun(m: Instance, fin: Finish, reflect: number?)
	for _, d in m:GetDescendants() do
		if d:IsA("SurfaceAppearance") then
			d:Destroy()
			saRemoved += 1
		end
	end
	for _, p in m:GetDescendants() do
		if not p:IsA("BasePart") then
			continue
		end
		if p.Material == Enum.Material.Neon then
			if fin.accent then
				p.Color = fin.accent
			end
		elseif near(p.Color, PALETTE_METAL) then
			p.Material = Enum.Material.Metal
			p.Color = fin.metal
			p.Reflectance = reflect or 0
		elseif near(p.Color, PALETTE_PANEL) then
			p.Material = if fin.panelMetal then Enum.Material.Metal else Enum.Material.SmoothPlastic
			p.Color = fin.panel
			p.Reflectance = if fin.panelMetal then 0.08 else 0
		elseif near(p.Color, PALETTE_DARK) then
			p.Material = Enum.Material.SmoothPlastic
			p.Color = fin.dark
		end
	end
end

-- Trophy lengths (studs along the wall): rifle walls hold 3 per row in 19.5, pistol walls 2.
local TROPHY_LEN: { [string]: number } = {
	Vandal = 5.2,
	Phantom = 5.2,
	Bulldog = 4.6,
	Guardian = 5.6,
	Marshal = 5.6,
	Operator = 5.7,
	Outlaw = 5.7,
	Spectre = 4.6,
	Stinger = 4.3,
	Judge = 5.0,
	Bucky = 5.3,
	Odin = 5.7,
	Ares = 5.6,
	Classic = 2.9,
	Ghost = 3.3,
	Shorty = 2.7,
	Sheriff = 3.1,
	Knife = 2.8,
}
local function trophySource(gun: string): string
	for _, pre in { "Trophy_", "Display_", "Hero_" } do
		if hasKit(pre .. gun) then
			return pre .. gun
		end
	end
	error("no display model for " .. gun)
end

-- Ambience carry-over: the Lobby_Turntable swivel set by AmbienceSetup on each chapel's gun.
local CollectionService = game:GetService("CollectionService")
type Spin = { center: Vector3, period: number, phase: number, swing: number? }
local oldSpins: { [string]: Spin } = {}
do
	local old = workspace.Lobby:FindFirstChild("Art")
	local oc = old and old:FindFirstChild("Weapons")
	local ch = oc and oc:FindFirstChild("Chapels")
	if ch then
		for _, c in ch:GetChildren() do
			local g = c:FindFirstChild("Gun")
			if g and g:HasTag("Lobby_Turntable") then
				local center = g:GetAttribute("SpinCenter")
				local period = g:GetAttribute("SpinPeriod")
				local phase = g:GetAttribute("SpinPhase")
				local swing = g:GetAttribute("SpinSwing")
				if
					typeof(center) == "Vector3"
					and typeof(period) == "number"
					and typeof(phase) == "number"
				then
					oldSpins[c.Name] = {
						center = center,
						period = period,
						phase = phase,
						swing = if typeof(swing) == "number" then swing else nil,
					}
				end
			end
		end
	end
end
local function tagSpin(inst: Instance, s: Spin)
	CollectionService:AddTag(inst, "Lobby_Turntable")
	inst:SetAttribute("SpinCenter", s.center)
	inst:SetAttribute("SpinPeriod", s.period)
	inst:SetAttribute("SpinPhase", s.phase)
	inst:SetAttribute("SpinSwing", s.swing)
	if inst:IsA("Model") then
		inst.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end
end
local function tagPulse(inst: Instance, period: number, depth: number, phase: number?)
	CollectionService:AddTag(inst, "Lobby_Pulse")
	inst:SetAttribute("AmbPeriod", period)
	inst:SetAttribute("AmbDepth", depth)
	inst:SetAttribute("AmbPhase", phase)
end

-- ------------------------------------------------------------------ structure

for _, b in PIERS do
	put(Structure, "ArmouryPier_R42", segCF(b, 0, CX, 0), "Pier_" .. b)
end
-- The drum sits 0.05 low: its soffit underside (y 18.0) is otherwise coplanar with the chapel
-- roof undersides and z-fights in jagged black patches over every chapel mouth.
for k = 0, 31 do
	put(Structure, "ArmouryDrum_R42", segCF(k * SEG, -0.05, CX, 0), "Drum_" .. k)
end
put(Structure, "LanternRing_R16", CFrame.new(CX, 0, 0), "Lantern")
put(Structure, "FloorRing_R20", CFrame.new(CX, 0, 0), "FloorRing")

-- Glazing bars under the lantern glass (greybox LanternGlass: y 37.0..37.6, r 16.5): four black
-- steel bars across the opening and a hub, so the oculus reads as a glazed lantern, not a hole.
do
	local glazing = Instance.new("Model")
	glazing.Name = "LanternGlazing"
	for k = 0, 3 do
		local bar = make(
			glazing,
			"Bar" .. k,
			Vector3.new(0.4, 0.45, 32.4),
			CFrame.new(CX, 36.78, 0) * CFrame.Angles(0, math.rad(k * 45), 0),
			Color3.new(),
			{ collide = false, shadow = false }
		)
		finish(bar, "SteelBlack")
	end
	local hub = cylinder(
		glazing,
		"Hub",
		CX,
		0,
		1.4,
		36.45,
		37.0,
		Color3.new(),
		{ collide = false, shadow = false }
	)
	finish(hub, "SteelBlack")
	glazing.Parent = Structure
end

-- ------------------------------------------------------------------ chapels

local rodCount = 0
local spinsApplied = 0
for i, bay in BAYS do
	local f = Instance.new("Model")
	f.Name = string.format("Chapel%d_%s", i, bay.gun)
	local bm = bay.b0 + SPAN / 2
	local inward = -dir(bm)
	local right = dir(bm + 90) -- viewer's right looking out from the centre
	put(f, if bay.deep then "GunChapel" else "GunChapel_R50", segCF(bay.b0, 0, CX, 0), "Shell")

	-- Turntable on the greybox plinth (r 47.5 deep / 46 shallow), facing the armoury.
	local pr = if bay.deep then 5 else 3.5
	local tt = at(42.5 + pr, bm, 0.5)
	atomic(
		put(
			f,
			if bay.deep then "GunTurntable" else "GunTurntable_7",
			faceCF(tt, inward),
			"Turntable"
		)
	)

	-- The display gun: muzzle to the viewer's right, its lowest point 1.6 above the deck.
	local gunName = "Display_" .. bay.gun
	local gm = kit(gunName)
	local low = gm:GetAttribute("Low") :: number
	local centre = Vector3.new(tt.X, DECK + 1.6 - low, tt.Z)
	local gun = placeGun(f, "Gun", gunName, centre, right)
	gun:SetAttribute("GunId", bay.gun)
	finishGun(gun, MUSEUM)

	-- Rods: under the stock and the handguard (rifles) or under the slide (pistols), always
	-- standing on the deck (|a| <= deck radius - 0.45), each at the highest underside in its span.
	local prof = profileOf(gm)
	local reach = (if bay.deep then 4.55 else 3.18) - 0.45
	local stations = {}
	if bay.deep then
		table.insert(stations, { bestStation(prof, -reach, -0.35 * reach) })
		table.insert(stations, { bestStation(prof, 0.35 * reach, reach) })
	else
		table.insert(stations, { bestStation(prof, 0, reach) })
	end
	for k, s in stations do
		local a, u = s[1], s[2]
		if a and u then
			local p = centre + right * a
			local top = centre.Y + u - 0.16
			column(f, rodPart, "Rod" .. k, p.X, p.Z, DECK, top)
			local sd =
				put(f, "DisplaySaddle", faceCF(Vector3.new(p.X, top, p.Z), right), "Saddle" .. k)
			for _, d in sd:GetDescendants() do
				if d:IsA("BasePart") then
					d.CastShadow = false
				end
			end
			rodCount += 1
		end
	end

	-- Trophy wall on the back wall (deep: the R56 chord, shallow: the middle R50 facet), two rows
	-- of the chapel's class: 3 + 2 staggered on the 20-wide wall, 2 + 2 on the 10-wide one (its
	-- rows sit higher: the big display pistol in front stands up to y 10.8).
	local face = if bay.deep
		then 56 * math.cos(math.rad(SPAN / 2))
		else 50 * math.cos(math.rad(SEG / 2))
	local wallPos = at(face, bm, 0.5)
	put(
		f,
		if bay.deep then "TrophyWall" else "TrophyWall_10",
		faceCF(wallPos, inward),
		"TrophyWall"
	)
	local slots: { { number } } = if bay.deep
		then { { -6.45, 15.1 }, { 0, 15.1 }, { 6.45, 15.1 }, { -3.25, 11.5 }, { 3.25, 11.5 } }
		else { { -2.2, 15.5 }, { 2.2, 15.5 }, { -2.2, 12.9 }, { 2.2, 12.9 } }
	for k, t in bay.trophies do
		local slot = slots[k]
		if not slot then
			break
		end
		local src = kit(trophySource(t.gun))
		local s = (TROPHY_LEN[t.gun] or 5) / (src:GetAttribute("Length") :: number)
		local off, cy = slot[1], slot[2]
		local tpos = wallPos + right * off + inward * 0.72
		tpos = Vector3.new(tpos.X, cy, tpos.Z)
		local tag = t.gun .. (if t.skin then "_" .. t.skin else "")
		local tm = placeGun(f, "Trophy_" .. tag, trophySource(t.gun), tpos, right)
		tm:ScaleTo(s)
		tm:SetAttribute("GunId", t.gun)
		if t.skin then
			tm:SetAttribute("Skin", t.skin)
		end
		-- Tiny bits (pins, charm loops, selector) vanish at this size: drop them.
		for _, d in tm:GetChildren() do
			if d:IsA("BasePart") and math.max(d.Size.X, d.Size.Y, d.Size.Z) < 0.16 then
				d:Destroy()
			end
		end
		finishGun(tm, if t.skin then SKINS[t.skin] else MUSEUM)
		atomic(tm)
		local tabBase = wallPos + right * off + inward * 0.4
		-- The name tab hangs just under the gun's lowest point (mags and grips never cover it).
		local tabY = cy + (src:GetAttribute("Low") :: number) * s - 0.55
		put(f, "TrophyTab", faceCF(Vector3.new(tabBase.X, tabY, tabBase.Z), inward), "Tab_" .. tag)
		local label = string.upper(t.gun)
		local sk = if t.skin then SKINS[t.skin] else nil
		if t.skin and sk and sk.label then
			label ..= string.format('  <font color="%s">%s</font>', sk.label, t.skin)
		end
		textPanel(
			f,
			"TabText_" .. tag,
			2.3,
			0.36,
			facing(Vector3.new(tabBase.X, tabY + 0.2, tabBase.Z) + inward * 0.14, inward),
			{ { text = label, cap = 0.22, rich = t.skin ~= nil } },
			40
		)
	end

	-- Sloped name plaque on the stage, to the viewer's right of the turntable (kit scaled 1.35 / 1.1).
	local front = if bay.deep
		then 44 * math.cos(math.rad(SPAN / 2))
		else 44 * math.cos(math.rad(SEG / 2))
	local s = if bay.deep then 1.35 else 1.1
	local plaqueAt = at(front + (if bay.deep then 1.1 else 0.9), bm, 0.5) + right * 7.6
	local plaque = put(f, "GunPlaque", faceCF(plaqueAt, inward), "Plaque")
	plaque:ScaleTo(s)
	atomic(plaque)
	local n = (inward * 0.6 + UP * 1.2).Unit
	local slopeUp = (-inward * 1.2 + UP * 0.6).Unit
	local mid = plaqueAt + UP * (0.72 * s) + n * 0.04
	textPanel(f, "PlaqueText", 5.6 * s, 1.25 * s, CFrame.lookAt(mid, mid + n, slopeUp), {
		{ text = bay.title, cap = 0.62 * s },
		{ text = bay.class, cap = 0.22 * s, sub = true },
	}, 60)

	-- Ambience: the swivel AmbienceSetup measured for this chapel (gun, deck, rods, saddles).
	local spinRec = oldSpins[f.Name]
	if spinRec then
		tagSpin(gun, spinRec)
		for _, d in (f:FindFirstChild("Turntable") :: Instance):GetChildren() do
			if d:IsA("BasePart") and string.find(d.Name, "_Deck$") then
				tagSpin(d, spinRec)
			end
		end
		for _, d in f:GetChildren() do
			if string.find(d.Name, "^Rod%d") or string.find(d.Name, "^Saddle%d") then
				tagSpin(d, spinRec)
			end
		end
		spinsApplied += 1
	end
	f.Parent = Chapels
end

-- ------------------------------------------------------------------ hero island

local dais = put(Hero, "HeroDais", CFrame.new(CX, 0, 0), "Dais")
for _, d in dais:GetDescendants() do
	if d:IsA("BasePart") and string.find(d.Name, "Top$") then
		d.Color = DAIS_TOP
	end
end
local heroAim = Vector3.new(CX, 14.5, 0)
do
	local hm = kit("Hero_Vandal")
	local prof = profileOf(hm)
	local south = Vector3.new(0, 0, 1)
	-- The plan's y 10-17 (fix pass): the gun's lowest point at y 10, so the entry eye line to the
	-- Locker's light box and mannequin passes under the magazine and the gun frames the Locker.
	local GUN_LOW = 10.0
	local yc = GUN_LOW - (hm:GetAttribute("Low") :: number)
	-- Greybox pylons (collision, never moved): N at z -7 (top 11.4), S at z 9 (top 10.6). Slide the
	-- gun along its axis so both meet a high, flat stretch of its underside.
	local function underMin(a: number): number?
		-- The lowest underside over the cradle's 1.8 length, so the cradle never cuts into the gun.
		local lo: number? = nil
		local x = a - 0.9
		while x <= a + 0.9 + 1e-6 do
			local u = underAt(prof, x)
			if u == nil then
				return nil
			end
			lo = if lo == nil then u else math.min(lo, u)
			x += 0.15
		end
		return lo
	end
	local bestZ, bestScore = 0, -math.huge
	local zc = -2.5
	while zc <= 2.5 do
		local uN = underMin(-7 - zc)
		local uS = underMin(9 - zc)
		if uN and uS then
			local score = math.min(uN, uS) - math.abs(zc) * 0.05
			if score > bestScore then
				bestZ, bestScore = zc, score
			end
		end
		zc += 0.25
	end
	local gun = placeGun(Hero, "HeroGun", "Hero_Vandal", Vector3.new(CX, yc, bestZ), south)
	gun:SetAttribute("GunId", "Vandal")
	finishGun(gun, MUSEUM)
	for _, d in gun:GetChildren() do
		if d:IsA("BasePart") and string.find(d.Name, "^Receiver") then
			d.Reflectance = 0.05
		end
	end
	gun.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	-- The receiver, for the key and rim lights.
	local rc = gun:FindFirstChild("Receiver_Panel")
	if rc and rc:IsA("BasePart") then
		heroAim = rc.Position
	end
	for _, d in gun:GetChildren() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			tagPulse(d, 5, 0.45)
		end
	end
	-- Museum mounts: black plinth + brushed collar on the dais top (y 1.6), a slim brushed column,
	-- a collar and the brushed V-cradle whose rim meets the gun's underside.
	for _, st in { { "N", -7 }, { "S", 9 } } do
		local tag, z = st[1] :: string, st[2] :: number
		local u = underMin(z - bestZ) :: number
		local cradle = yc + u - 0.5
		atomic(put(Hero, "HeroPylonBase", CFrame.new(CX, 1.6, z), "Base" .. tag))
		column(Hero, pylonPart, "Pylon" .. tag, CX, z, 1.6 + 0.4, cradle - 0.3)
		atomic(put(Hero, "HeroPylonCollar", CFrame.new(CX, cradle, z), "Collar" .. tag))
		atomic(put(Hero, "HeroCradle", faceCF(Vector3.new(CX, cradle, z), south), "Cradle" .. tag))
	end
	-- Lectern on the lower step, facing the entry, with the gun's name on its face.
	atomic(put(Hero, "HeroLectern", faceCF(Vector3.new(CX - 10.4, 0.8, 0), WEST), "Lectern"))
	textPanel(Hero, "LecternText", 8.2, 1.35, facing(Vector3.new(CX - 12.09, 1.85, 0), WEST), {
		{ text = "VANDAL", cap = 0.8 },
		{ text = "GUN 01  /  STANDARD RIFLE", cap = 0.24, sub = true },
	}, 80)
end
do
	local ring = Hero:FindFirstChild("Dais")
	local rg = ring and ring:FindFirstChild("HeroDais_Ring_Glow")
	if rg then
		tagPulse(rg, 5, 0.18, 2.5)
	end
end

-- ------------------------------------------------------------------ corridor

put(Corridor, "SteelFrame_14", faceCF(Vector3.new(81, 0, 0), WEST), "Frame1")
put(Corridor, "SteelFrame_135", faceCF(Vector3.new(89, 0, 0), WEST), "Frame2")

-- ------------------------------------------------------------------ locker

for k = 0, 15 do
	put(Locker, "LockerApse_R16", segCF(k * SEG, 0, 182, 0), "Apse_" .. k)
end
put(Locker, "LockerCheek", faceCF(Vector3.new(178, 0, -16), SOUTH), "CheekN")
put(Locker, "LockerCheek", faceCF(Vector3.new(178, 0, 16), NORTH), "CheekS")
put(Locker, "LockerBacklight", faceCF(Vector3.new(197, 0, 0), WEST), "Backlight")
-- The back-lit field: an unlit SurfaceGui (LightInfluence 0) on a carrier just in front of the
-- kit's light panel, so it reads as a light box without a big Neon surface or another light.
do
	local p = Instance.new("Part")
	p.Name = "BacklightField"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(8.7, 12.7, 0.05)
	p.CFrame = facing(Vector3.new(196.57, 8.5, 0), WEST)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 8
	gui.LightInfluence = 0
	gui.Brightness = 1
	gui.MaxDistance = 120
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	-- Toned down (fix pass) and brighter at the top, so the light figure's edges read against it.
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("DCD7CE")),
		ColorSequenceKeypoint.new(0.5, Color3.fromHex("CFCAC2")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("A39E96")),
	})
	grad.Parent = fill
	fill.Parent = gui
	gui.Parent = p
	p.Parent = Locker
end
atomic(put(Locker, "LockerPedestal", CFrame.new(188, 0, 0), "Pedestal"))
-- Light satin default-avatar form on its brass base ring (kit look), facing the Armoury.
atomic(put(Locker, "Mannequin", faceCF(Vector3.new(188, 1.2, 0), WEST), "Mannequin"))
for _, s in { -1, 1 } do
	local tag = if s < 0 then "N" else "S"
	local f = Vector3.new(0, 0, -s)
	local base = Vector3.new(184, 0, s * 10)
	atomic(put(Locker, "LoadoutTerminal", faceCF(base, f), "Terminal" .. tag))
	-- Screen: the kit's sloped face (centre 0.755 out, 4.45 up; normal 0.979 out, 0.206 up).
	local n = (f * 0.979 + UP * 0.206).Unit
	local slopeUp = (-f * 0.206 + UP * 0.979).Unit
	local mid = base + f * 0.755 + UP * 4.45 + n * 0.04
	textPanel(Locker, "Screen" .. tag, 2.4, 1.45, CFrame.lookAt(mid, mid + n, slopeUp), {
		{ text = "LOADOUT", cap = 0.42 },
		{ text = "EDIT CLASS  +  SKINS", cap = 0.16, sub = true },
	}, 40)
	framedSign("TerminalLabel" .. tag, "SignFrame_5x1", base + UP * (5.45 + 0.7 + 0.6), f, {
		{ text = "LOADOUT", cap = 0.75 },
	}, 60)
end

-- ------------------------------------------------------------------ signs

framedSign("ArmourySign", "SignFrame_20x2", Vector3.new(87, 14.75, 0), WEST, {
	{ text = "ARMOURY  +  LOCKER", cap = 1.6 },
}, 120)
-- The exit sign hangs on the drum face over the entry (r 42, set 0.45 off the curve), with its
-- frame just under the cornice shelf (y 28.4): from the Locker the eye line to it passes over
-- the raised hero rifle's receiver (y 19.2 on the corridor roof edge sat right behind it).
framedSign("ExitSign", "SignFrame_16x3", Vector3.new(CX - 42 + 0.45, 26.1, 0), EAST, {
	{ text = "EXIT TO HUB", cap = 2 },
}, 120)
framedSign("LockerSign", "SignFrame_16x6", Vector3.new(178, 24.5, 0), WEST, {
	{ text = "LOCKER", cap = 3.5 },
	{ text = "LOADOUT  +  SKINS", cap = 1.2, sub = true },
}, 120)

-- ------------------------------------------------------------------ lights (11 dynamic)

local rig = Instance.new("Part")
rig.Name = "LightRig"
rig.Anchored = true
rig.CanCollide = false
rig.CanQuery = false
rig.CanTouch = false
rig.CastShadow = false
rig.Transparency = 1
rig.Size = Vector3.one
rig.CFrame = CFrame.new(CX, 32, 0)
rig.Parent = Lights

local function emitter(name: string, pos: Vector3, target: Vector3?): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = rig
	a.WorldCFrame = if target then CFrame.lookAt(pos, target) else CFrame.new(pos)
	return a
end

local function spot(
	name: string,
	pos: Vector3,
	target: Vector3,
	brightness: number,
	range: number,
	angle: number,
	shadows: boolean
)
	local l = Instance.new("SpotLight")
	l.Name = name
	l.Face = Enum.NormalId.Front
	l.Color = NEUTRAL
	l.Brightness = brightness
	l.Range = range
	l.Angle = angle
	l.Shadows = shadows
	l.Parent = emitter(name, pos, target)
end

-- Hero key: front-top on the receiver from the entry side (the area's one shadow caster), and a
-- cool rim from behind and above (the Locker side) so the rifle's top edges separate from the dome.
spot("HeroKey", Vector3.new(CX - 20, 25, 0), heroAim, 3.5, 40, 30, true)
do
	spot("HeroRim", Vector3.new(CX + 20, 24, 0), heroAim, 2, 32, 35, false)
	local rim = rig:FindFirstChild("HeroRim")
	local l = rim and rim:FindFirstChildWhichIsA("SpotLight")
	if l then
		l.Color = Color3.fromHex("DDE8F2")
	end
end
-- Locker: on the figure's torso from the apse mouth.
spot("LockerSpot", Vector3.new(179, 18.5, 0), Vector3.new(188, 4, 0), 3, 30, 40, false)
-- Chapels: one shadowless point light per chapel, between its display gun and trophy wall: it
-- lights both, and spills out of the chapel mouth onto the piers and the armoury floor (this
-- replaces the four fills on the fins, which left the trophy walls in a grey half-light).
for i, bay in BAYS do
	local bm = bay.b0 + SPAN / 2
	local l = Instance.new("PointLight")
	l.Name = string.format("ChapelFill%d_%s", i, bay.gun)
	l.Color = NEUTRAL
	l.Brightness = 1.4
	l.Range = 22
	l.Shadows = false
	l.Parent = emitter(l.Name, if bay.deep then at(50.5, bm, 12.5) else at(47.2, bm, 12.5), nil)
end

-- ------------------------------------------------------------------ publish

publishArt(root)
local lights, collide, sas, guis, fidelity = 0, 0, 0, 0, 0
for _, d in root:GetDescendants() do
	if d:IsA("Light") then
		lights += 1
	elseif d:IsA("SurfaceAppearance") then
		sas += 1
	elseif d:IsA("SurfaceGui") then
		guis += 1
	elseif d:IsA("BasePart") then
		if d.CanCollide then
			collide += 1
		end
		if d:IsA("MeshPart") and d.CollisionFidelity ~= Enum.CollisionFidelity.Box then
			fidelity += 1
		end
	end
end
table.insert(
	REPORT,
	string.format(
		"Weapons: %d lights, %d colliding parts, %d rods, %d SurfaceAppearances (%d removed), %d SurfaceGuis, %d MeshParts not on Box fidelity, %d/8 chapel swivels re-tagged",
		lights,
		collide,
		rodCount,
		sas,
		saRemoved,
		guis,
		fidelity,
		spinsApplied
	)
)
