--!strict
-- Dev tool, not shipped. Builds a weapon Model to the Art Direction model
-- standard from (a) the MeshParts of the Open Cloud package inserted into
-- ServerStorage.ImportStaging.Raw_<Id> and (b) the Blender build data in
-- BuildData/<Id> (exported by tools/blender/export_weapons.py).
--
-- Blender gun space: +X muzzle, +Z up, +Y gun-left, origin = pistol grip.
-- Roblox gun space:  -Z muzzle, +Y up, -X gun-left, origin = Handle.
-- G(x, y, z) = (-y, z, -x) maps one to the other (a proper rotation).
--
-- Result:
--   <Id> (Model, PrimaryPart = Handle)
--     Handle            invisible grip part, RightGrip attachment
--     Rig               one invisible joint part per Blender bone (Root, Mag, Slide...)
--       Motors          Motor6D per bone (Handle -> Root -> Mag ...), C0 at the bone head
--     <mesh parts>      Body_Panel, Mag_Dark, Neon... welded to their bone's joint part
--     Buddy             empty folder; a charm model goes here, hung from CharmPoint

local ServerStorage = game:GetService("ServerStorage")
local InsertService = game:GetService("InsertService")

local Builder = {}

local BuildData = (script.Parent :: Instance):WaitForChild("BuildData")

type Bone = { name: string, parent: string?, head: { number }, matrix: { { number } } }
type Look = { material: string, color: string }
type PartData = {
	name: string,
	bone: string?,
	look: Look?,
	option: string?,
	pbr: boolean?,
	center: { number },
	size: { number },
}
type Locator = { name: string, bone: string?, matrix: { { number } } }
type BuildData = {
	id: string,
	gun: string,
	assetId: number,
	bones: { Bone },
	parts: { PartData },
	locators: { Locator },
	options_visible: { [string]: boolean },
	att_positions: string?,
	-- Baked texture set shared by every non-neon part (image ids), from Exports/textures.json.
	surface: { ColorMap: number, NormalMap: number, RoughnessMap: number, MetalnessMap: number }?,
}

local function G(x: number, y: number, z: number): Vector3
	return Vector3.new(-y, z, -x)
end

local function gv(v: { number }): Vector3
	return G(v[1], v[2], v[3])
end

local function column(m: { { number } }, c: number): Vector3
	return G(m[1][c], m[2][c], m[3][c])
end

local function translation(m: { { number } }): Vector3
	return G(m[1][4], m[2][4], m[3][4])
end

-- How the importer laid out mesh geometry relative to Blender axes. Found by
-- building all four candidates for Bitrate and comparing them (see Architecture).
local MESH_AXES: { [string]: { Vector3 } } = {
	I = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis },
	X = { Vector3.xAxis, -Vector3.yAxis, -Vector3.zAxis },
	Y = { -Vector3.xAxis, Vector3.yAxis, -Vector3.zAxis },
	Z = { -Vector3.xAxis, -Vector3.yAxis, Vector3.zAxis },
}
Builder.DEFAULT_AXES = "Y"

local function meshRotation(axes: string): CFrame
	local a = MESH_AXES[axes]
	local function m(v: Vector3): Vector3
		return G(v.X, v.Y, v.Z)
	end
	return CFrame.fromMatrix(Vector3.zero, m(a[1]), m(a[2]), m(a[3]))
end

local function setPhysics(part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
end

local function newJoint(name: string, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.one * 0.1
	p.Transparency = 1
	p.CFrame = cf
	setPhysics(p)
	return p
end

function Builder.data(id: string): BuildData
	local module = BuildData:FindFirstChild(id)
	assert(module and module:IsA("ModuleScript"), "no build data for " .. id)
	return (require(module) :: any) :: BuildData
end

-- Inserts the uploaded package as ImportStaging.Raw_<Id> (if not already there).
function Builder.insertRaw(id: string): Model
	local staging = ServerStorage:FindFirstChild("ImportStaging") :: Folder
	local existing = staging:FindFirstChild("Raw_" .. id)
	if existing then
		return existing :: Model
	end
	local data = Builder.data(id)
	assert(data.assetId and data.assetId > 0, "no asset id for " .. id)
	local raw = InsertService:LoadAsset(data.assetId)
	raw.Name = "Raw_" .. id
	raw.Parent = staging
	return raw
end

function Builder.build(id: string, axes: string?): Model
	local data = Builder.data(id)
	local raw = Builder.insertRaw(id)
	local rot = meshRotation(axes or Builder.DEFAULT_AXES)

	local meshes: { [string]: MeshPart } = {}
	for _, d in raw:GetDescendants() do
		if d:IsA("MeshPart") then
			meshes[d.Name] = d
		end
	end

	local model = Instance.new("Model")
	model.Name = id
	model:SetAttribute("WeaponId", id)

	local handle = newJoint("Handle", CFrame.identity)
	handle.Size = Vector3.one * 0.2
	handle.Parent = model
	model.PrimaryPart = handle

	local rig = Instance.new("Folder")
	rig.Name = "Rig"
	rig.Parent = model
	local motors = Instance.new("Folder")
	motors.Name = "Motors"
	motors.Parent = rig

	-- Joint parts + Motor6Ds, parents before children.
	local joints: { [string]: BasePart } = {}
	local pending = table.clone(data.bones)
	while #pending > 0 do
		local progressed = false
		for i = #pending, 1, -1 do
			local b = pending[i]
			local parentPart: BasePart? = if b.parent then joints[b.parent] else handle
			if parentPart then
				local cf = CFrame.fromMatrix(
					gv(b.head),
					column(b.matrix, 1),
					column(b.matrix, 2),
					column(b.matrix, 3)
				)
				local joint = newJoint(b.name, cf)
				joint.Parent = rig
				local motor = Instance.new("Motor6D")
				motor.Name = b.name
				motor.Part0 = parentPart
				motor.Part1 = joint
				motor.C0 = parentPart.CFrame:ToObjectSpace(cf)
				motor.C1 = CFrame.identity
				motor.Parent = motors
				joints[b.name] = joint
				table.remove(pending, i)
				progressed = true
			end
		end
		assert(progressed, "bone hierarchy has a cycle or a missing parent")
	end

	-- Mesh parts.
	local missing = {}
	for _, p in data.parts do
		local src = meshes[p.name]
		if not src then
			table.insert(missing, p.name)
			continue
		end
		local part = src:Clone()
		part:ClearAllChildren()
		part.CFrame = CFrame.new(gv(p.center)) * rot
		setPhysics(part)
		if p.look then
			part.Material = (Enum.Material :: any)[p.look.material]
			part.Color = Color3.fromHex(p.look.color)
		end
		if p.look and p.look.color == "FF3DCB" and string.find(p.name, "Lens") then
			part.Transparency = 0.25
		end
		local surface = data.surface
		if p.pbr and surface then
			local sa = Instance.new("SurfaceAppearance")
			sa.ColorMap = "rbxassetid://" .. surface.ColorMap
			sa.NormalMap = "rbxassetid://" .. surface.NormalMap
			sa.RoughnessMap = "rbxassetid://" .. surface.RoughnessMap
			sa.MetalnessMap = "rbxassetid://" .. surface.MetalnessMap
			sa.Parent = part
		end
		if p.option then
			part:SetAttribute("Option", p.option)
			if not data.options_visible[p.option] then
				part.Transparency = 1
			end
		end
		pcall(function()
			part.CollisionFidelity = Enum.CollisionFidelity.Box
		end)
		local joint = (p.bone and joints[p.bone]) or joints.Root or handle
		-- A classic Weld with an explicit offset: WeldConstraint offsets get
		-- recomputed on clients from wherever the parts first replicate, which
		-- scatters the parts of a gun held by another player.
		local weld = Instance.new("Weld")
		weld.Part0 = joint
		weld.Part1 = part
		weld.C0 = joint.CFrame:ToObjectSpace(part.CFrame)
		weld.C1 = CFrame.identity
		weld.Parent = part
		part.Parent = model
	end

	-- Locators -> Attachments.
	for _, l in data.locators do
		local parentPart: BasePart = if l.name == "RightGrip"
			then handle
			else (l.bone and joints[l.bone]) or joints.Root or handle
		local pos = translation(l.matrix)
		local world = CFrame.new(pos)
		if string.sub(l.name, 1, 5) == "Eject" then -- Eject, EjectLower: aimed along their local Z
			local dir = column(l.matrix, 3).Unit
			local up = if math.abs(dir.Y) > 0.9 then Vector3.zAxis else Vector3.yAxis
			world = CFrame.lookAt(pos, pos + dir, up)
		end
		local att = Instance.new("Attachment")
		att.Name = l.name
		att.CFrame = parentPart.CFrame:ToObjectSpace(world)
		att.Parent = parentPart
	end

	local buddy = Instance.new("Folder")
	buddy.Name = "Buddy"
	buddy.Parent = model

	-- (Bitrate's att_positions stay in BuildData: Server Authority drops string
	-- attributes over 50 characters.)
	local _, size = model:GetBoundingBox()
	model:SetAttribute("Length", math.round(size.Z * 1000) / 1000)
	model:SetAttribute("SourceAsset", data.assetId)
	if #missing > 0 then
		model:SetAttribute("MissingParts", table.concat(missing, ","))
	end
	return model
end

-- Builds <Id> into ImportStaging (replacing an older build) and returns it.
function Builder.stage(id: string, axes: string?): Model
	local staging = ServerStorage:FindFirstChild("ImportStaging") :: Folder
	local old = staging:FindFirstChild(id)
	if old then
		old:Destroy()
	end
	local model = Builder.build(id, axes)
	model.Parent = staging
	return model
end

-- Builds <Id>, installs it as ReplicatedStorage.Weapons.<Id> (the folder the
-- game reads; Studio-owned because Rojo live sync can't set MeshPart.MeshId)
-- and saves a backup to art-source/weapons/Studio/<Id>.rbxm through
-- tools/studio/receive_server.py (if it's running).
function Builder.publish(id: string): (Model, string)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local folder = ReplicatedStorage:FindFirstChild("Weapons")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Weapons"
		folder.Parent = ReplicatedStorage
	end
	local model = Builder.stage(id)
	local old = folder:FindFirstChild(id)
	if old then
		old:Destroy()
	end
	local final = model:Clone()
	final.Parent = folder

	local saved = "not saved"
	local ok, err = pcall(function()
		local buf = game:GetService("SerializationService"):SerializeInstancesAsync({ final })
		local b64 = buffer.tostring(game:GetService("EncodingService"):Base64Encode(buf))
		local res = game:GetService("HttpService"):RequestAsync({
			Url = "http://127.0.0.1:34999/save?path=art-source/weapons/Studio/" .. id .. ".rbxm",
			Method = "POST",
			Body = b64,
		})
		saved = res.Body
	end)
	if not ok then
		saved = "save failed: " .. tostring(err)
	end
	return final, saved
end

-- Shows a copy in Workspace.WeaponPreview at `cf` (anchored) for screenshots.
function Builder.preview(model: Model, cf: CFrame): Model
	local folder = workspace:FindFirstChild("WeaponPreview")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "WeaponPreview"
		folder.Parent = workspace
	end
	local copy = model:Clone()
	copy:PivotTo(cf)
	-- Anchor everything and drop the welds so Studio's weld overlay stays clean.
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end
	copy.Parent = folder
	return copy
end

function Builder.clearPreview()
	local folder = workspace:FindFirstChild("WeaponPreview")
	if folder then
		folder:Destroy()
	end
end

return Builder
