--!strict
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local RS = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local PlayZone = require(RS.Shared.PlayZone)
local UiMotion = require(RS.Shared.UiMotion)
local UiLayout = require(RS.Shared.UiLayout)
local InputMode = require(RS.Shared.InputMode)
local Router = require(script.Parent.Parent.Util.Router)

local MatchSettingsButton = {}
local player = Players.LocalPlayer

function MatchSettingsButton.start()
	local playerGui = player:WaitForChild("PlayerGui")
	local sizeConn: RBXScriptConnection? = nil
	local viewportConn: RBXScriptConnection? = nil

	local function layout()
		local screen = playerGui:FindFirstChild("MatchSettingsTopbar")
		local bar = screen and screen:FindFirstChild("Bar")
		if not screen or not screen:IsA("ScreenGui") or not bar or not bar:IsA("Frame") then
			return
		end
		local family = UiLayout.family()
		local camera = Workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize
		local mobile = family == "Phone"
			or family == "Tablet"
			or (
				UserInputService.TouchEnabled
				and viewport ~= nil
				and math.min(viewport.X, viewport.Y) < UiLayout.PHONE_SHORT_SIDE
			)

		local inset = GuiService.TopbarInset
		local btnSize = if inset.Height > 0
			then math.clamp(math.floor(inset.Height), 36, 44)
			else 44
		bar.Size = UDim2.fromOffset(btnSize, btnSize)

		local button = bar:FindFirstChild("Settings")
		if button and button:IsA("GuiButton") then
			button.Size = UDim2.fromOffset(btnSize, btnSize)
			local icon = button:FindFirstChild("Icon", true)
			if icon and icon:IsA("ImageLabel") then
				local iconSize = math.round(btnSize * 26 / 44)
				icon.Size = UDim2.fromOffset(iconSize, iconSize)
			end
		end

		local listLayout = bar:FindFirstChildOfClass("UIListLayout")
		if listLayout then
			listLayout.HorizontalAlignment = if mobile
				then Enum.HorizontalAlignment.Left
				else Enum.HorizontalAlignment.Right
		end

		bar.AnchorPoint = Vector2.new(if mobile then 0 else 1, 0.5)
		bar.Position = if mobile then UDim2.new(0, 12, 0.5, 0) else UDim2.new(1, -12, 0.5, 0)
	end

	local function watchCamera()
		if viewportConn then
			viewportConn:Disconnect()
			viewportConn = nil
		end
		local camera = Workspace.CurrentCamera
		if camera then
			viewportConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
		end
	end

	local function mount(screen: Instance)
		if screen.Name ~= "MatchSettingsTopbar" or not screen:IsA("ScreenGui") then
			return
		end
		if sizeConn then
			sizeConn:Disconnect()
			sizeConn = nil
		end
		sizeConn = screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
		local button = screen:FindFirstChild("Settings", true)
		local pop = button and button:FindFirstChild("Pop", true)
		if button and button:IsA("GuiButton") and pop and pop:IsA("UIScale") then
			UiMotion.button(button, pop, function()
				if PlayZone.get(player) == "Match" then
					Router.toggle("Settings")
				end
			end)
		end
		screen.Enabled = PlayZone.get(player) == "Match"
		layout()
	end

	watchCamera()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		watchCamera()
		layout()
	end)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layout)
	InputMode.changed:Connect(layout)
	playerGui.ChildAdded:Connect(mount)
	local current = playerGui:FindFirstChild("MatchSettingsTopbar")
	if current then
		mount(current)
	end
	PlayZone.onLocalChanged(function(zone)
		if Router.current() == "Settings" then
			Router.close()
		end
		local screen = playerGui:FindFirstChild("MatchSettingsTopbar")
		if screen and screen:IsA("ScreenGui") then
			screen.Enabled = zone == "Match"
			if zone == "Match" then
				layout()
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if
			not processed
			and (input.KeyCode == Enum.KeyCode.F10 or input.KeyCode == Enum.KeyCode.DPadRight)
			and PlayZone.get(player) == "Match"
		then
			Router.toggle("Settings")
		end
	end)
end

return MatchSettingsButton
