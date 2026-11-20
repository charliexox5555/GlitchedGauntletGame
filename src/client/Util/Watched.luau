--!strict
-- Who you're watching in first person right now (SpectateController pushes
-- it), for modules that react to "their" events as if they were yours (the
-- kill pop and kill tone: KillFeedController, Util/KillFeed) without
-- requiring SpectateController (a require cycle).

local Players = game:GetService("Players")

local Watched = {}

local holder: Instance? = nil -- a Player, or a bot's model
local body: Model? = nil

-- Their Mod row as the server last sent it (SpectateFeed "Mods"): per slot
-- id, level, charges and when the next charge is back (server time; nil for
-- predicted Mods). ModHudController draws it in place of yours.
export type ModRow = { id: string?, level: string, charges: number, rechargeAt: number? }
local rows: { [number]: ModRow } = {}

-- nil, nil: not watching anyone.
function Watched.set(newHolder: Instance?, newBody: Model?)
	if newHolder ~= holder then
		table.clear(rows)
	end
	holder = newHolder
	body = newBody
end

function Watched.setModRows(list: { [number]: ModRow })
	table.clear(rows)
	for slot, row in list do
		rows[slot] = row
	end
end

function Watched.modRow(slot: number): ModRow?
	return rows[slot]
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
