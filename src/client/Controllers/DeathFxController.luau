--!strict
-- The death look (vault/01 Design/Gunplay.md §3 → Health): nobody truly dies,
-- so when a fighter goes down (shared/Health "Downed") every client hides the
-- real body and shows a still copy of it falling over, resting, then fading
-- with a dust puff. The downed player's own screen drains of colour until
-- their next character. Numbers: Config/Juice DEATH.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Animations = require(ReplicatedStorage.Shared.Config.Animations)
local Health = require(ReplicatedStorage.Shared.Health)
local Juice = require(ReplicatedStorage.Shared.Config.Juice)
local VfxTextures = require(ReplicatedStorage.Shared.Config.VfxTextures)

local BodyClone = require(script.Parent.Parent.Util.BodyClone)

local DeathFxController = {}

DeathFxController.COPY_TAG = "DeathFxCopy"

local player = Players.LocalPlayer
local D = Juice.DEATH
local TICK = 0.1

-- true once a body's death look ran; false while we've seen it standing.
local shown: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local grade: ColorCorrectionEffect? = nil

local function hide(body: Model)
	for _, d in body:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = 1
		end
	end
end

local function puff(at: Vector3)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(3, 0.5, 3)
	holder.Position = at
	holder.Parent = Workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = VfxTextures.DUST_2x2
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	e.Color = ColorSequence.new(Color3.fromRGB(210, 204, 194))
	e.Size = NumberSequence.new(1, 3)
	e.Transparency = NumberSequence.new(0.45, 1)
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(180, 30)
	e.EmissionDirection = Enum.NormalId.Top
	e.Drag = 3
	e.Rate = 0
	e.Parent = holder
	e:Emit(D.dust)
	task.delay(1.2, function()
		holder:Destroy()
	end)
end

-- The body falls over (around its feet), rests, then fades.
local function fall(body: Model, parent: Instance?)
	local root = body:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		hide(body)
		return
	end
	local copy = BodyClone.copy(body, "root", body.Name .. "Down")
	hide(body)
	if not copy then
		return
	end
	copy:AddTag(DeathFxController.COPY_TAG) -- the final-kill replay hides these
	copy.Parent = parent or Workspace
	-- The knees buckle and the head drops first (the Death clip).
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	local animator: Animator? = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if humanoid and not animator then
		local made = Instance.new("Animator")
		made.Parent = humanoid
		animator = made
	end
	if animator then
		for _, t in animator:GetPlayingAnimationTracks() do
			t:Stop(0)
		end
		local clip = Instance.new("Animation")
		clip.AnimationId = Animations.COMBAT.Death
		local track = animator:LoadAnimation(clip)
		track.Priority = Enum.AnimationPriority.Action4
		track.Looped = false
		track:Play(0.05)
		track.Stopped:Once(function()
			-- Hold the last frame: replay frozen at the end.
			if copy.Parent then
				track:Play(0)
				track.TimePosition = track.Length
				track:AdjustSpeed(0)
			end
		end)
	end
	task.wait(D.buckle)
	if not copy.Parent then
		return
	end
	local start = copy:GetPivot()
	local _, size = copy:GetBoundingBox()
	local feet = start.Position - Vector3.new(0, size.Y / 2, 0)
	-- Mostly forward off the knees (sometimes backward), a little to one
	-- side, so no two look the same.
	local dir = if math.random() < 0.7 then -1 else 1
	local side = math.rad((math.random() * 2 - 1) * 20)
	local hinge = CFrame.new(feet) * (start - start.Position)
	local offset = hinge:ToObjectSpace(start)
	local progress = Instance.new("NumberValue")
	progress:GetPropertyChangedSignal("Value"):Connect(function()
		local k = progress.Value
		local tipped = hinge * CFrame.Angles(math.rad(D.tilt) * k * dir, side * k, 0) * offset
		copy:PivotTo(tipped - Vector3.new(0, size.Y * 0.12 * k, 0))
	end)
	local tween = TweenService:Create(
		progress,
		TweenInfo.new(D.fall, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
		{ Value = 1 }
	)
	tween:Play()
	tween.Completed:Once(function()
		task.wait(D.rest)
		if not copy.Parent then
			return
		end
		local info = TweenInfo.new(D.fade, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for _, d in copy:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				TweenService:Create(d, info, { Transparency = 1 }):Play()
			end
		end
		puff(copy:GetPivot().Position)
		task.wait(D.fade)
		copy:Destroy()
		progress:Destroy()
	end)
	-- The real body comes back (a new character replaces it): drop the copy.
	body.AncestryChanged:Once(function()
		if not body:IsDescendantOf(Workspace) and copy.Parent then
			copy:Destroy()
		end
	end)
end

local function setGrade(downed: boolean)
	local g = grade
	if not g then
		local new = Instance.new("ColorCorrectionEffect")
		new.Name = "DownedGrade"
		new.Parent = Lighting
		grade = new
		g = new
	end
	local effect = g :: ColorCorrectionEffect
	TweenService:Create(effect, TweenInfo.new(D.screenFade), {
		Saturation = if downed then D.saturation else 0,
		Brightness = if downed then D.brightness else 0,
		TintColor = if downed then D.tint else Color3.new(1, 1, 1),
	}):Play()
end

local function step(body: Model)
	local downed = Health.isDowned(body)
	local seen = shown[body]
	if not downed and seen == nil then
		shown[body] = false
	elseif downed and seen ~= true then
		shown[body] = true
		-- Parts that arrive later (an accessory) stay hidden too.
		body.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = 1
			end
		end)
		if body == player.Character then
			-- Your own: the screen drains, and the death camera
			-- (SpectateController) pulls out to watch the body fall.
			setGrade(true)
		end
		if seen == false then
			task.spawn(fall, body) -- it waits (the buckle) before the tip
		else
			hide(body) -- went down before we saw it (a late join): no replayed fall
		end
	end
end

-- The fall for any body (the final-kill replay's copy of the victim); its
-- falling copy goes in `parent` (the replay's folder, so it goes with it).
function DeathFxController.playFall(body: Model, parent: Instance?)
	task.spawn(fall, body, parent)
end

-- The grey goes when you start watching someone else (SpectateController).
function DeathFxController.clearGrade()
	setGrade(false)
end

function DeathFxController.start()
	player.CharacterAdded:Connect(function()
		setGrade(false)
	end)
	while true do
		task.wait(TICK)
		for _, p in Players:GetPlayers() do
			local c = p.Character
			if c then
				step(c)
			end
		end
		local dummies = Workspace:FindFirstChild("Dummies")
		if dummies then
			for _, m in dummies:GetChildren() do
				if m:IsA("Model") then
					step(m)
				end
			end
		end
	end
end

return DeathFxController
