--!strict
-- Minimal teams until MatchService exists: a "TeamId" number attribute on
-- each Player (ModService assigns it) and on dummies (DevModService). Used
-- everywhere a Mod asks "friend or foe" (damage, heals, reveal, colours).
-- Anything without a TeamId (test range dummies) is nobody's ally.

local Players = game:GetService("Players")

local Teams = {}

Teams.ATTRIBUTE = "TeamId"

-- The team of a Player, a character or a dummy model (nil: no team).
function Teams.of(x: Instance?): number?
	if not x then
		return nil
	end
	if x:IsA("Player") then
		local t = x:GetAttribute(Teams.ATTRIBUTE)
		return if typeof(t) == "number" then t else nil
	end
	if x:IsA("Model") then
		local owner = Players:GetPlayerFromCharacter(x)
		if owner then
			return Teams.of(owner)
		end
		local t = x:GetAttribute(Teams.ATTRIBUTE)
		return if typeof(t) == "number" then t else nil
	end
	return nil
end

-- Same team (both must have one). Something is always its own ally.
function Teams.isAlly(a: Instance?, b: Instance?): boolean
	if a == nil or b == nil then
		return false
	end
	if a == b then
		return true
	end
	local ta, tb = Teams.of(a), Teams.of(b)
	return ta ~= nil and ta == tb
end

return Teams
