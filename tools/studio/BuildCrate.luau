--!strict
-- Builds an animation-ready crate template in ReplicatedStorage.Crates from its uploaded mesh
-- (vault/01 Design/Inventory and Crates.md). Run in the Lobby place's edit DataModel (Studio
-- MCP execute_luau, or the command bar) with WHICH set; re-run after a re-upload. Save the
-- place after.
--
-- Sources (art-source/lobby/Exports/assets.json):
--   Crate      tools/blender/crates/build_crate.py      -> Crate.fbx      (Standard, Elite, Apex)
--   KnifeCase  tools/blender/crates/build_knife_case.py -> KnifeCase.fbx  (the Knife case)
-- Both have the same part names and rig, only sizes differ. Blender to Roblox axes:
-- Roblox (x, y, z) = Blender (-x, z, y), 1 unit = 1 stud; the front faces -Z.
--
-- Rig (Motor6D, so the Animation Editor and code can both drive it):
--   Root (anchored, invisible, PrimaryPart, floor centre)
--     -> Base   (Base_Body; every Base_* part welds to it)   shake / hop the whole crate
--        -> Lid     (Lid_Body on the back hinge axis; Lid_* weld to it)
--           -> Gem  (Gem_Gem at its centre)
--        -> LatchL / LatchR (knuckle axis)   flip down before the lid opens
--        -> Handle (mount axis)               swings when it shakes
-- Joints rotate about their local X (the crate's length). In Roblox the open direction is a
-- POSITIVE X angle (Blender's X is flipped): Lid +105 deg opens up and back, latches +130
-- drop forward and down, the handle +45 swings out (checked in play 2026-11-20).
-- Attachments for effects: Base_Body.Burst (inside, the loot reveal), Base_Body.Seam (front of
-- the lid seam), Base_Light.Glow, Gem_Gem.GemFx. Colours come from Shared/CrateLook per tier.

local WHICH = "Crate" -- or "KnifeCase"

type Target = {
	asset: number,
	pivots: { [string]: Vector3 }, -- Blender studs (the build script's PIVOTS)
	burst: Vector3, -- Roblox studs, model at the origin
	seam: Vector3,
}
local TARGETS: { [string]: Target } = {
	Crate = {
		asset = 134857131915909,
		pivots = {
			Lid = Vector3.new(0, 0.57, 0.63),
			LatchL = Vector3.new(-0.66, -0.575, 0.38),
			LatchR = Vector3.new(0.66, -0.575, 0.38),
			Handle = Vector3.new(0, -0.585, 0.31),
			Gem = Vector3.new(0, 0, 1.02),
		},
		burst = Vector3.new(0, 0.45, 0),
		seam = Vector3.new(0, 0.63, -0.6),
	},
	KnifeCase = {
		asset = 134286984339849,
		pivots = {
			Lid = Vector3.new(0, 0.33, 0.316),
			LatchL = Vector3.new(-0.33, -0.315, 0.19),
			LatchR = Vector3.new(0.33, -0.315, 0.19),
			Handle = Vector3.new(0, -0.32, 0.16),
			Gem = Vector3.new(0, 0, 0.535),
		},
		burst = Vector3.new(0, 0.25, 0),
		seam = Vector3.new(0, 0.316, -0.31),
	},
}
local target = TARGETS[WHICH]
assert(target, "unknown WHICH " .. WHICH)
local ASSET = target.asset

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PIVOTS = target.pivots
local function rbx(b: Vector3): Vector3
	return Vector3.new(-b.X, b.Z, b.Y)
end

local loaded = InsertService:LoadAsset(ASSET)
local src = loaded:FindFirstChildWhichIsA("Model") or loaded

local model = Instance.new("Model")
model.Name = WHICH

local root = Instance.new("Part")
root.Name = "Root"
root.Size = Vector3.new(0.2, 0.2, 0.2)
root.CFrame = CFrame.new()
root.Transparency = 1
root.Anchored = true
root.CanCollide, root.CanQuery, root.CanTouch = false, false, false
root.Parent = model
model.PrimaryPart = root

local parts: { [string]: MeshPart } = {}
for _, d in src:GetDescendants() do
	if d:IsA("MeshPart") then
		local p = d:Clone()
		p.Anchored = false
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		p.Massless = true
		p.CastShadow = true
		p.Parent = model
		parts[p.Name] = p
	end
end
loaded:Destroy()

local function need(name: string): MeshPart
	local p = parts[name]
	assert(p, "missing mesh part " .. name)
	return p
end

local base, lid, gem = need("Base_Body"), need("Lid_Body"), need("Gem_Gem")

-- a Motor6D whose joint frame sits at `pivot` (world, model at origin), axes = world axes
local function motor(name: string, part0: BasePart, part1: BasePart, pivot: Vector3)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0, m.Part1 = part0, part1
	local at = CFrame.new(pivot)
	m.C0 = part0.CFrame:ToObjectSpace(at)
	m.C1 = part1.CFrame:ToObjectSpace(at)
	m.Parent = part0
	return m
end

local function weldAll(prefix: string, to: BasePart)
	for name, p in parts do
		if p ~= to and string.sub(name, 1, #prefix) == prefix then
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = to, p
			w.Parent = p
		end
	end
end

motor("Base", root, base, Vector3.zero)
weldAll("Base_", base)
motor("Lid", base, lid, rbx(PIVOTS.Lid))
weldAll("Lid_", lid)
motor("Gem", lid, gem, rbx(PIVOTS.Gem))
motor("LatchL", base, need("LatchL_Hardware"), rbx(PIVOTS.LatchL))
motor("LatchR", base, need("LatchR_Hardware"), rbx(PIVOTS.LatchR))
motor("Handle", base, need("Handle_Hardware"), rbx(PIVOTS.Handle))

local function attach(name: string, part: BasePart, world: Vector3)
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = part.CFrame:ToObjectSpace(CFrame.new(world))
	a.Parent = part
end
attach("Burst", base, target.burst)
attach("Seam", base, target.seam)
attach("Glow", need("Base_Light"), need("Base_Light").Position)
attach("GemFx", gem, gem.Position)

local ac = Instance.new("AnimationController")
local animator = Instance.new("Animator")
animator.Parent = ac
ac.Parent = model

model:SetAttribute("Tier", if WHICH == "KnifeCase" then 4 else 1)
model:SetAttribute("Source", "tools/studio/BuildCrate.luau, asset " .. ASSET)

local folder = ReplicatedStorage:FindFirstChild("Crates")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Crates"
	folder.Parent = ReplicatedStorage
end
local old = folder:FindFirstChild(WHICH)
if old then
	old:Destroy()
end
model.Parent = folder
return `built Crates.{WHICH}: {#model:GetChildren()} children`
