--!strict
-- Writes the game's own health (shared/Health): HP, MaxHP and Downed on each
-- fighter's Humanoid. Roblox's Humanoid.Health stays full and the Dead state
-- is off, so nobody truly dies; at 0 HP the fighter is downed (clients show
-- the death look, Controllers/DeathFxController) until their character is
-- replaced. Only this module writes these attributes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Health = require(ReplicatedStorage.Shared.Health)

local HealthService = {}

local downedHandlers: { (humanoid: Humanoid) -> () } = {}

-- A new fighter: full HP, not downed, and a Humanoid that can't die.
function HealthService.prepare(humanoid: Humanoid, max: number?)
	local full = max or Combat.MAX_HEALTH
	humanoid.MaxHealth = full
	humanoid.Health = full
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid:SetAttribute(Health.MAX, full)
	humanoid:SetAttribute(Health.HP, full)
	humanoid:SetAttribute(Health.DOWNED, false)
end

-- Runs `fn` for every fighter that goes down (after the attribute is set).
function HealthService.onDowned(fn: (humanoid: Humanoid) -> ())
	table.insert(downedHandlers, fn)
end

-- Down a fighter now (0 HP, or falling off the map).
function HealthService.down(humanoid: Humanoid)
	if humanoid:GetAttribute(Health.DOWNED) == true then
		return
	end
	humanoid:SetAttribute(Health.HP, 0)
	humanoid:SetAttribute(Health.DOWNED, true)
	humanoid.WalkSpeed = 0
	humanoid.JumpHeight = 0
	-- The body stays (clients hide it and show the death look) but no longer
	-- blocks shots or people: the root is anchored where it fell, so nothing
	-- needs to collide (a colliding part ignores CanQuery, so it would still
	-- block raycasts and players).
	local body = humanoid.Parent
	if body then
		for _, part in body:GetDescendants() do
			if part:IsA("BasePart") then
				if part.Name == "HumanoidRootPart" then
					part.Anchored = true
				end
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
			end
		end
	end
	for _, fn in downedHandlers do
		task.spawn(fn, humanoid)
	end
end

-- Sets HP (clamped to 0..MaxHP); 0 downs the fighter.
function HealthService.set(humanoid: Humanoid, hp: number)
	if hp ~= hp or humanoid:GetAttribute(Health.DOWNED) == true then
		return
	end
	local value = math.clamp(hp, 0, Health.max(humanoid))
	humanoid:SetAttribute(Health.HP, value)
	if value <= 0 then
		HealthService.down(humanoid)
	end
end

-- Takes up to `amount` HP. Returns what it took.
function HealthService.damage(humanoid: Humanoid, amount: number): number
	if amount ~= amount or amount <= 0 or not Health.isAlive(humanoid) then
		return 0
	end
	local before = Health.get(humanoid)
	HealthService.set(humanoid, before - amount)
	return before - Health.get(humanoid)
end

-- Adds up to `amount` HP (never past MaxHP). Returns what it added.
function HealthService.heal(humanoid: Humanoid, amount: number): number
	if amount ~= amount or amount <= 0 or not Health.isAlive(humanoid) then
		return 0
	end
	local before = Health.get(humanoid)
	HealthService.set(humanoid, before + amount)
	return Health.get(humanoid) - before
end

return HealthService
