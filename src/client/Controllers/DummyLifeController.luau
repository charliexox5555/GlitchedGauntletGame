--!strict
-- The range's training bots on the client (vault/01 Design/Range v5.md, numbers in Config/RangeDummies). Owner,
-- 2026-11-25: "they will all just stand there but they need animations for getting hit ... and pulse", then "have a
-- better idle animation".
--
-- The server plays each bot's clips (the game's own third-person idle; the strafers' side runs). On top of them,
-- every model tagged `RangeBot` gets, locally:
--   * a head that looks about now and then, on its own timer;
--   * hit reactions: spring-driven (snap, brake, overshoot, settle) from the server's hit stamps
--     (LobbyServer/Range/RangeBots: HitFrom, HitHead, HitDealt, HitKill, then HitAt): the chest is pushed away from
--     the shooter and twists, the head lags or snaps back on a headshot, the arms fly and the knees give; repeated
--     hits stack;
--   * the pulse: every hit flashes the body toward white and settles;
--   * going down: a ragdoll copy of the body is knocked away from the shot (kill flash white), lies still, fades;
--   * coming back (`Respawned`): the new bot starts crouched and leaning over in white and slowly stands up.
-- Offsets go on each joint's parent-side attachment, so they layer over the Animator (AnimationConstraint rigs: a
-- scripted Transform is overwritten by it; TpIkController does the same). Purely visual and local: the server's
-- hitboxes don't move. The moving dummy's carriage is drawn here from the server clock (shared/RangeCarriage).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Health = require(ReplicatedStorage.Shared.Health)
local RangeCarriage = require(ReplicatedStorage.Shared.RangeCarriage)
local RangeDummies = require(ReplicatedStorage.Shared.Config.RangeDummies)
local RangeDummyLook = require(ReplicatedStorage.Shared.RangeDummyLook)

local DummyLifeController = {}

local TAG = "RangeBot"
local CARRIAGE_TAG = "RangeMovingDummy"
local MAX_DISTANCE = 220 -- studs: bots further than this from the camera aren't posed
local RAD = math.rad
local WHITE = Color3.new(1, 1, 1)

local IDLE = RangeDummies.IDLE
local REACT = RangeDummies.REACT
local PULSE = RangeDummies.PULSE
local SPAWN = RangeDummies.SPAWN

-- A damped spring on one axis (degrees), kicked by adding velocity.
type Spring = { x: number, v: number, w: number, z: number }

local function spring(spec: RangeDummies.SpringSpec): Spring
	return { x = 0, v = 0, w = spec.frequency * 2 * math.pi, z = spec.damping }
end

local function stepSpring(s: Spring, dt: number)
	-- Semi-implicit Euler in small steps: stable at low frame rates too.
	local steps = math.max(1, math.ceil(dt / (1 / 120)))
	local h = dt / steps
	for _ = 1, steps do
		s.v += (-s.w * s.w * s.x - 2 * s.z * s.w * s.v) * h
		s.x += s.v * h
	end
	s.x = math.clamp(s.x, -REACT.limit, REACT.limit)
end

-- Kicks a spring so it peaks near `degrees` (the impulse that gives an underdamped spring about that first swing).
local function kick(s: Spring, degrees: number)
	s.v += degrees * s.w * 1.25
end

type Joint = { attachment: Attachment, origin: CFrame }

type Bot = {
	model: Model,
	root: BasePart,
	joints: { [string]: Joint },
	parts: { BasePart },
	chestPitch: Spring,
	chestTwist: Spring,
	chestRoll: Spring,
	headPitch: Spring,
	headTwist: Spring,
	armsUp: Spring,
	armsOut: Spring,
	knees: Spring,
	springs: { Spring }, -- all of the above, stepped together
	lookYaw: number,
	lookPitch: number,
	lookTargetYaw: number,
	lookTargetPitch: number,
	nextLook: number,
	pulse: number, -- the flash now, 0..1
	pulseFrom: number,
	pulseAt: number,
	pulseTime: number,
	spawnAt: number?,
	lastHitAt: number,
	down: boolean, -- its ragdoll has played (it stays down until the server replaces it)
	connections: { RBXScriptConnection },
}

local bots: { [Model]: Bot } = {}
local carriages: { [Model]: { y: number, z: number, rotation: CFrame } } = {}
local rng = Random.new()

local JOINTS = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	Neck = "Head",
	LeftShoulder = "LeftUpperArm",
	RightShoulder = "RightUpperArm",
	LeftHip = "LeftUpperLeg",
	RightHip = "RightUpperLeg",
	LeftKnee = "LeftLowerLeg",
	RightKnee = "RightLowerLeg",
}

local function jointOf(model: Model, partName: string, jointName: string): Joint?
	local p = model:FindFirstChild(partName)
	local joint = p and p:FindFirstChild(jointName)
	if joint and joint:IsA("AnimationConstraint") and joint.Attachment0 then
		local a = joint.Attachment0 :: Attachment
		return { attachment = a, origin = a.CFrame }
	end
	return nil
end

local function pose(b: Bot, name: string, offset: CFrame)
	local j = b.joints[name]
	if j and j.attachment.Parent then
		j.attachment.CFrame = j.origin * offset
	end
end

local function restore(b: Bot)
	for _, j in b.joints do
		if j.attachment.Parent then
			j.attachment.CFrame = j.origin
		end
	end
end

local function colourParts(b: Bot, flash: number)
	for _, p in b.parts do
		local base = if p.Parent then RangeDummyLook.colourOf(p) else nil
		if base then
			p.Color = if flash > 0.001 then base:Lerp(WHITE, flash) else base
		end
	end
end

local function startPulse(b: Bot, amount: number, time: number)
	b.pulseFrom = math.max(amount, b.pulse)
	b.pulseAt = os.clock()
	b.pulseTime = time
end

-- A hit stamped by the server: kick the springs and flash.
local function onHit(b: Bot)
	local at = b.model:GetAttribute("HitAt")
	if typeof(at) ~= "number" or at <= b.lastHitAt then
		return
	end
	b.lastHitAt = at
	local dealt = b.model:GetAttribute("HitDealt")
	local head = b.model:GetAttribute("HitHead") == true
	local killed = b.model:GetAttribute("HitKill") == true
	local from = b.model:GetAttribute("HitFrom")
	local scale = if typeof(dealt) == "number"
		then math.clamp(dealt / REACT.fullDamage, REACT.minScale, REACT.maxScale)
		else 1
	-- Where the shot came from, in the bot's own space (-Z is its front).
	local dir = Vector3.new(0, 0, -1)
	if typeof(from) == "Vector3" then
		local rel = b.root.CFrame:PointToObjectSpace(from)
		local flat = Vector3.new(rel.X, 0, rel.Z)
		if flat.Magnitude > 0.05 then
			dir = flat.Unit
		end
	end
	-- From the front (dir.Z < 0) the chest goes back (+pitch); from the right (+X) the top rolls left and the chest
	-- twists away. A little randomness so a spray isn't a metronome.
	local front = -dir.Z
	local side = dir.X + rng:NextNumber(-0.35, 0.35)
	if head then
		local away = if front >= 0 then 1 else -1
		kick(b.headPitch, REACT.headPitch * scale * (0.6 + 0.4 * math.abs(front)) * away)
		kick(b.headTwist, REACT.headTwist * scale * side)
		kick(b.chestPitch, REACT.headChest * scale * front)
		kick(b.armsUp, REACT.headArms * scale)
		startPulse(b, PULSE.head, PULSE.time)
	else
		kick(b.chestPitch, REACT.bodyPitch * scale * front)
		kick(b.chestTwist, REACT.bodyTwist * scale * side)
		kick(b.chestRoll, REACT.bodyRoll * scale * side)
		kick(b.headPitch, REACT.bodyHead * scale * front)
		kick(b.armsUp, REACT.bodyArms * scale * 0.6)
		kick(b.armsOut, REACT.bodyArms * scale * 0.5)
		kick(b.knees, REACT.bodyKnees * scale)
		startPulse(b, PULSE.body, PULSE.time)
	end
	if killed then
		startPulse(b, PULSE.kill, PULSE.killTime)
	end
end

local function removeBot(model: Model)
	local b = bots[model]
	if not b then
		return
	end
	bots[model] = nil
	for _, c in b.connections do
		c:Disconnect()
	end
	restore(b)
	colourParts(b, 0)
end

local addBot: (Instance) -> ()

addBot = function(model: Instance)
	if not model:IsA("Model") or bots[model] or not model:IsDescendantOf(Workspace) then
		return
	end
	local rootPart = model:FindFirstChild("HumanoidRootPart")
	if not (rootPart and rootPart:IsA("BasePart")) then
		-- Streamed in as an empty model first: try again when its parts land.
		task.spawn(function()
			if model:WaitForChild("HumanoidRootPart", 15) and model:WaitForChild("Head", 5) then
				task.wait(0.1)
				if CollectionService:HasTag(model, TAG) then
					addBot(model)
				end
			end
		end)
		return
	end
	local joints: { [string]: Joint } = {}
	for jointName, partName in JOINTS do
		local j = jointOf(model, partName, jointName)
		if j then
			joints[jointName] = j
		end
	end
	local b: Bot = {
		model = model,
		root = rootPart,
		joints = joints,
		parts = {},
		chestPitch = spring(REACT.torso),
		chestTwist = spring(REACT.torso),
		chestRoll = spring(REACT.torso),
		headPitch = spring(REACT.head),
		headTwist = spring(REACT.head),
		armsUp = spring(REACT.arms),
		armsOut = spring(REACT.arms),
		knees = spring(REACT.legs),
		springs = {},
		lookYaw = 0,
		lookPitch = 0,
		lookTargetYaw = 0,
		lookTargetPitch = 0,
		nextLook = os.clock() + rng:NextNumber(IDLE.look[1], IDLE.look[2]),
		pulse = 0,
		pulseFrom = 0,
		pulseAt = 0,
		pulseTime = 1,
		spawnAt = nil,
		lastHitAt = 0,
		down = false,
		connections = {},
	}
	b.springs = {
		b.chestPitch,
		b.chestTwist,
		b.chestRoll,
		b.headPitch,
		b.headTwist,
		b.armsUp,
		b.armsOut,
		b.knees,
	}
	-- Hits stamped before we saw the bot (streaming in) aren't replayed.
	local at = model:GetAttribute("HitAt")
	if typeof(at) == "number" then
		b.lastHitAt = at
	end
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			table.insert(b.parts, d)
		end
	end
	table.insert(
		b.connections,
		model:GetAttributeChangedSignal("HitAt"):Connect(function()
			onHit(b)
		end)
	)
	local function materialise()
		local t = model:GetAttribute("Respawned")
		if typeof(t) == "number" and Workspace:GetServerTimeNow() - t < 1.5 then
			b.spawnAt = os.clock()
		end
	end
	materialise()
	table.insert(b.connections, model:GetAttributeChangedSignal("Respawned"):Connect(materialise))
	bots[model] = b
end

-- Going down: a loose ragdoll copy of the body (its own ball-socket joints; the animation joints let go) is knocked
-- away from the shot, lies still, then fades; the real body is hidden until the server replaces it.
local function ragdoll(b: Bot)
	local model = b.model
	restore(b)
	colourParts(b, 0)
	local ok, copy = pcall(function(): Model?
		model.Archivable = true
		return model:Clone()
	end)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = 1
		end
	end
	if not ok or not copy then
		return
	end
	for _, tag in copy:GetTags() do
		copy:RemoveTag(tag) -- a prop now, not a bot
	end
	copy.Name = model.Name .. "Ragdoll"
	local parts: { BasePart } = {}
	for _, d in copy:GetDescendants() do
		if d:IsA("Humanoid") or d:IsA("BaseScript") or d:IsA("BillboardGui") then
			d:Destroy()
		elseif d:IsA("AnimationConstraint") then
			d.Enabled = false
		end
	end
	local root = copy:FindFirstChild("HumanoidRootPart")
	if root then
		root:Destroy()
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = true
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = false
			table.insert(parts, d)
		end
	end
	-- Knocked away from the shooter (flat), a little up, with some tumble; a headshot kill hits harder.
	local R = RangeDummies.RAGDOLL
	local away = -b.root.CFrame.LookVector
	local from = model:GetAttribute("HitFrom")
	if typeof(from) == "Vector3" then
		local flat = (b.root.Position - from) * Vector3.new(1, 0, 1)
		if flat.Magnitude > 0.1 then
			away = flat.Unit
		end
	end
	local push = R.push * (if model:GetAttribute("HitHead") == true then R.headshotPush else 1)
	copy.Parent = Workspace
	for _, p in parts do
		local share = if p.Name == "UpperTorso" or p.Name == "Head" then 1 else 0.55
		p.AssemblyLinearVelocity = away * push * share + Vector3.new(0, R.lift, 0)
	end
	local chest = copy:FindFirstChild("UpperTorso")
	if chest and chest:IsA("BasePart") then
		local axis = Vector3.new(0, 1, 0):Cross(away)
		chest.AssemblyAngularVelocity = axis * R.spin
			+ Vector3.new(0, rng:NextNumber(-1, 1) * R.spin * 0.4, 0)
	end
	-- The kill's white, settling back to the body colour on the ragdoll.
	for _, p in parts do
		local base = RangeDummyLook.colourOf(p)
		if base then
			p.Color = base:Lerp(WHITE, PULSE.kill)
			TweenService
				:Create(p, TweenInfo.new(PULSE.killTime, Enum.EasingStyle.Quad), { Color = base })
				:Play()
		end
	end
	task.delay(R.rest + 0.8, function()
		if not copy.Parent then
			return
		end
		local info = TweenInfo.new(R.fade, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for _, p in parts do
			if p.Parent and p.Transparency < 1 then
				TweenService:Create(p, info, { Transparency = 1 }):Play()
			end
		end
		task.delay(R.fade + 0.05, function()
			copy:Destroy()
		end)
	end)
end

-- Per frame --------------------------------------------------------------------

local function stepBot(b: Bot, now: number, dt: number)
	for _, s in b.springs do
		stepSpring(s, dt)
	end

	-- The head looks about now and then (over the idle clip).
	if now >= b.nextLook then
		b.nextLook = now + rng:NextNumber(IDLE.look[1], IDLE.look[2])
		b.lookTargetYaw = rng:NextNumber(-IDLE.lookYaw, IDLE.lookYaw)
		b.lookTargetPitch = rng:NextNumber(-IDLE.lookPitch, IDLE.lookPitch * 0.5)
	end
	local follow = 1 - math.exp(-IDLE.lookSpeed * dt)
	b.lookYaw += (b.lookTargetYaw - b.lookYaw) * follow
	b.lookPitch += (b.lookTargetPitch - b.lookPitch) * follow

	-- Coming back: it starts crouched low and leaning over, then slowly straightens up (smootherstep) while the
	-- white drains out of it.
	local spawnK = 1
	local spawnAt = b.spawnAt
	if spawnAt then
		spawnK = math.clamp((now - spawnAt) / SPAWN.time, 0, 1)
		if spawnK >= 1 then
			b.spawnAt = nil
		end
	end
	local down = 1 - spawnK * spawnK * spawnK * (spawnK * (spawnK * 6 - 15) + 10)

	local dip = RAD(b.knees.x)
	pose(b, "Root", CFrame.new(0, -SPAWN.drop * down - b.knees.x * 0.008, 0))
	pose(
		b,
		"Waist",
		CFrame.Angles(
			RAD(b.chestPitch.x - SPAWN.lean * down),
			RAD(b.chestTwist.x),
			RAD(b.chestRoll.x)
		)
	)
	pose(
		b,
		"Neck",
		CFrame.Angles(RAD(b.lookPitch + b.headPitch.x), RAD(b.lookYaw + b.headTwist.x), 0)
	)
	local up = RAD(b.armsUp.x)
	local out = RAD(math.abs(b.armsOut.x))
	pose(b, "LeftShoulder", CFrame.Angles(up, 0, -out))
	pose(b, "RightShoulder", CFrame.Angles(up * 0.9, 0, out))
	local hip = dip * 0.6 + RAD(SPAWN.hip) * down
	local knee = dip + RAD(SPAWN.knee) * down
	pose(b, "LeftHip", CFrame.Angles(hip, 0, 0))
	pose(b, "RightHip", CFrame.Angles(hip * 0.85, 0, 0))
	pose(b, "LeftKnee", CFrame.Angles(-knee, 0, 0))
	pose(b, "RightKnee", CFrame.Angles(-knee * 0.85, 0, 0))

	-- The flash: the hit pulse (ease out) and the respawn's white.
	local flash = 0
	if b.pulseFrom > 0 then
		local k = math.clamp((now - b.pulseAt) / b.pulseTime, 0, 1)
		flash = b.pulseFrom * (1 - k) ^ 2
		if k >= 1 then
			b.pulseFrom = 0
		end
	end
	if spawnAt then
		flash = math.max(flash, down ^ 1.5)
	end
	if math.abs(flash - b.pulse) > 0.002 or (flash == 0 and b.pulse ~= 0) then
		b.pulse = flash
		colourParts(b, flash)
	end
end

local function stepCarriages()
	local t = Workspace:GetServerTimeNow()
	for model, c in carriages do
		if not model.Parent then
			carriages[model] = nil
			continue
		end
		local from, to, speed =
			model:GetAttribute("From"), model:GetAttribute("To"), model:GetAttribute("Speed")
		if typeof(from) == "number" and typeof(to) == "number" and typeof(speed) == "number" then
			model:PivotTo(CFrame.new(RangeCarriage.x(from, to, speed, t), c.y, c.z) * c.rotation)
		end
	end
end

local function addCarriage(inst: Instance)
	if inst:IsA("Model") and not carriages[inst] then
		local pivot = inst:GetPivot()
		carriages[inst] = { y = pivot.Y, z = pivot.Z, rotation = pivot.Rotation }
	end
end

function DummyLifeController.start()
	for _, inst in CollectionService:GetTagged(TAG) do
		addBot(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(addBot)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst)
		if inst:IsA("Model") then
			removeBot(inst)
		end
	end)
	for _, inst in CollectionService:GetTagged(CARRIAGE_TAG) do
		addCarriage(inst)
	end
	CollectionService:GetInstanceAddedSignal(CARRIAGE_TAG):Connect(addCarriage)
	CollectionService:GetInstanceRemovedSignal(CARRIAGE_TAG):Connect(function(inst)
		if inst:IsA("Model") then
			carriages[inst] = nil
		end
	end)

	RunService.PreRender:Connect(function(dt: number)
		-- The carriage glides from the server clock (the server places it there too).
		stepCarriages()
		local now = os.clock()
		local camera = Workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		dt = math.min(dt, 1 / 15)
		for model, b in bots do
			if not model.Parent or not b.root.Parent then
				removeBot(model)
			elseif Health.isDowned(model) then
				if not b.down then
					b.down = true
					task.spawn(ragdoll, b)
				end
			elseif (b.root.Position - eye).Magnitude <= MAX_DISTANCE then
				stepBot(b, now, dt)
			end
		end
	end)
end

return DummyLifeController
