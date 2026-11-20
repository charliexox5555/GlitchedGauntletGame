--!strict
-- The rework effects kit (vault/02 Art/Ability VFX Direction.md, locked
-- 2026-11-16): the 19 Blender meshes of ReplicatedStorage.Abilities.ReworkVFX
-- (art-source/abilities/Rework/v03/ReworkVFX/vfx_kit.py, PARTS.md), pooled and
-- placed for the element modules (FireFx, and the ice, impact, scan, healing,
-- teleport and shield ones after it). Same pattern as GlitchVfx / FireKit.
--
--   ReworkVfx.ready()             true once the whole kit is installed (callers
--                                 keep their old look until then)
--   ReworkVfx.take(name)          a pooled part (nil without the kit)
--   ReworkVfx.give(name, part)    back to its pool
--   ReworkVfx.place(part, name, anchor, scale)
--                                 sizes it and queues it for flush(): `anchor`
--                                 is where the mesh's anchor goes, `scale`
--                                 multiplies its kit extent per kit axis
--   ReworkVfx.flush()             moves everything queued this frame at once
--   ReworkVfx.extent(name)        the kit extent (studs, kit axes)
--   ReworkVfx.now() / timeScale() the effects clock: os.clock() slowed by the
--                                 Studio review attribute Workspace.VfxTimeScale
--                                 (0 freezes it), so captures can be frozen
--   ReworkVfx.curve(name, x)      the spec's size and transparency curves
--
-- Kit axes (Root at the origin; every mesh's anchor at the origin):
--   FX_Stroke      head at the anchor, the body runs along +Z, 1 long
--   FX_Ring, FX_FloorStar, Tele_Ring, Heal_Crown   flat on XZ, centre anchor
--   Fire_Tongue*, Ice_Plate*, Heal_Leaf   stand up +Y from the base; wide on
--                  Z, thin on X (the flat side faces X)
--   Ice_Cap, Impact_Chunk*   sit on the floor, up +Y
--   Stim_Chevron, Tele_Fold, Shield_Plate   flat on XY, facing Z
--   Scan_Shell     a 1-stud shell round the anchor

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReworkVfx = {}

export type Name =
	"FX_Stroke"
	| "FX_Ring"
	| "FX_FloorStar"
	| "Fire_TongueA"
	| "Fire_TongueB"
	| "Fire_TongueC"
	| "Ice_PlateA"
	| "Ice_PlateB"
	| "Ice_PlateC"
	| "Ice_Cap"
	| "Heal_Leaf"
	| "Heal_Crown"
	| "Stim_Chevron"
	| "Tele_Fold"
	| "Tele_Ring"
	| "Scan_Shell"
	| "Impact_ChunkA"
	| "Impact_ChunkB"
	| "Shield_Plate"

local NAMES: { Name } = {
	"FX_Stroke",
	"FX_Ring",
	"FX_FloorStar",
	"Fire_TongueA",
	"Fire_TongueB",
	"Fire_TongueC",
	"Ice_PlateA",
	"Ice_PlateB",
	"Ice_PlateC",
	"Ice_Cap",
	"Heal_Leaf",
	"Heal_Crown",
	"Stim_Chevron",
	"Tele_Fold",
	"Tele_Ring",
	"Scan_Shell",
	"Impact_ChunkA",
	"Impact_ChunkB",
	"Shield_Plate",
}

local PARK = CFrame.new(0, -10000, 0)

type Template = { part: BasePart, offset: Vector3, rot: CFrame, size: Vector3, extent: Vector3 }

local templates: { [string]: Template } = {}
local pools: { [string]: { BasePart } } = {}
local source: Model? = nil
local complete = false
local folder: Folder? = nil

local moveParts: { BasePart } = {}
local moveFrames: { CFrame } = {}

local function fxFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "ReworkFx"
	made.Parent = Workspace
	folder = made
	table.clear(pools)
	return made
end

-- The installed kit, re-read when it was replaced.
local function kit(): Model?
	local abilities = ReplicatedStorage:FindFirstChild("Abilities")
	local m = abilities and abilities:FindFirstChild("ReworkVFX")
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
				local e = rel:VectorToWorldSpace(child.Size)
				templates[child.Name] = {
					part = child,
					offset = rel.Position,
					rot = rel.Rotation,
					size = child.Size,
					extent = Vector3.new(math.abs(e.X), math.abs(e.Y), math.abs(e.Z)),
				}
			end
		end
		complete = true
		for _, name in NAMES do
			if not templates[name] then
				complete = false
				break
			end
		end
	end
	return m
end

-- Only a complete kit counts, so an older build can't half-draw an effect.
function ReworkVfx.ready(): boolean
	return kit() ~= nil and complete
end

function ReworkVfx.take(name: Name): BasePart?
	if not ReworkVfx.ready() then
		return nil
	end
	local t = templates[name]
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
		made.CFrame = PARK
		made.Parent = parent
		part = made
	end
	local p = part :: BasePart
	p.Material = t.part.Material
	p.Transparency = 0
	return p
end

function ReworkVfx.give(name: Name, part: BasePart)
	part.Transparency = 1
	part.CFrame = PARK
	local pool = pools[name]
	if pool and part.Parent == folder then
		table.insert(pool, part)
	end
end

-- The kit extent of `name` (studs at scale 1, kit axes), or nil.
function ReworkVfx.extent(name: Name): Vector3?
	if not ReworkVfx.ready() then
		return nil
	end
	return templates[name].extent
end

local MIN_SIZE = 0.001

function ReworkVfx.place(part: BasePart, name: Name, anchor: CFrame, scale: Vector3)
	local t = templates[name]
	if not t then
		return
	end
	local s = t.rot:VectorToObjectSpace(scale)
	local size = t.size * Vector3.new(math.abs(s.X), math.abs(s.Y), math.abs(s.Z))
	part.Size = Vector3.new(
		math.max(size.X, MIN_SIZE),
		math.max(size.Y, MIN_SIZE),
		math.max(size.Z, MIN_SIZE)
	)
	table.insert(moveParts, part)
	table.insert(moveFrames, anchor * CFrame.new(t.offset * scale) * t.rot)
end

function ReworkVfx.flush()
	if #moveParts == 0 then
		return
	end
	Workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
	table.clear(moveParts)
	table.clear(moveFrames)
end

-- The effects clock --------------------------------------------------------------

local scale = 1
local clock = os.clock()
local lastReal = os.clock()

local function readScale()
	local v = StateValues.get(Workspace, "VfxTimeScale")
	scale = if typeof(v) == "number" then math.clamp(v, 0, 1) else 1
end

function ReworkVfx.now(): number
	local real = os.clock()
	clock += (real - lastReal) * scale
	lastReal = real
	return clock
end

function ReworkVfx.timeScale(): number
	return scale
end

if RunService:IsStudio() then
	readScale()
	StateValues.changed(Workspace, "VfxTimeScale"):Connect(function()
		ReworkVfx.now() -- bank the time run at the old speed
		readScale()
	end)
end

-- Curves (Ability VFX Direction → Layer kits) --------------------------------------

export type Curve = "Pop" | "Spike" | "Bell" | "Grow" | "Shrink" | "Cut" | "Fade" | "Haze" | "Ping"

local KEYS: { [Curve]: { number } } = {
	Pop = { 0, 0, 0.1, 0.5, 0.3, 0.8, 1, 1 },
	Spike = { 0, 0, 0.3, 1, 1, 0 },
	Bell = { 0, 0, 0.5, 1, 1, 0 },
	Grow = { 0, 0.4, 0.3, 0.5, 0.6, 0.7, 1, 1 },
	Shrink = { 0, 1, 1, 0 },
	Cut = { 0, 0, 0.77, 0, 0.81, 0.38, 0.89, 0.74, 0.96, 0.95, 1, 1 },
	Fade = { 0, 0, 1, 1 },
	Haze = { 0, 1, 0.35, 0.76, 1, 1 },
	Ping = { 0, 0, 0.1, 0.46, 1, 1 },
}

-- The value of curve `name` at `x` (0..1).
function ReworkVfx.curve(name: Curve, x: number): number
	local k = KEYS[name]
	x = math.clamp(x, 0, 1)
	for i = 3, #k, 2 do
		if x <= k[i] then
			local x0, y0, x1, y1 = k[i - 2], k[i - 1], k[i], k[i + 1]
			local span = x1 - x0
			return if span <= 0 then y1 else y0 + (y1 - y0) * (x - x0) / span
		end
	end
	return k[#k]
end

-- The same curve as a NumberSequence (times `size`), for a ParticleEmitter.
function ReworkVfx.sequence(name: Curve, size: number?): NumberSequence
	local k = KEYS[name]
	local m = size or 1
	local keys = {}
	for i = 1, #k, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(k[i], k[i + 1] * m))
	end
	return NumberSequence.new(keys)
end

-- Mesh Snap: 0 to 1.12 over 70% of `onset`, back to 1 by its end.
function ReworkVfx.snap(t: number, onset: number): number
	if t >= onset then
		return 1
	end
	local x = math.max(t, 0) / onset
	if x < 0.7 then
		local e = x / 0.7
		return 1.12 * (1 - (1 - e) * (1 - e))
	end
	return 1.12 - 0.12 * (x - 0.7) / 0.3
end

return ReworkVfx
