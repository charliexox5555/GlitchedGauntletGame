--!strict
-- The standard match body (vault/01 Design/Match Avatar.md, Config/Avatar):
-- Roblox's default blocky R15 for everyone (every body-part id 0, fixed
-- scales), keeping the player's skin colours, classic clothing, face and
-- (by Config) hair, plus slim one-piece arms.
--
-- Shared so the server (CharacterService, MatchService), bots, range dummies
-- and the Studio tools that solve the holds (tools/studio/MakeHoldAnimations)
-- all build the exact same body.

local Avatar = require(script.Parent.Config.Avatar)

local MatchBody = {}

local ARM_PARTS = {
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
}

-- The standard description, built fresh (never trusting a client) and
-- copying only what Config/Avatar keeps from `own` (the player's own
-- description; nil for bots and dummies).
function MatchBody.description(own: HumanoidDescription?): HumanoidDescription
	local d = Instance.new("HumanoidDescription")
	-- Body parts: 0 = Roblox's default blocky R15 parts. Head too, so every
	-- head hitbox is the same size.
	d.Head = 0
	d.Torso = 0
	d.LeftArm = 0
	d.RightArm = 0
	d.LeftLeg = 0
	d.RightLeg = 0
	local s = Avatar.SCALES
	d.HeightScale = s.height
	d.WidthScale = s.width
	d.DepthScale = s.depth
	d.HeadScale = s.head
	d.BodyTypeScale = s.bodyType
	d.ProportionScale = s.proportion
	if own then
		if Avatar.KEEP_SKIN then
			d.HeadColor = own.HeadColor
			d.TorsoColor = own.TorsoColor
			d.LeftArmColor = own.LeftArmColor
			d.RightArmColor = own.RightArmColor
			d.LeftLegColor = own.LeftLegColor
			d.RightLegColor = own.RightLegColor
		end
		if Avatar.KEEP_CLOTHING then
			d.Shirt = own.Shirt
			d.Pants = own.Pants
			d.GraphicTShirt = own.GraphicTShirt
		end
		if Avatar.KEEP_FACE then
			d.Face = own.Face
		end
		-- Classic (rigid) accessories only: layered clothing wraps the body
		-- and won't fit the slim arms.
		if Avatar.ACCESSORIES == "all" then
			d.HatAccessory = own.HatAccessory
			d.HairAccessory = own.HairAccessory
			d.FaceAccessory = own.FaceAccessory
			d.NeckAccessory = own.NeckAccessory
			d.ShouldersAccessory = own.ShouldersAccessory
			d.FrontAccessory = own.FrontAccessory
			d.BackAccessory = own.BackAccessory
			d.WaistAccessory = own.WaistAccessory
		elseif Avatar.ACCESSORIES == "hair" then
			d.HairAccessory = own.HairAccessory
		end
	end
	return d
end

-- Slim one-piece arms: narrows the six arm parts to ARM_WIDTH and scales
-- their attachments (rig joints, grip) with them, so every joint stays where
-- it was and the hand sits flush with the forearm. Idempotent (the part's
-- attribute remembers its original size). Run it after any ApplyDescription,
-- which rebuilds the parts.
function MatchBody.slimArms(model: Model)
	-- The Humanoid rebuilds part sizes from its scale values whenever the
	-- model enters the Workspace (measured: a slimmed arm went back to 1.0 on
	-- parenting); the standard scales are already baked into the parts.
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutomaticScalingEnabled = false
	end
	local width = Avatar.ARM_WIDTH
	for _, name in ARM_PARTS do
		local part = model:FindFirstChild(name)
		if not part or not part:IsA("BasePart") then
			continue
		end
		local size = part.Size
		if math.abs(size.X - width) < 1e-3 and math.abs(size.Z - width) < 1e-3 then
			continue
		end
		local kx, kz = width / size.X, width / size.Z
		for _, a in part:GetChildren() do
			if a:IsA("Attachment") then
				local p = a.Position
				a.Position = Vector3.new(p.X * kx, p.Y, p.Z * kz)
			end
		end
		part.Size = Vector3.new(width, size.Y, width)
	end
end

return MatchBody
