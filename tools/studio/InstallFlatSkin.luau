--!strict
-- Install a flat-material geometry skin into the Gauntlet gameplay place
-- (Studio Edit only). Round two, 2026-11-14: the baked-atlas skins read soft
-- and seamy in Studio, while the game's own guns are one MeshPart per
-- material with a flat Color + Roblox Material; this installs skins the same
-- way (export: tools/blender/export_roblox_flat.py, whole lines:
-- tools/blender/export_skin_items_flat.py -> manifest_flat.json).
--
--   install({
--     line = "Sealwork", gun = "Vandal", version = "flat-d",
--     assetId = <FBX Model asset id>,
--     parts = { SK_Root_01 = { b = "Root", c = {x, y, z}, s = {x, y, z},
--               col = "202825", mat = "SmoothPlastic", refl = 0.05, pat = "Sealwork_Ruby"? }, ... },
--     replaced = { Receiver = true, ... },      -- stock MeshPart prefixes removed
--     kept = { "D2A04A", "Metal" }?,            -- optional flat finish for the other stock parts
--     joints = { { name = "Rib_00", parent = "Root", c0 = {x, y, z, r00..r22} }, ... }?,
--     tiles = { Sealwork_Ruby = { id = <decal id>, studs = 0.4 }, ... },
--   }) -> (Model, { string })   -- the variant and its notes (unmatched stock parts)
-- Without `kept`, stock parts the skin does not replace stay exactly as
-- they are (scope lenses, loaded rounds, feed belts). `joints` adds rig
-- joints the stock rig lacks (the Giltfold Fan's ribs): a hidden joint part
-- and a Rig.Motors Motor6D whose C0 is the bone's rest frame in its parent
-- joint's (Blender) axes, so GunAnimator clips can drive it.
-- Open Cloud Model uploads arrive in centimetres (x100): parts are sized
-- from the manifest. Decal ids resolve to their Image ids for the tiles.
local InsertService = game:GetService("InsertService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

type PartSpec = {
	b: string,
	c: { number },
	s: { number },
	col: string,
	mat: string,
	refl: number,
	pat: string?,
	glow: number?,
	glowMix: number?,
	loadedRound: boolean?,
}
type Tile = { id: number, studs: number }
type Joint = {
	name: string,
	parent: string,
	c0: { number },
	axis: { number }?,
	phase: number?,
	travel: number?,
	tilt: number?,
	tether: boolean?,
}
type EnergyAnchor = { name: string, bone: string, point: { number }, phase: number?, mist: boolean }

local imageCache: { [number]: string } = {}

local function image(decalId: number): string
	local cached = imageCache[decalId]
	if cached then
		return cached
	end
	local result = "rbxassetid://" .. tostring(decalId)
	local ok, package = pcall(function()
		return InsertService:LoadAsset(decalId)
	end)
	if ok and package then
		local decal = package:FindFirstChildWhichIsA("Decal", true)
		local texture = decal and decal.Texture
		package:Destroy()
		if texture and texture ~= "" then
			result = texture
		end
	end
	imageCache[decalId] = result
	return result
end

local function addJoints(rig: Instance, joints: { Joint })
	local motors = assert(rig:FindFirstChild("Motors"), "rig Motors missing")
	for _, j in joints do
		if rig:FindFirstChild(j.name) then
			continue
		end
		local parent = rig:FindFirstChild(j.parent)
		assert(parent and parent:IsA("BasePart"), "Missing parent joint " .. j.parent)
		local c = j.c0
		local c0 =
			CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
		local part = Instance.new("Part")
		part.Name = j.name
		part.Size = Vector3.one * 0.1
		part.Transparency = 1
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Massless = true
		part.Anchored = false
		part.CFrame = parent.CFrame * c0
		part.Parent = rig
		local motor = Instance.new("Motor6D")
		motor.Name = j.name
		motor.Part0 = parent
		motor.Part1 = part
		motor.C0 = c0
		if j.axis then
			motor:SetAttribute("RuinIdleAxis", Vector3.new(j.axis[1], j.axis[2], j.axis[3]))
			motor:SetAttribute("RuinIdlePhase", j.phase)
			motor:SetAttribute("RuinIdleTravel", j.travel)
			motor:SetAttribute("RuinIdleTilt", j.tilt)
			motor:SetAttribute("RuinIdleTether", j.tether)
		end
		motor.Parent = motors
	end
end

local function install(args: { [string]: any }): (Model, { string })
	assert(
		RunService:IsStudio()
			and not RunService:IsRunning()
			and (game.PlaceId == 133387545285290 or game.PlaceId == 71551303511506),
		"Gauntlet Lobby or Match Studio Edit only"
	)
	local lineName: string = args.line
	local gun: string = args.gun
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

	local tiles: { [string]: Tile } = args.tiles or {}
	local package = InsertService:LoadAsset(args.assetId)
	local imported: { [string]: MeshPart } = {}
	for _, obj in package:GetDescendants() do
		if obj:IsA("MeshPart") then
			imported[obj.Name] = obj
		end
	end

	local variant = stock:Clone()
	local variantHandle = variant.PrimaryPart :: BasePart
	local rig = assert(variant:FindFirstChild("Rig"), gun .. " rig missing")
	local replaced: { [string]: boolean } = args.replaced
	local kept: { string }? = args.kept
	local notes: { string } = {}
	local ok, err = pcall(function()
		if args.joints then
			addJoints(rig, args.joints)
		end
		for _, obj in variant:GetChildren() do
			if obj:IsA("MeshPart") then
				local prefix = obj.Name:match("^[^_]+")
				if prefix and replaced[prefix] then
					obj:Destroy()
				elseif kept and not obj.Name:match("_Neon$") then
					for _, c in obj:GetChildren() do
						if c:IsA("SurfaceAppearance") then
							c:Destroy()
						end
					end
					obj.Color = Color3.fromHex(kept[1])
					obj.Material = (Enum.Material :: any)[kept[2]]
				else
					table.insert(notes, "kept stock " .. obj.Name)
				end
			end
		end
		-- FBX import applies (-x, z, y); rotate onto the stock handle axes.
		local rotation = CFrame.fromMatrix(Vector3.zero, Vector3.zAxis, Vector3.yAxis)
		for name, spec in args.parts :: { [string]: PartSpec } do
			local source = assert(imported[name], "Missing imported mesh " .. name)
			local want = Vector3.new(spec.s[1], spec.s[3], spec.s[2])
			assert((source.Size / 100 - want).Magnitude < 0.01, "Import scale mismatch " .. name)
			local part = source:Clone()
			part.Size = want
			local c = spec.c
			part.CFrame = variantHandle.CFrame * CFrame.new(-c[2], c[3], -c[1]) * rotation
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
			part.Massless = true
			part.CollisionFidelity = Enum.CollisionFidelity.Box
			part.TextureID = ""
			local color = Color3.fromHex(spec.col)
			if spec.mat == "Neon" then
				-- Neon blows bright colours out to white; darken so the hue survives.
				color = color:Lerp(Color3.new(0, 0, 0), 0.4)
			end
			part.Color = color
			part.Material = (Enum.Material :: any)[spec.mat]
			part.Reflectance = spec.refl
			if spec.glow then
				part:SetAttribute("RuinIdleGlow", spec.glow)
				part:SetAttribute("RuinIdleGlowMix", spec.glowMix)
				part:SetAttribute("RuinIdleMagazine", spec.b == "Mag")
			end
			if spec.loadedRound then
				part:SetAttribute("SkinLoadedRound", true)
			end
			local pattern = spec.pat
			if pattern then
				local tile = assert(tiles[pattern], "Missing tile " .. pattern)
				local texture = image(tile.id)
				for _, face in Enum.NormalId:GetEnumItems() do
					local t = Instance.new("Texture")
					t.Name = "Pattern"
					t.Texture = texture
					t.Face = face
					t.StudsPerTileU = tile.studs
					t.StudsPerTileV = tile.studs
					if pattern == "Moltframe_Flow" then
						t:SetAttribute("MoltframeFlowLayer", 1) -- camera guns drift it (Config.SkinPreview)
					end
					t.Parent = part
				end
			end
			part.Parent = variant
			local joint = rig:FindFirstChild(spec.b)
			assert(joint and joint:IsA("BasePart"), "Missing joint " .. spec.b)
			local weld = Instance.new("Weld")
			weld.Name = "SkinCosmeticWeld"
			weld.Part0 = joint
			weld.Part1 = part
			weld.C0 = joint.CFrame:ToObjectSpace(part.CFrame)
			weld.Parent = part
		end
		for _, spec in (args.energy or {}) :: { EnergyAnchor } do
			local joint = rig:FindFirstChild(spec.bone)
			assert(joint and joint:IsA("BasePart"), "Missing energy anchor joint " .. spec.bone)
			local p = spec.point
			local world = variantHandle.CFrame:PointToWorldSpace(Vector3.new(-p[2], p[3], -p[1]))
			local anchor = Instance.new("Attachment")
			anchor.Name = spec.name
			anchor.Position = joint.CFrame:PointToObjectSpace(world)
			anchor:SetAttribute("RuinIdleLight", spec.phase)
			anchor:SetAttribute("RuinIdleMist", spec.mist)
			anchor:SetAttribute("RuinIdleMagazine", spec.bone == "Mag")
			anchor.Parent = joint
		end
		for _, locator in { "AimPoint", "RightGrip", "LeftGrip", "Muzzle", "Eject" } do
			-- lihfolk-ignore: findfirstchild-chain (both results are nil-checked below)
			local a = stock:FindFirstChild(locator, true) :: Attachment?
			-- lihfolk-ignore: findfirstchild-chain (nil-checked with `a` below)
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
	if not ok then
		variant:Destroy()
		error(err)
	end
	for _, old in line:GetChildren() do
		if old.Name == gun or old.Name:match("^" .. gun .. "_") then
			old:Destroy()
		end
	end
	variant.Name = gun
	variant:SetAttribute("SkinLine", lineName)
	variant:SetAttribute("SkinVersion", args.version)
	variant:SetAttribute("SkinSourceAsset", args.assetId)
	if args.adsDistance then
		variant:SetAttribute("SkinAdsDistance", args.adsDistance)
	end
	variant:SetAttribute("SkinReady", true)
	variant:SetAttribute("PreviewGeometry", lineName .. "_" .. gun .. "_" .. tostring(args.version))
	if args.item then
		variant:SetAttribute("SkinItem", args.item) -- the knife slot's model: Fan, Blade, Dagger
	end
	variant.Parent = line
	ChangeHistoryService:SetWaypoint(
		"Install " .. lineName .. " " .. gun .. " " .. tostring(args.version)
	)
	return variant, notes
end

return install
