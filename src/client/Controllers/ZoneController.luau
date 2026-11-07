--!strict
-- The sudden-death circle as you see it (vault/05 Production/Match Structure
-- Revamp.md): a glitch-storm wall that closes in, a tint on your screen and a
-- warning tick while you're outside. The server owns the circle and the
-- damage (ZoneService); this only reads shared/Zone and draws.
--
-- The wall is a ring of Beams between attachments on one anchored part (a
-- beam's width follows its attachments' up axis, so plain attachments stand
-- it upright). Each segment shows one repeat of the tiling texture, so the
-- number of segments in use follows the circle's size (Config/Juice
-- ZONE.tile): the ring is built once at the most segments, and the last one
-- in use closes the loop back to the first.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Juice = require(ReplicatedStorage.Shared.Config.Juice)
local VfxTextures = require(ReplicatedStorage.Shared.Config.VfxTextures)
local Zone = require(ReplicatedStorage.Shared.Zone)

local UiSound = require(script.Parent.Parent.Util.UiSound)

local ZoneController = {}

local Z = Juice.ZONE
local player = Players.LocalPlayer

type Segment = { a0: Attachment, storm: Beam, glitch: Beam }

local holder: Part? = nil
local segments: { Segment } = {}
local inUse = 0 -- segments drawn now
local current: Zone.State? = nil -- the circle, read when the server changes it
local tint: ColorCorrectionEffect? = nil
local tintTween: Tween? = nil
local wasOutside = false
local nextWarn = 0
local nextFlicker = 0
local rng = Random.new()

local function beam(
	parent: Instance,
	a0: Attachment,
	a1: Attachment,
	texture: string,
	color: Color3
): Beam
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.FaceCamera = false
	b.Segments = 1
	b.Width0 = Z.height
	b.Width1 = Z.height
	b.Texture = texture
	b.TextureMode = Enum.TextureMode.Stretch
	b.TextureLength = 1 -- one repeat per segment
	b.Color = ColorSequence.new(color)
	b.LightEmission = 0.6
	b.LightInfluence = 0
	b.Brightness = 2.2
	b.Parent = parent
	return b
end

local function clearWall()
	if holder then
		holder:Destroy()
		holder = nil
	end
	table.clear(segments)
end

-- Builds the ring with `count` segments (all hidden until `use`).
local function buildWall(count: number)
	clearWall()
	inUse = 0
	local part = Instance.new("Part")
	part.Name = "ZoneWall"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.CFrame = CFrame.identity
	local attachments: { Attachment } = {}
	for i = 1, count do
		local a = Instance.new("Attachment")
		a.Parent = part
		attachments[i] = a
	end
	for i = 1, count do
		local a0, a1 = attachments[i], attachments[i % count + 1]
		local storm = beam(part, a0, a1, VfxTextures.ZONE_WALL, Z.color)
		storm.TextureSpeed = Z.speed
		storm.Transparency = NumberSequence.new(Z.transparency)
		local glitch = beam(part, a0, a1, VfxTextures.ZONE_GLITCH, Z.glitchColor)
		glitch.TextureSpeed = Z.glitchSpeed
		glitch.LightEmission = 1
		storm.Enabled = false
		glitch.Enabled = false
		table.insert(segments, { a0 = a0, storm = storm, glitch = glitch })
	end
	part.Parent = workspace
	holder = part
end

local function setTint(on: boolean)
	local effect = tint
	if not effect then
		local e = Instance.new("ColorCorrectionEffect")
		e.Name = "ZoneTint"
		e.TintColor = Color3.new(1, 1, 1)
		e.Parent = Lighting
		tint = e
		effect = e
	end
	if tintTween then
		tintTween:Cancel()
	end
	local goal = if on
		then { TintColor = Z.tint, Saturation = -0.15 }
		else { TintColor = Color3.new(1, 1, 1), Saturation = 0 }
	local tw = TweenService:Create(effect :: ColorCorrectionEffect, TweenInfo.new(Z.tintTime), goal)
	tintTween = tw
	tw:Play()
end

local function myRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Draws the first `count` segments, the last one closing back to the first.
local function use(count: number)
	if count == inUse then
		return
	end
	for i, seg in segments do
		local on = i <= count
		seg.storm.Enabled = on
		seg.glitch.Enabled = on
		if on then
			local nextA = segments[i % count + 1].a0
			seg.storm.Attachment1 = nextA
			seg.glitch.Attachment1 = nextA
		end
	end
	inUse = count
end

local function step()
	local state = current
	if not state then
		if holder then
			clearWall()
		end
		if wasOutside then
			wasOutside = false
			setTint(false)
		end
		return
	end
	local now = workspace:GetServerTimeNow()
	local radius = Zone.radiusAt(state, now)
	local count =
		math.clamp(math.round(math.pi * 2 * radius / Z.tile), Z.minSegments, Z.maxSegments)
	if #segments ~= Z.maxSegments then
		buildWall(Z.maxSegments)
	end
	use(count)
	-- Place the ring: attachments around the circle at the wall's mid-height.
	local y = state.centre.Y - Z.below + Z.height / 2
	for i = 1, count do
		local seg = segments[i]
		local angle = (i - 1) / count * math.pi * 2
		seg.a0.Position = Vector3.new(
			state.centre.X + math.cos(angle) * radius,
			y,
			state.centre.Z + math.sin(angle) * radius
		)
	end
	-- The glitch layer flickers.
	if os.clock() >= nextFlicker then
		nextFlicker = os.clock() + Z.glitchFlicker
		for i = 1, count do
			segments[i].glitch.Transparency =
				NumberSequence.new(if rng:NextNumber() < 0.35 then 1 else rng:NextNumber(0.1, 0.5))
		end
	end
	-- You, outside: tint and a warning tick.
	local root = myRoot()
	local outside = root ~= nil and Zone.outside(state, root.Position, now) > 0
	if outside ~= wasOutside then
		wasOutside = outside
		setTint(outside)
	end
	if outside and os.clock() >= nextWarn then
		nextWarn = os.clock() + Z.warnEvery
		UiSound.play("ZoneWarn")
	end
end

function ZoneController.start()
	current = Zone.read()
	Zone.changed():Connect(function()
		current = Zone.read()
	end)
	RunService.RenderStepped:Connect(step)
end

return ZoneController
