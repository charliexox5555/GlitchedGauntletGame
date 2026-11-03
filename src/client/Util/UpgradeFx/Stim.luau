--!strict
-- Stim's upgrade levels on the client (vault/01 Design/Abilities/Upgrade
-- Paths.md → 8. Stim; Stim.md → Upgrades). The StimDrop of a path B or
-- glitch level is drawn with its own StimFx.Look (Util/StimFx keeps the
-- toss, the beacon and the zone's timing, so two zones at once each run
-- their own).
--
--   A2 / A3 Quick Stims   the plain look (StimFx's default): nothing here
--   B2 / B3 Strong Stim   a hotter, busier zone: white-hot-to-gold arcs and
--                         sparks, bolts twice as often and thicker, a second
--                         ring spinning inside the edge, the hum pitched up.
--                         Stimmed bodies, the screen and the HUD: StimFx
--                         reads StimStrong.
--   G2 / G3 Heal Zone     the Heal Orb's look (Util/HealFx's green-teal halo
--                         ring, motes and wisps, its chimes as a soft hum)
--                         with the glitch on top: magenta static pixels,
--                         tearing scanlines, the ring and coil flickering
--                         magenta, the beacon jittering. Anyone being healed
--                         inside glows and shows "+N"; read from their health
--                         going up, so it only shows what the server healed.
--                         Look (stylized, 2026-11-03), with the GlitchVFX kit
--                         installed (Util/GlitchVfx): a hex-tile floor and a
--                         stepped pixel ring instead of the soft glow, chunky
--                         pixel pluses rising instead of the cross and mote
--                         particles, the wisps cut to an accent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Mods)
local ModSounds = require(ReplicatedStorage.Shared.Config.ModSounds)
local Mods = require(ReplicatedStorage.Shared.Mods)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)
local Zone = require(ReplicatedStorage.Shared.Mods.Blocks.Zone)

local GlitchVfx = require(script.Parent.Parent.GlitchVfx)
local ModAudio = require(script.Parent.Parent.ModAudio)
local ModVfx = require(script.Parent.Parent.ModVfx)
local StimFx = require(script.Parent.Parent.StimFx)
local TeamColor = require(script.Parent.Parent.TeamColor)
local Types = require(script.Parent.Types)

local handler: Types.Handler = {}

local player = Players.LocalPlayer
local S = ModSounds.Stim
local curve = StimFx.curve

local HEAL = Color3.fromHex("5CFFC8") -- the Heal Orb's green-teal (Util/HealFx)
local GLITCH = Config.COLORS.glitch
local HEAL_STATS = Mods.stats("Stim", "G2")
local ZONE_HEIGHT: number = if HEAL_STATS then HEAL_STATS.height else 8

-- Strong Stim ---------------------------------------------------------------------

local STRONG_SEQ = ColorSequence.new(StimFx.WHITE_HOT, StimFx.STRONG)

local function strongEdge(parent: Instance): ParticleEmitter
	local e = StimFx.arcEmitter(parent, STRONG_SEQ)
	e.Size = curve({ 0, 1.5, 1, 1.1 })
	return e
end

local function strongMast(top: Attachment): { ParticleEmitter }
	local sparks = StimFx.sparkEmitter(top, STRONG_SEQ)
	sparks.Speed = NumberRange.new(8, 16)
	sparks.Rate = 26
	local arcs = StimFx.arcEmitter(top, STRONG_SEQ)
	arcs.Size = curve({ 0, 1.6, 1, 1.1 })
	arcs.Rate = 16
	return { sparks, arcs }
end

-- Opening: a bigger pop and a dashed ring spinning just inside the edge.
local function strongDeploy(zone: StimFx.Zone)
	local at = zone.spot.Position
	ModVfx.burst(at + Vector3.new(0, 1, 0), StimFx.WHITE_HOT, 12, "Glow")
	table.insert(
		zone.handles,
		ModVfx.quad({
			texture = VFX.MOD_RING_DASHED,
			cframe = CFrame.new(at + Vector3.new(0, 0.1, 0)),
			from = 2,
			to = zone.radius * 2 * 0.85,
			color = StimFx.STRONG,
			life = math.max(zone.endsAt - os.clock(), 0.1) + 0.4,
			alpha0 = 0.3,
			alpha1 = 1,
			hold = true,
			spin = 1.4,
		})
	)
end

local strongHum: ModSounds.Cue = table.clone(S.zoneLoop)
strongHum.pitch = 1.12
strongHum.volume = S.zoneLoop.volume * 1.15

local STRONG_LOOK: StimFx.Look = {
	color = StimFx.STRONG,
	ring = VFX.STIM_RING,
	ringAlpha = 0.05,
	ringPulse = 0.18,
	edge = strongEdge,
	edgeRate = 6,
	mast = strongMast,
	bolts = StimFx.STIM.bolts and StimFx.STIM.bolts * 0.5,
	boltColor = STRONG_SEQ,
	boltWidth = 0.9,
	coil = StimFx.WHITE_HOT,
	hum = strongHum,
	deploy = { S.deploy, S.deployCrackle, S.gained },
	finish = S.zoneEnd,
	onDeploy = strongDeploy,
}

-- Heal Zone -----------------------------------------------------------------------

local PIXEL_RATE = 32 -- static pixels a second
local PIXEL_MAX = 16 -- live at once per zone
-- With the GlitchVFX kit (sizes: the hex floor is 1.77 across, the ring 2.05).
local KIT_HEX_SPAN = 1.77
local KIT_RING_SPAN = 2.05
local PLUS_RATE = 2.5 -- pixel pluses rising a second
local PLUS_RISE = 2.4 -- studs/s
local PLUS_LIFE = 1.1

type Pixel = { part: Part, untilT: number }
type HealState = {
	fill: { ParticleEmitter }, -- motes and crosses rising across the floor
	pixels: { Pixel },
	free: { Part },
	spawn: number, -- pixels owed (fractional)
	last: number, -- os.clock() of the last step
	nextGlitch: number, -- the next flicker moment
	glitchUntil: number,
	nextTear: number,
	jittered: boolean, -- the beacon is off its spot
	kit: { GlitchVfx.Handle }, -- the kit's floor and ring (stopped with the zone)
	floor: GlitchVfx.Handle?,
	plus: number, -- pluses owed (fractional; the kit only)
}
local healZones: { [StimFx.Zone]: HealState } = {}

local function healEdge(parent: Instance): ParticleEmitter
	local w = Instance.new("ParticleEmitter")
	w.Name = "HealZoneWisps"
	w.Texture = VFX.HEALORB_WISP_2x2
	w.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	w.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	w.Color = ColorSequence.new(HEAL)
	w.Lifetime = NumberRange.new(1, 1.4)
	w.Speed = NumberRange.new(1.5, 2.5)
	w.EmissionDirection = Enum.NormalId.Top
	w.SpreadAngle = Vector2.new(10, 10)
	w.Size = curve({ 0, 1, 1, 1.8 })
	w.Transparency = curve({ 0, 1, 0.25, 0.45, 1, 1 })
	w.LightEmission = 0.8
	w.LightInfluence = 0
	w.Rotation = NumberRange.new(0, 360)
	w.Parent = parent
	return w
end

local function moteEmitter(parent: Instance): ParticleEmitter
	local m = Instance.new("ParticleEmitter")
	m.Name = "HealZoneMotes"
	m.Texture = VFX.HEALORB_MOTE
	m.Color = ColorSequence.new(HEAL)
	m.Lifetime = NumberRange.new(1, 1.6)
	m.Speed = NumberRange.new(1.5, 3.5)
	m.EmissionDirection = Enum.NormalId.Top
	m.SpreadAngle = Vector2.new(20, 20)
	m.Size = curve({ 0, 0.3, 1, 0.08 })
	m.Transparency = curve({ 0, 0.2, 1, 1 })
	m.LightEmission = 1
	m.LightInfluence = 0
	m.Rate = 0
	m.Parent = parent
	return m
end

local function crossEmitter(parent: Instance): ParticleEmitter
	local c = Instance.new("ParticleEmitter")
	c.Name = "HealZoneCrosses"
	c.Texture = VFX.MOD_CROSS
	c.Color = ColorSequence.new(HEAL)
	c.Lifetime = NumberRange.new(0.9, 1.4)
	c.Speed = NumberRange.new(1, 2.5)
	c.EmissionDirection = Enum.NormalId.Top
	c.Size = curve({ 0, 0.45, 1, 0.15 })
	c.Transparency = curve({ 0, 0.3, 1, 1 })
	c.LightEmission = 1
	c.LightInfluence = 0
	c.Rate = 0
	c.Parent = parent
	return c
end

local function healMast(top: Attachment): { ParticleEmitter }
	local motes = moteEmitter(top)
	motes.SpreadAngle = Vector2.new(35, 35)
	motes.Rate = 10
	return { motes }
end

-- A flat invisible part on the floor that emits over its area: two of them
-- turned 45° apart cover the zone's circle as an octagon.
local function floorEmitters(zone: StimFx.Zone, state: HealState)
	local side = zone.radius * 1.41
	for _, yaw in { 0, 45 } do
		local p = Instance.new("Part")
		p.Name = "HealZoneFloor"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 1
		p.Size = Vector3.new(side, 0.2, side)
		p.CFrame = CFrame.new(zone.spot.Position + Vector3.new(0, 0.2, 0))
			* CFrame.Angles(0, math.rad(yaw), 0)
		p.Parent = zone.edge
		local motes = moteEmitter(p)
		motes.Shape = Enum.ParticleEmitterShape.Box
		table.insert(state.fill, motes)
		if state.floor then
			motes.Rate = 2 -- the kit's pluses carry it
		else
			motes.Rate = 7
			local crosses = crossEmitter(p)
			crosses.Shape = Enum.ParticleEmitterShape.Box
			crosses.Rate = 2
			table.insert(state.fill, crosses)
		end
	end
end

local function healDeploy(zone: StimFx.Zone)
	local at = zone.spot.Position
	local now = os.clock()
	local life = math.max(zone.endsAt - now, 0.1) + 0.4
	ModVfx.burst(at + Vector3.new(0, 1, 0), HEAL, 16, "Cross")
	ModVfx.burst(at + Vector3.new(0, 1, 0), GLITCH, 8, "Sparkle")
	-- A soft glowing floor (with the kit: hex tiles and a stepped ring), and
	-- the glitch's dashed magenta rim just outside the halo, flickering.
	local kit: { GlitchVfx.Handle } = {}
	local hex = zone.radius * 2 / KIT_HEX_SPAN
	local floor = GlitchVfx.piece({
		name = "HexFloor_Energy",
		cframe = CFrame.new(at + Vector3.new(0, 0.06, 0)),
		scale = Vector3.new(hex * 0.3, 1, hex * 0.3),
		scale1 = Vector3.new(hex, 1, hex),
		color = HEAL,
		life = life,
		alpha0 = 0.6,
		hold = true,
		spin = Vector3.new(0, 0.25, 0),
	})
	if floor then
		table.insert(kit, floor)
		local ring = zone.radius * 2 / KIT_RING_SPAN
		local edge = GlitchVfx.piece({
			name = "PixelRing_Energy",
			cframe = CFrame.new(at + Vector3.new(0, 0.05, 0)),
			scale = Vector3.new(ring, 2, ring),
			color = HEAL,
			life = life,
			alpha0 = 0.2,
			hold = true,
			spin = Vector3.new(0, -0.35, 0),
		})
		if edge then
			table.insert(kit, edge)
		end
	else
		table.insert(
			zone.handles,
			ModVfx.quad({
				texture = VFX.MOD_GLOW,
				cframe = CFrame.new(at + Vector3.new(0, 0.04, 0)),
				from = zone.radius * 2,
				color = HEAL,
				life = life,
				alpha0 = 0.8,
				alpha1 = 1,
				hold = true,
			})
		)
	end
	table.insert(
		zone.handles,
		ModVfx.quad({
			texture = VFX.MOD_RING_DASHED,
			cframe = CFrame.new(at + Vector3.new(0, 0.09, 0)),
			from = zone.radius * 2 * 1.05,
			color = GLITCH,
			life = life,
			alpha0 = 0.45,
			alpha1 = 1,
			hold = true,
			pulse = 0.35,
			spin = -0.3,
		})
	)
	local state: HealState = {
		fill = {},
		pixels = {},
		free = {},
		spawn = 0,
		last = now,
		nextGlitch = now + 0.6,
		glitchUntil = 0,
		nextTear = now + 0.4,
		jittered = false,
		kit = kit,
		floor = floor,
		plus = 0,
	}
	floorEmitters(zone, state)
	healZones[zone] = state
end

local function pixel(zone: StimFx.Zone, state: HealState, now: number): Part
	local p = table.remove(state.free)
	if not p then
		local made = Instance.new("Part")
		made.Name = "GlitchPixel"
		made.Anchored = true
		made.CanCollide = false
		made.CanQuery = false
		made.CanTouch = false
		made.CastShadow = false
		made.Material = Enum.Material.Neon
		made.Parent = zone.edge
		p = made
	end
	local part = p :: Part
	table.insert(state.pixels, { part = part, untilT = now + 0.05 + math.random() * 0.09 })
	return part
end

-- One square of static: mostly on the rim, some inside; mostly magenta.
local function staticPixel(zone: StimFx.Zone, state: HealState, now: number)
	local p = pixel(zone, state, now)
	local a = math.random() * math.pi * 2
	local r = if math.random() < 0.6
		then zone.radius * (0.9 + math.random() * 0.14)
		else zone.radius * math.sqrt(math.random()) * 0.9
	local s = 0.2 + math.random() * 0.45
	p.Size = Vector3.new(s * (1 + math.random() * 2), s, s)
	p.Color = if math.random() < 0.8 then GLITCH else HEAL
	p.Transparency = math.random() * 0.3
	p.CFrame = CFrame.new(
		zone.spot.Position
			+ Vector3.new(math.cos(a) * r, 0.15 + math.random() * 2.4, math.sin(a) * r)
	) * CFrame.Angles(0, a, 0)
end

-- A thin magenta scanline tearing across the zone for a blink.
local function tear(zone: StimFx.Zone, state: HealState, now: number)
	local p = pixel(zone, state, now)
	p.Size = Vector3.new(zone.radius * 2 * (0.4 + math.random() * 0.6), 0.06, 0.25)
	p.Color = GLITCH
	p.Transparency = 0.3
	local yaw = math.random() * math.pi * 2
	local off = (math.random() * 2 - 1) * zone.radius * 0.5
	p.CFrame = CFrame.new(zone.spot.Position + Vector3.new(0, 0.3 + math.random() * 2.7, 0))
		* CFrame.Angles(0, yaw, 0)
		* CFrame.new(0, 0, off)
end

-- A chunky pixel plus rising off the floor and turning (the kit).
local function risePlus(zone: StimFx.Zone)
	local a = math.random() * math.pi * 2
	local r = zone.radius * math.sqrt(math.random()) * 0.85
	local s = 0.45 + math.random() * 0.25
	GlitchVfx.piece({
		name = "Plus_Energy",
		cframe = CFrame.new(
			zone.spot.Position
				+ Vector3.new(math.cos(a) * r, 0.4 + math.random() * 0.6, math.sin(a) * r)
		) * CFrame.Angles(0, math.random() * math.pi * 2, 0),
		scale = Vector3.one * s,
		scale1 = Vector3.one * s * 0.4,
		color = if math.random() < 0.15 then GLITCH else HEAL,
		life = PLUS_LIFE,
		alpha0 = 0.1,
		velocity = Vector3.new(0, PLUS_RISE, 0),
		spin = Vector3.new(0, 3, 0),
		stutter = 0.04,
	})
end

local glitchBlip: ModSounds.Cue = table.clone(S.zoneEnd)
glitchBlip.volume = 0.12

local function healStep(zone: StimFx.Zone, now: number)
	local state = healZones[zone]
	if not state then
		return
	end
	local dt = math.min(now - state.last, 0.1)
	state.last = now
	for i = #state.pixels, 1, -1 do
		local px = state.pixels[i]
		if now >= px.untilT then
			px.part.Transparency = 1
			table.insert(state.free, px.part)
			table.remove(state.pixels, i)
		end
	end
	if zone.fading then
		return
	end
	state.spawn += dt * PIXEL_RATE
	while state.spawn >= 1 do
		state.spawn -= 1
		if #state.pixels < PIXEL_MAX then
			staticPixel(zone, state, now)
		end
	end
	if now >= state.nextTear then
		state.nextTear = now + 0.7 + math.random() * 1.1
		tear(zone, state, now)
	end
	if state.floor then
		state.plus += dt * PLUS_RATE
		while state.plus >= 1 do
			state.plus -= 1
			risePlus(zone)
		end
	end
	-- Now and then a glitch moment: the halo blinks, the coil flashes
	-- magenta, the beacon jumps off its spot, a quiet static blip.
	if now >= state.nextGlitch then
		state.nextGlitch = now + 1.2 + math.random() * 1.8
		state.glitchUntil = now + 0.08 + math.random() * 0.12
		if math.random() < 0.35 then
			ModAudio.play(glitchBlip, zone.spot.Position, 1.3 + math.random() * 0.3)
		end
	end
	local glitching = now < state.glitchUntil
	local ring = zone.ring
	local decal = ring and ring.decal
	if glitching and decal then
		decal.Transparency = if math.random() < 0.5 then 1 else 0.05
	end
	for _, coil in zone.coils do
		coil.Color = if glitching and math.random() < 0.7 then GLITCH else HEAL
	end
	local floor = state.floor
	if floor then
		floor.part.Color = if glitching and math.random() < 0.6 then GLITCH else HEAL
	end
	local popped = now - zone.deployAt > 0.25 -- StimFx's snap-open is done
	if glitching and popped then
		local a = math.random() * math.pi * 2
		local d = 0.15 + math.random() * 0.25
		zone.model:PivotTo(zone.spot + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d))
		state.jittered = true
	elseif state.jittered then
		zone.model:PivotTo(zone.spot)
		state.jittered = false
	end
end

local function healFade(zone: StimFx.Zone)
	local state = healZones[zone]
	if state then
		for _, e in state.fill do
			e.Rate = 0
		end
		for _, h in state.kit do
			GlitchVfx.stop(h)
		end
	end
end

local function healRemove(zone: StimFx.Zone)
	-- The pixels and floor emitters are children of the zone's edge part,
	-- which StimFx destroys. The kit's pieces are pooled: stop them.
	local state = healZones[zone]
	if state then
		for _, h in state.kit do
			GlitchVfx.stop(h)
		end
	end
	healZones[zone] = nil
end

local healHum: ModSounds.Cue = table.clone(ModSounds.HealOrb.healLoop)
healHum.volume = ModSounds.HealOrb.healLoop.volume * 0.6
healHum.range = 40

local HEAL_LOOK: StimFx.Look = {
	color = HEAL,
	ring = VFX.HEALORB_RING,
	ringAlpha = 0.15,
	ringPulse = 0.05,
	edge = healEdge,
	edgeRate = 1.5,
	mast = healMast,
	bolts = nil,
	boltColor = ColorSequence.new(HEAL),
	boltWidth = 0.5,
	coil = HEAL,
	hum = healHum,
	deploy = { S.deploy, ModSounds.HealOrb.form },
	finish = S.zoneEnd, -- the static fizzle: the glitch dying out
	onDeploy = healDeploy,
	onStep = healStep,
	onFade = healFade,
	onRemove = healRemove,
}
-- With the GlitchVFX kit the edge wisps are only an accent (the pixel ring
-- and the pluses carry the zone).
local HEAL_KIT_LOOK: StimFx.Look = table.clone(HEAL_LOOK)
HEAL_KIT_LOOK.edgeRate = 0.5

-- Who's being healed inside a Heal Zone: a glow while their health climbs,
-- "+N" over their head every NUMBER_EVERY s, and a soft screen edge for us.

local NUMBER_EVERY = 1
local GLOW_HOLD = 0.35 -- seconds the glow stays after the last tick
local FLOAT_TIME = 0.9

type Healed = {
	last: number, -- health last frame
	pending: number, -- healed since the last number
	nextNumber: number,
	glowUntil: number,
	motes: ParticleEmitter,
	crosses: ParticleEmitter,
}
local healed: { [Model]: Healed } = {}

type Float = { gui: BillboardGui, label: TextLabel, born: number }
local floats: { Float } = {}
local floatFree: { Float } = {}

local function float(model: Model, amount: number)
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local f = table.remove(floatFree)
	if not f then
		local gui = Instance.new("BillboardGui")
		gui.Name = "HealZoneNumber"
		gui.Size = UDim2.fromOffset(90, 32)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.ResetOnSpawn = false
		gui.MaxDistance = 120
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.FontFace =
			Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
		label.TextSize = 22
		label.TextColor3 = HEAL
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.Parent = gui
		f = { gui = gui, label = label, born = 0 }
	end
	local fl = f :: Float
	fl.label.Text = "+" .. tostring(math.floor(amount + 0.5))
	fl.gui.Adornee = head
	fl.gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
	fl.gui.Parent = player:FindFirstChild("PlayerGui")
	fl.born = os.clock()
	table.insert(floats, fl)
end

local screenEdge: ImageLabel? = nil

local function edgeLabel(): ImageLabel
	local e = screenEdge
	if e and e.Parent then
		return e
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "HealZoneScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 2
	gui.Parent = player:WaitForChild("PlayerGui")
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.Image = VFX.HEALORB_EDGE
	img.ImageColor3 = HEAL
	img.ImageTransparency = 1
	img.ScaleType = Enum.ScaleType.Stretch
	img.Parent = gui
	screenEdge = img
	return img
end

local function insideAny(root: BasePart): boolean
	for zone in healZones do
		if not zone.fading then
			local z: Zone.Zone =
				{ center = zone.spot.Position, radius = zone.radius, height = ZONE_HEIGHT }
			if Zone.contains(z, root.Position) then
				return true
			end
		end
	end
	return false
end

local function track(model: Model, humanoid: Humanoid, root: BasePart): Healed
	local motes = moteEmitter(root)
	motes.Name = "HealZoneGlow"
	motes.Shape = Enum.ParticleEmitterShape.Box
	local crosses = crossEmitter(root)
	crosses.Name = "HealZoneGlowCrosses"
	crosses.Shape = Enum.ParticleEmitterShape.Box
	local rec: Healed = {
		last = humanoid.Health,
		pending = 0,
		nextNumber = 0,
		glowUntil = 0,
		motes = motes,
		crosses = crosses,
	}
	healed[model] = rec
	return rec
end

local function untrack(model: Model, rec: Healed)
	rec.motes:Destroy()
	rec.crosses:Destroy()
	healed[model] = nil
end

local function watch(model: Instance, now: number)
	if not model:IsA("Model") then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	local inside = humanoid.Health > 0 and insideAny(root)
	local rec = healed[model]
	if not rec then
		if not inside then
			return
		end
		rec = track(model, humanoid, root)
	end
	local r = rec :: Healed
	local health = humanoid.Health
	if inside and health > r.last + 1e-3 then
		r.pending += health - r.last
		r.glowUntil = now + GLOW_HOLD
	end
	r.last = health
	local glowing = now < r.glowUntil
	r.motes.Rate = if glowing then 14 else 0
	r.crosses.Rate = if glowing then 4 else 0
	if r.pending >= 1 and now >= r.nextNumber then
		r.nextNumber = now + NUMBER_EVERY
		if model ~= player.Character then
			float(model, r.pending)
		end
		r.pending = 0
	end
	if not inside and not glowing and now > r.glowUntil + 1.5 then
		untrack(model, r)
	end
end

local function stepHealed(now: number, dt: number)
	if next(healZones) == nil and next(healed) == nil then
		return
	end
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if character then
			watch(character, now)
		end
	end
	local dummies = Workspace:FindFirstChild("Dummies")
	if dummies then
		for _, d in dummies:GetChildren() do
			watch(d, now)
		end
	end
	for model, rec in healed do
		if not model.Parent or not rec.motes.Parent then
			untrack(model, rec)
		end
	end
	-- Our screen: a soft green-teal edge while we're healing, flicking
	-- magenta now and then.
	local mine = player.Character and healed[player.Character]
	local on = mine ~= nil and now < mine.glowUntil
	local e = screenEdge
	if on or (e and e.ImageTransparency < 1) then
		local img = edgeLabel()
		local target = if on then 0.5 else 1
		img.ImageTransparency += (target - img.ImageTransparency) * math.min(1, 6 * dt)
		if img.ImageTransparency > 0.98 and not on then
			img.ImageTransparency = 1
		end
		img.ImageColor3 = if on and math.random() < 0.03 then GLITCH else HEAL
	end
end

local function stepFloats(now: number)
	for i = #floats, 1, -1 do
		local f = floats[i]
		local k = (now - f.born) / FLOAT_TIME
		local adornee = f.gui.Adornee
		if k >= 1 or not adornee or not adornee.Parent then
			table.remove(floats, i)
			f.gui.Parent = nil
			f.gui.Adornee = nil
			table.insert(floatFree, f)
			continue
		end
		f.gui.StudsOffsetWorldSpace = Vector3.new(0, 2 + 1.5 * k, 0)
		f.label.TextTransparency = k * k
		f.label.TextStrokeTransparency = 0.4 + 0.6 * k
	end
end

-- Hooks ---------------------------------------------------------------------------

local function teamColor(data: { [string]: any }): Color3
	if data.caster == player then
		return TeamColor.ALLY
	end
	return TeamColor.forTeam(if typeof(data.team) == "number" then data.team else nil)
end

handler.onFx = function(kind: string, data: { [string]: any }): boolean
	if kind ~= "StimDrop" or data.id ~= "Stim" or typeof(data.level) ~= "string" then
		return false
	end
	local stats = Mods.stats("Stim", data.level)
	if not stats then
		return false
	end
	local look = if stats.behaviour == "Heal"
		then (if GlitchVfx.ready() then HEAL_KIT_LOOK else HEAL_LOOK)
		elseif stats.status == "StimStrong" then STRONG_LOOK
		else nil
	if not look then
		return false -- L1 / Quick Stims: StimFx's own look
	end
	if
		typeof(data.at) ~= "Vector3"
		or typeof(data.look) ~= "Vector3"
		or typeof(data.from) ~= "Vector3"
		or typeof(data.release) ~= "number"
		or typeof(data.toss) ~= "number"
		or typeof(data.radius) ~= "number"
		or typeof(data.duration) ~= "number"
		or typeof(data.deploy) ~= "number"
		or typeof(data.start) ~= "number"
	then
		return true -- malformed: nothing to draw either way
	end
	StimFx.drop({
		at = data.at,
		look = data.look,
		from = data.from,
		release = data.release,
		toss = data.toss,
		radius = data.radius,
		duration = data.duration,
		deploy = data.deploy,
		start = data.start,
		color = teamColor(data),
		own = data.caster == player, -- leaves from our first-person hand
		style = look,
	})
	return true
end

handler.step = function(dt: number)
	local now = os.clock()
	stepHealed(now, dt)
	stepFloats(now)
end

return handler
