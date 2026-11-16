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

-- An arc's new path: from the centre a random way out (biased off the
-- surface by `normal`), stopped by the first thing it meets, broken into
-- ARC_SEGMENTS jagged steps.
local function arcPath(
	center: Vector3,
	normal: Vector3,
	reach: number,
	params: RaycastParams
): { Vector3 }
	local dir = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1)
	if dir.Magnitude < 1e-3 then
		dir = normal
	end
	dir = (dir.Unit + normal * 0.25).Unit -- mostly along the surface: arcs crawl out
	local len = reach * (0.55 + 0.45 * math.random())
	local hit = Workspace:Raycast(center, dir * len, params)
	local finish = if hit then hit.Position else center + dir * len
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

local function addArcs(
	center: Vector3,
	normal: Vector3,
	reach: number,
	color: Color3,
	count: number,
	life: number,
	accent: boolean
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
			center = center,
			normal = normal,
			reach = reach,
			born = now,
			life = life * (0.7 + 0.3 * math.random()),
			nextJump = now + 1 / ARC_FPS,
			accentUntil = if accent then now + ACCENT_TIME else nil,
			color = color,
			points = arcPath(center, normal, reach, params),
		}
		placeArc(a, ARC_THICK)
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

function BlastFx.shock(at: Vector3, normal: Vector3, radius: number, color: Color3, static: boolean)
	local flat = surfaceFrame(at, normal)
	local spin = flat * CFrame.Angles(0, math.random() * math.pi, 0)
	-- Beat 1: a hard white star on the surface, a glow under it, the light.
	piece(
		"FX_FloorStar",
		spin,
		Vector3.new(radius * 1.1, 1, radius * 1.1),
		Vector3.new(radius * 0.5, 1, radius * 0.5),
		0.12,
		WHITE
	)
	glow(at + normal * 0.5, Tex.MOD_SPARKLE, WHITE, radius * 1.2, radius * 0.4, 0.1)
	glow(at + normal * 0.5, Tex.MOD_GLOW, ARC_GLOW, radius * 1.6, radius * 2.2, 0.25, 0.45)
	light(at + normal * 0.5, ARC_COLOR, 6, radius * 3, 0.25)
	-- Beat 2: the arcs snap out to the edge on held frames.
	addArcs(
		at + normal * 0.15,
		normal,
		radius,
		if static then STATIC_ARC else ARC_COLOR,
		if static then 7 else 6,
		0.24,
		static
	)
	-- Beat 3: the gameplay line (team colour at the blast's edge) and sparks.
	piece(
		"FX_Ring",
		flat,
		Vector3.new(radius * 0.8, 1, radius * 0.8),
		Vector3.new(radius * 2, 1, radius * 2),
		0.3,
		color,
		0.1
	)
	ModVfx.quad({
		texture = if static then Tex.MOD_RING_DASHED else Tex.MOD_RING,
		cframe = flat,
		from = radius * 1.4,
		to = radius * 2.05,
		color = color,
		life = if static then 0.5 else 0.35,
		alpha0 = 0.15,
	})
	ModVfx.burst(at + normal * 0.2, ARC_GLOW, 16, "Sparkle")
end

function BlastFx.roller(at: Vector3, radius: number, color: Color3)
	local floorAt = at - Vector3.new(0, 0.5, 0)
	local flat = surfaceFrame(floorAt, Vector3.yAxis) * CFrame.Angles(0, math.random() * math.pi, 0)
	local hot = Color3.fromHex("FFE2B8")
	glow(at, Tex.MOD_SPARKLE, Color3.fromHex("FFF4E0"), radius * 1.6, radius * 0.6, 0.14)
	glow(at, Tex.MOD_GLOW, Color3.fromHex("FFB060"), radius * 1.4, radius * 2.2, 0.32, 0.25)
	light(at, Color3.fromHex("FFD9A8"), 8, radius * 4, 0.35)
	piece(
		"FX_FloorStar",
		flat,
		Vector3.new(radius * 1.4, 1, radius * 1.4),
		Vector3.new(radius * 0.6, 1, radius * 0.6),
		0.16,
		hot
	)
	local wave = ModVfx.mesh({
		name = "Shockwave",
		cframe = CFrame.new(floorAt),
		from = Vector3.new(radius * 0.3, radius * 0.25, radius * 0.3),
		to = Vector3.new(radius, radius * 0.5, radius),
		color = Color3.fromHex("FFE7C8"),
		life = 0.3,
		alpha0 = 0.2,
	})
	if not wave then
		ModVfx.shell({
			shape = Enum.PartType.Block,
			cframe = CFrame.new(at),
			from = Vector3.one * radius * 0.4,
			to = Vector3.one * radius * 1.4,
			color = Color3.fromHex("FFE7C8"),
			life = 0.25,
			alpha0 = 0.4,
			material = Enum.Material.Neon,
		})
	end
	piece(
		"FX_Ring",
		flat,
		Vector3.new(radius, 1, radius),
		Vector3.new(radius * 2, 1, radius * 2),
		0.38,
		color,
		0.05
	)
	ModVfx.burst(at, Color3.fromHex("FFB060"), 26, "Sparkle")
	addArcs(at, Vector3.yAxis, radius * 0.7, hot, 3, 0.12, false)
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
			a.points = arcPath(a.center, a.normal, a.reach, params :: RaycastParams)
		end
		-- Thinner as it dies (no fade: a held stroke snaps off).
		placeArc(a, ARC_THICK * (1 - u * 0.65))
		local accent = a.accentUntil
		local c = if accent and now < accent then MAGENTA else a.color
		for _, s in a.strokes do
			s.Color = c
		end
	end
	ReworkVfx.flush()
end

return BlastFx
