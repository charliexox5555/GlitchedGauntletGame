--!strict
-- Mod dev test panel (F8, gamepad View/Select, touch TEST button: the
-- DevPanel input action). Opens only when the server marked us allowed
-- (player attribute "DevMods", DevModService: Studio, everyone in a test-mode
-- server, or the game's owner); every action is a DevMod request the server
-- checks again. Pick a slot, then a Mod and a level; refill charges, toggle
-- unlimited charges and quick-cast, spawn or clear your dummies. On small
-- screens the panel shrinks to fit. Dev dummies get a per-viewer outline (cyan ally,
-- orange-red enemy) so teams read at a glance.

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Mods)
local Mods = require(Shared.Mods)
local Net = require(Shared.Net)
local Teams = require(Shared.Mods.Teams)

local TeamColor = require(script.Parent.Parent.Util.TeamColor)
local CameraController = require(script.Parent.CameraController)
local InputController = require(script.Parent.InputController)
local ModController = require(script.Parent.ModController)
local WeaponController = require(script.Parent.WeaponController)

local DevModController = {}

local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromHex("A9ADB4")
local BACK = Color3.fromHex("16181B")
local CARD = Color3.fromHex("23262B")
local CARD_ON = Color3.fromHex("1F3A40")
local CYAN = Config.COLORS.ally
local BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local MEDIUM = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)

local DUMMY_TAG = "RangeDummy"
local SCREEN_MARGIN = 24 -- px kept clear around the panel when it's scaled to fit

type Button = { button: TextButton, stroke: UIStroke }

local root: TextButton? = nil
local panelFrame: Frame? = nil
local panelScale: UIScale? = nil
local open = false
local selectedSlot = 1
local selectedLevel = "L1"
local slotButtons: { Button } = {}
local modButtons: { [string]: Button } = {}
local levelButtons: { [string]: Button } = {}
local unlimitedButton: TextButton? = nil
local quickCastButton: TextButton? = nil
local noteLabel: TextLabel? = nil
local outlines: { [Instance]: Highlight } = {}
local nextOrder = 0 -- list layouts show things in the order they were made

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if inst:IsA("GuiObject") then
		nextOrder += 1
		inst.LayoutOrder = nextOrder
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function send(action: string, a: any?, b: any?, c: any?)
	Net.event("DevMod"):FireServer(action, a, b, c)
end

local function label(textValue: string, size: number, parent: Instance, color: Color3?): TextLabel
	return make("TextLabel", {
		Size = UDim2.new(1, 0, 0, size + 6),
		BackgroundTransparency = 1,
		FontFace = BOLD,
		TextSize = size,
		TextColor3 = color or WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = textValue,
	}, parent)
end

local function button(textValue: string, width: number, parent: Instance, onClick: () -> ()): Button
	local b = make("TextButton", {
		Size = UDim2.fromOffset(width, 30),
		BackgroundColor3 = CARD,
		BorderSizePixel = 0,
		FontFace = MEDIUM,
		TextSize = 15,
		TextColor3 = WHITE,
		Text = textValue,
		AutoButtonColor = true,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	local stroke = make("UIStroke", {
		Color = CYAN,
		Thickness = 1.5,
		Enabled = false,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, b)
	b.Activated:Connect(onClick)
	return { button = b, stroke = stroke }
end

local function row(parent: Instance, height: number): Frame
	local f = make("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
	}, parent)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		Wraps = true,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, f)
	return f
end

local function setToggle(b: TextButton?, name: string, on: boolean)
	if b then
		b.Text = name .. (if on then ": ON" else ": OFF")
		b.BackgroundColor3 = if on then CARD_ON else CARD
	end
end

-- Highlights what's selected and what each slot holds.
local function refresh()
	local slotId = player:GetAttribute("Mod" .. selectedSlot .. "Id")
	local slotLevel = player:GetAttribute("Mod" .. selectedSlot .. "Level")
	for i, b in slotButtons do
		b.stroke.Enabled = i == selectedSlot
		local id = player:GetAttribute("Mod" .. i .. "Id")
		local level = player:GetAttribute("Mod" .. i .. "Level")
		b.button.Text = string.format(
			"%s  %s",
			ModController.keyLabel(i),
			if typeof(id) == "string" then id .. " " .. tostring(level) else "empty"
		)
	end
	for id, b in modButtons do
		b.stroke.Enabled = id == slotId
	end
	for level, b in levelButtons do
		b.stroke.Enabled = level == selectedLevel
	end
	setToggle(
		unlimitedButton,
		"Test mode: unlimited charges",
		player:GetAttribute("ModUnlimitedCharges") == true
	)
	setToggle(quickCastButton, "Quick-cast", ModController.isQuickCast())
	local note = noteLabel
	if note then
		local stats = if typeof(slotId) == "string" and typeof(slotLevel) == "string"
			then Mods.stats(slotId, slotLevel)
			else nil
		local built = typeof(slotLevel) == "string" and Config.BUILT[slotLevel] == true
		note.Text = if stats
			then string.format(
				"%s %s: %s%s",
				tostring(slotId),
				tostring(slotLevel),
				tostring(stats.note),
				if built then "" else "  (numbers only: behaviour not built yet)"
			)
			else "Pick a Mod for this slot."
	end
end

-- Shrinks the panel to fit small screens (phones), never grows it.
local function fit()
	local panel, scale, camera = panelFrame, panelScale, workspace.CurrentCamera
	if not panel or not scale or not camera or scale.Scale <= 0 then
		return
	end
	local natural = panel.AbsoluteSize / scale.Scale
	if natural.X <= 0 or natural.Y <= 0 then
		return
	end
	local view = camera.ViewportSize
	scale.Scale = math.clamp(
		math.min((view.X - SCREEN_MARGIN * 2) / natural.X, (view.Y - SCREEN_MARGIN * 2) / natural.Y),
		0.4,
		1
	)
end

local function setOpen(value: boolean)
	local r = root
	if not r or open == value then
		return
	end
	open = value
	r.Visible = value
	CameraController.setCursorVisible(value)
	-- The gun stays down while clicking around the panel.
	WeaponController.setHolstered("DevPanel", value)
	if value then
		ModController.cancel()
		refresh()
		task.defer(fit) -- after the layout sizes the panel
		local first = slotButtons[1]
		if first and UserInputService.GamepadEnabled then
			GuiService.SelectedObject = first.button
		end
	else
		local selected = GuiService.SelectedObject
		if selected and selected:IsDescendantOf(r) then
			GuiService.SelectedObject = nil
		end
	end
end

local function build(): TextButton
	local screen = make("ScreenGui", {
		Name = "ModDevPanel",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 20,
	}, player:WaitForChild("PlayerGui"))
	-- Modal so the mouse is free in first person.
	local r = make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Modal = true,
		Visible = false,
		AutoButtonColor = false,
		Selectable = false,
	}, screen)
	local panel = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 30, 0.5, 0),
		Size = UDim2.fromOffset(470, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = BACK,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
	}, r)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, panel)
	make("UIStroke", { Color = WHITE, Transparency = 0.85, Thickness = 1 }, panel)
	panelFrame = panel
	panelScale = make("UIScale", { Scale = 1 }, panel)
	-- The layout settles after opening (AutomaticSize, the note's text):
	-- fit again. Stable: fit() divides out the scale it set.
	panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if open then
			fit()
		end
	end)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 14),
		PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
	}, panel)
	make(
		"UIListLayout",
		{ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder },
		panel
	)

	label("MOD TEST PANEL  ·  F8 / View", 18, panel)

	label("Slot", 13, panel, MUTED)
	local slotRow = row(panel, 30)
	for i = 1, Config.SLOTS do
		slotButtons[i] = button("", 140, slotRow, function()
			selectedSlot = i
			local level = player:GetAttribute("Mod" .. i .. "Level")
			if typeof(level) == "string" then
				selectedLevel = level
			end
			refresh()
		end)
	end

	label("Mod (greyed: not built yet)", 13, panel, MUTED)
	local modRow = row(panel, 102)
	for _, id in Config.ORDER do
		local def = Mods.def(id)
		local built = Mods.isBuilt(id)
		local b = button(if def then def.name else id, 140, modRow, function()
			if built then
				send("SetSlot", selectedSlot, id, selectedLevel)
			end
		end)
		if not built then
			b.button.TextColor3 = MUTED
			b.button.BackgroundTransparency = 0.5
			b.button.AutoButtonColor = false
		end
		modButtons[id] = b
	end
	button("Clear slot", 140, panel, function()
		send("ClearSlot", selectedSlot)
	end)

	label("Level (A/B/G: numbers only until Phase 2)", 13, panel, MUTED)
	local levelRow = row(panel, 30)
	for _, level in Config.LEVELS do
		levelButtons[level] = button(level, 56, levelRow, function()
			selectedLevel = level
			local id = player:GetAttribute("Mod" .. selectedSlot .. "Id")
			if typeof(id) == "string" then
				send("SetSlot", selectedSlot, id, level)
			end
			refresh()
		end)
	end

	label("Charges (refill = what a new round does)", 13, panel, MUTED)
	local cdRow = row(panel, 66)
	unlimitedButton = button("Test mode: unlimited charges", 286, cdRow, function()
		send("UnlimitedCharges", player:GetAttribute("ModUnlimitedCharges") ~= true)
	end).button
	button("Refill charges", 140, cdRow, function()
		send("RefillCharges")
	end)
	quickCastButton = button("Quick-cast", 140, cdRow, function()
		ModController.setQuickCast(not ModController.isQuickCast())
		refresh()
	end).button

	label("Dummies (prepared like players)", 13, panel, MUTED)
	local dummyRow = row(panel, 30)
	button("Spawn enemy", 140, dummyRow, function()
		send("SpawnDummy", "Enemy")
	end)
	button("Spawn teammate", 140, dummyRow, function()
		send("SpawnDummy", "Ally")
	end)
	button("Clear dummies", 140, dummyRow, function()
		send("ClearDummies")
	end)
	button("Hurt me (-50)", 140, panel, function()
		send("HurtSelf")
	end)

	noteLabel = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		FontFace = MEDIUM,
		TextSize = 14,
		TextColor3 = MUTED,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}, panel)

	-- Touch: a small TEST button under the GUNS button (above the panel's
	-- backdrop, so it closes the panel too), linked to the DevPanel action.
	if UserInputService.TouchEnabled then
		local b = make("TextButton", {
			Name = "DevPanelButton",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0, 96),
			Size = UDim2.fromOffset(64, 32),
			BackgroundColor3 = BACK,
			BackgroundTransparency = 0.4,
			FontFace = BOLD,
			TextSize = 14,
			TextColor3 = WHITE,
			Text = "TEST",
			ZIndex = 2,
		}, screen)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
		InputController.bindTouchButtons(screen)
	end
	return r
end

-- Per-viewer outline on dev dummies (they carry a DevDummy attribute).
local function outline(model: Instance)
	if outlines[model] or not model:IsA("Model") or model:GetAttribute("DevDummy") == nil then
		return
	end
	local existing = model:FindFirstChild("DevOutline")
	if existing and existing:IsA("Highlight") then
		outlines[model] = existing -- streamed back in with it
		return
	end
	local h = Instance.new("Highlight")
	h.Name = "DevOutline"
	h.FillTransparency = 1
	h.OutlineTransparency = 0.1
	h.OutlineColor = TeamColor.forTeam(Teams.of(model))
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = model
	h.Parent = model
	outlines[model] = h
end

function DevModController.start()
	CollectionService:GetInstanceAddedSignal(DUMMY_TAG):Connect(function(model)
		task.defer(outline, model)
	end)
	CollectionService:GetInstanceRemovedSignal(DUMMY_TAG):Connect(function(model)
		outlines[model] = nil
	end)
	for _, model in CollectionService:GetTagged(DUMMY_TAG) do
		outline(model)
	end

	local function ready()
		if player:GetAttribute("DevMods") == true and not root then
			root = build()
		end
	end
	player:GetAttributeChangedSignal("DevMods"):Connect(ready)
	ready()
	InputController.onPressed("DevPanel", function()
		if root then
			setOpen(not open)
		end
	end)
	-- Gamepad B (back) closes it too.
	UserInputService.InputBegan:Connect(function(input)
		if open and input.KeyCode == Enum.KeyCode.ButtonB then
			setOpen(false)
		end
	end)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if open then
				fit()
			end
		end)
	end
	-- Reflect server changes (slot set, unlimited charges) while open.
	for _, name in
		{
			"Mod1Id",
			"Mod2Id",
			"Mod3Id",
			"Mod1Level",
			"Mod2Level",
			"Mod3Level",
			"ModUnlimitedCharges",
		}
	do
		player:GetAttributeChangedSignal(name):Connect(function()
			if open then
				refresh()
			end
		end)
	end
	player.CharacterRemoving:Connect(function()
		setOpen(false)
	end)
end

return DevModController
