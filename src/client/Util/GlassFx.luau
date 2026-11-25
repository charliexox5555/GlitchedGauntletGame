--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SettingsApply = require(ReplicatedStorage.Shared.SettingsApply)
local ModAudio = require(script.Parent.ModAudio)
local ShotFxKit = require(script.Parent.ShotFxKit)

local GlassFx = {}
local rng = Random.new()
local live = 0
local MAX_SHARDS = 96

function GlassFx.play(
	position: Vector3,
	normal: Vector3,
	pane: CFrame,
	size: Vector3,
	color: Color3
)
	local camera = workspace.CurrentCamera
	if not camera or (camera.CFrame.Position - position).Magnitude > 100 then
		return
	end

	ModAudio.play(ModAudio.SOUNDS.Frost.shatter, position, rng:NextNumber(0.78, 0.96))
	-- Scatter thin triangular fragments over the actual face of the pane.
	local face = if size.X < size.Z then pane * CFrame.Angles(0, math.pi / 2, 0) else pane
	local halfWidth = math.max(size.X, size.Z) / 2
	local halfHeight = size.Y / 2
	local hit = face:PointToObjectSpace(position)
	local folder = ShotFxKit.effectsFolder()
	local count = math.min(SettingsApply.vfxCount(18), MAX_SHARDS - live)
	for i = 1, count do
		local nearImpact = i % 3 ~= 0
		local x = if nearImpact
			then math.clamp(hit.X + rng:NextNumber(-1.6, 1.6), -halfWidth, halfWidth)
			else rng:NextNumber(-halfWidth, halfWidth)
		local y = if nearImpact
			then math.clamp(hit.Y + rng:NextNumber(-1.6, 1.6), -halfHeight, halfHeight)
			else rng:NextNumber(-halfHeight, halfHeight)
		local shard = Instance.new("WedgePart")
		shard.Name = "GlassShard"
		shard.Size = Vector3.new(0.045, rng:NextNumber(0.12, 0.55), rng:NextNumber(0.16, 0.6))
		shard.CFrame = face
			* CFrame.new(x, y, 0)
			* CFrame.Angles(0, 0, rng:NextNumber(0, math.pi * 2))
			* CFrame.Angles(0, math.pi / 2 + 0.2, 0)
		shard.Material = Enum.Material.Glass
		shard.Color = color:Lerp(Color3.new(1, 1, 1), 0.32)
		shard.Transparency = 0.25
		shard.CanCollide = false
		shard.CanTouch = false
		shard.CanQuery = false
		shard.CastShadow = false
		shard.Parent = folder
		shard.AssemblyLinearVelocity = -normal * rng:NextNumber(3, 14)
			+ Vector3.new(rng:NextNumber(-6, 6), rng:NextNumber(4, 16), rng:NextNumber(-6, 6))
		shard.AssemblyAngularVelocity =
			Vector3.new(rng:NextNumber(-13, 13), 6, rng:NextNumber(-13, 13))
		live += 1
		TweenService:Create(shard, TweenInfo.new(0.42), { Transparency = 1 }):Play()
		task.delay(0.45, function()
			shard:Destroy()
			live -= 1
		end)
	end
end

return GlassFx
