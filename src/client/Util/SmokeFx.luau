--!strict
-- The Smoke power's look (Mods/Smoke; vault/01 Design/Abilities/Smoke.md). Owner 2026-11-27: "much larger ...
-- Valorant style ... not see-through". A big, solid dome that pops out of the canister, swells to full size, rolls
-- softly while it stands and thins out at the end:
--   * the shell: the Blender kit's Dome (ReplicatedStorage.Abilities.SmokeVFX), opaque and unlit (Neon), so you
--     never see through it and it never shades like rock;
--   * puffs: the kit's faceted Puff1-3 heaped round the base and over the top, so the outline billows;
--   * wisps: SMOKE_2x2 flipbook particles rolling off the whole surface (a sphere-surface emitter), softening it;
--   * inside it your screen is solid smoke (SmokeVeil), thinning only at the very edge.
-- Toxic Cloud (the glitched path): a sickly green smoke with magenta glitch static flickering over it.
-- Purely visual: what blocks sight for bots and aim assist is Mods/Blocks/Smoke on the same server parts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Tex = require(ReplicatedStorage.Shared.Config.VfxTextures)
local ModSounds = require(ReplicatedStorage.Shared.Config.ModSounds)
local ModAudio = require(script.Parent.ModAudio)

local SmokeFx = {}

-- Unlit greys: Neon brighter than about #8C8C8C clips to white, so these stay under it (lit faceted grey read as a
-- rock pile in the first Studio captures, 2026-11-27).
local SHELL = Color3.fromHex("767A82")
local PUFF = Color3.fromHex("7E828A")
local WISP = Color3.fromHex("C9CDD3")
local VEIL = Color3.fromHex("8A8E95")
local TOXIC_SHELL = Color3.fromHex("3B5230") -- unlit Neon reads much brighter: a dark sickly green lands mid
local TOXIC_PUFF = Color3.fromHex("435C36")
local TOXIC_WISP = Color3.fromHex("8FB866")
local GLITCH = Color3.fromHex("FF3BD4")
local PUFFS_PER_STUD = 2.6 -- puffs per stud of radius (28 at radius 11)
local TALL = 1.2 -- the dome stands this much taller than its radius: a round smoke ball, not a flat mound

type Puff = {
	part: BasePart,
	base: Vector3,
	home: Vector3,
	size: number,
	spin: Vector3,
	bob: number,
	delay: number, -- s after the pop this puff bursts out of the canister (the opening rolls out, not all at once)
}
type Cloud = {
	at: Vector3,
	radius: number,
	start: number, -- server time it popped
	duration: number,
	grow: number,
	fade: number,
	toxic: boolean,
	dome: BasePart?,
	domeBase: Vector3, -- the kit dome's size at radius 1 (a hemisphere: its box centre is half its height up)
	puffs: { Puff },
	shell: Part, -- the invisible sphere the surface wisps come off
	wisps: ParticleEmitter,
	static: ParticleEmitter?,
	hum: ModAudio.Hum?,
	faded: boolean, -- the thinning-out sound has played
}

local clouds: { Cloud } = {}

local function backOut(x: number): number
	local c1 = 1.4
	local c3 = c1 + 1
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end
local folder: Folder? = nil
local veil: Frame? = nil

local function fxFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "SmokeFx"
	made.Parent = Workspace
	folder = made
	return made
end

local function kit(name: string): BasePart?
	local abilities = ReplicatedStorage:FindFirstChild("Abilities")
	local vfx = abilities and abilities:FindFirstChild("SmokeVFX")
	local p = vfx and vfx:FindFirstChild(name, true)
	return if p and p:IsA("BasePart") then p else nil
end

local function copy(template: BasePart, color: Color3): BasePart
	local p = template:Clone()
	p:ClearAllChildren()
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0
	if p:IsA("MeshPart") then
		p.TextureID = ""
	end
	p.Parent = fxFolder()
	return p
end

local function veilFrame(): Frame?
	local v = veil
	if v and v.Parent then
		return v
	end
	local gui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not gui then
		return nil
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "SmokeVeil"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 5 -- under the HUD
	local f = Instance.new("Frame")
	f.Name = "Fog"
	f.Size = UDim2.fromScale(1, 1)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = VEIL
	f.BackgroundTransparency = 1
	f.Parent = screen
	screen.Parent = gui
	veil = f
	return f
end

local function smokeEmitter(color: Color3): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = Tex.SMOKE_2x2
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	e.FlipbookMode = Enum.ParticleFlipbookMode.Random
	e.Color = ColorSequence.new(color)
	e.LightInfluence = 0.3
	e.Rate = 0
	return e
end

-- A dome at `at` (the floor point): `start` server time, sizes in studs.
function SmokeFx.pop(
	at: Vector3,
	radius: number,
	duration: number,
	grow: number,
	fade: number,
	start: number,
	toxic: boolean
)
	local shellColor = if toxic then TOXIC_SHELL else SHELL
	local puffColor = if toxic then TOXIC_PUFF else PUFF
	local wispColor = if toxic then TOXIC_WISP else WISP

	-- the sphere the wisps roll off (resized with the dome every frame)
	local shell = Instance.new("Part")
	shell.Name = "SmokeShell"
	shell.Shape = Enum.PartType.Ball
	shell.Anchored = true
	shell.CanCollide = false
	shell.CanQuery = false
	shell.CanTouch = false
	shell.CastShadow = false
	shell.Transparency = 1
	shell.Size = Vector3.one
	shell.CFrame = CFrame.new(at)
	shell.Parent = fxFolder()

	-- the canister's gush: a ring of smoke blasting out along the floor
	local gush = smokeEmitter(wispColor)
	gush.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	gush.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(1, radius * 0.7),
	})
	gush.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gush.Lifetime = NumberRange.new(0.7, 1.1)
	gush.Speed = NumberRange.new(radius * 1.6, radius * 2.4)
	gush.SpreadAngle = Vector2.new(180, 25)
	gush.EmissionDirection = Enum.NormalId.Top
	gush.Drag = 4
	gush.Parent = shell
	gush:Emit(40)

	-- the opening jet: a column of smoke shooting straight up out of the canister before it spreads
	local jet = smokeEmitter(wispColor)
	jet.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	jet.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, radius * 0.5),
	})
	jet.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	jet.Lifetime = NumberRange.new(0.5, 0.8)
	jet.Speed = NumberRange.new(radius * 2.2, radius * 3)
	jet.SpreadAngle = Vector2.new(14, 14)
	jet.EmissionDirection = Enum.NormalId.Top
	jet.Drag = 3
	jet.Parent = shell
	jet:Emit(16)

	-- wisps rolling off the dome's surface for its whole life
	local wisps = smokeEmitter(wispColor)
	wisps.Shape = Enum.ParticleEmitterShape.Sphere
	wisps.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	wisps.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	wisps.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, radius * 0.35),
		NumberSequenceKeypoint.new(1, radius * 0.55),
	})
	wisps.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	wisps.Lifetime = NumberRange.new(2.2, 3.2)
	wisps.Speed = NumberRange.new(0.6, 1.4)
	wisps.Drag = 0.6
	wisps.RotSpeed = NumberRange.new(-12, 12)
	wisps.Rotation = NumberRange.new(0, 360)
	wisps.Rate = radius * 4
	wisps.Parent = shell

	local static: ParticleEmitter? = nil
	if toxic then
		-- the glitch: magenta static flickering over the cloud
		local e = Instance.new("ParticleEmitter")
		e.Texture = Tex.STIM_ARC_2x2
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		e.FlipbookMode = Enum.ParticleFlipbookMode.Random
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.Color = ColorSequence.new(GLITCH)
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Size = NumberSequence.new(radius * 0.25)
		e.Lifetime = NumberRange.new(0.05, 0.12)
		e.Rotation = NumberRange.new(0, 360)
		e.Speed = NumberRange.new(0)
		e.Rate = 18
		e.Parent = shell
		static = e
	end

	local cloud: Cloud = {
		at = at,
		radius = radius,
		start = start,
		duration = duration,
		grow = grow,
		fade = fade,
		toxic = toxic,
		dome = nil,
		domeBase = Vector3.new(2, 1, 2),
		puffs = {},
		shell = shell,
		wisps = wisps,
		static = static,
		hum = ModAudio.hum(
			if toxic then ModSounds.Smoke.toxicLoop else ModSounds.Smoke.loop,
			shell
		),
		faded = false,
	}
	local dome = kit("Dome")
	if dome then
		cloud.dome = copy(dome, shellColor)
		cloud.domeBase = dome.Size
	end
	local rng = Random.new(math.floor(at.X * 13 + at.Z * 7))
	local count = math.floor(radius * PUFFS_PER_STUD)
	for i = 1, count do
		local template = kit("Puff" .. tostring((i - 1) % 3 + 1))
		if not template then
			break
		end
		-- a ring round the base (it billows out along the floor), the rest over the top
		local a = (i / count) * math.pi * 2 * 1.618 + rng:NextNumber(-0.3, 0.3)
		local low = i % 2 == 0
		local up = if low then rng:NextNumber(0.02, 0.25) else rng:NextNumber(0.35, 0.95)
		local flat = math.sqrt(1 - up * up)
		local dir = Vector3.new(math.cos(a) * flat, up, math.sin(a) * flat)
		local p = copy(template, puffColor:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.05)))
		table.insert(cloud.puffs, {
			part = p,
			base = template.Size,
			home = dir * radius * (if low then 0.95 else 0.8),
			size = radius * rng:NextNumber(0.45, 0.7),
			spin = Vector3.new(
				rng:NextNumber(-0.12, 0.12),
				rng:NextNumber(-0.2, 0.2),
				rng:NextNumber(-0.12, 0.12)
			),
			bob = rng:NextNumber(0, math.pi * 2),
			-- the top and the near ring come first, the far base last
			delay = (if low then 0.12 else 0) + rng:NextNumber(0, 0.28),
		})
	end
	ModAudio.play(if toxic then ModSounds.Smoke.toxicPop else ModSounds.Smoke.pop, at)
	table.insert(clouds, cloud)
end

function SmokeFx.fizzle(at: Vector3)
	ModAudio.play(ModSounds.Smoke.fizzle, at)
end

local function remove(cloud: Cloud)
	ModAudio.stopHum(cloud.hum)
	if cloud.dome then
		cloud.dome:Destroy()
	end
	for _, puff in cloud.puffs do
		puff.part:Destroy()
	end
	cloud.shell:Destroy()
end

function SmokeFx.step()
	local now = Workspace:GetServerTimeNow()
	local cam = Workspace.CurrentCamera
	local eye = if cam then cam.CFrame.Position else Vector3.zero
	local fog = 0 -- how deep the camera is in smoke (0..1)
	local toxicFog = false
	for i = #clouds, 1, -1 do
		local c = clouds[i]
		local age = now - c.start
		if age > c.duration + 0.5 then
			remove(c)
			table.remove(clouds, i)
			continue
		end
		-- the shell swells in just behind the first puffs
		local size = if c.grow > 0 then math.clamp((age - 0.12) / c.grow, 0, 1) else 1
		size = 1 - (1 - size) ^ 3 -- ease out: it bursts, then settles
		local left = c.duration - age
		local thin = if c.fade > 0 then math.clamp(1 - left / c.fade, 0, 1) else 0
		local r = c.radius * size * (1 - 0.15 * thin)
		if thin > 0 and not c.faded then
			c.faded = true
			ModAudio.stopHum(c.hum)
			c.hum = nil
			ModAudio.play(ModSounds.Smoke.fade, c.at)
		end
		if c.dome then
			c.dome.Size = c.domeBase * math.max(r, 0.05) * Vector3.new(1, TALL, 1)
			c.dome.CFrame = CFrame.new(c.at + Vector3.new(0, c.domeBase.Y * r * TALL * 0.5, 0))
				* CFrame.Angles(0, age * 0.05, 0)
			c.dome.Transparency = thin
		end
		for _, puff in c.puffs do
			-- each puff bursts out of the canister on its own beat and overshoots a touch (Back), then settles
			local pk = math.clamp((age - puff.delay) / 0.55, 0, 1)
			local out = backOut(pk)
			local drift = Vector3.new(0, math.sin(age * 0.5 + puff.bob) * 0.35, 0)
			local s = math.max(puff.size * out * (1 + 0.04 * math.sin(age * 0.8 + puff.bob)), 0.02)
			puff.part.Size = puff.base * s
			local from = c.at + Vector3.new(0, 0.6, 0)
			local home = c.at + puff.home * Vector3.new(1, TALL, 1) * math.min(out, 1.05) + drift
			puff.part.CFrame = CFrame.new(from:Lerp(home, math.clamp(out, 0, 1.05)))
				* CFrame.Angles(puff.spin.X * age, puff.spin.Y * age + puff.bob, puff.spin.Z * age)
			puff.part.Transparency = thin
		end
		c.shell.Size = Vector3.one * math.max(r * 2, 0.1)
		c.wisps.Rate = if thin > 0 then 0 else c.radius * 4
		local static = c.static
		if static then
			static.Rate = if thin > 0 then 0 else 18
		end
		local d = (eye - c.at).Magnitude
		if r > 0 and d < r then
			fog = math.max(fog, math.clamp((r - d) / 1.2, 0, 1) * (1 - thin))
			toxicFog = toxicFog or c.toxic
		end
	end
	if fog > 0 or veil then
		local f = veilFrame()
		if f then
			f.BackgroundTransparency = 1 - fog
			f.BackgroundColor3 = if toxicFog then TOXIC_SHELL else VEIL
		end
	end
end

return SmokeFx
