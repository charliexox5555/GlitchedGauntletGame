--!strict
-- The Rewards screen (vault/02 Art/UI Lobby Overhaul.md → Missing screens),
-- a stub like RIVALS' Rewards page: Studio-built StarterGui.Rewards +
-- UiTemplates.Lobby.RewardRow (tools/studio/BuildProfileRewards.luau), rows
-- from Lobby/RewardsCatalog, opened by the top bar's gift button.
-- What works today is Roblox's own prompts (favourite, game invite,
-- notifications opt-in); the coins wait for the economy and the screen says
-- so. No remotes: nothing is granted here.

local AvatarEditorService = game:GetService("AvatarEditorService")
local ExperienceNotificationService = game:GetService("ExperienceNotificationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local SocialService = game:GetService("SocialService")

local RewardsCatalog = require(ReplicatedStorage.Lobby.RewardsCatalog)
local UiMotion = require(ReplicatedStorage.Shared.UiMotion)
local LobbyKit = require(script.Parent.Parent.Util.LobbyKit)
local Plates = require(script.Parent.Parent.Util.Plates)
local Router = require(script.Parent.Parent.Util.Router)
local LobbyHud = require(script.Parent.LobbyHud)

local RewardsController = {}

local player = Players.LocalPlayer
local C = LobbyKit.C

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

local function run(action: RewardsCatalog.Action)
	if action == "favorite" then
		local ok = pcall(function()
			AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
		end)
		if not ok then
			LobbyHud.toast("Favourite it from the game's page", "info")
		end
	elseif action == "invite" then
		local ok, can = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if ok and can then
			pcall(function()
				SocialService:PromptGameInvite(player)
			end)
		else
			LobbyHud.toast("Invites aren't available here", "info")
		end
	elseif action == "notify" then
		local ok, can = pcall(function()
			return ExperienceNotificationService:CanPromptOptInAsync()
		end)
		if ok and can then
			pcall(function()
				ExperienceNotificationService:PromptOptIn()
			end)
		else
			LobbyHud.toast("Notifications are already on, or not available here", "info")
		end
	else
		LobbyHud.toast("Coming soon", "info")
	end
end

function RewardsController.init()
	local g = player:WaitForChild("PlayerGui"):WaitForChild("Rewards", 15)
	local folder = ReplicatedStorage:WaitForChild("UiTemplates", 15)
	local lobby = folder and folder:WaitForChild("Lobby", 15)
	local tpl = lobby and lobby:WaitForChild("RewardRow", 15)
	if not (g and g:IsA("ScreenGui") and tpl and tpl:IsA("Frame")) then
		warn(
			"[Rewards] StarterGui.Rewards or its template missing (tools/studio/BuildProfileRewards.luau)"
		)
		return
	end
	local gui = g
	gui.Enabled = false
	local canvas = child(gui, "Canvas") :: Frame
	local list = child(canvas, "List") :: ScrollingFrame
	local first: GuiButton? = nil
	for i, r in RewardsCatalog do
		local row = LobbyKit.slot(tpl, list, function(f: Frame)
			f.Name = "Reward_" .. r.id
			f.LayoutOrder = i
			StateValues.set(f, "Slot", true)
			local title = child(f, "Title") :: TextLabel
			title.Text = r.title
			local sub = child(f, "Sub") :: TextLabel
			sub.Text = r.sub
			local reward = child(f, "Reward") :: Frame
			reward.Visible = r.coins > 0
			LobbyKit.price(reward, tostring(r.coins))
			-- full gold: the screen's note says the coins come with the economy
			local go = child(f, "Go") :: TextButton
			local label = child(go, "Label") :: TextLabel
			local live = r.action ~= "soon"
			go.BackgroundColor3 = if live then C.white else C.navyHi
			label.Text = if live then "GO" else "SOON"
			label.TextColor3 = if live then C.ink else C.muted
		end)
		Plates.deepen(row)
		local go = child(row, "Go") :: TextButton
		LobbyKit.button(go, function()
			run(r.action)
		end)
		if not first and r.action ~= "soon" then
			first = go
		end
	end
	Plates.deepen(gui)
	LobbyKit.page({
		name = "Rewards",
		gui = gui,
		canvas = canvas,
		design = Vector2.new(1920, 1080),
		wash = child(gui, "Wash") :: Frame,
		close = child(canvas, "Close") :: GuiButton,
		focus = function()
			return first
		end,
		-- phones: the title and a scrolling list fill the screen (about 0.65
		-- zoom on a 812 x 375 phone); GO grows to stay a 44 px+ target
		phone = {
			region = Rect.new(420, 40, 1500, 620),
			arrange = function()
				local close = child(canvas, "Close") :: GuiObject
				close.Position = UDim2.fromOffset(1450, 96)
				list.Size = UDim2.fromOffset(1040, 380)
				local note = child(canvas, "Note") :: GuiObject
				note.Position = UDim2.fromOffset(460, 586)
				for _, d in list:GetDescendants() do
					if d:IsA("TextButton") and d.Name == "Go" then
						d.Size = UDim2.fromOffset(200, 72)
					end
				end
			end,
		},
	})
	-- the top bar's gift button opens it
	local topbar = player.PlayerGui:WaitForChild("LobbyTopbar", 15)
	local bar = topbar and topbar:FindFirstChild("Bar")
	local gift = bar and bar:FindFirstChild("Rewards")
	local face = gift and gift:FindFirstChild("Face")
	local pop = face and face:FindFirstChild("Pop")
	if gift and gift:IsA("GuiButton") and pop and pop:IsA("UIScale") then
		UiMotion.button(gift, pop, function()
			Router.toggle("Rewards")
		end)
	end
end

return RewardsController
