--!strict
-- The SURGE power pack opening (vault/01 Design/Loadout and Power Deck.md -> Power cases; owner 2026-11-26:
-- "instead of a case we will do like a card pack, and it rips open the card pack and looks cool"). Numbers in
-- Shared/Config/CaseOpening PACK. Client-side and cosmetic: the server has already rolled the power
-- (Services/ShopService); this only shows it. Util/CaseOpening.start hands a pack tier (Config/Crates `pack`) here,
-- so it has the same API:
--
--   local h = PackOpening.start(owner, crateTier, count) -- flies in front of your camera, waits
--   h:reveal(results, onDone)                            -- shakes, rips, the card
--   h:abort()                                            -- refused: it drops away
--
-- Yours only (nobody else sees it). Beats: the pack flies in over a dim backdrop and sways → shakes (TIER_SHAKES; the
-- tier glow comes up from the second-to-last) → strains for TIER_FX.hold with the riser → the top strip
-- (Top_Seal) tears off from its notch, hinging on its far end (the model's TopPivot attribute), sparks along the
-- tear, then flies away → the power card slides up out of the pack with its back to you, the empty pack drops away,
-- the card comes to the centre and flips to its face: the tier's stinger, flash, kick and sparks, a small name
-- plate under it → it holds, then drops into the Backpack. Several results play one pack after another.
-- The pack is ReplicatedStorage.Crates.PowerPack (tools/studio/BuildPack.luau): anchored parts placed every frame.

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Cfg = require(ReplicatedStorage.Shared.Config.CaseOpening)
local CrateLook = require(ReplicatedStorage.Shared.CrateLook)
local Skins = require(ReplicatedStorage.Shared.Config.Skins)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Vfx = require(ReplicatedStorage.Shared.Config.VfxTextures)
local PowerCardFace = require(script.Parent.PowerCardFace)

export type Result = { gun: string, line: string, tier: string, name: string, power: string? }
export type Handle = {
	reveal: (self: Handle, results: { Result }, onDone: (() -> ())?) -> boolean,
	abort: (self: Handle) -> (),
	isDead: (self: Handle) -> boolean,
}

local P = Cfg.PACK
local PackOpening = {}

local HEAVY = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy) -- Rubik
local BOLD = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold)
local PACK_HEIGHT = 2.4 -- studs: the template from tooth to tooth
local NOTCH_X, STRIP_Y = 0.85, 0.93 -- the tear runs from the notch (+X, your left) to the hinge (TopPivot)
local TEXT = Color3.fromHex("F4F6F9")

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end
local function quintOut(x: number): number
	local t = 1 - clamp01(x)
	return 1 - t * t * t * t * t
end
local function quadIn(x: number): number
	local t = clamp01(x)
	return t * t
end
local function backOut(x: number, k: number): number
	local t = clamp01(x) - 1
	return 1 + (k + 1) * t * t * t + k * t * t
end
local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function sound(spec: any, gain: number?, pitchMult: number?)
	if typeof(spec) ~= "table" or typeof(spec.id) ~= "string" then
		return
	end
	local snd = Instance.new("Sound")
	snd.SoundId = spec.id
	snd.Volume = spec.volume * Cfg.LOCAL_VOLUME * (gain or 1)
	snd.PlaybackSpeed = spec.pitch * (pitchMult or 1)
	if typeof(spec.start) == "number" and spec.start > 0 then
		snd.TimePosition = spec.start
	end
	snd.Parent = SoundService
	snd:Play()
	local cut = spec.cut
	if typeof(cut) == "number" then
		task.delay(cut, function()
			if snd.Parent then
				TweenService:Create(snd, TweenInfo.new(0.08), { Volume = 0 }):Play()
			end
		end)
	end
	Debris:AddItem(snd, 8)
end

local warmed = false
local function warm()
	if warmed then
		return
	end
	warmed = true
	task.spawn(function()
		local list: { Instance } = {}
		local function add(spec: any)
			if typeof(spec) == "table" and typeof(spec.id) == "string" then
				local snd = Instance.new("Sound")
				snd.SoundId = spec.id
				table.insert(list, snd)
			end
		end
		add(P.Rip)
		add(Cfg.RISER)
		add(Cfg.SOUNDS.Tease)
		add(Cfg.SOUNDS.LidBoom)
		add(Cfg.SOUNDS.Fly)
		add(Cfg.SOUNDS.Toss)
		for _, spec in Cfg.REVEAL do
			add(spec)
		end
		pcall(ContentProvider.PreloadAsync, ContentProvider, list)
		for _, inst in list do
			inst:Destroy()
		end
	end)
end

-- a short camera kick and FOV punch (as Util/CaseOpening)
local function kick(strength: number, fovPunch: number)
	local cam = workspace.CurrentCamera
	if not cam or strength <= 0 then
		return
	end
	local t0 = os.clock()
	local baseFov = cam.FieldOfView
	local name = "PackKick" .. tostring(t0)
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 2, function()
		local t = os.clock() - t0
		local env = math.max(0, 1 - t / 0.35)
		if env <= 0 then
			RunService:UnbindFromRenderStep(name)
			cam.FieldOfView = baseFov
			return
		end
		local s = strength * env
		cam.CFrame = cam.CFrame
			* CFrame.new(math.sin(t * 61) * s * 0.6, math.sin(t * 47 + 1) * s * 0.4, 0)
			* CFrame.Angles(0, 0, math.rad(math.sin(t * 53) * 1.2 * env))
		cam.FieldOfView = baseFov - fovPunch * math.sin(math.min(t / 0.35, 1) * math.pi) * env
	end)
end

local function screenGui(name: string, order: number): ScreenGui?
	local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return nil
	end
	local g = Instance.new("ScreenGui")
	g.Name = name
	g:SetAttribute("LobbyGui", true) -- the match client never clears it (src/client init: armed-zone cleanup)
	g.IgnoreGuiInset = true
	g.ScreenInsets = Enum.ScreenInsets.None
	g.DisplayOrder = order
	g.ResetOnSpawn = false
	g.Parent = pg
	return g
end

-- a quick full-screen flash in the tier colour
local function flash(color: Color3, strength: number)
	if strength <= 0 then
		return
	end
	local g = screenGui("PackFlash", 5)
	if not g then
		return
	end
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 1 - strength
	f.BorderSizePixel = 0
	f.Parent = g
	TweenService:Create(f, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	Debris:AddItem(g, 0.6)
end

local function part(name: string, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(0.1, 0.1, 0.1)
	p.Parent = parent
	return p
end

local function sparkEmitter(
	parent: Instance,
	color: Color3,
	speed: number,
	spread: number
): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = Vfx.SPARK
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = 0
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.09),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Lifetime = NumberRange.new(0.3, 0.65)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(spread, spread)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -7, 0)
	e.Drag = 2.5
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Parent = parent
	return e
end

-- the small name plate under the card: tier word in its colour, the power's name; on a band that fades out to
-- the sides (no box), popping from the centre
local function plate(name: string, tierName: string, color: Color3): (ScreenGui?, CanvasGroup?)
	local g = screenGui("PackPlate", 20) -- over the lobby HUD (PLAY, the bar)
	if not g then
		return nil, nil
	end
	local group = Instance.new("CanvasGroup")
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = UDim2.fromScale(0.5, P.PLATE_Y)
	group.Size = UDim2.fromOffset(460, 76)
	group.BackgroundColor3 = Color3.fromHex("06080C")
	group.BackgroundTransparency = 0.3
	group.BorderSizePixel = 0
	group.GroupTransparency = 1
	group.Parent = g
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.22, 0),
		NumberSequenceKeypoint.new(0.78, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = group
	local scale = Instance.new("UIScale")
	scale.Scale = 0.92
	scale.Parent = group
	local function label(text: string, font: Font, size: number, c: Color3, y: number)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.new(0.5, 0, 0, y)
		l.Size = UDim2.new(1, -40, 0, size + 4)
		l.FontFace = font
		l.TextSize = size
		l.TextColor3 = c
		l.Text = text
		l.Parent = group
	end
	label(string.upper(tierName) .. " POWER", BOLD, 17, color, 8)
	label(string.upper(name), HEAVY, 32, TEXT, 30)
	local info = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	TweenService:Create(group, info, { GroupTransparency = 0 }):Play()
	TweenService:Create(scale, info, { Scale = 1 }):Play()
	return g, group
end

function PackOpening.start(_owner: Player, crateTier: number, _count: number): Handle?
	local cam = workspace.CurrentCamera
	local template = CrateLook.template(crateTier)
	if not (cam and template and template:FindFirstChild("Top_Seal")) then
		return nil
	end
	warm()
	local camera: Camera = cam
	local tpl: Model = template
	local pivotAttr = tpl:GetAttribute("TopPivot")
	local hinge: Vector3 = if typeof(pivotAttr) == "Vector3"
		then pivotAttr
		else Vector3.new(-0.86, 0.93, 0)

	-- how far in front of the camera: the pack fills P.SCREEN of the screen's height
	local dist = PACK_HEIGHT / (P.SCREEN * 2 * math.tan(math.rad(camera.FieldOfView) / 2))
	local folder = Instance.new("Folder")
	folder.Name = "PackOpening"
	folder.Parent = workspace

	local backdrop = part("PackBackdrop", folder)
	backdrop.Size = Vector3.new(220, 220, 0.2)
	backdrop.Color = Color3.new(0, 0, 0)
	backdrop.Material = Enum.Material.SmoothPlastic
	local lightPart = part("PackLight", folder)
	local light = Instance.new("PointLight")
	light.Range = 7
	light.Brightness = 1.4
	light.Color = Color3.fromHex("FFF4E2")
	light.Shadows = false
	light.Parent = lightPart
	local auraPart = part("PackAura", folder)
	local auraGui = Instance.new("BillboardGui")
	auraGui.LightInfluence = 0
	auraGui.Brightness = 2.4
	auraGui.Size = UDim2.fromScale(2, 2)
	auraGui.Adornee = auraPart
	auraGui.Parent = auraPart
	local aura = Instance.new("ImageLabel")
	aura.BackgroundTransparency = 1
	aura.Size = UDim2.fromScale(1, 1)
	aura.Image = Vfx.GLOW
	aura.ImageTransparency = 1
	aura.Parent = auraGui
	local tearPart = part("PackTear", folder)
	local burstPart = part("PackBurst", folder)

	-- poses, in stage space (the stage faces the camera: +X is your left, -Z toward you)
	local dim = 1
	local auraOffset = CFrame.new(0, 0, 0.6)
	local packPose = CFrame.new(0, -4, 0)
	local stripPose = CFrame.identity
	local cardPose: CFrame? = nil
	local tearAt = Vector3.zero

	local pack: Model? = nil
	local base: { [BasePart]: CFrame } = {}
	local strip: { BasePart } = {}
	local card: Model? = nil

	local function newPack()
		local m = tpl:Clone()
		base, strip = {}, {}
		local root = m.PrimaryPart
		local origin = if root then root.CFrame else CFrame.identity
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
				base[d] = origin:ToObjectSpace(d.CFrame)
				if d.Name == "Top_Seal" then
					table.insert(strip, d)
				end
			end
		end
		m.Parent = folder
		pack = m
		stripPose = CFrame.identity
	end

	local function stage(): CFrame
		local c = camera.CFrame
		return CFrame.lookAt(c.Position + c.LookVector * dist, c.Position, c.UpVector)
	end

	local renderName = "PackOpening" .. tostring(os.clock())
	RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, function()
		local st = stage()
		backdrop.CFrame = st * CFrame.new(0, 0, 1.8)
		backdrop.Transparency = lerp(P.DIM, 1, dim)
		lightPart.CFrame = st * CFrame.new(0.5, 0.9, -1.8)
		auraPart.CFrame = st * auraOffset
		tearPart.CFrame = st * packPose * CFrame.new(tearAt)
		local m = pack
		if m then
			local body = st * packPose
			local hingeCF = CFrame.new(hinge)
			local top = body * hingeCF * stripPose * hingeCF:Inverse()
			for p, off in base do
				p.CFrame = (if p.Name == "Top_Seal" then top else body) * off
			end
		end
		local c = card
		local pose = cardPose
		if c and pose then
			c:PivotTo(st * pose)
			burstPart.CFrame = st * pose
		end
	end)

	local stopping = false
	local dead = false
	local queued: { Result }? = nil
	local finished: (() -> ())? = nil
	local plateGui: ScreenGui? = nil

	local function cleanup()
		if dead then
			return
		end
		dead = true
		RunService:UnbindFromRenderStep(renderName)
		folder:Destroy()
		if plateGui then
			plateGui:Destroy()
		end
	end

	-- runs `step` with 0..1 every frame for `duration`; false when stopped
	local function run(duration: number, step: (a: number) -> ()): boolean
		local t0 = os.clock()
		while true do
			if stopping then
				return false
			end
			local a = if duration > 0 then (os.clock() - t0) / duration else 1
			step(math.min(a, 1))
			if a >= 1 then
				return true
			end
			RunService.RenderStepped:Wait()
		end
	end

	local function setAura(color: Color3, size: number, transparency: number, time: number)
		aura.ImageColor3 = color
		local info = TweenInfo.new(time, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		TweenService:Create(auraGui, info, { Size = UDim2.fromScale(size, size) }):Play()
		TweenService:Create(aura, info, { ImageTransparency = transparency }):Play()
	end

	local function flyIn(): boolean
		sound(Cfg.SOUNDS.Toss, 1, 1.1)
		local spin = math.rad(P.IN_SPIN)
		return run(P.IN_TIME, function(a)
			local e = quintOut(a)
			packPose = CFrame.new(0, lerp(-3.6, 0, e), lerp(1.2, 0, e))
				* CFrame.Angles(0, spin * (1 - e), 0)
		end)
	end

	local function sway(t: number)
		local s = math.rad(P.SWAY)
		packPose = CFrame.new(0, math.sin(t * 1.7) * 0.04, 0)
			* CFrame.Angles(
				math.sin(t * 1.1) * s * 0.4,
				math.sin(t * 1.4) * s,
				math.sin(t * 0.9) * s * 0.3
			)
	end

	local function openOne(r: Result): boolean
		local tier = Skins.TIERS[r.tier :: any] or Skins.TIERS.Common
		local color = tier.color
		local fx = (Cfg.TIER_FX :: any)[r.tier] or Cfg.TIER_FX.Common
		local shakes = (Cfg.TIER_SHAKES :: any)[r.tier] or Cfg.SHAKES
		local power = r.power
		if power and Theme.CARD_ART[power] then
			task.spawn(function()
				local img = Instance.new("ImageLabel")
				img.Image = Theme.CARD_ART[power]
				pcall(ContentProvider.PreloadAsync, ContentProvider, { img })
				img:Destroy()
			end)
		end

		-- shakes: rolls that grow; the tier glow from the second-to-last
		for i = 1, shakes do
			if i == math.max(1, shakes - 1) then
				sound(Cfg.SOUNDS.Tease)
				setAura(color, P.AURA_TEASE, 0.3, 0.5)
			end
			sound(P.Crinkle, 1, 0.92 + 0.07 * i)
			local amp = math.rad(P.SHAKE_ANGLES[math.min(i, #P.SHAKE_ANGLES)])
			if
				not run(P.SHAKE_EVERY, function(a)
					local env = (1 - a) * (1 - a)
					packPose = CFrame.new(
						0,
						math.sin(a * math.pi) * 0.06,
						-math.sin(a * math.pi) * 0.12
					) * CFrame.Angles(
						0,
						amp * 0.35 * math.sin(a * math.pi * 3) * env,
						amp * math.sin(a * math.pi * 5) * env
					)
				end)
			then
				return false
			end
		end
		-- the strain: trembling while the glow swells
		if fx.hold > 0 then
			sound(Cfg.RISER)
			setAura(color, P.AURA_HOLD, 0.12, fx.hold)
			local rng = Random.new()
			if
				not run(fx.hold, function(a)
					local s = math.rad(1.2 + 2.2 * a)
					packPose = CFrame.new(0, 0, -0.08 * a)
						* CFrame.Angles(0, rng:NextNumber(-s, s) * 0.4, rng:NextNumber(-s, s))
				end)
			then
				return false
			end
		end

		-- the rip: the strip hinges up from the notch, sparks run along the tear
		sound(P.Rip)
		kick(Cfg.CAMERA_KICK * fx.kick * 0.45, 0)
		local tearSparks = sparkEmitter(tearPart, color, 5, 40)
		tearSparks.Rate = 60 + fx.sparks
		local lift = math.rad(P.RIP_LIFT)
		local ok = run(P.RIP_TIME, function(a)
			local e = a ^ 0.8
			packPose = CFrame.new(0, -0.04 * e, 0) * CFrame.Angles(0, 0, math.rad(-3) * e)
			stripPose = CFrame.Angles(math.rad(-14) * e, 0, lift * e)
			tearAt = Vector3.new(lerp(NOTCH_X, hinge.X, e), STRIP_Y, -0.05)
		end)
		tearSparks.Rate = 0
		if not ok then
			return false
		end
		tearSparks:Emit(math.floor(fx.sparks * 0.4))
		setAura(color, P.AURA_HOLD + 0.8, 0.05, 0.3)
		if
			not run(P.STRIP_FLY, function(a)
				local e = quintOut(a)
				stripPose = CFrame.new(-2.6 * e, 2.2 * e, -0.8 * e)
					* CFrame.Angles(math.rad(-14) - 2.2 * e, 0, lift + 3.4 * e)
			end)
		then
			return false
		end
		for _, p in strip do
			p.Transparency = 1
		end

		-- the card slides up out of the pack, its back to you
		local c = PowerCardFace.clone()
		if c then
			if power then
				PowerCardFace.fill(c, power, "NEW")
			end
			for _, d in c:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
					d.CastShadow = false
				end
			end
			c:ScaleTo(P.CARD_SCALE)
			c.Parent = folder
			card = c
		end
		local scale = P.CARD_SCALE
		local back = CFrame.Angles(0, math.pi, 0)
		cardPose = packPose * CFrame.new(0, -0.05, 0.01) * back
		sound(Cfg.SOUNDS.Fly, 1, 1.25)
		local from = packPose
		if
			not run(P.SLIDE_TIME, function(a)
				cardPose = from * CFrame.new(0, lerp(-0.05, P.SLIDE_UP, quintOut(a)), 0.01) * back
			end)
		then
			return false
		end

		-- the pack drops away; the card comes to the centre, grows and flips to its face
		local slid = cardPose or CFrame.identity
		local burst = false
		local span = math.max(P.DROP_TIME, P.FLIP_TIME)
		local sparksOut = sparkEmitter(burstPart, color, 9, 180)
		sparksOut.Acceleration = Vector3.new(0, -4, 0)
		if
			not run(span, function(a)
				local t = a * span
				local d = quadIn(t / P.DROP_TIME)
				packPose = from
					* CFrame.new(0, -4.5 * d, 0.4 * d)
					* CFrame.Angles(math.rad(-30) * d, 0, 0)
				local f = clamp01(t / P.FLIP_TIME)
				local e = quintOut(f)
				local yaw = math.pi * backOut(f, 1.3)
				local pos = slid.Position:Lerp(Vector3.new(0, P.CARD_LIFT, -0.35), e)
				cardPose = CFrame.new(pos) * CFrame.Angles(0, math.pi + yaw, 0)
				local want = lerp(P.CARD_SCALE, P.CARD_GROW, e)
				if c and math.abs(want - scale) > 0.002 then
					scale = want
					c:ScaleTo(want)
				end
				if not burst and f >= 0.45 then
					burst = true
					sound((Cfg.REVEAL :: any)[r.tier] or Cfg.REVEAL.Common)
					sound(Cfg.SOUNDS.LidBoom, 0.8)
					for _, spec in fx.extra do
						sound(spec)
					end
					flash(color, fx.flash)
					kick(Cfg.CAMERA_KICK * fx.kick, Cfg.FOV_PUNCH * fx.kick)
					sparksOut:Emit(fx.sparks)
					auraOffset = CFrame.new(0, P.CARD_LIFT, 0.7)
					setAura(color, P.AURA_BURST + 0.6 * tier.order, 0, 0.4)
					local g, group = plate(r.name, tier.name, color)
					plateGui = g
					if group then
						group.Name = "Plate"
					end
				end
			end)
		then
			return false
		end
		if pack then
			pack:Destroy()
			pack = nil
		end

		-- the hold: a slow sway in the glow
		local rest = cardPose or CFrame.identity
		if
			not run(P.HOLD, function(a)
				local t = a * P.HOLD
				cardPose = rest
					* CFrame.new(0, math.sin(t * 1.6) * 0.035, 0)
					* CFrame.Angles(math.sin(t * 1.2) * 0.03, math.sin(t * 0.9) * 0.12, 0)
			end)
		then
			return false
		end

		-- into the Backpack
		local held = cardPose or CFrame.identity
		local g = plateGui
		local group = g and g:FindFirstChild("Plate")
		if group and group:IsA("CanvasGroup") then
			TweenService:Create(
				group,
				TweenInfo.new(P.OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{
					GroupTransparency = 1,
				}
			):Play()
		end
		setAura(color, 2, 1, P.OUT_TIME)
		sound(Cfg.SOUNDS.Collect, 0.8)
		local ok2 = run(P.OUT_TIME, function(a)
			local e = quadIn(a)
			cardPose = held * CFrame.new(0, -3.2 * e, 0)
			local want = lerp(P.CARD_GROW, P.CARD_GROW * 0.5, e)
			if c and math.abs(want - scale) > 0.002 then
				scale = want
				c:ScaleTo(want)
			end
		end)
		if c then
			c:Destroy()
		end
		card, cardPose = nil, nil
		if g then
			g:Destroy()
		end
		plateGui = nil
		auraOffset = CFrame.new(0, 0, 0.6)
		return ok2
	end

	-- the dim backdrop comes up while the pack flies in
	task.spawn(function()
		run(0.3, function(a)
			dim = 1 - quintOut(a)
		end)
	end)

	task.spawn(function()
		newPack()
		if not flyIn() then
			return
		end
		local t0 = os.clock()
		while not queued do
			if stopping then
				return
			end
			local t = os.clock() - t0
			if t > Cfg.WAIT_LIMIT then
				stopping = true
				break
			end
			sway(t)
			RunService.RenderStepped:Wait()
		end
		local list = queued
		if list and not stopping then
			for i, r in list do
				if i > 1 then
					newPack()
					if not flyIn() then
						return
					end
				end
				if not openOne(r) then
					return
				end
			end
			run(0.25, function(a)
				dim = quintOut(a)
			end)
			cleanup()
			local done = finished
			finished = nil
			if done then
				done()
			end
		end
		if stopping and not dead then
			cleanup()
		end
	end)

	local function abort()
		if stopping or dead then
			return
		end
		stopping = true
		-- the pack drops away and the backdrop fades, then everything goes
		local from = packPose
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < 0.3 and not dead do
				local a = (os.clock() - t0) / 0.3
				packPose = from * CFrame.new(0, -4 * quadIn(a), 0)
				dim = a
				RunService.RenderStepped:Wait()
			end
			cleanup()
		end)
	end

	local handle = {}
	function handle.reveal(_self: Handle, results: { Result }, onDone: (() -> ())?): boolean
		if stopping or dead or queued or #results == 0 then
			return false
		end
		finished = onDone
		queued = results
		return true
	end
	function handle.abort(_self: Handle)
		abort()
	end
	function handle.isDead(_self: Handle): boolean
		return dead
	end
	return handle :: any
end

return PackOpening
