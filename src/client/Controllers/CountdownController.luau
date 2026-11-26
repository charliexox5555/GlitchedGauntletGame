--!strict
-- The big 3-2-1 in the middle of the screen before every round (owner 2026-11-26: "maybe just a countdown more
-- like on the screen"; vault/01 Design/First Ten Minutes.md). It shows while the match is in its "Countdown"
-- phase, one number per second from MatchState's clock: each number pops in from the centre (Quint, no
-- overshoot) and fades as the next arrives. White Rubik Heavy with a soft dark drop copy for contrast over a
-- bright map: no outline, no glow (UI Theme v4). The GET READY / GUNS UP banner stays in its own slot.
-- Code-built (a single label pair); restyle here or move it into a Studio template if wanted.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MatchState = require(ReplicatedStorage.Shared.MatchState)
local UiMotion = require(ReplicatedStorage.Shared.UiMotion)

local CountdownController = {}

local player = Players.LocalPlayer

local FONT = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy) -- Rubik
local WHITE = Color3.fromHex("F4F6F9")
local SHADOW = Color3.fromHex("06080C")
-- The number's height as a share of the screen's. Roblox caps TextScaled at 100 px, so the label is a fixed
-- TextSize 100 (a ~100 px glyph) and a UIScale brings it to this size.
local NUMBER_HEIGHT = 0.17
local BASE_TEXT = 100
local POP_FROM = 1.35 -- each number starts this big and settles to 1
local POP_TIME = 0.32

type Ui = { gui: ScreenGui, label: TextLabel, shadow: TextLabel, scale: UIScale }

local function build(): Ui
	local gui = Instance.new("ScreenGui")
	gui.Name = "RoundCountdown"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Enabled = false
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.4)
	holder.Size = UDim2.fromOffset(BASE_TEXT * 2, BASE_TEXT * 1.3)
	holder.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	local function text(name: string, color: Color3, offset: number, z: number): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.new(0.5, 0, 0.5, offset)
		l.Size = UDim2.fromScale(1, 1)
		l.FontFace = FONT
		l.TextSize = BASE_TEXT
		l.TextColor3 = color
		l.ZIndex = z
		l.Text = ""
		l.Parent = holder
		return l
	end
	local shadow = text("Shadow", SHADOW, 6, 1)
	shadow.TextTransparency = 0.55
	local label = text("Number", WHITE, 0, 2)
	gui.Parent = player:WaitForChild("PlayerGui")
	return { gui = gui, label = label, shadow = shadow, scale = scale }
end

function CountdownController.start()
	local ui = build()
	local shown = 0
	RunService.RenderStepped:Connect(function()
		local counting = MatchState.phase() == "Countdown"
		local n = if counting then math.clamp(math.ceil(MatchState.timeLeft()), 0, 3) else 0
		if n == shown then
			return
		end
		shown = n
		if n <= 0 then
			ui.gui.Enabled = false
			return
		end
		ui.gui.Enabled = true
		ui.label.Text = tostring(n)
		ui.shadow.Text = tostring(n)
		ui.label.TextTransparency = 0
		ui.shadow.TextTransparency = 0.55
		local base = ui.gui.AbsoluteSize.Y * NUMBER_HEIGHT / BASE_TEXT
		ui.scale.Scale = if UiMotion.reduced() then base else base * POP_FROM
		UiMotion.tween(ui.scale, POP_TIME, { Scale = base })
		-- fade over the rest of its second
		UiMotion.tween(
			ui.label,
			0.9,
			{ TextTransparency = 0.35 },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
	end)
end

return CountdownController
