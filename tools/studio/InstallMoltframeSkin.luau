--!strict
-- Install a Moltframe geometry skin (v04 pipeline) into the Gauntlet gameplay
-- place, Studio Edit only. Run from the command bar / Studio MCP:
--   local install = require(<this module>)  -- or paste and call install({...})
--   install({
--     gun = "Vandal", version = "v04", assetId = <FBX Model asset id>,
--     line = "Moltframe",                          -- skin line folder (default Moltframe)
--     parts = <manifest.roblox_parts>,             -- MF_<Bone>_Body / MF_<Bone>_Chamber
--     replaced = { "Receiver", "Handguard", ... }, -- stock MeshPart prefixes to remove
--     atlas = { ColorMap = <decal id>, RoughnessMap = <decal id>, MetalnessMap = <decal id> },
--     chamber = { ColorMap = <decal id> }, flow = <decal id>,
--     solid = { ColorMap = <decal id>, RoughnessMap = <decal id>, MetalnessMap = <decal id> },
--   })
-- Open Cloud image uploads return *Decal* ids; SurfaceAppearance and Texture
-- need the Image id behind each Decal (the v02 maps failed for this reason),
-- so every id is resolved through InsertService first.
local InsertService = game:GetService("InsertService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local FLOW_TAG = "MoltframeFlowLayer"
local PULSE_TAG = "MoltframeChamberPulse"

local function image(decalId: number): string
	local ok, package = pcall(function()
		return InsertService:LoadAsset(decalId)
	end)
	if ok and package then
		local decal = package:FindFirstChildWhichIsA("Decal", true)
		local texture = decal and decal.Texture
		package:Destroy()
		if texture and texture ~= "" then
			return texture
		end
	end
	-- Already an Image id (or not loadable as a Decal): use it directly.
	return "rbxassetid://" .. tostring(decalId)
end

local function appearance(name: string, maps: { [string]: number }): SurfaceAppearance
	local a = Instance.new("SurfaceAppearance")
	a.Name = name
	for key, id in maps do
		(a :: any)[key] = image(id)
	end
	return a
end

-- The NormalId of `part` whose world direction best matches `world`.
local function faceToward(part: BasePart, world: Vector3): Enum.NormalId
	local best, score = Enum.NormalId.Right, -2
	for _, id in Enum.NormalId:GetEnumItems() do
		local d = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(id))
		local s = d:Dot(world.Unit)
		if s > score then
			best, score = id, s
		end
	end
	return best
end

type Spec = { center: { number }, size: { number }, bone: string }

local function install(args: { [string]: any }): Model
	assert(
		RunService:IsStudio() and not RunService:IsRunning() and game.PlaceId == 133387545285290,
		"Gauntlet gameplay Studio Edit only"
	)
	local gun: string = args.gun
	local version: string = args.version
	local lineName: string = args.line or "Moltframe"
	local weapons = ReplicatedStorage:FindFirstChild("Weapons")
	local found = weapons and weapons:FindFirstChild(gun)
	assert(found and found:IsA("Model") and found.PrimaryPart, "Stock " .. gun .. " missing")
	local stock = found :: Model
	local handle = stock.PrimaryPart :: BasePart

	local skins = ReplicatedStorage:FindFirstChild("WeaponSkins") or Instance.new("Folder")
	skins.Name = "WeaponSkins"
	skins.Parent = ReplicatedStorage
	local line = skins:FindFirstChild(lineName) or Instance.new("Folder")
	line.Name = lineName
	line.Parent = skins
	local previous = line:FindFirstChild(gun)
	if previous then
		-- keep the earlier template for comparison, out of the resolver's way
		previous.Name = gun .. "_" .. tostring(previous:GetAttribute("SkinVersion") or "old")
		previous:SetAttribute("SkinReady", false)
	end

	local package = InsertService:LoadAsset(args.assetId)
	local imported: { [string]: MeshPart } = {}
	for _, obj in package:GetDescendants() do
		if obj:IsA("MeshPart") then
			imported[obj.Name] = obj
		end
	end

	local atlas = appearance("Moltframe_" .. version, args.atlas)
	local chamberMaps = table.clone(args.chamber)
	local solid = args.solid and appearance("Moltframe_Solid", args.solid)
	local flowImage = args.flow and image(args.flow)

	local variant = stock:Clone()
	local variantHandle = variant.PrimaryPart :: BasePart
	local rig = assert(variant:FindFirstChild("Rig"), gun .. " rig missing")
	local replaced: { [string]: boolean } = {}
	for _, name in args.replaced do
		replaced[name] = true
	end

	local ok, err = pcall(function()
		for _, obj in variant:GetChildren() do
			if obj:IsA("MeshPart") then
				local prefix = obj.Name:match("^[^_]+")
				if prefix and replaced[prefix] then
					obj:Destroy()
				elseif solid then
					-- retained stock hardware (sights, controls): skin finish on its own UVs
					for _, c in obj:GetChildren() do
						if c:IsA("SurfaceAppearance") then
							c:Destroy()
						end
					end
					obj.Color = Color3.new(1, 1, 1)
					solid:Clone().Parent = obj
				end
			end
		end
		-- FBX import applies (-x, z, y); rotate onto the stock handle axes.
		local rotation = CFrame.fromMatrix(Vector3.zero, Vector3.zAxis, Vector3.yAxis)
		local leftWorld = variantHandle.CFrame:VectorToWorldSpace(Vector3.new(-1, 0, 0)) -- Blender +Y
		for name, spec in args.parts :: { [string]: Spec } do
			local source = assert(imported[name], "Missing imported mesh " .. name)
			local part = source:Clone()
			local c, s = spec.center, spec.size
			assert(
				(Vector3.new(s[1], s[3], s[2]) - source.Size).Magnitude < 0.01,
				"Import scale mismatch " .. name
			)
			local joint = rig:FindFirstChild(spec.bone)
			assert(joint and joint:IsA("BasePart"), "Missing joint " .. spec.bone)
			part.CFrame = variantHandle.CFrame * CFrame.new(-c[2], c[3], -c[1]) * rotation
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
			part.Massless = true
			part.CollisionFidelity = Enum.CollisionFidelity.Box
			part.Color = Color3.new(1, 1, 1)
			if name:match("_Chamber$") then
				local a = appearance("Moltframe_Chamber", chamberMaps)
				a:SetAttribute(PULSE_TAG, true)
				a.Parent = part
				if flowImage then
					for _, sign in { 1, -1 } do
						local face = faceToward(part, leftWorld * sign)
						for layer, spec2 in { { 1.6, 0.8, 0.45 }, { 1.0, 0.5, 0.62 } } do
							local t = Instance.new("Texture")
							t.Name = "MoltframeFlow" .. layer
							t.Texture = flowImage
							t.Face = face
							t.StudsPerTileU = spec2[1]
							t.StudsPerTileV = spec2[2]
							t.Transparency = spec2[3]
							t.OffsetStudsU = layer * 0.37
							t:SetAttribute(FLOW_TAG, layer)
							t.Parent = part
						end
					end
				end
			else
				atlas:Clone().Parent = part
			end
			part.Parent = variant
			local weld = Instance.new("Weld")
			weld.Name = "MoltframeCosmeticWeld"
			weld.Part0 = joint
			weld.Part1 = part
			weld.C0 = joint.CFrame:ToObjectSpace(part.CFrame)
			weld.Parent = part
		end
		for _, locator in { "AimPoint", "RightGrip", "LeftGrip", "Muzzle", "Eject" } do
			-- lihfolk-ignore: findfirstchild-chain (both results are nil-checked below)
			local a = stock:FindFirstChild(locator, true) :: Attachment?
			local b = variant:FindFirstChild(locator, true) :: Attachment?
			if a and b then
				assert(
					handle.CFrame
						:ToObjectSpace(a.WorldCFrame)
						:FuzzyEq(variantHandle.CFrame:ToObjectSpace(b.WorldCFrame), 1e-4),
					locator .. " moved"
				)
			end
		end
	end)
	package:Destroy()
	atlas:Destroy()
	if solid then
		solid:Destroy()
	end
	if not ok then
		variant:Destroy()
		if previous then
			previous.Name = gun
			previous:SetAttribute("SkinReady", true)
		end
		error(err)
	end
	variant.Name = gun
	variant:SetAttribute("SkinLine", lineName)
	variant:SetAttribute("SkinVersion", version)
	variant:SetAttribute("SkinReady", true)
	variant:SetAttribute("PreviewGeometry", lineName .. "_" .. gun .. "_" .. version)
	variant.Parent = line
	ChangeHistoryService:SetWaypoint("Install " .. lineName .. " " .. gun .. " " .. version)
	return variant
end

return install
