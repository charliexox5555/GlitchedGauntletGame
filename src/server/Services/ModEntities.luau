--!strict
-- Server-owned Mod things that outlive the request that made them: timers
-- (a Packet's fuse) now, and later the world objects (pads, walls, zones in
-- workspace.ModObjects, with HP and lifetime). Everything is tracked by owner,
-- so it all goes away when the owner leaves.
--
-- A Packet has no server part at all: its path is maths (Mods/Blocks/
-- Projectile) and clients draw it from the ModFx event.

local Players = game:GetService("Players")

local ModEntities = {}

type Timer = { owner: Player, thread: thread }

local timers: { [number]: Timer } = {}
local nextId = 0

-- Where placed Mod objects live (pads, walls). Queryable world parts there
-- block shots like any wall; LOS checks for Mods skip the folder.
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

-- Cancels everything `owner` has pending.
function ModEntities.clear(owner: Player)
	for id, t in timers do
		if t.owner == owner then
			timers[id] = nil
			task.cancel(t.thread)
		end
	end
end

function ModEntities.init()
	ModEntities.folder()
end

function ModEntities.start()
	Players.PlayerRemoving:Connect(ModEntities.clear)
end

return ModEntities
