--!strict
-- The Molly's fire for everyone (vault/01 Design/Abilities/Molly.md → Look):
-- the burst (a canister pop and a whoomp of flame out to the radius), the
-- steady patch (low flames across it, a brighter burning edge so the safe
-- line reads, a little smoke, floating embers, a flickering warm light, a
-- scorch mark), the end (flames die down and sizzle out over ~0.5 s; the
-- scorch fades a few seconds later), and the small flames on whoever is
-- burning (the server's BurningUntil attribute). Fire is fire-coloured for
-- everyone: it's the same danger to both teams.
--
-- Textures: Config/VfxTextures MOLLY_* (rendered in Blender by
-- tools/vfx/make_molly_vfx.py). Fire rigs are pooled; burning flames are one
-- emitter per character, made on first burn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ModSounds = require(ReplicatedStorage.Shared.Config.ModSounds)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local ModAudio = require(script.Parent.ModAudio)
local ModVfx = require(script.Parent.ModVfx)

local MollyFx = {}

local S = ModSounds.Molly
local player = Players.LocalPlayer

local FLAME_POINTS = 26 -- flame emitters spread over the patch
local EDGE_POINTS = 28 -- around the rim
local SMOKE_POINTS = 5
local FADE_TIME = 0.5 -- flames die down over this at the end
local SCORCH_LINGER = 3 -- seconds the scorch stays after the fire
local LIGHT_COLOR = Color3.fromRGB(255, 150, 70)
local FIRE_TINT = Color3.fromRGB(255, 255, 255) -- the flame textures carry their own colour

type Rig = {
	part: Part,
	flames: { ParticleEmitter },
	edge: { ParticleEmitter },
	smoke: { ParticleEmitter },
	embers: ParticleEmitter,
	burst: ParticleEmitter,
	light: PointLight,
	attachments: { Attachment },
}

type Fire = {
	rig: Rig,
	at: Vector3,
	radius: number,
	startAt: number, -- os.clock()
	endAt: number,
	hum: ModAudio.Hum?,
	sizzled: boolean,
	scorch: any,
}

local fires: { Fire } = {}
local freeRigs: { Rig } = {}
local folder: Folder? = nil

local function curve(points: { number }): NumberSequence
	local keys = {}
	for i = 1, #points, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(points[i], points[i + 1]))
	end
	return NumberSequence.new(keys)
end

local function fxFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "MollyFx"
	made.Parent = Workspace
	folder = made
	table.clear(freeRigs)
	return made
end

local function emitter(parent: Instance, texture: string): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Rate = 0
	e.Enabled = true
	e.LightInfluence = 0
	e.LockedToPart = false
	e.Color = ColorSequence.new(FIRE_TINT)
	e.Parent = parent
	return e
end

-- A low flame: the looping 16-frame sheet, each particle starting on its
-- own frame. The sprite's base is its bottom edge, so emitters sit about half
-- a flame's height above the floor (see layout).
local function flameEmitter(parent: Instance, tall: number): ParticleEmitter
	local e = emitter(parent, VFX.MOLLY_FLAME_4x4)
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	e.FlipbookMode = Enum.ParticleFlipbookMode.Loop
	e.FlipbookFramerate = NumberRange.new(20, 24)
	e.FlipbookStartRandom = true
	e.Lifetime = NumberRange.new(0.6, 0.9)
	e.Speed = NumberRange.new(0.2, 0.6)
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(6, 6)
	e.Size = curve({ 0, 0.8 * tall, 0.3, 1.4 * tall, 1, 1.2 * tall })
	e.Transparency = curve({ 0, 0.7, 0.15, 0.1, 0.75, 0.3, 1, 1 })
	e.LightEmission = 0.6
	e.Brightness = 1.3
	e.Orientation = Enum.ParticleOrientation.FacingCamera
	e.Rotation = NumberRange.new(-6, 6)
	return e
end

local FLAME_TALL = 1.6 -- patch flames (studs, roughly knee-high at their peak)
local EDGE_TALL = 2 -- the burning edge: a little taller so the line reads
-- Emitters sit this share of a flame's size up: the sprite's base is its
-- bottom edge, and at its biggest (1.4x) half of it would sink into the floor.
local FLOOR_LIFT = 0.72

local function build(): Rig
	local part = Instance.new("Part")
	part.Name = "MollyFire"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 0.2, 1)
	part.CFrame = CFrame.new(0, -10000, 0)
	part.Parent = fxFolder()

	local attachments: { Attachment } = {}
	local function attach(): Attachment
		local a = Instance.new("Attachment")
		a.Parent = part
		table.insert(attachments, a)
		return a
	end
	local flames, edge, smoke = {}, {}, {}
	for _ = 1, FLAME_POINTS do
		table.insert(flames, flameEmitter(attach(), FLAME_TALL))
	end
	for _ = 1, EDGE_POINTS do
		table.insert(edge, flameEmitter(attach(), EDGE_TALL))
	end
	for _ = 1, SMOKE_POINTS do
		local e = emitter(attach(), VFX.MOLLY_SMOKE_2x2)
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot -- billows, then thins
		e.Color = ColorSequence.new(Color3.fromHex("3A3A3C"))
		e.Lifetime = NumberRange.new(1.8, 2.6)
		e.Speed = NumberRange.new(2, 3.5)
		e.Acceleration = Vector3.new(0, 1.2, 0)
		e.Drag = 0.6
		e.EmissionDirection = Enum.NormalId.Top
		e.SpreadAngle = Vector2.new(20, 20)
		e.Size = curve({ 0, 1.6, 1, 4.5 })
		e.Transparency = curve({ 0, 1, 0.2, 0.72, 1, 1 })
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-20, 20)
		e.LightInfluence = 0.6
		table.insert(smoke, e)
	end
	local center = attach()
	-- On the part itself: its size (the patch) sets the emitter's shape.
	local embers = emitter(part, VFX.MOLLY_EMBER)
	embers.Shape = Enum.ParticleEmitterShape.Cylinder
	embers.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	embers.Lifetime = NumberRange.new(1, 1.8)
	embers.Speed = NumberRange.new(3, 6)
	embers.Acceleration = Vector3.new(0, 1.5, 0)
	embers.EmissionDirection = Enum.NormalId.Top
	embers.SpreadAngle = Vector2.new(25, 25)
	embers.Size = curve({ 0, 0.14, 1, 0.05 })
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 214, 120), Color3.fromRGB(200, 50, 20))
	embers.Transparency = curve({ 0, 0, 0.8, 0.3, 1, 1 })
	embers.LightEmission = 1
	embers.Brightness = 2
	-- The whoomp: a side-view sheet (base at the bottom) as wide as the patch,
	-- played once; a second, smaller one a beat later (ignite).
	local burst = emitter(center, VFX.MOLLY_BURST_2x2)
	burst.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	burst.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	burst.Lifetime = NumberRange.new(0.4)
	burst.Speed = NumberRange.new(0)
	burst.Size = NumberSequence.new(18)
	burst.Transparency = curve({ 0, 0, 0.8, 0.2, 1, 1 })
	burst.LightEmission = 0.6
	burst.Brightness = 1.4
	burst.Orientation = Enum.ParticleOrientation.FacingCamera
	local light = Instance.new("PointLight")
	light.Color = LIGHT_COLOR
	light.Shadows = false
	light.Brightness = 0
	light.Parent = center
	return {
		part = part,
		flames = flames,
		edge = edge,
		smoke = smoke,
		embers = embers,
		burst = burst,
		light = light,
		attachments = attachments,
	}
end

local function takeRig(): Rig
	fxFolder()
	local rig = table.remove(freeRigs)
	if rig and rig.part.Parent then
		return rig
	end
	return build()
end

-- Lays the rig out for a patch of `radius` at `at`: flames spread evenly over
-- the disc (golden angle), the edge points on the rim, smoke inside.
local function layout(rig: Rig, at: Vector3, radius: number)
	rig.part.CFrame = CFrame.new(at)
	local golden = math.pi * (3 - math.sqrt(5))
	for n = 1, FLAME_POINTS do
		local r = radius * 0.92 * math.sqrt((n - 0.5) / FLAME_POINTS)
		local a = n * golden
		rig.attachments[n].Position =
			Vector3.new(math.cos(a) * r, FLAME_TALL * FLOOR_LIFT, math.sin(a) * r)
	end
	local i = FLAME_POINTS
	for n = 1, EDGE_POINTS do
		local a = (n / EDGE_POINTS) * math.pi * 2
		rig.attachments[i + n].Position =
			Vector3.new(math.cos(a) * radius, EDGE_TALL * FLOOR_LIFT, math.sin(a) * radius)
	end
	i += EDGE_POINTS
	for n = 1, SMOKE_POINTS do
		local a = n * 2.4
		local r = radius * 0.5 * ((n % 3) / 3 + 0.2)
		rig.attachments[i + n].Position = Vector3.new(math.cos(a) * r, 0.5, math.sin(a) * r)
	end
	-- The ember cylinder spans the patch.
	rig.part.Size = Vector3.new(radius * 2, 0.2, radius * 2)
end

local function setRates(rig: Rig, k: number)
	for _, e in rig.flames do
		e.Rate = 5 * k
	end
	for _, e in rig.edge do
		e.Rate = 7 * k
	end
	for _, e in rig.smoke do
		e.Rate = 1.2 * k
	end
	rig.embers.Rate = 14 * k
end

-- The canister bursts at `at` (the floor): a fire of `radius` until
-- `duration` after server time `start`.
function MollyFx.ignite(at: Vector3, radius: number, duration: number, start: number)
	local left = duration - (Workspace:GetServerTimeNow() - start)
	if left <= 0 then
		return
	end
	local rig = takeRig()
	layout(rig, at + Vector3.new(0, 0.1, 0), radius)
	setRates(rig, 1)
	rig.light.Range = radius * 1.8
	-- The whoomp: the sheet as wide as the patch (its base on the floor), a
	-- smaller one a beat later, and a light spike.
	local burstAttachment = rig.burst.Parent :: Attachment
	burstAttachment.Position = Vector3.new(0, radius * 0.5, 0)
	rig.burst.Size = NumberSequence.new(radius * 2)
	rig.burst:Emit(1)
	task.delay(0.06, function()
		rig.burst.Size = NumberSequence.new(radius * 1.4)
		rig.burst:Emit(1)
	end)
	rig.light.Brightness = 6
	ModAudio.play(S.burst, at)
	local now = os.clock()
	local scorch = ModVfx.quad({
		texture = VFX.MOLLY_SCORCH,
		cframe = CFrame.new(at + Vector3.new(0, 0.05, 0)),
		from = radius * 2.6, -- the char fills the middle 60%
		color = Color3.new(1, 1, 1),
		life = left + SCORCH_LINGER,
		alpha0 = 0.05,
		hold = true,
	})
	table.insert(fires, {
		rig = rig,
		at = at,
		radius = radius,
		startAt = now,
		endAt = now + left,
		hum = ModAudio.hum(S.fireLoop, rig.part),
		sizzled = false,
		scorch = scorch,
	})
end

-- A canister that never found a floor: a small pop, nothing burns.
function MollyFx.fizzle(at: Vector3)
	ModAudio.play(S.sizzleOut, at)
end

-- Small flames on everyone burning (the server's BurningUntil), and the
-- sizzle for us.
type Burn = { emitter: ParticleEmitter, root: BasePart }
local burns: { [Model]: Burn } = setmetatable({}, { __mode = "k" }) :: any
local burnSoundAt = -math.huge
local BURN_SOUND_GAP = 0.3

local function burnOf(model: Model, root: BasePart): Burn
	local b = burns[model]
	if b and b.emitter.Parent and b.root == root then
		return b
	end
	-- One per root, even if this table lost its entry.
	local existing = root:FindFirstChild("MollyBurn")
	if existing and existing:IsA("ParticleEmitter") then
		local found = { emitter = existing, root = root }
		burns[model] = found
		return found
	end
	-- On the root: its box (the torso) is where the flames come from.
	local e = flameEmitter(root, 1)
	e.Name = "MollyBurn"
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Rate = 0
	local made = { emitter = e, root = root }
	burns[model] = made
	return made
end

local function stepBurning(serverNow: number)
	local function check(model: Instance)
		if not model:IsA("Model") then
			return
		end
		local untilT = model:GetAttribute("BurningUntil")
		local burning = typeof(untilT) == "number" and serverNow < untilT
		local b = burns[model]
		if not burning and not b then
			return
		end
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		local burn = burnOf(model, root)
		burn.emitter.Rate = if burning then 14 else 0
		if burning and model == player.Character then
			local now = os.clock()
			if now - burnSoundAt >= BURN_SOUND_GAP then
				burnSoundAt = now
				ModAudio.play(S.burning)
			end
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
end

-- Per frame (ModFxController.update).
function MollyFx.step()
	local now = os.clock()
	for i = #fires, 1, -1 do
		local f = fires[i]
		local rig = f.rig
		local left = f.endAt - now
		if left <= -1 then
			-- Out, and the last particles are gone: back to the pool (the
			-- loop stopped even if a long frame skipped the fade).
			ModAudio.stopHum(f.hum)
			f.hum = nil
			table.remove(fires, i)
			rig.light.Brightness = 0
			rig.part.CFrame = CFrame.new(0, -10000, 0)
			table.insert(freeRigs, rig)
			continue
		end
		if left <= FADE_TIME and not f.sizzled then
			f.sizzled = true
			ModAudio.stopHum(f.hum)
			f.hum = nil
			ModAudio.play(S.sizzleOut, f.at)
		end
		local k = math.clamp(left / FADE_TIME, 0, 1)
		setRates(rig, k)
		-- Flicker: a warm light that never sits still; the burst's spike decays.
		local since = now - f.startAt
		local base = 2.2
			+ 0.6 * math.noise(now * 7.3, f.at.X)
			+ 0.4 * math.noise(now * 13.1, f.at.Z)
		local spike = math.max(0, 1 - since / 0.35) * 4
		rig.light.Brightness = math.max(0, base * k + spike)
	end
	stepBurning(Workspace:GetServerTimeNow())
end

return MollyFx
