--!strict
-- The draft screen (rough, PC first; final design comes later): 3 guns on top, 3
-- abilities below, your kit and LOCK IN at the bottom, like Gauntlet: Glitched
-- (vault/01 Design/Match Flow.md). The server dealt these cards and checks every
-- pick; this only shows them and asks. Layout is Scale inside a 16:9 panel.
-- Each ability has its own slot (its key chip shows it). Once the slots are
-- full, the row shows one column per slot with that ability's upgrade cards
-- (vault/01 Design/Abilities/Upgrade Paths.md); the glitch card is magenta.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchState = require(ReplicatedStorage.Shared.MatchState)
local ModsConfig = require(ReplicatedStorage.Shared.Config.Mods)
local Mods = require(ReplicatedStorage.Shared.Mods)
local Net = require(ReplicatedStorage.Shared.Net)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local CameraController = require(script.Parent.CameraController)

local DraftController = {}

local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromHex("A9ADB4")
local BACK = Color3.fromHex("16181B")
local CARD = Color3.fromHex("23262B")
local CARD_HOVER = Color3.fromHex("30343A")
local CARD_OFF = Color3.fromHex("1B1D21")
local ACCENT = Color3.fromHex("F2C94C")
local READY = Color3.fromHex("3FA66A")
local GLITCH = ModsConfig.COLORS.glitch
local GLITCH_CARD = Color3.fromHex("2A1630")
local BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local MEDIUM = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)

local KEYS = { "Q", "E", "T" }
local TICK = 0.1

type Card = { button: TextButton, stroke: UIStroke, id: string, rest: Color3 }

local panel: Frame? = nil
local backdrop: TextButton? = nil
local clock: TextLabel? = nil
local lockButton: TextButton? = nil
local lockHint: TextLabel? = nil
local gunCards: { Card } = {}
local abilityCards: { Card } = {}
local offer: MatchState.DraftOffer? = nil
local selectedGun: string? = nil
local selectedAbility: string? = nil
local isOpen = false

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

local function text(parent: Instance, content: string, props: { [string]: any }): TextLabel
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = BOLD,
		TextColor3 = WHITE,
		TextScaled = true,
		Text = content,
	}, parent)
	for k, v in props do
		(label :: any)[k] = v
	end
	return label
end

local function setOpen(value: boolean)
	if isOpen == value then
		return
	end
	isOpen = value
	if backdrop then
		backdrop.Visible = value
		backdrop.Modal = value -- frees the mouse in first person
	end
	CameraController.setCursorVisible(value)
end

local function nothingToPick(o: MatchState.DraftOffer): boolean
	return #o.abilities == 0 and #(o.upgrades or {}) == 0
end

local function canLock(): boolean
	local o = offer
	if not o then
		return false
	end
	return selectedGun ~= nil and (selectedAbility ~= nil or nothingToPick(o))
end

-- A card's text: the level's note without its "Path: " lead (the card's
-- title already names the path).
local function cardNote(id: string, level: string): string
	local stats = Mods.stats(id, level)
	local note: string = if stats then stats.note or "" else ""
	local rest = string.match(note, "^[%w%s]+:%s*(.+)$")
	return rest or note
end

-- Text that scales with the screen but never past `max` (cards of different
-- lengths would otherwise all come out at different sizes).
local function capText(label: TextLabel, max: number)
	make("UITextSizeConstraint", { MaxTextSize = max }, label)
end

-- "Lv 2 · Ghost" (L1: "Lv 1").
local function levelLabel(id: string, level: string): string
	local def = Mods.def(id)
	local path = string.sub(level, 1, 1)
	local n = string.sub(level, 2, 2)
	local name = if def and path ~= "L" then (def.paths :: any)[path] else nil
	if path == "L" then
		return "Lv 1"
	end
	return string.format("Lv %s · %s", n, name or level)
end

local function refreshSelection()
	for _, c in gunCards do
		c.stroke.Enabled = c.id == selectedGun
	end
	for _, c in abilityCards do
		c.stroke.Enabled = c.id == selectedAbility
	end
	local ready = canLock()
	if lockButton then
		lockButton.BackgroundColor3 = if ready then READY else CARD
		lockButton.TextColor3 = if ready then WHITE else MUTED
	end
	if lockHint then
		local o = offer
		local slot = if o and #o.abilities > 0 then "ability" else nil
		lockHint.Text = if ready
			then "Ready"
			elseif not selectedGun then "Choose a gun"
			elseif o and #(o.upgrades or {}) > 0 then "Choose an upgrade"
			elseif slot then "Choose an ability"
			else ""
	end
end

local function hookCard(button: TextButton, onPick: () -> (), rest: Color3?)
	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = CARD_HOVER
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = rest or CARD
	end)
	button.Activated:Connect(onPick)
end

-- The slot's key on a card's corner (abilities live in fixed slots).
local function keyChip(parent: Instance, slot: number, color: Color3?)
	local chip = make("TextLabel", {
		Position = UDim2.fromScale(0.04, 0.03),
		Size = UDim2.fromScale(0.16, 0.11),
		BackgroundColor3 = BACK,
		FontFace = BOLD,
		TextScaled = true,
		TextColor3 = color or ACCENT,
		Text = KEYS[slot] or "?",
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0.25, 0) }, chip)
	make("UIAspectRatioConstraint", { AspectRatio = 1.2 }, chip)
end

-- A still picture of the gun: the model in a ViewportFrame, framed to fit.
local function gunPicture(parent: Instance, id: string, props: { [string]: any })
	local view = make("ViewportFrame", {
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(190, 190, 190),
		LightColor = WHITE,
	}, parent)
	for k, v in props do
		(view :: any)[k] = v
	end
	local folder = ReplicatedStorage:FindFirstChild("Weapons")
	local template = folder and folder:FindFirstChild(id)
	if not template or not template:IsA("Model") then
		return
	end
	local model = template:Clone()
	model.Parent = view
	local box, size = model:GetBoundingBox()
	local camera = make("Camera", { FieldOfView = 30 }, view)
	view.CurrentCamera = camera
	local distance = math.max(size.X, size.Y, size.Z) * 2.1
	camera.CFrame = CFrame.lookAt(box.Position + box.RightVector * distance, box.Position)
end

local function gunCard(parent: Instance, id: string, index: number, phaseName: string): Card
	local config = Weapons.get(id)
	local button = make("TextButton", {
		Name = id,
		Position = UDim2.fromScale((index - 1) * 0.34, 0),
		Size = UDim2.fromScale(0.32, 1),
		BackgroundColor3 = CARD,
		AutoButtonColor = false,
		Text = "",
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0.05, 0) }, button)
	local stroke = make("UIStroke", {
		Color = ACCENT,
		Thickness = 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Enabled = false,
	}, button)
	gunPicture(button, id, {
		Position = UDim2.fromScale(0.02, 0.05),
		Size = UDim2.fromScale(0.56, 0.9),
	})
	if config then
		text(button, config.displayName, {
			Position = UDim2.fromScale(0.6, 0.1),
			Size = UDim2.fromScale(0.37, 0.24),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		text(
			button,
			string.format("%s · Shield %d", config.class, MatchState.shieldFor(phaseName, id)),
			{
				Position = UDim2.fromScale(0.6, 0.36),
				Size = UDim2.fromScale(0.37, 0.13),
				TextXAlignment = Enum.TextXAlignment.Left,
				FontFace = MEDIUM,
				TextColor3 = MUTED,
			}
		)
		local head = config.damage.head
		text(
			button,
			string.format(
				"Damage %d%s",
				config.damage.body,
				if head then " / head " .. head else ""
			),
			{
				Position = UDim2.fromScale(0.6, 0.53),
				Size = UDim2.fromScale(0.37, 0.13),
				TextXAlignment = Enum.TextXAlignment.Left,
				FontFace = MEDIUM,
			}
		)
		text(
			button,
			string.format("%.1f shots/s · mag %d", 1 / config.fireInterval, config.magSize),
			{
				Position = UDim2.fromScale(0.6, 0.7),
				Size = UDim2.fromScale(0.37, 0.13),
				TextXAlignment = Enum.TextXAlignment.Left,
				FontFace = MEDIUM,
			}
		)
	end
	hookCard(button, function()
		selectedGun = id
		Net.event("DraftPick"):FireServer("Gun", id)
		refreshSelection()
	end)
	return { button = button, stroke = stroke, id = id, rest = CARD }
end

local function abilityFace(button: Instance, id: string, dim: boolean)
	local def = Mods.def(id)
	local stats = Mods.stats(id, "L1")
	local icon = make("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.06),
		Size = UDim2.fromScale(0.34, 0.34),
		BackgroundTransparency = 1,
		Image = if def then def.icon else "",
		ImageTransparency = if dim then 0.5 else 0,
	}, button)
	make("UIAspectRatioConstraint", { AspectRatio = 1 }, icon)
	text(button, if def then def.name else id, {
		Position = UDim2.fromScale(0.06, 0.43),
		Size = UDim2.fromScale(0.88, 0.13),
		TextColor3 = if dim then MUTED else WHITE,
	})
	text(button, if def then string.upper(def.role) else "", {
		Position = UDim2.fromScale(0.06, 0.57),
		Size = UDim2.fromScale(0.88, 0.07),
		FontFace = MEDIUM,
		TextColor3 = if dim then MUTED else ACCENT,
	})
	return stats
end

local function abilityCard(parent: Instance, id: string, index: number): Card
	local button = make("TextButton", {
		Name = id,
		Position = UDim2.fromScale((index - 1) * 0.34, 0),
		Size = UDim2.fromScale(0.32, 1),
		BackgroundColor3 = CARD,
		AutoButtonColor = false,
		Text = "",
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0.04, 0) }, button)
	local stroke = make("UIStroke", {
		Color = ACCENT,
		Thickness = 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Enabled = false,
	}, button)
	local stats = abilityFace(button, id, false)
	local def = Mods.def(id)
	if def then
		keyChip(button, def.slot)
	end
	capText(
		text(button, if stats then stats.note else "", {
			Position = UDim2.fromScale(0.07, 0.66),
			Size = UDim2.fromScale(0.86, 0.28),
			FontFace = MEDIUM,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
		}),
		22
	)
	hookCard(button, function()
		selectedAbility = id
		Net.event("DraftPick"):FireServer("Ability", id)
		refreshSelection()
	end)
	return { button = button, stroke = stroke, id = id, rest = CARD }
end

-- One upgrade card inside a slot's column: the path, the level, what it does.
local function upgradeCard(
	parent: Instance,
	c: MatchState.UpgradeCard,
	row: number,
	rows: number
): Card
	local glitch = string.sub(c.level, 1, 1) == "G"
	local rest = if glitch then GLITCH_CARD else CARD
	local gap = 0.03
	local h = (1 - gap * (rows - 1)) / rows
	local button = make("TextButton", {
		Name = c.key,
		Position = UDim2.fromScale(0, (row - 1) * (h + gap)),
		Size = UDim2.fromScale(1, h),
		BackgroundColor3 = rest,
		AutoButtonColor = false,
		Text = "",
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0.08, 0) }, button)
	if glitch then
		make("UIStroke", {
			Color = GLITCH,
			Thickness = 1.5,
			Transparency = 0.3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, button)
	end
	local stroke = make("UIStroke", {
		Color = if glitch then GLITCH else ACCENT,
		Thickness = 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Enabled = false,
	}, button)
	capText(
		text(
			button,
			(if glitch then "GLITCHED · " else "") .. string.upper(levelLabel(c.id, c.level)),
			{
				Position = UDim2.fromScale(0.05, 0.08),
				Size = UDim2.fromScale(0.9, 0.26),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = if glitch then GLITCH else ACCENT,
			}
		),
		18
	)
	capText(
		text(button, cardNote(c.id, c.level), {
			Position = UDim2.fromScale(0.05, 0.4),
			Size = UDim2.fromScale(0.9, 0.52),
			FontFace = MEDIUM,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
		}),
		17
	)
	hookCard(button, function()
		selectedAbility = c.key
		Net.event("DraftPick"):FireServer("Ability", c.key)
		refreshSelection()
	end, rest)
	return { button = button, stroke = stroke, id = c.key, rest = rest }
end

-- A slot's column once every slot is full: the ability, its level, and the
-- upgrade cards for it (none left: maxed).
local function upgradeColumn(
	parent: Instance,
	slot: number,
	id: string,
	level: string,
	cards: { MatchState.UpgradeCard }
)
	local column = make("Frame", {
		Name = "Slot" .. slot,
		Position = UDim2.fromScale((slot - 1) * 0.34, 0),
		Size = UDim2.fromScale(0.32, 1),
		BackgroundColor3 = CARD_OFF,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0.04, 0) }, column)
	local def = Mods.def(id)
	keyChip(column, slot)
	text(column, if def then def.name else (if id ~= "" then id else "Empty"), {
		Position = UDim2.fromScale(0.24, 0.035),
		Size = UDim2.fromScale(0.72, 0.075),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	text(column, if id ~= "" then levelLabel(id, level) else "", {
		Position = UDim2.fromScale(0.24, 0.11),
		Size = UDim2.fromScale(0.72, 0.045),
		FontFace = MEDIUM,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local holder = make("Frame", {
		Position = UDim2.fromScale(0.04, 0.19),
		Size = UDim2.fromScale(0.92, 0.78),
		BackgroundTransparency = 1,
	}, column)
	if #cards == 0 then
		text(holder, if id ~= "" then "MAXED" else "", {
			Position = UDim2.fromScale(0, 0.4),
			Size = UDim2.fromScale(1, 0.12),
			TextColor3 = MUTED,
		})
		return
	end
	-- Always room for three, so a lone card isn't stretched.
	local rows = math.max(#cards, 3)
	for i, c in cards do
		table.insert(abilityCards, upgradeCard(holder, c, i, rows))
	end
end

local function kitLine(parent: Instance, kit: { string }, levels: { string })
	for slot = 1, ModsConfig.SLOTS do
		local id = kit[slot]
		local def = if id and id ~= "" then Mods.def(id) else nil
		local tile = make("Frame", {
			Position = UDim2.fromScale((slot - 1) * 0.33, 0),
			Size = UDim2.fromScale(0.31, 1),
			BackgroundColor3 = CARD,
		}, parent)
		make("UICorner", { CornerRadius = UDim.new(0.12, 0) }, tile)
		text(tile, KEYS[slot], {
			Position = UDim2.fromScale(0.05, 0.14),
			Size = UDim2.fromScale(0.2, 0.72),
			TextColor3 = ACCENT,
		})
		local level = levels[slot] or ""
		text(
			tile,
			if def then string.format("%s · %s", def.name, levelLabel(def.id, level)) else "Empty",
			{
				Position = UDim2.fromScale(0.28, 0.22),
				Size = UDim2.fromScale(0.68, 0.56),
				FontFace = MEDIUM,
				TextColor3 = if def then WHITE else MUTED,
				TextXAlignment = Enum.TextXAlignment.Left,
			}
		)
	end
end

-- "Dash (Lv 2 · Ghost), Molly (Lv 1)" from "id:level" entries.
local function names(entries: { string }): string
	local out: { string } = {}
	for _, entry in entries do
		local id, level = string.match(entry, "^(%w+):(%w+)$")
		local def = id and Mods.def(id)
		if def and level then
			table.insert(out, string.format("%s (%s)", def.name, levelLabel(def.id, level)))
		else
			table.insert(out, entry)
		end
	end
	return if #out > 0 then table.concat(out, ", ") else "none yet"
end

local function show(o: MatchState.DraftOffer)
	local p = panel
	if not p then
		return
	end
	p:ClearAllChildren()
	make("UICorner", { CornerRadius = UDim.new(0.015, 0) }, p)
	make("UIAspectRatioConstraint", { AspectRatio = 16 / 9 }, p)
	table.clear(gunCards)
	table.clear(abilityCards)
	offer = o
	selectedGun = o.gun
	selectedAbility = nil

	-- Header.
	text(p, string.format("ROUND %d · %s PHASE", o.round, string.upper(o.phase)), {
		Position = UDim2.fromScale(0.02, 0.018),
		Size = UDim2.fromScale(0.4, 0.05),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	clock = text(p, "", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.012),
		Size = UDim2.fromScale(0.12, 0.065),
	})
	text(p, "Enemy abilities: " .. names(o.enemyKit), {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.98, 0.026),
		Size = UDim2.fromScale(0.38, 0.035),
		FontFace = MEDIUM,
		TextColor3 = ModsConfig.COLORS.enemy,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	-- Guns.
	text(p, "CHOOSE YOUR GUN", {
		Position = UDim2.fromScale(0.02, 0.085),
		Size = UDim2.fromScale(0.4, 0.032),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = MUTED,
	})
	local guns = make("Frame", {
		Name = "GunRow",
		Position = UDim2.fromScale(0.02, 0.122),
		Size = UDim2.fromScale(0.96, 0.25),
		BackgroundTransparency = 1,
	}, p)
	for i, id in o.guns do
		table.insert(gunCards, gunCard(guns, id, i, o.phase))
	end

	-- Abilities.
	local upgrades = o.upgrades or {}
	text(
		p,
		if #o.abilities > 0
			then "DRAFT AN ABILITY"
			elseif #upgrades > 0 then "UPGRADE AN ABILITY"
			else "YOUR ABILITIES",
		{
			Position = UDim2.fromScale(0.02, 0.385),
			Size = UDim2.fromScale(0.4, 0.032),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = MUTED,
		}
	)
	local abilities = make("Frame", {
		Name = "AbilityRow",
		Position = UDim2.fromScale(0.02, 0.422),
		Size = UDim2.fromScale(0.96, 0.42),
		BackgroundTransparency = 1,
	}, p)
	if #o.abilities > 0 then
		for i, id in o.abilities do
			table.insert(abilityCards, abilityCard(abilities, id, i))
		end
	else
		for slot = 1, ModsConfig.SLOTS do
			local cards: { MatchState.UpgradeCard } = {}
			for _, c in upgrades do
				if c.slot == slot then
					table.insert(cards, c)
				end
			end
			upgradeColumn(abilities, slot, o.kit[slot] or "", (o.levels or {})[slot] or "", cards)
		end
	end

	-- Your kit, and lock in.
	local kit = make("Frame", {
		Position = UDim2.fromScale(0.02, 0.87),
		Size = UDim2.fromScale(0.56, 0.095),
		BackgroundTransparency = 1,
	}, p)
	kitLine(kit, o.kit, o.levels or {})
	lockHint = text(p, "", {
		Position = UDim2.fromScale(0.6, 0.895),
		Size = UDim2.fromScale(0.15, 0.045),
		FontFace = MEDIUM,
		TextColor3 = MUTED,
	})
	local lock = make("TextButton", {
		Name = "LockIn",
		Position = UDim2.fromScale(0.77, 0.87),
		Size = UDim2.fromScale(0.21, 0.095),
		BackgroundColor3 = CARD,
		AutoButtonColor = false,
		FontFace = BOLD,
		TextScaled = true,
		TextColor3 = MUTED,
		Text = "LOCK IN",
	}, p)
	make("UICorner", { CornerRadius = UDim.new(0.15, 0) }, lock)
	make("UIPadding", {
		PaddingTop = UDim.new(0.2, 0),
		PaddingBottom = UDim.new(0.2, 0),
	}, lock)
	lockButton = lock
	lock.Activated:Connect(function()
		if canLock() then
			Net.event("DraftPick"):FireServer("Lock")
		end
	end)
	refreshSelection()
	setOpen(true)
end

local function build()
	local g = make("ScreenGui", {
		Name = "Draft",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 8,
	}, player:WaitForChild("PlayerGui"))
	local back = make("TextButton", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
	}, g)
	backdrop = back
	panel = make("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.94),
		BackgroundColor3 = BACK,
		BackgroundTransparency = 0.08,
	}, back)
end

-- The screen closes once you've locked in, or when the draft ends.
local function syncVisibility()
	if MatchState.phase() ~= "Draft" or player:GetAttribute("DraftLocked") == true then
		setOpen(false)
	end
end

function DraftController.isOpen(): boolean
	return isOpen
end

function DraftController.start()
	build()
	Net.event("DraftOffer").OnClientEvent:Connect(function(o: MatchState.DraftOffer)
		-- Queued while this client was starting up: that draft is already over.
		if o.endsAt > workspace:GetServerTimeNow() then
			show(o)
		end
	end)
	MatchState.changed("Phase"):Connect(syncVisibility)
	player:GetAttributeChangedSignal("DraftLocked"):Connect(syncVisibility)
	-- Started up mid-draft: ask for the cards.
	if MatchState.phase() == "Draft" then
		Net.event("DraftPick"):FireServer("Sync")
	end
	while true do
		task.wait(TICK)
		if isOpen and clock then
			clock.Text = tostring(math.ceil(MatchState.timeLeft()))
		end
	end
end

return DraftController
