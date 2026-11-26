--!strict
-- The top-right bar in a match and in the range: SETTINGS, and in the range LEAVE (owner 2026-11-26: "a button to
-- leave ... a little leave thing ... L on computer and then some other keybind on controllers"). Leave, the L key
-- and D-pad left (Config/Input RangeLeave, rebindable in Settings) send you back to the lobby behind the loading
-- card (Util/RangeTransition; the server's RangeService checks the trip). The buttons are the Studio template
-- UI.Match.MatchSettingsTopbar (Leave added by tools/studio/AddLeaveButton.luau).
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local RS = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local PlayZone = require(RS.Shared.PlayZone)
local UiMotion = require(RS.Shared.UiMotion)
local UiLayout = require(RS.Shared.UiLayout)
local InputMode = require(RS.Shared.InputMode)
local RangeTransition = require(script.Parent.Parent.Util.RangeTransition)
local Router = require(script.Parent.Parent.Util.Router)

local MatchSettingsButton = {}
local player = Players.LocalPlayer
local GAP = 12

local function shownIn(zone: string): boolean
	return zone == "Match" or zone == "Range"
end

-- Back to the lobby from the range (a menu open closes first).
local function leaveRange()
	if PlayZone.get(player) ~= "Range" or UserInputService:GetFocusedTextBox() ~= nil then
		return
	end
	if Router.current() ~= nil then
		Router.close()
	end
	RangeTransition.travel()
end

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
		local inRange = PlayZone.get(player) == "Range"
		local count = 0
		for _, name in { "Leave", "Settings" } do
			local button = bar:FindFirstChild(name)
			if button and button:IsA("GuiButton") then
				button.Visible = name ~= "Leave" or inRange
				if button.Visible then
					count += 1
				end
				button.Size = UDim2.fromOffset(btnSize, btnSize)
				local icon = button:FindFirstChild("Icon", true)
				if icon and icon:IsA("ImageLabel") then
					local iconSize = math.round(btnSize * 26 / 44)
					icon.Size = UDim2.fromOffset(iconSize, iconSize)
				end
				local glyph = button:FindFirstChild("Glyph", true)
				if glyph and glyph:IsA("Frame") then
					local glyphSize = math.round(btnSize * 24 / 44)
					glyph.Size = UDim2.fromOffset(glyphSize, glyphSize)
				end
			end
		end
		count = math.max(count, 1)
		bar.Size = UDim2.fromOffset(btnSize * count + GAP * (count - 1), btnSize)

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
				if shownIn(PlayZone.get(player)) then
					Router.toggle("Settings")
				end
			end)
		end
		local leave = screen:FindFirstChild("Leave", true)
		local leavePop = leave and leave:FindFirstChild("Pop", true)
		if leave and leave:IsA("GuiButton") and leavePop and leavePop:IsA("UIScale") then
			UiMotion.button(leave, leavePop, leaveRange)
		end
		screen.Enabled = shownIn(PlayZone.get(player))
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
			screen.Enabled = shownIn(zone)
			if screen.Enabled then
				layout()
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local zone = PlayZone.get(player)
		-- D-pad right opens the gun terminal in the range (LoadoutController), so it's Settings in a match only
		if
			(input.KeyCode == Enum.KeyCode.F10 and shownIn(zone))
			or (input.KeyCode == Enum.KeyCode.DPadRight and zone == "Match")
		then
			Router.toggle("Settings")
		end
	end)
	-- L / D-pad left (Config/Input RangeLeave: an InputAction, so a rebind in Settings applies)
	task.spawn(function()
		local ctx = player:WaitForChild("PlayContext", 60)
		if not ctx then
			return
		end
		local function hook(a: Instance)
			if a:IsA("InputAction") and a.Name == "RangeLeave" then
				a.Pressed:Connect(function()
					if Router.current() == nil then
						leaveRange()
					end
				end)
			end
		end
		for _, a in ctx:GetChildren() do
			hook(a)
		end
		ctx.ChildAdded:Connect(hook)
	end)
	RangeTransition.start()
end

return MatchSettingsButton
