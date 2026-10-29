--!strict
-- Recall (Escape, Anchor; was Rollback; vault/01 Design/Abilities/Recall.md):
-- Chamber's Rendezvous. Two steps on one key:
--   1. No anchor: the key holds the anchor (HeldPlace, Blocks/Placeable: a
--      spot on walkable ground within `placeRange` where you look); LMB
--      plants it. Planting costs nothing: the charge is the teleport.
--   2. Anchor down: the key asks the server to teleport (ModRecall: within
--      `range`, a `windup` with no shooting, then you appear on it). The
--      anchor stays: the next teleport waits for the `cooldown` (Chamber's
--      Rendezvous). Holding the key `pickupHold` s within `pickupRange`
--      picks it back up instead (any time, even on cooldown).
-- The anchor is a Mod object (ModEntities) that `hp` bullet hits destroy:
-- then the teleport goes on its full cooldown, and you plant again after.
-- One anchor at a time; a spot needs room for you to arrive (roomAt).
-- Its owner sees the `range` as a ring on the floor (ModController).
--
-- The move itself runs in the simulation (step, called by
-- Simulation/Abilities every step), like Dash: the server publishes the
-- destination as player attributes, written by ModRecall outside the
-- simulation:
--   RecallTo       where the root goes (Vector3)
--   RecallSerial   bumped for each teleport
-- and the simulation writes on the character:
--   RecallSeen     the last RecallSerial applied (a new character starts
--                  from the current one: no teleport carried into a new life)
--   RecallAt       time() of the last arrival (the client's arrival feel)

local Placeable = require(script.Parent.Blocks.Placeable)
local Types = require(script.Parent.Types)

local Recall = {}

function Recall.size(stats: Types.Stats): Vector3
	return Vector3.new(stats.size, stats.height, stats.size)
end

-- Room for a body standing on `floor` (you arrive there): nothing solid in
-- a `roomWidth` x `roomHeight` box above it. Bodies don't count.
function Recall.roomAt(floor: Vector3, stats: Types.Stats, overlap: OverlapParams?): boolean
	local w: number = stats.roomWidth
	local h: number = stats.roomHeight
	local box = CFrame.new(floor + Vector3.new(0, h / 2 + 0.15, 0))
	local inside =
		workspace:GetPartBoundsInBox(box, Vector3.new(w, h, w), overlap or Placeable.overlap(false))
	for _, part in inside do
		if part.CanCollide then
			return false
		end
	end
	return true
end

function Recall.find(
	head: Vector3,
	aim: Vector3,
	stats: Types.Stats,
	params: RaycastParams,
	overlap: OverlapParams?
): Placeable.Spot
	local o = overlap or Placeable.overlap(false)
	local spot = Placeable.find(head, aim, stats.placeRange, Recall.size(stats), params, o)
	if spot.valid then
		local floor = spot.cframe.Position - Vector3.new(0, stats.height / 2 + 0.05, 0)
		if not Recall.roomAt(floor, stats, o) then
			return { cframe = spot.cframe, valid = false, reason = "No room to stand there" }
		end
	end
	return spot
end

-- Inside the simulation, every step: a teleport the server published.
function Recall.step(player: Player, character: Model, root: BasePart, now: number)
	local published = player:GetAttribute("RecallSerial")
	local serial = if typeof(published) == "number" then published else 0
	local seen = character:GetAttribute("RecallSeen")
	if seen == serial then
		return
	end
	character:SetAttribute("RecallSeen", serial)
	if typeof(seen) ~= "number" then
		return -- a new character: what came before isn't for it
	end
	local to = player:GetAttribute("RecallTo")
	if typeof(to) ~= "Vector3" then
		return
	end
	-- Keep the facing: only the position changes.
	local rotation = root.CFrame - root.CFrame.Position
	character:PivotTo(CFrame.new(to) * rotation)
	root.AssemblyLinearVelocity = Vector3.zero
	character:SetAttribute("RecallAt", now)
end

local module: Types.ModModule = {}

module.validate = function(ctx: Types.ServerCtx, req: Types.Request): (boolean, string?)
	if req.mode ~= "Primary" then
		return false, "bad mode"
	end
	if ctx.anchorDown then
		return false, "Anchor already planted" -- pick it up first (ModRecall)
	end
	local spot = Recall.find(ctx.head.Position, req.direction, ctx.stats, ctx.worldParams())
	if not spot.valid then
		return false, spot.reason
	end
	req.placement = spot.cframe
	return true
end

-- Planting is free: the charge is spent by the teleport (ModRecall).
module.spends = function(_ctx: Types.ServerCtx, _req: Types.Request): boolean
	return false
end

module.apply = function(ctx: Types.ServerCtx, req: Types.Request)
	local stats = ctx.stats
	local placement = req.placement
	if not placement then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Name = "Recall"
	anchor.Size = Recall.size(stats)
	anchor.CFrame = placement
	anchor.Transparency = 1 -- clients dress it with the finished model
	anchor.CanCollide = false
	anchor.CanQuery = true -- shootable (WeaponService hits on Mod objects)
	anchor.CanTouch = false
	anchor:SetAttribute("CountsHits", true) -- `hp` is hits, whatever the gun
	ctx.place("Recall", anchor, stats.life, stats.hp, 1)
	if not anchor.Parent then
		return -- the caster died first
	end
	ctx.anchor(anchor)
	ctx.fx("RecallPlaced", { at = anchor.Position })
end

Recall.module = module

return Recall
