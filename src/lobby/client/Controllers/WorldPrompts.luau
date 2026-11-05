--!strict
-- Hooks the lobby world (lane A's CollectionService tags, Overnight
-- 2026-11-04 → World → UI) to the menus: each tagged part gets a local
-- ProximityPrompt that opens its menu. `LobbyQueue` parts may carry a `Mode`
-- attribute ("1v1" / "2v2" / "3v3") that preselects that mode. Works whenever
-- tags appear (late builds, StreamingEnabled streaming parts in and out).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Lobby.Config)

local Router = require(script.Parent.Parent.Util.Router)

local WorldPrompts = {}

type Hook = { menu: string, action: string, object: string }

local HOOKS: { [string]: Hook } = {
	LobbyQueue = { menu = "Queue", action = "Play", object = "Duels" },
	LobbyShop = { menu = "Shop", action = "Open Shop", object = "Market" },
	LobbyBattlePass = { menu = "BattlePass", action = "Battle Pass", object = "Season 1" },
	LobbyLocker = { menu = "Locker", action = "Open Locker", object = "Loadout" },
	LobbyRangeEntrance = { menu = "Range", action = "Range", object = "Practice" },
}

local PROMPT_NAME = "LobbyMenuPrompt"

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
	local m = inst:GetAttribute("Mode")
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
	local mode = if tag == "LobbyQueue" then modeOf(inst) else nil
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = if mode then `Queue {string.upper(mode)}` else hook.action
	prompt.ObjectText = hook.object
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
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

local function detach(inst: Instance)
	local anchor = anchorOf(inst)
	local prompt = anchor and anchor:FindFirstChild(PROMPT_NAME)
	if prompt then
		prompt:Destroy()
	end
end

function WorldPrompts.start()
	for tag, hook in HOOKS do
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
			attach(tag, hook, inst)
		end)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(detach)
		for _, inst in CollectionService:GetTagged(tag) do
			attach(tag, hook, inst)
		end
	end
end

return WorldPrompts
