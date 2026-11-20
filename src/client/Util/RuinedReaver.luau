--!strict
-- Ruined Reaver first-person choreography on the existing Knife slot.
local StateValues = require(game:GetService("ReplicatedStorage").Shared.StateValues)

local Shared = game:GetService("ReplicatedStorage").Shared
local Ease = require(Shared.Util.Ease)
local Vfx = require(Shared.Config.VfxTextures)
local UiMotion = require(Shared.UiMotion)
local LocalHide = require(script.Parent.LocalHide)
local Audio = require(script.Parent.Parent.Controllers.AudioController)
local ShadowAudio = require(Shared.Config.ShadowMistAudio)

type Key = { at: number, offset: CFrame, spread: number }
type Segment = { a: Key, b: Key, exit: CFrame, entry: CFrame }
type Track = { length: number, contact: number?, keys: { Key }, segments: { Segment }? }
type Shard = { motor: Motor6D, axis: Vector3, attached: { BasePart } }
export type State = {
	name: string,
	time: number,
	clock: number,
	pose: CFrame,
	origin: CFrame,
	spread: number,
	originSpread: number,
	scale: number,
	shards: { Shard },
	trail: Trail,
	cutStrokes: { Beam },
	cutStart: Attachment,
	cutEnd: Attachment,
	hilt: { BasePart },
	core: { BasePart },
	mist: ParticleEmitter,
	bladeMist: { ParticleEmitter },
	links: { Beam },
	veils: { Beam },
	support: number,
	bladeLight: PointLight,
	sparks: ParticleEmitter,
	flare: ParticleEmitter,
	current: Attachment,
	orbits: { Beam },
	orbitNodes: { Attachment },
	inspectStart: Audio.Handle?,
	inspectBed: Audio.Handle?,
	flash: number,
}

local Reaver = {}
local MINT = Color3.fromRGB(105, 228, 193)
local RIFT_SHADOW = Color3.fromHex("276A60")
local INSPECT_LOCK = 3.88
local DRAW_LOCK = 0.58
local HEAVY_CONTACT = 0.30
local IDENTITY = CFrame.identity
local TIP = Vector3.new(0, 0.065, -3.64)
local PRIMARY_GRIP = Vector3.new(0, -0.03, 0.20)
local SECONDARY_GRIP = Vector3.new(-0.024, -0.035, 0.54)
local READY = CFrame.new(0.97, -0.80, -1.50)
	* CFrame.fromOrientation(math.rad(52), math.rad(-8), math.rad(-38))

local function handleAt(grip: CFrame, scale: number): CFrame
	return grip * CFrame.new(-PRIMARY_GRIP * scale)
end

local function key(
	at: number,
	x: number,
	y: number,
	z: number,
	pitch: number,
	yaw: number,
	roll: number,
	spread: number
): Key
	return {
		at = at,
		offset = READY:Inverse()
			* CFrame.new(x, y, z)
			* CFrame.fromOrientation(math.rad(pitch), math.rad(yaw), math.rad(roll)),
		spread = spread,
	}
end

local function rest(at: number): Key
	return { at = at, offset = IDENTITY, spread = 0 }
end

local TRACKS: { [string]: Track } = {
	Draw = {
		length = 1.05,
		keys = {
			key(0, 1.08, -1.72, -1.27, -58, -24, 27, 1.10),
			key(0.18, 1.24, -1.02, -1.42, -33, -53, 6, 0.96),
			key(0.36, 1.16, -0.63, -1.81, 26, -37, -33, 0.59),
			key(DRAW_LOCK, 1.01, -0.61, -1.70, 58, -10, -51, 0),
			rest(1.05),
		},
	},
	Slash1 = {
		length = 0.55,
		contact = 0.168,
		keys = {
			rest(0),
			key(0.080, 1.29, -0.34, -1.46, 51, -37, -60, 0.02),
			key(0.168, 0.33, -0.22, -2.09, 21, 38, -43, 0.09),
			key(0.279, -0.65, -0.61, -1.91, -12, 73, -65, 0.05),
			key(0.41, 0.02, -0.99, -1.62, 11, 39, -51, 0.01),
			rest(0.55),
		},
	},
	Slash2 = {
		length = 0.55,
		contact = 0.231,
		keys = {
			rest(0),
			key(0.124, -0.53, -0.83, -1.62, -9, 65, 53, 0.02),
			key(0.231, 0.08, -0.42, -2.12, 12, 8, 70, 0.10),
			key(0.342, 1.10, -0.15, -1.84, 29, -56, 67, 0.04),
			key(0.456, 1.23, -0.54, -1.56, 49, -25, 12, 0.01),
			rest(0.55),
		},
	},
	Slash3 = {
		length = 0.70,
		contact = 0.29,
		keys = {
			rest(0),
			key(0.16, 1.27, -0.51, -1.43, 8, -70, -66, 0.02),
			key(0.29, 0.43, -0.44, -2.12, 3, 17, -79, 0.10),
			key(0.42, -0.68, -0.49, -1.91, -1, 71, -68, 0.06),
			key(0.57, 0.19, -0.87, -1.67, 17, 38, -41, 0.01),
			rest(0.70),
		},
	},
	HeavyStab = {
		length = 0.88,
		contact = HEAVY_CONTACT,
		keys = {
			rest(0),
			key(0.13, 0.81, 0.06, -1.46, 59, -44, -35, 0.07),
			key(0.207, 0.65, 0.26, -1.52, 70, -18, -30, 0.09),
			key(HEAVY_CONTACT, 0.26, -0.29, -2.18, 19, 26, -44, 0.17),
			key(0.425, -0.30, -0.79, -2.06, -24, 43, -49, 0.09),
			key(0.66, 0.54, -0.96, -1.55, 17, 10, -39, 0.02),
			rest(0.88),
		},
	},
	Inspect = {
		length = 4.55,
		keys = {
			rest(0),
			key(0.48, 0.99, -0.60, -1.84, 51, 22, -42, 0.02),
			key(1.08, 1.09, -0.41, -2.48, 25, 61, -49, 0.35),
			key(1.72, 1.15, -0.52, -2.68, 12, 69, -30, 0.86),
			key(2.30, 1.14, -0.50, -2.64, 12, 71, 12, 0.94),
			key(2.94, 1.02, -0.46, -2.49, 16, 65, 59, 0.74),
			key(3.50, 0.86, -0.50, -2.21, 26, 50, 33, 0.50),
			key(INSPECT_LOCK, 0.89, -0.58, -1.98, 40, 33, -21, 0),
			rest(4.55),
		},
	},
}

local function rotationVector(relative: CFrame): Vector3
	local axis, angle = relative:ToAxisAngle()
	return axis * angle
end

local function poseTangent(keys: { Key }, i: number): (Vector3, Vector3)
	local before, keyframe, after = keys[i - 1], keys[i], keys[i + 1]
	if not before or not after then
		return Vector3.zero, Vector3.zero
	end
	local weight = 0.85 / (after.at - before.at)
	local pose = keyframe.offset
	local travel = (after.offset.Position - before.offset.Position) * weight
	local ahead = rotationVector(pose:ToObjectSpace(after.offset))
	local behind = rotationVector(pose:ToObjectSpace(before.offset))
	return travel, (ahead - behind) * weight
end

local function control(keyframe: Key, velocity: Vector3, angular: Vector3, time: number): CFrame
	local pose = keyframe.offset
	local arc = if angular.Magnitude > 1e-5
		then CFrame.fromAxisAngle(angular.Unit, angular.Magnitude * time)
		else IDENTITY
	return CFrame.new(pose.Position + velocity * time) * pose.Rotation * arc
end

-- Adjacent segments share the same positional and angular tangent. The
-- wrist keeps carrying the blade through the contact pose and into the arc.
for _, track in TRACKS do
	local segments: { Segment } = {}
	for i = 1, #track.keys - 1 do
		local a, b = track.keys[i], track.keys[i + 1]
		local length = (b.at - a.at) / 3
		local out, spinOut = poseTangent(track.keys, i)
		local into, spinIn = poseTangent(track.keys, i + 1)
		table.insert(segments, {
			a = a,
			b = b,
			exit = control(a, out, spinOut, length),
			entry = control(b, into, spinIn, -length),
		})
	end
	track.segments = segments
end

local function socket(handle: BasePart, name: string, position: Vector3): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position
	attachment.Parent = handle
	return attachment
end

local function bladeLinks(
	model: Model,
	parent: BasePart,
	scale: number
): ({ Beam }, { Beam }, { Attachment })
	local links: { Beam } = {}
	local veils: { Beam } = {}
	local anchors: { Attachment } = {}
	for i = 1, 4 do
		local first = model:FindFirstChild("RuinBladeLink" .. i .. "A", true)
		local second = model:FindFirstChild("RuinBladeLink" .. i .. "B", true)
		if first and first:IsA("Attachment") and second and second:IsA("Attachment") then
			local ribbon = Instance.new("Beam")
			ribbon.Name = "ReaverSpectralRift"
			ribbon.Attachment0, ribbon.Attachment1 = first, second
			ribbon.Color = ColorSequence.new(MINT, Color3.fromRGB(39, 158, 132))
			ribbon.Width0, ribbon.Width1 = 0.039 * scale, 0.021 * scale
			ribbon.CurveSize0, ribbon.CurveSize1 = 0.086 * scale, -0.056 * scale
			ribbon.FaceCamera = true
			ribbon.LightEmission = 0.78
			ribbon.LightInfluence = 0
			ribbon.Segments = 6
			ribbon.Enabled = false
			ribbon.Parent = parent
			table.insert(links, ribbon)
			local veil = ribbon:Clone()
			veil.Name = "ReaverRiftVeil"
			veil.Attachment0, veil.Attachment1 = first, second
			veil.Texture = Vfx.FROST_VAPOR
			veil.TextureMode = Enum.TextureMode.Stretch
			veil.TextureSpeed = if i % 2 == 0 then 0.34 else -0.34
			veil.LightEmission = 0.46
			veil.Color = ColorSequence.new(Color3.fromRGB(50, 168, 142), MINT)
			veil.Parent = parent
			table.insert(veils, veil)
			if i == 2 or i == 3 then
				table.insert(anchors, second)
			end
		end
	end
	return links, veils, anchors
end

function Reaver.new(model: Model, scale: number): State?
	local handle = model.PrimaryPart
	if StateValues.get(model, "SkinItem") ~= "RuinedReaver" or not handle then
		return nil
	end
	local root = socket(handle, "ReaverTrailRoot", Vector3.new(0, 0.05, -0.78) * scale)
	local tip = socket(handle, "ReaverTrailTip", TIP * scale)
	local trail = Instance.new("Trail")
	trail.Name = "RuinedReaverTrail"
	trail.Attachment0, trail.Attachment1 = root, tip
	trail.Enabled = false
	trail.Lifetime = 0.24
	trail.MinLength = 0.03
	trail.Color = ColorSequence.new(MINT, Color3.fromRGB(23, 74, 67))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.44),
		NumberSequenceKeypoint.new(0.5, 0.73),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new(1, 0.42)
	trail.LightEmission = 0.66
	trail.LightInfluence = 0
	trail.Texture = Vfx.FROST_VAPOR
	trail.TextureMode = Enum.TextureMode.Stretch
	trail.Parent = handle
	local cutStart = socket(handle, "ReaverCutStart", Vector3.zero)
	local cutEnd = socket(handle, "ReaverCutEnd", Vector3.zero)
	local cutStrokes: { Beam } = {}
	for i, look in
		{
			{ color = Color3.fromRGB(164, 255, 223), width = 0.115, texture = Vfx.RECON_TRAIL },
			{ color = Color3.fromRGB(26, 121, 107), width = 0.36, texture = Vfx.FROST_VAPOR },
		}
	do
		local stroke = Instance.new("Beam")
		stroke.Name = if i == 1 then "ReaverCutEdge" else "ReaverCutVapor"
		stroke.Attachment0, stroke.Attachment1 = cutStart, cutEnd
		stroke.Width0, stroke.Width1 = look.width * 0.15 * scale, look.width * scale
		stroke.Texture = look.texture
		stroke.TextureMode = Enum.TextureMode.Stretch
		stroke.Color = ColorSequence.new(look.color)
		stroke.LightEmission = if i == 1 then 0.90 else 0.48
		stroke.LightInfluence = 0
		stroke.FaceCamera = true
		stroke.Segments = 12
		stroke.Enabled = false
		stroke.Parent = handle
		table.insert(cutStrokes, stroke)
	end
	local mist = Instance.new("ParticleEmitter")
	mist.Name = "ReaverHiltMist"
	mist.Texture = Vfx.FROST_MIST_2x2
	mist.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	mist.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	mist.Color = ColorSequence.new(MINT, Color3.fromRGB(22, 79, 69))
	mist.LightEmission = 0.12
	mist.Lifetime = NumberRange.new(0.42, 0.76)
	mist.Speed = NumberRange.new(0.32, 1.1)
	mist.Rotation = NumberRange.new(-35, 35)
	mist.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18 * scale),
		NumberSequenceKeypoint.new(1, 0.72 * scale),
	})
	mist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.62),
		NumberSequenceKeypoint.new(0.18, 0.54),
		NumberSequenceKeypoint.new(1, 1),
	})
	mist.Rate = 2
	mist.SpreadAngle = Vector2.new(28, 28)
	mist.Parent = root
	local current = socket(handle, "ReaverSpectralCurrent", Vector3.new(0, 0.06, -1.72) * scale)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "ReaverFractureSparks"
	sparks.Texture = Vfx.WIND_STROKE
	sparks.Color = ColorSequence.new(Color3.fromRGB(186, 255, 233), MINT)
	sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
	sparks.LightEmission = 0.85
	sparks.LightInfluence = 0
	sparks.Lifetime = NumberRange.new(0.18, 0.37)
	sparks.Speed = NumberRange.new(1.4, 3.5)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.Size = NumberSequence.new(0.10 * scale, 0)
	sparks.Transparency = NumberSequence.new(0.22, 1)
	sparks.Enabled = false
	sparks.Parent = current
	local flare = Instance.new("ParticleEmitter")
	flare.Name = "ReaverSealFlash"
	flare.Texture = Vfx.RECON_GLOW
	flare.Color = ColorSequence.new(Color3.fromRGB(148, 245, 217), MINT)
	flare.LightEmission = 0.92
	flare.LightInfluence = 0
	flare.Lifetime = NumberRange.new(0.20)
	flare.Speed = NumberRange.new(0)
	flare.Size = NumberSequence.new(0.14 * scale, 0.85 * scale)
	flare.Transparency = NumberSequence.new(0.28, 1)
	flare.Enabled = false
	flare.Parent = current

	local orbitNodes: { Attachment } = {}
	local orbits: { Beam } = {}
	for i = 1, 7 do
		table.insert(orbitNodes, socket(handle, "ReaverOrbit" .. i, Vector3.zero))
		if i > 1 then
			local arc = Instance.new("Beam")
			arc.Name = "ReaverInspectRibbon"
			arc.Attachment0, arc.Attachment1 = orbitNodes[i - 1], orbitNodes[i]
			arc.Color = ColorSequence.new(MINT, Color3.fromRGB(37, 124, 111))
			arc.Texture = Vfx.HEALORB_RIBBON
			arc.TextureMode = Enum.TextureMode.Stretch
			arc.TextureSpeed = 1.35
			arc.LightEmission = 0.65
			arc.LightInfluence = 0
			arc.FaceCamera = true
			arc.Segments = 5
			arc.Enabled = false
			arc.Parent = handle
			table.insert(orbits, arc)
		end
	end
	local links, veils, anchors = bladeLinks(model, handle, scale)
	local bladeMist: { ParticleEmitter } = {}
	for _, anchor in anchors do
		local wisp = mist:Clone()
		wisp.Name = "ReaverBladeMist"
		wisp.Rate = 1.3
		wisp.Parent = anchor
		table.insert(bladeMist, wisp)
	end
	local bladeLight = Instance.new("PointLight")
	bladeLight.Name = "ReaverRiftLight"
	bladeLight.Color = MINT
	bladeLight.Range = 1.35 * scale
	bladeLight.Brightness = 1.3
	bladeLight.Parent = current
	local shards: { Shard } = {}
	local welds: { [BasePart]: { BasePart } } = {}
	local rig = model:FindFirstChild("Rig")
	local body = rig and rig:FindFirstChild("Root")
	local hilt: { BasePart } = {}
	local core: { BasePart } = {}
	for _, obj in model:GetDescendants() do
		if obj:IsA("Weld") and obj.Part0 and obj.Part1 then
			local parts = welds[obj.Part0] or {}
			table.insert(parts, obj.Part1)
			welds[obj.Part0] = parts
			if obj.Name == "SkinCosmeticWeld" and obj.Part0 == body then
				if obj.Part1.Material == Enum.Material.Neon or obj.Part1.Color == RIFT_SHADOW then
					table.insert(core, obj.Part1)
				else
					table.insert(hilt, obj.Part1)
				end
			end
		end
	end
	for _, obj in model:GetDescendants() do
		if obj:IsA("Motor6D") and obj.Part1 and string.match(obj.Name, "^RuinShard_") then
			local localPosition = handle.CFrame:PointToObjectSpace(obj.Part1.Position)
			local axis = Vector3.new(
				if #shards % 2 == 0 then 1 else -1,
				math.sign(localPosition.Y) * 0.65,
				-0.13
			).Unit
			table.insert(shards, { motor = obj, axis = axis, attached = welds[obj.Part1] or {} })
		end
	end
	return {
		name = "Idle",
		time = 0,
		clock = 0,
		pose = IDENTITY,
		origin = IDENTITY,
		spread = 0,
		originSpread = 0,
		scale = scale,
		shards = shards,
		trail = trail,
		cutStrokes = cutStrokes,
		cutStart = cutStart,
		cutEnd = cutEnd,
		hilt = hilt,
		core = core,
		mist = mist,
		bladeMist = bladeMist,
		links = links,
		veils = veils,
		support = 0,
		bladeLight = bladeLight,
		sparks = sparks,
		flare = flare,
		current = current,
		orbits = orbits,
		orbitNodes = orbitNodes,
		flash = 0,
	}
end

function Reaver.play(state: State, name: string): number
	if state.name == "Inspect" then
		Audio.fadeOut(state.inspectStart, 0.12)
		Audio.fadeOut(state.inspectBed, 0.18)
		state.inspectStart = nil
		state.inspectBed = nil
	end
	state.origin = state.pose
	state.originSpread = state.spread
	state.name = name
	state.time = 0
	return if TRACKS[name] then TRACKS[name].contact or 0 else 0
end

local function sample(track: Track, t: number): (CFrame, number)
	for _, segment in track.segments or {} do
		local a, b = segment.a, segment.b
		if t <= b.at then
			local u = math.clamp((t - a.at) / (b.at - a.at), 0, 1)
			local left = a.offset:Lerp(segment.exit, u)
			local middle = segment.exit:Lerp(segment.entry, u)
			local right = segment.entry:Lerp(b.offset, u)
			local pose = left:Lerp(middle, u):Lerp(middle:Lerp(right, u), u)
			return pose, Ease.lerp(a.spread, b.spread, Ease.smooth(u))
		end
	end
	return IDENTITY, 0
end

local function bladeTip(track: Track, time: number, scale: number): Vector3
	local offset = sample(track, time)
	return handleAt(READY * offset, scale):PointToWorldSpace(TIP * scale)
end

local function alignStroke(anchor: Attachment, at: Vector3, direction: Vector3)
	local x = direction.Unit
	local guide = if math.abs(x.Y) < 0.95 then Vector3.yAxis else Vector3.zAxis
	local y = (guide - x * x:Dot(guide)).Unit
	anchor.CFrame = CFrame.fromMatrix(at, x, y)
end

-- The luminous edge follows the actual tip path through the follow-through.
local function stepCut(state: State, track: Track?, visible: boolean)
	local contact = track and track.contact
	local t = state.time
	local show = visible and contact and t > contact - 0.074 and t < contact + 0.25
	for _, beam in state.cutStrokes do
		beam.Enabled = show == true
	end
	if not show or not track or not contact then
		return
	end
	local start, finish = contact - 0.087, contact + 0.095
	local head = math.min(t, finish)
	local tail = math.clamp(t - 0.13, start, head - 0.009)
	local span = (head - tail) / 3
	local pose = handleAt(READY * state.pose, state.scale)
	local a = bladeTip(track, tail, state.scale)
	local b = bladeTip(track, head, state.scale)
	local va = (
		bladeTip(track, tail + 0.008, state.scale) - bladeTip(track, tail - 0.008, state.scale)
	) / 0.016
	local vb = (
		bladeTip(track, head + 0.008, state.scale) - bladeTip(track, head - 0.008, state.scale)
	) / 0.016
	if va.Magnitude < 0.02 or vb.Magnitude < 0.02 then
		for _, beam in state.cutStrokes do
			beam.Enabled = false
		end
		return
	end
	alignStroke(state.cutStart, pose:PointToObjectSpace(a), pose:VectorToObjectSpace(va))
	alignStroke(state.cutEnd, pose:PointToObjectSpace(b), pose:VectorToObjectSpace(vb))
	local gain = Ease.smooth((t - start) / 0.063) * (1 - Ease.smooth((t - finish) / 0.155))
	for i, beam in state.cutStrokes do
		beam.CurveSize0, beam.CurveSize1 = va.Magnitude * span, vb.Magnitude * span
		local peak = gain * (if i == 1 then 0.89 else 0.61)
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.54, 1 - peak * 0.72),
			NumberSequenceKeypoint.new(0.84, 1 - peak),
			NumberSequenceKeypoint.new(1, 1 - peak * 0.75),
		})
	end
end

function Reaver.step(
	state: State,
	dt: number,
	visible: boolean,
	sprinting: boolean
): (CFrame, Vector3, Vector3, boolean, number)
	local previous = state.time
	state.time += dt
	state.clock = (state.clock + dt) % 360
	state.flash = Ease.approach(state.flash, 0, 15, dt)
	local movement = state.name
	local track = TRACKS[movement]
	local inspecting = movement == "Inspect"
	local drawing = movement == "Draw"
	local fx = visible and not UiMotion.reduced()
	local target, spread = IDENTITY, 0
	local pulseAt: number? = nil
	if track then
		target, spread = sample(track, state.time)
		if previous == 0 and state.time > 0 and drawing and fx then
			state.mist:Emit(8)
			Audio.playSound(ShadowAudio.drawAir, "Foley")
		end
		if inspecting and visible then
			if previous < 0.10 and state.time >= 0.10 then
				state.inspectStart = Audio.playSound(ShadowAudio.inspect, "Foley")
			end
			if previous < 1.13 and state.time >= 1.13 then
				state.inspectBed = Audio.playSound(ShadowAudio.inspectBed, "Foley", nil, 0.74)
				if fx then
					state.sparks:Emit(6)
					state.flash = 0.69
				end
			end
		end
		if movement == "HeavyStab" and previous == 0 and state.time > 0 and visible then
			Audio.playSound(ShadowAudio.drawAir, "Foley", nil, 0.62)
		end
		pulseAt = if movement == "Draw"
			then DRAW_LOCK
			elseif movement == "Inspect" then INSPECT_LOCK
			else track.contact
		if pulseAt and previous < pulseAt and state.time >= pulseAt and visible then
			state.flash = if movement == "HeavyStab" then 1.65 else 1.12
			if fx then
				if inspecting or drawing then
					state.flare:Emit(1)
					state.sparks:Emit(9)
					state.mist:Emit(7)
					for _, wisp in state.bladeMist do
						wisp:Emit(2)
					end
				else
					state.sparks:Emit(if movement == "HeavyStab" then 5 else 3)
				end
			end
			if inspecting or drawing then
				Audio.playSound(ShadowAudio.lock, "Foley")
			end
		end
		local blend = Ease.smooth(state.time / (if drawing then 0.12 else 0.065))
		state.pose = state.origin:Lerp(target, blend)
		state.spread = Ease.lerp(state.originSpread, spread, blend)
		if state.time >= track.length then
			Reaver.play(state, "Idle")
		end
	else
		target = if sprinting
			then CFrame.new(0.22, -0.42, 0.14) * CFrame.Angles(0, -0.30, 0.18)
			else CFrame.new(0, math.sin(state.time * 2.3) * 0.018, 0) * CFrame.Angles(
				math.sin(state.time * 1.7) * 0.019,
				0,
				0
			)
		state.pose = state.pose:Lerp(target, 1 - math.exp(-14 * dt))
		state.spread = Ease.approach(state.spread, 0, 22, dt)
	end
	spread = if fx then state.spread else 0
	local hiltFade = if drawing then 1 - Ease.smooth((state.time - 0.07) / 0.25) else 0
	local coreFade = if drawing then 1 - Ease.smooth((state.time - 0.41) / 0.17) else 0
	for _, part in state.hilt do
		LocalHide.set(part, if visible then hiltFade else 1)
	end
	for _, part in state.core do
		LocalHide.set(part, if visible then coreFade else 1)
	end
	local contact = track and track.contact
	local sweeping = fx
		and contact ~= nil
		and state.time >= contact - 0.092
		and state.time <= contact + 0.11
	local visibleSweep = sweeping == true and state.name == movement
	state.trail.Enabled = visibleSweep
	stepCut(state, track, fx and state.name == movement)
	state.trail.Lifetime = if movement == "HeavyStab" then 0.27 else 0.20
	state.mist.Enabled = fx and (not drawing or hiltFade < 0.5)
	for _, wisp in state.bladeMist do
		wisp.Enabled = fx and coreFade < 0.65
		wisp.Rate = 1.1 + math.min(spread, 1) * (if inspecting then 2.50 else 0.90)
	end
	local orbit = if inspecting
		then Ease.smooth((state.time - 0.82) / 0.62) * (1 - Ease.smooth((state.time - 3.45) / 0.47))
		else 0
	local charge = if inspecting
		then Ease.smooth((state.time - 0.79) / 1.60)
		elseif drawing then Ease.smooth((state.time - 0.36) / 0.22)
		elseif sweeping then Ease.smooth((state.time - (contact or 0) + 0.12) / 0.15)
		else 0.35
	state.current.Position = Vector3.new(0, 0.025 + charge * 0.18, -0.75 - charge * 2.47)
		* state.scale
	local orbitVisible = fx and orbit > 0.015
	local arcCount = #state.orbits
	if orbitVisible then
		local radiusX, radiusY = 0.15 + 0.27 * orbit, 0.18 + 0.24 * orbit
		for i, node in state.orbitNodes do
			local u = (i - 1) / arcCount
			local theta = state.clock * 3.2 - u * 6.1
			local x, y = math.cos(theta), math.sin(theta)
			local position = Vector3.new(x * radiusX, y * radiusY + 0.19 * u, -0.79 - 2.66 * u)
			local tangent = Vector3.new(y * radiusX * 6.1, 0.19 - x * radiusY * 6.1, -2.66)
			local side = tangent.Unit
			local up = (Vector3.yAxis - side * side.Y).Unit
			node.CFrame = CFrame.fromMatrix(position * state.scale, side, up)
		end
	end
	for i, arc in state.orbits do
		arc.Enabled = orbitVisible
		if orbitVisible then
			local start = math.sin(math.pi * (i - 1) / arcCount)
			local finish = math.sin(math.pi * i / arcCount)
			arc.Width0 = (0.05 + start * 0.20) * orbit * state.scale
			arc.Width1 = (0.05 + finish * 0.20) * orbit * state.scale
			arc.CurveSize0 = 0.17 * state.scale
			arc.CurveSize1 = 0.17 * state.scale
			arc.Transparency =
				NumberSequence.new(1 - orbit * 0.67 * start, 1 - orbit * 0.67 * finish)
		end
	end
	for index, ribbon in state.links do
		local t = if pulseAt then state.time - pulseAt - (index - 1) * 0.027 else -1
		local wave = if t >= 0 then math.max(0, 1 - t * 6) else 0
		local surge = if inspecting then math.max(0, 1 - math.abs(charge * 4 - index) * 1.3) else 0
		local amount =
			math.min(1, (0.43 + spread * 0.30 + wave * 0.52 + surge * 0.32) * (1 - coreFade))
		ribbon.Enabled = fx and coreFade < 0.88
		local veil = state.veils[index]
		veil.Enabled = ribbon.Enabled
		if ribbon.Enabled then
			ribbon.Width0 = (0.048 + wave * 0.058 + surge * 0.025) * state.scale
			ribbon.Width1 = (0.029 + wave * 0.035) * state.scale
			veil.Width0 = (0.13 + wave * 0.13 + spread * 0.05) * state.scale
			veil.Width1 = veil.Width0 * 0.64
			veil.CurveSize0 = (0.18 + math.sin(state.clock * 3.0 + index) * 0.12) * state.scale
			veil.CurveSize1 = -veil.CurveSize0 * 0.84
			veil.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 1 - amount * 0.56),
				NumberSequenceKeypoint.new(1, 1),
			})
			ribbon.CurveSize0 = (0.065 + math.sin(state.clock * 4 + index) * 0.043) * state.scale
			ribbon.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.84),
				NumberSequenceKeypoint.new(0.42, 1 - amount * 0.85),
				NumberSequenceKeypoint.new(1, 0.84),
			})
		end
	end
	state.bladeLight.Enabled = visible and coreFade < 0.95
	state.bladeLight.Range = (1.35 + orbit * 0.65) * state.scale
	state.bladeLight.Brightness = (0.96 + spread * 0.94 + (if fx then state.flash * 2.2 else 0))
		* (1 - coreFade)
	for index, shard in state.shards do
		local settle = if inspecting
			then 1 - math.max(0, 1 - math.abs(state.time - INSPECT_LOCK) / 0.19)
			else 1
		local float = if fx
			then (0.012 + 0.012 * math.sin(state.clock * 2.5 + index)) * settle
			else 0
		shard.motor.Transform = CFrame.new(shard.axis * ((float + 0.25 * spread) * state.scale))
			* CFrame.Angles(
				spread * 0.10,
				spread * 0.07,
				spread * (if index % 2 == 0 then 0.13 else -0.13)
			)
		local fade = if drawing
			then 1 - Ease.smooth((state.time - (0.24 + index * 0.028)) / 0.20)
			else 0
		if shard.motor.Part1 then
			LocalHide.set(shard.motor.Part1, if visible then fade else 1)
		end
		for _, part in shard.attached do
			LocalHide.set(part, if visible then fade else 1)
		end
	end
	local needsSupport = movement == "HeavyStab"
	local follow = if needsSupport
		then Ease.smooth((state.time - 0.04) / 0.13) * (1 - Ease.smooth((state.time - 0.31) / 0.18))
		elseif inspecting then Ease.smooth((state.time - 0.53) / 0.43) * (1 - Ease.smooth(
			(state.time - 2.25) / 0.56
		))
		else 0
	state.support = Ease.approach(state.support, follow, 24, dt)
	local grip = READY * state.pose
	local pose = handleAt(grip, state.scale)
	local balance = if contact and not needsSupport
		then Ease.smooth(state.time / 0.10) * (1 - Ease.smooth((state.time - contact) / 0.23))
		else 0
	local offHand = Vector3.new(
		-0.62 - 0.19 * balance,
		-0.93 + math.sin(state.clock * 2.3) * 0.019 + 0.08 * balance,
		-1.29 - 0.14 * balance
	)
	local supportGrip = pose:PointToWorldSpace(
		(if inspecting then Vector3.new(-0.14, -0.26, -1.65 - charge * 0.45) else SECONDARY_GRIP)
			* state.scale
	)
	if inspecting then
		supportGrip += Vector3.new(-0.10, -0.26, 0)
	end
	return pose,
		grip.Position,
		offHand:Lerp(supportGrip, state.support),
		state.support > 0.2,
		if needsSupport then state.support else 0
end

return Reaver
