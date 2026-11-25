--!strict
-- The Range menu (bar button RANGE, the range entrance prompt): a framed
-- placeholder on Util/Menu's chrome until the Range wing opens. Every other
-- lobby menu is a Studio-built screen with its own controller.

local Fx = require(script.Parent.Parent.Util.Fx)
local Icons = require(script.Parent.Parent.Util.Icons)
local Kit = require(script.Parent.Parent.Util.Kit)
local Menu = require(script.Parent.Parent.Util.Menu)
local Router = require(script.Parent.Parent.Util.Router)
local Style = require(script.Parent.Parent.Util.Style)

local Panels = {}

local C = Style.COLOR

-- On Util/Menu's 1920 x 1080 canvas (Shared/UiLayout fits it per device).
local BODY = Vector2.new(96, 228)
local BODY_SIZE = Vector2.new(1728, 700)

type Panel = {
	chrome: Menu.Chrome,
	focus: GuiObject?,
	body: Frame,
	isOpen: boolean,
}

local function card(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	line: Color3?
): Frame
	local c = Kit.surface(parent, {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		ZIndex = 2,
	}, {
		radius = Style.RADIUS.lg,
		transparency = 0.02,
		stroke = line or true,
		strokeTransparency = if line then 0.3 else nil,
	})
	Kit.shadow(c, Style.RADIUS.lg, 0.8)
	return c
end

local function soon(parent: Instance, text: string, y: number)
	-- An auto-layout row, so the tag and the line never touch at any text size.
	local row = Kit.make("Frame", {
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.fromOffset(1600, 32),
		BackgroundTransparency = 1,
	}, parent)
	Kit.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 16),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	local tag = Kit.tag(row, "COMING SOON", C.primary, { LayoutOrder = 1 }, true)
	Kit.text(row, text, "body", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.textSecondary,
		LayoutOrder = 2,
	})
	return tag
end

local function build(name: string, kicker: string, title: string): Panel
	local chrome = Menu.build("Lobby" .. name, kicker, title)
	local body = Kit.make("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(BODY.X, BODY.Y),
		Size = UDim2.fromOffset(BODY_SIZE.X, BODY_SIZE.Y),
		BackgroundTransparency = 1,
	}, chrome.content)
	local panel: Panel = {
		chrome = chrome,
		focus = chrome.close,
		body = body,
		isOpen = false,
	}
	Router.register(name, {
		open = function()
			if panel.isOpen then
				return
			end
			panel.isOpen = true
			Menu.show(chrome)
			body.Position = UDim2.fromOffset(BODY.X, BODY.Y + 32)
			Fx.tween(body, Fx.MOTION.enter, { Position = UDim2.fromOffset(BODY.X, BODY.Y) })
		end,
		close = function()
			if not panel.isOpen then
				return
			end
			panel.isOpen = false
			Menu.hide(chrome, function()
				return panel.isOpen
			end)
		end,
		focus = function(): GuiObject?
			return panel.focus
		end,
	})
	return panel
end

--------------------------------------------------------------------------------

local function buildRange()
	local p = build("Range", "PRACTICE", "SHOOTING RANGE")
	local c = card(p.body, 0, 0, 1100, 420)
	Icons.draw(c, "Range", 120, C.textSecondary, {
		Position = UDim2.fromOffset(60, 60),
		ZIndex = 4,
	})
	Kit.text(c, "EVERY GUN. EVERY MOD.", "title", {
		Position = UDim2.fromOffset(230, 70),
		Size = UDim2.fromOffset(800, 50),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	})
	Kit.text(
		c,
		"Firing lanes, moving dummies that shoot back, a movement course and a power test area. Walk down the ramp behind spawn, or press RANGE.",
		"body",
		{
			Position = UDim2.fromOffset(232, 136),
			Size = UDim2.fromOffset(800, 80),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			TextColor3 = C.textSecondary,
			ZIndex = 4,
		}
	)
	soon(
		p.body,
		"The Range wing opens in the next lobby phase. You'll be able to queue from inside it.",
		460
	)
end

function Panels.init()
	buildRange()
end

return Panels
