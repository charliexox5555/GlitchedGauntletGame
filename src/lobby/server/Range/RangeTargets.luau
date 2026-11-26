--!strict
-- The range's air targets on the server (vault/01 Design/Range v5.md, numbers in Config/RangeTargets). Owner
-- 2026-11-26: "red circle targets [in the air] that you can shoot down. They break, like they shatter".
--
-- Every target (a Model tagged `RangeTarget`) floats from its home CFrame along shared/RangeTargetMotion, placed
-- here each frame from the server clock (clients draw it from the same clock, so nothing is sent). A target breaks
-- only when the server's own rays for an accepted shot (WeaponService.onRays: the spread it recomputed, not the
-- client's claim) reach it first, from a shooter in the Range zone. Broken: `BrokenAt` (server time), `BrokenFrom`
-- (where the shot came from) and `BrokenHit` (where it landed) for the clients' shatter, its parts stop taking rays,
-- and RESPAWN later it comes back (`BrokenAt` cleared, `ReturnedAt` set). No remotes.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local RangeTargetMotion = require(ReplicatedStorage.Shared.RangeTargetMotion)
local RangeTargets = require(ReplicatedStorage.Shared.Config.RangeTargets)

local RangeTargetsServer = {}

type Target = { model: Model, home: CFrame, broken: boolean, parts: { BasePart } }

local targets: { [Model]: Target } = {}

local function add(inst: Instance)
	if not inst:IsA("Model") or targets[inst] then
		return
	end
	local parts: { BasePart } = {}
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = true
			table.insert(parts, d)
		end
	end
	inst.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	inst:SetAttribute("BrokenAt", nil)
	-- The home: the placement tool's `Home` attribute (clients read the same), else where it was built.
	local stored = inst:GetAttribute("Home")
	local home = if typeof(stored) == "CFrame" then stored else inst:GetPivot()
	inst:SetAttribute("Home", home)
	targets[inst] = { model = inst, home = home, broken = false, parts = parts }
end

local function targetOf(part: Instance): Target?
	local model = part:FindFirstAncestorWhichIsA("Model")
	while model do
		local t = targets[model]
		if t then
			return t
		end
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return nil
end

local function setQueryable(t: Target, on: boolean)
	for _, p in t.parts do
		p.CanQuery = on
	end
end

local function breakTarget(t: Target, from: Vector3, at: Vector3)
	t.broken = true
	setQueryable(t, false)
	local m = t.model
	m:SetAttribute("BrokenFrom", from)
	m:SetAttribute("BrokenHit", at)
	-- Last: clients react when this changes, with the fields above in place.
	m:SetAttribute("BrokenAt", workspace:GetServerTimeNow())
	task.delay(RangeTargets.RESPAWN, function()
		if not m.Parent then
			return
		end
		t.broken = false
		setQueryable(t, true)
		m:SetAttribute("BrokenAt", nil)
		m:SetAttribute("ReturnedAt", workspace:GetServerTimeNow())
	end)
end

-- An accepted shot's rays: the first thing each ray meets (past the shooter) decides. Read-only on the shot.
local function onRays(
	player: Player,
	character: Model,
	origin: Vector3,
	dirs: { Vector3 },
	config: any
)
	if PlayZone.get(player) ~= "Range" or next(targets) == nil or config.melee then
		return
	end
	local range = if typeof(config.range) == "number" then config.range else 0
	if range <= 0 then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	for _, dir in dirs do
		local hit = workspace:Raycast(origin, dir * range, params)
		local t = hit and targetOf(hit.Instance)
		if t and hit and not t.broken then
			breakTarget(t, origin, hit.Position)
		end
	end
end

local function step()
	local t = workspace:GetServerTimeNow()
	for model, target in targets do
		if not model.Parent then
			targets[model] = nil
		elseif not target.broken then
			model:PivotTo(RangeTargetMotion.pose(model, target.home, t))
		end
	end
end

-- `onRays`: WeaponService.onRays (the match code, handed over by RangeService).
function RangeTargetsServer.start(onRaysHook: (any) -> ())
	for _, inst in CollectionService:GetTagged(RangeTargets.TAG) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(RangeTargets.TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(RangeTargets.TAG):Connect(function(inst)
		if inst:IsA("Model") then
			targets[inst] = nil
		end
	end)
	onRaysHook(onRays)
	RunService.Heartbeat:Connect(step)
end

return RangeTargetsServer
