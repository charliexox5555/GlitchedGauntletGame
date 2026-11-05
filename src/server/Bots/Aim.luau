--!strict
-- A human-ish aim (vault/01 Design/Bots.md → Brain): a critically damped
-- spring on yaw and pitch toward the aim point (a hand's lag), plus an aim
-- error that starts large on a new target and settles toward the profile's
-- floor while tracking (re-inflated when the target cuts the other way),
-- plus recoil that is only partly pulled back. The bot doesn't know its own
-- error: it fires when its *intended* aim is on target.

local BotTypes = require(script.Parent.Types)

type Bot = BotTypes.Bot

local Aim = {}

local Perception = require(script.Parent.Perception)
local BotsConfig = require(game:GetService("ReplicatedStorage").Shared.Config.Bots)
local Health = require(game:GetService("ReplicatedStorage").Shared.Health)
local RECOIL_RECOVER = 0.18 -- seconds (time constant) the leftover kick settles
local rng = Random.new()

local function smoothDamp(
	current: number,
	target: number,
	velocity: number,
	smooth: number,
	dt: number
): (number, number)
	local omega = 2 / math.max(smooth, 0.01)
	local x = omega * dt
	local decay = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
	local change = current - target
	local temp = (velocity + omega * change) * dt
	return target + (change + temp) * decay, (velocity - omega * temp) * decay
end

local function wrap(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

local function anglesTo(from: Vector3, to: Vector3): (number, number)
	local d = to - from
	local flat = math.sqrt(d.X * d.X + d.Z * d.Z)
	return math.atan2(-d.X, -d.Z), math.atan2(d.Y, math.max(flat, 1e-3))
end

local function direction(yaw: number, pitch: number): Vector3
	local c = math.cos(pitch)
	return Vector3.new(-math.sin(yaw) * c, math.sin(pitch), -math.cos(yaw) * c)
end

local function randomError(size: number): Vector2
	local a = rng:NextNumber() * 2 * math.pi
	return Vector2.new(math.cos(a), math.sin(a)) * size
end

-- A fresh target: the error starts wide.
function Aim.acquire(bot: Bot)
	bot.aimError = randomError(bot.profile.errorStart * (0.7 + rng:NextNumber() * 0.6))
end

-- The target cut the other way, or the bot got hit: the aim loosens.
function Aim.disturb(bot: Bot, share: number)
	bot.aimError += randomError(bot.profile.errorStart * share)
end

-- A shot's kick (degrees up, degrees side): what isn't pulled back stays.
function Aim.kick(bot: Bot, up: number, side: number)
	local keep = 1 - bot.profile.recoilControl * (0.85 + rng:NextNumber() * 0.3)
	bot.recoil += Vector2.new(side, up) * math.max(keep, 0)
end

-- The point the bot wants its crosshair on (nil: just look ahead): where the
-- target was `trackLag` ago, so strafing makes it miss (LihFolk AI
-- Difficulty Tuning: aiming at the live position "feels like aimbot").
function Aim.targetPoint(bot: Bot, now: number): Vector3?
	local m = bot.target
	if not m then
		return nil
	end
	local name = if m.aimPart == "Head" and m.headVisible then "Head" else "UpperTorso"
	local part = m.model:FindFirstChild(name)
	if not part or not part:IsA("BasePart") then
		return m.lastPos
	end
	local root = m.model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return part.Position
	end
	return Perception.lagged(m, now, bot.profile.trackLag) + (part.Position - root.Position)
end

-- Per frame: moves the spring toward `point` (or the look-at direction),
-- settles the error and recoil. Returns the angle (degrees) between where
-- the bot means to aim and where its spring is (the tracking lag).
function Aim.step(bot: Bot, point: Vector3?, dt: number): number
	local head = bot.head
	if not head then
		return 180
	end
	local wantYaw, wantPitch = bot.yaw, 0
	if point then
		wantYaw, wantPitch = anglesTo(head.Position, point)
	elseif bot.lookAt then
		wantYaw = anglesTo(head.Position, bot.lookAt)
	end
	wantYaw = bot.yaw + wrap(wantYaw - bot.yaw)
	local smooth = bot.profile.aimSmooth * (if point then 1 else 1.6)
	bot.yaw, bot.yawVel = smoothDamp(bot.yaw, wantYaw, bot.yawVel, smooth, dt)
	bot.pitch, bot.pitchVel = smoothDamp(bot.pitch, wantPitch, bot.pitchVel, smooth, dt)
	bot.yaw = wrap(bot.yaw)

	-- The error settles toward a wobble at the floor; recoil recovers.
	-- The wobble it settles toward moves a few times a second (a hand's drift).
	if rng:NextNumber() < dt / 0.25 then
		bot.aimWobble = randomError(bot.profile.errorFloor * (0.4 + rng:NextNumber() * 0.8))
	end
	local floor = bot.aimWobble
	-- A nearly dead target: easier levels ease off (a fair finish).
	local target = bot.target
	local humanoid = target and target.model:FindFirstChildOfClass("Humanoid")
	if
		humanoid
		and Health.get(humanoid) / math.max(Health.max(humanoid), 1) < BotsConfig.LOW_HEALTH
	then
		floor *= bot.profile.easeLowHealth
	end
	bot.aimError = floor + (bot.aimError - floor) * math.exp(-dt / bot.profile.errorSettle)
	bot.recoil *= math.exp(-dt / RECOIL_RECOVER)

	local lagYaw = math.deg(wrap(wantYaw - bot.yaw))
	local lagPitch = math.deg(wantPitch - bot.pitch)
	return math.sqrt(lagYaw * lagYaw + lagPitch * lagPitch)
end

-- Where the gun actually points: the spring plus error and recoil.
-- `missBy` (degrees, optional): pushed sideways off target on purpose (a
-- fair miss: the first shots at a new target, or over the hit budget).
function Aim.direction(bot: Bot, missBy: number?): Vector3
	local yaw = bot.yaw + math.rad(bot.aimError.X + bot.recoil.X + (missBy or 0))
	local pitch = math.clamp(bot.pitch + math.rad(bot.aimError.Y + bot.recoil.Y), -1.4, 1.4)
	return direction(yaw, pitch)
end

-- The angular size (degrees) of a part-sized target at `distance`.
function Aim.targetSize(distance: number): number
	return math.deg(math.atan2(1, math.max(distance, 1)))
end

return Aim
