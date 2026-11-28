--!strict
-- Smoke building block (Mods/Smoke, vault/01 Design/Abilities/Smoke.md): the smoke domes that stand in the world
-- and the one question everyone asks of them, "does smoke block the line from A to B?". The server makes each dome
-- an invisible, non-colliding, non-queryable part in workspace.ModSmokes (bullets and players pass through) with
-- the state clients and bots read:
--   SmokeAt (server time it popped), SmokeRadius, SmokeLife (s), SmokeGrow (s), SmokeFade (s), TeamId, OwnerId
-- Bots (Bots/Perception), aim assist and auto shoot (AimAssistController) and the client look (Util/SmokeFx) all
-- read the same parts, so what blocks sight is the same for everyone. A dome is a sphere centred on the floor
-- point (its top half is the dome you see).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local StateValues = require(ReplicatedStorage.Shared.StateValues)

local Smoke = {}

Smoke.FOLDER = "ModSmokes"
local CLEAR_AT_END = 0.4 -- s before the end the thinning smoke stops blocking
local EDGE = 0.92 -- share of the radius that blocks (the wispy rim doesn't)

local function num(part: Instance, name: string): number?
	local v = StateValues.get(part, name)
	return if typeof(v) == "number" and v == v then v else nil
end

function Smoke.folder(): Folder?
	local f = Workspace:FindFirstChild(Smoke.FOLDER)
	return if f and f:IsA("Folder") then f else nil
end

-- A dome's numbers never change after it pops: read once (StateValues decode) and kept per part.
type Info = { at: number, radius: number, life: number, grow: number, fade: number }
local infos: { [Instance]: Info | false } = setmetatable({}, { __mode = "k" }) :: any

function Smoke.info(part: Instance): Info?
	local known = infos[part]
	if known ~= nil then
		return if known then known else nil
	end
	local at, radius, life = num(part, "SmokeAt"), num(part, "SmokeRadius"), num(part, "SmokeLife")
	if not (at and radius and life) then
		return nil -- not replicated yet: ask again next time
	end
	local info: Info = {
		at = at,
		radius = radius,
		life = life,
		grow = num(part, "SmokeGrow") or 0,
		fade = num(part, "SmokeFade") or 0,
	}
	infos[part] = info
	return info
end

-- The blocking radius of one dome at server time `now` (0 before it pops, while it's gone, or for a non-dome).
function Smoke.radiusAt(part: Instance, now: number): number
	local info = Smoke.info(part)
	if not info then
		return 0
	end
	local age = now - info.at
	if age < 0 or age > info.life - CLEAR_AT_END then
		return 0
	end
	local radius, grow = info.radius, info.grow
	local share = if grow > 0 then math.clamp(age / grow, 0, 1) else 1
	return radius * share
end

-- The dome's centre (the floor point).
function Smoke.centerOf(part: BasePart): Vector3
	return part.Position
end

-- Does any smoke stand between `from` and `to`? A line that starts or ends inside a dome counts.
function Smoke.blocks(from: Vector3, to: Vector3, now: number?): boolean
	local folder = Smoke.folder()
	if not folder then
		return false
	end
	local t = now or Workspace:GetServerTimeNow()
	local seg = to - from
	local len2 = seg:Dot(seg)
	for _, part in folder:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end
		local r = Smoke.radiusAt(part, t) * EDGE
		if r <= 0 then
			continue
		end
		local c = part.Position
		local u = if len2 > 1e-6 then math.clamp((c - from):Dot(seg) / len2, 0, 1) else 0
		local closest = from + seg * u
		if (closest - c).Magnitude <= r then
			return true
		end
	end
	return false
end

-- Is `point` inside a standing dome?
function Smoke.inside(point: Vector3, now: number?): Instance?
	local folder = Smoke.folder()
	if not folder then
		return nil
	end
	local t = now or Workspace:GetServerTimeNow()
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") then
			local r = Smoke.radiusAt(part, t)
			if r > 0 and (point - part.Position).Magnitude <= r then
				return part
			end
		end
	end
	return nil
end

-- Server: puts a dome on the floor at `at`, gone `life` + 0.5 s later.
function Smoke.spawn(
	at: Vector3,
	radius: number,
	life: number,
	grow: number,
	fade: number,
	teamId: number?,
	ownerId: number
): BasePart
	local folder = Smoke.folder()
	if not folder then
		local f = Instance.new("Folder")
		f.Name = Smoke.FOLDER
		f.Parent = Workspace
		folder = f
	end
	local part = Instance.new("Part")
	part.Name = "Smoke"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.CastShadow = false
	part.Size = Vector3.one * 0.2
	part.CFrame = CFrame.new(at)
	StateValues.set(part, "SmokeAt", Workspace:GetServerTimeNow())
	StateValues.set(part, "SmokeRadius", radius)
	StateValues.set(part, "SmokeLife", life)
	StateValues.set(part, "SmokeGrow", grow)
	StateValues.set(part, "SmokeFade", fade)
	StateValues.set(part, "TeamId", teamId or 0)
	StateValues.set(part, "OwnerId", ownerId)
	part.Parent = folder
	task.delay(life + 0.5, function()
		part:Destroy()
	end)
	return part
end

return Smoke
