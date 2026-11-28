--!strict
-- The lobby HUD (vault/02 Art/UI Lobby HUD.md): the Studio-built ScreenGuis
-- (LobbyTasks, LobbyPlayerList, LobbyBar, LobbyToast, LobbyTopbar) filled
-- and animated by Util/LobbyHudView (profile, player list, bottom bar, PLAY,
-- party, toasts) on every device; Shared/UiLayout sizes them per device.
-- This module also draws the edge-to-edge shades in their own
-- ScreenInsets.None gui so the bars read over a bright lobby.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local LoginRewards = require(ReplicatedStorage.Shared.LoginRewards)
local Onboarding = require(ReplicatedStorage.Shared.Onboarding)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local SeasonPass = require(ReplicatedStorage.Shared.SeasonPass)
local SeasonCatalog = require(ReplicatedStorage.Lobby.SeasonCatalog)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local Kit = require(script.Parent.Parent.Util.Kit)
local LobbyHudView = require(script.Parent.Parent.Util.LobbyHudView)
local QueueState = require(script.Parent.Parent.Util.QueueState)
local Router = require(script.Parent.Parent.Util.Router)
local Style = require(script.Parent.Parent.Util.Style)

local LobbyHud = {}

local C = Style.COLOR
local player = Players.LocalPlayer

local bound = false -- the Studio-built HUD is bound (Util/LobbyHudView)

-- A short message. kind: "error" (red strip) or "info".
function LobbyHud.toast(text: string, kind: string?)
	if bound then
		LobbyHudView.toast(text, kind)
	end
end

-- The Shop's red dot while today's login reward waits in its DAILY tab (vault/01 Design/Shop Economy and
-- Art v1.md -> Economy pass, "login is claimed by hand"): only once the Shop is unlocked, rechecked when the
-- login state or match count changes and once a minute for the UTC day rollover.
local DAILY_CHECK_SECONDS = 60

-- Season pass rewards reached and not claimed yet (release 1 friction pass, 2026-11-28: the pass's only way
-- in is the Shop's card, and a tier gained in a match was never mentioned). They add to the Shop's dot, and
-- one toast per lobby visit says they're waiting.
local function passWaiting(): number
	if not SeasonCatalog.screenOn() then
		return 0
	end
	local s = PlayerData.season(player)
	local n = 0
	for tier = 1, s.tier do
		for _, track: SeasonPass.Track in { "free", "premium" } :: { SeasonPass.Track } do
			if #SeasonCatalog.rewards(tier, track) > 0 and SeasonPass.canClaim(s, tier, track) then
				n += 1
			end
		end
	end
	return n
end
local passToastShown = false

local function drawDailyDot()
	local matches = StateValues.get(player, "Matches")
	local shopOpen = typeof(matches) == "number" and Onboarding.unlocked("Shop", matches)
	local login = LoginRewards.clean({
		last = StateValues.get(player, "LoginLast"),
		step = StateValues.get(player, "LoginStep"),
	})
	local today = Economy.day(math.floor(workspace:GetServerTimeNow()))
	local ready = shopOpen and StateValues.get(player, "DataReady") == true
	local waiting = ready and LoginRewards.nextStep(login, today) ~= nil
	local pass = if ready then passWaiting() else 0
	LobbyHudView.setBadge("Shop", (if waiting then 1 else 0) + pass)
	if pass > 0 and not passToastShown then
		passToastShown = true
		LobbyHudView.toast(
			`{pass} SEASON PASS REWARD{if pass == 1 then "" else "S"} WAITING: OPEN THE SHOP TO CLAIM`,
			"info"
		)
	end
end

function LobbyHud.init()
	local playerGui = player:WaitForChild("PlayerGui")
	-- Edge-to-edge shades (art only, nothing to press) so the bars read over a
	-- bright lobby; the top one runs under Roblox's strip, no hard edge.
	local shadeGui = Kit.make("ScreenGui", {
		Name = "LobbyHudShade",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
		DisplayOrder = 1,
	}, playerGui)
	shadeGui:SetAttribute("LobbyGui", true) -- the match client never clears it
	local shadeTop = Kit.make("Frame", {
		Name = "ShadeTop",
		Size = UDim2.new(1, 0, 0, 150),
		BackgroundColor3 = C.scrim,
		BorderSizePixel = 0,
		Active = false,
	}, shadeGui)
	Kit.make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.5, 1) }, shadeTop)
	local shadeBottom = Kit.make("Frame", {
		Name = "ShadeBottom",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.26),
		BackgroundColor3 = C.scrim,
		BorderSizePixel = 0,
		Active = false,
	}, shadeGui)
	Kit.make(
		"UIGradient",
		{ Rotation = -90, Transparency = NumberSequence.new(0.42, 1) },
		shadeBottom
	)

	local guis = LobbyHudView.guis(playerGui, 10)
	if guis then
		bound = LobbyHudView.bind(guis)
	else
		warn("[LobbyHud] Studio HUD ScreenGuis missing (tools/studio/BuildLobbyHud.luau)")
	end
end

function LobbyHud.start()
	if not bound then
		return
	end
	QueueState.onChanged(LobbyHudView.refresh)
	Router.onChanged(function()
		LobbyHudView.refresh()
	end)
	LobbyHudView.refresh()
	LobbyHudView.intro()
	for _, name in { "DataReady", "Matches", "LoginLast", "LoginStep" } do
		StateValues.changed(player, name):Connect(drawDailyDot)
	end
	-- the pass state (claims, purchases, match progress) is the "Season" StringValue
	task.spawn(function()
		local v = player:WaitForChild(PlayerData.SEASON, 60)
		if v and v:IsA("StringValue") then
			v.Changed:Connect(drawDailyDot)
			drawDailyDot()
		end
	end)
	task.spawn(function()
		while true do
			drawDailyDot()
			task.wait(DAILY_CHECK_SECONDS)
		end
	end)
end

return LobbyHud
