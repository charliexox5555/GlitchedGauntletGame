--!strict
-- The in-world case opening (vault/01 Design/Case Opening.md; numbers in
-- Shared/Config/CaseOpening). Client-side and cosmetic: the server has already rolled
-- the skin (Services/ShopService); this only shows it.
--
--   local h = CaseOpening.start(owner, crateTier, isLocal, count) -- tossed out, shaking
--   h:reveal(results, onDone)                                -- the build-up and the burst
--   h:abort()                                                -- refused: it sinks away
--
-- Beats: toss → shakes (more for higher tiers; the seams glow in the tier colour before
-- the lid goes) → latches → dip → lid burst (flash, sparks, floor ring, light beam,
-- camera kick for you) → the skin rises and turns in its glow with the card (portrait
-- on its tier tile) → it arcs and spins into you with a trail → collect burst; the
-- crate sinks. Others see the same at the opener, quieter, with their name on the card.
-- The crate is ReplicatedStorage.Crates.Crate (Motor6D Base, Lid, Gem, LatchL, LatchR,
-- Handle; positive X angle = open). Studio review: workspace StateValue CaseTimeScale.

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Cfg = require(ReplicatedStorage.Shared.Config.CaseOpening)
local CrateLook = require(ReplicatedStorage.Shared.CrateLook)
local Locker = require(ReplicatedStorage.Shared.Locker)
local SkinArt = require(ReplicatedStorage.Shared.SkinArt)
local Skins = require(ReplicatedStorage.Shared.Config.Skins)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local UiMotion = require(ReplicatedStorage.Shared.UiMotion)
local Vfx = require(ReplicatedStorage.Shared.Config.VfxTextures)
local ItemStage = require(script.Parent.ItemStage)
local PowerCardFace = require(script.Parent.PowerCardFace)
-- the name plate over a rising power card is smaller than a skin's (owner 2026-11-26: "a bit too large")
local POWER_CARD_SCALE = 0.7
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

-- A skin, or a power from a power case (power = Config/Mods id, gun and line ""; Shared/PowerCases): its
-- 3D card rises instead of a gun (Util/PowerCardFace).
export type Result = { gun: string, line: string, tier: string, name: string, power: string? }

local CaseOpening = {}

local FONT = Font.new("rbxassetid://12187365977", Enum.FontWeight.Heavy) -- Rubik
local C1 = 1.70158

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end
local function backOut(x: number, k: number?): number
	local c1 = k or C1
	local c3 = c1 + 1 -- back easing
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end
local function quintOut(x: number): number
	return 1 - (1 - x) ^ 5
end
local function quadIn(x: number): number
	return x * x
end

local function rootOf(p: Player): BasePart?
	local ch = p.Character
	local r = ch and ch:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function facingOpener(position: Vector3, origin: Vector3): CFrame
	return CFrame.lookAt(position, Vector3.new(origin.X, position.Y, origin.Z))
end

local function landingSpot(
	origin: Vector3,
	look: Vector3,
	params: RaycastParams,
	angle: number,
	distance: number,
	occupied: { Vector3 },
	height: number?
): CFrame?
	local dir = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(look)
	local offset = dir * distance
	local target = origin + offset + Vector3.yAxis * (height or 0)
	if workspace:Raycast(origin, target - origin, params) then
		return nil
	end
	if not height then
		local down = workspace:Raycast(target + Vector3.yAxis * 4, -Vector3.yAxis * 14, params)
		if not down or down.Normal.Y < 0.7 then
			return nil
		end
		target = down.Position
	end
	for _, position in occupied do
		local delta = target - position
		local spacing = if height
			then delta.Magnitude
			else Vector3.new(delta.X, 0, delta.Z).Magnitude
		if spacing < Cfg.BATCH_MIN_SPACING then
			return nil
		end
	end
	return facingOpener(target, origin)
end

local audioWarmed = false
local function warmAudio()
	if audioWarmed then
		return
	end
	audioWarmed = true
	task.spawn(function()
		local seen: { [string]: boolean } = {}
		local list: { Instance } = {}
		local function addSpec(spec: any)
			if typeof(spec) == "table" and typeof(spec.id) == "string" and not seen[spec.id] then
				seen[spec.id] = true
				local snd = Instance.new("Sound")
				snd.SoundId = spec.id
				table.insert(list, snd)
			end
		end
		for _, spec in Cfg.SOUNDS do
			addSpec(spec)
		end
		for _, spec in Cfg.REVEAL do
			addSpec(spec)
		end
		addSpec(Cfg.RISER)
		for _, fx in Cfg.TIER_FX do
			for _, spec in fx.extra do
				addSpec(spec)
			end
		end
		if #list > 0 then
			pcall(ContentProvider.PreloadAsync, ContentProvider, list)
			for _, inst in list do
				inst:Destroy()
			end
		end
	end)
end

local function sound(spec: any, parent: Instance, gain: number, pitchMult: number?)
	local snd = Instance.new("Sound")
	snd.SoundId = spec.id
	snd.Volume = spec.volume * gain
	snd.PlaybackSpeed = spec.pitch * (pitchMult or 1)
	snd.RollOffMode = Enum.RollOffMode.InverseTapered
	snd.RollOffMinDistance = Cfg.ROLLOFF.X
	snd.RollOffMaxDistance = Cfg.ROLLOFF.Y
	snd.Parent = parent
	if typeof(spec.start) == "number" and spec.start > 0 then
		snd.TimePosition = spec.start
	end
	snd:Play()
	local cut = spec.cut
	if cut then -- a slice of a longer recording: fade it out after `cut` seconds
		task.delay(cut, function()
			if snd.Parent then
				TweenService:Create(snd, TweenInfo.new(0.1), { Volume = 0 }):Play()
			end
		end)
	end
	Debris:AddItem(snd, 8)
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function sparks(parent: Instance, color: Color3, count: number, speed: number)
	local e = emitter(parent, {
		Texture = Vfx.SPARK,
		Color = ColorSequence.new(color),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.34),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(0.45, 0.9),
		Speed = NumberRange.new(speed * 0.55, speed),
		SpreadAngle = Vector2.new(35, 35),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -22, 0),
		Drag = 2,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
	})
	e:Emit(count)
	Debris:AddItem(e, 2)
end

local function glow(parent: Instance, color: Color3, size: number, life: number)
	local e = emitter(parent, {
		Texture = Vfx.GLOW,
		Color = ColorSequence.new(color),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, size * 0.3),
			NumberSequenceKeypoint.new(0.25, size),
			NumberSequenceKeypoint.new(1, size * 1.1),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(life),
		Speed = NumberRange.new(0),
		ZOffset = 1,
	})
	e:Emit(1)
	Debris:AddItem(e, life + 1)
end

local function dust(parent: Instance)
	local e = emitter(parent, {
		Texture = Vfx.GLOW,
		Color = ColorSequence.new(Color3.fromHex("B9B4AC")),
		LightEmission = 0,
		LightInfluence = 1,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.8),
			NumberSequenceKeypoint.new(1, 2.6),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(80, 10),
		EmissionDirection = Enum.NormalId.Top,
		Drag = 4,
	})
	e:Emit(12)
	Debris:AddItem(e, 2)
end

local function helperPart(name: string, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = cf
	p.Parent = workspace
	return p
end

-- a flat ring on the floor that grows and fades (the lid's shockwave, the collect)
local function ring(cf: CFrame, color: Color3, size: number, time: number)
	local p = helperPart("CaseRing", cf)
	p.Size = Vector3.new(0.5, 0.05, 0.5)
	local d = Instance.new("Decal")
	d.Texture = Vfx.MOD_RING
	d.Color3 = color
	d.Face = Enum.NormalId.Top
	d.Transparency = 0.05
	d.Parent = p
	local info = TweenInfo.new(time, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	TweenService:Create(p, info, { Size = Vector3.new(size, 0.05, size) }):Play()
	TweenService:Create(d, info, { Transparency = 1 }):Play()
	Debris:AddItem(p, time + 0.2)
end

-- a soft beam of the tier colour straight up out of the crate
local function beam(
	from: Attachment,
	color: Color3,
	height: number,
	time: number,
	widthScale: number?
)
	local wScale = widthScale or 1
	local top = helperPart("CaseBeamTop", from.WorldCFrame + Vector3.new(0, height, 0))
	local a1 = Instance.new("Attachment")
	a1.Parent = top
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = from, a1
	b.Texture = Vfx.GLOW
	b.TextureMode = Enum.TextureMode.Stretch
	b.Color = ColorSequence.new(color)
	b.LightEmission = 1
	b.LightInfluence = 0
	b.FaceCamera = true
	b.Width0, b.Width1 = 2.4 * wScale, 0.6 * wScale
	b.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	b.Parent = top
	local fade = Instance.new("NumberValue")
	fade.Value = 0
	fade.Changed:Connect(function(v: number)
		b.Width0 = (2.4 * (1 - v) + 0.2) * wScale
		b.Width1 = (0.6 * (1 - v) + 0.05) * wScale
		b.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15 + 0.85 * v),
			NumberSequenceKeypoint.new(1, 1),
		})
	end)
	TweenService:Create(
		fade,
		TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Value = 1 }
	):Play()
	Debris:AddItem(top, time + 0.2)
	Debris:AddItem(fade, time + 0.2)
end

-- a short camera kick and FOV punch (the opener's own view only)
local function kick(strength: number, fovPunch: number)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local t0 = os.clock()
	local baseFov = cam.FieldOfView
	local name = "CaseKick" .. tostring(t0)
	-- (+2: after Shared/SettingsApply sets the player's FOV at +1)
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

-- a quick full-screen flash in the tier colour (the opener's own view, high tiers)
local function flash(color: Color3, strength: number)
	local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg or strength <= 0 then
		return
	end
	local g = Instance.new("ScreenGui")
	g.Name = "CaseFlash"
	g:SetAttribute("LobbyGui", true) -- the match client never clears it (src/client init: armed-zone cleanup)
	g.IgnoreGuiInset = true
	g.ScreenInsets = Enum.ScreenInsets.None -- full-bleed, under the notch too
	g.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	g.ClipToDeviceSafeArea = false
	g.DisplayOrder = 5
	g.ResetOnSpawn = false
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 1 - strength
	f.BorderSizePixel = 0
	f.Parent = g
	g.Parent = pg
	TweenService:Create(f, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	Debris:AddItem(g, 0.6)
end

-- the floating card: the skin's portrait spilling over its tier tile, the name in the
-- tier colour, the tier tag; "NAME UNBOXED" on top for everyone else. Pops in with one
-- shine sweep.
local function card(
	anchor: BasePart,
	result: Result,
	color: Color3,
	tierName: string,
	tierOrder: number,
	who: string?,
	sizeScale: number
): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = "CaseCard"
	bb.Size = UDim2.fromScale(Cfg.CARD_SIZE.X * sizeScale, Cfg.CARD_SIZE.Y * sizeScale)
	bb.LightInfluence = 0
	bb.MaxDistance = 90
	bb.Adornee = anchor
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundColor3 = Color3.fromHex("141417")
	holder.BackgroundTransparency = 0.06
	holder.BorderSizePixel = 0
	holder.Parent = bb
	local pop = Instance.new("UIScale")
	pop.Scale = 0
	pop.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.1, 0)
	corner.Parent = holder
	local border = Instance.new("UIStroke")
	border.Color = color
	border.Thickness = if tierOrder >= 4 then 4 elseif tierOrder == 3 then 3 else 2
	border.Transparency = if tierOrder >= 3 then 0.1 else 0.35
	border.Parent = holder
	-- the tier tile with the portrait spilling out
	local tile = Instance.new("Frame")
	tile.Name = "Tile"
	tile.AnchorPoint = Vector2.new(0, 0.5)
	tile.Position = UDim2.fromScale(0.03, 0.5)
	tile.Size = UDim2.fromScale(Cfg.CARD_TILE, 0.84)
	tile.BackgroundColor3 = color
	tile.BorderSizePixel = 0
	tile.Parent = holder
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0.1, 0)
	tc.Parent = tile
	local tg = Instance.new("UIGradient")
	tg.Rotation = 90
	tg.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(105, 105, 115))
	tg.Parent = tile
	local pic = Instance.new("ImageLabel")
	pic.Name = "Pic"
	pic.BackgroundTransparency = 1
	pic.AnchorPoint = Vector2.new(0.5, 0.5)
	pic.Position = UDim2.fromScale(0.46, 0.44)
	pic.Size = UDim2.fromScale(1.35, 1.35)
	pic.ScaleType = Enum.ScaleType.Fit
	if result.power then
		-- a power: its card art, cropped to the tile (owner 2026-11-26: the icons should look better)
		PowerCardFace.thumb(pic, result.power)
		pic.Position = UDim2.fromScale(0.5, 0.5)
		pic.Size = UDim2.fromScale(0.94, 0.94)
		local pc = Instance.new("UICorner")
		pc.CornerRadius = UDim.new(0.1, 0)
		pc.Parent = pic
	else
		pic.Image = SkinArt.portrait(result.gun, result.line) or ""
	end
	pic.ZIndex = 3
	pic.Parent = tile
	local x0 = 0.06 + Cfg.CARD_TILE
	local function label(name: string, text: string, y: number, h: number, c: Color3)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(x0, y)
		l.Size = UDim2.fromScale(0.96 - x0, h)
		l.FontFace = FONT
		l.TextScaled = true
		l.TextWrapped = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = c
		l.Text = text
		l.ZIndex = 2
		l.Parent = holder
	end
	if who then
		label("Who", string.upper(who) .. " UNBOXED", 0.1, 0.18, Color3.fromHex("9F9FA2"))
	end
	label("Name", result.name, if who then 0.29 else 0.15, if who then 0.33 else 0.42, color)
	local tag = Instance.new("Frame")
	tag.Name = "Tier"
	tag.Position = UDim2.fromScale(x0, 0.68)
	tag.Size = UDim2.fromScale(0.3, 0.2)
	tag.BackgroundColor3 = color
	tag.BorderSizePixel = 0
	tag.ZIndex = 2
	tag.Parent = holder
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.FontFace = FONT
	tl.TextScaled = true
	tl.TextColor3 = Color3.fromHex("0F0F12")
	tl.Text = tierName
	tl.ZIndex = 3
	tl.Parent = tag
	-- one shine sweep across the card
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Size = UDim2.fromScale(1, 1)
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0
	shine.BorderSizePixel = 0
	shine.ZIndex = 5
	shine.Parent = holder
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0.1, 0)
	sc.Parent = shine
	local sg = Instance.new("UIGradient")
	sg.Rotation = 20
	sg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	sg.Offset = Vector2.new(-1, 0)
	sg.Parent = shine
	bb.Parent = anchor
	TweenService:Create(
		pop,
		TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
	task.delay(0.3, function()
		TweenService
			:Create(sg, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
				Offset = Vector2.new(1, 0),
			})
			:Play()
	end)
	if tierOrder >= 4 and not UiMotion.reduced() then
		task.delay(1.05, function()
			if sg.Parent then
				sg.Offset = Vector2.new(-1, 0)
				TweenService:Create(
					sg,
					TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
					{ Offset = Vector2.new(1, 0) }
				):Play()
			end
		end)
	end
	return bb
end

type Phase = "toss" | "wait" | "open" | "collect" | "sink" | "dead"

type Timing = { shakes: number, lidAt: number, modelsReady: (shake: number) -> boolean }

type CrateHandle = {
	reveal: (result: Result?, timing: Timing, lead: boolean, onDone: () -> ()) -> (),
	abort: () -> (),
	canReveal: () -> boolean,
	isDead: () -> boolean,
}

export type Handle = {
	reveal: (self: Handle, results: { Result }, onDone: (() -> ())?) -> boolean,
	abort: (self: Handle) -> (),
	isDead: (self: Handle) -> boolean,
}

local function startCrate(
	owner: Player,
	origin: Vector3,
	crateTier: number,
	isLocal: boolean,
	land: CFrame,
	count: number
): CrateHandle?
	local model = CrateLook.make(crateTier)
	local root = model and model.PrimaryPart
	if not model or not root then
		if model then
			model:Destroy()
		end
		return nil
	end
	local audienceGain = if isLocal then Cfg.LOCAL_VOLUME else Cfg.OTHERS_VOLUME
	-- a batch shares the loudness, but each crate still reads (sqrt, not a straight split)
	local gain = audienceGain / math.sqrt(count)
	-- the tier's model decides its size (the Knife case is smaller: Config/Crates)
	local scale = CrateLook.scale(crateTier) or Cfg.SCALE
	model.Name = "CaseOpening_" .. owner.UserId
	model:ScaleTo(scale)
	local joints: { [string]: Motor6D } = {}
	for _, n in { "Base", "Lid", "Gem", "LatchL", "LatchR", "Handle" } do
		local j = CrateLook.joint(model, n)
		if j then
			joints[n] = j
		end
	end
	local baseInst = model:FindFirstChild("Base_Body")
	local burstInst = if baseInst then baseInst:FindFirstChild("Burst") else nil
	local burst: Attachment? = if burstInst and burstInst:IsA("Attachment") then burstInst else nil
	local lightInst = model:FindFirstChild("Base_Light")
	local stripPart: BasePart? = if lightInst and lightInst:IsA("BasePart") then lightInst else nil
	local footing = Instance.new("Attachment")
	footing.Name = "Footing"
	footing.Parent = root

	local startCF = CFrame.new(origin + Vector3.new(0, 1, 0)) * land.Rotation
	model:PivotTo(startCF * CFrame.Angles(0, math.rad(Cfg.TOSS_SPIN), 0))
	model.Parent = workspace
	sound(Cfg.SOUNDS.Toss, root, gain)

	local phase: Phase = "toss"
	local clock = 0
	local t0 = 0
	local landedAt = 0
	local shakes = 0
	local lastShake = -1
	local result: Result? = nil
	local timing: Timing? = nil
	local lead = false
	local onDone: (() -> ())? = nil
	local openAt = 0
	local fired: { [string]: boolean } = {}
	local skin: Model? = nil
	local skinScale = 1
	local skinHome: CFrame? = nil
	local anchor: BasePart? = nil
	local aura: BasePart? = nil
	local cardGui: BillboardGui? = nil
	local light: PointLight? = nil
	local tierColor = Color3.new(1, 1, 1)
	local tierOrder = 1
	local collectAt = 0
	local lidAt = Cfg.LID_AT -- + the tier's held beat (TIER_FX.hold)
	local fx: any = Cfg.TIER_FX.Common
	local flyFrom: CFrame? = nil
	local sinkAt = 0
	local lastPreSpark = -1
	local holdBaseFov: number? = nil
	local conn: RBXScriptConnection

	local function once(key: string): boolean
		if fired[key] then
			return false
		end
		fired[key] = true
		return true
	end

	local function cleanup()
		phase = "dead"
		conn:Disconnect()
		model:Destroy()
		for _, x in { skin, anchor, aura } :: { Instance? } do
			if x then
				x:Destroy()
			end
		end
		local done = onDone
		onDone = nil
		if done then
			task.spawn(done)
		end
	end

	local function setJoint(name: string, cf: CFrame)
		local j = joints[name]
		if j then
			j.Transform = cf
		end
	end

	local function startSink()
		if phase == "sink" or phase == "dead" then
			return
		end
		phase = "sink"
		sinkAt = clock
		sound(Cfg.SOUNDS.Sink, root, gain)
		dust(footing)
	end

	-- the seams glow in the tier colour: the tease before the lid
	local function tease()
		local r = result
		if not r or not once("tease") then
			return
		end
		local tier = Skins.TIERS[r.tier :: any] or Skins.TIERS.Common
		tierColor = tier.color -- a power's tier too (Config/PowerCases)
		tierOrder = tier.order
		sound(Cfg.SOUNDS.Tease, root, gain)
		local strip = stripPart
		if strip then
			strip.Color = tierColor
		end
		if burst then
			local l = Instance.new("PointLight")
			l.Color = tierColor
			l.Range = Cfg.LIGHT_RANGE * 0.6
			l.Brightness = Cfg.TEASE_GLOW
			l.Shadows = false
			l.Parent = burst
			light = l
		end
	end

	local function revealSkin()
		local r = result
		if not r then
			return
		end
		local top = land.Position + Vector3.new(0, 1.0 * scale, 0)
		local src = if r.power then nil else Locker.skinModel(r.gun, r.line)
		local powerCard = if r.power then PowerCardFace.clone() else nil
		if powerCard and r.power then
			-- a power: its card rises out of the case (front toward the opener, like the crate's front)
			PowerCardFace.fill(powerCard, r.power, "NEW")
			for _, d in powerCard:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
					d.CanTouch = false
				end
			end
			local size = powerCard:GetExtentsSize()
			local longest = math.max(size.X, size.Y, size.Z)
			if longest > 0 then
				skinScale = Cfg.SKIN_LENGTH * 0.62 / longest
				powerCard:ScaleTo(skinScale)
			end
			powerCard.Name = "CaseSkin"
			powerCard:PivotTo(CFrame.new(top - Vector3.new(0, 0.6, 0)) * land.Rotation)
			powerCard.Parent = workspace
			skin = powerCard
		elseif src and src:FindFirstChildWhichIsA("BasePart", true) then
			local m = ItemStage.presentable(src)
			local size = m:GetExtentsSize()
			local longest = math.max(size.X, size.Y, size.Z)
			if longest > 0 then
				skinScale = Cfg.SKIN_LENGTH / longest
				m:ScaleTo(skinScale)
			end
			m.Name = "CaseSkin"
			m:PivotTo(CFrame.new(top - Vector3.new(0, 0.6, 0)) * land.Rotation)
			m.Parent = workspace
			skin = m
		end
		skinHome = CFrame.new(top + Vector3.new(0, Cfg.RISE_HEIGHT, 0)) * land.Rotation
		anchor = helperPart(
			"CaseCardAnchor",
			CFrame.new(top + Vector3.new(0, Cfg.RISE_HEIGHT + Cfg.CARD_UP, 0))
		)
		-- the glow the skin turns in: a light and slow sparkles
		local au = helperPart("CaseAura", skinHome :: CFrame)
		local al = Instance.new("PointLight")
		al.Color = tierColor
		al.Range = 9
		al.Brightness = 1.2
		al.Shadows = false
		al.Parent = au
		emitter(au, {
			Texture = Vfx.MOD_SPARKLE,
			Color = ColorSequence.new(tierColor),
			LightEmission = 1,
			LightInfluence = 0,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.3, 0.35),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Lifetime = NumberRange.new(0.6, 1.1),
			Speed = NumberRange.new(0.6, 1.4),
			SpreadAngle = Vector2.new(180, 180),
			Rate = Cfg.SPARKLES + tierOrder * 2,
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		}).Enabled =
			true
		local glowE = emitter(au, {
			Texture = Vfx.GLOW,
			Color = ColorSequence.new(tierColor),
			LightEmission = 1,
			LightInfluence = 0,
			Size = NumberSequence.new(4.2),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.72),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(1.2),
			Rate = 2,
			Speed = NumberRange.new(0),
			ZOffset = -1,
		})
		glowE.Enabled = true
		aura = au
		local tier = Skins.TIERS[r.tier :: any] or Skins.TIERS.Common
		cardGui = card(
			anchor :: BasePart,
			r,
			tier.color,
			if r.power then tier.name .. " POWER" else tier.name,
			tier.order,
			if isLocal then nil else owner.DisplayName,
			(
				if count > #Cfg.BATCH_ANGLES
					then Cfg.WIDE_CARD_SCALE
					elseif count > 1 then Cfg.BATCH_CARD_SCALE
					else 1
			) * (if r.power then POWER_CARD_SCALE else 1)
		)
	end

	conn = RunService.RenderStepped:Connect(function(dt: number)
		local timeScale = StateValues.get(workspace, "CaseTimeScale")
		clock += dt * (if typeof(timeScale) == "number" and RunService:IsStudio()
			then timeScale
			else 1)
		local now = clock
		if phase == "toss" then
			local u = clamp01((now - t0) / Cfg.TOSS)
			local flat = startCF.Position:Lerp(land.Position, quintOut(u))
			local bounce = math.abs(math.cos(3 * math.pi * (u + 0.25)) * (u - 1) / 0.707)
			local y = land.Position.Y
				+ (startCF.Position.Y - land.Position.Y + Cfg.TOSS_HEIGHT * 0.4) * bounce
			local yaw = math.rad(Cfg.TOSS_SPIN) * (1 - quintOut(u))
			model:PivotTo(CFrame.new(flat.X, y, flat.Z) * land.Rotation * CFrame.Angles(0, yaw, 0))
			if u >= 1 then
				model:PivotTo(land)
				phase = "wait"
				landedAt = now
				sound(Cfg.SOUNDS.Land, root, gain)
				dust(footing)
			end
			return
		end
		if phase == "wait" then
			local tau = now - landedAt
			if not timing and tau > Cfg.WAIT_LIMIT then
				startSink()
				return
			end
			local k = math.floor((tau - 0.25) / Cfg.SHAKE_EVERY)
			if k >= 0 and k ~= lastShake then
				lastShake = k
				shakes += 1
				local shakePitch = 1 + 0.06 * math.max(shakes - 1, 0)
				local shakeGain = gain * (0.8 + 0.14 * math.min(shakes, 5))
				sound(Cfg.SOUNDS.Shake, root, shakeGain, shakePitch)
				sound(Cfg.SOUNDS.Rattle, root, shakeGain, shakePitch)
				-- the knock on the floor: a little higher each time, the boom heavier
				sound(Cfg.SOUNDS.Knock, root, shakeGain, shakePitch * (0.96 + 0.08 * math.random()))
				sound(Cfg.SOUNDS.ShakeBoom, root, shakeGain, 1 + 0.04 * math.max(shakes - 1, 0))
				local schedule = timing
				if schedule and shakes >= schedule.shakes - 1 then
					tease()
				end
				if schedule and shakes > schedule.shakes and schedule.modelsReady(shakes) then
					phase = "open"
					openAt = now
					lidAt = schedule.lidAt
					return
				end
			end
			local since = (tau - 0.25) - math.max(lastShake, 0) * Cfg.SHAKE_EVERY
			if lastShake >= 0 and since < 0.32 then
				local amp = Cfg.SHAKE_ANGLES[math.min(shakes, #Cfg.SHAKE_ANGLES)]
				local env = 1 - since / 0.32
				local rz = math.rad(amp) * math.sin(since * math.pi * 2 * 3.2) * env
				local hop = math.sin(clamp01(since / 0.2) * math.pi) * 0.05 * scale * (shakes - 1)
				setJoint("Base", CFrame.new(0, hop, 0) * CFrame.Angles(0, 0, rz))
				setJoint(
					"Handle",
					CFrame.Angles(math.rad(25) * math.sin(since * math.pi * 2 * 2) * env, 0, 0)
				)
				local l = light
				if l then -- the glow throbs with the shake
					l.Brightness = Cfg.TEASE_GLOW * (0.6 + 0.8 * env)
				end
			else
				setJoint("Base", CFrame.new())
				setJoint("Handle", CFrame.new())
			end
			return
		end
		if phase == "open" then
			local tau = now - openAt
			local reduced = UiMotion.reduced()
			for i, n in { "LatchL", "LatchR" } do
				local lt = tau - (i - 1) * Cfg.LATCH_GAP
				if lt >= 0 and once(n) then
					sound(Cfg.SOUNDS.Latch, root, gain, if i == 1 then 1 else 1.12)
				end
				local a = backOut(clamp01(lt / Cfg.LATCH_TIME), 2.4) * Cfg.LATCH_ANGLE
				setJoint(n, CFrame.Angles(math.rad(math.max(a, 0)), 0, 0))
			end
			local coil = clamp01((tau - Cfg.COIL) / (lidAt - Cfg.COIL))
			local dip = if tau < lidAt
				then math.sin(coil * math.pi * 0.5)
				else 1 - clamp01((tau - lidAt) / 0.15)
			-- the held beat (higher tiers): the crate trembles and the glow ramps up
			local holdStart = lidAt - fx.hold
			local held = if fx.hold > 0 then clamp01((tau - holdStart) / fx.hold) else 0
			if lead and fx.hold > 0 and tau >= holdStart - 0.05 and once("riser") then
				sound(Cfg.RISER, root, audienceGain)
				sound(Cfg.SOUNDS.Strain, root, gain)
			end
			if tau < lidAt and held > 0 and not reduced then
				if tierOrder >= 3 and burst then
					local beat = math.floor(tau / 0.12)
					if beat ~= lastPreSpark then
						lastPreSpark = beat
						sparks(burst :: Attachment, tierColor, 4, 8 + 6 * held)
					end
				end
				if isLocal and lead then
					local cam = workspace.CurrentCamera
					if cam then
						if not holdBaseFov then
							holdBaseFov = cam.FieldOfView
						end
						cam.FieldOfView = (holdBaseFov :: number) - 2.5 * fx.kick * held
					end
				end
			end
			local tremble = if tau < lidAt
					and held > 0
					and not reduced
				then CFrame.Angles(0, 0, math.rad(math.sin(tau * 70) * 2.5 * held))
				else CFrame.new()
			setJoint("Base", CFrame.new(0, -0.06 * scale * dip, 0) * tremble)
			local pl0 = light
			if pl0 and tau < lidAt and held > 0 then
				pl0.Brightness = Cfg.TEASE_GLOW * (1 + 2 * held)
			end
			local lt = tau - lidAt
			if lt >= 0 then
				if once("lid") then
					if holdBaseFov then
						local cam = workspace.CurrentCamera
						if cam then
							cam.FieldOfView = holdBaseFov
						end
						holdBaseFov = nil
					end
					sound(Cfg.SOUNDS.Lid, root, gain)
					local r = result
					if r then
						sound(Cfg.SOUNDS.Burst, root, gain)
						sound(Cfg.SOUNDS.LidBoom, root, gain)
						sound(Cfg.SOUNDS.Swell, root, gain)
						if lead then
							sound(Cfg.REVEAL[r.tier] or Cfg.REVEAL.Common, root, audienceGain)
							for _, extra in fx.extra do
								sound(extra, root, audienceGain)
							end
						end
					end
					if r and burst then
						local b0 = burst :: Attachment
						local burstCount = if reduced then math.min(fx.sparks, 20) else fx.sparks
						sparks(b0, tierColor, burstCount, 16 + tierOrder * 3)
						if not reduced then
							for w = 1, fx.waves do
								task.delay(0.14 * w, function()
									if b0.Parent then
										sparks(
											b0,
											tierColor,
											math.floor(fx.sparks * 0.6),
											20 + tierOrder * 3
										)
									end
								end)
							end
						end
						glow(b0, tierColor, 5 + tierOrder * 1.5, 0.6)
						if fx.beam > 0 then
							beam(
								b0,
								tierColor,
								(Cfg.BEAM_HEIGHT + tierOrder) * fx.beam,
								Cfg.BEAM_TIME * fx.beam,
								if tierOrder >= 4 then 1.45 else 1
							)
							if tierOrder >= 4 and not reduced then
								beam(
									b0,
									Color3.new(1, 1, 1),
									(Cfg.BEAM_HEIGHT + tierOrder) * fx.beam * 0.85,
									Cfg.BEAM_TIME * fx.beam * 0.75,
									0.55
								)
							end
						end
						local l = light
						if not l then
							l = Instance.new("PointLight")
							l.Shadows = false
							l.Parent = burst
							light = l
						end
						local pl = l :: PointLight
						pl.Color = tierColor
						pl.Range = Cfg.LIGHT_RANGE
						pl.Brightness = Cfg.LIGHT_PEAK
						TweenService:Create(
							pl,
							TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
							{ Brightness = Cfg.LIGHT_PEAK * 0.3 }
						):Play()
					end
					local ringCount = if r then fx.rings else 0
					for k = 1, ringCount do
						task.delay((k - 1) * 0.12, function()
							ring(
								land * CFrame.new(0, 0.06, 0),
								tierColor,
								Cfg.RING_SIZE * (0.7 + 0.1 * tierOrder) * (1 + 0.25 * (k - 1)),
								Cfg.RING_TIME
							)
						end)
					end
					if isLocal and lead and not reduced then
						kick(Cfg.CAMERA_KICK * fx.kick, Cfg.FOV_PUNCH * fx.kick)
						flash(tierColor, fx.flash)
					end
				end
				local p = clamp01(lt / Cfg.LID_TIME)
				local angle = Cfg.LID_ANGLE * backOut(p, 1.2 + Cfg.LID_OVERSHOOT / 20)
				setJoint("Lid", CFrame.Angles(math.rad(angle), 0, 0))
				setJoint("Gem", CFrame.Angles(0, lt * 4, 0))
			else
				-- the lid strains against the latches
				setJoint(
					"Lid",
					CFrame.Angles(math.rad(6 * coil + math.sin(tau * 60) * 1.5 * coil), 0, 0)
				)
			end
			local rt = lt - Cfg.RISE_DELAY
			if rt >= 0 then
				if once("rise") then
					revealSkin()
				end
				local home = skinHome
				local m = skin
				if home and m then
					local p = quintOut(clamp01(rt / Cfg.RISE_TIME))
					local start = home - Vector3.new(0, Cfg.RISE_HEIGHT + 0.6, 0)
					local spin = math.rad(360) * (1 - (1 - clamp01(rt / 1.3)) ^ 3)
						+ math.rad(Cfg.SPIN_SPEED) * math.max(rt - 1.3, 0)
					local bob = math.sin(rt * 2.2) * 0.12 * clamp01(rt - Cfg.RISE_TIME)
					m:PivotTo(
						start:Lerp(home, p) * CFrame.new(0, bob, 0) * CFrame.Angles(0, spin, 0)
					)
				end
				if rt > Cfg.RISE_TIME + Cfg.HOLD then
					if not result then
						startSink()
						return
					end
					phase = "collect"
					collectAt = now
					flyFrom = if skin then (skin :: Model):GetPivot() else nil
					sound(Cfg.SOUNDS.Fly, root, gain)
					local gui = cardGui
					local holder = gui and gui:FindFirstChild("Holder")
					local pop = holder and holder:FindFirstChildWhichIsA("UIScale")
					if pop then
						TweenService:Create(
							pop,
							TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In),
							{ Scale = 0 }
						):Play()
					end
					local au = aura
					if au then
						for _, e in au:GetChildren() do
							if e:IsA("ParticleEmitter") then
								e.Enabled = false
							end
						end
					end
					-- a trail behind the skin as it flies
					local m2 = skin
					local part = m2 and m2:FindFirstChildWhichIsA("BasePart", true)
					if part then
						local a0 = Instance.new("Attachment")
						a0.Position = Vector3.new(0, 0.25, 0)
						a0.Parent = part
						local a1 = Instance.new("Attachment")
						a1.Position = Vector3.new(0, -0.25, 0)
						a1.Parent = part
						local tr = Instance.new("Trail")
						tr.Attachment0, tr.Attachment1 = a0, a1
						tr.Color = ColorSequence.new(tierColor)
						tr.LightEmission = 1
						tr.Lifetime = 0.3
						tr.Transparency = NumberSequence.new(0.2, 1)
						tr.Parent = part
					end
				end
			end
			return
		end
		if phase == "collect" then
			local tau = now - collectAt
			local target = rootOf(owner)
			local m = skin
			local from = flyFrom
			if m and from and target then
				local p = quadIn(clamp01(tau / Cfg.FLY_TIME))
				local goal = target.Position + Vector3.new(0, 0.6, 0)
				local mid = from.Position:Lerp(goal, 0.5) + Vector3.new(0, Cfg.FLY_ARC, 0)
				local a = from.Position:Lerp(mid, p)
				local b = mid:Lerp(goal, p)
				local pos = a:Lerp(b, p)
				m:ScaleTo(skinScale * math.max(0.15, 1 - 0.85 * p))
				m:PivotTo(
					CFrame.new(pos)
						* from.Rotation
						* CFrame.Angles(0, math.rad(Cfg.FLY_SPIN) * p, 0)
				)
			end
			if tau >= Cfg.FLY_TIME then
				if m then
					m:Destroy()
					skin = nil
				end
				if target then
					local att = Instance.new("Attachment")
					att.Position = Vector3.new(0, 0.6, 0)
					att.Parent = target
					sparks(att, tierColor, 22, 11)
					glow(att, tierColor, 5, 0.45)
					ring(CFrame.new(target.Position - Vector3.new(0, 2.8, 0)), tierColor, 9, 0.45)
					sound(Cfg.SOUNDS.Collect, target, gain)
					sound(Cfg.SOUNDS.CollectSpark, target, gain)
					Debris:AddItem(att, 2)
					if isLocal and lead and not UiMotion.reduced() then
						kick(Cfg.CAMERA_KICK * 0.4, 2)
					end
				end
				for _, x in { anchor, aura } :: { Instance? } do
					if x then
						x:Destroy()
					end
				end
				anchor, aura = nil, nil
				local l = light
				if l then
					TweenService:Create(l, TweenInfo.new(0.4), { Brightness = 0 }):Play()
				end
				startSink()
			end
			return
		end
		if phase == "sink" then
			local p = quadIn(clamp01((now - sinkAt) / Cfg.SINK_TIME))
			model:PivotTo(land * CFrame.new(0, -1.6 * scale * p, 0))
			if p >= 1 then
				cleanup()
			end
		end
	end)

	local function reveal(r: Result?, schedule: Timing, isLead: boolean, done: () -> ())
		result = r
		timing = schedule
		lead = isLead
		onDone = done
		if r then
			fx = (Cfg.TIER_FX :: any)[r.tier] or Cfg.TIER_FX.Common
			-- Ask now so an on-demand skin and its art arrive before the lid opens.
			if not r.power then
				Locker.skinModel(r.gun, r.line)
			end
			task.spawn(function()
				local imgs: { Instance } = {}
				local urls = if r.power
					then { Theme.CARD_ART[r.power or ""] }
					else { SkinArt.portrait(r.gun, r.line), SkinArt.side(r.gun, r.line) }
				for _, url in urls do
					if typeof(url) == "string" and url ~= "" then
						local lbl = Instance.new("ImageLabel")
						lbl.Image = url
						table.insert(imgs, lbl)
					end
				end
				if #imgs > 0 then
					pcall(ContentProvider.PreloadAsync, ContentProvider, imgs)
					for _, inst in imgs do
						inst:Destroy()
					end
				end
			end)
		end
	end

	return {
		reveal = reveal,
		abort = startSink,
		canReveal = function()
			return phase == "toss" or phase == "wait"
		end,
		isDead = function()
			return phase == "dead"
		end,
	}
end

function CaseOpening.start(
	owner: Player,
	crateTier: number,
	isLocal: boolean,
	count: number
): Handle?
	local ownerRoot = rootOf(owner)
	if not ownerRoot then
		return nil
	end
	warmAudio()

	local ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true

	count = math.clamp(count, 1, Cfg.MAX_CRATES)
	local wide = count > #Cfg.BATCH_ANGLES
	local angles: { number } = if count == 1 then { 0 } elseif wide then {} else Cfg.BATCH_ANGLES
	if wide then
		-- centre-out, so the middle crates get the clear spots first
		local order: { number } = {}
		for i = 1, count do
			table.insert(order, (i - (count + 1) / 2) * Cfg.WIDE_STEP)
		end
		table.sort(order, function(a, b)
			return math.abs(a) < math.abs(b)
		end)
		angles = order
	end
	local distance = if count == 1
		then Cfg.DISTANCE
		elseif wide then Cfg.WIDE_DISTANCE
		else Cfg.BATCH_DISTANCE
	local distances = { distance }
	for _, alternate in Cfg.TRY_DISTANCES do
		table.insert(distances, alternate)
	end
	local occupied: { Vector3 } = {}
	local origin = ownerRoot.Position
	local flat = ownerRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
	local look = if flat.Magnitude >= 0.1 then flat.Unit else -Vector3.zAxis
	local landings: { CFrame? } = table.create(count)
	local function reserve(i: number, land: CFrame)
		landings[i] = land
		table.insert(occupied, land.Position)
	end
	-- Reserve the preferred spots first so a blocked slot can't take its neighbour's.
	for i, angle in angles do
		local land = landingSpot(origin, look, params, angle, distance, occupied)
		if land then
			reserve(i, land)
		end
	end
	local function search(angle: number, height: number?): CFrame?
		for _, radius in distances do
			for _, offset in Cfg.TRY_ANGLES do
				local land =
					landingSpot(origin, look, params, angle + offset, radius, occupied, height)
				if land then
					return land
				end
			end
		end
		return nil
	end
	for i, angle in angles do
		if not landings[i] then
			local land = search(angle)
			if land then
				reserve(i, land)
			end
		end
	end

	local slots: { CrateHandle } = {}
	for i, angle in angles do
		local land = landings[i] or search(angle, Cfg.HOVER_HEIGHT)
		if not land then
			-- Keep the full opening visible even if the player is boxed in or over a void.
			local dir = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(look)
			local target = origin
				+ dir * distance
				+ Vector3.yAxis * (Cfg.HOVER_HEIGHT + Cfg.BATCH_MIN_SPACING)
			land = facingOpener(target, origin)
		end
		-- Nearby hovering crates also use distinct spots.
		if not landings[i] then
			reserve(i, land)
		end
		local crate = startCrate(owner, origin, crateTier, isLocal, land, count)
		if crate then
			table.insert(slots, crate)
		end
	end
	if next(slots) == nil then
		return nil
	end

	local function reveal(_self: Handle, results: { Result }, onDone: (() -> ())?): boolean
		local active: { CrateHandle } = {}
		for _, slot in slots do
			if slot.canReveal() then
				table.insert(active, slot)
			end
		end
		if #active == 0 or #results == 0 then
			return false
		end

		-- Match the longest build-up so every lid bursts on the same beat.
		local shown = math.min(#active, #results)
		local deadline = os.clock() + Cfg.SKIN_WAIT
		local ready = false
		local checkedShake = 0
		local function modelsReady(shake: number): boolean
			if ready or shake == checkedShake then
				return ready
			end
			checkedShake = shake
			if os.clock() >= deadline then
				ready = true
				return true
			end
			for i = 1, shown do
				local reward = results[i]
				local model = if reward.power
					then nil
					else Locker.skinModel(reward.gun, reward.line)
				if
					not reward.power
					and (not model or not model:FindFirstChildWhichIsA("BasePart", true))
				then
					return false
				end
			end
			ready = true
			return true
		end
		local timing: Timing =
			{ shakes = Cfg.SHAKES, lidAt = Cfg.LID_AT, modelsReady = modelsReady }
		local lead = 1
		local highestTier = 0
		for i = 1, shown do
			local tierId = results[i].tier
			local tier = Skins.TIERS[tierId :: any] or Skins.TIERS.Common
			local fx = (Cfg.TIER_FX :: any)[tierId] or Cfg.TIER_FX.Common
			timing.shakes = math.max(timing.shakes, (Cfg.TIER_SHAKES :: any)[tierId] or Cfg.SHAKES)
			timing.lidAt = math.max(timing.lidAt, Cfg.LID_AT + fx.hold)
			if tier.order > highestTier then
				lead = i
				highestTier = tier.order
			end
		end

		local remaining = #active
		local function finished()
			remaining -= 1
			if remaining == 0 and onDone then
				onDone()
			end
		end
		for i, slot in active do
			slot.reveal(results[i], timing, i == lead, finished)
		end
		return true
	end

	return {
		reveal = reveal,
		abort = function()
			for _, slot in slots do
				slot.abort()
			end
		end,
		isDead = function()
			for _, slot in slots do
				if not slot.isDead() then
					return false
				end
			end
			return true
		end,
	}
end

return CaseOpening
