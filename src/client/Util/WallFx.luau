--!strict
-- The Firewall for everyone (vault/01 Design/Abilities/Firewall.md → Look):
-- each piece the server builds (workspace.ModWalls, Services/ModWalls) is
-- dressed as a tall, opaque curtain of fire, so it blocks sight. The
-- stylized look (Util/FireKit, the Blender FireVFX meshes): an orange sheet
-- with a jagged flame top, bright yellow licks low on both faces, and three
-- flame tongues dancing on top (two orange, a taller red one) that flicker,
-- lean and swap shapes; each piece rises out of the floor with a little
-- overshoot as the wall races on, and is turned at random so the pieces
-- don't repeat. A few embers, a warm light along it, a scorch line on the
-- floor. The newest piece flares while the wall races forward. At ExpiresAt
-- the flames sink into the floor over ~0.5 s (the server removes the pieces
-- just after). Also: the heat haze while you stand in a wall, the flame in a
-- Firewall caster's hand for others, and the wall's sounds.
--
-- Until the hub has installed ReplicatedStorage.Abilities.FireVFX, pieces
-- keep the old look: the Molly's Blender-rendered flame and smoke
-- flipbooks.
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

local FireKit = require(script.Parent.FireKit)
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

-- The mesh wall (FireKit). Sizes are for a 10-stud wall, 1.5 thick, 4-stud
-- pieces (Config/Mods Firewall L1); a piece scales to its own size.
local MESH_HEIGHT, MESH_THICK, MESH_SEGMENT = 10, 1.5, 4
local MESH_EMBER_RATE = 3 -- embers are an accent only
local ANIM_GAP = 1 / 30 -- the flames move at most this often
local ANIM_RANGE = 220 -- pieces farther than this from the camera hold still
-- The flames on top of each piece: along (studs from the middle), base
-- height, height, width scale, and whether it's the tall red one.
type Slot = { along: number, y: number, h: number, w: number, tip: boolean }
local SLOTS: { Slot } = {
	{ along = -1.25, y = 7.0, h = 2.8, w = 2.4, tip = false },
	{ along = 0.15, y = 6.8, h = 3.7, w = 1.9, tip = true },
	{ along = 1.35, y = 7.2, h = 2.5, w = 2.2, tip = false },
}
local SLOT_DEPTH = 1.8 -- tongue depth scale: as thin as the sheet's top

type MeshWall = {
	sheet: BasePart,
	core: BasePart,
	flames: { FireKit.Flame },
	turn: number, -- 0 or pi
	settled: boolean, -- sheet and core are at full size (only the flames move)
}

type Piece = {
	part: BasePart,
	flames: ParticleEmitter?, -- the particle look only
	tall: ParticleEmitter?,
	smoke: ParticleEmitter?,
	embers: ParticleEmitter,
	light: PointLight?,
	mesh: MeshWall?,
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

-- The mesh wall for a piece (nil when the kit isn't installed).
local function meshWall(part: BasePart): MeshWall?
	if not FireKit.available() then
		return nil
	end
	local sheet = FireKit.take("Sheet")
	local core = FireKit.take("Core")
	if not sheet or not core then
		return nil
	end
	sheet.Color = FireKit.SHEET
	core.Color = FireKit.CORE
	local now = os.clock()
	local made: { FireKit.Flame } = {}
	for _, slot in SLOTS do
		local f = FireKit.flame(if slot.tip then FireKit.TIP else FireKit.BODY, now)
		if f then
			table.insert(made, f)
		end
	end
	-- Turned at random (the sheet's ends match either way), so neighbours differ.
	local index = part:GetAttribute("Index")
	local odd = typeof(index) == "number" and index % 2 == 1
	return {
		sheet = sheet,
		core = core,
		flames = made,
		turn = if odd ~= (math.random() < 0.3) then math.pi else 0,
		settled = false,
	}
end

local function dropMesh(m: MeshWall)
	FireKit.give("Sheet", m.sheet)
	FireKit.give("Core", m.core)
	for _, f in m.flames do
		FireKit.drop(f)
	end
	table.clear(m.flames)
end

-- Places a piece's mesh wall: `grow` (rising out of the floor, sinking at
-- the end) scales its height, `front` stretches the flames on the newest piece.
local function placeMesh(
	p: Piece,
	m: MeshWall,
	now: number,
	grow: number,
	front: number,
	all: boolean
)
	local part = p.part
	local size = part.Size
	local anchor = part.CFrame * CFrame.new(0, -size.Y / 2, 0) * CFrame.Angles(0, m.turn, 0)
	local hk = size.Y / MESH_HEIGHT
	local along = size.Z / MESH_SEGMENT
	local across = size.X / MESH_THICK
	if all then
		local body = Vector3.new(across, math.max(hk * grow, 0.02), along)
		FireKit.place(m.sheet, "Sheet", anchor, body)
		FireKit.place(m.core, "Core", anchor, body)
	end
	for i, f in m.flames do
		local slot = SLOTS[i]
		FireKit.swap(f, now)
		local h, lean = FireKit.flicker(f.seed, now, 1)
		h *= front
		local w = slot.w * along / math.sqrt(h)
		local at = anchor
			* CFrame.new(0, slot.y * hk * grow, slot.along * along)
			* CFrame.Angles(lean, f.turn, 0)
		FireKit.place(
			f.part,
			f.name,
			at,
			Vector3.new(SLOT_DEPTH * across, math.max(slot.h * hk * h * grow, 0.02), w)
		)
	end
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
	local mesh = meshWall(part)
	local low: ParticleEmitter?, tall: ParticleEmitter?, smoke: ParticleEmitter? = nil, nil, nil
	if not mesh then
		-- The particle look: dense low flames through the whole curtain, a
		-- taller layer, smoke above.
		low = flames(part, 4, LOW_RATE)
		local t = flames(part, 6.5, TALL_RATE)
		t.Lifetime = NumberRange.new(0.7, 1.1)
		tall = t
		local e = Instance.new("ParticleEmitter")
		e.Texture = VFX.MOLLY_SMOKE_2x2
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		e.Color = ColorSequence.new(Color3.fromHex("1E1C1B"))
		e.Shape = Enum.ParticleEmitterShape.Box
		e.Lifetime = NumberRange.new(1.6, 2.4)
		e.Speed = NumberRange.new(h * 0.5, h * 0.8)
		e.Acceleration = Vector3.new(0, 1.5, 0)
		e.Drag = 0.8
		e.EmissionDirection = Enum.NormalId.Top
		e.SpreadAngle = Vector2.new(15, 15)
		e.Size = curve({ 0, 3, 1, 7 })
		e.Transparency = curve({ 0, 1, 0.2, 0.3, 1, 1 })
		e.Rotation = NumberRange.new(0, 360)
		e.LightInfluence = 0.6
		e.Rate = SMOKE_RATE
		e.Parent = part
		smoke = e
	end
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
	embers.Rate = if mesh then MESH_EMBER_RATE else 6
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
	local piece: Piece = {
		part = part,
		flames = low,
		tall = tall,
		smoke = smoke,
		embers = embers,
		light = light,
		mesh = mesh,
		born = os.clock(),
		scorched = false,
	}
	pieces[part] = piece
	if mesh then
		placeMesh(piece, mesh, piece.born, 0.02, 1, true)
	end
	sound(part, kind)
end

local function forget(part: BasePart)
	local p = pieces[part]
	pieces[part] = nil
	local m = p and p.mesh
	if p and m then
		p.mesh = nil
		dropMesh(m)
	end
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

-- A piece rising out of the floor: 0 -> a little over 1 -> 1 over FRONT_TIME.
local function rise(age: number): number
	local t = math.clamp(age / FRONT_TIME, 0, 1)
	local back = 1.7
	local u = t - 1
	return math.max(1 + (back + 1) * u * u * u + back * u * u, 0.02)
end

local lastAnim = 0

-- Per frame (ModFxController.update).
function WallFx.step()
	local now = os.clock()
	local serverNow = Workspace:GetServerTimeNow()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local at = if root and root:IsA("BasePart") then root.Position else nil
	local inside: string? = nil
	local animate = now - lastAnim >= ANIM_GAP
	if animate then
		lastAnim = now
	end
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else nil
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
		local m = p.mesh
		if m then
			p.embers.Rate = MESH_EMBER_RATE * k * front
			if k <= 0 then
				-- Sunk: back to the pools (the server removes the piece next).
				p.mesh = nil
				dropMesh(m)
			else
				local growing = age < FRONT_TIME or k < 1
				local near = not eye or (eye - part.Position).Magnitude < ANIM_RANGE
				if growing or (animate and near) then
					local grow = rise(age) * k
					-- The flames flare a little less than the particles did.
					placeMesh(p, m, now, grow, 1 + (front - 1) * 0.25, growing or not m.settled)
					m.settled = not growing
				end
			end
		else
			local low, tall, smoke = p.flames, p.tall, p.smoke
			if low and tall and smoke then
				low.Rate = LOW_RATE * k * front
				tall.Rate = TALL_RATE * k * front
				smoke.Rate = SMOKE_RATE * k
			end
			p.embers.Rate = 6 * k * front
		end
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
	FireKit.flush()
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
