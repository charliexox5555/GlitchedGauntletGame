--!strict
-- A tiny generic pool for Mod effects (roblox-performance): instances are
-- built once by `make`, handed out by acquire() and parked (not destroyed) by
-- release(). Parked parts move far away and go transparent; anything else is
-- just unparented.
--
--   local spheres = VfxPool.new(function() return Instance.new("Part") end, folder, 4)
--   local p = spheres:acquire() ... spheres:release(p)

export type Pool<T> = {
	make: () -> T,
	parent: Instance,
	free: { T },
	acquire: (self: Pool<T>) -> T,
	release: (self: Pool<T>, item: T) -> (),
}

local PARK = CFrame.new(0, -10000, 0)

local VfxPool = {}

local function acquire<T>(self: Pool<T>): T
	local item = table.remove(self.free)
	if item == nil then
		item = self.make()
	end
	local inst = (item :: any) :: Instance
	if not inst:IsA("BasePart") then
		inst.Parent = self.parent
	end
	return item :: T
end

local function release<T>(self: Pool<T>, item: T)
	local inst = (item :: any) :: Instance
	if inst:IsA("BasePart") then
		inst.CFrame = PARK
		inst.Transparency = 1
	else
		inst.Parent = nil
	end
	table.insert(self.free, item)
end

function VfxPool.new<T>(make: () -> T, parent: Instance, prewarm: number?): Pool<T>
	local pool: Pool<T> = {
		make = make,
		parent = parent,
		free = {},
		acquire = acquire,
		release = release,
	}
	for _ = 1, prewarm or 0 do
		local item = make()
		pool:release(item)
	end
	return pool
end

return VfxPool
