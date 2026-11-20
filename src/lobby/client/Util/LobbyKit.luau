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
--   page(spec)                  a router page: blur + wash, opens from 0.75
--                               of its fit, one at a time, back / B closes
-- Colours, font and motion are Config/UiStyle.KIT.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local UiStyle = require(ReplicatedStorage.Shared.Config.UiStyle)
local UiMotion = require(ReplicatedStorage.Shared.UiMotion)
local Cards = require(script.Parent.Cards)
local CloseButton = require(script.Parent.CloseButton)
local Layout = require(script.Parent.Layout)
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
-- Returns pick(i), which also runs onSelect.
function LobbyKit.tabs(list: { GuiButton }, onSelect: (i: number) -> ()): (i: number) -> ()
	local current = 0
	local function words(tab: GuiButton): TextLabel?
		return tab:FindFirstChildWhichIsA("TextLabel", true)
	end
	local function look(i: number)
		for j, tab in list do
			local on = j == i
			UiMotion.tween(tab, M.quick, { BackgroundColor3 = if on then C.white else C.navy })
			local w = words(tab)
			if w then
				UiMotion.tween(w, M.quick, { TextColor3 = if on then C.ink else C.muted })
			end
		end
	end
	local function pick(i: number)
		if i == current then
			return
		end
		current = i
		look(i)
		onSelect(i)
	end
	for i, tab in list do
		LobbyKit.button(tab, function()
			pick(i)
		end)
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
	canvas: GuiObject, -- centre-anchored, holds the page
	design: Vector2, -- the canvas' design size (desktop 1920 x 1080)
	wash: GuiObject?, -- the full-screen violet wash, faded in
	focus: (() -> GuiObject?)?, -- where gamepad selection starts
	close: GuiButton?, -- the drawn-X close
	onOpen: ((arg: any?) -> ())?,
	onClose: (() -> ())?,
	-- Phones (Util/Layout family "phone"): the whole 1920 x 1080 canvas would
	-- draw at ~0.35 (4-9 px words, 30 px buttons), so a phone shows only
	-- `region` of the canvas (design px, min / max corners), zoomed to fill
	-- the screen; `arrange` moves the page's pieces into that region once.
	phone: { region: Rect, arrange: (() -> ())? }?,
}

export type Page = { isOpen: () -> boolean, refit: () -> () }

-- A page in the router: one open at a time, blur 24 behind it, the wash fades
-- in, the canvas opens from 0.75 of its fit (Quint Out, no overshoot).
function LobbyKit.page(spec: PageSpec): Page
	-- lihfolk-ignore: findfirstchild-chain (nil-checked on the next line)
	local fit = spec.canvas:FindFirstChild("Fit") :: UIScale?
	if not fit then
		local s = Instance.new("UIScale")
		s.Name = "Fit"
		s.Parent = spec.canvas
		fit = s
	end
	local fitScale = fit :: UIScale
	local open = false
	local token = 0
	local washT = if spec.wash then spec.wash.BackgroundTransparency else 1

	local phone = if Layout.isPhone() then spec.phone else nil
	if phone and phone.arrange then
		phone.arrange()
	end
	local function target(): number
		local size = spec.gui.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return 1
		end
		if phone then
			local r = phone.region
			local w, h = r.Max.X - r.Min.X, r.Max.Y - r.Min.Y
			local k = math.min(size.X / w, size.Y / h)
			-- the region's centre on the screen's centre (the canvas is
			-- centre-anchored: offsets are in screen px)
			local cx, cy = (r.Min.X + r.Max.X) / 2, (r.Min.Y + r.Max.Y) / 2
			spec.canvas.Position =
				UDim2.new(0.5, (spec.design.X / 2 - cx) * k, 0.5, (spec.design.Y / 2 - cy) * k)
			return k
		end
		return math.min(size.X / spec.design.X, size.Y / spec.design.Y)
	end
	local function refit()
		if open then
			fitScale.Scale = target()
		end
	end
	spec.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)

	local resetClose: (() -> ())? = nil
	if spec.close then
		resetClose = CloseButton.hook(spec.close, function()
			Router.close()
		end)
	end

	Router.register(spec.name, {
		focus = spec.focus,
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
			UiMotion.pageIn(fitScale, target())
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
			UiMotion.out(fitScale, { Scale = target() * 0.94 })
			if spec.onClose then
				spec.onClose()
			end
			task.delay(M.quick + 0.02, function()
				if mine == token and not open then
					spec.gui.Enabled = false
				end
			end)
		end,
	})

	return {
		isOpen = function()
			return open
		end,
		refit = refit,
	}
end

return LobbyKit
