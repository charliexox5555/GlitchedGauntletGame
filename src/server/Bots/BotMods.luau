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
-- Recall still uses the Player-keyed anchor and teleport service.
--
-- Each ready Mod scores its opportunity. Held Mods lower the gun, then
-- recheck the intended throw from the bot's actual release position.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BotsConfig = require(Shared.Config.Bots)
local StatusEffects = require(Shared.Config.StatusEffects)
local Charges = require(Shared.Mods.Charges)
local Health = require(Shared.Health)
local Mods = require(Shared.Mods)
local ModsConfig = require(Shared.Config.Mods)
local Net = require(Shared.Net)
local Projectile = require(Shared.Mods.Blocks.Projectile)
local Recon = require(Shared.Mods.Recon)
local Teams = require(Shared.Mods.Teams)
-- The throwables' own flight (throw / options), for aiming.
local THROWS: { [string]: any } = {
	Molly = require(Shared.Mods.Molly),
	Frost = require(Shared.Mods.Frost),
	Flash = require(Shared.Mods.Flash),
}
local Target = require(Shared.Mods.Blocks.Target)

local Services = script.Parent.Parent.Services
local ModEntities = require(Services.ModEntities)
local ModWalls = require(Services.ModWalls)
local StatusService = require(Services.StatusService)
local WeaponService = require(Services.WeaponService)

local BotGun = require(script.Parent.BotGun)
local BotTypes = require(script.Parent.Types)
local Perception = require(script.Parent.Perception)
local Nav = require(script.Parent.Nav)
local STUDIO = game:GetService("RunService"):IsStudio()

type Bot = BotTypes.Bot

local BotMods = {}

local SERVER_MODS: { [string]: boolean } = {
	Molly = true,
	Frost = true,
	Firewall = true,
	Recon = true,
	HealOrb = true,
	Stim = true,
	ShockDart = true,
	Flash = true,
	Roller = true,
}
local USE_KINDS: { [string]: string } = {
	HeldThrow = "Throw",
	HeldPlace = "Place",
	HeldTarget = "Heal",
	HeldSteer = "Cast",
	HeldCharge = "Heal",
}
local THROW_PITCHES = { -6, 4, 14, 24, 36 } -- degrees tried when aiming a throw

local rng = Random.new()
-- Threads a bot's Mods scheduled (fuses, ticks): cancelled when it despawns.
local threads: { [Bot]: { thread } } = setmetatable({}, { __mode = "k" }) :: any

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function bump(owner: Instance, name: string)
	local v = StateValues.get(owner, name)
	StateValues.set(owner, name, (if typeof(v) == "number" then v else 0) + 1)
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
		StateValues.set(bot.owner, p .. "Id", if id ~= "" then id else nil)
		StateValues.set(bot.owner, p .. "Level", if id ~= "" then level else nil)
		if changed then
			bump(bot.owner, p .. "Serial")
			bot.modRetryAt[slot] = 0
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
		bot.modRetryAt[slot] = 0
		bot.modReadyAt[slot] = serverNow()
	end
	bump(bot.owner, "ModResetSerial")
end

function BotMods.onSpawn(bot: Bot)
	bot.nextModTry = os.clock() + 1
	StateValues.set(bot.owner, "ModHeld", 0)
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
		ModWalls.clear(model)
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
		fireRate = function(mult: number, duration: number)
			StateValues.set(model, "FireRateMult", mult)
			local untilTime = serverNow() + duration
			StateValues.set(model, "FireRateUntil", untilTime)
			hold(
				bot,
				list,
				task.delay(duration, function()
					if alive() and StateValues.get(model, "FireRateUntil") == untilTime then
						StateValues.set(model, "FireRateMult", nil)
						StateValues.set(model, "FireRateUntil", nil)
					end
				end)
			)
		end,
		active = function(_duration: number) end, -- a HUD bar: bots have none
		objectsNear = function(at: Vector3, radius: number): { BasePart }
			return ModEntities.objectsNear(at, radius)
		end,
		damageObject = function(part: BasePart, amount: number)
			ModEntities.damage(part, amount, nil)
		end,
		anchorDown = false,
		remove = function(part: BasePart, why: string)
			ModEntities.remove(part, why)
		end,
		blind = function(target: Model, duration: number, strength: number, from: Vector3?)
			StatusService.blind(target, duration, strength, from)
		end,
		lookOf = Target.lookOf,
		wall = function(spec: any)
			local root = bot.root
			if not root or not alive() then
				return
			end
			StateValues.set(bot.owner, "ModHeld", slot)
			bot.gun.busyUntil = os.clock() + stats.maxLength / stats.speed + ModsConfig.USE_TIME
			ModWalls.build(model, root, stats, spec, {
				damage = damage,
				status = StatusService.apply,
				look = function()
					return nil
				end,
				built = function()
					if alive() then
						StateValues.set(bot.owner, "ModHeld", 0)
					end
				end,
			})
		end,
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

-- Check where the actual projectile ends before spending a charge. A throw
-- that bounces back onto the caster or hits the near face is a bad cast.
local function aimProjectile(
	bot: Bot,
	id: string,
	eye: Vector3,
	stats: any,
	mode: string,
	point: Vector3
): Vector3?
	local flat = (point - eye) * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.1 then
		return nil
	end
	local forward = flat.Unit
	local params = worldParams()
	local best: Vector3? = nil
	local bestMiss = if id == "Flash" then 14 else (stats.radius or 8) * 0.9
	local mod = THROWS[id]
	local options = if mod then mod.options(stats, mode == "Alt") else Recon.options(stats, 0)
	for _, pitch in THROW_PITCHES do
		local r = math.rad(pitch) + (if mod then 0 else math.atan2(point.Y - eye.Y, flat.Magnitude))
		local dir = forward * math.cos(r) + Vector3.new(0, math.sin(r), 0)
		local origin, velocity
		if mod then
			origin, velocity = mod.throw(eye, dir, mode, stats, params)
		else
			origin, velocity = Recon.launch(eye, dir, 1, stats, params)
		end
		local path = Projectile.simulate(origin, velocity, options, params)
		local landing = Projectile.positionAt(path, Projectile.endTime(path))
		local miss = (landing - point).Magnitude
		local clear = id == "Recon" and stats.behaviour == "Spike"
			or Nav.clearLine(bot, landing, point)
		if miss < bestMiss and (landing - eye).Magnitude > 6 and clear then
			best, bestMiss = dir, miss
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
	local holdFor = if def.activation == "HeldCharge"
		then stats.chargeTime or 0.5
		elseif held then 0.25 + rng:NextNumber() * 0.25
		else 0
	local life = bot.life
	bot.gun.busyUntil = os.clock() + holdFor + ModsConfig.USE_TIME
	if held then
		StateValues.set(bot.owner, "ModHeld", slot)
	end
	task.delay(holdFor, function()
		if bot.life ~= life then
			return
		end
		StateValues.set(bot.owner, "ModHeld", 0)
		if
			not bot.fighting
			or not Health.isAlive(bot.humanoid)
			or not bot.head
			or bot.goal == "Rotate"
		then
			return
		end
		local eye = bot.head.Position
		local look = bot.root and bot.root.CFrame.LookVector or Vector3.new(0, 0, -1)
		local offset = if aimAt then aimAt - eye else look
		local dir = if offset.Magnitude > 0.1 then offset.Unit else look
		if aimAt and (THROWS[id] or id == "ShockDart" or id == "Recon") then
			local point = if id == "Flash" or id == "Recon"
				then aimAt
				else aimAt - Vector3.yAxis * 1.5
			local planned = aimProjectile(bot, id, eye, stats, mode, point)
			if not planned then
				bot.gun.busyUntil = os.clock()
				bot.modRetryAt[slot] = os.clock() + BotsConfig.MOD_RETRY
				return
			end
			dir = planned
		elseif aimAt and id == "Roller" then
			-- Set it down a few steps ahead, toward them.
			local flat = (aimAt - eye) * Vector3.new(1, 0, 1)
			local forward = if flat.Magnitude > 0.1 then flat.Unit else look
			dir = forward * math.cos(math.rad(35)) - Vector3.new(0, math.sin(math.rad(35)), 0)
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
				bot.gun.busyUntil = os.clock()
				bot.modRetryAt[slot] = os.clock() + BotsConfig.MOD_RETRY
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
			if c < 1 then
				return
			end
			bot.modCharges[slot], bot.modReadyAt[slot] =
				Charges.spend(c, r, stats.charges, stats.cooldown, serverNow())
		end
		local kind = if def.activation == "HeldThrow" and mode == "Alt"
			then "Lob"
			else def.useKind or USE_KINDS[def.activation]
		if kind then
			StateValues.set(bot.owner, "ModUseKind", kind)
			StateValues.set(bot.owner, "ModUseAt", workspace:GetServerTimeNow())
		end
		local ok, err = pcall(module.apply :: any, ctx, req)
		if not ok then
			warn("[BotMods]", id, "failed for", bot.name, err)
		elseif STUDIO then
			StateValues.set(bot.owner, "BotLastMod", id)
			StateValues.set(
				bot.owner,
				"BotModCasts",
				(StateValues.get(bot.owner, "BotModCasts") :: number? or 0) + 1
			)
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
	local charges = StateValues.get(model, "Mod" .. slot .. "Charges")
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
		local charges = bot.model and StateValues.get(bot.model, "Mod" .. slot .. "Charges")
		return (id == "Dash" or id == "Updraft") and (typeof(charges) ~= "number" or charges >= 1)
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

type Opportunity = {
	score: number,
	mode: string?,
	point: Vector3?,
	ally: Model?,
}

-- Evaluate the whole kit. Difficulty changes how often and how selectively
-- a bot commits. Every profile uses the same charge and validation rules.
function BotMods.think(bot: Bot, world: any, now: number)
	local root, humanoid, head, model = bot.root, bot.humanoid, bot.head, bot.model
	if
		not bot.fighting
		or not root
		or not humanoid
		or not head
		or not model
		or now < bot.nextModTry
	then
		return
	end
	local profile = bot.profile.mods
	bot.nextModTry = now + profile.interval * rng:NextNumber(0.85, 1.15)
	local blinded = StateValues.get(model, StatusEffects.blinded.attribute)
	if
		now < bot.gun.busyUntil
		or BotGun.reloading(bot.gun)
		or (typeof(blinded) == "number" and blinded > serverNow())
		or rng:NextNumber() > profile.abilityUse
	then
		return
	end

	local share = Health.get(humanoid) / math.max(Health.max(humanoid), 1)
	local target = bot.target
	local engaged = target ~= nil and Perception.engageable(bot, target, now)
	local known = Perception.lastKnown(bot, now)
	if known and now - known.seenAt > BotsConfig.HUNT_MEMORY then
		known = nil
	end
	local seen = if engaged and target then target.lastPos else nil
	local point = seen or (known and known.lastPos)
	local distance = if point then (point - root.Position).Magnitude else math.huge
	local incoming = now - bot.lastHurtAt < 0.7
	local rotating = bot.goal == "Rotate"
	local cover = bot.goal == "Cover"
	local weapons = BotGun.config(bot.gun)
	local closeGun = weapons and (weapons.class == "Shotgun" or weapons.class == "SMG")
	local dir = humanoid.MoveDirection
	local best: Opportunity? = nil
	local bestSlot, bestId = 0, ""

	for slot = 1, ModsConfig.SLOTS do
		local id = bot.kit[slot]
		if id == "" or now < bot.modRetryAt[slot] or not ready(bot, slot, id) then
			continue
		end
		local _, stats = statsFor(bot, slot)
		local option: Opportunity? = nil
		if id == "Dash" and stats then
			local reach = stats.distance
			if
				(
					rotating
					or (seen and closeGun and distance > 12 and distance < 35)
					or (incoming and share < 0.4 and (bot.goal == "Retreat" or cover))
				)
				and Nav.canMove(bot, dir, reach)
				and Nav.zoneAllows(bot, root.Position + dir * reach, stats.duration)
			then
				option = { score = if rotating then 1 else 0.83 }
			end
		elseif id == "Updraft" and not rotating and not cover then
			local height = if stats then math.min(stats.peak or 7, 14) else 7
			local escape = incoming and share < 0.44
			local elevated = seen
				and bot.goal == "Engage"
				and distance < 38
				and seen.Y - root.Position.Y > 3
				and seen.Y - root.Position.Y <= height
			if
				(escape or elevated)
				and humanoid.FloorMaterial ~= Enum.Material.Air
				and Nav.clearLine(bot, head.Position, head.Position + Vector3.yAxis * height)
				and Nav.zoneAllows(bot, root.Position + dir * 8, 0.45)
			then
				option = { score = if escape then 0.76 + (0.44 - share) * 0.3 else 0.76 }
			end
		elseif rotating then
			continue
		elseif id == "Molly" and point and distance > 9 and distance < 47 then
			option = { score = if seen then 0.57 else 0.82, point = point }
		elseif id == "Frost" and point and distance > 9 and distance < 40 then
			option =
				{ score = if seen and (closeGun or incoming) then 0.81 else 0.66, point = point }
		elseif
			id == "Firewall"
			and point
			and stats
			and distance > 10
			and distance < stats.maxLength
			and (incoming or bot.goal == "Hunt")
		then
			option = { score = 0.8, mode = "Alt", point = point }
		elseif id == "Stim" and (not engaged or cover) and share < 0.62 then
			option = { score = 0.77 + (0.62 - share) * 0.3 }
		elseif id == "HealOrb" then
			if share < 0.62 and not incoming and (not engaged or cover) then
				option = { score = 0.86 + (0.62 - share) * 0.2, mode = "Alt" }
			else
				local ally = hurtAlly(bot, world.allies, 40, 0.55)
				local part = ally and ally:FindFirstChild("HumanoidRootPart")
				if
					part
					and part:IsA("BasePart")
					and Nav.clearLine(bot, head.Position, part.Position)
				then
					option = { score = 0.85, point = part.Position, ally = ally }
				end
			end
		elseif id == "ShockDart" and seen and distance > 13 and distance < 55 then
			option = { score = 0.73, point = seen }
		elseif id == "Flash" and point and distance > 12 and distance < 34 then
			option = { score = if seen then 0.62 else 0.88, point = point }
		elseif id == "Roller" and point and distance > 10 and distance < 38 then
			option = { score = if seen then 0.69 else 0.78, point = point }
		elseif id == "Recon" and not engaged then
			local search = point or bot.nav.goal or world.roam
			if search and (search - root.Position).Magnitude > 10 then
				option = { score = if point then 0.85 else 0.65, point = search }
			end
		end
		if option then
			option.score += rng:NextNumber(-0.045, 0.045)
			if option.score >= profile.minScore and (not best or option.score > best.score) then
				best, bestSlot, bestId = option, slot, id
			end
		end
	end
	if not best then
		return
	end
	if SERVER_MODS[bestId] then
		castServer(bot, bestSlot, bestId, best.mode or "Primary", best.point, best.ally)
	else
		pressPredicted(bot, bestSlot)
	end
end

return BotMods
