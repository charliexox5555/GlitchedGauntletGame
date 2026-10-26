--!strict
-- The test range, for testers in a published place (vault/04 Tech/
-- Architecture.md → Test range). Runs only while test mode is on
-- (shared/TestMode): builds the range (TestRange/RangeBuilder), spawns every
-- player there, runs the dummies (TestRange/Dummies), tracks stats
-- (TestRange/RangeStats) and serves the Tester remote and the weapon racks.
--
-- Tester remote validation (roblox-security): test mode on (server value) ->
-- rate limit -> action is a known string -> per-action argument types and
-- ranges (slot, weapon id that exists and fits the slot, known behaviour,
-- boolean) -> act through WeaponService, which owns loadouts and ammo.
-- Nothing the client sends is trusted beyond picking from those lists.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local TestMode = require(ReplicatedStorage.Shared.TestMode)
local TestRange = require(ReplicatedStorage.Shared.Config.TestRange)
local Types = require(ReplicatedStorage.Shared.Types)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local TestRangeFolder = script.Parent.Parent.TestRange
local Dummies = require(TestRangeFolder.Dummies)
local RangeBuilder = require(TestRangeFolder.RangeBuilder)
local RangeStats = require(TestRangeFolder.RangeStats)
local WeaponService = require(script.Parent.WeaponService)

type Slot = Types.Slot

local TestRangeService = {}

local STATE_FOLDER = "TestRangeState"
local MAX_ID_LENGTH = 32
local RESET_COOLDOWN = 2 -- seconds between dummy resets, server-wide
local SHARED_COOLDOWN = 0.5 -- per player, for actions that change the range for everyone

local enabled = false
local behaviours: { [string]: boolean } = {}
local buckets: { [Player]: { tokens: number, last: number } } = {}
local lastReset = -math.huge
local lastShared: { [Player]: number } = {}
local stateFolder: Folder? = nil

local function allow(player: Player): boolean
	local perSecond, burst = TestRange.RATE[1], TestRange.RATE[2]
	local now = os.clock()
	local b = buckets[player]
	if not b then
		b = { tokens = burst, last = now }
		buckets[player] = b
	end
	b.tokens = math.min(burst, b.tokens + (now - b.last) * perSecond)
	b.last = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

-- One tester can't flood everyone with resets or behaviour flips.
local function allowShared(player: Player): boolean
	local now = os.clock()
	if now - (lastShared[player] or -math.huge) < SHARED_COOLDOWN then
		return false
	end
	lastShared[player] = now
	return true
end

local function isSlot(v: unknown): boolean
	return v == "Primary" or v == "Secondary" or v == "Melee"
end

local function alive(player: Player): boolean
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function isBehaviour(id: unknown): boolean
	return typeof(id) == "string" and behaviours[id :: string] ~= nil
end

-- Puts a gun into its slot (loadout survives respawns) and switches to it.
local function giveWeapon(player: Player, id: string)
	local config = Weapons.get(id)
	if not config then
		return
	end
	WeaponService.setWeapon(player, config.slot, config.id)
	WeaponService.equip(player, config.slot)
end

local function setBehaviour(id: string, on: boolean)
	behaviours[id] = on
	if stateFolder then
		stateFolder:SetAttribute(id, on)
	end
end

local function onTester(player: Player, action: unknown, a: unknown, b: unknown)
	if not enabled or not allow(player) or typeof(action) ~= "string" then
		return
	end
	if action == "SetWeapon" then
		if not isSlot(a) or typeof(b) ~= "string" or #(b :: string) > MAX_ID_LENGTH then
			return
		end
		local config = Weapons.get(b :: string)
		if not config or config.slot ~= a then
			return
		end
		giveWeapon(player, config.id)
	elseif action == "Refill" then
		WeaponService.refill(player)
	elseif action == "ResetDummies" then
		local now = os.clock()
		if now - lastReset >= RESET_COOLDOWN and allowShared(player) then
			lastReset = now
			Dummies.resetAll()
		end
	elseif action == "SetBehaviour" then
		if not isBehaviour(a) or typeof(b) ~= "boolean" or not allowShared(player) then
			return
		end
		setBehaviour(a :: string, b :: boolean)
	elseif action == "ResetStats" then
		RangeStats.reset(player)
	end
end

-- Weapon racks: the prompt fires on the server; check the player is really
-- standing at the rack before handing the gun over.
local function onStation(player: Player, base: BasePart, weaponId: string)
	if not enabled or not allow(player) or not alive(player) then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	if (root.Position - base.Position).Magnitude > TestRange.STATION_PROMPT_DISTANCE + 5 then
		return
	end
	giveWeapon(player, weaponId)
end

function TestRangeService.init()
	enabled = TestMode.resolve()
	-- Always listening (onTester drops everything while test mode is off),
	-- so requests never queue up on a remote with no handler.
	Net.event("Tester").OnServerEvent:Connect(onTester)
	if not enabled then
		return
	end
	for _, b in TestRange.BEHAVIOURS do
		behaviours[b.id] = b.default
	end
	WeaponService.onShot(RangeStats.onShot)
	WeaponService.onDamage(RangeStats.onDamage)
	Dummies.onHealed(RangeStats.clearTarget)
end

function TestRangeService.start()
	if not enabled then
		return
	end
	-- Shared switches, replicated as attributes for the tester menu.
	local old = ReplicatedStorage:FindFirstChild(STATE_FOLDER)
	if old then
		old:Destroy()
	end
	local state = Instance.new("Folder")
	state.Name = STATE_FOLDER
	for id, on in behaviours do
		state:SetAttribute(id, on)
	end
	state.Parent = ReplicatedStorage
	stateFolder = state

	local built = RangeBuilder.build()
	-- Everyone spawns in the range: other spawns are switched off.
	for _, d in workspace:GetDescendants() do
		if d:IsA("SpawnLocation") and d ~= built.spawn then
			d.Enabled = false
		end
	end
	for _, station in built.stations do
		station.prompt.Triggered:Connect(function(player)
			onStation(player, station.base, station.weaponId)
		end)
	end

	local oldDummies = workspace:FindFirstChild("Dummies")
	if oldDummies then
		oldDummies:Destroy()
	end
	-- WeaponService's wall checks skip workspace.Dummies (bodies aren't walls).
	local dummies = Instance.new("Folder")
	dummies.Name = "Dummies"
	dummies.Parent = workspace
	Dummies.start(dummies, built.toWorld, function(id: string): boolean
		return behaviours[id] == true
	end)
	RangeStats.start()

	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
		lastShared[player] = nil
	end)
	-- Anyone who spawned before the range existed respawns in it.
	for _, player in Players:GetPlayers() do
		if player.Character then
			player:LoadCharacter()
		end
	end
	print("[TestRange] test mode is ON: range built, dummies spawned")
end

return TestRangeService
