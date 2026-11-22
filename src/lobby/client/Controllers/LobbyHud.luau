--!strict
-- The lobby HUD (vault/02 Art/UI Lobby HUD.md): the Studio-built ScreenGuis
-- (LobbyTasks, LobbyPlayerList, LobbyBar, LobbyToast, LobbyTopbar) filled
-- and animated by Util/LobbyHudView (profile, player list, bottom bar, PLAY,
-- party, toasts) on every device; Shared/UiLayout sizes them per device.
-- This module also draws the edge-to-edge shades in their own
-- ScreenInsets.None gui so the bars read over a bright lobby.

local Players = game:GetService("Players")

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
end

return LobbyHud
