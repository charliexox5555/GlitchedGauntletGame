--!strict
-- Updraft's upgrade levels on the client (vault/01 Design/Abilities/Upgrade
-- Paths.md → 2. Updraft). High Rise (A) and Second Wind (B) are numbers only:
-- the L1 look already scales with the rise (ModFeelController, WindFx) and
-- the HUD has 3 charge pips. Crash Down (G, the slam) is drawn here.
-- Restyled 2026-11-16 to the effects spec ("the floor broke"; glitch magenta
-- is no longer on the dive or the impact):
--   The dive (UpdraftSlam = "Down" / UpdraftSlamStart, simulation-written: ours
--   predicted, others' replicated): a white streak above the body with a white
--   slice beside it, and a ring on the floor where it lands, sized to the
--   slam's radius (cyan for your side, pulsing orange-red for enemies: the
--   danger read), plus a falling whoosh.
--   The impact (ours at once from our predicted UpdraftSlamAt, others' from
--   the server's UpdraftSlam ModFx): one white flash, the team-coloured
--   shockwave ring at the radius, dust thrown out flat, chips up, one light;
--   for the caster a camera punch (a smaller one for anyone near). With the
--   GlitchVFX kit installed (Util/GlitchVfx): the floor cracks open in its own
--   colour darkened (dark splits, lingering a few seconds), rubble chunks in
--   the floor's own colour and material are thrown up and land, and a stepped
--   ring rides out over the shockwave.
--   The prompt: while you're up in an Updraft with Crash Down, a "Q  CRASH
--   DOWN" prompt under the crosshair: the key is the Updraft slot's own input
--   (a second press slams; LB on a gamepad; on touch a CRASH button that
--   presses that same input), so the slam can be found.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local InputGlyphs = require(Shared.InputGlyphs)
local Health = require(ReplicatedStorage.Shared.Health)
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
	local v = StateValues.get(inst, name)
	return if typeof(v) == "number" then v else default
end

local function rootOf(model: Model): BasePart?
	local r = model:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
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
			color = WHITE, -- motion without gameplay meaning is white (was glitch magenta)
			life = DIVE_LIFE,
			alpha0 = 0.45,
			hold = true,
			material = Enum.Material.Neon,
		}),
		streak = GlitchVfx.piece({
			name = "Streak_Energy",
			cframe = root.CFrame,
			scale = Vector3.one * 0.3,
			color = WHITE:Lerp(color, 0.2),
			life = DIVE_LIFE,
			alpha0 = 0.2,
			hold = true,
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
	-- Crash Down pass (2026-11-16, Ability VFX Direction → Impact: "the floor
	-- broke"): the cracks are the floor's own colour darkened, not glowing;
	-- only the snap-open copy below is hot for a frame.
	GlitchVfx.piece({
		name = "Crack_Energy",
		cframe = CFrame.new(at + Vector3.new(0, 0.05, 0)) * yaw,
		scale = flat,
		color = (floorColor or GREY):Lerp(Color3.new(0, 0, 0), 0.4),
		material = Enum.Material.SmoothPlastic,
		life = FEEL.crackLife,
		alpha0 = 0.05,
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
	-- The shockwave: a stepped ring out to the radius.
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
			scale = Vector3.one * (2 + math.random() * 1.6), -- chunks, not gravel
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
	kitImpact(at, radius, color)

	-- A small hot flash, a frame or two.
	ModVfx.shell({
		shape = Enum.PartType.Ball,
		cframe = CFrame.new(at + Vector3.new(0, 1, 0)),
		from = Vector3.one * 2,
		to = Vector3.one * 4.5,
		color = WHITE, -- the one hit frame is white (X4)
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

-- "Q  CRASH DOWN" under the crosshair while a slam is ready (up in an Updraft
-- with Crash Down), so it can be found. The key is the Updraft slot's input:
-- a second press of it slams (Mods/Updraft simPress). Touch: a CRASH button
-- that presses that input (an InputBinding on its action, like
-- HudController's buttons).

-- The input action and the key label of the slot Updraft is in.
local function slamInput(pad: boolean): (string?, string)
	local _, slot = UpdraftMod.slamStats(player)
	if not slot then
		return nil, ""
	end
	local name = "Mod" .. slot
	-- the player's own binding (Settings keybinds), not the default
	local keys, pads = InputGlyphs.keysFor(name)
	if pad and pads[1] then
		return name, InputGlyphs.padName(pads[1])
	end
	return name, if keys[1] then InputGlyphs.keyName(keys[1]) else ""
end

local HEAVY = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy)
local BACK = Color3.fromHex("16181B")
-- The match UI's prompt look (vault/02 Art/UI Match Extras.md).
local PROMPT_FONT = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy)
local KEY_FACE, KEY_LIP = Color3.fromHex("E9EDF3"), Color3.fromHex("0F0F12")
local INK = Color3.fromHex("1A1A1D")
local PLATE = Color3.fromHex("262629")
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
	-- A keycap (the match UI's "fake button"): a light face on a dark lip.
	key.Size = UDim2.fromOffset(36, 38)
	key.BackgroundColor3 = KEY_FACE
	key.BackgroundTransparency = 0
	key.FontFace = PROMPT_FONT
	key.TextSize = 18
	key.TextColor3 = INK
	key.Parent = row
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = key
	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.AnchorPoint = Vector2.new(0, 1)
	lip.Position = UDim2.fromScale(0, 1)
	lip.Size = UDim2.new(1, 0, 0, 6)
	lip.BackgroundColor3 = KEY_LIP
	lip.BorderSizePixel = 0
	lip.ZIndex = 0
	lip.Parent = key
	local lipCorner = Instance.new("UICorner")
	lipCorner.CornerRadius = UDim.new(0, 5)
	lipCorner.Parent = lip

	-- The words on a navy plate (no outline).
	local text = Instance.new("Frame")
	text.Name = "Text"
	text.LayoutOrder = 2
	text.Size = UDim2.fromOffset(196, 38)
	text.BackgroundColor3 = PLATE
	text.BorderSizePixel = 0
	text.Parent = row
	local plateCorner = Instance.new("UICorner")
	plateCorner.CornerRadius = UDim.new(0, 6)
	plateCorner.Parent = text
	local plateFrame = text
	text = Instance.new("Frame")
	text.Name = "Words"
	text.Position = UDim2.fromOffset(14, 0)
	text.Size = UDim2.new(1, -28, 1, 0)
	text.BackgroundTransparency = 1
	text.Parent = plateFrame
	local function line(name: string, color: Color3, z: number): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.FontFace = PROMPT_FONT
		l.TextSize = 17
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = color
		l.Text = "CRASH DOWN"
		l.ZIndex = z
		l.Parent = text
		return l
	end
	-- White words (magenta and a cyan split until 2026-11-17: glitch is no
	-- longer this Mod's look). The split label stays, hidden, for the code
	-- that drives it.
	local split = line("Split", TeamColor.ALLY, 1)
	split.TextTransparency = 1
	local label = line("Label", Color3.new(1, 1, 1), 2)

	local button = Instance.new("TextButton")
	button.Name = "CrashDownButton"
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(0.5, 0, PROMPT_Y, 26)
	button.Size = UDim2.fromOffset(84, 84)
	button.BackgroundColor3 = BACK
	button.BackgroundTransparency = 0.3
	button.FontFace = HEAVY
	button.TextSize = 16
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = "CRASH"
	button.AutoButtonColor = true
	button.Visible = false
	button.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = button
	local ring = Instance.new("UIStroke")
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Color = TeamColor.ALLY
	ring.Thickness = 2.5
	ring.Parent = button

	made = { gui = gui, row = row, key = key, label = label, split = split, button = button }
	prompt = made
	promptBound = false
	promptShown = false
	promptTouch = false
	promptKey = ""
	return made
end

-- The touch button presses the Updraft slot's input (once the input context
-- is ready): the same second press as the key.
local function bindPromptButton(p: Prompt)
	if promptBound then
		return
	end
	local name = slamInput(false)
	if not name then
		return
	end
	local ok, action = pcall(InputController.action, name)
	if not ok then
		return
	end
	local old = action:FindFirstChild("Touch_CrashDownButton")
	if old then
		old:Destroy() -- a rebuilt prompt's button replaces the old one
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
	if not character or StateValues.get(character, "Updrafting") ~= true then
		return false, false
	end
	local slam = StateValues.get(character, "UpdraftSlam")
	if slam == "Down" or not UpdraftMod.slamStats(player) then
		return false, false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not Health.isAlive(humanoid) then
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
	local mode = InputGlyphs.mode() -- the same device rule as every key chip
	local touch = mode == "Touch"
	local pad = mode == "Gamepad"
	local _, key = slamInput(pad)
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
		local slamming = StateValues.get(character, "UpdraftSlam") == "Down"
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
			local pos = StateValues.get(character, "UpdraftSlamPos")
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

-- Round over: delayed effects are dropped and every dive column / closing
-- ring is stopped (ModVfx / GlitchVfx fade them). `seen` keeps each body's
-- last start and landing, so step doesn't replay the slam it was drawing.
handler.clearAll = function()
	table.clear(queued)
	for _, s in seen do
		local dive = s.dive
		if dive then
			s.dive = nil
			endDive(dive)
		end
	end
	lightPower = 0
end

return handler
