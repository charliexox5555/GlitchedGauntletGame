--!strict
-- Replay-owned effects follow recorded time and disappear with the replay.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Projectile = require(ReplicatedStorage.Shared.Mods.Blocks.Projectile)
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local ReplayModFx = {}

local FIRE = Color3.fromRGB(255, 114, 47)
local ICE = Color3.fromRGB(99, 220, 255)
local SCAN = Color3.fromRGB(144, 167, 255)
local SHOCK = Color3.fromRGB(185, 138, 255)
local HEAL = Color3.fromRGB(103, 255, 174)
local LIGHT = Color3.fromRGB(255, 231, 169)
local projectiles = {
	MollyThrow = FIRE,
	FrostThrow = ICE,
	ReconThrow = SCAN,
	ShockThrow = SHOCK,
	FlashThrow = LIGHT,
}
local pulses = {
	MollyBurst = FIRE,
	MollyFizzle = FIRE,
	FrostBurst = ICE,
	FrostFizzle = ICE,
	ReconPulse = SCAN,
	ReconStick = SCAN,
	ShockBurst = SHOCK,
	FlashPop = LIGHT,
	RollerPlaced = LIGHT,
	RollerLock = LIGHT,
	RollerBoom = FIRE,
	RollerFizzle = FIRE,
	RecallPlaced = SHOCK,
	RecallWindup = SHOCK,
	RecallArrive = SHOCK,
	RecallPickedUp = SHOCK,
	UpdraftSlam = ICE,
	Updraft = ICE,
	Dash = SCAN,
	Heal = HEAL,
	Barrier = HEAL,
	BarrierBlock = HEAL,
	StimDrop = HEAL,
}
local zones = { MollyBurst = true, FrostBurst = true, StimDrop = true }

type Mark = {
	t: number,
	ends: number,
	color: Color3,
	shape: "Pulse" | "Zone" | "Flight" | "Wall",
	radius: number,
	at: Vector3,
	path: Projectile.Path?,
	cframe: CFrame?,
	size: Vector3?,
}

local marks: { Mark } = {}
local walls: { [BasePart]: Mark } = {}

local function add(mark: Mark)
	if #marks >= 384 then
		table.remove(marks, 1)
	end
	table.insert(marks, mark)
end

function ReplayModFx.clear()
	table.clear(marks)
	table.clear(walls)
end

function ReplayModFx.capture(kind: string, data: { [string]: any }, now: number)
	local t = if typeof(data.start) == "number" and math.abs(data.start - now) < 1
		then data.start
		else now
	local color = projectiles[kind]
	if color then
		local path = Projectile.unpack(data.path)
		if path and typeof(data.land) == "number" then
			add({
				t = t,
				ends = t + math.clamp(data.land, 0.05, 8),
				color = color,
				shape = "Flight",
				at = Vector3.zero,
				radius = 0.35,
				path = path,
			})
		end
		return
	end
	color = pulses[kind]
	if not color then
		return
	end
	local at = data.at or data.to or data.position
	if typeof(at) ~= "Vector3" then
		local target = data.target
		local root = if typeof(target) == "Instance" and target:IsA("Model")
			then target:FindFirstChild("HumanoidRootPart")
			else nil
		at = if root and root:IsA("BasePart") then root.Position else nil
	end
	if typeof(at) ~= "Vector3" then
		return
	end
	local zone = zones[kind] == true
	if kind == "StimDrop" and typeof(data.deploy) == "number" then
		t += math.clamp(data.deploy, 0, 3)
	end
	local duration = if zone and typeof(data.duration) == "number"
		then math.clamp(data.duration, 0.4, 15)
		else 0.55
	add({
		t = t,
		ends = t + duration,
		at = at,
		color = color,
		radius = if typeof(data.radius) == "number" then math.clamp(data.radius, 0.8, 40) else 3,
		shape = if zone then "Zone" else "Pulse",
	})
end

function ReplayModFx.sample(now: number, oldest: number, matchId: string?)
	for part, mark in walls do
		if not part.Parent then
			mark.ends = now
			walls[part] = nil
		end
	end
	local folder = Workspace:FindFirstChild("ModWalls")
	if folder then
		for _, part in folder:GetChildren() do
			if
				not part:IsA("BasePart")
				or walls[part]
				or part:GetAttribute("ReplayMatchId") ~= matchId
			then
				continue
			end
			local built = StateValues.get(part, "BuiltAt")
			local mark: Mark = {
				t = if typeof(built) == "number" then built else now,
				ends = math.huge,
				color = if StateValues.get(part, "WallKind") == "Frost" then ICE else FIRE,
				at = part.Position,
				radius = 0,
				shape = "Wall",
				cframe = part.CFrame,
				size = part.Size,
			}
			walls[part] = mark
			add(mark)
		end
	end
	for i = #marks, 1, -1 do
		if marks[i].ends < oldest then
			table.remove(marks, i)
		end
	end
end

function ReplayModFx.stage(folder: Folder, from: number, to: number): (number) -> ()
	local queued: { Mark } = {}
	for _, mark in marks do
		if mark.ends >= from and mark.t <= to then
			table.insert(queued, mark)
		end
	end
	table.sort(queued, function(a, b)
		return a.t < b.t
	end)
	local nextMark = 1
	local active: { [Mark]: Part } = {}
	return function(t: number)
		while queued[nextMark] and queued[nextMark].t <= t do
			local mark = queued[nextMark]
			nextMark += 1
			if mark.ends <= t then
				continue
			end
			local part = Instance.new("Part")
			part.Name = "ReplayMod" .. mark.shape
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
			part.Color = mark.color
			part.Material = Enum.Material.Neon
			part.Shape = if mark.shape == "Wall"
				then Enum.PartType.Block
				elseif mark.shape == "Zone" then Enum.PartType.Cylinder
				else Enum.PartType.Ball
			active[mark] = part
		end
		for mark, part in active do
			if t >= mark.ends then
				part:Destroy()
				active[mark] = nil
				continue
			end
			local elapsed = t - mark.t
			local progress = math.clamp(elapsed / (mark.ends - mark.t), 0, 1)
			if mark.path then
				part.Size = Vector3.one * 0.7
				part.Position = Projectile.positionAt(mark.path, elapsed)
			elseif mark.shape == "Wall" then
				part.Size = mark.size :: Vector3
				part.CFrame = mark.cframe :: CFrame
				part.Transparency = 0.38 + 0.1 * math.sin(elapsed * 8)
			elseif mark.shape == "Zone" then
				local diameter = 2 * mark.radius * math.clamp(elapsed * 5, 0.05, 1)
				part.Size = Vector3.new(0.14, diameter, diameter)
				part.CFrame = CFrame.new(mark.at + Vector3.yAxis * 0.14)
					* CFrame.Angles(0, 0, math.pi / 2)
				part.Transparency = 0.55 + 0.12 * math.sin(elapsed * 7)
			else
				part.Size = Vector3.one * (mark.radius * (0.15 + progress * 1.85))
				part.Position = mark.at
				part.Transparency = 0.48 + 0.52 * progress
			end
			part.Parent = folder
		end
	end
end

return ReplayModFx
