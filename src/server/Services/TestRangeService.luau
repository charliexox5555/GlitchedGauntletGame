--!strict
-- Studio-only test range: R15 dummies holding guns at known distances (one
-- strafes), a solid wall and a ThinWall in front of the spawn. Lets you test
-- hit zones, falloff, penetration and third-person weapon holding solo.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Dev = require(ReplicatedStorage.Shared.Config.Dev)

local CharacterService = require(script.Parent.CharacterService)
local WeaponService = require(script.Parent.WeaponService)

local TestRangeService = {}

local DUMMY_COLOR = Color3.fromHex("56607C")
local DARK = Color3.fromHex("1C2030")
local NEON = Color3.fromHex("00E5FF")

local function spawnFrame(): CFrame
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local base = if spawn then spawn.CFrame else CFrame.new(0, 0.5, 0)
	-- Face along -Z from the spawn.
	return CFrame.new(base.Position + Vector3.new(0, 3, 0))
end

local function makeDummy(index: number, folder: Folder)
	local layout = Dev.DUMMIES[index]
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = DUMMY_COLOR
	desc.TorsoColor = DARK
	desc.LeftArmColor = DUMMY_COLOR
	desc.RightArmColor = DUMMY_COLOR
	desc.LeftLegColor = DARK
	desc.RightLegColor = DARK
	local dummy = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	dummy.Name = string.format("Dummy_%dstuds", layout.distance)
	-- Stream the whole dummy at once, like player characters.
	dummy.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local humanoid = dummy:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayName = string.format("%d studs", layout.distance)
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.NameDisplayDistance = 150
	humanoid.HealthDisplayDistance = 150

	local origin = spawnFrame()
	local pos = origin.Position + Vector3.new(layout.side, 0, -layout.distance)
	dummy:PivotTo(CFrame.lookAt(pos, Vector3.new(origin.X, pos.Y, origin.Z)))
	dummy.Parent = folder
	CharacterService.prepare(dummy)
	task.defer(function()
		WeaponService.attachWorldModel(dummy, layout.weapon)
	end)

	if layout.strafe then
		task.spawn(function()
			local dir = 1
			while dummy.Parent and humanoid.Health > 0 do
				humanoid:MoveTo(pos + Vector3.new(8 * dir, 0, 0))
				humanoid.MoveToFinished:Wait()
				dir = -dir
			end
		end)
	end

	humanoid.Died:Connect(function()
		task.delay(Dev.DUMMY_RESPAWN, function()
			dummy:Destroy()
			if folder.Parent then
				makeDummy(index, folder)
			end
		end)
	end)
end

local function makeWall(name: string, cf: CFrame, size: Vector3, thin: boolean, parent: Instance)
	local wall = Instance.new("Part")
	wall.Name = name
	wall.Anchored = true
	wall.Size = size
	wall.CFrame = cf
	wall.Material = if thin then Enum.Material.Glass else Enum.Material.SmoothPlastic
	wall.Color = if thin then NEON else DARK
	wall.Transparency = if thin then 0.6 else 0
	wall.Parent = parent
	if thin then
		CollectionService:AddTag(wall, Combat.THIN_WALL_TAG)
	end
end

function TestRangeService.start()
	if not RunService:IsStudio() or not Dev.TEST_RANGE then
		return
	end
	local old = workspace:FindFirstChild("TestRange")
	if old then
		old:Destroy()
	end
	local range = Instance.new("Folder")
	range.Name = "TestRange"
	range.Parent = workspace
	local dummies = Instance.new("Folder")
	dummies.Name = "Dummies"
	dummies.Parent = workspace

	local origin = spawnFrame()
	local floorY = origin.Y - 3
	-- A solid wall (blocks every gun) and a ThinWall (Flood / Ray Trace shoot through).
	makeWall(
		"SolidWall",
		CFrame.new(origin.X + 18, floorY + 4, origin.Z - 45),
		Vector3.new(10, 8, 1),
		false,
		range
	)
	makeWall(
		"ThinWall",
		CFrame.new(origin.X - 18, floorY + 4, origin.Z - 45),
		Vector3.new(10, 8, 0.4),
		true,
		range
	)

	-- Give the server a moment to load weapon models before dressing dummies.
	task.wait(1)
	for i = 1, #Dev.DUMMIES do
		makeDummy(i, dummies)
	end
end

return TestRangeService
