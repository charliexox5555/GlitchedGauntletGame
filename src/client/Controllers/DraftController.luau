--!strict
-- The draft screen (rough, PC first; final design comes later): 3 guns on top, 3
-- abilities below, your kit and LOCK IN at the bottom, like Gauntlet: Glitched
-- (vault/01 Design/Match Flow.md). The server dealt these cards and checks every
-- pick; this only shows them and asks. Layout is Scale inside a 16:9 panel.

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
local BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local MEDIUM = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)

local KEYS = { "Q", "E", "T" }
local TICK = 0.1

type Card = { button: TextButton, stroke: UIStroke, id: string }

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

local function canLock(): boolean
	local o = offer
	if not o then
		return false
	end
	return selectedGun ~= nil and (selectedAbility ~= nil or #o.abilities == 0)
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
		local slot = if o then KEYS[#o.kit + 1] else nil
		lockHint.Text = if ready
			then "Ready"
			elseif not selectedGun then "Choose a gun"
			elseif slot then string.format("Choose an ability for %s", slot)
			else ""
	end
end

local function hookCard(button: TextButton, onPick: () -> ())
	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = CARD_HOVER
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = CARD
	end)
	button.Activated:Connect(onPick)
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
	return { button = button, stroke = stroke, id = id }
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
	text(button, if stats then stats.note else "", {
		Position = UDim2.fromScale(0.07, 0.66),
		Size = UDim2.fromScale(0.86, 0.28),
		FontFace = MEDIUM,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
	})
	hookCard(button, function()
		selectedAbility = id
		Net.event("DraftPick"):FireServer("Ability", id)
		refreshSelection()
	end)
	return { button = button, stroke = stroke, id = id }
end

-- Every slot full: the upgrade cards will live here. Shown, but not pickable yet.
local function upgradePlaceholder(parent: Instance, id: string, index: number)
	local card = make("Frame", {
		Name = id,
		Position = UDim2.fromScale((index - 1) * 0.34, 0),
		Size = UDim2.fromScale(0.32, 1),
		BackgroundColor3 = CARD_OFF,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0.04, 0) }, card)
	abilityFace(card, id, true)
	text(card, "Upgrades coming soon", {
		Position = UDim2.fromScale(0.07, 0.7),
		Size = UDim2.fromScale(0.86, 0.12),
		FontFace = MEDIUM,
		TextColor3 = MUTED,
	})
end

local function kitLine(parent: Instance, kit: { string })
	for slot = 1, ModsConfig.SLOTS do
		local id = kit[slot]
		local def = id and Mods.def(id)
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
		text(tile, if def then def.name else "Empty", {
			Position = UDim2.fromScale(0.28, 0.22),
			Size = UDim2.fromScale(0.68, 0.56),
			FontFace = MEDIUM,
			TextColor3 = if def then WHITE else MUTED,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
end

local function names(ids: { string }): string
	local out: { string } = {}
	for _, id in ids do
		local def = Mods.def(id)
		table.insert(out, if def then def.name else id)
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
	text(p, if #o.abilities > 0 then "DRAFT AN ABILITY" else "YOUR ABILITIES", {
		Position = UDim2.fromScale(0.02, 0.385),
		Size = UDim2.fromScale(0.4, 0.032),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = MUTED,
	})
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
		for i, id in o.kit do
			upgradePlaceholder(abilities, id, i)
		end
	end

	-- Your kit, and lock in.
	local kit = make("Frame", {
		Position = UDim2.fromScale(0.02, 0.87),
		Size = UDim2.fromScale(0.56, 0.095),
		BackgroundTransparency = 1,
	}, p)
	kitLine(kit, o.kit)
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
