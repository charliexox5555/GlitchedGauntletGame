--!strict
-- Test range dummies on the client: a health bar over every dummy (the
-- "RangeDummy" tag and Dummy* attributes set by the server's TestRange/
-- Dummies). The bar only shows the Humanoid's replicated health; the server
-- owns the number. Dummies stream in and out (StreamingEnabled), so bars are
-- made when a dummy arrives and dropped when it leaves.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local RangeController = {}

local TAG = "RangeDummy"
local DARK = Color3.fromHex("1E2022")
local HEALTHY = Color3.fromHex("6FCF97")
local YELLOW = Color3.fromHex("F2C94C")
local RED = Color3.fromHex("EB5757")
local WHITE = Color3.new(1, 1, 1)

local FILL_INFO = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TRAIL_INFO =
	TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.3)

type Bar = {
	gui: BillboardGui,
	connections: { RBXScriptConnection },
}

local bars: { [Instance]: Bar } = {}
local playerGui: Instance? = nil

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

local function fillColor(fraction: number): Color3
	if fraction <= 0.25 then
		return RED
	elseif fraction <= 0.5 then
		return YELLOW
	end
	return HEALTHY
end

local function removeBar(model: Instance)
	local bar = bars[model]
	if bar then
		bars[model] = nil
		for _, c in bar.connections do
			c:Disconnect()
		end
		bar.gui:Destroy()
	end
end

local function addBar(model: Instance)
	if bars[model] or not model:IsA("Model") or not playerGui then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head")
	if not humanoid or not head or not head:IsA("BasePart") then
		return
	end
	local accentValue = model:GetAttribute("DummyAccent")
	local accent = if typeof(accentValue) == "Color3" then accentValue else WHITE
	local labelValue = model:GetAttribute("DummyLabel")
	local distance = model:GetAttribute("DummyDistance")

	local gui = make("BillboardGui", {
		Name = "RangeBar_" .. model.Name,
		Adornee = head,
		Size = UDim2.fromOffset(132, 38),
		StudsOffsetWorldSpace = Vector3.new(0, 2.3, 0),
		AlwaysOnTop = true,
		MaxDistance = 260,
		LightInfluence = 0,
		ResetOnSpawn = false,
	}, playerGui)
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 13,
		TextColor3 = accent,
		TextStrokeTransparency = 0.4,
		Text = string.format(
			"%s%s",
			if typeof(labelValue) == "string" then labelValue else "DUMMY",
			if typeof(distance) == "number" then string.format("  ·  %d", distance) else ""
		),
	}, gui)
	local back = make("Frame", {
		Position = UDim2.fromOffset(4, 20),
		Size = UDim2.new(1, -8, 0, 12),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 3) }, back)
	make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.3 }, back)
	local trail = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, back)
	make("UICorner", { CornerRadius = UDim.new(0, 3) }, trail)
	local fill = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = HEALTHY,
		BorderSizePixel = 0,
	}, back)
	make("UICorner", { CornerRadius = UDim.new(0, 3) }, fill)
	local hp = make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 11,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0.2,
		ZIndex = 2,
	}, back)

	local fillTween: Tween? = nil
	local trailTween: Tween? = nil
	local function refresh(instant: boolean)
		local max = math.max(humanoid.MaxHealth, 1)
		local health = math.clamp(humanoid.Health, 0, max)
		local fraction = health / max
		local size = UDim2.fromScale(fraction, 1)
		fill.BackgroundColor3 = fillColor(fraction)
		hp.Text = if health > 0 then tostring(math.ceil(health)) else "RESPAWNING"
		if fillTween then
			fillTween:Cancel()
		end
		if trailTween then
			trailTween:Cancel()
		end
		if instant or fraction >= trail.Size.X.Scale then
			fill.Size = size
			trail.Size = size
			return
		end
		fillTween = TweenService:Create(fill, FILL_INFO, { Size = size })
		trailTween = TweenService:Create(trail, TRAIL_INFO, { Size = size });
		(fillTween :: Tween):Play();
		(trailTween :: Tween):Play()
	end
	refresh(true)

	bars[model] = {
		gui = gui,
		connections = {
			humanoid.HealthChanged:Connect(function()
				refresh(false)
			end),
			model.AncestryChanged:Connect(function()
				if not model:IsDescendantOf(workspace) then
					removeBar(model)
				end
			end),
		},
	}
end

function RangeController.start()
	-- Billboards go straight into PlayerGui (they don't render inside a Folder).
	playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	-- Bars appear for tagged dummies whether or not test mode replicated yet;
	-- the tag only exists while the server runs the range.
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model)
		-- Atomic streaming: the parts arrive with the model, but give the
		-- attributes a frame.
		task.defer(addBar, model)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(removeBar)
	for _, model in CollectionService:GetTagged(TAG) do
		addBar(model)
	end
end

return RangeController
