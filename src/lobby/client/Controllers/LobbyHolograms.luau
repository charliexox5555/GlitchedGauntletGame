--!strict
-- The lobby's hologram stands (vault/02 Art/Lobby Holograms.md), RIVALS-style shop entry points. Studio-built
-- (tools/studio/lobby_v5/BuildLobbyHolograms.luau) under Workspace.LobbyV5.Holograms, each a Model tagged
-- `LobbyHologram` with an `Offer` attribute, a `Hologram` model (the floating items), an optional `HologramAlt`
-- (shown once the offer is owned) and a `PromptAnchor` part.
-- This client:
--   * sways and bobs each nearby `Hologram` (Lobby Config.HOLOGRAM; one BulkMoveTo per stand, 30 Hz, only
--     within range and while no menu is open). No flicker: the owner found flashing off-putting.
--   * adds a ProximityPrompt that opens the offer: the Starter Bundle confirm, the Tempest-Strike bundle page,
--     the Battle Pass, or the Free Rewards popup.
--   * prompts work from the first visit (owner 2026-11-28: on before the Shop unlocks too) and follow the owned
--     state (the Starter stand swaps to the Standard Case and opens the Shop's cases once the bundle is bought).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Lobby.Config)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local SeasonCatalog = require(ReplicatedStorage.Lobby.SeasonCatalog)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local Router = require(script.Parent.Parent.Util.Router)
local ShopController = require(script.Parent.ShopController)

local LobbyHolograms = {}

local TAG = "LobbyHologram"
local PROMPT_NAME = "HologramPrompt"
local H = Config.HOLOGRAM
local player = Players.LocalPlayer

type Offer = {
	action: string,
	object: string,
	open: () -> (),
	-- the owned version, when the offer can be owned (state value that says so)
	owned: string?,
	ownedAction: string?,
	ownedObject: string?,
	ownedOpen: (() -> ())?,
	-- false hides the prompt (e.g. the pass is closed for this update)
	available: (() -> boolean)?,
	spin: boolean?,
}

local OFFERS: { [string]: Offer } = {
	Starter = {
		action = "View Bundle",
		object = "Starter Bundle",
		open = function()
			ShopController.openDisplay("Starter", nil)
		end,
		owned = "StarterBought",
		ownedAction = "Open Cases",
		ownedObject = "Shop",
		ownedOpen = function()
			Router.open("Shop", "CASES")
		end,
	},
	TempestStrike = {
		action = "View Bundle",
		object = "Tempest-Strike",
		open = function()
			ShopController.openDisplay("TempestStrike", nil)
		end,
	},
	BattlePass = {
		action = "Open",
		object = "Battle Pass",
		open = function()
			Router.open("BattlePass")
		end,
		available = SeasonCatalog.screenOn,
	},
	FreeRewards = {
		action = "Claim",
		object = "Free Rewards",
		open = function()
			Router.open("FreeRewards")
		end,
		spin = true,
	},
}

type Layer = { parts: { BasePart }, offsets: { CFrame }, shown: { number } }
type Stand = {
	model: Model,
	offer: Offer,
	home: CFrame,
	main: Layer?,
	alt: Layer?,
	prompt: ProximityPrompt?,
	phase: number,
	usingAlt: boolean?,
}

local stands: { [Model]: Stand } = {}

local function layerOf(holder: Instance?, home: CFrame): Layer?
	if not (holder and holder:IsA("Model")) then
		return nil
	end
	local layer: Layer = { parts = {}, offsets = {}, shown = {} }
	for _, d in holder:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(layer.parts, d)
			table.insert(layer.offsets, home:ToObjectSpace(d.CFrame))
			local t = d:GetAttribute("ShowT")
			table.insert(layer.shown, if typeof(t) == "number" then t else d.Transparency)
		end
	end
	return if #layer.parts > 0 then layer else nil
end

local function setVisible(layer: Layer?, on: boolean)
	if not layer then
		return
	end
	for i, p in layer.parts do
		p.Transparency = if on then layer.shown[i] else 1
	end
end

local function owned(stand: Stand): boolean
	local key = stand.offer.owned
	return key ~= nil and StateValues.get(player, key) == true
end

-- the prompt and the owned swap follow the player's state
local function refresh(stand: Stand)
	local offer = stand.offer
	local isOwned = owned(stand) and stand.alt ~= nil
	if isOwned ~= (stand.usingAlt == true) then
		stand.usingAlt = isOwned
		setVisible(stand.main, not isOwned)
		setVisible(stand.alt, isOwned)
	end
	local prompt = stand.prompt
	if prompt then
		prompt.Enabled = offer.available == nil or offer.available()
		prompt.ActionText = if isOwned then offer.ownedAction or offer.action else offer.action
		prompt.ObjectText = if isOwned then offer.ownedObject or offer.object else offer.object
	end
end

local function makePrompt(stand: Stand)
	local anchor = stand.model:FindFirstChild("PromptAnchor")
	if not (anchor and anchor:IsA("BasePart")) or anchor:FindFirstChild(PROMPT_NAME) then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = H.promptReach
	prompt.Triggered:Connect(function()
		if PlayZone.get(player) ~= "Lobby" or Router.current() then
			return
		end
		local offer = stand.offer
		if stand.usingAlt and offer.ownedOpen then
			offer.ownedOpen()
		else
			offer.open()
		end
	end)
	prompt.Parent = anchor
	stand.prompt = prompt
end

local function track(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local id = model:GetAttribute("Offer")
	local offer = if typeof(id) == "string" then OFFERS[id] else nil
	if not offer then
		return
	end
	local holder = model:FindFirstChild("Hologram")
	if not (holder and holder:IsA("Model")) then
		return
	end
	local home = holder:GetPivot()
	local stand: Stand = {
		model = model,
		offer = offer,
		home = home,
		main = layerOf(holder, home),
		alt = layerOf(model:FindFirstChild("HologramAlt"), home),
		phase = (home.Position.X * 0.37 + home.Position.Z * 0.21) % 6.28, -- stands don't move in step
	}
	if not stand.main then
		return -- not streamed in yet: the DescendantAdded hook below tries again
	end
	stands[model] = stand
	makePrompt(stand)
	refresh(stand)
end

local function untrack(model: Instance)
	local stand = stands[model :: Model]
	if stand then
		stands[model :: Model] = nil
		if stand.prompt then
			stand.prompt:Destroy()
		end
	end
end

local watchers: { [Instance]: RBXScriptConnection } = {}
local function watch(model: Instance)
	track(model)
	if not watchers[model] then
		-- StreamingEnabled: a stand's parts can arrive after its tag (the builder makes stands Atomic, so they
		-- arrive together); rebuild once they do
		watchers[model] = model.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") and not stands[model :: Model] then
				task.defer(track, model)
			end
		end)
	end
end

local function unwatch(model: Instance)
	untrack(model)
	local w = watchers[model]
	if w then
		w:Disconnect()
		watchers[model] = nil
	end
end

local scratch: { CFrame } = {}
local function step(now: number)
	local camera = workspace.CurrentCamera
	if not camera or Router.current() or PlayZone.get(player) ~= "Lobby" then
		return
	end
	local eye = camera.CFrame.Position
	local bobW = 2 * math.pi / H.bobPeriod
	local swayW = 2 * math.pi / H.swayPeriod
	for _, stand in stands do
		if (stand.home.Position - eye).Magnitude > H.range then
			continue
		end
		local layer = if stand.usingAlt then stand.alt else stand.main
		if not layer then
			continue
		end
		local yaw = if stand.offer.spin
			then math.rad((now * H.spin) % 360)
			else math.rad(H.sway) * math.sin(now * swayW + stand.phase)
		local pivot = stand.home
			* CFrame.new(0, H.bob * math.sin(now * bobW + stand.phase), 0)
			* CFrame.Angles(0, yaw, 0)
		table.clear(scratch)
		for i, offset in layer.offsets do
			scratch[i] = pivot * offset
		end
		workspace:BulkMoveTo(layer.parts, scratch, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function LobbyHolograms.start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(watch)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(unwatch)
	for _, model in CollectionService:GetTagged(TAG) do
		watch(model)
	end
	StateValues.anyChanged(player):Connect(function(name: string)
		if name == "Matches" or name == "StarterBought" then
			for _, stand in stands do
				refresh(stand)
			end
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 / H.hz then
			acc = 0
			step(os.clock())
		end
	end)
end

return LobbyHolograms
