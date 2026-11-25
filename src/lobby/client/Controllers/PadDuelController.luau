--!strict
-- How a duel pad looks while it fills (place merge 2026-11-21: "it is made on the server and looks different when
-- queuing"). Reads the pad model's attributes from PadDuelService (PadMode, PadNeed, PadA, PadB, PadStartsAt):
--  * each half's neon border (parts named Border_A* / Border_B*) turns its team colour once someone stands on it,
--    and both blink while the pad counts down;
--  * a small label over the pad: the mode, each half's count, then the countdown.
-- Text in the game font (UiStyle.FONT), flat, no plates or outlines (owner's UI rules).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local UiStyle = require(ReplicatedStorage.Shared.Config.UiStyle)

local PadDuelController = {}

local TAG = "LobbyQueue"
local LABEL_HEIGHT = 9 -- studs over the pad
local BLINK = 4 -- blinks per second while counting down

type Tracked = {
	model: Instance,
	zone: BasePart,
	bordersA: { BasePart },
	bordersB: { BasePart },
	idle: { [BasePart]: Color3 },
	gui: BillboardGui,
	title: TextLabel,
	status: TextLabel,
}

local tracked: { [BasePart]: Tracked } = {}

local function label(
	parent: Instance,
	name: string,
	font: Font,
	maxSize: number,
	y: number,
	h: number
): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, h)
	t.Position = UDim2.fromScale(0, y)
	t.FontFace = font
	-- Note: setting TextWrapped = false clears TextScaled in Roblox, so leave it on.
	t.TextScaled = true
	t.TextXAlignment = Enum.TextXAlignment.Center
	t.TextColor3 = UiStyle.COLOR.text
	t.TextStrokeTransparency = 0.6
	t.Text = ""
	t.Parent = parent
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 6
	constraint.MaxTextSize = maxSize
	constraint.Parent = t
	return t
end

local function track(zone: Instance)
	if not zone:IsA("BasePart") or tracked[zone] then
		return
	end
	local model = zone.Parent
	if not model or model:GetAttribute("PadMode") == nil then
		return
	end
	local bordersA: { BasePart } = {}
	local bordersB: { BasePart } = {}
	local idle: { [BasePart]: Color3 } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if string.sub(d.Name, 1, 8) == "Border_A" then
				table.insert(bordersA, d)
				idle[d] = d.Color
			elseif string.sub(d.Name, 1, 8) == "Border_B" then
				table.insert(bordersB, d)
				idle[d] = d.Color
			end
		end
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "PadDuelLabel"
	-- Stud-scaled dimensions keep distant pads shrinking naturally in 3D space
	-- so faraway pad labels never blow up or overlap on small phone viewports.
	gui.Size = UDim2.fromScale(10, 2.5)
	gui.StudsOffsetWorldSpace = Vector3.new(0, LABEL_HEIGHT, 0)
	gui.MaxDistance = 75
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Adornee = zone
	gui.Parent = zone
	tracked[zone] = {
		model = model,
		zone = zone,
		bordersA = bordersA,
		bordersB = bordersB,
		idle = idle,
		gui = gui,
		title = label(gui, "Title", UiStyle.FONT.display, 34, 0, 0.56),
		status = label(gui, "Status", UiStyle.FONT.label, 22, 0.58, 0.42),
	}
end

local function paint(parts: { BasePart }, t: Tracked, color: Color3?)
	for _, p in parts do
		p.Color = color or t.idle[p]
	end
end

local function update()
	local now = workspace:GetServerTimeNow()
	local blinkOn = math.floor(os.clock() * BLINK * 2) % 2 == 0
	for zone, t in tracked do
		if not zone.Parent then
			tracked[zone] = nil
			continue
		end
		local mode = t.model:GetAttribute("PadMode")
		local need = t.model:GetAttribute("PadNeed")
		local a = t.model:GetAttribute("PadA")
		local b = t.model:GetAttribute("PadB")
		local startsAt = t.model:GetAttribute("PadStartsAt")
		if
			typeof(mode) ~= "string"
			or typeof(need) ~= "number"
			or typeof(a) ~= "number"
			or typeof(b) ~= "number"
		then
			continue
		end
		local counting = typeof(startsAt) == "number" and startsAt > now
		t.title.Text = string.upper(mode) .. " DUEL"
		if counting then
			t.status.Text = `STARTING  {math.ceil((startsAt :: number) - now)}`
		elseif a + b == 0 then
			t.status.Text = "STEP ON A SIDE"
		else
			t.status.Text = `{a}/{need}   VS   {b}/{need}`
		end
		local showA = a > 0 and (not counting or blinkOn)
		local showB = b > 0 and (not counting or blinkOn)
		paint(t.bordersA, t, if showA then UiStyle.COLOR.ally else nil)
		paint(t.bordersB, t, if showB then UiStyle.COLOR.enemy else nil)
	end
end

function PadDuelController.start()
	for _, zone in CollectionService:GetTagged(TAG) do
		track(zone)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(zone)
		task.defer(track, zone)
	end)
	-- Pads get their attributes from the server a moment after they stream in.
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		if PlayZone.get(Players.LocalPlayer) ~= "Lobby" then
			return
		end
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		for _, zone in CollectionService:GetTagged(TAG) do
			if not tracked[zone] then
				track(zone)
			end
		end
		update()
	end)
end

return PadDuelController
