--!strict
-- Wind strokes on your own screen: the Dash, the Updraft, a slide, and the
-- Ghost / cloak edge cue (vault/02 Art/Ability VFX Direction.md → Wind).
--
-- One image (VfxTextures.WIND_STROKE: a hard-edged wedge pointed at both ends,
-- head on the left) on a handful of ImageLabels: each stroke is the off-white
-- shape over a slightly bigger dark copy of itself (its edge, so it reads on
-- a bright sky). A stroke snaps in on a screen edge, moves a short way along
-- the move on held frames and goes by closing from the tail: no blur, no
-- fade, and never inside the aim area (the middle of the screen; a stroke
-- that would reach it is cut short when it starts). Every number is in
-- Config/Mods WIND_FEEL.
--
-- Built once and reused; ModFeelController steps it. Studio only: the
-- Workspace attribute VfxTimeScale slows or freezes the strokes (captures).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Mods)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local WindStrokes = {}

local WIND = Config.WIND_FEEL
local DASH = WIND.dash
local UPDRAFT = WIND.updraft
local GHOST = WIND.ghost

local player = Players.LocalPlayer
local studio = RunService:IsStudio()

-- One drawn stroke: the shape and the dark edge under it.
type Mark = { label: ImageLabel, ink: ImageLabel }

type Stroke = {
	mark: Mark,
	on: boolean,
	start: number, -- effects clock
	life: number,
	origin: Vector2, -- where the head ends its onset (pixels)
	dir: Vector2, -- the way it points and moves (screen, y down)
	length: number,
	thick: number,
	travel: number,
}

local gui: ScreenGui? = nil
local dashPool: { Stroke } = {}
local updraftPool: { Stroke } = {}
local ghostMarks: { { Mark } } = {} -- [side][stroke]
local cloakMarks: { Mark } = {} -- [side]
local ghostShown = false
local clock = 0 -- effects time (seconds)
local live = 0 -- strokes still playing

local function newLabel(parent: Instance, name: string, color: Color3, z: number): ImageLabel
	local label = Instance.new("ImageLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Image = VFX.WIND_STROKE
	label.ImageColor3 = color
	label.ZIndex = z
	label.Visible = false
	label.Parent = parent
	return label
end

local function newMark(parent: Instance, name: string, color: Color3): Mark
	return {
		ink = newLabel(parent, name .. "Ink", WIND.ink, 1),
		label = newLabel(parent, name, color, 2),
	}
end

-- `opacity` 0..1 of the stroke's own (`alpha`: its ImageTransparency at 1).
local function tint(mark: Mark, alpha: number, opacity: number)
	mark.label.ImageTransparency = 1 - (1 - alpha) * opacity
	mark.ink.ImageTransparency = 1 - (1 - WIND.inkAlpha) * opacity
end

-- Puts a stroke's centre at x, y (pixels), `length` by `thick`.
local function draw(mark: Mark, x: number, y: number, length: number, thick: number)
	local at = UDim2.fromOffset(x, y)
	mark.label.Position = at
	mark.label.Size = UDim2.fromOffset(length, thick)
	mark.label.Visible = true
	mark.ink.Position = at
	mark.ink.Size = UDim2.fromOffset(length * WIND.inkLength, thick * WIND.inkThick)
	mark.ink.Visible = true
end

local function turn(mark: Mark, rotation: number)
	mark.label.Rotation = rotation
	mark.ink.Rotation = rotation
end

local function hide(mark: Mark)
	mark.label.Visible = false
	mark.ink.Visible = false
end

local function newPool(parent: Instance, name: string, count: number): { Stroke }
	local pool: { Stroke } = {}
	for i = 1, count do
		pool[i] = {
			mark = newMark(parent, name .. i, WIND.color),
			on = false,
			start = 0,
			life = 0,
			origin = Vector2.zero,
			dir = Vector2.xAxis,
			length = 0,
			thick = 0,
			travel = 0,
		}
	end
	return pool
end

local function screen(): ScreenGui
	local g = gui
	if g then
		return g
	end
	local made = Instance.new("ScreenGui")
	made.Name = "WindStrokes"
	made.IgnoreGuiInset = true
	made.ScreenInsets = Enum.ScreenInsets.None -- full-bleed, under the notch too
	made.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	made.ClipToDeviceSafeArea = false
	made.ResetOnSpawn = false
	made.DisplayOrder = 3
	dashPool = newPool(made, "Dash", #DASH.strokes)
	updraftPool = newPool(made, "Updraft", #UPDRAFT.strokes)
	for side = 1, 2 do
		ghostMarks[side] = {}
		for j = 1, #GHOST.strokes do
			local mark = newMark(made, "Ghost" .. side .. j, GHOST.color)
			tint(mark, GHOST.alpha, 1)
			ghostMarks[side][j] = mark
		end
		local line = newMark(made, "Cloak" .. side, GHOST.color)
		tint(line, GHOST.cloak.alpha, 1)
		turn(line, 90)
		cloakMarks[side] = line
	end
	made.Parent = player:WaitForChild("PlayerGui")
	gui = made
	return made
end

-- How far along the ray p + d * t the box starts (0: p is inside it; nil:
-- the ray never gets there).
local function reach(p: Vector2, d: Vector2, lo: Vector2, hi: Vector2): number?
	local t0, t1 = 0, math.huge
	if math.abs(d.X) < 1e-6 then
		if p.X < lo.X or p.X > hi.X then
			return nil
		end
	else
		local a, b = (lo.X - p.X) / d.X, (hi.X - p.X) / d.X
		t0, t1 = math.max(t0, math.min(a, b)), math.min(t1, math.max(a, b))
	end
	if math.abs(d.Y) < 1e-6 then
		if p.Y < lo.Y or p.Y > hi.Y then
			return nil
		end
	else
		local a, b = (lo.Y - p.Y) / d.Y, (hi.Y - p.Y) / d.Y
		t0, t1 = math.max(t0, math.min(a, b)), math.min(t1, math.max(a, b))
	end
	return if t0 <= t1 then t0 else nil
end

local function stop(stroke: Stroke)
	if stroke.on then
		stroke.on = false
		live -= 1
	end
	hide(stroke.mark)
end

-- Starts one stroke: head at `origin` pointing along `dir` (unit), lengths in
-- pixels, `opacity` 0..1. Its length and its travel are cut so that no part
-- of it (its dark edge included) ever gets inside the aim area.
local function launch(
	stroke: Stroke,
	view: Vector2,
	origin: Vector2,
	dir: Vector2,
	length: number,
	thick: number,
	travel: number,
	start: number,
	life: number,
	opacity: number
)
	local pad = WIND.clearPad * view.Y + thick * WIND.inkThick / 2
	local half = view * (WIND.clear / 2) + Vector2.new(pad, pad)
	local lo, hi = view / 2 - half, view / 2 + half
	local over = (WIND.inkLength - 1) / 2 -- the edge reaches this share past each tip
	local behind = reach(origin, -dir, lo, hi)
	if behind then
		length = math.min(length, behind / (1 + over))
	end
	local ahead = reach(origin, dir, lo, hi)
	if ahead then
		travel = math.clamp(ahead - length * over, 0, travel)
	end
	if length < thick * 3 or life <= 0 then
		stop(stroke) -- no room for it here (a narrow window)
		return
	end
	if not stroke.on then
		stroke.on = true
		live += 1
	end
	stroke.start, stroke.life = start, life
	stroke.origin, stroke.dir = origin, dir
	stroke.length, stroke.thick, stroke.travel = length, thick, travel
	-- The image's head is on its left: turn that to face `dir`.
	turn(stroke.mark, math.deg(math.atan2(dir.Y, dir.X)) + 180)
	tint(stroke.mark, WIND.alpha, opacity)
	hide(stroke.mark) -- shown by the next step (it may start later)
end

local function place(stroke: Stroke)
	local t = clock - stroke.start
	if t < 0 then
		return
	end
	if t >= stroke.life then
		stop(stroke)
		return
	end
	-- Held frames: the pose only changes fps times a second.
	local step = 1 / WIND.fps
	local k = math.floor(t / step) * step / stroke.life
	local closing = if k <= WIND.hold then 1 else 1 - (k - WIND.hold) / (1 - WIND.hold)
	-- The onset is the one smooth part: the head shoots out from the tail.
	local out = if t < WIND.onset
		then WIND.onsetLength + (1 - WIND.onsetLength) * (t / WIND.onset)
		else 1
	local length = stroke.length * closing * out
	local head = stroke.origin
		+ stroke.dir * (stroke.travel * (1 - (1 - k) ^ 2) - stroke.length * (1 - out))
	local centre = head - stroke.dir * (length / 2)
	draw(
		stroke.mark,
		centre.X,
		centre.Y,
		length,
		stroke.thick * (WIND.thin + (1 - WIND.thin) * closing)
	)
end

-- The Dash's strokes. `dir`: the dash in camera space. `strength` 0..1: 1 is
-- a dash; less is a slide (fewer, shorter, fainter strokes).
function WindStrokes.dash(dir: Vector3, strength: number)
	local view = screen().AbsoluteSize
	local side, ahead = dir.X, -dir.Z
	if math.abs(side) + math.abs(ahead) < 1e-3 then
		side, ahead = 0, 1
	end
	-- Forward or back: along the line to the centre. Sideways: flat.
	local radial = math.abs(ahead) >= math.abs(side)
	local light = strength < 1
	local share = if light then DASH.light + (1 - DASH.light) * math.clamp(strength, 0, 1) else 1
	local mid = view / 2
	for i, spec in DASH.strokes do
		local stroke = dashPool[i]
		if (spec.ahead and not radial) or (light and not spec.slide) then
			stop(stroke)
			continue
		end
		local origin = Vector2.new(spec.x * view.X, spec.y * view.Y)
		local d: Vector2
		if radial then
			local inward = mid - origin
			if inward.Magnitude < 1 then
				stop(stroke)
				continue
			end
			d = inward.Unit * math.sign(ahead)
		else
			d = Vector2.new(math.sign(side), 0)
		end
		local size = WIND.sizes[spec.size]
		launch(
			stroke,
			view,
			origin,
			d,
			size[1] * view.Y * share,
			size[2] * view.Y,
			DASH.travel * view.Y * share,
			clock,
			DASH.time,
			share
		)
	end
end

-- The Updraft's strokes: straight up, in waves over the `rise` (seconds from
-- the launch to the peak), all gone before the peak.
function WindStrokes.updraft(rise: number)
	local view = screen().AbsoluteSize
	local up = Vector2.new(0, -1)
	for i, spec in UPDRAFT.strokes do
		local at = (spec.at or 0) * rise
		local size = WIND.sizes[spec.size]
		launch(
			updraftPool[i],
			view,
			Vector2.new(spec.x * view.X, spec.y * view.Y),
			up,
			size[1] * view.Y,
			size[2] * view.Y,
			UPDRAFT.travel * view.Y,
			clock + at,
			math.min(UPDRAFT.life, UPDRAFT.endBy * rise - at),
			1
		)
	end
end

-- The Ghost cue, every frame (UpgradeFx/DashGhost): `dodge` while the dodge
-- window is open (thin strokes jumping along both side edges), `cloak` 0..1
-- how far the cloak is on (one thin line down each side).
function WindStrokes.ghost(dodge: boolean, cloak: number)
	if not dodge and cloak <= 0 then
		if ghostShown then
			ghostShown = false
			for side = 1, 2 do
				for _, mark in ghostMarks[side] do
					hide(mark)
				end
				hide(cloakMarks[side])
			end
		end
		return
	end
	local view = screen().AbsoluteSize
	ghostShown = true
	local frame = math.floor(clock * GHOST.fps)
	local line = GHOST.cloak
	local lineFrame = math.floor(clock * line.fps)
	for side = 1, 2 do
		local inset = GHOST.inset * view.X
		local x = if side == 1 then inset else view.X - inset
		for j, spec in GHOST.strokes do
			local mark = ghostMarks[side][j]
			-- Each stroke on its own beat, the two sides out of step.
			local n = frame + j * 2 + side * 3
			if not dodge or n % GHOST.blink == 0 then
				hide(mark)
				continue
			end
			local y = spec.y + GHOST.jump[n % #GHOST.jump + 1]
			turn(mark, if (n % 2 == 0) == (side == 1) then 90 else 270) -- head up / down
			draw(
				mark,
				x,
				(if side == 1 then y else 1 - y) * view.Y,
				spec.length * view.Y,
				spec.thick * view.Y
			)
		end
		local mark = cloakMarks[side]
		if cloak > 0 then
			local nudge = if (lineFrame + side) % 2 == 0 then line.jump else -line.jump
			draw(
				mark,
				x - inset / 2,
				(0.5 + nudge) * view.Y,
				line.length * view.Y * cloak,
				line.thick * view.Y
			)
		else
			hide(mark)
		end
	end
end

-- Every frame (ModFeelController).
function WindStrokes.step(dt: number)
	if studio then
		local scale = StateValues.get(Workspace, "VfxTimeScale")
		if typeof(scale) == "number" then
			dt *= math.clamp(scale, 0, 1)
		end
	end
	clock += dt
	if live <= 0 then
		return
	end
	for _, stroke in dashPool do
		if stroke.on then
			place(stroke)
		end
	end
	for _, stroke in updraftPool do
		if stroke.on then
			place(stroke)
		end
	end
end

return WindStrokes
