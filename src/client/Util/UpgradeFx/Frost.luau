--!strict
-- Frost's upgrade levels on the client (vault/01 Design/Abilities/Upgrade
-- Paths.md → 5. Frost; Frost.md → Upgrades).
--
-- Stockpile (A) and Big Burst (B) are numbers only: Util/FrostFx already
-- scales the burst to `radius`, and the HUD shows up to 3 charge pips.
--
-- Freeze Frame (G) is a paused video frame:
--   - the burst (FrostBurst with `freeze`): a snap-freeze shockwave instead of
--     the frost puff. A ring races out and stops dead at the edge, held with
--     magenta / cyan ghost copies jittering beside it, ice spikes burst out of
--     the floor around it, a "❚❚" pause glyph flickers over it, then it pops;
--     a tape-brake snap with static;
--   - every frozen body (players and dummies, read from FrozenUntil): encased
--     in a jagged, glitching ice block (crystal shards, magenta scanlines
--     scrolling over it, datamosh jumps, a "❚❚ 1.4" tag: cyan for your
--     team, orange-red for enemies); it shatters when it thaws;
--   - us while frozen: a frosted, desaturated screen with VHS scanlines,
--     tearing bars and a "❚❚ FROZEN" countdown; it shatters off at the end.
-- Stylized look (2026-11-03, Util/IceKit): the ring is the kit's faceted
-- crystal crown, the spikes are faceted crystals (magenta slivers flicker),
-- the floor frost is a faceted patch with magenta cracks, and a frozen body
-- stands in the faceted Shell with two magenta crystal slivers, magenta
-- slices sweeping down through it and pixel cubes on its datamosh jumps; it
-- shatters into faceted chips. Without ReplicatedStorage.Abilities.IceVFX it
-- falls back to the older look (decal rings, glass blocks with SurfaceGui
-- scanlines, physics glass chunks).
-- The rules of being frozen (dropped hold / reload, turn cap, paused
-- animations) live in Util/Frozen, started and stepped from here.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Health = require(ReplicatedStorage.Shared.Health)
local ModSounds = require(ReplicatedStorage.Shared.Config.ModSounds)
local Status = require(ReplicatedStorage.Shared.Mods.Status)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local CameraController = require(script.Parent.Parent.Parent.Controllers.CameraController)
local Frozen = require(script.Parent.Parent.Frozen)
local IceKit = require(script.Parent.Parent.IceKit)
local ModAudio = require(script.Parent.Parent.ModAudio)
local ModVfx = require(script.Parent.Parent.ModVfx)
local TeamColor = require(script.Parent.Parent.TeamColor)
local Types = require(script.Parent.Types)
local VfxPool = require(script.Parent.Parent.VfxPool)

local S = ModSounds.Frost
local player = Players.LocalPlayer
local rng = Random.new()

local ICE = Color3.fromHex("BFE8FF")
local ICE_DEEP = Color3.fromHex("7FD4FF")
local GLITCH = TeamColor.GLITCH
local GHOST = Color3.fromHex("3DF2FF") -- the cyan half of the chromatic split

-- The burst's timeline (seconds).
local RING_OUT = 0.1 -- races to the edge
local RING_HOLD = 0.45 -- then stops dead ("paused")
local RING_POP = 0.18
local SPIKE_RISE = 0.08
local SPIKE_HOLD = 0.8
local SPIKE_SINK = 0.25
local GROUND_TIME = 3.5

-- Effects that run over time: `step` returns false when done (and cleans up).
local running: { (now: number) -> boolean } = {}

local folder: Folder? = nil
local slicePool: VfxPool.Pool<Part>? = nil -- the Freeze Frame slices (in this folder)
local function fxFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "FreezeFrameFx"
	made.Parent = Workspace
	folder = made
	slicePool = nil
	return made
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = fxFolder()
	return p
end

local function easeOut(t: number): number
	local k = math.clamp(t, 0, 1)
	return 1 - (1 - k) * (1 - k)
end

local function jitter(amount: number): Vector3
	return Vector3.new(rng:NextNumber(-amount, amount), 0, rng:NextNumber(-amount, amount))
end

-- A flat ring on the floor: the kit's crystal crown (Ring_Energy) or, without
-- the kit, MOD_RING on a thin part's top face.
type Ring = {
	part: BasePart,
	set: (center: Vector3, diameter: number, alpha: number) -> (),
	free: () -> (),
}

local function ring(color: Color3): Ring
	local found = IceKit.acquire("Ring_Energy")
	if found then
		local kit: BasePart = found -- non-optional for the closures below
		kit.Color = color
		kit.Material = Enum.Material.Neon
		local yaw = IceKit.yaw(rng)
		return {
			part = kit,
			set = function(center: Vector3, diameter: number, alpha: number)
				IceKit.place(
					kit,
					CFrame.new(center) * yaw,
					Vector3.new(diameter / 2, 1.5, diameter / 2)
				)
				kit.Transparency = alpha
			end,
			free = function()
				IceKit.release(kit)
			end,
		}
	end
	local p = part({ Size = Vector3.new(1, 0.05, 1), Transparency = 1 })
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	d.Texture = VFX.MOD_RING
	d.Color3 = color
	d.Transparency = 1
	d.Parent = p
	return {
		part = p,
		set = function(center: Vector3, diameter: number, alpha: number)
			p.Size = Vector3.new(diameter, 0.05, diameter)
			p.CFrame = CFrame.new(center)
			d.Transparency = alpha
		end,
		free = function()
			p:Destroy()
		end,
	}
end

-- A pause mark ("❚❚" as two bars, so no font has to have the glyph) and
-- an optional text after it, filling `parent`. `bars`: the share of the
-- width the bars take.
type Mark = { frame: Frame, text: TextLabel? }

local function pauseMark(
	parent: Instance,
	color: Color3,
	z: number,
	withText: boolean,
	bars: number
): Mark
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.ZIndex = z
	frame.Parent = parent
	local left = if withText then 0 else (1 - bars) / 2
	for i = 0, 1 do
		local bar = Instance.new("Frame")
		bar.Position = UDim2.fromScale(left + bars * (0.08 + 0.52 * i), 0.12)
		bar.Size = UDim2.fromScale(bars * 0.32, 0.76)
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = color
		bar.ZIndex = z
		bar.Parent = frame
	end
	local text: TextLabel? = nil
	if withText then
		local l = Instance.new("TextLabel")
		l.Position = UDim2.fromScale(bars + 0.04, 0)
		l.Size = UDim2.fromScale(1 - bars - 0.04, 1)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.Arcade
		l.TextScaled = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = color
		l.ZIndex = z
		l.Parent = frame
		text = l
	end
	return { frame = frame, text = text }
end

-- A main mark (last, `color`) over its two chromatic ghosts (magenta, cyan).
local function splitMark(parent: Instance, color: Color3, withText: boolean, bars: number): { Mark }
	return {
		pauseMark(parent, GLITCH, 1, withText, bars),
		pauseMark(parent, GHOST, 2, withText, bars),
		pauseMark(parent, color, 3, withText, bars),
	}
end

local function setMarkText(marks: { Mark }, text: string)
	for _, m in marks do
		local l = m.text
		if l then
			l.Text = text
		end
	end
end

-- The chromatic split: the two ghosts jump a few pixels each tick.
local function splitGhosts(marks: { Mark }, pixels: number)
	for i = 1, 2 do
		local side = if i == 1 then -1 else 1
		marks[i].frame.Position =
			UDim2.fromOffset(side * rng:NextInteger(1, pixels), rng:NextInteger(-1, 1))
		marks[i].frame.Visible = rng:NextNumber() < 0.85
	end
end

-- A pause tag as a BillboardGui on `adornee`, `studs` tall (hidden by walls:
-- it must never show a frozen enemy through them).
local function pauseTag(
	adornee: BasePart,
	offset: Vector3,
	studs: number,
	color: Color3,
	withText: boolean
): (BillboardGui, { Mark })
	local gui = Instance.new("BillboardGui")
	gui.Name = "FreezeFrameTag"
	gui.Adornee = adornee
	gui.Size = UDim2.new(studs * (if withText then 2.6 else 1.2), 0, studs, 0)
	gui.StudsOffsetWorldSpace = offset
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	local marks = splitMark(gui, color, withText, if withText then 0.36 else 0.8)
	gui.Parent = fxFolder()
	return gui, marks
end

-- The burst -------------------------------------------------------------------------

-- The kit's spikes: faceted crystals snapping out of the floor, one in four
-- a flickering magenta sliver. False when the kit isn't installed.
local function kitSpikes(at: Vector3, radius: number): boolean
	if not IceKit.ready() then
		return false
	end
	local count = math.clamp(math.floor(radius * 1.2), 10, 22)
	for i = 1, count do
		local angle = (i + rng:NextNumber(-0.3, 0.3)) / count * math.pi * 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local len = rng:NextNumber(2, 4.5) * math.clamp(radius / 10, 1, 1.4)
		local base = at + out * radius * rng:NextNumber(0.82, 1)
		local neon = i % 4 == 0
		IceKit.spawn({
			name = if neon then IceKit.SHARDS[3] else IceKit.pick(rng, IceKit.SHARDS),
			at = CFrame.lookAt(base, base + out)
				* CFrame.Angles(-math.rad(rng:NextNumber(15, 35)), rng:NextNumber(0, math.pi), 0)
				* CFrame.new(0, -len * 0.15, 0),
			scale = Vector3.new(len * 1.3, len, len * 1.3),
			color = if neon then GLITCH elseif rng:NextNumber() < 0.5 then ICE else ICE_DEEP,
			material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			alpha = if neon then 0.35 else 0.12,
			flicker = if neon then 0.45 else nil,
			life = SPIKE_RISE + SPIKE_HOLD + SPIKE_SINK,
			from = 0.05,
			grow = SPIKE_RISE,
			snap = true,
			fade = SPIKE_SINK,
			sink = len * 0.6,
		})
	end
	return true
end

local function spikeRing(at: Vector3, radius: number)
	if kitSpikes(at, radius) then
		return
	end
	local count = math.clamp(math.floor(radius * 1.2), 10, 22)
	local spikes: { { p: Part, home: CFrame, len: number, neon: boolean } } = {}
	for i = 1, count do
		local angle = (i + rng:NextNumber(-0.3, 0.3)) / count * math.pi * 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local len = rng:NextNumber(2, 4.5) * math.clamp(radius / 10, 1, 1.4)
		local base = at + out * radius * rng:NextNumber(0.82, 1)
		-- Tilted outward 15-35 degrees, the long axis up.
		local tilt = math.rad(rng:NextNumber(15, 35))
		local home = CFrame.lookAt(base, base + out)
			* CFrame.Angles(-tilt, rng:NextNumber(0, math.pi), 0)
			* CFrame.new(0, len * 0.35, 0)
		-- One in four is a corrupted magenta sliver.
		local neon = i % 4 == 0
		local width = rng:NextNumber(0.5, 1.1)
		local p = part({
			Size = Vector3.new(width, len, width * rng:NextNumber(0.6, 1)),
			Material = if neon then Enum.Material.Neon else Enum.Material.Glass,
			Color = if neon then GLITCH else (if rng:NextNumber() < 0.5 then ICE else ICE_DEEP),
			Transparency = if neon then 0.35 else 0.25,
			Reflectance = if neon then 0 else 0.15,
			CFrame = home * CFrame.new(0, -len, 0),
		})
		table.insert(spikes, { p = p, home = home, len = len, neon = neon })
	end
	local born = os.clock()
	table.insert(running, function(now: number): boolean
		local t = os.clock() - born
		if t >= SPIKE_RISE + SPIKE_HOLD + SPIKE_SINK then
			for _, s in spikes do
				s.p:Destroy()
			end
			return false
		end
		for _, s in spikes do
			local rise = easeOut(t / SPIKE_RISE)
			local sink = math.clamp((t - SPIKE_RISE - SPIKE_HOLD) / SPIKE_SINK, 0, 1)
			s.p.CFrame = s.home * CFrame.new(0, -s.len * (1 - rise) - s.len * 0.6 * sink, 0)
			s.p.Transparency = if s.neon
				then (if math.floor(now * 20) % 3 == 0 then 0.8 else 0.35) + 0.6 * sink
				else 0.25 + 0.75 * sink
		end
		return true
	end)
end

local function snapFreeze(at: Vector3, radius: number, team: number?)
	local rim = TeamColor.forTeam(team)
	local floor = at + Vector3.new(0, 0.08, 0)
	local born = os.clock()

	-- The ring and its two chromatic ghosts.
	local main = ring(rim)
	local magenta = ring(GLITCH)
	local cyan = ring(GHOST)
	local light = Instance.new("PointLight")
	light.Color = ICE
	light.Brightness = 6
	light.Range = radius * 2
	light.Shadows = false
	light.Parent = main.part
	local glyph, glyphMarks = pauseTag(main.part, Vector3.new(0, 4.5, 0), 2.2, rim, false)
	local nextTick = 0
	local magentaAt, cyanAt = floor, floor
	table.insert(running, function(now: number): boolean
		local t = os.clock() - born
		if t >= RING_OUT + RING_HOLD + RING_POP then
			light:Destroy()
			glyph:Destroy()
			main.free()
			magenta.free()
			cyan.free()
			return false
		end
		local d = radius * 2 * easeOut(t / RING_OUT)
		local pop = math.clamp((t - RING_OUT - RING_HOLD) / RING_POP, 0, 1)
		local size = d * (1 + 0.12 * pop)
		main.set(floor, size, pop)
		light.Brightness = 6 * (1 - math.clamp(t / (RING_OUT + RING_HOLD), 0, 1))
		-- Held: the ghosts jitter on a stepped clock (a stuck frame), the glyph flickers.
		local held = t >= RING_OUT and pop == 0
		if now >= nextTick then
			nextTick = now + rng:NextNumber(0.04, 0.09)
			magentaAt = floor + jitter(if held then 0.7 else 0.3)
			cyanAt = floor + jitter(if held then 0.7 else 0.3)
			glyph.Enabled = held and rng:NextNumber() < 0.8
			splitGhosts(glyphMarks, 4)
		end
		magenta.set(magentaAt, size, if pop > 0 then 1 else 0.35)
		cyan.set(cyanAt, size, if pop > 0 then 1 else 0.35)
		return true
	end)

	-- A hard white-blue flash at the core, sparkles, a digital grid on the floor.
	ModVfx.shell({
		shape = Enum.PartType.Ball,
		cframe = CFrame.new(at + Vector3.new(0, 1, 0)),
		from = Vector3.one * 2,
		to = Vector3.one * radius * 0.9,
		color = ICE,
		life = 0.16,
		alpha0 = 0.15,
		material = Enum.Material.Neon,
	})
	ModVfx.burst(at + Vector3.new(0, 1, 0), ICE, 30, "Sparkle")
	ModVfx.burst(at + Vector3.new(0, 1, 0), GLITCH, 12, "Sparkle")
	-- Frost on the floor: the kit's faceted patch with magenta cracks
	-- flickering in it, or the older frost decal.
	local patch = CFrame.new(at + Vector3.new(0, 0.02, 0)) * IceKit.yaw(rng)
	local flat = Vector3.new(radius, 1.5, radius)
	if
		not IceKit.spawn({
			name = "Floor",
			at = patch,
			scale = flat,
			color = ICE_DEEP,
			alpha = 0.3,
			life = GROUND_TIME,
			from = 0.95,
			grow = RING_OUT,
			fade = 0.6,
		})
	then
		ModVfx.quad({
			texture = VFX.FROST_GROUND,
			cframe = CFrame.new(at + Vector3.new(0, 0.05, 0)),
			from = radius * 1.9,
			to = radius * 2.1,
			color = ICE_DEEP,
			life = GROUND_TIME,
			alpha0 = 0.05,
			hold = true,
		})
	else
		IceKit.spawn({
			name = "Cracks_Energy",
			at = patch,
			scale = flat,
			color = GLITCH,
			material = Enum.Material.Neon,
			alpha = 0.2,
			flicker = 0.5,
			life = RING_OUT + RING_HOLD + RING_POP,
			fade = RING_POP,
		})
	end
	ModVfx.quad({
		texture = VFX.MOD_HEX,
		cframe = CFrame.new(at + Vector3.new(0, 0.06, 0)),
		from = radius * 2,
		color = GLITCH,
		life = RING_OUT + RING_HOLD,
		alpha0 = 0.55,
		hold = true,
	})
	spikeRing(at, radius)

	ModAudio.play(S.freezeSnap, at)
	ModAudio.play(S.burstCrackle, at, 0.75)
	ModAudio.play(S.freezeStatic, at)
	local cam = Workspace.CurrentCamera
	if cam then
		local away = (cam.CFrame.Position - at).Magnitude
		if away < radius * 3 then
			CameraController.shake(0.7 * (1 - away / (radius * 3)))
		end
	end
end

-- Ice blocks on frozen bodies -------------------------------------------------------

type Line = { frame: Frame, base: number }

type Shard = { p: BasePart, rel: CFrame, neon: boolean, scale: Vector3 }

type Block = {
	model: Model,
	root: BasePart,
	rel: CFrame, -- the block's centre from the root
	size: Vector3,
	kit: boolean, -- the ice kit's Shell (else the older glass block)
	scale: Vector3, -- the Shell's kit scale
	main: BasePart,
	shards: { Shard },
	lines: { Line },
	tear: { Frame },
	slices: { Part }, -- the kit's look: magenta scanline slices through the ice
	pixels: BasePart?, -- the kit's look: magenta pixel cubes on a datamosh jump
	tag: BillboardGui,
	tagMarks: { Mark },
	nextGlitch: number,
	glitchUntil: number,
	offset: Vector3,
	pixelAt: CFrame,
}

local blocks: { [Model]: Block } = {}

local LINES = 7
local SLICES = 2
local SHELL_ALPHA = 0.45 -- the frozen body shows through the ice

-- Thin magenta slices sweeping down through the kit's block (pooled).
local function slices(): VfxPool.Pool<Part>
	local pool = slicePool
	if pool then
		return pool
	end
	local made = VfxPool.new(function(): Part
		return part({
			Name = "FreezeFrameSlice",
			Size = Vector3.new(1, 0.05, 1),
			Material = Enum.Material.Neon,
			Color = GLITCH,
			Transparency = 1,
		})
	end, fxFolder(), 0)
	slicePool = made
	return made
end

-- Magenta scanlines over one face of the block, scrolled in step.
local function scanFace(block: Block, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0
	gui.Brightness = 1.5
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	for i = 1, LINES do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0, 0.5)
		f.Size = UDim2.new(1, 0, 0.025, 0)
		f.BorderSizePixel = 0
		f.BackgroundColor3 = GLITCH
		f.BackgroundTransparency = 0.45
		f.Parent = gui
		table.insert(block.lines, { frame = f, base = (i - 1) / LINES })
	end
	-- A wider tear that flashes now and then.
	local tear = Instance.new("Frame")
	tear.BorderSizePixel = 0
	tear.BackgroundColor3 = GHOST
	tear.BackgroundTransparency = 0.5
	tear.Visible = false
	tear.Parent = gui
	table.insert(block.tear, tear)
	gui.Parent = block.main
end

-- The kit's block: the faceted Shell around the body, two magenta crystal
-- slivers, scanline slices and a pixel accent. Nil when the kit isn't installed.
local function kitShell(
	size: Vector3,
	cf: CFrame
): (BasePart?, Vector3, { Shard }, { Part }, BasePart?)
	local core = IceKit.SHELL_CORE
	local scale = size / core
	local shell = IceKit.acquire("Shell")
	if not shell then
		return nil, scale, {}, {}, nil
	end
	shell.Color = ICE
	shell.Material = Enum.Material.SmoothPlastic
	shell.Transparency = SHELL_ALPHA
	IceKit.place(shell, cf, scale)
	local shards: { Shard } = {}
	local half = size / 2
	for i = 1, 2 do
		local p = IceKit.acquire("Shard3")
		if p then
			local side = if i == 1 then -1 else 1
			local spot = Vector3.new(
				side * half.X * 0.9,
				rng:NextNumber(-0.2, 0.6) * half.Y,
				rng:NextNumber(-0.5, 0.5) * half.Z
			)
			local out = Vector3.new(side, 0.7, 0).Unit
			local len = rng:NextNumber(1.3, 2)
			p.Color = GLITCH
			p.Material = Enum.Material.Neon
			p.Transparency = 0.3
			table.insert(shards, {
				p = p,
				rel = CFrame.lookAt(spot, spot + out)
					* CFrame.Angles(-math.pi / 2, rng:NextNumber(0, math.pi), 0)
					* CFrame.new(0, -len * 0.3, 0),
				neon = true,
				scale = Vector3.one * len,
			})
		end
	end
	local cuts: { Part } = {}
	local pool = slices()
	for _ = 1, SLICES do
		local s = pool:acquire()
		s.Size = Vector3.new(size.X * 0.9, 0.05, size.Z * 0.9)
		s.Transparency = 0.35
		table.insert(cuts, s)
	end
	local pixels = IceKit.acquire("Pixels_Energy")
	if pixels then
		pixels.Color = GLITCH
		pixels.Material = Enum.Material.Neon
		pixels.Transparency = 1
	end
	return shell, scale, shards, cuts, pixels
end

local function encase(model: Model, root: BasePart): Block
	-- The body's box, padded, in the root's frame (accessories and a long
	-- gun stay within sane limits).
	local boxCf, boxSize = model:GetBoundingBox()
	local size = Vector3.new(
		math.clamp(boxSize.X, 3, 4.6) + 0.9,
		math.clamp(boxSize.Y, 4.5, 6.5) + 0.8,
		math.clamp(boxSize.Z, 2, 3.2) + 0.9
	)
	local c = root.CFrame:PointToObjectSpace(boxCf.Position)
	local rel = CFrame.new(
		math.clamp(c.X, -0.5, 0.5),
		math.clamp(c.Y, -1.2, 0.6),
		math.clamp(c.Z, -0.5, 0.5)
	)
	local teamColor = TeamColor.forOwner(Players:GetPlayerFromCharacter(model) or model)
	local shell, scale, kitShards, cuts, pixels = kitShell(size, root.CFrame * rel)
	local main: BasePart = shell
		or part({
			Name = "FreezeFrameIce",
			Size = size,
			Material = Enum.Material.Glass,
			Color = ICE,
			Transparency = 0.55,
			Reflectance = 0.1,
			CFrame = root.CFrame * rel,
		})
	local tag, tagMarks = pauseTag(main, Vector3.new(0, size.Y / 2 + 1.2, 0), 1.1, teamColor, true)
	local block: Block = {
		model = model,
		root = root,
		rel = rel,
		size = size,
		kit = shell ~= nil,
		scale = scale,
		main = main,
		shards = kitShards,
		lines = {},
		tear = {},
		slices = cuts,
		pixels = pixels,
		tag = tag,
		tagMarks = tagMarks,
		nextGlitch = 0,
		glitchUntil = 0,
		offset = Vector3.zero,
		pixelAt = CFrame.identity,
	}
	if block.kit then
		return block
	end
	for _, face in
		{ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
	do
		scanFace(block, face)
	end
	-- Jagged crystals jutting out of the faces and corners.
	local half = size / 2
	for i = 1, 9 do
		local p = Vector3.new(
			rng:NextNumber(-1, 1) * half.X,
			rng:NextNumber(-0.7, 1) * half.Y,
			rng:NextNumber(-1, 1) * half.Z
		)
		-- Push it onto the nearest side face so it grows out of the block.
		if math.abs(p.X) / half.X > math.abs(p.Z) / half.Z then
			p = Vector3.new(math.sign(p.X) * half.X, p.Y, p.Z)
		else
			p = Vector3.new(p.X, p.Y, math.sign(p.Z) * half.Z)
		end
		local out = (p * Vector3.new(1, 0.6, 1)).Unit
		local len = rng:NextNumber(1.2, 2.6)
		local shardRel = CFrame.lookAt(p, p + out)
			* CFrame.Angles(-math.pi / 2, rng:NextNumber(0, math.pi), 0)
			* CFrame.new(0, len * 0.2, 0)
		local neon = i % 4 == 0
		local width = rng:NextNumber(0.35, 0.8)
		local shard = part({
			Size = Vector3.new(width, len, width),
			Material = if neon then Enum.Material.Neon else Enum.Material.Glass,
			Color = if neon then GLITCH else ICE_DEEP,
			Transparency = if neon then 0.3 else 0.2,
			Reflectance = if neon then 0 else 0.2,
			CFrame = main.CFrame * shardRel,
		})
		table.insert(block.shards, { p = shard, rel = shardRel, neon = neon, scale = Vector3.one })
	end
	return block
end

-- The kit's shatter: faceted chips flying out (one in five magenta).
local function kitChips(block: Block)
	local half = block.size / 2
	local base = block.root.CFrame * block.rel -- the block's own axes (the mesh part's are turned)
	for i = 1, 7 do
		local spot = Vector3.new(
			rng:NextNumber(-half.X, half.X),
			rng:NextNumber(-half.Y, half.Y),
			rng:NextNumber(-half.Z, half.Z)
		)
		local out = spot * Vector3.new(1, 0, 1)
		local dir = if out.Magnitude > 0.01 then out.Unit else Vector3.xAxis
		local neon = i % 5 == 0
		IceKit.spawn({
			name = IceKit.FRAGMENTS[(i - 1) % 3 + 1],
			at = base * CFrame.new(spot) * IceKit.yaw(rng),
			scale = Vector3.one * rng:NextNumber(0.6, 1.2),
			color = if neon then GLITCH else ICE,
			material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			alpha = 0.1,
			life = 0.8,
			fade = 0.45,
			velocity = base:VectorToWorldSpace(dir) * rng:NextNumber(10, 22)
				+ Vector3.new(0, rng:NextNumber(8, 18), 0),
			spin = Vector3.new(
				rng:NextNumber(-12, 12),
				rng:NextNumber(-12, 12),
				rng:NextNumber(-12, 12)
			),
		})
	end
end

-- Breaks the block apart: chunks flying out, a pop of shards and static.
local function shatter(block: Block, loud: boolean)
	local center = block.main.Position
	if block.kit then
		kitChips(block)
	else
		local half = block.size / 2
		local chunks: { Part } = {}
		for _ = 1, 12 do
			local spot = Vector3.new(
				rng:NextNumber(-half.X, half.X),
				rng:NextNumber(-half.Y, half.Y),
				rng:NextNumber(-half.Z, half.Z)
			)
			local s = rng:NextNumber(0.3, 0.9)
			local p = part({
				Size = Vector3.new(s, s * rng:NextNumber(0.6, 1.8), s),
				Material = Enum.Material.Glass,
				Color = if rng:NextNumber() < 0.2 then GLITCH else ICE,
				Transparency = 0.2,
				CFrame = block.main.CFrame
					* CFrame.new(spot)
					* CFrame.Angles(rng:NextNumber(0, math.pi), rng:NextNumber(0, math.pi), 0),
			})
			p.Anchored = false
			p.Massless = true
			local out = spot * Vector3.new(1, 0, 1)
			local dir = if out.Magnitude > 0.01 then out.Unit else Vector3.xAxis
			p.AssemblyLinearVelocity = dir * rng:NextNumber(10, 22)
				+ Vector3.new(0, rng:NextNumber(8, 18), 0)
			p.AssemblyAngularVelocity = Vector3.new(
				rng:NextNumber(-12, 12),
				rng:NextNumber(-12, 12),
				rng:NextNumber(-12, 12)
			)
			table.insert(chunks, p)
		end
		local born = os.clock()
		table.insert(running, function(_now: number): boolean
			local t = os.clock() - born
			if t >= 0.8 then
				for _, c in chunks do
					c:Destroy()
				end
				return false
			end
			for _, c in chunks do
				c.Transparency = 0.2 + 0.8 * math.clamp((t - 0.35) / 0.45, 0, 1)
			end
			return true
		end)
	end
	ModVfx.burst(center, ICE, if block.kit then 14 else 24, "Sparkle")
	ModVfx.burst(center, GLITCH, if block.kit then 5 else 8, "Sparkle")
	if loud then
		ModAudio.play(S.shatter, center)
	end
	block.tag:Destroy()
	if block.kit then
		IceKit.release(block.main)
		for _, s in block.shards do
			IceKit.release(s.p)
		end
		local pool = slices()
		for _, s in block.slices do
			pool:release(s)
		end
		local pixels = block.pixels
		if pixels then
			IceKit.release(pixels)
		end
	else
		block.main:Destroy()
		for _, s in block.shards do
			s.p:Destroy()
		end
	end
end

local function stepBlock(block: Block, now: number, left: number)
	-- Datamosh: now and then the whole block jumps sideways and flashes
	-- magenta for a frame or two.
	if now >= block.nextGlitch then
		block.nextGlitch = now + rng:NextNumber(0.08, 0.3)
		block.glitchUntil = now + rng:NextNumber(0.03, 0.07)
		block.offset = Vector3.new(rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.1, 0.1), 0)
		splitGhosts(block.tagMarks, 3)
		for _, tear in block.tear do
			tear.Visible = rng:NextNumber() < 0.5
			tear.Position = UDim2.fromScale(0, rng:NextNumber(0, 0.9))
			tear.Size = UDim2.fromScale(1, rng:NextNumber(0.03, 0.12))
		end
		-- The kit's pixel cubes land on a random side of the block.
		local half = block.size / 2
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		block.pixelAt = CFrame.new(0, rng:NextNumber(-0.4, 0.6) * half.Y, side * (half.Z + 0.1))
	end
	local glitching = now < block.glitchUntil
	local offset = if glitching then block.offset else Vector3.zero
	local base = block.root.CFrame * block.rel * CFrame.new(offset)
	if block.kit then
		IceKit.place(block.main, base, block.scale)
		for _, s in block.shards do
			IceKit.place(s.p, base * s.rel, s.scale)
			s.p.Transparency = if glitching then 0 else 0.3
		end
		-- Two magenta slices sweep down through the ice, a stuck video line.
		local h = block.size.Y
		for i, s in block.slices do
			local y = h / 2 - ((now * 0.6 + (i - 1) / #block.slices) % 1) * h
			s.CFrame = base * CFrame.new(0, y, 0)
		end
		local pixels = block.pixels
		if pixels then
			if glitching then
				IceKit.place(pixels, base * block.pixelAt, Vector3.one * 1.1)
				pixels.Transparency = 0.05
			else
				pixels.Transparency = 1
			end
		end
	else
		block.main.CFrame = base
		for _, s in block.shards do
			s.p.CFrame = base * s.rel
			if s.neon then
				s.p.Transparency = if glitching then 0 else 0.3
			end
		end
	end
	block.main.Color = if glitching then GLITCH else ICE
	-- Scanlines crawl down the faces.
	local scroll = (now * 0.35) % 1
	for _, line in block.lines do
		line.frame.Position = UDim2.fromScale(0, (line.base + scroll) % 1)
	end
	setMarkText(block.tagMarks, string.format("%.1f", left))
end

-- Our screen ------------------------------------------------------------------------

type Screen = {
	gui: ScreenGui,
	frost: ImageLabel,
	lines: { Line },
	tears: { Frame },
	title: { Mark },
	count: TextLabel,
	vhs: Frame,
	flash: Frame,
	grade: ColorCorrectionEffect,
}

local screen: Screen? = nil
local nextScreenGlitch = 0
local SCREEN_LINES = 28

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Arcade
	l.TextScaled = true
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local function buildScreen(): Screen
	local s = screen
	if s and s.gui.Parent then
		return s
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "FreezeFrameScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3
	gui.Enabled = false
	local frost = Instance.new("ImageLabel")
	frost.Size = UDim2.fromScale(1, 1)
	frost.BackgroundTransparency = 1
	frost.Image = VFX.FROST_VIGNETTE
	frost.ImageColor3 = ICE
	frost.ImageTransparency = 1
	frost.ScaleType = Enum.ScaleType.Stretch
	frost.Parent = gui
	local scan = Instance.new("Frame")
	scan.Size = UDim2.fromScale(1, 1)
	scan.BackgroundTransparency = 1
	scan.ClipsDescendants = true
	scan.Parent = gui
	local lines = {}
	for i = 1, SCREEN_LINES do
		local f = Instance.new("Frame")
		f.Size = UDim2.new(1, 0, 0, 2)
		f.BorderSizePixel = 0
		f.BackgroundColor3 = GLITCH
		f.BackgroundTransparency = 0.85
		f.Parent = scan
		table.insert(lines, { frame = f, base = (i - 1) / SCREEN_LINES })
	end
	local tears = {}
	for i = 1, 3 do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = if i == 2 then GHOST else GLITCH
		f.BackgroundTransparency = 0.7
		f.Visible = false
		f.Parent = scan
		table.insert(tears, f)
	end
	local center = Instance.new("Frame")
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	center.Position = UDim2.fromScale(0.5, 0.36)
	center.Size = UDim2.fromScale(0.36, 0.08)
	center.BackgroundTransparency = 1
	center.Parent = gui
	local title = splitMark(center, ICE, true, 0.16)
	setMarkText(title, "FROZEN")
	local count = label(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.41),
		Size = UDim2.fromScale(0.2, 0.05),
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.3,
	})
	-- A VHS "PAUSE" in the corner.
	local vhs = Instance.new("Frame")
	vhs.Position = UDim2.new(0, 28, 0, 24)
	vhs.Size = UDim2.fromScale(0.15, 0.04)
	vhs.BackgroundTransparency = 1
	vhs.Parent = gui
	setMarkText({ pauseMark(vhs, Color3.new(1, 1, 1), 1, true, 0.2) }, "PAUSE")
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BorderSizePixel = 0
	flash.BackgroundColor3 = ICE
	flash.BackgroundTransparency = 1
	flash.ZIndex = 10
	flash.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "FreezeFrameGrade"
	grade.Enabled = false
	grade.Saturation = -0.75
	grade.Contrast = 0.15
	grade.TintColor = Color3.fromRGB(215, 240, 255)
	grade.Parent = Lighting
	local made: Screen = {
		gui = gui,
		frost = frost,
		lines = lines,
		tears = tears,
		title = title,
		count = count,
		vhs = vhs,
		flash = flash,
		grade = grade,
	}
	screen = made
	return made
end

local screenOn = false
local frostFade: Tween? = nil

local function setScreen(on: boolean)
	if on == screenOn then
		return
	end
	screenOn = on
	local s = buildScreen()
	if on then
		if frostFade then
			frostFade:Cancel()
			frostFade = nil
		end
		s.gui.Enabled = true
		s.grade.Enabled = true
		s.frost.ImageTransparency = 0.05
		s.flash.BackgroundTransparency = 0.35
		TweenService:Create(s.flash, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
		ModAudio.play(S.frozenStatic)
	else
		-- Shatter off: a white flash, then the frost falls away.
		s.grade.Enabled = false
		s.flash.BackgroundTransparency = 0.2
		TweenService:Create(s.flash, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
		local fade = TweenService:Create(s.frost, TweenInfo.new(0.3), { ImageTransparency = 1 })
		fade.Completed:Once(function()
			if not screenOn then
				s.gui.Enabled = false
			end
		end)
		frostFade = fade
		fade:Play()
		for _, m in s.title do
			m.frame.Visible = false
		end
		s.count.Visible = false
		s.vhs.Visible = false
		ModAudio.play(S.shatter)
		ModAudio.play(S.recover)
	end
end

local function stepScreen(now: number, left: number)
	local s = screen
	if not s or not screenOn then
		return
	end
	s.title[3].frame.Visible = true
	s.count.Visible = true
	s.count.Text = string.format("%.1f", left)
	local scroll = (now * 0.2) % 1
	for _, line in s.lines do
		line.frame.Position = UDim2.fromScale(0, (line.base + scroll) % 1)
	end
	if now >= nextScreenGlitch then
		nextScreenGlitch = now + rng:NextNumber(0.06, 0.16)
		splitGhosts(s.title, 6)
		for _, tear in s.tears do
			tear.Visible = rng:NextNumber() < 0.45
			tear.Position = UDim2.fromScale(0, rng:NextNumber(0, 0.95))
			tear.Size = UDim2.new(1, 0, 0, rng:NextInteger(4, 30))
		end
		s.vhs.Visible = rng:NextNumber() < 0.85
	end
end

-- Handler -----------------------------------------------------------------------------

-- Seconds `model` stays frozen (0: not frozen, or dead: a body shatters when it dies).
local function frozenLeft(model: Model, now: number): number
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or not Health.isAlive(humanoid) then
		return 0
	end
	return math.max(Status.until_(model, "Frozen") - now, 0)
end

local handler: Types.Handler = {}

handler.start = function()
	Frozen.start()
end

handler.onFx = function(kind: string, data: { [string]: any }): boolean
	if kind ~= "FrostBurst" or typeof(data.freeze) ~= "number" then
		return false
	end
	local at, radius = data.at, data.radius
	if typeof(at) ~= "Vector3" or typeof(radius) ~= "number" then
		return false
	end
	local team = data.team
	snapFreeze(at, radius, if typeof(team) == "number" then team else nil)
	return true
end

handler.step = function(_dt: number)
	Frozen.step()
	local now = os.clock()
	local serverNow = Workspace:GetServerTimeNow()
	local mine = player.Character
	local seen: { [Model]: boolean } = {}
	for _, body in Frozen.bodies() do
		local left = frozenLeft(body, serverNow)
		-- Our own block would sit around the camera: we get the screen instead.
		if left <= 0 or body == mine then
			continue
		end
		local root = body:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			continue
		end
		local block = blocks[body]
		if not block or block.root ~= root then
			if block then
				shatter(block, false)
			end
			block = encase(body, root)
			blocks[body] = block
		end
		seen[body] = true
		stepBlock(block, now, left)
	end
	for body, block in blocks do
		if not seen[body] then
			blocks[body] = nil
			shatter(block, body.Parent ~= nil)
		end
	end
	local myLeft = if mine then frozenLeft(mine, serverNow) else 0
	setScreen(myLeft > 0)
	stepScreen(now, myLeft)
	for i = #running, 1, -1 do
		if not running[i](now) then
			table.remove(running, i)
		end
	end
end

return handler
