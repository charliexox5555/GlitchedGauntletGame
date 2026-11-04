--!strict
-- Movement effects on every character this client can see (players and test
-- range dummies): dust at the feet while sliding, and the slide scrape in 3D
-- for other characters (your own plays 2D from MovementController). Driven by
-- the replicated MoveState attribute (Simulation/Movement), so it needs no
-- remote. Numbers: Config/Juice SLIDE.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Juice = require(ReplicatedStorage.Shared.Config.Juice)
local VfxTextures = require(ReplicatedStorage.Shared.Config.VfxTextures)

local AudioController = require(script.Parent.AudioController)

local CharacterFxController = {}

local TICK = 0.05 -- seconds between checks

type Watch = { emitter: ParticleEmitter, sliding: boolean }

local watched: { [Model]: Watch } = setmetatable({}, { __mode = "k" }) :: any

local function dustFor(character: Model, root: BasePart, humanoid: Humanoid): ParticleEmitter
	local feet = Instance.new("Attachment")
	feet.Name = "SlideDust"
	feet.Position = Vector3.new(0, -(humanoid.HipHeight + root.Size.Y / 2) + 0.2, 0)
	feet.Parent = root
	local e = Instance.new("ParticleEmitter")
	e.Texture = VfxTextures.DUST_2x2
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	e.Color = ColorSequence.new(Color3.fromRGB(205, 198, 186))
	e.LightEmission = 0
	e.LightInfluence = 1
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 2.4),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.6, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(0.35, 0.7)
	e.Speed = NumberRange.new(3, 7)
	e.SpreadAngle = Vector2.new(70, 20)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, 1.5, 0)
	e.Drag = 4
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Rate = Juice.SLIDE.dustRate
	e.Enabled = false
	e.Parent = feet
	character.Destroying:Once(function()
		watched[character] = nil
	end)
	return e
end

local function step(character: Model, isOwn: boolean)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	local watch = watched[character]
	if not watch then
		local new: Watch = { emitter = dustFor(character, root, humanoid), sliding = false }
		watch = new
		watched[character] = new
	end
	local w = watch :: Watch
	local sliding = character:GetAttribute("MoveState") == "Slide" and humanoid.Health > 0
	local speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	w.emitter.Enabled = sliding and speed > Juice.SLIDE.dustMinSpeed
	if sliding and not w.sliding and not isOwn then
		local sound = Juice.SLIDE.sound
		AudioController.play(sound.id, {
			group = "Foley",
			volume = sound.volume,
			cut = sound.cut,
			at = root.Position,
			range = sound.range,
		})
	end
	w.sliding = sliding
end

function CharacterFxController.start()
	local player = Players.LocalPlayer
	while true do
		task.wait(TICK)
		for _, p in Players:GetPlayers() do
			local character = p.Character
			if character then
				step(character, p == player)
			end
		end
		local dummies = Workspace:FindFirstChild("Dummies")
		if dummies then
			for _, model in dummies:GetChildren() do
				if model:IsA("Model") then
					step(model, false)
				end
			end
		end
	end
end

return CharacterFxController
