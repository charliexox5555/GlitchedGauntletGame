--!strict
-- Hooks the lobby world (lane A's CollectionService tags, Overnight
-- 2026-11-04 → World → UI) to the menus: each tagged part gets a local
-- ProximityPrompt that opens its menu. `LobbyQueue` parts may carry a `Mode`
-- attribute ("1v1" / "2v2" / "3v3") that preselects that mode. Works whenever
-- tags appear (late builds, StreamingEnabled streaming parts in and out).
-- Step pads (owner 2026-11-16, like RIVALS): a tagged BasePart with the
-- attribute `Trigger = "Step"` gets no prompt; walking onto it opens its menu
-- once, and it re-arms when the player steps off. A `LobbyQueue` step pad
-- instead starts a search for its mode when you step on and cancels it when
-- you step off (QueueState join / leave: the Play menu's own QueueRequest).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Lobby.Config)

local QueueState = require(script.Parent.Parent.Util.QueueState)
local Router = require(script.Parent.Parent.Util.Router)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local SeasonCatalog = require(ReplicatedStorage.Lobby.SeasonCatalog)

local WorldPrompts = {}

-- `key` / `pad`: a prompt key other than E / ButtonX (inside the range E is a Mod and X a match action).
type Hook = { menu: string, action: string, object: string, key: Enum.KeyCode?, pad: Enum.KeyCode? }

local HOOKS: { [string]: Hook } = {
	-- LobbyQueue pads are duel pads since the place merge (2026-11-21): the
	-- server runs them (Services/PadDuelService), so no prompt here.
	LobbyShop = { menu = "Shop", action = "Open Shop", object = "Market" },
	-- LobbyBattlePass: see below (SeasonCatalog.screenOn)
	LobbyLocker = { menu = "Locker", action = "Open Locker", object = "Loadout" },
}

-- Closed for this update (shared/Config/Release): no prompt for the Battle Pass or the range.
if SeasonCatalog.screenOn() then
	HOOKS.LobbyBattlePass = { menu = "BattlePass", action = "Battle Pass", object = "Season 1" }
end
-- The range has no prompt: you walk into its hologram gate (LobbyServer RangeService, tag RangeEntry) or use the
-- bar's RANGE button.
-- The range's loadout terminals (tag RangeLoadout) are not here: ProximityPrompts never show inside the armed range
-- (measured 2026-11-25), so LoadoutController draws their hint and takes the key itself.

local PROMPT_NAME = "LobbyMenuPrompt"
local STEP_CHECK = 0.1 -- seconds between step-pad checks
local STEP_HEIGHT = 8 -- studs above the pad's centre that still count as standing on it

type StepZone = { part: BasePart, tag: string, hook: Hook, inst: Instance, inside: boolean }
local stepZones: { [Instance]: StepZone } = {}

local function anchorOf(inst: Instance): Instance?
	if inst:IsA("BasePart") or inst:IsA("Attachment") then
		return inst
	end
	if inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function modeOf(inst: Instance): string?
	local m = StateValues.get(inst, "Mode")
	if typeof(m) == "string" and Config.MODE_BY_ID[m] then
		return m
	end
	return nil
end

local function attach(tag: string, hook: Hook, inst: Instance)
	local anchor = anchorOf(inst)
	if not anchor or anchor:FindFirstChild(PROMPT_NAME) then
		return
	end
	if StateValues.get(inst, "Trigger") == "Step" and anchor:IsA("BasePart") then
		stepZones[inst] = { part = anchor, tag = tag, hook = hook, inst = inst, inside = false }
		return
	end
	local mode = if tag == "LobbyQueue" then modeOf(inst) else nil
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = if mode then `Queue {string.upper(mode)}` else hook.action
	prompt.ObjectText = hook.object
	prompt.KeyboardKeyCode = hook.key or Enum.KeyCode.E
	prompt.GamepadKeyCode = hook.pad or Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	-- Big pads: reach the prompt from the pad's edge.
	local reach = 10
	if anchor:IsA("BasePart") then
		reach = math.clamp(math.max(anchor.Size.X, anchor.Size.Z) / 2 + 6, 10, 24)
	end
	prompt.MaxActivationDistance = reach
	prompt.Triggered:Connect(function()
		Router.open(hook.menu, if tag == "LobbyQueue" then modeOf(inst) else nil)
	end)
	prompt.Parent = anchor
end

-- Tagged Models under StreamingEnabled: their parts can stream in after the
-- tag, or out and back in (taking the prompt with them), so retry whenever a
-- part arrives. (Tagging the BasePart itself, or Atomic/Persistent model
-- streaming, avoids this altogether.)
local watchers: { [Instance]: RBXScriptConnection } = {}

local function track(tag: string, hook: Hook, inst: Instance)
	attach(tag, hook, inst)
	if inst:IsA("Model") and not watchers[inst] then
		watchers[inst] = inst.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") then
				attach(tag, hook, inst)
			end
		end)
	end
end

local function detach(inst: Instance)
	stepZones[inst] = nil
	local watcher = watchers[inst]
	if watcher then
		watcher:Disconnect()
		watchers[inst] = nil
	end
	local anchor = anchorOf(inst)
	local prompt = anchor and anchor:FindFirstChild(PROMPT_NAME)
	if prompt then
		prompt:Destroy()
	end
end

local function insideZone(zone: StepZone, pos: Vector3): boolean
	local part = zone.part
	if not part.Parent then
		return false
	end
	local rel = part.CFrame:PointToObjectSpace(pos)
	local half = part.Size / 2
	return math.abs(rel.X) <= half.X
		and math.abs(rel.Z) <= half.Z
		and rel.Y >= -half.Y - 2
		and rel.Y <= half.Y + STEP_HEIGHT
end

-- Queue pads (owner 2026-11-16: "just have it queue the player auto", like RIVALS): stepping onto a pad starts a
-- search for its mode, stepping off cancels it, through the same QueueRequest join / leave the Play menu sends (the
-- server's QueueService checks the mode, the party leader, the party size and the rate). Only a search this pad
-- started is cancelled by stepping off, and a party member who isn't the leader never cancels the party's search.
local padSearch: string? = nil -- the mode a pad started for this player

local function stepQueue(zone: StepZone, now: boolean)
	local mode = modeOf(zone.inst)
	if not mode or now == zone.inside then
		return
	end
	local status = QueueState.status()
	local leads = not QueueState.inParty() or QueueState.isLeader()
	if now then
		if status == "found" or status == "teleporting" then
			return
		end
		if not (status == "searching" and QueueState.mode() == mode) then
			QueueState.join(mode)
		end
		padSearch = if leads then mode else nil
	elseif padSearch == mode then
		padSearch = nil
		if leads and status == "searching" and QueueState.mode() == mode then
			QueueState.leave()
		end
	end
end

local function checkSteps()
	if PlayZone.get(Players.LocalPlayer) ~= "Lobby" then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local pos = root.Position
	for _, zone in stepZones do
		local now = insideZone(zone, pos)
		if zone.tag == "LobbyQueue" then
			stepQueue(zone, now)
		elseif now and not zone.inside then
			Router.open(zone.hook.menu)
		end
		zone.inside = now
	end
end

function WorldPrompts.start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= STEP_CHECK then
			acc = 0
			checkSteps()
		end
	end)
	for tag, hook in HOOKS do
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
			track(tag, hook, inst)
		end)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(detach)
		for _, inst in CollectionService:GetTagged(tag) do
			track(tag, hook, inst)
		end
	end
end

return WorldPrompts
