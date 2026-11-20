--!strict
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage.Shared.Config.SkinPreview)
local Preview = require(ReplicatedStorage.Shared.SkinPreview)
local Net = require(ReplicatedStorage.Shared.Net)
local CameraController = require(script.Parent.CameraController)
local WeaponController = require(script.Parent.WeaponController)
local ChamberFlow = require(script.Parent.Parent.Util.ChamberFlow)

local SkinPreviewController = {}
local PLATE = Color3.fromHex("10141B")
local ROW = Color3.fromHex("212A37")
local TEXT = Color3.fromHex("F4F6F9")
local MUTED = Color3.fromHex("A9B2BF")
local GOLD = Color3.fromHex("FFC83D")
local FONT = Font.new("rbxasset://fonts/families/TitilliumWeb.json", Enum.FontWeight.SemiBold)

local function button(parent: Instance, name: string, size: UDim2, position: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = size
	b.Position = position
	b.BackgroundColor3 = ROW
	b.TextColor3 = TEXT
	b.FontFace = FONT
	b.TextSize = 16
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = b
	b.Parent = parent
	return b
end

function SkinPreviewController.start()
	if not Preview.allowed() then
		return
	end
	-- Camera guns follow their owner's pick even for players who can't pick
	-- (Config.USER_IDS), e.g. while spectating someone who can.
	Preview.watch()
	ChamberFlow.start()
	local player = Players.LocalPlayer
	if not Preview.canUse(player) then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SkinPreview"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 18

	local toggle = button(gui, "OpenSkins", UDim2.fromOffset(190, 34), UDim2.new(1, -18, 0.63, 0))
	toggle.AnchorPoint = Vector2.new(1, 1)

	local overlay = button(gui, "CloseOnOutsideClick", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
	overlay.BackgroundTransparency = 1
	overlay.AutoButtonColor = false
	overlay.Selectable = false
	overlay.Modal = true
	overlay.Text = ""
	overlay.Visible = false

	local panel = Instance.new("Frame")
	panel.Name = "Lines"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -18, 0.5, 0)
	panel.Size = UDim2.fromOffset(235, 58 + #Config.LINES * 44)
	panel.BackgroundColor3 = PLATE
	panel.Active = true
	panel.Parent = overlay
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = TEXT
	stroke.Transparency = 0.85
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Text = "SKINS"
	title.TextColor3 = TEXT
	title.BackgroundTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.Bold)
	title.TextSize = 18
	title.Position = UDim2.fromOffset(13, 8)
	title.Size = UDim2.fromOffset(162, 34)
	title.Parent = panel
	local close = button(panel, "Close", UDim2.fromOffset(40, 30), UDim2.new(1, -50, 0, 10))
	close.Text = "×"

	local rows: { [string]: TextButton } = {}
	local function setOpen(open: boolean)
		if overlay.Visible == open then
			return
		end
		overlay.Visible = open
		toggle.Visible = not open
		CameraController.setCursorVisible(open)
		WeaponController.setHolstered("SkinPreview", open)
	end
	local function selectLine(line: string)
		if line ~= Preview.line() then
			Net.event(Config.REMOTE):FireServer(line)
		end
	end
	for index, line in Config.LINES do
		local b = button(
			panel,
			line,
			UDim2.new(1, -24, 0, 39),
			UDim2.fromOffset(12, 48 + (index - 1) * 44)
		)
		b.Activated:Connect(function()
			selectLine(line)
			setOpen(false)
		end)
		rows[line] = b
	end
	local function refresh()
		local current = Preview.line()
		toggle.Text = "Skins · " .. current .. "   [;]"
		for line, row in rows do
			local selected = current == line
			row.Text = if selected then "✓   " .. line else line
			row.TextColor3 = if selected then GOLD else MUTED
		end
	end
	refresh()
	gui.Parent = player:WaitForChild("PlayerGui")
	toggle.Activated:Connect(function()
		setOpen(true)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)
	overlay.Activated:Connect(function()
		setOpen(false)
	end)
	StateValues.changed(player, Config.ATTRIBUTE):Connect(refresh)
	ContextActionService:BindActionAtPriority(
		"SkinPreview",
		function(_, state, input)
			if UserInputService:GetFocusedTextBox() then
				return Enum.ContextActionResult.Pass
			end
			if state == Enum.UserInputState.Begin then
				if input.KeyCode == Config.MENU_KEY then
					setOpen(not overlay.Visible)
				else
					local index = table.find(Config.LINES, Preview.line()) or 1
					local backwards = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
						or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
					local nextIndex = ((index - 1 + (if backwards then -1 else 1)) % #Config.LINES)
						+ 1
					selectLine(Config.LINES[nextIndex])
				end
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Config.KEY,
		Config.CYCLE_KEY,
		Config.MENU_KEY
	)
end

return SkinPreviewController
