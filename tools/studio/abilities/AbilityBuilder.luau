--!strict
-- Dev tool, not shipped. Builds a Mod prop Model (art-source/abilities/README.md)
-- from (a) the MeshParts of the Open Cloud upload inserted into
-- ServerStorage.ImportStaging.Raw_<Id> and (b) the Blender build data in
-- BuildData/<Id> (tools/blender/export_mods.py -> tools/studio/make_ability_build_data.py).
-- Same axes and mesh layout as the guns (tools/studio/rojo/WeaponBuilder.luau):
--
-- Blender: +X forward, +Z up, +Y left.  Roblox: -Z forward, +Y up, -X left.
-- G(x, y, z) = (-y, z, -x) maps one to the other.
--
-- Result (pivot at the Blender origin: the grip for handheld props, the centre
-- for thrown ones, the floor centre for placed ones; facing -Z):
--   <Id> (Model, PrimaryPart = Root)
--     Root            invisible 0.2 part at the pivot; carries the locator Attachments
--                     (Handle, LeftGrip, Emitter, Fuse, Top, Center) and, on handheld
--                     and thrown props, RightGrip (= Handle, like the guns)
--     <mesh parts>    Blender names (Body_Shell, Grip_Dark, Core_Energy...), each welded to Root
-- Every part: Anchored, CanCollide/CanQuery/CanTouch off, Massless; shadows only
-- on the solid parts of placed props. *_Energy parts are Neon in the ally colour
-- with the attribute Energy = true: tint them per viewer (and the Decals on them).

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Builder = {}

local BuildData = (script.Parent :: Instance):WaitForChild("BuildData")

type Look = { material: string, color: string, transparency: number? }
type PartData = {
	name: string,
	look: Look?,
	energy: boolean,
	tris: number,
	center: { number },
	size: { number },
	doubleSided: boolean?,
	decal: number?,
}
type Locator = { name: string, matrix: { { number } } }
type BuildData = {
	mod: string,
	kind: string, -- "handheld" | "thrown" | "placed" | "vfx"
	assetId: number,
	tris: number,
	parts: { PartData },
	locators: { Locator },
	holdOffset: { number }?,
}

local function G(x: number, y: number, z: number): Vector3
	return Vector3.new(-y, z, -x)
end

local function gv(v: { number }): Vector3
	return G(v[1], v[2], v[3])
end

local function translation(m: { { number } }): Vector3
	return G(m[1][4], m[2][4], m[3][4])
end

-- How the importer lays out mesh geometry relative to Blender axes. The guns
-- import as "Y"; the Mod uploads (no armature) import as "M" = (Blender X,
-- Blender Z, -Blender Y), found by the code session's first build (commit 4be1d37):
-- with "Y" the Firewall came out 6 wide x 8.26 tall and the Launch Pad stood on edge.
local MESH_AXES: { [string]: { Vector3 } } = {
	I = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis },
	X = { Vector3.xAxis, -Vector3.yAxis, -Vector3.zAxis },
	Y = { -Vector3.xAxis, Vector3.yAxis, -Vector3.zAxis },
	Z = { -Vector3.xAxis, -Vector3.yAxis, Vector3.zAxis },
	M = { Vector3.xAxis, Vector3.zAxis, -Vector3.yAxis },
}
Builder.DEFAULT_AXES = "M"

local function meshRotation(axes: string): CFrame
	local a = MESH_AXES[axes]
	local function m(v: Vector3): Vector3
		return G(v.X, v.Y, v.Z)
	end
	return CFrame.fromMatrix(Vector3.zero, m(a[1]), m(a[2]), m(a[3]))
end

local function setPhysics(part: BasePart, shadow: boolean)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = shadow
end

function Builder.data(id: string): BuildData
	local module = BuildData:FindFirstChild(id)
	assert(module and module:IsA("ModuleScript"), "no build data for " .. id)
	return (require(module) :: any) :: BuildData
end

function Builder.ids(): { string }
	local out = {}
	for _, m in BuildData:GetChildren() do
		table.insert(out, m.Name)
	end
	table.sort(out)
	return out
end

-- Inserts the uploaded model as ImportStaging.Raw_<Id> (if not already there).
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

-- A Decal asset id -> the image content id behind it (what Decal.Texture needs).
local imageCache: { [number]: string } = {}
local function decalImage(decalId: number): string
	local cached = imageCache[decalId]
	if cached then
		return cached
	end
	local loaded = InsertService:LoadAsset(decalId)
	local decal = loaded:FindFirstChildWhichIsA("Decal", true)
	assert(decal, "asset " .. decalId .. " has no Decal")
	local image = decal.Texture
	loaded:Destroy()
	imageCache[decalId] = image
	return image
end

-- The face of `part` whose outward normal points most along `dir` (world space).
local function faceToward(part: BasePart, dir: Vector3): Enum.NormalId
	local best, bestDot = Enum.NormalId.Front, -math.huge
	for _, n in Enum.NormalId:GetEnumItems() do
		local face = (n :: any) :: Enum.NormalId
		local d = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face)):Dot(dir)
		if d > bestDot then
			best, bestDot = face, d
		end
	end
	return best
end

function Builder.build(id: string, axes: string?): Model
	local data = Builder.data(id)
	local raw = Builder.insertRaw(id)
	local rot = meshRotation(axes or Builder.DEFAULT_AXES)
	local placed = data.kind == "placed"

	local meshes: { [string]: MeshPart } = {}
	for _, d in raw:GetDescendants() do
		if d:IsA("MeshPart") then
			meshes[d.Name] = d
		end
	end

	local model = Instance.new("Model")
	model.Name = id
	model:SetAttribute("AbilityId", id)
	model:SetAttribute("Kind", data.kind)

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * 0.2
	root.Transparency = 1
	root.CFrame = CFrame.identity
	setPhysics(root, false)
	root.Parent = model
	model.PrimaryPart = root

	local missing = {}
	local noDoubleSided = {}
	for _, p in data.parts do
		local src = meshes[p.name]
		if not src then
			table.insert(missing, p.name)
			continue
		end
		local part = src:Clone()
		part:ClearAllChildren()
		part.CFrame = CFrame.new(gv(p.center)) * rot
		setPhysics(part, placed and not p.energy)
		if p.look then
			part.Material = (Enum.Material :: any)[p.look.material]
			part.Color = Color3.fromHex(p.look.color)
			part.Transparency = p.look.transparency or 0
		end
		if p.energy then
			part:SetAttribute("Energy", true)
		end
		if p.doubleSided then
			-- Not settable from every security context; the README says to tick it by hand if this fails.
			if not pcall(function()
				(part :: any).DoubleSided = true
			end) then
				table.insert(noDoubleSided, p.name)
			end
		end
		pcall(function()
			part.CollisionFidelity = Enum.CollisionFidelity.Box
		end)
		local decalId = p.decal
		if decalId then
			-- The Firewall grid: one Decal on each big face, tinted like the part (white texture).
			local image = decalImage(decalId)
			local normal = G(1, 0, 0) -- the wall faces Blender +X
			for i, dir in { normal, -normal } do
				local decal = Instance.new("Decal")
				decal.Name = if i == 1 then "GridFront" else "GridBack"
				decal.Texture = image
				decal.Color3 = part.Color
				decal.Face = faceToward(part, dir)
				decal.Parent = part
			end
		end
		-- A classic Weld (WeldConstraint offsets get recomputed on clients), so code can unanchor the Root.
		local weld = Instance.new("Weld")
		weld.Part0 = root
		weld.Part1 = part
		weld.C0 = root.CFrame:ToObjectSpace(part.CFrame)
		weld.C1 = CFrame.identity
		weld.Parent = part
		part.Parent = model
	end

	-- Locators -> Attachments on Root, axis-aligned with the model (Emitter's LookVector = forward).
	for _, l in data.locators do
		local att = Instance.new("Attachment")
		att.Name = l.name
		att.CFrame = CFrame.new(translation(l.matrix))
		att.Parent = root
		if l.name == "Handle" and (data.kind == "handheld" or data.kind == "thrown") then
			local grip = att:Clone()
			grip.Name = "RightGrip"
			grip.Parent = root
		end
	end

	local hold = data.holdOffset
	if hold then
		model:SetAttribute("HoldOffset", Vector3.new(hold[1], hold[2], hold[3]))
	end
	model.WorldPivot = CFrame.identity
	model:SetAttribute("SourceAsset", data.assetId)
	model:SetAttribute("Tris", data.tris)
	if #missing > 0 then
		model:SetAttribute("MissingParts", table.concat(missing, ","))
	end
	if #noDoubleSided > 0 then
		model:SetAttribute("SetDoubleSidedByHand", table.concat(noDoubleSided, ","))
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

-- Builds <Id>, installs it as ReplicatedStorage.Abilities.<Id> (Studio-owned:
-- Rojo can't set MeshPart.MeshId) and saves a backup to
-- art-source/abilities/Studio/<Id>.rbxm through tools/studio/receive_server.py
-- (if it's running).
function Builder.publish(id: string): (Model, string)
	local folder = ReplicatedStorage:FindFirstChild("Abilities")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Abilities"
		folder.Parent = ReplicatedStorage
	end
	local model = Builder.stage(id)
	local old = (folder :: Instance):FindFirstChild(id)
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
			Url = "http://127.0.0.1:34999/save?path=art-source/abilities/Studio/" .. id .. ".rbxm",
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

-- Publishes every Mod that has build data; returns "<Id>: <save result>" lines.
function Builder.publishAll(): { string }
	local report = {}
	for _, id in Builder.ids() do
		local model, saved = Builder.publish(id)
		local missing = model:GetAttribute("MissingParts")
		table.insert(
			report,
			id .. ": " .. saved .. (if missing then " | MISSING " .. tostring(missing) else "")
		)
	end
	return report
end

return Builder
