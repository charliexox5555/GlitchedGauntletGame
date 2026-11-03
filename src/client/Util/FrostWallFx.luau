--!strict
-- The Frost Wall (Firewall's glitch path G2/G3, vault/01 Design/Abilities/
-- Firewall.md → Upgrades) for everyone: Util/WallFx hands it the pieces the
-- server marks WallKind "Frost". Each piece becomes a solid wall of ice
-- rising out of the floor as the wall races on, with a little cold mist at
-- its foot, frost glints, a cold light, frost on the floor and a thin edge
-- line in the viewer's colour (cyan: yours or your team's, orange-red: an
-- enemy's). It's a glitch: the ice flickers and jumps sideways in magenta
-- with pixel cubes and torn scanlines flashing on its faces. At ExpiresAt the
-- ice shatters and sinks over ~0.5 s.
--
-- Stylized look (2026-11-03, Util/IceKit): one faceted crystal slab per
-- 4-stud piece (SlabA / SlabB: chunky columns with cleaved tops, nearly
-- opaque, it Hinders on contact), a crystal cluster at its foot, the magenta
-- Pixels / Scanlines meshes for the glitches, a faceted frost patch on the
-- floor and chips flying off when it shatters; little mist. Until
-- ReplicatedStorage.Abilities.IceVFX is installed it falls back to the older
-- look (frosted Ice blocks with Glass crests and a frost decal).
-- Everything client-side is pooled: the kit meshes (IceKit) and each piece's
-- edge line with its mist, glints and light.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Firewall = require(ReplicatedStorage.Shared.Mods.Firewall)
local Mods = require(ReplicatedStorage.Shared.Mods)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local IceKit = require(script.Parent.IceKit)
local ModVfx = require(script.Parent.ModVfx)
local TeamColor = require(script.Parent.TeamColor)

local FrostWallFx = {}

local player = Players.LocalPlayer

FrostWallFx.ICE = Color3.fromHex("BFE8FF")
local ICE = FrostWallFx.ICE
local DEEP = Color3.fromHex("6FB8E8") -- the slabs' deeper blue
local GLITCH = TeamColor.GLITCH

local FADE = 0.5 -- the ice sinks over this at the end (ModWalls FADE)
local RISE = 0.3 -- each slab grows out of the floor over this
local STAGGER = 0.1 -- slabs along a piece rise this far apart
local SLAB_EVERY = 1.7 -- studs of wall per slab (the old look)
local SLAB_ALPHA = 0.18 -- frosted: you can't see through it
local CREST_ALPHA = 0.3
local KIT_SLAB_ALPHA = 0.08 -- the kit's slab: solid ice
local FLOOR_LINGER = 2.5 -- the frost on the floor stays after the wall
local MIST_RATE = 5
local GLINT_RATE = 4
local KIT_MIST_RATE = 2 -- the kit's look: shapes, few particles
local KIT_GLINT_RATE = 2
local GLITCH_GAP = NumberRange.new(0.5, 1.8) -- seconds between a piece's glitches
local GLITCH_TIME = NumberRange.new(0.05, 0.12)
local SLABS: { IceKit.Name } = { "SlabA", "SlabB" }

type Slab = {
	part: BasePart,
	cf: CFrame, -- where it stands
	height: number,
	delay: number, -- rise stagger
	color: Color3,
	material: Enum.Material,
	alpha: number,
}

-- Pooled per piece: the edge line on the floor (mist pours off it) and an
-- invisible box over the piece carrying the glints and the light.
type Rig = {
	edge: Part,
	mist: ParticleEmitter,
	volume: Part,
	glints: ParticleEmitter,
	light: PointLight,
}

-- A magenta glitch accent: an old-look static square (a Part) or a kit mesh.
type Accent = { part: BasePart, kit: IceKit.Name? }

type Piece = {
	part: BasePart,
	kit: boolean,
	slabs: { Slab },
	accents: { Accent },
	held: { BasePart }, -- kit parts to give back to IceKit
	parts: { BasePart }, -- old-look parts to destroy
	rig: Rig,
	stopFloor: () -> (),
	born: number, -- os.clock()
	risen: boolean,
	k: number, -- the last fade applied (1: whole, 0: gone)
	shattered: boolean,
	rng: Random,
	nextGlitch: number,
	glitchUntil: number,
	glitched: boolean,
}

local pieces: { [BasePart]: Piece } = {}
-- Floor frost outliving its piece: stopped at `at` (server time).
local floors: { { stop: () -> (), at: number } } = {}

local function curve(points: { number }): NumberSequence
	local keys = {}
	for i = 1, #points, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(points[i], points[i + 1]))
	end
	return NumberSequence.new(keys)
end

-- Whether a Firewall level is the ice wall (Config/Mods behaviour "Frost").
function FrostWallFx.isFrost(level: unknown): boolean
	if typeof(level) ~= "string" then
		return false
	end
	local stats = Mods.stats("Firewall", level)
	return stats ~= nil and stats.behaviour == "Frost"
end

local function block(
	parent: Instance,
	class: "Part" | "WedgePart",
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	alpha: number
): BasePart
	local p: BasePart = if class == "WedgePart"
		then Instance.new("WedgePart")
		else Instance.new("Part")
	p.Name = "Ice"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Transparency = alpha
	p.Reflectance = if material == Enum.Material.Glass then 0.15 else 0
	p.Parent = parent
	return p
end

local function backOut(x: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

local function tintOf(part: BasePart): Color3
	if part:GetAttribute("OwnerId") == player.UserId then
		return TeamColor.ALLY
	end
	local team = part:GetAttribute("TeamId")
	return TeamColor.forTeam(if typeof(team) == "number" then team else nil)
end

-- The pooled edge rigs ------------------------------------------------------------

local rigFolder: Folder? = nil
local freeRigs: { Rig } = {}
local PARK = CFrame.new(0, -10000, 0)

local function folder(): Folder
	local f = rigFolder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "FrostWallFx"
	made.Parent = Workspace
	rigFolder = made
	table.clear(freeRigs)
	return made
end

local function makeRig(parent: Folder): Rig
	local edge = block(parent, "Part", Vector3.one, PARK, ICE, Enum.Material.Neon, 1) :: Part
	edge.Name = "IceEdge"
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = VFX.FROST_MIST_2x2
	mist.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	mist.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	mist.Shape = Enum.ParticleEmitterShape.Box
	mist.EmissionDirection = Enum.NormalId.Top
	mist.Color = ColorSequence.new(ICE)
	mist.Lifetime = NumberRange.new(1.8, 2.6)
	mist.Speed = NumberRange.new(0.4, 1.4)
	mist.Acceleration = Vector3.new(0, -0.5, 0) -- cold air sinks and spreads
	mist.Drag = 0.6
	mist.SpreadAngle = Vector2.new(70, 70)
	mist.Size = curve({ 0, 2.5, 1, 6.5 })
	mist.Transparency = curve({ 0, 1, 0.25, 0.55, 1, 1 })
	mist.Rotation = NumberRange.new(0, 360)
	mist.RotSpeed = NumberRange.new(-15, 15)
	mist.LightEmission = 0.1
	mist.LightInfluence = 0.5
	mist.Rate = 0
	mist.Parent = edge
	local volume =
		block(parent, "Part", Vector3.one, PARK, ICE, Enum.Material.SmoothPlastic, 1) :: Part
	volume.Name = "IceGlints"
	-- Frost glints winking all over the ice.
	local glints = Instance.new("ParticleEmitter")
	glints.Texture = VFX.FROST_SHARD
	glints.Shape = Enum.ParticleEmitterShape.Box
	glints.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	glints.Color = ColorSequence.new(Color3.new(1, 1, 1), ICE)
	glints.Lifetime = NumberRange.new(0.3, 0.7)
	glints.Speed = NumberRange.new(0, 0.3)
	glints.Size = curve({ 0, 0, 0.3, 0.5, 1, 0 })
	glints.Rotation = NumberRange.new(0, 360)
	glints.LightEmission = 1
	glints.LightInfluence = 0
	glints.Rate = 0
	glints.Parent = volume
	local light = Instance.new("PointLight")
	light.Color = ICE
	light.Range = 12
	light.Brightness = 1.2
	light.Shadows = false
	light.Enabled = false
	light.Parent = volume
	return { edge = edge, mist = mist, volume = volume, glints = glints, light = light }
end

local function takeRig(): Rig
	local parent = folder()
	return table.remove(freeRigs) or makeRig(parent)
end

local function giveRig(rig: Rig)
	rig.mist.Rate = 0
	rig.glints.Rate = 0
	rig.light.Enabled = false
	rig.edge.CFrame = PARK
	rig.edge.Transparency = 1
	rig.volume.CFrame = PARK
	if rig.edge.Parent and rig.edge.Parent == rigFolder then
		table.insert(freeRigs, rig)
	end
end

-- Dressing a piece ------------------------------------------------------------------

type Ctx = {
	part: BasePart,
	rng: Random,
	tint: Color3,
	base: CFrame, -- the floor line, along the wall
	h: number,
	len: number,
	th: number,
	slabs: { Slab },
	add: (p: BasePart, cf: CFrame, height: number, delay: number, alpha: number) -> (),
}

-- The old look: frosted Ice blocks with Glass crests and shards, static squares.
local function dressBlocks(c: Ctx, parts: { BasePart }, accents: { Accent })
	local rng, base, h, len, th = c.rng, c.base, c.h, c.len, c.th
	local parent = folder()
	local function made(p: BasePart): BasePart
		table.insert(parts, p)
		return p
	end
	-- The slabs: frosted ice blocks leaning a little, each with a glassy
	-- crest sloping one way or the other, so the top edge is jagged.
	local n = math.max(2, math.round(len / SLAB_EVERY))
	for i = 1, n do
		local z = -len / 2 + (i - 0.5) * len / n
		local sh = h * rng:NextNumber(0.6, 0.9)
		local w = len / n * rng:NextNumber(1.1, 1.35)
		local t = th * rng:NextNumber(0.9, 1.4)
		local lean =
			CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), 0, math.rad(rng:NextNumber(-7, 7)))
		local cf = base
			* CFrame.new(rng:NextNumber(-0.2, 0.2), 0, z)
			* lean
			* CFrame.new(0, sh / 2, 0)
		local color = ICE:Lerp(DEEP, rng:NextNumber(0, 0.45)):Lerp(c.tint, 0.1)
		local delay = (i - 1) / n * STAGGER
		c.add(
			made(
				block(
					parent,
					"Part",
					Vector3.new(t, sh, w),
					cf,
					color,
					Enum.Material.Ice,
					SLAB_ALPHA
				)
			),
			cf,
			sh,
			delay,
			SLAB_ALPHA
		)
		local crest = math.max(h - sh + rng:NextNumber(0.3, 1.8), 0.8)
		local flip = if rng:NextNumber() < 0.5
			then CFrame.Angles(0, math.pi, 0)
			else CFrame.identity
		local ccf = cf * CFrame.new(0, sh / 2 + crest / 2, 0) * flip
		c.add(
			made(
				block(
					parent,
					"WedgePart",
					Vector3.new(t * 0.9, crest, w),
					ccf,
					ICE,
					Enum.Material.Glass,
					CREST_ALPHA
				)
			),
			ccf,
			sh + crest,
			delay + 0.04,
			CREST_ALPHA
		)
	end
	-- Shards jutting out of the foot on both sides.
	for _, side in { -1, 1 } do
		local sz = Vector3.new(0.35, rng:NextNumber(2.5, 4.5), 0.35)
		local cf = base
			* CFrame.new(side * (th / 2 + 0.15), 0, rng:NextNumber(-len / 3, len / 3))
			* CFrame.Angles(0, rng:NextNumber(-0.6, 0.6), -side * math.rad(rng:NextNumber(18, 35)))
			* CFrame.new(0, sz.Y / 2 - 0.3, 0)
		c.add(
			made(block(parent, "Part", sz, cf, ICE, Enum.Material.Glass, CREST_ALPHA)),
			cf,
			sz.Y,
			0.05,
			CREST_ALPHA
		)
	end
	-- Magenta static: a few squares that flash on the slabs' faces.
	for _ = 1, 3 do
		local px = made(
			block(parent, "Part", Vector3.new(0.05, 0.5, 0.5), base, GLITCH, Enum.Material.Neon, 1)
		)
		px.Name = "Static"
		table.insert(accents, { part = px, kit = nil })
	end
end

-- The kit's look: one faceted slab, a crystal cluster at the foot, magenta
-- Pixels / Scanlines meshes for the glitches. False when a mesh is missing.
local function dressKit(c: Ctx, held: { BasePart }, accents: { Accent }): boolean
	local rng, base, h, len, th = c.rng, c.base, c.h, c.len, c.th
	local function take(name: IceKit.Name): BasePart?
		local p = IceKit.acquire(name)
		if p then
			table.insert(held, p)
		end
		return p
	end
	local slab = take(IceKit.pick(rng, SLABS))
	local cluster = take("Cluster")
	local pixels = take("Pixels_Energy")
	local lines = take("Scanlines_Energy")
	if not slab or not cluster or not pixels or not lines then
		return false
	end
	-- The slab spans the whole piece (and overlaps its neighbours a little:
	-- the columns reach past the core), turned round on every other piece.
	local core = IceKit.SLAB_CORE
	local flip = if rng:NextNumber() < 0.5 then CFrame.Angles(0, math.pi, 0) else CFrame.identity
	slab.Color = ICE:Lerp(DEEP, rng:NextNumber(0, 0.35)):Lerp(c.tint, 0.08)
	slab.Material = Enum.Material.SmoothPlastic
	slab.Transparency = KIT_SLAB_ALPHA
	IceKit.place(
		slab,
		base * CFrame.new(rng:NextNumber(-0.08, 0.08), 0, 0) * flip,
		Vector3.new(th * 1.1 / core.X, h / core.Y, len / core.Z)
	)
	c.add(slab, slab.CFrame, h, 0, KIT_SLAB_ALPHA)
	-- A crystal cluster leaning off the foot, one side or the other.
	local side = if rng:NextNumber() < 0.5 then -1 else 1
	local size = rng:NextNumber(2, 2.8)
	cluster.Color = ICE
	cluster.Material = Enum.Material.SmoothPlastic
	cluster.Transparency = 0.1
	IceKit.place(
		cluster,
		base
			* CFrame.new(side * (th / 2 + 0.1), 0, rng:NextNumber(-len / 3, len / 3))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
		Vector3.one * size
	)
	c.add(cluster, cluster.CFrame, size * 1.1, 0.05, 0.1)
	local glitches: { Accent } =
		{ { part = pixels, kit = "Pixels_Energy" }, { part = lines, kit = "Scanlines_Energy" } }
	for _, accent in glitches do
		local p = accent.part
		p.Color = GLITCH
		p.Material = Enum.Material.Neon
		p.Transparency = 1
		table.insert(accents, accent)
	end
	return true
end

-- Dresses a piece; false when it already was.
function FrostWallFx.dress(part: BasePart): boolean
	if pieces[part] then
		return false
	end
	local wallId = part:GetAttribute("WallId")
	local index = part:GetAttribute("Index")
	local seed = (if typeof(wallId) == "number" then wallId else 0) * 131
		+ (if typeof(index) == "number" then index else 0)
	local rng = Random.new(seed)
	local size = part.Size
	local h, len, th = size.Y, size.Z, size.X
	local base = part.CFrame * CFrame.new(0, -h / 2, 0) -- the floor line, along the wall
	local tint = tintOf(part)
	local slabs: { Slab } = {}
	local ctx: Ctx = {
		part = part,
		rng = rng,
		tint = tint,
		base = base,
		h = h,
		len = len,
		th = th,
		slabs = slabs,
		add = function(p: BasePart, cf: CFrame, height: number, delay: number, alpha: number)
			p.CFrame = cf * CFrame.new(0, -height, 0) -- below the floor until it rises
			table.insert(slabs, {
				part = p,
				cf = cf,
				height = height,
				delay = delay,
				color = p.Color,
				material = p.Material,
				alpha = alpha,
			})
		end,
	}
	local accents: { Accent } = {}
	local held: { BasePart } = {}
	local parts: { BasePart } = {}
	local kit = IceKit.ready() and dressKit(ctx, held, accents)
	if not kit then
		for _, p in held do
			IceKit.release(p)
		end
		table.clear(held)
		table.clear(slabs)
		table.clear(accents)
		dressBlocks(ctx, parts, accents)
	end
	-- The edge line in the viewer's colour along the foot; the mist pours off it.
	local rig = takeRig()
	rig.edge.Size = Vector3.new(th * 1.8, 0.06, len)
	rig.edge.CFrame = base * CFrame.new(0, 0.04, 0)
	rig.edge.Color = tint
	rig.edge.Transparency = 0.35
	rig.volume.Size = size
	rig.volume.CFrame = part.CFrame
	-- The kit's look: mist from every other piece only.
	local odd = typeof(index) == "number" and index % 2 == 1
	rig.mist.Rate = if not kit then MIST_RATE elseif odd then KIT_MIST_RATE else 0
	rig.glints.Rate = if kit then KIT_GLINT_RATE else GLINT_RATE
	-- A cold light on every other piece.
	rig.light.Enabled = odd
	rig.light.Brightness = 1.2
	local stopFloor: () -> ()
	if kit then
		local handle = IceKit.spawn({
			name = "Floor",
			at = base * CFrame.new(0, 0.02, 0),
			scale = Vector3.new(th * 1.3, 1.5, len * 0.62),
			color = ICE,
			alpha = 0.35,
			life = 60, -- stopped once the wall is gone
			from = 0.4,
			grow = RISE,
			fade = 0.6,
		})
		stopFloor = function()
			if handle then
				IceKit.stop(handle)
			end
		end
	else
		local handle = ModVfx.quad({
			texture = VFX.FROST_GROUND,
			cframe = base * CFrame.new(0, 0.05, 0),
			from = math.max(len, th) * 1.7,
			color = ICE,
			life = 60, -- stopped once the wall is gone
			alpha0 = 0.2,
			hold = true,
			lightInfluence = 0.6,
		})
		stopFloor = function()
			ModVfx.stop(handle)
		end
	end
	local now = os.clock()
	pieces[part] = {
		part = part,
		kit = kit,
		slabs = slabs,
		accents = accents,
		held = held,
		parts = parts,
		rig = rig,
		stopFloor = stopFloor,
		born = now,
		risen = false,
		k = 1,
		shattered = false,
		rng = rng,
		nextGlitch = now + RISE + rng:NextNumber(GLITCH_GAP.Min, GLITCH_GAP.Max),
		glitchUntil = 0,
		glitched = false,
	}
	-- The ice bursting out of the floor.
	rig.mist:Emit(2)
	ModVfx.burst(base.Position + Vector3.new(0, 1, 0), ICE, if kit then 3 else 5, "Sparkle")
	return true
end

-- Glitches ---------------------------------------------------------------------------

local function unglitch(p: Piece)
	if not p.glitched then
		return
	end
	p.glitched = false
	for _, s in p.slabs do
		s.part.Color = s.color
		s.part.Material = s.material
		s.part.Transparency = s.alpha
		s.part.CFrame = s.cf
	end
	for _, a in p.accents do
		a.part.Transparency = 1
	end
end

-- A glitch: a slab jumps sideways in magenta (or the whole piece flickers
-- out), and static flashes on the ice.
local function glitch(p: Piece, now: number)
	local rng = p.rng
	if rng:NextNumber() < 0.2 then
		for _, s in p.slabs do
			s.part.Transparency = 0.7
		end
	else
		local s = p.slabs[rng:NextInteger(1, #p.slabs)]
		s.part.Color = GLITCH
		s.part.Material = Enum.Material.Neon
		s.part.Transparency = 0.3
		s.part.CFrame = s.cf * CFrame.new(rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.3, 0.3), 0)
	end
	local size = p.part.Size
	for _, a in p.accents do
		local name = a.kit
		if name then
			-- A kit accent on one face of the wall, flat against it (its thin
			-- axis turned onto the wall's thickness).
			local face = if rng:NextNumber() < 0.5 then -1 else 1
			local at = p.part.CFrame
				* CFrame.new(
					face * (size.X / 2 + 0.12),
					rng:NextNumber(-0.25, 0.35) * size.Y,
					rng:NextNumber(-0.35, 0.35) * size.Z
				)
				* CFrame.Angles(0, math.pi / 2, 0)
			local scale = if name == "Pixels_Energy"
				then Vector3.one * rng:NextNumber(0.9, 1.8)
				else Vector3.new(rng:NextNumber(1.5, 3), rng:NextNumber(0.8, 2), 1)
			IceKit.place(a.part, at, scale)
			a.part.Transparency = 0.05
		else
			local s = p.slabs[rng:NextInteger(1, #p.slabs)]
			local half = s.part.Size / 2
			local edge = rng:NextNumber(0.25, 0.9)
			a.part.Size = Vector3.new(0.05, edge, edge * rng:NextNumber(0.5, 2.5))
			a.part.CFrame = s.cf
				* CFrame.new(
					(half.X + 0.04) * (if rng:NextNumber() < 0.5 then -1 else 1),
					rng:NextNumber(-half.Y, half.Y),
					rng:NextNumber(-half.Z, half.Z)
				)
			a.part.Transparency = 0.05
		end
	end
	p.glitched = true
	p.glitchUntil = now + rng:NextNumber(GLITCH_TIME.Min, GLITCH_TIME.Max)
	p.nextGlitch = now + rng:NextNumber(GLITCH_GAP.Min, GLITCH_GAP.Max)
end

-- The kit's shatter: a few chips fly off the top of the piece.
local function chips(p: Piece)
	local rng = p.rng
	local top = p.part.CFrame * CFrame.new(0, p.part.Size.Y * 0.3, 0)
	for i = 1, 2 do
		local out = p.part.CFrame.RightVector * (if i == 1 then -1 else 1)
		IceKit.spawn({
			name = IceKit.pick(rng, IceKit.FRAGMENTS),
			at = top * CFrame.new(0, rng:NextNumber(-1.5, 1.5), rng:NextNumber(-1.2, 1.2)),
			scale = Vector3.one * rng:NextNumber(0.6, 1.1),
			color = ICE,
			alpha = 0.1,
			life = 0.6,
			fade = 0.25,
			velocity = out * rng:NextNumber(6, 12) + Vector3.new(0, rng:NextNumber(6, 12), 0),
			spin = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8)),
		})
	end
end

local function forget(part: BasePart, p: Piece, serverNow: number)
	pieces[part] = nil
	for _, held in p.held do
		IceKit.release(held)
	end
	for _, old in p.parts do
		old:Destroy()
	end
	giveRig(p.rig)
	-- It lingers after a wall that ran out; a wall cleared early (the round
	-- ended) takes its frost with it.
	local expires = part:GetAttribute("ExpiresAt")
	local ranOut = typeof(expires) == "number" and serverNow >= expires
	table.insert(floors, {
		stop = p.stopFloor,
		at = if ranOut then (expires :: number) + FLOOR_LINGER else serverNow,
	})
end

-- Per frame (WallFx.step). Whether `at` (our root) is in live ice.
function FrostWallFx.step(now: number, serverNow: number, at: Vector3?): boolean
	local inside = false
	for part, p in pieces do
		if not part.Parent then
			forget(part, p, serverNow)
			continue
		end
		-- Rising out of the floor.
		if not p.risen then
			local age = now - p.born
			local done = true
			for _, s in p.slabs do
				local x = math.clamp((age - s.delay) / RISE, 0, 1)
				if x < 1 then
					done = false
				end
				s.part.CFrame = s.cf * CFrame.new(0, -(1 - backOut(x)) * s.height, 0)
			end
			p.risen = done
		end
		-- The end: it shatters and sinks over FADE after ExpiresAt.
		local expires = part:GetAttribute("ExpiresAt")
		local k = 1
		if typeof(expires) == "number" then
			k = math.clamp((expires - serverNow) / FADE, 0, 1)
		end
		if k < 1 then
			unglitch(p)
			if not p.shattered then
				p.shattered = true
				local rig = p.rig
				rig.mist.Rate = 0
				rig.glints.Rate = 0
				rig.mist:Emit(if p.kit then 1 else 3)
				rig.glints:Emit(if p.kit then 5 else 10)
				ModVfx.burst(part.Position, ICE, if p.kit then 6 else 10, "Sparkle")
				if p.kit then
					chips(p)
				end
			end
			if k ~= p.k then
				p.k = k
				for _, s in p.slabs do
					s.part.Transparency = s.alpha + (1 - s.alpha) * (1 - k)
					s.part.CFrame = s.cf * CFrame.new(0, -(1 - k) * s.height * 0.35, 0)
				end
				p.rig.light.Brightness = 1.2 * k
				p.rig.edge.Transparency = 0.35 + 0.65 * (1 - k)
			end
		elseif p.risen then
			-- Glitch static while it stands.
			if p.glitched and now >= p.glitchUntil then
				unglitch(p)
			elseif not p.glitched and now >= p.nextGlitch then
				glitch(p, now)
			end
		end
		if at and k > 0 and Firewall.inside(part, at, 0.8) then
			inside = true
		end
	end
	for i = #floors, 1, -1 do
		if serverNow >= floors[i].at then
			floors[i].stop()
			table.remove(floors, i)
		end
	end
	return inside
end

return FrostWallFx
