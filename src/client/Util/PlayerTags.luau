--!strict
-- Level and device marks for a player in the match UI (Config/PlayerTags;
-- vault/02 Art/UI Match Overhaul.md): the Tab scoreboard puts them after the
-- name, the top bar on each headshot tile. They follow the player's "Level"
-- and "Device" attributes live and disconnect when destroyed. Bots use
-- their assigned level and device, plus an account headshot when available.
--
--   PlayerTags.level(parent, fighter?, size, z?, savedLevel?) -> Frame "LevelTag"
--   PlayerTags.device(parent, fighter?, size, z?)  -> ImageLabel "DeviceTag"
--   PlayerTags.title(parent, player?, size, z?)    -> TextLabel "TitleTag" (gold; hidden with no title, bots)
-- `z` sets the ZIndex (screens with Global ZIndex need it).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local Config = require(ReplicatedStorage.Shared.Config.PlayerTags)

local PlayerTags = {}

local RUBIK = "rbxassetid://12187365977"
local HEAVY = Font.new(RUBIK, Enum.FontWeight.Heavy)
local PLATE = Color3.fromHex("141418")
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromHex("FFC83D") -- titles (Style Bible: gold = the flex; LobbyHudView TITLE_GOLD)
local TITLE_CHARS = 16 -- longer titles end in "..." so a row never grows

local function follow(obj: Instance, player: Instance, attribute: string, apply: () -> ())
	apply()
	local conn = StateValues.changed(player, attribute):Connect(apply)
	obj.Destroying:Connect(function()
		conn:Disconnect()
	end)
end

-- A small dark level chip. `savedLevel` covers bots whose model streamed out.
function PlayerTags.level(
	parent: Instance,
	fighter: Instance?,
	size: number,
	z: number?,
	savedLevel: number?
): Frame
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
	text.TextColor3 = WHITE
	if fighter then
		follow(chip, fighter, "Level", function()
			local level = StateValues.get(fighter, "Level")
			text.Text = "LV "
				.. tostring(
					if typeof(level) == "number" then math.floor(level) else savedLevel or 1
				)
		end)
	else
		text.Text = "LV " .. tostring(savedLevel or 1)
	end
	chip.Parent = parent
	return chip
end

-- The equipped title (Shared/PlayerData.title) as a small gold word after the name, following the
-- "Title" StateValue live. A bot, a player who left, or no title: hidden.
function PlayerTags.title(parent: Instance, who: Player?, size: number, z: number?): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = "TitleTag"
	text.BackgroundTransparency = 1
	text.AutomaticSize = Enum.AutomaticSize.X
	text.Size = UDim2.fromOffset(0, size + 4)
	text.FontFace = HEAVY
	text.TextSize = size
	text.TextColor3 = GOLD
	text.Visible = false
	if z then
		text.ZIndex = z
	end
	if who then
		follow(text, who, "Title", function()
			local title = PlayerData.title(who)
			if title and utf8.len(title) and (utf8.len(title) :: number) > TITLE_CHARS then
				title = string.sub(
					title,
					1,
					(utf8.offset(title, TITLE_CHARS) or (TITLE_CHARS + 1)) - 1
				) .. "..."
			end
			text.Text = title or ""
			text.Visible = title ~= nil
		end)
	end
	text.Parent = parent
	return text
end

-- Matches the existing player headshot format. A bot's portrait account
-- is cosmetic and remains separate from the identity used for stats.
function PlayerTags.headshot(userId: unknown, fallback: string): string
	if typeof(userId) == "number" and userId > 0 then
		return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId)
	end
	return fallback
end

-- The placeholder occupies the same tile until the account image is ready.
function PlayerTags.loadHeadshot(image: ImageLabel, userId: unknown, fallback: string)
	local source = PlayerTags.headshot(userId, fallback)
	local placeholder = image:FindFirstChild("LoadingPortrait") :: ImageLabel?
	if source ~= fallback and not placeholder then
		placeholder = Instance.new("ImageLabel")
		placeholder.Name = "LoadingPortrait"
		placeholder.Size = UDim2.fromScale(1, 1)
		placeholder.BackgroundTransparency = 1
		placeholder.ZIndex = image.ZIndex
		placeholder.Image = fallback
		placeholder.ScaleType = image.ScaleType
		placeholder.Parent = image
		image:GetPropertyChangedSignal("IsLoaded"):Connect(function()
			placeholder.Visible = image.Image ~= fallback and not image.IsLoaded
		end)
	end
	if image.Image ~= source then
		image.Image = source
	end
	if placeholder then
		placeholder.Visible = source ~= fallback and not image.IsLoaded
	end
end

-- The player's device icon (white; tint it with ImageColor3). `size` = px.
function PlayerTags.device(
	parent: Instance,
	fighter: Instance?,
	size: number,
	z: number?
): ImageLabel
	local icon = Instance.new("ImageLabel")
	icon.Name = "DeviceTag"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(size, size)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Visible = false
	if z then
		icon.ZIndex = z
	end
	if fighter then
		follow(icon, fighter, "Device", function()
			local device = StateValues.get(fighter, "Device")
			local image = if typeof(device) == "string" then (Config.ICONS :: any)[device] else nil
			icon.Image = image or ""
			icon.Visible = image ~= nil
		end)
	end
	icon.Parent = parent
	return icon
end

return PlayerTags
