--!strict
-- Charge + cooldown maths shared by the server (ModService), the simulation
-- (Abilities) and the HUD, so all three agree. A Mod has `max` charges; while
-- it has fewer, one comes back every `cooldown` seconds (`rechargeAt` is when
-- the next one arrives). The cooldown starts on use (Mods.md).

local Charges = {}

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
		return max, now
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

-- Seconds until the next charge (0 when full).
function Charges.remaining(charges: number, rechargeAt: number, max: number, now: number): number
	if charges >= max then
		return 0
	end
	return math.max(rechargeAt - now, 0)
end

return Charges
