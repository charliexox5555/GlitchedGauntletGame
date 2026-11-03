--!strict
-- The Heal Orb's Barrier (G2 / G3; vault/01 Design/Abilities/Heal Orb.md →
-- Barrier), on every client:
--   - a see-through hex bubble around the whole body (ForceField material
--     with the hex texture), cyan on your team and orange-red on enemies,
--     with magenta glitch static: pixels popping on its skin and a flicker
--     every second or so. Each Barrier hit left is one layer (G3: two
--     nested bubbles; a block takes the inner one away).
--   - when it blocks: the layer shatters into pixels (Neon cubes) with a
--     flash and a glassy break; on your own screen a crack flash.
--   - your own Barrier: a faint hex pattern at the screen edges and a pip
--     per hit left above the health bar (the bubble itself hides while the
--     camera is inside it, so you see out).
-- The server owns the count (the BarrierHits character attribute,
-- Mods/HealOrb); this module reads it, and the ModFx events Barrier /
-- BarrierBlock add the cast and the shatter.
-- Look (stylized, 2026-11-03), with the GlitchVFX kit installed (Util/
-- GlitchVfx; the ForceField look above stays until then): each layer is a
-- solid-reading hex shell (inset panels with a brighter frame, flickering
-- magenta), a block bursts it into flying hex tiles, and a hit that leaves a
-- layer cracks the next one on the side facing you for a moment.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local HealOrb = require(Shared.Mods.HealOrb)
local VFX = require(Shared.Config.VfxTextures)

local GlitchVfx = require(script.Parent.GlitchVfx)
local HealFx = require(script.Parent.HealFx)
local ModAudio = require(script.Parent.ModAudio)
local ModVfx = require(script.Parent.ModVfx)
local TeamColor = require(script.Parent.TeamColor)

local BarrierFx = {}

local player = Players.LocalPlayer
local S = ModAudio.SOUNDS.HealOrb
local ATTR = HealOrb.BARRIER_ATTRIBUTE

local WHITE = Color3.new(1, 1, 1)
local GLITCH = TeamColor.GLITCH

-- The bubble (studs; an ellipsoid around a standing R15 body).
local SIZE = Vector3.new(5.8, 7.6, 5.8)
local CENTER = Vector3.new(0, 0.3, 0) -- from the root
local LAYER_GAP = 0.88 -- each further hit is a layer inside the last
local GLITCH_SCALE = 1.04 -- the magenta static shell, just outside
local ALPHA_ALLY = 0.3 -- ForceField transparency (it's see-through anyway)
local ALPHA_ENEMY = 0.1 -- enemies see it clearly: their next shot won't count
local FORM_TIME = 0.25 -- the bubble grows in
local FADE_TIME = 0.25 -- it fades when it ends without a block (round end, death)
local GONE_GRACE = 0.15 -- the count can arrive before the shatter event
local INSIDE = 3.4 -- camera this close to the centre: you're inside it
local SCAN_EVERY = 0.1 -- seconds between looks at who has a Barrier
local MAX_LAYERS = 3

-- Glitch static.
local STATIC_PIXELS = 8
local STATIC_STEP = 0.05 -- the pixels re-roll this often
local STATIC_ODDS = 0.35 -- share of them showing at a time
local FLICKER_EVERY = NumberRange.new(0.7, 1.6)
local FLICKER_TIME = 0.12

-- Shatter.
local SHARDS_FULL = 34
local SHARDS_LAYER = 16
local SHARD_GRAVITY = 40
local SHARD_POOL = 80

-- Screen (your own Barrier).
local EDGE_ALPHA = 0.7 -- the hex pattern at its strongest (at the edge)
local EDGE_DEPTH = 0.2 -- how far in from each edge it reaches (screen share)
local CRACK_TIME = 0.45
local CRACKS = 7

-- The kit's hex shell (GlitchVFX: panels at r 1, frame 1.01, crack 1.02, all
-- in a 2.04 box): a layer's part is SIZE x KIT_SPAN at full size.
local KIT_SPAN = 1.02
local KIT_PANEL_ALPHA = { ally = 0.62, enemy = 0.45 } -- the panels (see-through for your side)
local KIT_EDGE_ALPHA = { ally = 0.2, enemy = 0.05 } -- the frame reads solid
local SHELL_CRACK_TIME = 0.6 -- a hit that leaves a layer cracks the next one this long
local TILES_FULL = 18 -- hex tiles a full break throws (the pixels come too, fewer)
local TILES_LAYER = 9

local folder: Folder? = nil

local function fxFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "BarrierFx"
	made.Parent = Workspace
	folder = made
	return made
end

local function newPart(): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Transparency = 1
	p.Parent = fxFolder()
	return p
end

-- A see-through ellipsoid: a ForceField part whose sphere mesh carries the
-- pattern (the material animates it on its own).
local function newShell(texture: string?): (Part, SpecialMesh)
	local p = newPart()
	p.Material = Enum.Material.ForceField
	p.Size = SIZE
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.TextureId = texture or ""
	mesh.Parent = p
	return p, mesh
end

local function rootOf(model: Model): BasePart?
	local r = model:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function alive(model: Model): boolean
	local h = model:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0
end

local function hitsOn(model: Model): number
	local n = model:GetAttribute(ATTR)
	return if typeof(n) == "number" and n == n then math.clamp(math.floor(n), 0, MAX_LAYERS) else 0
end

-- A random point on an ellipsoid of `size` around the origin, and its outward direction.
local function onSkin(size: Vector3): (Vector3, Vector3)
	local u = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1)
	if u.Magnitude < 1e-3 then
		u = Vector3.yAxis
	end
	u = u.Unit
	return Vector3.new(u.X * size.X / 2, u.Y * size.Y / 2, u.Z * size.Z / 2), u
end

-- Shards ---------------------------------------------------------------------------

type Shard = {
	part: Part,
	pos: Vector3,
	vel: Vector3,
	axis: Vector3,
	spin: number,
	size: number,
	born: number,
	life: number,
}

local freeShards: { Part } = {}
local shards: { Shard } = {}

local function takeShard(): Part?
	local p = table.remove(freeShards)
	if p and p.Parent then
		return p
	end
	if #shards >= SHARD_POOL then
		return nil
	end
	local made = newPart()
	made.Material = Enum.Material.Neon
	return made
end

-- Pixels flying off a `size` ellipsoid at `center`, in `color` (some magenta and white).
local function shatter(center: CFrame, size: Vector3, color: Color3, count: number)
	local now = os.clock()
	for _ = 1, count do
		local p = takeShard()
		if not p then
			return
		end
		local offset, out = onSkin(size)
		local roll = math.random()
		p.Color = if roll < 0.6 then color elseif roll < 0.85 then GLITCH else WHITE
		local s = 0.2 + math.random() * 0.24
		p.Size = Vector3.one * s
		p.Transparency = 0
		local pos = center:PointToWorldSpace(offset)
		p.CFrame = CFrame.new(pos)
		table.insert(shards, {
			part = p,
			pos = pos,
			vel = center:VectorToWorldSpace(out) * (8 + math.random() * 9) + Vector3.new(0, 4, 0),
			axis = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit,
			spin = 8 + math.random() * 10,
			size = s,
			born = now,
			life = 0.45 + math.random() * 0.35,
		})
	end
end

local function stepShards(dt: number, now: number)
	for i = #shards, 1, -1 do
		local sh = shards[i]
		local k = (now - sh.born) / sh.life
		if k >= 1 or not sh.part.Parent then
			sh.part.Transparency = 1
			table.insert(freeShards, sh.part)
			table.remove(shards, i)
			continue
		end
		sh.vel -= Vector3.new(0, SHARD_GRAVITY * dt, 0)
		sh.vel *= 1 - math.min(dt * 2.5, 0.5) -- drag: a burst, not a fountain
		sh.pos += sh.vel * dt
		sh.part.Size = Vector3.one * (sh.size * (1 - 0.7 * k))
		sh.part.CFrame = CFrame.new(sh.pos)
			* CFrame.fromAxisAngle(sh.axis, (now - sh.born) * sh.spin)
		sh.part.Transparency = k * k
	end
end

-- Hex tiles flying off a `size` ellipsoid at `center` (the GlitchVFX kit's
-- shatter: its panels coming apart). False when the kit isn't installed.
local function shatterTiles(center: CFrame, size: Vector3, color: Color3, count: number): boolean
	if not GlitchVfx.ready() then
		return false
	end
	for _ = 1, count do
		local offset, out = onSkin(size)
		local pos = center:PointToWorldSpace(offset)
		local dir = center:VectorToWorldSpace(out)
		local roll = math.random()
		-- Lying on the skin (the tile's face is its Y), spinning off it.
		local cf = CFrame.lookAt(pos, pos + dir)
			* CFrame.Angles(math.pi / 2, 0, math.random() * 6.3)
		GlitchVfx.piece({
			name = "HexTile_Energy",
			cframe = cf,
			scale = Vector3.one * (0.6 + math.random() * 0.35),
			scale1 = Vector3.one * 0.25,
			color = if roll < 0.65 then color elseif roll < 0.9 then GLITCH else WHITE,
			life = 0.5 + math.random() * 0.35,
			alpha0 = 0.05,
			alpha1 = 0.9,
			velocity = dir * (9 + math.random() * 9) + Vector3.new(0, 5, 0),
			gravity = SHARD_GRAVITY,
			spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 16,
			stutter = 0.08,
		})
	end
	return true
end

-- Bubbles --------------------------------------------------------------------------

-- A layer is a ForceField ellipsoid (the old look: `mesh` scales it) or, with
-- the GlitchVFX kit, a hex panel shell (`part`, sized directly) and its frame.
type Layer = { part: BasePart, mesh: SpecialMesh?, edges: BasePart?, scale: number }

type Bubble = {
	model: Model,
	root: BasePart?,
	hits: number,
	color: Color3,
	own: boolean,
	layers: { Layer },
	kit: boolean, -- drawn with the GlitchVFX hex shell
	glitch: Part?, -- the magenta static shell (the old look only)
	glitchMesh: SpecialMesh?,
	crack: BasePart?, -- the kit's shell crack
	crackDir: Vector3, -- where it faces (flat, world)
	crackUntil: number,
	pixels: { Part },
	pixelAt: { Vector3 }, -- each pixel's spot on the skin (from the centre)
	born: number,
	goneAt: number?, -- the count went: fade (after the grace)
	fadeFrom: number?,
	nextStatic: number,
	nextFlicker: number,
	flickerUntil: number,
}

local bubbles: { [Model]: Bubble } = {}

local function freeBubble(b: Bubble)
	for _, l in b.layers do
		local edges = l.edges
		if l.mesh then
			l.part:Destroy()
		else
			GlitchVfx.give("HexShell_Energy", l.part)
		end
		if edges then
			GlitchVfx.give("HexEdge_Energy", edges)
		end
	end
	local glitch = b.glitch
	if glitch then
		glitch:Destroy()
	end
	local crack = b.crack
	if crack then
		GlitchVfx.give("ShellCrack_Energy", crack)
	end
	for _, p in b.pixels do
		p:Destroy()
	end
	if bubbles[b.model] == b then
		bubbles[b.model] = nil
	end
end

local function makeBubble(model: Model, hits: number, form: boolean): Bubble
	local own = model == player.Character
	local color = TeamColor.forOwner(model)
	local layers: { Layer } = {}
	local kit = GlitchVfx.ready()
	local glitch: Part?, glitchMesh: SpecialMesh? = nil, nil
	for i = 1, MAX_LAYERS do
		local scale = LAYER_GAP ^ (i - 1)
		local panels = if kit then GlitchVfx.take("HexShell_Energy") else nil
		local edges = if kit then GlitchVfx.take("HexEdge_Energy") else nil
		if panels and edges then
			panels.Color = color
			edges.Color = color
			table.insert(layers, { part = panels, mesh = nil, edges = edges, scale = scale })
		else
			kit = false
			local part, mesh = newShell(VFX.MOD_HEX)
			part.Color = color
			table.insert(layers, { part = part, mesh = mesh, edges = nil, scale = scale })
		end
	end
	if not kit then
		local g, gm = newShell(nil)
		g.Color = GLITCH
		glitch, glitchMesh = g, gm
	end
	local pixels = {}
	for i = 1, STATIC_PIXELS do
		local p = newPart()
		p.Material = Enum.Material.Neon
		p.Color = GLITCH
		p.Size = Vector3.new(0.22, 0.22, 0.22)
		pixels[i] = p
	end
	local now = os.clock()
	local b: Bubble = {
		model = model,
		root = rootOf(model),
		hits = hits,
		color = color,
		own = own,
		layers = layers,
		kit = kit,
		glitch = glitch,
		glitchMesh = glitchMesh,
		crack = if kit then GlitchVfx.take("ShellCrack_Energy") else nil,
		crackDir = Vector3.zAxis,
		crackUntil = 0,
		pixels = pixels,
		pixelAt = table.create(STATIC_PIXELS, Vector3.zero),
		born = if form then now else now - FORM_TIME,
		goneAt = nil,
		fadeFrom = nil,
		nextStatic = now,
		nextFlicker = now + FLICKER_EVERY.Min,
		flickerUntil = if form then now + FLICKER_TIME else 0,
	}
	bubbles[model] = b
	return b
end

local function ensure(model: Model, hits: number, form: boolean): Bubble
	local b = bubbles[model]
	if b and not b.fadeFrom then
		b.hits = hits
		b.goneAt = nil
		return b
	end
	if b then
		freeBubble(b)
	end
	return makeBubble(model, hits, form)
end

local function centerOf(b: Bubble): CFrame?
	local root = b.root
	if not root or root.Parent ~= b.model then
		return nil
	end
	return root.CFrame * CFrame.new(CENTER)
end

local function drawBubble(b: Bubble, now: number, camPos: Vector3?)
	local center = centerOf(b)
	if not center then
		for _, l in b.layers do
			l.part.Transparency = 1
			local edges = l.edges
			if edges then
				edges.Transparency = 1
			end
		end
		local glitch = b.glitch
		if glitch then
			glitch.Transparency = 1
		end
		local crack = b.crack
		if crack then
			crack.Transparency = 1
		end
		for _, p in b.pixels do
			p.Transparency = 1
		end
		return
	end
	local grow = math.clamp((now - b.born) / FORM_TIME, 0, 1)
	grow = 1 - (1 - grow) * (1 - grow)
	local fade = if b.fadeFrom then math.clamp((now - b.fadeFrom) / FADE_TIME, 0, 1) else 0
	local inside = b.own and camPos ~= nil and (camPos - center.Position).Magnitude < INSIDE
	local flicker = now < b.flickerUntil
	if now >= b.nextFlicker then
		b.flickerUntil = now + FLICKER_TIME
		b.nextFlicker = now
			+ FLICKER_EVERY.Min
			+ math.random() * (FLICKER_EVERY.Max - FLICKER_EVERY.Min)
	end
	local ally = b.color == TeamColor.ALLY
	local base = if ally then ALPHA_ALLY else ALPHA_ENEMY
	local edgeBase = if ally then KIT_EDGE_ALPHA.ally else KIT_EDGE_ALPHA.enemy
	if b.kit then
		base = if ally then KIT_PANEL_ALPHA.ally else KIT_PANEL_ALPHA.enemy
	end
	local grown = 0.35 + 0.65 * grow
	-- A glitch: the bubble jumps sideways a hair and its alpha stutters.
	local jitter = if flicker
		then CFrame.new((math.random() - 0.5) * 0.35, (math.random() - 0.5) * 0.15, 0)
		else CFrame.identity
	for i, l in b.layers do
		local shown = i <= b.hits and not inside
		local alpha = if shown then base + (1 - base) * fade else 1
		if shown and flicker then
			alpha = math.min(alpha + math.random() * 0.4, 1)
		end
		l.part.Transparency = alpha
		local mesh, edges = l.mesh, l.edges
		if shown then
			l.part.Color = if flicker and math.random() < 0.5 then GLITCH else b.color
			l.part.CFrame = center * jitter
			if mesh then
				mesh.Scale = Vector3.one * (l.scale * grown)
			else
				l.part.Size = SIZE * (KIT_SPAN * l.scale * grown)
			end
		end
		if edges then
			-- The frame: bright and nearly solid, magenta in a flicker.
			local edgeAlpha = if shown then edgeBase + (1 - edgeBase) * fade else 1
			edges.Transparency = edgeAlpha
			if shown then
				edges.Color = if flicker then GLITCH else b.color
				edges.Size = SIZE * (KIT_SPAN * l.scale * grown)
				edges.CFrame = center * jitter
			end
		end
	end
	-- The magenta static shell: faint, louder in a flicker.
	local glitch, glitchMesh = b.glitch, b.glitchMesh
	if glitch and glitchMesh then
		local glitchAlpha = if inside then 1 elseif flicker then 0.35 else 0.88 + math.random() * 0.1
		glitch.Transparency = glitchAlpha + (1 - glitchAlpha) * fade
		glitchMesh.Scale = Vector3.one * (GLITCH_SCALE * grown)
		glitch.CFrame = center * jitter:Inverse()
	end
	-- The kit's crack on the outer layer left, facing whoever is looking.
	local crack = b.crack
	if crack then
		local k = 1 - (b.crackUntil - now) / SHELL_CRACK_TIME
		if k < 0 or k >= 1 or inside or b.hits <= 0 then
			crack.Transparency = 1
		else
			local layer = b.layers[math.clamp(b.hits, 1, #b.layers)]
			local pos = center.Position
			-- Turned about Y only, so the ellipsoid's stretch keeps it on the skin.
			crack.CFrame = CFrame.lookAt(pos, pos + b.crackDir)
			crack.Size = SIZE * (KIT_SPAN * layer.scale * grown)
			crack.Color = if flicker and math.random() < 0.5
				then GLITCH
				else b.color:Lerp(WHITE, 0.4)
			crack.Transparency = k * k
		end
	end
	-- Static pixels on the skin.
	if now >= b.nextStatic then
		b.nextStatic = now + STATIC_STEP
		for i, p in b.pixels do
			if inside or fade > 0 or math.random() > (if flicker then 0.9 else STATIC_ODDS) then
				p.Transparency = 1
			else
				local offset = onSkin(SIZE * GLITCH_SCALE)
				b.pixelAt[i] = offset
				p.CFrame = center * CFrame.new(offset)
				p.Color = if math.random() < 0.8 then GLITCH else b.color
				p.Transparency = 0.1
			end
		end
	else
		-- The pixels ride along between re-rolls.
		for i, p in b.pixels do
			if p.Transparency < 1 then
				p.CFrame = center * CFrame.new(b.pixelAt[i])
			end
		end
	end
end

-- Screen (your own Barrier) ----------------------------------------------------------

type Screen = {
	gui: ScreenGui,
	edges: { ImageLabel },
	flash: ImageLabel,
	cracks: { Frame },
	crackStrokes: { UIStroke },
	pips: { Frame },
	pipRow: Frame,
}

local screen: Screen? = nil
local edgeShown = 0 -- 0..1, eased toward whether your Barrier is up
local crackAt = -math.huge

local function edgeStrip(
	parent: Instance,
	rotation: number,
	pos: UDim2,
	size: UDim2,
	anchor: Vector2
): ImageLabel
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Image = VFX.MOD_HEX
	img.ScaleType = Enum.ScaleType.Tile
	img.TileSize = UDim2.fromOffset(96, 83) -- the texture is 512 x 443
	img.ImageColor3 = TeamColor.ALLY
	img.ImageTransparency = 1
	img.AnchorPoint = anchor
	img.Position = pos
	img.Size = size
	local grad = Instance.new("UIGradient")
	grad.Rotation = rotation
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, EDGE_ALPHA),
		NumberSequenceKeypoint.new(1, 1),
	})
	grad.Parent = img
	img.Parent = parent
	return img
end

local function buildScreen(): Screen
	local s = screen
	if s and s.gui.Parent then
		return s
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "BarrierScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3
	gui.Parent = player:WaitForChild("PlayerGui")
	local d = EDGE_DEPTH
	local edges = {
		edgeStrip(gui, 90, UDim2.fromScale(0, 0), UDim2.fromScale(1, d), Vector2.zero), -- top
		edgeStrip(gui, -90, UDim2.fromScale(0, 1), UDim2.fromScale(1, d), Vector2.new(0, 1)), -- bottom
		edgeStrip(gui, 0, UDim2.fromScale(0, 0), UDim2.fromScale(d * 0.75, 1), Vector2.zero), -- left
		edgeStrip(gui, 180, UDim2.fromScale(1, 0), UDim2.fromScale(d * 0.75, 1), Vector2.new(1, 0)), -- right
	}
	local flash = Instance.new("ImageLabel")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundTransparency = 1
	flash.Image = VFX.HEALORB_EDGE
	flash.ImageColor3 = WHITE
	flash.ImageTransparency = 1
	flash.ScaleType = Enum.ScaleType.Stretch
	flash.Parent = gui
	local cracks = {}
	local crackStrokes = {}
	for i = 1, CRACKS * 2 do
		-- Centre-anchored: GUI rotation always pivots on the centre.
		local c = Instance.new("Frame")
		c.AnchorPoint = Vector2.new(0.5, 0.5)
		c.BorderSizePixel = 0
		c.BackgroundColor3 = WHITE
		c.BackgroundTransparency = 1
		c.Visible = false
		local stroke = Instance.new("UIStroke")
		stroke.Color = GLITCH
		stroke.Thickness = 1
		stroke.Transparency = 1
		stroke.Parent = c
		c.Parent = gui
		cracks[i] = c
		crackStrokes[i] = stroke
	end
	-- Pips: one per hit left, just above the health readout (bottom left).
	local row = Instance.new("Frame")
	row.Name = "BarrierPips"
	row.AnchorPoint = Vector2.new(0, 1)
	row.Position = UDim2.new(0, 38, 1, -102)
	row.Size = UDim2.fromOffset(200, 18)
	row.BackgroundTransparency = 1
	row.Visible = false
	row.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 9)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	local label = Instance.new("TextLabel")
	label.LayoutOrder = 0
	label.Size = UDim2.fromOffset(64, 18)
	label.BackgroundTransparency = 1
	label.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
	label.TextSize = 15
	label.TextColor3 = TeamColor.ALLY
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = "BARRIER"
	label.Parent = row
	local labelStroke = Instance.new("UIStroke")
	labelStroke.Transparency = 0.5
	labelStroke.Parent = label
	local pips = {}
	for i = 1, MAX_LAYERS do
		local pip = Instance.new("Frame")
		pip.LayoutOrder = i
		pip.Size = UDim2.fromOffset(11, 11)
		pip.Rotation = 45
		pip.BorderSizePixel = 0
		pip.BackgroundColor3 = TeamColor.ALLY
		pip.Visible = false
		local ps = Instance.new("UIStroke")
		ps.Color = GLITCH
		ps.Thickness = 1.5
		ps.Parent = pip
		pip.Parent = row
		pips[i] = pip
	end
	local made: Screen = {
		gui = gui,
		edges = edges,
		flash = flash,
		cracks = cracks,
		crackStrokes = crackStrokes,
		pips = pips,
		pipRow = row,
	}
	screen = made
	return made
end

-- The crack flash: the edge glow pops white-magenta and cracks run in from the edges.
local function crackScreen()
	local s = buildScreen()
	crackAt = os.clock()
	local cam = Workspace.CurrentCamera
	local view = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	for i = 1, CRACKS do
		-- From a random point on the edge toward the centre, a bit off.
		local side = math.random(1, 4)
		local t = 0.1 + math.random() * 0.8
		local from = if side == 1
			then Vector2.new(t * view.X, 0)
			elseif side == 2 then Vector2.new(t * view.X, view.Y)
			elseif side == 3 then Vector2.new(0, t * view.Y)
			else Vector2.new(view.X, t * view.Y)
		local toward = (view / 2 - from).Unit
		local angle = math.atan2(toward.Y, toward.X) + (math.random() - 0.5) * 0.5
		local length = view.Y * (0.14 + math.random() * 0.12)
		local dir = Vector2.new(math.cos(angle), math.sin(angle))
		local mid = from + dir * (length / 2)
		local main = s.cracks[i * 2 - 1]
		main.Position = UDim2.fromOffset(mid.X, mid.Y)
		main.Size = UDim2.fromOffset(length, 2)
		main.Rotation = math.deg(angle)
		main.Visible = true
		-- A branch off its middle.
		local at = from + dir * length * (0.45 + math.random() * 0.2)
		local branchAngle = angle
			+ (if math.random() < 0.5 then -1 else 1) * (0.35 + math.random() * 0.35)
		local branchLength = length * 0.45
		local branchMid = at
			+ Vector2.new(math.cos(branchAngle), math.sin(branchAngle)) * (branchLength / 2)
		local branch = s.cracks[i * 2]
		branch.Position = UDim2.fromOffset(branchMid.X, branchMid.Y)
		branch.Size = UDim2.fromOffset(branchLength, 1)
		branch.Rotation = math.deg(branchAngle)
		branch.Visible = true
	end
end

local function stepScreen(dt: number, now: number)
	local character = player.Character
	local hits = if character and alive(character) then hitsOn(character) else 0
	local s = screen
	if not s and hits == 0 then
		return
	end
	local k = (now - crackAt) / CRACK_TIME
	if s and hits == 0 and edgeShown < 0.01 and k >= 1 and s.flash.ImageTransparency >= 1 then
		if s.pipRow.Visible or s.edges[1].Visible then
			s.pipRow.Visible = false
			for _, e in s.edges do
				e.Visible = false
			end
		end
		return -- nothing showing: no per-frame work
	end
	local sc = s or buildScreen()
	-- The edge hex eases in and out; a magenta stutter now and then.
	local goal = if hits > 0 then 1 else 0
	edgeShown += (goal - edgeShown) * math.min(dt * 8, 1)
	local b = character and bubbles[character]
	local flicker = b ~= nil and now < b.flickerUntil
	for _, e in sc.edges do
		e.ImageTransparency = 1 - edgeShown
		e.ImageColor3 = if flicker then GLITCH else TeamColor.ALLY
		e.Visible = edgeShown > 0.01
	end
	sc.pipRow.Visible = hits > 0
	for i, pip in sc.pips do
		pip.Visible = i <= hits
	end
	-- The crack flash.
	if k < 1 then
		local alpha = k ^ 0.7
		sc.flash.ImageTransparency = 0.05 + 0.95 * alpha
		sc.flash.ImageColor3 = WHITE:Lerp(GLITCH, math.min(k * 2, 1))
		for i, c in sc.cracks do
			if c.Visible then
				c.BackgroundTransparency = alpha
				sc.crackStrokes[i].Transparency = 0.3 + 0.7 * alpha
			end
		end
	elseif sc.flash.ImageTransparency < 1 then
		sc.flash.ImageTransparency = 1
		for _, c in sc.cracks do
			c.Visible = false
		end
	end
end

-- Events ------------------------------------------------------------------------------

-- The Barrier is cast on `data.target` (ModFx "Barrier").
function BarrierFx.cast(data: { [string]: any })
	local target = data.target
	if typeof(target) ~= "Instance" or not target:IsA("Model") then
		return -- streamed out: the scan draws it when it streams in
	end
	local model = target :: Model
	local hits = if typeof(data.hits) == "number"
		then math.clamp(math.floor(data.hits), 1, MAX_LAYERS)
		else 1
	local b = ensure(model, hits, true)
	b.flickerUntil = os.clock() + FLICKER_TIME
	local caster = data.caster
	local casterModel = if typeof(caster) == "Instance" and caster:IsA("Player")
		then caster.Character
		else nil
	HealFx.ribbon(casterModel, model, b.color)
	local root = rootOf(model)
	if root then
		ModVfx.burst(root.Position, GLITCH, 10, "Sparkle")
		ModVfx.burst(root.Position, b.color, 8, "Glow")
		local mine = model == player.Character or caster == player
		local at = if mine then nil else root.Position
		ModAudio.play(S.barrierUp, at)
		ModAudio.play(S.barrierUpStatic, at)
	end
end

-- The Barrier on `data.target` took a hit (ModFx "BarrierBlock"): one layer
-- shatters (all of it when `data.left` is 0).
function BarrierFx.block(data: { [string]: any })
	local target = data.target
	local left = if typeof(data.left) == "number" then math.max(math.floor(data.left), 0) else 0
	local model = if typeof(target) == "Instance" and target:IsA("Model")
		then target :: Model
		else nil
	local b = model and bubbles[model]
	local center = if b then centerOf(b) else nil
	if not center and typeof(data.at) == "Vector3" then
		center = CFrame.new(data.at + CENTER)
	end
	if not center then
		return
	end
	local color = if b then b.color elseif model then TeamColor.forOwner(model) else TeamColor.ENEMY
	-- The pixels fly off the outer skin; any layer left stays at full size.
	-- With the kit, hex tiles fly too (and fewer pixels).
	local size = SIZE
	local tiles = shatterTiles(center, size, color, if left > 0 then TILES_LAYER else TILES_FULL)
	local pixelCount = if left > 0 then SHARDS_LAYER else SHARDS_FULL
	shatter(center, size, color, if tiles then pixelCount // 2 else pixelCount)
	ModVfx.shell({
		shape = Enum.PartType.Ball,
		cframe = center,
		from = Vector3.one * (size.X * 0.9),
		to = Vector3.one * (size.Y * 1.15),
		color = if left > 0 then color else WHITE,
		life = 0.18,
		alpha0 = 0.7,
		material = Enum.Material.Neon,
	})
	ModVfx.burst(center.Position, GLITCH, if left > 0 then 8 else 16, "Sparkle")
	if b then
		b.hits = left
		b.flickerUntil = os.clock() + 0.3 -- a hard stutter
		if left <= 0 then
			freeBubble(b) -- it's the pixels now
		else
			-- The layer left cracks on the side facing this viewer.
			local cam = Workspace.CurrentCamera
			local toCam = if cam
				then (cam.CFrame.Position - center.Position) * Vector3.new(1, 0, 1)
				else Vector3.zero
			b.crackDir = if toCam.Magnitude > 0.1 then toCam.Unit else Vector3.zAxis
			b.crackUntil = os.clock() + SHELL_CRACK_TIME
		end
	end
	local mine = model ~= nil and model == player.Character
	local at = if mine then nil else center.Position
	ModAudio.play(S.barrierBreak, at, if left > 0 then 1.15 else 1)
	ModAudio.play(S.barrierBreakZap, at)
	if mine then
		crackScreen()
	end
end

-- Per frame ---------------------------------------------------------------------------

local lastScan = -math.huge

-- Who has a Barrier, by the server's count: players' characters and dummies.
local function scan(now: number)
	local seen: { [Model]: boolean } = {}
	local function look(model: Model)
		seen[model] = true
		local hits = if alive(model) then hitsOn(model) else 0
		local b = bubbles[model]
		if hits > 0 then
			b = ensure(model, hits, false)
			b.root = rootOf(model) -- streamed bodies: look it up again
		elseif b and not b.fadeFrom then
			if not b.goneAt then
				b.goneAt = now
			elseif now - b.goneAt >= GONE_GRACE then
				b.fadeFrom = now
			end
		end
	end
	for _, p in Players:GetPlayers() do
		local c = p.Character
		if c then
			look(c)
		end
	end
	local dummies = Workspace:FindFirstChild("Dummies")
	if dummies then
		for _, m in dummies:GetChildren() do
			if m:IsA("Model") then
				look(m)
			end
		end
	end
	for model, b in bubbles do
		if not seen[model] or model.Parent == nil then
			freeBubble(b)
		end
	end
end

function BarrierFx.step(dt: number)
	local now = os.clock()
	if now - lastScan >= SCAN_EVERY then
		lastScan = now
		scan(now)
	end
	local cam = Workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else nil
	for _, b in bubbles do
		if b.fadeFrom and now - b.fadeFrom >= FADE_TIME then
			freeBubble(b)
		else
			drawBubble(b, now, camPos)
		end
	end
	stepShards(dt, now)
	stepScreen(dt, now)
end

return BarrierFx
