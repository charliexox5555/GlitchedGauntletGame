--!strict
-- The look stream (vault/05 Production/Spectate Replay Fix Plan.md, B):
-- where every fighter is aiming, on one timestamped timeline, for the people
-- spectating them and for the final-kill replay.
--   * Players send `Look` (unreliable, a 16-byte buffer: f64 server time,
--     f32 yaw, f32 pitch in radians) about Juice.SPECTATE.lookHz times a
--     second while alive (WeaponController). Checked here: a buffer of exactly
--     16 bytes, finite numbers, a time near the server's now and newer than
--     the last, a live character, the rate limit (Config/Match RATE.Look).
--   * Bots push their gun look from Bots/Brain (`push`).
--   * Every accepted sample goes into a short ring per fighter (`window`
--     reads it back for the replay) and is relayed at once, unreliable, only
--     to the players spectating that fighter (`LookRelay`, the same buffer;
--     Bots/Spectated knows who watches whom).
-- A fighter is keyed by what the clients know them by: the Player, or the
-- bot's model. No gameplay reads this: it is only what the camera shows.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Health = require(ReplicatedStorage.Shared.Health)
local Juice = require(ReplicatedStorage.Shared.Config.Juice)
local MatchConfig = require(ReplicatedStorage.Shared.Config.Match)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)

local Spectated = require(script.Parent.Parent.Bots.Spectated)

local LookStream = {}

local S = Juice.SPECTATE
local SIZE = math.ceil(S.lookRingSeconds * S.lookHz * 1.5) -- slots per fighter (headroom over the rate)
local PACKET = 16
local PITCH_LIMIT = 1.5
local TWO_PI = 2 * math.pi

export type Sample = { t: number, yaw: number, pitch: number }

type Ring = {
	t: { number },
	yaw: { number },
	pitch: { number },
	head: number, -- the slot written last
	count: number,
	lag: number, -- smoothed seconds from a sample's time to its arrival (players; bots 0)
}

-- Fighters who left or bots that were removed drop out by themselves.
local rings: { [Instance]: Ring } = setmetatable({}, { __mode = "k" }) :: any
local limiter = RateLimit.new(MatchConfig.RATE)

local function wrap(a: number): number
	return (a + math.pi) % TWO_PI - math.pi
end

local function finite(v: number): boolean
	return v == v and v > -math.huge and v < math.huge
end

local function ringOf(holder: Instance): Ring
	local ring = rings[holder]
	if not ring then
		ring = {
			t = table.create(SIZE, -math.huge),
			yaw = table.create(SIZE, 0),
			pitch = table.create(SIZE, 0),
			head = 0,
			count = 0,
			lag = 0,
		}
		rings[holder] = ring
	end
	return ring
end

local function packet(t: number, yaw: number, pitch: number): buffer
	local b = buffer.create(PACKET)
	buffer.writef64(b, 0, t)
	buffer.writef32(b, 8, yaw)
	buffer.writef32(b, 12, pitch)
	return b
end

-- A checked sample from `holder` (a Player or a bot's model): into its ring,
-- then to whoever spectates it.
function LookStream.push(holder: Instance, t: number, yaw: number, pitch: number)
	if not (finite(t) and finite(yaw) and finite(pitch)) then
		return
	end
	yaw = wrap(yaw)
	pitch = math.clamp(pitch, -PITCH_LIMIT, PITCH_LIMIT)
	local ring = ringOf(holder)
	if ring.count > 0 and t <= ring.t[ring.head] then
		return -- late or repeated (unreliable packets can arrive out of order)
	end
	local slot = ring.head % SIZE + 1
	ring.head = slot
	ring.count = math.min(ring.count + 1, SIZE)
	ring.t[slot] = t
	ring.yaw[slot] = yaw
	ring.pitch[slot] = pitch
	local watchers = Spectated.watchersOf(holder)
	if #watchers > 0 then
		local b = packet(t, yaw, pitch)
		local relay = Net.unreliable("LookRelay")
		for _, spectator in watchers do
			if spectator.Parent == Players then
				relay:FireClient(spectator, holder, b)
			end
		end
	end
end

-- How late `holder`'s samples reach the server (seconds, smoothed): their
-- look at time t matches what the server saw of them at about t + lag.
function LookStream.lagOf(holder: Instance): number
	local ring = rings[holder]
	return if ring then ring.lag else 0
end

-- The samples between `from` and `to` (server time), oldest first: the
-- final-kill replay's view of the killer.
function LookStream.window(holder: Instance, from: number, to: number): { Sample }
	local out: { Sample } = {}
	local ring = rings[holder]
	if not ring then
		return out
	end
	-- Oldest to newest.
	for i = ring.count - 1, 0, -1 do
		local slot = (ring.head - 1 - i) % SIZE + 1
		local t = ring.t[slot]
		if t >= from and t <= to then
			table.insert(out, { t = t, yaw = ring.yaw[slot], pitch = ring.pitch[slot] })
		end
	end
	return out
end

local function onLook(player: Player, data: unknown)
	if not limiter:allow(player, "Look") then
		return
	end
	if typeof(data) ~= "buffer" or buffer.len(data) ~= PACKET then
		return
	end
	local t = buffer.readf64(data, 0)
	local yaw = buffer.readf32(data, 8)
	local pitch = buffer.readf32(data, 12)
	if not (finite(t) and finite(yaw) and finite(pitch)) then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if t < now - S.lookMaxAge or t > now + S.lookMaxAhead then
		return
	end
	local character = player.Character
	if not character or not Health.isAlive(character:FindFirstChildOfClass("Humanoid")) then
		return
	end
	local ring = ringOf(player)
	ring.lag += (math.clamp(now - t, 0, S.lookMaxAge) - ring.lag) * 0.1
	LookStream.push(player, t, yaw, pitch)
end

function LookStream.init()
	Net.unreliable("Look").OnServerEvent:Connect(onLook)
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
		rings[player] = nil
	end)
end

return LookStream
