--!strict
-- Per-player tester stats, measured on the server from WeaponService's
-- accepted shots and applied damage (never from client claims): damage,
-- shots, hits, accuracy, headshots, kills, DPS, time-to-kill and the last
-- hit's damage and distance. Sent to the owner on TesterStats.
--
-- Time-to-kill runs from the first hit on a target to the killing hit (so a
-- one-shot kill is 0 s), with the shots fired over that time.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local TestRange = require(ReplicatedStorage.Shared.Config.TestRange)
local Types = require(ReplicatedStorage.Shared.Types)

type HitZone = Types.HitZone

type Stats = {
	snapshot: Types.TesterStats,
	recent: { { t: number, damage: number } },
	dirty: boolean,
}

type Engagement = { start: number, shotsAtStart: number }

export type DamageEvent = {
	attacker: Player,
	victim: Model,
	damage: number,
	zone: HitZone,
	killed: boolean,
	weaponId: string,
	position: Vector3,
	projectile: boolean,
}

local RangeStats = {}

local stats: { [Player]: Stats } = {}
local engagements: { [Model]: { [Player]: Engagement } } = {}

local function fresh(): Stats
	return {
		snapshot = {
			damage = 0,
			shots = 0,
			hits = 0,
			headshots = 0,
			kills = 0,
			dps = 0,
			peakDps = 0,
		},
		recent = {},
		dirty = true,
	}
end

local function statsFor(player: Player): Stats
	local s = stats[player]
	if not s then
		s = fresh()
		stats[player] = s
	end
	return s
end

local function round(n: number, places: number): number
	local m = 10 ^ places
	return math.round(n * m) / m
end

local function updateDps(s: Stats, now: number)
	local cutoff = now - TestRange.DPS_WINDOW
	local total = 0
	for i = #s.recent, 1, -1 do
		local r = s.recent[i]
		if r.t < cutoff then
			table.remove(s.recent, i)
		else
			total += r.damage
		end
	end
	-- Rate since the oldest hit in the window: the hits after it, over the
	-- time since it (n hits span n - 1 gaps). Falls off once firing stops.
	local oldest = s.recent[1]
	local dps = 0
	if oldest then
		local span = now - oldest.t
		dps = if span >= 0.2 then (total - oldest.damage) / span else total / TestRange.DPS_WINDOW
	end
	dps = round(dps, 1)
	if dps ~= s.snapshot.dps then
		s.snapshot.dps = dps
		s.dirty = true
	end
	if dps > s.snapshot.peakDps then
		s.snapshot.peakDps = dps
	end
end

function RangeStats.onShot(player: Player, _weaponId: string, hit: boolean)
	if not player.Parent then
		return -- left the game (a late projectile): don't recreate their entry
	end
	local s = statsFor(player)
	s.snapshot.shots += 1
	if hit then
		s.snapshot.hits += 1
	end
	s.dirty = true
end

function RangeStats.clearTarget(victim: Model)
	engagements[victim] = nil
end

function RangeStats.onDamage(e: DamageEvent)
	if not e.attacker.Parent then
		return
	end
	local s = statsFor(e.attacker)
	local snap = s.snapshot
	local now = os.clock()
	snap.damage = round(snap.damage + e.damage, 1)
	if e.zone == "Head" then
		snap.headshots += 1
	end
	-- Projectile shots were counted when fired; their hits land here.
	if e.projectile then
		snap.hits += 1
	end
	table.insert(s.recent, { t = now, damage = e.damage })
	updateDps(s, now)

	local head = e.attacker.Character and e.attacker.Character:FindFirstChild("Head")
	local distance = if head and head:IsA("BasePart")
		then (e.position - head.Position).Magnitude
		else 0
	snap.lastHit = {
		damage = round(e.damage, 1),
		zone = e.zone,
		distance = round(distance, 1),
		weapon = e.weaponId,
	}

	-- Time-to-kill. This damage's own shot is counted after the damage (except
	-- projectiles, counted when fired), hence the +1 / -1.
	local pending = if e.projectile then 0 else 1
	local byAttacker = engagements[e.victim]
	if not byAttacker then
		byAttacker = {}
		engagements[e.victim] = byAttacker
		-- Dummies are destroyed; old characters may only be unparented.
		local victim = e.victim
		local connection: RBXScriptConnection
		connection = victim.AncestryChanged:Connect(function()
			if not victim:IsDescendantOf(workspace) then
				engagements[victim] = nil
				connection:Disconnect()
			end
		end)
	end
	local engagement = byAttacker[e.attacker]
	if not engagement then
		engagement = { start = now, shotsAtStart = snap.shots + pending - 1 }
		byAttacker[e.attacker] = engagement
	end
	if e.killed then
		snap.kills += 1
		snap.lastTtk = round(now - engagement.start, 3)
		snap.lastTtkShots = snap.shots + pending - engagement.shotsAtStart
		snap.lastTtkWeapon = e.weaponId
		engagements[e.victim] = nil
	end
	s.dirty = true
end

function RangeStats.reset(player: Player)
	stats[player] = fresh()
	for _, byAttacker in engagements do
		byAttacker[player] = nil
	end
end

-- Sends changed stats (and the DPS decaying back to 0) a few times a second.
function RangeStats.start()
	Players.PlayerRemoving:Connect(function(player)
		stats[player] = nil
		for _, byAttacker in engagements do
			byAttacker[player] = nil
		end
	end)
	task.spawn(function()
		while true do
			task.wait(TestRange.STATS_SEND_INTERVAL)
			local now = os.clock()
			for player, s in stats do
				if #s.recent > 0 or s.snapshot.dps > 0 then
					updateDps(s, now)
				end
				if s.dirty and player.Parent then
					s.dirty = false
					Net.event("TesterStats"):FireClient(player, s.snapshot)
				end
			end
		end
	end)
end

return RangeStats
