--!strict
-- Shared by predicted bullet rays and authoritative gunfire. Movement,
-- melee, and camera-origin validation use ordinary collision with intact panes.

local CollectionService = game:GetService("CollectionService")

local BallisticGlass = {}
BallisticGlass.TAG = "BreakableMapGlass"

function BallisticGlass.raycast(
	origin: Vector3,
	direction: Vector3,
	params: RaycastParams,
	onPane: ((BasePart, Vector3, Vector3) -> ())?
): RaycastResult?
	local result = workspace:Raycast(origin, direction, params)
	-- A separate limit keeps panes from spending the wall/character trace budget.
	for _ = 1, 12 do
		if not result then
			return nil
		end
		local part = result.Instance
		if not part:IsA("BasePart") or not CollectionService:HasTag(part, BallisticGlass.TAG) then
			return result
		end
		if onPane then
			onPane(part, result.Position, result.Normal)
		end
		params:AddToFilter(part)
		result = workspace:Raycast(origin, direction, params)
	end
	return result
end

return BallisticGlass
