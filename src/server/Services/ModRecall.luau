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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Recall = require(ReplicatedStorage:WaitForChild("Shared").Mods.Recall)

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

-- The key with an anchor down: wind up, then appear on it.
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
		hooks.spend()
		local from = bodyRoot.Position
		local to = floor + Vector3.new(0, humanoid.HipHeight + bodyRoot.Size.Y / 2 + 0.05, 0)
		player:SetAttribute("RecallTo", to)
		local serial = player:GetAttribute("RecallSerial")
		player:SetAttribute("RecallSerial", (if typeof(serial) == "number" then serial else 0) + 1)
		ModEntities.remove(anchor.part, "Used")
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

function ModRecall.start()
	Players.PlayerRemoving:Connect(function(player)
		anchors[player] = nil
		windups[player] = nil
	end)
end

return ModRecall
