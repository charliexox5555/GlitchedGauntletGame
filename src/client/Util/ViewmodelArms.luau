--!strict
-- First-person arms, RIVALS style (Gunplay.md §6): each arm is one long,
-- softly bevelled block (R6 cross-section) that comes up from off-screen and
-- ends at the gun's grip; the end of the block is the hand. Skin colour from
-- the avatar; if they wear a classic Shirt, a second, slightly larger copy of
-- the block carries the shirt texture (the mesh's UVs sit on the template's
-- arm faces, like Roblox draws shirts on R6 arms; transparent template areas
-- show the skin underneath). Mesh: tools/blender/make_arm_mesh.py.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local VM = require(ReplicatedStorage.Shared.Config.Viewmodel)

export type Side = "Right" | "Left"

type Arm = { base: BasePart, overlay: BasePart }

export type Arms = {
	model: Model,
	sides: { [Side]: Arm },
	parts: { BasePart },
	cframes: { CFrame },
	shirt: boolean,
	depth: number, -- current depth push (mesh scale follows it)
}

local ViewmodelArms = {}

local function shirtTemplate(character: Model?): string
	local shirt = character and character:FindFirstChildOfClass("Shirt")
	return if shirt then shirt.ShirtTemplate else ""
end

-- Skin colour of one arm: the avatar's own arm part, else BodyColors.
local function armColor(character: Model?, side: Side): Color3
	if character then
		for _, name in { side .. "LowerArm", side .. " Arm", side .. "UpperArm" } do
			local p = character:FindFirstChild(name)
			if p and p:IsA("BasePart") then
				return p.Color
			end
		end
		local colors = character:FindFirstChildOfClass("BodyColors")
		if colors then
			return if side == "Right" then colors.RightArmColor3 else colors.LeftArmColor3
		end
	end
	return Color3.fromRGB(234, 184, 146)
end

-- What the arms depend on; rebuild when it changes (appearance loads late).
function ViewmodelArms.signature(character: Model?): string
	return table.concat({
		shirtTemplate(character),
		armColor(character, "Right"):ToHex(),
		armColor(character, "Left"):ToHex(),
	}, "|")
end

local function block(
	name: string,
	side: Side,
	scale: number,
	color: Color3,
	texture: string,
	parent: Instance
): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.one * 0.2 -- the mesh draws at its own scale
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = VM.ARM_MESH[side]
	mesh.TextureId = texture
	mesh.Scale = Vector3.one * scale
	mesh.Parent = p
	p.Parent = parent
	return p
end

function ViewmodelArms.build(character: Model?): Arms
	local model = Instance.new("Model")
	model.Name = "ViewmodelArms"
	local template = shirtTemplate(character)
	local width = VM.ARM_WIDTH / VM.ARM_MESH_SIZE.X
	local sides: { [Side]: Arm } = {}
	local parts: { BasePart } = {}
	for _, side: Side in { "Right", "Left" } :: { Side } do
		local base = block(side .. "Arm", side, width, armColor(character, side), "", model)
		local overlay = block(
			side .. "Sleeve",
			side,
			width * VM.SLEEVE_INFLATE,
			Color3.new(1, 1, 1),
			template,
			model
		)
		overlay.Transparency = if template ~= "" then 0 else 1
		sides[side] = { base = base, overlay = overlay }
		table.insert(parts, base)
		table.insert(parts, overlay)
	end
	return {
		model = model,
		sides = sides,
		parts = parts,
		cframes = table.create(#parts, CFrame.identity),
		shirt = template ~= "",
		depth = 1,
	}
end

function ViewmodelArms.setVisible(arms: Arms, visible: boolean)
	local m = if visible then 0 else 1
	for _, p in arms.parts do
		p.LocalTransparencyModifier = m
	end
end

-- Lays one arm from `shoulder` (any point further along the arm, off-screen)
-- down to `grip`: the block's hand end sits just past the grip. `right` sets
-- the block's roll (its X axis is the character's right). The block is then
-- pushed `depth` times further from `eye` and drawn that much bigger, so it
-- looks the same on screen but sits behind the gun (1 = no push). Writes both
-- parts' CFrames at `index`.
function ViewmodelArms.solve(
	arms: Arms,
	index: number,
	shoulder: Vector3,
	grip: Vector3,
	right: Vector3,
	eye: Vector3,
	depth: number
)
	local up = shoulder - grip
	if up.Magnitude < 1e-4 then
		return
	end
	up = up.Unit
	local x = right - up * right:Dot(up)
	if x.Magnitude < 1e-4 then
		x = up:Cross(Vector3.zAxis)
	end
	x = x.Unit
	local length = VM.ARM_WIDTH / VM.ARM_MESH_SIZE.X * VM.ARM_MESH_SIZE.Y
	-- The hand end overshoots the grip a little so the grip sits in the "palm".
	local center = grip + up * (length / 2 - VM.ARM_WIDTH * VM.HAND_OVERSHOOT)
	center = eye + (center - eye) * depth
	local cf = CFrame.fromMatrix(center, x, up, x:Cross(up))
	arms.cframes[index] = cf
	arms.cframes[index + 1] = cf
	if depth ~= arms.depth then
		arms.depth = depth
		local width = VM.ARM_WIDTH / VM.ARM_MESH_SIZE.X * depth
		for _, p in arms.parts do
			local mesh = p:FindFirstChildOfClass("SpecialMesh")
			if mesh then
				local inflate = if p.Name:find("Sleeve") then VM.SLEEVE_INFLATE else 1
				mesh.Scale = Vector3.one * width * inflate
			end
		end
	end
end

-- Moves all arm parts to the CFrames written by `solve`.
function ViewmodelArms.apply(arms: Arms)
	Workspace:BulkMoveTo(arms.parts, arms.cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

return ViewmodelArms
