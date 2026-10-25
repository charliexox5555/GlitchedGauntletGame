--!strict
-- Remembers where every combatant's root was over the last second, so the
-- server can accept a client's hit on a target that has since moved (lag),
-- without accepting hits on spots the target never was.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)

-- Fixed-size ring buffer of root CFrames per combatant (no per-frame allocation).
local CAPACITY = 90 -- > 1 s at 60 Hz

type Record = {
	root: BasePart,
	times: { number },
	frames: { CFrame },
	head: number, -- index of the newest sample
	count: number,
}

local HitboxHistory = {}

local records: { [Model]: Record } = {}
local heartbeat: RBXScriptConnection? = nil

function HitboxHistory.track(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		records[model] = {
			root = root,
			times = table.create(CAPACITY, 0),
			frames = table.create(CAPACITY, CFrame.identity),
			head = 0,
			count = 0,
		}
	end
end

function HitboxHistory.untrack(model: Model)
	records[model] = nil
end

function HitboxHistory.isTracked(model: Model): boolean
	return records[model] ~= nil
end

-- Where `part` (of `model`) was, at the moment within the last `maxAge`
-- seconds when it was closest to `position`. Returns that rewound centre if
-- `position` lies on the part (within `tolerance`), otherwise nil.
function HitboxHistory.rewind(
	model: Model,
	part: BasePart,
	position: Vector3,
	tolerance: number,
	maxAge: number
): Vector3?
	local record = records[model]
	if not record or not record.root.Parent then
		return nil
	end
	local radius = part.Size.Magnitude / 2 + tolerance
	local best: Vector3? = nil
	local bestDist = math.huge
	local current = part.Position
	local d = (current - position).Magnitude
	if d <= radius then
		best, bestDist = current, d
	end
	local offset = record.root.CFrame:ToObjectSpace(part.CFrame)
	local cutoff = os.clock() - maxAge
	local index = record.head
	for _ = 1, record.count do
		if record.times[index] < cutoff then
			break
		end
		local center = (record.frames[index] * offset).Position
		local dist = (center - position).Magnitude
		if dist <= radius and dist < bestDist then
			best, bestDist = center, dist
		end
		index -= 1
		if index < 1 then
			index = CAPACITY
		end
	end
	return best
end

function HitboxHistory.start()
	if heartbeat then
		heartbeat:Disconnect()
	end
	heartbeat = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for model, record in records do
			if not model.Parent or not record.root.Parent then
				records[model] = nil
				continue
			end
			local i = record.head % CAPACITY + 1
			record.head = i
			record.times[i] = now
			record.frames[i] = record.root.CFrame
			record.count = math.min(record.count + 1, CAPACITY)
		end
	end)
end

-- Kept for tooling: true if `position` is on `part` now or within the last second.
function HitboxHistory.plausible(
	model: Model,
	part: BasePart,
	position: Vector3,
	tolerance: number
): boolean
	return HitboxHistory.rewind(model, part, position, tolerance, Combat.HISTORY_SECONDS) ~= nil
end

return HitboxHistory
