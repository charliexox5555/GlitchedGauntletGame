--!strict
-- The range's air targets on the client (vault/01 Design/Range v5.md, numbers in Config/RangeTargets). They are per
-- player (owner 2026-11-26: "completely client-sided ... separate per player"): what you see here is yours alone.
--   * every target glides along shared/RangeTargetMotion from the server clock and turns to face your camera
--     (eased, so you see it swing round);
--   * the server tells you when you broke one (LobbyNet RangeTargetEvent, from your own accepted shot's rays): it is
--     hidden and thrown apart here (shards in its ring colours burst from the hit and on along the shot, a white pop,
--     the shatter sound), then grows back in when the server's clock says it's back.
-- Nothing here decides a hit. Targets you can't see (far away) aren't moved.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local RangeTargetMotion = require(ReplicatedStorage.Shared.RangeTargetMotion)
local RangeTargets = require(ReplicatedStorage.Shared.Config.RangeTargets)
local SettingsApply = require(ReplicatedStorage.Shared.SettingsApply)

local ModAudio = require(script.Parent.Parent.Util.ModAudio)
local ShotFxKit = require(script.Parent.Parent.Util.ShotFxKit)

local RangeTargetsController = {}

local MAX_DISTANCE = 300 -- studs from the camera: further targets are left where they are
local WHITE = Color3.new(1, 1, 1)

type Target = {
	model: Model,
	home: CFrame,
	parts: { BasePart },
	facing: CFrame, -- the rotation now (eased toward the camera)
	backAt: number?, -- server time it comes back (nil: standing)
	growAt: number?,
	scale: number,
}

local targets: { [Model]: Target } = {}
local rng = Random.new()

local function setHidden(t: Target, hidden: boolean)
	for _, p in t.parts do
		p.LocalTransparencyModifier = if hidden then 1 else 0
		-- your shots' impacts land on your standing targets only (the server's copies take no rays at all)
		p.CanQuery = not hidden
	end
end

local function scaleTo(t: Target, k: number)
	k = math.max(k, 0.05)
	if math.abs(k - t.scale) > 1e-3 then
		t.scale = k
		pcall(function()
			t.model:ScaleTo(k)
		end)
	end
end

local function shatter(t: Target, at: Vector3, from: Vector3)
	local pivot = t.model:GetPivot()
	local centre = pivot.Position
	local along = if (at - from).Magnitude > 0.1 then (at - from).Unit else -pivot.LookVector
	setHidden(t, true)
	local camera = Workspace.CurrentCamera
	if camera and (camera.CFrame.Position - centre).Magnitude > MAX_DISTANCE then
		return
	end
	ModAudio.play(ModAudio.SOUNDS.Frost.shatter, centre, rng:NextNumber(1.05, 1.25))
	local folder = ShotFxKit.effectsFolder()
	-- the white pop at the hit
	local flash = Instance.new("Part")
	flash.Name = "TargetPop"
	flash.Anchored = true
	flash.CanCollide, flash.CanQuery, flash.CanTouch, flash.CastShadow = false, false, false, false
	flash.Material = Enum.Material.Neon
	flash.Color = WHITE
	flash.Size = Vector3.new(0.6, 0.6, 0.05)
	flash.CFrame = CFrame.lookAt(at, at - along)
	flash.Parent = folder
	TweenService:Create(
		flash,
		TweenInfo.new(RangeTargets.FLASH_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(RangeTargets.FLASH_SIZE, RangeTargets.FLASH_SIZE, 0.05),
			Transparency = 1,
		}
	):Play()
	task.delay(RangeTargets.FLASH_TIME + 0.05, function()
		flash:Destroy()
	end)
	-- shards from the rings, in their colours (outer shards the outer rings' colours)
	local radius = 2.1
	local colours: { Color3 } = {}
	for _, p in t.parts do
		table.insert(colours, p.Color)
	end
	if #colours == 0 then
		colours = { WHITE }
	end
	local count = SettingsApply.vfxCount(RangeTargets.SHARDS)
	for i = 1, count do
		local angle = rng:NextNumber(0, 2 * math.pi)
		local r = math.sqrt(rng:NextNumber(0.05, 1)) * radius
		local pos = pivot * Vector3.new(math.cos(angle) * r, math.sin(angle) * r, 0)
		local size = rng:NextNumber(RangeTargets.SHARD_SIZE[1], RangeTargets.SHARD_SIZE[2])
		local shard = Instance.new("WedgePart")
		shard.Name = "TargetShard"
		shard.Size = Vector3.new(RangeTargets.SHARD_THICK, size, size * rng:NextNumber(0.6, 1.3))
		shard.CFrame = CFrame.new(pos)
			* (pivot - pivot.Position)
			* CFrame.Angles(0, math.pi / 2, angle)
		shard.Material = Enum.Material.SmoothPlastic
		local ring = math.clamp(math.floor((1 - r / radius) * #colours) + 1, 1, #colours)
		shard.Color = colours[ring]
		shard.CanCollide, shard.CanQuery, shard.CanTouch, shard.CastShadow =
			false, false, false, false
		shard.Parent = folder
		local out = pos - at
		local outward = if out.Magnitude > 0.05 then out.Unit else pivot.RightVector
		shard.AssemblyLinearVelocity = outward
				* rng:NextNumber(RangeTargets.SHARD_SPEED[1], RangeTargets.SHARD_SPEED[2])
			+ along * RangeTargets.PUSH
			+ Vector3.new(0, rng:NextNumber(2, 8), 0)
		shard.AssemblyAngularVelocity =
			Vector3.new(rng:NextNumber(-14, 14), rng:NextNumber(-14, 14), rng:NextNumber(-14, 14))
		local life = RangeTargets.SHARD_LIFE * rng:NextNumber(0.75, 1.15)
		TweenService:Create(
			shard,
			TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Transparency = 1 }
		):Play()
		task.delay(life + 0.05, function()
			shard:Destroy()
		end)
		if i % 8 == 0 then
			task.wait() -- spread the spawns over a couple of frames
		end
	end
end

local add: (Instance) -> ()

add = function(inst: Instance)
	if not inst:IsA("Model") or targets[inst] or not inst:IsDescendantOf(Workspace) then
		return
	end
	local parts: { BasePart } = {}
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	if #parts == 0 then
		task.delay(0.5, function() -- streamed in as an empty model first
			if CollectionService:HasTag(inst, RangeTargets.TAG) then
				add(inst)
			end
		end)
		return
	end
	local stored = inst:GetAttribute("Home")
	local home = if typeof(stored) == "CFrame" then stored else inst:GetPivot()
	local t: Target = {
		model = inst,
		home = home,
		parts = parts,
		facing = home - home.Position,
		backAt = nil,
		growAt = nil,
		scale = 1,
	}
	targets[inst] = t
	setHidden(t, false)
end

-- The server: you broke one of yours. Checked here before use (types), nothing decided.
local function onBroken(model: unknown, at: unknown, from: unknown, backAt: unknown)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		return
	end
	local t = targets[model]
	if
		not t
		or typeof(at) ~= "Vector3"
		or typeof(from) ~= "Vector3"
		or typeof(backAt) ~= "number"
	then
		return
	end
	t.backAt = backAt
	t.growAt = nil
	task.spawn(shatter, t, at, from)
end

function RangeTargetsController.start()
	for _, inst in CollectionService:GetTagged(RangeTargets.TAG) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(RangeTargets.TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(RangeTargets.TAG):Connect(function(inst)
		if inst:IsA("Model") then
			targets[inst] = nil
		end
	end)
	LobbyNet.event("RangeTargetEvent").OnClientEvent:Connect(onBroken)

	RunService.PreRender:Connect(function(dt: number)
		local now = Workspace:GetServerTimeNow()
		local clock = os.clock()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		local turn = 1 - math.exp(-RangeTargets.TURN * math.min(dt, 0.1))
		for model, t in targets do
			if not model.Parent then
				targets[model] = nil
				continue
			end
			local backAt = t.backAt
			if backAt then
				if now < backAt then
					continue -- broken (for you): hidden until it's back
				end
				t.backAt = nil
				setHidden(t, false)
				t.growAt = clock
				scaleTo(t, RangeTargets.RETURN_FROM)
			end
			local pos = RangeTargetMotion.position(model, t.home, now)
			local toEye = eye - pos
			if toEye.Magnitude > MAX_DISTANCE then
				continue
			end
			-- face the camera, eased: the target swings round to you
			local want = CFrame.lookAt(Vector3.zero, toEye)
			t.facing = t.facing:Lerp(want, turn)
			local growAt = t.growAt
			if growAt then
				local k = math.clamp((clock - growAt) / RangeTargets.RETURN_TIME, 0, 1)
				scaleTo(
					t,
					RangeTargets.RETURN_FROM + (1 - RangeTargets.RETURN_FROM) * (1 - (1 - k) ^ 3)
				)
				if k >= 1 then
					t.growAt = nil
				end
			end
			model:PivotTo(CFrame.new(pos) * t.facing)
		end
	end)
end

return RangeTargetsController
