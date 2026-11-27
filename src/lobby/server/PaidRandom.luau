--!strict
-- Is a paid random item (a case or pack bought with Robux, or with coins, which are sold for Robux) allowed
-- for this player? PolicyService's ArePaidRandomItemsRestricted, server-side, failing closed. LihFolk: Paid
-- Random Items and Odds Disclosure; vault/01 Design/Shop Economy and Art v1.md.
-- Returns (answered, allowed): answered = false when the policy call failed (a request treats that as not
-- allowed; a receipt waits and Roblox sends it again).

local PolicyService = game:GetService("PolicyService")

local PaidRandom = {}

function PaidRandom.check(player: Player): (boolean, boolean)
	local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	if not ok or typeof(info) ~= "table" then
		return false, false
	end
	return true, (info :: any).ArePaidRandomItemsRestricted == false
end

return PaidRandom
