--!strict
-- World effects of Mods for everyone (ModFx events from ModService), coloured
-- per viewer (Util/TeamColor): cyan for you and your team, orange-red for
-- enemies. Cosmetic only: the server already decided every result. Stage 1
-- placeholders (pooled parts and billboards); the VFX pass replaces them.
--
--   PacketThrow  the grenade flying its server path (Blocks/Projectile replay),
--                fuse blink, and a danger ring where it will go off
--   PacketBoom   flash sphere + shockwave ring, camera shake nearby
--   Heal         a beam from the healer to the ally, +HP over the target
--   LagThrow / LagZone   the orb's flight, then the slowing dome
--   PingPulse    an expanding scan sphere (everyone sees it)
--   Overclock    the caster's gun glows (a screen-edge glow for the caster)
--   Placed / ObjectGone  a pop when a Mod object goes up / breaks or expires
-- Also: ModReveal (sent to your team only) outlines revealed enemies through
-- walls; Mod objects in workspace.ModObjects are coloured per viewer and
-- flash when hit; a Rollback ghost trail follows anyone whose Rollback is
-- ready; your own Rollback plays a "VHS rewind" wash; anyone a Lag Field is
-- slowing shows SLOWED.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Projectile = require(Shared.Mods.Blocks.Projectile)

local ModProps = require(script.Parent.Parent.Util.ModProps)
local TeamColor = require(script.Parent.Parent.Util.TeamColor)
local VfxPool = require(script.Parent.Parent.Util.VfxPool)
local CameraController = require(script.Parent.CameraController)

local ModFxController = {}

local player = Players.LocalPlayer

type Flight = {
	blink: boolean, -- Packet's fuse blink
	model: Model,
	glow: { BasePart },
	ring: Part,
	path: Projectile.Path,
	start: number,
	fuse: number,
	color: Color3,
	key: string,
}

type Boom = { sphere: Part, ring: Part, at: Vector3, radius: number, born: number }

type Beam = {
	part: Part,
	from: Model,
	to: Model,
	born: number,
	duration: number,
}

type Floater = { gui: BillboardGui, label: TextLabel, born: number }

local BOOM_TIME = 0.35
local FLOATER_TIME = 1.1

local folder: Folder? = nil
local lastRollback = 0
local flights: { Flight } = {}
local booms: { Boom } = {}
local beams: { Beam } = {}
local floaters: { Floater } = {}
local grenadeFree: { [string]: { Model } } = {}
local partPool: VfxPool.Pool<Part>? = nil
local floaterFree: { Floater } = {}

local function fxFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "ModFx"
	made.Parent = Workspace
	folder = made
	partPool = nil
	table.clear(grenadeFree)
	return made
end

local function parts(): VfxPool.Pool<Part>
	local pool = partPool
	if pool then
		return pool
	end
	local made = VfxPool.new(function(): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Transparency = 1
		p.Parent = fxFolder()
		return p
	end, fxFolder(), 8)
	partPool = made
	return made
end

local function takePart(shape: Enum.PartType, color: Color3): Part
	local p = parts():acquire()
	p.Shape = shape
	p.Color = color
	p.Material = Enum.Material.Neon -- pooled parts may come back as ForceField
	return p
end

local function rootOf(model: Model?): BasePart?
	local r = model and model:FindFirstChild("HumanoidRootPart")
	if r and r:IsA("BasePart") then
		return r
	end
	return nil
end

-- Packet ----------------------------------------------------------------------------

local function takeGrenade(id: string, color: Color3): (Model?, string)
	local key = id .. color:ToHex()
	local free = grenadeFree[key]
	local model = free and table.remove(free)
	if not model then
		local template = ModProps.get(id, color)
		if not template then
			return nil, key
		end
		model = template:Clone()
	end
	(model :: Model).Parent = fxFolder()
	return model, key
end

local function onPacketThrow(data: { [string]: any })
	local path = Projectile.unpack(data.path)
	local start, fuse, radius = data.start, data.fuse, data.radius
	if
		not path
		or typeof(start) ~= "number"
		or typeof(fuse) ~= "number"
		or typeof(radius) ~= "number"
	then
		return
	end
	local color = TeamColor.forTeam(if typeof(data.team) == "number" then data.team else nil)
	if data.caster == player then
		color = TeamColor.ALLY
	end
	local model, key = takeGrenade("Packet", color)
	if not model then
		return
	end
	local glow = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			table.insert(glow, d)
		end
	end
	-- Danger ring where it will go off.
	local ring = takePart(Enum.PartType.Cylinder, color)
	ring.Size = Vector3.new(0.08, radius * 2, radius * 2)
	ring.CFrame = CFrame.new(Projectile.positionAt(path, fuse)) * CFrame.Angles(0, 0, math.pi / 2)
	table.insert(flights, {
		blink = true,
		model = model,
		glow = glow,
		ring = ring,
		path = path,
		start = start,
		fuse = fuse,
		color = color,
		key = key,
	})
end

local function onPacketBoom(data: { [string]: any })
	local at, radius = data.at, data.radius
	if typeof(at) ~= "Vector3" or typeof(radius) ~= "number" then
		return
	end
	local color = if data.caster == player
		then TeamColor.ALLY
		else TeamColor.forTeam(if typeof(data.team) == "number" then data.team else nil)
	local sphere = takePart(Enum.PartType.Ball, color)
	local ring = takePart(Enum.PartType.Cylinder, color)
	table.insert(
		booms,
		{ sphere = sphere, ring = ring, at = at, radius = radius, born = os.clock() }
	)
	local cam = Workspace.CurrentCamera
	if cam then
		local d = (cam.CFrame.Position - at).Magnitude
		if d < radius * 4 then
			CameraController.shake(1.2 * (1 - d / (radius * 4)))
		end
	end
end

-- Patch Up --------------------------------------------------------------------------

local function floater(target: Model, text: string, color: Color3)
	local head = target:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local f = table.remove(floaterFree)
	if not f then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(120, 40)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.ResetOnSpawn = false
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.FontFace =
			Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
		label.TextSize = 26
		label.TextStrokeTransparency = 0.4
		label.Parent = gui
		f = { gui = gui, label = label, born = 0 }
	end
	local fl = f :: Floater
	fl.label.Text = text
	fl.label.TextColor3 = color
	fl.gui.Adornee = head
	fl.gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
	fl.gui.Parent = player:FindFirstChild("PlayerGui")
	fl.born = os.clock()
	table.insert(floaters, fl)
end

local function onHeal(data: { [string]: any })
	local target, caster = data.target, data.caster
	local duration, amount = data.duration, data.amount
	if typeof(duration) ~= "number" or typeof(amount) ~= "number" then
		return
	end
	if typeof(target) ~= "Instance" or not (target :: Instance):IsA("Model") then
		return -- streamed out: nothing to draw on
	end
	local targetModel = target :: Model
	local friendly = data.caster == player
		or TeamColor.isFriendly(if typeof(data.team) == "number" then data.team else nil)
	local color = if friendly then TeamColor.ALLY else TeamColor.ENEMY
	local casterModel = if typeof(caster) == "Instance" and (caster :: Instance):IsA("Player")
		then (caster :: Player).Character
		else nil
	if casterModel and casterModel ~= targetModel then
		local beam = takePart(Enum.PartType.Block, color)
		table.insert(beams, {
			part = beam,
			from = casterModel,
			to = targetModel,
			born = os.clock(),
			duration = math.max(duration, 0.4),
		})
	end
	if friendly then
		floater(targetModel, "+" .. tostring(math.round(amount)), color)
	end
end

-- Shapes: parts that grow and fade (zones, pulses, pops) -----------------------------

type Shape = {
	part: Part,
	born: number,
	life: number,
	cframe: CFrame,
	from: Vector3, -- size at birth
	to: Vector3, -- size at the end (eased out)
	alpha0: number, -- transparency at birth
	alpha1: number, -- at the end
	hold: boolean, -- keep alpha0 and fade only over the last 0.3 s (zones)
}

type ShapeSpec = {
	shape: Enum.PartType,
	color: Color3,
	cframe: CFrame,
	from: Vector3,
	to: Vector3,
	life: number,
	alpha0: number,
	alpha1: number,
	hold: boolean?,
	material: Enum.Material?,
}

local shapes: { Shape } = {}
local FLAT = CFrame.Angles(0, 0, math.pi / 2) -- a Cylinder part lying flat

local function shape(spec: ShapeSpec)
	local p = takePart(spec.shape, spec.color)
	p.Material = spec.material or Enum.Material.Neon
	p.Size = spec.from
	p.CFrame = spec.cframe
	p.Transparency = spec.alpha0
	table.insert(shapes, {
		part = p,
		born = os.clock(),
		life = spec.life,
		cframe = spec.cframe,
		from = spec.from,
		to = spec.to,
		alpha0 = spec.alpha0,
		alpha1 = spec.alpha1,
		hold = spec.hold == true,
	})
end

local function teamColor(data: { [string]: any }): Color3
	if data.caster == player then
		return TeamColor.ALLY
	end
	return TeamColor.forTeam(if typeof(data.team) == "number" then data.team else nil)
end

-- Lag Field --------------------------------------------------------------------------

local function onLagThrow(data: { [string]: any })
	local path = Projectile.unpack(data.path)
	local start, land, radius = data.start, data.land, data.radius
	if
		not path
		or typeof(start) ~= "number"
		or typeof(land) ~= "number"
		or typeof(radius) ~= "number"
	then
		return
	end
	local color = teamColor(data)
	local model, key = takeGrenade("LagField", color)
	if not model then
		return
	end
	-- Where the zone will open.
	local ring = takePart(Enum.PartType.Cylinder, color)
	ring.Size = Vector3.new(0.08, radius * 2, radius * 2)
	ring.CFrame = CFrame.new(Projectile.positionAt(path, land)) * FLAT
	table.insert(flights, {
		blink = false,
		model = model,
		glow = {},
		ring = ring,
		path = path,
		start = start,
		fuse = land,
		color = color,
		key = key,
	})
end

local function onLagZone(data: { [string]: any })
	local at, radius, duration = data.at, data.radius, data.duration
	if typeof(at) ~= "Vector3" or typeof(radius) ~= "number" or typeof(duration) ~= "number" then
		return
	end
	local color = teamColor(data)
	local size = Vector3.one * radius * 2
	local disc = Vector3.new(0.1, radius * 2, radius * 2)
	-- A soft dome, a bright rim on the ground, and an opening burst.
	shape({
		shape = Enum.PartType.Ball,
		color = color,
		cframe = CFrame.new(at),
		from = size,
		to = size,
		life = duration,
		alpha0 = 0.9,
		alpha1 = 1,
		hold = true,
		material = Enum.Material.ForceField,
	})
	shape({
		shape = Enum.PartType.Cylinder,
		color = color,
		cframe = CFrame.new(at) * FLAT,
		from = disc,
		to = disc,
		life = duration,
		alpha0 = 0.88,
		alpha1 = 1,
		hold = true,
	})
	shape({
		shape = Enum.PartType.Ball,
		color = color,
		cframe = CFrame.new(at),
		from = Vector3.one * 2,
		to = size,
		life = 0.35,
		alpha0 = 0.3,
		alpha1 = 1,
	})
end

-- Ping -------------------------------------------------------------------------------

local function onPingPulse(data: { [string]: any })
	local at, radius = data.at, data.radius
	if typeof(at) ~= "Vector3" or typeof(radius) ~= "number" then
		return
	end
	local color = teamColor(data)
	local d = radius * 2
	shape({
		shape = Enum.PartType.Ball,
		color = color,
		cframe = CFrame.new(at),
		from = Vector3.one * 2,
		to = Vector3.one * d,
		life = 0.6,
		alpha0 = 0.55,
		alpha1 = 1,
		material = Enum.Material.ForceField,
	})
	shape({
		shape = Enum.PartType.Cylinder,
		color = color,
		cframe = CFrame.new(at - Vector3.new(0, 2.8, 0)) * FLAT,
		from = Vector3.new(0.12, 2, 2),
		to = Vector3.new(0.12, d, d),
		life = 0.6,
		alpha0 = 0.3,
		alpha1 = 1,
	})
end

-- Revealed enemies: an orange-red outline through walls (your team only).
type RevealMark = { highlight: Highlight, untilT: number }
local reveals: { [Model]: RevealMark } = {}

local function onReveal(targets: unknown, duration: unknown)
	if typeof(targets) ~= "table" or typeof(duration) ~= "number" then
		return
	end
	local untilT = os.clock() + math.clamp(duration :: number, 0, 10)
	for _, target in ipairs(targets :: { any }) do
		if typeof(target) == "Instance" and (target :: Instance):IsA("Model") then
			local model = target :: Model
			local mark = reveals[model]
			if mark then
				mark.untilT = untilT
			else
				local h = Instance.new("Highlight")
				h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				h.FillColor = TeamColor.ENEMY
				h.OutlineColor = TeamColor.ENEMY
				h.FillTransparency = 0.55
				h.OutlineTransparency = 0
				h.Adornee = model
				h.Parent = fxFolder()
				reveals[model] = { highlight = h, untilT = untilT }
			end
		end
	end
end

-- Overclock --------------------------------------------------------------------------

type Glow = { highlight: Highlight, untilT: number }
local glows: { Glow } = {}
local edge: Frame? = nil
local edgeStroke: UIStroke? = nil
local edgeUntil = 0

local function screenEdge(): Frame
	local f = edge
	if f and f.Parent then
		return f
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "ModScreenFx"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1
	gui.Parent = player:WaitForChild("PlayerGui")
	-- A stroke draws outside its frame: inset the frame by the thickness so
	-- the glow sits on the screen's edge.
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.new(1, -40, 1, -40)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = TeamColor.ALLY
	stroke.Thickness = 20
	stroke.Transparency = 0.6
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	edge = frame
	edgeStroke = stroke
	return frame
end

local function onOverclock(data: { [string]: any })
	local duration = data.duration
	if typeof(duration) ~= "number" then
		return
	end
	if data.caster == player then
		edgeUntil = os.clock() + duration
		screenEdge().Visible = true
		return
	end
	local caster = data.caster
	local character = if typeof(caster) == "Instance" and (caster :: Instance):IsA("Player")
		then (caster :: Player).Character
		else nil
	local gun = character and character:FindFirstChild("WorldWeapon")
	if gun then
		local color = teamColor(data)
		local h = Instance.new("Highlight")
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.FillColor = color
		h.OutlineColor = color
		h.FillTransparency = 0.3
		h.Adornee = gun
		h.Parent = fxFolder()
		table.insert(glows, { highlight = h, untilT = os.clock() + duration })
	end
end

-- Placed objects ---------------------------------------------------------------------

-- Mod objects are coloured per viewer and flash white when hit.
local objectFlash: { [BasePart]: number } = {}

local function objectColor(part: BasePart): Color3
	local team = part:GetAttribute("TeamId")
	return TeamColor.forTeam(if typeof(team) == "number" then team else nil)
end

local function colourObject(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	part.Color = objectColor(part)
	local lastHp = part:GetAttribute("Hp")
	part:GetAttributeChangedSignal("Hp"):Connect(function()
		local hp = part:GetAttribute("Hp")
		if typeof(hp) == "number" and typeof(lastHp) == "number" and hp < lastHp then
			objectFlash[part] = os.clock()
		end
		lastHp = hp
	end)
end

local function onPlaced(data: { [string]: any })
	local at = data.at
	if typeof(at) ~= "Vector3" then
		return
	end
	shape({
		shape = Enum.PartType.Ball,
		color = teamColor(data),
		cframe = CFrame.new(at),
		from = Vector3.one,
		to = Vector3.one * 7,
		life = 0.3,
		alpha0 = 0.4,
		alpha1 = 1,
	})
end

local function onObjectGone(data: { [string]: any })
	local at, size = data.at, data.size
	if typeof(at) ~= "Vector3" or typeof(size) ~= "Vector3" then
		return
	end
	local broken = data.why == "Broken"
	shape({
		shape = Enum.PartType.Block,
		color = TeamColor.forTeam(if typeof(data.team) == "number" then data.team else nil),
		cframe = CFrame.new(at),
		from = size,
		to = size * (if broken then 1.6 else 1.1),
		life = if broken then 0.35 else 0.25,
		alpha0 = 0.3,
		alpha1 = 1,
	})
end

-- Rollback ---------------------------------------------------------------------------

-- Your own rewind: a short "VHS" wash (desaturated, high contrast, tinted).
local vhs: ColorCorrectionEffect? = nil
local VHS_TIME = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function playVhs()
	local effect = vhs
	if not effect or not effect.Parent then
		local made = Instance.new("ColorCorrectionEffect")
		made.Name = "ModRewind"
		made.Parent = Lighting
		vhs = made
		effect = made
	end
	local cc = effect :: ColorCorrectionEffect
	cc.Saturation = -0.85
	cc.Contrast = 0.35
	cc.TintColor = Color3.fromHex("C8F7FF")
	cc.Brightness = 0.05
	TweenService:Create(cc, VHS_TIME, {
		Saturation = 0,
		Contrast = 0,
		TintColor = Color3.new(1, 1, 1),
		Brightness = 0,
	}):Play()
end

-- Ghost trails: for anyone whose Rollback is ready, where they were over the
-- last few seconds (where a rewind would take them), coloured by team. The
-- big dot is where they'd land.
type Trail = { times: { number }, points: { Vector3 }, dots: { Part } }
local trails: { [Player]: Trail } = {}
local TRAIL_STEP = 0.2
local TRAIL_SPAN = 3
local nextTrailSample = 0

local function rollbackReady(other: Player): boolean
	local character = other.Character
	for slot = 1, 3 do
		if other:GetAttribute("Mod" .. slot .. "Id") == "Rollback" then
			local charges = character and character:GetAttribute("Mod" .. slot .. "Charges")
			return typeof(charges) ~= "number" or charges >= 1
		end
	end
	return false
end

local function dropTrail(other: Player)
	local trail = trails[other]
	if trail then
		local pool = parts()
		for _, dot in trail.dots do
			pool:release(dot)
		end
		trails[other] = nil
	end
end

local function stepTrails(now: number)
	if now < nextTrailSample then
		return
	end
	nextTrailSample = now + TRAIL_STEP
	for other in trails do
		if other.Parent ~= Players then
			dropTrail(other)
		end
	end
	for _, other in Players:GetPlayers() do
		local root = rootOf(other.Character)
		if not root or not rollbackReady(other) then
			dropTrail(other)
			continue
		end
		local trail = trails[other]
		if not trail then
			trail = { times = {}, points = {}, dots = {} }
			trails[other] = trail
		end
		local t = trail :: Trail
		table.insert(t.times, now)
		table.insert(t.points, root.Position - Vector3.new(0, 2.5, 0))
		while #t.times > 0 and now - t.times[1] > TRAIL_SPAN do
			table.remove(t.times, 1)
			table.remove(t.points, 1)
		end
		local color = TeamColor.forOwner(other)
		for i, point in t.points do
			local dot = t.dots[i]
			if not dot then
				dot = takePart(Enum.PartType.Ball, color)
				t.dots[i] = dot
			end
			local age = (now - t.times[i]) / TRAIL_SPAN
			dot.Color = color
			dot.Size = Vector3.one * (if i == 1 then 0.9 else 0.35)
			dot.CFrame = CFrame.new(point)
			dot.Transparency = 0.35 + 0.5 * (1 - age)
		end
		for i = #t.dots, #t.points + 1, -1 do
			parts():release(t.dots[i])
			t.dots[i] = nil
		end
	end
end

-- Slowed: a SLOWED tag over anyone a Lag Field is slowing.
local slowTags: { [Model]: BillboardGui } = {}

local function tagSlowed(model: Model?, seen: { [Model]: boolean })
	if not model then
		return
	end
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	seen[model] = true
	if slowTags[model] then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(90, 22)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
	label.TextSize = 16
	label.TextColor3 = TeamColor.forOwner(Players:GetPlayerFromCharacter(model) or model)
	label.TextStrokeTransparency = 0.4
	label.Text = "SLOWED"
	label.Parent = gui
	gui.Parent = player:FindFirstChild("PlayerGui")
	slowTags[model] = gui
end

local function stepSlowed()
	local seen: { [Model]: boolean } = {}
	for _, other in Players:GetPlayers() do
		local mult = other:GetAttribute("ModSpeedMult")
		if other ~= player and typeof(mult) == "number" and mult < 1 then
			tagSlowed(other.Character, seen)
		end
	end
	local dummies = Workspace:FindFirstChild("Dummies")
	if dummies then
		for _, m in dummies:GetChildren() do
			if m:IsA("Model") and m:GetAttribute("Slowed") == true then
				tagSlowed(m, seen)
			end
		end
	end
	for model, gui in slowTags do
		if not seen[model] then
			gui:Destroy()
			slowTags[model] = nil
		end
	end
end

local function onFx(kind: unknown, data: unknown)
	if typeof(kind) ~= "string" or typeof(data) ~= "table" then
		return
	end
	local d = data :: { [string]: any }
	if kind == "PacketThrow" then
		onPacketThrow(d)
	elseif kind == "PacketBoom" then
		onPacketBoom(d)
	elseif kind == "Heal" then
		onHeal(d)
	elseif kind == "LagThrow" then
		onLagThrow(d)
	elseif kind == "LagZone" then
		onLagZone(d)
	elseif kind == "PingPulse" then
		onPingPulse(d)
	elseif kind == "Overclock" then
		onOverclock(d)
	elseif kind == "Placed" then
		onPlaced(d)
	elseif kind == "ObjectGone" then
		onObjectGone(d)
	end
end

-- Per frame ---------------------------------------------------------------------------

local function update(_dt: number)
	local now = os.clock()
	local serverNow = Workspace:GetServerTimeNow()
	local pool = parts()

	for i = #flights, 1, -1 do
		local f = flights[i]
		local t = serverNow - f.start
		if t >= f.fuse then
			table.remove(flights, i)
			f.model.Parent = nil
			local free = grenadeFree[f.key]
			if not free then
				free = {}
				grenadeFree[f.key] = free
			end
			table.insert(free, f.model)
			pool:release(f.ring)
			continue
		end
		local pos = Projectile.positionAt(f.path, math.max(t, 0))
		f.model:PivotTo(CFrame.new(pos) * CFrame.Angles(t * 9, t * 5, 0))
		-- Fuse blink, faster as it runs out.
		local rate = 4 + 14 * (t / f.fuse)
		local on = not f.blink or math.sin(now * rate * math.pi * 2) > 0
		for _, g in f.glow do
			g.Transparency = if on then 0 else 0.6
		end
		f.ring.Transparency = 0.8 - 0.25 * (t / f.fuse) + (if on then 0 else 0.08)
	end

	for i = #booms, 1, -1 do
		local b = booms[i]
		local k = (now - b.born) / BOOM_TIME
		if k >= 1 then
			table.remove(booms, i)
			pool:release(b.sphere)
			pool:release(b.ring)
			continue
		end
		local e = 1 - (1 - k) * (1 - k)
		local d = b.radius * 2 * (0.25 + 0.75 * e)
		b.sphere.Size = Vector3.one * d
		b.sphere.CFrame = CFrame.new(b.at)
		b.sphere.Transparency = 0.25 + 0.75 * k
		local r = b.radius * 2 * (0.4 + 0.8 * e)
		b.ring.Size = Vector3.new(0.12, r, r)
		b.ring.CFrame = CFrame.new(b.at) * CFrame.Angles(0, 0, math.pi / 2)
		b.ring.Transparency = 0.4 + 0.6 * k
	end

	for i = #beams, 1, -1 do
		local b = beams[i]
		local a, z = rootOf(b.from), rootOf(b.to)
		local k = (now - b.born) / b.duration
		if k >= 1 or not a or not z then
			table.remove(beams, i)
			pool:release(b.part)
			continue
		end
		local from = a.Position + Vector3.new(0, 0.6, 0)
		local to = z.Position + Vector3.new(0, 0.6, 0)
		local length = (to - from).Magnitude
		b.part.Size = Vector3.new(0.12, 0.12, length)
		b.part.CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to)
		b.part.Transparency = 0.3 + 0.5 * k
	end

	for i = #shapes, 1, -1 do
		local s = shapes[i]
		local k = (now - s.born) / s.life
		if k >= 1 then
			table.remove(shapes, i)
			pool:release(s.part)
			continue
		end
		local e = 1 - (1 - k) * (1 - k)
		s.part.Size = s.from:Lerp(s.to, e)
		s.part.CFrame = s.cframe
		local fade = k
		if s.hold then
			local from = math.max(1 - 0.3 / s.life, 0)
			fade = if k < from then 0 else (k - from) / (1 - from)
		end
		s.part.Transparency = s.alpha0 + (s.alpha1 - s.alpha0) * fade
	end

	for model, mark in reveals do
		if now >= mark.untilT or not model.Parent then
			mark.highlight:Destroy()
			reveals[model] = nil
		end
	end
	for i = #glows, 1, -1 do
		local g = glows[i]
		local adornee = g.highlight.Adornee
		if now >= g.untilT or not adornee or not adornee.Parent then
			g.highlight:Destroy()
			table.remove(glows, i)
		end
	end
	local frame, stroke = edge, edgeStroke
	if frame and stroke and frame.Visible then
		local left = edgeUntil - now
		frame.Visible = left > 0
		local tail = if left < 0.5 then 0.4 * (1 - left / 0.5) else 0
		stroke.Transparency = math.min(0.62 + 0.12 * math.sin(now * 9) + tail, 1)
	end
	for part, at in objectFlash do
		if now - at >= 0.12 or not part.Parent then
			objectFlash[part] = nil
			if part.Parent then
				part.Color = objectColor(part)
			end
		else
			part.Color = Color3.new(1, 1, 1)
		end
	end
	stepTrails(now)

	-- Your own Rollback.
	local character = player.Character
	local rollbackAt = character and character:GetAttribute("RollbackAt")
	if typeof(rollbackAt) == "number" and rollbackAt > lastRollback then
		lastRollback = rollbackAt
		playVhs()
	end

	for i = #floaters, 1, -1 do
		local f = floaters[i]
		local k = (now - f.born) / FLOATER_TIME
		if k >= 1 then
			table.remove(floaters, i)
			f.gui.Parent = nil
			f.gui.Adornee = nil
			table.insert(floaterFree, f)
			continue
		end
		f.gui.StudsOffsetWorldSpace = Vector3.new(0, 2 + 1.5 * k, 0)
		f.label.TextTransparency = k * k
		f.label.TextStrokeTransparency = 0.4 + 0.6 * k
	end
end

function ModFxController.start()
	Net.event("ModFx").OnClientEvent:Connect(onFx)
	Net.event("ModReveal").OnClientEvent:Connect(onReveal)
	RunService.RenderStepped:Connect(update)
	-- Mod objects: coloured for this viewer as they stream in.
	task.spawn(function()
		local objects = Workspace:WaitForChild("ModObjects")
		objects.ChildAdded:Connect(function(child)
			task.defer(colourObject, child)
		end)
		for _, child in objects:GetChildren() do
			colourObject(child)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			stepSlowed()
		end
	end)
	player.CharacterAdded:Connect(function()
		lastRollback = 0
	end)
end

return ModFxController
