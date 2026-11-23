--!strict
-- Chrome for the last code-built lobby menu (Controllers/Panels: the Range
-- placeholder), v2 (Figma "Lobby v2 · Play menu 1920x1080"): an edge-to-edge
-- dimmer gui (ScreenInsets None, art only) and a content gui in the core-UI
-- safe area (LihFolk: Safe Areas and Insets), a 1920 x 1080 CanvasGroup
-- canvas whose "Fit" UIScale Shared/UiLayout owns (every device), the
-- kicker + title header, and the shared drawn-X close (Util/CloseButton).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiLayout = require(ReplicatedStorage.Shared.UiLayout)

local CloseButton = require(script.Parent.CloseButton)
local Fx = require(script.Parent.Fx)
local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Router)
local Style = require(script.Parent.Style)

local Menu = {}

local C = Style.COLOR

export type Chrome = {
	gui: ScreenGui,
	backdrop: ScreenGui,
	scrim: TextButton,
	content: CanvasGroup,
	header: Frame,
	headerPos: Vector2,
	close: TextButton,
	resetClose: () -> (),
}

function Menu.build(name: string, kicker: string, title: string): Chrome
	local M = Style.MENU
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local backdrop = Kit.make("ScreenGui", {
		Name = name .. "Backdrop",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 19,
		Enabled = false,
	}, playerGui)
	backdrop:SetAttribute("LobbyGui", true) -- the match client never clears it
	local gui = Kit.make("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 20,
		Enabled = false,
	}, playerGui)
	gui:SetAttribute("LobbyGui", true) -- the match client never clears it
	local scrim = Kit.make("TextButton", {
		Name = "Scrim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.scrim,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Modal = true,
		Selectable = false,
	}, backdrop)
	-- Vignette: dark bands fading in from the top and bottom edges.
	for _, top in { true, false } do
		local band = Kit.make("Frame", {
			AnchorPoint = Vector2.new(0, if top then 0 else 1),
			Position = UDim2.fromScale(0, if top then 0 else 1),
			Size = UDim2.fromScale(1, 0.3),
			BackgroundColor3 = C.scrim,
			BorderSizePixel = 0,
		}, scrim)
		Kit.make("UIGradient", {
			Rotation = if top then 90 else -90,
			Transparency = NumberSequence.new(0.2, 1),
		}, band)
	end
	local content = Kit.make("CanvasGroup", {
		Name = "Content",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1920, 1080),
		BackgroundTransparency = 1,
		-- Gamepad selection stays inside the menu (LihFolk: Gamepad and Console UX).
		SelectionGroup = true,
		SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
		SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
		SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
		SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
	}, gui)

	local header = Kit.make("Frame", {
		Name = "Header",
		Position = UDim2.fromOffset(M.header.X, M.header.Y),
		Size = UDim2.fromOffset(1200, 100),
		BackgroundTransparency = 1,
	}, content)
	Kit.text(header, kicker, "label", {
		Name = "Kicker",
		Size = UDim2.fromOffset(700, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.primary,
	})
	Kit.text(header, title, "title", {
		Name = "Title",
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.fromOffset(1100, 66),
		TextSize = Style.TEXT.title.size,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- the shared close button (Util/CloseButton): the same drawn X as the
	-- Studio-built menus; its top-right corner sits where the old one did
	local half = M.closeSize / 2
	local close =
		CloseButton.make(content, Vector2.new(M.close.X - half, M.close.Y + half), M.closeSize)
	local resetClose = CloseButton.hook(close, function()
		Router.close()
	end)
	local fit = Instance.new("UIScale")
	fit.Name = "Fit"
	fit.Parent = content
	UiLayout.watch(gui)
	return {
		gui = gui,
		backdrop = backdrop,
		scrim = scrim,
		content = content,
		header = header,
		headerPos = M.header,
		close = close,
		resetClose = resetClose,
	}
end

-- Shared open / close motion: the dimmer and content fade, the header slides.
function Menu.show(chrome: Chrome)
	chrome.resetClose()
	chrome.gui.Enabled = true
	chrome.backdrop.Enabled = true
	chrome.scrim.BackgroundTransparency = 1
	Fx.tween(chrome.scrim, Fx.MOTION.dimIn, { BackgroundTransparency = Style.ALPHA.scrim })
	chrome.content.GroupTransparency = 1
	Fx.tween(chrome.content, Fx.MOTION.enter, { GroupTransparency = 0 })
	local p = chrome.headerPos
	chrome.header.Position = UDim2.fromOffset(p.X - 36, p.Y)
	Fx.tween(chrome.header, Fx.MOTION.enter, { Position = UDim2.fromOffset(p.X, p.Y) })
end

function Menu.hide(chrome: Chrome, isOpen: () -> boolean)
	Fx.out(chrome.content, { GroupTransparency = 1 })
	Fx.tween(
		chrome.scrim,
		Fx.MOTION.dimOut,
		{ BackgroundTransparency = 1 },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	task.delay(Fx.MOTION.exit + 0.02, function()
		if not isOpen() then
			chrome.gui.Enabled = false
			chrome.backdrop.Enabled = false
		end
	end)
end

return Menu
