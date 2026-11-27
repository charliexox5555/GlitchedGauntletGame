--!strict
-- The range's LOADOUT menu (vault/01 Design/Range v5.md §4). Owner, 2026-11-25: "lets create a working load out
-- selector ... In that menu you can also access your locker". Opened at a range terminal (tag `RangeLoadout`):
-- walk up to one and G / D-pad right / the phone's CHOOSE GUNS button opens it (the openers are drawn here because
-- ProximityPrompts never show inside the armed range, measured 2026-11-25). The screen is Studio-built (UI.Lobby.Loadout, backup tools/studio/BuildLoadoutMenu.luau); the gun
-- cards are the Locker's own templates (UI.Templates.Lobby.GunGroup / GunCard).
--
--   * PRIMARY / SECONDARY / MELEE tabs (or 1 / 2 / 3, LB / RB on a controller, or a slot card on the left) pick
--     the slot; a controller gets its button hints along the foot, a phone a compact layout (Phone* attributes on
--     the screen) and no touch controls behind the menu (TouchController hides them while GameSettingsOpen);
--   * the right side lists every installed gun for that slot, grouped by class, in your equipped skin;
--   * clicking one asks the server for it (the existing PickWeapon remote: WeaponService checks the id, the
--     installed model, a live character and that you're in the range) and equips it; what you hold comes back in
--     WeaponState, which this menu mirrors (nothing is decided here);
--   * LOCKER opens the Locker; closing the Locker brings you back here.
-- While any lobby menu is open in the range, the mouse is freed and the match input paused (the match client's
-- `GameSettingsOpen` switch, the same one the Settings menu uses).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GunLoadout = require(ReplicatedStorage.Shared.GunLoadout)
local InputGlyphs = require(ReplicatedStorage.Shared.InputGlyphs)
local InputMode = require(ReplicatedStorage.Shared.InputMode)
local Locker = require(ReplicatedStorage.Shared.Locker)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local SkinArt = require(ReplicatedStorage.Shared.SkinArt)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Types = require(ReplicatedStorage.Shared.Types)
local UiMotion = require(ReplicatedStorage.Shared.UiMotion)
local UiRoot = require(ReplicatedStorage.Shared.UiRoot)
local UiSfx = require(ReplicatedStorage.Shared.UiSfx)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local LobbyKit = require(script.Parent.Parent.Util.LobbyKit)
local Router = require(script.Parent.Parent.Util.Router)

local LoadoutController = {}

local player = Players.LocalPlayer
local C = LobbyKit.C
local ALLY = Color3.fromHex("3FE0F2") -- the picked card, like the Locker's list
local TEAL = Color3.fromHex("2BD9A8") -- the range's accent
local MENU = "Loadout"
local SETTINGS_SWITCH = "GameSettingsOpen" -- frees the mouse, pauses match input (CameraController, InputController)
local GROUP_WIDTH = 1070 -- the gun list's width inside the scroll (4 cards a row)
local TERMINAL_TAG = "RangeLoadout"
local REACH = 9 -- studs from a terminal's body to show its hint and take the key
local HINT_CHECK = 0.1 -- seconds between reach checks
local PAD_OPEN = Enum.KeyCode.DPadRight -- free in the range (Config/Input)
local OPEN_KEYS: { [Enum.KeyCode]: boolean } = { [Enum.KeyCode.G] = true, [PAD_OPEN] = true }
local RUBIK_H = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy) -- Rubik (Config/Theme)

local SLOTS: { Types.Slot } = { "Primary", "Secondary", "Melee" }
local CLASSES = {
	{ "Sidearm", "SIDEARMS" },
	{ "SMG", "SMGS" },
	{ "Shotgun", "SHOTGUNS" },
	{ "Rifle", "RIFLES" },
	{ "Sniper", "SNIPERS" },
	{ "MachineGun", "HEAVY" },
	{ "Melee", "MELEE" },
}
local KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
}

local canvas: Frame? = nil
local gunsList: ScrollingFrame? = nil
local templates: Folder? = nil
local pickTab: ((number) -> ())? = nil
local isOpen = false
local slotIndex = 1
local held: { [Types.Slot]: string } = {} -- the server's last word on each slot
local cards: { [string]: GuiButton } = {}
local returnFromLocker = false
local hint: BillboardGui? = nil
local nearTerminal: BasePart? = nil
local freedMouse = false

local function child(parent: Instance, name: string): Instance
	return parent:WaitForChild(name, 5) or error(`[Loadout] missing {parent:GetFullName()}.{name}`)
end

local function installed(id: string): boolean
	local folder = ReplicatedStorage:FindFirstChild("Weapons")
	return folder ~= nil and folder:FindFirstChild(id) ~= nil
end

local function lineOf(id: string): string
	return Locker.equipped(player)[id] or "Stock"
end

local function picture(id: string): string
	return SkinArt.side(id, lineOf(id)) or Theme.GUN[id] or ""
end

local function title(id: string): string
	local cfg = Weapons.get(id)
	return string.upper(if cfg then cfg.displayName else id)
end

local function skinTitle(id: string): string
	local line = lineOf(id)
	return if line == "Stock" then "DEFAULT SKIN" else string.upper(line) .. " SKIN"
end

-- A slot's card: LobbyKit.button wraps a layout item in a holder of the same name (so it pops from its centre),
-- so look for the button itself.
local function slotCard(column: Instance, slot: string): GuiButton?
	for _, d in column:GetDescendants() do
		if d.Name == slot and d:IsA("GuiButton") then
			return d
		end
	end
	return nil
end

-- The left column: what each slot holds now; the picked slot is lit.
local function renderSlots()
	local c = canvas
	if not c then
		return
	end
	local column = c:FindFirstChild("Slots")
	if not column then
		return
	end
	for i, slot in SLOTS do
		local card = slotCard(column, slot)
		if not card then
			continue
		end
		local id = held[slot]
		local on = i == slotIndex
		UiMotion.tween(card, 0.16, {
			BackgroundColor3 = if on then C.navyHi else C.navy,
			BackgroundTransparency = if on then 0 else 0.2,
		})
		local icon = card:FindFirstChild("Icon")
		if icon and icon:IsA("ImageLabel") then
			icon.Image = if id then picture(id) else ""
		end
		local name = card:FindFirstChild("Name")
		if name and name:IsA("TextLabel") then
			name.Text = if id then title(id) else "EMPTY"
		end
		local skin = card:FindFirstChild("Skin")
		if skin and skin:IsA("TextLabel") then
			skin.Text = if id then skinTitle(id) else ""
		end
		local kicker = card:FindFirstChild("Kicker")
		if kicker and kicker:IsA("TextLabel") then
			kicker.TextColor3 = if on then TEAL else C.muted
		end
	end
end

local function styleCard(card: GuiButton, on: boolean)
	UiMotion.tween(card, 0.14, {
		BackgroundColor3 = if on then ALLY else C.navy,
		BackgroundTransparency = if on then 0 else 0.25,
	})
	local name = card:FindFirstChild("Name")
	if name and name:IsA("TextLabel") then
		name.TextColor3 = if on then C.ink else C.white
	end
	local row = card:FindFirstChild("Skin")
	local label = row and row:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.TextColor3 = if on then C.ink else C.muted
	end
end

local function refreshCards()
	local slot = SLOTS[slotIndex]
	for id, card in cards do
		styleCard(card, held[slot] == id)
		local icon = card:FindFirstChild("Icon")
		if icon and icon:IsA("ImageLabel") then
			icon.Image = picture(id)
		end
	end
end

local function choose(id: string)
	local cfg = Weapons.get(id)
	if not cfg or not installed(id) then
		return
	end
	if held[cfg.slot] == id then
		UiSfx.cue("Back")
		return
	end
	UiSfx.cue("Confirm")
	-- Shown at once; the server's WeaponState confirms it (or puts back what you really hold).
	held[cfg.slot] = id
	Net.event("PickWeapon"):FireServer(id)
	refreshCards()
	renderSlots()
end

-- The gun list's inner width in design px (a phone's list is narrower: UI.Lobby.Loadout Phone* attributes).
local function groupWidth(): number
	local list, c = gunsList, canvas
	if not list or not c then
		return GROUP_WIDTH
	end
	local fit = c:FindFirstChild("Fit")
	local k = if fit and fit:IsA("UIScale") and fit.Scale > 0 then fit.Scale else 1
	local w = math.floor(list.AbsoluteSize.X / k) - 24
	return if w > 260 then w else GROUP_WIDTH
end

-- The guns for the picked slot, grouped by class, the Locker's cards.
local function buildGuns()
	local list, tpl = gunsList, templates
	if not list or not tpl then
		return
	end
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	table.clear(cards)
	local slot = SLOTS[slotIndex]
	local order = 0
	local width = groupWidth()
	for _, class in CLASSES do
		local ids: { string } = {}
		for _, cfg in Weapons.list do
			-- the active set only (Config/Loadout; parked guns stay out); the knife has no loadout slot
			local active = cfg.slot == "Melee" or GunLoadout.slotOf(cfg.id) ~= nil
			if cfg.slot == slot and cfg.class == class[1] and active and installed(cfg.id) then
				table.insert(ids, cfg.id)
			end
		end
		if #ids == 0 then
			continue
		end
		table.sort(ids, function(a: string, b: string): boolean
			local ca, cb = Weapons.get(a), Weapons.get(b)
			local ta, tb = if ca then ca.tier else 0, if cb then cb.tier else 0
			if ta ~= tb then
				return ta < tb
			end
			return title(a) < title(b)
		end)
		order += 1
		local group = (tpl:WaitForChild("GunGroup") :: Frame):Clone()
		group.Name = class[2]
		group.LayoutOrder = order
		local headRow = group:FindFirstChild("HeadRow")
		if headRow and headRow:IsA("GuiObject") then
			headRow.Size = UDim2.fromOffset(width, headRow.Size.Y.Offset)
			local head = headRow:FindFirstChild("Head")
			if head and head:IsA("TextLabel") then
				head.Text = class[2]
			end
			local count = headRow:FindFirstChild("Count")
			if count and count:IsA("TextLabel") then
				count.Text = tostring(#ids)
			end
		end
		local grid = group:FindFirstChild("Grid")
		if not (grid and grid:IsA("GuiObject")) then
			continue
		end
		grid.Size = UDim2.new(0, width, grid.Size.Y.Scale, grid.Size.Y.Offset)
		for i, id in ids do
			local card = (tpl:WaitForChild("GunCard") :: GuiButton):Clone()
			card.Name = id
			card.LayoutOrder = i
			local name = card:FindFirstChild("Name")
			if name and name:IsA("TextLabel") then
				name.Text = title(id)
			end
			local row = card:FindFirstChild("Skin")
			local label = row and row:FindFirstChild("Label")
			if label and label:IsA("TextLabel") then
				label.Text = skinTitle(id)
			end
			card.Parent = grid
			LobbyKit.button(card, function()
				choose(id)
			end, { card = true })
			cards[id] = card
		end
		group.Parent = list
	end
	list.CanvasPosition = Vector2.zero
	refreshCards()
end

local function selectSlot(i: number)
	slotIndex = math.clamp(i, 1, #SLOTS)
	buildGuns()
	renderSlots()
end

-- What the server says each slot holds (sent to this player only; checked here before use).
local function onWeaponState(state: unknown)
	if typeof(state) ~= "table" then
		return
	end
	local slots = (state :: any).slots
	if typeof(slots) ~= "table" then
		return
	end
	for _, slot in SLOTS do
		local s = slots[slot]
		local id = if typeof(s) == "table" then s.id else nil
		held[slot] = if typeof(id) == "string" then id else nil
	end
	if isOpen then
		refreshCards()
		renderSlots()
	end
end

-- Any lobby menu open in the range frees the mouse (first person locks it) and pauses the match input.
local function onMenuChanged(name: string?)
	local inRange = PlayZone.get(player) == "Range"
	local want = inRange and name ~= nil
	if want ~= freedMouse then
		freedMouse = want
		player:SetAttribute(SETTINGS_SWITCH, want)
	end
	-- LOCKER from here: closing the Locker comes back to the loadout.
	if name == "Locker" then
		return
	end
	if name == nil and returnFromLocker and inRange then
		returnFromLocker = false
		task.defer(Router.open, MENU)
		return
	end
	returnFromLocker = false
end

-- The controller's hints along the foot (LB / RB slot, A equip, B back), only with a gamepad.
local PAD_GLYPHS: { [string]: Enum.KeyCode } = {
	GlyphL = Enum.KeyCode.ButtonL1,
	GlyphR = Enum.KeyCode.ButtonR1,
	GlyphA = Enum.KeyCode.ButtonA,
	GlyphB = Enum.KeyCode.ButtonB,
}

local function refreshPadHints()
	local c = canvas
	local hints = c and c:FindFirstChild("PadHints")
	if not (hints and hints:IsA("GuiObject")) then
		return
	end
	local pad = InputGlyphs.mode() == "Gamepad"
	hints.Visible = pad
	if not pad then
		return
	end
	for _, d in hints:GetDescendants() do
		local code = PAD_GLYPHS[d.Name]
		if code and d:IsA("ImageLabel") then
			d.Image = UserInputService:GetImageForKeyCode(code)
		end
	end
end

local function entrance()
	local c = canvas
	if not c or UiMotion.reduced() then
		return
	end
	local column = c:FindFirstChild("Slots")
	if column and column:IsA("GuiObject") then
		UiMotion.slideIn(column, -24, 0, 0)
	end
	if gunsList then
		UiMotion.slideIn(gunsList, 24, 0, 0.04)
	end
end

-- Opening from a terminal (owner 2026-11-26: the hint sat too high; on a phone "a click to choose guns"; on a
-- console "a different button ... on the screen"):
--   * keyboard: a plate just above the terminal with the G key chip;
--   * gamepad: the same plate with the controller's own D-pad-right glyph;
--   * touch: no world plate (taps on it fight the touch controls); a CHOOSE GUNS button on the screen, centred
--     under the crosshair, clear of the stick and the action buttons.
-- Sizes follow the screen height (designed at 1080).
local HINT_LIFT = 3.1 -- studs above the terminal body's centre: just over its top (5.4 tall, body centre ~2.9)
local hintKey: TextLabel? = nil
local hintGlyph: ImageLabel? = nil
local touchButton: GuiButton? = nil

local function screenScale(): number
	local camera = workspace.CurrentCamera
	local h = if camera then camera.ViewportSize.Y else 1080
	return math.clamp(h / 1080, 0.6, 1.5)
end

local function plateLook(plate: GuiObject)
	plate.BackgroundColor3 = C.navy
	plate.BackgroundTransparency = 0.08
	plate.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = plate
	local bar = Instance.new("Frame")
	bar.Name = "Accent"
	bar.BackgroundColor3 = TEAL
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, 10, 1, 0)
	bar.Size = UDim2.new(1, -20, 0, 3)
	bar.Parent = plate
end

-- The plate's words, from `x` (a share of its width) to its right edge, as tall as the plate allows.
local function words(parent: Instance, text: string, x: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(x, 0)
	label.Size = UDim2.fromScale(0.97 - x, 1)
	label.FontFace = RUBIK_H
	label.TextScaled = true
	label.TextColor3 = C.white
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.26, 0)
	pad.PaddingBottom = UDim.new(0.26, 0)
	pad.Parent = label
	label.Parent = parent
	return label
end

local function buildHint(parent: Instance): BillboardGui
	local g = Instance.new("BillboardGui")
	g.Name = "LoadoutHint"
	g.ResetOnSpawn = false
	g.AlwaysOnTop = true
	g.LightInfluence = 0
	g.StudsOffsetWorldSpace = Vector3.new(0, HINT_LIFT, 0)
	g.Enabled = false
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.Size = UDim2.fromScale(1, 1)
	plateLook(plate)
	plate.Parent = g
	-- the key: a white chip with the letter (keyboard), or the controller's glyph (gamepad)
	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.BackgroundColor3 = C.white
	key.BorderSizePixel = 0
	key.AnchorPoint = Vector2.new(0, 0.5)
	key.Position = UDim2.new(0.045, 0, 0.47, 0)
	key.Size = UDim2.fromScale(0.62, 0.62)
	key.SizeConstraint = Enum.SizeConstraint.RelativeYY
	key.FontFace = RUBIK_H
	key.TextScaled = true
	key.TextColor3 = C.ink
	key.Text = "G"
	key.Parent = plate
	local keyCorner = Instance.new("UICorner")
	keyCorner.CornerRadius = UDim.new(0.15, 0)
	keyCorner.Parent = key
	local glyph = Instance.new("ImageLabel")
	glyph.Name = "Glyph"
	glyph.BackgroundTransparency = 1
	glyph.AnchorPoint = key.AnchorPoint
	glyph.Position = key.Position
	glyph.Size = UDim2.fromScale(0.7, 0.7)
	glyph.SizeConstraint = Enum.SizeConstraint.RelativeYY
	glyph.ScaleType = Enum.ScaleType.Fit
	glyph.Visible = false
	glyph.Parent = plate
	words(plate, "CHOOSE GUNS", 0.23)
	hintKey, hintGlyph = key, glyph
	g.Parent = parent
	return g
end

-- The phone's button: a screen plate (its own ScreenGui, above the touch controls).
local function buildTouchButton(parent: Instance): GuiButton
	local g = Instance.new("ScreenGui")
	g.Name = "LoadoutTouch"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 16
	-- KeepGui: the match client's cleanup (client/init) leaves it. Not LobbyGui: ArmedHideController would hide it in the range
	g:SetAttribute("KeepGui", true)
	g.Parent = parent
	local b = Instance.new("TextButton")
	b.Name = "ChooseGuns"
	b.Text = ""
	b.AutoButtonColor = false
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.fromScale(0.5, 0.7)
	b.Visible = false
	plateLook(b)
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0.04, 0, 0.47, 0)
	icon.Size = UDim2.fromScale(0.3, 0.62)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Image = Theme.GUN.Vandal or ""
	icon.Parent = b
	words(b, "CHOOSE GUNS", 0.38)
	b.Parent = g
	LobbyKit.button(b, function()
		if nearTerminal and Router.current() == nil then
			Router.open(MENU)
		end
	end)
	return b
end

-- The terminal body within reach (nil when none, or when not in the range / a menu is open).
local function terminalInReach(): BasePart?
	if PlayZone.get(player) ~= "Range" or Router.current() ~= nil then
		return nil
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	local best: BasePart? = nil
	local bestDistance = REACH
	for _, inst in CollectionService:GetTagged(TERMINAL_TAG) do
		if inst:IsA("BasePart") and inst:IsDescendantOf(workspace) then
			local d = (inst.Position - root.Position).Magnitude
			if d < bestDistance then
				best, bestDistance = inst, d
			end
		end
	end
	return best
end

local function inputMode(): string
	return InputGlyphs.mode()
end

-- Shows the right opener for the device, at the screen's scale.
local function refreshOpener()
	local mode = inputMode()
	local k = screenScale()
	local h = hint
	if h then
		h.Size = UDim2.fromOffset(math.round(236 * k), math.round(52 * k))
		h.Enabled = nearTerminal ~= nil and mode ~= "Touch"
		h.Adornee = nearTerminal
	end
	local key, glyph = hintKey, hintGlyph
	if key and glyph then
		local image = if mode == "Gamepad"
			then UserInputService:GetImageForKeyCode(PAD_OPEN)
			else ""
		glyph.Image = image
		glyph.Visible = image ~= ""
		key.Visible = image == ""
	end
	local b = touchButton
	if b then
		b.Size = UDim2.fromOffset(math.round(300 * k), math.round(76 * k))
		b.Visible = nearTerminal ~= nil and mode == "Touch"
	end
end

local function watchTerminals()
	local lastMode = inputMode()
	while true do
		local found = terminalInReach()
		-- the device can change without InputMode.changed (Studio's ForceInput switch): check it here too
		local mode = inputMode()
		if found ~= nearTerminal or mode ~= lastMode then
			nearTerminal = found
			lastMode = mode
			refreshOpener()
			refreshPadHints()
		end
		task.wait(HINT_CHECK)
	end
end

function LoadoutController.start()
	local pg = player:WaitForChild("PlayerGui")
	local screen = pg:WaitForChild(MENU, 30)
	if not (screen and screen:IsA("ScreenGui")) then
		warn("[Loadout] no UI.Lobby.Loadout screen (run tools/studio/BuildLoadoutMenu.luau)")
		return
	end
	local c = child(screen, "Canvas") :: Frame
	canvas = c
	gunsList = child(c, "Guns") :: ScrollingFrame
	templates = UiRoot.templates():WaitForChild("Lobby") :: Folder
	LobbyKit.deepen(screen)

	local tabs: { GuiButton } = {}
	for _, name in { "PRIMARY", "SECONDARY", "MELEE" } do
		table.insert(tabs, child(child(c, "Tabs"), name) :: GuiButton)
	end
	pickTab = LobbyKit.tabs(tabs, selectSlot)
	local column = child(c, "Slots")
	for i, slot in SLOTS do
		local card = slotCard(column, slot)
		if card then
			LobbyKit.button(card, function()
				if pickTab then
					pickTab(i)
				end
			end, { card = true })
		end
	end
	LobbyKit.button(child(c, "Locker") :: GuiButton, function()
		returnFromLocker = true
		Router.open("Locker")
	end)

	LobbyKit.page({
		name = MENU,
		gui = screen,
		-- lihfolk-ignore: findfirstchild-chain (a cast to an optional, never indexed; page() handles nil)
		wash = screen:FindFirstChild("Wash") :: GuiObject?,
		close = child(c, "Close") :: GuiButton,
		focus = function(): GuiObject?
			local list = gunsList
			return if list then list:FindFirstChildWhichIsA("GuiButton", true) else nil
		end,
		onOpen = function()
			isOpen = true
			refreshPadHints()
			-- Ask for a fresh snapshot of what's in hand (the server answers with WeaponState).
			Net.event("WeaponState"):FireServer()
			if pickTab then
				pickTab(slotIndex)
			end
			buildGuns()
			renderSlots()
			entrance()
		end,
		onClose = function()
			isOpen = false
		end,
	})

	Net.event("WeaponState").OnClientEvent:Connect(onWeaponState)
	Locker.observe(player, function()
		if isOpen then
			refreshCards()
			renderSlots()
		end
	end)
	Router.onChanged(onMenuChanged)
	-- Leaving the range with a menu open: give the mouse back to the lobby.
	PlayZone.onLocalChanged(function()
		if PlayZone.get(player) ~= "Range" then
			if Router.current() == MENU then
				Router.close()
			end
			if freedMouse then
				freedMouse = false
				player:SetAttribute(SETTINGS_SWITCH, false)
			end
		end
	end)
	hint = buildHint(pg)
	touchButton = buildTouchButton(pg)
	InputMode.changed:Connect(function()
		refreshOpener()
		refreshPadHints()
	end)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshOpener)
	end
	task.spawn(watchTerminals)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if not isOpen then
			if OPEN_KEYS[input.KeyCode] and nearTerminal and Router.current() == nil then
				Router.open(MENU)
			end
			return
		end
		local i = KEYS[input.KeyCode]
		if
			not i
			and (input.KeyCode == Enum.KeyCode.ButtonL1 or input.KeyCode == Enum.KeyCode.ButtonR1)
		then
			-- the bumpers step through the slots, wrapping round
			local step = if input.KeyCode == Enum.KeyCode.ButtonR1 then 1 else -1
			i = (slotIndex - 1 + step) % #SLOTS + 1
		end
		if i and pickTab then
			pickTab(i)
		end
	end)
end

return LoadoutController
