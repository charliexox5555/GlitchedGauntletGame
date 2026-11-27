--!strict
-- Waits for a part of a Studio-built screen or template, with a timeout (code audit 2026-11-27: a renamed or
-- missing Studio child hung its screen forever on `WaitForChild` with no timeout). On a timeout it raises a clear
-- error naming the missing path; callers bind their screen inside `pcall` and turn that one screen off.
--
--   local UiWait = require(ReplicatedStorage.Shared.Util.UiWait)
--   local band = UiWait.child(root, "Band") :: CanvasGroup
--   local ok, err = pcall(bind) -- on failure: warn and leave the screen off

local UiWait = {}

UiWait.TIMEOUT = 10 -- s: a screen copied in from PlayerScripts or ReplicatedStorage is complete well before this

function UiWait.child(parent: Instance, name: string, timeout: number?): any
	local found = parent:WaitForChild(name, timeout or UiWait.TIMEOUT)
	if not found then
		error(`[UI] {parent:GetFullName()}.{name} is missing (Studio template)`, 2)
	end
	return found
end

-- Runs `bind` protected: on a missing part it warns once and returns nil, so the caller leaves its screen off.
function UiWait.try<T>(label: string, bind: () -> T): T?
	local ok, result = pcall(bind)
	if not ok then
		warn(`[UI] {label} not available: {result}`)
		return nil
	end
	return result
end

return UiWait
