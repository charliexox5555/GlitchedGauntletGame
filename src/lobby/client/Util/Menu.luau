--!strict
-- Shared chrome for every full-screen lobby menu (Play, Shop, Battle Pass,
-- Locker, Settings, Range), v2 (Figma "Lobby v2 · Play menu 1920x1080"):
-- an edge-to-edge dimmer gui (ScreenInsets None, art only) and a content gui
-- in the core-UI safe area (LihFolk: Safe Areas and Insets), a CanvasGroup
-- canvas with one Fit UIScale, the kicker + title header, and the same round
-- close button in the same corner on every menu (LihFolk: Menu Archetypes).

local Players = game:GetService("Players")

local Fx = require(script.Parent.Fx)
local Kit = require(script.Parent.Kit)
local Layout = require(script.Parent.Layout)
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
}

function Menu.canvas(): Vector2
	return if Layout.isPhone() then Layout.PHONE_CANVAS else Vector2.new(1920, 1080)
end

function Menu.build(name: string, kicker: string, title: string): Chrome
	local phone = Layout.isPhone()
	local M = if phone then Style.MENU.phone else Style.MENU.desktop
	local canvas = Menu.canvas()
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
	local gui = Kit.make("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 20,
		Enabled = false,
	}, playerGui)
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
		Size = UDim2.fromOffset(canvas.X, canvas.Y),
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
		Size = UDim2.fromOffset(if phone then 640 else 1200, if phone then 60 else 100),
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
		Position = UDim2.fromOffset(0, if phone then 20 else 24),
		Size = UDim2.fromOffset(if phone then 620 else 1100, if phone then 38 else 66),
		TextSize = if phone then 32 else Style.TEXT.title.size,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local close = Kit.circle(content, {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(M.close.X, M.close.Y),
	}, M.closeSize)
	Kit.cross(close, math.floor(M.closeSize * 0.42))
	local stroke = Kit.strokeOf(close)
	Fx.button(close, function()
		Router.close()
	end, {
		silent = true,
		onHover = function(on)
			Fx.tween(
				close,
				Fx.MOTION.hover,
				{ BackgroundColor3 = if on then C.surfaceHover else C.surface }
			)
			Fx.tween(
				stroke,
				Fx.MOTION.hover,
				{ Transparency = if on then Style.ALPHA.strokeHover else Style.ALPHA.stroke }
			)
		end,
	})
	Layout.fit(content, "menu")
	return {
		gui = gui,
		backdrop = backdrop,
		scrim = scrim,
		content = content,
		header = header,
		headerPos = M.header,
		close = close,
	}
end

-- Shared open / close motion: the dimmer and content fade, the header slides.
function Menu.show(chrome: Chrome)
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
