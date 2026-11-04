--!strict
-- Heal Orb (Sustain, Target; was Patch Up; vault/01 Design/Abilities/Heal
-- Orb.md): Sage's healing orb. Held: an orb of light forms in your palm. LMB
-- sends it to the ally in your crosshair (within `range`, in sight), RMB
-- presses it into your chest; with no ally in the crosshair, LMB heals you. An
-- ally gets `heal` over `duration`, you `selfHeal` (half), as server ticks
-- that keep going while they take damage. A new orb on someone already
-- healing replaces the rest of the old heal (no stacking). A target at full
-- health is refused (nothing spent).
--
-- Upgrades (Heal Orb.md → Upgrades): A Charges and B Long Heal are numbers
-- only. G Barrier (`behaviour = "Barrier"`) heals nothing: the target gets
-- `barrierHits` Barrier hits (a character attribute, server-written; a new
-- cast replaces the count). Each enemy damage instance (a bullet, a whole
-- shotgun blast, a fire tick, a slam) uses one up and deals nothing, before
-- the gun shield and health. It lasts until used up, death or the next round.

local Players = game:GetService("Players")

local Health = require(script.Parent.Parent.Health)
local Target = require(script.Parent.Blocks.Target)
local Teams = require(script.Parent.Teams)
local Types = require(script.Parent.Types)

local HealOrb = {}

-- Extra room the server allows on the client's target (latency, aim).
local RANGE_SLACK = 3
local ANGLE_SLACK = 8

local function full(model: Model): boolean
	local h = model:FindFirstChildOfClass("Humanoid")
	return h == nil or Health.get(h) >= Health.max(h)
end

-- Who LMB would heal right now, as the client sees it: the ally in the
-- crosshair, else yourself.
function HealOrb.primaryTarget(
	player: Player,
	origin: Vector3,
	dir: Vector3,
	stats: Types.Stats,
	params: RaycastParams
): Model?
	local allies = HealOrb.allies(player)
	if #allies == 0 then
		return player.Character
	end
	return Target.pick(origin, dir, stats.range, stats.aimAngle, allies, params) or player.Character
end

function HealOrb.allies(player: Player): { Model }
	return Target.allies(player)
end

HealOrb.full = full

-- Barrier hits left on a character (clients read it to draw the bubble).
HealOrb.BARRIER_ATTRIBUTE = "BarrierHits"

-- Whether this level gives a Barrier instead of a heal.
function HealOrb.isBarrier(stats: Types.Stats): boolean
	return stats.behaviour == "Barrier"
end

-- Who cast the Barrier on each character (the fx's owner), and the watches
-- that clear it (death, the character going). Cleared with the Barrier.
local barrierFrom: { [Model]: Player } = {}
local watches: { [Model]: { RBXScriptConnection } } = {}

local function clearBarrier(model: Model)
	if model.Parent then
		model:SetAttribute(HealOrb.BARRIER_ATTRIBUTE, nil)
	end
	barrierFrom[model] = nil
	local list = watches[model]
	watches[model] = nil
	if list then
		for _, c in list do
			c:Disconnect()
		end
	end
end

local function giveBarrier(target: Model, hits: number, caster: Player)
	target:SetAttribute(HealOrb.BARRIER_ATTRIBUTE, hits) -- replaces, never adds
	barrierFrom[target] = caster
	if watches[target] then
		return
	end
	local list = {
		target.Destroying:Once(function()
			clearBarrier(target)
		end),
	}
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if humanoid then
		table.insert(
			list,
			Health.onDowned(humanoid, function()
				clearBarrier(target)
			end) :: RBXScriptConnection
		)
	end
	watches[target] = list
end

local module: Types.ModModule = {}

module.validate = function(ctx: Types.ServerCtx, req: Types.Request): (boolean, string?)
	local stats = ctx.stats
	if req.mode == "Alt" then
		req.target = ctx.character
	else
		local allies = Target.allies(ctx.player)
		if #allies == 0 or req.target == nil or req.target == ctx.character then
			-- No ally aimed at: LMB heals you. (A named ally that fails the
			-- checks below is refused, not turned into a self-heal.)
			req.target = ctx.character
		else
			local t = req.target
			if not t or not table.find(allies, t) then
				return false, "no ally targeted"
			end
			local from = ctx.head.Position
			local point = Target.aimPoint(t)
			if not point or (point - from).Magnitude > stats.range + RANGE_SLACK then
				return false, "out of range"
			end
			-- Against the server's own camera, so the request's aim tolerance
			-- doesn't stack on top of the crosshair cone.
			if Target.angle(from, ctx.cameraLook, t) > stats.aimAngle + ANGLE_SLACK then
				return false, "not in the crosshair"
			end
			if not Target.visible(from, t, ctx.worldParams()) then
				return false, "no line of sight"
			end
		end
	end
	local target = req.target :: Model
	-- A Barrier goes on anyone; only a heal needs missing health.
	if not HealOrb.isBarrier(stats) and full(target) then
		return false, "full health"
	end
	return true
end

module.apply = function(ctx: Types.ServerCtx, req: Types.Request)
	local target = req.target :: Model
	local self = target == ctx.character
	if HealOrb.isBarrier(ctx.stats) then
		local hits = math.max(math.floor(ctx.stats.barrierHits), 1)
		giveBarrier(target, hits, ctx.player)
		ctx.fx("Barrier", { target = target, hits = hits, self = self })
		return
	end
	local amount = if self then ctx.stats.selfHeal else ctx.stats.heal
	ctx.heal(target, amount, ctx.stats.duration)
	ctx.fx("Heal", {
		target = target,
		duration = ctx.stats.duration,
		amount = amount,
		self = self,
	})
end

module.server = function(api: Types.ServerApi)
	-- One enemy damage instance per Barrier hit. Your own and your team's
	-- damage (a Molly at your feet) goes past it without using it up.
	api.guard(function(victim: Model, humanoid: Humanoid, amount: number, attacker: Player?): number
		local left = victim:GetAttribute(HealOrb.BARRIER_ATTRIBUTE)
		if typeof(left) ~= "number" or left < 1 or amount <= 0 or not Health.isAlive(humanoid) then
			return amount
		end
		if attacker and (attacker.Character == victim or Teams.isAlly(attacker, victim)) then
			return amount
		end
		left -= 1
		local caster = barrierFrom[victim]
		if left >= 1 then
			victim:SetAttribute(HealOrb.BARRIER_ATTRIBUTE, left)
		else
			clearBarrier(victim)
		end
		local owner = caster or Players:GetPlayerFromCharacter(victim)
		if owner then
			local root = victim:FindFirstChild("HumanoidRootPart")
			api.fx(owner, "HealOrb", "BarrierBlock", {
				target = victim,
				left = left,
				at = if root and root:IsA("BasePart") then root.Position else nil,
			})
		end
		return 0
	end)
	-- A new round starts clean.
	api.onRefill(function(player: Player)
		local character = player.Character
		if character then
			clearBarrier(character)
		end
	end)
end

HealOrb.module = module

return HealOrb
