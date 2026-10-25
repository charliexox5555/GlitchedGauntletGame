--!strict
-- Shot feedback in the Style B neon look (Gunplay.md §5): muzzle flash,
-- tracers, impact sparks, the Ray Trace beam, gun sounds, other players'
-- shots, and the pixel-dissolve on death (no blood).

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local EffectsController = {}

local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local PIXEL_TEXTURE = "rbxasset://textures/particles/SquareParticle.png"
local NEON = Color3.fromHex("00E5FF")

local folder: Folder? = nil

local function effectsFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "Effects"
	f.Parent = Workspace
	folder = f
	return f
end

local function fxPart(size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Parent = effectsFolder()
	return p
end

-- Sounds ---------------------------------------------------------------------

function EffectsController.playSound(id: string, parent: Instance?, volume: number?, pitch: number?)
	if id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.PlaybackSpeed = pitch or 1
	s.RollOffMaxDistance = 300
	s.Parent = parent or effectsFolder()
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	Debris:AddItem(s, 6)
end

-- Plays a sound at a world position (for other players' shots and impacts).
function EffectsController.playSoundAt(
	id: string,
	position: Vector3,
	volume: number?,
	pitch: number?
)
	local holder = Instance.new("Attachment")
	holder.WorldPosition = position
	holder.Parent = Workspace.Terrain
	EffectsController.playSound(id, holder, volume, pitch)
	Debris:AddItem(holder, 6)
end

-- Visuals --------------------------------------------------------------------

function EffectsController.muzzleFlash(cf: CFrame, color: Color3, scale: number?)
	local s = scale or 1
	local flash = fxPart(Vector3.new(0.35, 0.35, 0.6) * s, cf * CFrame.new(0, 0, -0.25 * s), color)
	flash.Shape = Enum.PartType.Ball
	flash.Transparency = 0.15
	local core = fxPart(
		Vector3.new(0.12, 0.12, 0.9) * s,
		cf * CFrame.new(0, 0, -0.4 * s),
		Color3.new(1, 1, 1)
	)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 4
	light.Range = 8
	light.Parent = flash
	Debris:AddItem(flash, 0.05)
	Debris:AddItem(core, 0.035)
end

function EffectsController.tracer(
	from: Vector3,
	to: Vector3,
	color: Color3,
	width: number?,
	life: number?
)
	local dist = (to - from).Magnitude
	if dist < 1 then
		return
	end
	local w = width or 0.07
	local t = life or 0.07
	local p = fxPart(Vector3.new(w, w, dist), CFrame.lookAt((from + to) / 2, to), color)
	p.Transparency = 0.1
	TweenService
		:Create(
			p,
			TweenInfo.new(t),
			{ Transparency = 1, Size = Vector3.new(w * 0.3, w * 0.3, dist) }
		)
		:Play()
	Debris:AddItem(p, t + 0.05)
end

-- Thick lingering beam (Ray Trace).
function EffectsController.beam(from: Vector3, to: Vector3, color: Color3)
	EffectsController.tracer(from, to, color, 0.35, 0.45)
	EffectsController.tracer(from, to, Color3.new(1, 1, 1), 0.1, 0.2)
end

function EffectsController.impact(position: Vector3, normal: Vector3, color: Color3?)
	local c = color or NEON
	local att = Instance.new("Attachment")
	att.WorldCFrame = CFrame.lookAt(position, position + normal)
	att.Parent = Workspace.Terrain
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK_TEXTURE
	sparks.Color = ColorSequence.new(c)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Lifetime = NumberRange.new(0.12, 0.25)
	sparks.Speed = NumberRange.new(8, 16)
	sparks.SpreadAngle = Vector2.new(40, 40)
	sparks.EmissionDirection = Enum.NormalId.Front
	sparks.Drag = 6
	sparks.Enabled = false
	sparks.Parent = att
	sparks:Emit(8)
	-- A small glowing square where the shot landed.
	local mark = fxPart(
		Vector3.new(0.18, 0.18, 0.02),
		CFrame.lookAt(position + normal * 0.02, position + normal * 2),
		c
	)
	TweenService:Create(mark, TweenInfo.new(0.6), { Transparency = 1 }):Play()
	Debris:AddItem(mark, 0.65)
	Debris:AddItem(att, 0.5)
end

-- Enemies dissolve into neon pixels instead of ragdolling.
function EffectsController.dissolve(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local att = Instance.new("Attachment")
			att.WorldPosition = d.Position
			att.Parent = Workspace.Terrain
			local pixels = Instance.new("ParticleEmitter")
			pixels.Texture = PIXEL_TEXTURE
			pixels.Color = ColorSequence.new(NEON, Color3.fromHex("56607C"))
			pixels.LightEmission = 0.8
			pixels.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.18),
				NumberSequenceKeypoint.new(1, 0.05),
			})
			pixels.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			})
			pixels.Lifetime = NumberRange.new(0.5, 0.9)
			pixels.Speed = NumberRange.new(2, 6)
			pixels.SpreadAngle = Vector2.new(180, 180)
			pixels.Acceleration = Vector3.new(0, 6, 0)
			pixels.Enabled = false
			pixels.Parent = att
			pixels:Emit(math.clamp(math.floor(d.Size.Magnitude * 6), 4, 18))
			Debris:AddItem(att, 1.2)
			d.LocalTransparencyModifier = 1
		end
	end
end

-- Muzzle attachment of another player's world weapon.
local function worldMuzzle(character: Model?): Attachment?
	local weapon = character and character:FindFirstChild("WorldWeapon")
	local muzzle = weapon and weapon:FindFirstChild("Muzzle", true)
	if muzzle and muzzle:IsA("Attachment") then
		return muzzle
	end
	return nil
end

local function onShotFx(shooter: Player, weaponId: string, origin: Vector3, ends: { Vector3 })
	local config = Weapons.get(weaponId)
	if not config then
		return
	end
	local muzzle = worldMuzzle(shooter.Character)
	local from = if muzzle then muzzle.WorldPosition else origin
	if config.melee then
		EffectsController.playSoundAt(config.sounds.fire, from, 0.6)
		return
	end
	if muzzle then
		EffectsController.muzzleFlash(muzzle.WorldCFrame, config.tracerColor, 0.8)
	end
	EffectsController.playSoundAt(config.sounds.fire, from, (config.sounds.fireVolume or 0.7) * 0.9)
	for _, e in ends do
		if config.fireMode == "Charge" then
			EffectsController.beam(from, e, config.tracerColor)
		elseif not config.suppressed then
			EffectsController.tracer(from, e, config.tracerColor)
		end
	end
end

local function onKilled(victim: Model?)
	if victim and victim.Parent then
		EffectsController.dissolve(victim)
	end
end

function EffectsController.start()
	effectsFolder()
	Net.unreliable("ShotFx").OnClientEvent:Connect(onShotFx)
	Net.event("Killed").OnClientEvent:Connect(onKilled)
end

return EffectsController
