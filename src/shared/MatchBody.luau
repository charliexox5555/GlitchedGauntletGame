--!strict
-- The standard match body (vault/01 Design/Match Avatar.md, Third Person
-- Overhaul.md, Config/Avatar): Roblox's default blocky R15 for everyone
-- (every body-part id 0, fixed scales), keeping the player's skin colours,
-- classic clothing, face and (by Config) accessories, drawn as our own sharp
-- blocks (`dress`).
--
-- Shared so the server (CharacterService, MatchService), bots, range dummies
-- and the Studio tools all build the exact same body.

local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")

local Avatar = require(script.Parent.Config.Avatar)

local MatchBody = {}

-- Models whose clothing changes are already being followed (`dress`).
local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

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
		-- What comes through is checked again once it has spawned
		-- (`filterAccessory`: size caps, effects stripped).
		-- Accessories come from the description's accessory list, rigid AND
		-- layered: most hair today is layered (it wraps the head), and the
		-- old string fields (HairAccessory...) leave it out, which is why
		-- players lost their hair (2026-11-12). Layered items are kept only
		-- on the head (Config/Avatar ACCESSORY_LAYERED): the body under our
		-- blocks is invisible, so layered clothing would wrap nothing we draw.
		if Avatar.ACCESSORIES ~= "none" then
			local keep = {}
			local ok, list = pcall(function()
				return own:GetAccessories(true)
			end)
			for _, item in if ok then list else {} do
				local kind = item.AccessoryType.Name
				local allowed = if Avatar.ACCESSORIES == "hair"
					then kind == "Hair"
					else Avatar.ACCESSORY_LIMITS[kind] ~= nil
				if
					allowed and (not item.IsLayered or table.find(Avatar.ACCESSORY_LAYERED, kind))
				then
					table.insert(keep, item)
				end
			end
			pcall(function()
				d:SetAccessories(keep, true)
			end)
		end
	end
	return d
end

-- Largest to smallest.
local function sorted(v: Vector3): (number, number, number)
	local a, b, c = v.X, v.Y, v.Z
	if a < b then
		a, b = b, a
	end
	if b < c then
		b, c = c, b
	end
	if a < b then
		a, b = b, a
	end
	return a, b, c
end

-- The accessory rule (Config/Avatar ACCESSORY_LIMITS / ACCESSORY_STRIP,
-- Third Person Overhaul.md §4). Returns false when the accessory was removed:
-- layered clothing, a type with no limit, or one bigger than its limit. One
-- that stays loses its effects (particles, trails, lights, sounds, scripts).
-- Server only: call it on each Accessory of a spawned character.
function MatchBody.filterAccessory(accessory: Accessory): boolean
	local handle = accessory:FindFirstChild("Handle")
	local limit = Avatar.ACCESSORY_LIMITS[accessory.AccessoryType.Name]
	local keep = handle ~= nil and handle:IsA("BasePart") and limit ~= nil
	-- Layered (a WrapLayer): only on the head, which we still draw.
	if
		keep
		and (handle :: BasePart):FindFirstChildWhichIsA("WrapLayer")
		and not table.find(Avatar.ACCESSORY_LAYERED, accessory.AccessoryType.Name)
	then
		keep = false
	end
	if keep then
		local a, b, c = sorted((handle :: BasePart).Size)
		local la, lb, lc = sorted(limit)
		keep = a <= la and b <= lb and c <= lc
	end
	if not keep then
		accessory:Destroy()
		return false
	end
	for _, d in accessory:GetDescendants() do
		for _, class in Avatar.ACCESSORY_STRIP do
			if d:IsA(class) then
				d:Destroy()
				break
			end
		end
	end
	return true
end

-- One MeshPart per block, made once (with its clothing faces) and cloned
-- for each body.
local templates: { [string]: MeshPart } = {}
local loading = false

local SIDES = { "Front", "Back", "Left", "Right" }

-- One face of a block showing its piece of a clothing template. A Texture on
-- the face, not the mesh's own texture: it is the one way a game script can
-- let the part's colour (the skin) show through the template's clear areas.
-- A MeshPart's TextureID and a SpecialMesh's texture draw them black, a
-- Decal can't crop, and a SurfaceAppearance's maps can't be written at run
-- time (all measured 2026-11-12). On a MeshPart a Texture's tile starts at
-- the centre of the face, hence the half sizes.
local function face(made: MeshPart, spec: Avatar.Block, cloth: string, layer: number, name: string)
	local region = Avatar.CLOTH_REGIONS[spec.region]
	local corner: Vector2 = region[name]
	local sheet = Avatar.CLOTH_TEMPLATE
	local side = name ~= "Top" and name ~= "Bottom"
	local wide = if name == "Left" or name == "Right" then spec.size.Z else spec.size.X
	local tall = if side then spec.size.Y else spec.size.Z
	local acrossPx = if name == "Left" or name == "Right" then 64 else region.across
	local row0 = if side then corner.Y + spec.t0 * region.down else corner.Y
	local row1 = if side then corner.Y + spec.t1 * region.down else corner.Y + 64
	local texture = Instance.new("Texture")
	texture.Name = cloth
	texture.Face = (Enum.NormalId :: any)[name]
	texture.ZIndex = layer
	texture.StudsPerTileU = wide * sheet.X / acrossPx
	texture.StudsPerTileV = tall * sheet.Y / (row1 - row0)
	texture.OffsetStudsU = corner.X / sheet.X * texture.StudsPerTileU + wide / 2
	texture.OffsetStudsV = row0 / sheet.Y * texture.StudsPerTileV + tall / 2
	texture.Parent = made
end

-- The five Bones of a skinned limb, at the mesh's bind pose (as the importer
-- reads tools/blender/make_skinned_limbs.py: "Upper" turned half a turn about
-- X so its +Y runs down the limb, the rest under it on its axis). They sit
-- flat under the MeshPart so each one's Transform is in the mesh's frame.
local BONES = { "Upper", "Mid1", "Lower", "Mid2", "End" }
local ROOT_BONES = { "Hip", "HipMid" } -- legs: the thigh's top on the pelvis
local function addBones(made: MeshPart, spec: Avatar.Block, skin: Avatar.Skin)
	local c = spec.offset.Y
	local upper = CFrame.new(0, skin.top - c, 0) * CFrame.Angles(math.pi, 0, 0)
	local at = {
		Upper = upper,
		Mid1 = upper * CFrame.new(0, skin.top - skin.bend, 0),
		Lower = upper * CFrame.new(0, skin.top - skin.bend, 0),
		Mid2 = upper * CFrame.new(0, skin.top - skin.wrist, 0),
		End = upper * CFrame.new(0, skin.top - skin.wrist, 0),
		Hip = upper,
		HipMid = upper,
	}
	for _, name in BONES do
		local bone = Instance.new("Bone")
		bone.Name = skin.prefix .. name
		bone.CFrame = at[name]
		bone.Parent = made
	end
	if skin.root then
		for _, name in ROOT_BONES do
			local bone = Instance.new("Bone")
			bone.Name = skin.prefix .. name
			bone.CFrame = at[name]
			bone.Parent = made
		end
	end
end

-- A skinned limb's live state (`skinLimb`): its parts, the rest pose of the
-- lower and tip parts in the upper part's frame, and its bones.
export type Limb = {
	made: MeshPart,
	upper: BasePart,
	lower: BasePart,
	tip: BasePart,
	restLower: CFrame, -- inverse rest pose of the lower part (upper frame)
	restTip: CFrame, -- ...and of the tip part
	root: BasePart?, -- legs: the pelvis...
	restRoot: CFrame, -- ...and its inverse rest pose
	twist: boolean, -- keep joint twist (Skin.twist)
	weld: CFrame, -- the mesh in the upper part's frame...
	weldInv: CFrame,
	bones: { [string]: Bone },
	rest: { [string]: CFrame }, -- each bone's bind CFrame...
	restInv: { [string]: CFrame }, -- ...and its inverse
}

local function rigAttachment(part: Instance, name: string): Attachment?
	local a = part:FindFirstChild(name)
	return if a and a:IsA("Attachment") then a else nil
end

-- The state for one limb mesh (a child of its upper R15 part), or nil while
-- a part it needs is missing (streaming, a rebuild).
function MatchBody.limb(made: MeshPart): Limb?
	local owner = made:FindFirstChild(Avatar.LIMB_OWNER)
	local upper = if owner and owner:IsA("ObjectValue") then owner.Value else nil
	local model = upper and upper.Parent
	local spec = upper and Avatar.BLOCKS[upper.Name]
	local skin = spec and spec.skin
	if not (upper and upper:IsA("BasePart") and model and spec and skin) then
		return nil
	end
	local lower = model:FindFirstChild(skin.lower)
	local tip = model:FindFirstChild(skin.tip)
	if not (lower and lower:IsA("BasePart") and tip and tip:IsA("BasePart")) then
		return nil
	end
	local ju, jl = rigAttachment(upper, skin.joint), rigAttachment(lower, skin.joint)
	local tl, tt = rigAttachment(lower, skin.tipJoint), rigAttachment(tip, skin.tipJoint)
	if not (ju and jl and tl and tt) then
		return nil
	end
	local restLower = ju.CFrame * jl.CFrame:Inverse()
	local restTip = if tip == lower then restLower else restLower * tl.CFrame * tt.CFrame:Inverse()
	local root: BasePart? = nil
	local restRoot = CFrame.new()
	if skin.root and skin.rootJoint then
		local found = model:FindFirstChild(skin.root)
		local ru = rigAttachment(upper, skin.rootJoint)
		local rr = found and rigAttachment(found, skin.rootJoint)
		if not (found and found:IsA("BasePart") and ru and rr) then
			return nil
		end
		root = found
		restRoot = ru.CFrame * rr.CFrame:Inverse()
	end
	local bones: { [string]: Bone } = {}
	local rest: { [string]: CFrame } = {}
	local restInv: { [string]: CFrame } = {}
	local names = table.clone(BONES)
	if root then
		table.move(ROOT_BONES, 1, #ROOT_BONES, #names + 1, names)
	end
	for _, name in names do
		local bone = made:FindFirstChild(skin.prefix .. name)
		if not (bone and bone:IsA("Bone")) then
			return nil
		end
		bones[name] = bone
		rest[name] = bone.CFrame
		restInv[name] = bone.CFrame:Inverse()
	end
	local weld = CFrame.new(spec.offset)
	return {
		made = made,
		upper = upper,
		lower = lower,
		tip = tip,
		restLower = restLower:Inverse(),
		restTip = restTip:Inverse(),
		root = root,
		restRoot = restRoot:Inverse(),
		twist = skin.twist == true or Avatar.LIMB_SKIN.twist,
		weld = weld,
		weldInv = weld:Inverse(),
		bones = bones,
		rest = rest,
		restInv = restInv,
	}
end

local MID = Avatar.LIMB_SKIN.mid
local TIP = Avatar.LIMB_SKIN.tip
-- Limb meshes whose end (hand / foot) bends with its own part even though
-- LIMB_SKIN.tip is off: the win cutscene's copies' legs, so a planted foot
-- can sit flat on the floor while the shin leans (Util/WinCutscene).
local tipBend: { [MeshPart]: boolean } = setmetatable({}, { __mode = "k" }) :: any

function MatchBody.setTipBend(made: MeshPart, on: boolean)
	tipBend[made] = if on then true else nil
end
local REST = CFrame.new()

-- `d` (a joint's move in the mesh frame, a turn about `pivot`) without its
-- twist about the limb's axis (Y): swing-twist split of its rotation.
local function swingOnly(d: CFrame, pivot: Vector3): CFrame
	local axis, angle = (d - d.Position):ToAxisAngle()
	if angle < 1e-4 then
		return d
	end
	local twist = 2 * math.atan2(axis.Y * math.sin(angle / 2), math.cos(angle / 2))
	local swing = (d - d.Position) * CFrame.Angles(0, -twist, 0)
	return CFrame.new(pivot) * swing * CFrame.new(-pivot)
end

-- Bends a limb mesh to match its R15 parts this frame (client, after the
-- animation: Controllers/BodySkinController; or a Studio tool). The lower
-- bone follows the forearm / shin, the end bone the hand / foot, and each
-- helper turns half way between its neighbours, so the outside of a bend is
-- two equal flat plates and the limb keeps its thickness.
function MatchBody.skinLimb(limb: Limb)
	local u = limb.upper.CFrame
	-- How far each part has moved from its rest pose, in the mesh's frame.
	local dl = limb.weldInv * (u:ToObjectSpace(limb.lower.CFrame) * limb.restLower) * limb.weld
	local b, r, ri = limb.bones, limb.rest, limb.restInv
	if not limb.twist then
		dl = swingOnly(dl, r.Lower.Position)
	end
	local root = limb.root
	if root then
		-- The thigh's top stays on the pelvis; the hip loop turns half way.
		local dr = limb.weldInv * (u:ToObjectSpace(root.CFrame) * limb.restRoot) * limb.weld
		dr = swingOnly(dr, r.Hip.Position)
		b.Hip.Transform = ri.Hip * dr * r.Hip
		b.HipMid.Transform = REST:Lerp(ri.HipMid * dr * r.HipMid, MID)
	end
	local dt = if TIP or tipBend[limb.made]
		then limb.weldInv * (u:ToObjectSpace(limb.tip.CFrame) * limb.restTip) * limb.weld
		else dl
	b.Lower.Transform = ri.Lower * dl * r.Lower
	b.Mid1.Transform = REST:Lerp(ri.Mid1 * dl * r.Mid1, MID)
	b.End.Transform = ri.End * dt * r.End
	b.Mid2.Transform = ri.Mid2 * (dl * r.Mid2):Lerp(dt * r.Mid2, MID)
end

-- Makes the block templates (yields the first time, on the server or in a
-- Studio tool). `dress` calls it; calling it at start-up keeps the first
-- spawn from waiting.
function MatchBody.preload()
	while loading do
		task.wait()
	end
	loading = true
	for name, spec in Avatar.BLOCKS do
		if not templates[name] then
			local ok, made = pcall(function(): MeshPart
				return AssetService:CreateMeshPartAsync(
					-- selene: allow(undefined_variable)
					Content.fromUri(spec.mesh),
					{ CollisionFidelity = Enum.CollisionFidelity.Box }
				)
			end)
			if ok and made then
				made.Name = Avatar.BLOCK_NAME
				made.Material = Enum.Material.SmoothPlastic
				made.CanCollide = false
				made.CanQuery = false
				made.CanTouch = false
				made.Massless = true
				for layer, cloth in spec.cloth do
					for _, side in SIDES do
						face(made, spec, cloth, layer, side)
					end
					if spec.top then
						face(made, spec, cloth, layer, "Top")
					end
					if spec.bottom then
						face(made, spec, cloth, layer, "Bottom")
					end
				end
				if spec.skin then
					addBones(made, spec, spec.skin)
				end
				templates[name] = made
			else
				warn("[MatchBody] couldn't make the block for", name, made)
			end
		end
	end
	loading = false
end

-- The block drawn over an R15 part: a child of the part, or (a skinned limb)
-- the mesh its BodyLimb link points at.
local function blockOf(part: Instance): Instance?
	local link = part:FindFirstChild(Avatar.LIMB_LINK)
	if link and link:IsA("ObjectValue") then
		return link.Value
	end
	return part:FindFirstChild(Avatar.BLOCK_NAME)
end
MatchBody.blockOf = blockOf

-- Where skinned limb meshes live: outside every character, because the
-- character's Animator rewrites any Bone inside it during the physics step
-- and the frame is drawn with that, not with BodySkinController's bend
-- (measured 2026-11-12). Welded to their part, so they stream and move with
-- the body. `localCopy`: the client's folder for body copies (BodyClone).
function MatchBody.limbFolder(localCopy: boolean?): Folder
	local name = if localCopy then Avatar.LIMB_FOLDER .. "Local" else Avatar.LIMB_FOLDER
	local folder = workspace:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end
	local made = Instance.new("Folder")
	made.Name = name
	made.Parent = workspace
	return made
end

-- Moves a limb mesh onto another body's part (a BodyClone copy): returns the
-- new mesh, welded to `part`, linked both ways, destroyed with the part.
function MatchBody.attachLimb(source: Instance, part: BasePart, localCopy: boolean?): MeshPart?
	if not source:IsA("MeshPart") then
		return nil
	end
	local was = source.Archivable
	source.Archivable = true
	local made = source:Clone()
	source.Archivable = was
	local weld = made:FindFirstChildOfClass("Weld")
	if weld then
		weld.Part0 = part
		weld.Part1 = made
	end
	local owner = made:FindFirstChild(Avatar.LIMB_OWNER)
	if owner and owner:IsA("ObjectValue") then
		owner.Value = part
	end
	local link = part:FindFirstChild(Avatar.LIMB_LINK)
	if link and link:IsA("ObjectValue") then
		link.Value = made
	end
	made.Parent = MatchBody.limbFolder(localCopy)
	part.Destroying:Connect(function()
		made:Destroy()
	end)
	part.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			made:Destroy()
		end
	end)
	return made
end

-- Skin colour and clothing onto the blocks (again whenever either changes).
local function refresh(model: Model)
	local shirt = model:FindFirstChildOfClass("Shirt")
	local pants = model:FindFirstChildOfClass("Pants")
	local worn = {
		Shirt = if shirt then shirt.ShirtTemplate else "",
		Pants = if pants then pants.PantsTemplate else "",
	}
	for name in Avatar.BLOCKS do
		local part = model:FindFirstChild(name)
		local made = part and blockOf(part)
		if part and part:IsA("BasePart") and made and made:IsA("MeshPart") then
			made.Color = part.Color
			for _, child in made:GetChildren() do
				if child:IsA("Texture") then
					local template = worn[child.Name] or ""
					if child.Texture ~= template then
						child.Texture = template
					end
				end
			end
		end
	end
end

-- Draws the body as blocks (Config/Avatar BLOCKS): one welded block over each
-- R15 part, in that part's skin colour with the classic Shirt / Pants laid on
-- it; the engine's parts stay as the rig and the hitboxes, invisible. The
-- blocks follow later changes of skin colour and clothing. Idempotent; run
-- it after any ApplyDescription (which can rebuild the parts). Can yield the
-- first time (`preload`).
function MatchBody.dress(model: Model)
	if not Avatar.BLOCK_BODY then
		return
	end
	MatchBody.preload()
	local watch = false
	for name, spec in Avatar.BLOCKS do
		local part = model:FindFirstChild(name)
		if not part or not part:IsA("BasePart") then
			continue
		end
		part.Transparency = 1
		if blockOf(part) then
			continue
		end
		local template = templates[name]
		if not template then
			continue
		end
		local made = template:Clone()
		made.Color = part.Color
		made.CFrame = part.CFrame * CFrame.new(spec.offset)
		local weld = Instance.new("Weld")
		weld.Part0 = part
		weld.Part1 = made
		weld.C0 = CFrame.new(spec.offset)
		weld.Parent = made
		if spec.skin then
			local owner = Instance.new("ObjectValue")
			owner.Name = Avatar.LIMB_OWNER
			owner.Value = part
			owner.Parent = made
			local link = Instance.new("ObjectValue")
			link.Name = Avatar.LIMB_LINK
			link.Value = made
			link.Parent = part
			CollectionService:AddTag(made, Avatar.LIMB_TAG)
			made.Parent = MatchBody.limbFolder()
			part.Destroying:Connect(function()
				made:Destroy()
			end)
			part.AncestryChanged:Connect(function(_, parent)
				if parent == nil then
					made:Destroy()
				end
			end)
		else
			made.Parent = part
		end
		part:GetPropertyChangedSignal("Color"):Connect(function()
			made.Color = part.Color
		end)
		watch = true
	end
	for _, name in Avatar.BLOCK_HIDDEN do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Transparency = 1
		end
	end
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		head.Material = Enum.Material.SmoothPlastic
	end
	refresh(model)
	if watch and not watched[model] then
		watched[model] = true
		-- Clothing arrives (or changes) after the body: redraw.
		local function onClothing(child: Instance)
			if child:IsA("Shirt") then
				child:GetPropertyChangedSignal("ShirtTemplate"):Connect(function()
					refresh(model)
				end)
			elseif child:IsA("Pants") then
				child:GetPropertyChangedSignal("PantsTemplate"):Connect(function()
					refresh(model)
				end)
			else
				return
			end
			refresh(model)
		end
		for _, child in model:GetChildren() do
			onClothing(child)
		end
		model.ChildAdded:Connect(onClothing)
		model.ChildRemoved:Connect(function(child)
			if child:IsA("Shirt") or child:IsA("Pants") then
				refresh(model)
			end
		end)
	end
end

return MatchBody
