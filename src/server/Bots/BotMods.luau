--!strict
-- A bot's Mods (vault/01 Design/Bots.md → Mod rules). Phase 2 stub: the
-- kit is published on the owner like ModService publishes a player's (so
-- the shared simulation runs predicted Mods); casting rules come in phase 3.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModsConfig = require(ReplicatedStorage.Shared.Config.Mods)
local BotTypes = require(script.Parent.Types)

type Bot = BotTypes.Bot

local BotMods = {}

local function bump(owner: Instance, name: string)
	local v = owner:GetAttribute(name)
	owner:SetAttribute(name, (if typeof(v) == "number" then v else 0) + 1)
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
		end
	end
end

-- A new round: every charge back (ModService.refillCharges for players).
function BotMods.refill(bot: Bot)
	bump(bot.owner, "ModResetSerial")
end

function BotMods.onSpawn(_bot: Bot) end

function BotMods.think(_bot: Bot, _world: any, _now: number) end

return BotMods
