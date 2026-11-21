--!strict
-- The in-world case opening (vault/01 Design/Case Opening.md; numbers in
-- Shared/Config/CaseOpening). Client-side and cosmetic: the server has already rolled
-- the skin (Services/ShopService); this only shows it.
--
--   local h = CaseOpening.start(owner, crateTier, isLocal)   -- tossed out, shaking
--   h:reveal({ gun, line, tier, name }, onDone)              -- latches, lid, the skin
--   h:abort()                                                -- refused: it sinks away
--
-- The opener starts it on OPEN (the toss hides the server's round trip); other
-- players start and reveal at once from the CaseShow broadcast, quieter, with the
-- opener's name on the card. The crate is ReplicatedStorage.Crates.Crate (rigged:
-- Motor6D Base, Lid, Gem, LatchL, LatchR, Handle; positive X angle = open).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Cfg = require(ReplicatedStorage.Shared.Config.CaseOpening)
local CrateLook = require(ReplicatedStorage.Shared.CrateLook)
local Locker = require(ReplicatedStorage.Shared.Locker)
local Skins = require(ReplicatedStorage.Shared.Config.Skins)
local Vfx = require(ReplicatedStorage.Shared.Config.VfxTextures)
local ItemStage = require(script.Parent.ItemStage)
local StateValues = require(ReplicatedStorage.Shared.StateValues)

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
local function quintIn(x: number): number
	return x ^ 5
end

local function rootOf(p: Player): BasePart?
	local ch = p.Character
	local r = ch and ch:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

-- a clear floor spot in front of the player (tries other angles when blocked)
local function landingSpot(root: BasePart, ignore: { Instance }): (CFrame?, Vector3)
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
				-- the crate faces the player, its front toward them
				local floor = down.Position
				local face = CFrame.lookAt(floor, Vector3.new(from.X, floor.Y, from.Z))
				return face, dir
			end
		end
	end
	return nil, look
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
	Debris:AddItem(snd, 8)
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.Enabled = true
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
			NumberSequenceKeypoint.new(0, 0.32),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(0.45, 0.85),
		Speed = NumberRange.new(speed * 0.6, speed),
		SpreadAngle = Vector2.new(30, 30),
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

-- the floating name card (our look: a dark plate, the name in the tier colour,
-- the tier underneath; the opener's name on top for everyone else)
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
	holder.Size = UDim2.fromScale(0.3, 0.3)
	holder.BackgroundColor3 = Color3.fromHex("141417")
	holder.BackgroundTransparency = 0.08
	holder.BorderSizePixel = 0
	holder.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.12, 0)
	corner.Parent = holder
	local function label(name: string, text: string, y: number, h: number, c: Color3)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0.05, y)
		l.Size = UDim2.fromScale(0.9, h)
		l.FontFace = FONT
		l.TextScaled = true
		l.TextColor3 = c
		l.Text = text
		l.Parent = holder
	end
	if who then
		label("Who", string.upper(who) .. " UNBOXED", 0.06, 0.2, Color3.fromHex("9F9FA2"))
		label("Name", result.name, 0.28, 0.4, color)
	else
		label("Name", result.name, 0.1, 0.52, color)
	end
	local tag = Instance.new("Frame")
	tag.Name = "Tier"
	tag.AnchorPoint = Vector2.new(0.5, 0)
	tag.Position = UDim2.fromScale(0.5, 0.72)
	tag.Size = UDim2.fromScale(0.36, 0.2)
	tag.BackgroundColor3 = color
	tag.BorderSizePixel = 0
	tag.Parent = holder
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.FontFace = FONT
	tl.TextScaled = true
	tl.TextColor3 = Color3.fromHex("0F0F12")
	tl.Text = tierName
	tl.Parent = tag
	bb.Parent = anchor
	TweenService:Create(
		holder,
		TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(1, 1) }
	):Play()
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
	local land, _dir = landingSpot(ownerRoot, ignore)
	if not land then
		model:Destroy()
		return nil
	end
	local gain = if isLocal then 1 else Cfg.OTHERS_VOLUME
	model.Name = "CaseOpening_" .. owner.UserId
	model:ScaleTo(Cfg.SCALE)
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
	local footing = Instance.new("Attachment")
	footing.Name = "Footing"
	footing.Parent = root

	local startCF = CFrame.new(ownerRoot.Position + Vector3.new(0, 1, 0)) * land.Rotation
	model:PivotTo(startCF * CFrame.Angles(0, math.rad(Cfg.TOSS_SPIN), 0))
	model.Parent = workspace
	sound(Cfg.SOUNDS.Toss, root, gain)

	local phase: Phase = "toss"
	-- the sequence's own clock: Studio review can slow it with the workspace value
	-- CaseTimeScale (e.g. 0.15) to capture each beat
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
	local skinHome: CFrame? = nil
	local anchor: BasePart? = nil
	local cardGui: BillboardGui? = nil
	local light: PointLight? = nil
	local tierColor = Color3.new(1, 1, 1)
	local collectAt = 0
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
		if skin then
			skin:Destroy()
		end
		if anchor then
			anchor:Destroy()
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

	local function revealSkin()
		local r = result
		if not r then
			return
		end
		local top = land.Position + Vector3.new(0, 1.0 * Cfg.SCALE, 0)
		local src = Locker.skinModel(r.gun, r.line)
		if src then
			local m = ItemStage.presentable(src)
			local size = m:GetExtentsSize()
			local longest = math.max(size.X, size.Y, size.Z)
			if longest > 0 then
				m:ScaleTo(Cfg.SKIN_LENGTH / longest)
			end
			m.Name = "CaseSkin"
			m:PivotTo(CFrame.new(top - Vector3.new(0, 0.6, 0)) * land.Rotation)
			m.Parent = workspace
			skin = m
		end
		skinHome = CFrame.new(top + Vector3.new(0, Cfg.RISE_HEIGHT, 0)) * land.Rotation
		local a = Instance.new("Part")
		a.Name = "CaseCardAnchor"
		a.Anchored = true
		a.CanCollide, a.CanQuery, a.CanTouch = false, false, false
		a.Transparency = 1
		a.Size = Vector3.new(0.2, 0.2, 0.2)
		a.CFrame = CFrame.new(top + Vector3.new(0, Cfg.RISE_HEIGHT + Cfg.CARD_UP, 0))
		a.Parent = workspace
		anchor = a
		local tier = Skins.TIERS[r.tier :: any] or Skins.TIERS.Common
		cardGui = card(a, r, tier.color, tier.name, if isLocal then nil else owner.DisplayName)
	end

	conn = RunService.RenderStepped:Connect(function(dt: number)
		local scale = StateValues.get(workspace, "CaseTimeScale")
		clock += dt * (if typeof(scale) == "number" and RunService:IsStudio() then scale else 1)
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
				if result and shakes > Cfg.SHAKES then
					phase = "open"
					openAt = now
					return
				end
			end
			local local_ = (tau - 0.25) - math.max(lastShake, 0) * Cfg.SHAKE_EVERY
			if lastShake >= 0 and local_ < 0.32 then
				local amp = Cfg.SHAKE_ANGLES[math.min(shakes, #Cfg.SHAKE_ANGLES)]
				local env = 1 - local_ / 0.32
				local rz = math.rad(amp) * math.sin(local_ * math.pi * 2 * 3.2) * env
				local hop = math.sin(clamp01(local_ / 0.2) * math.pi)
					* 0.05
					* Cfg.SCALE
					* (shakes - 1)
				setJoint("Base", CFrame.new(0, hop, 0) * CFrame.Angles(0, 0, rz))
				setJoint(
					"Handle",
					CFrame.Angles(math.rad(25) * math.sin(local_ * math.pi * 2 * 2) * env, 0, 0)
				)
			else
				setJoint("Base", CFrame.new())
				setJoint("Handle", CFrame.new())
			end
			return
		end
		if phase == "open" then
			local tau = now - openAt
			-- latches snap down, one after the other
			for i, n in { "LatchL", "LatchR" } do
				local lt = tau - (i - 1) * Cfg.LATCH_GAP
				if lt >= 0 and once(n) then
					sound(Cfg.SOUNDS.Latch, root, gain)
				end
				local a = backOut(clamp01(lt / Cfg.LATCH_TIME), 2.4) * Cfg.LATCH_ANGLE
				setJoint(n, CFrame.Angles(math.rad(math.max(a, 0)), 0, 0))
			end
			-- anticipation: the crate dips, the lid cracks
			local coil = clamp01((tau - Cfg.COIL) / (Cfg.LID_AT - Cfg.COIL))
			local dip = if tau < Cfg.LID_AT
				then math.sin(coil * math.pi * 0.5)
				else 1 - clamp01((tau - Cfg.LID_AT) / 0.15)
			setJoint("Base", CFrame.new(0, -0.05 * Cfg.SCALE * dip, 0))
			-- the lid bursts
			local lt = tau - Cfg.LID_AT
			if lt >= 0 then
				if once("lid") then
					local r = result :: Result
					local tier = Skins.TIERS[r.tier :: any] or Skins.TIERS.Common
					tierColor = tier.color
					sound(Cfg.SOUNDS.Lid, root, gain)
					sound(Cfg.SOUNDS.Swell, root, gain)
					sound(Cfg.REVEAL[r.tier] or Cfg.REVEAL.Common, root, gain)
					if burst then
						sparks(burst, tierColor, 28 + tier.order * 10, 16 + tier.order * 3)
						glow(burst, tierColor, 5 + tier.order * 1.5, 0.6)
						local l = Instance.new("PointLight")
						l.Color = tierColor
						l.Range = Cfg.LIGHT_RANGE
						l.Brightness = Cfg.LIGHT_PEAK
						l.Shadows = false
						l.Parent = burst
						light = l
						TweenService:Create(
							l,
							TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
							{ Brightness = Cfg.LIGHT_PEAK * 0.3 }
						):Play()
					end
				end
				local p = clamp01(lt / Cfg.LID_TIME)
				local angle = Cfg.LID_ANGLE * backOut(p, 1.2 + Cfg.LID_OVERSHOOT / 20)
				setJoint("Lid", CFrame.Angles(math.rad(angle), 0, 0))
				setJoint("Gem", CFrame.Angles(0, lt * 4, 0))
			else
				setJoint("Lid", CFrame.Angles(math.rad(6 * coil), 0, 0))
			end
			-- the skin rises and turns
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
					local gui = cardGui
					local holder = gui and gui:FindFirstChild("Holder")
					if holder and holder:IsA("Frame") then
						TweenService:Create(
							holder,
							TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In),
							{ Size = UDim2.fromScale(0, 0) }
						):Play()
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
				local p = quintIn(clamp01(tau / Cfg.FLY_TIME))
				m:PivotTo(from:Lerp(target.CFrame, p))
			end
			if tau >= Cfg.FLY_TIME then
				if m then
					m:Destroy()
					skin = nil
				end
				if target then
					local att = Instance.new("Attachment")
					att.Parent = target
					sparks(att, tierColor, 18, 10)
					glow(att, tierColor, 4, 0.4)
					sound(Cfg.SOUNDS.Collect, target, gain)
					Debris:AddItem(att, 2)
				end
				if anchor then
					anchor:Destroy()
					anchor = nil
				end
				local l = light
				if l then
					TweenService:Create(l, TweenInfo.new(0.4), { Brightness = 0 }):Play()
				end
				startSink()
			end
			return
		end
		if phase == "sink" then
			local p = quintIn(clamp01((now - sinkAt) / Cfg.SINK_TIME))
			model:PivotTo(land * CFrame.new(0, -1.6 * Cfg.SCALE * p, 0))
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
