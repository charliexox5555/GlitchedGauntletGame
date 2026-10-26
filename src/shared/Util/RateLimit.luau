--!strict
-- Per-player token buckets for remote handlers (roblox-security). One limiter
-- per service, built from a rate table { [key] = { perSecond, burst } }
-- (Config/Combat RATE, Config/Mods RATE). Server only in practice.
--
--   local limiter = RateLimit.new(Combat.RATE)
--   if not limiter:allow(player, "Fire") then return end
--   Players.PlayerRemoving:Connect(function(p) limiter:forget(p) end)

export type Rates = { [string]: { number } }

type Bucket = { tokens: number, last: number }

export type Limiter = {
	rates: Rates,
	buckets: { [Player]: { [string]: Bucket } },
	allow: (self: Limiter, player: Player, key: string) -> boolean,
	forget: (self: Limiter, player: Player) -> (),
}

local RateLimit = {}

local function allow(self: Limiter, player: Player, key: string): boolean
	local rate = self.rates[key]
	assert(rate, "no rate for " .. key)
	local perSecond, burst = rate[1], rate[2]
	local now = os.clock()
	local pb = self.buckets[player]
	if not pb then
		pb = {}
		self.buckets[player] = pb
	end
	local b = pb[key]
	if not b then
		b = { tokens = burst, last = now }
		pb[key] = b
	end
	b.tokens = math.min(burst, b.tokens + (now - b.last) * perSecond)
	b.last = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

local function forget(self: Limiter, player: Player)
	self.buckets[player] = nil
end

function RateLimit.new(rates: Rates): Limiter
	return {
		rates = rates,
		buckets = {},
		allow = allow,
		forget = forget,
	}
end

return RateLimit
