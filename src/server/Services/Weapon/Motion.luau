--!strict
-- Motion history for shot validation (WeaponService): what the server's own
-- simulation says each player was doing, sampled every Heartbeat, so the
-- server can recompute the spread a shot was allowed (Gunplay v2 movement
-- penalty and ADS), and the Dash gun gate. A plain module: no init/start
-- (WeaponService connects `sample` to Heartbeat).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Accuracy = require(Shared.Util.Accuracy)
local Combat = require(Shared.Config.Combat)
local DashMod = require(Shared.Mods.Dash)
local Types = require(Shared.Types)

type WeaponConfig = Types.WeaponConfig

-- `aim` is the ADS blend the client also runs (0..1 over the gun's adsTime).
type MotionSample = {
	t: number,
	state: string,
	speed: number,
	aim: number,
	sinceLanding: number,
}

type MotionTrack = {
	samples: { MotionSample },
	aim: number,
	lastState: string,
	landedAt: number,
	-- Dash (Mods/Dash.stepGate), on the server's own clock from its own
	-- simulation's dash attributes: no shots before dash.readyAt; the first
	-- shot until dash.focusUntil has no movement spread (Dash Focus).
	dash: DashMod.GunGate,
}

local Motion = {}

local motion: { [Player]: MotionTrack } = {}

local function aimHeld(player: Player): boolean
	local context = player:FindFirstChild("PlayContext")
	local action = context and context:FindFirstChild("Aim")
	return action ~= nil and action:IsA("InputAction") and action:GetState() == true
end

-- One Heartbeat sample for every player. `configOf`: the gun the player has
-- equipped (WeaponService's state), for the ADS blend.
function Motion.sample(dt: number, configOf: (Player) -> WeaponConfig?)
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not character or not root or not root:IsA("BasePart") then
			continue
		end
		local track = motion[player]
		if not track then
			track = {
				samples = {},
				aim = 0,
				lastState = "Idle",
				landedAt = -math.huge,
				dash = DashMod.newGate(),
			}
			motion[player] = track
		end
		local state = (character:GetAttribute("MoveState") :: string?) or "Idle"
		-- Dash: the gun gate, from this server's own simulation.
		DashMod.stepGate(track.dash, character, now, time())
		-- Landings, on the server's own clock (the client spots its own).
		if track.lastState == "Air" and state ~= "Air" then
			track.landedAt = now
		end
		track.lastState = state
		-- The same ADS blend the client runs (WeaponController): toward 1 while
		-- the Aim input is held, at 1 / adsTime per second.
		local config = configOf(player)
		local canAim = config ~= nil and config.fireMode ~= "Melee" and not config.noAds
		local rate = 1 / math.max(if config then config.adsTime else 0.2, 0.05)
		local held = canAim and aimHeld(player) and state ~= "Sprint"
		track.aim = math.clamp(track.aim + (if held then rate else -rate) * dt, 0, 1)
		local list = track.samples
		table.insert(list, {
			t = now,
			state = state,
			speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude,
			aim = track.aim,
			sinceLanding = now - track.landedAt,
		})
		while #list > 0 and now - list[1].t > Combat.MOTION_HISTORY do
			table.remove(list, 1)
		end
	end
end

-- Dash: the gun is down while dashing and for the dash's fire delay after.
function Motion.dashBlocked(player: Player): boolean
	local track = motion[player]
	return track ~= nil and os.clock() < track.dash.readyAt - Combat.DASH_FIRE_SLACK
end

-- Dash Focus: is a shot at `now` the first one after a dash, inside its
-- window (the server saw the dash itself; the client never claims it)?
-- Either way the window closes: call this only for a shot being accepted.
function Motion.takeFocus(player: Player, now: number, ping: number): boolean
	local track = motion[player]
	local focus = track ~= nil
		and track.dash.focusOpen
		and now <= track.dash.focusUntil + Combat.DASH_FIRE_SLACK + ping
	if track then
		track.dash.focusOpen = false
	end
	return focus
end

-- A new life: no dash left over from the last one.
function Motion.resetDash(player: Player)
	local track = motion[player]
	if track then
		DashMod.resetGate(track.dash)
	end
end

function Motion.forget(player: Player)
	motion[player] = nil
end

-- The spread a shot is allowed to have, from the server's own state: the
-- gun's spray heat band (from accepted shot times, plus SPREAD_HEAT_SLACK
-- shots) and what the player was doing around when they fired: samples from
-- `ping` + FIRE_TIME_SLACK ago up to now. The high edge also allows a jump the
-- server hasn't simulated yet (high edges only ever cost the shooter).
-- Returns the lowest and highest cone, and whether a centre-biased shot is
-- allowed (only when the server saw the shooter standing at fire time).
-- `focus` (Dash Focus): the shot may have no movement spread at all, and be
-- centre-biased like a standing shot.
function Motion.spreadBand(
	player: Player,
	config: WeaponConfig,
	heatLow: number,
	heatHigh: number,
	ping: number,
	focus: boolean
): (number, number, boolean)
	local now = os.clock()
	local track = motion[player]
	local samples = if track then track.samples else {}
	local fireTime = now - ping
	local recent: { MotionSample } = {}
	local closest: MotionSample? = nil
	for _, s in samples do
		if s.t >= fireTime - Combat.FIRE_TIME_SLACK then
			table.insert(recent, s)
		end
		if not closest or math.abs(s.t - fireTime) < math.abs(closest.t - fireTime) then
			closest = s
		end
	end
	local latest = samples[#samples]
	if #recent == 0 and latest then
		table.insert(recent, latest)
	end
	if #recent == 0 then
		-- No samples yet (just spawned): anything from standing aimed to airborne.
		table.insert(
			recent,
			{ t = now, state = "Idle", speed = 0, aim = 1, sinceLanding = math.huge }
		)
		table.insert(recent, { t = now, state = "Air", speed = 0, aim = 0, sinceLanding = 0 })
	end
	local aimLow, aimHigh = 0, 1
	local anyCrouch, allCrouch = false, true
	for _, s in recent do
		aimLow = math.max(aimLow, s.aim)
		aimHigh = math.min(aimHigh, s.aim)
		anyCrouch = anyCrouch or s.state == "Crouch"
		allCrouch = allCrouch and s.state == "Crouch"
	end
	local moveLow, moveHigh = math.huge, 0
	for _, s in recent do
		local m: Accuracy.Motion =
			{ state = s.state, speed = s.speed, aim = aimLow, sinceLanding = s.sinceLanding }
		moveLow = math.min(moveLow, Accuracy.movement(config, m))
		m.aim = aimHigh
		moveHigh = math.max(moveHigh, Accuracy.movement(config, m))
	end
	if latest and latest.state ~= "Air" then
		local jump: Accuracy.Motion =
			{ state = "Air", speed = latest.speed, aim = aimHigh, sinceLanding = math.huge }
		moveHigh = math.max(moveHigh, Accuracy.movement(config, jump))
	end
	if focus then
		moveLow = 0
	end
	-- The gun's spread is monotonic in heat but may fall as it heats (Ares),
	-- so take both heat edges each way.
	local slack = Combat.SPREAD_HEAT_SLACK
	local coolHeat, hotHeat = heatLow - slack, heatHigh + slack
	local low = math.min(
		Accuracy.gun(config, coolHeat, aimLow, anyCrouch),
		Accuracy.gun(config, hotHeat, aimLow, anyCrouch)
	) + moveLow
	local high = math.max(
		Accuracy.gun(config, coolHeat, aimHigh, allCrouch),
		Accuracy.gun(config, hotHeat, aimHigh, allCrouch)
	) + moveHigh
	local standing = focus
		or moveLow <= 0
			and closest ~= nil
			and Accuracy.movement(config, {
				state = closest.state,
				speed = closest.speed,
				aim = closest.aim,
				sinceLanding = closest.sinceLanding,
			}) <= 0
	return low, high, standing
end

return Motion
