--!strict
-- The stylized fire kit (vault/02 Art/Art Direction.md → "Ability VFX:
-- stylized, mesh-first"): the Blender flame meshes of
-- ReplicatedStorage.Abilities.FireVFX (tools/blender/build_mod_firevfx.py,
-- art-source/abilities/README.md), pooled and placed for Util/WallFx (the
-- Firewall) and Util/MollyFx (the Molly's fire patch, Fork Fire's fires).
--
-- Every piece is one Neon MeshPart coloured here in code (three tones: a
-- yellow-white core low, an orange body, red tips). Each mesh's anchor is its
-- Blender origin (a flame's base, the wall's or patch's floor centre), and
-- place() scales it along the model's axes: X across (the wall's thickness),
-- Y up, Z along (the wall's length). Flames flicker by scaling and leaning
-- and swap between the three tongue variants now and then.
--
-- Nothing is made per frame: parts come from per-mesh pools (they only grow
-- to the most ever shown at once) and CFrames go out in one BulkMoveTo per
-- frame (flush). FireKit.available() is false until the hub has built the
-- model in Studio: callers then keep their particle look.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FireKit = {}

FireKit.CORE = Color3.fromRGB(255, 212, 90)
FireKit.BODY = Color3.fromRGB(255, 122, 30)
FireKit.SHEET = Color3.fromRGB(232, 80, 26)
FireKit.TIP = Color3.fromRGB(210, 46, 18)
FireKit.POOL = Color3.fromRGB(255, 90, 26)

FireKit.TONGUES = { "Tongue1", "Tongue2", "Tongue3" }

local PARK = CFrame.new(0, -10000, 0)
local SWAP_MIN, SWAP_MAX = 0.18, 0.45 -- seconds a flame keeps one variant

type Template = { part: BasePart, offset: Vector3, rot: CFrame, size: Vector3 }

local templates: { [string]: Template } = {}
local pools: { [string]: { BasePart } } = {}
local source: Model? = nil
local folder: Folder? = nil
local rng = Random.new()

local moveParts: { BasePart } = {}
local moveFrames: { CFrame } = {}

local function fxFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "FireFx"
	made.Parent = Workspace
	folder = made
	table.clear(pools)
	return made
end

-- The installed kit, re-read if it was replaced (AbilityBuilder.publish).
local function kit(): Model?
	local abilities = ReplicatedStorage:FindFirstChild("Abilities")
	local m = abilities and abilities:FindFirstChild("FireVFX")
	if not m or not m:IsA("Model") then
		return nil
	end
	if m ~= source then
		local root = m:FindFirstChild("Root")
		if not root or not root:IsA("BasePart") then
			return nil
		end
		source = m
		table.clear(templates)
		table.clear(pools)
		for _, child in m:GetChildren() do
			if child:IsA("BasePart") and child ~= root then
				local rel = root.CFrame:ToObjectSpace(child.CFrame)
				local name = string.gsub(child.Name, "_Energy$", "")
				templates[name] = {
					part = child,
					offset = rel.Position,
					rot = rel.Rotation,
					size = child.Size,
				}
			end
		end
	end
	return m
end

-- Whether the kit is installed with all of `names` (default: every mesh).
function FireKit.available(names: { string }?): boolean
	if not kit() then
		return false
	end
	for _, name in names or { "Sheet", "Core", "Pool", "Ring", "CrownA", "CrownB", "Spark" } do
		if not templates[name] then
			return false
		end
	end
	for _, name in FireKit.TONGUES do
		if not templates[name] then
			return false
		end
	end
	return true
end

-- A `name` piece out of its pool (nil when the kit isn't installed).
function FireKit.take(name: string): BasePart?
	if not kit() then
		return nil
	end
	local t = templates[name]
	if not t then
		return nil
	end
	local parent = fxFolder()
	local pool = pools[name]
	if not pool then
		pool = {}
		pools[name] = pool
	end
	local part = table.remove(pool)
	while part and part.Parent ~= parent do
		part = table.remove(pool)
	end
	if not part then
		local made = t.part:Clone()
		made:ClearAllChildren() -- the builder's Weld
		made.Anchored = true
		made.CanCollide = false
		made.CanQuery = false
		made.CanTouch = false
		made.CastShadow = false
		made.Massless = true
		made.Material = Enum.Material.Neon
		made.CFrame = PARK
		made.Parent = parent
		part = made
	end
	local p = part :: BasePart
	p.Transparency = 0
	return p
end

-- Back to its pool (parked far away, hidden).
function FireKit.give(name: string, part: BasePart)
	part.Transparency = 1
	part.CFrame = PARK
	local pool = pools[name]
	if pool and part.Parent then
		table.insert(pool, part)
	end
end

-- Sizes `part` (a `name` piece) by `scale` (model axes: X across, Y up,
-- Z along) and queues it at `anchor` (its Blender origin) for flush().
function FireKit.place(part: BasePart, name: string, anchor: CFrame, scale: Vector3)
	local t = templates[name]
	if not t then
		return
	end
	local s = t.rot:VectorToObjectSpace(scale)
	part.Size = t.size * Vector3.new(math.abs(s.X), math.abs(s.Y), math.abs(s.Z))
	table.insert(moveParts, part)
	table.insert(moveFrames, anchor * CFrame.new(t.offset * scale) * t.rot)
end

-- Moves everything place() queued this frame in one go.
function FireKit.flush()
	if #moveParts == 0 then
		return
	end
	Workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
	table.clear(moveParts)
	table.clear(moveFrames)
end

-- A flame's flicker at `now`: its height factor (about 0.75 to 1.3) and lean
-- (radians). Taller means thinner: scale its width by 1 / sqrt(height).
function FireKit.flicker(seed: number, now: number, speed: number): (number, number)
	local h = 1
		+ 0.42 * math.noise(now * 5.3 * speed, seed)
		+ 0.2 * math.noise(now * 12.7 * speed, seed + 7.1)
	local lean = 0.3 * math.noise(now * 2.9 * speed, seed + 3.3)
	return h, lean
end

-- A flame tongue that swaps between the variants now and then.
export type Flame = {
	part: BasePart,
	name: string,
	color: Color3,
	seed: number,
	nextSwap: number,
	turn: number, -- 0 or pi: the variant drawn mirrored
}

function FireKit.flame(color: Color3, now: number): Flame?
	local name = FireKit.TONGUES[rng:NextInteger(1, #FireKit.TONGUES)]
	local part = FireKit.take(name)
	if not part then
		return nil
	end
	part.Color = color
	return {
		part = part,
		name = name,
		color = color,
		seed = rng:NextNumber(0, 1000),
		nextSwap = now + rng:NextNumber(SWAP_MIN, SWAP_MAX),
		turn = if rng:NextNumber() < 0.5 then 0 else math.pi,
	}
end

function FireKit.paint(f: Flame, color: Color3)
	f.color = color
	f.part.Color = color
end

-- Swaps `f` to another variant when it's due (call before placing it).
function FireKit.swap(f: Flame, now: number)
	if now < f.nextSwap then
		return
	end
	f.nextSwap = now + rng:NextNumber(SWAP_MIN, SWAP_MAX)
	local name = FireKit.TONGUES[rng:NextInteger(1, #FireKit.TONGUES - 1)]
	if name == f.name then
		name = FireKit.TONGUES[#FireKit.TONGUES]
	end
	local part = FireKit.take(name)
	if not part then
		return
	end
	FireKit.give(f.name, f.part)
	part.Color = f.color
	f.part = part
	f.name = name
	f.turn = if rng:NextNumber() < 0.5 then 0 else math.pi
end

function FireKit.drop(f: Flame)
	FireKit.give(f.name, f.part)
end

return FireKit
