--!strict
-- Gun review mode (Studio and test-mode servers only): F6 opens a small
-- panel for signing off each gun's first-person look, one gun at a time.
-- [ / ] switch gun (the PickWeapon remote, checked on the server, like the P
-- picker), N replays the draw, G the reload and B the empty reload (viewmodel only, no
-- server state), Z cycles slow motion and X freezes (Workspace VfxTimeScale,
-- read by ViewmodelController and EffectsController), K / J mark the gun
-- "looks good" / "needs work". Verdicts print to Output as [GunReview] lines
-- so a later Claude session can read them. Nothing here decides gameplay.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local TestMode = require(ReplicatedStorage.Shared.TestMode)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local GunReview = require(ReplicatedStorage.Shared.Config.GunReview)

local ViewmodelController = require(script.Parent.ViewmodelController)

local GunReviewController = {}

local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromHex("A9ADB4")
local BACK = Color3.fromHex("16181B")
local ACCENT = Color3.fromHex("F2C94C")
local BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local MEDIUM = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)

type Verdict = "good" | "work"

local order: { string } = {}
local verdicts: { [string]: Verdict } = {}
local index = 1
local speed = 1
local frozen = false
local open = false

local gui: ScreenGui? = nil
local title: TextLabel? = nil
local status: TextLabel? = nil
local list: TextLabel? = nil

local function allowed(): boolean
	return RunService:IsStudio() or TestMode.isOn()
end

local function label(
	parent: Instance,
	text: string,
	size: number,
	font: Font,
	color: Color3,
	y: number,
	h: number
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(14, y)
	l.Size = UDim2.new(1, -28, 0, h)
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.TextWrapped = true
	l.RichText = true
	l.Text = text
	l.Parent = parent
	return l
end

local function equippedId(): string?
	-- WorldModel writes the held gun on the Player (and on bots' models).
	local id = StateValues.get(player, "WeaponId")
	return if typeof(id) == "string" then id else nil
end

local function refresh()
	if not title or not status or not list then
		return
	end
	local id = order[index] or "?"
	title.Text =
		string.format('GUN REVIEW  <font color="#F2C94C">%s</font>  %d / %d', id, index, #order)
	local speedText = if frozen
		then "frozen"
		elseif speed == 1 then "normal speed"
		else string.format("%.1fx speed", speed)
	local held = equippedId()
	status.Text = string.format(
		"Holding: %s  ·  %s\n[ ] gun  ·  N draw  ·  G reload  ·  B empty reload  ·  Z slow-mo  ·  X freeze\nK looks good  ·  J needs work  ·  F6 hide",
		held or "nothing",
		speedText
	)
	local lines = { "<b>Check each step</b>" }
	for _, step in GunReview.STEPS do
		table.insert(lines, "·  " .. step)
	end
	table.insert(lines, "")
	local done = 0
	local row = {}
	for i, gun in order do
		local v = verdicts[gun]
		local color = if v == "good" then "#6FCF97" elseif v == "work" then "#EB5757" else "#A9ADB4"
		local mark = if v == "good" then "✓" elseif v == "work" then "✗" else "·"
		local name = if i == index then "<b>" .. gun .. "</b>" else gun
		table.insert(row, string.format('<font color="%s">%s %s</font>', color, mark, name))
		if v then
			done += 1
		end
	end
	table.insert(lines, string.format("<b>Guns</b> (%d / %d reviewed)", done, #order))
	table.insert(lines, table.concat(row, "   "))
	list.Text = table.concat(lines, "\n")
end

local function applyTimeScale()
	StateValues.set(
		Workspace,
		"VfxTimeScale",
		if frozen then 0 elseif speed == 1 then nil else speed
	)
	refresh()
end

local function pick(i: number)
	index = ((i - 1) % #order) + 1
	Net.event("PickWeapon"):FireServer(order[index])
	task.delay(0.3, refresh)
	refresh()
end

local function heldConfig()
	local id = equippedId()
	return id and Weapons.get(id)
end

local function setVerdict(v: Verdict)
	local id = order[index]
	verdicts[id] = v
	print(
		string.format("[GunReview] %s: %s", id, if v == "good" then "LOOKS GOOD" else "NEEDS WORK")
	)
	refresh()
end

local function build()
	local g = Instance.new("ScreenGui")
	g.Name = "GunReview"
	g.ResetOnSpawn = false
	g.DisplayOrder = 50
	g.IgnoreGuiInset = false
	g.Enabled = false
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.new(0, 16, 0.45, 0)
	panel.Size = UDim2.fromOffset(380, 330)
	panel.BackgroundColor3 = BACK
	panel.BackgroundTransparency = 0.15
	panel.Parent = g
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = ACCENT
	stroke.Transparency = 0.5
	stroke.Parent = panel
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local function fit()
		local cam = Workspace.CurrentCamera
		local h = if cam then cam.ViewportSize.Y else 800
		scale.Scale = math.clamp(h / 900, 0.6, 1.2)
	end
	fit()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	title = label(panel, "", 20, BOLD, WHITE, 10, 26)
	status = label(panel, "", 14, MEDIUM, MUTED, 40, 54)
	list = label(panel, "", 14, MEDIUM, WHITE, 100, 220)
	g.Parent = player:WaitForChild("PlayerGui")
	gui = g
	refresh()
end

local function setOpen(value: boolean)
	open = value
	if gui then
		gui.Enabled = value
	end
	if not value then
		speed, frozen = 1, false
		applyTimeScale()
	else
		-- Start on the gun in hand when it's in the list.
		local held = equippedId()
		local at = held and table.find(order, held)
		if at then
			index = at
		end
		refresh()
	end
end

function GunReviewController.start()
	if not allowed() then
		return
	end
	local folder = ReplicatedStorage:WaitForChild("Weapons", 10)
	for _, id in GunReview.ORDER do
		if Weapons.get(id) and folder and folder:FindFirstChild(id) then
			table.insert(order, id)
		end
	end
	if #order == 0 then
		return
	end
	build()
	local keys = GunReview.KEYS
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed and input.KeyCode ~= keys.toggle then
			return
		end
		local key = input.KeyCode
		if key == keys.toggle then
			setOpen(not open)
			return
		end
		if not open then
			return
		end
		if key == keys.next then
			pick(index + 1)
		elseif key == keys.prev then
			pick(index - 1)
		elseif key == keys.slow then
			local at = table.find(GunReview.SPEEDS, speed) or 1
			speed = GunReview.SPEEDS[(at % #GunReview.SPEEDS) + 1]
			frozen = false
			applyTimeScale()
		elseif key == keys.freeze then
			frozen = not frozen
			applyTimeScale()
		elseif key == keys.draw then
			local config = heldConfig()
			if config then
				ViewmodelController.equip(config, config.drawTime or config.equipTime)
			end
		elseif key == keys.reload then
			local config = heldConfig()
			if config and config.magSize > 0 then
				ViewmodelController.reload(config.reloadTime, false)
			end
		elseif key == keys.emptyReload then
			local config = heldConfig()
			if config and config.magSize > 0 then
				ViewmodelController.reload(config.emptyReloadTime or config.reloadTime, true)
			end
		elseif key == keys.good then
			setVerdict("good")
		elseif key == keys.needsWork then
			setVerdict("work")
		end
	end)
	StateValues.changed(player, "WeaponId"):Connect(refresh)
	player.CharacterAdded:Connect(function()
		task.delay(1, refresh)
	end)
end

return GunReviewController
