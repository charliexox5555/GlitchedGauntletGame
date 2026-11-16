--!strict
-- Every lobby menu's round close button (owner 2026-11-15: "all close
-- buttons should look better and fit similar theme"): a dark navy circle
-- with a drawn X (Glyph.A / Glyph.B, two rounded bars, not a font glyph).
-- Studio-built menus get it from tools/studio/BuildLobbyMenus.luau and
-- BuildLocker.luau; code-built menus (Util/Menu) from CloseButton.make.
-- Hover fills the circle white, turns the X ink and gives it a quarter turn;
-- a press dips it. Clean Quint motion, no overshoot.

local TweenService = game:GetService("TweenService")

local M = require(game:GetService("ReplicatedStorage").Shared.UiMotion).M -- hover 1.125, press 0.875

local CloseButton = {}

local WHITE, INK = Color3.new(1, 1, 1), Color3.fromHex("141A26")
local NAVY = Color3.fromHex("0B1236")

local function tween(
	obj: Instance,
	time: number,
	goal: { [string]: any },
	dir: Enum.EasingDirection?
)
	local t = TweenService:Create(
		obj,
		TweenInfo.new(time, Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

-- Builds the button in code: `centre` is its centre, `d` its diameter.
function CloseButton.make(parent: Instance, centre: Vector2, d: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = "Close"
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.fromOffset(centre.X, centre.Y)
	b.Size = UDim2.fromOffset(d, d)
	b.BackgroundColor3 = NAVY
	b.BackgroundTransparency = 0.1
	b.BorderSizePixel = 0
	b.Text = ""
	b.AutoButtonColor = false
	b.ZIndex = 3
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = b
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = b
	local glyph = Instance.new("Frame")
	glyph.Name = "Glyph"
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	glyph.Size = UDim2.fromOffset(d * 0.42, d * 0.42)
	glyph.BackgroundTransparency = 1
	glyph.ZIndex = 5
	glyph.Parent = b
	for _, r in { 45, -45 } do
		local bar = Instance.new("Frame")
		bar.Name = if r > 0 then "A" else "B"
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromOffset(d * 0.42, math.max(4, math.floor(d * 0.07 + 0.5)))
		bar.Rotation = r
		bar.BackgroundColor3 = WHITE
		bar.BorderSizePixel = 0
		bar.ZIndex = 5
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0.5, 0)
		bc.Parent = bar
		bar.Parent = glyph
	end
	b.Parent = parent
	return b
end

-- Wires `b`'s hover and press looks and calls `onClick` when it's pressed.
-- Returns a reset for the menu to call when it opens (a menu that closed
-- while the button was hovered never got its MouseLeave).
function CloseButton.hook(b: GuiButton, onClick: () -> ()): () -> ()
	local glyph = b:FindFirstChild("Glyph")
	local pop = b:FindFirstChild("Pop")
	local fill = b.BackgroundColor3
	local fillT = b.BackgroundTransparency
	local hovered = false
	local function look(on: boolean, time: number?)
		hovered = on
		local k = time or 1
		tween(b, 0.18 * k, {
			BackgroundColor3 = if on then WHITE else fill,
			BackgroundTransparency = if on then 0 else fillT,
		})
		if glyph and glyph:IsA("GuiObject") then
			tween(glyph, 0.26 * k, { Rotation = if on then 90 else 0 })
			for _, bar in glyph:GetChildren() do
				if bar:IsA("Frame") then
					tween(bar, 0.18 * k, { BackgroundColor3 = if on then INK else WHITE })
				end
			end
		end
		if pop and pop:IsA("UIScale") then
			tween(pop, 0.18 * k, { Scale = if on then M.hover else 1 })
		end
	end
	b.MouseEnter:Connect(function()
		look(true)
	end)
	b.MouseLeave:Connect(function()
		look(false)
	end)
	b.Activated:Connect(function()
		if pop and pop:IsA("UIScale") then
			local rest = if hovered then M.hover else 1
			local t = tween(pop, 0.07, { Scale = rest * M.press })
			t.Completed:Once(function(state: Enum.PlaybackState)
				if state == Enum.PlaybackState.Completed then
					tween(pop, 0.26, { Scale = rest })
				end
			end)
		end
		onClick()
	end)
	return function()
		look(false, 0.01)
	end
end

return CloseButton
