--!strict
-- Charge + cooldown maths shared by the server (ModService), the simulation
-- (Abilities) and the HUD, so all three agree. A Mod has `max` charges per
-- round (refilled at round start: ModService.refillCharges). With a
-- `cooldown` above 0, a spent charge comes back every `cooldown` seconds
-- (`rechargeAt` is when the next one arrives; the cooldown starts on use).
-- With `cooldown` 0 a spent charge stays spent until the next refill
-- (vault/01 Design/Abilities/00 Abilities.md → Charges).

local Charges = {}

-- Whether spent charges come back during the round.
function Charges.recharges(cooldown: number): boolean
	return cooldown > 0
end

-- Charges available at `now`, and the next recharge time.
function Charges.settle(
	charges: number,
	rechargeAt: number,
	max: number,
	cooldown: number,
	now: number
): (number, number)
	if charges >= max then
		return max, rechargeAt
	end
	if cooldown <= 0 then
		return charges, rechargeAt -- per round: back only on a refill
	end
	while charges < max and now >= rechargeAt do
		charges += 1
		if charges < max then
			rechargeAt += cooldown
		end
	end
	return charges, rechargeAt
end

-- Spends one charge (call after settle, with charges >= 1).
function Charges.spend(
	charges: number,
	rechargeAt: number,
	max: number,
	cooldown: number,
	now: number
): (number, number)
	if charges >= max then
		rechargeAt = now + cooldown
	end
	return charges - 1, rechargeAt
end

-- Seconds until the next charge (0 when full, or when it never recharges).
function Charges.remaining(
	charges: number,
	rechargeAt: number,
	max: number,
	cooldown: number,
	now: number
): number
	if charges >= max or cooldown <= 0 then
		return 0
	end
	return math.max(rechargeAt - now, 0)
end

return Charges
