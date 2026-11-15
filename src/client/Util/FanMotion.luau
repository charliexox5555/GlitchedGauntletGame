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
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MeleeSkins = require(ReplicatedStorage.Shared.Config.MeleeSkins)

local FAN = MeleeSkins.FAN

type Rib = { motor: Motor6D, angle: number } -- angle: radians when shut

export type Fan = {
	ribs: { Rib },
	name: string,
	keys: { { number } }, -- { seconds, closed } in time order
	smooth: boolean, -- ease between keys (sparse moves); dense Blender curves are linear
	time: number,
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
	return { ribs = ribs, name = "Idle", keys = { { 0, 0 } }, smooth = false, time = 0 }
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

-- Starts `name` ("Draw", "Slash", "Heavy", "Inspect" or "Idle"); `length` is
-- the arm move's length in seconds (the draw time, the swing, the inspect).
function FanMotion.play(fan: Fan, name: string, length: number?)
	local len = math.max(length or 0.5, 0.05)
	local keys: { { number } } = {}
	local smooth = false
	if name == "Draw" then
		local at = len * FAN.DRAW_OPEN_AT
		table.insert(keys, { 0, 1 })
		shifted(FAN.OPEN, at, keys)
	elseif name == "Heavy" then
		shifted(FAN.CLOSE, 0, keys)
		shifted(FAN.OPEN, math.max(len * FAN.HEAVY_REOPEN_AT, FAN.CLOSE[#FAN.CLOSE][1]), keys)
	elseif name == "Slash" then
		keys = scaled(FAN.SLASH, len)
		smooth = true
	elseif name == "Inspect" then
		keys = scaled(FAN.INSPECT, len)
		smooth = true
	else
		name = "Idle"
		keys = { { 0, 0 } }
	end
	fan.name = name
	fan.keys = keys
	fan.smooth = smooth
	fan.time = 0
end

local function sample(fan: Fan, t: number): number
	local keys = fan.keys
	if t <= keys[1][1] then
		return keys[1][2]
	end
	for i = 2, #keys do
		local b = keys[i]
		if t <= b[1] then
			local a = keys[i - 1]
			local u = if b[1] > a[1] then (t - a[1]) / (b[1] - a[1]) else 1
			if fan.smooth then
				u = u * u * (3 - 2 * u)
			end
			return a[2] + (b[2] - a[2]) * u
		end
	end
	return keys[#keys][2]
end

-- Advances the move and poses the ribs. Returns true while a move other than
-- the idle is still running.
function FanMotion.step(fan: Fan, dt: number): boolean
	fan.time += dt
	local last = fan.keys[#fan.keys][1]
	local t = fan.time
	if RunService:IsStudio() then
		local scrub = Workspace:GetAttribute("DevFanScrub")
		if typeof(scrub) == "number" then
			t = math.clamp(scrub, 0, 1) * last
		end
	end
	local closed = sample(fan, t)
	for _, rib in fan.ribs do
		rib.motor.Transform = CFrame.fromAxisAngle(Vector3.zAxis, rib.angle * closed)
	end
	if fan.name ~= "Idle" and t > last then
		fan.name = "Idle"
		fan.keys = { { 0, closed } }
		fan.time = 0
	end
	return fan.name ~= "Idle"
end

return FanMotion
