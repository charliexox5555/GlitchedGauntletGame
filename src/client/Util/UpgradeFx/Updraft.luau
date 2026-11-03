--!strict
-- Updraft's upgrade levels on the client (vault/01 Design/Abilities/Upgrade
-- Paths.md → 2. Updraft). High Rise (A) and Second Wind (B) are numbers only:
-- the L1 look already scales with the rise (ModFeelController, WindFx) and
-- the HUD has 3 charge pips. Crash Down (G, the slam) is drawn here, in the
-- glitch theme "a corrupted packet crashing into the floor":
--   The dive (UpdraftSlam = "Down" / UpdraftSlamStart, simulation-written: ours
--   predicted, others' replicated): a streak above the body with a magenta
--   slice jittering beside it, magenta static round the body, and a ring on
--   the floor where it lands, sized to the slam's radius (cyan for your side,
--   pulsing orange-red for enemies: the danger read), plus a falling whoosh.
--   The impact (ours at once from our predicted UpdraftSlamAt, others' from
--   the server's UpdraftSlam ModFx): a small flash, a shockwave ring at the
--   radius, a magenta ring that skips frames as it grows, a hex "corrupted
--   floor" patch, dust thrown out flat, chips up, magenta voxel static, one
--   light; for the caster a camera punch (a smaller one for anyone near).
--   Look (stylized, 2026-11-03), with the GlitchVFX kit installed (Util/
--   GlitchVfx; the old look stays until then): the floor cracks open to the
--   slam's radius (glowing cracks over dark splits, lingering a few seconds),
--   rubble chunks in the floor's own colour and material are thrown up and
--   land, the shockwave is a stepped pixel ring, the corrupted floor a hex
--   tile disc, and the dive trails a bundle of falling bars.
--   The prompt: while you're up in an Updraft with Crash Down, a "C  CRASH
--   DOWN" prompt under the crosshair (B on a gamepad; on touch a CRASH button
--   that presses Crouch), so the slam can be found.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local S = require(Shared.Config.ModSounds)
local Tex = require(Shared.Config.VfxTextures)
local UpdraftMod = require(Shared.Mods.Updraft)

local CameraController = require(script.Parent.Parent.Parent.Controllers.CameraController)
local InputController = require(script.Parent.Parent.Parent.Controllers.InputController)
local GlitchVfx = require(script.Parent.Parent.GlitchVfx)
local ModAudio = require(script.Parent.Parent.ModAudio)
local ModVfx = require(script.Parent.Parent.ModVfx)
local TeamColor = require(script.Parent.Parent.TeamColor)
local Types = require(script.Parent.Types)

local player = Players.LocalPlayer

-- Look only (the rules are in Config/Mods Updraft).
local FEEL = {
	diveFov = 5, -- FOV push as the dive starts (degrees, over diveFovTime)
	diveFovTime = 0.25,
	impactFov = -8, -- squeeze on the landing
	impactFovTime = 0.3,
	impactShake = 1.2, -- degrees of wobble
	impactDip = -2.2, -- the view nods down (degrees, all of it comes back)
	impactDipTime = 0.22,
	nearShake = 0.5, -- someone else's slam this close (radius x nearRange) shakes your view
	nearRange = 2,
	crackLife = 3, -- seconds the floor cracks stay
	rubble = 9, -- chunks thrown up
	rubbleLife = 2.2,
	rubbleGravity = 110, -- studs/s²
}

local RING_SCALE = 1 / 0.9 -- MOD_RING / MOD_RING_DASHED draw their rim at r = 0.9
local WHITE = Color3.new(1, 1, 1)
local GREY = Color3.fromRGB(150, 145, 140)
local DIVE_LIFE = 1.5
local RING_START = 1.35 -- the danger ring starts this much wider and closes in to the radius
local QUAD_THICKNESS = 0.05 -- ModVfx quads' thickness -- longest a dive's pieces live if its end is missed
local DARK = Color3.fromRGB(18, 16, 22)
local RUBBLE: { GlitchVfx.Name } = { "Rubble1", "Rubble2", "Rubble3" }
-- Kit sizes (tools/blender/build_mod_glitchvfx.py): the crack and the ring
-- are 2.02 / 2.05 across, the hex floor 1.77.
local CRACK_SPAN = 2.02
local RING_SPAN = 2.05
local HEX_SPAN = 1.77
-- Floors that make no sense as rubble.
local NO_RUBBLE_MATERIAL: { [Enum.Material]: boolean } = {
	[Enum.Material.Neon] = true,
	[Enum.Material.ForceField] = true,
	[Enum.Material.Glass] = true,
	[Enum.Material.Water] = true,
	[Enum.Material.Air] = true,
}

type Dive = {
	ring: ModVfx.Handle,
	fill: ModVfx.Handle,
	core: ModVfx.Handle,
	slice: ModVfx.Handle,
	streak: GlitchVfx.Handle?, -- falling bars round the column (the kit installed)
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
	local streak = dive.streak
	if streak then
		-- Its bars run along Z: stood up, stretched over the column, turning.
		local size = Vector3.new(1.3, 1.3, length * 1.1)
		streak.cframe = CFrame.new(mid)
			* CFrame.Angles(math.pi / 2, 0, os.clock() * 7 % (math.pi * 2))
		streak.from, streak.to = size, size
	end
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
		streak = GlitchVfx.piece({
			name = "Streak_Energy",
			cframe = root.CFrame,
			scale = Vector3.one * 0.3,
			color = color:Lerp(TeamColor.GLITCH, 0.5),
			life = DIVE_LIFE,
			alpha0 = 0.2,
			hold = true,
			stutter = 0.15,
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
	local streak = dive.streak
	if streak then
		GlitchVfx.stop(streak)
	end
end

-- The impact -----------------------------------------------------------------

-- The floor under `at`: where it is (the cracks lie on it) and what it's
-- made of (the rubble), or nils.
local function floorLook(at: Vector3): (Vector3?, Color3?, Enum.Material?)
	local result = Workspace:Raycast(at + Vector3.new(0, 2, 0), Vector3.new(0, -6, 0), rayParams)
	if not result then
		return nil, nil, nil
	end
	local hit = result.Instance
	if hit:IsA("Terrain") then
		local ok, c = pcall(hit.GetMaterialColor, hit, result.Material)
		return result.Position, if ok then c else nil, result.Material
	elseif hit:IsA("BasePart") then
		return result.Position, hit.Color, hit.Material
	end
	return result.Position, nil, nil
end

-- The GlitchVFX kit's part of the impact: the floor cracks open, rubble flies,
-- a stepped shockwave ring. False when the kit isn't installed.
local function kitImpact(feet: Vector3, radius: number, color: Color3): boolean
	if not GlitchVfx.ready() then
		return false
	end
	local ground, floorColor, floorMaterial = floorLook(feet)
	local at = ground or feet
	local yaw = CFrame.Angles(0, math.random() * math.pi * 2, 0)
	local span = radius * 2 / CRACK_SPAN
	local flat = Vector3.new(span, 1, span)
	-- Dark splits, glowing cracks over them, and a hot copy that snaps open.
	GlitchVfx.piece({
		name = "CrackGap",
		cframe = CFrame.new(at + Vector3.new(0, 0.03, 0)) * yaw,
		scale = flat,
		color = DARK,
		life = FEEL.crackLife,
		alpha0 = 0.05,
		hold = true,
	})
	GlitchVfx.piece({
		name = "Crack_Energy",
		cframe = CFrame.new(at + Vector3.new(0, 0.05, 0)) * yaw,
		scale = flat,
		color = color,
		life = FEEL.crackLife,
		alpha0 = 0.15,
		hold = true,
	})
	GlitchVfx.piece({
		name = "Crack_Energy",
		cframe = CFrame.new(at + Vector3.new(0, 0.07, 0)) * yaw,
		scale = flat * Vector3.new(0.35, 1, 0.35),
		scale1 = flat * Vector3.new(1.04, 1, 1.04),
		color = color:Lerp(WHITE, 0.55),
		life = 0.28,
		alpha0 = 0,
	})
	-- The shockwave: a stepped ring out to the radius, a magenta one stuttering behind.
	local ring = radius * 2 / RING_SPAN
	GlitchVfx.piece({
		name = "PixelRing_Energy",
		cframe = CFrame.new(at + Vector3.new(0, 0.1, 0)) * yaw,
		scale = Vector3.new(0.2, 6, 0.2),
		scale1 = Vector3.new(ring * 1.05, 1.5, ring * 1.05),
		color = color:Lerp(WHITE, 0.25),
		life = 0.34,
		alpha0 = 0,
		alpha1 = 0.9,
	})
	later(0.05, function()
		GlitchVfx.piece({
			name = "PixelRing_Energy",
			cframe = CFrame.new(at + Vector3.new(0, 0.1, 0)) * yaw:Inverse(),
			scale = Vector3.new(0.3, 3, 0.3),
			scale1 = Vector3.new(ring * 0.9, 1, ring * 0.9),
			color = TeamColor.GLITCH,
			life = 0.3,
			alpha0 = 0.1,
			stutter = 0.35,
		})
	end)
	-- The floor glitching out: a hex tile disc.
	local hex = radius * 2 / HEX_SPAN
	GlitchVfx.piece({
		name = "HexFloor_Energy",
		cframe = CFrame.new(at + Vector3.new(0, 0.09, 0)) * yaw,
		scale = Vector3.new(hex, 1, hex),
		color = TeamColor.GLITCH,
		life = 0.65,
		alpha0 = 0.45,
		hold = true,
		stutter = 0.25,
	})
	-- Rubble in the floor's own colour, thrown up and out; it lands and lies.
	local material = if floorMaterial and not NO_RUBBLE_MATERIAL[floorMaterial]
		then floorMaterial
		else Enum.Material.Slate
	local rubbleColor = (floorColor or GREY):Lerp(Color3.new(0, 0, 0), 0.15)
	for i = 1, FEEL.rubble do
		local angle = (i / FEEL.rubble) * math.pi * 2 + math.random() * 0.5
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local start = at + out * (0.5 + math.random() * radius * 0.3) + Vector3.new(0, 0.4, 0)
		GlitchVfx.piece({
			name = RUBBLE[math.random(1, #RUBBLE)],
			cframe = CFrame.new(start)
				* CFrame.Angles(math.random() * 6.3, math.random() * 6.3, math.random() * 6.3),
			scale = Vector3.one * (1.3 + math.random() * 1.1),
			color = rubbleColor,
			material = material,
			life = FEEL.rubbleLife,
			alpha0 = 0,
			hold = true,
			velocity = out * (7 + math.random() * 12) + Vector3.new(0, 24 + math.random() * 16, 0),
			gravity = FEEL.rubbleGravity,
			floorY = at.Y,
			spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 18,
		})
	end
	return true
end

local function impact(at: Vector3, radius: number, color: Color3, mine: boolean)
	local floor = at + Vector3.new(0, 0.08, 0)
	local cf = CFrame.new(floor)
	local size = radius * 2 * RING_SCALE
	refreshRayFilter()
	local kit = kitImpact(at, radius, color)

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
	-- The floor under it glitches out for a moment (the kit draws its hex disc).
	if not kit then
		ModVfx.quad({
			texture = Tex.MOD_HEX,
			cframe = cf,
			from = radius * 2,
			color = TeamColor.GLITCH,
			life = 0.65,
			alpha0 = 0.4,
			hold = true,
		})
	end

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
		-- Felt nearby too: a smaller shake, fading with distance.
		local camera = Workspace.CurrentCamera
		if camera then
			local near = radius * FEEL.nearRange
			local away = (camera.CFrame.Position - at).Magnitude
			if away < near then
				CameraController.shake(FEEL.nearShake * (1 - away / near))
			end
		end
	end
end

-- The prompt -------------------------------------------------------------------

-- "C  CRASH DOWN" under the crosshair while a slam is ready (up in an Updraft
-- with Crash Down), so it can be found. Touch: a CRASH button that presses
-- Crouch (an InputBinding on the Crouch action, like HudController's buttons).
local HEAVY = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
local BACK = Color3.fromHex("16181B")
local PROMPT_Y = 0.62 -- screen height of the prompt (under the crosshair)

type Prompt = {
	gui: ScreenGui,
	row: Frame,
	key: TextLabel,
	label: TextLabel,
	split: TextLabel,
	button: TextButton,
}
local prompt: Prompt? = nil
local promptShown = false
local promptTouch = false
local promptKey = ""
local promptBound = false

local function buildPrompt(): Prompt
	local made = prompt
	if made and made.gui.Parent then
		return made
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "CrashDownPrompt"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, PROMPT_Y)
	row.Size = UDim2.fromOffset(0, 34)
	row.AutomaticSize = Enum.AutomaticSize.X
	row.BackgroundTransparency = 1
	row.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.LayoutOrder = 1
	key.Size = UDim2.fromOffset(34, 34)
	key.BackgroundColor3 = BACK
	key.BackgroundTransparency = 0.2
	key.FontFace = HEAVY
	key.TextSize = 20
	key.TextColor3 = WHITE
	key.Parent = row
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = key
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = TeamColor.GLITCH
	stroke.Thickness = 2
	stroke.Parent = key

	local text = Instance.new("Frame")
	text.Name = "Text"
	text.LayoutOrder = 2
	text.Size = UDim2.fromOffset(150, 34)
	text.BackgroundTransparency = 1
	text.Parent = row
	local function line(name: string, color: Color3, z: number): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.FontFace = HEAVY
		l.TextSize = 22
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = color
		l.TextStrokeTransparency = 0.6
		l.Text = "CRASH DOWN"
		l.ZIndex = z
		l.Parent = text
		return l
	end
	-- A cyan copy behind the magenta text: the colour split of a bad signal.
	local split = line("Split", TeamColor.ALLY, 1)
	split.TextTransparency = 0.55
	local label = line("Label", TeamColor.GLITCH, 2)

	local button = Instance.new("TextButton")
	button.Name = "CrashDownButton"
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(0.5, 0, PROMPT_Y, 26)
	button.Size = UDim2.fromOffset(84, 84)
	button.BackgroundColor3 = BACK
	button.BackgroundTransparency = 0.3
	button.FontFace = HEAVY
	button.TextSize = 16
	button.TextColor3 = TeamColor.GLITCH
	button.Text = "CRASH"
	button.AutoButtonColor = true
	button.Visible = false
	button.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = button
	local ring = Instance.new("UIStroke")
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Color = TeamColor.GLITCH
	ring.Thickness = 2.5
	ring.Parent = button

	made = { gui = gui, row = row, key = key, label = label, split = split, button = button }
	prompt = made
	promptBound = false
	return made
end

-- The touch button presses Crouch (once the input context is ready).
local function bindPromptButton(p: Prompt)
	if promptBound then
		return
	end
	local ok, action = pcall(InputController.action, "Crouch")
	if not ok then
		return
	end
	local binding = Instance.new("InputBinding")
	binding.Name = "Touch_CrashDownButton"
	binding.UIButton = p.button
	binding.Parent = action
	promptBound = true
end

-- (ready, a press waiting for the arm time)
local function slamReady(): (boolean, boolean)
	local character = player.Character
	if not character or character:GetAttribute("Updrafting") ~= true then
		return false, false
	end
	local slam = character:GetAttribute("UpdraftSlam")
	if slam == "Down" or not UpdraftMod.slamStats(player) then
		return false, false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false, false
	end
	return true, slam == "Queued"
end

local function stepPrompt(now: number)
	local ready, waiting = slamReady()
	if not ready and not promptShown then
		return
	end
	local p = buildPrompt()
	if ready ~= promptShown then
		promptShown = ready
		p.gui.Enabled = ready
	end
	if not ready then
		return
	end
	local last = UserInputService:GetLastInputType()
	local touch = last == Enum.UserInputType.Touch
	local pad = string.find(last.Name, "Gamepad") ~= nil
	local key = if pad then "B" else "C"
	if touch ~= promptTouch then
		promptTouch = touch
		p.row.Visible = not touch
		p.button.Visible = touch
		if touch then
			bindPromptButton(p)
		end
	end
	if key ~= promptKey then
		promptKey = key
		p.key.Text = key
	end
	-- A press waiting for the arm time reads as taken; otherwise it pulses,
	-- with a glitch slip now and then.
	local pulse = if waiting then 0.5 else 0.15 * (0.5 + 0.5 * math.sin(now * 10))
	p.label.TextTransparency = pulse
	p.key.TextTransparency = pulse
	local slip = if math.random() < 0.06 then (math.random() - 0.5) * 8 else 0
	p.split.Position = UDim2.fromOffset(2 + slip, 0)
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
	stepPrompt(now)
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
		local slamming = character:GetAttribute("UpdraftSlam") == "Down"
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
