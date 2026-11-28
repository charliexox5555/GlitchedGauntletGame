--!strict
-- Owner-only Lobby admin service (Config/Admin.AUTHORIZED_USER_IDS).
-- Validates identity, rate limits, types and bounds on every request, then
-- applies mutations atomically through PlayerDataService.transact so saves,
-- live StateValues, Backpack inventory and Locker equips update immediately.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local AdminConfig = require(ReplicatedStorage.Shared.Config.Admin)
local BotsConfig = require(ReplicatedStorage.Shared.Config.Bots)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local DailyRoll = require(ReplicatedStorage.Shared.DailyRoll)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Inventory = require(ReplicatedStorage.Shared.Config.Inventory)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local Locker = require(ReplicatedStorage.Shared.Locker)
local GunLoadout = require(ReplicatedStorage.Shared.GunLoadout)
local LoadoutConfig = require(ReplicatedStorage.Shared.Config.Loadout)
local ModLoadout = require(ReplicatedStorage.Shared.ModLoadout)
local Mods = require(ReplicatedStorage.Shared.Mods)
local ModsConfig = require(ReplicatedStorage.Shared.Config.Mods)
local OnboardingConfig = require(ReplicatedStorage.Shared.Config.Onboarding)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local Progress = require(ReplicatedStorage.Shared.Progress)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.Progression)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local ServerRole = require(ReplicatedStorage.Shared.ServerRole)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local TaskPath = require(ReplicatedStorage.Shared.TaskPath)
local Tasks = require(ReplicatedStorage.Shared.Config.Tasks)

local LockerService = require(script.Parent.LockerService)
local OnboardingService = require(script.Parent.OnboardingService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local QueueService = require(script.Parent.QueueService)

type Data = PlayerData.Data

local AdminService = {}

local QUICK_MATCH_SIZES: { [string]: number } = {
	["1v1"] = 1,
	["2v2"] = 2,
	["3v3"] = 3,
	beginner = 2,
}
local matchHostRef: any = nil

local function getMatchHost(): any
	if matchHostRef then
		return matchHostRef
	end
	local server = ServerScriptService:FindFirstChild("Server")
	local services = server and server:FindFirstChild("Services")
	local host = services and services:FindFirstChild("MatchHost")
	if host and host:IsA("ModuleScript") then
		matchHostRef = require(host)
	end
	return matchHostRef
end

local limiter = RateLimit.new({ Admin = AdminConfig.RATE })
local adminEvent: RemoteEvent? = nil

local function finiteInt(v: unknown, minVal: number, maxVal: number): number?
	if typeof(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		return nil
	end
	return math.clamp(math.floor(v), minVal, maxVal)
end

local function str(v: unknown, maxLen: number): string?
	if typeof(v) ~= "string" or #v == 0 or #v > maxLen then
		return nil
	end
	return v
end

local function fmt(n: number): string
	local sign = if n < 0 then "-" else ""
	local s = tostring(math.abs(math.floor(n)))
	while true do
		local nextStr, k = string.gsub(s, "^(%d+)(%d%d%d)", "%1,%2")
		s = nextStr
		if k == 0 then
			break
		end
	end
	return sign .. s
end

local function reply(
	player: Player,
	ok: boolean,
	action: string,
	targetUserId: number,
	text: string
)
	if adminEvent then
		adminEvent:FireClient(player, {
			ok = ok,
			action = action,
			targetUserId = targetUserId,
			text = text,
		})
	end
end

local function removeSkinFromData(data: Data, gunId: string, line: string): boolean
	local list = data.skins[gunId]
	if not list then
		return false
	end
	local idx = table.find(list, line)
	if not idx then
		return false
	end
	table.remove(list, idx)
	if #list == 0 then
		data.skins[gunId] = nil
	end
	return true
end

local function buildMutation(
	action: string,
	payload: { [string]: unknown },
	targetName: string
): (PlayerDataService.Change?, string?)
	if action == "addCoins" then
		local delta = finiteInt(payload.amount, -Inventory.MAX_COINS, Inventory.MAX_COINS)
		if not delta or delta == 0 then
			return nil, "Invalid coin amount"
		end
		return function(data: Data)
			data.coins = math.clamp(data.coins + delta, 0, Inventory.MAX_COINS)
			return true
		end,
			string.format("%s%s Coins -> %s", if delta > 0 then "+" else "", fmt(delta), targetName)
	elseif action == "setCoins" then
		local value = finiteInt(payload.amount, 0, Inventory.MAX_COINS)
		if not value then
			return nil, "Invalid coin value"
		end
		return function(data: Data)
			data.coins = value
			return true
		end,
			string.format("Set Coins = %s -> %s", fmt(value), targetName)
	elseif action == "addTickets" then
		local delta = finiteInt(payload.amount, -Economy.MAX_TICKETS, Economy.MAX_TICKETS)
		if not delta or delta == 0 then
			return nil, "Invalid ticket amount"
		end
		return function(data: Data)
			data.tickets = math.clamp(data.tickets + delta, 0, Economy.MAX_TICKETS)
			return true
		end,
			string.format(
				"%s%s Tickets -> %s",
				if delta > 0 then "+" else "",
				fmt(delta),
				targetName
			)
	elseif action == "setTickets" then
		local value = finiteInt(payload.amount, 0, Economy.MAX_TICKETS)
		if not value then
			return nil, "Invalid ticket value"
		end
		return function(data: Data)
			data.tickets = value
			return true
		end,
			string.format("Set Tickets = %s -> %s", fmt(value), targetName)
	elseif action == "addLevel" then
		local delta =
			finiteInt(payload.amount, -ProgressionConfig.MAX_LEVEL, ProgressionConfig.MAX_LEVEL)
		if not delta or delta == 0 then
			return nil, "Invalid level delta"
		end
		return function(data: Data)
			local nextLevel = math.clamp(data.prog.level + delta, 1, ProgressionConfig.MAX_LEVEL)
			data.prog.level = nextLevel
			data.prog.xp = math.min(data.prog.xp, ProgressionConfig.xpToNext(nextLevel) - 1)
			if nextLevel >= ProgressionConfig.MAX_LEVEL then
				data.prog.xp = 0
			end
			return true
		end,
			string.format("%s%d Level(s) -> %s", if delta > 0 then "+" else "", delta, targetName)
	elseif action == "setLevel" then
		local level = finiteInt(payload.amount, 1, ProgressionConfig.MAX_LEVEL)
		if not level then
			return nil, "Invalid level"
		end
		return function(data: Data)
			data.prog.level = level
			data.prog.xp = 0
			return true
		end,
			string.format("Set Level = %d -> %s", level, targetName)
	elseif action == "addXp" then
		local amount = finiteInt(payload.amount, 1, 1_000_000)
		if not amount then
			return nil, "Invalid XP amount"
		end
		return function(data: Data)
			Progress.addXp(data.prog, amount)
			return true
		end,
			string.format("+%s XP -> %s", fmt(amount), targetName)
	elseif action == "addStreak" then
		local delta =
			finiteInt(payload.amount, -ProgressionConfig.STREAK.max, ProgressionConfig.STREAK.max)
		if not delta or delta == 0 then
			return nil, "Invalid streak delta"
		end
		return function(data: Data)
			local nextStreak = math.clamp(data.prog.streak + delta, 0, ProgressionConfig.STREAK.max)
			data.prog.streak = nextStreak
			if nextStreak > data.prog.best then
				data.prog.best = nextStreak
			end
			return true
		end,
			string.format("%s%d Win Streak -> %s", if delta > 0 then "+" else "", delta, targetName)
	elseif action == "setStreak" then
		local value = finiteInt(payload.amount, 0, ProgressionConfig.STREAK.max)
		if not value then
			return nil, "Invalid streak value"
		end
		return function(data: Data)
			data.prog.streak = value
			if value > data.prog.best then
				data.prog.best = value
			end
			return true
		end,
			string.format("Set Streak = %d -> %s", value, targetName)
	elseif action == "addStats" then
		local wins = finiteInt(payload.wins or 0, 0, 100_000) or 0
		local kills = finiteInt(payload.kills or 0, 0, 100_000) or 0
		if wins == 0 and kills == 0 then
			return nil, "Nothing to add"
		end
		return function(data: Data)
			if wins > 0 then
				data.prog.wins = math.min(data.prog.wins + wins, 1_000_000_000)
				data.prog.matches = math.max(data.prog.matches + wins, data.prog.wins)
			end
			if kills > 0 then
				data.prog.kills = math.min(data.prog.kills + kills, 1_000_000_000)
			end
			return true
		end,
			string.format("+%d Wins / +%d Kills -> %s", wins, kills, targetName)
	elseif action == "grantSkin" then
		local gunId = str(payload.gun, 24)
		local line = str(payload.line, 32)
		if not gunId or not line or line == "Stock" or not Locker.valid(gunId, line) then
			return nil, "Invalid skin"
		end
		return function(data: Data)
			if not PlayerData.grantSkin(data, gunId, line) then
				return false, "Already owned"
			end
			return true
		end,
			string.format("Granted %s / %s -> %s", gunId, line, targetName)
	elseif action == "removeSkin" then
		local gunId = str(payload.gun, 24)
		local line = str(payload.line, 32)
		if not gunId or not line or line == "Stock" then
			return nil, "Invalid skin"
		end
		return function(data: Data)
			if not removeSkinFromData(data, gunId, line) then
				return false, "Not owned"
			end
			return true
		end,
			string.format("Removed %s / %s <- %s", gunId, line, targetName)
	elseif action == "grantLine" then
		local line = str(payload.line, 32)
		if not line or line == "Stock" then
			return nil, "Invalid line"
		end
		local pairsToGrant: { string } = {}
		for gunId in Weapons.list do
			if Locker.valid(gunId, line) then
				table.insert(pairsToGrant, gunId)
			end
		end
		if #pairsToGrant == 0 then
			return nil, "No skins in line"
		end
		return function(data: Data)
			local added = 0
			for _, gunId in pairsToGrant do
				if PlayerData.grantSkin(data, gunId, line) then
					added += 1
				end
			end
			if added == 0 then
				return false, "Line already owned"
			end
			return true
		end,
			string.format("Granted %s line (%d skins) -> %s", line, #pairsToGrant, targetName)
	elseif action == "removeLine" then
		local line = str(payload.line, 32)
		if not line or line == "Stock" then
			return nil, "Invalid line"
		end
		return function(data: Data)
			local removed = 0
			for gunId in Weapons.list do
				if removeSkinFromData(data, gunId, line) then
					removed += 1
				end
			end
			if removed == 0 then
				return false, "Line not owned"
			end
			return true
		end,
			string.format("Removed %s line <- %s", line, targetName)
	elseif action == "grantAllSkins" then
		return function(data: Data)
			local added = 0
			for gunId in Weapons.list do
				for _, line in Locker.linesFor(gunId) do
					if line ~= "Stock" and PlayerData.grantSkin(data, gunId, line) then
						added += 1
					end
				end
			end
			if added == 0 then
				return false, "All skins already owned"
			end
			return true
		end,
			string.format("Granted ALL skins -> %s", targetName)
	elseif action == "grantAllPowers" then
		-- The power deck (vault/01 Design/Loadout and Power Deck.md): every built power owned, the deck fills up
		-- to Config/Mods DECK_SIZE.
		return function(data: Data)
			local added = 0
			for _, id in ModsConfig.ORDER do
				if Mods.isBuilt(id) and ModLoadout.grant(data.mods, id) then
					added += 1
				end
			end
			if added == 0 then
				return false, "All powers already owned"
			end
			return true
		end,
			string.format("Granted ALL powers -> %s", targetName)
	elseif action == "grantNextPower" then
		return function(data: Data)
			for _, id in ModsConfig.ORDER do
				if Mods.isBuilt(id) and ModLoadout.grant(data.mods, id) then
					return true
				end
			end
			return false, "All powers already owned"
		end,
			string.format("Granted the next power -> %s", targetName)
	elseif action == "resetPowers" then
		return function(data: Data)
			data.mods = ModLoadout.clean(nil) -- the starter deck only
			return true
		end,
			string.format("Powers back to the starter deck <- %s", targetName)
	elseif action == "grantAllGuns" then
		-- The gun loadout (vault/01 Design/Loadout and Power Deck.md, step 2): every gun in the active set owned.
		return function(data: Data)
			local added = 0
			for _, list in { LoadoutConfig.PRIMARIES, LoadoutConfig.SECONDARIES } do
				for _, id in list do
					if not data.guns.owned[id] then
						data.guns.owned[id] = true
						added += 1
					end
				end
			end
			if added == 0 then
				return false, "All guns already owned"
			end
			return true
		end,
			string.format("Granted ALL guns -> %s", targetName)
	elseif action == "resetGuns" then
		return function(data: Data)
			data.guns = GunLoadout.clean(nil) -- the starter pair only
			return true
		end,
			string.format("Guns back to the starter pair <- %s", targetName)
	elseif action == "clearAllSkins" then
		return function(data: Data)
			table.clear(data.skins)
			return true
		end,
			string.format("Cleared ALL skins <- %s", targetName)
	elseif action == "addItem" then
		local itemId = str(payload.itemId, 32)
		local def = if itemId then Inventory.ITEMS[itemId] else nil
		local delta = finiteInt(payload.amount, -999, 999)
		if not itemId or not def or not delta or delta == 0 then
			return nil, "Invalid item"
		end
		return function(data: Data)
			local nextCount = math.clamp((data.items[itemId] or 0) + delta, 0, def.maxStack)
			if nextCount <= 0 then
				data.items[itemId] = nil
			else
				data.items[itemId] = nextCount
			end
			return true
		end,
			string.format(
				"%s%d %s -> %s",
				if delta > 0 then "+" else "",
				delta,
				def.name,
				targetName
			)
	elseif action == "setItem" then
		local itemId = str(payload.itemId, 32)
		local def = if itemId then Inventory.ITEMS[itemId] else nil
		local count = finiteInt(payload.amount, 0, if def then def.maxStack else 999)
		if not itemId or not def or not count then
			return nil, "Invalid item count"
		end
		return function(data: Data)
			if count <= 0 then
				data.items[itemId] = nil
			else
				data.items[itemId] = count
			end
			return true
		end,
			string.format("Set %s = %d -> %s", def.name, count, targetName)
	elseif action == "addAllCases" then
		local delta = finiteInt(payload.amount, -999, 999)
		if not delta or delta == 0 then
			return nil, "Invalid case count"
		end
		return function(data: Data)
			for itemId, def in Inventory.ITEMS do
				if def.kind == "Case" and not def.retired then
					local nextCount = math.clamp((data.items[itemId] or 0) + delta, 0, def.maxStack)
					if nextCount <= 0 then
						data.items[itemId] = nil
					else
						data.items[itemId] = nextCount
					end
				end
			end
			return true
		end,
			string.format(
				"%s%d of ALL Cases -> %s",
				if delta > 0 then "+" else "",
				delta,
				targetName
			)
	elseif action == "clearItems" then
		return function(data: Data)
			table.clear(data.items)
			return true
		end,
			string.format("Cleared ALL Backpack cases <- %s", targetName)
	elseif action == "rerollDaily" then
		return function(data: Data)
			data.daily = DailyRoll.roll(data.skins, data.guns, Economy.day(os.time()), Random.new())
			return true
		end,
			string.format("Rerolled Daily Shop -> %s", targetName)
	elseif action == "resetDailyFree" then
		return function(data: Data)
			data.buys.free = false
			table.clear(data.daily.bought)
			return true
		end,
			string.format("Reset Free Daily & Slots -> %s", targetName)
	elseif action == "toggleStarter" then
		local flag = payload.flag == true
		return function(data: Data)
			data.buys.starter = flag
			return true
		end,
			string.format("Starter Bought = %s -> %s", tostring(flag), targetName)
	elseif action == "resetGroupReward" then
		-- the Free Rewards gift can be claimed again (Services/GroupRewardService); coins and the case stay
		return function(data: Data)
			data.buys.group = false
			return true
		end,
			string.format("Reset Free Rewards Gift -> %s", targetName)
	elseif action == "resetLogin" then
		return function(data: Data)
			data.login.last = 0
			return true
		end,
			string.format("Unlocked Login Claim -> %s", targetName)
	elseif action == "taskSkip" then
		-- the task Path: show the next part (or set), paying nothing
		return function(data: Data)
			local t = data.tasks
			local set = Tasks.SETS[t.set]
			if not set then
				return false, "Path already done"
			end
			if t.part < #set.parts then
				t.part += 1
			else
				t.set += 1
				t.part = 1
			end
			t.n, t.seen = {}, {}
			return true
		end,
			string.format("Task Path: skipped a part -> %s", targetName)
	elseif action == "taskReset" then
		return function(data: Data)
			data.tasks = TaskPath.new()
			return true
		end,
			string.format("Task Path: reset to Recruit -> %s", targetName)
	elseif action == "resetProfile" then
		return function(data: Data)
			local fresh = PlayerData.clean(nil)
			data.coins = fresh.coins
			data.tickets = fresh.tickets
			data.items = fresh.items
			data.skins = fresh.skins
			data.mods = fresh.mods
			data.guns = fresh.guns
			data.prog = fresh.prog
			data.login = fresh.login
			data.daily =
				DailyRoll.roll(fresh.skins, fresh.guns, Economy.day(os.time()), Random.new())
			data.earn = fresh.earn
			data.onb = fresh.onb
			data.tasks = fresh.tasks
			data.buys.starter = false
			data.buys.free = false
			return true
		end,
			string.format("Reset Save to Default -> %s", targetName)
	elseif action == "startOnboarding" then
		return function(data: Data)
			local fresh = PlayerData.clean(nil)
			data.prog = fresh.prog
			data.onb = fresh.onb
			table.clear(data.skins)
			data.items[OnboardingConfig.FIRST_MATCH_CASE] = nil
			return true
		end,
			string.format("Started Full Onboarding -> %s", targetName)
	end
	return nil, "Unknown action"
end

-- Bots tab: difficulty and level of the bots in this server (match servers, pad
-- duels). The bots' owners live in ServerStorage.BotOwners (Services/BotService);
-- BotService watches "AdminDifficulty" / "AdminLevel" on them and applies them at
-- once. botId 0 = every bot here, and (difficulty) the default for bots made later.
local function botOwners(botId: number): { Instance }
	local folder = game:GetService("ServerStorage"):FindFirstChild("BotOwners")
	local found: { Instance } = {}
	if folder then
		for _, owner in folder:GetChildren() do
			if botId == 0 or StateValues.get(owner, "BotId") == botId then
				table.insert(found, owner)
			end
		end
	end
	return found
end

local BOT_ACTIONS: { [string]: boolean } = { botDifficulty = true, botLevel = true }

local function onBotRequest(player: Player, action: string, payload: { [string]: unknown })
	local botId = finiteInt(payload.botId, 0, 1e9)
	if not botId then
		reply(player, false, action, 0, "Invalid bot")
		return
	end
	local owners = botOwners(botId)
	local who = if botId == 0 then "all bots" else `bot #{botId}`
	if action == "botDifficulty" then
		local name = str(payload.difficulty, 16)
		if not name or not BotsConfig.PROFILES[name] then
			reply(player, false, action, 0, "Unknown difficulty")
			return
		end
		if botId == 0 then
			StateValues.set(workspace, "AdminBotDifficulty", name)
		elseif #owners == 0 then
			reply(player, false, action, 0, "That bot is gone")
			return
		end
		for _, owner in owners do
			StateValues.set(owner, "AdminDifficulty", name)
		end
		print(`[Admin] {player.Name}: {who} -> {name}`)
		reply(player, true, action, 0, `{who} ({#owners}) -> {string.upper(name)}`)
	else
		-- `level` sets it; `add` (the preset buttons) adds to each bot's own level
		local level = finiteInt(payload.level, 1, AdminConfig.BOT_LEVEL_MAX)
		local add = finiteInt(payload.add, -AdminConfig.BOT_LEVEL_MAX, AdminConfig.BOT_LEVEL_MAX)
		if not level and not add then
			reply(player, false, action, 0, "Invalid level")
			return
		end
		if #owners == 0 then
			reply(player, false, action, 0, "No bots here")
			return
		end
		for _, owner in owners do
			local now = StateValues.get(owner, "Level")
			local base = if typeof(now) == "number" then now else 1
			local new = level or math.clamp(base + (add or 0), 1, AdminConfig.BOT_LEVEL_MAX)
			StateValues.set(owner, "AdminLevel", new)
		end
		local what = if level
			then `level {level}`
			else `level {if (add or 0) >= 0 then "+" else ""}{add}`
		print(`[Admin] {player.Name}: {who} {what}`)
		reply(player, true, action, 0, `{who} ({#owners}) -> {what}`)
	end
end

local function onRequest(
	player: Player,
	actionRaw: unknown,
	targetIdRaw: unknown,
	payloadRaw: unknown
)
	-- Strict owner-only authorization gate
	if not AdminConfig.isAllowed(player.UserId) then
		return
	end
	if not limiter:allow(player, "Admin") then
		reply(player, false, tostring(actionRaw or ""), 0, "Rate limited — slow down")
		return
	end
	local action = str(actionRaw, 32)
	local targetUserId = finiteInt(targetIdRaw, 1, 1e12)
	if not action or not targetUserId then
		reply(player, false, action or "", 0, "Invalid request")
		return
	end
	local payload: { [string]: unknown } = if typeof(payloadRaw) == "table"
		then payloadRaw :: { [string]: unknown }
		else {}
	if BOT_ACTIONS[action] then
		onBotRequest(player, action, payload)
		return
	end
	if action == "toggleQuickMatch" then
		if not RunService:IsStudio() then
			reply(player, false, action, 0, "Studio only")
			return
		end
		local enabled = payload.flag == true
		workspace:SetAttribute("QuickMatch", enabled)
		local msg = if enabled
			then "QuickMatch ON (1-round matches)"
			else "QuickMatch OFF (normal rounds)"
		print(`[Admin] {player.Name}: {msg}`)
		reply(player, true, action, 0, msg)
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target then
		reply(player, false, action, targetUserId, "Target player left the server")
		return
	end
	if action == "quickLocalMatch" then
		if not ServerRole.isLobby() or ServerRole.isHosted() then
			reply(player, false, action, targetUserId, "Lobby server only")
			return
		end
		if PlayZone.get(target) ~= "Lobby" then
			reply(player, false, action, targetUserId, "Return to the Lobby first")
			return
		end
		local queueStatus = StateValues.get(target, "QueueStatus")
		if queueStatus == "searching" or queueStatus == "found" or queueStatus == "teleporting" then
			reply(player, false, action, targetUserId, "Leave queue first")
			return
		end
		local mode = str(payload.mode, 16) or "1v1"
		local teamSize = QUICK_MATCH_SIZES[mode]
		if not teamSize then
			reply(player, false, action, targetUserId, "Invalid mode")
			return
		end
		local host = getMatchHost()
		if not host then
			reply(player, false, action, targetUserId, "MatchHost unavailable")
			return
		end
		host.startDuel(mode, teamSize, { { target }, {} }, true, true)
		local msg = string.format(
			"Started instant %s bot match -> %s",
			string.upper(mode),
			target.DisplayName
		)
		print(`[Admin] {player.Name}: {msg}`)
		reply(player, true, action, targetUserId, msg)
		return
	end
	if action == "startOnboarding" then
		if PlayZone.get(target) ~= "Lobby" then
			reply(player, false, action, targetUserId, "Return to the Lobby first")
			return
		end
		local queueStatus = StateValues.get(target, "QueueStatus")
		if queueStatus == "found" or queueStatus == "teleporting" then
			reply(player, false, action, targetUserId, "Match is already starting")
			return
		end
	end

	local change, summary = buildMutation(action, payload, target.DisplayName)
	if not change then
		reply(player, false, action, targetUserId, summary or "Invalid arguments")
		return
	end

	local ok, reason = PlayerDataService.transact(target, PlayerDataService.newTxId(), change, true)
	if ok then
		if action == "startOnboarding" or action == "resetProfile" then
			LockerService.reset(target)
			QueueService.resetOnboarding(target)
			OnboardingService.reset(target)
			local seq = StateValues.get(target, "OnbResetSeq")
			StateValues.set(target, "OnbResetSeq", (if typeof(seq) == "number" then seq else 0) + 1)
		end
		print(`[Admin] {player.Name} ({player.UserId}): {summary}`)
		reply(player, true, action, targetUserId, summary or "Done")
	else
		reply(
			player,
			false,
			action,
			targetUserId,
			string.format("%s failed (%s)", action, reason or "error")
		)
	end
end

function AdminService.init()
	adminEvent = LobbyNet.event("AdminEvent")
	LobbyNet.event("AdminRequest").OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(p: Player)
		limiter:forget(p)
	end)
end

return AdminService
