--!strict
-- The Giltfold Fan's ribs in first person (Config/MeleeSkins FAN; design:
-- vault/02 Art/Skins/Giltfold/concept.md, "Fan poses and animation"). The
-- stock knife tracks still move the arm and the fan; this only opens and
-- closes the leaf by writing each rib Motor6D's Transform, which
-- Util/ViewmodelRig reads when it solves the gun's joints (call step() after
-- the gun's GunAnimator update, before the solve).
--
--   Draw    comes up shut, spreads open (Blender Fan_Open: overshoot, settle)
--   Slash   a small fold on the windup, a flick past open at contact
--   Heavy   folds shut for the thrust (Fan_Close), reopens on the recovery
--   Inspect shuts and reopens to show the leaf, then two fanning pulses
--   Idle    open
--
-- Studio review: the Workspace attribute DevFanScrub (0..1) holds the
-- current move at that point.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MeleeSkins = require(ReplicatedStorage.Shared.Config.MeleeSkins)

local FAN = MeleeSkins.FAN

type Rib = { motor: Motor6D, angle: number } -- angle: radians when shut

export type Fan = {
	ribs: { Rib },
	name: string,
	keys: { { number } }, -- { seconds, closed } in time order
	slopes: { number }, -- the curve's slope at each key (PCHIP)
	time: number,
	from: number, -- the leaf as the move began: the move blends in from here
	closed: number, -- the leaf's last value (the centre rib's)
}

local FanMotion = {}

-- The fan in `model` (a Knife variant whose rig has the Rib_NN motors), or nil.
function FanMotion.new(model: Instance): Fan?
	local rig = model:FindFirstChild("Rig")
	local motors = rig and rig:FindFirstChild("Motors")
	if not motors then
		return nil
	end
	local ribs: { Rib } = {}
	for _, m in motors:GetChildren() do
		local index = tonumber(m.Name:match("^" .. FAN.RIB_PREFIX .. "(%d+)$"))
		if index and m:IsA("Motor6D") then
			table.insert(ribs, { motor = m, angle = math.rad((index - FAN.CENTER) * FAN.STEP_DEG) })
		end
	end
	if #ribs == 0 then
		return nil
	end
	return {
		ribs = ribs,
		name = "Idle",
		keys = { { 0, 0 } },
		slopes = { 0 },
		time = 0,
		from = 0,
		closed = 0,
	}
end

local function shifted(keys: { { number } }, at: number, out: { { number } })
	for _, k in keys do
		table.insert(out, { at + k[1], k[2] })
	end
end

local function scaled(keys: { { number } }, length: number): { { number } }
	local out = table.create(#keys)
	for i, k in keys do
		out[i] = { k[1] * length, k[2] }
	end
	return out
end

-- Slopes for a monotone cubic through the keys (PCHIP, Fritsch-Carlson):
-- speed carries through every key, nothing overshoots between two keys.
-- 2026-11-21: was smoothstep per segment (the leaf stopped dead at every key,
-- the owner's "posed keys") and straight lines between the 24 fps Blender
-- samples (a speed step every 42 ms).
local function pchip(keys: { { number } }): { number }
	local n = #keys
	local slopes = table.create(n, 0)
	if n < 2 then
		return slopes
	end
	local d = table.create(n - 1, 0)
	for i = 1, n - 1 do
		local h = keys[i + 1][1] - keys[i][1]
		d[i] = if h > 0 then (keys[i + 1][2] - keys[i][2]) / h else 0
	end
	for i = 2, n - 1 do
		if d[i - 1] * d[i] > 0 then
			local h0 = keys[i][1] - keys[i - 1][1]
			local h1 = keys[i + 1][1] - keys[i][1]
			local w0, w1 = 2 * h1 + h0, h1 + 2 * h0
			slopes[i] = (w0 + w1) / (w0 / d[i - 1] + w1 / d[i])
		end
	end
	return slopes
end

-- Starts `name` ("Draw", "Slash", "Heavy", "Inspect" or "Idle"); `length` is
-- the arm move's length in seconds (the draw time, the swing, the inspect);
-- `hit` (0..1 of it) puts a slash's flick on that swing's contact.
function FanMotion.play(fan: Fan, name: string, length: number?, hit: number?)
	local len = math.max(length or 0.5, 0.05)
	local keys: { { number } } = {}
	if name == "Draw" then
		local at = len * FAN.DRAW_OPEN_AT
		table.insert(keys, { 0, 1 })
		shifted(FAN.OPEN, at, keys)
	elseif name == "Heavy" then
		shifted(FAN.CLOSE, 0, keys)
		shifted(FAN.OPEN, math.max(len * FAN.HEAVY_REOPEN_AT, FAN.CLOSE[#FAN.CLOSE][1]), keys)
	elseif name == "Slash" then
		keys = scaled(FAN.SLASH, len)
		-- The flick (FAN.SLASH_FLICK) lands on this swing's contact: the
		-- light slashes hit at different points (Slash2 at 38.5%, not 30%).
		local flick = FAN.SLASH[FAN.SLASH_FLICK][1]
		local finish = FAN.SLASH[#FAN.SLASH][1]
		if hit and hit > 0 and hit < finish then
			for i, k in FAN.SLASH do
				local at = if k[1] <= flick
					then k[1] * hit / flick
					else hit + (k[1] - flick) * (finish - hit) / (finish - flick)
				keys[i] = { at * len, k[2] }
			end
		end
	elseif name == "Inspect" then
		keys = scaled(FAN.INSPECT, len)
	else
		name = "Idle"
		keys = { { 0, 0 } }
	end
	fan.name = name
	fan.keys = keys
	fan.slopes = pchip(keys)
	fan.from = fan.closed
	fan.time = 0
end

local function sample(fan: Fan, t: number): number
	local keys = fan.keys
	local value = keys[#keys][2]
	if t <= keys[1][1] then
		value = keys[1][2]
	else
		for i = 2, #keys do
			local b = keys[i]
			if t <= b[1] then
				local a = keys[i - 1]
				local h = b[1] - a[1]
				if h <= 0 then
					value = b[2]
					break
				end
				local u = (t - a[1]) / h
				local u2, u3 = u * u, u * u * u
				value = a[2] * (2 * u3 - 3 * u2 + 1)
					+ fan.slopes[i - 1] * h * (u3 - 2 * u2 + u)
					+ b[2] * (-2 * u3 + 3 * u2)
					+ fan.slopes[i] * h * (u3 - u2)
				break
			end
		end
	end
	-- A new move picks the leaf up where the last one left it (a slash out of
	-- the heavy's fold snapped shut-to-open in one frame).
	local blend = math.clamp(t / FAN.BLEND, 0, 1)
	blend = blend * blend * (3 - 2 * blend)
	return fan.from + (value - fan.from) * blend
end

-- Advances the move and poses the ribs. Returns true while a move other than
-- the idle is still running.
function FanMotion.step(fan: Fan, dt: number): boolean
	fan.time += dt
	local last = fan.keys[#fan.keys][1]
	local t = fan.time
	if RunService:IsStudio() then
		local scrub = StateValues.get(Workspace, "DevFanScrub")
		if typeof(scrub) == "number" then
			t = math.clamp(scrub, 0, 1) * last
		end
	end
	local closed = sample(fan, t)
	-- The ribs ripple out from the centre (RIB_LAG a step): the outer ones
	-- trail the centre, so the leaf opens and folds as a wave, not a plate.
	for _, rib in fan.ribs do
		local steps = math.abs(rib.angle) / math.rad(FAN.STEP_DEG)
		rib.motor.Transform =
			CFrame.fromAxisAngle(Vector3.zAxis, rib.angle * sample(fan, t - steps * FAN.RIB_LAG))
	end
	fan.closed = closed
	if fan.name ~= "Idle" and t > last then
		fan.name = "Idle"
		fan.keys = { { 0, closed } }
		fan.slopes = { 0 }
		fan.from = closed
		fan.time = 0
	end
	return fan.name ~= "Idle"
end

return FanMotion
