--!strict
-- Client: ask the player to favorite the game, once, when the onboarding rules say an
-- ask is due (Shared/Onboarding.favAsk; vault/05 Production/Handoff - Onboarding and
-- Bots.md). Used by the lobby (after match 1) and the match client (during match 2,
-- if the first ask was declined). The result goes to the server (OnboardingRequest
-- "favAsked"), which counts the ask and remembers a favorite, so it is never asked
-- twice for the same step, here or on another server.
--
-- AvatarEditorService:PromptSetFavorite doesn't yield: the answer arrives on
-- PromptSetFavoriteCompleted (LihFolk: AvatarEditorService and In-Game Avatar Editors).
-- Already a favorite (GetFavoriteAsync, pcall'd): no prompt, reported as favorited.

local AvatarEditorService = game:GetService("AvatarEditorService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Onboarding = require(ReplicatedStorage.Shared.Onboarding)
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local FavoritePrompt = {}

local ANSWER_TIMEOUT = 90 -- seconds; an unanswered prompt counts as declined
local busy = false

local function num(v: any, default: number): number
	return if typeof(v) == "number" and v == v then v else default
end

-- The saved onboarding state as published on the local player.
function FavoritePrompt.state(): (Onboarding.Onb, number)
	local p = Players.LocalPlayer
	return {
		fav = num(StateValues.get(p, "OnbFav"), 0),
		favDone = StateValues.get(p, "OnbFavDone") ~= false,
		seen = num(StateValues.get(p, "OnbSeen"), 0),
	},
		num(StateValues.get(p, "Matches"), 0)
end

local function report(favorited: boolean)
	local folder = ReplicatedStorage:FindFirstChild("LobbyRemotes")
	local remote = folder and folder:FindFirstChild("OnboardingRequest")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer("favAsked", favorited)
	end
end

-- Asks now if an ask is due `where` ("lobby" | "match"). Yields until answered.
function FavoritePrompt.maybeAsk(where: string)
	if busy or StateValues.get(Players.LocalPlayer, "DataReady") ~= true then
		return
	end
	local o, matches = FavoritePrompt.state()
	if not Onboarding.favAsk(o, matches, where) then
		return
	end
	busy = true
	local placeId = game.PlaceId
	local okFav, already = pcall(function()
		return AvatarEditorService:GetFavoriteAsync(placeId, Enum.AvatarItemType.Asset)
	end)
	if okFav and already == true then
		report(true)
		busy = false
		return
	end
	local answer: Enum.AvatarPromptResult? = nil
	local conn = AvatarEditorService.PromptSetFavoriteCompleted:Connect(function(result)
		answer = result
	end)
	local okPrompt, err = pcall(function()
		AvatarEditorService:PromptSetFavorite(placeId, Enum.AvatarItemType.Asset, true)
	end)
	if not okPrompt then
		conn:Disconnect()
		busy = false
		warn(`[Onboarding] favorite prompt failed: {err}`) -- not counted: it never showed
		return
	end
	local t0 = os.clock()
	while answer == nil and os.clock() - t0 < ANSWER_TIMEOUT do
		task.wait(0.25)
	end
	conn:Disconnect()
	report(answer == Enum.AvatarPromptResult.Success)
	busy = false
end

return FavoritePrompt
