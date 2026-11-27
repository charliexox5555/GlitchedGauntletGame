--!strict
-- The lobby's shared component kit (vault/02 Art/UI Lobby Overhaul.md →
-- System). Every Studio-built screen gets its look and feel from here, so
-- each screen's controller only says what goes where:
--   plate(body)                 a slanted plate, one piece (Util/Plates)
--   cell(frame)                 a chunky cell, one piece (Util/Cards)
--   button(btn, onClick, opts)  hover 1.125 / press 0.875 from the centre
--   tabs(list, onSelect)        icon / word tabs: the picked one white + ink
--   price(plate, text)          set a price plate's amount
--   close(btn, onClick)         the one drawn-X close button
--   slot(template, parent, fill) / clearSlots(parent)
--                               one repeated card per call (RIVALS' Slot
--                               pattern), wrapped so it pops from its centre
--   page(spec)                  a router page: blur + wash, one at a time,
--                               back / B closes
-- Colours, font and motion are Config/UiStyle.KIT.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local UiStyle = require(ReplicatedStorage.Shared.Config.UiStyle)
local UiMotion = require(ReplicatedStorage.Shared.UiMotion)
local UiSfx = require(ReplicatedStorage.Shared.UiSfx)
local Cards = require(script.Parent.Cards)
local CloseButton = require(script.Parent.CloseButton)
local Pivot = require(script.Parent.Pivot)
local Plates = require(script.Parent.Plates)
local Router = require(script.Parent.Router)

local LobbyKit = {}

local C = UiStyle.KIT.color
local M = UiStyle.KIT.motion
LobbyKit.C = C
LobbyKit.M = M
LobbyKit.FONT = UiStyle.KIT.font.display

LobbyKit.plate = Plates.finish
LobbyKit.deepen = Plates.deepen
LobbyKit.cell = Cards.finish
LobbyKit.close = CloseButton.hook

-- The button's pop (a child UIScale named "Pop"), made if missing.
function LobbyKit.pop(obj: GuiObject): UIScale
	local p = obj:FindFirstChild("Pop")
	if p and p:IsA("UIScale") then
		return p
	end
	local s = Instance.new("UIScale")
	s.Name = "Pop"
	s.Parent = obj
	return s
end

-- Call after the button is parented (a layout item gets a holder).
function LobbyKit.button(
	btn: GuiButton,
	onClick: () -> (),
	opts: UiMotion.ButtonOptions?
): { RBXScriptConnection }
	local pop = LobbyKit.pop(btn)
	Pivot.prepare(btn)
	return UiMotion.button(btn, pop, onClick, opts)
end

-- Tabs: the picked tab is a white plate with ink words, the rest navy with
-- muted words (a tab's words are its first TextLabel; icons keep their art).
-- Tabs sit side by side, so they never grow (owner 2026-11-20: "chunky, the
-- buttons overlap"): hovering an idle tab lifts its plate a shade and its
-- words to white, eased; picking one eases to the white plate.
-- Returns pick(i), which also runs onSelect.
function LobbyKit.tabs(list: { GuiButton }, onSelect: (i: number) -> ()): (i: number) -> ()
	local current = 0
	local over: GuiButton? = nil
	local function words(tab: GuiButton): TextLabel?
		return tab:FindFirstChildWhichIsA("TextLabel", true)
	end
	local function look()
		for j, tab in list do
			local on = j == current
			local hot = not on and tab == over
			UiMotion.tween(tab, 0.2, {
				BackgroundColor3 = if on
					then C.white
					elseif hot then C.navyHi:Lerp(C.white, 0.08)
					else C.navy,
			})
			local w = words(tab)
			if w then
				UiMotion.tween(
					w,
					0.2,
					{ TextColor3 = if on then C.ink elseif hot then C.white else C.muted }
				)
			end
		end
	end
	local function pick(i: number)
		if i == current then
			return
		end
		current = i
		look()
		onSelect(i)
	end
	for i, tab in list do
		LobbyKit.button(tab, function()
			if i ~= current then
				UiSfx.cue("Tab")
			end
			pick(i)
		end, {
			hover = 1,
			enabled = function()
				return false -- no grow, no dip
			end,
			onHover = function(on: boolean)
				over = if on then tab elseif over == tab then nil else over
				look()
			end,
		})
	end
	return pick
end

-- A price plate's amount (the label named Amount anywhere inside it).
function LobbyKit.price(plate: Instance, text: string)
	local a = plate:FindFirstChild("Amount", true)
	if a and a:IsA("TextLabel") then
		a.Text = text
	end
end

-- One repeated card: clone, fill, parent, wrap so it pops from its centre.
function LobbyKit.slot<T>(template: T, parent: Instance, fill: (T) -> ()): T
	local item = (template :: any):Clone()
	fill(item)
	item.Parent = parent
	if parent:FindFirstChildWhichIsA("UIGridStyleLayout") then
		Pivot.wrap(item)
	end
	return item
end

-- Remove every slot (and its holder) under `parent`.
function LobbyKit.clearSlots(parent: Instance)
	for _, c in parent:GetChildren() do
		if
			c:IsA("GuiObject")
			and (StateValues.get(c, "PivotHolder") == true or StateValues.get(c, "Slot") == true)
		then
			c:Destroy()
		end
	end
end

export type PageSpec = {
	name: string, -- the Router name
	gui: ScreenGui,
	wash: GuiObject?, -- the full-screen violet wash, faded in
	focus: (() -> GuiObject?)?, -- where gamepad selection starts
	back: (() -> boolean)?, -- B steps back inside the page first (true = handled; Util/Router)
	close: GuiButton?, -- the drawn-X close
	onOpen: ((arg: any?) -> ())?,
	onClose: (() -> ())?,
}

export type Page = { isOpen: () -> boolean }

-- A page in the router: one open at a time, blur 24 behind it, the wash fades
-- in. The canvas' "Fit" UIScale is Shared/UiLayout's (every device).
function LobbyKit.page(spec: PageSpec): Page
	local open = false
	local token = 0
	local closing = 0 -- the token of a close whose fade is still showing
	local washT = if spec.wash then spec.wash.BackgroundTransparency else 1

	local resetClose: (() -> ())? = nil
	if spec.close then
		resetClose = CloseButton.hook(spec.close, function()
			Router.close()
		end)
	end

	Router.register(spec.name, {
		focus = spec.focus,
		screen = spec.gui.Name, -- traps gamepad selection inside the page
		back = spec.back,
		open = function(arg: any?)
			token += 1
			if open then
				if spec.onOpen then
					spec.onOpen(arg)
				end
				return
			end
			open = true
			spec.gui.Enabled = true
			if resetClose then
				resetClose()
			end
			if spec.wash then
				spec.wash.BackgroundTransparency = 1
				UiMotion.tween(spec.wash, M.beat, { BackgroundTransparency = washT })
			end
			if spec.onOpen then
				spec.onOpen(arg)
			end
		end,
		close = function()
			if not open then
				return
			end
			open = false
			token += 1
			local mine = token
			if spec.wash then
				UiMotion.out(spec.wash, { BackgroundTransparency = 1 })
			end
			if spec.onClose then
				spec.onClose()
			end
			closing = mine -- its fade is still on screen
			task.delay(M.quick + 0.02, function()
				if mine == token and not open then
					spec.gui.Enabled = false
				end
				if closing == mine then
					closing = 0
				end
			end)
		end,
	})

	-- A closed page stays off. ArmedHideController puts back every lobby screen that was on when a match began, so
	-- a page caught in its close fade (closed, then straight into a match) came back on in the lobby with the
	-- Router closed: a dead Backpack after a new player's match 2 (2026-11-26).
	spec.gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if spec.gui.Enabled and not open and closing ~= token then
			spec.gui.Enabled = false
		end
	end)

	return {
		isOpen = function()
			return open
		end,
	}
end

return LobbyKit
