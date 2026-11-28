--!strict
-- Builds the lobby hologram stands (vault/02 Art/Lobby Holograms.md) into Workspace.LobbyV5.Holograms.
-- Run in the Lobby place's edit DataModel (Studio MCP execute_luau or the command bar), then save the place.
-- Re-runnable: each stand is rebuilt from scratch.
--
-- Look (owner 2026-11-28, from RIVALS' imported HologramFreeRewards / SuperStarterBundle: "less subtle, enticing"):
--   * projector: tools/blender/lobby_v5/build_holo_projector.py (FBX asset below, 1 unit = 1 stud, built x S)
--   * a bold Neon light cone and floor ring in the offer's colour, a light at the lens, rising motes
--   * bundles ("solid"): clean copies of the real items in their real colours, with a light burst behind them
--     (rays + glow + star glints, our own textures in art-source/lobby/HoloProjector/textures)
--   * single emblems ("neon"): a pale Neon core and a saturated Neon shell 1.06x, like a hologram
-- No ForceField: its scrolling shimmer read as flashing (owner).
-- The client (src/lobby/client/Controllers/LobbyHolograms.luau) turns / bobs the `Hologram` model, swaps in
-- `HologramAlt` once the offer is owned, and adds the prompt on `PromptAnchor`; it reads the stand's `Offer`.

local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CrateLook = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CrateLook"))

local PROJECTOR_ASSET = 106433727165434 -- HoloProjector_v02.fbx
local TEX = {
	-- image ids (the Open Cloud upload returns a Decal id: InsertService:LoadAsset(decal).Decal.Texture)
	rays = "rbxassetid://116935114007248", -- holo_rays.png (decal 135781545064670)
	glow = "rbxassetid://113177783739708", -- holo_glow.png (decal 113153565884236)
	star = "rbxassetid://100881118533549", -- holo_star.png (decal 133400187158110)
}
local S = 1.35 -- projector scale
local HOVER_Y = 8.4 -- studs above the floor: the item group's centre (at the cone's mouth, like RIVALS)
local HUB = Vector3.new(0, 0, -1600) -- stands face the hub centre (spawn)
local TAG = "LobbyHologram"

-- per offer: `color` = effects / emblem colour, `neon` = the same hue dark enough that Neon doesn't clip to white
type Accent = { color: Color3, neon: Color3 }
local ACCENT: { [string]: Accent } = {
	gold = { color = Color3.fromHex("FFC23D"), neon = Color3.fromHex("B07A12") },
	blue = { color = Color3.fromHex("4FC8FF"), neon = Color3.fromHex("1C86B8") },
	purple = { color = Color3.fromHex("A66CFF"), neon = Color3.fromHex("5B2FB0") },
	green = { color = Color3.fromHex("46E08A"), neon = Color3.fromHex("1E8A4C") },
}

type Item = { source: Instance, scale: number, cf: CFrame, tier: number? }
type Stand = {
	name: string,
	offer: string,
	pos: Vector3,
	accent: string,
	kind: "solid" | "neon",
	items: { Item },
	alt: { Item }?,
}

local skins = ServerStorage:WaitForChild("WeaponSkins")
local crates = ReplicatedStorage:WaitForChild("Crates")
local kit = ServerStorage:WaitForChild("LobbyKit")
local tempest = skins:WaitForChild("TempestStrike")

local function deg(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

-- guns are authored muzzle along -Z, upright Y: turn them side-on to the viewer
local SIDE = deg(0, 90, 0)

local STANDS: { Stand } = {
	{
		name = "Holo_Starter",
		offer = "Starter",
		pos = Vector3.new(-24, 0, -1580),
		accent = "gold",
		kind = "solid",
		items = {
			{
				source = skins:WaitForChild("Payload"):WaitForChild("Bulldog"),
				scale = 2.8,
				cf = CFrame.new(0, 1.55, 0) * SIDE * deg(0, 0, -6),
			},
			{
				source = crates:WaitForChild("Crate"),
				scale = 1.2,
				tier = 1,
				cf = CFrame.new(-2.3, -0.5, 0) * deg(0, 24, 0),
			},
			{
				source = crates:WaitForChild("CharmBox"),
				scale = 1.45,
				cf = CFrame.new(2.4, -0.45, -0.1) * deg(0, -26, 0),
			},
			{
				source = kit:WaitForChild("MarketShowCoins"),
				scale = 1.1,
				cf = CFrame.new(0.05, -1.05, -1.2) * deg(0, 8, 0),
			},
		},
		-- shown instead once the Starter Bundle is owned: the Standard Case (opens the Shop's cases)
		alt = {
			{
				source = crates:WaitForChild("Crate"),
				scale = 1.9,
				tier = 1,
				cf = CFrame.new(0, 0, 0) * deg(0, 0, 0),
			},
		},
	},
	{
		name = "Holo_FreeRewards",
		offer = "FreeRewards",
		pos = Vector3.new(-12.5, 0, -1572.5),
		accent = "green",
		kind = "neon",
		items = {
			{ source = crates:WaitForChild("GoodieBag"), scale = 3.4, cf = CFrame.new(0, 0, 0) },
		},
	},
	{
		name = "Holo_TempestStrike",
		offer = "TempestStrike",
		pos = Vector3.new(24, 0, -1580),
		accent = "blue",
		kind = "solid",
		items = {
			{
				source = tempest:WaitForChild("Vandal"),
				scale = 2.2,
				cf = CFrame.new(0, 2.15, 0.2) * SIDE * deg(0, 0, -5),
			},
			{
				source = tempest:WaitForChild("Marshal"),
				scale = 1.85,
				cf = CFrame.new(0.2, 0.8, 0.45) * SIDE * deg(0, 0, 3),
			},
			{
				source = tempest:WaitForChild("Sheriff"),
				scale = 2.1,
				cf = CFrame.new(-2.0, -0.55, -0.4) * SIDE * deg(0, 0, -8),
			},
			{
				source = tempest:WaitForChild("Knife"),
				scale = 1.7,
				cf = CFrame.new(2.1, -0.45, -0.65) * SIDE * deg(0, 0, 35),
			},
		},
	},
	{
		name = "Holo_BattlePass",
		offer = "BattlePass",
		pos = Vector3.new(12.5, 0, -1572.5),
		accent = "purple",
		kind = "neon",
		items = {
			{ source = kit:WaitForChild("SeasonCrest"), scale = 0.24, cf = CFrame.new(0, 0, 0) },
		},
	},
}

local function clean(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			d.Massless = true
			if d.Transparency >= 0.95 then
				d:Destroy()
			end
		elseif
			not (
				d:IsA("Model")
				or d:IsA("Folder")
				or d:IsA("SpecialMesh")
				or d:IsA("SurfaceAppearance")
			)
		then
			d:Destroy()
		end
	end
end

-- a part as a hologram: `core` = pale, nearly solid; otherwise the saturated shell
local function neonLayer(model: Instance, accent: Accent, core: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Material = Enum.Material.Neon
			d.Color = if core then accent.neon:Lerp(Color3.new(1, 1, 1), 0.3) else accent.neon
			d.Transparency = if core then 0.08 else 0.55
			if d:IsA("MeshPart") then
				d.TextureID = ""
			end
		elseif d:IsA("SpecialMesh") then
			d.TextureId = ""
		elseif d:IsA("SurfaceAppearance") then
			d:Destroy()
		end
	end
end

local function holoItem(item: Item, parent: Instance, s: Stand)
	local copy = item.source:Clone()
	local model: Model
	if copy:IsA("Model") then
		model = copy
	else
		model = Instance.new("Model")
		copy.Parent = model
	end
	if item.tier then
		CrateLook.paint(model, item.tier)
	end
	clean(model)
	model.Name = item.source.Name
	model:ScaleTo(item.scale)
	local box = model:GetBoundingBox()
	model.WorldPivot = box
	model:PivotTo(item.cf)
	if s.kind == "neon" then
		local shell = model:Clone()
		neonLayer(model, ACCENT[s.accent], true)
		neonLayer(shell, ACCENT[s.accent], false)
		shell:ScaleTo(1.06)
		shell:PivotTo(item.cf)
		shell.Name = "Shell"
		shell.Parent = model
	end
	model.Parent = parent
end

local function group(name: string, items: { Item }, parent: Instance, at: CFrame, s: Stand): Model
	local holder = Instance.new("Model")
	holder.Name = name
	for _, item in items do
		holoItem(item, holder, s)
	end
	holder.WorldPivot = CFrame.new()
	holder:PivotTo(at)
	holder.Parent = parent
	return holder
end

local imported = InsertService:LoadAsset(PROJECTOR_ASSET)
local meshes: { [string]: MeshPart } = {}
for _, d in imported:GetDescendants() do
	if d:IsA("MeshPart") then
		meshes[d.Name] = d
	end
end
assert(meshes.Base_Body and meshes.Holo_Cone, "projector asset is missing parts")

local function part(name: string, parent: Instance, at: CFrame): MeshPart
	local source = meshes[name]
	local p = source:Clone()
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = source.Size * S
	p.CFrame = at * CFrame.new(source.Position * S)
	p.Parent = parent
	return p
end

local function hidden(name: string, size: Vector3, cf: CFrame, collide: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Transparency = 1
	p.CanCollide = collide
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function seq(points: { { number } }): NumberSequence
	local kps = {}
	for _, p in points do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(kps)
end

local function emitter(parent: Instance, name: string, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.LightEmission = 1
	e.LightInfluence = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local lobby = workspace:WaitForChild("LobbyV5")
local folder = lobby:FindFirstChild("Holograms") or Instance.new("Folder")
folder.Name = "Holograms"
folder.Parent = lobby
for _, old in folder:GetChildren() do
	old:Destroy()
end

local built = {}
for _, s in STANDS do
	local accent = ACCENT[s.accent]
	local base = CFrame.lookAt(s.pos, Vector3.new(HUB.X, s.pos.Y, HUB.Z))
	local stand = Instance.new("Model")
	stand.Name = s.name
	stand:SetAttribute("Offer", s.offer)
	stand:SetAttribute("Source", "tools/studio/lobby_v5/BuildLobbyHolograms.luau")

	local projector = Instance.new("Model")
	projector.Name = "Projector"
	local body = part("Base_Body", projector, base)
	body.Color = Color3.fromHex("3A3D44")
	body.Material = Enum.Material.Metal
	local trim = part("Base_Trim", projector, base)
	trim.Color = Color3.fromHex("24262B")
	trim.Material = Enum.Material.Metal
	local light = part("Base_Light", projector, base)
	light.Color = accent.neon
	light.Material = Enum.Material.Neon
	light.CastShadow = false
	local ring = part("Holo_Ring", projector, base * CFrame.new(0, 0.03, 0))
	ring.Color = accent.neon
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.1
	ring.CastShadow = false
	local cone = part("Holo_Cone", projector, base)
	cone.Name = "Cone"
	cone.Color = accent.neon
	cone.Material = Enum.Material.Neon
	cone.Transparency = 0.8
	cone.CastShadow = false

	local lens = Instance.new("Attachment")
	lens.Name = "Lens"
	lens.Parent = light
	lens.WorldPosition = (base * CFrame.new(0, 1.2 * S, 0)).Position
	local glow = Instance.new("PointLight")
	glow.Color = accent.color
	glow.Brightness = 1
	glow.Range = 12
	glow.Shadows = false
	glow.Parent = lens
	emitter(lens, "Motes", {
		Color = ColorSequence.new(accent.color),
		Rate = 6,
		Lifetime = NumberRange.new(2.4, 3.4),
		Speed = NumberRange.new(1.4, 2.2),
		SpreadAngle = Vector2.new(16, 16),
		Size = seq({ { 0, 0.14 }, { 1, 0 } }),
		Transparency = seq({ { 0, 0.1 }, { 1, 1 } }),
	})

	-- the burst behind the items (bundles only): slow-turning rays, a soft glow and star glints
	if s.kind == "solid" then
		local burst = Instance.new("Attachment")
		burst.Name = "Burst"
		burst.Parent = cone
		burst.WorldPosition = (base * CFrame.new(0, HOVER_Y + 0.2, 1.2)).Position
		emitter(burst, "Rays", {
			Texture = TEX.rays,
			Color = ColorSequence.new(accent.color),
			LockedToPart = true,
			Rate = 1.2,
			Lifetime = NumberRange.new(3.2, 3.2),
			Speed = NumberRange.new(0, 0),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-10, 10),
			Size = seq({ { 0, 12 }, { 1, 14 } }),
			Transparency = seq({ { 0, 1 }, { 0.35, 0.3 }, { 0.65, 0.3 }, { 1, 1 } }),
			ZOffset = -4,
		})
		emitter(burst, "Glow", {
			Texture = TEX.glow,
			Color = ColorSequence.new(accent.color),
			LockedToPart = true,
			Rate = 1.5,
			Lifetime = NumberRange.new(2, 2),
			Speed = NumberRange.new(0, 0),
			Size = seq({ { 0, 8 }, { 1, 8 } }),
			Transparency = seq({ { 0, 1 }, { 0.5, 0.55 }, { 1, 1 } }),
			ZOffset = -5,
		})
		emitter(burst, "Glints", {
			Texture = TEX.star,
			Color = ColorSequence.new(Color3.new(1, 1, 1), accent.color),
			Rate = 3,
			Lifetime = NumberRange.new(0.6, 0.9),
			Speed = NumberRange.new(2.5, 4),
			Drag = 5,
			SpreadAngle = Vector2.new(180, 180),
			Rotation = NumberRange.new(0, 0),
			Size = seq({ { 0, 0 }, { 0.3, 0.9 }, { 1, 0 } }),
			Transparency = seq({ { 0, 0 }, { 1, 0.3 } }),
			ZOffset = 2,
		})
	end
	projector.Parent = stand

	-- keep-out: players can't climb onto the base or walk into the hologram (invisible cylinder inside the ring)
	local keep = hidden(
		"KeepOut",
		Vector3.new(10, 3.4 * S, 3.4 * S),
		base * CFrame.new(0, 5, 0) * deg(0, 0, 90),
		true
	)
	keep.Shape = Enum.PartType.Cylinder
	keep.Parent = stand
	-- the prompt's anchor (the client adds the ProximityPrompt)
	hidden("PromptAnchor", Vector3.new(1, 1, 1), base * CFrame.new(0, 3, 0), false).Parent = stand

	local hover = base * CFrame.new(0, HOVER_Y, 0)
	group("Hologram", s.items, stand, hover, s)
	if s.alt then
		local alt = group("HologramAlt", s.alt, stand, hover, s)
		for _, d in alt:GetDescendants() do
			if d:IsA("BasePart") then
				d:SetAttribute("ShowT", d.Transparency)
				d.Transparency = 1 -- the client shows it once the main offer is owned
			end
		end
	end
	stand.PrimaryPart = body
	stand.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- the client sees a stand whole or not at all
	stand.Parent = folder
	CollectionService:AddTag(stand, TAG)
	table.insert(built, `{s.name}: {#stand:GetDescendants()} instances`)
end
imported:Destroy()
return table.concat(built, "\n")
