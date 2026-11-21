--!strict
-- The in-world case opening (vault/01 Design/Case Opening.md; numbers in
-- Shared/Config/CaseOpening). Client-side and cosmetic: the server has already rolled
-- the skin (Services/ShopService); this only shows it.
--
--   local h = CaseOpening.start(owner, crateTier, isLocal)   -- tossed out, shaking
--   h:reveal({ gun, line, tier, name }, onDone)              -- the build-up and the burst
--   h:abort()                                                -- refused: it sinks away
--
-- Beats: toss → shakes (more for higher tiers; the seams glow in the tier colour before
-- the lid goes) → latches → dip → lid burst (flash, sparks, floor ring, light beam,
-- camera kick for you) → the skin rises and turns in its glow with the card (portrait
-- on its tier tile) → it arcs and spins into you with a trail → collect burst; the
-- crate sinks. Others see the same at the opener, quieter, with their name on the card.
-- The crate is ReplicatedStorage.Crates.Crate (Motor6D Base, Lid, Gem, LatchL, LatchR,
-- Handle; positive X angle = open). Studio review: workspace StateValue CaseTimeScale.

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
local Vfx = require(ReplicatedStorage.Shared.Config.VfxTextures)
local ItemStage = require(script.Parent.ItemStage)

export type Result = { gun: string, line: string, tier: string, name: string }

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

-- a clear floor spot in front of the player (tries other angles when blocked)
local function landingSpot(root: BasePart, ignore: { Instance }): CFrame?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.1 then
		look = Vector3.new(0, 0, -1)
	end
	look = look.Unit
	local from = root.Position
	for _, deg in Cfg.TRY_ANGLES do
		local dir = CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(look)
		local target = from + dir * Cfg.DISTANCE
		if not workspace:Raycast(from, target - from, params) then
			local down =
				workspace:Raycast(target + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), params)
			if down then
				local floor = down.Position
				return CFrame.lookAt(floor, Vector3.new(from.X, floor.Y, from.Z)) -- front toward the player
			end
		end
	end
	return nil
end

local function sound(spec: any, parent: Instance, gain: number)
	local snd = Instance.new("Sound")
	snd.SoundId = spec.id
	snd.Volume = spec.volume * gain
	snd.PlaybackSpeed = spec.pitch
	snd.RollOffMode = Enum.RollOffMode.InverseTapered
	snd.RollOffMinDistance = Cfg.ROLLOFF.X
	snd.RollOffMaxDistance = Cfg.ROLLOFF.Y
	snd.Parent = parent
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
local function beam(from: Attachment, color: Color3, height: number, time: number)
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
	b.Width0, b.Width1 = 2.4, 0.6
	b.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	b.Parent = top
	local fade = Instance.new("NumberValue")
	fade.Value = 0
	fade.Changed:Connect(function(v: number)
		b.Width0 = 2.4 * (1 - v) + 0.2
		b.Width1 = 0.6 * (1 - v) + 0.05
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
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
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
	g.IgnoreGuiInset = true
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
	who: string?
): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = "CaseCard"
	bb.Size = UDim2.fromScale(Cfg.CARD_SIZE.X, Cfg.CARD_SIZE.Y)
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
	pic.Image = SkinArt.portrait(result.gun, result.line) or ""
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
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = c
		l.Text = text
		l.ZIndex = 2
		l.Parent = holder
	end
	if who then
		label("Who", string.upper(who) .. " UNBOXED", 0.1, 0.18, Color3.fromHex("9F9FA2"))
	end
	label("Name", result.name, if who then 0.3 else 0.16, 0.36, color)
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
	return bb
end

type Phase = "toss" | "wait" | "open" | "collect" | "sink" | "dead"

export type Handle = {
	reveal: (self: Handle, result: Result, onDone: (() -> ())?) -> (),
	abort: (self: Handle) -> (),
	isDead: (self: Handle) -> boolean,
}

function CaseOpening.start(owner: Player, crateTier: number, isLocal: boolean): Handle?
	local ownerRoot = rootOf(owner)
	local model = CrateLook.make(crateTier)
	if not ownerRoot or not model then
		return nil
	end
	local ignore: { Instance } = { model }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	local land = landingSpot(ownerRoot, ignore)
	if not land then
		model:Destroy()
		return nil
	end
	local gain = if isLocal then 1 else Cfg.OTHERS_VOLUME
	-- the tier's model decides its size (the Knife case is smaller: Config/Crates)
	local scale = CrateLook.scale(crateTier) or Cfg.SCALE
	model.Name = "CaseOpening_" .. owner.UserId
	model:ScaleTo(scale)
	local root = model.PrimaryPart :: BasePart
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

	local startCF = CFrame.new(ownerRoot.Position + Vector3.new(0, 1, 0)) * land.Rotation
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

	local function targetShakes(): number
		local r = result
		return math.max(
			Cfg.SHAKES,
			if r then (Cfg.TIER_SHAKES :: any)[r.tier] or Cfg.SHAKES else Cfg.SHAKES
		)
	end

	-- the seams glow in the tier colour: the tease before the lid
	local function tease()
		local r = result
		if not r or not once("tease") then
			return
		end
		local tier = Skins.TIERS[r.tier :: any] or Skins.TIERS.Common
		tierColor = tier.color
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
		local src = Locker.skinModel(r.gun, r.line)
		if src then
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
			tier.name,
			if isLocal then nil else owner.DisplayName
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
			if tau > Cfg.WAIT_LIMIT then
				startSink()
				return
			end
			local k = math.floor((tau - 0.25) / Cfg.SHAKE_EVERY)
			if k >= 0 and k ~= lastShake then
				lastShake = k
				shakes += 1
				sound(Cfg.SOUNDS.Shake, root, gain)
				sound(Cfg.SOUNDS.Rattle, root, gain)
				if result and shakes >= targetShakes() - 1 then
					tease()
				end
				if result and shakes > targetShakes() then
					phase = "open"
					openAt = now
					local r = result :: Result
					fx = (Cfg.TIER_FX :: any)[r.tier] or Cfg.TIER_FX.Common
					lidAt = Cfg.LID_AT + fx.hold
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
			for i, n in { "LatchL", "LatchR" } do
				local lt = tau - (i - 1) * Cfg.LATCH_GAP
				if lt >= 0 and once(n) then
					sound(Cfg.SOUNDS.Latch, root, gain)
				end
				local a = backOut(clamp01(lt / Cfg.LATCH_TIME), 2.4) * Cfg.LATCH_ANGLE
				setJoint(n, CFrame.Angles(math.rad(math.max(a, 0)), 0, 0))
			end
			local coil = clamp01((tau - Cfg.COIL) / (lidAt - Cfg.COIL))
			local dip = if tau < lidAt
				then math.sin(coil * math.pi * 0.5)
				else 1 - clamp01((tau - lidAt) / 0.15)
			-- the held beat (higher tiers): the crate trembles and the glow ramps up
			local held = if fx.hold > 0 then clamp01((tau - Cfg.LID_AT) / fx.hold) else 0
			if fx.hold > 0 and tau >= Cfg.LID_AT - 0.05 and once("riser") then
				sound(Cfg.RISER, root, gain)
			end
			local tremble = if tau < lidAt and held > 0
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
					local r = result :: Result
					local tier = Skins.TIERS[r.tier :: any] or Skins.TIERS.Common
					tierColor = tier.color
					tierOrder = tier.order
					sound(Cfg.SOUNDS.Lid, root, gain)
					sound(Cfg.SOUNDS.Burst, root, gain)
					sound(Cfg.SOUNDS.LidBoom, root, gain)
					sound(Cfg.SOUNDS.Swell, root, gain)
					sound(Cfg.REVEAL[r.tier] or Cfg.REVEAL.Common, root, gain)
					for _, extra in fx.extra do
						sound(extra, root, gain)
					end
					if burst then
						local b0 = burst :: Attachment
						sparks(b0, tierColor, fx.sparks, 16 + tierOrder * 3)
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
						glow(b0, tierColor, 5 + tierOrder * 1.5, 0.6)
						if fx.beam > 0 then
							beam(
								b0,
								tierColor,
								(Cfg.BEAM_HEIGHT + tierOrder) * fx.beam,
								Cfg.BEAM_TIME * fx.beam
							)
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
					for k = 1, fx.rings do
						task.delay((k - 1) * 0.12, function()
							ring(
								land * CFrame.new(0, 0.06, 0),
								tierColor,
								Cfg.RING_SIZE * (0.7 + 0.1 * tierOrder) * (1 + 0.25 * (k - 1)),
								Cfg.RING_TIME
							)
						end)
					end
					if isLocal then
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
					if isLocal then
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

	local handle = {} :: any
	function handle.reveal(_self: Handle, r: Result, done: (() -> ())?)
		if phase == "dead" or phase == "sink" then
			if done then
				task.spawn(done)
			end
			return
		end
		result = r
		onDone = done
	end
	function handle.abort(_self: Handle)
		startSink()
	end
	function handle.isDead(_self: Handle): boolean
		return phase == "dead"
	end
	return handle :: Handle
end

return CaseOpening
