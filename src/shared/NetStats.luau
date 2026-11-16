--!strict
-- The server / FPS / ping readout (vault/02 Art/UI Match Overhaul.md), lobby
-- and match, after RIVALS' "Details" chip: a small dark plate in the Roblox
-- top bar row, top right, two lines:
--   VIRGINIA, US                (Shared/ServerRegion)
--   [bars] 144 FPS   32 MS      (bars: 3 green / 2 gold / 1 red by ping)
-- Client only. NetStats.mount(rightInset) builds its own ScreenGui.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config.NetStats)
local ServerRegion = require(script.Parent.ServerRegion)

local NetStats = {}

local RUBIK = "rbxassetid://12187365977"
local BOLD = Font.new(RUBIK, Enum.FontWeight.Bold)
local HEAVY = Font.new(RUBIK, Enum.FontWeight.Heavy)
local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromHex("A9A9B0")
local GOOD = Color3.fromHex("64FF32")
local OK = Color3.fromHex("FFD700")
local BAD = Color3.fromHex("FF3232")
local OFF = Color3.fromHex("4A4A52")
local HEIGHT = 40

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local i = Instance.new(class)
	for k, v in props do
		(i :: any)[k] = v
	end
	if parent then
		i.Parent = parent
	end
	return i
end

local function label(
	parent: Instance,
	name: string,
	font: Font,
	size: number,
	color: Color3,
	order: number
): TextLabel
	return make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, size + 2),
		FontFace = font,
		TextSize = size,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Right,
		LayoutOrder = order,
		Text = "",
	}, parent)
end

-- Builds the readout and keeps it updated. `rightInset`: px from the right edge.
function NetStats.mount(rightInset: number): ScreenGui
	local player = Players.LocalPlayer
	local gui = make("ScreenGui", {
		Name = "NetStats",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 90,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local inset = game:GetService("GuiService"):GetGuiInset()
	local plate = make("Frame", {
		Name = "Plate",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -rightInset, 0, math.max(inset.Y, HEIGHT + 8) / 2),
		Size = UDim2.fromOffset(0, HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromHex("0F0F12"),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, plate)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
	}, plate)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 1),
	}, plate)
	local region = label(plate, "Region", BOLD, 12, MUTED, 1)
	local row = make("Frame", {
		Name = "Row",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 16),
		LayoutOrder = 2,
	}, plate)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}, row)
	local bars = make("Frame", {
		Name = "Bars",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(14, 12),
		LayoutOrder = 1,
	}, row)
	local barList: { Frame } = {}
	for i = 1, 3 do
		local h = 4 + (i - 1) * 4
		barList[i] = make("Frame", {
			Name = "Bar" .. i,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, (i - 1) * 5, 1, 0),
			Size = UDim2.fromOffset(3, h),
			BackgroundColor3 = OFF,
			BorderSizePixel = 0,
		}, bars)
	end
	local fps = label(row, "Fps", HEAVY, 14, WHITE, 2)
	local ping = label(row, "Ping", HEAVY, 14, WHITE, 3)
	gui.Parent = player:WaitForChild("PlayerGui")

	local function showRegion()
		region.Text = ServerRegion.get()
	end
	showRegion()
	ServerRegion.changed():Connect(showRegion)

	local frames: { number } = {}
	local sum = 0
	RunService.RenderStepped:Connect(function(dt: number)
		table.insert(frames, dt)
		sum += dt
		if #frames > Config.FPS_FRAMES then
			sum -= table.remove(frames, 1) :: number
		end
	end)
	task.spawn(function()
		while gui.Parent do
			local avg = if #frames > 0 then sum / #frames else 1 / 60
			fps.Text = string.format("%d FPS", math.floor(1 / math.max(avg, 1e-3) + 0.5))
			local ms = math.floor(player:GetNetworkPing() * 1000 + 0.5)
			ping.Text = string.format("%d MS", ms)
			local level = if ms < Config.PING.good then 3 elseif ms < Config.PING.ok then 2 else 1
			local color = if level == 3 then GOOD elseif level == 2 then OK else BAD
			for i, b in barList do
				b.BackgroundColor3 = if i <= level then color else OFF
			end
			task.wait(Config.REFRESH)
		end
	end)
	return gui
end

return NetStats
