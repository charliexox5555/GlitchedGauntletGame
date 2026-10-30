--!strict
-- Lobby art: the hub (spawn rotunda + outer ring), phase 1 step 5.
-- Bundle: `python tools/studio/lobby/bundle.py Art_Hub -o art_hub.luau` (after the
-- Hub kit group is installed with kit_bundle.py Hub). Re-runnable: it hides the
-- greybox parts it replaces (they stay the collision), finishes the ones that stay
-- visible, and rebuilds Workspace.Lobby.Art.Rotunda and Art.Ring.
--
-- Kit pieces (tools/blender/build_lobby_kit_hub.py):
--   rotunda  RotundaFloor, SpawnDais, RotundaPier x8, RotundaColumn x4, RingBeam_R44 /
--            Drum_R44 / DomeCoffer_R44 x32, OculusRim_R16, LeaderboardFrame x4, PierPlaque x2
--   ring     RingFloor_R44_68 / RingCeiling_R44_68 x32, RockPlinth_R68 + RockWall_R68_A/B/C
--            (each upright or turned over, so 6 looks) on the 14 rock segments,
--            Alcove_R68 x4, PortalFrame_52 (Duels) + PortalFrame_26 x3, TitleBand_40/_26
-- Lights: one SurfaceLight per portal soffit (4, shadowless). Everything else glows
-- with Neon; the sunbeam rig is step 6.

local rotGrey = grey("Rotunda")
assert(rotGrey, "no Greybox.Rotunda (run Hub.luau first)")
local ringGrey = grey("Ring")
assert(ringGrey, "no Greybox.Ring (run Hub.luau first)")

local LIGHTS = 0
-- Roblox Neon pushes toward white: the kit's cove colour (#FFDDB0) read clinical,
-- so every warm line is tinted down to a warm 3000K-looking amber.
local KIT_COVE = Color3.fromHex("FFDDB0")
local WARM = Color3.fromHex("D9A577")
local SCREEN_GLOW = Color3.fromHex("A9BACB")

local function warmGlows(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Glow") and d.Color == KIT_COVE then
			d.Color = WARM
		end
	end
end

local function bearingOf(p: Vector3): number
	return math.deg(math.atan2(p.X, -p.Z)) % 360
end

local function child(m: Instance, name: string): BasePart
	local p = m:FindFirstChild(name)
	assert(p and p:IsA("BasePart"), "kit part missing: " .. name)
	return p
end

-- ---------------------------------------------------------------- rotunda

local rot = artSection("Rotunda")

for _, p in rotGrey:GetChildren() do
	local n = p.Name
	if n == "LobbySpawn" then
		continue -- phase-2 hook: stays exactly as built (invisible spawn)
	elseif string.find(n, "^Leaderboard_") then
		finish(p, "Screen") -- keeps both SurfaceGuis
	elseif n == "Plaque" then
		finish(p, "Sign")
	else
		hide(p) -- floor, inlay, dais, arrow, piers, columns, beam, drum, dome, oculus
	end
end

-- Flat floor meshes never need to cast shadows (they only cost shadow-map draws).
local function noShadow(m: Instance)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CastShadow = false
		end
	end
end

-- The floor's top is z 0 in the kit; the greybox floor top is 0.02 (inlay 0.04).
local floor = put(rot, "RotundaFloor", CFrame.new(0, 0.02, 0))
noShadow(floor)
-- The four light lines run from the dais to the portals, each in its wing's colour.
local FLOOR_LINES: { [string]: Color3 } = {
	N = GLOW.duelsRed,
	E = Color3.fromHex("F2EEE4"),
	S = GLOW.cool,
	W = Color3.fromHex("D9A577"),
}
for d, c in FLOOR_LINES do
	child(floor, "RotundaFloor_Line" .. d .. "_Glow").Color = c
end
put(rot, "SpawnDais", CFrame.identity)
put(rot, "OculusRim_R16", CFrame.identity)

local structure = Instance.new("Folder")
structure.Name = "Structure"
structure.Parent = rot
for k = 0, 7 do
	put(structure, "RotundaPier", ringCF(45.5, 22.5 + 45 * k), "Pier_" .. k)
end
for k = 0, 3 do
	put(structure, "RotundaColumn", ringCF(44, 45 + 90 * k), "Column_" .. k)
end
for k = 0, 31 do
	local cf = segCF(k * SEG)
	put(structure, "RingBeam_R44", cf, "RingBeam_" .. k)
	put(structure, "Drum_R44", cf, "Drum_" .. k)
	put(structure, "DomeCoffer_R44", cf, "Dome_" .. k)
end

-- SurfaceGui texture budget (performance audit): at most 25 pixels per stud. A gui
-- built at a higher density is rescaled in place (label sizes and text limits scale
-- with it), so its layout stays the same. Idempotent.
local MAX_PPS = 25
local function capPps(gui: SurfaceGui, maxDistance: number)
	gui.MaxDistance = maxDistance
	local pps = gui.PixelsPerStud
	if pps <= MAX_PPS then
		return
	end
	local k = MAX_PPS / pps
	gui.PixelsPerStud = MAX_PPS
	for _, d in gui:GetDescendants() do
		if d:IsA("GuiObject") then
			local s = d.Size
			d.Size = UDim2.new(
				s.X.Scale,
				math.floor(s.X.Offset * k),
				s.Y.Scale,
				math.floor(s.Y.Offset * k)
			)
			local q = d.Position
			d.Position = UDim2.new(
				q.X.Scale,
				math.floor(q.X.Offset * k),
				q.Y.Scale,
				math.floor(q.Y.Offset * k)
			)
		end
		if d:IsA("TextLabel") then
			d.TextSize = math.max(1, math.floor(d.TextSize * k))
		elseif d:IsA("UITextSizeConstraint") then
			d.MaxTextSize = math.max(1, math.floor(d.MaxTextSize * k))
		end
	end
end

-- Wing data for the ring-side arrows (leaderboard backs): name, one-line content, the
-- wing's light colour (the strip under its arrow).
type Wing = { name: string, sub: string, color: Color3 }
local WINGS: { [string]: Wing } = {
	DUELS = { name = "DUELS", sub = "1V1 / 2V2 / 3V3", color = GLOW.duelsRed },
	WEAPONS = { name = "WEAPONS", sub = "GUNS + LOCKER", color = Color3.fromHex("F2EEE4") },
	RANGE = { name = "RANGE", sub = "PRACTICE", color = GLOW.cool },
	MARKET = { name = "MARKET", sub = "SHOP + PASS", color = WARM },
}
-- Seen from the ring (behind each board): the wing to the walker's left and right.
local BOARD_WINGS: { [string]: { string } } = {
	Leaderboard_1 = { "WEAPONS", "DUELS" }, -- NE
	Leaderboard_2 = { "DUELS", "MARKET" }, -- NW
	Leaderboard_3 = { "RANGE", "WEAPONS" }, -- SE
	Leaderboard_4 = { "MARKET", "RANGE" }, -- SW
}

-- The ring side of a board: two halves either side of a 3-stud centre gap (the slim
-- column stands behind the board's centre), each an arrow plus the wing name and
-- its contents, in the top band above the kit's back plate (z 20.75-25.5 of the
-- 12-25.5 screen, i.e. the top 35% of the face).
local BAND = (25.5 - 20.75) / 13.5
local SUBGREY = Color3.fromRGB(176, 180, 186)
local BACKPLATE = Color3.fromHex("4B4F55")
local function label(
	parent: Instance,
	name: string,
	text: string,
	font: Enum.Font,
	color: Color3,
	pos: UDim2,
	size: UDim2,
	align: Enum.TextXAlignment,
	maxPx: number
): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Position = pos
	t.Size = size
	t.Font = font
	t.Text = text
	t.TextColor3 = color
	t.TextXAlignment = align
	t.TextYAlignment = Enum.TextYAlignment.Center
	t.TextScaled = true
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxPx
	c.Parent = t
	t.Parent = parent
	return t
end

local function boardBack(board: BasePart)
	for _, g in board:GetChildren() do
		if g:IsA("SurfaceGui") and g.Face == Enum.NormalId.Back then
			g:Destroy()
		end
	end
	local pair = BOARD_WINGS[board.Name]
	if not pair then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "RingSide"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = MAX_PPS
	gui.LightInfluence = 0
	gui.Brightness = 1.5
	gui.MaxDistance = 120
	gui.ClipsDescendants = true
	local px = MAX_PPS / 0.72 -- pixels per stud of cap height
	for side = 1, 2 do
		local w = WINGS[pair[side]]
		local left = side == 1
		-- arrow at the outer edge, name and contents toward the centre gap (0.415-0.585)
		local arrowX = if left then 0.03 else 0.91
		label(
			gui,
			"Arrow" .. side,
			if left then "<" else ">",
			Enum.Font.GothamBlack,
			C.white,
			UDim2.fromScale(arrowX, 0.02),
			UDim2.fromScale(0.06, BAND * 0.62),
			Enum.TextXAlignment.Center,
			math.floor(2.0 * px)
		)
		local textX = if left then 0.105 else 0.575
		local align = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
		label(
			gui,
			"Wing" .. side,
			w.name,
			Enum.Font.GothamBlack,
			C.white,
			UDim2.fromScale(textX, 0.03),
			UDim2.fromScale(0.31, BAND * 0.55),
			align,
			math.floor(1.6 * px)
		)
		label(
			gui,
			"Sub" .. side,
			w.sub,
			Enum.Font.GothamBold,
			SUBGREY,
			UDim2.fromScale(textX, 0.03 + BAND * 0.57),
			UDim2.fromScale(0.31, BAND * 0.3),
			align,
			math.floor(0.6 * px)
		)
	end
	gui.Parent = board
end

-- Leaderboards keep their greybox screens (and the front SurfaceGui); the kit bezel
-- and hangers frame them on the slim columns' brackets. The back is rebuilt above.
for _, p in rotGrey:GetChildren() do
	if p:IsA("BasePart") and string.find(p.Name, "^Leaderboard_") then
		local m =
			put(rot, "LeaderboardFrame", ringCF(42.5, bearingOf(p.Position)), p.Name .. "_Frame")
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		tint(m, SCREEN_GLOW)
		local pair = BOARD_WINGS[p.Name]
		if pair then
			-- the wing-colour line under each arrow (BackPosY is the walker's left)
			child(m, "LeaderboardFrame_BackPosY_Glow").Color = WINGS[pair[1]].color
			child(m, "LeaderboardFrame_BackNegY_Glow").Color = WINGS[pair[2]].color
		end
		-- the ring-side cladding reads as dark gunmetal, not a dead black screen
		child(m, "LeaderboardFrame_BackPlate").Color = BACKPLATE
		boardBack(p)
		for _, g in p:GetChildren() do
			if g:IsA("SurfaceGui") then
				capPps(g, if g.Face == Enum.NormalId.Back then 120 else 250)
			end
		end
	elseif p:IsA("BasePart") and p.Name == "Plaque" then
		local b = bearingOf(p.Position)
		local m = put(rot, "PierPlaque", ringCF(42.5, b), "Plaque_" .. math.floor(b + 0.5))
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		-- WEAPONS (east side) gets the neutral museum white, MARKET the warm cove.
		tint(m, if b < 180 then Color3.fromHex("E6E2D8") else WARM)
		for _, g in p:GetChildren() do
			if g:IsA("SurfaceGui") then
				capPps(g, 120)
			end
		end
	end
end

warmGlows(rot)
publishArt(rot)

-- ---------------------------------------------------------------- ring

local ring = artSection("Ring")

for _, p in ringGrey:GetChildren() do
	hide(p) -- every ring greybox part is dressed by a kit piece (titles are rebuilt below)
end

local floors = Instance.new("Folder")
floors.Name = "FloorCeiling"
floors.Parent = ring
local rock = Instance.new("Folder")
rock.Name = "Rock"
rock.Parent = ring

-- Rock variety: 3 meshes, each upright or turned over about its mid radial line
-- (the rock's foot and top edges are both held on R68.9, so either way meets its
-- neighbours). Neighbours never share a look.
local ORDER = { 1, 5, 3, 4, 2, 6 }
local VARIANTS = { "RockWall_R68_A", "RockWall_R68_B", "RockWall_R68_C" }
local mid = math.rad(SEG / 2)
local FLIP = CFrame.new(0, 16.8, 0)
	* CFrame.fromAxisAngle(Vector3.new(math.sin(mid), 0, -math.cos(mid)), math.pi)
	* CFrame.new(0, -16.8, 0)

local rockCount = 0
for k = 0, 31 do
	local b = k * SEG
	local cf = segCF(b)
	noShadow(put(floors, "RingFloor_R44_68", cf, "Floor_" .. k))
	put(floors, "RingCeiling_R44_68", cf, "Ceiling_" .. k)
	local bm = b + SEG / 2
	if not inAny(bm, PORTALS) and not inAny(bm, ALCOVES) then
		put(rock, "RockPlinth_R68", cf, "Plinth_" .. k)
		local idx = ORDER[(rockCount % #ORDER) + 1]
		local v = VARIANTS[((idx - 1) % 3) + 1]
		put(rock, v, if idx > 3 then cf * FLIP else cf, "Rock_" .. k)
		rockCount += 1
	end
end

local alcoves = Instance.new("Folder")
alcoves.Name = "Alcoves"
alcoves.Parent = ring
for i, a in ALCOVES do
	put(alcoves, "Alcove_R68", segCF(a[1]), "Alcove_" .. i)
end

-- Portals: frames (fronts 2 in front of the rock chord; side frames run back to the
-- wing boundary at 72), title bands in the frames' title slots, and the title signs
-- rebuilt on the bands (the greybox Title_* panels sat inside the new frame heads).
local FRONT_26 = 68 * math.cos(math.rad(SEG)) - 2
local FRONT_52 = 68 * math.cos(math.rad(2 * SEG)) - 2
local SUB = Color3.fromRGB(190, 192, 196)
type PortalSpec = {
	name: string,
	b: number,
	frame: string,
	back: number,
	band: string,
	w: number,
	title: string,
	cap: number,
	sub: string,
	strip: Color3,
	light: Color3,
}
local PORTAL_SPECS: { PortalSpec } = {
	{
		name = "DUELS",
		b = 0,
		frame = "PortalFrame_52",
		back = FRONT_52 + 6,
		band = "TitleBand_40",
		w = 40,
		title = "DUELS",
		cap = 5.5,
		sub = "STEP ON A PAD TO QUEUE",
		strip = GLOW.duelsRed,
		light = Color3.fromHex("FFF1DC"),
	},
	{
		name = "WEAPONS",
		b = 90,
		frame = "PortalFrame_26",
		back = 72,
		band = "TitleBand_26",
		w = 26,
		title = "WEAPONS",
		cap = 4,
		sub = "GUNS + LOCKER",
		strip = Color3.fromHex("F2EEE4"),
		light = Color3.fromHex("F2F0EA"),
	},
	{
		name = "RANGE",
		b = 180,
		frame = "PortalFrame_26",
		back = 72,
		band = "TitleBand_26",
		w = 26,
		title = "RANGE",
		cap = 4.5,
		sub = "PRACTICE",
		strip = GLOW.cool,
		light = Color3.fromHex("DDE8F2"),
	},
	{
		name = "MARKET",
		b = 270,
		frame = "PortalFrame_26",
		back = 72,
		band = "TitleBand_26",
		w = 26,
		title = "MARKET",
		cap = 4.5,
		sub = "SHOP + BATTLE PASS",
		strip = WARM,
		light = Color3.fromHex("FFD9A8"),
	},
}

local portals = Instance.new("Folder")
portals.Name = "Portals"
portals.Parent = ring
for _, s in PORTAL_SPECS do
	local frame = put(portals, s.frame, ringCF(s.back, s.b), "Portal_" .. s.name)
	local front = if s.frame == "PortalFrame_52" then FRONT_52 else FRONT_26
	-- One shadowless SurfaceLight on the hidden soffit strip washes the jamb returns
	-- and the sill, so each portal reads as a deep frame from the dais.
	local strip = child(frame, s.frame .. "_Soffit_Glow")
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 120
	-- (fix pass: 1.6 / 18 left the portal mouths near black in Studio's high-quality render)
	light.Range = 22
	light.Brightness = 2.6
	light.Color = s.light
	light.Shadows = false
	light.Parent = strip
	LIGHTS += 1

	local slotBack = front + 0.6
	local band = put(portals, s.band, ringCF(slotBack, s.b, 17), "TitleBand_" .. s.name)
	band.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	tint(band, s.strip)

	-- The SurfaceGui panel: kit x 0.2-0.3 in front of the band's backing, z 0.7-9.6.
	local x, z = polar(slotBack - 0.25, s.b)
	local pos = Vector3.new(x, 17 + 5.15, z)
	local facing = Vector3.new(-x, 0, -z).Unit
	local panel = make(
		band,
		"Title_" .. s.name,
		Vector3.new(s.w - 0.8, 8.9, 0.1),
		CFrame.lookAt(pos, pos + facing),
		C.sign,
		{
			collide = false,
			shadow = false,
		}
	)
	finish(panel, "Sign")
	if s.name == "DUELS" then
		-- From the spawn the Duels hall's arch titles sit behind this portal's head, so
		-- the band itself names the modes, in their colours (4V4 dormant grey). The row
		-- is RichText in one scaled label; the planned cap is 1.9 (readable to ~57).
		addSurface(panel, Enum.NormalId.Front, {
			{ text = s.title, cap = 3.6 },
			{ text = "1V1   2V2   3V3   4V4", cap = 2.0 },
		}, 8.9)
	else
		addSurface(panel, Enum.NormalId.Front, {
			{ text = s.title, cap = s.cap },
			{ text = s.sub, cap = 1.2, color = SUB },
		}, 8.9)
	end
	local gui = panel:FindFirstChildOfClass("SurfaceGui")
	if gui then
		capPps(gui, 250)
		for _, l in gui:GetChildren() do
			if l:IsA("TextLabel") and l.LayoutOrder == 2 then
				l.Font = Enum.Font.GothamBold
				if s.name == "DUELS" then
					l.Font = Enum.Font.GothamBlack
					l.RichText = true
					local function tag(t: string, c: Color3): string
						return string.format('<font color="#%s">%s</font>', c:ToHex(), t)
					end
					l.Text = table.concat({
						tag("1V1", GLOW.m1v1),
						tag("2V2", GLOW.m2v2),
						tag("3V3", GLOW.m3v3),
						tag("4V4", GLOW.dormant),
					}, "   ·   ")
				end
			end
		end
	end
end

-- Portal jambs: the greybox lintels and rock chords start behind the frames' fronts
-- (art review: players hugging the wall slid 2-3 studs into solid concrete), so each
-- jamb gets one invisible box collider whose faces sit 0.03-0.05 behind the visible
-- jamb faces. Deliberate CanCollide parts in the Art folder (they follow the kit).
local collision = Instance.new("Folder")
collision.Name = "JambCollision"
collision.Parent = ring
local JAMB_H = 16
for _, s in PORTAL_SPECS do
	local wide = s.frame == "PortalFrame_52"
	local front = (if wide then FRONT_52 else FRONT_26) + 0.03
	local back = if wide then FRONT_52 + 4 else 68.2
	local inner = (if wide then 51.6 else 26.2) / 2 + 0.05
	local outer = inner - 0.05 + 3
	for side = -1, 1, 2 do
		local cf = ringCF((front + back) / 2, s.b)
			* CFrame.new(0, JAMB_H / 2, side * (inner + outer) / 2)
		local jamb = make(
			collision,
			string.format("Jamb_%s_%s", s.name, if side < 0 then "A" else "B"),
			Vector3.new(back - front, JAMB_H, outer - inner),
			cf,
			C.concrete,
			{ transparency = 1, shadow = false }
		)
		jamb.CanTouch = false
		jamb:SetAttribute("Collider", true)
	end
end

warmGlows(ring)
publishArt(ring)
table.insert(REPORT, string.format("hub dynamic lights %d, rock segments %d", LIGHTS, rockCount))
