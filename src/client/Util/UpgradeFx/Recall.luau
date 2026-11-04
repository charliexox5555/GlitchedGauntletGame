--!strict
-- Recall's upgrade levels on the client (vault/01 Design/Abilities/Upgrade
-- Paths.md → 9. Recall). A (Recharge) and B (Long Range) are numbers only:
-- the HUD, the range check and the ring already read the level's stats. The
-- glitch path, Crash Recovery:
--   * armed (our own read, until it's spent this round): our anchor glows
--     magenta with glitch static (RecallFx.setArmed), the range ring turns
--     magenta (inside it you're covered, RecallRing.setTint), and a small
--     "CRASH RECOVERY READY" chip sits above the Mod bar (out of range / no
--     anchor dims it);
--   * the rescue (RecallCrash from the server): the crash, the ghost and
--     the streak home (UpgradeFx/RecallCrash); the anchor breaking under it
--     ("Crashed") gets magenta shards instead of the usual break.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Health = require(ReplicatedStorage.Shared.Health)
local Config = require(ReplicatedStorage.Shared.Config.Mods)
local Mods = require(ReplicatedStorage.Shared.Mods)

local RecallCrash = require(script.Parent.RecallCrash)
local RecallFx = require(script.Parent.Parent.RecallFx)
local RecallRing = require(script.Parent.Parent.RecallRing)
local Types = require(script.Parent.Types)

local player = Players.LocalPlayer

local GLITCH = Config.COLORS.glitch
local CYAN = Config.COLORS.ally
local BACK = Color3.fromHex("16181B")
local MUTED = Color3.fromHex("C9CCD1")
local HEAVY = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
local CHIP_BOTTOM = 190 -- px from the bottom: above the Mod bar's status line (ModHudController)
local RECOVERED_TIME = 1.4 -- the chip reads "RECOVERED" this long after our rescue
local JITTER_EVERY = { 1.2, 3 } -- seconds between the chip's glitch hiccups
local JITTER_TIME = 0.09

type ChipState = "Hidden" | "Ready" | "OutOfRange" | "NoAnchor" | "Recovered"

local TEXT: { [ChipState]: string } = {
	Hidden = "",
	Ready = "CRASH RECOVERY READY",
	OutOfRange = "CRASH RECOVERY · OUT OF RANGE",
	NoAnchor = "CRASH RECOVERY · PLANT ANCHOR",
	Recovered = "CRASH RECOVERED",
}

type Chip = { gui: ScreenGui, frame: Frame, stroke: UIStroke, label: TextLabel, split: TextLabel }
local chip: Chip? = nil
local shown: ChipState = "Hidden"
local recoveredUntil = 0
local nextJitter = 0
local jitterUntil = 0

local function buildChip(): Chip
	local made = chip
	if made and made.gui.Parent then
		return made
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "RecallCrashChip"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 2
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.Name = "Chip"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -CHIP_BOTTOM)
	frame.Size = UDim2.fromOffset(0, 24)
	frame.AutomaticSize = Enum.AutomaticSize.X
	frame.BackgroundColor3 = BACK
	frame.BackgroundTransparency = 0.25
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = GLITCH
	stroke.Thickness = 1.5
	stroke.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = frame
	local function text(name: string, color: Color3, z: number): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(0, 0, 1, 0)
		l.AutomaticSize = Enum.AutomaticSize.X
		l.FontFace = HEAVY
		l.TextSize = 14
		l.TextColor3 = color
		l.ZIndex = z
		l.Parent = frame
		return l
	end
	-- A cyan copy behind the magenta text: the colour split of a bad signal.
	local split = text("Split", CYAN, 1)
	split.TextTransparency = 0.6
	local label = text("Label", GLITCH, 2)
	made = { gui = gui, frame = frame, stroke = stroke, label = label, split = split }
	chip = made
	return made
end

local function setChip(state: ChipState)
	if state == shown then
		return
	end
	shown = state
	local c = buildChip()
	c.gui.Enabled = state ~= "Hidden"
	c.label.Text = TEXT[state]
	c.split.Text = TEXT[state]
	local strong = state == "Ready" or state == "Recovered"
	c.label.TextColor3 = if strong then GLITCH else MUTED
	c.stroke.Transparency = if strong then 0 else 0.6
	c.split.Visible = strong
end

-- Every so often the chip hiccups: a sideways slip and a wider colour split.
local function stepJitter(now: number)
	local c = chip
	if not c or shown == "Hidden" then
		return
	end
	if now >= nextJitter then
		nextJitter = now + JITTER_EVERY[1] + math.random() * (JITTER_EVERY[2] - JITTER_EVERY[1])
		jitterUntil = now + JITTER_TIME
	end
	local on = now < jitterUntil
	c.frame.Position = UDim2.new(0.5, if on then math.random(-4, 4) else 0, 1, -CHIP_BOTTOM)
	c.split.Position = UDim2.fromOffset(if on then -3 else -1, if on then 1 else 0)
end

-- Our Recall level, if we have Recall (ModService publishes ModNId / ModNLevel).
local function recallLevel(): string?
	for slot = 1, Config.SLOTS do
		if player:GetAttribute("Mod" .. slot .. "Id") == "Recall" then
			local level = player:GetAttribute("Mod" .. slot .. "Level")
			return if typeof(level) == "string" then level else nil
		end
	end
	return nil
end

local handler: Types.Handler = {}

handler.onFx = function(kind: string, data: { [string]: any }): boolean
	if kind == "RecallCrash" then
		RecallCrash.play(data)
		if data.caster == player then
			recoveredUntil = os.clock() + RECOVERED_TIME
		end
		return true
	end
	if kind == "ObjectGone" and data.kind == "Recall" and data.why == "Crashed" then
		if typeof(data.at) == "Vector3" then
			RecallCrash.anchorGone(data.at)
		end
		return true
	end
	return false
end

handler.step = function(_dt: number)
	RecallCrash.step()
	local now = os.clock()
	local level = recallLevel()
	local stats = level and Mods.stats("Recall", level)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local alive = Health.isAlive(humanoid)
	local armed = stats ~= nil
		and stats.behaviour == "Crash"
		and player:GetAttribute("RecallCrashUsed") ~= true
		and alive
	RecallFx.setArmed(armed)
	RecallRing.setTint(if armed then GLITCH else nil)
	if now < recoveredUntil then
		setChip("Recovered")
	elseif not armed or not stats then
		setChip("Hidden")
	else
		local anchor = player:GetAttribute("RecallAnchor")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if typeof(anchor) ~= "Vector3" then
			setChip("NoAnchor")
		elseif
			root
			and root:IsA("BasePart")
			and (root.Position - anchor).Magnitude <= stats.range
		then
			setChip("Ready")
		else
			setChip("OutOfRange")
		end
	end
	stepJitter(now)
end

return handler
