--!strict
-- Level and device marks for a player in the match UI (Config/PlayerTags;
-- vault/02 Art/UI Match Overhaul.md): the Tab scoreboard puts them after the
-- name, the top bar on each headshot tile. They follow the player's "Level"
-- and "Device" attributes live and disconnect when destroyed. A bot (no
-- player) gets a BOT chip instead.
--
--   PlayerTags.level(parent, player?, size, z?)   -> Frame "LevelTag" ("LV 12" / "BOT")
--   PlayerTags.device(parent, player?, size, z?)  -> ImageLabel "DeviceTag" (hidden for bots)
-- `z` sets the ZIndex (screens with Global ZIndex need it).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.PlayerTags)

local PlayerTags = {}

local RUBIK = "rbxassetid://12187365977"
local HEAVY = Font.new(RUBIK, Enum.FontWeight.Heavy)
local PLATE = Color3.fromHex("141418")
local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromHex("A9A9B0")

local function follow(obj: Instance, player: Player, attribute: string, apply: () -> ())
	apply()
	local conn = player:GetAttributeChangedSignal(attribute):Connect(apply)
	obj.Destroying:Connect(function()
		conn:Disconnect()
	end)
end

-- A small dark chip: "LV 12" for a player, "BOT" for a bot. `size` = text px.
function PlayerTags.level(parent: Instance, player: Player?, size: number, z: number?): Frame
	local chip = Instance.new("Frame")
	chip.Name = "LevelTag"
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Size = UDim2.fromOffset(0, size + 6)
	chip.BackgroundColor3 = PLATE
	chip.BackgroundTransparency = 0.1
	chip.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = chip
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 5)
	pad.PaddingRight = UDim.new(0, 5)
	pad.Parent = chip
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.AutomaticSize = Enum.AutomaticSize.X
	text.Size = UDim2.fromScale(0, 1)
	text.FontFace = HEAVY
	text.TextSize = size
	text.Parent = chip
	if z then
		chip.ZIndex = z
		text.ZIndex = z + 1
	end
	if player then
		text.TextColor3 = WHITE
		follow(chip, player, "Level", function()
			local level = player:GetAttribute("Level")
			text.Text = "LV "
				.. tostring(if typeof(level) == "number" then math.floor(level) else 1)
		end)
	else
		text.TextColor3 = MUTED
		text.Text = "BOT"
	end
	chip.Parent = parent
	return chip
end

-- The player's device icon (white; tint it with ImageColor3). `size` = px.
function PlayerTags.device(parent: Instance, player: Player?, size: number, z: number?): ImageLabel
	local icon = Instance.new("ImageLabel")
	icon.Name = "DeviceTag"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(size, size)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Visible = false
	if z then
		icon.ZIndex = z
	end
	if player then
		follow(icon, player, "Device", function()
			local device = player:GetAttribute("Device")
			local image = if typeof(device) == "string" then (Config.ICONS :: any)[device] else nil
			icon.Image = image or ""
			icon.Visible = image ~= nil
		end)
	end
	icon.Parent = parent
	return icon
end

return PlayerTags
