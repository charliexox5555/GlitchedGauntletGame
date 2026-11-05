--!strict
-- A bot's Mods (vault/01 Design/Bots.md → Mod rules).
--
-- Predicted Mods (Dash, Updraft) run in the shared simulation exactly like a
-- player's: the kit is published on the bot's owner (Mod<n>Id / Level /
-- Serial, ModResetSerial, as ModService does for a player) and the bot
-- presses its Mod<n> input. Server Mods (Molly, Frost, Recon, Heal Orb,
-- Stim) call the Mod module's own validate / apply with the same ServerCtx
-- ModService builds, the bot's character standing in as the caster
-- (Teams.characterOf). Charges and cooldowns use the same Charges rules.
-- Firewall and Recall need Player-keyed services: bots don't cast them.
--
-- Each Mod has one "when to use" rule; a true rule casts with the profile's
-- abilityUse chance, after a short hold for held Mods (the gun goes down).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Charges = require(Shared.Mods.Charges)
local Health = require(Shared.Health)
local Mods = require(Shared.Mods)
local ModsConfig = require(Shared.Config.Mods)
local Net = require(Shared.Net)
local Projectile = require(Shared.Mods.Blocks.Projectile)
local Teams = require(Shared.Mods.Teams)
-- The throwables' own flight (throw / options), for aiming.
local THROWS: { [string]: any } = {
	Molly = require(Shared.Mods.Molly),
	Frost = require(Shared.Mods.Frost),
}

local Services = script.Parent.Parent.Services
local ModEntities = require(Services.ModEntities)
local StatusService = require(Services.StatusService)
local WeaponService = require(Services.WeaponService)

local BotGun = require(script.Parent.BotGun)
local BotTypes = require(script.Parent.Types)
local Perception = require(script.Parent.Perception)

type Bot = BotTypes.Bot

local BotMods = {}

local SERVER_MODS: { [string]: boolean } = {
	Molly = true,
	Frost = true,
	Recon = true,
	HealOrb = true,
	Stim = true,
}
local USE_KINDS: { [string]: string } = {
	HeldThrow = "Throw",
	HeldPlace = "Place",
	HeldTarget = "Heal",
	HeldSteer = "Cast",
	HeldCharge = "Heal",
}
local TRY_EVERY = 0.4 -- seconds between rule checks
local THROW_PITCHES = { -6, 4, 14, 24, 36 } -- degrees tried when aiming a throw

local rng = Random.new()
-- Threads a bot's Mods scheduled (fuses, ticks): cancelled when it despawns.
local threads: { [Bot]: { thread } } = setmetatable({}, { __mode = "k" }) :: any

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function bump(owner: Instance, name: string)
	local v = owner:GetAttribute(name)
	owner:SetAttribute(name, (if typeof(v) == "number" then v else 0) + 1)
end

local function statsFor(bot: Bot, slot: number): (string?, any)
	local id = bot.kit[slot]
	if not id or id == "" then
		return nil, nil
	end
	return id, Mods.stats(id, bot.levels[slot])
end

-- The drafted kit: per slot, a Mod id and level ("" = empty).
function BotMods.setKit(bot: Bot, kit: { string }, levels: { string })
	for slot = 1, ModsConfig.SLOTS do
		local id = kit[slot] or ""
		local level = levels[slot] or ""
		local changed = bot.kit[slot] ~= id or bot.levels[slot] ~= level
		bot.kit[slot], bot.levels[slot] = id, level
		local p = "Mod" .. slot
		bot.owner:SetAttribute(p .. "Id", if id ~= "" then id else nil)
		bot.owner:SetAttribute(p .. "Level", if id ~= "" then level else nil)
		if changed then
			bump(bot.owner, p .. "Serial")
			local _, stats = statsFor(bot, slot)
			bot.modCharges[slot] = if stats then stats.charges else 0
			bot.modReadyAt[slot] = serverNow()
		end
	end
end

-- A new round: every charge back (ModService.refillCharges for players).
function BotMods.refill(bot: Bot)
	for slot = 1, ModsConfig.SLOTS do
		local _, stats = statsFor(bot, slot)
		bot.modCharges[slot] = if stats then stats.charges else 0
		bot.modReadyAt[slot] = serverNow()
	end
	bump(bot.owner, "ModResetSerial")
end

function BotMods.onSpawn(bot: Bot)
	bot.nextModTry = os.clock() + 1
	bot.owner:SetAttribute("ModHeld", 0)
end

-- A despawn or a new life: what the last one left goes (ModEntities), and
-- its pending fuses stop.
function BotMods.clear(bot: Bot, model: Model?)
	local list = threads[bot]
	if list then
		for _, t in list do
			pcall(task.cancel, t)
		end
		threads[bot] = nil
	end
	if model then
		ModEntities.clear(model :: any, true)
	end
end

-- World-only raycast params (ModService's worldParams).
local function worldParams(): RaycastParams
	local exclude: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	for _, name in { "Dummies", "Effects" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(exclude, f)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return params
end

local function hold(bot: Bot, list: { thread }, thread: thread)
	table.insert(list, thread)
	threads[bot] = list
end

-- The ServerCtx ModService builds for a player, for this bot.
local function context(
	bot: Bot,
	slot: number,
	id: string,
	stats: any,
	heldFor: number,
	look: Vector3
): any
	local model = bot.model :: Model
	local life = bot.life
	local list = threads[bot] or {}
	local level = bot.levels[slot]
	local function alive(): boolean
		return bot.life == life and bot.owner.Parent ~= nil
	end
	local function damage(victim: Model, amount: number, at: Vector3)
		WeaponService.damageBy(model, victim, amount, "Body", id, at)
	end
	return {
		player = model, -- the caster (Teams.characterOf: a model is its own character)
		character = model,
		humanoid = bot.humanoid,
		head = bot.head,
		slot = slot,
		id = id,
		level = level,
		stats = stats,
		now = serverNow(),
		heldFor = heldFor,
		worldParams = worldParams,
		cameraLook = look,
		damage = damage,
		heal = function(target: Model, amount: number, duration: number)
			if duration <= 0 then
				WeaponService.heal(target, amount)
				return
			end
			local tick = 0.25
			local steps = math.max(math.floor(duration / tick), 1)
			hold(
				bot,
				list,
				task.spawn(function()
					for _ = 1, steps do
						task.wait(tick)
						if not Health.isAlive(target:FindFirstChildOfClass("Humanoid")) then
							return
						end
						WeaponService.heal(target, amount / steps)
					end
				end)
			)
		end,
		restore = function(target: Model, amount: number)
			WeaponService.heal(target, amount)
		end,
		fx = function(kind: string, data: { [string]: any })
			data.caster = model
			data.team = bot.team
			data.id = id
			data.level = level
			Net.event("ModFx"):FireAllClients(kind, data)
		end,
		schedule = function(delay: number, fn: () -> ())
			hold(
				bot,
				list,
				task.delay(delay, function()
					if bot.owner.Parent ~= nil then
						fn()
					end
				end)
			)
		end,
		place = function(
			kind: string,
			part: BasePart,
			lifeTime: number,
			hp: number,
			maxActive: number
		)
			if not alive() or not Health.isAlive(bot.humanoid) then
				part:Destroy()
				return
			end
			ModEntities.place(model :: any, kind, part, lifeTime, hp, maxActive)
		end,
		status = function(target: Model, name: string, duration: number)
			StatusService.apply(target, name, duration)
		end,
		reveal = function(targets: { Model }, duration: number, style: string?)
			-- The bot's team sees them: players get the reveal, bots learn
			-- where they are.
			local info = if style
				then { style = style, caster = model, id = id, level = level }
				else nil
			for _, other in Players:GetPlayers() do
				if Teams.of(other) == bot.team then
					Net.event("ModReveal"):FireClient(other, targets, duration, info)
				end
			end
			for _, m in targets do
				local victim = Players:GetPlayerFromCharacter(m)
				if victim then
					Net.event("ModFx")
						:FireClient(victim, "Revealed", { duration = duration, style = style })
				end
			end
			BotMods.onReveal(bot.team, targets)
		end,
		fireRate = function(_mult: number, _duration: number) end, -- no bot Mod boosts the gun yet
		active = function(_duration: number) end, -- a HUD bar: bots have none
		objectsNear = function(at: Vector3, radius: number): { BasePart }
			return ModEntities.objectsNear(at, radius)
		end,
		damageObject = function(part: BasePart, amount: number)
			ModEntities.damage(part, amount, nil)
		end,
		anchorDown = false,
	}
end

-- Set by BotService: tells every bot on `team` where `targets` are.
local revealListener: ((team: number, targets: { Model }) -> ())? = nil
function BotMods.onReveal(team: number, targets: { Model })
	if revealListener then
		revealListener(team, targets)
	end
end
function BotMods.setRevealListener(fn: (team: number, targets: { Model }) -> ())
	revealListener = fn
end

-- The flat-then-pitched throw direction that lands nearest `point`
-- (simulated with the Mod's own flight).
local function aimThrow(bot: Bot, mod: any, stats: any, mode: string, point: Vector3): Vector3
	local head = bot.head :: BasePart
	local flat = (point - head.Position) * Vector3.new(1, 0, 1)
	local forward = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(0, 0, -1)
	local params = worldParams()
	local best, bestMiss = forward, math.huge
	for _, pitch in THROW_PITCHES do
		local r = math.rad(pitch)
		local dir = forward * math.cos(r) + Vector3.new(0, math.sin(r), 0)
		local ok, landing = pcall(function()
			local origin, velocity = mod.throw(head.Position, dir, mode, stats, params)
			local path = Projectile.simulate(origin, velocity, mod.options(stats), params)
			return Projectile.positionAt(path, Projectile.endTime(path))
		end)
		if ok then
			local miss = (landing - point).Magnitude
			if miss < bestMiss then
				best, bestMiss = dir, miss
			end
		end
	end
	return best
end

-- Spends a charge of a server Mod and casts it (after a hold for held Mods).
local function castServer(
	bot: Bot,
	slot: number,
	id: string,
	mode: string,
	aimAt: Vector3?,
	target: Model?
)
	local def = Mods.def(id)
	local module = Mods.module(id)
	local _, stats = statsFor(bot, slot)
	local model, head = bot.model, bot.head
	if not def or not module or not module.apply or not stats or not model or not head then
		return
	end
	local now = serverNow()
	local charges, readyAt = Charges.settle(
		bot.modCharges[slot],
		bot.modReadyAt[slot],
		stats.charges,
		stats.cooldown,
		now
	)
	if charges < 1 then
		bot.modCharges[slot], bot.modReadyAt[slot] = charges, readyAt
		return
	end
	local held = def.activation ~= "Instant"
	local holdFor = if held then 0.25 + rng:NextNumber() * 0.25 else 0
	local life = bot.life
	bot.gun.busyUntil = os.clock() + holdFor + ModsConfig.USE_TIME
	if held then
		bot.owner:SetAttribute("ModHeld", slot)
	end
	task.delay(holdFor, function()
		bot.owner:SetAttribute("ModHeld", 0)
		if
			bot.life ~= life
			or not bot.fighting
			or not Health.isAlive(bot.humanoid)
			or not bot.head
		then
			return
		end
		local eye = bot.head.Position
		local look = bot.root and bot.root.CFrame.LookVector or Vector3.new(0, 0, -1)
		local dir = if aimAt then (aimAt - eye).Unit else look
		local throwable = THROWS[id]
		if aimAt and throwable then
			dir = aimThrow(bot, throwable, stats, mode, aimAt)
		elseif aimAt and def.activation == "HeldCharge" then
			dir = ((aimAt - eye) * Vector3.new(1, 0, 1)).Unit * math.cos(math.rad(20))
				+ Vector3.new(0, math.sin(math.rad(20)), 0)
		end
		local ctx = context(bot, slot, id, stats, holdFor, dir)
		local req: any = {
			mode = mode,
			origin = eye,
			direction = dir.Unit,
			target = target,
			charge = if def.activation == "HeldCharge" then 1 else nil,
			bounces = if def.activation == "HeldCharge" then 0 else nil,
		}
		local validate = module.validate
		if validate then
			local ok, valid = pcall(validate, ctx, req)
			if not ok or not valid then
				return
			end
		end
		local spends = module.spends == nil or module.spends(ctx, req)
		if spends then
			local c, r = Charges.settle(
				bot.modCharges[slot],
				bot.modReadyAt[slot],
				stats.charges,
				stats.cooldown,
				serverNow()
			)
			bot.modCharges[slot], bot.modReadyAt[slot] =
				Charges.spend(c, r, stats.charges, stats.cooldown, serverNow())
		end
		local kind = if def.activation == "HeldThrow" and mode == "Alt"
			then "Lob"
			else def.useKind or USE_KINDS[def.activation]
		if kind then
			bot.owner:SetAttribute("ModUseKind", kind)
			bot.owner:SetAttribute("ModUseAt", workspace:GetServerTimeNow())
		end
		local ok, err = pcall(module.apply :: any, ctx, req)
		if not ok then
			warn("[BotMods]", id, "failed for", bot.name, err)
		end
	end)
end

-- Presses a predicted Mod's input for a moment (Simulation/Abilities casts it).
local function pressPredicted(bot: Bot, slot: number)
	local model = bot.model
	local action = bot.inputs["Mod" .. slot]
	if not model or not action then
		return
	end
	local charges = model:GetAttribute("Mod" .. slot .. "Charges")
	if typeof(charges) == "number" and charges < 1 then
		return
	end
	action:Fire(true)
	local life = bot.life
	task.delay(0.12, function()
		if bot.life == life then
			action:Fire(false)
		end
	end)
end

local function ready(bot: Bot, slot: number, id: string): boolean
	if not SERVER_MODS[id] then
		return true -- predicted: pressPredicted checks the simulation's charges
	end
	local _, stats = statsFor(bot, slot)
	if not stats then
		return false
	end
	local charges = Charges.settle(
		bot.modCharges[slot],
		bot.modReadyAt[slot],
		stats.charges,
		stats.cooldown,
		serverNow()
	)
	return charges >= 1
end

-- The most hurt ally in sight within `range` (not this bot), if any is below `below`.
local function hurtAlly(bot: Bot, allies: { Model }, range: number, below: number): Model?
	local root = bot.root
	if not root then
		return nil
	end
	local best: Model? = nil
	local bestShare = below
	for _, ally in allies do
		local humanoid = ally:FindFirstChildOfClass("Humanoid")
		local other = ally:FindFirstChild("HumanoidRootPart")
		if
			humanoid
			and other
			and other:IsA("BasePart")
			and (other.Position - root.Position).Magnitude <= range
		then
			local share = Health.get(humanoid) / math.max(Health.max(humanoid), 1)
			if share < bestShare then
				best, bestShare = ally, share
			end
		end
	end
	return best
end

-- Rules, a few times a second.
function BotMods.think(bot: Bot, world: any, now: number)
	local root, humanoid = bot.root, bot.humanoid
	if not bot.fighting or not root or not humanoid or now < bot.nextModTry then
		return
	end
	bot.nextModTry = now + TRY_EVERY
	if os.clock() < bot.gun.busyUntil or BotGun.reloading(bot.gun) then
		return
	end
	if rng:NextNumber() > bot.profile.abilityUse then
		return
	end
	local share = Health.get(humanoid) / math.max(Health.max(humanoid), 1)
	local target = bot.target
	local engaged = target ~= nil and Perception.engageable(bot, target, now)
	local distance = if target then (target.lastPos - root.Position).Magnitude else math.huge
	local hurtRecently = now - bot.lastHurtAt < 0.6
	local config = BotGun.config(bot.gun)
	local close = config ~= nil and (config.class == "Shotgun" or config.class == "SMG")

	for slot = 1, ModsConfig.SLOTS do
		local id = bot.kit[slot]
		if id == "" or not ready(bot, slot, id) then
			continue
		end
		if id == "Dash" then
			-- Close the gap with a short-range gun.
			if engaged and close and distance > 12 and distance < 32 then
				pressPredicted(bot, slot)
				return
			end
		elseif id == "Updraft" then
			-- Escape when hurt and under fire.
			if share < 0.4 and hurtRecently then
				pressPredicted(bot, slot)
				return
			end
		elseif id == "Molly" then
			-- Flush someone just out of sight, or zone a close fight.
			local known = Perception.lastKnown(bot, now)
			if not engaged and known and now - known.seenAt < 4 then
				local d = (known.lastPos - root.Position).Magnitude
				if d > 12 and d < 45 then
					castServer(bot, slot, id, "Primary", known.lastPos, nil)
					return
				end
			elseif
				engaged
				and target
				and distance > 10
				and distance < 28
				and rng:NextNumber() < 0.35
			then
				castServer(bot, slot, id, "Primary", target.lastPos, nil)
				return
			end
		elseif id == "Frost" then
			-- Slow someone it is pushing.
			if engaged and target and distance < 26 and bot.profile.aggression >= 0.5 then
				castServer(bot, slot, id, "Primary", target.lastPos, nil)
				return
			end
		elseif id == "Stim" then
			-- Hurt with nobody in sight.
			if share < 0.6 and not engaged then
				castServer(bot, slot, id, "Primary", nil, nil)
				return
			end
		elseif id == "HealOrb" then
			-- Self when hurt and not being shot this moment, else a hurt ally.
			if share < 0.55 and not hurtRecently then
				castServer(bot, slot, id, "Alt", nil, nil)
				return
			end
			local ally = hurtAlly(bot, world.allies, 40, 0.5)
			if ally then
				local aRoot = ally:FindFirstChild("HumanoidRootPart")
				castServer(
					bot,
					slot,
					id,
					"Primary",
					if aRoot and aRoot:IsA("BasePart") then aRoot.Position else nil,
					ally
				)
				return
			end
		elseif id == "Recon" then
			-- Nobody seen for a while: find them.
			local known = Perception.lastKnown(bot, now)
			if not target and not known and world.roam then
				castServer(bot, slot, id, "Primary", world.roam, nil)
				return
			end
		end
	end
end

return BotMods
