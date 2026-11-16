--!strict
-- The server / FPS / ping readout (vault/02 Art/UI Match Overhaul.md), lobby
-- and match, as simple as RIVALS' (owner, 2026-11-16): no plate, two small
-- right-aligned lines in the Roblox top bar row, top right:
--   France      (globe)        Shared/ServerRegion
--   13fps 1ms   (bars)         3 green / 2 gold / 1 red bars by ping
-- Client only. NetStats.mount(rightInset) builds its own ScreenGui.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config.NetStats)
local ServerRegion = require(script.Parent.ServerRegion)

local NetStats = {}

local FONT = Font.new("rbxassetid://12187365977", Enum.FontWeight.Medium, Enum.FontStyle.Italic)
local TEXT = Color3.fromHex("D8D8DC")
local GOOD = Color3.fromHex("64FF32")
local OK = Color3.fromHex("FFD700")
local BAD = Color3.fromHex("FF3232")
local OFF = Color3.fromHex("6A6A70")
local GLOBE = "rbxassetid://84851804750230"
local SIZE = 14

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

local function line(parent: Instance, order: number): (TextLabel, Frame)
	local row = make("Frame", {
		Name = "Line" .. order,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, SIZE + 3),
		LayoutOrder = order,
	}, parent)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 5),
	}, row)
	local text = make("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, SIZE + 3),
		FontFace = FONT,
		TextSize = SIZE,
		TextColor3 = TEXT,
		TextXAlignment = Enum.TextXAlignment.Right,
		LayoutOrder = 1,
		Text = "",
	}, row)
	make("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.7, Thickness = 1 }, text)
	local icon = make("Frame", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(SIZE - 1, SIZE - 1),
		LayoutOrder = 2,
	}, row)
	return text, icon
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
	local stack = make("Frame", {
		Name = "Stack",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -rightInset, 0, math.max(inset.Y, 44) / 2),
		Size = UDim2.fromOffset(0, 2 * (SIZE + 3)),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
	}, gui)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, stack)
	local region, globeBox = line(stack, 1)
	make("ImageLabel", {
		Name = "Globe",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = GLOBE,
		ImageColor3 = TEXT,
	}, globeBox)
	local stats, barBox = line(stack, 2)
	local barList: { Frame } = {}
	for i = 1, 3 do
		barList[i] = make("Frame", {
			Name = "Bar" .. i,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 1 + (i - 1) * 4, 1, -1),
			Size = UDim2.fromOffset(3, 3 + (i - 1) * 4),
			BackgroundColor3 = OFF,
			BorderSizePixel = 0,
		}, barBox)
	end
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
			local fps = math.floor(1 / math.max(avg, 1e-3) + 0.5)
			local ms = math.floor(player:GetNetworkPing() * 1000 + 0.5)
			stats.Text = string.format("%dfps  %dms", fps, ms)
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
