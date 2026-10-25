--!strict
-- First-person viewmodel: a scaled copy of the equipped gun in front of the
-- camera, simple arms from the shoulders to RightGrip / LeftGrip, and the
-- gun's own Blender animations (fire, reload) on its Motor6D rig.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Spring = require(ReplicatedStorage.Shared.Util.Spring)
local Types = require(ReplicatedStorage.Shared.Types)
local VM = require(ReplicatedStorage.Shared.Config.Viewmodel)

local GunAnimator = require(script.Parent.Parent.Util.GunAnimator)
local MovementController = require(script.Parent.MovementController)

type WeaponConfig = Types.WeaponConfig

local ViewmodelController = {}

local player = Players.LocalPlayer

type Arm = { upper: Part, hand: Part, cuff: Part }

local model: Model? = nil
local handle: BasePart? = nil
local animator: GunAnimator.GunAnimator? = nil
local config: WeaponConfig? = nil
local rightGrip: Attachment? = nil
local leftGrip: Attachment? = nil
local muzzle: Attachment? = nil
local aimRel = Vector3.zero
local arms: { Arm } = {}

local adsAlpha = 0
local sprintAlpha = 0
local equipStart = 0
local equipTime = 0.3
local hidden = false
local bobTime = 0
local lastCamera: CFrame? = nil

local sway = Spring.new(VM.SWAY_STIFFNESS, VM.SWAY_DAMPING)
local recoil = Spring.new(VM.RECOIL_STIFFNESS, VM.RECOIL_DAMPING)

local function weaponsFolder(): Instance?
	return ReplicatedStorage:FindFirstChild("Weapons")
end

local function skinColor(): Color3
	local character = player.Character
	local hand = character and character:FindFirstChild("RightHand")
	if hand and hand:IsA("BasePart") then
		return hand.Color
	end
	return Color3.fromRGB(234, 184, 146)
end

local function armPart(name: string, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = material
	p.Color = color
	p.Size = Vector3.one * 0.2
	p.Parent = parent
	return p
end

local function setVisible(visible: boolean)
	local m = model
	if not m then
		return
	end
	local modifier = if visible then 0 else 1
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = modifier
		end
	end
end

function ViewmodelController.unequip()
	if model then
		model:Destroy()
	end
	model = nil
	handle = nil
	animator = nil
	config = nil
	arms = {}
end

function ViewmodelController.equip(weapon: WeaponConfig)
	ViewmodelController.unequip()
	local folder = weaponsFolder()
	local template = folder and folder:FindFirstChild(weapon.id)
	local cam = Workspace.CurrentCamera
	if not template or not template:IsA("Model") or not cam then
		warn("[Viewmodel] no model for " .. weapon.id)
		return
	end
	local m = template:Clone()
	m.Name = "Viewmodel"
	m:ScaleTo(VM.SCALE)
	local h = m.PrimaryPart :: BasePart
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d == h
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end

	-- Where the sight is relative to the grip, at rest (for ADS alignment).
	local aim = m:FindFirstChild("AimPoint", true)
	aimRel = if aim and aim:IsA("Attachment")
		then h.CFrame:PointToObjectSpace(aim.WorldPosition)
		else Vector3.new(0, 0.3, 0)
	local rg = m:FindFirstChild("RightGrip", true)
	local lg = m:FindFirstChild("LeftGrip", true)
	local mz = m:FindFirstChild("Muzzle", true)
	rightGrip = if rg and rg:IsA("Attachment") then rg else nil
	leftGrip = if lg and lg:IsA("Attachment") then lg else nil
	muzzle = if mz and mz:IsA("Attachment") then mz else nil

	-- Arms.
	local skin = skinColor()
	arms = {}
	for _, side in { "Right", "Left" } do
		local upper = armPart(side .. "Sleeve", VM.SLEEVE_COLOR, Enum.Material.SmoothPlastic, m)
		local hand = armPart(side .. "Hand", skin, Enum.Material.SmoothPlastic, m)
		hand.Size = VM.HAND_SIZE
		-- Thin neon cuff where the sleeve meets the hand.
		local cuff = armPart(side .. "Cuff", VM.CUFF_COLOR, Enum.Material.Neon, m)
		cuff.Size = Vector3.new(VM.ARM_THICKNESS * 1.1, VM.ARM_THICKNESS * 1.1, 0.04)
		table.insert(arms, { upper = upper, hand = hand, cuff = cuff })
	end

	m.Parent = cam
	model = m
	handle = h
	config = weapon
	animator = GunAnimator.new(m, weapon.id, VM.SCALE)
	equipStart = os.clock()
	equipTime = weapon.equipTime
	hidden = false
	recoil.position = Vector3.zero
	recoil.velocity = Vector3.zero
end

function ViewmodelController.fire(kickScale: number)
	if animator then
		animator:play("Fire")
	end
	local up = if config then config.recoil.up else 1
	local k = math.clamp(up, 0.3, 4) * kickScale
	recoil:impulse(
		Vector3.new(
			VM.KICK_BACK * 40 * k,
			VM.KICK_ROTATE * 40 * k,
			(math.random() - 0.5) * VM.KICK_ROTATE * 20 * k
		)
	)
end

function ViewmodelController.reload(duration: number)
	if animator then
		animator:play("Reload", duration)
	end
end

function ViewmodelController.cancelReload()
	if animator and animator:isPlaying("Reload") then
		animator:stop()
	end
end

-- Melee swing uses the weapon's Fire clip.
function ViewmodelController.swing()
	if animator then
		animator:play("Fire")
	end
end

function ViewmodelController.setAds(alpha: number)
	adsAlpha = alpha
end

function ViewmodelController.setHidden(value: boolean)
	if hidden ~= value then
		hidden = value
		setVisible(not value)
	end
end

function ViewmodelController.muzzleCFrame(): CFrame?
	if muzzle then
		return muzzle.WorldCFrame
	end
	return nil
end

function ViewmodelController.isEquipped(): boolean
	return model ~= nil
end

local function placeArm(arm: Arm, shoulder: Vector3, grip: Vector3)
	local dist = (grip - shoulder).Magnitude
	arm.upper.Size = Vector3.new(VM.ARM_THICKNESS, VM.ARM_THICKNESS, math.max(dist, 0.05))
	arm.upper.CFrame = CFrame.lookAt((shoulder + grip) / 2, grip)
	arm.hand.CFrame = CFrame.lookAt(grip, grip + (grip - shoulder))
	arm.cuff.CFrame = arm.hand.CFrame * CFrame.new(0, 0, VM.HAND_SIZE.Z / 2)
end

local function ease(t: number): number
	-- Blend between linear and smoothstep.
	local s = t * t * (3 - 2 * t)
	return t + (s - t) * VM.ADS_EASE
end

local function update(dt: number)
	local cam = Workspace.CurrentCamera
	local h = handle
	local m = model
	local c = config
	if not cam or not h or not m or not c then
		lastCamera = cam and cam.CFrame
		return
	end
	local camCf = cam.CFrame

	-- Sway from how much the view turned this frame.
	if lastCamera then
		local delta = lastCamera:ToObjectSpace(camCf)
		local rx, ry = delta:ToEulerAnglesYXZ()
		local scale = VM.SWAY_AMOUNT * (1 - adsAlpha * (1 - VM.ADS_SWAY_SCALE))
		sway.target = Vector3.new(
			math.clamp(rx * scale * 4, -VM.SWAY_MAX, VM.SWAY_MAX),
			math.clamp(ry * scale * 4, -VM.SWAY_MAX, VM.SWAY_MAX),
			0
		)
	end
	lastCamera = camCf
	local s = sway:update(dt)
	sway.target = Vector3.zero
	local r = recoil:update(dt)

	-- Bob while walking on the ground.
	local state = MovementController.getState()
	local moving = state == "Walk" or state == "Sprint" or state == "Crouch"
	if moving then
		bobTime += dt * VM.BOB_SPEED * (if state == "Sprint" then 1.4 else 1)
	end
	local bobScale = (if moving then 1 else 0) * (1 - adsAlpha * 0.85)
	local bob = CFrame.new(
		math.sin(bobTime) * VM.BOB_AMOUNT.X * bobScale,
		-math.abs(math.cos(bobTime)) * VM.BOB_AMOUNT.Y * bobScale,
		0
	)

	local sprintTarget = if state == "Sprint" and adsAlpha < 0.1 then 1 else 0
	sprintAlpha += (sprintTarget - sprintAlpha) * (1 - math.exp(-12 * dt))

	local hip = CFrame.new(c.viewmodelOffset)
	local ads = CFrame.new(0, 0, -VM.ADS_DISTANCE) * CFrame.new(-aimRel)
	local base = hip:Lerp(ads, ease(adsAlpha))
	local equipT = math.clamp((os.clock() - equipStart) / math.max(equipTime, 0.05), 0, 1)
	local equip = VM.EQUIP_DROP:Lerp(CFrame.new(), ease(equipT))
	local sprint = CFrame.new():Lerp(VM.SPRINT_OFFSET, sprintAlpha)
	local swayCf = CFrame.Angles(s.X, s.Y, s.Y * 0.5)
	local recoilCf = CFrame.new(0, 0, r.X * 0.1) * CFrame.Angles(r.Y * 0.1, 0, r.Z * 0.1)

	h.CFrame = camCf * base * sprint * equip * bob * swayCf * recoilCf

	if animator then
		animator:update(dt)
	end

	-- Arms follow the grips (after the gun has moved).
	if not hidden then
		local rightShoulder = camCf:PointToWorldSpace(VM.SHOULDER_RIGHT)
		local leftShoulder = camCf:PointToWorldSpace(VM.SHOULDER_LEFT)
		if rightGrip and arms[1] then
			placeArm(arms[1], rightShoulder, rightGrip.WorldPosition)
		end
		if leftGrip and arms[2] then
			placeArm(arms[2], leftShoulder, leftGrip.WorldPosition)
		end
	end
end

function ViewmodelController.start()
	RunService:BindToRenderStep("GGViewmodel", Enum.RenderPriority.Camera.Value + 2, update)
	player.CharacterRemoving:Connect(function()
		ViewmodelController.unequip()
	end)
end

return ViewmodelController
