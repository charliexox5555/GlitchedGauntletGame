--!strict
-- Weapon picker for testing (Studio and test-mode servers only): P, gamepad
-- D-pad up, or the GUNS touch button opens a small menu of every installed
-- gun (a Config/Weapons entry whose model is in ReplicatedStorage.Weapons),
-- grouped by slot. Picking one asks the server (PickWeapon remote, checked
-- there) to put it in its slot and equip it. Nothing here decides anything.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local TestMode = require(ReplicatedStorage.Shared.TestMode)
local Types = require(ReplicatedStorage.Shared.Types)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local CameraController = require(script.Parent.CameraController)
local InputController = require(script.Parent.InputController)

local PickerController = {}

local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromHex("A9ADB4")
local BACK = Color3.fromHex("16181B")
local CARD = Color3.fromHex("23262B")
local CARD_HOVER = Color3.fromHex("30343A")
local ACCENT = Color3.fromHex("F2C94C")
local BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local MEDIUM = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)

-- A trigger press this soon after the menu closes was the click that closed it.
local CLOSE_GRACE = 0.25

local CLASS_NAMES: { [string]: string } =
	{ MachineGun = "Machine gun", SMG = "SMG", Sidearm = "Sidearm" }
local SLOT_ORDER: { Types.Slot } = { "Primary", "Secondary", "Melee" }

type Card = { button: TextButton, stroke: UIStroke, id: string }

local root: TextButton? = nil
local cards: { Card } = {}
local open = false
local closedAt = -math.huge

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function allowed(): boolean
	return RunService:IsStudio() or TestMode.isOn()
end

-- Installed guns for a slot, cheapest tier first.
local function installed(slot: Types.Slot): { Types.WeaponConfig }
	local folder = ReplicatedStorage:FindFirstChild("Weapons")
	local list = {}
	for _, w in Weapons.list do
		if w.slot == slot and folder and folder:FindFirstChild(w.id) then
			table.insert(list, w)
		end
	end
	table.sort(list, function(a, b)
		if a.tier ~= b.tier then
			return a.tier < b.tier
		end
		return a.displayName < b.displayName
	end)
	return list
end

local function setOpen(value: boolean)
	local r = root
	if not r or open == value then
		return
	end
	open = value
	r.Visible = value
	CameraController.setCursorVisible(value)
	if value then
		-- Highlight the gun in hand.
		local held = player:GetAttribute("WeaponId")
		for _, c in cards do
			c.stroke.Enabled = c.id == held
			c.button.BackgroundColor3 = CARD
		end
		if UserInputService.GamepadEnabled and cards[1] then
			GuiService.SelectedObject = cards[1].button
		end
	else
		closedAt = os.clock()
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(r) then
			GuiService.SelectedObject = nil
		end
	end
end

local function pick(id: string)
	Net.event("PickWeapon"):FireServer(id)
	setOpen(false)
end

local function build(): ScreenGui
	local g = make("ScreenGui", {
		Name = "WeaponPicker",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
	}, player:WaitForChild("PlayerGui"))

	-- A modal backdrop: frees the mouse in first person; a click outside the
	-- panel closes the menu.
	local backdrop = make("TextButton", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		AutoButtonColor = false,
		Modal = true,
		Text = "",
		Visible = false,
	}, g)
	backdrop.Activated:Connect(function()
		setOpen(false)
	end)
	root = backdrop

	local panel = make("TextButton", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(640, 520),
		BackgroundColor3 = BACK,
		BackgroundTransparency = 0.05,
		AutoButtonColor = false,
		Text = "",
		Selectable = false,
	}, backdrop)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, panel)
	make("UISizeConstraint", { MaxSize = Vector2.new(640, 520) }, panel)
	make("UIAspectRatioConstraint", { AspectRatio = 640 / 520 }, panel)
	make("TextLabel", {
		Position = UDim2.fromOffset(22, 16),
		Size = UDim2.new(1, -44, 0, 26),
		BackgroundTransparency = 1,
		FontFace = BOLD,
		TextSize = 24,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "WEAPONS",
	}, panel)
	make("TextLabel", {
		Position = UDim2.fromOffset(22, 42),
		Size = UDim2.new(1, -44, 0, 18),
		BackgroundTransparency = 1,
		FontFace = MEDIUM,
		TextSize = 14,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Testing only. Pick a gun to put it in its slot  ·  P to close",
	}, panel)

	local list = make("ScrollingFrame", {
		Position = UDim2.fromOffset(18, 72),
		Size = UDim2.new(1, -36, 1, -86),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = MUTED,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Selectable = false,
	}, panel)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, list)

	for order, slot in SLOT_ORDER do
		local guns = installed(slot)
		if #guns == 0 then
			continue
		end
		make("TextLabel", {
			LayoutOrder = order * 2 - 1,
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			FontFace = BOLD,
			TextSize = 14,
			TextColor3 = MUTED,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.upper(slot),
		}, list)
		local grid = make("Frame", {
			LayoutOrder = order * 2,
			Size = UDim2.new(1, -6, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, list)
		make("UIGridLayout", {
			CellSize = UDim2.fromOffset(190, 52),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, grid)
		for i, w in guns do
			local button = make("TextButton", {
				Name = w.id,
				LayoutOrder = i,
				BackgroundColor3 = CARD,
				AutoButtonColor = false,
				Text = "",
			}, grid)
			make("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
			local stroke =
				make("UIStroke", { Color = ACCENT, Thickness = 2, Enabled = false }, button)
			make("TextLabel", {
				Position = UDim2.fromOffset(12, 7),
				Size = UDim2.new(1, -20, 0, 20),
				BackgroundTransparency = 1,
				FontFace = BOLD,
				TextSize = 17,
				TextColor3 = WHITE,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = w.displayName,
			}, button)
			make("TextLabel", {
				Position = UDim2.fromOffset(12, 28),
				Size = UDim2.new(1, -20, 0, 16),
				BackgroundTransparency = 1,
				FontFace = MEDIUM,
				TextSize = 13,
				TextColor3 = MUTED,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = CLASS_NAMES[w.class] or w.class,
			}, button)
			button.MouseEnter:Connect(function()
				button.BackgroundColor3 = CARD_HOVER
			end)
			button.MouseLeave:Connect(function()
				button.BackgroundColor3 = CARD
			end)
			button.Activated:Connect(function()
				pick(w.id)
			end)
			table.insert(cards, { button = button, stroke = stroke, id = w.id })
		end
	end

	-- Touch: a small GUNS button, linked to the WeaponPicker action.
	if UserInputService.TouchEnabled then
		local b = make("TextButton", {
			Name = "PickerButton",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0, 56),
			Size = UDim2.fromOffset(64, 32),
			BackgroundColor3 = BACK,
			BackgroundTransparency = 0.4,
			FontFace = BOLD,
			TextSize = 14,
			TextColor3 = WHITE,
			Text = "GUNS",
		}, g)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
		InputController.bindTouchButtons(g)
	end
	return g
end

function PickerController.isOpen(): boolean
	return open
end

-- True while the menu is open or has only just closed (the click that picked
-- a gun must not also fire it).
function PickerController.isBusy(): boolean
	return open or os.clock() - closedAt < CLOSE_GRACE
end

function PickerController.start()
	if not allowed() then
		return
	end
	build()
	InputController.onPressed("WeaponPicker", function()
		setOpen(not open)
	end)
	player.CharacterRemoving:Connect(function()
		setOpen(false)
	end)
end

return PickerController
