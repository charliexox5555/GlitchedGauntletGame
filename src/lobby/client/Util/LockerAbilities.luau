--!strict
-- The Mod collection fills the existing Locker canvas under its tabs: the power deck
-- (vault/01 Design/Loadout and Power Deck.md). A DECK n / 10 line on top; every owned power can be
-- equipped into the deck the draft deals from (Config/Mods DECK_MIN to DECK_SIZE, the server checks it
-- again in Services/LockerService); powers not owned show LOCKED.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local ModLoadout = require(ReplicatedStorage.Shared.ModLoadout)
local Mods = require(ReplicatedStorage.Shared.Mods)
local ModsConfig = require(ReplicatedStorage.Shared.Config.Mods)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Cards = require(script.Parent.Cards)

local LockerAbilities = {}
local COLORS = Theme.COLORS
local GAP = 16

local function label(
	parent: GuiObject,
	name: string,
	text: string,
	font: Font,
	color: Color3,
	position: UDim2,
	size: UDim2
): TextLabel
	local out = Instance.new("TextLabel")
	out.Name = name
	out.BackgroundTransparency = 1
	out.FontFace = font
	out.Text = text
	out.TextColor3 = color
	out.TextXAlignment = Enum.TextXAlignment.Left
	out.Position = position
	out.Size = size
	out.ZIndex = parent.ZIndex + 1
	out.Parent = parent
	return out
end

function LockerAbilities.mount(canvas: Frame, player: Player): Frame
	local fit = canvas:WaitForChild("Fit") :: UIScale
	local root = Instance.new("Frame")
	root.Name = "AbilityCollection"
	root.BackgroundTransparency = 1
	root.Position = UDim2.fromOffset(64, 188)
	root.Size = UDim2.new(1, -128, 1, -216)
	root.ZIndex = 5
	root.Visible = false
	root.Parent = canvas

	local deckLine = label(
		root,
		"Deck",
		"DECK",
		Theme.TEXT.titleS.font,
		COLORS.text,
		UDim2.new(),
		UDim2.new(0.3, 0, 0, 40)
	)
	local feedback = label(
		root,
		"Feedback",
		"",
		Theme.TEXT.bodyM.font,
		COLORS.textSecondary,
		UDim2.new(0.3, 0, 0, 0),
		UDim2.new(0.7, 0, 0, 40)
	)
	feedback.TextXAlignment = Enum.TextXAlignment.Right
	feedback.Visible = false

	local list = Instance.new("ScrollingFrame")
	list.Name = "Mods"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.fromScale(1, 1)
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = COLORS.lineStrong
	list.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	list.Selectable = false
	list.ZIndex = root.ZIndex
	list.Parent = root

	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.CellPadding = UDim2.fromOffset(GAP, GAP)
	grid.Parent = list

	local ids = {}
	for id in ModsConfig.defs do
		if Mods.isBuilt(id) then
			table.insert(ids, id)
		end
	end
	-- The starter deck first, then the catalog order (Config/Mods ORDER).
	table.sort(ids, function(a, b)
		local sa = table.find(ModsConfig.STARTER_DECK, a) ~= nil
		local sb = table.find(ModsConfig.STARTER_DECK, b) ~= nil
		if sa ~= sb then
			return sa
		end
		return (table.find(ModsConfig.ORDER, a) or 99) < (table.find(ModsConfig.ORDER, b) or 99)
	end)

	local remote = LobbyNet.event("LockerModRequest")
	local loadout = PlayerData.mods(player)
	local pending: string? = nil
	local actions: { [string]: TextButton } = {}
	local locks: { [string]: Frame } = {}
	local textSizes: { [TextLabel]: number } = { [feedback] = 24, [deckLine] = 30 }

	local function refresh()
		loadout = PlayerData.mods(player)
		local count = ModLoadout.equippedCount(loadout)
		deckLine.Text = string.format("DECK  %d / %d", count, ModsConfig.DECK_SIZE)
		for id, button in actions do
			local owned = loadout.owned[id] == true
			local equipped = ModLoadout.eligible(id, loadout)
			-- Equip only with room in the deck; unequip only above the minimum.
			local can = if equipped
				then ModLoadout.canUnequip(loadout, id)
				else ModLoadout.canEquip(loadout, id)
			local muted = equipped or pending ~= nil or not can
			button.Visible = owned
			button.Text = if pending == id
				then "SAVING…"
				elseif equipped then "UNEQUIP"
				elseif not can then "DECK FULL"
				else "EQUIP"
			button.BackgroundColor3 = if muted then COLORS.raised else COLORS.gold
			button.TextColor3 = if muted
				then (if can or pending then COLORS.text else COLORS.textSecondary)
				else COLORS.onAccent
			button.AutoButtonColor = pending == nil and can
			locks[id].Visible = not owned
		end
	end

	for order, id in ids do
		local def = ModsConfig.defs[id]
		local card = Instance.new("Frame")
		card.Name = id
		card.LayoutOrder = order
		card.BackgroundColor3 = COLORS.card
		card.BorderSizePixel = 0
		card.ZIndex = root.ZIndex
		card.Parent = list
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = card

		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.Image = def.icon
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Position = UDim2.new(0, 18, 0.06, 0)
		icon.Size = UDim2.new(0, 62, 0.32, 0)
		icon.ZIndex = card.ZIndex + 1
		icon.Parent = card

		local title = label(
			card,
			"Title",
			string.upper(def.name),
			Theme.TEXT.titleCard.font,
			COLORS.text,
			UDim2.new(0, 96, 0.06, 0),
			UDim2.new(1, -114, 0.2, 0)
		)
		title.TextTruncate = Enum.TextTruncate.AtEnd
		textSizes[title] = 31
		local role = label(
			card,
			"Role",
			string.upper(def.role),
			Theme.TEXT.label.font,
			Theme.ROLE[def.role] or COLORS.textSecondary,
			UDim2.new(0, 96, 0.25, 0),
			UDim2.new(1, -114, 0.14, 0)
		)
		textSizes[role] = 20
		local desc = label(
			card,
			"Description",
			def.levels.L1.note or "",
			Theme.TEXT.bodyM.font,
			COLORS.textSecondary,
			UDim2.new(0, 18, 0.4, 0),
			UDim2.new(1, -36, 0.24, 0)
		)
		desc.TextWrapped = true
		textSizes[desc] = 23

		local footer = Instance.new("Frame")
		footer.Name = "Locked"
		footer.BackgroundTransparency = 1
		footer.Position = UDim2.new(0, 18, 0.67, 0)
		footer.Size = UDim2.new(1, -36, 0.3, 0)
		footer.ZIndex = card.ZIndex + 1
		footer.Parent = card
		local lock = Instance.new("ImageLabel")
		lock.Name = "Lock"
		lock.AnchorPoint = Vector2.new(0, 0.5)
		lock.Position = UDim2.new(0, -7, 0.5, 0)
		lock.Size = UDim2.fromOffset(38, 38)
		lock.BackgroundTransparency = 1
		lock.Image = Theme.ICON.Lock
		lock.ImageColor3 = COLORS.textSecondary
		lock.ZIndex = footer.ZIndex + 1
		lock.Parent = footer
		local status = label(
			footer,
			"Status",
			if def.free then "ALWAYS EQUIPPED" else "LOCKED",
			Theme.TEXT.label.font,
			COLORS.textSecondary,
			UDim2.fromOffset(36, 0),
			UDim2.new(1, -36, 1, 0)
		)
		textSizes[status] = 22

		if not def.free then
			locks[id] = footer
			local button = Instance.new("TextButton")
			button.Name = "Equip"
			button.Text = "EQUIP"
			button.FontFace = Theme.TEXT.titleS.font
			button.BorderSizePixel = 0
			button.Position = footer.Position
			button.Size = footer.Size
			button.ZIndex = card.ZIndex + 2
			button.Parent = card
			Cards.finish(button)
			actions[id] = button
			button.Activated:Connect(function()
				if pending or not loadout.owned[id] then
					return
				end
				local equip = not ModLoadout.eligible(id, loadout)
				if equip and not ModLoadout.canEquip(loadout, id) then
					feedback.Text = string.format(
						"Your deck is full (%d). Unequip a power first.",
						ModsConfig.DECK_SIZE
					)
					return
				elseif not equip and not ModLoadout.canUnequip(loadout, id) then
					feedback.Text =
						string.format("Your deck needs at least %d powers.", ModsConfig.DECK_MIN)
					return
				end
				pending = id
				feedback.Text = ""
				refresh()
				remote:FireServer(id, equip)
			end)
		end
		Cards.finish(card)
	end

	local function resize()
		local scale = math.max(fit.Scale, 0.01)
		local width = root.AbsoluteSize.X
		local columns = if width >= 1050 then 3 elseif width >= 550 then 2 else 1
		grid.FillDirectionMaxCells = columns
		grid.CellSize = UDim2.fromOffset(
			math.max(1, math.floor((width / scale - 12 - GAP * (columns - 1)) / columns)),
			math.max(192, math.ceil(148 / scale))
		)
		local textFloor = math.ceil(12 / scale)
		for item, size in textSizes do
			item.TextSize = math.max(size, textFloor)
		end
		for _, button in actions do
			button.TextSize = math.max(24, textFloor)
		end
		feedback.Visible = feedback.Text ~= ""
		local top = math.max(48, textFloor + 6)
		feedback.Size = UDim2.new(0.7, 0, 0, top)
		deckLine.Size = UDim2.new(0.3, 0, 0, top)
		list.Position = UDim2.fromOffset(0, top)
		list.Size = UDim2.new(1, 0, 1, -top)
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	fit:GetPropertyChangedSignal("Scale"):Connect(resize)
	feedback:GetPropertyChangedSignal("Text"):Connect(resize)
	resize()
	refresh()

	local function watch(value: Instance)
		if value.Name == PlayerData.MODS and value:IsA("StringValue") then
			value.Changed:Connect(refresh)
			refresh()
		end
	end
	player.ChildAdded:Connect(watch)
	local value = player:FindFirstChild(PlayerData.MODS)
	if value then
		watch(value)
	end
	remote.OnClientEvent:Connect(function(saved: boolean)
		if pending then
			pending = nil
			feedback.Text = if saved then "" else "Couldn’t save your power. Try again."
			refresh()
		end
	end)
	return root
end

return LockerAbilities
