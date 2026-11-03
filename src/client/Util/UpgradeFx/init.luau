--!strict
-- The upgrade levels' client effects (vault/01 Design/Abilities/Upgrade
-- Paths.md), one module per ability so each can be worked on alone.
-- ModFxController calls start / onFx / step; each module is a Types.Handler.

local Types = require(script.Types)

local UpgradeFx = {}

local warned: { [Types.Handler]: boolean } = {}

local handlers: { Types.Handler } = {
	require(script.Dash),
	require(script.Updraft),
	require(script.Molly),
	require(script.Firewall),
	require(script.Frost),
	require(script.Recon),
	require(script.HealOrb),
	require(script.Stim),
	require(script.Recall),
}

function UpgradeFx.start()
	for _, h in handlers do
		local fn = h.start
		if fn then
			task.spawn(fn)
		end
	end
end

-- True when a handler took care of the event.
function UpgradeFx.onFx(kind: string, data: { [string]: any }): boolean
	for _, h in handlers do
		local fn = h.onFx
		if fn then
			local ok, handled = pcall(fn, kind, data)
			if not ok then
				warn("[UpgradeFx] onFx failed:", handled)
			elseif handled then
				return true
			end
		end
	end
	return false
end

-- One handler failing mustn't stop ModFxController's frame (reveal
-- highlights would never be cleared): each runs on its own, warned once.
function UpgradeFx.step(dt: number)
	for _, h in handlers do
		local fn = h.step
		if fn then
			local ok, err = pcall(fn, dt)
			if not ok and not warned[h] then
				warned[h] = true
				warn("[UpgradeFx] step failed:", err)
			end
		end
	end
end

return UpgradeFx
