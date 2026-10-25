--!strict
-- Remembers where every combatant's root was over the last second, so the
-- server can accept a client's hit on a target that has since moved (lag),
-- without accepting hits on spots the target never was.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)

type Sample = { t: number, cf: CFrame }
type Record = { root: BasePart, samples: { Sample } }

local HitboxHistory = {}

local records: { [Model]: Record } = {}
local heartbeat: RBXScriptConnection? = nil

function HitboxHistory.track(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		records[model] = { root = root, samples = {} }
	end
end

function HitboxHistory.untrack(model: Model)
	records[model] = nil
end

function HitboxHistory.isTracked(model: Model): boolean
	return records[model] ~= nil
end

-- True if `position` lies on `part` (a descendant of `model`) now or at some
-- moment in the recorded history, within `tolerance` studs.
function HitboxHistory.plausible(
	model: Model,
	part: BasePart,
	position: Vector3,
	tolerance: number
): boolean
	local record = records[model]
	if not record or not record.root.Parent then
		return false
	end
	local radius = part.Size.Magnitude / 2 + tolerance
	if (part.Position - position).Magnitude <= radius then
		return true
	end
	local offset = record.root.CFrame:ToObjectSpace(part.CFrame)
	for _, s in record.samples do
		if ((s.cf * offset).Position - position).Magnitude <= radius then
			return true
		end
	end
	return false
end

function HitboxHistory.start()
	if heartbeat then
		heartbeat:Disconnect()
	end
	heartbeat = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local cutoff = now - Combat.HISTORY_SECONDS
		for model, record in records do
			if not model.Parent or not record.root.Parent then
				records[model] = nil
				continue
			end
			local samples = record.samples
			table.insert(samples, { t = now, cf = record.root.CFrame })
			while #samples > 0 and samples[1].t < cutoff do
				table.remove(samples, 1)
			end
		end
	end)
end

return HitboxHistory
