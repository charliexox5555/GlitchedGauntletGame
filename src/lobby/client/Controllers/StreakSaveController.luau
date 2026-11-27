--!strict
-- The streak save (vault/01 Design/Progression.md), Studio-built (tools/studio/BuildStreakSave.luau):
--   LobbyBar.Bottom.SaveStreak  shown in Settings' place while a lost streak can be saved (Settings
--                               stays on the top bar), with the time left
--   StreakSave                  the popup: the lost streak, the time left, SAVE FOR <price> coins
-- The offer is on the player (StreakSaveValue / StreakSaveEnds / StreakSavePrice, Shared/PlayerData);
-- BUY sends StreakSave("buy", shownPrice) and the server checks everything (StreakSaveService).
-- Not enough coins: the button says GET COINS and opens the Shop. No alarms, no flashing: the
-- countdown is the real one (LihFolk: Ethical Design and Player Trust).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local UiSfx = require(ReplicatedStorage.Shared.UiSfx)
local LobbyKit = require(script.Parent.Parent.Util.LobbyKit)
local Router = require(script.Parent.Parent.Util.Router)
local UiWait = require(ReplicatedStorage.Shared.Util.UiWait)
local need = UiWait.child
local LobbyHud = require(script.Parent.LobbyHud)

local StreakSaveController = {}

local player = Players.LocalPlayer

local gui: ScreenGui? = nil
local card: Frame
local streakLabel: TextLabel
local endsLabel: TextLabel
local noteLabel: TextLabel
local actionLabel: TextLabel
local coinIcon: ImageLabel
local flamePop: UIScale?
local barSettings: GuiObject? = nil
local barSave: GuiObject? = nil
local barTimer: TextLabel? = nil
local sending = false

local function num(name: string): number
	local v = StateValues.get(player, name)
	return if typeof(v) == "number" and v == v then v else 0
end

local function now(): number
	return workspace:GetServerTimeNow()
end

-- The live offer: (streak, seconds left, price), or nil.
local function offer(): (number?, number, number)
	local value, ends = num("StreakSaveValue"), num("StreakSaveEnds")
	local left = ends - now()
	if value <= 0 or left <= 0 then
		return nil, 0, 0
	end
	return value, left, num("StreakSavePrice")
end

local function clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

local function canAfford(price: number): boolean
	return PlayerData.coins(player) >= price
end

local function render()
	local value, left, price = offer()
	-- the bar: SAVE WINSTREAK in Settings' place while the offer lasts
	if barSave and barSettings then
		barSave.Visible = value ~= nil
		barSettings.Visible = value == nil
	end
	if barTimer then
		barTimer.Text = clock(left)
	end
	if not gui then
		return
	end
	if not value then
		if Router.current() == "StreakSave" then
			Router.close()
		end
		return
	end
	streakLabel.Text = tostring(value)
	endsLabel.Text = "ENDS IN " .. clock(left)
	if sending then
		actionLabel.Text = "SAVING..."
		coinIcon.Visible = false
	elseif canAfford(price) then
		actionLabel.Text = "SAVE FOR " .. price
		coinIcon.Visible = true
		noteLabel.Text = "YOUR STREAK COMES BACK WITH ANY WINS SINCE"
	else
		actionLabel.Text = "GET COINS"
		coinIcon.Visible = false
		noteLabel.Text =
			string.format("YOU NEED %d COINS (YOU HAVE %d)", price, PlayerData.coins(player))
	end
	-- the words sit centred on the button, left of the coin when it shows
	actionLabel.Size = if coinIcon.Visible then UDim2.new(1, -56, 1, 0) else UDim2.fromScale(1, 1)
end

local function buy()
	local value, _, price = offer()
	if not value or sending then
		return
	end
	if not canAfford(price) then
		Router.open("Shop")
		return
	end
	sending = true
	render()
	LobbyNet.event("StreakSave"):FireServer("buy", price)
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
	if payload.kind == "saved" then
		sending = false
		UiSfx.cue("Confirm")
		LobbyHud.toast("WINSTREAK SAVED", "info")
		if Router.current() == "StreakSave" then
			Router.close()
		end
	elseif payload.kind == "failed" then
		sending = false
		UiSfx.cue("PurchaseDenied")
		LobbyHud.toast(
			if typeof(payload.text) == "string" then payload.text else "Couldn't save",
			"error"
		)
		render()
	end
end

function StreakSaveController.init()
	local playerGui = player:WaitForChild("PlayerGui")
	local g = playerGui:WaitForChild("StreakSave", 15)
	local bar = playerGui:WaitForChild("LobbyBar", 15)
	local bottom = bar and bar:WaitForChild("Bottom", 15)
	if bottom then
		barSettings = bottom:FindFirstChild("Settings") :: GuiObject?
		barSave = bottom:FindFirstChild("SaveStreak") :: GuiObject?
		local timer = barSave and barSave:FindFirstChild("Timer")
		barTimer = timer and timer:FindFirstChild("Value") :: TextLabel?
	end
	if not (g and g:IsA("ScreenGui")) then
		warn(
			"[StreakSave] PlayerScripts.UI.Lobby.StreakSave missing (tools/studio/BuildStreakSave.luau)"
		)
		return
	end
	gui = g
	g.Enabled = false
	-- lihfolk-ignore: findfirstchild-chain (every lookup below is nil-guarded with `and`)
	local canvas = need(g, "Canvas") :: Frame
	card = need(canvas, "Card") :: Frame
	streakLabel = need(card, "Streak") :: TextLabel
	endsLabel = need(card, "Ends") :: TextLabel
	noteLabel = need(card, "Note") :: TextLabel
	local action = need(card, "Action") :: TextButton
	actionLabel = need(action, "Label") :: TextLabel
	coinIcon = need(action, "Coin") :: ImageLabel
	local flame = card:FindFirstChild("Flame")
	flamePop = flame and flame:FindFirstChild("Pop") :: UIScale?
	LobbyKit.button(action, buy)
	LobbyKit.page({
		name = "StreakSave",
		gui = g,
		wash = need(g, "Wash") :: Frame,
		close = need(canvas, "Close") :: GuiButton,
		focus = function()
			return action
		end,
		onOpen = function()
			render()
			local pop = flamePop
			if pop then
				pop.Scale = 0.6
				TweenService:Create(
					pop,
					TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
					{ Scale = 1 }
				):Play()
			end
		end,
	} :: any)
end

function StreakSaveController.start()
	LobbyNet.event("ProgressEvent").OnClientEvent:Connect(onEvent)
	StateValues.anyChanged(player):Connect(function(name: string)
		if
			name == "StreakSaveValue"
			or name == "StreakSaveEnds"
			or name == "StreakSavePrice"
			or name == "Coins"
		then
			render()
		end
	end)
	-- the countdowns tick once a second
	while true do
		render()
		task.wait(1)
	end
end

return StreakSaveController
