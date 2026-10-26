--!strict
-- Server-owned Mod things that outlive the request that made them, all
-- tracked by owner so they go away when the owner dies or leaves:
--   timers   a Packet's fuse, a Lag Field opening (schedule)
--   objects  placed parts in workspace.ModObjects (Launch Pad, Firewall) with
--            HP and a lifetime; shots and blasts damage them (damage)
--   zones    Lag Field: enemies inside get the ModSpeedMult player attribute
--            (the movement simulation multiplies it in), dummies "Slowed"
-- A Packet has no server part at all: its path is maths (Mods/Blocks/
-- Projectile) and clients draw it from the ModFx event.
--
-- Object attributes (clients colour and label them): Kind, TeamId, OwnerId,
-- Hp, MaxHp, ExpiresAt (workspace:GetServerTimeNow()).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ModTypes = require(Shared.Mods.Types)
local Net = require(Shared.Net)
local Target = require(Shared.Mods.Blocks.Target)
local Teams = require(Shared.Mods.Teams)
local Zone = require(Shared.Mods.Blocks.Zone)

local ModEntities = {}

type Timer = { owner: Player, thread: thread }

type Object = {
	part: BasePart,
	owner: Player,
	kind: string,
	expiresAt: number, -- os.clock()
	hp: number,
}

type ZoneState = {
	owner: Player,
	zone: Zone.Zone,
	untilT: number, -- os.clock()
	slow: number,
}

local timers: { [number]: Timer } = {}
local nextId = 0
local objects: { [BasePart]: Object } = {}
local zones: { ZoneState } = {}
local slowed: { [Instance]: boolean } = {} -- players and dummies currently slowed

-- Where placed Mod objects live. Queryable world parts there block shots
-- like any wall.
function ModEntities.folder(): Folder
	local existing = workspace:FindFirstChild("ModObjects")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = "ModObjects"
	f.Parent = workspace
	return f
end

-- Timers ----------------------------------------------------------------------------

-- Runs `fn` after `delay` seconds, unless `owner` leaves first.
function ModEntities.schedule(owner: Player, delay: number, fn: () -> ()): number
	nextId += 1
	local id = nextId
	local thread = task.delay(delay, function()
		timers[id] = nil
		if owner.Parent == Players then
			fn()
		end
	end)
	timers[id] = { owner = owner, thread = thread }
	return id
end

-- Objects ---------------------------------------------------------------------------

local function remove(obj: Object, why: string)
	if objects[obj.part] ~= obj then
		return
	end
	objects[obj.part] = nil
	Net.event("ModFx"):FireAllClients("ObjectGone", {
		kind = obj.kind,
		at = obj.part.Position,
		size = obj.part.Size,
		why = why,
		team = Teams.of(obj.owner),
	})
	obj.part:Destroy()
end

-- Puts `part` in the world for `owner`. At most `maxActive` of a kind per
-- owner: placing another removes the oldest.
function ModEntities.place(
	owner: Player,
	kind: string,
	part: BasePart,
	life: number,
	hp: number,
	maxActive: number
)
	local mine: { Object } = {}
	for _, obj in objects do
		if obj.owner == owner and obj.kind == kind then
			table.insert(mine, obj)
		end
	end
	table.sort(mine, function(a, b)
		return a.expiresAt < b.expiresAt
	end)
	for i = 1, #mine - math.max(maxActive, 1) + 1 do
		remove(mine[i], "Replaced")
	end
	part.Anchored = true
	part:SetAttribute("Kind", kind)
	part:SetAttribute("TeamId", Teams.of(owner))
	part:SetAttribute("OwnerId", owner.UserId)
	part:SetAttribute("Hp", hp)
	part:SetAttribute("MaxHp", hp)
	part:SetAttribute("ExpiresAt", workspace:GetServerTimeNow() + life)
	part.Parent = ModEntities.folder()
	objects[part] =
		{ part = part, owner = owner, kind = kind, expiresAt = os.clock() + life, hp = hp }
end

-- Is `part` a live Mod object (something shots and blasts can damage)?
function ModEntities.isObject(part: Instance): boolean
	return part:IsA("BasePart") and objects[part] ~= nil
end

-- Damage to a Mod object. Nobody damages their own team's objects. Returns
-- the HP actually taken.
function ModEntities.damage(part: BasePart, amount: number, attacker: Player?): number
	local obj = objects[part]
	if not obj or amount ~= amount or amount <= 0 then
		return 0
	end
	if attacker and Teams.isAlly(attacker, obj.owner) then
		return 0
	end
	local dealt = math.min(amount, obj.hp)
	obj.hp -= dealt
	part:SetAttribute("Hp", math.max(obj.hp, 0))
	if obj.hp <= 0 then
		remove(obj, "Broken")
	end
	return dealt
end

-- Objects whose box is within `radius` of `at`.
function ModEntities.objectsNear(at: Vector3, radius: number): { BasePart }
	local out: { BasePart } = {}
	for part in objects do
		local rel = part.CFrame:PointToObjectSpace(at)
		local half = part.Size / 2
		local closest = Vector3.new(
			math.clamp(rel.X, -half.X, half.X),
			math.clamp(rel.Y, -half.Y, half.Y),
			math.clamp(rel.Z, -half.Z, half.Z)
		)
		if (rel - closest).Magnitude <= radius then
			table.insert(out, part)
		end
	end
	return out
end

-- Zones -----------------------------------------------------------------------------

function ModEntities.addZone(owner: Player, spec: ModTypes.ZoneSpec)
	table.insert(zones, {
		owner = owner,
		zone = { center = spec.center, radius = spec.radius, height = spec.height },
		untilT = os.clock() + spec.duration,
		slow = spec.slow,
	})
end

-- The slow on one combatant from every zone it's in (1 = none).
local function speedFor(model: Model, owner: Player?): number
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return 1
	end
	local mult = 1
	for _, z in zones do
		local victim: Instance = owner or model
		if not Teams.isAlly(z.owner, victim) and Zone.contains(z.zone, root.Position) then
			mult = math.min(mult, 1 - z.slow)
		end
	end
	return mult
end

local function stepZones()
	local now = os.clock()
	for i = #zones, 1, -1 do
		if now >= zones[i].untilT then
			table.remove(zones, i)
		end
	end
	local seen: { [Instance]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local mult = if character and #zones > 0 then speedFor(character, player) else 1
		if player:GetAttribute("ModSpeedMult") ~= mult and (mult < 1 or slowed[player]) then
			player:SetAttribute("ModSpeedMult", if mult < 1 then mult else nil)
		end
		slowed[player] = if mult < 1 then true else nil
		seen[player] = true
	end
	-- Dummies can't be slowed (they're scripted), but they show it.
	if #zones > 0 or next(slowed) then
		for _, model in Target.combatants() do
			if not Players:GetPlayerFromCharacter(model) then
				local isSlowed = #zones > 0 and speedFor(model, nil) < 1
				if isSlowed ~= (slowed[model] == true) then
					model:SetAttribute("Slowed", if isSlowed then true else nil)
				end
				slowed[model] = if isSlowed then true else nil
				seen[model] = true
			end
		end
	end
	for inst in slowed do
		if not seen[inst] then
			slowed[inst] = nil
		end
	end
end

-- Lifecycle -------------------------------------------------------------------------

-- Everything `owner` has in the world goes (objects, zones). `timers` too
-- when they leave (a grenade in flight still goes off after its thrower dies).
function ModEntities.clear(owner: Player, timersToo: boolean?)
	if timersToo then
		for id, t in timers do
			if t.owner == owner then
				timers[id] = nil
				task.cancel(t.thread)
			end
		end
	end
	for _, obj in objects do
		if obj.owner == owner then
			remove(obj, "Expired")
		end
	end
	for i = #zones, 1, -1 do
		if zones[i].owner == owner then
			table.remove(zones, i)
		end
	end
end

local function stepObjects()
	local now = os.clock()
	for _, obj in objects do
		if now >= obj.expiresAt or obj.part.Parent == nil then
			remove(obj, "Expired")
		end
	end
end

function ModEntities.init()
	ModEntities.folder()
end

function ModEntities.start()
	Players.PlayerRemoving:Connect(function(player)
		ModEntities.clear(player, true)
		slowed[player] = nil
	end)
	RunService.Heartbeat:Connect(function()
		stepObjects()
		stepZones()
	end)
end

return ModEntities
