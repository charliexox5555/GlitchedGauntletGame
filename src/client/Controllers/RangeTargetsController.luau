--!strict
-- The range's air targets on the client (vault/01 Design/Range v5.md, numbers in Config/RangeTargets). The server
-- breaks them (LobbyServer Range/RangeTargets); here every client:
--   * draws each target gliding along shared/RangeTargetMotion from the server clock (smooth at any ping);
--   * when one breaks (`BrokenAt`): hides it and throws it apart: shards in its own ring colours burst out from where
--     it was hit and on along the shot, tumble, fall and fade, with a white pop and the shatter sound;
--   * when it comes back (`ReturnedAt`): grows it back in from small.
-- Purely visual and local.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local RangeTargetMotion = require(ReplicatedStorage.Shared.RangeTargetMotion)
local RangeTargets = require(ReplicatedStorage.Shared.Config.RangeTargets)
local SettingsApply = require(ReplicatedStorage.Shared.SettingsApply)

local ModAudio = require(script.Parent.Parent.Util.ModAudio)
local ShotFxKit = require(script.Parent.Parent.Util.ShotFxKit)

local RangeTargetsController = {}

local MAX_DISTANCE = 300 -- studs: further targets aren't moved here (the server still places them)
local WHITE = Color3.new(1, 1, 1)

type Target = {
	model: Model,
	home: CFrame,
	parts: { BasePart },
	hidden: boolean,
	growAt: number?,
	connections: { RBXScriptConnection },
}

local targets: { [Model]: Target } = {}
local rng = Random.new()

local function setHidden(t: Target, hidden: boolean)
	t.hidden = hidden
	for _, p in t.parts do
		p.LocalTransparencyModifier = if hidden then 1 else 0
	end
end

-- A target's look at a size share (the pop back in): scales the model about its pivot, locally.
local function scaleTo(t: Target, k: number)
	pcall(function()
		t.model:ScaleTo(math.max(k, 0.05))
	end)
end

local function shatter(t: Target)
	local m = t.model
	local hitAt = m:GetAttribute("BrokenHit")
	local from = m:GetAttribute("BrokenFrom")
	local pivot = m:GetPivot()
	local centre = pivot.Position
	local at = if typeof(hitAt) == "Vector3" then hitAt else centre
	local along = if typeof(from) == "Vector3" and (at - from).Magnitude > 0.1
		then (at - from).Unit
		else -pivot.LookVector
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

	-- shards from the rings, in their colours, more from the outer (bigger) rings
	local radius = 2.1
	local count = SettingsApply.vfxCount(RangeTargets.SHARDS)
	local colours: { Color3 } = {}
	for _, p in t.parts do
		table.insert(colours, p.Color)
	end
	if #colours == 0 then
		colours = { WHITE }
	end
	for i = 1, count do
		local angle = rng:NextNumber(0, 2 * math.pi)
		local r = math.sqrt(rng:NextNumber(0.05, 1)) * radius
		local local_ = Vector3.new(math.cos(angle) * r, math.sin(angle) * r, 0)
		local pos = pivot * local_
		local size = rng:NextNumber(RangeTargets.SHARD_SIZE[1], RangeTargets.SHARD_SIZE[2])
		local shard = Instance.new("WedgePart")
		shard.Name = "TargetShard"
		shard.Size = Vector3.new(RangeTargets.SHARD_THICK, size, size * rng:NextNumber(0.6, 1.3))
		shard.CFrame = CFrame.new(pos)
			* (pivot - pivot.Position)
			* CFrame.Angles(0, math.pi / 2, angle)
		shard.Material = Enum.Material.SmoothPlastic
		-- the ring that was there: outer shards red / rim, inner white, by the share of the radius
		local ring = math.clamp(math.floor((1 - r / radius) * #colours) + 1, 1, #colours)
		shard.Color = colours[ring]
		shard.CanCollide = false
		shard.CanQuery = false
		shard.CanTouch = false
		shard.CastShadow = false
		shard.Parent = folder
		local out = (pos - at)
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

local function remove(model: Model)
	local t = targets[model]
	if not t then
		return
	end
	targets[model] = nil
	for _, c in t.connections do
		c:Disconnect()
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
		-- streamed in as an empty model first: try again when its parts land
		task.delay(0.5, function()
			if CollectionService:HasTag(inst, RangeTargets.TAG) then
				add(inst)
			end
		end)
		return
	end
	-- The home is where the server last put it minus its motion: rebuild it from the build attribute when
	-- there is one (set by the placement tool), else from the model's pivot now.
	local stored = inst:GetAttribute("Home")
	local home = if typeof(stored) == "CFrame" then stored else inst:GetPivot()
	local t: Target =
		{ model = inst, home = home, parts = parts, hidden = false, growAt = nil, connections = {} }
	targets[inst] = t
	if inst:GetAttribute("BrokenAt") ~= nil then
		setHidden(t, true)
	end
	table.insert(
		t.connections,
		inst:GetAttributeChangedSignal("BrokenAt"):Connect(function()
			if inst:GetAttribute("BrokenAt") ~= nil then
				task.spawn(shatter, t)
			end
		end)
	)
	table.insert(
		t.connections,
		inst:GetAttributeChangedSignal("ReturnedAt"):Connect(function()
			setHidden(t, false)
			t.growAt = os.clock()
			scaleTo(t, RangeTargets.RETURN_FROM)
		end)
	)
end

function RangeTargetsController.start()
	for _, inst in CollectionService:GetTagged(RangeTargets.TAG) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(RangeTargets.TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(RangeTargets.TAG):Connect(function(inst)
		if inst:IsA("Model") then
			remove(inst)
		end
	end)
	RunService.PreRender:Connect(function()
		local now = Workspace:GetServerTimeNow()
		local clock = os.clock()
		local camera = Workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		for model, t in targets do
			if not model.Parent then
				remove(model)
				continue
			end
			if t.hidden or (t.home.Position - eye).Magnitude > MAX_DISTANCE then
				continue
			end
			local growAt = t.growAt
			if growAt then
				local k = math.clamp((clock - growAt) / RangeTargets.RETURN_TIME, 0, 1)
				local eased = 1 - (1 - k) ^ 3
				scaleTo(t, RangeTargets.RETURN_FROM + (1 - RangeTargets.RETURN_FROM) * eased)
				if k >= 1 then
					t.growAt = nil
				end
			end
			model:PivotTo(RangeTargetMotion.pose(model, t.home, now))
		end
	end)
end

return RangeTargetsController
