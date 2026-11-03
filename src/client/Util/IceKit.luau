--!strict
-- The stylized ice kit (Art Direction → "Ability VFX: stylized, mesh-first"):
-- the faceted crystal meshes in ReplicatedStorage.Abilities.IceVFX
-- (tools/blender/build_mod_icevfx.py), pooled and placed in code for the
-- Frost burst (Util/FrostFx), the Freeze Frame ice blocks (UpgradeFx/Frost)
-- and the Frost Wall (Util/FrostWallFx). Until the model is installed
-- `ready()` is false and those fall back to their older look.
--
-- Kit space = the model's axes (Roblox: +Y up, X and Z as built): a mesh is
-- placed by its kit origin (`at`) and a per-axis `scale` of its kit units.
--   Shard1 / Shard2 / Shard3  crystals, 1 tall, origin at the base
--   Cluster                   five crystals fanning out of one base, ~1 tall
--   SlabA / SlabB             wall segments, origin on the floor at the centre;
--                             core SLAB_CORE (X thick, Y tall, Z along the wall)
--   Shell                     a frozen body's ice block, origin at the core's
--                             centre; core SHELL_CORE (X wide, Y tall, Z deep)
--   Fragment1..3              chips, ~1 across, origin at the centre
--   Ring_Energy               snap-freeze ring, r 1 (teeth tips), on the floor
--   Floor / Cracks_Energy     frost patch r 1 and its cracks, on the floor
--   Pixels_Energy             pixel cubes, ~1 x 1 in X/Y, thin in Z (glitch)
--   Scanlines_Energy          thin slivers, ~1 x 1 in X/Y, thin in Z (glitch)
--
--   IceKit.acquire(name) / release(part) / place(part, at, scale)   held parts
--   IceKit.spawn(spec)   a timed piece: grows (optionally snapping past full
--                        size), holds, fades and sinks, or flies as debris
--   IceKit.step()        animates the timed pieces (Util/FrostFx.step)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local VfxPool = require(script.Parent.VfxPool)

local IceKit = {}

export type Name =
	"Shard1"
	| "Shard2"
	| "Shard3"
	| "Cluster"
	| "SlabA"
	| "SlabB"
	| "Shell"
	| "Fragment1"
	| "Fragment2"
	| "Fragment3"
	| "Ring_Energy"
	| "Floor"
	| "Cracks_Energy"
	| "Pixels_Energy"
	| "Scanlines_Energy"

IceKit.SHARDS = { "Shard1", "Shard2", "Shard3" } :: { Name }
IceKit.FRAGMENTS = { "Fragment1", "Fragment2", "Fragment3" } :: { Name }
-- The meshes' cores in kit units (build_mod_icevfx.py: spikes and foot
-- crystals stick out past these).
IceKit.SLAB_CORE = Vector3.new(1.2, 10, 4)
IceKit.SHELL_CORE = Vector3.new(4, 5.6, 2.4)

local RECHECK = 2 -- seconds between looks for a model that isn't installed yet
local GRAVITY = 70 -- debris falls a little faster than the world: snappier

type Template = { part: BasePart, rel: CFrame }

local templates: { [string]: Template } = {}
local pools: { [string]: VfxPool.Pool<BasePart> } = {}
local nameOf: { [BasePart]: string } = {}
local folder: Folder? = nil
local installed = false
local nextCheck = 0

local function fxFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "IceVfx"
	made.Parent = Workspace
	folder = made
	table.clear(pools)
	table.clear(nameOf)
	return made
end

-- Whether the kit is installed (looked up again every few seconds until it is).
function IceKit.ready(): boolean
	if installed then
		local any = next(templates)
		if any and templates[any].part.Parent then
			return true
		end
		installed = false
		table.clear(templates)
		table.clear(pools)
	end
	local now = os.clock()
	if now < nextCheck then
		return false
	end
	nextCheck = now + RECHECK
	local abilities = ReplicatedStorage:FindFirstChild("Abilities")
	local model = abilities and abilities:FindFirstChild("IceVFX")
	local root = model and model:FindFirstChild("Root")
	if not model or not root or not root:IsA("BasePart") then
		return false
	end
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child ~= root then
			templates[child.Name] = { part = child, rel = root.CFrame:ToObjectSpace(child.CFrame) }
		end
	end
	installed = next(templates) ~= nil
	return installed
end

local function poolOf(name: string): VfxPool.Pool<BasePart>?
	local pool = pools[name]
	if pool then
		return pool
	end
	local t = templates[name]
	if not t then
		return nil
	end
	local parent = fxFolder()
	local made = VfxPool.new(function(): BasePart
		local p = t.part:Clone()
		p:ClearAllChildren()
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Massless = true
		p.Transparency = 1
		p.Parent = parent
		nameOf[p] = name
		return p
	end, parent, 0)
	pools[name] = made
	return made
end

-- A pooled copy of `name` (parked and invisible until placed), nil when the
-- kit isn't installed. Set its Color / Material / Transparency yourself.
function IceKit.acquire(name: Name): BasePart?
	if not IceKit.ready() then
		return nil
	end
	local pool = poolOf(name)
	return if pool then pool:acquire() else nil
end

function IceKit.release(part: BasePart)
	local name = nameOf[part]
	local pool = name and pools[name]
	if pool and part.Parent then
		pool:release(part)
	elseif not pool then
		part:Destroy()
	end
end

-- Puts `part` with its kit origin at `at`, scaled per kit axis by `scale`.
function IceKit.place(part: BasePart, at: CFrame, scale: Vector3)
	local name = nameOf[part]
	local t = name and templates[name]
	if not t then
		return
	end
	local rel = t.rel
	local s = rel:VectorToObjectSpace(scale) -- the scale along the part's own axes
	part.Size = t.part.Size * Vector3.new(math.abs(s.X), math.abs(s.Y), math.abs(s.Z))
	part.CFrame = at * CFrame.new(rel.Position * scale) * rel.Rotation
end

-- Timed pieces --------------------------------------------------------------------

export type Spec = {
	name: Name,
	at: CFrame, -- the kit origin at full size
	scale: Vector3,
	color: Color3,
	material: Enum.Material?, -- default SmoothPlastic
	alpha: number?, -- transparency while shown (default 0)
	delay: number?, -- hidden this long first
	life: number, -- seconds shown, fade included
	from: number?, -- starts at this share of `scale` (default 1)
	grow: number?, -- seconds to full size (default 0.1 when `from` is set)
	snap: boolean?, -- grows past full size and settles back (crystals snapping out)
	fade: number?, -- seconds of fade at the end (default 0.3)
	sink: number?, -- studs it sinks along its up axis during the fade
	flicker: number?, -- glitch: transparency jumps up by this on a stepped clock
	velocity: Vector3?, -- debris: flies, falls and tumbles
	spin: Vector3?, -- radians/s about each axis (debris)
}

export type Handle = {
	part: BasePart,
	spec: Spec,
	born: number,
	life: number,
	stopped: boolean,
}

local live: { Handle } = {}

-- Starts a timed piece; nil when the kit isn't installed.
function IceKit.spawn(spec: Spec): Handle?
	local part = IceKit.acquire(spec.name)
	if not part then
		return nil
	end
	part.Color = spec.color
	part.Material = spec.material or Enum.Material.SmoothPlastic
	part.Reflectance = 0
	part.Transparency = 1
	local h: Handle = {
		part = part,
		spec = spec,
		born = os.clock() + (spec.delay or 0),
		life = spec.life,
		stopped = false,
	}
	table.insert(live, h)
	return h
end

-- Ends a timed piece early: it fades out from now.
function IceKit.stop(h: Handle)
	if h.stopped then
		return
	end
	h.stopped = true
	local age = math.max(os.clock() - h.born, 0)
	h.life = math.min(h.life, age + (h.spec.fade or 0.3))
end

local function backOut(x: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

function IceKit.step()
	local now = os.clock()
	for i = #live, 1, -1 do
		local h = live[i]
		local s = h.spec
		local t = now - h.born
		if t >= h.life or not h.part.Parent then
			table.remove(live, i)
			IceKit.release(h.part)
			continue
		end
		if t < 0 then
			continue -- still waiting out its delay
		end
		local scale = s.scale
		local from = s.from
		if from then
			local grow = s.grow or 0.1
			local x = math.clamp(t / grow, 0, 1)
			local e = if s.snap then backOut(x) else 1 - (1 - x) * (1 - x)
			scale = scale * (from + (1 - from) * e)
		end
		local fade = s.fade or 0.3
		local k = math.clamp((t - (h.life - fade)) / fade, 0, 1) -- 0 shown .. 1 gone
		local at = s.at
		local v = s.velocity
		if v then
			at = CFrame.new(v * t + Vector3.new(0, -0.5 * GRAVITY * t * t, 0)) * at
		end
		local spin = s.spin
		if spin then
			at = at * CFrame.Angles(spin.X * t, spin.Y * t, spin.Z * t)
		end
		local sink = s.sink
		if sink and k > 0 then
			at = at * CFrame.new(0, -sink * k, 0)
		end
		IceKit.place(h.part, at, scale)
		local alpha = s.alpha or 0
		local flicker = s.flicker
		if flicker and math.floor(now * 20) % 3 == 0 then
			alpha += flicker
		end
		h.part.Transparency = math.min(alpha + (1 - alpha) * k, 1)
	end
end

-- A random turn about Y (so repeated meshes don't line up).
function IceKit.yaw(rng: Random): CFrame
	return CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
end

-- Picks one of `names`.
function IceKit.pick(rng: Random, names: { Name }): Name
	return names[rng:NextInteger(1, #names)]
end

return IceKit
