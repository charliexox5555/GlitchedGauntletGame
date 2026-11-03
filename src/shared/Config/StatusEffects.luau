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
--   stun      (optional) no shooting, no abilities, no dash: Frozen
--   turn      (optional) the view turns at most this many degrees a second
--             (the client's camera, so the body barely turns: Frozen)

export type Effect = {
	attribute: string, -- the character attribute holding the expiry (server time)
	move: number,
	jump: number,
	gravity: number,
	fireRate: number,
	reload: number,
	equip: number,
	recoil: number,
	stun: boolean?,
	turn: number?,
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
	-- Stimmed (vault/01 Design/Abilities/Stim.md → Stimmed): swap and reload
	-- times are 30% / 15% shorter.
	Stimmed = {
		attribute = "StimmedUntil",
		move = 1.15,
		jump = 1,
		gravity = 1,
		fireRate = 1.15,
		reload = 1 / 0.85,
		equip = 1 / 0.7,
		recoil = 1,
	},
	-- Strong Stim (Stim path B, vault/01 Design/Abilities/Upgrade Paths.md):
	-- +25% move and fire rate, reloads 25% and swaps 45% shorter. Replaces
	-- Stimmed (the zone gives one or the other, never both).
	StimStrong = {
		attribute = "StimStrongUntil",
		move = 1.25,
		jump = 1,
		gravity = 1,
		fireRate = 1.25,
		reload = 1 / 0.75,
		equip = 1 / 0.55,
		recoil = 1,
	},
	-- Frozen (Frost's glitch, Freeze Frame): frozen solid. No moving, jumping,
	-- shooting or abilities; you fall normally. The other fields stay 1 so
	-- no timing maths divides by zero: `stun` does the blocking.
	Frozen = {
		attribute = "FrozenUntil",
		move = 0,
		jump = 0,
		gravity = 1,
		fireRate = 1,
		reload = 1,
		equip = 1,
		recoil = 1,
		stun = true,
		turn = 25, -- a slow creak, not a flick
	},
}

return table.freeze({
	effects = effects,
	-- Shots, reloads and swaps this close to a status starting or ending may
	-- use either side's timing (the client and server see the change a ping
	-- apart).
	GRACE = 0.3,
})
