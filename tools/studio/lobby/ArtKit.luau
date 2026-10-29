--!strict
-- Lobby art kit: the prelude for the Art_*.luau scripts (phase 1 steps 4-7).
-- bundle.py puts it after GreyboxKit.luau whenever an Art_* body is bundled, so
-- polar(), SEG, C, box(), make(), sign() and the rest are in scope too.
--
-- The art pass sits on top of the greybox, which stays the collision:
--   Workspace.Lobby.Greybox.<Section>  collision parts. Parts the art replaces are
--                                      hidden (Transparency 1, no shadow) but keep
--                                      CanCollide; parts that stay visible get a
--                                      finished look (finish()). Never delete them.
--   Workspace.Lobby.Art.<Section>      visual kit pieces (MeshParts, no collision),
--                                      cloned from ServerStorage.LobbyKit (kit_bundle.py).
-- Each Art_<Area>.luau rebuilds its own Art folders and re-applies its finishes,
-- so it can run again after its greybox script.

local ServerStorage = game:GetService("ServerStorage")

-- Finished looks (vault/02 Art/Lobby Kit.md style sheet, as tuned in tools/blender/lobbykit.py).
-- Variants are MaterialVariants in MaterialService (Materials.luau); until they exist
-- the base material shows.
type ArtLook = { material: Enum.Material, color: Color3, variant: string? }
local LOOK: { [string]: ArtLook } = {
	ConcreteBoard = {
		material = Enum.Material.Concrete,
		color = Color3.fromHex("8E8C87"),
		variant = "Lobby_ConcreteBoard",
	},
	ConcreteShade = {
		material = Enum.Material.Concrete,
		color = Color3.fromHex("6B6965"),
		variant = "Lobby_ConcreteBoard",
	},
	ConcretePolished = {
		material = Enum.Material.Concrete,
		color = Color3.fromHex("B9B4AA"),
		variant = "Lobby_ConcretePolished",
	},
	ConcreteInlay = {
		material = Enum.Material.Concrete,
		color = Color3.fromHex("F2EADB"),
		variant = "Lobby_ConcretePolished",
	},
	ConcreteDark = {
		material = Enum.Material.Concrete,
		color = Color3.fromHex("3A3B3D"),
		variant = "Lobby_ConcreteDark",
	},
	ConcreteHoned = {
		material = Enum.Material.Concrete,
		color = Color3.fromHex("7E7C78"),
		variant = "Lobby_ConcreteDark",
	},
	Terrazzo = {
		material = Enum.Material.Concrete,
		color = Color3.fromHex("D6C8B0"),
		variant = "Lobby_Terrazzo",
	},
	Rock = {
		material = Enum.Material.Slate,
		color = Color3.fromHex("625D57"),
		variant = "Lobby_Rock",
	},
	RockDuels = {
		material = Enum.Material.Slate,
		color = Color3.fromHex("2E2F33"),
		variant = "Lobby_Rock",
	},
	SteelBlack = { material = Enum.Material.Metal, color = Color3.fromHex("1C1D20") },
	SteelBrushed = { material = Enum.Material.Metal, color = Color3.fromHex("A7ABB0") },
	Oak = { material = Enum.Material.Wood, color = Color3.fromHex("94683F"), variant = "Lobby_Oak" },
	Brass = { material = Enum.Material.Metal, color = Color3.fromHex("B08D55") },
	Glass = { material = Enum.Material.Glass, color = Color3.fromHex("A9C9CF") },
	Sign = { material = Enum.Material.SmoothPlastic, color = Color3.fromHex("2A2C30") },
	Screen = { material = Enum.Material.SmoothPlastic, color = Color3.fromHex("0B0D10") },
}

-- Glow colours (Neon, thin strips only).
local GLOW = {
	cove = Color3.fromHex("FFF1DC"),
	cool = Color3.fromHex("DDE8F2"),
	duelsRed = Color3.fromHex("B3262E"),
	m1v1 = C.m1v1,
	m2v2 = C.m2v2,
	m3v3 = C.m3v3,
	m4v4 = C.m4v4,
	gauntlet = C.gauntlet,
	dormant = C.unpowered,
}

local function artRoot(): Instance
	local lobby = workspace:FindFirstChild("Lobby")
	assert(lobby, "no Workspace.Lobby (run the greybox first)")
	local root = lobby:FindFirstChild("Art")
	if not root then
		local folder = Instance.new("Folder")
		folder.Name = "Art"
		folder.Parent = lobby
		root = folder
	end
	assert(root)
	return root
end

-- The greybox folder of a section (Rotunda, Ring, Duels, ...), or nil.
local function grey(section: string): Instance?
	local lobby = workspace:FindFirstChild("Lobby")
	local root = lobby and lobby:FindFirstChild("Greybox")
	return root and root:FindFirstChild(section)
end

-- Replaces Workspace.Lobby.Art.<f.Name> with f (build into an unparented folder first).
local function publishArt(f: Folder)
	local root = artRoot()
	local old = root:FindFirstChild(f.Name)
	if old then
		old:Destroy()
	end
	f.Parent = root
	task.wait()
	local parts = 0
	for _, d in f:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	local line = string.format("Art.%s %d parts", f.Name, parts)
	table.insert(REPORT, line)
	print("Lobby art: " .. line)
end

local function kit(name: string): Model
	local lib = ServerStorage:FindFirstChild("LobbyKit")
	assert(lib, "no ServerStorage.LobbyKit (run kit_bundle.py output first)")
	local m = lib:FindFirstChild(name)
	assert(m and m:IsA("Model"), "no kit piece " .. name)
	return m
end

local function hasKit(name: string): boolean
	local lib = ServerStorage:FindFirstChild("LobbyKit")
	return lib ~= nil and lib:FindFirstChild(name) ~= nil
end

-- Clones a kit piece, puts its origin (the Blender piece origin) at cf.
local function put(parent: Instance, piece: string, cf: CFrame, name: string?): Model
	local m = kit(piece):Clone()
	m.Name = name or piece
	m:PivotTo(cf)
	m.Parent = parent
	return m
end

-- Round kit: the master spans bearings 0..11.25 around the circle centre; this turns it
-- to start at bearing b (clockwise from north), around (cx, cz), at height y.
local function segCF(b: number, y: number?, cx: number?, cz: number?): CFrame
	return CFrame.new(cx or 0, y or 0, cz or 0) * CFrame.Angles(0, -math.rad(b), 0)
end

-- Straight kit: origin at pos, the piece's +X (its front, into the room) along `front`.
local function faceCF(pos: Vector3, front: Vector3): CFrame
	local f = Vector3.new(front.X, 0, front.Z).Unit
	return CFrame.fromMatrix(pos, f, Vector3.yAxis)
end

-- Straight kit at polar (r, b), facing the centre (cx, cz).
local function ringCF(r: number, b: number, y: number?, cx: number?, cz: number?): CFrame
	local x, z = polar(r, b)
	local pos = Vector3.new((cx or 0) + x, y or 0, (cz or 0) + z)
	return faceCF(pos, Vector3.new(-x, 0, -z))
end

-- Finished look on a part that stays visible (usually greybox collision).
local function finish(p: Instance, look: string)
	local l = LOOK[look]
	assert(l, "no look " .. look)
	if p:IsA("BasePart") then
		p.Material = l.material
		p.Color = l.color
		p.MaterialVariant = l.variant or ""
		p.Transparency = 0
	end
end

-- Hides a greybox part the art replaces; it keeps its collision.
local function hide(p: Instance)
	if p:IsA("BasePart") then
		p.Transparency = 1
		p.CastShadow = false
		for _, d in p:GetChildren() do
			if d:IsA("SurfaceGui") or d:IsA("Decal") or d:IsA("Texture") then
				d:Destroy()
			end
		end
	end
end

-- Recolours every Glow part of a placed piece (mode colours, dormant grey).
local function tint(m: Instance, color: Color3)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Glow") then
			d.Color = color
		end
	end
end

local function artSection(name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	return f
end
