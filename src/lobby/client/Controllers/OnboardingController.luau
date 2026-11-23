--!strict
-- The new-player flow in the lobby (vault/05 Production/Handoff - Onboarding and
-- Bots.md → Phase 2; rules in Shared/Onboarding, numbers in Config/Onboarding):
--  * first join: queued for Beginner 2v2 once the loading screen closes (no menu);
--  * while new, PLAY queues Beginner 2v2 straight away (its sub-line says so);
--  * the "Join the queue to start playing!" bubble over PLAY while idle;
--  * the HUD unlocks by matches played (Party after 1, Shop and Backpack after 3),
--    each with one NEW callout until that menu is opened;
--  * the favorite prompt back in the lobby after match 1 (Shared/FavoritePrompt).
-- It only reads the server-published state (Matches, Level, OnbSeen, ...) and asks:
-- the server decides the queue (QueueService refuses Beginner at level 10+) and
-- stores what was asked or seen (Services/OnboardingService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FavoritePrompt = require(ReplicatedStorage.Shared.FavoritePrompt)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local OnbConfig = require(ReplicatedStorage.Shared.Config.Onboarding)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
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
local favAsked = false -- the lobby ask, once per session
local seenSent: { [number]: boolean } = {} -- NEW bits already reported this session
local calloutFor: string? = nil

local function num(name: string, default: number): number
	local v = StateValues.get(player, name)
	return if typeof(v) == "number" and v == v then v else default
end

local function ready(): boolean
	-- in the lobby only (a hosted server puts an arriving player straight into their queued match)
	return StateValues.get(player, "DataReady") == true
		and player:GetAttribute("LoadingScreen") ~= true
		and PlayZone.get(player) == "Lobby"
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
	if not b or seenSent[b] then
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

-- HUD parts, the NEW callout, PLAY's shortcut and the bubble, from the current state.
local function apply()
	if StateValues.get(player, "DataReady") ~= true then
		return -- the save isn't here yet: leave the full HUD as built
	end
	local matches, level = num("Matches", 0), num("Level", 1)
	for _, u in OnbConfig.UNLOCKS do
		LobbyHudView.setUnlocked(u.id, Onboarding.unlocked(u.id, matches))
	end
	local due: string? = nil
	local seen = seenBits()
	for _, u in OnbConfig.UNLOCKS do
		if Onboarding.newPop(u.id, matches, seen) then
			due = u.id
			break
		end
	end
	if due ~= calloutFor then
		calloutFor = due
		LobbyHudView.callout(due, if due then OnbConfig.NEW_TEXT else nil)
	end
	local shortcut = Onboarding.playShortcut(matches, level)
	LobbyHudView.setPlay(
		if shortcut then playNew else nil,
		if shortcut then OnbConfig.PLAY_SUB_NEW else nil
	)
	LobbyHudView.bubble(Onboarding.bubble(matches), OnbConfig.BUBBLE_TEXT)
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

-- Back in the lobby after match 1: ask to favorite (once).
local function tryFavorite()
	if favAsked or not ready() then
		return
	end
	local o, matches = FavoritePrompt.state()
	if not Onboarding.favAsk(o, matches, "lobby") then
		return
	end
	favAsked = true
	task.delay(OnbConfig.FAV_LOBBY_DELAY, function()
		-- not over MATCH FOUND or a teleport
		local status = QueueState.status()
		if status == "found" or status == "teleporting" then
			favAsked = false -- next time back here
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
	for _, name in { "DataReady", "Matches", "Level", "OnbSeen", "OnbFav", "OnbFavDone" } do
		StateValues.changed(player, name):Connect(refresh)
	end
	player:GetAttributeChangedSignal("LoadingScreen"):Connect(refresh)
	player:GetAttributeChangedSignal(PlayZone.ATTRIBUTE):Connect(refresh) -- back in the lobby after a match
	-- opening an unlocked menu clears its NEW callout for good
	Router.onChanged(function(current: string?)
		for id, menu in MENU_OF do
			if current == menu and calloutFor == id then
				markSeen(id)
				apply()
			end
		end
		LobbyHudView.placeBubble()
	end)
	QueueState.onChanged(LobbyHudView.placeBubble)
	refresh()
end

return OnboardingController
