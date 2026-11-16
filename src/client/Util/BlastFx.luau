--!strict
-- The free pack's world blasts (vault/02 Art/Ability VFX Direction.md: shapes
-- first, three beats, team colour on gameplay lines, magenta only as a
-- two-frame accent on the glitch path's key moment). Solid shapes from the
-- rework kit (Util/ReworkVfx: FX_Stroke, FX_FloorStar, FX_Ring) carry each
-- effect; soft glows only sit under them (a soft glow alone vanishes on a
-- pale floor in daylight: the first pass, 2026-11-17).
--   BlastFx.shock(at, normal, radius, color, static)   Shock Dart's burst: a
--     white star flat on the surface it hit (beat 1), jagged white-blue arcs
--     snapping out on held frames (beat 2), a ring in team colour at the
--     blast's edge and sparks (beat 3). Static (G): ice-white arcs and a
--     dashed ring; the arcs' first two frames magenta.
--   BlastFx.roller(at, radius, color)   the Roller's blast: a hot star and
--     glow, a shockwave, a floor star and ring in team colour, sparks.
--   BlastFx.flashPop(at, color, exposure, range)   the Flash going off: one
--     big glow shrinking 50 → 1 studs over ~0.5 s, a hard four-point star and
--     a light (RIVALS FlashbangEffect numbers, our own look); Exposure (G): a
--     scan ring in team colour runs out, its first two frames magenta.
-- Everything runs on the effects clock (ReworkVfx.now: Studio review can slow
-- or freeze it) and is stepped by ModFxController (BlastFx.step).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Tex = require(ReplicatedStorage.Shared.Config.VfxTextures)
local ModsConfig = require(ReplicatedStorage.Shared.Config.Mods)

local ModVfx = require(script.Parent.ModVfx)
local ReworkVfx = require(script.Parent.ReworkVfx)

local BlastFx = {}

local WHITE = Color3.new(1, 1, 1)
local ARC_COLOR = Color3.fromHex("4FB2EE") -- Neon draws it a step brighter: a light electric blue
local ARC_GLOW = Color3.fromHex("5EC4FF")
local STATIC_ARC = Color3.fromHex("A9D9F0")
local FIRE_HOT = Color3.fromHex("E08A1E") -- Neon draws it a step brighter: hot gold-orange
local FIRE_DEEP = Color3.fromHex("D2481A") -- the outer flame, orange-red
local MAGENTA = ModsConfig.COLORS.glitch
local ACCENT_TIME = 2 / 30 -- the glitch accent: two frames
local ARC_FPS = 24 -- held frames: arcs jump to new paths this often
local ARC_SEGMENTS = 3
local ARC_THICK = 2.6 -- x the stroke's kit thickness (~0.12-0.2 studs)

type Billboard = {
	gui: BillboardGui,
	image: ImageLabel,
	from: number,
	to: number,
	born: number,
	life: number,
	alpha0: number,
	color: Color3,
	accentUntil: number?,
}

type Light = { part: BasePart, light: PointLight, born: number, life: number, from: number }

-- A kit piece animated from `from` to `to` scale (kit axes) over `life`.
type Piece = {
	part: BasePart,
	name: ReworkVfx.Name,
	anchor: CFrame,
	from: Vector3,
	to: Vector3,
	born: number,
	life: number,
	alpha0: number,
	color: Color3,
	accentUntil: number?,
}

type Arc = {
	strokes: { BasePart },
	-- `field`: each new path starts somewhere inside the radius (arcs
	-- crawling over the area); `target`: the path always ends there (an arc
	-- jumping to someone it hit); `from`: a fixed start (a bolt from above).
	field: boolean,
	target: Vector3?,
	from: Vector3?,
	thick: number,
	center: Vector3,
	normal: Vector3,
	reach: number,
	born: number,
	life: number,
	nextJump: number,
	accentUntil: number?,
	color: Color3,
	points: { Vector3 },
}

local folder: Folder? = nil
local billboards: { Billboard } = {}
local lights: { Light } = {}
local pieces: { Piece } = {}
local arcs: { Arc } = {}

local function fxFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "BlastFx"
	made.Parent = Workspace
	folder = made
	return made
end

local function holder(at: Vector3): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one * 0.1
	p.CFrame = CFrame.new(at)
	p.Parent = fxFolder()
	return p
end

-- A camera-facing glow `from` → `to` studs across over `life` s.
local function glow(
	at: Vector3,
	texture: string,
	color: Color3,
	from: number,
	to: number,
	life: number,
	alpha0: number?,
	accent: boolean?
)
	local now = ReworkVfx.now()
	local part = holder(at)
	local gui = Instance.new("BillboardGui")
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Size = UDim2.fromScale(from, from)
	gui.Adornee = part
	gui.Parent = part
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = texture
	image.ImageColor3 = color
	image.ImageTransparency = alpha0 or 0
	image.Parent = gui
	table.insert(billboards, {
		gui = gui,
		image = image,
		from = from,
		to = to,
		born = now,
		life = life,
		alpha0 = alpha0 or 0,
		color = color,
		accentUntil = if accent then now + ACCENT_TIME else nil,
	})
end

local function light(at: Vector3, color: Color3, brightness: number, range: number, life: number)
	local part = holder(at)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = part
	table.insert(
		lights,
		{ part = part, light = l, born = ReworkVfx.now(), life = life, from = brightness }
	)
end

-- A kit piece, Neon, `from` → `to` (kit-axis scale) over `life`.
local function piece(
	name: ReworkVfx.Name,
	anchor: CFrame,
	from: Vector3,
	to: Vector3,
	life: number,
	color: Color3,
	alpha0: number?,
	accent: boolean?
)
	local part = ReworkVfx.take(name)
	if not part then
		return
	end
	local now = ReworkVfx.now()
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = alpha0 or 0
	ReworkVfx.place(part, name, anchor, from)
	table.insert(pieces, {
		part = part,
		name = name,
		anchor = anchor,
		from = from,
		to = to,
		born = now,
		life = life,
		alpha0 = alpha0 or 0,
		color = color,
		accentUntil = if accent then now + ACCENT_TIME else nil,
	})
end

local function worldParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { fxFolder() }
	for _, name in { "ModVfx", "ModFx", "Effects", "Dummies", "ReworkFx", "Rollers" } do
		local f = Workspace:FindFirstChild(name)
		if f then
			table.insert(exclude, f)
		end
	end
	params.FilterDescendantsInstances = exclude
	return params
end

-- A random unit vector on the surface plane (normal `n`).
local function along(n: Vector3): Vector3
	local d = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1)
	d -= n * d:Dot(n)
	return if d.Magnitude > 1e-3 then d.Unit else n:Cross(Vector3.xAxis).Unit
end

-- An arc's new path: from `center` a random way out (biased off the surface
-- by `normal`), stopped by the first thing it meets (or to `finishAt`),
-- broken into ARC_SEGMENTS jagged steps.
local function arcPath(
	center: Vector3,
	normal: Vector3,
	reach: number,
	params: RaycastParams,
	finishAt: Vector3?
): { Vector3 }
	local finish: Vector3
	if finishAt then
		finish = finishAt
	else
		local dir = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1)
		if dir.Magnitude < 1e-3 then
			dir = normal
		end
		dir = (dir.Unit + normal * 0.25).Unit -- mostly along the surface: arcs crawl out
		local len = reach * (0.55 + 0.45 * math.random())
		local hit = Workspace:Raycast(center, dir * len, params)
		finish = if hit then hit.Position else center + dir * len
	end
	local span = finish - center
	local side = span:Cross(normal)
	if side.Magnitude < 1e-3 then
		side = span:Cross(Vector3.xAxis)
	end
	side = side.Unit
	local up = span:Cross(side).Unit
	local points = { center }
	for i = 1, ARC_SEGMENTS - 1 do
		local u = i / ARC_SEGMENTS
		local kink = span.Magnitude * 0.3
		local jitter = side * (math.random() * 2 - 1) * kink
			+ up * (math.random() * 2 - 1) * kink * 0.6
		table.insert(points, center + span * u + jitter)
	end
	table.insert(points, finish)
	return points
end

-- Places an arc's strokes along its points: each stroke's head (bright end)
-- at the outer point, its body back toward the centre.
local function placeArc(a: Arc, thick: number)
	for i, stroke in a.strokes do
		local p0, p1 = a.points[i], a.points[i + 1]
		local seg = p1 - p0
		local len = seg.Magnitude
		if len < 1e-3 then
			continue
		end
		local anchor = CFrame.lookAt(p1, p1 + seg)
		ReworkVfx.place(stroke, "FX_Stroke", anchor, Vector3.new(thick, thick, len))
	end
end

local function pathFor(a: Arc, params: RaycastParams): { Vector3 }
	local from = a.from
	if from then
		return arcPath(from, a.normal, a.reach, params, a.target or a.center)
	end
	if a.target then
		return arcPath(a.center, a.normal, a.reach, params, a.target)
	end
	if a.field then
		-- A short arc crawling somewhere inside the radius.
		local start = a.center + along(a.normal) * (a.reach * math.sqrt(math.random()) * 0.85)
		return arcPath(start, a.normal, a.reach * 0.45, params)
	end
	return arcPath(a.center, a.normal, a.reach, params)
end

type ArcKind = { field: boolean?, target: Vector3?, from: Vector3?, thick: number? }

local function addArcs(
	center: Vector3,
	normal: Vector3,
	reach: number,
	color: Color3,
	count: number,
	life: number,
	accent: boolean,
	kind: ArcKind?
)
	local now = ReworkVfx.now()
	local params = worldParams()
	for _ = 1, count do
		local strokes: { BasePart } = {}
		for _ = 1, ARC_SEGMENTS do
			local s = ReworkVfx.take("FX_Stroke")
			if not s then
				return -- no kit installed: no arcs
			end
			s.Material = Enum.Material.Neon
			s.Color = if accent then MAGENTA else color
			table.insert(strokes, s)
		end
		local a: Arc = {
			strokes = strokes,
			field = kind ~= nil and kind.field == true,
			target = if kind then kind.target else nil,
			from = if kind then kind.from else nil,
			thick = if kind and kind.thick then kind.thick else ARC_THICK,
			center = center,
			normal = normal,
			reach = reach,
			born = now,
			life = life * (0.7 + 0.3 * math.random()),
			nextJump = now + 1 / ARC_FPS,
			accentUntil = if accent then now + ACCENT_TIME else nil,
			color = color,
			points = {},
		}
		a.points = pathFor(a, params)
		placeArc(a, a.thick)
		table.insert(arcs, a)
	end
end

-- The surface's frame for flat pieces: its normal is the frame's +Y.
local function surfaceFrame(at: Vector3, normal: Vector3): CFrame
	local up = if normal.Magnitude > 1e-3 then normal.Unit else Vector3.yAxis
	local side = if math.abs(up.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis
	local right = up:Cross(side).Unit
	local back = right:Cross(up).Unit
	return CFrame.fromMatrix(at + up * 0.06, right, up, back)
end

-- Shock Dart's burst (2026-11-17 v2, owner: "it doesn't look like there's a
-- radius"): the blast area is drawn at its true size and held long enough to
-- read, and it's fun. Beat 1: a bolt cracks down from above onto the impact,
-- a white star flat on the surface, the flash and light. Beat 2: an electric
-- dome and a lit floor disc fill exactly `radius`, the edge ring in team
-- colour, arcs crawling over the whole area on held frames for half a
-- second, an arc jumping to everyone it hit (`struck`). Beat 3: it all
-- snaps off, sparks fall. Static (G): ice-white, dashed edge, the first two
-- frames magenta.
function BlastFx.shock(
	at: Vector3,
	normal: Vector3,
	radius: number,
	color: Color3,
	static: boolean,
	struck: { Vector3 }?
)
	local flat = surfaceFrame(at, normal)
	local spin = flat * CFrame.Angles(0, math.random() * math.pi, 0)
	local arcColor = if static then STATIC_ARC else ARC_COLOR
	local d = radius * 2
	-- Beat 1: the strike from above, the star, the flash.
	local sky = at + normal * 9 + along(normal) * 1.5
	addArcs(
		at,
		normal,
		radius,
		Color3.fromHex("DDF3FF"),
		2,
		0.14,
		static,
		{ from = sky, thick = ARC_THICK * 2.2 }
	)
	piece(
		"FX_FloorStar",
		spin,
		Vector3.new(d * 0.6, 1, d * 0.6),
		Vector3.new(d * 0.25, 1, d * 0.25),
		0.14,
		WHITE
	)
	glow(at + normal * 0.5, Tex.MOD_SPARKLE, WHITE, radius * 1.4, radius * 0.5, 0.12)
	glow(at + normal * 0.5, Tex.MOD_GLOW, ARC_GLOW, d * 1.1, d * 1.3, 0.35, 0.45)
	light(at + normal * 0.8, ARC_COLOR, 7, radius * 3.5, 0.5)
	-- Beat 2: the area, at its true size.
	piece(
		"Scan_Shell",
		flat,
		Vector3.one * (d * 0.35),
		Vector3.one * d,
		0.45,
		arcColor,
		0.82,
		static
	)
	ModVfx.quad({
		texture = Tex.MOD_GLOW,
		cframe = flat,
		from = d * 0.6,
		to = d * 1.05,
		color = arcColor,
		life = 0.5,
		alpha0 = 0.35,
		hold = true,
	})
	piece("FX_Ring", flat, Vector3.new(d * 0.5, 1, d * 0.5), Vector3.new(d, 1, d), 0.5, color, 0.05)
	ModVfx.quad({
		texture = if static then Tex.MOD_RING_DASHED else Tex.MOD_RING,
		cframe = flat,
		from = d * 0.7,
		to = d * 1.02,
		color = color,
		life = 0.55,
		alpha0 = 0.1,
		hold = true,
	})
	addArcs(at + normal * 0.15, normal, radius, arcColor, 6, 0.3, static)
	addArcs(
		at + normal * 0.1,
		normal,
		radius,
		arcColor,
		7,
		0.5,
		static,
		{ field = true, thick = ARC_THICK * 0.8 }
	)
	for _, p in struck or {} do
		addArcs(
			at + normal * 0.3,
			normal,
			radius,
			Color3.fromHex("CFEFFF"),
			1,
			0.35,
			static,
			{ target = p, thick = ARC_THICK * 1.3 }
		)
		ModVfx.burst(p, ARC_GLOW, 8, "Sparkle")
	end
	-- Beat 3: sparks thrown off.
	ModVfx.burst(at + normal * 0.2, ARC_GLOW, 24, "Sparkle")
end

-- The Roller's blast (2026-11-17 v2, owner: "more like the Boom Bot... like
-- fire", not a blue flash): a fireball. Beat 1: a hot white-gold star and
-- flash, a warm light. Beat 2: a crown of fire tongues (the rework kit's)
-- bursts up and out around the bot, hot yellow inside, orange outside, a
-- shockwave runs over the floor, the gameplay ring in team colour marks the
-- radius. Beat 3: the tongues fall back and fade, embers fly.
function BlastFx.roller(at: Vector3, radius: number, color: Color3)
	local floorAt = at - Vector3.new(0, 0.55, 0)
	local flat = surfaceFrame(floorAt, Vector3.yAxis) * CFrame.Angles(0, math.random() * math.pi, 0)
	local d = radius * 2
	glow(at, Tex.MOD_SPARKLE, Color3.fromHex("FFF4D6"), radius * 1.5, radius * 0.5, 0.12)
	glow(at + Vector3.new(0, 1, 0), Tex.MOD_GLOW, FIRE_DEEP, d * 0.9, d * 1.3, 0.4, 0.3)
	light(at + Vector3.new(0, 1, 0), FIRE_HOT, 5, radius * 3, 0.45)
	piece(
		"FX_FloorStar",
		flat,
		Vector3.new(d * 0.7, 1, d * 0.7),
		Vector3.new(d * 0.3, 1, d * 0.3),
		0.18,
		FIRE_HOT
	)
	-- The fire crown: an inner ring standing tall, an outer ring leaning out.
	local base = CFrame.new(floorAt)
	for i = 0, 11 do
		local outer = i % 2 == 1
		local yaw = (i / 12) * math.pi * 2 + math.random() * 0.3
		local out = if outer then radius * 0.42 else radius * 0.18
		local lean = if outer
			then math.rad(28 + math.random() * 12)
			else math.rad(8 + math.random() * 8)
		local anchor = base
			* CFrame.Angles(0, yaw, 0)
			* CFrame.new(0, 0, -out)
			* CFrame.Angles(-lean, 0, 0)
		local tall = radius * (if outer then 0.75 else 1.05) * (0.85 + math.random() * 0.3)
		local wide = if outer then 2.2 else 2.6
		piece(
			if i % 3 == 0
				then "Fire_TongueA"
				elseif i % 3 == 1 then "Fire_TongueB"
				else "Fire_TongueC",
			anchor,
			Vector3.new(1.2, 0.4, wide * 0.6),
			Vector3.new(1.2, tall, wide),
			0.42 + math.random() * 0.12,
			if outer then FIRE_DEEP else FIRE_HOT,
			0
		)
	end
	local wave = ModVfx.mesh({
		name = "Shockwave",
		cframe = CFrame.new(floorAt),
		from = Vector3.new(radius * 0.3, radius * 0.2, radius * 0.3),
		to = Vector3.new(radius, radius * 0.4, radius),
		color = Color3.fromHex("FFD9A0"),
		life = 0.3,
		alpha0 = 0.25,
	})
	if not wave then
		ModVfx.shell({
			shape = Enum.PartType.Block,
			cframe = CFrame.new(at),
			from = Vector3.one * radius * 0.4,
			to = Vector3.one * radius * 1.4,
			color = FIRE_HOT,
			life = 0.25,
			alpha0 = 0.4,
			material = Enum.Material.Neon,
		})
	end
	piece(
		"FX_Ring",
		flat,
		Vector3.new(d * 0.5, 1, d * 0.5),
		Vector3.new(d, 1, d),
		0.42,
		color,
		0.05
	)
	ModVfx.burst(at, FIRE_HOT, 30, "Sparkle")
end

function BlastFx.flashPop(at: Vector3, color: Color3, exposure: boolean, range: number)
	if exposure then
		-- No white-out: a cold star and a scan ring running out to the range.
		glow(at, Tex.MOD_SPARKLE, Color3.fromHex("F4FBFF"), 9, 3, 0.16, nil, true)
		glow(at, Tex.MOD_GLOW, color, 14, 2, 0.4, 0.3)
		light(at, color, 4, 24, 0.35)
		ModVfx.mesh({
			name = "ScanRing",
			cframe = CFrame.new(at),
			from = Vector3.new(1, 0.4, 1),
			to = Vector3.new(range, 0.4, range),
			color = color,
			life = 0.45,
			alpha0 = 0.1,
		})
		return
	end
	-- One glow 50 → 1 studs over ~0.5 s, a hard white star and a light.
	glow(at, Tex.MOD_GLOW, WHITE, 50, 1, 0.5, 0)
	glow(at, Tex.MOD_SPARKLE, WHITE, 12, 4, 0.14)
	light(at, WHITE, 14, 45, 0.5)
	ModVfx.burst(at, WHITE, 10, "Sparkle")
end

local function ease(u: number): number
	return 1 - (1 - u) ^ 3
end

function BlastFx.step()
	local now = ReworkVfx.now()
	for i = #billboards, 1, -1 do
		local b = billboards[i]
		local u = (now - b.born) / b.life
		if u >= 1 then
			table.remove(billboards, i)
			local part = b.gui.Parent
			if part then
				part:Destroy()
			end
			continue
		end
		local size = b.from + (b.to - b.from) * ease(u)
		b.gui.Size = UDim2.fromScale(size, size)
		b.image.ImageTransparency = b.alpha0 + (1 - b.alpha0) * (u * u)
		local accent = b.accentUntil
		b.image.ImageColor3 = if accent and now < accent then MAGENTA else b.color
	end
	for i = #lights, 1, -1 do
		local l = lights[i]
		local u = (now - l.born) / l.life
		if u >= 1 then
			table.remove(lights, i)
			l.part:Destroy()
			continue
		end
		l.light.Brightness = l.from * (1 - u) ^ 2
	end
	for i = #pieces, 1, -1 do
		local p = pieces[i]
		local u = (now - p.born) / p.life
		if u >= 1 then
			table.remove(pieces, i)
			ReworkVfx.give(p.name, p.part)
			continue
		end
		ReworkVfx.place(p.part, p.name, p.anchor, p.from:Lerp(p.to, ease(u)))
		p.part.Transparency = p.alpha0 + (1 - p.alpha0) * (u * u)
		local accent = p.accentUntil
		p.part.Color = if accent and now < accent then MAGENTA else p.color
	end
	local params: RaycastParams? = nil
	for i = #arcs, 1, -1 do
		local a = arcs[i]
		local u = (now - a.born) / a.life
		if u >= 1 then
			table.remove(arcs, i)
			for _, s in a.strokes do
				ReworkVfx.give("FX_Stroke", s)
			end
			continue
		end
		if now >= a.nextJump then
			a.nextJump = now + 1 / ARC_FPS
			params = params or worldParams()
			a.points = pathFor(a, params :: RaycastParams)
		end
		-- Thinner as it dies (no fade: a held stroke snaps off).
		placeArc(a, a.thick * (1 - u * 0.65))
		local accent = a.accentUntil
		local c = if accent and now < accent then MAGENTA else a.color
		for _, s in a.strokes do
			s.Color = c
		end
	end
	ReworkVfx.flush()
end

return BlastFx
