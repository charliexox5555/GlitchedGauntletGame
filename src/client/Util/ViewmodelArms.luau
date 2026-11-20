--!strict
-- First-person arms, RIVALS style (Gunplay.md §6): each arm is one long,
-- sturdy block (R6 cross-section, small bevels) that comes up from off-screen
-- and ends at the gun's grip; the end of the block is the hand. Three layers
-- per arm, all the same block (tools/blender/make_arm_mesh.py):
--   skin     the avatar's own arm colour. With no classic Shirt this is all
--            you see: a plain skin-coloured block.
--   sleeve   only if the avatar wears a classic Shirt: a slightly fatter copy
--            carrying the shirt texture (the mesh's UVs sit on the template's
--            arm faces, like Roblox draws shirts on R6 arms). It starts
--            VM.ARM_SLEEVE.bare studs up from the hand end, so the hand and
--            wrist stay skin and the sleeve's end reads as a cuff.
--   outline  the block turned inside out, a hair larger, near-black: from
--            outside only its far faces draw, as a thin dark rim round the
--            hand (VM.ARM_OUTLINE; rim 0 turns it off).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VM = require(ReplicatedStorage.Shared.Config.Viewmodel)

export type Side = "Right" | "Left"

type Arm = { base: BasePart, overlay: BasePart, outline: BasePart }

export type Arms = {
	-- A WorldModel, not a plain Model: under Server Authority the Workspace
	-- snaps part positions to a coarse grid (up to ~0.006 studs, depending on
	-- where you stand), which made each viewmodel part jitter on its own. A
	-- WorldModel keeps exact positions and still renders under the Camera.
	model: WorldModel,
	sides: { [Side]: Arm },
	-- RightArm, RightSleeve, RightOutline, LeftArm, LeftSleeve, LeftOutline
	parts: { BasePart },
	cframes: { CFrame }, -- where `place` put each part this frame
	shirt: boolean,
}

local LAYERS = 3 -- parts per arm, in the order above

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
	meshId: string,
	scale: number,
	color: Color3,
	texture: string,
	parent: Instance,
	rim: number?
): BasePart
	local p = Instance.new("Part")
	p.Name = name
	-- The mesh draws at its own scale; the part's size only sets the bounds
	-- the renderer culls by. A tiny part was culled whenever its centre went
	-- behind the camera, so an arm reaching toward the camera vanished.
	-- Stretched along its length (VM.ARM_LENGTH_SCALE) so the cut end of the
	-- arm stays off-screen in wide moves (knife slashes, inspects).
	-- `rim` (the outline): this many studs larger all round instead of a
	-- uniform scale, which would stick out much further at the two ends of a
	-- long block than at its sides.
	local length = scale * VM.ARM_LENGTH_SCALE
	local stretch = Vector3.new(scale, length, scale)
	if rim then
		local size = VM.ARM_MESH_SIZE
		stretch = Vector3.new(
			scale + 2 * rim / size.X,
			length + 2 * rim / size.Y,
			scale + 2 * rim / size.Z
		)
	end
	p.Size = VM.ARM_MESH_SIZE * stretch
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
	mesh.MeshId = meshId
	mesh.TextureId = texture
	mesh.Scale = stretch
	mesh.Parent = p
	p.Parent = parent
	return p
end

function ViewmodelArms.build(character: Model?): Arms
	local model = Instance.new("WorldModel")
	model.Name = "ViewmodelArms"
	local template = shirtTemplate(character)
	local width = VM.ARM_WIDTH / VM.ARM_MESH_SIZE.X
	local sides: { [Side]: Arm } = {}
	local parts: { BasePart } = {}
	for _, side: Side in { "Right", "Left" } :: { Side } do
		local skin = armColor(character, side)
		local base = block(side .. "Arm", VM.ARM_MESH[side], width, skin, "", model)
		-- The sleeve's own colour is the skin too: where the engine draws the
		-- template's clear areas in the part's colour, it's skin that shows.
		local overlay = block(
			side .. "Sleeve",
			VM.ARM_MESH[side],
			width * VM.ARM_SLEEVE.inflate,
			skin,
			template,
			model
		)
		overlay.Transparency = if template ~= "" then 0 else 1
		local rim = VM.ARM_OUTLINE.rim
		local outline = block(
			side .. "Outline",
			VM.ARM_OUTLINE.mesh[side],
			width,
			VM.ARM_OUTLINE.color,
			"",
			model,
			math.max(rim, 0)
		)
		outline.Transparency = if rim > 0 then VM.ARM_OUTLINE.transparency else 1
		sides[side] = { base = base, overlay = overlay, outline = outline }
		table.insert(parts, base)
		table.insert(parts, overlay)
		table.insert(parts, outline)
	end
	return {
		model = model,
		sides = sides,
		parts = parts,
		cframes = table.create(#parts, CFrame.identity),
		shirt = template ~= "",
	}
end

function ViewmodelArms.setVisible(arms: Arms, visible: boolean)
	local m = if visible then 0 else 1
	for _, p in arms.parts do
		p.LocalTransparencyModifier = m
	end
end

-- Moves both arms to where `place` put them.
function ViewmodelArms.apply(arms: Arms)
	arms.model:BulkMoveTo(arms.parts, arms.cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Lays one arm along the line from `hand` toward `toward` (any point further
-- up the arm, off-screen): the block's hand end sits just past `hand`, so the
-- grip is in its "palm". `right` sets the block's roll (its X axis is the
-- character's right). Writes every layer's CFrame into `arms.cframes`; `apply`
-- moves them, in the same render step as the gun.
-- Where `place` last put `side`'s hand (world), and the arm's direction up
-- from it; nil before it was placed.
function ViewmodelArms.handOf(arms: Arms, side: Side): (Vector3?, Vector3?)
	local cf = arms.cframes[if side == "Right" then 1 else 1 + LAYERS]
	if not cf then
		return nil, nil
	end
	local length = VM.ARM_WIDTH / VM.ARM_MESH_SIZE.X * VM.ARM_MESH_SIZE.Y * VM.ARM_LENGTH_SCALE
	local up = cf.UpVector
	return cf.Position - up * (length / 2 - VM.ARM_WIDTH * VM.HAND_OVERSHOOT), up
end

function ViewmodelArms.place(arms: Arms, side: Side, hand: Vector3, toward: Vector3, right: Vector3)
	local up = toward - hand
	if up.Magnitude < 1e-4 then
		return
	end
	up = up.Unit
	local x = right - up * right:Dot(up)
	if x.Magnitude < 1e-4 then
		x = up:Cross(Vector3.zAxis)
	end
	x = x.Unit
	local length = VM.ARM_WIDTH / VM.ARM_MESH_SIZE.X * VM.ARM_MESH_SIZE.Y * VM.ARM_LENGTH_SCALE
	local center = hand + up * (length / 2 - VM.ARM_WIDTH * VM.HAND_OVERSHOOT)
	local cf = CFrame.fromMatrix(center, x, up, x:Cross(up))
	local index = if side == "Right" then 1 else 1 + LAYERS
	arms.cframes[index] = cf
	-- The sleeve starts above the wrist: the hand end stays skin.
	arms.cframes[index + 1] = cf + up * VM.ARM_SLEEVE.bare
	arms.cframes[index + 2] = cf
end

return ViewmodelArms
