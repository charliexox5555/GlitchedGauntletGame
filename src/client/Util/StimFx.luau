--!strict
-- The Stim for everyone (vault/01 Design/Abilities/Stim.md → Look, Screen):
-- the beacon tossed underhand a few steps ahead (an arc from the hand,
-- tumbling a little), landing and snapping open, its zone (an
-- electric-yellow ring on the floor with arcs crackling along the edge and
-- bolts from the mast), the electric crackle on anyone stimmed (players and
-- dummies, read from their StimmedUntil, so enemies see who's stimmed), and
-- for us while stimmed: a gently pulsing yellow screen edge, the gained /
-- ending cues. Textures are the Stim's Blender renders (Config/VfxTextures
-- STIM_*), tinted electric yellow here. The beacon's status light takes the
-- caster's team colour (ModProps).
--
-- Upgrades: a drop can carry its own Look (colours, textures, sounds and
-- extra drawing hooks; UpgradeFx/Stim makes Strong Stim's and the Heal
-- Zone's). Strong Stim ("StimStrong") gets a hotter, busier crackle, a
-- stronger screen pulse and its own HUD label here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ModSounds = require(ReplicatedStorage.Shared.Config.ModSounds)
local Status = require(ReplicatedStorage.Shared.Mods.Status)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local ModAudio = require(script.Parent.ModAudio)
local ModProps = require(script.Parent.ModProps)
local ModVfx = require(script.Parent.ModVfx)

local StimFx = {}

local S = ModSounds.Stim
local player = Players.LocalPlayer

local YELLOW = Color3.fromHex("FFD23F")
local STRONG = Color3.fromHex("FFC21F") -- Strong Stim: a deeper, hotter gold
local WHITE_HOT = Color3.fromHex("FFF8E0")
local BEACON_SCALE = 1.5 -- the Blender beacon is 1.1 studs tall; knee-high reads better
local TOSS_HEIGHT = 1.4 -- studs the toss arcs above the straight line
local TOSS_TUMBLE = 300 -- degrees it pitches over in the air (lands upright)
local BOUNCE_TIME = 0.14 -- the little hop as it lands
local POP_TIME = 0.15 -- snapping open
local EDGE_ARCS = 14 -- arc emitters around the zone's edge
local BOLT_EVERY = 0.35 -- seconds between bolts from the mast to the edge
local FADE = 0.4 -- the zone dies out over this at the end
local EDGE_IN = TweenInfo.new(0.2)
local EDGE_OUT = TweenInfo.new(0.5)

local function curve(points: { number }): NumberSequence
	local keys = {}
	for i = 1, #points, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(points[i], points[i + 1]))
	end
	return NumberSequence.new(keys)
end

local function fxFolder(): Instance
	local f = Workspace:FindFirstChild("StimFx")
	if f then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "StimFx"
	made.Parent = Workspace
	return made
end

local function anchoredPart(name: string, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	return p
end

local function arcEmitter(parent: Instance, color: ColorSequence?): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "StimArcs"
	e.Texture = VFX.STIM_ARC_2x2
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	e.FlipbookMode = Enum.ParticleFlipbookMode.Random
	e.Color = color or ColorSequence.new(YELLOW)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Lifetime = NumberRange.new(0.08, 0.16)
	e.Speed = NumberRange.new(0)
	e.Rotation = NumberRange.new(0, 360)
	e.Size = curve({ 0, 1.1, 1, 0.8 })
	e.Transparency = curve({ 0, 0, 1, 0.6 })
	e.LockedToPart = true
	e.Rate = 0
	e.Parent = parent
	return e
end

-- The mast's sparks (the plain stim's).
local function sparkEmitter(parent: Instance, color: ColorSequence): ParticleEmitter
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "StimSparks"
	sparks.Texture = VFX.STIM_SPARK
	sparks.Color = color
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
	sparks.Lifetime = NumberRange.new(0.15, 0.3)
	sparks.Speed = NumberRange.new(6, 12)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.Acceleration = Vector3.new(0, -30, 0)
	sparks.Size = curve({ 0, 0.3, 1, 0.05 })
	sparks.Rate = 0
	sparks.Parent = parent
	return sparks
end

-- How one zone looks and sounds. The plain stim's is STIM below; upgrades
-- (UpgradeFx/Stim) pass their own.
export type Look = {
	color: Color3, -- the ring, beacon pops and bolts
	ring: string, -- the zone ring's texture (top view)
	ringAlpha: number, -- its transparency while it holds
	ringPulse: number, -- and its flicker
	-- One emitter per point along the edge, and how fast it emits.
	edge: (parent: Instance) -> ParticleEmitter,
	edgeRate: number,
	-- Emitters on the mast's top while the zone is up (rate set here).
	mast: (top: Attachment) -> { ParticleEmitter },
	bolts: number?, -- seconds between bolts from the mast (nil: none)
	boltColor: ColorSequence,
	boltWidth: number,
	coil: Color3?, -- recolours the beacon's yellow coil (`*_Yellow`)
	hum: ModSounds.Cue?,
	deploy: { ModSounds.Cue }, -- played together as it snaps open
	finish: ModSounds.Cue?, -- the zone dying out
	-- An upgrade's own drawing: when it snaps open, every frame while it
	-- shows, when it starts fading, and when it's gone (clean up).
	onDeploy: ((zone: Zone) -> ())?,
	onStep: ((zone: Zone, now: number) -> ())?,
	onFade: ((zone: Zone) -> ())?,
	onRemove: ((zone: Zone) -> ())?,
}

-- The beacon model (finished Blender model, else a small placeholder), and
-- its coil parts.
local function beaconModel(color: Color3, coilColor: Color3?): (Model, { BasePart })
	local finished = ModProps.finished("Stim", { "placed" })
	local model: Model
	if finished then
		model = finished:Clone()
		ModProps.tint(model, color)
		model:ScaleTo(BEACON_SCALE)
	else
		model = Instance.new("Model")
		model.Name = "Stim"
		local body = anchoredPart("Base_Shell", Vector3.new(1, 0.6, 1), CFrame.new(0, 0.3, 0))
		body.Transparency = 0
		body.Color = Color3.fromHex("2C2E35")
		body.Parent = model
		local coil =
			anchoredPart("Coil_Yellow", Vector3.new(0.35, 0.35, 0.35), CFrame.new(0, 1.2, 0))
		coil.Shape = Enum.PartType.Ball
		coil.Transparency = 0
		coil.Material = Enum.Material.Neon
		coil.Color = YELLOW
		coil.Parent = model
		local top = Instance.new("Attachment")
		top.Name = "Top"
		top.Position = Vector3.new(0, 1.4, 0)
		top.Parent = body
		model.PrimaryPart = body
		model.WorldPivot = CFrame.identity
	end
	local coils = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and string.sub(d.Name, -7) == "_Yellow" then
			table.insert(coils, d)
			if coilColor then
				d.Color = coilColor
			end
		end
	end
	return model, coils
end

-- One beacon and its zone (hooks get it as a Zone).
type Beacon = {
	look: Look,
	model: Model,
	coils: { BasePart }, -- the coil parts (an upgrade may flicker them)
	handles: { ModVfx.Handle }, -- an upgrade's extra shapes (stopped with the zone)
	spot: CFrame, -- floor, facing the caster's look
	from: Vector3, -- where it leaves the hand
	own: boolean,
	radius: number,
	releaseAt: number, -- os.clock() it leaves the hand (hidden before)
	landAt: number, -- os.clock() it lands
	landed: boolean,
	deployAt: number, -- os.clock() it snaps open
	endsAt: number, -- os.clock() the zone ends
	ring: ModVfx.Handle?,
	edge: Part, -- the arcs along the edge
	arcs: { ParticleEmitter },
	sparks: { ParticleEmitter }, -- the mast's (Look.mast)
	hum: ModAudio.Hum?,
	top: Attachment?,
	nextBolt: number,
	deployed: boolean,
	fading: boolean,
	shown: boolean, -- put in the world (a missing parent after that: it's gone)
}
export type Zone = Beacon
local beacons: { Beacon } = {}

local function plainEdge(parent: Instance): ParticleEmitter
	return arcEmitter(parent)
end

local function plainMast(top: Attachment): { ParticleEmitter }
	local sparks = sparkEmitter(top, ColorSequence.new(YELLOW))
	sparks.Rate = 12
	local arcs = arcEmitter(top)
	arcs.Rate = 8
	return { sparks, arcs }
end

-- The plain stim (L1 and path A).
local STIM: Look = {
	color = YELLOW,
	ring = VFX.STIM_RING,
	ringAlpha = 0.15,
	ringPulse = 0.12,
	edge = plainEdge,
	edgeRate = 2.5,
	mast = plainMast,
	bolts = BOLT_EVERY,
	boltColor = ColorSequence.new(YELLOW),
	boltWidth = 0.6,
	coil = nil,
	hum = S.zoneLoop,
	deploy = { S.deploy, S.deployCrackle },
	finish = S.zoneEnd,
}
StimFx.STIM = STIM
StimFx.YELLOW = YELLOW
StimFx.STRONG = STRONG
StimFx.WHITE_HOT = WHITE_HOT
StimFx.arcEmitter = arcEmitter
StimFx.sparkEmitter = sparkEmitter
StimFx.curve = curve

-- A toss (the StimDrop fx): from `start` (server time) the beacon leaves
-- the hand at `from` after `release` s, flies `toss` s to `at` (the floor),
-- facing `look`; the zone runs from `deploy` s after `start` for `duration`.
export type Drop = {
	at: Vector3,
	look: Vector3,
	from: Vector3,
	release: number,
	toss: number,
	radius: number,
	duration: number,
	deploy: number,
	start: number,
	color: Color3,
	own: boolean, -- ours: it leaves from our first-person hand (OWN_HAND)
	style: Look?, -- an upgrade's look (default: STIM)
}

-- Where our toss lets go, in camera space (Config/Viewmodel StimToss at its
-- release).
local OWN_HAND = Vector3.new(-0.22, -0.62, -1.65)

function StimFx.drop(d: Drop)
	-- Shown late (streaming, lag): skip what has already happened.
	local late = math.max(Workspace:GetServerTimeNow() - d.start, 0)
	if late > d.deploy + d.duration then
		return
	end
	local at, radius = d.at, d.radius
	local now = os.clock() - late
	local flat = Vector3.new(d.look.X, 0, d.look.Z)
	flat = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	local spot = CFrame.lookAt(at, at + flat)
	local look = d.style or STIM
	local model, coils = beaconModel(d.color, look.coil)
	model:PivotTo(CFrame.new(d.from) * spot.Rotation)
	-- Out of sight until it leaves the hand (stepBeacon parents it).
	model.Parent = nil
	-- The edge: one invisible part per beacon, emitters around it.
	local edge = anchoredPart("StimEdge", Vector3.one * 0.2, CFrame.new(at))
	local arcs = {}
	for i = 1, EDGE_ARCS do
		local a = (i / EDGE_ARCS) * math.pi * 2
		local att = Instance.new("Attachment")
		att.Position = Vector3.new(math.cos(a) * radius * 0.92, 0.5, math.sin(a) * radius * 0.92)
		att.Parent = edge
		local e = look.edge(att)
		e.Rate = 0
		table.insert(arcs, e)
	end
	edge.Parent = fxFolder()
	local top: Attachment? = nil
	for _, desc in model:GetDescendants() do
		if desc:IsA("Attachment") and desc.Name == "Top" then
			top = desc
		end
	end
	local b: Beacon = {
		look = look,
		model = model,
		coils = coils,
		handles = {},
		spot = spot,
		from = d.from,
		own = d.own,
		radius = radius,
		releaseAt = now + d.release,
		landAt = now + d.release + d.toss,
		landed = late > d.release + d.toss + 0.2, -- long down already: no landing sound
		deployAt = now + d.deploy,
		endsAt = now + d.deploy + d.duration,
		ring = nil,
		edge = edge,
		arcs = arcs,
		sparks = {},
		hum = nil,
		top = top,
		nextBolt = 0,
		deployed = false,
		fading = false,
		shown = false,
	}
	table.insert(beacons, b)
end

-- The beacon snaps open: the crackle, the ring spreading out, the hum.
local function deploy(b: Beacon)
	b.deployed = true
	local look = b.look
	local at = b.spot.Position
	for _, cue in look.deploy do
		ModAudio.play(cue, at)
	end
	ModVfx.burst(at + Vector3.new(0, 1, 0), look.color, 14, "Sparkle")
	-- The ring spreads out fast, then the zone's ring holds (flickering).
	ModVfx.quad({
		texture = look.ring,
		cframe = CFrame.new(at + Vector3.new(0, 0.08, 0)),
		from = 2,
		to = b.radius * 2,
		color = look.color,
		life = 0.35,
		alpha0 = 0,
		alpha1 = 0.6,
	})
	b.ring = ModVfx.quad({
		texture = look.ring,
		cframe = CFrame.new(at + Vector3.new(0, 0.06, 0)),
		from = b.radius * 2,
		color = look.color,
		life = math.max(b.endsAt - os.clock(), 0.1) + FADE,
		alpha0 = look.ringAlpha,
		alpha1 = 1,
		hold = true,
		pulse = look.ringPulse,
	})
	local root = b.model.PrimaryPart
	b.hum = ModAudio.hum(look.hum, root)
	local top = b.top
	if top then
		b.sparks = look.mast(top)
	end
	for _, e in b.arcs do
		e.Rate = look.edgeRate
	end
	local hook = look.onDeploy
	if hook then
		hook(b)
	end
end

-- A bolt from the mast to a random point on the edge, gone in a blink.
local function bolt(b: Beacon)
	local top = b.top
	if not top then
		return
	end
	local a = math.random() * math.pi * 2
	local r = b.radius * (0.55 + math.random() * 0.4)
	local hit = Instance.new("Attachment")
	hit.Position = Vector3.new(math.cos(a) * r, 0.3, math.sin(a) * r)
	hit.Parent = b.edge
	local beam = Instance.new("Beam")
	beam.Attachment0 = top
	beam.Attachment1 = hit
	beam.Texture = VFX.STIM_BOLT
	beam.TextureMode = Enum.TextureMode.Stretch
	beam.Color = b.look.boltColor
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Width0 = b.look.boltWidth
	beam.Width1 = b.look.boltWidth * 0.67
	beam.Transparency = NumberSequence.new(0.1)
	beam.Parent = hit
	task.delay(0.07 + math.random() * 0.05, function()
		hit:Destroy()
	end)
end

local function remove(b: Beacon)
	ModAudio.stopHum(b.hum)
	b.hum = nil
	local ring = b.ring
	if ring then
		ModVfx.stop(ring)
	end
	for _, h in b.handles do
		ModVfx.stop(h)
	end
	table.clear(b.handles)
	local hook = b.look.onRemove
	if hook then
		hook(b)
	end
	b.model:Destroy()
	b.edge:Destroy()
end

local function stepBeacon(b: Beacon, now: number): boolean
	-- Still in the hand: nothing in the world yet.
	if now < b.releaseAt then
		return true
	end
	if not b.model.Parent then
		if b.shown then
			remove(b)
			return false
		end
		b.model.Parent = fxFolder()
		b.shown = true
		local cam = Workspace.CurrentCamera
		if b.own and cam then
			b.from = cam.CFrame:PointToWorldSpace(OWN_HAND)
		end
	end
	if now < b.landAt then
		-- In the air: an arc from the hand, pitching over to land upright.
		local k = (now - b.releaseAt) / math.max(b.landAt - b.releaseAt, 1e-3)
		local pos = b.from:Lerp(b.spot.Position, k)
			+ Vector3.new(0, TOSS_HEIGHT * 4 * k * (1 - k), 0)
		b.model:PivotTo(
			CFrame.new(pos)
				* b.spot.Rotation
				* CFrame.Angles(math.rad(-TOSS_TUMBLE * (1 - k)), 0, 0)
		)
	elseif not b.landed then
		b.landed = true
		ModAudio.play(S.drop, b.spot.Position)
		ModVfx.burst(b.spot.Position + Vector3.new(0, 0.3, 0), b.look.color, 5, "Sparkle")
	end
	-- A small hop as it lands, then a pop as it snaps open.
	local since = now - b.landAt
	if since >= 0 and since < BOUNCE_TIME then
		local k = since / BOUNCE_TIME
		b.model:PivotTo(b.spot + Vector3.new(0, 0.25 * math.sin(k * math.pi), 0))
	elseif since >= BOUNCE_TIME and not b.deployed then
		b.model:PivotTo(b.spot)
	end
	if not b.deployed and now >= b.deployAt then
		deploy(b)
	end
	local sinceDeploy = now - b.deployAt
	if b.deployed and sinceDeploy < POP_TIME then
		local k = sinceDeploy / POP_TIME
		b.model:PivotTo(b.spot * CFrame.new(0, 0.15 * math.sin(k * math.pi), 0))
	end
	local boltEvery = b.look.bolts
	if boltEvery and b.deployed and now < b.endsAt and now >= b.nextBolt then
		b.nextBolt = now + boltEvery * (0.6 + math.random() * 0.8)
		bolt(b)
	end
	if now >= b.endsAt and not b.fading then
		b.fading = true
		for _, e in b.arcs do
			e.Rate = 0
		end
		for _, e in b.sparks do
			e.Rate = 0
		end
		ModAudio.stopHum(b.hum)
		b.hum = nil
		ModAudio.play(b.look.finish, b.spot.Position)
		local hook = b.look.onFade
		if hook then
			hook(b)
		end
	end
	local onStep = b.look.onStep
	if onStep and b.deployed then
		onStep(b, now)
	end
	if now >= b.endsAt + FADE then
		remove(b)
		return false
	end
	return true
end

-- The crackle on anyone stimmed: yellow for Stimmed; for Strong Stim
-- hotter (white-hot fading to gold), busier and bigger, with sparks
-- spitting up off the body.
type Body = { arcs: ParticleEmitter, sparks: ParticleEmitter?, strong: boolean }
local bodies: { [Model]: Body } = {}

local PLAIN_ARCS = ColorSequence.new(YELLOW)
local STRONG_ARCS = ColorSequence.new(WHITE_HOT, STRONG)

local function bodyOn(model: Model, root: BasePart): Body
	local body = bodies[model]
	if body and body.arcs.Parent == root then
		return body
	end
	local existing = root:FindFirstChild("StimCrackle")
	local made: ParticleEmitter
	if existing and existing:IsA("ParticleEmitter") then
		made = existing
	else
		made = arcEmitter(root)
		made.Name = "StimCrackle"
		made.Shape = Enum.ParticleEmitterShape.Box
	end
	-- (Re)starts plain; setStrong steps it up.
	made.Color = PLAIN_ARCS
	made.Size = curve({ 0, 0.9, 1, 0.6 })
	local surge = root:FindFirstChild("StimSurge")
	local fresh: Body = {
		arcs = made,
		sparks = if surge and surge:IsA("ParticleEmitter") then surge else nil,
		strong = false,
	}
	bodies[model] = fresh
	return fresh
end

local function setStrong(body: Body, root: BasePart, strong: boolean)
	if body.strong == strong then
		return
	end
	body.strong = strong
	body.arcs.Color = if strong then STRONG_ARCS else PLAIN_ARCS
	body.arcs.Size = if strong then curve({ 0, 1.3, 1, 0.8 }) else curve({ 0, 0.9, 1, 0.6 })
	if strong and not body.sparks then
		local sparks = sparkEmitter(root, STRONG_ARCS)
		sparks.Name = "StimSurge"
		sparks.Shape = Enum.ParticleEmitterShape.Box
		sparks.EmissionDirection = Enum.NormalId.Top
		sparks.Acceleration = Vector3.new(0, -10, 0)
		body.sparks = sparks
	end
end

-- Our screen while stimmed.
local edgeGlow: ImageLabel? = nil
local stimLevel = 0 -- 0 none, 1 Stimmed, 2 Strong Stim

local function screen(): ImageLabel
	local e = edgeGlow
	if e and e.Parent then
		return e
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "StimScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 2
	gui.Parent = player:WaitForChild("PlayerGui")
	local img = Instance.new("ImageLabel")
	img.Name = "Edge"
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.Image = VFX.STIM_EDGE
	img.ImageColor3 = YELLOW
	img.ImageTransparency = 1
	img.ScaleType = Enum.ScaleType.Stretch
	img.Parent = gui
	edgeGlow = img
	return img
end

local function setStimmed(level: number, was: number)
	local img = screen()
	if level > 0 then
		-- Gaining it, or stepping up to Strong Stim: the zap (higher for strong).
		if level > was then
			ModAudio.play(S.gained, nil, if level == 2 then 1.15 else nil)
		end
		img.ImageColor3 = if level == 2 then STRONG else YELLOW
		local alpha = if level == 2 then 0.3 else 0.5
		TweenService:Create(img, EDGE_IN, { ImageTransparency = alpha }):Play()
	else
		ModAudio.play(S.ending)
		TweenService:Create(img, EDGE_OUT, { ImageTransparency = 1 }):Play()
	end
end

local function levelOf(model: Instance?, serverNow: number): number
	if Status.active(model, "StimStrong", serverNow) then
		return 2
	end
	return if Status.active(model, "Stimmed", serverNow) then 1 else 0
end

-- Per frame (ModFxController.update).
function StimFx.step()
	local now = os.clock()
	for i = #beacons, 1, -1 do
		if not stepBeacon(beacons[i], now) then
			table.remove(beacons, i)
		end
	end
	local serverNow = Workspace:GetServerTimeNow()
	local function check(model: Instance)
		if not model:IsA("Model") then
			return
		end
		local level = levelOf(model, serverNow)
		if level == 0 and not bodies[model] then
			return
		end
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		local body = bodyOn(model, root)
		if level > 0 then
			setStrong(body, root, level == 2)
		end
		body.arcs.Rate = if level == 2 then 30 elseif level == 1 then 14 else 0
		local sparks = body.sparks
		if sparks then
			sparks.Rate = if level == 2 then 10 else 0
		end
	end
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if character then
			check(character)
		end
	end
	local dummies = Workspace:FindFirstChild("Dummies")
	if dummies then
		for _, d in dummies:GetChildren() do
			check(d)
		end
	end
	for model, body in bodies do
		if not model.Parent or not body.arcs.Parent then
			bodies[model] = nil
		end
	end
	local mine = levelOf(player.Character, serverNow)
	if mine ~= stimLevel then
		local was = stimLevel
		stimLevel = mine
		setStimmed(mine, was)
	end
	-- A gentle pulse while it lasts (the tweens set the start and the end);
	-- Strong Stim pulses faster and deeper.
	local e = edgeGlow
	if mine > 0 and e and e.ImageTransparency < 0.95 then
		if mine == 2 then
			e.ImageTransparency = 0.2 + 0.35 * (0.5 + 0.5 * math.sin(now * 8))
		else
			e.ImageTransparency = 0.45 + 0.25 * (0.5 + 0.5 * math.sin(now * 5))
		end
	end
end

-- Seconds of stim (Stimmed or Strong Stim) we have left (0 = none), for the HUD.
function StimFx.stimmedLeft(): number
	local character = player.Character
	local untilT =
		math.max(Status.until_(character, "Stimmed"), Status.until_(character, "StimStrong"))
	return math.max(untilT - Workspace:GetServerTimeNow(), 0)
end

-- Whether our stim right now is Strong Stim (the HUD's label).
function StimFx.strong(): boolean
	return Status.active(player.Character, "StimStrong", Workspace:GetServerTimeNow())
end

return StimFx
