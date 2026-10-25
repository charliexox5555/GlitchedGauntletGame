--!strict
-- Third-person weapon pose. Every armed character (players and test dummies,
-- marked by the server with a "WeaponId" attribute) gets its arms raised to
-- hold the gun, pitched by the replicated "AimPitch". Runs after the
-- Animator each frame, so it layers over walk/idle animations.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PoseController = {}

-- Joint-space poses (R15). The right hand holds the grip; the left reaches
-- across toward the front of the gun.
local RIGHT_YAW = math.rad(8)
local LEFT_YAW = math.rad(-38)
local LEFT_ELBOW = CFrame.Angles(math.rad(18), 0, 0)
local WAIST_SHARE = 0.35

-- R15 joints are Motor6Ds on older rigs and AnimationConstraints on current
-- avatars; both expose the same Transform property.
type Joint = Instance

type Rig = {
	rightShoulder: Joint?,
	leftShoulder: Joint?,
	leftElbow: Joint?,
	waist: Joint?,
}

local rigs: { [Model]: Rig } = {}

local function motor(model: Model, partName: string, jointName: string): Joint?
	local part = model:FindFirstChild(partName)
	local m = part and part:FindFirstChild(jointName)
	if m and (m:IsA("Motor6D") or m:IsA("AnimationConstraint")) then
		return m
	end
	return nil
end

local function setTransform(joint: Joint?, cf: CFrame)
	if joint then
		(joint :: any).Transform = cf
	end
end

local function live(m: Joint?): boolean
	return m ~= nil and m.Parent ~= nil
end

-- Every joint found and still in the rig (Humanoids can rebuild their joints,
-- and streaming can swap parts, so a cached Motor6D may go stale).
local function complete(r: Rig): boolean
	return live(r.rightShoulder) and live(r.leftShoulder) and live(r.leftElbow) and live(r.waist)
end

-- With StreamingEnabled a model's limbs can arrive after the model itself,
-- so keep looking until every joint has been found.
local function rigFor(model: Model): Rig
	local r = rigs[model]
	if r and not complete(r) then
		rigs[model] = nil
		r = nil
	end
	if not r then
		r = {
			rightShoulder = motor(model, "RightUpperArm", "RightShoulder"),
			leftShoulder = motor(model, "LeftUpperArm", "LeftShoulder"),
			leftElbow = motor(model, "LeftLowerArm", "LeftElbow"),
			waist = motor(model, "UpperTorso", "Waist"),
		}
		rigs[model] = r
		if complete(r) then
			model.Destroying:Once(function()
				rigs[model] = nil
			end)
		end
	end
	return r
end

local function pose(model: Model)
	if not model:GetAttribute("WeaponId") or not model:FindFirstChild("WorldWeapon") then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local r = rigFor(model)
	local pitch = (model:GetAttribute("AimPitch") :: number?) or 0
	local armPitch = pitch * (1 - WAIST_SHARE)
	setTransform(
		r.rightShoulder,
		CFrame.Angles(0, RIGHT_YAW, 0) * CFrame.Angles(math.pi / 2 + armPitch, 0, 0)
	)
	setTransform(
		r.leftShoulder,
		CFrame.Angles(0, LEFT_YAW, 0) * CFrame.Angles(math.pi / 2 + armPitch, 0, 0)
	)
	setTransform(r.leftElbow, LEFT_ELBOW)
	setTransform(r.waist, CFrame.Angles(pitch * WAIST_SHARE, 0, 0))
end

local function step()
	for _, p in Players:GetPlayers() do
		local c = p.Character
		if c then
			pose(c)
		end
	end
	local dummies = Workspace:FindFirstChild("Dummies")
	if dummies then
		for _, d in dummies:GetChildren() do
			if d:IsA("Model") then
				pose(d)
			end
		end
	end
end

function PoseController.start()
	RunService.PreSimulation:Connect(step)
end

return PoseController
