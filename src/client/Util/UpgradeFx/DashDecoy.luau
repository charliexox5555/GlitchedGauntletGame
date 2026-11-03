--!strict
-- Dash Desync's decoy (G2/G3; vault/01 Design/Abilities/Dash.md → Upgrades).
-- Every client builds it on its own from the dasher's character attributes
-- (Mods/Dash: DashWindows / DashDecoy / DashDecoyRun, read with Dash.decoy), so nothing
-- crosses the network and nothing about it is real:
--   - a copy of the dasher's character (scripts, sounds and effects
--     stripped, joints made kinematic), anchored at the root, nothing in it
--     collides or can be hit (CanQuery off: shots and hit markers ignore it)
--   - it runs the old way at the old speed with the dasher's run clip and
--     gun pose, follows the ground, stops at walls, falls off ledges
--   - G3: it turns to the nearest enemy in sight and fires fake shots
--     (tracers, muzzle flash and the gun's far sound, no damage)
--   - at the end it glitches out in magenta static
-- The split (the dash start) gets the same static, so nobody can tell which
-- of the two walked away from it.
-- Look (stylized, 2026-11-03): with the GlitchVFX kit installed (Util/
-- GlitchVfx) the static is two stacks of scanline slivers slipping sideways
-- out of step with a spray of voxels coming off them (pooled), and the decoy's
-- last frame pops into a voxel clump.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Animations = require(ReplicatedStorage.Shared.Config.Animations)
local GunSounds = require(ReplicatedStorage.Shared.Config.GunSounds)
local Movement = require(ReplicatedStorage.Shared.Config.Movement)
local TestRange = require(ReplicatedStorage.Shared.Config.TestRange)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local Types = require(ReplicatedStorage.Shared.Types)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local AudioController = require(script.Parent.Parent.Parent.Controllers.AudioController)
local EffectsController = require(script.Parent.Parent.Parent.Controllers.EffectsController)
local GlitchVfx = require(script.Parent.Parent.GlitchVfx)
local ModVfx = require(script.Parent.Parent.ModVfx)
local TeamColor = require(script.Parent.Parent.TeamColor)

local DashDecoy = {}

local GLITCH_TIME = 0.3 -- seconds of static before the decoy is gone
local SPLIT_TIME = 0.22 -- the static where the dash started
local SLICES = 7 -- static slices across a body
local TURN_RATE = 14 -- how fast the G3 decoy turns to its target (1/s)
local STEP_SNAP = 3 -- studs: closer to the ground than this, it walks on it
local DETAIL_RANGE = 60 -- muzzle flashes only this close to the camera

export type Spawn = {
	owner: Player,
	character: Model,
	from: Vector3, -- the root's position at the press
	yaw: number, -- the root's facing at the press
	velocity: Vector3, -- flat: the way it runs
	start: number, -- time() of the press
	untilT: number, -- time() it glitches out
	fires: boolean,
	stats: { [string]: any },
}

type Static = {
	slices: { BasePart }, -- Neon slices (without the kit)
	slivers: { BasePart }, -- the kit's scanline stacks
	cframe: CFrame,
	size: Vector3,
	born: number,
	life: number,
}
local SLIVER_STACKS = 2 -- the kit's sliver stacks per static
local SLIVER_DEPTH = 0.6 -- of the body's depth

type Decoy = {
	owner: Player,
	model: Model,
	root: BasePart,
	parts: { BasePart },
	pos: Vector3,
	yaw: number,
	velocity: Vector3,
	fall: number,
	rootHeight: number,
	untilT: number,
	run: AnimationTrack?,
	aim: AnimationTrack?,
	sprint: AnimationTrack?,
	fires: boolean,
	nextShot: number,
	weapon: Types.WeaponConfig?,
	muzzle: Attachment?,
	stats: { [string]: any },
	params: RaycastParams,
	glitchAt: number?,
}

local decoys: { [Player]: Decoy } = {}
local statics: { Static } = {}
local folder: Folder? = nil

local function fxFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local existing = Workspace:FindFirstChild("DashFx")
	if existing and existing:IsA("Folder") then
		folder = existing
		return existing
	end
	local made = Instance.new("Folder")
	made.Name = "DashFx"
	made.Parent = Workspace
	folder = made
	return made
end

-- World only: no bodies, decoys or effects (and only what collides).
local function worldParams(): RaycastParams
	local exclude: { Instance } = { fxFolder() }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	for _, name in { "Dummies", "ModFx" } do
		local f = Workspace:FindFirstChild(name)
		if f then
			table.insert(exclude, f)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	return params
end

-- Magenta static ----------------------------------------------------------------

-- Thin neon slices across a body-sized box that jump sideways and flicker:
-- the glitch path's look (Config/Mods COLORS.glitch).
function DashDecoy.static(cframe: CFrame, size: Vector3, life: number): Static
	local slices: { BasePart } = {}
	local slivers: { BasePart } = {}
	for _ = 1, if GlitchVfx.ready() then SLIVER_STACKS else 0 do
		local p = GlitchVfx.take("Slivers_Energy")
		if p then
			p.Color = TeamColor.GLITCH
			p.Size = Vector3.new(size.X, size.Y, size.Z * SLIVER_DEPTH)
			table.insert(slivers, p)
		end
	end
	if #slivers > 0 then
		-- Voxels coming off it.
		GlitchVfx.piece({
			name = "PixelSpray_Energy",
			cframe = cframe * CFrame.Angles(0, math.random() * math.pi * 2, 0),
			scale = Vector3.one * (size.X / 2.2),
			scale1 = Vector3.one * (size.X / 1.4),
			color = TeamColor.GLITCH,
			life = life + 0.1,
			alpha0 = 0.1,
			stutter = 0.3,
			spin = Vector3.new(0, 4, 0),
		})
	end
	for _ = 1, if #slivers > 0 then 0 else SLICES do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = TeamColor.GLITCH
		p.Size = Vector3.new(size.X, size.Y / (SLICES * 2.5), size.Z)
		p.Parent = fxFolder()
		table.insert(slices, p)
	end
	local s: Static = {
		slices = slices,
		slivers = slivers,
		cframe = cframe,
		size = size,
		born = os.clock(),
		life = life,
	}
	table.insert(statics, s)
	return s
end

local function stepStatics()
	local now = os.clock()
	for i = #statics, 1, -1 do
		local s = statics[i]
		local k = (now - s.born) / s.life
		if k >= 1 then
			for _, p in s.slices do
				p:Destroy()
			end
			for _, p in s.slivers do
				GlitchVfx.give("Slivers_Energy", p)
			end
			table.remove(statics, i)
			continue
		end
		for _, p in s.slivers do
			-- Out of step with each other: a sideways slip, sometimes mirrored.
			local x = (math.random() - 0.5) * s.size.X * 0.35
			local flip = if math.random() < 0.5 then math.pi else 0
			p.CFrame = s.cframe
				* CFrame.new(x, (math.random() - 0.5) * 0.3, 0)
				* CFrame.Angles(0, flip, 0)
			p.Transparency = if math.random() < 0.3 then 1 else 0.1 + 0.9 * k
		end
		for _, p in s.slices do
			local y = (math.random() - 0.5) * s.size.Y
			local x = (math.random() - 0.5) * s.size.X * 0.7
			p.CFrame = s.cframe * CFrame.new(x, y, 0)
			p.Transparency = if math.random() < 0.35 then 1 else 0.15 + 0.85 * k
		end
	end
end

-- The copy -------------------------------------------------------------------------

-- Animation joints (AnimationConstraint) become Motor6Ds: with the root
-- anchored, the copy then poses kinematically and nothing hangs on physics.
local function kinematicJoints(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("AnimationConstraint") then
			local a0, a1 = d.Attachment0, d.Attachment1
			local p0 = a0 and a0.Parent
			local p1 = a1 and a1.Parent
			if a0 and a1 and p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") then
				local m = Instance.new("Motor6D")
				m.Name = d.Name
				m.Part0 = p0
				m.Part1 = p1
				m.C0 = a0.CFrame
				m.C1 = a1.CFrame
				m.Parent = p1
			end
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("Constraint") and not d:IsA("RigidConstraint") then
			d:Destroy()
		end
	end
end

local function copyOf(character: Model): Model?
	local was = character.Archivable
	character.Archivable = true
	local ok, copy = pcall(character.Clone, character)
	character.Archivable = was
	if not ok or not copy then
		return nil
	end
	local model = copy :: Model
	model.Name = "DashDecoy"
	for name in model:GetAttributes() do
		model:SetAttribute(name, nil)
	end
	for _, d in model:GetDescendants() do
		if
			d:IsA("LuaSourceContainer")
			or d:IsA("Sound")
			or d:IsA("ParticleEmitter")
			or d:IsA("Trail")
			or d:IsA("Beam")
			or d:IsA("Highlight")
			or d:IsA("ForceField")
		then
			d:Destroy()
		end
	end
	kinematicJoints(model)
	return model
end

local function load(
	animator: Animator,
	id: string,
	priority: Enum.AnimationPriority
): AnimationTrack?
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local ok, track = pcall(animator.LoadAnimation, animator, anim)
	if not ok then
		return nil
	end
	local t = track :: AnimationTrack
	t.Priority = priority
	t.Looped = true
	return t
end

-- The run clip the dasher's own Animate script uses (stock R15 otherwise).
local function runClip(character: Model): string
	local animate = character:FindFirstChild("Animate")
	local run = animate and animate:FindFirstChild("run")
	local clip = run and run:FindFirstChildOfClass("Animation")
	if clip and clip.AnimationId ~= "" then
		return clip.AnimationId
	end
	return TestRange.ANIMATIONS.Run
end

local function bodySize(d: Decoy): Vector3
	return Vector3.new(2.6, d.rootHeight + 2, 1.6)
end

-- Shots ------------------------------------------------------------------------------

local function chestOf(model: Model): BasePart?
	local p = model:FindFirstChild("UpperTorso") or model:FindFirstChild("HumanoidRootPart")
	return if p and p:IsA("BasePart") then p else nil
end

local function alive(model: Model): boolean
	local h = model:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0
end

-- The nearest live enemy of the dasher within range and in sight of `eye`.
local function nearestEnemy(d: Decoy, eye: Vector3): BasePart?
	local range: number = d.stats.decoyShotRange or 150
	local best: BasePart? = nil
	local bestDist = range
	local function consider(model: Model)
		if Teams.isAlly(d.owner, model) or not alive(model) then
			return
		end
		local chest = chestOf(model)
		if not chest then
			return
		end
		local dist = (chest.Position - eye).Magnitude
		if dist >= bestDist then
			return
		end
		if Workspace:Raycast(eye, chest.Position - eye, d.params) then
			return -- a wall between
		end
		best, bestDist = chest, dist
	end
	for _, p in Players:GetPlayers() do
		if p ~= d.owner and p.Character then
			consider(p.Character)
		end
	end
	local dummies = Workspace:FindFirstChild("Dummies")
	if dummies then
		for _, m in dummies:GetChildren() do
			if m:IsA("Model") then
				consider(m)
			end
		end
	end
	return best
end

local function spread(dir: Vector3, degrees: number): Vector3
	local r = math.rad(degrees) * math.sqrt(math.random())
	local a = math.random() * 2 * math.pi
	local cf = CFrame.lookAt(Vector3.zero, dir)
	return (cf * CFrame.Angles(r * math.cos(a), r * math.sin(a), 0)).LookVector
end

-- One fake shot from the decoy's gun at `target`: what a real one looks and
-- sounds like to a bystander, without the server ever hearing of it.
local function fakeShot(d: Decoy, target: BasePart)
	local config = d.weapon :: Types.WeaponConfig
	local muzzle = d.muzzle
	local from = if muzzle then muzzle.WorldPosition else d.pos + Vector3.new(0, 1.5, 0)
	local aim = target.Position - from
	if aim.Magnitude < 1 then
		return
	end
	local range: number = d.stats.decoyShotRange or 150
	local cone: number = d.stats.decoyShotSpread or 2.5
	for _ = 1, math.max(config.pellets, 1) do
		local dir = spread(aim.Unit, if config.pellets > 1 then config.pelletSpread else cone)
		local hit = Workspace:Raycast(from, dir * range, d.params)
		local finish = if hit then hit.Position else from + dir * range
		if not config.suppressed then
			EffectsController.tracer(from, finish, config)
		end
		if hit then
			EffectsController.impact(hit.Position, hit.Normal, hit.Instance, hit.Material)
		end
	end
	local cam = Workspace.CurrentCamera
	if muzzle then
		local near = cam ~= nil and (cam.CFrame.Position - from).Magnitude < DETAIL_RANGE
		EffectsController.muzzleFlash(muzzle, config, false, near)
	end
	AudioController.playSound(GunSounds.get(config.id).fireFar, "Enemy", from)
end

-- Life ---------------------------------------------------------------------------------

local function remove(d: Decoy)
	if decoys[d.owner] == d then
		decoys[d.owner] = nil
	end
	d.model:Destroy()
end

local function glitchOut(d: Decoy)
	if d.glitchAt then
		return
	end
	d.glitchAt = os.clock()
	DashDecoy.static(d.root.CFrame, bodySize(d), GLITCH_TIME)
	for _, track in { d.run, d.aim, d.sprint } do
		if track then
			track:AdjustSpeed(0) -- freezes mid-stride, like a lost connection
		end
	end
end

function DashDecoy.spawn(s: Spawn)
	local old = decoys[s.owner]
	if old then
		remove(old)
	end
	local model = copyOf(s.character)
	local root = model and model:FindFirstChild("HumanoidRootPart")
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if not model or not root or not root:IsA("BasePart") or not humanoid then
		if model then
			model:Destroy()
		end
		return
	end
	humanoid.EvaluateStateMachine = false
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	local parts: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d == root
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d.LocalTransparencyModifier = 0
			table.insert(parts, d)
		elseif d:IsA("Decal") then
			d.LocalTransparencyModifier = 0
		end
	end
	local weaponId = s.owner:GetAttribute("WeaponId")
	local weapon = if typeof(weaponId) == "string" then Weapons.get(weaponId) else nil
	local world = model:FindFirstChild("WorldWeapon")
	local muzzle = world and world:FindFirstChild("Muzzle", true)

	local rootHeight = humanoid.HipHeight + root.Size.Y / 2
	local late = math.clamp(time() - s.start, 0, 0.3)
	local d: Decoy = {
		owner = s.owner,
		model = model,
		root = root,
		parts = parts,
		pos = s.from + s.velocity * late,
		yaw = s.yaw,
		velocity = s.velocity,
		fall = 0,
		rootHeight = rootHeight,
		untilT = s.untilT,
		run = nil,
		aim = nil,
		sprint = nil,
		fires = s.fires and weapon ~= nil and not (weapon :: Types.WeaponConfig).melee,
		nextShot = s.start + (s.stats.decoyShotDelay or 0.2),
		weapon = weapon,
		muzzle = if muzzle and muzzle:IsA("Attachment") then muzzle else nil,
		stats = s.stats,
		params = worldParams(),
		glitchAt = nil,
	}
	root.CFrame = CFrame.new(d.pos) * CFrame.Angles(0, d.yaw, 0)
	model.Parent = fxFolder()

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		local made = Instance.new("Animator")
		made.Parent = humanoid
		animator = made
	end
	local a = animator :: Animator
	local speed = s.velocity.Magnitude
	d.run = load(a, runClip(s.character), Enum.AnimationPriority.Movement)
	if weapon then
		-- The gun pose a real player has at this speed (Simulation/Poses):
		-- the sprint carry above walking speed, else the level hold.
		d.aim = load(a, Animations.POSES.AimLevel, Enum.AnimationPriority.Action)
		d.sprint = load(a, Animations.POSES.Sprint, Enum.AnimationPriority.Action2)
	end
	if d.run and speed > 0.5 then
		d.run:Play(0)
		d.run:AdjustSpeed(speed / Movement.WALK_SPEED)
	end
	if d.aim then
		d.aim:Play(0)
	end
	if d.sprint and speed > Movement.WALK_SPEED + 2 and not d.fires then
		d.sprint:Play(0)
	end
	decoys[s.owner] = d
	-- The split: static where the dash started (the decoy stands in it).
	DashDecoy.static(root.CFrame, bodySize(d), SPLIT_TIME)
end

local function stepDecoy(d: Decoy, dt: number, now: number)
	if d.glitchAt then
		local k = (os.clock() - d.glitchAt) / GLITCH_TIME
		if k >= 1 then
			ModVfx.burst(d.pos, TeamColor.GLITCH, 14, "Cross")
			GlitchVfx.piece({
				name = "Pixels_Energy",
				cframe = CFrame.new(d.pos) * CFrame.Angles(0, math.random() * math.pi * 2, 0),
				scale = Vector3.one * 1.8,
				scale1 = Vector3.one * 0.4,
				color = TeamColor.GLITCH,
				life = 0.25,
				alpha0 = 0,
				stutter = 0.2,
			})
			remove(d)
			return
		end
		-- Jitters in place, bits dropping out.
		local jitter = Vector3.new((math.random() - 0.5) * 0.9, 0, (math.random() - 0.5) * 0.9)
		d.root.CFrame = CFrame.new(d.pos + jitter) * CFrame.Angles(0, d.yaw, 0)
		for _, p in d.parts do
			p.LocalTransparencyModifier = if math.random() < 0.3 + 0.6 * k then 1 else 0
		end
		return
	end
	if now >= d.untilT or not d.owner.Parent then
		glitchOut(d)
		return
	end

	-- Run on, stop at walls.
	local v = d.velocity
	if v.Magnitude > 0.1 then
		local ahead = Workspace:Raycast(d.pos, v.Unit * (v.Magnitude * dt + 1.2), d.params)
		if ahead then
			d.velocity = Vector3.zero
			if d.run then
				d.run:Stop(0.15)
			end
			if d.sprint then
				d.sprint:Stop(0.15)
			end
		else
			d.pos += v * dt
		end
	end
	-- Follow the ground, fall off ledges.
	local down = Workspace:Raycast(
		d.pos + Vector3.yAxis,
		-Vector3.yAxis * (d.rootHeight + 1 + STEP_SNAP),
		d.params
	)
	local ground = if down then down.Position.Y + d.rootHeight else nil
	if ground and d.pos.Y - ground <= STEP_SNAP and d.fall <= 0 then
		d.pos = Vector3.new(d.pos.X, ground, d.pos.Z)
	else
		d.fall += Workspace.Gravity * dt
		local y = d.pos.Y - d.fall * dt
		if ground and y <= ground then
			y = ground
			d.fall = 0
		end
		d.pos = Vector3.new(d.pos.X, y, d.pos.Z)
	end

	-- G3: turn to the nearest enemy in sight and shoot at the gun's rate.
	if d.fires and now >= d.nextShot then
		local eye = d.pos + Vector3.new(0, 1.5, 0)
		local target = nearestEnemy(d, eye)
		local config = d.weapon :: Types.WeaponConfig
		if target then
			local to = (target.Position - d.pos) * Vector3.new(1, 0, 1)
			if to.Magnitude > 0.1 then
				local want = math.atan2(-to.X, -to.Z)
				local diff = (want - d.yaw + math.pi) % (2 * math.pi) - math.pi
				d.yaw += diff * math.clamp(TURN_RATE * dt, 0, 1)
				-- Shoots once it's (nearly) facing it.
				if math.abs(diff) < math.rad(25) then
					fakeShot(d, target)
					d.nextShot = now
						+ math.max(config.fireInterval, d.stats.decoyShotMinGap or 0.12)
				end
			end
		else
			d.nextShot = now + 0.1
		end
	end
	d.root.CFrame = CFrame.new(d.pos) * CFrame.Angles(0, d.yaw, 0)
end

-- Every frame (UpgradeFx/Dash).
function DashDecoy.step(dt: number)
	local now = time()
	for _, d in decoys do
		stepDecoy(d, dt, now)
	end
	stepStatics()
end

return DashDecoy
