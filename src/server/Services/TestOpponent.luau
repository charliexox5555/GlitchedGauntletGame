--!strict
-- A stand-in for the second player in Studio playtests (Config/Match
-- TEST_OPPONENT), so one person can play whole rounds: it drafts, walks its
-- route, shoots back and dies like anyone else. A plain rig prepared by
-- CharacterService, so shots at it go through the normal WeaponService checks.
-- Not a real bot: the practice bot comes later.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Animations = require(ReplicatedStorage.Shared.Config.Animations)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Config = require(ReplicatedStorage.Shared.Config.Match)
local Net = require(ReplicatedStorage.Shared.Net)
local PoseSim = require(ReplicatedStorage.Shared.Simulation.Poses)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)

local CharacterService = require(script.Parent.CharacterService)
local WeaponService = require(script.Parent.WeaponService)
local Health = require(ReplicatedStorage.Shared.Health)

local TestOpponent = {}

local CFG = Config.TEST_OPPONENT
local SKIN = Color3.fromHex("A3A5A8")
local CLOTH = Color3.fromHex("4A4D52")
local STEP = 0.1 -- seconds between decisions
local STUCK_AFTER = 1.5 -- seconds without progress before the next waypoint
local MUZZLE_HEIGHT = 1 -- studs above the root its shots start
local MISS_OFFSET = 3 -- studs off target a miss's tracer lands

-- The opponent's seat in the draft (not a Player).
TestOpponent.KEY = table.freeze({ name = "TestOpponent" })

local rng = Random.new()
local model: Model? = nil
local fighting = false
local generation = 0

function TestOpponent.isAllowed(): boolean
	return RunService:IsStudio() and CFG.enabled
end

function TestOpponent.model(): Model?
	return model
end

function TestOpponent.isAlive(): boolean
	local m = model
	local humanoid = m and m:FindFirstChildOfClass("Humanoid")
	return Health.isAlive(humanoid)
end

function TestOpponent.health(): number
	local m = model
	local humanoid = m and m:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return 0
	end
	local shield = humanoid:GetAttribute(Combat.SHIELD_ATTRIBUTE)
	return Health.get(humanoid) + (if typeof(shield) == "number" then shield else 0)
end

function TestOpponent.remove()
	generation += 1
	fighting = false
	if model then
		model:Destroy()
		model = nil
	end
end

-- Only moves and shoots while the round is live.
function TestOpponent.setFighting(on: boolean)
	fighting = on
	local m = model
	local humanoid = m and m:FindFirstChildOfClass("Humanoid")
	if humanoid and not on then
		humanoid:Move(Vector3.zero, false)
	end
end

local function dummyFolder(): Instance
	local folder = workspace:FindFirstChild("Dummies")
	if folder then
		return folder
	end
	-- WeaponService's wall checks skip workspace.Dummies (bodies aren't walls).
	local made = Instance.new("Folder")
	made.Name = "Dummies"
	made.Parent = workspace
	return made
end

local function nearestEnemy(from: Vector3, team: number): (Player?, BasePart?)
	local best: Player? = nil
	local bestHead: BasePart? = nil
	local bestDist = CFG.range
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local head = character and character:FindFirstChild("Head")
		if
			humanoid
			and Health.isAlive(humanoid)
			and head
			and head:IsA("BasePart")
			and Teams.of(player) ~= team
		then
			local d = (head.Position - from).Magnitude
			if d < bestDist then
				best, bestHead, bestDist = player, head, d
			end
		end
	end
	return best, bestHead
end

local function shoot(m: Model, root: BasePart, target: Player, head: BasePart)
	local origin = root.Position + Vector3.new(0, MUZZLE_HEIGHT, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { dummyFolder() }
	local toHead = head.Position - origin
	local sight = workspace:Raycast(origin, toHead, params)
	local character = target.Character
	if not sight or not character or not sight.Instance:IsDescendantOf(character) then
		return -- no line of sight
	end
	local hit = rng:NextNumber() < CFG.hitChance
	local aim = head.Position
	if hit then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			-- A blocked hit (Barrier, Ghost dash, Crash Recovery) shows nothing.
			local dealt = WeaponService.hurt(humanoid, CFG.damage)
			if dealt > 0 then
				Net.event("Damaged"):FireClient(target, origin, math.round(dealt))
			end
		end
	else
		aim += rng:NextUnitVector() * MISS_OFFSET
	end
	Net.unreliable("ShotFx"):FireAllClients(m, CFG.weapon, origin, { aim })
end

local function brain(
	m: Model,
	humanoid: Humanoid,
	root: BasePart,
	team: number,
	toWorld: (Vector3) -> Vector3,
	gen: number
)
	local waypoint = 1
	local lastDistance = math.huge
	local lastProgress = os.clock()
	local nextShot = 0
	while generation == gen and m.Parent and Health.isAlive(humanoid) do
		task.wait(STEP)
		PoseSim.legs(m) -- the players' direction-blended run, so a solo test shows it
		if not fighting then
			continue
		end
		-- Walk the route, on to the next point when close or stuck.
		local goal = toWorld(CFG.route[waypoint])
		local flat = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)
		local distance = flat.Magnitude
		if distance < lastDistance - 0.2 then
			lastDistance = distance
			lastProgress = os.clock()
		end
		if distance < 3 or os.clock() - lastProgress > STUCK_AFTER then
			waypoint = waypoint % #CFG.route + 1
			lastDistance = math.huge
			lastProgress = os.clock()
		elseif distance > 0 then
			humanoid:Move(flat.Unit, false)
		end
		local target, head = nearestEnemy(root.Position, team)
		if target and head then
			local look = Vector3.new(head.Position.X, root.Position.Y, head.Position.Z)
			root.CFrame = CFrame.lookAt(root.Position, look)
			local now = os.clock()
			if now >= nextShot then
				nextShot = now + CFG.fireEvery
				shoot(m, root, target, head)
			end
		end
	end
end

-- A fresh opponent standing at `spawnAt`, on `team`. Its route is written for
-- the Z < 0 end of the map, so team 1's end (Z > 0) walks it turned 180 degrees.
function TestOpponent.spawn(spawnAt: CFrame, team: number, toMapWorld: (Vector3) -> Vector3?)
	TestOpponent.remove()
	local gen = generation
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = SKIN
	desc.TorsoColor = CLOTH
	desc.LeftArmColor = SKIN
	desc.RightArmColor = SKIN
	desc.LeftLegColor = CLOTH
	desc.RightLegColor = CLOTH
	local m = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	if gen ~= generation then
		m:Destroy() -- removed while that yielded
		return
	end
	m.Name = "Test Opponent"
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local animate = m:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local humanoid = m:FindFirstChildOfClass("Humanoid")
	local root = m:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		m:Destroy()
		return
	end
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = CFG.walkSpeed
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.NameDisplayDistance = 0
	m:PivotTo(spawnAt + Vector3.new(0, 3, 0))
	m:SetAttribute(Teams.ATTRIBUTE, team)
	m.Parent = dummyFolder()
	CharacterService.prepare(m)
	CharacterService.useOurAnimations(m)
	model = m

	task.defer(function()
		if gen ~= generation or not m.Parent then
			return
		end
		WeaponService.attachWorldModel(m, CFG.weapon)
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local animation = Instance.new("Animation")
			animation.AnimationId = Animations.POSES.AimLevel
			local hold = animator:LoadAnimation(animation)
			hold.Priority = Enum.AnimationPriority.Action
			hold.Looped = true
			hold:Play(0)
		end
	end)

	local sign = if team == 1 then -1 else 1
	task.spawn(brain, m, humanoid, root, team, function(point: Vector3): Vector3
		local world = toMapWorld(Vector3.new(point.X * sign, 0, point.Z * sign))
		return world or root.Position
	end, gen)
end

return TestOpponent
