--!strict
-- Per-hit validation and lag compensation for a shot WeaponService has
-- already accepted (its weapon state, counter, origin and spread checked):
-- each claimed hit must be a real, live, tracked enemy hitbox (or a Mod
-- object), in range, on its pellet's server-computed ray (or in melee reach
-- and in front), on the target's rewound hitbox, with no wall in between.
-- Then the damage: summed per target, computed on the server from
-- Config/Weapons, never from the client. A plain module: no init/start.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared.Config.Combat)
local DamageMath = require(Shared.Util.Damage)
local Net = require(Shared.Net)
local Spread = require(Shared.Util.Spread)
local Teams = require(Shared.Mods.Teams)
local Types = require(Shared.Types)
local Validate = require(Shared.Util.Validate)

local HitboxHistory = require(script.Parent.Parent.HitboxHistory)
local ModEntities = require(script.Parent.Parent.ModEntities)
local Damage = require(script.Parent.Damage)
local Targets = require(script.Parent.Targets)

type WeaponConfig = Types.WeaponConfig
type HitZone = Types.HitZone

export type ValidHit = { model: Model, part: BasePart, rewound: Vector3, pellet: number }
export type ObjectHit = { part: BasePart, position: Vector3 }

local finiteVector = Validate.vector

local Hits = {}

-- Reads an array argument safely (ignores non-integer keys, caps length).
function Hits.readArray(value: unknown, max: number): { unknown }
	local out = {}
	if typeof(value) ~= "table" then
		return out
	end
	for _, v in ipairs(value :: { unknown }) do
		if #out >= max then
			break
		end
		table.insert(out, v)
	end
	return out
end

function Hits.networkPing(player: Player): number
	local ok, ping = pcall(function()
		return player:GetNetworkPing()
	end)
	return if ok and typeof(ping) == "number" and ping == ping then math.clamp(ping, 0, 1) else 0.1
end

-- How far back a hit may be rewound for this shooter (seconds).
function Hits.rewindWindow(player: Player): number
	local ok, ping = pcall(function()
		return player:GetNetworkPing()
	end)
	local p = if ok and typeof(ping) == "number" then ping else 0.1
	return math.min(p * 2 + Combat.REWIND_EXTRA, Combat.REWIND_MAX)
end

-- Studio-only: record why the last shot or hit was rejected (player attribute
-- "FireReject"), so tuning tolerances doesn't need print debugging.
function Hits.reject(player: Player, reason: string)
	if RunService:IsStudio() then
		player:SetAttribute("FireReject", string.sub(reason, 1, 50)) -- attribute strings cap at 50 chars
	end
end

local reject = Hits.reject

-- Checks the hits a shot claims (`rawHits`, straight from the client).
-- `dirs`: each pellet's server-computed ray; `exclude`: the wall check's
-- exclusions (Targets.wallExclusions); `rewindAge`: Hits.rewindWindow.
-- Returns the character hits and the Mod object hits that passed.
function Hits.validate(
	player: Player,
	character: Model,
	root: Instance?,
	config: WeaponConfig,
	origin: Vector3,
	dirs: { Vector3 },
	pellets: number,
	exclude: { Instance },
	rewindAge: number,
	rawHits: unknown
): ({ ValidHit }, { ObjectHit })
	local maxHits =
		math.min(Combat.MAX_HITS_PER_SHOT, pellets * (if config.pierceCharacters then 4 else 1))
	local valid: { ValidHit } = {}
	local objectHits: { ObjectHit } = {}
	local seen: { [Model]: { [number]: boolean } } = {}
	local pelletUsed: { [number]: boolean } = {}
	for _, raw in Hits.readArray(rawHits, maxHits) do
		if typeof(raw) ~= "table" then
			reject(player, "typeof(raw) ~= 'table'")
			continue
		end
		local h = raw :: { [string]: unknown }
		local part = h.part
		local position = finiteVector(h.position)
		local pellet = h.pellet
		if typeof(part) ~= "Instance" or not (part :: Instance):IsA("BasePart") or not position then
			reject(
				player,
				"typeof(part) ~= 'Instance' or not (part :: Instance):IsA('BasePart') or not position"
			)
			continue
		end
		if
			typeof(pellet) ~= "number"
			or pellet ~= math.floor(pellet)
			or pellet < 1
			or pellet > pellets
		then
			reject(player, "bad pellet index")
			continue
		end
		local hitPart = part :: BasePart
		-- A Mod object (Firewall, Launch Pad): the pellet stops on it and
		-- takes its HP. Same ray, range and wall checks as a body hit.
		if ModEntities.isObject(hitPart) then
			local offset = position - origin
			local rel = hitPart.CFrame:PointToObjectSpace(position)
			-- Objects don't move: a tight box (not the bodies' latency allowance).
			local half = hitPart.Size / 2 + Vector3.one * Combat.OBJECT_HIT_TOLERANCE
			if
				config.melee
				or pelletUsed[pellet]
				or offset.Magnitude > config.range + 5
				or (offset.Magnitude > 1 and Spread.angle(offset, dirs[pellet]) > Combat.DIRECTION_TOLERANCE)
				or math.abs(rel.X) > half.X
				or math.abs(rel.Y) > half.Y
				or math.abs(rel.Z) > half.Z
				or Targets.blocked(exclude, origin, position, config.penetration)
			then
				reject(player, "bad Mod object hit")
			else
				pelletUsed[pellet] = true
				table.insert(objectHits, { part = hitPart, position = position })
			end
			continue
		end
		local model = Targets.hitboxOwner(hitPart)
		if
			not model
			or model == character
			or not Targets.liveHumanoid(model)
			or not HitboxHistory.isTracked(model)
		then
			reject(player, "not a live tracked hitbox: " .. hitPart.Name)
			continue
		end
		-- No friendly fire from guns. Dummies with no team are nobody's ally.
		if Teams.isAlly(player, model) then
			reject(player, "ally")
			continue
		end

		-- One target per pellet (piercing guns: each target once per pellet).
		local seenForModel = seen[model]
		if
			(seenForModel and seenForModel[pellet])
			or (pelletUsed[pellet] and not config.pierceCharacters)
		then
			reject(player, "duplicate hit for this pellet")
			continue
		end

		if config.melee then
			-- In reach and roughly in front of the attacker.
			if not root or not root:IsA("BasePart") then
				reject(player, "not root or not root:IsA('BasePart')")
				continue
			end
			local toTarget = hitPart.Position - root.Position
			local reach = config.melee.range + Combat.MELEE_TOLERANCE + hitPart.Size.Magnitude / 2
			if toTarget.Magnitude > reach then
				reject(player, "toTarget.Magnitude > reach")
				continue
			end
			local flat = toTarget * Vector3.new(1, 0, 1)
			local facing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			if flat.Magnitude > 0.5 and facing.Unit:Dot(flat.Unit) < Combat.MELEE_FACING_DOT then
				reject(
					player,
					"flat.Magnitude > 0.5 and facing.Unit:Dot(flat.Unit) < Combat.MELEE_FACING_DOT"
				)
				continue
			end
		else
			local offset = position - origin
			if offset.Magnitude > config.range + 5 then
				reject(player, "offset.Magnitude > config.range + 5")
				continue
			end
			-- The hit must lie on this pellet's server-computed ray.
			if
				offset.Magnitude > 1
				and Spread.angle(offset, dirs[pellet]) > Combat.DIRECTION_TOLERANCE
			then
				reject(
					player,
					string.format("off pellet ray by %.2f deg", Spread.angle(offset, dirs[pellet]))
				)
				continue
			end
		end

		-- The target really was there recently (rewound to the shooter's ping)...
		local isArm = string.find(hitPart.Name, "Arm") ~= nil
			or string.find(hitPart.Name, "Hand") ~= nil
		local tolerance = Combat.HIT_POSITION_TOLERANCE
			+ (if isArm then Combat.ARM_HIT_EXTRA_TOLERANCE else 0)
		local rewound = HitboxHistory.rewind(model, hitPart, position, tolerance, rewindAge)
		if not rewound then
			reject(player, "not rewound")
			continue
		end
		-- ...and nothing solid sits between the shooter and the hit point, or
		-- between the hit point and the actual body part.
		if Targets.blocked(exclude, origin, position, config.penetration) then
			reject(player, "blocked(exclude, origin, position, config.penetration)")
			continue
		end
		if Targets.blocked(exclude, position, rewound, config.penetration) then
			reject(player, "blocked(exclude, position, rewound, config.penetration)")
			continue
		end
		if not seenForModel then
			seenForModel = {}
			seen[model] = seenForModel
		end
		seenForModel[pellet] = true
		pelletUsed[pellet] = true
		table.insert(valid, { model = model, part = hitPart, rewound = rewound, pellet = pellet })
	end
	return valid, objectHits
end

-- Deals a validated shot's damage. Sums damage per target (pellets), then
-- applies it once; distance for falloff is measured by the server: head to
-- the rewound body part (Mod objects: to the hit point). `altFire`: the
-- shot was an alt-fire (a melee heavy). Returns whether a character was hit.
function Hits.apply(
	player: Player,
	config: WeaponConfig,
	altFire: Types.AltFire?,
	head: BasePart,
	root: Instance?,
	valid: { ValidHit },
	objectHits: { ObjectHit }
): boolean
	type Tally = { amount: number, zone: HitZone, position: Vector3 }
	local tally: { [Model]: Tally } = {}
	for _, hit in valid do
		local zone = DamageMath.zoneOf(hit.part.Name)
		local amount: number
		if config.melee then
			local heavy = if altFire then config.melee.heavy else nil
			amount = if heavy then heavy.damage else config.damage.body
			local victimRoot = hit.model:FindFirstChild("HumanoidRootPart")
			if victimRoot and victimRoot:IsA("BasePart") and root and root:IsA("BasePart") then
				local toVictim = (victimRoot.Position - root.Position) * Vector3.new(1, 0, 1)
				if toVictim.Magnitude > 0.01 then
					local facing = victimRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
					if facing.Unit:Dot(toVictim.Unit) > Combat.BACKSTAB_DOT then
						amount = if heavy then heavy.backDamage else config.melee.backDamage
					end
				end
			end
			zone = "Body"
		else
			amount = DamageMath.compute(config, zone, (hit.rewound - head.Position).Magnitude)
		end
		local t = tally[hit.model]
		if t then
			t.amount += amount
			if zone == "Head" then
				t.zone = "Head"
			end
		else
			tally[hit.model] = { amount = amount, zone = zone, position = hit.rewound }
		end
	end
	for model, t in tally do
		Damage.apply(player, model, t.amount, t.zone, config.id, t.position)
	end
	-- Mod objects: pellets summed per object, falloff by the server's distance.
	local objectTally: { [BasePart]: { amount: number, position: Vector3 } } = {}
	for _, hit in objectHits do
		local amount = DamageMath.compute(config, "Body", (hit.position - head.Position).Magnitude)
		local t = objectTally[hit.part]
		if t then
			t.amount += amount
		else
			objectTally[hit.part] = { amount = amount, position = hit.position }
		end
	end
	for part, t in objectTally do
		local dealt = ModEntities.damage(part, t.amount, player)
		if dealt > 0 then
			Net.event("HitConfirm"):FireClient(player, {
				damage = math.round(dealt),
				zone = "Body",
				killed = false,
				position = t.position,
			})
		end
	end
	return next(tally) ~= nil
end

return Hits
