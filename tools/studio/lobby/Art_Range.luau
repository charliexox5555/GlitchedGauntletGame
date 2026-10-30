--!strict
-- Lobby art pass: the Range (kit group "Range", tools/blender/build_lobby_kit_range.py).
-- Bundle: `python tools/studio/lobby/bundle.py Art_Range -o art_range.luau` and run it in the
-- Lobby place. It dresses two greybox sections and rebuilds two Art folders:
--   Greybox.Wing_Range -> Art.Range     the descent, the Range Lobby, the viewing window onto the
--                                       1:3 ScaleModel, the ENTER RANGE gate and the status screen
--   Greybox.RangeFar   -> Art.RangeFar  the real range 1,000 studs south
-- The greybox stays the collision: parts the art replaces are hidden (they keep CanCollide),
-- parts that stay visible get a finished LOOK. Triggers, points and the spawn are not touched.
-- Re-runnable: publishArt replaces the Art folders, finish/hide are idempotent.

local FY = -8 -- Range Lobby floor
local FL = 1214 -- RangeFar firing line
local YELLOW = Color3.fromHex("E2B93B")
local MUTED = Color3.fromRGB(190, 192, 196)
local DAY = Color3.fromHex("DDE8F2")

-- Range looks (the style sheet's materials with the Range's cool colours).
LOOK.RangeFloor = {
	material = Enum.Material.Concrete,
	color = Color3.fromHex("A6A29B"),
	variant = "Lobby_ConcretePolished",
}
LOOK.LaneLight = {
	material = Enum.Material.Concrete,
	color = Color3.fromHex("CFCCC5"),
	variant = "Lobby_ConcretePolished",
}
LOOK.LinePaint = { material = Enum.Material.Concrete, color = Color3.fromHex("EDEEEF") }
LOOK.SafetyYellow = { material = Enum.Material.Concrete, color = YELLOW }
LOOK.RubberMat = { material = Enum.Material.Rubber, color = Color3.fromHex("2B2D30") }
LOOK.SteelPlate = { material = Enum.Material.DiamondPlate, color = Color3.fromHex("3E4349") }
LOOK.CourseFloor = {
	material = Enum.Material.Concrete,
	color = Color3.fromHex("9E9A92"),
	variant = "Lobby_ConcreteDark",
}
LOOK.AbilityFloor = {
	material = Enum.Material.Concrete,
	color = Color3.fromHex("5E5B56"),
	variant = "Lobby_ConcreteDark",
}

local wingG = grey("Wing_Range")
local farG = grey("RangeFar")
assert(wingG and farG, "run Wing_Range first")

-- Box collision fidelity on every Range kit MeshPart, so no mesh keeps a convex-decomposition hull
-- (the art never collides; the greybox and the invisible blocks below do). Setting the property
-- directly is ignored in Studio, so the mesh is re-applied from a Box-fidelity copy. Done on the
-- ServerStorage.LobbyKit masters once per install: every clone inherits it.
do
	local AssetService = game:GetService("AssetService")
	local lib = game:GetService("ServerStorage"):FindFirstChild("LobbyKit")
	local cache: { [string]: MeshPart } = {}
	local fixed = 0
	if lib then
		for _, m in lib:GetChildren() do
			if m:GetAttribute("KitGroup") ~= "Range" then
				continue
			end
			for _, d in m:GetDescendants() do
				if d:IsA("MeshPart") and d.CollisionFidelity ~= Enum.CollisionFidelity.Box then
					local src = cache[d.MeshId]
					if not src then
						local ok, made = pcall(function()
							return AssetService:CreateMeshPartAsync(d.MeshId, {
								CollisionFidelity = Enum.CollisionFidelity.Box,
								RenderFidelity = d.RenderFidelity,
							})
						end)
						if ok then
							src = made
							cache[d.MeshId] = made
						end
					end
					if src then
						local size = d.Size
						d:ApplyMesh(src)
						d.Size = size
						fixed += 1
					end
				end
			end
		end
	end
	for _, p in cache do
		p:Destroy()
	end
	table.insert(REPORT, string.format("Range kit: %d MeshParts set to Box fidelity", fixed))
end

-- Invisible collision block (deliberate: stands against a wall, out of every walking line), so
-- kit props that players must not walk through collide as one box instead of their meshes.
local function blocker(parent: Instance, name: string, size: Vector3, cf: CFrame)
	local p =
		make(parent, name, size, cf, C.white, { collide = true, shadow = false, transparency = 1 })
	p.CanTouch = false
	return p
end

-- Ambience tags (art-source/lobby/scripts/AmbienceSetup.luau): re-applied here so they survive
-- a rebuild of the Art folders.
local function ambTag(inst: Instance, tagName: string, attrs: { [string]: any })
	inst:AddTag(tagName)
	for k, v in attrs do
		inst:SetAttribute(k, v)
	end
end

local function each(folder: Instance, name: string, fn: (Instance) -> ())
	for _, c in folder:GetChildren() do
		if c.Name == name then
			fn(c)
		end
	end
end

local function finishAll(folder: Instance, names: { string }, look: string)
	for _, n in names do
		each(folder, n, function(p)
			finish(p, look)
		end)
	end
end

local function hideAll(folder: Instance, names: { string })
	for _, n in names do
		each(folder, n, hide)
	end
end

-- Non-uniform scale of a placed kit model in its own axes (X front, Y up, Z width). Kit parts are
-- axis-aligned with the model (kit_bundle only turns them 180 degrees about Y).
local function stretch(m: Model, sx: number, sy: number, sz: number)
	local pivot = m:GetPivot()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local rel = pivot:ToObjectSpace(d.CFrame)
			local p = rel.Position
			d.Size = Vector3.new(d.Size.X * sx, d.Size.Y * sy, d.Size.Z * sz)
			d.CFrame = pivot * CFrame.new(p.X * sx, p.Y * sy, p.Z * sz) * rel.Rotation
		end
	end
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Formwork panels on a wall face from a to b (plan points on the face), rows of 19.2 from y0
-- until y1 is covered (rows that run past a ceiling end inside or above it, out of sight).
-- Panels stand 0.02 off the face, so their boards are 0.12 proud of the collision.
local function panelWall(
	f: Instance,
	a: Vector3,
	b: Vector3,
	y0: number,
	y1: number,
	front: Vector3
)
	local d = flat(b - a)
	local len = d.Magnitude
	local dir = d.Unit
	local fr = flat(front).Unit
	local halves = math.max(1, math.floor(len / 9.6 + 0.5))
	local s = len / (halves * 9.6)
	local rows = math.max(1, math.ceil((y1 - y0) / 19.2 - 0.01))
	for r = 0, rows - 1 do
		local t, h = 0, halves
		while h > 0 do
			local full = h >= 2
			local w = (if full then 19.2 else 9.6) * s
			local c = flat(a) + dir * (t + w / 2) + fr * 0.02
			local m = put(
				f,
				if full then "RangeWallPanel" else "RangeWallPanelHalf",
				faceCF(Vector3.new(c.X, y0 + r * 19.2, c.Z), fr),
				"WallPanel"
			)
			stretch(m, 1, 1, s)
			t += w
			h -= if full then 2 else 1
		end
	end
end

-- Plinth (1.5 tall, honed, brushed nosing) along a wall face from a to b at floor height y.
local function plinth(f: Instance, a: Vector3, b: Vector3, y: number, front: Vector3)
	local d = flat(b - a)
	local mid = flat(a + b) / 2 + flat(front).Unit * 0.1
	local m = put(f, "RangePlinth", faceCF(Vector3.new(mid.X, y, mid.Z), front), "Plinth")
	stretch(m, 1, 1, d.Magnitude)
end

-- Scalable trim (RangeEdge: steel angle + yellow band) along a block's top edge from a to b
-- (points on the edge), with `front` the face below the edge.
local function edge(f: Instance, a: Vector3, b: Vector3, front: Vector3)
	local d = flat(b - a)
	local mid = (a + b) / 2
	local m = put(f, "RangeEdge", faceCF(mid, front), "Edge")
	stretch(m, 1, 1, d.Magnitude)
end

local function rod(f: Instance, x: number, z: number, y0: number, y1: number, r: number?)
	local m = put(f, "RangeRod", CFrame.new(x, (y0 + y1) / 2, z), "Rod")
	local d = (r or 0.12) * 2
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			p.Size = Vector3.new(d, y1 - y0, d)
		end
	end
end

-- Sign text on its own invisible face part (the frame's panel is a mesh). GothamBlack for the
-- first line, GothamBold for the rest; caps follow the plan and shrink together to fit.
type TLine = { text: string, cap: number, color: Color3? }

local function textPart(
	parent: Instance,
	name: string,
	w: number,
	h: number,
	cf: CFrame,
	lines: { TLine },
	maxDist: number?
)
	local p = make(parent, name, Vector3.new(w, h, 0.02), cf, C.white, {
		collide = false,
		shadow = false,
		transparency = 1,
	})
	local maxFont, stack = 0, 0
	for _, l in lines do
		local font = l.cap / 0.72
		local _, breaks = string.gsub(l.text, "\n", "")
		maxFont = math.max(maxFont, font)
		stack += font * 1.1 * (breaks + 1)
	end
	local k = math.min(1, h * 0.9 / stack)
	-- Texture memory: at most 25 pixels per stud, and drawn only within its sightline.
	local pps = math.clamp(math.floor(95 / (maxFont * k)), 4, 25)
	pps = math.max(4, math.min(pps, math.floor(1000 / math.max(w, h))))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps
	gui.LightInfluence = 0
	gui.Brightness = 1.5
	gui.MaxDistance = maxDist or 110
	gui.ClipsDescendants = true
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui
	for i, l in lines do
		local font = l.cap / 0.72 * k
		local _, breaks = string.gsub(l.text, "\n", "")
		local t = Instance.new("TextLabel")
		t.LayoutOrder = i
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(0.94, 0, 0, math.ceil(font * pps * 1.1 * (breaks + 1)))
		t.Font = if i == 1 then Enum.Font.GothamBlack else Enum.Font.GothamBold
		t.TextSize = math.floor(font * pps)
		t.TextColor3 = l.color or C.white
		t.Text = l.text
		t.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = math.floor(font * pps)
		limit.Parent = t
		t.Parent = gui
	end
	gui.Parent = p
	return p
end

type SignOpts = { edge: number?, screen: boolean?, strip: boolean?, maxDist: number? }

-- A sign on the kit frame: black steel bezel, charcoal (or screen) panel, cool edge strip along
-- the bottom. pos/facing are the greybox sign's centre and facing; the panel face lands where
-- the greybox sign's front face was.
local function signFrame(
	parent: Instance,
	name: string,
	w: number,
	h: number,
	pos: Vector3,
	facing: Vector3,
	lines: { TLine },
	opts: SignOpts?
): Model
	local o: SignOpts = opts or {}
	local e = o.edge or math.clamp(math.min(w, h) * 0.07, 0.15, 0.4)
	local st = if o.strip == false then 0 else math.clamp(h * 0.05, 0.08, 0.3)
	local model = Instance.new("Model")
	model.Name = "Sign_" .. name
	local face = pos + facing.Unit * 0.15
	local base = CFrame.lookAt(face, face + facing) * CFrame.Angles(0, math.pi / 2, 0)
	local src = kit("RangeSignFrame")
	local function clone(part: string, size: Vector3, cf: CFrame): BasePart
		local p = (src:FindFirstChild("RangeSignFrame_" .. part) :: BasePart):Clone()
		p.Size = size
		p.CFrame = cf
		p.CastShadow = false
		p.Parent = model
		return p
	end
	clone("Bar", Vector3.new(0.6, e, w), base * CFrame.new(-0.15, h / 2 - e / 2, 0))
	clone("Bar", Vector3.new(0.6, e, w), base * CFrame.new(-0.15, -h / 2 + e / 2, 0))
	for _, s in { -1, 1 } do
		clone(
			"Bar",
			Vector3.new(0.6, e, h - 2 * e),
			base * CFrame.new(-0.15, 0, s * (w / 2 - e / 2)) * CFrame.Angles(math.pi / 2, 0, 0)
		)
	end
	local panel =
		clone("Panel", Vector3.new(0.3, h - 2 * e, w - 2 * e), base * CFrame.new(-0.15, 0, 0))
	if o.screen then
		panel.Color = C.screen
		panel.Material = Enum.Material.SmoothPlastic
		panel.Reflectance = 0.05
	end
	if st > 0 then
		clone(
			"Strip_Glow",
			Vector3.new(0.1, st, w - 2 * e),
			base * CFrame.new(0.0, -h / 2 + e + st / 2, 0)
		)
	end
	local th = h - 2 * e - st
	local tc = face + Vector3.new(0, st / 2, 0) + facing.Unit * 0.03
	textPart(model, "Text", w - 2 * e, th, CFrame.lookAt(tc, tc + facing), lines, o.maxDist)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Parent = parent
	return model
end

local function surfaceLight(
	parent: Instance,
	name: string,
	size: Vector3,
	pos: Vector3,
	face: Enum.NormalId,
	range: number,
	brightness: number,
	angle: number,
	color: Color3?
)
	local p = make(parent, name, size, CFrame.new(pos), C.white, {
		collide = false,
		shadow = false,
		transparency = 1,
	})
	local l = Instance.new("SurfaceLight")
	l.Face = face
	l.Range = range
	l.Brightness = brightness
	l.Angle = angle
	l.Color = color or DAY
	l.Shadows = false
	l.Parent = p
	return p
end

-- Shadowless SpotLight on an invisible holder at pos, aimed at target.
local function spot(
	parent: Instance,
	name: string,
	pos: Vector3,
	target: Vector3,
	range: number,
	brightness: number,
	angle: number,
	color: Color3?
)
	local p = make(parent, name, Vector3.new(1, 1, 1), CFrame.lookAt(pos, target), C.white, {
		collide = false,
		shadow = false,
		transparency = 1,
	})
	local l = Instance.new("SpotLight")
	l.Face = Enum.NormalId.Front
	l.Range = range
	l.Brightness = brightness
	l.Angle = angle
	l.Color = color or DAY
	l.Shadows = false
	l.Parent = p
	return p
end

-- Text painted flat on a floor (reads from the north, top of the text to the south).
local function floorText(
	parent: Instance,
	name: string,
	w: number,
	h: number,
	pos: Vector3,
	lines: { TLine },
	maxDist: number?
)
	return textPart(
		parent,
		name,
		w,
		h,
		CFrame.fromMatrix(pos, Vector3.xAxis, Vector3.zAxis),
		lines,
		maxDist
	)
end

-- Travel gates (ENTER RANGE, EXIT TO LOBBY) get thin cool glow lines round the opening's front
-- edge, so they read as the way through. (x, y, z): bottom centre of the opening's front face.
local function gateGlow(gate: Model, x: number, y: number, z: number)
	local o: PartOpts = { material = Enum.Material.Neon, collide = false, shadow = false }
	for _, s in { -1, 1 } do
		make(
			gate,
			"FrontGlow",
			Vector3.new(0.25, 10.4, 0.1),
			CFrame.new(x + s * 6.3, y + 5.2, z),
			DAY,
			o
		)
	end
	make(gate, "FrontGlow", Vector3.new(12.85, 0.25, 0.1), CFrame.new(x, y + 10.3, z), DAY, o)
end

-- Hub side: Wing_Range -> Art.Range -------------------------------------------------------

local function artHub()
	local g = wingG :: Instance
	local f = artSection("Range")

	-- Descent: two steel portal frames, board-formed walls, honed ramp.
	hideAll(g, { "FrameJamb", "FrameHead" })
	for _, z in { 82, 96 } do
		put(f, "RangeFrame", faceCF(Vector3.new(0, FY - 2, z), SOUTH), "RangeFrame")
	end
	finishAll(g, { "Ramp" }, "ConcreteHoned")
	finishAll(g, { "RampLine" }, "LinePaint")
	finishAll(g, { "DescentLip" }, "ConcreteDark")
	finishAll(
		g,
		{ "DescentWall", "Lintel", "NorthWall", "Chamfer", "SideWall", "Soffit" },
		"ConcreteBoard"
	)
	finishAll(
		g,
		{ "Pilaster", "Beam", "SouthWallW", "SouthWallE", "GateHead", "CoreWall", "Header" },
		"ConcreteBoard"
	)
	finishAll(g, { "DescentCeiling", "HallRoof", "MiniRoof", "VestibuleRoof" }, "ConcreteShade")
	finishAll(g, { "HallFloor" }, "ConcretePolished")
	finishAll(g, { "Sill", "VestibuleFloor" }, "ConcreteHoned")
	finishAll(g, { "VestibuleWallW", "VestibuleWallE", "VestibuleBack" }, "ConcreteBoard")
	finishAll(g, { "HallFiringLine" }, "SafetyYellow")
	-- The old guide strips (and the return pad) are collision 0.06-0.1 proud of the floor: they
	-- take the hall floor's own look, and a thin cool light line in a brushed channel on top of
	-- them does the guiding, from the ramp foot along the west aisle into the ENTER RANGE gate.
	finishAll(g, { "GuideBand", "GuideLink", "ReturnPad" }, "ConcretePolished")
	local guide = Instance.new("Model")
	guide.Name = "GuideLine"
	local function guideRun(a: Vector3, b: Vector3, top: number)
		local d = flat(b - a)
		local mid = flat(a + b) / 2
		local cf =
			CFrame.lookAt(Vector3.new(mid.X, top + 0.01, mid.Z), Vector3.new(b.X, top + 0.01, b.Z))
		local ch = make(guide, "Channel", Vector3.new(0.8, 0.02, d.Magnitude), cf, C.white, {
			collide = false,
			shadow = false,
		})
		finish(ch, "SteelBrushed")
		make(
			guide,
			"Line_Glow",
			Vector3.new(0.3, 0.02, d.Magnitude),
			cf + Vector3.new(0, 0.01, 0),
			DAY,
			{
				material = Enum.Material.Neon,
				collide = false,
				shadow = false,
			}
		)
	end
	local link = g:FindFirstChild("GuideLink") :: BasePart?
	if link then
		local half = link.CFrame.LookVector * (link.Size.Z / 2 - 0.6)
		local top = link.Position.Y + link.Size.Y / 2
		guideRun(link.Position - half, link.Position + half, top)
	end
	guideRun(Vector3.new(-43, 0, 120.6), Vector3.new(-43, 0, 196), FY + 0.06)
	guideRun(Vector3.new(-43, 0, 196), Vector3.new(-43, 0, 200.2), FY + 0.04)
	-- Return pad: a cool ring round the pad where players come back from the range.
	for _, r in
		{
			{ 0, -2.85, 6.3, 0.3 },
			{ 0, 2.85, 6.3, 0.3 },
			{ -2.85, 0, 0.3, 5.4 },
			{ 2.85, 0, 0.3, 5.4 },
		}
	do
		make(
			guide,
			"ReturnRing_Glow",
			Vector3.new(r[3], 0.02, r[4]),
			CFrame.new(-56 + r[1], FY + 0.07, 186 + r[2]),
			DAY,
			{ material = Enum.Material.Neon, collide = false, shadow = false }
		)
	end
	guide.Parent = f

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = f
	for _, s in { -1, 1 } do
		local side = Vector3.new(-s, 0, 0)
		panelWall(walls, Vector3.new(s * 14, 0, 70), Vector3.new(s * 14, 0, 104), -10, 16, side)
		-- Hall: north wall either side of the lintel, the chamfers, the side walls.
		panelWall(walls, Vector3.new(s * 14, 0, 106), Vector3.new(s * 36, 0, 106), FY, 20, SOUTH)
		plinth(walls, Vector3.new(s * 14, 0, 106), Vector3.new(s * 36, 0, 106), FY, SOUTH)
		local c0 = Vector3.new(s * 36, 0, 105)
		local c1 = Vector3.new(s * 63, 0, 132)
		local inward = Vector3.new(-s, 0, 1).Unit
		panelWall(walls, c0 + inward * 1, c1 + inward * 1, FY, 20, inward)
		plinth(walls, c0 + inward * 1, c1 + inward * 1, FY, inward)
		panelWall(walls, Vector3.new(s * 62, 0, 132), Vector3.new(s * 62, 0, 198), FY, 14, side)
		plinth(walls, Vector3.new(s * 62, 0, 132), Vector3.new(s * 62, 0, 198), FY, side)
		-- The core block's outer walls (the aisles either side of the scale model).
		panelWall(
			walls,
			Vector3.new(s * 24, 0, 130),
			Vector3.new(s * 24, 0, 198),
			FY,
			20,
			Vector3.new(s, 0, 0)
		)
		plinth(
			walls,
			Vector3.new(s * 24, 0, 130),
			Vector3.new(s * 24, 0, 198),
			FY,
			Vector3.new(s, 0, 0)
		)
	end
	-- South wall bays (between the gate, the core and the status frame) and over the gate.
	for _, seg in { { -62, -51 }, { -35, -24 }, { 24, 62 } } do
		local a, b = Vector3.new(seg[1], 0, 198), Vector3.new(seg[2], 0, 198)
		panelWall(walls, a, b, FY, 20, NORTH)
		plinth(walls, a, b, FY, NORTH)
	end
	panelWall(walls, Vector3.new(-51, 0, 198), Vector3.new(-35, 0, 198), FY + 12, 20, NORTH)
	-- Header over the viewing window (the RANGE title hangs on it).
	panelWall(walls, Vector3.new(-24, 0, 130), Vector3.new(24, 0, 130), 4, 20, NORTH)

	-- Cool light rails along the core block's outer walls (they lead the eye to the gate and the
	-- status screen) and an info screen opposite each bench.
	local frameSrc = kit("RangeSignFrame")
	for _, s in { -1, 1 } do
		local rail = Instance.new("Model")
		rail.Name = "CoreLightRail"
		local base = CFrame.lookAt(
			Vector3.new(s * 24.27, FY + 9, 164),
			Vector3.new(s * 30, FY + 9, 164)
		) * CFrame.Angles(0, math.pi / 2, 0)
		local bar = (frameSrc:FindFirstChild("RangeSignFrame_Bar") :: BasePart):Clone()
		bar.Size = Vector3.new(0.3, 0.3, 64)
		bar.CFrame = base
		bar.CastShadow = false
		bar.Parent = rail
		local glow = (frameSrc:FindFirstChild("RangeSignFrame_Strip_Glow") :: BasePart):Clone()
		glow.Size = Vector3.new(0.2, 0.06, 63.6)
		glow.CFrame = base * CFrame.new(0, -0.18, 0)
		glow.Parent = rail
		rail.Parent = f
	end
	signFrame(f, "InsideBoard", 10, 6, Vector3.new(24.25, FY + 5, 160), EAST, {
		{ text = "INSIDE THE RANGE", cap = 0.9 },
		{
			text = "7 LANES  ·  10 TO 150\nMOVEMENT COURSE\nCOVER + ABILITY YARD",
			cap = 0.7,
			color = MUTED,
		},
	}, { screen = true, edge = 0.25 })
	signFrame(f, "HowBoard", 10, 6, Vector3.new(-24.25, FY + 5, 160), WEST, {
		{ text = "HOW IT WORKS", cap = 0.9 },
		{
			text = "STEP THROUGH THE GATE\nPRACTISE FREELY\nEXIT TO COME BACK",
			cap = 0.7,
			color = MUTED,
		},
	}, { screen = true, edge = 0.25 })

	-- Benches.
	hideAll(g, { "Bench" })
	for _, s in { -1, 1 } do
		put(f, "RangeBench", faceCF(Vector3.new(s * 26.5, FY, 160), Vector3.new(-s, 0, 0)), "Bench")
	end

	-- Viewing window and the 1:3 scale model behind it.
	hideAll(g, { "ViewingGlass", "Mullion", "Rail", "RailPost" })
	hideAll(
		g,
		{ "MiniLane", "MiniFiringLine", "MiniCounter", "MiniStall", "MiniBacker", "MiniTarget" }
	)
	hideAll(g, { "MiniTargetHead", "MiniBerm" })
	for _, d in { 10, 25, 50, 100, 150 } do
		hideAll(g, { "MiniMark" .. d, "MiniBoard" .. d })
	end
	local window = put(f, "ViewingWindow", faceCF(Vector3.new(0, FY, 131), NORTH), "ViewingWindow")
	-- Glass material hides SurfaceGuis behind it (the model's signs), so the pane is a clear
	-- tinted SmoothPlastic sheet instead.
	local pane = window:FindFirstChild("ViewingWindow_Glass") :: BasePart
	pane.Material = Enum.Material.SmoothPlastic
	pane.Color = Color3.fromHex("DCE6EA")
	pane.Transparency = 0.86
	pane.Reflectance = 0.05
	local mini = put(f, "ScaleModel", faceCF(Vector3.new(0, FY, 165), NORTH), "ScaleModel")
	-- The diorama's yards (cover + ability on the viewer's left, movement course on the right).
	local yards = put(f, "ScaleModelYards", faceCF(Vector3.new(0, FY, 165), NORTH))
	for _, d in yards:GetChildren() do
		d.Parent = mini
	end
	yards:Destroy()
	local fz = 135
	-- Lane numbers painted on the floor between the 10 and 25 lines (the sill hides the floor
	-- nearer the window; nothing tall stands in front of the lanes). They run east to west: the
	-- viewer looks downrange like a shooter, lane 1 on the left.
	for i = 1, 7 do
		floorText(
			mini,
			"LaneNo" .. i,
			2.6,
			2.2,
			Vector3.new(12 - 3 * i, FY + 0.09, fz + 6.6),
			{ { text = tostring(i), cap = 1.5, color = YELLOW } },
			90
		)
	end
	-- Yard names painted on the yard floors.
	floorText(mini, "CoverLabel", 8.6, 1.2, Vector3.new(16.7, FY + 0.09, 151.5), {
		{ text = "COVER", cap = 0.9, color = YELLOW },
	}, 90)
	floorText(mini, "AbilityLabel", 8.6, 1.2, Vector3.new(16.7, FY + 0.09, 162), {
		{ text = "ABILITIES", cap = 0.9, color = YELLOW },
	}, 90)
	floorText(mini, "CourseLabel", 8.6, 1.2, Vector3.new(-16.7, FY + 0.09, 189.5), {
		{ text = "MOVEMENT", cap = 0.9, color = YELLOW },
	}, 90)
	textPart(
		mini,
		"MiniTitle",
		27.6,
		3.2,
		CFrame.lookAt(Vector3.new(0, FY + 9.8, 197.58), Vector3.new(0, FY + 9.8, 196)),
		{
			{ text = "PRACTICE RANGE", cap = 1.5 },
			{ text = "LANES  10 · 25 · 50 · 100 · 150", cap = 0.55, color = MUTED },
		},
		80
	)
	local boards =
		{ { 10, 1.1, 3.4 }, { 25, 1.3, 3.8 }, { 50, 1.5, 4.2 }, { 100, 1.7, 5 }, { 150, 1.9, 5.6 } }
	for _, b in boards do
		local d, cap, w = b[1], b[2], b[3]
		local z = fz + d / 3
		local h = cap * 1.6
		for _, s in { -1, 1 } do
			local x = s * (21.8 - w / 2)
			signFrame(
				f,
				"MiniBoard" .. d,
				w,
				h,
				Vector3.new(x, 1.5, z),
				NORTH,
				{ { text = tostring(d), cap = cap, color = if d >= 100 then YELLOW else nil } },
				{ edge = 0.15, maxDist = 90 }
			)
			for _, k in { -1, 1 } do
				rod(f, x + k * (w / 2 - 0.5), z + 0.15, 1.5 + h / 2, 4, 0.06)
			end
		end
	end

	-- Signs on kit frames (the greybox signs keep their positions; their panels are hidden).
	hideAll(
		g,
		{ "RangeTitle", "ScalePlaque", "EnterSign", "TransferPanel", "ReturnLabel", "StatusScreen" }
	)
	signFrame(f, "RangeTitle", 42, 11, Vector3.new(0, 12.5, 129.8), NORTH, {
		{ text = "RANGE", cap = 5 },
		{ text = "PRACTICE LANES  ·  MOVEMENT  ·  ABILITIES", cap = 1.3, color = MUTED },
	}, { maxDist = 250 })
	signFrame(
		f,
		"ScalePlaque",
		12,
		1.6,
		Vector3.new(0, FY + 1.6, 129.8),
		NORTH,
		{ { text = "SCALE MODEL  1:3", cap = 0.8 } },
		{ edge = 0.15, strip = false, maxDist = 60 }
	)
	signFrame(f, "EnterSign", 20, 5, Vector3.new(-43, FY + 15, 197.75), NORTH, {
		{ text = "ENTER RANGE", cap = 2.6 },
		{ text = "LANES  ·  MOVEMENT  ·  ABILITIES", cap = 1, color = MUTED },
	}, { maxDist = 150 })
	signFrame(f, "TransferPanel", 10, 6, Vector3.new(-43, FY + 5, 213.8), NORTH, {
		{ text = "RANGE", cap = 1.6 },
		{ text = "STEP IN TO TRAVEL", cap = 1, color = MUTED },
	}, { screen = true })
	signFrame(
		f,
		"ReturnLabel",
		9,
		2,
		Vector3.new(-61.75, FY + 7, 186),
		EAST,
		{ { text = "RETURN POINT", cap = 1.2 } },
		{ edge = 0.2 }
	)

	-- ENTER RANGE gate and the matching status frame.
	hideAll(
		g,
		{ "GateJambW", "GateJambE", "GateFrameHead", "GateGlowW", "GateGlowE", "GateGlowTop" }
	)
	hideAll(g, { "StatusJambW", "StatusJambE", "StatusHead" })
	gateGlow(
		put(f, "EnterGate", faceCF(Vector3.new(-43, FY, 198), NORTH), "EnterGate"),
		-43,
		FY,
		195.75
	)
	put(f, "EnterGate", faceCF(Vector3.new(43, FY, 198), NORTH), "StatusFrame")
	signFrame(f, "StatusScreen", 11.6, 9.6, Vector3.new(43, FY + 5, 197.75), NORTH, {
		{ text = "RANGE STATUS", cap = 1.6 },
		{ text = "LANES OPEN  7 / 7\nIN RANGE  0 / 30", cap = 1.2, color = MUTED },
	}, { screen = true, edge = 0.2 })

	-- East aisle lounge: the RANGE RECORDS board on the side wall, a bench facing it, planters
	-- either side of the status screen and a light pool, so the aisle is a place to wait and
	-- watch, not a dead end. Bench and planters collide through one invisible block each.
	local lounge = Instance.new("Folder")
	lounge.Name = "Lounge"
	lounge.Parent = f
	signFrame(lounge, "RecordsBoard", 18, 9, Vector3.new(61.7, FY + 6.4, 185), WEST, {
		{ text = "RANGE RECORDS", cap = 1.5 },
		{
			text = "MOVEMENT COURSE    --:--\nLONGEST HIT    --- STUDS\nBEST 150 GROUP    --",
			cap = 0.95,
			color = MUTED,
		},
	}, { screen = true, edge = 0.25 })
	local bench = put(lounge, "RangeBench", faceCF(Vector3.new(52, FY, 185), EAST), "Bench")
	stretch(bench, 1, 1, 0.6)
	blocker(lounge, "BenchBlock", Vector3.new(3, 1.5, 12), CFrame.new(52, FY + 0.75, 185))
	for _, x in { 30, 56 } do
		put(lounge, "RangePlanter", faceCF(Vector3.new(x, FY, 196.35), NORTH), "Planter")
		blocker(
			lounge,
			"PlanterBlock",
			Vector3.new(8.2, 1.95, 2.6),
			CFrame.new(x, FY + 0.975, 196.35)
		)
	end
	put(lounge, "RangePlanter", faceCF(Vector3.new(60.2, FY, 160), WEST), "Planter")
	blocker(lounge, "PlanterBlock", Vector3.new(2.6, 1.95, 8.2), CFrame.new(60.2, FY + 0.975, 160))

	-- Lights (6, all shadowless): the model's daylight, the facade wash, the gate, a cool
	-- down-light over each aisle (on the ceiling slot lines; their spill grazes the side walls)
	-- and the lounge pool at the status screen.
	local lights = Instance.new("Folder")
	lights.Name = "Lights"
	lights.Parent = f
	surfaceLight(
		lights,
		"MiniDaylight",
		Vector3.new(42, 0.2, 60),
		Vector3.new(0, 3.4, 165),
		Enum.NormalId.Bottom,
		16,
		1,
		90
	)
	surfaceLight(
		lights,
		"FacadeWash",
		Vector3.new(60, 0.2, 14),
		Vector3.new(0, 19.6, 120),
		Enum.NormalId.Bottom,
		40,
		1.4,
		60
	)
	local gl =
		make(lights, "GateGlow", Vector3.new(1, 1, 1), CFrame.new(-43, FY + 5, 195), C.white, {
			collide = false,
			shadow = false,
			transparency = 1,
		})
	local pl = Instance.new("PointLight")
	pl.Range = 26
	pl.Brightness = 1.6
	pl.Color = DAY
	pl.Shadows = false
	pl.Parent = gl
	for _, s in { -1, 1 } do
		spot(
			lights,
			if s < 0 then "AisleW" else "AisleE",
			Vector3.new(s * 42, 19.4, 151),
			Vector3.new(s * 44, FY, 166),
			40,
			1.6,
			130
		)
	end
	local ll =
		make(lights, "LoungeGlow", Vector3.new(1, 1, 1), CFrame.new(46, FY + 9, 189), C.white, {
			collide = false,
			shadow = false,
			transparency = 1,
		})
	local lp = Instance.new("PointLight")
	lp.Range = 18
	lp.Brightness = 1.2
	lp.Color = DAY
	lp.Shadows = false
	lp.Parent = ll

	publishArt(f)
end

-- The real range: RangeFar -> Art.RangeFar --------------------------------------------------

local function artFar()
	local g = farG :: Instance
	local f = artSection("RangeFar")

	finishAll(g, { "Floor" }, "RangeFloor")
	finishAll(
		g,
		{ "WallSide", "WallNorth", "WallSouth", "Pilaster", "LongPlatform", "LaneWall" },
		"ConcreteBoard"
	)
	finishAll(g, { "SolidWall", "Pillar", "JumpBox", "GapPlatform", "CrouchWall" }, "ConcreteBoard")
	finishAll(
		g,
		{ "Canopy", "CanopyColumn", "ExitWallW", "ExitWallE", "ExitRoof" },
		"ConcreteBoard"
	)
	finishAll(g, { "GuideWallW", "GuideWallE", "GuideRoof" }, "ConcreteBoard")
	finishAll(g, { "RoofN", "RoofS", "RoofBand" }, "ConcreteShade")
	finishAll(g, { "Lane1", "Lane3", "Lane5", "Lane7", "Track" }, "LaneLight")
	finishAll(g, { "LaneLine" }, "LinePaint")
	finishAll(g, { "FiringLine", "LongPlatformEdge", "CoverLine" }, "SafetyYellow")
	finishAll(g, { "ShooterStrip" }, "RubberMat")
	finishAll(g, { "CoverYard" }, "ConcreteDark")
	finishAll(g, { "AbilityYard" }, "AbilityFloor")
	finishAll(g, { "Course" }, "CourseFloor")
	finishAll(g, { "ThinWall" }, "SteelPlate")
	edge(f, Vector3.new(-81, 9, 1194.15), Vector3.new(-71, 9, 1194.15), SOUTH)
	finishAll(g, { "ArrivalPad" }, "ConcretePolished")

	-- Walls: formwork panels and plinths all round.
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = f
	for _, s in { -1, 1 } do
		local a, b = Vector3.new(s * 120, 0, 1012), Vector3.new(s * 120, 0, 1296)
		panelWall(walls, a, b, 0, 36, Vector3.new(-s, 0, 0))
		plinth(walls, a, b, 0, Vector3.new(-s, 0, 0))
	end
	panelWall(walls, Vector3.new(-120, 0, 1012), Vector3.new(120, 0, 1012), 0, 36, SOUTH)
	plinth(walls, Vector3.new(-120, 0, 1012), Vector3.new(120, 0, 1012), 0, SOUTH)
	panelWall(walls, Vector3.new(-120, 0, 1296), Vector3.new(120, 0, 1296), 0, 36, NORTH)

	-- Roof trusses (10 x 24 per line) with light bars over the lanes.
	hideAll(g, { "Truss" })
	local roof = Instance.new("Folder")
	roof.Name = "Roof"
	roof.Parent = f
	for z = 1060, 1240, 36 do
		for k = 0, 9 do
			put(roof, "RangeTruss", faceCF(Vector3.new(-108 + 24 * k, 33, z), NORTH), "Truss")
		end
		for x = -36, 36, 12 do
			put(roof, "RangeLightBar", faceCF(Vector3.new(x, 33, z), NORTH), "LightBar")
		end
	end
	-- Skylights: the three roof sun slots (4 x 150) read as cool diffuser strips in black steel
	-- trims instead of raw sky. The diffusers cast no shadow, so the sun shafts still reach the lanes.
	local trimSrc = kit("RangeSignFrame"):FindFirstChild("RangeSignFrame_Bar") :: BasePart
	for _, x in { -24, 0, 24 } do
		local sky = Instance.new("Model")
		sky.Name = "Skylight"
		make(sky, "Diffuser", Vector3.new(4, 0.1, 150), CFrame.new(x, 35.98, 1125), DAY, {
			material = Enum.Material.Neon,
			collide = false,
			shadow = false,
			transparency = 0.25,
		})
		for _, s in { -1, 1 } do
			local t = trimSrc:Clone()
			t.Name = "Trim"
			t.CFrame = CFrame.new(x + s * 2.2, 35.8, 1125) * CFrame.Angles(0, math.pi / 2, 0)
			t.Size = Vector3.new(0.5, 0.5, 150.5)
			t.CastShadow = false
			t.Parent = sky
		end
		sky.Parent = roof
	end

	-- Lanes: dividers, header beam with lane numbers, steel silhouettes, berm, distance markers.
	local lanes = Instance.new("Folder")
	lanes.Name = "Lanes"
	lanes.Parent = f
	hideAll(g, { "Stall", "Target", "TargetHead", "Berm", "BermSlope", "MarkerPost" })
	for k = 0, 7 do
		put(
			lanes,
			"LaneDivider",
			faceCF(Vector3.new(-42 + 12 * k, 0, FL + 3.5), NORTH),
			"LaneDivider"
		)
	end
	local beam = Instance.new("Model")
	beam.Name = "LaneHeader"
	local bar = (kit("RangeSignFrame"):FindFirstChild("RangeSignFrame_Bar") :: BasePart):Clone()
	bar.Size = Vector3.new(0.6, 0.6, 85)
	bar.CFrame = CFrame.new(0, 7.3, FL + 3) * CFrame.Angles(0, math.pi / 2, 0)
	bar.Parent = beam
	local line = (kit("RangeSignFrame"):FindFirstChild("RangeSignFrame_Strip_Glow") :: BasePart):Clone()
	line.Size = Vector3.new(0.3, 0.05, 84)
	line.CFrame = CFrame.new(0, 6.97, FL + 3) * CFrame.Angles(0, math.pi / 2, 0)
	line.Parent = beam
	beam.Parent = lanes
	each(g, "LaneNumber", hide)
	for i = 1, 7 do
		signFrame(
			lanes,
			"LaneNumber" .. i,
			4,
			2.4,
			Vector3.new(-48 + 12 * i, 8.8, FL + 3),
			SOUTH,
			{ { text = tostring(i), cap = 1.5, color = YELLOW } },
			{ edge = 0.2, maxDist = 120 }
		)
	end
	for i, d in { 10, 25, 50, 150, 100, 50, 25 } do
		put(
			lanes,
			"TargetStand",
			faceCF(Vector3.new(-48 + 12 * i, 0, FL - d), SOUTH),
			"TargetStand"
		)
	end
	for _, cx in { -36, -12, 12, 36 } do
		put(lanes, "Berm", faceCF(Vector3.new(cx, 0, 1037), SOUTH), "Berm")
	end
	edge(lanes, Vector3.new(-46, 4, FL - 170), Vector3.new(-46, 4, FL - 8), EAST)
	edge(lanes, Vector3.new(46, 4, FL - 170), Vector3.new(46, 4, FL - 8), WEST)
	local big = {
		{ 10, 2, 0, 22 },
		{ 25, 2.6, -20, 22 },
		{ 50, 3.5, 20, 24 },
		{ 100, 5, -20, 24 },
		{ 150, 6.5, 20, 8 },
	}
	for _, m in big do
		local d, cap, x, baseY = m[1], m[2], m[3], m[4]
		local z = FL - d
		local text = tostring(d)
		local h = cap * 1.7
		local w = cap * (#text * 0.95 + 0.8)
		hideAll(g, { "Marker" .. d, "MarkerSmall" .. d })
		each(g, "MarkLine" .. d, function(p)
			finish(p, "LinePaint")
		end)
		signFrame(
			lanes,
			"Marker" .. d,
			w,
			h,
			Vector3.new(x, baseY + h / 2, z),
			SOUTH,
			{ { text = text, cap = cap, color = if d >= 100 then YELLOW else nil } },
			{ maxDist = 250 }
		)
		for _, k in { -1, 1 } do
			rod(lanes, x + k * (w / 2 - 0.6), z - 0.1, baseY + h, 36, 0.1)
		end
		for _, s in { -1, 1 } do
			local post = put(
				lanes,
				"DistancePost",
				faceCF(Vector3.new(s * 44.5, 0, z), SOUTH),
				"DistancePost"
			)
			local tc = Vector3.new(s * 44.5, 6.08, z + 0.12)
			textPart(
				post,
				"Text",
				3.0,
				1.35,
				CFrame.lookAt(tc, tc + SOUTH),
				{ { text = text, cap = 1.2 } },
				50
			)
		end
	end

	-- Cover + ability yard (west) and movement course (east).
	local yard = Instance.new("Folder")
	yard.Name = "Yards"
	yard.Parent = f
	hideAll(g, { "LowCover", "CoverSign", "AbilitySign", "CourseSign" })
	put(yard, "JerseyBarrier", faceCF(Vector3.new(-62, 0, FL - 25.25), SOUTH), "JerseyBarrier")
	edge(yard, Vector3.new(-99, 9, FL - 22.5), Vector3.new(-89, 9, FL - 22.5), SOUTH)
	for _, x in { -100, -80, -60 } do
		edge(yard, Vector3.new(x - 1.5, 10, FL - 8.5), Vector3.new(x + 1.5, 10, FL - 8.5), SOUTH)
	end
	for i, hh in { 2, 3.5, 5, 6.5 } do
		local z = FL - 4 - i * 9
		edge(yard, Vector3.new(77, hh, z + 3), Vector3.new(83, hh, z + 3), SOUTH)
	end
	for _, p in
		{ { FL - 30, FL - 20 }, { FL - 44, FL - 36 }, { FL - 62, FL - 54 }, { FL - 83, FL - 75 } }
	do
		edge(yard, Vector3.new(94, 3, p[2]), Vector3.new(102, 3, p[2]), SOUTH)
		edge(yard, Vector3.new(94, 3, p[1]), Vector3.new(102, 3, p[1]), NORTH)
	end
	for i = 0, 2 do
		local wz = FL - 120 - i * 14
		edge(yard, Vector3.new(75, 3.2, wz + 0.6), Vector3.new(85, 3.2, wz + 0.6), SOUTH)
	end
	-- Sprint track ticks every 10 studs (paint, 0.02 on the track, no collision).
	local ticks = Instance.new("Model")
	ticks.Name = "TrackTicks"
	for z = 1100, 1250, 10 do
		local p = box(ticks, "Tick", 57.2, 66.8, 0.1, 0.12, z - 0.15, z + 0.15, C.white, {
			collide = false,
			shadow = false,
		})
		finish(p, if z % 50 == 0 then "SafetyYellow" else "LinePaint")
	end
	ticks.Parent = yard
	signFrame(yard, "CoverSign", 22, 4, Vector3.new(-80, 9, FL + 8), SOUTH, {
		{ text = "COVER + ABILITY YARD", cap = 1.8 },
	})
	signFrame(yard, "AbilitySign", 18, 3, Vector3.new(-80, 6, FL - 64), SOUTH, {
		{ text = "ABILITY TEST SPACE", cap = 1.4 },
	})
	signFrame(yard, "CourseSign", 22, 4, Vector3.new(80, 9, FL + 44), SOUTH, {
		{ text = "MOVEMENT COURSE", cap = 1.8 },
	})
	for _, k in { -1, 1 } do
		rod(yard, -80 + k * 10.4, FL + 7.9, 11, 36, 0.1)
		rod(yard, -80 + k * 8.4, FL - 63.9, 7.5, 36, 0.1)
		rod(yard, 80 + k * 10.4, FL + 43.9, 11, 36, 0.1)
	end
	-- Dressing against the walls, out of every walking line.
	for _, z in { 1176, 1186 } do
		put(yard, "JerseyBarrier", faceCF(Vector3.new(-116.6, 0, z), EAST), "WallBarrier")
	end
	for _, c in
		{
			{ -116.4, 1252, 0 },
			{ -116.4, 1256.5, 0 },
			{ -116.4, 1254.2, 2.2 },
			{ 116.4, 1150, 0 },
			{ 116.4, 1154.5, 0 },
		}
	do
		put(
			yard,
			"RangeCrate",
			faceCF(Vector3.new(c[1], c[3], c[2]), Vector3.new(-math.sign(c[1]), 0, 0)),
			"Crate"
		)
	end
	-- The meshes never collide: each barrier and crate stack gets one invisible block (deliberate).
	for _, z in { 1176, 1186 } do
		blocker(yard, "BarrierBlock", Vector3.new(2, 3.6, 8), CFrame.new(-116.6, 1.8, z))
	end
	blocker(yard, "CrateBlock", Vector3.new(2.4, 4.4, 8.5), CFrame.new(-116.4, 2.2, 1254.25))
	blocker(yard, "CrateBlock", Vector3.new(2.4, 2.2, 8.5), CFrame.new(116.4, 1.1, 1152.25))

	-- Arrival: wayfinding under the canopy, the EXIT TO LOBBY gate, the guide niche.
	local arrival = Instance.new("Folder")
	arrival.Name = "Arrival"
	arrival.Parent = f
	-- Walkways: charcoal rubber bands (like the shooter strip) from the arrival pad to the cover
	-- yard and the movement course. Paint only: 0.04 thick on the floor, no collision.
	local walk = Instance.new("Model")
	walk.Name = "Walkways"
	local function band(x0: number, x1: number, z0: number, z1: number)
		local p = box(walk, "Walkway", x0, x1, 0, 0.04, z0, z1, C.white, {
			collide = false,
			shadow = false,
		})
		finish(p, "RubberMat")
	end
	band(-56, -7.6, 1276, 1280)
	band(-56, -52, 1218.5, 1276)
	band(7.6, 82, 1276, 1280)
	band(78, 82, 1253.5, 1276)
	walk.Parent = arrival
	hideAll(g, {
		"Wayfinding",
		"ExitSign",
		"ExitPanel",
		"GuideBoard",
		"Title",
		"ExitGlowW",
		"ExitGlowE",
		"ExitGlowTop",
	})
	for _, w in { { -32, "<  COVER YARD" }, { 0, "LANES  1 - 7" }, { 32, "MOVEMENT  >" } } do
		local x = w[1] :: number
		signFrame(
			arrival,
			"Wayfinding",
			20,
			4,
			Vector3.new(x, 12, 1263),
			SOUTH,
			{ { text = w[2] :: string, cap = 1.8 } },
			{ maxDist = 150 }
		)
		for _, k in { -1, 1 } do
			rod(arrival, x + k * 8, 1262.9, 14, 16, 0.08)
		end
	end
	gateGlow(
		put(arrival, "EnterGate", faceCF(Vector3.new(32, 0, 1284), NORTH), "ExitGate"),
		32,
		0,
		1281.75
	)
	signFrame(
		arrival,
		"ExitSign",
		14,
		3.2,
		Vector3.new(32, 14, 1281.75),
		NORTH,
		{ { text = "EXIT TO LOBBY", cap = 2.2 } }
	)
	for _, k in { -1, 1 } do
		rod(arrival, 32 + k * 5.5, 1281.9, 15.6, 16, 0.08)
	end
	signFrame(arrival, "ExitPanel", 10, 6, Vector3.new(32, 5, 1295.8), NORTH, {
		{ text = "LOBBY", cap = 1.6 },
		{ text = "STEP IN TO RETURN", cap = 1, color = MUTED },
	}, { screen = true })
	signFrame(arrival, "GuideBoard", 12, 9, Vector3.new(-32, 5, 1295.8), NORTH, {
		{ text = "RANGE GUIDE", cap = 1.4 },
		{
			text = "AHEAD: LANES, DUMMIES 10-150\nLEFT: COVER + ABILITIES\nRIGHT: MOVEMENT COURSE",
			cap = 1,
			color = MUTED,
		},
	}, { screen = true })
	signFrame(arrival, "Title", 84, 11, Vector3.new(0, 29.5, 1012.25), SOUTH, {
		{ text = "PRACTICE RANGE", cap = 7 },
		{ text = "LANES  10 · 25 · 50 · 100 · 150", cap = 1.8, color = MUTED },
	}, { maxDist = 300 })

	-- Lights (9, shadowless). No single hall-sized light: a big SurfaceLight sits its source far
	-- behind its face and barely reaches the floor. Instead: two wide down-lights over the lanes,
	-- one over each yard and two over the course, a wash on the berm, one under the arrival canopy
	-- and one in the exit alcove. The hall is 36 tall, so the down-lights need Range 60 and a high
	-- Brightness (the falloff over 31 studs leaves only a fraction at the floor). Studio's light
	-- update lags a big camera jump by a few seconds: judge captures after the view has settled.
	local lights = Instance.new("Folder")
	lights.Name = "Lights"
	lights.Parent = f
	local down = Vector3.new(0, -1, 0)
	for _, l in
		{
			{ "LanesNear", Vector3.new(0, 32, 1228), 60, 3.5, 120 },
			{ "LanesFar", Vector3.new(0, 32, 1150), 60, 3.5, 120 },
			{ "CoverYard", Vector3.new(-80, 31, 1186), 60, 3, 115 },
			{ "AbilityYard", Vector3.new(-80, 31, 1106), 60, 3, 115 },
			{ "CourseNear", Vector3.new(80, 31, 1200), 60, 3, 115 },
			{ "CourseFar", Vector3.new(80, 31, 1100), 60, 3, 115 },
		}
	do
		local pos = l[2] :: Vector3
		spot(
			lights,
			l[1] :: string,
			pos,
			pos + down,
			l[3] :: number,
			l[4] :: number,
			l[5] :: number
		)
	end
	spot(lights, "BermWash", Vector3.new(0, 22, 1080), Vector3.new(0, 7, 1036), 60, 4, 110)
	spot(lights, "CanopyLight", Vector3.new(0, 15.6, 1279), Vector3.new(0, 0, 1279), 24, 2.5, 150)
	-- A small pool inside the EXIT TO LOBBY alcove (its roof shades it from the canopy light).
	local exitGlow =
		make(lights, "ExitGlow", Vector3.new(1, 1, 1), CFrame.new(32, 8, 1291), C.white, {
			collide = false,
			shadow = false,
			transparency = 1,
		})
	local ep = Instance.new("PointLight")
	ep.Range = 14
	ep.Brightness = 1.4
	ep.Color = DAY
	ep.Shadows = false
	ep.Parent = exitGlow

	publishArt(f)
end

artHub()
artFar()

-- Ambience tags (the ENTER RANGE pulse, the status screen scan, two flickering bars).
do
	local art = (workspace:FindFirstChild("Lobby") :: Instance):FindFirstChild("Art") :: Instance
	local hub = art:FindFirstChild("Range") :: Instance
	for _, m in hub:GetChildren() do
		if m.Name == "EnterGate" and m:IsA("Model") and m:GetPivot().Position.X < 0 then
			for _, d in m:GetChildren() do
				if
					d:IsA("BasePart")
					and (d.Name == "EnterGate_Light_Glow" or d.Name == "FrontGlow")
				then
					ambTag(d, "Lobby_Pulse", {
						AmbPeriod = 4,
						AmbDepth = if d.Name == "FrontGlow" then 0.35 else 0.25,
					})
				end
			end
		end
	end
	local gateLight = (hub:FindFirstChild("Lights") :: Instance):FindFirstChild(
			"GateGlow"
		) :: Instance
	ambTag(
		gateLight:FindFirstChildWhichIsA("Light") :: Instance,
		"Lobby_Pulse",
		{ AmbPeriod = 4, AmbDepth = 0.35 }
	)
	local status = (hub:FindFirstChild("Sign_StatusScreen") :: Instance):FindFirstChild(
			"Text"
		) :: Instance
	ambTag(status, "Lobby_LedScreen", {
		AmbFace = "Front",
		AmbStyle = "Scan",
		AmbColor = Color3.fromHex("BFE3FF"),
		AmbPeriod = 5,
	})
	local roof = (art:FindFirstChild("RangeFar") :: Instance):FindFirstChild("Roof") :: Instance
	for _, want in { Vector3.new(36, 33, 1240), Vector3.new(-36, 33, 1060) } do
		for _, m in roof:GetChildren() do
			if m:IsA("Model") and (m:GetPivot().Position - want).Magnitude < 1 then
				for _, d in m:GetChildren() do
					if d:IsA("BasePart") and string.find(d.Name, "_Glow$") then
						ambTag(d, "Lobby_Flicker", {})
					end
				end
			end
		end
	end
end
