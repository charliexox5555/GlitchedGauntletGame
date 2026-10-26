--!strict
-- Rollback (Escape, Rewind): instant and predicted. Simulation/Abilities
-- keeps a few seconds of root CFrames per character (Blocks/Rewind, trimmed on
-- every Server Authority rollback); the cast snaps you back to where you were
-- `rewind` seconds ago and stops you. The server then restores the ammo you
-- had then (ModService sees RollbackAt change → WeaponService.rewindAmmo).
--
-- Character attributes (simulation-written):
--   RollbackAt    time() of the last rewind (the client plays the VHS effect)
--   RollbackFrom  where you were just before it

local Rewind = require(script.Parent.Blocks.Rewind)
local Types = require(script.Parent.Types)

local Rollback = {}

-- Seconds of history kept (the longest rewind any level needs, plus slack).
Rollback.KEEP = 4
local ROOM = Vector3.new(2, 5, 1.5) -- a character's box at the old spot

-- Per character, inside the simulation. Weak keys: gone with the character.
local histories: { [Model]: Rewind.History } = setmetatable({}, { __mode = "k" }) :: any

-- Called every simulation step for characters that have Rollback slotted.
function Rollback.record(character: Model, root: BasePart, now: number)
	local h = histories[character]
	if not h then
		h = Rewind.new()
		histories[character] = h
	end
	Rewind.push(h, now, root.CFrame, Rollback.KEEP)
end

-- RunService.Rollback: forget the steps that are about to be run again.
function Rollback.onRollback(t: number)
	for _, h in histories do
		Rewind.trimAfter(h, t)
	end
end

local module: Types.ModModule = {}

module.simCast = function(ctx: Types.SimCtx): boolean
	local h = histories[ctx.character]
	if not h then
		return false
	end
	local past = Rewind.sample(h, ctx.now - ctx.stats.rewind)
	if not past then
		return false
	end
	local root = ctx.root
	local objects = workspace:FindFirstChild("ModObjects")
	if objects then
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Include
		overlap.FilterDescendantsInstances = { objects }
		if #workspace:GetPartBoundsInBox(CFrame.new(past.Position), ROOM, overlap) > 0 then
			return false -- something stands there now: no rewind, no charge spent
		end
	end
	local from = root.Position
	-- Keep the current facing: only the position goes back.
	local rotation = root.CFrame - root.CFrame.Position
	ctx.character:PivotTo(CFrame.new(past.Position) * rotation)
	root.AssemblyLinearVelocity = Vector3.zero
	ctx.character:SetAttribute("RollbackAt", ctx.now)
	ctx.character:SetAttribute("RollbackFrom", from)
	return true
end

Rollback.module = module

return Rollback
