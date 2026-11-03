--!strict
-- Updraft's upgrade levels on the client (vault/01 Design/Abilities/Upgrade
-- Paths.md → 2. Updraft). High Rise (A) and Second Wind (B) are numbers only:
-- the L1 look already scales with the rise (ModFeelController, WindFx) and
-- the HUD has 3 charge pips. Crash Down (G, the slam) is drawn here, in the
-- glitch theme "a corrupted packet crashing into the floor":
--   The dive (UpdraftSlamming / UpdraftSlamStart, simulation-written: ours
--   predicted, others' replicated): a streak above the body with a magenta
--   slice jittering beside it, magenta static round the body, and a ring on
--   the floor where it lands, sized to the slam's radius (cyan for your side,
--   pulsing orange-red for enemies: the danger read), plus a falling whoosh.
--   The impact (ours at once from our predicted UpdraftSlamAt, others' from
--   the server's UpdraftSlam ModFx): a small flash, a shockwave ring at the
--   radius, a magenta ring that skips frames as it grows, a hex "corrupted
--   floor" patch, dust thrown out flat, chips up, magenta voxel static, one
--   light; for the caster a camera punch.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local S = require(Shared.Config.ModSounds)
local Tex = require(Shared.Config.VfxTextures)
local UpdraftMod = require(Shared.Mods.Updraft)

local CameraController = require(script.Parent.Parent.Parent.Controllers.CameraController)
local ModAudio = require(script.Parent.Parent.ModAudio)
local ModVfx = require(script.Parent.Parent.ModVfx)
local TeamColor = require(script.Parent.Parent.TeamColor)
local Types = require(script.Parent.Types)

local player = Players.LocalPlayer

-- Look only (the rules are in Config/Mods Updraft).
local FEEL = {
	diveFov = 5, -- FOV push as the dive starts (degrees, over diveFovTime)
	diveFovTime = 0.25,
	impactFov = -7, -- squeeze on the landing
	impactFovTime = 0.3,
	impactShake = 0.7, -- degrees of wobble
	impactDip = -1.2, -- the view nods down (degrees, all of it comes back)
	impactDipTime = 0.2,
}

local RING_SCALE = 1 / 0.9 -- MOD_RING / MOD_RING_DASHED draw their rim at r = 0.9
local WHITE = Color3.new(1, 1, 1)
local GREY = Color3.fromRGB(150, 145, 140)
local DIVE_LIFE = 1.5
local RING_START = 1.35 -- the danger ring starts this much wider and closes in to the radius
local QUAD_THICKNESS = 0.05 -- ModVfx quads' thickness -- longest a dive's pieces live if its end is missed

type Dive = {
	ring: ModVfx.Handle,
	fill: ModVfx.Handle,
	core: ModVfx.Handle,
	slice: ModVfx.Handle,
	top: Vector3, -- where the dive started
	size: number, -- the ring's size at the radius
	born: number,
	fall: number, -- seconds the drop should take (the ring closes in over it)
	nextStatic: number,
}
type Seen = { start: number, landed: number, dive: Dive? }

local seen: { [Model]: Seen } = setmetatable({}, { __mode = "k" }) :: any
local queued: { { at: number, fn: () -> () } } = {}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- One anchored holder for the dust / chips emitters and the impact light.
local holder: BasePart? = nil
local dust: ParticleEmitter? = nil
local chips: ParticleEmitter? = nil
local light: PointLight? = nil
local lightAt = -math.huge
local lightLife = 0.2
local lightPower = 0

local function number(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if typeof(v) == "number" then v else default
end

local function rootOf(model: Model): BasePart?
	local r = model:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function later(delay: number, fn: () -> ())
	table.insert(queued, { at = os.clock() + delay, fn = fn })
end

local function getHolder(): BasePart
	local h = holder
	if h and h.Parent then
		return h
	end
	local p = Instance.new("Part")
	p.Name = "UpdraftSlamFx"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.Parent = Workspace

	local function emitter(name: string): ParticleEmitter
		local a = Instance.new("Attachment")
		a.Name = name
		a.Parent = p
		local e = Instance.new("ParticleEmitter")
		e.Enabled = false
		e.Rate = 0
		e.LightInfluence = 0.6
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-60, 60)
		e.Parent = a
		return e
	end
	-- Dust: thrown out flat along the floor, rolling and thinning.
	local d = emitter("Dust")
	d.Texture = Tex.DUST_2x2
	d.EmissionDirection = Enum.NormalId.Front
	d.SpreadAngle = Vector2.new(18, 6)
	d.Speed = NumberRange.new(26, 40)
	d.Drag = 5
	d.Acceleration = Vector3.new(0, 3, 0)
	d.Lifetime = NumberRange.new(0.45, 0.8)
	d.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.6),
		NumberSequenceKeypoint.new(1, 4.5),
	})
	d.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	-- Chips: kicked up, falling back (short, draggy).
	local c = emitter("Chips")
	c.Texture = Tex.CHIPS_2x2
	c.EmissionDirection = Enum.NormalId.Top
	c.SpreadAngle = Vector2.new(40, 40)
	c.Speed = NumberRange.new(22, 38)
	c.Drag = 1.5
	c.Acceleration = Vector3.new(0, -110, 0)
	c.Lifetime = NumberRange.new(0.5, 0.8)
	c.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0.4),
	})
	c.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	c.FlipbookMode = Enum.ParticleFlipbookMode.Random
	local l = Instance.new("PointLight")
	l.Brightness = 0
	l.Shadows = false
	l.Parent = p
	holder, dust, chips, light = p, d, c, l
	return p
end

-- The floor under `from` (bodies don't count), or nil.
local function floorBelow(from: Vector3): Vector3?
	local result = Workspace:Raycast(from, Vector3.new(0, -250, 0), rayParams)
	return if result then result.Position else nil
end

local function refreshRayFilter()
	local list: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	local dummies = Workspace:FindFirstChild("Dummies")
	if dummies then
		table.insert(list, dummies)
	end
	rayParams.FilterDescendantsInstances = list
end

-- Glitch static: a magenta voxel blinking in and out at `at`.
local function static(at: Vector3, size: number, life: number)
	local s = Vector3.one * size
	ModVfx.shell({
		shape = Enum.PartType.Block,
		cframe = CFrame.new(at) * CFrame.Angles(0, math.random() * math.pi, 0),
		from = s,
		to = s * 0.3,
		color = TeamColor.GLITCH,
		life = life,
		alpha0 = 0.05,
		alpha1 = 0.6,
		material = Enum.Material.Neon,
	})
end

-- The dive -------------------------------------------------------------------

local function column(dive: Dive, root: BasePart)
	local bottom = root.Position + Vector3.new(0, 1.5, 0)
	local length = math.max(dive.top.Y - bottom.Y, 0.5)
	local mid = Vector3.new(bottom.X, bottom.Y + length * 0.5, bottom.Z)
	local core = Vector3.new(0.5, length, 0.5)
	dive.core.cframe = CFrame.new(mid)
	dive.core.from, dive.core.to = core, core
	-- The slice: a wider, broken copy that hops sideways (a frame tearing).
	local jitter = Vector3.new((math.random() - 0.5) * 1.2, 0, (math.random() - 0.5) * 1.2)
	local slice = Vector3.new(1.2, length * (0.55 + math.random() * 0.35), 0.15)
	dive.slice.cframe = CFrame.new(mid + jitter) * CFrame.Angles(0, math.random() * math.pi, 0)
	dive.slice.from, dive.slice.to = slice, slice
end

local function placeRing(dive: Dive, root: BasePart)
	local floor = floorBelow(root.Position)
	if floor then
		local cf = CFrame.new(floor + Vector3.new(0, 0.08, 0))
		dive.ring.cframe = cf
		dive.fill.cframe = cf
	end
end

local function startDive(other: Player, root: BasePart): Dive
	local mine = other == player
	local color = TeamColor.forOwner(other)
	local stats = UpdraftMod.slamStats(other)
	local radius: number = if stats then stats.slamRadius else 8
	local size = radius * 2 * RING_SCALE
	refreshRayFilter()
	local floor = floorBelow(root.Position) or root.Position - Vector3.new(0, 3, 0)
	local cf = CFrame.new(floor + Vector3.new(0, 0.08, 0))
	local enemy = color == TeamColor.ENEMY
	local speed: number = if stats then stats.slamSpeed else 90
	local dive: Dive = {
		-- Closing in to the radius as you fall: where it will hit.
		ring = ModVfx.quad({
			texture = Tex.MOD_RING_DASHED,
			cframe = cf,
			from = size * RING_START,
			color = color,
			life = DIVE_LIFE,
			alpha0 = if enemy then 0.05 else 0.35,
			hold = true,
			spin = 2.5,
			pulse = if enemy then 0.35 else 0,
		}),
		fill = ModVfx.quad({
			texture = Tex.MOD_GLOW,
			cframe = cf,
			from = size * 0.9,
			color = color,
			life = DIVE_LIFE,
			alpha0 = if enemy then 0.7 else 0.85,
			hold = true,
		}),
		core = ModVfx.shell({
			shape = Enum.PartType.Block,
			cframe = root.CFrame,
			from = Vector3.one * 0.5,
			color = color:Lerp(WHITE, 0.35),
			life = DIVE_LIFE,
			alpha0 = 0.25,
			hold = true,
			material = Enum.Material.Neon,
		}),
		slice = ModVfx.shell({
			shape = Enum.PartType.Block,
			cframe = root.CFrame,
			from = Vector3.one * 0.5,
			color = TeamColor.GLITCH,
			life = DIVE_LIFE,
			alpha0 = 0.45,
			hold = true,
			material = Enum.Material.Neon,
		}),
		top = root.Position + Vector3.new(0, 2, 0),
		size = size,
		born = os.clock(),
		fall = math.max((root.Position.Y - floor.Y) / math.max(speed, 1), 0.05),
		nextStatic = 0,
	}
	column(dive, root)
	if mine then
		ModAudio.play(S.Updraft.slamDive)
		CameraController.punchFov(FEEL.diveFov, FEEL.diveFovTime)
	else
		ModAudio.play(S.Updraft.slamDiveWorld, root.Position)
	end
	return dive
end

local function stepDive(dive: Dive, root: BasePart, now: number)
	column(dive, root)
	placeRing(dive, root)
	local k = math.clamp((now - dive.born) / dive.fall, 0, 1)
	local d = dive.size * (RING_START + (1 - RING_START) * k)
	local ring = Vector3.new(d, QUAD_THICKNESS, d)
	dive.ring.from, dive.ring.to = ring, ring
	if now >= dive.nextStatic then
		dive.nextStatic = now + 0.03
		for _ = 1, 2 do
			local offset = Vector3.new(
				(math.random() - 0.5) * 3.5,
				(math.random() - 0.3) * 5,
				(math.random() - 0.5) * 3.5
			)
			static(root.Position + offset, 0.25 + math.random() * 0.45, 0.1 + math.random() * 0.06)
		end
	end
end

local function endDive(dive: Dive)
	ModVfx.stop(dive.ring)
	ModVfx.stop(dive.fill)
	ModVfx.stop(dive.core)
	ModVfx.stop(dive.slice)
end

-- The impact -----------------------------------------------------------------

local function impact(at: Vector3, radius: number, color: Color3, mine: boolean)
	local floor = at + Vector3.new(0, 0.08, 0)
	local cf = CFrame.new(floor)
	local size = radius * 2 * RING_SCALE

	-- A small hot flash, a frame or two.
	ModVfx.shell({
		shape = Enum.PartType.Ball,
		cframe = CFrame.new(at + Vector3.new(0, 1, 0)),
		from = Vector3.one * 2,
		to = Vector3.one * 4.5,
		color = color:Lerp(WHITE, 0.6),
		life = 0.08,
		alpha0 = 0.1,
		material = Enum.Material.Neon,
	})
	-- The shockwave: out to the radius while fading (the mesh when installed).
	ModVfx.quad({
		texture = Tex.MOD_RING,
		cframe = cf,
		from = 2,
		to = size,
		color = color,
		life = 0.32,
		alpha0 = 0,
	})
	ModVfx.mesh({
		name = "Shockwave",
		cframe = cf,
		from = Vector3.new(2, 1.5, 2),
		to = Vector3.new(radius * 2, 2.5, radius * 2),
		color = color,
		life = 0.3,
		alpha0 = 0.25,
	})
	-- The glitch ring: shown at three sizes with gaps (skipped frames).
	for i, k in { 0.45, 0.75, 1.05 } do
		later((i - 1) * 0.05, function()
			ModVfx.quad({
				texture = Tex.MOD_RING_DASHED,
				cframe = cf * CFrame.Angles(0, math.random() * math.pi, 0),
				from = size * k,
				to = size * k * 1.06,
				color = TeamColor.GLITCH,
				life = 0.09,
				alpha0 = 0.05,
				alpha1 = 0.5,
			})
		end)
	end
	-- The floor under it glitches out for a moment.
	ModVfx.quad({
		texture = Tex.MOD_HEX,
		cframe = cf,
		from = radius * 2,
		color = TeamColor.GLITCH,
		life = 0.65,
		alpha0 = 0.4,
		hold = true,
	})

	-- Dust out flat in every direction, chips up.
	local h = getHolder()
	local d, c = dust, chips
	if d and c then
		local da = d.Parent :: Attachment
		for i = 1, 10 do
			local angle = (i / 10) * math.pi * 2 + math.random() * 0.3
			local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
			da.WorldCFrame =
				CFrame.lookAt(at + Vector3.new(0, 0.6, 0), at + Vector3.new(0, 0.6, 0) + dir)
			d.Color = ColorSequence.new(GREY:Lerp(color, 0.15))
			d:Emit(2)
		end
		local ca = c.Parent :: Attachment
		ca.WorldPosition = at + Vector3.new(0, 0.4, 0)
		c.Color = ColorSequence.new(GREY)
		c:Emit(10)
	end
	ModVfx.burst(at + Vector3.new(0, 1, 0), color, 14, "Sparkle")

	-- Magenta voxel static scattered over the area for a moment.
	for _ = 1, 16 do
		local angle = math.random() * math.pi * 2
		local dist = math.sqrt(math.random()) * radius
		local pos = at
			+ Vector3.new(math.cos(angle) * dist, 0.3 + math.random() * 1.6, math.sin(angle) * dist)
		later(math.random() * 0.35, function()
			static(pos, 0.3 + math.random() * 0.6, 0.12 + math.random() * 0.15)
		end)
	end

	-- One light, low, under the flash.
	h.Position = at + Vector3.new(0, 2, 0)
	local l = light
	if l then
		l.Color = color
		l.Range = radius * 2
		lightPower = 3
		lightLife = 0.2
		lightAt = os.clock()
	end

	if mine then
		ModAudio.play(S.Updraft.slamImpact)
		ModAudio.play(S.Updraft.slamGlitch)
		CameraController.shake(FEEL.impactShake)
		CameraController.punchFov(FEEL.impactFov, FEEL.impactFovTime)
		CameraController.kick(FEEL.impactDip, 0, 1, FEEL.impactDipTime)
	else
		ModAudio.play(S.Updraft.slamImpact, at)
		ModAudio.play(S.Updraft.slamGlitch, at)
	end
end

-- Hooks --------------------------------------------------------------------

local handler: Types.Handler = {}

handler.onFx = function(kind: string, data: { [string]: any }): boolean
	if kind ~= "UpdraftSlam" then
		return false
	end
	-- Ours was drawn on our own (predicted) landing.
	if data.caster == player then
		return true
	end
	local at, radius = data.at, data.radius
	if typeof(at) ~= "Vector3" or typeof(radius) ~= "number" or radius ~= radius then
		return true
	end
	local team = if typeof(data.team) == "number" then data.team else nil
	impact(at, math.clamp(radius, 1, 40), TeamColor.forTeam(team), false)
	return true
end

handler.step = function(_dt: number)
	local now = os.clock()
	for i = #queued, 1, -1 do
		local q = queued[i]
		if now >= q.at then
			table.remove(queued, i)
			q.fn()
		end
	end
	local l = light
	if l then
		local k = (now - lightAt) / lightLife
		local power = if k < 1 then lightPower * (1 - k) else 0
		if l.Brightness ~= power then
			l.Brightness = power
		end
	end

	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and rootOf(character)
		if not character or not root then
			continue
		end
		local start = number(character, "UpdraftSlamStart", 0)
		local landed = number(character, "UpdraftSlamAt", 0)
		local slamming = character:GetAttribute("UpdraftSlamming") == true
		local s = seen[character]
		if not s then
			-- First sight: remember, don't replay old slams.
			seen[character] = { start = start, landed = landed, dive = nil }
			continue
		end
		-- (A re-simulated start a few ms off isn't a new slam.)
		if slamming and start > s.start + 0.05 then
			if s.dive then
				endDive(s.dive)
			end
			s.dive = startDive(other, root)
		end
		s.start = start
		local dive = s.dive
		if dive then
			if slamming then
				stepDive(dive, root, now)
			else
				endDive(dive)
				s.dive = nil
			end
		end
		-- Our own landing, as predicted (others' come from the server's ModFx).
		if other == player and landed > s.landed + 0.05 then
			local stats = UpdraftMod.slamStats(other)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local pos = character:GetAttribute("UpdraftSlamPos")
			local centre = if typeof(pos) == "Vector3" then pos else root.Position
			local drop = (if humanoid then humanoid.HipHeight else 2) + root.Size.Y * 0.5
			impact(
				centre - Vector3.new(0, drop, 0),
				if stats then stats.slamRadius else 8,
				TeamColor.ALLY,
				true
			)
		end
		s.landed = landed
	end
end

return handler
