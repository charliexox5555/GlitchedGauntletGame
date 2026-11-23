--!strict
-- Local presentation for the Arc's guided insert and swept blade.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateValues = require(ReplicatedStorage.Shared.StateValues)
local Audio = require(ReplicatedStorage.Shared.Config.SlipframeAudio)
local Ease = require(ReplicatedStorage.Shared.Util.Ease)
local AudioController = require(script.Parent.Parent.Controllers.AudioController)

local BLUE = Color3.fromRGB(77, 164, 246)
local ICE = Color3.fromRGB(197, 239, 255)
local REVEAL_AT = 17 / 64
local HOLD_AT = 26 / 64
local CLOSE_AT = 40 / 64
local SEAT_AT = 50 / 64
local WAKE_AT = 13 / 64
local DRAW_AT = 6 / 14
local PLATE_TRAVEL = 0.018

-- Samples along the moving metal inlay, in the r01 Blender export coordinates.
local SEAM = {
	Vector3.new(0.568, 0.029, 0.028),
	Vector3.new(0.653, 0.029, 0.021),
	Vector3.new(0.776, 0.029, 0.018),
	Vector3.new(0.903, 0.029, 0.022),
	Vector3.new(0.976, 0.029, 0.031),
}

export type State = {
	motor: Motor6D,
	outward: Vector3,
	scale: number,
	inlay: BasePart,
	inlayColor: Color3,
	inlayMaterial: Enum.Material,
	contacts: BasePart,
	contactColor: Color3,
	contactMaterial: Enum.Material,
	seam: Beam,
	seamHeel: Attachment,
	seamTip: Attachment,
	seamFrame: CFrame,
	light: PointLight,
	edge: Trail,
	core: Trail,
	drawPrev: number?,
	inspectPrev: number?,
	swingPrev: number?,
	releaseSound: AudioController.Handle?,
}

local Arc = {}

local function exportPoint(point: Vector3): Vector3
	return Vector3.new(-point.Y, point.Z, -point.X)
end

local function part(parent: Instance, name: string): BasePart?
	local child = parent:FindFirstChild(name)
	return if child and child:IsA("BasePart") then child else nil
end

local function anchor(parent: BasePart, name: string, p: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = p
	a.Parent = parent
	return a
end

local function ribbon(name: string, heel: Attachment, tip: Attachment, core: boolean): Trail
	local t = Instance.new("Trail")
	t.Name = name
	t.Attachment0 = heel
	t.Attachment1 = tip
	t.Enabled = false
	t.FaceCamera = true
	t.Lifetime = if core then 0.085 else 0.13
	t.MinLength = 0.006
	t.LightEmission = if core then 0.92 else 0.65
	t.LightInfluence = 0
	t.Color = if core then ColorSequence.new(ICE, BLUE) else ColorSequence.new(BLUE, ICE)
	t.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if core then 0.17 else 0.45),
		NumberSequenceKeypoint.new(0.48, if core then 0.62 else 0.76),
		NumberSequenceKeypoint.new(1, 1),
	})
	t.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if core then 0.28 else 0.83),
		NumberSequenceKeypoint.new(1, 0),
	})
	t.Parent = tip
	return t
end

function Arc.new(model: Model, scale: number): State?
	if
		StateValues.get(model, "SkinLine") ~= "Slipframe"
		or StateValues.get(model, "WeaponId") ~= "Knife"
	then
		return nil
	end
	local handle = model.PrimaryPart
	local rig = model:FindFirstChild("Rig")
	local motors = rig and rig:FindFirstChild("Motors")
	local motor = motors and motors:FindFirstChild("ArcPlate")
	local inlay = part(model, "SK_ArcPlate_ArcInlay")
	local contacts = part(model, "SK_Root_ArcContacts")
	if
		not handle
		or not motor
		or not motor:IsA("Motor6D")
		or not motor.Part0
		or not motor.Part1
		or not inlay
		or not contacts
	then
		return nil
	end
	local body, plate = motor.Part0, motor.Part1
	local jointFrame = body.CFrame * motor.C0
	local seamFrame = plate.CFrame:ToObjectSpace(handle.CFrame)
	local seamHeel = anchor(plate, "ArcSweepHeel", Vector3.zero)
	local seamTip = anchor(plate, "ArcSweepTip", Vector3.zero)
	local seam = Instance.new("Beam")
	seam.Name = "ArcInlaySweep"
	seam.Attachment0 = seamHeel
	seam.Attachment1 = seamTip
	seam.Width0 = 0.004 * scale
	seam.Width1 = 0.019 * scale
	seam.FaceCamera = true
	seam.Enabled = false
	seam.LightEmission = 0.93
	seam.LightInfluence = 0
	seam.Color = ColorSequence.new(BLUE, ICE)
	seam.Transparency = NumberSequence.new(0.12, 0.04)
	seam.Parent = seamHeel
	local light = Instance.new("PointLight")
	light.Name = "ArcContactLight"
	light.Color = BLUE
	light.Brightness = 0
	light.Range = 0.85 * scale
	light.Parent = contacts
	local bladeFrame = body.CFrame:ToObjectSpace(handle.CFrame)
	local heel = anchor(
		body,
		"ArcRibbonHeel",
		bladeFrame:PointToWorldSpace(exportPoint(Vector3.new(0.64, 0, -0.142)) * scale)
	)
	local authoredTip = body:FindFirstChild("ArcVisualTip")
	local tip = if authoredTip and authoredTip:IsA("Attachment")
		then authoredTip
		else anchor(
			body,
			"ArcRibbonTip",
			bladeFrame:PointToWorldSpace(exportPoint(Vector3.new(1.271, 0, 0.133)) * scale)
		)
	return {
		motor = motor,
		outward = jointFrame:VectorToObjectSpace(-handle.CFrame.RightVector),
		scale = scale,
		inlay = inlay,
		inlayColor = inlay.Color,
		inlayMaterial = inlay.Material,
		contacts = contacts,
		contactColor = contacts.Color,
		contactMaterial = contacts.Material,
		seam = seam,
		seamHeel = seamHeel,
		seamTip = seamTip,
		seamFrame = seamFrame,
		light = light,
		edge = ribbon("ArcEdgeTrail", heel, tip, false),
		core = ribbon("ArcTrailCore", heel, tip, true),
	}
end

local function between(t: number, first: number, last: number): number
	return Ease.smooth(math.clamp((t - first) / (last - first), 0, 1))
end

local function crossed(t: number?, previous: number?, point: number): boolean
	return t ~= nil and t >= point and (previous == nil or previous < point or previous > t)
end

local function pulse(t: number, start: number, finish: number): number
	return between(t, start, start + 0.055) * (1 - between(t, finish - 0.09, finish))
end

local function point(t: number): Vector3
	local u = math.clamp(t, 0, 1) * (#SEAM - 1)
	local i = math.min(math.floor(u) + 1, #SEAM - 1)
	return exportPoint(SEAM[i]:Lerp(SEAM[i + 1], u - (i - 1)))
end

local function clearRibbon(state: State)
	for _, trail in { state.edge, state.core } do
		trail.Enabled = false
		trail:Clear()
	end
end

function Arc.cancelInspect(state: State)
	state.inspectPrev = nil
	state.motor.Transform = CFrame.identity
	state.inlay.Color = state.inlayColor
	state.inlay.Material = state.inlayMaterial
	state.contacts.Color = state.contactColor
	state.contacts.Material = state.contactMaterial
	state.light.Brightness = 0
	state.seam.Enabled = false
	AudioController.fadeOut(state.releaseSound, 0.06)
	state.releaseSound = nil
end

function Arc.step(
	state: State,
	visible: boolean,
	draw: number?,
	inspect: number?,
	swing: number?,
	hit: number?,
	heavy: boolean
)
	local drawPrev, inspectPrev, swingPrev = state.drawPrev, state.inspectPrev, state.swingPrev
	state.drawPrev, state.inspectPrev, state.swingPrev = draw, inspect, swing
	local swingIn = math.max((hit or 0.34) - (if heavy then 0.22 else 0.16), 0)
	local swingOut = (hit or 0.34) + (if heavy then 0.12 else 0.11)
	local cut = visible and swing ~= nil and swing >= swingIn and swing < swingOut
	if not visible or (cut and not state.edge.Enabled) then
		clearRibbon(state)
	end
	state.edge.Enabled, state.core.Enabled = cut, cut and heavy

	if visible then
		if crossed(draw, drawPrev, DRAW_AT) then
			AudioController.playSound(Audio.arc.draw, "Foley")
		end
		if crossed(inspect, inspectPrev, REVEAL_AT) then
			state.releaseSound = AudioController.playSound(Audio.arc.release, "Foley")
		end
		if crossed(inspect, inspectPrev, SEAT_AT) then
			AudioController.playSound(Audio.arc.seat, "Foley")
		end
		if crossed(swing, swingPrev, swingIn) then
			AudioController.playSound(if heavy then Audio.arc.heavy else Audio.arc.slash, "Gun")
		end
	end

	local reveal = if visible and inspect
		then between(inspect, REVEAL_AT, HOLD_AT) * (1 - between(inspect, CLOSE_AT, SEAT_AT))
		else 0
	state.motor.Transform = CFrame.new(state.outward * (state.scale * PLATE_TRAVEL * reveal))
	local wake, travel = 0, 0
	if visible and draw then
		wake = pulse(draw, DRAW_AT - 0.09, 0.93)
		travel = (draw - 0.31) / 0.56
	elseif visible and inspect then
		wake = pulse(inspect, WAKE_AT, 0.80)
		travel = (inspect - WAKE_AT) / 0.45
	elseif cut and swing then
		wake = 0.7
		travel = (swing - swingIn) / (swingOut - swingIn)
	end
	state.inlay.Color = state.inlayColor:Lerp(ICE, wake)
	state.inlay.Material = if wake > 0.11 then Enum.Material.Neon else state.inlayMaterial
	state.contacts.Color = state.contactColor:Lerp(ICE, reveal)
	state.contacts.Material = if reveal > 0.12 then Enum.Material.Neon else state.contactMaterial
	state.light.Brightness = 0.85 * reveal + 0.32 * wake
	state.seam.Enabled = wake > 0.08 and travel > 0 and travel < 1.3
	if state.seam.Enabled then
		state.seamHeel.Position =
			state.seamFrame:PointToWorldSpace(point(travel - 0.29) * state.scale)
		state.seamTip.Position = state.seamFrame:PointToWorldSpace(point(travel) * state.scale)
	end
end

return Arc
