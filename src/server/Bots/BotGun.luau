--!strict
-- A bot's guns (vault/01 Design/Bots.md → "How bots plug into the game").
-- The same rules a player's guns follow on the server (WeaponService), from
-- the same data and shared code: Config/Weapons, FireRate (intervals, burst,
-- spin-up), Accuracy (spray heat, movement and ADS cone), Spread (pellets),
-- Damage (zones, falloff). Shots are real raycasts from the head; walls use
-- WeaponService's own check and hits go through its damage path. There is
-- no client claim to validate: the server is the shooter.
--
-- One GunState per bot, no allocations per shot beyond the hit list.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Accuracy = require(Shared.Util.Accuracy)
local Combat = require(Shared.Config.Combat)
local Damage = require(Shared.Util.Damage)
local FireRate = require(Shared.Util.FireRate)
local Net = require(Shared.Net)
local Spread = require(Shared.Util.Spread)
local Status = require(Shared.Mods.Status)
local Teams = require(Shared.Mods.Teams)
local Types = require(Shared.Types)
local Weapons = require(Shared.Config.Weapons)
local Health = require(Shared.Health)

local Services = script.Parent.Parent.Services
local ModEntities = require(Services.ModEntities)
local WeaponService = require(Services.WeaponService)

type Slot = Types.Slot
type WeaponConfig = Types.WeaponConfig

type SlotState = {
	id: string,
	config: WeaponConfig,
	ammo: number,
	reloadEnd: number?, -- os.clock() a reload finishes
	lastFire: number,
	spinStart: number?,
	burstShots: number,
	heat: number,
	lastShotAt: number,
	altReadyAt: number,
	sprayShots: number, -- shots in the current spray (recoil)
}

export type GunState = {
	slots: { [Slot]: SlotState },
	equipped: Slot?,
	equipReadyAt: number,
	busyUntil: number, -- a Mod use holds the gun down
	aim: number, -- ADS blend 0..1 (like WeaponController's)
	aimHeld: boolean,
	lastState: string,
	landedAt: number,
	rng: Random,
}

local BotGun = {}

local SLOTS: { Slot } = { "Primary", "Secondary", "Melee" }
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

function BotGun.new(): GunState
	return {
		slots = {},
		equipped = nil,
		equipReadyAt = 0,
		busyUntil = 0,
		aim = 0,
		aimHeld = false,
		lastState = "Idle",
		landedAt = -math.huge,
		rng = Random.new(),
	}
end

local function newSlot(id: string): SlotState?
	local config = Weapons.get(id)
	if not config then
		return nil
	end
	return {
		id = id,
		config = config,
		ammo = config.magSize,
		reloadEnd = nil,
		lastFire = -math.huge,
		spinStart = nil,
		burstShots = 0,
		heat = 0,
		lastShotAt = -math.huge,
		altReadyAt = -math.huge,
		sprayShots = 0,
	}
end

-- Fresh guns, full mags (a new life or a new draft).
function BotGun.setLoadout(gun: GunState, loadout: { [Slot]: string })
	table.clear(gun.slots)
	for _, slot in SLOTS do
		local id = loadout[slot]
		local s = if id then newSlot(id) else nil
		if s then
			gun.slots[slot] = s
		end
	end
	gun.equipped = nil
end

local function mults(character: Model): Status.Mults
	return Status.mults(character, workspace:GetServerTimeNow())
end

-- Equips `slot` (the full draw time, like a player's swap) and shows the gun.
function BotGun.equip(gun: GunState, character: Model, owner: Instance, slot: Slot)
	local target = gun.slots[slot]
	if not target or gun.equipped == slot then
		return
	end
	local current = gun.equipped and gun.slots[gun.equipped]
	if current then
		current.reloadEnd = nil -- a swap cancels the reload
	end
	gun.equipped = slot
	local config = target.config
	gun.equipReadyAt = os.clock()
		+ (config.drawTime or config.equipTime) / math.max(mults(character).equip, 0.05)
	WeaponService.attachWorldModel(character, target.id)
	-- What the simulations read off a Player (Simulation/Movement, Poses).
	owner:SetAttribute("WeaponId", target.id)
	owner:SetAttribute("MoveMult", config.moveMultiplier)
	owner:SetAttribute("AdsMult", config.adsMoveMultiplier)
end

function BotGun.current(gun: GunState): SlotState?
	return if gun.equipped then gun.slots[gun.equipped] else nil
end

function BotGun.config(gun: GunState): WeaponConfig?
	local s = BotGun.current(gun)
	return s and s.config
end

function BotGun.reloading(gun: GunState): boolean
	local s = BotGun.current(gun)
	return s ~= nil and s.reloadEnd ~= nil
end

-- Share of the magazine left (1 for guns with no magazine).
function BotGun.ammoShare(gun: GunState): number
	local s = BotGun.current(gun)
	if not s or s.config.magSize <= 0 then
		return 1
	end
	return s.ammo / s.config.magSize
end

-- Starts a reload (whole mag; shell guns load every shell, the same total
-- time the player's shell reload takes). Others see it (Poses: ReloadAt).
function BotGun.reload(gun: GunState, character: Model, owner: Instance): boolean
	local s = BotGun.current(gun)
	if not s or s.reloadEnd or s.config.magSize <= 0 or s.ammo >= s.config.magSize then
		return false
	end
	if Status.stunned(character, workspace:GetServerTimeNow()) or os.clock() < gun.busyUntil then
		return false
	end
	local config = s.config
	local slow = 1 / math.max(mults(character).reload, 0.05)
	local shell = config.shellReload
	local duration = if shell
		then (shell.start + shell.insert * (config.magSize - s.ammo) + shell.finish) * slow
		else (if s.ammo == 0 then config.emptyReloadTime else config.reloadTime) * slow
	s.reloadEnd = os.clock() + duration
	owner:SetAttribute("ReloadFor", duration)
	owner:SetAttribute("ReloadAt", workspace:GetServerTimeNow())
	return true
end

-- Per frame: finishes reloads and runs the ADS blend and landing clock (what
-- WeaponService samples for players).
function BotGun.step(gun: GunState, character: Model, dt: number)
	local now = os.clock()
	local s = BotGun.current(gun)
	if s and s.reloadEnd and now >= s.reloadEnd then
		s.reloadEnd = nil
		s.ammo = s.config.magSize
	end
	local state = (character:GetAttribute("MoveState") :: string?) or "Idle"
	if gun.lastState == "Air" and state ~= "Air" then
		gun.landedAt = now
	end
	gun.lastState = state
	local config = s and s.config
	local canAim = config ~= nil and config.fireMode ~= "Melee" and not config.noAds
	local rate = 1 / math.max(if config then config.adsTime else 0.2, 0.05)
	local held = canAim and gun.aimHeld and state ~= "Sprint"
	gun.aim = math.clamp(gun.aim + (if held then rate else -rate) * dt, 0, 1)
end

-- The cone (degrees) the next shot would have right now.
function BotGun.cone(gun: GunState, root: BasePart): number
	local s = BotGun.current(gun)
	if not s then
		return 0
	end
	local now = os.clock()
	local heat = Accuracy.cool(s.config, s.heat, now - s.lastShotAt)
	local cone = Accuracy.cone(s.config, heat, {
		state = gun.lastState,
		speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude,
		aim = gun.aim,
		sinceLanding = now - gun.landedAt,
	})
	return cone
end

-- Whether a shot would be accepted now (the same gates as WeaponService).
function BotGun.ready(gun: GunState, character: Model): boolean
	local s = BotGun.current(gun)
	if not s then
		return false
	end
	local now = os.clock()
	if now < gun.equipReadyAt or now < gun.busyUntil or s.reloadEnd then
		return false
	end
	if s.config.magSize > 0 and s.ammo < 1 then
		return false
	end
	if character:GetAttribute("Dashing") == true then
		return false
	end
	if Status.stunned(character, workspace:GetServerTimeNow()) then
		return false
	end
	local m = mults(character)
	local boost = FireRate.boost(character :: any) -- FireRateMult (Overclock); bots: none yet
	local interval = FireRate.interval(s.config, s.spinStart, s.lastFire, now, s.burstShots)
		/ (boost * m.fireRate)
	return now >= s.lastFire + interval and now >= s.altReadyAt
end

local function bodyOwner(part: Instance): Model?
	if not Combat.BODY_PARTS[part.Name] then
		return nil
	end
	local model = part.Parent
	if model and model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
		return model
	end
	return nil
end

local function combatantOf(part: Instance): Model?
	local node: Instance? = part.Parent
	while node and node ~= workspace do
		if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then
			return node
		end
		node = node.Parent
	end
	return nil
end

type Tally = { amount: number, zone: Types.HitZone, position: Vector3 }

-- One pellet: walks the ray through thin walls (when the gun can) and
-- non-hitbox parts of characters, until a body part, a Mod object or a wall.
-- Body hits go into `tally`; returns where the tracer ends.
local function tracePellet(
	shooter: Model,
	config: WeaponConfig,
	origin: Vector3,
	dir: Vector3,
	tally: { [Model]: Tally },
	objects: { [BasePart]: number }
): Vector3
	rayParams.FilterDescendantsInstances = { shooter }
	local from = origin
	local remaining = config.range
	local pierced = 0
	for _ = 1, 8 do
		local result = workspace:Raycast(from, dir * remaining, rayParams)
		if not result then
			return from + dir * remaining
		end
		local part = result.Instance
		local at = result.Position
		remaining -= (at - from).Magnitude
		if ModEntities.isObject(part) and part:IsA("BasePart") then
			objects[part] = (objects[part] or 0)
				+ Damage.compute(config, "Body", (at - origin).Magnitude)
			return at
		end
		local model = bodyOwner(part)
		if model then
			if
				not Teams.isAlly(shooter, model)
				and Health.isAlive(model:FindFirstChildOfClass("Humanoid"))
			then
				local zone = Damage.zoneOf(part.Name)
				local amount = Damage.compute(config, zone, (at - origin).Magnitude)
				local t = tally[model]
				if t then
					t.amount += amount
					if zone == "Head" then
						t.zone = "Head"
					end
				else
					tally[model] = { amount = amount, zone = zone, position = at }
				end
				pierced += 1
				if not config.pierceCharacters or pierced >= 4 then
					return at
				end
			end
			rayParams:AddToFilter(model)
		elseif
			-- A hat or held gun (not a hitbox, not a wall), or a wall this gun goes through.
			combatantOf(part)
			or config.penetration == "All"
			or (
				config.penetration == "ThinWall"
				and CollectionService:HasTag(part, Combat.THIN_WALL_TAG)
			)
		then
			rayParams:AddToFilter(part)
		else
			return at
		end
		from = at
		if remaining <= 0.5 then
			return at
		end
	end
	return from
end

-- Pulls the trigger along `aim` (a unit vector from the head). Returns
-- whether a shot went off and the recoil kick (degrees up, degrees side).
function BotGun.fire(gun: GunState, character: Model, aim: Vector3): (boolean, number, number)
	local s = BotGun.current(gun)
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")
	if
		not s
		or not head
		or not head:IsA("BasePart")
		or not root
		or not root:IsA("BasePart")
		or not BotGun.ready(gun, character)
	then
		return false, 0, 0
	end
	local config = s.config
	if config.melee then
		return false, 0, 0 -- bots don't knife yet
	end
	local now = os.clock()
	local cone = BotGun.cone(gun, root)
	local heat = Accuracy.cool(config, s.heat, now - s.lastShotAt)
	local m = mults(character)
	local interval = FireRate.interval(config, s.spinStart, s.lastFire, now, s.burstShots)
		/ (FireRate.boost(character :: any) * m.fireRate)

	-- Accept.
	if not s.spinStart or now - s.lastFire > FireRate.SPIN_RESET then
		s.spinStart = now
	end
	if now - s.lastShotAt > config.fireInterval * 2.5 then
		s.sprayShots = 0
	end
	s.sprayShots += 1
	s.burstShots = FireRate.nextBurstCount(config, s.burstShots, s.lastFire, now)
	s.lastFire = math.max(now, s.lastFire + interval)
	s.heat = heat + 1
	s.lastShotAt = now
	if config.magSize > 0 then
		s.ammo -= 1
	end

	local origin = head.Position
	local dirs = Spread.shot(
		aim.Unit,
		gun.rng:NextInteger(1, 2147483646),
		config.pellets,
		cone,
		config.pelletSpread,
		Accuracy.movement(config, {
			state = gun.lastState,
			speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude,
			aim = gun.aim,
			sinceLanding = now - gun.landedAt,
		}) <= 0
	)
	local tally: { [Model]: Tally } = {}
	local objects: { [BasePart]: number } = {}
	local ends = table.create(#dirs)
	for i, dir in dirs do
		ends[i] = tracePellet(character, config, origin, dir, tally, objects)
	end
	Net.unreliable("ShotFx"):FireAllClients(character, config.id, origin, ends)
	for model, t in tally do
		WeaponService.damageBy(character, model, t.amount, t.zone, config.id, t.position)
	end
	for part, amount in objects do
		ModEntities.damage(part, amount, nil)
	end

	-- Recoil: the gun's kick for this shot (the Aim model takes it back partly).
	local r = config.recoil
	local up = if s.sprayShots <= r.protected then r.up else r.upAfter
	local side = (gun.rng:NextNumber() * 2 - 1) * r.side
	return true, up * m.recoil, side * m.recoil
end

return BotGun
