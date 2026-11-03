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
--
-- A piece marked WallKind "Frost" (the glitch path's ice wall) is dressed by
-- Util/FrostWallFx instead, with ice sounds (ModSounds.FirewallFrost), a
-- cold tint while you stand in it and a cold vapour in the caster's hand.
-- Walls of any length (20 to 60 studs) are a row of the same pieces; a
-- long wall gets a loop every HUM_EVERY pieces so its far end is heard.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Firewall = require(ReplicatedStorage.Shared.Mods.Firewall)
local ModSounds = require(ReplicatedStorage.Shared.Config.ModSounds)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local FrostWallFx = require(script.Parent.FrostWallFx)
local ModAudio = require(script.Parent.ModAudio)
local ModVfx = require(script.Parent.ModVfx)

local WallFx = {}

local SOUNDS: { [string]: typeof(ModSounds.Firewall) } =
	{ Fire = ModSounds.Firewall, Frost = ModSounds.FirewallFrost }
local player = Players.LocalPlayer

local FADE = 0.5 -- the flames sink over this at the end
local FRONT_TIME = 0.35 -- the newest piece flares this long
local SCORCH_LINGER = 3
local LOW_RATE = 18 -- flames per second per piece (dense enough to hide what's behind)
local TALL_RATE = 6
local SMOKE_RATE = 8
local HAZE_IN = TweenInfo.new(0.15)
local HAZE_OUT = TweenInfo.new(0.4)
local HUM_EVERY = 8 -- pieces (segment 4: a loop every 32 studs)
local CRACKLE_EVERY = 4 -- an ice wall crackles every this many pieces as it races on

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
-- Each wall's loops (one every HUM_EVERY pieces) and its end sound.
type WallSound = {
	kind: string,
	hums: { ModAudio.Hum },
	parts: { BasePart },
	ended: boolean,
	at: Vector3,
}
local wallSounds: { [number]: WallSound } = {}

local function kindOf(part: BasePart): string
	return if part:GetAttribute("WallKind") == "Frost" then "Frost" else "Fire"
end

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

-- The wall's sounds: the build as it starts (an ice wall crackles along its
-- length), a loop every HUM_EVERY pieces.
local function sound(part: BasePart, kind: string)
	local wallId = part:GetAttribute("WallId")
	local index = part:GetAttribute("Index")
	if typeof(wallId) ~= "number" or typeof(index) ~= "number" then
		return
	end
	local S = SOUNDS[kind]
	local ws = wallSounds[wallId]
	if not ws then
		ModAudio.play(S.build, part.Position)
		ws = { kind = kind, hums = {}, parts = {}, ended = false, at = part.Position }
		wallSounds[wallId] = ws
	elseif kind == "Frost" and (index - 1) % CRACKLE_EVERY == 0 then
		ModAudio.play(S.build, part.Position, 0.9 + 0.2 * math.random())
	end
	local w = ws :: WallSound
	table.insert(w.parts, part)
	if (index - 1) % HUM_EVERY == 0 and not w.ended then
		local hum = ModAudio.hum(S.loop, part)
		if hum then
			table.insert(w.hums, hum)
		end
	end
end

local function stopHums(ws: WallSound)
	for _, hum in ws.hums do
		ModAudio.stopHum(hum)
	end
	table.clear(ws.hums)
end

local function dress(part: BasePart)
	if pieces[part] then
		return
	end
	local kind = kindOf(part)
	if kind == "Frost" then
		if FrostWallFx.dress(part) then
			sound(part, kind)
		end
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
	sound(part, kind)
end

local function forget(part: BasePart)
	pieces[part] = nil
end

-- The heat haze while we stand in a wall (and the pass-through sizzle); a
-- cold tint in an ice wall.
local haze: ColorCorrectionEffect? = nil
local hazeBlur: BlurEffect? = nil
local insideNow: string? = nil

local function setHaze(kind: string?)
	local on = kind ~= nil
	local frost = kind == "Frost"
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
		TintColor = if frost
			then Color3.fromRGB(185, 220, 255)
			elseif on then Color3.fromRGB(255, 165, 110)
			else Color3.new(1, 1, 1),
		Brightness = if frost then 0.05 elseif on then -0.05 else 0,
		Contrast = if on then 0.1 else 0,
		Saturation = if frost then -0.25 elseif on then 0.15 else 0,
	}):Play()
	TweenService:Create(blur, info, { Size = if frost then 4 elseif on then 6 else 0 }):Play()
end

-- The flame in a Firewall caster's free hand, for other players (a cold
-- vapour for the ice wall).
type Hand = { emitter: ParticleEmitter, kind: string }
local hands: { [Model]: Hand } = setmetatable({}, { __mode = "k" }) :: any

-- "Fire" / "Frost" while `other` holds a Firewall, else nil.
local function firewallHeld(other: Player): string?
	local held = other:GetAttribute("ModHeld")
	if typeof(held) ~= "number" or held == 0 then
		return nil
	end
	if other:GetAttribute("Mod" .. held .. "Id") ~= "Firewall" then
		return nil
	end
	return if FrostWallFx.isFrost(other:GetAttribute("Mod" .. held .. "Level"))
		then "Frost"
		else "Fire"
end

local function coldHand(hand: BasePart): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = VFX.FROST_MIST_2x2
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.Color = ColorSequence.new(FrostWallFx.ICE)
	e.Lifetime = NumberRange.new(0.5, 0.8)
	e.Speed = NumberRange.new(0.3, 1)
	e.Acceleration = Vector3.new(0, -1.5, 0) -- cold vapour falls off the hand
	e.Size = curve({ 0, 0.5, 1, 1.4 })
	e.Transparency = curve({ 0, 0.4, 1, 1 })
	e.Rotation = NumberRange.new(0, 360)
	e.LightEmission = 0.3
	e.LightInfluence = 0.3
	e.LockedToPart = true
	e.Rate = 0
	e.Parent = hand
	return e
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
		local kind = firewallHeld(other)
		local h = hands[character]
		if kind and (not h or h.emitter.Parent ~= hand or h.kind ~= kind) then
			if h then
				h.emitter:Destroy()
			end
			local made: ParticleEmitter
			if kind == "Frost" then
				made = coldHand(hand)
			else
				made = flames(hand, 0.9, 0)
				made.Shape = Enum.ParticleEmitterShape.Sphere
				made.LockedToPart = true
				made.Speed = NumberRange.new(0.5, 1.5)
			end
			h = { emitter = made, kind = kind }
			hands[character] = h
		end
		if h then
			h.emitter.Rate = if kind then (if h.kind == "Frost" then 20 else 26) else 0
		end
	end
end

-- Per frame (ModFxController.update).
function WallFx.step()
	local now = os.clock()
	local serverNow = Workspace:GetServerTimeNow()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local at = if root and root:IsA("BasePart") then root.Position else nil
	local inside: string? = nil
	for part, p in pieces do
		if not part.Parent then
			forget(part)
			continue
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
		end
		p.flames.Rate = LOW_RATE * k * front
		p.tall.Rate = TALL_RATE * k * front
		p.smoke.Rate = SMOKE_RATE * k
		p.embers.Rate = 6 * k * front
		local light = p.light
		if light then
			light.Brightness = (2.2 + 0.5 * math.noise(now * 6, part.Position.X)) * k
		end
		if at and k > 0 and Firewall.inside(part, at, 0.8) then
			inside = "Fire"
		end
	end
	if FrostWallFx.step(now, serverNow, at) and not inside then
		inside = "Frost"
	end
	-- Sounds: the end as a wall's pieces start to go; gone with its pieces.
	for wallId, ws in wallSounds do
		local alive: BasePart? = nil
		for i = #ws.parts, 1, -1 do
			if ws.parts[i].Parent then
				alive = ws.parts[i]
			else
				table.remove(ws.parts, i)
			end
		end
		if not alive then
			stopHums(ws)
			wallSounds[wallId] = nil
			continue
		end
		local expires = (alive :: BasePart):GetAttribute("ExpiresAt")
		if not ws.ended and typeof(expires) == "number" and expires - serverNow <= FADE then
			ws.ended = true
			stopHums(ws)
			ModAudio.play(SOUNDS[ws.kind].ending, ws.at)
		end
	end
	if inside ~= insideNow then
		insideNow = inside
		setHaze(inside)
		if inside then
			ModAudio.play(SOUNDS[inside].passThrough)
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
