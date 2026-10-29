--!strict
-- The Firewall for everyone (vault/01 Design/Abilities/Firewall.md → Look):
-- each piece the server builds (workspace.ModWalls, Services/ModWalls) is
-- dressed as a tall curtain of fire with smoke off the top, so it blocks
-- sight: the Molly's Blender-rendered flame and smoke flipbooks (the two
-- fires match), embers, a warm light along it, a scorch line on the floor.
-- The newest piece flares while the wall races forward. At ExpiresAt the
-- flames sink and die out over ~0.5 s (the server removes the pieces just
-- after). Also: the heat haze while you stand in a wall, the flame in a
-- Firewall caster's hand for others, and the wall's sounds.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Firewall = require(ReplicatedStorage.Shared.Mods.Firewall)
local ModSounds = require(ReplicatedStorage.Shared.Config.ModSounds)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local ModAudio = require(script.Parent.ModAudio)
local ModVfx = require(script.Parent.ModVfx)

local WallFx = {}

local S = ModSounds.Firewall
local player = Players.LocalPlayer

local FADE = 0.5 -- the flames sink over this at the end
local FRONT_TIME = 0.35 -- the newest piece flares this long
local SCORCH_LINGER = 3
local LOW_RATE = 18 -- flames per second per piece (dense enough to hide what's behind)
local TALL_RATE = 6
local SMOKE_RATE = 8
local HAZE_IN = TweenInfo.new(0.15)
local HAZE_OUT = TweenInfo.new(0.4)

type Piece = {
	part: BasePart,
	flames: ParticleEmitter,
	tall: ParticleEmitter,
	smoke: ParticleEmitter,
	embers: ParticleEmitter,
	light: PointLight?,
	born: number, -- os.clock()
	scorched: boolean,
}

local pieces: { [BasePart]: Piece } = {}
-- One loop per wall (on its first piece), and its end sound.
type WallSound = { hum: ModAudio.Hum?, ended: boolean, at: Vector3 }
local wallSounds: { [number]: WallSound } = {}

local function curve(points: { number }): NumberSequence
	local keys = {}
	for i = 1, #points, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(points[i], points[i + 1]))
	end
	return NumberSequence.new(keys)
end

local function flames(part: BasePart, size: number, rate: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = VFX.MOLLY_FLAME_4x4
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	e.FlipbookMode = Enum.ParticleFlipbookMode.Loop
	e.FlipbookFramerate = NumberRange.new(20, 24)
	e.FlipbookStartRandom = true
	e.Shape = Enum.ParticleEmitterShape.Box -- the piece's box: the whole curtain
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Lifetime = NumberRange.new(0.6, 0.9)
	e.Speed = NumberRange.new(1, 3)
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(8, 8)
	e.Size = curve({ 0, size * 0.8, 0.35, size * 1.25, 1, size })
	e.Transparency = curve({ 0, 0.6, 0.15, 0.05, 0.75, 0.25, 1, 1 })
	-- Low glow: many sprites overlap in a wall, and additive light would
	-- wash the curtain out to white.
	e.LightEmission = 0.15
	e.LightInfluence = 0
	e.Brightness = 1
	e.Rate = rate
	e.LockedToPart = false
	e.Parent = part
	return e
end

local function dress(part: BasePart)
	if pieces[part] then
		return
	end
	local h = part.Size.Y
	-- Dense low flames through the whole curtain, a taller layer, smoke above.
	local low = flames(part, 4, LOW_RATE)
	local tall = flames(part, 6.5, TALL_RATE)
	tall.Lifetime = NumberRange.new(0.7, 1.1)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = VFX.MOLLY_SMOKE_2x2
	smoke.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	smoke.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	smoke.Color = ColorSequence.new(Color3.fromHex("1E1C1B"))
	smoke.Shape = Enum.ParticleEmitterShape.Box
	smoke.Lifetime = NumberRange.new(1.6, 2.4)
	smoke.Speed = NumberRange.new(h * 0.5, h * 0.8)
	smoke.Acceleration = Vector3.new(0, 1.5, 0)
	smoke.Drag = 0.8
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.SpreadAngle = Vector2.new(15, 15)
	smoke.Size = curve({ 0, 3, 1, 7 })
	smoke.Transparency = curve({ 0, 1, 0.2, 0.3, 1, 1 })
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.LightInfluence = 0.6
	smoke.Rate = SMOKE_RATE
	smoke.Parent = part
	local embers = Instance.new("ParticleEmitter")
	embers.Texture = VFX.MOLLY_EMBER
	embers.Shape = Enum.ParticleEmitterShape.Box
	embers.Lifetime = NumberRange.new(1, 1.8)
	embers.Speed = NumberRange.new(3, 7)
	embers.Acceleration = Vector3.new(0, 2, 0)
	embers.EmissionDirection = Enum.NormalId.Top
	embers.SpreadAngle = Vector2.new(30, 30)
	embers.Size = curve({ 0, 0.14, 1, 0.05 })
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 214, 120), Color3.fromRGB(200, 50, 20))
	embers.LightEmission = 1
	embers.LightInfluence = 0
	embers.Rate = 6
	embers.Parent = part
	-- A warm light on every other piece.
	local light: PointLight? = nil
	local index = part:GetAttribute("Index")
	if typeof(index) == "number" and index % 2 == 1 then
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 150, 70)
		l.Range = 14
		l.Brightness = 2.5
		l.Shadows = false
		l.Parent = part
		light = l
	end
	pieces[part] = {
		part = part,
		flames = low,
		tall = tall,
		smoke = smoke,
		embers = embers,
		light = light,
		born = os.clock(),
		scorched = false,
	}
	-- The wall's sound: a loop on its first piece, the rush as it builds.
	local wallId = part:GetAttribute("WallId")
	if typeof(wallId) == "number" and not wallSounds[wallId] then
		ModAudio.play(S.build, part.Position)
		wallSounds[wallId] = { hum = ModAudio.hum(S.loop, part), ended = false, at = part.Position }
	end
end

local function forget(part: BasePart)
	pieces[part] = nil
end

-- The heat haze while we stand in a wall (and the pass-through sizzle).
local haze: ColorCorrectionEffect? = nil
local hazeBlur: BlurEffect? = nil
local insideNow = false

local function setHaze(on: boolean)
	if not haze then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "FirewallHaze"
		cc.Enabled = true
		cc.Parent = Lighting
		haze = cc
		local blur = Instance.new("BlurEffect")
		blur.Name = "FirewallHazeBlur"
		blur.Size = 0
		blur.Parent = Lighting
		hazeBlur = blur
	end
	local cc = haze :: ColorCorrectionEffect
	local blur = hazeBlur :: BlurEffect
	local info = if on then HAZE_IN else HAZE_OUT
	TweenService:Create(cc, info, {
		TintColor = if on then Color3.fromRGB(255, 165, 110) else Color3.new(1, 1, 1),
		Brightness = if on then -0.05 else 0,
		Contrast = if on then 0.1 else 0,
		Saturation = if on then 0.15 else 0,
	}):Play()
	TweenService:Create(blur, info, { Size = if on then 6 else 0 }):Play()
end

-- The flame in a Firewall caster's free hand, for other players.
local handFlames: { [Model]: ParticleEmitter } = setmetatable({}, { __mode = "k" }) :: any

local function firewallHeld(other: Player): boolean
	local held = other:GetAttribute("ModHeld")
	if typeof(held) ~= "number" or held == 0 then
		return false
	end
	return other:GetAttribute("Mod" .. held .. "Id") == "Firewall"
end

local function stepHands()
	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		local character = other.Character
		local hand = character and character:FindFirstChild("LeftHand")
		if not character or not hand or not hand:IsA("BasePart") then
			continue
		end
		local on = firewallHeld(other)
		local e = handFlames[character]
		if on and (not e or e.Parent ~= hand) then
			local made = flames(hand, 0.9, 0)
			made.Shape = Enum.ParticleEmitterShape.Sphere
			made.LockedToPart = true
			made.Speed = NumberRange.new(0.5, 1.5)
			handFlames[character] = made
			e = made
		end
		if e then
			e.Rate = if on then 26 else 0
		end
	end
end

-- Per frame (ModFxController.update).
function WallFx.step()
	local now = os.clock()
	local serverNow = Workspace:GetServerTimeNow()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local inside = false
	local live: { [number]: boolean } = {}
	for part, p in pieces do
		if not part.Parent then
			forget(part)
			continue
		end
		local wallId = part:GetAttribute("WallId")
		if typeof(wallId) == "number" then
			live[wallId] = true
		end
		-- The newest piece flares as the wall races on.
		local age = now - p.born
		local front = if age < FRONT_TIME then 1 + 1.5 * (1 - age / FRONT_TIME) else 1
		-- The end: flames sink over FADE after ExpiresAt.
		local expires = part:GetAttribute("ExpiresAt")
		local k = 1
		if typeof(expires) == "number" then
			k = math.clamp((expires - serverNow) / FADE, 0, 1)
			if not p.scorched then
				p.scorched = true
				ModVfx.quad({
					texture = VFX.MOLLY_SCORCH,
					cframe = part.CFrame * CFrame.new(0, -part.Size.Y / 2 + 0.05, 0),
					from = math.max(part.Size.Z, part.Size.X) * 1.6,
					color = Color3.new(1, 1, 1),
					life = math.max(expires - serverNow, 0) + SCORCH_LINGER,
					alpha0 = 0.15,
					hold = true,
				})
			end
			if typeof(wallId) == "number" then
				local ws = wallSounds[wallId]
				if ws and not ws.ended and expires - serverNow <= FADE then
					ws.ended = true
					ModAudio.stopHum(ws.hum)
					ws.hum = nil
					ModAudio.play(S.ending, ws.at)
				end
			end
		end
		p.flames.Rate = LOW_RATE * k * front
		p.tall.Rate = TALL_RATE * k * front
		p.smoke.Rate = SMOKE_RATE * k
		p.embers.Rate = 6 * k * front
		local light = p.light
		if light then
			light.Brightness = (2.2 + 0.5 * math.noise(now * 6, part.Position.X)) * k
		end
		if
			root
			and root:IsA("BasePart")
			and k > 0
			and Firewall.inside(part, root.Position, 0.8)
		then
			inside = true
		end
	end
	for wallId, ws in wallSounds do
		if not live[wallId] then
			ModAudio.stopHum(ws.hum)
			wallSounds[wallId] = nil
		end
	end
	if inside ~= insideNow then
		insideNow = inside
		setHaze(inside)
		if inside then
			ModAudio.play(S.passThrough)
		end
	end
	stepHands()
end

function WallFx.start()
	local function watch(folder: Instance)
		folder.ChildAdded:Connect(function(child)
			if child:IsA("BasePart") then
				dress(child)
			end
		end)
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				dress(child)
			end
		end
	end
	local existing = Workspace:FindFirstChild("ModWalls")
	if existing then
		watch(existing)
	end
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "ModWalls" then
			watch(child)
		end
	end)
end

return WallFx
