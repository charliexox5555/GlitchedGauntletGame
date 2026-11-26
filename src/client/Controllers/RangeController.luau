--!strict
-- Range dummies on the client: a health bar over every dummy (the
-- "RangeDummy" tag and Dummy* attributes set by the server's TestRange/
-- Dummies and LobbyServer/Range/RangeBots). The bar only shows the replicated
-- health; the server owns the number. The damage dummy (tag
-- RangeDamageDummy) shows its running damage, DPS and hits instead
-- (vault/01 Design/Range v5.md). Dummies stream in and out (StreamingEnabled),
-- so bars are made when a dummy arrives and dropped when it leaves.

local StateValues = require(game:GetService("ReplicatedStorage").Shared.StateValues)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Health = require(game:GetService("ReplicatedStorage").Shared.Health)
local RangeDummies = require(game:GetService("ReplicatedStorage").Shared.Config.RangeDummies)
local Theme = require(game:GetService("ReplicatedStorage").Shared.Config.Theme)

local RangeController = {}

local TAG = "RangeDummy"
local DAMAGE_TAG = "RangeDamageDummy"
local HEAVY = Theme.TEXT.titleS.font
local BOLD = Theme.TEXT.label.font
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
local pending: { [Instance]: boolean } = {}
local addBar: (Instance) -> ()
local playerGui: Instance? = nil

local make = require(script.Parent.Parent.Util.Ui).make

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

addBar = function(model: Instance)
	if bars[model] or not model:IsA("Model") or not playerGui then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head")
	if not humanoid or not head or not head:IsA("BasePart") then
		-- Streamed in as an empty model first (the range is far from the lobby): try again when its parts land.
		if not pending[model] then
			pending[model] = true
			task.spawn(function()
				local h = model:WaitForChild("Head", 15)
				model:WaitForChild("Humanoid", 5)
				pending[model] = nil
				if
					h
					and model:IsDescendantOf(workspace)
					and CollectionService:HasTag(model, TAG)
				then
					addBar(model)
				end
			end)
		end
		return
	end
	local accentValue = StateValues.get(model, "DummyAccent")
	local accent = if typeof(accentValue) == "Color3"
		then accentValue
		elseif CollectionService:HasTag(model, "RangeBot") then RangeDummies.COLOR:Lerp(
			WHITE,
			0.45
		)
		else WHITE
	local damageDummy = CollectionService:HasTag(model, DAMAGE_TAG)
	local labelValue = StateValues.get(model, "DummyLabel")
	local distance = StateValues.get(model, "DummyDistance")

	local gui = make("BillboardGui", {
		Name = "RangeBar_" .. model.Name,
		Adornee = head,
		Size = UDim2.fromOffset(if damageDummy then 200 else 132, 38),
		StudsOffsetWorldSpace = Vector3.new(0, 2.3, 0),
		AlwaysOnTop = true,
		MaxDistance = 260,
		LightInfluence = 0,
		ResetOnSpawn = false,
	}, playerGui)
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		FontFace = HEAVY,
		TextSize = 13,
		TextColor3 = accent,
		TextStrokeTransparency = 0.55,
		Text = if damageDummy
			then "DAMAGE DUMMY"
			else string.format(
				"%s%s",
				if typeof(labelValue) == "string" then labelValue else "DUMMY",
				if typeof(distance) == "number" then string.format("  ·  %d", distance) else ""
			),
	}, gui)
	local back = make("Frame", {
		Position = UDim2.fromOffset(4, 20),
		Size = UDim2.new(1, -8, 0, 12),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}, gui)
	local trail = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Visible = not damageDummy,
	}, back)
	local fill = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = HEALTHY,
		BorderSizePixel = 0,
		Visible = not damageDummy,
	}, back)
	local hp = make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		FontFace = BOLD,
		TextSize = 11,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0.2,
		ZIndex = 2,
	}, back)

	local fillTween: Tween? = nil
	local trailTween: Tween? = nil
	local function refresh(instant: boolean)
		if damageDummy then
			local total = model:GetAttribute("DamageTotal")
			local dps = model:GetAttribute("DamageDps")
			local hits = model:GetAttribute("DamageHits")
			hp.Text = if typeof(total) == "number" and total > 0
				then string.format(
					"%d DMG  ·  %d DPS  ·  %d HITS",
					total,
					if typeof(dps) == "number" then dps else 0,
					if typeof(hits) == "number" then hits else 0
				)
				else "SHOOT ME"
			return
		end
		local max = Health.max(humanoid)
		local health = math.clamp(Health.get(humanoid), 0, max)
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
			StateValues.changed(humanoid, Health.HP):Connect(function()
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
