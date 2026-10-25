--!strict
-- First-person arms dressed as the player (Gunplay.md §6). Normally these are
-- copies of the player's own R15 arm meshes (upper arm, lower arm, hand) in a
-- small model with a Humanoid and a copy of their Shirt, so Roblox composites
-- the clothing onto them exactly like on the avatar. R6 avatars get blocky
-- arms with the shirt template cropped onto each face instead.
--
-- Each segment is placed from its rig attachments: the upper arm runs from
-- its shoulder to its elbow attachment, the lower arm from elbow to wrist and
-- the hand from wrist to grip, solved with two-bone IK so the grip attachment
-- sits on the gun's grip.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VM = require(ReplicatedStorage.Shared.Config.Viewmodel)

export type Side = "Right" | "Left"

-- A part posed along a bone: `prox`/`dist` are its joint points in part space.
type Segment = { part: BasePart, prox: Vector3, dist: Vector3, rest: CFrame }

export type Arm = {
	upper: Segment,
	lower: Segment,
	hand: Segment,
	l1: number, -- shoulder → elbow
	l2: number, -- elbow → wrist
	lh: number, -- wrist → grip
}

export type Arms = {
	model: Model,
	sides: { [Side]: Arm },
	parts: { BasePart },
	cframes: { CFrame },
}

local ViewmodelArms = {}

local SEGMENTS = { "UpperArm", "LowerArm", "Hand" }

-- The attachment pairs that define each R15 segment's bone.
local function boneNames(side: Side): { { string } }
	return {
		{ side .. "ShoulderRigAttachment", side .. "ElbowRigAttachment" },
		{ side .. "ElbowRigAttachment", side .. "WristRigAttachment" },
		{ side .. "WristRigAttachment", side .. "GripAttachment" },
	}
end

-- Rest frame of a bone in part space: Y from the distal to the proximal
-- joint, X as close to the part's own X (the character's right) as possible.
local function restFrame(prox: Vector3, dist: Vector3): CFrame
	local y = (prox - dist).Unit
	local x = Vector3.xAxis - y * y.X
	if x.Magnitude < 1e-4 then
		x = Vector3.zAxis - y * y.Z
	end
	x = x.Unit
	return CFrame.fromMatrix(prox, x, y, x:Cross(y)):Inverse()
end

local function segment(part: BasePart, prox: Vector3, dist: Vector3): Segment
	return { part = part, prox = prox, dist = dist, rest = restFrame(prox, dist) }
end

local function prepare(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.LocalTransparencyModifier = 0
end

local function shirtTemplate(character: Model?): string
	local shirt = character and character:FindFirstChildOfClass("Shirt")
	return if shirt then shirt.ShirtTemplate else ""
end

-- What the arms depend on; rebuild when it changes (appearance loads late).
function ViewmodelArms.signature(character: Model?): string
	local out = { shirtTemplate(character) }
	if character then
		for _, side in { "Right", "Left" } do
			for _, name in SEGMENTS do
				local p = character:FindFirstChild(side .. name)
				if p and p:IsA("BasePart") then
					table.insert(out, p.Color:ToHex())
					if p:IsA("MeshPart") then
						table.insert(out, p.MeshId)
					end
				end
			end
			local r6 = character:FindFirstChild(side .. " Arm")
			if r6 and r6:IsA("BasePart") then
				table.insert(out, r6.Color:ToHex())
			end
		end
	end
	return table.concat(out, "|")
end

-- The player's own R15 arms, normalised in size (see below).
local function buildR15(character: Model, model: Model): { [Side]: Arm }?
	local sides: { [Side]: Arm } = {}
	for _, side: Side in { "Right", "Left" } :: { Side } do
		local names = boneNames(side)
		local sources: { BasePart } = {}
		local points: { { Vector3 } } = {}
		for i, name in SEGMENTS do
			local src = character:FindFirstChild(side .. name)
			if not src or not src:IsA("BasePart") then
				return nil
			end
			local a = src:FindFirstChild(names[i][1])
			local b = src:FindFirstChild(names[i][2])
			if not a or not a:IsA("Attachment") or not b or not b:IsA("Attachment") then
				return nil
			end
			sources[i] = src
			points[i] = { a.Position, b.Position }
		end
		-- Avatar arm packages vary a lot in size, so normalise: the hand to a
		-- set wrist → grip length, the arm to a set thickness, and the upper
		-- and lower arm lengths so the whole arm spans ARM_REACH.
		local armRaw = (points[1][1] - points[1][2]).Magnitude
			+ (points[2][1] - points[2][2]).Magnitude
		local handRaw = (points[3][1] - points[3][2]).Magnitude
		local thickRaw = math.min(sources[2].Size.X, sources[2].Size.Z)
		if armRaw < 1e-3 or handRaw < 1e-3 or thickRaw < 1e-3 then
			return nil
		end
		local lengthScale = (VM.ARM_REACH - VM.HAND_LENGTH) / armRaw
		local widthScale = VM.ARM_THICKNESS / thickRaw
		local armScale = Vector3.new(widthScale, lengthScale, widthScale)
		local handScale = Vector3.one * (VM.HAND_LENGTH / handRaw)
		local segs: { Segment } = {}
		for i, src in sources do
			local partScale = if i == 3 then handScale else armScale
			local p = src:Clone()
			for _, child in p:GetChildren() do
				child:Destroy() -- joints, wraps, scale values: none needed here
			end
			p.Size = src.Size * partScale
			prepare(p)
			p.Parent = model
			segs[i] = segment(p, points[i][1] * partScale, points[i][2] * partScale)
		end
		sides[side] = {
			upper = segs[1],
			lower = segs[2],
			hand = segs[3],
			l1 = (segs[1].prox - segs[1].dist).Magnitude,
			l2 = (segs[2].prox - segs[2].dist).Magnitude,
			lh = (segs[3].prox - segs[3].dist).Magnitude,
		}
	end
	return sides
end

-- R6 fallback: blocky segments with the shirt template cropped onto each face
-- (Decal UVScale/UVOffset), over the avatar's arm colour.
local SHIRT_FACES: { [string]: Enum.NormalId } = {
	F = Enum.NormalId.Front,
	B = Enum.NormalId.Back,
	R = Enum.NormalId.Right,
	L = Enum.NormalId.Left,
	U = Enum.NormalId.Top,
	D = Enum.NormalId.Bottom,
}

local function dress(part: BasePart, side: Side, template: string, a: number, b: number)
	local faces = VM.SHIRT_FACES[side]
	local image = VM.SHIRT_SIZE
	for faceKey, normal in SHIRT_FACES do
		local origin = faces[faceKey]
		local y0, h = origin.Y + a * 128, (b - a) * 128
		if faceKey == "U" or faceKey == "D" then
			if (faceKey == "U" and a > 0) or (faceKey == "D" and b < 1) then
				continue
			end
			y0, h = origin.Y, 64
		end
		local decal = Instance.new("Decal")
		decal.Face = normal
		decal.Texture = template
		decal.UVScale = Vector2.new(64 / image.X, h / image.Y)
		decal.UVOffset = Vector2.new(origin.X / image.X, y0 / image.Y)
		decal.Parent = part
	end
end

local function armColor(character: Model?, side: Side): Color3
	local r6 = character and character:FindFirstChild(side .. " Arm")
	if r6 and r6:IsA("BasePart") then
		return r6.Color
	end
	local colors = character and character:FindFirstChildOfClass("BodyColors")
	if colors then
		return if side == "Right" then colors.RightArmColor3 else colors.LeftArmColor3
	end
	return Color3.fromRGB(234, 184, 146)
end

local function buildBlocks(character: Model?, model: Model): { [Side]: Arm }
	local template = shirtTemplate(character)
	local reach = VM.ARM_REACH
	local lengths = { reach * 0.47, reach * 0.4, reach * 0.13 }
	local split = { 0, 0.45, 0.82, 1 }
	local w = reach * 0.13
	local sides: { [Side]: Arm } = {}
	for _, side: Side in { "Right", "Left" } :: { Side } do
		local segs: { Segment } = {}
		for i, len in lengths do
			local p = Instance.new("Part")
			p.Name = side .. SEGMENTS[i]
			p.Size = Vector3.new(w, len, w)
			p.Material = Enum.Material.SmoothPlastic
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Color = armColor(character, side)
			prepare(p)
			if template ~= "" then
				dress(p, side, template, split[i], split[i + 1])
			end
			p.Parent = model
			segs[i] = segment(p, Vector3.new(0, len / 2, 0), Vector3.new(0, -len / 2, 0))
		end
		sides[side] = {
			upper = segs[1],
			lower = segs[2],
			hand = segs[3],
			l1 = lengths[1],
			l2 = lengths[2],
			lh = lengths[3],
		}
	end
	return sides
end

function ViewmodelArms.build(character: Model?): Arms
	local model = Instance.new("Model")
	model.Name = "ViewmodelArms"
	local humanoid = Instance.new("Humanoid")
	-- R15, so the Shirt composites onto the arm meshes; inert otherwise.
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.EvaluateStateMachine = false
	humanoid.Parent = model

	local sides = if character then buildR15(character, model) else nil
	if not sides then
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") then
				child:Destroy()
			end
		end
		sides = buildBlocks(character, model)
		humanoid:Destroy()
	else
		local shirt = character and character:FindFirstChildOfClass("Shirt")
		if shirt then
			shirt:Clone().Parent = model
		end
	end

	local parts: { BasePart } = {}
	for _, side: Side in { "Right", "Left" } :: { Side } do
		local arm = (sides :: { [Side]: Arm })[side]
		table.insert(parts, arm.upper.part)
		table.insert(parts, arm.lower.part)
		table.insert(parts, arm.hand.part)
	end
	return {
		model = model,
		sides = sides :: { [Side]: Arm },
		parts = parts,
		cframes = table.create(#parts),
	}
end

function ViewmodelArms.setVisible(arms: Arms, visible: boolean)
	local m = if visible then 0 else 1
	for _, d in arms.model:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = m
		end
	end
end

-- The part's CFrame that lays segment `s` from world point `from` (its
-- proximal joint) toward `to`, with its X axis on `hinge`.
local function place(s: Segment, from: Vector3, to: Vector3, hinge: Vector3, twist: number?): CFrame
	local y = from - to
	y = if y.Magnitude > 1e-5 then y.Unit else Vector3.yAxis
	local x = hinge - y * hinge:Dot(y)
	if x.Magnitude < 1e-4 then
		x = y:Cross(Vector3.zAxis)
	end
	x = x.Unit
	local frame = CFrame.fromMatrix(from, x, y, x:Cross(y))
	if twist and twist ~= 0 then
		frame *= CFrame.Angles(0, twist, 0) -- roll around the bone
	end
	return frame * s.rest
end

-- Two-bone IK for one arm: shoulder → elbow → wrist, hand's grip point on `grip`.
-- `hint` is the direction the elbow should bend toward. Writes the three part
-- CFrames into arms.cframes at `index`..`index + 2`.
function ViewmodelArms.solve(
	arms: Arms,
	side: Side,
	index: number,
	shoulder: Vector3,
	grip: Vector3,
	hint: Vector3
)
	local arm = arms.sides[side]
	local l1, l2 = arm.l1, arm.l2 + arm.lh -- forearm bone runs to the grip point
	local toGrip = grip - shoulder
	local d = toGrip.Magnitude
	if d < 1e-3 then
		return
	end
	-- Out of reach: the (off-screen) shoulder slides forward instead of the
	-- hand letting go of the gun.
	local reach = (l1 + l2) * 0.995
	if d > reach then
		shoulder += toGrip.Unit * (d - reach)
		toGrip = grip - shoulder
		d = reach
	end
	d = math.max(d, math.abs(l1 - l2) + 0.02)
	local dir = toGrip.Unit
	local cosA = math.clamp((l1 * l1 + d * d - l2 * l2) / (2 * l1 * d), -1, 1)
	local sinA = math.sqrt(1 - cosA * cosA)
	local pole = hint - dir * hint:Dot(dir)
	if pole.Magnitude < 1e-4 then
		pole = Vector3.xAxis - dir * dir.X
	end
	pole = pole.Unit
	local elbow = shoulder + dir * (l1 * cosA) + pole * (l1 * sinA)
	local hinge = pole:Cross(dir)
	local forearm = grip - elbow
	local forearmDir = if forearm.Magnitude > 1e-4 then forearm.Unit else dir
	local wrist = grip - forearmDir * arm.lh

	local cframes = arms.cframes
	cframes[index] = place(arm.upper, shoulder, elbow, hinge)
	cframes[index + 1] = place(arm.lower, elbow, wrist, hinge)
	cframes[index + 2] = place(arm.hand, wrist, grip, hinge, twist)
end

-- Moves all arm parts to the CFrames written by `solve`.
function ViewmodelArms.apply(arms: Arms)
	if #arms.cframes == #arms.parts then
		Workspace:BulkMoveTo(arms.parts, arms.cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

return ViewmodelArms
