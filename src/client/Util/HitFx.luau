--!strict
-- What the body you hit does (owner, 2026-11-13; numbers in Config/HitFx):
--   * flash: a body hit turns the whole body solid white with a thin red rim;
--     a headshot or a kill turns it solid red (the owner's RIVALS references).
--     A Highlight on the character plus one on each skinned limb mesh, as those live
--     in Workspace.GGBodyLimbs outside the character (shared/MatchBody), so a
--     Highlight on the character alone only lit the head.
--   * slash (off by default, Config SLASH.enabled): a small, see-through
--     white-on-red streak riding on the body part that was hit.
--   * head flash: a headshot plays the owner's flare (impact flash, flame
--     shooting up, breaking apart, embers) as a fan of glowing flame copies
--     riding the head that snap in, rise, stretch and flick, with a white pop,
--     a shockwave ring, sparks and embers.
-- Only the shooter sees these (they run on the hit confirm). Everything is
-- pooled: Highlights live only while a body is flashing (the engine caps how
-- many draw), slashes and head-flash rigs are reused. Advanced by step(dt)
-- with the effects time (Studio VfxTimeScale).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Avatar = require(ReplicatedStorage.Shared.Config.Avatar)
local Config = require(ReplicatedStorage.Shared.Config.HitFx)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local ShotFxKit = require(script.Parent.ShotFxKit)

type FlashSpec = Config.FlashSpec
type SlashSpec = Config.SlashSpec

local HitFx = {}

local WHITE = Color3.new(1, 1, 1)

-- Load the hit textures up front, or the first headshot shows a blank
-- flash (seen in Studio, 2026-11-13).
task.spawn(function()
	game:GetService("ContentProvider")
		:PreloadAsync({ Config.TEXTURES.headFlare, Config.TEXTURES.wedge })
end)

local function ease(k: number): number
	local inv = 1 - math.clamp(k, 0, 1)
	return 1 - inv * inv
end

-- Flash ----------------------------------------------------------------------------

type Flash = { highlights: { Highlight }, spec: FlashSpec, t: number, killed: boolean }
local flashes: { [Model]: Flash } = {}
local liveHighlights = 0

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude

-- The body at `position` and its part nearest the point (the slash and the
-- head flash stick to it).
local function bodyAt(position: Vector3): (Model?, BasePart?)
	local own = Players.LocalPlayer.Character
	overlap.FilterDescendantsInstances = if own then { own } else {}
	local body: Model? = nil
	local best: BasePart? = nil
	local bestDist = math.huge
	for _, part in Workspace:GetPartBoundsInRadius(position, Config.FLASH.search, overlap) do
		local node: Instance? = part.Parent
		while node and node ~= Workspace do
			if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then
				break
			end
			node = node.Parent
		end
		if node and node ~= Workspace and (body == nil or node == body) then
			body = node :: Model
			local dist = (part.Position - position).Magnitude
			if dist < bestDist then
				best, bestDist = part, dist
			end
		end
	end
	return body, best
end

-- The character, then its skinned limb meshes (each R15 part's BodyLimb link).
local function adorneesOf(body: Model): { Instance }
	local list: { Instance } = { body }
	if not Config.FLASH.limbs then
		return list
	end
	for _, part in body:GetChildren() do
		local link = part:FindFirstChild(Avatar.LIMB_LINK)
		local made = if link and link:IsA("ObjectValue") then link.Value else nil
		-- (Limbs held inside the body, Util/LimbHold, are already under its
		-- own Highlight.)
		if made and made.Parent and not made:IsDescendantOf(body) then
			table.insert(list, made)
		end
	end
	return list
end

local function newHighlight(adornee: Instance): Highlight
	local h = Instance.new("Highlight")
	h.Name = "HitFlash"
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.FillTransparency = 1
	h.OutlineTransparency = 1
	h.Adornee = adornee
	h.Parent = if adornee:IsA("Model") then adornee else ShotFxKit.effectsFolder()
	return h
end

-- Highlights for `body` within the budget: the whole body, the model alone
-- when the limbs don't fit, none when nothing fits.
local function lightUp(body: Model): { Highlight }
	local list = adorneesOf(body)
	local room = Config.FLASH.maxHighlights - liveHighlights
	if #list > room then
		list = if room >= 1 then { body } else {}
	end
	local highlights = {}
	for _, adornee in list do
		table.insert(highlights, newHighlight(adornee))
	end
	liveHighlights += #highlights
	return highlights
end

local function clearHighlights(flash: Flash)
	for _, h in flash.highlights do
		h:Destroy()
	end
	liveHighlights -= #flash.highlights
	table.clear(flash.highlights)
end

local function dropFlash(body: Model, flash: Flash)
	clearHighlights(flash)
	flashes[body] = nil
end

-- A kill: DeathFxController hides the real body at once and shows a falling
-- copy (tagged, named after it), so the kill flash moves onto the copy.
local function deathCopyOf(body: Model): Model?
	local f = Config.FLASH
	local copy = Workspace:FindFirstChild(body.Name .. f.copySuffix)
	if copy and copy:IsA("Model") and copy:HasTag(f.copyTag) and not flashes[copy] then
		return copy
	end
	return nil
end

local function applyFlash(flash: Flash)
	local s = flash.spec
	local t = flash.t
	local color: Color3
	local fill: number
	if t < s.whiteTime then
		color = WHITE
		fill = s.whiteFill
	else
		local blendK = math.clamp((t - s.whiteTime) / s.blend, 0, 1)
		color = WHITE:Lerp(s.color, blendK)
		-- Solid until `hold`, then fades out by `time` (RIVALS: a solid white or
		-- red body, not a tint).
		local fadeK = math.clamp((t - s.hold) / (s.time - s.hold), 0, 1)
		local from = s.whiteFill + (s.fill - s.whiteFill) * blendK
		fill = from + (1 - from) * fadeK ^ 1.2
	end
	local outlineK = math.clamp((t - s.hold) / (s.outlineTime - s.hold), 0, 1)
	local outline = s.outlineFrom + (1 - s.outlineFrom) * ease(outlineK)
	for _, h in flash.highlights do
		h.FillColor = color
		h.FillTransparency = fill
		h.OutlineColor = s.outline
		h.OutlineTransparency = outline
	end
end

-- Slash ------------------------------------------------------------------------------

type Slash = {
	att: Attachment, -- in the world, or moved onto the hit part (follows the body)
	gui: BillboardGui,
	strokes: { { edge: Frame, core: Frame, angle: number } },
	spec: SlashSpec,
	t: number,
	active: boolean,
}
local slashes: { Slash } = {}
local nextSlash = 1
local clock = 0 -- effects time (step)
local lastSlash = -math.huge

local function taper(f: Frame)
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.18, 0),
		NumberSequenceKeypoint.new(0.75, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = f
end

local function stroke(gui: BillboardGui, color: Color3, z: number): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.ZIndex = z
	f.Parent = gui
	taper(f)
	return f
end

local function newSlash(): Slash
	local att = ShotFxKit.worldAttachment("HitSlash")
	local gui = Instance.new("BillboardGui")
	gui.Name = "HitSlash"
	gui.Adornee = att
	gui.AlwaysOnTop = false -- depth-tested, pulled toward the camera (never over the gun)
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.MaxDistance = 1000
	gui.ResetOnSpawn = false
	gui.Enabled = false
	-- In the effects folder, not on the attachment: the attachment rides on a
	-- body part and dies with it; the gui is reused.
	gui.Parent = ShotFxKit.effectsFolder()
	local strokes = {}
	for i = 1, 2 do
		strokes[i] = {
			edge = stroke(gui, Config.SLASH.edge, 1),
			core = stroke(gui, Config.SLASH.core, 2),
			angle = 0,
		}
	end
	return {
		att = att,
		gui = gui,
		strokes = strokes,
		spec = Config.SLASH.body,
		t = 0,
		active = false,
	}
end

-- `part`: the body part hit; the slash rides on it (owner, 2026-11-13: "they
-- don't follow the player"; Valorant's hit effects also move with the spot
-- on the body you hit). Its pull toward the camera is redone every frame.
local function playSlash(position: Vector3, spec: SlashSpec, part: BasePart?)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	if #slashes < Config.SLASH.pool then
		table.insert(slashes, newSlash())
	end
	local s = slashes[nextSlash]
	nextSlash = nextSlash % Config.SLASH.pool + 1
	if not s then
		return
	end
	if not pcall(function()
		s.att.Parent = if part then part else Workspace.Terrain
	end) then
		-- Its last body part was destroyed (and the attachment with it).
		s.att = ShotFxKit.worldAttachment("HitSlash")
		s.att.Parent = if part then part else Workspace.Terrain
		s.gui.Adornee = s.att
	end
	s.att.WorldPosition = position
	s.gui.Size = UDim2.new(spec.size, spec.minPx, spec.size, spec.minPx)
	local range = Config.SLASH.angle
	local angle = (range.Min + math.random() * (range.Max - range.Min))
		* (if math.random() < 0.5 then -1 else 1)
	for i, st in s.strokes do
		local on = i <= spec.count
		st.edge.Visible = on
		st.core.Visible = on
		-- A crossed pair: the second leans the other way.
		st.angle = if i == 1 then angle else -angle
	end
	for _, st in s.strokes do
		st.edge.BackgroundTransparency = spec.alpha
		st.core.BackgroundTransparency = spec.alpha
	end
	s.spec = spec
	s.t = 0
	s.active = true
	s.gui.Enabled = true
end

local function stepSlash(s: Slash, dt: number)
	s.t += dt
	local spec = s.spec
	if s.t >= spec.life or not s.att.Parent then
		s.active = false
		s.gui.Enabled = false
		if s.att.Parent and s.att.Parent ~= Workspace.Terrain then
			s.att.Parent = Workspace.Terrain -- off the body before it can be destroyed
		end
		return
	end
	local cam = Workspace.CurrentCamera
	if cam then
		local toCam = cam.CFrame.Position - s.att.WorldPosition
		s.gui.StudsOffsetWorldSpace = if toCam.Magnitude > 1e-3
			then toCam.Unit * Config.SLASH.towardCamera
			else Vector3.zero
	end
	-- Wipes in from one end, then thins out.
	local wipeK = ease(s.t / spec.wipe)
	local thin = if s.t < spec.wipe then 1 else 1 - (s.t - spec.wipe) / (spec.life - spec.wipe)
	for i, st in s.strokes do
		if i > spec.count then
			break
		end
		-- The second stroke of a pair lands a beat later.
		local k = if i == 1 then wipeK else ease((s.t - spec.wipe * 0.6) / spec.wipe)
		local rad = math.rad(st.angle)
		local dir = Vector2.new(math.cos(rad), math.sin(rad))
		local len = spec.length * k
		local centre = dir * (len - spec.length) / 2
		local pos = UDim2.fromScale(0.5 + centre.X, 0.5 + centre.Y)
		for _, f in { st.edge, st.core } do
			f.Rotation = st.angle
			f.Position = pos
		end
		st.edge.Size = UDim2.fromScale(len, spec.edge * thin)
		st.core.Size = UDim2.fromScale(len, spec.core * thin)
	end
end

-- Headshot flash ---------------------------------------------------------------------

-- A fan of flame copies riding the head (one billboard each, one image layer
-- per frame of the flare sheet, cross-faded by Config HEAD_FLASH.frames), plus
-- particles at the head for the hit frame (white pop, shockwave ring), sparks
-- and embers.
type FlameCopy = {
	gui: BillboardGui,
	layers: { ImageLabel },
	angle: number, -- degrees off upright (0: the centre flame)
	scale: number,
	delay: number, -- s
	mirrored: boolean,
}
type FlareRig = {
	att: Attachment, -- on the head part (follows it), or parked on Terrain
	copies: { FlameCopy },
	fxAtt: Attachment,
	pop: ParticleEmitter,
	ring: ParticleEmitter,
	sparks: ParticleEmitter,
	embers: ParticleEmitter,
	glow: ParticleEmitter,
	dark: ParticleEmitter,
	crown: ParticleEmitter,
	crownAtt: Attachment,
	head: Vector3, -- this hit's head point
	streak: ParticleEmitter,
	burstPending: boolean, -- the burst layers wait HEAD_FLASH.burstDelay
	more: number, -- this hit's count multiplier (a kill: more)
	t: number,
	scale: number,
	tilt: number, -- degrees
	flick: number, -- signed degrees over the life
	side: Vector3, -- the drift direction (camera right * side)
	active: boolean,
}
local rigs: { FlareRig } = {}
local nextRig = 1

-- Config.HEAD_FLASH.ramp as a ColorSequence (white, orange at 25 %, red).
local function rampSequence(): ColorSequence
	local r = Config.HEAD_FLASH.ramp
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, r[1]),
		ColorSequenceKeypoint.new(0.25, r[2]),
		ColorSequenceKeypoint.new(1, r[3]),
	})
end

-- A flat time/value curve with every value times `s`.
local function scaled(points: { number }, s: number): NumberSequence
	local out = table.clone(points)
	for i = 2, #out, 2 do
		out[i] *= s
	end
	return ShotFxKit.curve(out)
end

local function newCopy(att: Attachment): FlameCopy
	local f = Config.HEAD_FLASH
	local gui = Instance.new("BillboardGui")
	gui.Name = "HeadFlash"
	gui.Adornee = att
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Brightness = f.brightness
	gui.MaxDistance = 1000
	gui.ResetOnSpawn = false
	gui.ClipsDescendants = false
	gui.Enabled = false
	gui.Parent = ShotFxKit.effectsFolder()
	local layers = {}
	for i = 1, #f.frames do
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.fromScale(1, 1)
		img.Image = Config.TEXTURES.headFlare
		img.ImageTransparency = 1
		img.ZIndex = i
		img.Parent = gui
		layers[i] = img
	end
	return { gui = gui, layers = layers, angle = 0, scale = 1, delay = 0, mirrored = false }
end

local function newRig(): FlareRig
	local f = Config.HEAD_FLASH
	local att = ShotFxKit.worldAttachment("HeadFlash")
	local copies = {}
	for i = 1, math.max(1, f.fan.count) do
		copies[i] = newCopy(att)
	end
	local fxAtt = ShotFxKit.worldAttachment("HeadFlashFx")
	local pop = ShotFxKit.emitter(fxAtt, VFX.GLOW, f.pop.color)
	ShotFxKit.fire(pop)
	pop.Lifetime = NumberRange.new(f.pop.lifetime)
	pop.Size = ShotFxKit.curve(f.pop.size)
	pop.Transparency = ShotFxKit.curve(f.pop.transparency)
	pop.ZOffset = f.pop.zOffset
	local ring = ShotFxKit.emitter(fxAtt, VFX.MOD_RING, f.ring.color)
	ShotFxKit.fire(ring)
	ring.Rotation = NumberRange.new(0)
	ring.Lifetime = NumberRange.new(f.ring.lifetime)
	ring.Size = ShotFxKit.curve(f.ring.size)
	ring.Transparency = ShotFxKit.curve(f.ring.transparency)
	local sparks = ShotFxKit.sparkEmitter(fxAtt, f.sparks.size)
	sparks.Color = rampSequence()
	sparks.Squash = ShotFxKit.curve({ 0, f.sparks.squash, 1, f.sparks.squash })
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Speed = f.sparks.speed
	sparks.SpreadAngle = Vector2.new(f.sparks.spread, f.sparks.spread)
	sparks.Lifetime = f.sparks.lifetime
	sparks.Drag = f.sparks.drag
	sparks.Acceleration = Vector3.new(0, -f.sparks.gravity, 0)
	local embers = ShotFxKit.emitter(fxAtt, VFX.MOLLY_EMBER, f.embers.color)
	ShotFxKit.fire(embers)
	embers.Brightness = 2
	embers.EmissionDirection = Enum.NormalId.Top
	embers.Speed = f.embers.speed
	embers.SpreadAngle = Vector2.new(f.embers.spread, f.embers.spread)
	embers.Lifetime = f.embers.lifetime
	embers.Drag = f.embers.drag
	embers.Acceleration = Vector3.new(0, -f.embers.gravity, 0)
	embers.Size = ShotFxKit.curve(f.embers.size)
	-- RIVALS' layer recipe (Config HEAD_FLASH.glow / dark / streak).
	local glow = ShotFxKit.emitter(fxAtt, VFX.MOD_GLOW, Color3.new(1, 1, 1))
	ShotFxKit.fire(glow)
	glow.Color = rampSequence()
	glow.Rotation = NumberRange.new(0)
	glow.Lifetime = NumberRange.new(f.glow.lifetime)
	glow.Transparency = ShotFxKit.curve(f.glow.transparency)
	glow.ZOffset = f.glow.zOffset
	local dark = ShotFxKit.emitter(fxAtt, VFX.MOD_GLOW, Color3.new(0, 0, 0))
	dark.LightInfluence = 0
	-- Negative LightEmission darkens what's behind it (contrast for the glow).
	dark.LightEmission = f.dark.lightEmission
	dark.Rotation = NumberRange.new(0)
	dark.Lifetime = NumberRange.new(f.dark.lifetime)
	dark.Transparency = ShotFxKit.curve(f.dark.transparency)
	local streak = ShotFxKit.emitter(fxAtt, VFX.MOD_GLOW, Color3.new(1, 1, 1))
	ShotFxKit.fire(streak)
	streak.Color = rampSequence()
	streak.Rotation = NumberRange.new(0)
	streak.EmissionDirection = Enum.NormalId.Top
	streak.Lifetime = NumberRange.new(f.streak.lifetime)
	streak.Drag = f.streak.drag
	streak.Squash = ShotFxKit.curve(f.streak.squash)
	streak.Transparency = ShotFxKit.curve(f.streak.transparency)
	streak.ZOffset = f.streak.zOffset
	-- The crown burst (Config HEAD_FLASH.crown): a one-shot 4x4 flipbook,
	-- upright on screen.
	local crownAtt = ShotFxKit.worldAttachment("HeadCrown")
	local crown = ShotFxKit.emitter(crownAtt, Config.TEXTURES.headCrown, Color3.new(1, 1, 1))
	ShotFxKit.fire(crown)
	crown.Color = rampSequence()
	crown.Brightness = f.crown.brightness
	crown.Orientation = Enum.ParticleOrientation.FacingCamera
	crown.Rotation = NumberRange.new(0)
	crown.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	crown.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	crown.Lifetime = NumberRange.new(f.crown.lifetime)
	crown.Transparency = ShotFxKit.curve(f.crown.transparency)
	crown.ZOffset = f.crown.zOffset
	return {
		att = att,
		copies = copies,
		fxAtt = fxAtt,
		pop = pop,
		ring = ring,
		sparks = sparks,
		embers = embers,
		glow = glow,
		dark = dark,
		crown = crown,
		crownAtt = crownAtt,
		head = Vector3.zero,
		streak = streak,
		burstPending = false,
		more = 1,
		t = 0,
		scale = 1,
		tilt = 0,
		flick = 0,
		side = Vector3.zero,
		active = false,
	}
end

-- Linear value of a flat time/value curve at k (0..1).
local function sample(points: { number }, k: number): number
	for i = 3, #points, 2 do
		if k <= points[i] then
			local t0, v0, t1, v1 = points[i - 2], points[i - 1], points[i], points[i + 1]
			return v0 + (v1 - v0) * (if t1 > t0 then (k - t0) / (t1 - t0) else 1)
		end
	end
	return points[#points]
end

-- One flame copy at its own time `t` (the rig's time minus its delay).
local function stepCopy(rig: FlareRig, c: FlameCopy, t: number)
	local f = Config.HEAD_FLASH
	if not f.flare or t < 0 or t >= f.life then
		c.gui.Enabled = false
		return
	end
	c.gui.Enabled = true
	local k = t / f.life
	-- Snap and bounce (width), and a stretch up while the flame shoots up.
	local width = sample(f.size, k) * rig.scale * c.scale
	local flame = f.frames[2]
	local flameK = math.clamp((t - flame.start) / (f.frames[3].stop - flame.start), 0, 1)
	local height = width * (1 + f.stretch * math.sin(math.pi * flameK))
	c.gui.Size = UDim2.new(width, 0, height, 0)
	-- It travels: rises off the head and drifts to the flick's side.
	local travel = ease(k)
	c.gui.StudsOffsetWorldSpace = Vector3.yAxis
			* (f.baseHeight + (f.anchorY - 0.5) * height + f.rise * travel * rig.scale * c.scale)
		+ rig.side * travel * rig.scale
	-- Turned about the flame's base, not the image's centre: a GUI turns about
	-- its centre, so the layers are shifted to put the base back (screen y is
	-- down; turning by r moves the base, (0, a*h), to (-a*h*sin r, a*h*cos r)).
	local rotation = rig.tilt + c.angle + rig.flick * travel
	local r = math.rad(rotation)
	local a = f.anchorY - 0.5
	local shift =
		UDim2.fromScale(0.5 + a * height * math.sin(r) / width, 0.5 + a * (1 - math.cos(r)))
	for i, img in c.layers do
		local w = f.frames[i]
		-- Fades in from `start` to `peak`, holds 40% of the way to `stop`, then
		-- fades out: neighbouring frames overlap, so they cross-fade.
		local vis = 0
		if t >= w.start and t <= w.stop then
			if t < w.peak then
				vis = (t - w.start) / math.max(w.peak - w.start, 1e-3)
			else
				local fk = (t - w.peak) / math.max(w.stop - w.peak, 1e-3)
				vis = if fk < 0.4 then 1 else 1 - (fk - 0.4) / 0.6
			end
		end
		img.ImageTransparency = 1 - (1 - f.alpha) * math.clamp(vis, 0, 1)
		img.Rotation = rotation
		img.Position = shift
	end
end

-- The burst layers, `burstDelay` after the hit frame (RIVALS' EmitDelay).
local function emitBurst(rig: FlareRig)
	local f = Config.HEAD_FLASH
	rig.burstPending = false
	local s = rig.scale
	rig.glow.Size = scaled(f.glow.size, s)
	rig.glow:Emit(1)
	if f.dark.enabled then
		rig.dark.Size = scaled(f.dark.size, s)
		rig.dark:Emit(1)
	end
	-- The crown, its base on top of the head.
	local cr = f.crown
	if cr.count > 0 then
		local cs = s * cr.scale
		rig.crown.Size = scaled(cr.size, cs)
		local peak = cr.size[#cr.size] * cs
		rig.crownAtt.WorldPosition = rig.head + Vector3.yAxis * (f.baseHeight + cr.baseShare * peak)
		rig.crown:Emit(cr.count)
	end
	rig.streak.Size = scaled(f.streak.size, s)
	rig.streak.Speed = NumberRange.new(f.streak.speed * s)
	rig.streak:Emit(1)
	rig.sparks.Size = scaled({ 0, 0, 0.1, f.sparks.size, 1, 0 }, s)
	rig.sparks.Speed =
		NumberRange.new(f.sparks.speed.Min * math.sqrt(s), f.sparks.speed.Max * math.sqrt(s))
	rig.sparks:Emit(math.round(f.sparks.count * rig.more))
	rig.embers:Emit(math.round(f.embers.count * rig.more))
end

local function stepFlare(rig: FlareRig, dt: number)
	local f = Config.HEAD_FLASH
	rig.t += dt
	if rig.burstPending and rig.t >= f.burstDelay then
		emitBurst(rig)
	end
	local last = 0
	for _, c in rig.copies do
		last = math.max(last, c.delay)
	end
	if rig.t >= f.life + last or not rig.att.Parent then
		rig.active = false
		for _, c in rig.copies do
			c.gui.Enabled = false
		end
		if rig.att.Parent and rig.att.Parent ~= Workspace.Terrain then
			rig.att.Parent = Workspace.Terrain -- off the head before it can be destroyed
		end
		return
	end
	for _, c in rig.copies do
		stepCopy(rig, c, rig.t - c.delay)
	end
end

-- Frame `i` of the sheet (left to right, top row first), mirrored or not.
-- ImageRect is in image pixels (the sheet is 1024 square); a negative width
-- flips the frame.
local function frameRect(img: ImageLabel, i: number, mirrored: boolean)
	local f = Config.HEAD_FLASH
	local cell = 1024 / f.grid
	local col, row = (i - 1) % f.grid, (i - 1) // f.grid
	if mirrored then
		img.ImageRectOffset = Vector2.new((col + 1) * cell, row * cell)
		img.ImageRectSize = Vector2.new(-cell, cell)
	else
		img.ImageRectOffset = Vector2.new(col * cell, row * cell)
		img.ImageRectSize = Vector2.new(cell, cell)
	end
end

local function headFlash(headPart: BasePart?, head: Vector3, killed: boolean)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local f = Config.HEAD_FLASH
	if #rigs < f.rigs then
		table.insert(rigs, newRig())
	end
	local rig = rigs[nextRig]
	nextRig = nextRig % f.rigs + 1
	if not rig then
		return
	end
	-- Ride the head (it follows the target), else stay at the point.
	if
		not pcall(function()
			rig.att.Parent = if headPart then headPart else Workspace.Terrain
		end)
	then
		rig.att = ShotFxKit.worldAttachment("HeadFlash")
		rig.att.Parent = if headPart then headPart else Workspace.Terrain
		for _, c in rig.copies do
			c.gui.Adornee = rig.att
		end
	end
	rig.att.WorldPosition = head
	-- Size: by distance (capped up close), a head kill, and a little random.
	local dist = (head - cam.CFrame.Position).Magnitude
	local reach = math.clamp(dist / f.range.from, f.range.near, f.range.max)
	local jitter = 1 + (math.random() * 2 - 1) * f.sizeJitter
	rig.scale = (if killed then f.kill else 1) * reach * jitter
	-- Variety: lean, flick side, mirror.
	local sideSign = if math.random() < 0.5 then -1 else 1
	rig.tilt = (math.random() * 2 - 1) * f.tilt
	rig.flick = sideSign * (f.flick.Min + math.random() * (f.flick.Max - f.flick.Min))
	rig.side = cam.CFrame.RightVector * (-sideSign * f.drift)
	-- The fan: the centre flame (randomly mirrored) and side copies alternating
	-- left and right, each mirrored to lean outward.
	local fan = f.fan
	for n, c in rig.copies do
		if n == 1 then
			c.angle, c.scale, c.delay = 0, 1, f.burstDelay
			c.mirrored = f.mirror and math.random() < 0.5
		else
			local sideOf = if n % 2 == 0 then -1 else 1
			local step = n // 2
			c.angle = sideOf * step * (fan.angle + (math.random() * 2 - 1) * fan.angleJitter)
			c.scale = fan.sideScale ^ step
			c.delay = f.burstDelay + fan.delay * step
			c.mirrored = sideOf < 0
		end
		for i, img in c.layers do
			frameRect(img, i, c.mirrored)
		end
	end
	rig.t = 0
	rig.active = true
	stepFlare(rig, 0)
	-- The hit frame and the bits that fly: at the top of the head, sparks and
	-- embers aimed away from the shooter and up.
	local shot = if dist > 1e-3 then (head - cam.CFrame.Position).Unit else cam.CFrame.LookVector
	local out = (shot * f.away + Vector3.yAxis).Unit
	local right = out:Cross(Vector3.zAxis)
	if right.Magnitude < 1e-3 then
		right = out:Cross(Vector3.xAxis)
	end
	rig.fxAtt.WorldCFrame = CFrame.fromMatrix(head + Vector3.yAxis * f.baseHeight, right.Unit, out)
	rig.more = if killed then f.kill else 1
	-- The hit frame now; the rest of the burst a beat later (stepFlare).
	rig.head = head
	rig.pop:Emit(f.pop.count)
	if f.ring.enabled then
		rig.ring:Emit(1)
	end
	rig.burstPending = true
	if f.burstDelay <= 0 then
		emitBurst(rig)
	end
end

-- Public -----------------------------------------------------------------------------

-- The body at `position` was hit: flash it, slash it (at most one every
-- SLASH.minGap; a kill always), and on a headshot a flash pops from the head.
function HitFx.hit(position: Vector3, head: boolean, killed: boolean)
	local body, part = bodyAt(position)
	if Config.SLASH.enabled and (killed or clock - lastSlash >= Config.SLASH.minGap) then
		lastSlash = clock
		local slashSpec = if killed
			then Config.SLASH.kill
			elseif head then Config.SLASH.head
			else Config.SLASH.body
		playSlash(position, slashSpec, part)
	end
	if head then
		-- Centred on the head (the burst sits behind it), else on the hit point.
		local found = body and body:FindFirstChild("Head")
		local headPart = if found and found:IsA("BasePart") then found else nil
		headFlash(headPart, if headPart then headPart.Position else position, killed)
	end
	if not body then
		return
	end
	local spec = if killed
		then Config.FLASH.kill
		elseif head then Config.FLASH.head
		else Config.FLASH.body
	local flash = flashes[body]
	if not flash then
		local made: Flash = { highlights = lightUp(body), spec = spec, t = 0, killed = killed }
		flash = made
		flashes[body] = made
	end
	local active = flash :: Flash
	active.spec = spec
	active.t = 0
	active.killed = killed
	applyFlash(active)
end

-- How many flash Highlights are alive (Studio checks).
function HitFx.liveHighlights(): number
	return liveHighlights
end

local moves: { { from: Model, to: Model } } = {}

function HitFx.step(dt: number)
	clock += dt
	for body, flash in flashes do
		flash.t += dt
		local copy = if flash.killed and flash.t < Config.FLASH.copyWait
			then deathCopyOf(body)
			else nil
		if copy then
			table.insert(moves, { from = body, to = copy })
		elseif flash.t >= flash.spec.time or not body.Parent then
			dropFlash(body, flash)
		else
			applyFlash(flash)
		end
	end
	-- Kill flashes onto the death copies (after the loop: no new keys mid-walk).
	for _, move in moves do
		local flash = flashes[move.from]
		if flash then
			clearHighlights(flash)
			flashes[move.from] = nil
			flash.highlights = lightUp(move.to)
			flash.killed = false
			flashes[move.to] = flash
			applyFlash(flash)
		end
	end
	table.clear(moves)
	for _, s in slashes do
		if s.active then
			stepSlash(s, dt)
		end
	end
	for _, rig in rigs do
		if rig.active then
			stepFlare(rig, dt)
		end
	end
end

return HitFx
