--!strict
-- The new-player flow in the lobby (vault/05 Production/Handoff - Onboarding and
-- Bots.md → Phase 2; rules in Shared/Onboarding, numbers in Config/Onboarding):
--  * first join: queued for Beginner 2v2 once the loading screen closes (no menu);
--  * while new, PLAY queues Beginner 2v2 straight away (its sub-line says so);
--  * the "Join the queue to start playing!" bubble over PLAY while idle;
--  * the HUD unlocks by matches played (Config/Onboarding UNLOCKS: all after match 2),
--    each with one NEW callout until that menu is opened;
--  * no free case after match 1 any more (owner 2026-11-27: too strong, RIVALS doesn't);
--    an old save's unopened Starter Case just sits in the Backpack;
--  * the favorite prompt back in the lobby (Shared/FavoritePrompt).
-- It only reads the server-published state (Matches, Level, OnbSeen, ...) and asks:
-- the server decides the queue (QueueService refuses Beginner at level 10+) and
-- stores what was asked or seen (Services/OnboardingService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FavoritePrompt = require(ReplicatedStorage.Shared.FavoritePrompt)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local OnbConfig = require(ReplicatedStorage.Shared.Config.Onboarding)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local Onboarding = require(ReplicatedStorage.Shared.Onboarding)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local LobbyHudView = require(script.Parent.Parent.Util.LobbyHudView)
local QueueState = require(script.Parent.Parent.Util.QueueState)
local Router = require(script.Parent.Parent.Util.Router)

local OnboardingController = {}

local player = Players.LocalPlayer

-- The menu that counts as "opened" for each unlock's NEW callout.
local MENU_OF: { [string]: string } = { Party = "Party", Shop = "Shop", Backpack = "Backpack" }

local autoQueued = false -- once per session
local favAskedFor: number? = nil -- the o.fav count already prompted this session
local seenSent: { [number]: boolean } = {} -- NEW bits already reported this session
local calloutFor: string? = nil
local calloutTextShown: string? = nil

local function num(name: string, default: number): number
	local v = StateValues.get(player, name)
	return if typeof(v) == "number" and v == v then v else default
end

local function ready(): boolean
	-- in the lobby only, once loading, client controllers, and the lobby character are all ready
	local char = player.Character
	return game:IsLoaded()
		and StateValues.get(player, "DataReady") == true
		and player:GetAttribute("LobbyClientReady") == true
		and player:GetAttribute("LoadingScreen") == false
		and player:GetAttribute("DuelLoading") ~= true
		and player:GetAttribute("CaseOpeningActive") ~= true
		and player:GetAttribute("CaseRevealOpen") ~= true
		and PlayZone.get(player) == "Lobby"
		and char ~= nil
		and char:FindFirstChild("HumanoidRootPart") ~= nil
end

local function seenBits(): number
	local bits = num("OnbSeen", 0)
	for b in seenSent do
		bits = bit32.bor(bits, b)
	end
	return bits
end

local function markSeen(id: string)
	local b = Onboarding.bitOf(id)
	if not b or seenSent[b] or Onboarding.hasBit(seenBits(), b) then
		return
	end
	seenSent[b] = true
	LobbyNet.event("OnboardingRequest"):FireServer("seen", b)
end

-- PLAY while new: queue Beginner 2v2 instead of opening the menu.
local function playNew(): boolean
	if not Onboarding.playShortcut(num("Matches", 0), num("Level", 1)) then
		return false
	end
	if not QueueState.isLeader() then
		return false -- the menu explains "your party leader starts"
	end
	QueueState.join(OnbConfig.BEGINNER_MODE)
	return true
end

local function openingOrRevealing(): boolean
	return player:GetAttribute("CaseOpeningActive") == true
		or player:GetAttribute("CaseRevealOpen") == true
end

-- HUD parts, the NEW callout, PLAY's shortcut and the bubble, from the current state.
local function apply()
	if StateValues.get(player, "DataReady") ~= true then
		return -- the save isn't here yet: leave the full HUD as built
	end
	local matches, level = num("Matches", 0), num("Level", 1)
	for _, u in OnbConfig.UNLOCKS do
		LobbyHudView.setUnlocked(u.id, Onboarding.unlocked(u.id, matches))
	end
	local blocking = openingOrRevealing()

	local dueId: string? = nil
	local dueText: string? = nil
	if not blocking then
		local seen = seenBits()
		for _, u in OnbConfig.UNLOCKS do
			if Onboarding.newPop(u.id, matches, seen) then
				dueId = u.id
				dueText = OnbConfig.NEW_TEXT
				break
			end
		end
	end
	if dueId ~= calloutFor or dueText ~= calloutTextShown then
		calloutFor = dueId
		calloutTextShown = dueText
		LobbyHudView.callout(dueId, dueText)
	end
	LobbyHudView.highlight(nil)
	local shortcut = Onboarding.playShortcut(matches, level)
	LobbyHudView.setPlay(
		if shortcut then playNew else nil,
		if shortcut then OnbConfig.PLAY_SUB_NEW else nil
	)
	local showBubble = not blocking and Onboarding.bubble(matches)
	LobbyHudView.bubble(showBubble, OnbConfig.BUBBLE_TEXT)
end

-- First join: straight into Beginner 2v2 once the loading screen is gone.
local function tryAutoQueue()
	if autoQueued or not ready() then
		return
	end
	if not Onboarding.autoQueue(num("Matches", 0), num("Level", 1)) then
		autoQueued = true -- not new: never on this session
		return
	end
	autoQueued = true
	task.delay(OnbConfig.AUTO_QUEUE_DELAY, function()
		if not ready() then
			autoQueued = false
			return
		end
		-- still new (re-read: Matches can land just after DataReady), still free to queue:
		-- idle (Play Again may already have queued us), leading, no menu
		if
			Onboarding.autoQueue(num("Matches", 0), num("Level", 1))
			and QueueState.status() == "idle"
			and QueueState.isLeader()
			and Router.current() == nil
		then
			QueueState.join(OnbConfig.BEGINNER_MODE)
		end
	end)
end

-- Back in the lobby after match 2 (or match 3 if declined): ask to favorite.
local function tryFavorite()
	if not ready() then
		return
	end
	local o, matches = FavoritePrompt.state()
	if favAskedFor == o.fav or not Onboarding.favAsk(o, matches, "lobby") then
		return
	end
	favAskedFor = o.fav
	task.delay(OnbConfig.FAV_LOBBY_DELAY, function()
		-- not over MATCH FOUND, a teleport, or leaving the lobby
		local status = QueueState.status()
		if not ready() or status == "found" or status == "teleporting" then
			favAskedFor = nil -- try again next time back in the lobby
			return
		end
		FavoritePrompt.maybeAsk("lobby")
	end)
end

local function refresh()
	apply()
	tryAutoQueue()
	tryFavorite()
end

function OnboardingController.init() end

function OnboardingController.start()
	for _, name in
		{
			"DataReady",
			"Matches",
			"Level",
			"OnbSeen",
			"OnbFav",
			"OnbFavDone",
		}
	do
		StateValues.changed(player, name):Connect(refresh)
	end
	task.spawn(function()
		local replica = PlayerData.replica(player)
		if replica then
			replica.Changed:Connect(refresh)
			refresh()
		end
	end)
	for _, attr in
		{
			"LoadingScreen",
			"LobbyClientReady",
			"DuelLoading",
			"CaseOpeningActive",
			"CaseRevealOpen",
			PlayZone.ATTRIBUTE,
		}
	do
		player:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	local function watchCharacter(char: Model)
		task.spawn(function()
			if
				char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 10)
			then
				refresh()
			end
		end)
	end
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
	if not game:IsLoaded() then
		task.spawn(function()
			game.Loaded:Wait()
			refresh()
		end)
	end
	-- opening an unlocked menu clears its NEW callout for good
	Router.onChanged(function(current: string?)
		for id, menu in MENU_OF do
			if current == menu then
				markSeen(id)
				apply()
			end
		end
		LobbyHudView.placeBubble()
	end)
	QueueState.onChanged(LobbyHudView.placeBubble)
	StateValues.changed(player, "OnbResetSeq"):Connect(function()
		autoQueued = false
		favAskedFor = nil
		table.clear(seenSent)
		calloutFor = nil
		calloutTextShown = nil
		LobbyHudView.callout(nil, nil)
		LobbyHudView.highlight(nil)
		player:SetAttribute("CaseOpeningActive", nil)
		player:SetAttribute("CaseRevealOpen", nil)
		if Router.current() ~= nil then
			Router.close()
		end
		task.defer(refresh)
	end)
	refresh()
end

return OnboardingController
