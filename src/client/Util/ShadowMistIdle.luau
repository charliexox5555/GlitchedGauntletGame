--!strict
-- Local cosmetic finish. The stock rig and animator own the handling pose.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local Shared = ReplicatedStorage.Shared
local Style = require(Shared.Config.SkinPreview).SHADOW_MIST
local VFX = require(Shared.Config.VfxTextures)
local UiMotion = require(Shared.UiMotion)
local Actions = require(script.Parent.ShadowMistActions)

type Shard = {
	motor: Motor6D,
	offset: Vector3,
	phase: number,
	tilt: number,
	sight: boolean,
	delay: number,
}
type ShellPart = { part: BasePart, transparency: number, delay: number }
type Binding = { part: BasePart, color: Color3, phase: number, mix: number }
type Light = { part: PointLight, phase: number, magazine: boolean }
type Emitter = { part: ParticleEmitter, magazine: boolean }

export type State = {
	shards: { Shard },
	shell: { ShellPart },
	assembly: number,
	bindings: { Binding },
	emitters: { Emitter },
	lights: { Light },
	seams: { Beam },
	magGlow: BasePart?,
	clock: number,
	motion: number,
	active: boolean,
}

local ShadowMistIdle = {}

-- One slow stream at each break in the silhouette. The narrower collar and
-- magazine need a smaller plume than the fore-end and stock heel.
local MIST_SOURCES: { [string]: number } = {
	RuinMistFore = 1,
	RuinReceiverGlow = 0.85,
	RuinMagGlow = 0.74,
	RuinCollarL = 0.76,
	RuinCollarR = 0.76,
	RuinMistHeel = 1,
}

-- End and start angles of the eight carved segments in Blender's aperture.
local SIGHT_CUTS = {
	{ -3, 30 },
	{ 40, 72 },
	{ 81, 117 },
	{ 127, 163 },
	{ 173, 212 },
	{ 221, 257 },
	{ 264, 311 },
	{ 321, 350 },
}

local function makeMist(state: State, anchor: Attachment, scale: number, magazine: boolean)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "ShadowMistSmoke"
	emitter.Texture = VFX.FROST_MIST_2x2
	emitter.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	emitter.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	emitter.Color = ColorSequence.new(Color3.fromRGB(106, 166, 153), Color3.fromRGB(105, 145, 137))
	emitter.Rate = Style.MIST_RATE
	emitter.Lifetime = NumberRange.new(1.05, 1.35)
	emitter.Speed = NumberRange.new(0.11 * scale, 0.20 * scale)
	emitter.Drag = 1.5
	emitter.SpreadAngle = Vector2.new(17, 17)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.LightEmission = 0.04
	emitter.LightInfluence = 0
	emitter.Brightness = 1
	emitter.LockedToPart = true
	emitter.Rotation = NumberRange.new(-15, 15)
	emitter.RotSpeed = NumberRange.new(-9, 9)
	emitter.ZOffset = 0.025 * scale
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.17 * scale),
		NumberSequenceKeypoint.new(0.40, 0.28 * scale),
		NumberSequenceKeypoint.new(1, 0.36 * scale),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.24, 0.63),
		NumberSequenceKeypoint.new(0.53, 0.70),
		NumberSequenceKeypoint.new(0.81, 0.88),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Enabled = false
	emitter.Parent = anchor
	table.insert(state.emitters, { part = emitter, magazine = magazine })
end

local function attach(parent: BasePart, name: string, position: Vector3): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position
	attachment.Parent = parent
	return attachment
end

local function addBeam(
	state: State,
	from: Attachment,
	to: Attachment,
	width: number,
	curve0: number,
	curve1: number,
	sight: boolean?
)
	local beam = Instance.new("Beam")
	beam.Name = if sight then "ShadowMistApertureSeam" else "ShadowMistSeam"
	beam.Attachment0, beam.Attachment1 = from, to
	beam.Color = ColorSequence.new(Style.MIST_TINT, Style.TINT_PEAK)
	beam.Texture = VFX.HEALORB_RIBBON
	beam.TextureSpeed = 0
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.91),
		NumberSequenceKeypoint.new(0.35, 0.34),
		NumberSequenceKeypoint.new(0.72, 0.48),
		NumberSequenceKeypoint.new(1, 0.97),
	})
	beam.FaceCamera = true
	beam.Width0 = width
	beam.Width1 = width * 0.79
	beam.Segments = 6
	beam.CurveSize0 = curve0
	beam.CurveSize1 = curve1
	beam.LightEmission = 0.64
	beam.LightInfluence = 0
	beam.Brightness = 1.2
	beam.Enabled = false
	beam.Parent = from
	table.insert(state.seams, beam)
end

local function addSeam(state: State, model: Model, motor: Motor6D, scale: number)
	local root = motor.Part0
	local shard = motor.Part1
	local handle = model.PrimaryPart
	if not root or not shard or not handle then
		return
	end
	local p = handle.CFrame:PointToObjectSpace(shard.Position)
	local side = if p.X >= 0 then 1 else -1
	local inward = handle.CFrame:VectorToWorldSpace(Vector3.new(-side * 0.091, -0.045, 0) * scale)
	local origin =
		attach(root, "ShadowMistSeamRoot", root.CFrame:PointToObjectSpace(shard.Position + inward))
	local floating = attach(shard, "ShadowMistSeamShard", Vector3.zero)
	addBeam(state, origin, floating, 0.023 * scale, 0.045 * scale, -0.023 * scale)
end

local function addSightSeams(state: State, scale: number)
	local joints: { Motor6D } = {}
	for _, shard in state.shards do
		if shard.sight then
			table.insert(joints, shard.motor)
		end
	end
	if #joints ~= #SIGHT_CUTS then
		return
	end
	table.sort(joints, function(a, b)
		return a.Name < b.Name
	end)
	local root = joints[1].Part0
	if not root then
		return
	end
	local function edge(joint: Motor6D, angle: number): Attachment?
		local part = joint.Part1
		if not part then
			return nil
		end
		local t = math.rad(angle)
		local p = Vector3.new(0.065, 0.078 * math.cos(t), 0.4098 + 0.078 * math.sin(t))
		return attach(
			part,
			"ShadowMistSightEdge",
			part.CFrame:PointToObjectSpace(root.CFrame:PointToWorldSpace(p * scale))
		)
	end
	for i, joint in joints do
		local nextIndex = i % #joints + 1
		local endpoint = joint.Part1
		local nextPart = joints[nextIndex].Part1
		local from = endpoint and endpoint:FindFirstChild("RuinSightEnd")
		local to = nextPart and nextPart:FindFirstChild("RuinSightStart")
		if from and to and from:IsA("Attachment") and to:IsA("Attachment") then
			addBeam(state, from, to, 0.007 * scale, 0, 0, true)
		else
			local a = edge(joint, SIGHT_CUTS[i][2] - 0.65)
			local b = edge(joints[nextIndex], SIGHT_CUTS[nextIndex][1] + 0.65)
			if a and b then
				addBeam(state, a, b, 0.007 * scale, 0, 0, true)
			end
		end
	end
end

local function addEnergy(state: State, anchor: Attachment, scale: number, localized: boolean)
	local phase = StateValues.get(anchor, "RuinIdleLight")
	local mist = StateValues.get(anchor, "RuinIdleMist") == true
	local magazine = StateValues.get(anchor, "RuinIdleMagazine") == true
	local p = anchor.Parent
	if (typeof(phase) ~= "number" and not mist) or not p or not p:IsA("BasePart") then
		return
	end
	phase = if typeof(phase) == "number" then phase else 0
	local mistScale = MIST_SOURCES[anchor.Name]
	if mist and (mistScale or not localized) then
		-- Bone +Z is up along the receiver cross-section.
		local side = if anchor.Position.Y >= 0 then 1 else -1
		local smoke = attach(p, "ShadowMistSmokeOrigin", anchor.Position)
		smoke.CFrame =
			CFrame.lookAt(anchor.Position, anchor.Position + Vector3.new(-0.36, side * 0.32, 0.84))
		makeMist(state, smoke, scale * (mistScale or 1), magazine)
	end

	-- Only the main effect anchors carry lights.
	if
		anchor.Name:match("RuinCowl[LR]")
		or anchor.Name:match("RuinLowerFore[LR]")
		or anchor.Name:match("RuinHeel[LR]")
	then
		return
	end
	if anchor.Name == "RuinCollarR" then
		return
	end
	local light = Instance.new("PointLight")
	light.Name = "ShadowMistGlow"
	light.Color = Style.MIST_TINT
	light.Range = Style.LIGHT_RANGE * scale
	light.Enabled = false
	light.Shadows = false
	light.Parent = anchor
	table.insert(state.lights, { part = light, phase = phase, magazine = magazine })
end

function ShadowMistIdle.new(model: Model, scale: number): State?
	if StateValues.get(model, "SkinLine") ~= Style.LINE then
		return nil
	end
	local state: State = {
		shards = {},
		shell = {},
		assembly = 1,
		bindings = {},
		emitters = {},
		lights = {},
		seams = {},
		magGlow = nil,
		clock = 0,
		motion = 0,
		active = false,
	}
	local localized = model:FindFirstChild("RuinApertureGlow", true) ~= nil
	local legacy = StateValues.get(model, "WeaponId") == "Vandal"
		and StateValues.get(model, "SkinVersion") == "v03"
	local handle = model.PrimaryPart
	local function gatherDelay(part: BasePart?): number
		local localPoint = if part and handle
			then handle.CFrame:PointToObjectSpace(part.Position)
			else Vector3.zero
		return math.clamp((-localPoint.Z / scale + 1) / 2.7, 0, 1) * 0.28
	end
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			local axis = StateValues.get(d, "RuinIdleAxis")
			local phase = StateValues.get(d, "RuinIdlePhase")
			if typeof(axis) == "Vector3" and typeof(phase) == "number" then
				local travel = StateValues.get(d, "RuinIdleTravel")
				local tilt = StateValues.get(d, "RuinIdleTilt")
				table.insert(state.shards, {
					motor = d,
					offset = axis * (scale * (if typeof(travel) == "number"
						then travel
						else Style.SHARD_TRAVEL)),
					phase = phase,
					tilt = if typeof(tilt) == "number" then tilt else Style.SHARD_TILT,
					sight = d.Name:match("^RuinSight_") ~= nil,
					delay = gatherDelay(d.Part1),
				})
				if
					StateValues.get(d, "RuinIdleTether") == true
					or (legacy and (d.Name == "RuinShard_01" or d.Name == "RuinShard_02"))
				then
					addSeam(state, model, d, scale)
				end
			end
		elseif d:IsA("BasePart") then
			local phase = StateValues.get(d, "RuinIdleGlow")
			if typeof(phase) == "number" then
				local mix = StateValues.get(d, "RuinIdleGlowMix")
				table.insert(state.bindings, {
					part = d,
					color = d.Color,
					phase = phase,
					mix = if typeof(mix) == "number" then mix else 1,
				})
				if StateValues.get(d, "RuinIdleMagazine") == true then
					state.magGlow = d
				end
			end
		elseif d:IsA("Attachment") then
			addEnergy(state, d, scale, localized)
		elseif d:IsA("Weld") and d.Part0 and d.Part0.Name:match("^RuinShard_") then
			local part = d.Part1
			if part and part.Transparency < 1 then
				table.insert(
					state.shell,
					{ part = part, transparency = part.Transparency, delay = gatherDelay(part) }
				)
			end
		end
	end
	addSightSeams(state, scale)
	return state
end

local function wave(phase: number): number
	return 0.5 - 0.5 * math.cos(phase)
end

local function gather(assembly: number, delay: number): number
	return math.clamp((assembly - delay) / (1 - delay), 0, 1)
end

local function shotPulse(age: number, phase: number): number
	local delay = if phase < 0.50 then 0.016 elseif phase < 1.35 then 0 else 0.032
	local traveling = if age >= delay then math.max(0, 1 - (age - delay) / 0.145) ^ 1.6 else 0
	return traveling * (if phase >= 3 then 0.32 else 1)
end

function ShadowMistIdle.step(
	state: State,
	dt: number,
	visible: boolean,
	idle: boolean,
	ads: number,
	action: Actions.Frame?
)
	local reduced = UiMotion.reduced()
	local aim = math.clamp(ads, 0, 1)
	local target = if visible and not reduced then (if idle then 1 else 0.48) else 0
	local step = math.min(dt, 0.1)
	state.motion = math.clamp(
		target,
		math.max(0, state.motion - step * 7),
		math.min(1, state.motion + step * 4.5)
	)
	state.clock = (state.clock + step) % Style.PERIOD
	local phase = state.clock / Style.PERIOD * 2 * math.pi
	local assembly = if action then action.assembly else 1
	local spread = if action then action.spread else 0
	local twist = if action then action.twist else 0
	local inspectClamp = if action then action.inspectClamp else 0
	local energyKick = if action then action.energy else 0
	local shotAge = if action then action.shotAge else math.huge
	local shotScale = 1 - aim * 0.57
	if assembly ~= state.assembly then
		state.assembly = assembly
		for _, shell in state.shell do
			local reveal = math.clamp(gather(assembly, shell.delay) / 0.69, 0, 1)
			shell.part.Transparency = 1 - (1 - shell.transparency) * reveal
		end
	end
	if state.motion > 0 then
		state.active = true
		for _, shard in state.shards do
			local aimWeight = if shard.sight then Style.ADS_SIGHT_WEIGHT else Style.ADS_SHARD_WEIGHT
			local weight = state.motion * (1 - (1 - aimWeight) * aim)
			if not shard.sight then
				weight *= 1 - inspectClamp
			end
			local beat = phase + shard.phase
			local lift = (0.16 + 0.84 * wave(beat)) * weight
			local tilt = shard.tilt * math.sin(beat) * weight
			local position = shard.offset * lift
			if not shard.sight and (spread > 0.001 or assembly < 0.999) then
				local extent = Style.INSPECT_SPREAD
					* (if shard.offset.Magnitude > 0.055 then 0.72 else 1)
				local convergence = 1 - gather(assembly, shard.delay)
				local outward = math.max(position.Magnitude, extent * spread) + convergence * 0.29
				position = CFrame.Angles(twist + convergence * 0.20, 0, 0)
					:VectorToWorldSpace(shard.offset.Unit * outward)
			end
			if not shard.sight and shotAge < 0.18 then
				-- Keep the idle phase running under the shot. Offsets follow the same
				-- clearance directions as the floating armor when it breathes.
				local elapsed = shotAge - (0.030 - shard.delay * 0.085)
				local flex = math.clamp(elapsed / 0.014, 0, 1)
					* math.clamp(1 - elapsed / 0.15, 0, 1) ^ 2
				flex *= 1 - aim * 0.81
				position += shard.offset.Unit * flex * (0.018 + shard.delay * 0.037)
				tilt += math.cos(shard.phase) * flex * 0.044
			end
			shard.motor.Transform = CFrame.new(position)
				* CFrame.Angles(tilt + twist * 0.5, 0, tilt * 0.55)
		end
	elseif state.active then
		state.active = false
		for _, shard in state.shards do
			shard.motor.Transform = CFrame.identity
		end
	end

	local magGlow = state.magGlow
	local magVisible = not magGlow or magGlow.LocalTransparencyModifier < 0.98
	local smokeRate = (Style.MIST_RATE + (if action then action.mist * 5.5 else 0)) * (1 - aim) ^ 2
	for _, emitter in state.emitters do
		local enabled = visible
			and not reduced
			and aim < 0.64
			and (not emitter.magazine or magVisible)
		if emitter.part.Enabled ~= enabled then
			emitter.part.Enabled = enabled
			if not enabled then
				emitter.part:Clear()
			end
		end
		if enabled then
			emitter.part.Rate = smokeRate
		end
	end

	local energy = 1 - (1 - Style.ADS_LIGHT) * aim
	local function beat(offset: number): number
		return if reduced then 0.55 else wave(phase + offset)
	end
	if visible then
		for _, binding in state.bindings do
			local pulse = (0.55 + 0.11 * beat(binding.phase)) * binding.mix * energy
			local shot = shotPulse(shotAge, binding.phase) * shotScale
			local kick = energyKick * 0.42 + shot * 0.72
			local peak = Style.TINT_PEAK:Lerp(Color3.fromRGB(102, 255, 205), shot)
			binding.part.Color = binding.color:Lerp(peak, math.min(pulse + kick, 1))
		end
	end
	for _, seam in state.seams do
		seam.Enabled = visible and assembly > 0.58
		if seam.Enabled then
			seam.Brightness = 1.2
				+ 0.7 * spread
				+ (if action then action.shot * shotScale * 0.52 else 0)
		end
	end
	for _, light in state.lights do
		light.part.Enabled = visible and (not light.magazine or magVisible)
		if visible then
			light.part.Brightness = Style.LIGHT_BRIGHTNESS
					* (0.90 + 0.10 * beat(light.phase))
					* energy
				+ energyKick * 2.25
				+ shotPulse(shotAge, light.phase) * shotScale * 2.85
		end
	end
end

return ShadowMistIdle
