--!strict
-- The Free Rewards popup (vault/02 Art/Lobby Holograms.md), opened by the green lobby hologram
-- (Controllers/LobbyHolograms). Studio-built (tools/studio/BuildFreeRewards.luau): ServerStorage.LobbyUI.FreeRewards.
--   JOIN      Roblox's own join prompt for the game's group (GroupService:PromptJoinAsync)
--   CLAIM     GroupRewardClaim; the server asks Roblox about the group and pays once (Services/GroupRewardService)
-- "Like the game" is only asked: no button, no check, no reward tied to it (platforms prohibit rewarding ratings).
-- The gift's numbers come from Config/Economy.GROUP_REWARD.

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Inventory = require(ReplicatedStorage.Shared.Config.Inventory)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local UiSfx = require(ReplicatedStorage.Shared.UiSfx)
local UiWait = require(ReplicatedStorage.Shared.Util.UiWait)
local need = UiWait.child
local LobbyKit = require(script.Parent.Parent.Util.LobbyKit)
local LobbyHud = require(script.Parent.LobbyHud)

local FreeRewardsController = {}

local REWARD = Economy.GROUP_REWARD
local player = Players.LocalPlayer

local gui: ScreenGui? = nil
local actionLabel: TextLabel
local status: TextLabel
local joinButton: GuiObject
local sending = false
local joinedNow = false

local function claimed(): boolean
	return StateValues.get(player, "GroupRewardClaimed") == true
end

local function itemName(): string
	local def = Inventory.ITEMS[REWARD.item]
	return if def then def.name else "A CASE"
end

local function render()
	if not gui then
		return
	end
	local done = claimed()
	joinButton.Visible = not done
	if done then
		actionLabel.Text = "CLAIMED"
		status.Text = "THANKS FOR JOINING! YOUR GIFT IS IN YOUR BACKPACK"
	elseif sending then
		actionLabel.Text = "CHECKING..."
	else
		actionLabel.Text = "CLAIM"
		status.Text = if joinedNow then "YOU'RE IN! CLAIM YOUR GIFT" else ""
	end
end

local function join()
	if claimed() then
		return
	end
	task.spawn(function()
		local ok, result = pcall(function()
			return GroupService:PromptJoinAsync(REWARD.group)
		end)
		if
			ok
			and (
				result == Enum.GroupMembershipStatus.Joined
				or result == Enum.GroupMembershipStatus.AlreadyMember
			)
		then
			joinedNow = true
		elseif not ok then
			LobbyHud.toast("Join the group from the game's page, then claim", "info")
		end
		render()
	end)
end

local function claim()
	if claimed() or sending then
		return
	end
	if not PlayerData.ready(player) then
		LobbyHud.toast("Your save is still loading", "info")
		return
	end
	sending = true
	render()
	LobbyNet.event("GroupRewardClaim"):FireServer()
	task.delay(10, function()
		if sending then
			sending = false -- no answer: let them try again
			render()
		end
	end)
end

local function onEvent(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	sending = false
	if payload.kind == "claimed" then
		UiSfx.cue("Confirm")
		LobbyHud.toast(`GIFT CLAIMED: {REWARD.coins} COINS + {itemName()}`, "info")
	elseif payload.kind == "notMember" then
		UiSfx.cue("PurchaseDenied")
		status.Text = "JOIN THE GROUP FIRST, THEN CLAIM"
		LobbyHud.toast("Join the group first, then claim", "error")
		return
	elseif payload.kind == "failed" then
		UiSfx.cue("PurchaseDenied")
		LobbyHud.toast(
			if typeof(payload.text) == "string" then payload.text else "Couldn't claim, try again",
			"error"
		)
	end
	render()
end

function FreeRewardsController.init()
	local playerGui = player:WaitForChild("PlayerGui")
	local g = playerGui:WaitForChild("FreeRewards", 15)
	if not (g and g:IsA("ScreenGui")) then
		warn("[FreeRewards] LobbyUI.FreeRewards missing (tools/studio/BuildFreeRewards.luau)")
		return
	end
	gui = g
	g.Enabled = false
	local canvas = need(g, "Canvas") :: Frame
	local card = need(canvas, "Card") :: Frame
	local action = need(card, "Action") :: TextButton
	actionLabel = need(action, "Label") :: TextLabel
	status = need(card, "Status") :: TextLabel
	joinButton = need(need(card, "Join"), "JoinButton") :: TextButton
	-- the gift's words follow the config
	local gift = need(card, "Gift")
	local coins = need(need(gift, "Coins"), "Amount") :: TextLabel
	coins.Text = `{REWARD.coins} COINS`
	local case = need(need(gift, "Case"), "Amount") :: TextLabel
	case.Text = itemName()
	LobbyKit.button(action, claim)
	LobbyKit.button(joinButton :: GuiButton, join)
	LobbyKit.page({
		name = "FreeRewards",
		gui = g,
		wash = need(g, "Wash") :: Frame,
		close = need(canvas, "Close") :: GuiButton,
		focus = function()
			return if claimed() then action else joinButton
		end,
		onOpen = function()
			render()
		end,
	} :: any)
end

function FreeRewardsController.start()
	LobbyNet.event("GroupRewardEvent").OnClientEvent:Connect(onEvent)
	StateValues.anyChanged(player):Connect(function(name: string)
		if name == "GroupRewardClaimed" then
			render()
		end
	end)
end

return FreeRewardsController
