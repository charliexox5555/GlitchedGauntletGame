--!strict
-- Recall's server half (Mods/Recall, vault/01 Design/Abilities/Recall.md):
-- each player's planted anchor, the teleport wind-up and the pick-up.
-- ModService owns the slot, the charge and the remote checks; it hands the
-- teleport and the pick-up here with its hooks (spend the charge, refuse,
-- tell everyone).
--
-- Attributes:
--   player RecallAnchor        the anchor's position while it stands (the
--                              client's range checks; anyone may read it,
--                              the anchor is in plain sight anyway)
--   character RecallWindupUntil  server time the wind-up ends (everyone draws
--                              the shimmer; WeaponService takes no shots)
--   player RecallTo / RecallSerial   the teleport, applied by the simulation
--                              (Mods/Recall.step)
--   player RecallCrashUsed     Crash Recovery (glitch path) is spent this
--                              round (the owner's "armed" read goes)
--
-- Crash Recovery (G2 / G3, vault/01 Design/Abilities/Upgrade Paths.md → 9.
-- Recall): a damage guard (bound into Mods/Recall's server hook at the end
-- of this file). Once a round, the hit that would kill you while you stand
-- within `range` of your anchor (still up, with room to arrive) is blocked:
-- you're set to `rescueHealth` and teleported onto the anchor at once (no
-- wind-up), and the anchor breaks ("Crashed": no charge lost, plant again).
-- Nothing lands for `rescueGrace` s after (the trip, shots already fired at
-- where you were). Each round start re-arms it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared.Config.Combat)
local Mods = require(Shared.Mods)
local ModTypes = require(Shared.Mods.Types)
local Recall = require(Shared.Mods.Recall)
local Teams = require(Shared.Mods.Teams)

local ModEntities = require(script.Parent.ModEntities)
local WeaponService = require(script.Parent.WeaponService)

local ModRecall = {}

local RANGE_SLACK = 2 -- studs on top of the range (the client saw an older position)

export type Hooks = {
	ready: () -> boolean, -- a charge to spend (or test mode)
	spend: () -> (),
	deny: (reason: string) -> (),
	fx: (kind: string, data: { [string]: any }) -> (),
	pose: (kind: string) -> (), -- the third-person clip (ModUseKind)
}

type Anchor = { part: BasePart, slot: number }
local anchors: { [Player]: Anchor } = {}

type Windup = { token: number, character: Model, slot: number }
local windups: { [Player]: Windup } = {}
local nextToken = 0

-- Crash Recovery: spent this round, and the grace after a rescue (server time).
local crashUsed: { [Player]: boolean } = {}
local graceUntil: { [Player]: number } = {}

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function liveHumanoid(model: Model?): Humanoid?
	local h = model and model:FindFirstChildOfClass("Humanoid")
	return if h and h.Health > 0 then h else nil
end

-- The anchor `player` planted, while it stands.
function ModRecall.anchor(player: Player): Anchor?
	local a = anchors[player]
	if a and a.part.Parent then
		return a
	end
	return nil
end

-- The anchor just planted (Mods/Recall.apply through ctx.anchor). `lost`
-- spends the slot's charge: enemies breaking it lose you the teleport.
function ModRecall.track(player: Player, slot: number, part: BasePart, lost: () -> ())
	anchors[player] = { part = part, slot = slot }
	player:SetAttribute("RecallAnchor", part.Position)
	part.AncestryChanged:Connect(function()
		if part.Parent then
			return
		end
		local a = anchors[player]
		if a and a.part == part then
			anchors[player] = nil
			player:SetAttribute("RecallAnchor", nil)
			if part:GetAttribute("RemovedWhy") == "Broken" then
				lost()
			end
		end
	end)
end

local function floorOf(part: BasePart): Vector3
	return part.Position - Vector3.new(0, part.Size.Y / 2, 0)
end

-- Where the root goes to stand on `floor`.
local function standAt(floor: Vector3, humanoid: Humanoid, root: BasePart): Vector3
	return floor + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2 + 0.05, 0)
end

-- The teleport itself: the simulation applies it (Mods/Recall.step).
local function publish(player: Player, to: Vector3)
	player:SetAttribute("RecallTo", to)
	local serial = player:GetAttribute("RecallSerial")
	player:SetAttribute("RecallSerial", (if typeof(serial) == "number" then serial else 0) + 1)
end

function ModRecall.isWinding(player: Player): boolean
	return windups[player] ~= nil
end

-- Ends a wind-up without teleporting (death, a new character).
function ModRecall.cancel(player: Player)
	local w = windups[player]
	if not w then
		return
	end
	windups[player] = nil
	if w.character.Parent then
		w.character:SetAttribute("RecallWindupUntil", nil)
	end
end

-- The key with an anchor down: wind up, then appear on it. The anchor
-- stays: the next teleport waits for the slot's cooldown.
function ModRecall.teleport(player: Player, slot: number, stats: { [string]: any }, hooks: Hooks)
	if windups[player] then
		return -- already winding up
	end
	local a = ModRecall.anchor(player)
	if not a or a.slot ~= slot then
		hooks.deny("No anchor")
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not liveHumanoid(character) or not root or not root:IsA("BasePart") then
		hooks.deny("dead")
		return
	end
	if (root.Position - a.part.Position).Magnitude > stats.range + RANGE_SLACK then
		hooks.deny("Out of range")
		return
	end
	if not Recall.roomAt(floorOf(a.part), stats) then
		hooks.deny("No room at the anchor")
		return
	end
	if not hooks.ready() then
		hooks.deny("not ready")
		return
	end
	nextToken += 1
	local token = nextToken
	local body: Model = character
	windups[player] = { token = token, character = body, slot = slot }
	body:SetAttribute("RecallWindupUntil", serverNow() + stats.windup)
	-- No shots during the wind-up (the gun stays up: you arrive ready).
	WeaponService.setHolstered(player, false, stats.windup)
	hooks.pose("Cast")
	hooks.fx("RecallWindup", { at = root.Position, duration = stats.windup })
	task.delay(stats.windup, function()
		local w = windups[player]
		if not w or w.token ~= token then
			return -- cancelled
		end
		windups[player] = nil
		if body.Parent then
			body:SetAttribute("RecallWindupUntil", nil)
		end
		local humanoid = liveHumanoid(body)
		local anchor = ModRecall.anchor(player)
		local bodyRoot = body:FindFirstChild("HumanoidRootPart")
		if
			player.Parent ~= Players
			or player.Character ~= body
			or not humanoid
			or not bodyRoot
			or not bodyRoot:IsA("BasePart")
		then
			return
		end
		if not anchor then
			hooks.deny("Anchor destroyed") -- the charge went with it (track)
			return
		end
		local floor = floorOf(anchor.part)
		if not Recall.roomAt(floor, stats) then
			hooks.deny("No room at the anchor") -- nothing spent, the anchor stays
			return
		end
		hooks.spend() -- the cooldown starts; the anchor stays for the next one
		local from = bodyRoot.Position
		publish(player, standAt(floor, humanoid, bodyRoot))
		hooks.fx("RecallArrive", { from = from, at = floor })
	end)
end

-- Holding the key next to the anchor: it comes back to you (plant it again).
function ModRecall.pickUp(player: Player, slot: number, stats: { [string]: any }, hooks: Hooks)
	if windups[player] then
		return
	end
	local a = ModRecall.anchor(player)
	if not a or a.slot ~= slot then
		hooks.deny("No anchor")
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or not liveHumanoid(player.Character) then
		hooks.deny("dead")
		return
	end
	if (root.Position - a.part.Position).Magnitude > stats.pickupRange + RANGE_SLACK then
		hooks.deny("Too far to pick up")
		return
	end
	local at = a.part.Position
	ModEntities.remove(a.part, "PickedUp")
	hooks.fx("RecallPickedUp", { at = at })
end

-- Crash Recovery ------------------------------------------------------------------

-- The rescue (from the damage guard, inside the hit: nothing here yields).
-- Within `range` of a standing anchor with room on it: `rescueHealth`, a
-- wind-up in progress cancelled, the teleport published at once, then
-- (deferred) the anchor breaks and everyone gets RecallCrash. False: no
-- rescue (out of range, no anchor, no room), the hit lands.
function ModRecall.rescue(
	player: Player,
	stats: { [string]: any },
	fx: (kind: string, data: { [string]: any }) -> ()
): boolean
	local a = ModRecall.anchor(player)
	local character = player.Character
	local humanoid = liveHumanoid(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not a or not humanoid or not root or not root:IsA("BasePart") then
		return false
	end
	if (root.Position - a.part.Position).Magnitude > stats.range then
		return false -- the server's own positions: no slack
	end
	local floor = floorOf(a.part)
	if not Recall.roomAt(floor, stats) then
		return false
	end
	crashUsed[player] = true
	player:SetAttribute("RecallCrashUsed", true)
	graceUntil[player] = serverNow() + stats.rescueGrace
	if windups[player] then
		ModRecall.cancel(player)
		-- Lift what's left of the wind-up's no-shots: you arrive ready.
		WeaponService.setHolstered(player, false, 0.01)
	end
	local health = math.clamp(stats.rescueHealth, 1, humanoid.MaxHealth)
	humanoid.Health = health
	if typeof(humanoid:GetAttribute(Combat.SHIELD_ATTRIBUTE)) == "number" then
		humanoid:SetAttribute(Combat.SHIELD_ATTRIBUTE, 0) -- the hit took it all
	end
	local from = root.CFrame
	publish(player, standAt(floor, humanoid, root))
	local part = a.part
	task.defer(function()
		ModEntities.remove(part, "Crashed") -- not "Broken": no charge lost
		fx("RecallCrash", { from = from, at = floor, health = health })
	end)
	return true
end

-- The damage guard: cheap until the victim is a player with Crash Recovery
-- armed and the hit would kill them (health + gun shield, as hurt takes it).
local function crashGuard(api: ModTypes.ServerApi)
	return function(victim: Model, humanoid: Humanoid, amount: number, attacker: Player?): number
		local player = Players:GetPlayerFromCharacter(victim)
		if not player then
			return amount
		end
		-- Your own and your team's damage never trigger it (a Molly at your
		-- feet would make it an escape button), like the Barrier.
		if attacker and (attacker == player or Teams.isAlly(attacker, player)) then
			return amount
		end
		local grace = graceUntil[player]
		if grace and serverNow() < grace then
			return 0
		end
		if crashUsed[player] or humanoid.Health <= 0 then
			return amount
		end
		local _, level = api.slotOf(player, "Recall")
		local stats = level and Mods.stats("Recall", level)
		if not stats or stats.behaviour ~= "Crash" then
			return amount
		end
		local shield = humanoid:GetAttribute(Combat.SHIELD_ATTRIBUTE)
		local cover = humanoid.Health
			+ (if typeof(shield) == "number" then math.max(shield, 0) else 0)
		if amount < cover then
			return amount
		end
		local rescued = ModRecall.rescue(
			player,
			stats,
			function(kind: string, data: { [string]: any })
				api.fx(player, "Recall", kind, data)
			end
		)
		return if rescued then 0 else amount
	end
end

local function rearm(player: Player)
	crashUsed[player] = nil
	graceUntil[player] = nil
	if player.Parent then
		player:SetAttribute("RecallCrashUsed", nil)
	end
end

-- Mods/Recall's server hook (run once by ModService.start, in Config/Mods
-- ORDER: Heal Orb's Barrier guard comes first, so a hit it takes never
-- reaches this one).
Recall.bindServer(function(api: ModTypes.ServerApi)
	api.guard(crashGuard(api))
	api.onRefill(rearm)
end)

function ModRecall.start()
	Players.PlayerRemoving:Connect(function(player)
		anchors[player] = nil
		windups[player] = nil
		crashUsed[player] = nil
		graceUntil[player] = nil
	end)
end

return ModRecall
