--!strict
-- Footsteps for every character this client can see (players, bots and range
-- dummies), 2026-11-05 lane F. Real recordings per surface (Config/Sounds
-- STEPS, from the atlas); one step every `stride` studs travelled on the
-- ground, measured from the root's movement, so it works the same for your
-- own character and for replicated ones without any remote. Yours play 2D,
-- others' 3D at their feet. Numbers: Config/Audio STEPS. LihFolk: Custom
-- Character Sounds (one def per surface, client-side for every character),
-- Combat Sound Design and Feedback (footsteps are information: 3D, quieter
-- when sneaking).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Audio = require(ReplicatedStorage.Shared.Config.Audio)
local Health = require(ReplicatedStorage.Shared.Health)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local AudioController = require(script.Parent.AudioController)

local FootstepController = {}

local STEPS = Audio.STEPS

-- Material -> Config/Sounds STEPS key. Anything not listed is "Concrete".
local SURFACE: { [Enum.Material]: string } = {
	[Enum.Material.Metal] = "Metal",
	[Enum.Material.DiamondPlate] = "Metal",
	[Enum.Material.CorrodedMetal] = "Metal",
	[Enum.Material.Foil] = "Metal",
	[Enum.Material.Wood] = "Wood",
	[Enum.Material.WoodPlanks] = "Wood",
	[Enum.Material.Grass] = "Grass",
	[Enum.Material.LeafyGrass] = "Grass",
	[Enum.Material.Ground] = "Grass",
	[Enum.Material.Mud] = "Grass",
	[Enum.Material.Sand] = "Grass",
	[Enum.Material.Fabric] = "Grass",
	[Enum.Material.Snow] = "Snow",
	[Enum.Material.Ice] = "Snow",
	[Enum.Material.Glacier] = "Snow",
}

type Track = { last: Vector3?, travelled: number }

local tracks: { [Model]: Track } = setmetatable({}, { __mode = "k" }) :: any
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true

-- What the character stands on (nil: in the air).
local function ground(character: Model, root: BasePart, humanoid: Humanoid): RaycastResult?
	params.FilterDescendantsInstances = { character, Workspace.CurrentCamera :: Instance }
	local depth = humanoid.HipHeight + root.Size.Y / 2 + 0.8
	return Workspace:Raycast(root.Position, Vector3.new(0, -depth, 0), params)
end

local function stepFor(character: Model, own: boolean, dt: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or not Health.isAlive(humanoid) then
		tracks[character] = nil
		return
	end
	local t = tracks[character]
	if not t then
		t = { last = nil, travelled = 0 }
		tracks[character] = t
	end
	local pos = root.Position
	local last = t.last
	t.last = pos
	if not last or dt <= 0 then
		return
	end
	local move = (pos - last) * Vector3.new(1, 0, 1)
	local speed = move.Magnitude / dt
	local state = character:GetAttribute("MoveState")
	if speed < STEPS.minSpeed or speed > 80 or state == "Slide" or state == "Air" then
		-- Standing, teleported or sliding: the next step comes half a stride in.
		t.travelled = math.min(t.travelled, STEPS.stride * 0.5)
		return
	end
	local crouch = state == "Crouch"
	local sprint = state == "Sprint"
	local stride = if crouch
		then STEPS.crouchStride
		elseif sprint then STEPS.sprintStride
		else STEPS.stride
	t.travelled += move.Magnitude
	if t.travelled < stride then
		return
	end
	t.travelled -= stride
	if t.travelled > stride then
		t.travelled = 0
	end
	local hit = ground(character, root, humanoid)
	if not hit then
		return
	end
	local surface = SURFACE[hit.Material] or "Concrete"
	local id = Sounds.STEPS[surface] or Sounds.STEPS.Concrete
	local scale = if crouch then STEPS.crouchScale elseif sprint then STEPS.sprintScale else 1
	if own then
		AudioController.play(id, { group = "Foley", volume = STEPS.ownVolume * scale })
	else
		AudioController.play(id, {
			group = "Foley",
			volume = STEPS.otherVolume * scale,
			at = hit.Position,
			range = STEPS.range,
		})
	end
end

function FootstepController.start()
	local player = Players.LocalPlayer
	RunService.Heartbeat:Connect(function(dt)
		local cam = Workspace.CurrentCamera
		local eye = if cam then cam.CFrame.Position else Vector3.zero
		for _, p in Players:GetPlayers() do
			local character = p.Character
			if character then
				local own = p == player
				local root = character.PrimaryPart
				if own or (root and (root.Position - eye).Magnitude <= STEPS.hearRange) then
					stepFor(character, own, dt)
				end
			end
		end
		local dummies = Workspace:FindFirstChild("Dummies")
		if dummies then
			for _, model in dummies:GetChildren() do
				local root = if model:IsA("Model") then model.PrimaryPart else nil
				if root and (root.Position - eye).Magnitude <= STEPS.hearRange then
					stepFor(model :: Model, false, dt)
				end
			end
		end
	end)
end

return FootstepController
