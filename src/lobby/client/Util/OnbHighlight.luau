--!strict
-- Gold highlight stroke, gentle pulse and optional action chip for onboarding
-- prompts. Keyed per UI context ("LobbyBar", "Backpack", "Locker") so each
-- area holds at most one active highlight and cleans up reliably.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiMotion = require(ReplicatedStorage.Shared.UiMotion)

export type TagPos = "top" | "bottom" | "insideTopRight"

export type Options = {
	tag: string?,
	tagPos: TagPos?,
	stroke: boolean?,
	scale: number?,
}

type Entry = {
	target: GuiObject,
	tagText: string?,
	tagPos: TagPos,
	strokeOn: boolean,
	scale: number,
	pulse: UIScale,
	stroke: UIStroke?,
	tag: Frame?,
	conn: RBXScriptConnection,
}

local OnbHighlight = {}

local GOLD = Color3.fromHex("FFC83D")
local INK = Color3.fromHex("1A1A1D")
local FONT = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy)

local entries: { [string]: Entry } = {}

local function clearArtifacts(target: GuiObject)
	for _, name in { "OnbPulse", "OnbStroke", "OnbTag" } do
		local found = target:FindFirstChild(name)
		if found then
			found:Destroy()
		end
	end
end

function OnbHighlight.clear(key: string)
	local entry = entries[key]
	if not entry then
		return
	end
	entries[key] = nil
	entry.conn:Disconnect()
	if entry.pulse.Parent then
		entry.pulse:Destroy()
	end
	if entry.stroke and entry.stroke.Parent then
		entry.stroke:Destroy()
	end
	if entry.tag and entry.tag.Parent then
		entry.tag:Destroy()
	end
end

function OnbHighlight.focus(key: string, target: GuiObject?, opts: Options?)
	if not target then
		OnbHighlight.clear(key)
		return
	end
	local tagText = if opts and opts.tag and opts.tag ~= "" then string.upper(opts.tag) else nil
	local tagPos: TagPos = if opts and opts.tagPos then opts.tagPos else "top"
	local strokeOn = if opts and opts.stroke ~= nil then opts.stroke else true
	local scale = if opts and opts.scale then opts.scale else 1.06

	local existing = entries[key]
	if
		existing
		and existing.target == target
		and existing.tagText == tagText
		and existing.tagPos == tagPos
		and existing.strokeOn == strokeOn
		and existing.scale == scale
	then
		return
	end

	OnbHighlight.clear(key)
	clearArtifacts(target)

	local pulse = Instance.new("UIScale")
	pulse.Name = "OnbPulse"
	pulse.Scale = 1
	pulse.Parent = target

	local stroke: UIStroke? = nil
	if strokeOn then
		local s = Instance.new("UIStroke")
		s.Name = "OnbStroke"
		s.Color = GOLD
		s.Thickness = 3.5
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.LineJoinMode = Enum.LineJoinMode.Round
		s.Transparency = 0
		s.Parent = target
		stroke = s
	end

	local tagFrame: Frame? = nil
	if tagText then
		local chip = Instance.new("Frame")
		chip.Name = "OnbTag"
		chip.BackgroundColor3 = GOLD
		chip.BorderSizePixel = 0
		chip.AutomaticSize = Enum.AutomaticSize.X
		chip.Size = UDim2.fromOffset(0, 24)
		chip.ZIndex = target.ZIndex + 25
		chip.Active = false
		chip.Selectable = false
		if tagPos == "insideTopRight" then
			chip.AnchorPoint = Vector2.new(1, 0)
			chip.Position = UDim2.new(1, -8, 0, 8)
		elseif tagPos == "bottom" then
			chip.AnchorPoint = Vector2.new(0.5, 0)
			chip.Position = UDim2.new(0.5, 0, 1, 6)
		else
			chip.AnchorPoint = Vector2.new(0.5, 1)
			chip.Position = UDim2.new(0.5, 0, 0, -6)
		end
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = chip
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 8)
		pad.PaddingRight = UDim.new(0, 8)
		pad.Parent = chip
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromOffset(0, 24)
		label.AutomaticSize = Enum.AutomaticSize.X
		label.BackgroundTransparency = 1
		label.Text = tagText
		label.FontFace = FONT
		label.TextSize = 13
		label.TextColor3 = INK
		label.ZIndex = chip.ZIndex + 1
		label.Active = false
		label.Parent = chip
		chip.Parent = target
		tagFrame = chip
	end

	local entry: Entry
	local conn = target.Destroying:Once(function()
		if entries[key] == entry then
			OnbHighlight.clear(key)
		end
	end)
	entry = {
		target = target,
		tagText = tagText,
		tagPos = tagPos,
		strokeOn = strokeOn,
		scale = scale,
		pulse = pulse,
		stroke = stroke,
		tag = tagFrame,
		conn = conn,
	}
	entries[key] = entry

	if UiMotion.reduced() then
		return
	end

	task.spawn(function()
		while entries[key] == entry and target.Parent do
			local up = UiMotion.tween(
				pulse,
				0.45,
				{ Scale = scale },
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.Out
			)
			if stroke then
				UiMotion.tween(
					stroke,
					0.45,
					{ Transparency = 0.35 },
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.Out
				)
			end
			up.Completed:Wait()
			if entries[key] ~= entry or not target.Parent then
				break
			end
			local down = UiMotion.tween(
				pulse,
				0.45,
				{ Scale = 1 },
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.In
			)
			if stroke then
				UiMotion.tween(
					stroke,
					0.45,
					{ Transparency = 0 },
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.In
				)
			end
			down.Completed:Wait()
			if entries[key] ~= entry then
				break
			end
			task.wait(0.2)
		end
	end)
end

return OnbHighlight
