--!strict
-- Client-only presentation of the authoritative overtime radius.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Z = require(ReplicatedStorage.Shared.Config.Juice).ZONE
local Textures = require(ReplicatedStorage.Shared.Config.VfxTextures)

local OvertimeZoneVfx = {}

type Meshes = { curtain: MeshPart, trace: MeshPart, drift: MeshPart }
type Spark = { point: Attachment, emitter: ParticleEmitter }
export type Visual = {
	root: Folder,
	meshes: Meshes?,
	fallback: { Attachment }?,
	sparks: { Spark },
}

local function prepare(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

local function meshSet(parent: Folder): Meshes?
	local templates = ReplicatedStorage:FindFirstChild("OvertimeZoneMeshes")
	local curtain = templates and templates:FindFirstChild("Curtain", true)
	local trace = templates and templates:FindFirstChild("GroundTrace", true)
	local drift = templates and templates:FindFirstChild("Drift", true)
	if
		not (
			curtain
			and curtain:IsA("MeshPart")
			and curtain:FindFirstChildOfClass("SurfaceAppearance")
			and trace
			and trace:IsA("MeshPart")
			and drift
			and drift:IsA("MeshPart")
		)
	then
		return nil
	end
	local walls = { curtain = curtain:Clone(), trace = trace:Clone(), drift = drift:Clone() }
	for _, part in walls do
		prepare(part)
		part.Parent = parent
	end
	local surface = walls.curtain:FindFirstChildOfClass("SurfaceAppearance")
	if surface then
		surface.Color = Z.color
	end
	walls.trace.Color = Z.edgeColor
	walls.drift.Color = Z.glitchColor
	return walls
end

-- A single layer keeps overtime readable while mesh content is unavailable.
local function fallbackWall(parent: BasePart): { Attachment }
	local points: { Attachment } = {}
	for i = 1, Z.fallbackSegments do
		local point = Instance.new("Attachment")
		point.Parent = parent
		points[i] = point
	end
	for i, point in points do
		local panel = Instance.new("Beam")
		panel.Attachment0 = point
		panel.Attachment1 = points[i % #points + 1]
		panel.Segments = 1
		panel.Width0 = Z.height
		panel.Width1 = Z.height
		panel.Texture = Textures.ZONE_WALL
		panel.TextureMode = Enum.TextureMode.Stretch
		panel.TextureSpeed = 0.13
		panel.Color = ColorSequence.new(Z.color)
		panel.Transparency = NumberSequence.new(0.38)
		panel.LightEmission = 0.85
		panel.LightInfluence = 0
		panel.Parent = parent
	end
	return points
end

local function makeSparks(parent: BasePart): { Spark }
	local sparks: { Spark } = {}
	for i = 1, Z.sparkEmitters do
		local point = Instance.new("Attachment")
		point.Name = "EdgeSparks"
		point.Parent = parent
		local emitter = Instance.new("ParticleEmitter")
		emitter.Enabled = false
		emitter.Texture = Textures.SPARK
		emitter.Color = ColorSequence.new(Z.edgeColor, Z.glitchColor)
		emitter.LightEmission = 0.85
		emitter.LightInfluence = 0
		emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.SpreadAngle = Vector2.new(18, 18)
		emitter.Lifetime = NumberRange.new(0.25, 0.66)
		emitter.Speed = NumberRange.new(5, 9)
		emitter.Drag = 2
		emitter.Rate = 5
		emitter.Size = NumberSequence.new(0.23, 0.06)
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.3, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Parent = point
		sparks[i] = { point = point, emitter = emitter }
	end
	return sparks
end

function OvertimeZoneVfx.new(): Visual
	local root = Instance.new("Folder")
	root.Name = "OvertimeZoneVisuals"
	local anchor = Instance.new("Part")
	anchor.Name = "EffectAnchor"
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.identity
	prepare(anchor)
	anchor.Parent = root
	local meshes = meshSet(root)
	return {
		root = root,
		meshes = meshes,
		fallback = if meshes then nil else fallbackWall(anchor),
		sparks = makeSparks(anchor),
	}
end

local function radial(centre: Vector3, radius: number, angle: number, y: number): Vector3
	return Vector3.new(centre.X + math.cos(angle) * radius, y, centre.Z + math.sin(angle) * radius)
end

function OvertimeZoneVfx.draw(visual: Visual, centre: Vector3, radius: number, age: number)
	local midHeight = centre.Y + Z.height / 2 - Z.below
	local mesh = visual.meshes
	local fallback = visual.fallback
	if mesh then
		local diameter = 2 * radius
		mesh.curtain.Size = Vector3.new(diameter, Z.height, diameter)
		mesh.curtain.CFrame = CFrame.new(centre.X, midHeight, centre.Z)
			* CFrame.Angles(0, age * 0.065, 0)
		-- Keep the trace inside the curtain so the outer side cannot z-fight.
		local traceDiameter = diameter * 0.996
		mesh.trace.Size = Vector3.new(traceDiameter, 0.26, traceDiameter)
		mesh.trace.CFrame = CFrame.new(centre + Vector3.yAxis * 0.18)
		mesh.trace.Transparency = 0.13 + 0.09 * math.sin(age * 2.1)
		local driftDiameter = diameter * 1.025
		local driftHeight = math.clamp(radius * 0.23, 3.1, 13)
		mesh.drift.Size = Vector3.new(driftDiameter, driftHeight, driftDiameter)
		mesh.drift.CFrame = CFrame.new(
			centre + Vector3.yAxis * (driftHeight * 0.55 + 0.35 * math.sin(age * 1.1))
		) * CFrame.Angles(0, -age * 0.18, 0)
		mesh.drift.Transparency = 0.48 + 0.13 * math.sin(age * 2.8)
	elseif fallback then
		for i, point in fallback do
			local angle = (i - 1) * math.pi * 2 / #fallback
			point.Position = radial(centre, radius, angle, midHeight)
		end
	end
end

function OvertimeZoneVfx.sparksNear(visual: Visual, centre: Vector3, radius: number, eye: Vector3)
	local offset = eye - centre
	local angle = math.atan2(offset.Z, offset.X)
	local distance = math.abs(Vector2.new(offset.X, offset.Z).Magnitude - radius)
	local on = distance < Z.sparkDistance
	local stride = math.min(3 / radius, 0.42)
	for i, spark in visual.sparks do
		if spark.emitter.Enabled ~= on then
			spark.emitter.Enabled = on
		end
		if on then
			local a = angle + (i - (#visual.sparks + 1) / 2) * stride
			local y =
				math.clamp(eye.Y - 3.25, centre.Y - Z.below, centre.Y + Z.height - Z.below - 3)
			spark.point.Position = radial(centre, radius + 0.16, a, y)
		end
	end
end

return OvertimeZoneVfx
