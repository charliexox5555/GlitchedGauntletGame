--!strict
-- The game's own health (vault/01 Design/Gunplay.md §3 → Health, 2026-11-04).
-- Roblox's Humanoid.Health is never touched, so nobody truly dies: at 0 HP a
-- fighter is "downed" (it looks like a death; the next round spawns them
-- fresh). The server writes these Humanoid state values (Services/HealthService);
-- everything reads them through here:
--   HP      current health (0..MaxHP)
--   MaxHP   full health
--   Downed  true from 0 HP until the character is replaced
-- The shield has a separate state field (Config/Combat SHIELD_ATTRIBUTE).

local StateValues = require(game:GetService("ReplicatedStorage").Shared.StateValues)

local Combat = require(script.Parent.Config.Combat)

local Health = {}

Health.HP = "HP"
Health.MAX = "MaxHP"
Health.DOWNED = "Downed"

-- A Humanoid, or the Humanoid of a model.
function Health.humanoid(x: Instance?): Humanoid?
	if not x then
		return nil
	end
	if x:IsA("Humanoid") then
		return x
	end
	return x:FindFirstChildOfClass("Humanoid")
end

function Health.max(x: Instance?): number
	local h = Health.humanoid(x)
	local max = h and StateValues.get(h, Health.MAX)
	return if typeof(max) == "number" and max > 0 then max else Combat.MAX_HEALTH
end

-- Current HP (a fighter not set up yet counts as full; no humanoid: 0).
function Health.get(x: Instance?): number
	local h = Health.humanoid(x)
	if not h then
		return 0
	end
	local hp = StateValues.get(h, Health.HP)
	return if typeof(hp) == "number" then hp else Health.max(h)
end

function Health.isDowned(x: Instance?): boolean
	local h = Health.humanoid(x)
	return h ~= nil and StateValues.get(h, Health.DOWNED) == true
end

-- In the fight: has a humanoid, isn't downed, has HP left.
function Health.isAlive(x: Instance?): boolean
	local h = Health.humanoid(x)
	return h ~= nil and StateValues.get(h, Health.DOWNED) ~= true and Health.get(h) > 0
end

-- Fires whenever HP changes.
function Health.changed(x: Instance?): RBXScriptSignal?
	local h = Health.humanoid(x)
	return if h then StateValues.changed(h, Health.HP) else nil
end

-- Calls `fn` once, when this fighter goes down.
function Health.onDowned(x: Instance?, fn: () -> ()): RBXScriptConnection?
	local h = Health.humanoid(x)
	if not h then
		return nil
	end
	local humanoid = h :: Humanoid
	local conn: RBXScriptConnection? = nil
	conn = StateValues.changed(humanoid, Health.DOWNED):Connect(function()
		if StateValues.get(humanoid, Health.DOWNED) == true then
			if conn then
				conn:Disconnect()
			end
			fn()
		end
	end)
	return conn
end

return Health
