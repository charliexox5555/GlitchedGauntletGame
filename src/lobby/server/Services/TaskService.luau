--!strict
-- The task Path on the server (vault/01 Design/Tasks and Rewards.md; list in Config/Tasks, rules in
-- Shared/TaskPath). No remote in: every count comes from server decisions.
--   * Matches: ProgressionService applies a match's task stats in the same PlayerData write as its XP and match
--     pay (txId "m:<matchKey>:<userId>"), with TaskService.pay, then calls TaskService.notify.
--   * Range (lobby only): Range/RangeEvents counts are held here and written in one PlayerData change, at once
--     when they finish a task, else RANGE_FLUSH seconds after the first, and when the player leaves.
-- Out: TaskEvent (server -> one client) with what finished, for the toast. The Path is published by
-- Shared/PlayerData as the "Tasks" StringValue.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Inventory = require(ReplicatedStorage.Shared.Config.Inventory)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local TaskPath = require(ReplicatedStorage.Shared.TaskPath)
local Tasks = require(ReplicatedStorage.Shared.Config.Tasks)
local PlayerDataService = require(script.Parent.PlayerDataService)
local Telemetry = require(script.Parent.Parent.Telemetry)

local TaskService = {}

type Pending = { stats: TaskPath.RangeStats, timer: thread?, tries: number }

local MAX_TRIES = 3 -- a range write that failed (DataStore busy) is tried again this many times

local pending: { [Player]: Pending } = {}
local flushing: { [Player]: boolean } = {}
local inFlight = 0

-- Inside a PlayerData change (no yields): pays what a Path change earned. Balances stop at their caps.
function TaskService.pay(data: PlayerData.Data, payout: TaskPath.Payout)
	data.coins = math.min(data.coins + payout.coins, Inventory.MAX_COINS)
	data.tickets = math.min(data.tickets + payout.tickets, Economy.MAX_TICKETS)
end

-- After the write landed: the toast, and analytics for each finished set.
function TaskService.notify(player: Player?, payout: TaskPath.Payout?)
	if not player or not payout or #payout.done == 0 then
		return
	end
	for _, setId in payout.sets do
		Telemetry.event(player, "Task set done", 1, setId)
	end
	LobbyNet.event("TaskEvent"):FireClient(player, {
		done = payout.done,
		coins = payout.coins,
		tickets = payout.tickets,
		parts = payout.parts,
		sets = payout.sets,
		title = payout.title,
	})
end

local function flush(player: Player)
	local p = pending[player]
	if not p then
		return
	end
	if flushing[player] then
		p.timer = nil -- the write in flight sends these after it
		return
	end
	pending[player] = nil
	if p.timer and coroutine.running() ~= p.timer then
		pcall(task.cancel, p.timer)
	end
	flushing[player] = true
	inFlight += 1
	local stats = p.stats
	local payout: TaskPath.Payout? = nil
	-- by UserId: a player who just left is still written (the record may already be gone)
	local ok, why = PlayerDataService.transactUserId(
		player.UserId,
		PlayerDataService.newTxId(),
		function(data: PlayerData.Data)
			payout = nil
			if not TaskPath.open(data.prog.matches) then
				return false, "closed"
			end
			local result = TaskPath.applyRange(data.tasks, stats, data.prog.level)
			TaskService.pay(data, result)
			payout = result
			return true
		end
	)
	inFlight -= 1
	flushing[player] = nil
	if ok then
		if player.Parent == Players then
			TaskService.notify(player, payout)
		end
	elseif why ~= "closed" then
		if
			(why == "saving" or why == "busy")
			and player.Parent == Players
			and p.tries < MAX_TRIES
		then
			-- put the counts back (with any that arrived meanwhile) and try again later
			local back = pending[player]
			if back then
				back.stats.visit = math.max(back.stats.visit, stats.visit)
				back.stats.targets = math.min(back.stats.targets + stats.targets, 1000)
				back.stats.bots = math.min(back.stats.bots + stats.bots, 1000)
				for t, n in stats.botTiers do
					back.stats.botTiers[t] = math.min((back.stats.botTiers[t] or 0) + n, 1000)
				end
				back.tries = math.max(back.tries, p.tries + 1)
			else
				pending[player] = { stats = stats, tries = p.tries + 1 }
			end
			local again = pending[player]
			if again and not again.timer then
				again.timer = task.delay(Tasks.RANGE_FLUSH, flush, player)
			end
			return
		end
		warn(`[TaskService] range progress for {player.UserId} not saved: {why}`)
	end
	-- counts that arrived during the write go out next
	local later = pending[player]
	if later and not later.timer then
		task.spawn(flush, player)
	end
end

local function onRange(player: Player, kind: string, tier: number?)
	local data = PlayerDataService.get(player)
	if not data or not TaskPath.open(data.prog.matches) or not TaskPath.wantsRange(data.tasks) then
		return
	end
	local p = pending[player]
	if not p then
		p = { stats = { visit = 0, targets = 0, bots = 0, botTiers = { 0, 0, 0, 0 } }, tries = 0 }
		pending[player] = p
	end
	local s = p.stats
	if kind == "visit" then
		s.visit = 1
	elseif kind == "target" then
		s.targets = math.min(s.targets + 1, 1000)
	elseif kind == "bot" then
		s.bots = math.min(s.bots + 1, 1000)
		if tier and s.botTiers[tier] then
			s.botTiers[tier] = math.min(s.botTiers[tier] + 1, 1000)
		end
	else
		return
	end
	if TaskPath.rangeFinishes(data.tasks, s) then
		task.spawn(flush, player) -- the reward lands now
	elseif not p.timer then
		p.timer = task.delay(Tasks.RANGE_FLUSH, flush, player)
	end
end

function TaskService.init() end

function TaskService.start()
	local RangeEvents = require(script.Parent.Parent.Range.RangeEvents)
	RangeEvents.connect(onRange)
	Players.PlayerRemoving:Connect(function(player: Player)
		local p = pending[player]
		if p then
			if p.timer then
				pcall(task.cancel, p.timer)
				p.timer = nil
			end
			task.spawn(flush, player)
		end
	end)
	game:BindToClose(function()
		for player in pending do
			task.spawn(flush, player)
		end
		local t = os.clock()
		while (inFlight > 0 or next(pending) ~= nil) and os.clock() - t < 20 do
			task.wait(0.2)
		end
	end)
end

return TaskService
