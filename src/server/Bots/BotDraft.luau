--!strict
-- A bot's draft picks (vault/01 Design/Bots.md → Match integration): from
-- the same seat offers a player sees (DraftService), a gun that suits its
-- style and a card that fills an empty slot with a Mod it can use, else an
-- upgrade of one it has. Picks only what the seat was offered.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local BotDraft = {}

-- Mods bots can cast (Bots/BotMods). Firewall and Recall need Player-keyed
-- services: drafted only when nothing else is offered.
BotDraft.USABLE = table.freeze({
	Dash = true,
	Updraft = true,
	Molly = true,
	Frost = true,
	Recon = true,
	HealOrb = true,
	Stim = true,
})

-- How much a bot of this aggression likes each gun class.
local function classScore(class: string, aggression: number): number
	if class == "Shotgun" or class == "SMG" then
		return aggression
	elseif class == "Sniper" then
		return 0.9 - aggression
	elseif class == "Rifle" or class == "MachineGun" then
		return 0.7
	end
	return 0.5
end

export type SeatView = {
	guns: { string },
	abilities: { string },
	upgrades: { { key: string, id: string } },
	gun: string?,
	ability: string?,
	locked: boolean,
}

function BotDraft.pick(seat: SeatView, aggression: number, rng: Random)
	-- Gun: the best-liked class, a little random so bots differ.
	local bestGun: string? = nil
	local bestScore = -math.huge
	for _, id in seat.guns do
		local config = Weapons.get(id)
		local score = (
			if config then classScore(config.class, aggression) + config.tier * 0.1 else 0
		) + rng:NextNumber() * 0.25
		if score > bestScore then
			bestGun, bestScore = id, score
		end
	end
	seat.gun = bestGun or seat.gun

	-- Card: a new usable Mod first, then an upgrade of a usable one.
	local choice: string? = nil
	local usable: { string } = {}
	for _, id in seat.abilities do
		if BotDraft.USABLE[id] then
			table.insert(usable, id)
		end
	end
	if #usable > 0 then
		choice = usable[rng:NextInteger(1, #usable)]
	else
		local ups: { string } = {}
		for _, card in seat.upgrades do
			if BotDraft.USABLE[card.id] then
				table.insert(ups, card.key)
			end
		end
		if #ups > 0 then
			choice = ups[rng:NextInteger(1, #ups)]
		elseif #seat.abilities > 0 then
			choice = seat.abilities[rng:NextInteger(1, #seat.abilities)]
		elseif #seat.upgrades > 0 then
			choice = seat.upgrades[rng:NextInteger(1, #seat.upgrades)].key
		end
	end
	seat.ability = choice
	seat.locked = true
end

return BotDraft
