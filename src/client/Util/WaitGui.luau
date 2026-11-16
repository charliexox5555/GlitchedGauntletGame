--!strict
-- Waits for a screen's StarterGui copy to land in PlayerGui, with no timeout
-- and no "infinite yield" warning. StarterGui only copies on a spawn, and the
-- map vote (plus slow arrivals) can hold the first spawn past
-- WaitForChild's 30 s, which used to leave a screen unbound for the match
-- (vault/02 Art/UI Match Overhaul.md).
--
-- One ChildAdded connection, not a `:Wait()` loop: StarterGui copies every
-- screen in the same frame, and with deferred events a loop that re-waits
-- misses the ones that fired while it was busy.
--
--   local gui = WaitGui("BottomHud")  -- yields until it exists

local Players = game:GetService("Players")

return function(name: string): Instance
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local found = playerGui:FindFirstChild(name)
	if found then
		return found
	end
	local thread = coroutine.running()
	local done = false
	local conn: RBXScriptConnection
	conn = playerGui.ChildAdded:Connect(function(child)
		if not done and child.Name == name then
			done = true
			conn:Disconnect()
			task.spawn(thread, child)
		end
	end)
	return coroutine.yield()
end
