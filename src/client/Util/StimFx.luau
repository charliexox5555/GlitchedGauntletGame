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

local function arcEmitter(parent: Instance): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "StimArcs"
	e.Texture = VFX.STIM_ARC_2x2
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	e.FlipbookMode = Enum.ParticleFlipbookMode.Random
	e.Color = ColorSequence.new(YELLOW)
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

-- The beacon model (finished Blender model, else a small placeholder).
local function beaconModel(color: Color3): Model
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
	return model
end

-- One beacon and its zone.
type Beacon = {
	model: Model,
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
	sparks: ParticleEmitter?,
	hum: ModAudio.Hum?,
	top: Attachment?,
	nextBolt: number,
	deployed: boolean,
	fading: boolean,
	shown: boolean, -- put in the world (a missing parent after that: it's gone)
}
local beacons: { Beacon } = {}

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
	local model = beaconModel(d.color)
	model:PivotTo(CFrame.new(d.from) * spot.Rotation)
	-- Out of sight until it leaves the hand (stepBeacon parents it).
	model.Parent = nil
	-- The edge: one invisible part per beacon, arc emitters around it.
	local edge = anchoredPart("StimEdge", Vector3.one * 0.2, CFrame.new(at))
	local arcs = {}
	for i = 1, EDGE_ARCS do
		local a = (i / EDGE_ARCS) * math.pi * 2
		local att = Instance.new("Attachment")
		att.Position = Vector3.new(math.cos(a) * radius * 0.92, 0.5, math.sin(a) * radius * 0.92)
		att.Parent = edge
		table.insert(arcs, arcEmitter(att))
	end
	edge.Parent = fxFolder()
	local top: Attachment? = nil
	for _, desc in model:GetDescendants() do
		if desc:IsA("Attachment") and desc.Name == "Top" then
			top = desc
		end
	end
	local b: Beacon = {
		model = model,
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
		sparks = nil,
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
	local at = b.spot.Position
	ModAudio.play(S.deploy, at)
	ModAudio.play(S.deployCrackle, at)
	ModVfx.burst(at + Vector3.new(0, 1, 0), YELLOW, 14, "Sparkle")
	-- The ring spreads out fast, then the zone's ring holds (flickering).
	ModVfx.quad({
		texture = VFX.STIM_RING,
		cframe = CFrame.new(at + Vector3.new(0, 0.08, 0)),
		from = 2,
		to = b.radius * 2,
		color = YELLOW,
		life = 0.35,
		alpha0 = 0,
		alpha1 = 0.6,
	})
	b.ring = ModVfx.quad({
		texture = VFX.STIM_RING,
		cframe = CFrame.new(at + Vector3.new(0, 0.06, 0)),
		from = b.radius * 2,
		color = YELLOW,
		life = math.max(b.endsAt - os.clock(), 0.1) + FADE,
		alpha0 = 0.15,
		alpha1 = 1,
		hold = true,
		pulse = 0.12,
	})
	local root = b.model.PrimaryPart
	b.hum = ModAudio.hum(S.zoneLoop, root)
	local top = b.top
	if top then
		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "StimSparks"
		sparks.Texture = VFX.STIM_SPARK
		sparks.Color = ColorSequence.new(YELLOW)
		sparks.LightEmission = 1
		sparks.LightInfluence = 0
		sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
		sparks.Lifetime = NumberRange.new(0.15, 0.3)
		sparks.Speed = NumberRange.new(6, 12)
		sparks.SpreadAngle = Vector2.new(70, 70)
		sparks.Acceleration = Vector3.new(0, -30, 0)
		sparks.Size = curve({ 0, 0.3, 1, 0.05 })
		sparks.Rate = 12
		sparks.Parent = top
		b.sparks = sparks
		arcEmitter(top).Rate = 8
	end
	for _, e in b.arcs do
		e.Rate = 2.5
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
	beam.Color = ColorSequence.new(YELLOW)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Width0 = 0.6
	beam.Width1 = 0.4
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
		ModVfx.burst(b.spot.Position + Vector3.new(0, 0.3, 0), YELLOW, 5, "Sparkle")
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
	if b.deployed and now < b.endsAt and now >= b.nextBolt then
		b.nextBolt = now + BOLT_EVERY * (0.6 + math.random() * 0.8)
		bolt(b)
	end
	if now >= b.endsAt and not b.fading then
		b.fading = true
		for _, e in b.arcs do
			e.Rate = 0
		end
		local sparks = b.sparks
		if sparks then
			sparks.Rate = 0
		end
		ModAudio.stopHum(b.hum)
		b.hum = nil
		ModAudio.play(S.zoneEnd, b.spot.Position)
	end
	if now >= b.endsAt + FADE then
		remove(b)
		return false
	end
	return true
end

-- The crackle on anyone stimmed.
local bodies: { [Model]: ParticleEmitter } = {}

local function crackleOn(model: Model, root: BasePart): ParticleEmitter
	local e = bodies[model]
	if e and e.Parent == root then
		return e
	end
	local existing = root:FindFirstChild("StimCrackle")
	local made: ParticleEmitter
	if existing and existing:IsA("ParticleEmitter") then
		made = existing
	else
		made = arcEmitter(root)
		made.Name = "StimCrackle"
		made.Shape = Enum.ParticleEmitterShape.Box
		made.Size = curve({ 0, 0.9, 1, 0.6 })
	end
	bodies[model] = made
	return made
end

-- Our screen while stimmed.
local edgeGlow: ImageLabel? = nil
local stimmedNow = false

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

local function setStimmed(on: boolean)
	local img = screen()
	if on then
		ModAudio.play(S.gained)
		TweenService:Create(img, EDGE_IN, { ImageTransparency = 0.5 }):Play()
	else
		ModAudio.play(S.ending)
		TweenService:Create(img, EDGE_OUT, { ImageTransparency = 1 }):Play()
	end
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
		local on = Status.active(model, "Stimmed", serverNow)
		if not on and not bodies[model] then
			return
		end
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		crackleOn(model, root).Rate = if on then 14 else 0
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
	for model, e in bodies do
		if not model.Parent or not e.Parent then
			bodies[model] = nil
		end
	end
	local mine = Status.active(player.Character, "Stimmed", serverNow)
	if mine ~= stimmedNow then
		stimmedNow = mine
		setStimmed(mine)
	end
	-- A gentle pulse while it lasts (the tweens set the start and the end).
	local e = edgeGlow
	if mine and e and e.ImageTransparency < 0.95 then
		e.ImageTransparency = 0.45 + 0.25 * (0.5 + 0.5 * math.sin(now * 5))
	end
end

-- Seconds of Stimmed we have left (0 = none), for the HUD.
function StimFx.stimmedLeft(): number
	return math.max(Status.until_(player.Character, "Stimmed") - Workspace:GetServerTimeNow(), 0)
end

return StimFx
