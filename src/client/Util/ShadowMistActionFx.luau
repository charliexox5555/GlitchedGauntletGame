--!strict
-- Short-lived seafoam arcs and flares for the viewmodel's handling beats.
local Shared = game:GetService("ReplicatedStorage").Shared
local Style = require(Shared.Config.SkinPreview).SHADOW_MIST
local VFX = require(Shared.Config.VfxTextures)
local Kit = require(script.Parent.ShotFxKit)

type Ring = {
	first: Attachment,
	last: Attachment,
	beam: Beam,
	rim: Beam,
	anchor: Attachment,
	centerOffset: Vector3,
	radius: number,
	phase: number,
	vertical: boolean,
}

export type Node = {
	rings: { Ring },
	haze: ParticleEmitter,
	grit: ParticleEmitter,
	lamp: PointLight,
}

local ActionFx = {}

local function ring(
	anchor: Attachment,
	parent: BasePart,
	center: Vector3,
	radius: number,
	phase: number,
	vertical: boolean
): Ring
	local first = Instance.new("Attachment")
	first.Name = "ShadowMistArcStart"
	first.Parent = parent
	local last = Instance.new("Attachment")
	last.Name = "ShadowMistArcEnd"
	last.Parent = parent
	local beam = Instance.new("Beam")
	beam.Name = "ShadowMistActionArc"
	beam.Attachment0 = first
	beam.Attachment1 = last
	beam.Texture = VFX.FROST_VAPOR
	beam.TextureSpeed = 0
	beam.TextureMode = Enum.TextureMode.Stretch
	beam.Color = ColorSequence.new(Color3.fromRGB(29, 99, 87), Style.SHOT_TINT)
	beam.LightEmission = 0.78
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Brightness = 1.6
	beam.Segments = 12
	beam.Enabled = false
	beam.Parent = first
	local rim = beam:Clone()
	rim.Name = "ShadowMistArcEdge"
	rim.Attachment0, rim.Attachment1 = first, last
	rim.Texture = VFX.HEALORB_RIBBON
	rim.Color = ColorSequence.new(Style.SHOT_TINT, Color3.fromRGB(166, 255, 225))
	rim.LightEmission = 0.92
	rim.Brightness = 2.15
	rim.Parent = first
	return {
		first = first,
		last = last,
		beam = beam,
		rim = rim,
		anchor = anchor,
		centerOffset = center - anchor.Position,
		radius = radius,
		phase = phase,
		vertical = vertical,
	}
end

function ActionFx.new(anchor: Attachment, scale: number, size: number, vertical: boolean): Node
	local parent = anchor.Parent :: BasePart
	local p = anchor.Position
	local center = if vertical
		then Vector3.new(
			p.X,
			if anchor.Name == "ShadowMistChannel" then p.Y else 0,
			p.Z + 0.09 * scale
		)
		else Vector3.new(p.X, 0, p.Z - 0.045 * scale)
	local radius = size * scale
	local haze = Kit.emitter(anchor, VFX.MOD_GLOW, Style.SHOT_TINT)
	haze.Name = "ShadowMistActionBloom"
	haze.LightInfluence = 0
	haze.LightEmission = 0.66
	haze.LockedToPart = true
	haze.Lifetime = NumberRange.new(0.16, 0.28)
	haze.Rotation = NumberRange.new(0)
	haze.Size = Kit.curve({ 0, 0.17 * scale, 0.24, 0.53 * scale, 1, 0.78 * scale })
	haze.Transparency = Kit.curve({ 0, 0.25, 0.36, 0.58, 1, 1 })
	local grit = Kit.sparkEmitter(anchor, 0.035 * scale)
	grit.Name = "ShadowMistActionSparks"
	grit.Color = ColorSequence.new(Color3.fromRGB(173, 255, 224), Color3.fromRGB(30, 111, 98))
	grit.Speed = NumberRange.new(0.5 * scale, 2.0 * scale)
	grit.SpreadAngle = Vector2.new(46, 46)
	grit.EmissionDirection = Enum.NormalId.Back
	grit.Lifetime = NumberRange.new(0.13, 0.35)
	grit.Drag = 3.2
	grit.LockedToPart = true
	local lamp = Instance.new("PointLight")
	lamp.Name = "ShadowMistActionLight"
	lamp.Color = Style.SHOT_TINT
	lamp.Range = 1.44 * scale
	lamp.Shadows = false
	lamp.Enabled = false
	lamp.Parent = anchor
	return {
		rings = {
			ring(anchor, parent, center, radius, 0, vertical),
			ring(anchor, parent, center, radius * 0.86, math.pi, vertical),
		},
		haze = haze,
		grit = grit,
		lamp = lamp,
	}
end

function ActionFx.pop(node: Node?, sparks: number)
	if node then
		node.haze:Emit(1)
		node.grit:Emit(sparks)
	end
end

local function endpoint(item: Ring, socket: Attachment, angle: number, r: number, lead: number)
	local c, s = math.cos(angle), math.sin(angle)
	local position = if item.vertical
		then Vector3.new(r * c, r * s, lead)
		else Vector3.new(lead, r * c, r * s)
	local tangent = if item.vertical then Vector3.new(-s, c, 0) else Vector3.new(0, -s, c)
	local up = if item.vertical then Vector3.zAxis else Vector3.xAxis
	socket.CFrame =
		CFrame.fromMatrix(item.anchor.Position + item.centerOffset + position, tangent.Unit, up)
end

function ActionFx.step(node: Node?, clock: number, strength: number, spread: number, flash: number)
	if not node then
		return
	end
	node.lamp.Enabled = strength > 0.02 or flash > 0.02
	if node.lamp.Enabled then
		node.lamp.Brightness = strength * 1.75 + flash * 2.75
	end
	node.grit.Enabled = strength > 0.38
	node.grit.Rate = if node.grit.Enabled then strength * 3.5 else 0
	for _, item in node.rings do
		local beam = item.beam
		local rim = item.rim
		beam.Enabled = strength > 0.035
		rim.Enabled = beam.Enabled
		if beam.Enabled then
			local angle = clock * 7.2 + item.phase
			local r = item.radius * (0.76 + 0.42 * strength + 0.49 * spread)
			local lead = r * 0.25
			endpoint(item, item.first, angle, r, -lead)
			endpoint(item, item.last, angle + 1.85, r, lead)
			beam.CurveSize0 = r * 0.68
			beam.CurveSize1 = r * 0.68
			beam.Width0 = r * (0.18 + 0.40 * strength)
			beam.Width1 = beam.Width0 * 0.60
			local fade = 1 - math.min(strength, 1) * 0.70
			beam.Transparency =
				Kit.curve({ 0, 1, 0.26, math.min(1, fade + 0.055), 0.66, fade, 1, 1 })
			rim.CurveSize0, rim.CurveSize1 = beam.CurveSize0, beam.CurveSize1
			rim.Width0, rim.Width1 = beam.Width0 * 0.38, beam.Width1 * 0.37
			rim.Transparency =
				Kit.curve({ 0, 1, 0.18, 1 - strength * 0.83, 0.63, 1 - strength * 0.69, 1, 1 })
		end
	end
end

function ActionFx.clear(node: Node?)
	if node then
		node.haze:Clear()
		node.grit:Clear()
	end
end

return ActionFx
