--!strict
-- The GlitchVFX kit (Art Direction → "Ability VFX: stylized, mesh-first"):
-- the Blender meshes the glitched upgrade levels are drawn with, from
-- ReplicatedStorage.Abilities.GlitchVFX (tools/blender/build_mod_glitchvfx.py,
-- built in Studio by AbilityBuilder; Studio-owned). Pooled like ModVfx and
-- animated here: grow, fade, spin, fly (rubble, shatter tiles) and stutter
-- (dropped frames). Nothing is created per frame; a pool only grows when an
-- effect needs more pieces than it has parked.
--
--   GlitchVfx.ready()        true once the kit is installed (callers keep
--                            their old look until then)
--   GlitchVfx.piece(spec)    one mesh, sized from its authored size; nil when
--                            the kit isn't installed
--   GlitchVfx.stop(handle)   ends a long one early (fades over FADE_TAIL)
--   GlitchVfx.take(name) / give(name, part)   a pooled part the caller drives
--                            itself (follows a body without a frame of lag)
--
-- Pieces (authored sizes in studs; every CFrame is the mesh's box centre):
--   Crack_Energy / CrackGap  radial floor cracks 2.02 across (glow lines /
--                            the dark split under them)
--   Rubble1..3               rock chunks ~0.5 (give them the floor's colour)
--   HexShell_Energy / HexEdge_Energy / ShellCrack_Energy
--                            a hex bubble's panels / frame / a crack on its
--                            -Z side, all 2.04 across (centre = the sphere's)
--   HexTile_Energy           one loose hex panel 1 across (shatter pieces)
--   ScanWave_Energy          a torn scan band, r 1 (2.5 box), 1.15 tall
--   Pixels_Energy / PixelSpray_Energy   a voxel clump ~1 / a spray ~2
--   Slivers_Energy           scanline slivers in a 2.9 x 5.3 x 0.9 body box
--   Streak_Energy            staggered bars 4 long along Z
--   HexFloor_Energy          a disc of hex tiles 1.77 across, flat
--   Plus_Energy              a pixel plus 1 x 1, 0.3 deep (faces Z)
--   PixelRing_Energy         a stepped ring 2.05 across, 0.15 tall

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local VfxPool = require(script.Parent.VfxPool)

local GlitchVfx = {}

export type Name =
	"Crack_Energy"
	| "CrackGap"
	| "Rubble1"
	| "Rubble2"
	| "Rubble3"
	| "HexShell_Energy"
	| "HexEdge_Energy"
	| "HexTile_Energy"
	| "ShellCrack_Energy"
	| "ScanWave_Energy"
	| "Pixels_Energy"
	| "PixelSpray_Energy"
	| "Slivers_Energy"
	| "Streak_Energy"
	| "HexFloor_Energy"
	| "Plus_Energy"
	| "PixelRing_Energy"

export type Spec = {
	name: Name,
	cframe: CFrame,
	scale: Vector3, -- times the authored size, at birth
	scale1: Vector3?, -- at the end (eased out); default `scale`
	color: Color3,
	life: number,
	alpha0: number?, -- transparency at birth (default 0)
	alpha1: number?, -- at the end (default 1)
	hold: boolean?, -- keep alpha0 and fade only over the last FADE_TAIL seconds
	velocity: Vector3?, -- studs/s (flying pieces)
	gravity: number?, -- studs/s² pulling the velocity down
	floorY: number?, -- a flying piece stops here (it lands and lies still)
	spin: Vector3?, -- radians/s about the piece's own X, Y, Z (stops on landing)
	stutter: number?, -- 0..1: the chance each frame it drops out (a bad frame)
	material: Enum.Material?, -- default the template's
}

type Live = {
	part: BasePart,
	pool: VfxPool.Pool<BasePart>,
	born: number,
	life: number,
	cframe: CFrame, -- moved by velocity / spin; callers may set it to follow something
	from: Vector3, -- sizes (studs), settable while it lives
	to: Vector3,
	alpha0: number,
	alpha1: number,
	hold: boolean,
	velocity: Vector3?,
	gravity: number,
	floorY: number?,
	spin: Vector3?,
	stutter: number,
	stopped: boolean,
}

export type Handle = Live

local FADE_TAIL = 0.3

type Template = { part: BasePart, size: Vector3, material: Enum.Material }

local folder: Folder? = nil
local templates: { [string]: Template } = {}
local pools: { [string]: VfxPool.Pool<BasePart> } = {}
local live: { Live } = {}
local connection: RBXScriptConnection? = nil
local lastStep = os.clock()

local NAMES: { Name } = {
	"Crack_Energy",
	"CrackGap",
	"Rubble1",
	"Rubble2",
	"Rubble3",
	"HexShell_Energy",
	"HexEdge_Energy",
	"HexTile_Energy",
	"ShellCrack_Energy",
	"ScanWave_Energy",
	"Pixels_Energy",
	"PixelSpray_Energy",
	"Slivers_Energy",
	"Streak_Energy",
	"HexFloor_Energy",
	"Plus_Energy",
	"PixelRing_Energy",
}
local checked: Instance? = nil -- the installed kit, once every piece was found in it

local function kit(): Instance?
	local abilities = ReplicatedStorage:FindFirstChild("Abilities")
	return abilities and abilities:FindFirstChild("GlitchVFX")
end

-- Only a complete kit counts: callers skip their old look when this is true,
-- so an older build missing a piece must not half-draw an effect.
function GlitchVfx.ready(): boolean
	local model = kit()
	if not model then
		return false
	end
	if model == checked then
		return true
	end
	for _, name in NAMES do
		local part = model:FindFirstChild(name)
		if not part or not part:IsA("BasePart") then
			return false
		end
	end
	checked = model
	return true
end

local function fxFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "GlitchVfx"
	made.Parent = Workspace
	folder = made
	-- The old folder (and every pooled part in it) is gone: start over.
	table.clear(pools)
	table.clear(live)
	return made
end

local function template(name: string): Template?
	local t = templates[name]
	if t and t.part.Parent then
		return t
	end
	local model = if GlitchVfx.ready() then kit() else nil
	local part = model and model:FindFirstChild(name)
	if not part or not part:IsA("BasePart") then
		return nil
	end
	local made = { part = part, size = part.Size, material = part.Material }
	templates[name] = made
	return made
end

local function poolFor(name: string, tpl: Template): VfxPool.Pool<BasePart>
	local parent = fxFolder()
	local pool = pools[name]
	if pool then
		return pool
	end
	local made = VfxPool.new(function(): BasePart
		local p = tpl.part:Clone()
		p:ClearAllChildren() -- the builder's Weld to Root
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Massless = true
		p.Transparency = 1
		p.Parent = parent
		return p
	end, parent, 0)
	pools[name] = made
	return made
end

local function step()
	local now = os.clock()
	local dt = math.min(now - lastStep, 0.1)
	lastStep = now
	for i = #live, 1, -1 do
		local l = live[i]
		local k = (now - l.born) / l.life
		if k >= 1 then
			table.remove(live, i)
			l.pool:release(l.part)
			continue
		end
		local v = l.velocity
		if v then
			local cf = l.cframe + v * dt
			v -= Vector3.new(0, l.gravity * dt, 0)
			local floorY = l.floorY
			if floorY and cf.Position.Y - l.part.Size.Y * 0.5 < floorY and v.Y < 0 then
				-- Landed: lie still where it hit.
				cf = cf + Vector3.new(0, floorY + l.part.Size.Y * 0.5 - cf.Position.Y, 0)
				l.velocity = nil
				l.spin = nil
			else
				l.velocity = v
			end
			l.cframe = cf
		end
		local spin = l.spin
		if spin then
			l.cframe *= CFrame.Angles(spin.X * dt, spin.Y * dt, spin.Z * dt)
		end
		local e = 1 - (1 - k) * (1 - k)
		l.part.Size = l.from:Lerp(l.to, e)
		l.part.CFrame = l.cframe
		local fade = k
		if l.hold then
			local fadeFrom = math.max(1 - FADE_TAIL / l.life, 0)
			fade = if k < fadeFrom then 0 else (k - fadeFrom) / (1 - fadeFrom)
		end
		local alpha = l.alpha0 + (l.alpha1 - l.alpha0) * fade
		if l.stutter > 0 and math.random() < l.stutter then
			alpha = 1
		end
		l.part.Transparency = alpha
	end
	if #live == 0 then
		local c = connection
		if c then
			c:Disconnect()
			connection = nil
		end
	end
end

-- One kit mesh (nil when the kit isn't installed: keep the old look).
function GlitchVfx.piece(spec: Spec): Handle?
	local tpl = template(spec.name)
	if not tpl then
		return nil
	end
	local pool = poolFor(spec.name, tpl)
	local p = pool:acquire()
	local from = tpl.size * spec.scale
	p.Material = spec.material or tpl.material
	p.Color = spec.color
	p.Size = from
	p.CFrame = spec.cframe
	p.Transparency = spec.alpha0 or 0
	local entry: Live = {
		part = p,
		pool = pool,
		born = os.clock(),
		life = math.max(spec.life, 0.01),
		cframe = spec.cframe,
		from = from,
		to = tpl.size * (spec.scale1 or spec.scale),
		alpha0 = spec.alpha0 or 0,
		alpha1 = spec.alpha1 or 1,
		hold = spec.hold == true,
		velocity = spec.velocity,
		gravity = spec.gravity or 0,
		floorY = spec.floorY,
		spin = spec.spin,
		stutter = spec.stutter or 0,
		stopped = false,
	}
	table.insert(live, entry)
	if not connection then
		lastStep = os.clock()
		connection = RunService.RenderStepped:Connect(step)
	end
	return entry
end

-- A kit part for the caller to drive itself every frame (a bubble that must
-- not lag the body it follows), or nil. Hand it back with give().
function GlitchVfx.take(name: Name): BasePart?
	local tpl = template(name)
	if not tpl then
		return nil
	end
	local p = poolFor(name, tpl):acquire()
	p.Material = tpl.material
	p.Size = tpl.size
	return p
end

function GlitchVfx.give(name: Name, part: BasePart)
	if part.Parent == nil then
		return -- destroyed with an old folder
	end
	local pool = pools[name]
	local f = folder
	if pool and f and f.Parent then
		part.Parent = f -- it may have been borrowed into a model (a Highlight's adornee)
		pool:release(part)
	else
		part:Destroy()
	end
end

-- The authored size of a piece (studs), or nil when the kit isn't installed.
function GlitchVfx.size(name: Name): Vector3?
	local tpl = template(name)
	return if tpl then tpl.size else nil
end

-- Ends a long piece early (it fades out over FADE_TAIL).
function GlitchVfx.stop(handle: Handle)
	if handle.stopped then
		return
	end
	handle.stopped = true
	local age = os.clock() - handle.born
	handle.life = math.min(handle.life, age + FADE_TAIL)
	handle.hold = true
end

GlitchVfx.FADE_TAIL = FADE_TAIL

return GlitchVfx
