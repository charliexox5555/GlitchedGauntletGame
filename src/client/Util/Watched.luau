--!strict
-- Who you're watching in first person right now (SpectateController pushes
-- it), for modules that react to "their" events as if they were yours (the
-- kill pop and kill tone: KillFeedController, Util/KillFeed) without
-- requiring SpectateController (a require cycle).

local Players = game:GetService("Players")

local Watched = {}

local holder: Instance? = nil -- a Player, or a bot's model
local body: Model? = nil

-- nil, nil: not watching anyone.
function Watched.set(newHolder: Instance?, newBody: Model?)
	holder = newHolder
	body = newBody
end

-- The watched fighter's attribute holder (a Player or a bot model), and body.
function Watched.get(): (Instance?, Model?)
	return holder, body
end

-- Whether `x` (a Killed event's attacker or victim: a Player, a character or
-- a bot's model) is the watched fighter.
function Watched.is(x: Instance?): boolean
	if x == nil or holder == nil then
		return false
	end
	if x == holder or x == body then
		return true
	end
	return x:IsA("Model") and Players:GetPlayerFromCharacter(x) == holder
end

return Watched
