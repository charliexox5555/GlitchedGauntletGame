--!strict
-- The Mod VFX library (Stage 3): stylized, Valorant-style shapes, all pooled
-- and tinted per viewer (Util/TeamColor), never created and destroyed per cast.
--
--   ModVfx.quad(spec)    a flat textured quad (ring, scan, chevron, glow):
--                        grows, fades, spins, optionally holds then fades
--   ModVfx.shell(spec)   a sphere / box shell (ForceField shimmer or Neon)
--   ModVfx.mesh(spec)    one of the Blender VFX meshes (ReplicatedStorage.
--                        Abilities.ModVFX: Dome, Shockwave, Sphere, ScanRing),
--                        scaled; nil until the models are installed
--   ModVfx.burst(at, color, count, kind)   a particle pop (sparkles, crosses)
--   ModVfx.step()        animates everything (ModFxController, every frame)
--
-- Every call returns a handle; `ModVfx.stop(handle)` ends a long one early
-- (a zone whose owner died). Textures: Config/VfxTextures MOD_*.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Tex = require(ReplicatedStorage.Shared.Config.VfxTextures)

local VfxPool = require(script.Parent.VfxPool)

local ModVfx = {}

export type QuadSpec = {
	texture: string,
	cframe: CFrame, -- centre; the quad lies in this CFrame's XZ plane, facing +Y
	from: number, -- diameter at birth (studs)
	to: number?, -- diameter at the end (eased out); default `from`
	color: Color3,
	life: number,
	alpha0: number?, -- transparency at birth (default 0)
	alpha1: number?, -- at the end (default 1)
	hold: boolean?, -- keep alpha0 and fade only over the last FADE_TAIL seconds
	spin: number?, -- radians per second around the quad's normal
	pulse: number?, -- transparency wobble (0..1) at 6 Hz, for danger rings
	lightInfluence: number?,
}

export type ShellSpec = {
	shape: Enum.PartType, -- Ball or Block
	cframe: CFrame,
	from: Vector3,
	to: Vector3?,
	color: Color3,
	life: number,
	alpha0: number?,
	alpha1: number?,
	hold: boolean?,
	material: Enum.Material?, -- default ForceField (an animated shimmer)
}

export type MeshSpec = {
	name: "Dome" | "Shockwave" | "Sphere" | "ScanRing",
	cframe: CFrame, -- the mesh's origin: Dome / Shockwave / ScanRing sit on it
	from: Vector3, -- size at birth (the meshes are 2 across at radius 1)
	to: Vector3?,
	color: Color3,
	life: number,
	alpha0: number?,
	alpha1: number?,
	hold: boolean?,
	spin: number?,
}

type Live = {
	part: BasePart,
	pool: VfxPool.Pool<BasePart>,
	decal: Decal?, -- quads: the texture on the top face
	born: number,
	life: number,
	cframe: CFrame,
	from: Vector3,
	to: Vector3,
	alpha0: number,
	alpha1: number,
	hold: boolean,
	spin: number,
	pulse: number,
	quad: boolean,
	stopped: boolean,
}

export type Handle = Live

local FADE_TAIL = 0.3
local QUAD_THICKNESS = 0.05

local folder: Folder? = nil
local quadPool: VfxPool.Pool<BasePart>? = nil
local shellPool: VfxPool.Pool<BasePart>? = nil
local meshPools: { [string]: VfxPool.Pool<BasePart> } = {}
local live: { Live } = {}

local burstPart: BasePart? = nil
local emitters: { [string]: ParticleEmitter } = {}

local function fxFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "ModVfx"
	made.Parent = Workspace
	folder = made
	quadPool = nil
	shellPool = nil
	table.clear(meshPools)
	burstPart = nil
	table.clear(emitters)
	table.clear(live)
	return made
end

local function basePart(): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Parent = fxFolder()
	return p
end

local function quads(): VfxPool.Pool<BasePart>
	local pool = quadPool
	if pool then
		return pool
	end
	local made = VfxPool.new(function(): BasePart
		local p = basePart()
		p.Size = Vector3.new(1, QUAD_THICKNESS, 1)
		local d = Instance.new("Decal")
		d.Name = "Face"
		d.Face = Enum.NormalId.Top
		d.Parent = p
		return p
	end, fxFolder(), 12)
	quadPool = made
	return made
end

local function shells(): VfxPool.Pool<BasePart>
	local pool = shellPool
	if pool then
		return pool
	end
	local made = VfxPool.new(basePart, fxFolder(), 6)
	shellPool = made
	return made
end

local function track(entry: Live): Live
	table.insert(live, entry)
	return entry
end

-- A flat textured quad: rings, scans, chevrons, glows.
function ModVfx.quad(spec: QuadSpec): Handle
	local p = quads():acquire()
	local decal = p:FindFirstChild("Face") :: Decal
	decal.Texture = spec.texture
	decal.Color3 = spec.color
	decal.Transparency = spec.alpha0 or 0
	p.CFrame = spec.cframe
	local from = Vector3.new(spec.from, QUAD_THICKNESS, spec.from)
	local to = spec.to or spec.from
	p.Size = from
	return track({
		part = p,
		pool = quads(),
		decal = decal,
		born = os.clock(),
		life = spec.life,
		cframe = spec.cframe,
		from = from,
		to = Vector3.new(to, QUAD_THICKNESS, to),
		alpha0 = spec.alpha0 or 0,
		alpha1 = spec.alpha1 or 1,
		hold = spec.hold == true,
		spin = spec.spin or 0,
		pulse = spec.pulse or 0,
		quad = true,
		stopped = false,
	})
end

-- A shell: a ForceField sphere (domes, scan bubbles) or a Neon flash.
function ModVfx.shell(spec: ShellSpec): Handle
	local p = shells():acquire() :: Part
	p.Shape = spec.shape
	p.Material = spec.material or Enum.Material.ForceField
	p.Color = spec.color
	p.Size = spec.from
	p.CFrame = spec.cframe
	p.Transparency = spec.alpha0 or 0
	return track({
		part = p,
		pool = shells(),
		decal = nil,
		born = os.clock(),
		life = spec.life,
		cframe = spec.cframe,
		from = spec.from,
		to = spec.to or spec.from,
		alpha0 = spec.alpha0 or 0,
		alpha1 = spec.alpha1 or 1,
		hold = spec.hold == true,
		spin = 0,
		pulse = 0,
		quad = false,
		stopped = false,
	})
end

local function meshPool(name: string): VfxPool.Pool<BasePart>?
	local pool = meshPools[name]
	if pool then
		return pool
	end
	local abilities = ReplicatedStorage:FindFirstChild("Abilities")
	local vfx = abilities and abilities:FindFirstChild("ModVFX")
	local template = vfx and vfx:FindFirstChild(name .. "_Energy")
	if not template or not template:IsA("BasePart") then
		return nil
	end
	local made = VfxPool.new(function(): BasePart
		local p = template:Clone()
		p:ClearAllChildren()
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 1
		p.Parent = fxFolder()
		return p
	end, fxFolder(), 2)
	meshPools[name] = made
	return made
end

-- One of the Blender VFX meshes, scaled and tinted (nil when the models
-- aren't installed: the caller falls back to a shell).
function ModVfx.mesh(spec: MeshSpec): Handle?
	local pool = meshPool(spec.name)
	if not pool then
		return nil
	end
	local p = pool:acquire()
	p.Color = spec.color
	p.Size = spec.from
	p.CFrame = spec.cframe
	p.Transparency = spec.alpha0 or 0
	return track({
		part = p,
		pool = pool,
		decal = nil,
		born = os.clock(),
		life = spec.life,
		cframe = spec.cframe,
		from = spec.from,
		to = spec.to or spec.from,
		alpha0 = spec.alpha0 or 0,
		alpha1 = spec.alpha1 or 1,
		hold = spec.hold == true,
		spin = spec.spin or 0,
		pulse = 0,
		quad = false,
		stopped = false,
	})
end

-- Ends a long effect early (it fades out over FADE_TAIL).
function ModVfx.stop(handle: Handle)
	if handle.stopped then
		return
	end
	handle.stopped = true
	local age = os.clock() - handle.born
	handle.life = math.min(handle.life, age + FADE_TAIL)
	handle.hold = true
end

-- Particles --------------------------------------------------------------------

export type BurstKind = "Sparkle" | "Cross" | "Glow"

local BURST_TEXTURES: { [BurstKind]: string } = {
	Sparkle = Tex.MOD_SPARKLE,
	Cross = Tex.MOD_CROSS,
	Glow = Tex.MOD_GLOW,
}

local function emitter(kind: BurstKind): ParticleEmitter
	local e = emitters[kind]
	if e and e.Parent then
		return e
	end
	local part = burstPart
	if not part or not part.Parent then
		part = basePart()
		part.Size = Vector3.one * 0.2
		burstPart = part
	end
	local a = Instance.new("Attachment")
	a.Name = kind
	a.Parent = part
	local made = Instance.new("ParticleEmitter")
	made.Texture = BURST_TEXTURES[kind]
	made.Enabled = false
	made.LightInfluence = 0
	made.LightEmission = 1
	made.Rate = 0
	made.SpreadAngle = Vector2.new(180, 180)
	made.Drag = 4
	made.Rotation = NumberRange.new(0, 360)
	made.RotSpeed = NumberRange.new(-90, 90)
	if kind == "Cross" then
		made.Acceleration = Vector3.new(0, 6, 0)
		made.Speed = NumberRange.new(1, 3)
		made.Lifetime = NumberRange.new(0.6, 1.1)
		made.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 0.1),
		})
	else
		made.Speed = NumberRange.new(10, 22)
		made.Lifetime = NumberRange.new(0.25, 0.5)
		made.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, if kind == "Glow" then 3 else 0.9),
			NumberSequenceKeypoint.new(1, 0),
		})
	end
	made.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	made.Parent = a
	emitters[kind] = made
	return made
end

-- A pop of `count` particles at `at`.
function ModVfx.burst(at: Vector3, color: Color3, count: number, kind: BurstKind?)
	local e = emitter(kind or "Sparkle")
	local a = e.Parent :: Attachment
	a.WorldPosition = at
	e.Color = ColorSequence.new(color)
	e:Emit(count)
end

-- Per frame ----------------------------------------------------------------------

function ModVfx.step()
	local now = os.clock()
	for i = #live, 1, -1 do
		local l = live[i]
		local k = (now - l.born) / l.life
		if k >= 1 then
			table.remove(live, i)
			l.pool:release(l.part)
			continue
		end
		local e = 1 - (1 - k) * (1 - k)
		l.part.Size = l.from:Lerp(l.to, e)
		l.part.CFrame = if l.spin ~= 0
			then l.cframe * CFrame.Angles(0, l.spin * (now - l.born), 0)
			else l.cframe
		local fade = k
		if l.hold then
			local fadeFrom = math.max(1 - FADE_TAIL / l.life, 0)
			fade = if k < fadeFrom then 0 else (k - fadeFrom) / (1 - fadeFrom)
		end
		local alpha = l.alpha0 + (l.alpha1 - l.alpha0) * fade
		if l.pulse > 0 then
			alpha =
				math.clamp(alpha + l.pulse * (0.5 + 0.5 * math.sin(now * 6 * math.pi * 2)), 0, 1)
		end
		if l.decal then
			l.decal.Transparency = alpha
		else
			l.part.Transparency = alpha
		end
	end
end

-- Lying flat on the ground at `at` (quads face +Y already).
function ModVfx.flat(at: Vector3): CFrame
	return CFrame.new(at)
end

ModVfx.FADE_TAIL = FADE_TAIL

return ModVfx
