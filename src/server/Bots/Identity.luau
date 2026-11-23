--!strict
-- Match-server avatar cache. Only fitted models leave this module.

local Context = require(script.Parent.Parent.Context) -- this match (MatchKit/Context)
local Players = Context.players
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Locker = require(Shared.Locker)
local MatchBody = require(Shared.MatchBody)
local Weapons = require(Shared.Config.Weapons)
local Config = require(script.Parent.AppearanceConfig)

local Identity = {}
local rng = Random.new()
local fallbackRig = script.Parent.FallbackRig :: Model

local playerSeen: { [number]: boolean } = {}
local friendNames: { [string]: boolean } = {}
local candidates: { [number]: boolean } = {}
local sourceNames: { [number]: { [string]: boolean } } = {}
local attempted: { [number]: boolean } = {}
local ready: { [number]: Model } = {}
local used: { [number]: boolean } = {}
local workers = 0
local friendAttempts = 0
local backupAttempts = 0
local readyCount = 0
local pendingFriends = 0

local function choose<T>(items: { T }): T
	return items[rng:NextInteger(1, #items)]
end

local function build(description: HumanoidDescription): Model?
	local ok, model = pcall(
		Players.CreateHumanoidModelFromDescriptionAsync,
		Players,
		description,
		Enum.HumanoidRigType.R15
	)
	description:Destroy()
	if ok and model then
		local head = model:FindFirstChild("Head")
		local root = model:FindFirstChild("HumanoidRootPart")
		-- A body part that didn't load comes back as a default limb: no stand-in like that (MatchBody.missingParts).
		if
			head
			and head:IsA("BasePart")
			and root
			and root:IsA("BasePart")
			and model:FindFirstChildOfClass("Humanoid")
			and #MatchBody.missingParts(model) == 0
		then
			return model
		end
		model:Destroy()
	end
	return nil
end

local function available(id: number): boolean
	return not attempted[id] and not playerSeen[id]
end

local function nextSource(): number?
	local pool = {}
	if friendAttempts < Config.FRIEND_ATTEMPTS then
		for id in candidates do
			if available(id) then
				table.insert(pool, id)
			end
		end
	end
	if #pool == 0 and pendingFriends == 0 and backupAttempts < Config.BACKUP_ATTEMPTS then
		for _, id in Config.BACKUP_USER_IDS do
			if id > 0 and id % 1 == 0 and available(id) then
				table.insert(pool, id)
			end
		end
	end
	return if #pool > 0 then choose(pool) else nil
end

local function warm()
	while workers < Config.AVATAR_WORKERS and readyCount + workers < Config.AVATAR_TEMPLATES do
		local id = nextSource()
		if not id then
			return
		end
		attempted[id] = true
		if candidates[id] then
			friendAttempts += 1
		else
			backupAttempts += 1
		end
		workers += 1
		task.spawn(function()
			local ok, own = pcall(Players.GetHumanoidDescriptionFromUserIdAsync, Players, id)
			if ok and own then
				local fitted, desc = pcall(MatchBody.description, own)
				own:Destroy()
				local model = if fitted then build(desc) else nil
				if model then
					if playerSeen[id] then
						model:Destroy()
					else
						ready[id] = model
						readyCount += 1
					end
				end
			end
			workers -= 1
			warm()
		end)
	end
end

function Identity.collect(player: Player)
	local userId = player.UserId
	if userId < 1 or playerSeen[userId] then
		return
	end
	playerSeen[userId] = true
	local cached = ready[userId]
	if cached then
		cached:Destroy()
		ready[userId] = nil
		readyCount -= 1
	end
	pendingFriends += 1
	task.spawn(function()
		pcall(function()
			local pages = Players:GetFriendsAsync(userId)
			local count = 0
			for page = 1, Config.FRIEND_PAGES do
				for _, friend in pages:GetCurrentPage() do
					if count >= Config.FRIENDS_PER_PLAYER then
						break
					end
					local names = {}
					for _, name in { friend.Username or "", friend.DisplayName or "" } do
						local lower = string.lower(name)
						friendNames[lower] = true
						names[lower] = true
					end
					if typeof(friend.Id) == "number" and friend.Id > 0 then
						candidates[friend.Id] = true
						sourceNames[friend.Id] = names
						count += 1
					end
				end
				warm()
				if
					pages.IsFinished
					or count >= Config.FRIENDS_PER_PLAYER
					or page == Config.FRIEND_PAGES
				then
					break
				end
				pages:AdvanceToNextPageAsync()
			end
		end)
		pendingFriends -= 1
		warm()
	end)
end

function Identity.prefetch()
	task.delay(Config.PREFETCH_DELAY, warm)
end

function Identity.name(inUse: { [string]: boolean }): string
	local blocked = table.clone(friendNames)
	for _, player in Players:GetPlayers() do
		blocked[string.lower(player.Name)] = true
		blocked[string.lower(player.DisplayName)] = true
	end
	local options = {}
	for _, name in Config.NAMES do
		if not blocked[string.lower(name)] and not inUse[name] then
			table.insert(options, name)
		end
	end
	if #options > 0 then
		return choose(options)
	end
	local serial = 100
	while inUse["PaperComet" .. serial] or blocked["papercomet" .. serial] do
		serial += 1
	end
	return "PaperComet" .. serial
end

function Identity.profile(): (number, { [string]: string }, boolean, string)
	local weight = 0
	for _, group in Config.PROFILES do
		weight += group.weight
	end
	local roll = rng:NextInteger(1, weight)
	local selected = Config.PROFILES[1]
	for _, group in Config.PROFILES do
		roll -= group.weight
		if roll <= 0 then
			selected = group
			break
		end
	end
	local level = rng:NextInteger(selected.level[1], selected.level[2])
	local count = rng:NextInteger(selected.skins[1], selected.skins[2])
	local starterSkin = count > 0 and rng:NextNumber() < Config.STARTER_SKIN_CHANCE
	if starterSkin then
		count -= 1
	end
	local skins: { [string]: string } = {}
	local guns = {}
	for id, weapon in Weapons.list do
		if starterSkin and weapon.class == "Sidearm" then
			continue
		end
		local options = Locker.linesFor(id)
		if options[1] == "Stock" then
			table.remove(options, 1)
			if #options > 0 then
				table.insert(guns, { id = id, lines = options })
			end
		end
	end
	for _ = 1, math.min(count, #guns) do
		local gun = table.remove(guns, rng:NextInteger(1, #guns))
		skins[gun.id] = choose(gun.lines)
	end
	return level, skins, starterSkin, choose(Config.DEVICES)
end

function Identity.starterSkin(id: string): string?
	local lines = Locker.linesFor(id)
	if lines[1] == "Stock" and #lines > 1 then
		return lines[rng:NextInteger(2, #lines)]
	end
	return nil
end

local function takeReady(name: string): (Model?, string?, number?)
	local friends, backups = {}, {}
	local lower = string.lower(name)
	for id in ready do
		local names = sourceNames[id]
		if not used[id] and not playerSeen[id] and not (names and names[lower]) then
			table.insert(if candidates[id] then friends else backups, id)
		end
	end
	local options = if #friends > 0 then friends else backups
	if #options > 0 then
		local id = choose(options)
		used[id] = true
		return ready[id]:Clone(), if candidates[id] then "Friend" else "Backup", id
	end
	return nil, nil, nil
end

-- Seats prepare during the map vote. The bundled rig needs no asset lookup.
function Identity.avatar(name: string, needed: () -> boolean): (Model?, string, number?)
	-- Also take a current roster snapshot here, in case the first draft
	-- begins before the join listener observed every player.
	for _, player in Players:GetPlayers() do
		Identity.collect(player)
	end
	local deadline = os.clock() + Config.FIRST_SPAWN_LOOK_WAIT
	while needed() do
		local model, source, userId = takeReady(name)
		if model and source then
			return model, source, userId
		end
		if (pendingFriends == 0 and workers == 0) or os.clock() >= deadline then
			break
		end
		task.wait(0.05)
	end

	if not needed() then
		return nil, "Cancelled", nil
	end
	local fallback = fallbackRig:Clone()
	local colors = fallback:FindFirstChildOfClass("BodyColors") :: BodyColors
	local skin = Color3.fromHex(string.format("%06x", choose(Config.FALLBACK_SKIN)))
	local top = Color3.fromHex(string.format("%06x", choose(Config.FALLBACK_TOP)))
	local pants = Color3.fromHex(string.format("%06x", choose(Config.FALLBACK_PANTS)))
	colors.HeadColor3, colors.LeftArmColor3, colors.RightArmColor3 = skin, skin, skin
	colors.TorsoColor3 = top
	colors.LeftLegColor3, colors.RightLegColor3 = pants, pants
	return fallback, "Generated", nil
end

function Identity.poolStatus(): (number, number, number)
	return readyCount, friendAttempts + backupAttempts, pendingFriends
end

function Identity.releaseLooks()
	table.clear(used)
end

return Identity
