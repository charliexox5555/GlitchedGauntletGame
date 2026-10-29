--!strict
-- Test range dummies (Config/TestRange DUMMIES): plain grey R15 rigs holding
-- a gun, prepared by CharacterService like player characters (100 HP, hitbox
-- history), so every shot at them goes through the normal WeaponService
-- validation and rewind. Kinds: static, strafe, strafe + jump, crouch-walk,
-- long range and a shooter that fires harmless tracers (ShotFx only: it never
-- applies damage). They respawn after dying and can heal between kills.
--
-- Clients draw the health bars (RangeController) from the "RangeDummy" tag
-- and the Dummy* attributes.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Animations = require(ReplicatedStorage.Shared.Config.Animations)
local Movement = require(ReplicatedStorage.Shared.Config.Movement)
local Net = require(ReplicatedStorage.Shared.Net)
local Status = require(ReplicatedStorage.Shared.Mods.Status)
local TestRange = require(ReplicatedStorage.Shared.Config.TestRange)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local Services = script.Parent.Parent.Services
local CharacterService = require(Services.CharacterService)
local WeaponService = require(Services.WeaponService)

type DummySpot = TestRange.DummySpot

type Dummy = {
	index: number,
	spot: DummySpot,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	home: CFrame, -- world CFrame of the root at its spot, facing the firing line
	dir: number,
	nextTurn: number,
	nextJump: number,
	lastHit: number,
	tracks: { [string]: AnimationTrack },
	yaw: number, -- shooter: current facing (radians)
	targetYaw: number,
}

local Dummies = {}

Dummies.TAG = "RangeDummy"

local SKIN = Color3.fromHex("A3A5A8") -- plain grey mannequin
local CLOTH = Color3.fromHex("4A4D52")

local rng = Random.new()
local folder: Folder? = nil
local toWorld: ((Vector3) -> CFrame)? = nil
local dummies: { [number]: Dummy } = {}
local generation = 0
local behaviour: (id: string) -> boolean = function(_id: string): boolean
	return true
end

local function between(range: { number }): number
	return rng:NextNumber(range[1], range[2])
end

local function loadTrack(
	animator: Animator,
	id: string,
	priority: Enum.AnimationPriority
): AnimationTrack
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local track = animator:LoadAnimation(anim)
	track.Priority = priority
	return track
end

local function moves(spot: DummySpot): boolean
	return TestRange.KINDS[spot.kind].speed ~= nil
end

local makeDummy: (index: number) -> ()

local function onDied(d: Dummy, gen: number)
	task.delay(TestRange.RESPAWN, function()
		if dummies[d.index] == d then
			dummies[d.index] = nil
			d.model:Destroy()
			if gen == generation and folder and folder.Parent then
				makeDummy(d.index)
			end
		end
	end)
end

makeDummy = function(index: number)
	local spot = TestRange.DUMMIES[index]
	local kind = TestRange.KINDS[spot.kind]
	local container = folder
	local convert = toWorld
	if not container or not convert then
		return
	end

	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = SKIN
	desc.TorsoColor = CLOTH
	desc.LeftArmColor = SKIN
	desc.RightArmColor = SKIN
	desc.LeftLegColor = CLOTH
	desc.RightLegColor = CLOTH
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = string.format("Dummy_%s_%d", spot.kind, spot.distance)
	-- Stream the whole dummy at once, like player characters.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy() -- a LocalScript: never runs on an NPC; we play the clips here
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = kind.speed or 0

	local floor = Vector3.new(spot.x, spot.y or 0, -spot.distance)
	local standHeight = humanoid.HipHeight + root.Size.Y / 2
	-- Face the firing line (+Z in range space).
	local home = convert(floor + Vector3.new(0, standHeight, 0)) * CFrame.Angles(0, math.pi, 0)
	model:PivotTo(home)
	-- Static dummies are anchored so players can't shove them off their marks.
	root.Anchored = not moves(spot)

	model:SetAttribute("DummyKind", spot.kind)
	model:SetAttribute("DummyLabel", spot.label or kind.label)
	model:SetAttribute("DummyDistance", spot.distance)
	model:SetAttribute("DummyAccent", kind.accent)
	CollectionService:AddTag(model, Dummies.TAG)
	model.Parent = container
	CharacterService.prepare(model)

	local now = os.clock()
	local d: Dummy = {
		index = index,
		spot = spot,
		model = model,
		humanoid = humanoid,
		root = root,
		home = home,
		dir = if rng:NextNumber() < 0.5 then -1 else 1,
		nextTurn = now + between(kind.turnAfter or { 1, 1 }),
		nextJump = now + between(kind.jumpAfter or { 1, 1 }),
		lastHit = 0,
		tracks = {},
		yaw = 0,
		targetYaw = 0,
	}
	dummies[index] = d
	local gen = generation

	local lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if health < lastHealth then
			d.lastHit = os.clock()
		end
		lastHealth = health
	end)
	humanoid.Died:Connect(function()
		onDied(d, gen)
	end)

	task.defer(function()
		if not model.Parent then
			return
		end
		WeaponService.attachWorldModel(model, spot.weapon)
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			return
		end
		-- Hold the gun up with the players' pose (Config/Animations).
		local hold = loadTrack(animator, Animations.POSES.AimLevel, Enum.AnimationPriority.Action)
		hold.Looped = true
		hold:Play(0)
		d.tracks.Hold = hold
		if kind.crouch then
			local crouch =
				loadTrack(animator, Animations.POSES.Crouch, Enum.AnimationPriority.Action2)
			crouch.Looped = true
			crouch:Play(0)
			local walk =
				loadTrack(animator, Animations.POSES.CrouchWalk, Enum.AnimationPriority.Action2)
			walk.Looped = true
			walk:Play(0, 0.001)
			d.tracks.Crouch = crouch
			d.tracks.CrouchWalk = walk
		elseif kind.speed then
			local run =
				loadTrack(animator, TestRange.ANIMATIONS.Run, Enum.AnimationPriority.Movement)
			run.Looped = true
			run:Play(0, 0.001)
			d.tracks.Run = run
			if kind.jumpAfter then
				d.tracks.Jump =
					loadTrack(animator, TestRange.ANIMATIONS.Jump, Enum.AnimationPriority.Movement)
				local fall =
					loadTrack(animator, TestRange.ANIMATIONS.Fall, Enum.AnimationPriority.Movement)
				fall.Looped = true
				d.tracks.Fall = fall
				humanoid.StateChanged:Connect(function(_, new)
					if new == Enum.HumanoidStateType.Jumping then
						d.tracks.Jump:Play(0.05)
					elseif new == Enum.HumanoidStateType.Freefall then
						fall:Play(0.15)
					elseif
						new == Enum.HumanoidStateType.Landed
						or new == Enum.HumanoidStateType.Running
					then
						fall:Stop(0.1)
					end
				end)
			end
		end
	end)
end

-- Per-frame behaviour ----------------------------------------------------------------

local function stepMover(d: Dummy, now: number, dt: number)
	local kind = TestRange.KINDS[d.spot.kind]
	local speed = kind.speed :: number
	local sway = kind.sway or 4
	local rel = d.home:PointToObjectSpace(d.root.Position)
	local moving = behaviour("Move")
	if moving then
		-- Random left/right changes (ADAD), kept inside the dummy's lane. The
		-- home CFrame faces +Z, so its local -X is the range's +X.
		if now >= d.nextTurn then
			d.dir = -d.dir
			d.nextTurn = now + between(kind.turnAfter or { 1, 1 })
		end
		if rel.X > sway then
			d.dir = -1
		elseif rel.X < -sway then
			d.dir = 1
		end
		-- Drift back onto the line if shoved.
		local back = math.clamp(-rel.Z * 0.5, -1, 1)
		d.humanoid:Move(d.home:VectorToWorldSpace(Vector3.new(d.dir, 0, back)), false)
		if kind.jumpAfter and now >= d.nextJump then
			d.humanoid.Jump = true
			d.nextJump = now + between(kind.jumpAfter)
		end
	elseif Vector3.new(rel.X, 0, rel.Z).Magnitude > 0.5 then
		-- Movement off: walk back to the spot and stand there.
		d.humanoid:Move(d.home:VectorToWorldSpace(Vector3.new(-rel.X, 0, -rel.Z).Unit), false)
	else
		d.humanoid:Move(Vector3.zero, false)
	end
	-- Status effects (Hinder): slower, a lower and floatier jump, like players
	-- (Simulation/Movement does the same for them).
	local m = Status.mults(d.model, workspace:GetServerTimeNow())
	local walkSpeed = speed * m.move
	if math.abs(d.humanoid.WalkSpeed - walkSpeed) > 1e-3 then
		d.humanoid.WalkSpeed = walkSpeed
	end
	local jumpHeight = Movement.JUMP_HEIGHT * m.jump * m.gravity
	if math.abs(d.humanoid.JumpHeight - jumpHeight) > 1e-3 then
		d.humanoid.JumpHeight = jumpHeight
	end
	if m.gravity < 1 and d.humanoid.FloorMaterial == Enum.Material.Air then
		d.root.AssemblyLinearVelocity += Vector3.new(0, workspace.Gravity * (1 - m.gravity) * dt, 0)
	end
	-- Keep facing the firing line.
	if math.abs(d.root.CFrame.LookVector:Dot(d.home.LookVector)) < 0.999 then
		d.root.CFrame = CFrame.lookAt(d.root.Position, d.root.Position + d.home.LookVector)
	end

	-- Leg animation follows the ground speed.
	local v = d.root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	local ground = v.Magnitude
	local stride = math.clamp(ground / speed, 0, 1)
	local run = d.tracks.Run
	if run then
		run:AdjustWeight(math.max(stride, 0.001), 0.15)
		run:AdjustSpeed(math.max(ground / 16, 0.1))
	end
	local walk, crouch = d.tracks.CrouchWalk, d.tracks.Crouch
	if walk and crouch then
		walk:AdjustWeight(math.max(stride, 0.001), 0.15)
		crouch:AdjustWeight(math.max(1 - stride, 0.001), 0.15)
		walk:AdjustSpeed(math.max(ground / Animations.CROUCH_WALK_SPEED, 0.1))
	end
end

local function stepShooterTurn(d: Dummy, dt: number)
	local k = 1 - math.exp(-TestRange.SHOOTER.turnResponsiveness * dt)
	local diff = (d.targetYaw - d.yaw + math.pi) % (2 * math.pi) - math.pi
	if math.abs(diff) < 0.002 then
		return
	end
	d.yaw += diff * k
	d.root.CFrame = d.home * CFrame.Angles(0, d.yaw, 0)
end

local function step(dt: number)
	local now = os.clock()
	local regen = behaviour("Regen")
	for _, d in dummies do
		if d.humanoid.Health <= 0 or not d.model.Parent then
			continue
		end
		if moves(d.spot) then
			stepMover(d, now, dt)
			-- Fell out of the range somehow: put it back.
			if (d.root.Position - d.home.Position).Magnitude > 40 then
				d.model:PivotTo(d.home)
			end
		elseif d.spot.kind == "Shooter" then
			stepShooterTurn(d, dt)
		end
		if
			regen
			and d.humanoid.Health < d.humanoid.MaxHealth
			and now - d.lastHit >= TestRange.REGEN_DELAY
		then
			d.humanoid.Health = d.humanoid.MaxHealth
		end
	end
end

-- Shooter ------------------------------------------------------------------------------

local function sightParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	if folder then
		table.insert(exclude, folder)
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	return params
end

-- The nearest living player the shooter can see.
local function pickTarget(d: Dummy, from: Vector3, params: RaycastParams): BasePart?
	local best: BasePart? = nil
	local bestDist = TestRange.SHOOTER.range
	for _, p in Players:GetPlayers() do
		local character = p.Character
		local head = character and character:FindFirstChild("Head")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not head or not head:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
			continue
		end
		local offset = head.Position - from
		local dist = offset.Magnitude
		-- In front of it (no shooting at people behind its tower).
		if dist < bestDist and offset.Unit:Dot(d.home.LookVector) > 0.2 then
			if not workspace:Raycast(from, offset, params) then
				best, bestDist = head, dist
			end
		end
	end
	return best
end

local function muzzleOf(d: Dummy): Vector3
	local weapon = d.model:FindFirstChild("WorldWeapon")
	local muzzle = weapon and weapon:FindFirstChild("Muzzle", true)
	if muzzle and muzzle:IsA("Attachment") then
		return muzzle.WorldPosition
	end
	local head = d.model:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head.Position else d.root.Position
end

-- One harmless shot: aimed past the target's head (never lower than its
-- centre), carried on to whatever wall is behind them.
local function fakeShot(d: Dummy, target: BasePart, params: RaycastParams)
	local origin = muzzleOf(d)
	local toTarget = target.Position - origin
	if toTarget.Magnitude < 1 then
		return
	end
	local forward = toTarget.Unit
	local right = forward:Cross(Vector3.yAxis)
	if right.Magnitude < 0.01 then
		right = Vector3.xAxis
	end
	right = right.Unit
	local up = right:Cross(forward).Unit
	local angle = rng:NextNumber(0, math.pi)
	local miss = (right * math.cos(angle) + up * math.sin(angle))
		* between(TestRange.SHOOTER.missOffset)
	local dir = ((target.Position + miss) - origin).Unit
	local reach = TestRange.SHOOTER.range + 60
	local result = workspace:Raycast(origin, dir * reach, params)
	local finish = if result then result.Position else origin + dir * reach
	Net.unreliable("ShotFx"):FireAllClients(d.model, d.spot.weapon, origin, { finish })
end

local function shooterLoop(d: Dummy)
	local cfg = TestRange.SHOOTER
	local config = Weapons.get(d.spot.weapon)
	while dummies[d.index] == d and d.humanoid.Health > 0 do
		task.wait(between(cfg.burstGap))
		if
			dummies[d.index] ~= d
			or d.humanoid.Health <= 0
			or not behaviour("Shoot")
			or not config
		then
			continue
		end
		local params = sightParams()
		local target = pickTarget(d, muzzleOf(d), params)
		if not target then
			d.targetYaw = 0
			continue
		end
		-- Turn toward them (relative to facing the firing line), then fire.
		local flat = d.home:VectorToObjectSpace(target.Position - d.root.Position)
			* Vector3.new(1, 0, 1)
		if flat.Magnitude > 0.1 then
			d.targetYaw = math.atan2(-flat.X, -flat.Z)
		end
		task.wait(0.25)
		for _ = 1, cfg.burst do
			if dummies[d.index] ~= d or d.humanoid.Health <= 0 or not target.Parent then
				break
			end
			fakeShot(d, target, params)
			task.wait(cfg.shotGap)
		end
	end
end

-- API ---------------------------------------------------------------------------------

function Dummies.start(
	container: Folder,
	convert: (Vector3) -> CFrame,
	isOn: (id: string) -> boolean
)
	folder = container
	toWorld = convert
	behaviour = isOn
	RunService.Heartbeat:Connect(step)
	-- Every new shooter (first spawn, respawn, reset) runs its firing loop.
	container.ChildAdded:Connect(function(child)
		task.defer(function()
			for _, d in dummies do
				if d.model == child and d.spot.kind == "Shooter" then
					task.spawn(shooterLoop, d)
				end
			end
		end)
	end)
	for i = 1, #TestRange.DUMMIES do
		makeDummy(i)
	end
end

-- Every dummy back to full health at its spot.
function Dummies.resetAll()
	generation += 1
	for i, d in dummies do
		dummies[i] = nil
		d.model:Destroy()
	end
	for i = 1, #TestRange.DUMMIES do
		makeDummy(i)
	end
end

function Dummies.isDummy(model: Model): boolean
	return CollectionService:HasTag(model, Dummies.TAG)
end

return Dummies
