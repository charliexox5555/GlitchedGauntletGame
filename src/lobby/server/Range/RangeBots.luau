--!strict
-- The range's training bots on the server (vault/01 Design/Range v5.md, numbers
-- in Config/RangeDummies). RangeService hands it the match services and every
-- model tagged `RangeBot`; this:
--   * dresses each bot (shared/RangeDummyLook: the blocky body in one blue), plays the game's own third-person
--     idle on it (Config/RangeDummies CLIPS; the strafers blend in the side runs) and prepares
--     it like any fighter (CharacterService: health, hitbox history), so shots
--     go through WeaponService's normal checks;
--   * stamps each hit on the bot (HitFrom / HitHead / HitDealt / HitKill, then
--     HitAt) for the clients' hit reactions (Controllers/DummyLifeController);
--   * brings a downed bot back after RESPAWN as it was built (`Respawned`);
--   * walks `Behaviour = "Strafe"` bots left and right of their spot;
--   * keeps the damage dummy (tag RangeDamageDummy) standing and counts its
--     damage (DamageTotal / DamageDps / DamageHits);
--   * runs the moving dummy's carriage (tag RangeMovingDummy) from the server
--     clock (shared/RangeCarriage; clients draw it from the same clock).
-- No remotes: everything here is decided by the server.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RangeCarriage = require(ReplicatedStorage.Shared.RangeCarriage)
local RangeEvents = require(script.Parent.RangeEvents)
local RangeDummies = require(ReplicatedStorage.Shared.Config.RangeDummies)
local RangeDummyLook = require(ReplicatedStorage.Shared.RangeDummyLook)

local RangeBots = {}

RangeBots.BOT_TAG = "RangeBot"
RangeBots.DUMMY_TAG = "RangeDummy" -- the shared training-dummy tag (no bars or name tags since 2026-11-26)
local DAMAGE_TAG = "RangeDamageDummy"
local CARRIAGE_TAG = RangeCarriage.TAG

export type MatchServices = {
	Character: any,
	Health: any,
	HealthLib: any,
	Damage: any,
}

type Clips = {
	idle: AnimationTrack,
	upper: AnimationTrack,
	runL: AnimationTrack?,
	runR: AnimationTrack?,
	upperRun: AnimationTrack?,
}

type Strafer = {
	model: Model,
	clips: Clips?,
	run: number, -- 0..1, the eased share of the run clips
	blendAt: number, -- os.clock() of the last weight update (sent ~10 times a second, not every frame)
	humanoid: Humanoid,
	root: BasePart,
	home: CFrame,
	sway: number,
	dir: number,
	nextTurn: number,
}

type DamageLog = {
	total: number,
	hits: number,
	recent: { { t: number, amount: number } },
	last: number,
}

local match: MatchServices? = nil
local rng = Random.new()
local templates: { [Model]: { template: Model, parent: Instance } } = {}
local strafers: { [Model]: Strafer } = {}
local damageLogs: { [Model]: DamageLog } = {}
local lastGuarded: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local carriages: { [Model]: { home: CFrame } } = {}
local CARRIAGE_STEP = 0.05 -- s between rider moves on the server (clients glide it every frame)

local function between(range: { number }): number
	return range[1] + rng:NextNumber() * (range[2] - range[1])
end

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Hit stamps ---------------------------------------------------------------------------

local function attackerPosition(attacker: Instance): Vector3?
	local body: Instance? = if attacker:IsA("Player") then attacker.Character else attacker
	local root = body and body:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function onHit(
	attacker: Instance,
	victim: Model,
	dealt: number,
	killed: boolean,
	headshot: boolean?
)
	if not CollectionService:HasTag(victim, RangeBots.BOT_TAG) then
		return nil
	end
	local amount = lastGuarded[victim] or dealt
	lastGuarded[victim] = nil
	local from = attackerPosition(attacker)
	if from then
		victim:SetAttribute("HitFrom", from)
	end
	victim:SetAttribute("HitHead", headshot == true)
	victim:SetAttribute("HitDealt", amount)
	victim:SetAttribute("HitKill", killed)
	-- Last: the clients react when this changes, with the fields above in place.
	victim:SetAttribute("HitAt", workspace:GetServerTimeNow())
	if killed then
		-- the task Path (Services/TaskService): a player downed a training bot
		local shooter = if attacker:IsA("Player")
			then attacker
			elseif attacker:IsA("Model") then Players:GetPlayerFromCharacter(attacker)
			else nil
		if shooter then
			RangeEvents.fire(shooter, "bot")
		end
	end
	return nil
end

-- The damage dummy ---------------------------------------------------------------------

local function publishDamage(model: Model, log: DamageLog)
	local now = os.clock()
	local window = RangeDummies.DAMAGE_DUMMY.dpsWindow
	local sum = 0
	local kept = {}
	for _, hit in log.recent do
		if now - hit.t <= window then
			sum += hit.amount
			table.insert(kept, hit)
		end
	end
	log.recent = kept
	model:SetAttribute("DamageTotal", math.round(log.total))
	model:SetAttribute("DamageHits", log.hits)
	model:SetAttribute("DamageDps", math.round(sum / window))
end

-- Every hit on a combatant passes here first: the damage dummy counts the
-- full amount but never drops below its floor (it is healed straight back).
local function damageGuard(
	victim: Model,
	humanoid: Humanoid,
	amount: number,
	_attacker: Player?
): number
	if not CollectionService:HasTag(victim, DAMAGE_TAG) or not match then
		return amount
	end
	local log = damageLogs[victim]
	if not log then
		log = { total = 0, hits = 0, recent = {}, last = 0 }
		damageLogs[victim] = log
	end
	log.total += amount
	log.hits += 1
	log.last = os.clock()
	table.insert(log.recent, { t = log.last, amount = amount })
	publishDamage(victim, log)
	lastGuarded[victim] = amount
	local hp = match.HealthLib.get(humanoid)
	local allowed = math.max(hp - RangeDummies.DAMAGE_DUMMY.floorHp, 0)
	task.defer(function()
		if humanoid.Parent and match then
			match.Health.set(humanoid, match.HealthLib.max(humanoid))
		end
	end)
	return math.min(amount, allowed)
end

local function stepDamageBoards()
	local now = os.clock()
	for model, log in damageLogs do
		if not model.Parent then
			damageLogs[model] = nil
		elseif log.hits > 0 and now - log.last > RangeDummies.DAMAGE_DUMMY.resetAfter then
			log.total, log.hits, log.recent = 0, 0, {}
			publishDamage(model, log)
		elseif log.hits > 0 then
			publishDamage(model, log)
		end
	end
end

-- Strafers -----------------------------------------------------------------------------

-- The clips (played here on the server: they replicate to every client like any NPC's).
local function track(
	animator: Animator,
	id: string,
	priority: Enum.AnimationPriority
): AnimationTrack?
	if id == "" then
		return nil
	end
	local a = Instance.new("Animation")
	a.AnimationId = id
	local ok, t = pcall(function()
		return animator:LoadAnimation(a)
	end)
	if not ok then
		warn("[RangeBots] couldn't load", id, t)
		return nil
	end
	t.Priority = priority
	t.Looped = true
	return t
end

local function startClips(humanoid: Humanoid, strafer: boolean): Clips?
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local C = RangeDummies.CLIPS
	local idle = track(animator, C.idle, Enum.AnimationPriority.Idle)
	local upper = track(animator, C.upper, Enum.AnimationPriority.Action)
	if not idle or not upper then
		return nil
	end
	-- each bot starts its idle at its own point, so a crowd doesn't breathe in step
	for _, t in { idle, upper } do
		t:Play(0)
		t.TimePosition = rng:NextNumber() * math.max(t.Length, 0.1)
	end
	local clips: Clips = { idle = idle, upper = upper }
	if strafer then
		clips.runL = track(animator, C.runL, Enum.AnimationPriority.Movement)
		clips.runR = track(animator, C.runR, Enum.AnimationPriority.Movement)
		clips.upperRun = track(animator, C.upperRun, Enum.AnimationPriority.Action)
		for _, t in { clips.runL, clips.runR, clips.upperRun } do
			if t then
				t:Play(0, 0.001)
			end
		end
	end
	return clips
end

local function addStrafer(bot: Model, humanoid: Humanoid, clips: Clips?)
	local root = rootOf(bot)
	if not root then
		return
	end
	local sway = bot:GetAttribute("Sway")
	local speed = bot:GetAttribute("Speed")
	local S = RangeDummies.STRAFE
	-- Facing stays the way the bot was placed; only the root moves.
	local home = root.CFrame
	root.Anchored = false
	humanoid.WalkSpeed = if typeof(speed) == "number" and speed > 0 then speed else S.speed
	humanoid.AutoRotate = false
	if root:CanSetNetworkOwnership() then
		root:SetNetworkOwner(nil) -- the server walks it; clients only watch
	end
	strafers[bot] = {
		model = bot,
		clips = clips,
		run = 0,
		blendAt = 0,
		humanoid = humanoid,
		root = root,
		home = home,
		sway = if typeof(sway) == "number" and sway > 0 then sway else S.sway,
		dir = if rng:NextNumber() < 0.5 then -1 else 1,
		nextTurn = os.clock() + between(S.turnAfter),
	}
end

-- The run clips follow the ground speed: RunL / RunR by which way the bot is going, the upper body hands over to
-- the run's arms (weights eased; set every step, faded by the engine over the same time).
local BLEND_EVERY = 0.1

local function blendRun(s: Strafer)
	local clips = s.clips
	local now = os.clock()
	if not clips or now - s.blendAt < BLEND_EVERY then
		return
	end
	local dt = math.min(now - s.blendAt, 0.5)
	s.blendAt = now
	local v = s.home:VectorToObjectSpace(s.root.AssemblyLinearVelocity)
	local want = math.clamp(math.abs(v.X) / RangeDummies.STRAFE.speed, 0, 1)
	s.run += (want - s.run) * (1 - math.exp(-RangeDummies.STRAFE.blend * dt))
	local k = math.max(s.run, 0.001)
	local fade = BLEND_EVERY
	local rate = math.clamp(math.abs(v.X) / RangeDummies.CLIPS.runSpeed, 0.3, 1.6)
	if clips.runR then
		clips.runR:AdjustWeight(if v.X >= 0 then k else 0.001, fade)
		clips.runR:AdjustSpeed(rate)
	end
	if clips.runL then
		clips.runL:AdjustWeight(if v.X < 0 then k else 0.001, fade)
		clips.runL:AdjustSpeed(rate)
	end
	if clips.upperRun then
		clips.upperRun:AdjustWeight(k, fade)
		clips.upperRun:AdjustSpeed(rate)
	end
	clips.upper:AdjustWeight(math.max(1 - s.run, 0.001), fade)
end

local function stepStrafers()
	local now = os.clock()
	for bot, s in strafers do
		if not bot.Parent or not s.root.Parent then
			strafers[bot] = nil
			continue
		end
		if match and match.HealthLib.isDowned(s.humanoid) then
			s.humanoid:Move(Vector3.zero, false)
			continue
		end
		local rel = s.home:PointToObjectSpace(s.root.Position)
		if now >= s.nextTurn then
			s.dir = -s.dir
			s.nextTurn = now + between(RangeDummies.STRAFE.turnAfter)
		end
		if rel.X > s.sway then
			s.dir = -1
		elseif rel.X < -s.sway then
			s.dir = 1
		end
		local back = math.clamp(-rel.Z * 0.5, -1, 1) -- drift back onto the line if shoved
		s.humanoid:Move(s.home:VectorToWorldSpace(Vector3.new(s.dir, 0, back)), false)
		if s.root.CFrame.LookVector:Dot(s.home.LookVector) < 0.999 then
			s.root.CFrame = CFrame.lookAt(s.root.Position, s.root.Position + s.home.LookVector)
		end
		blendRun(s)
	end
end

-- The moving dummy's carriage ----------------------------------------------------------

-- The carriage itself never moves on the server (shared/RangeCarriage: clients glide it); only its rider does.
local function addCarriage(inst: Instance)
	if not inst:IsA("Model") or carriages[inst] then
		return
	end
	-- clients get it whole (its parts with it, not an empty model first) and read its home from the stamp
	inst.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local stored = inst:GetAttribute(RangeCarriage.HOME_ATTRIBUTE)
	local home = if typeof(stored) == "CFrame" then stored else inst:GetPivot()
	inst:SetAttribute(RangeCarriage.HOME_ATTRIBUTE, home)
	carriages[inst] = { home = home }
	for _, rider in RangeCarriage.riders(inst) do
		RangeCarriage.riderOffset(rider, home, true)
	end
end

local function stepCarriages()
	local t = workspace:GetServerTimeNow()
	for model, c in carriages do
		if not model.Parent then
			carriages[model] = nil
			continue
		end
		local want = RangeCarriage.pose(model, c.home, t)
		if want then
			for _, rider in RangeCarriage.riders(model) do
				local offset = RangeCarriage.riderOffset(rider, c.home, true)
				if offset then
					rider:PivotTo(want * offset)
				end
			end
		end
	end
end

-- Bots ---------------------------------------------------------------------------------

local prepare: (Model, boolean?) -> ()

local function onDowned(bot: Model)
	local entry = templates[bot]
	if not entry then
		return
	end
	templates[bot] = nil
	strafers[bot] = nil
	task.delay(RangeDummies.RESPAWN, function()
		if not entry.parent.Parent then
			return
		end
		-- (a carriage rider comes back where it was built; the next carriage step puts it on the carriage)
		local fresh = entry.template:Clone()
		bot:Destroy()
		fresh.Parent = entry.parent
		prepare(fresh, true)
	end)
end

prepare = function(bot: Model, respawned: boolean?)
	local services = match
	if not services or templates[bot] or not bot:IsDescendantOf(workspace) then
		return
	end
	local humanoid = bot:FindFirstChildOfClass("Humanoid")
	local parent = bot.Parent
	if not humanoid or not parent then
		return
	end
	-- Kept before anything changes it, to bring the bot back as it was built.
	local template = bot:Clone()
	CollectionService:RemoveTag(template, RangeBots.DUMMY_TAG)
	local entry = { template = template, parent = parent }
	templates[bot] = entry

	-- Stream the whole bot at once (the range is far from the lobby), so clients never see half a rig.
	bot.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	-- No name tag and no health bar, Roblox's or ours (owner 2026-11-26).
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 0
	humanoid.HealthDisplayDistance = 0
	RangeDummyLook.apply(bot)
	-- A carriage rider sits where the carriage is (its template was saved at the build spot).
	local carriage = parent:FindFirstAncestorWhichIsA("Model")
	while carriage and not CollectionService:HasTag(carriage, CARRIAGE_TAG) do
		carriage = carriage:FindFirstAncestorWhichIsA("Model")
	end
	if carriage then
		-- its place on the carriage, stamped while it still stands where it was built
		addCarriage(carriage)
		local c = carriages[carriage]
		if c then
			RangeCarriage.riderOffset(bot, c.home, true)
		end
	end
	CollectionService:AddTag(bot, RangeBots.DUMMY_TAG)
	services.Character.prepare(bot)
	if respawned then
		bot:SetAttribute("Respawned", workspace:GetServerTimeNow())
	end
	local strafer = bot:GetAttribute("Behaviour") == "Strafe"
	local clips = startClips(humanoid, strafer)
	if strafer then
		addStrafer(bot, humanoid, clips)
	end
	services.HealthLib.onDowned(humanoid, function()
		onDowned(bot)
	end)
	bot.Destroying:Connect(function()
		templates[bot] = nil
		strafers[bot] = nil
		damageLogs[bot] = nil
	end)
end

function RangeBots.start(services: MatchServices)
	match = services
	services.Damage.onHit(onHit)
	services.Damage.addDamageGuard(damageGuard)

	for _, bot in CollectionService:GetTagged(RangeBots.BOT_TAG) do
		if bot:IsA("Model") then
			prepare(bot)
		end
	end
	CollectionService:GetInstanceAddedSignal(RangeBots.BOT_TAG):Connect(function(bot)
		if bot:IsA("Model") then
			task.defer(prepare, bot)
		end
	end)
	for _, inst in CollectionService:GetTagged(CARRIAGE_TAG) do
		addCarriage(inst)
	end
	CollectionService:GetInstanceAddedSignal(CARRIAGE_TAG):Connect(addCarriage)

	local boardClock, carriageClock = 0, 0
	RunService.Heartbeat:Connect(function(dt: number)
		carriageClock += dt
		if carriageClock >= CARRIAGE_STEP then
			carriageClock = 0
			stepCarriages()
		end
		stepStrafers()
		boardClock += dt
		if boardClock >= 0.25 then
			boardClock = 0
			stepDamageBoards()
		end
	end)
end

return RangeBots
