--!strict
-- Login reward state (saved as PlayerData `login`) and the one rule both sides use
-- (Config/Economy.LOGIN; vault/01 Design/Shop Economy and Art v1.md). The server decides;
-- the client only draws the board from the published LoginLast / LoginStep.
--   last  the UTC day index of the last claim (0 = never)
--   step  the step claimed that day (1..#LOGIN; 0 = never)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)

export type Login = { last: number, step: number }

local LoginRewards = {}

local STEPS = #Economy.LOGIN
LoginRewards.STEPS = STEPS

function LoginRewards.new(): Login
	return { last = 0, step = 0 }
end

local function whole(n: unknown, max: number): number?
	if typeof(n) ~= "number" or n ~= n or n < 0 or n > max then
		return nil
	end
	return math.floor(n)
end

-- Any stored value to a valid Login (a bad one counts as never claimed).
function LoginRewards.clean(raw: unknown): Login
	if typeof(raw) ~= "table" then
		return LoginRewards.new()
	end
	local t = raw :: { [string]: unknown }
	local last = whole(t.last, 1e7)
	local step = whole(t.step, STEPS)
	if not last or not step then
		return LoginRewards.new()
	end
	return { last = last, step = step }
end

function LoginRewards.valid(l: Login): boolean
	return whole(l.last, 1e7) == l.last and whole(l.step, STEPS) == l.step
end

-- The step `today` would claim, or nil when today is already claimed.
function LoginRewards.nextStep(l: Login, today: number): number?
	if l.last >= today then
		return nil
	end
	if l.last == today - 1 and l.step >= 1 and l.step < STEPS then
		return l.step + 1
	end
	return 1
end

-- For the board: which step is "today" (to claim or just claimed) and whether it is
-- still waiting to be claimed. Steps before it show as claimed.
function LoginRewards.board(l: Login, today: number): (number, boolean)
	local n = LoginRewards.nextStep(l, today)
	if n then
		return n, true
	end
	return math.max(l.step, 1), false
end

return LoginRewards
