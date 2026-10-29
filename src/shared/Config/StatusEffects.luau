--!strict
-- Shared status effects (vault/01 Design/Abilities/00 Abilities.md → Status
-- effects): server-enforced, an expiry time on the character, reusable by any
-- Mod. Each is a set of multipliers on the base rates (1 = no change; a
-- "rate" above 1 is faster, so a slower reload is below 1). Several at once
-- multiply (Mods/Status.mults).
--
--   move      walk / sprint / air speed
--   jump      jump height
--   gravity   how fast you fall (below 1: a floaty, slow-motion jump)
--   fireRate  shots per second
--   reload    reload speed (0.7: a reload takes 1 / 0.7 as long)
--   equip     equip / swap speed
--   recoil    recoil recovery speed

export type Effect = {
	attribute: string, -- the character attribute holding the expiry (server time)
	move: number,
	jump: number,
	gravity: number,
	fireRate: number,
	reload: number,
	equip: number,
	recoil: number,
}

local effects: { [string]: Effect } = {
	-- Hinder (vault/01 Design/Abilities/Frost.md → Hinder).
	Hinder = {
		attribute = "HinderedUntil",
		move = 0.65,
		jump = 0.6,
		gravity = 0.6,
		fireRate = 0.75,
		reload = 0.7,
		equip = 0.7,
		recoil = 0.7,
	},
}

return table.freeze({
	effects = effects,
	-- Shots, reloads and swaps this close to a status starting or ending may
	-- use either side's timing (the client and server see the change a ping
	-- apart).
	GRACE = 0.3,
})
