--!strict
-- The Frost Wall (Firewall's glitch path G2/G3, vault/01 Design/Abilities/
-- Firewall.md → Upgrades) for everyone: Util/WallFx hands it the pieces the
-- server marks WallKind "Frost". Each piece becomes a row of frosted ice
-- slabs with glassy crests and shards sticking out, rising out of the floor
-- as the wall races on, with cold mist pooling at its foot, frost glints, a
-- cold light, frost on the floor and a thin edge line in the viewer's colour
-- (cyan: yours or your team's, orange-red: an enemy's). It's a glitch: the
-- slabs flicker and jump sideways in magenta static. At ExpiresAt the ice
-- shatters and sinks over ~0.5 s.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Firewall = require(ReplicatedStorage.Shared.Mods.Firewall)
local Mods = require(ReplicatedStorage.Shared.Mods)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

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
local SLAB_EVERY = 1.7 -- studs of wall per slab
local SLAB_ALPHA = 0.18 -- frosted: you can't see through it
local CREST_ALPHA = 0.3
local FLOOR_LINGER = 2.5 -- the frost on the floor stays after the wall
local MIST_RATE = 5
local GLINT_RATE = 4
local GLITCH_GAP = NumberRange.new(0.5, 1.8) -- seconds between a piece's glitches
local GLITCH_TIME = NumberRange.new(0.05, 0.12)

type Slab = {
	part: BasePart,
	cf: CFrame, -- where it stands
	height: number,
	delay: number, -- rise stagger
	color: Color3,
	material: Enum.Material,
	alpha: number,
}

type Piece = {
	part: BasePart,
	slabs: { Slab },
	pixels: { Part }, -- magenta static squares
	mist: ParticleEmitter,
	glints: ParticleEmitter,
	light: PointLight?,
	floor: ModVfx.Handle,
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
local floors: { { handle: ModVfx.Handle, at: number } } = {}

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
	local function add(p: BasePart, cf: CFrame, height: number, delay: number, alpha: number)
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
		local color = ICE:Lerp(DEEP, rng:NextNumber(0, 0.45)):Lerp(tint, 0.1)
		local delay = (i - 1) / n * STAGGER
		add(
			block(part, "Part", Vector3.new(t, sh, w), cf, color, Enum.Material.Ice, SLAB_ALPHA),
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
		add(
			block(
				part,
				"WedgePart",
				Vector3.new(t * 0.9, crest, w),
				ccf,
				ICE,
				Enum.Material.Glass,
				CREST_ALPHA
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
		add(
			block(part, "Part", sz, cf, ICE, Enum.Material.Glass, CREST_ALPHA),
			cf,
			sz.Y,
			0.05,
			CREST_ALPHA
		)
	end
	-- A thin line in the viewer's colour along the foot; the mist pours off it.
	local edge = block(
		part,
		"Part",
		Vector3.new(th * 1.8, 0.06, len),
		base * CFrame.new(0, 0.04, 0),
		tint,
		Enum.Material.Neon,
		0.35
	)
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
	mist.Rate = MIST_RATE
	mist.Parent = edge
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
	glints.Rate = GLINT_RATE
	glints.Parent = part
	-- A cold light on every other piece.
	local light: PointLight? = nil
	if typeof(index) == "number" and index % 2 == 1 then
		local l = Instance.new("PointLight")
		l.Color = ICE
		l.Range = 12
		l.Brightness = 1.2
		l.Shadows = false
		l.Parent = part
		light = l
	end
	-- Magenta static: a few squares that flash on the slabs' faces.
	local pixels: { Part } = {}
	for _ = 1, 3 do
		local px = block(
			part,
			"Part",
			Vector3.new(0.05, 0.5, 0.5),
			part.CFrame,
			GLITCH,
			Enum.Material.Neon,
			1
		) :: Part
		px.Name = "Static"
		table.insert(pixels, px)
	end
	local floor = ModVfx.quad({
		texture = VFX.FROST_GROUND,
		cframe = base * CFrame.new(0, 0.05, 0),
		from = math.max(len, th) * 1.7,
		color = ICE,
		life = 60, -- stopped once the wall is gone
		alpha0 = 0.2,
		hold = true,
		lightInfluence = 0.6,
	})
	local now = os.clock()
	pieces[part] = {
		part = part,
		slabs = slabs,
		pixels = pixels,
		mist = mist,
		glints = glints,
		light = light,
		floor = floor,
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
	mist:Emit(2)
	ModVfx.burst(base.Position + Vector3.new(0, 1, 0), ICE, 5, "Sparkle")
	return true
end

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
	for _, px in p.pixels do
		px.Transparency = 1
	end
end

-- A glitch: a slab jumps sideways in magenta (or the whole piece flickers
-- out), and static squares flash on the ice.
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
	for _, px in p.pixels do
		local s = p.slabs[rng:NextInteger(1, #p.slabs)]
		local half = s.part.Size / 2
		local edge = rng:NextNumber(0.25, 0.9)
		px.Size = Vector3.new(0.05, edge, edge * rng:NextNumber(0.5, 2.5))
		px.CFrame = s.cf
			* CFrame.new(
				(half.X + 0.04) * (if rng:NextNumber() < 0.5 then -1 else 1),
				rng:NextNumber(-half.Y, half.Y),
				rng:NextNumber(-half.Z, half.Z)
			)
		px.Transparency = 0.05
	end
	p.glitched = true
	p.glitchUntil = now + rng:NextNumber(GLITCH_TIME.Min, GLITCH_TIME.Max)
	p.nextGlitch = now + rng:NextNumber(GLITCH_GAP.Min, GLITCH_GAP.Max)
end

local function forget(part: BasePart, p: Piece, serverNow: number)
	pieces[part] = nil
	-- It lingers after a wall that ran out; a wall cleared early (the round
	-- ended) takes its frost with it.
	local expires = part:GetAttribute("ExpiresAt")
	local ranOut = typeof(expires) == "number" and serverNow >= expires
	table.insert(floors, {
		handle = p.floor,
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
				p.mist.Rate = 0
				p.glints.Rate = 0
				p.mist:Emit(3)
				p.glints:Emit(10)
				ModVfx.burst(part.Position, ICE, 10, "Sparkle")
			end
			if k ~= p.k then
				p.k = k
				for _, s in p.slabs do
					s.part.Transparency = s.alpha + (1 - s.alpha) * (1 - k)
					s.part.CFrame = s.cf * CFrame.new(0, -(1 - k) * s.height * 0.35, 0)
				end
				local light = p.light
				if light then
					light.Brightness = 1.2 * k
				end
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
			ModVfx.stop(floors[i].handle)
			table.remove(floors, i)
		end
	end
	return inside
end

return FrostWallFx
