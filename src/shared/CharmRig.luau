--!strict
-- Attaches a charm Model onto a gun's CharmPoint, drives 2-axis gravity-seeking
-- spring-pendulum physics, animated sub-parts (Joystick, ClockworkGear,
-- ReactorCore), live reactive screens (HighScore, KillRadar), and shot/kill VFX
-- across all 32 charms. Lives in ReplicatedStorage.Shared for Client and Locker.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharmsConfig = require(ReplicatedStorage.Shared.Config.Charms)

export type Mode = "anchored" | "world"

export type Options = {
	mode: Mode?,
	kills: number?,
	castShadow: boolean?,
	viewYawBias: number?,
	gunId: string?,
}

type StaticPart = {
	part: BasePart,
	rel: CFrame,
	neon: boolean,
	baseColor: Color3,
}

type AnimPart = {
	part: BasePart,
	role: string,
	originRel: Vector3,
	restFromOrigin: CFrame,
	motor: Motor6D?,
}

export type State = {
	id: string,
	def: CharmsConfig.CharmDef,
	mode: Mode,
	model: Model,
	pivot: BasePart,
	point: Attachment,
	mountRot: CFrame,
	mountMotor: Motor6D?,
	parts: { BasePart },
	staticParts: { StaticPart },
	animParts: { AnimPart },
	emitters: { { emitter: ParticleEmitter, baseRate: number } },
	light: PointLight?,
	lightBase: number,
	pitch: number,
	pitchVel: number,
	roll: number,
	rollVel: number,
	twist: number,
	twistVel: number,
	lastPos: Vector3?,
	lastVel: Vector3,
	lastRight: Vector3?,
	elapsed: number,
	spinAngle: number,
	spinBoost: number,
	stickX: number,
	stickZ: number,
	stickSpin: number,
	pulse: number,
	pulseKind: "fire" | "kill",
	kills: number,
	screenGui: SurfaceGui?,
	scoreLabel: TextLabel?,
	radarBeam: Frame?,
	radarPing: Frame?,
	radarDots: Frame?,
	hiddenNow: boolean,
}

local CharmRig = {}

local MAX_DT = 1 / 20
local TELEPORT_DIST = 3.5

local function setPartHidden(part: BasePart, value: number)
	part.LocalTransparencyModifier = value
	for _, child in part:GetChildren() do
		if child:IsA("Decal") then
			child.LocalTransparencyModifier = value
		end
	end
end

local function makeEmitter(
	parent: Instance,
	def: CharmsConfig.CharmDef,
	scale: number
): (ParticleEmitter, number)
	local idle = def.fx.idle
	local accent = def.accent
	local pScale = math.clamp(scale / 0.56, 0.35, 1.5)
	local vScale = math.clamp(scale / 0.56, 0.45, 1.4)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "CharmVfx"
	emitter.LockedToPart = true
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.LightEmission = 0.75
	emitter.LightInfluence = 0.25
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(0.18 * vScale, 0.45 * vScale)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.32, 0.58)
	emitter.Drag = 4
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, accent:Lerp(Color3.new(1, 1, 1), 0.35)),
		ColorSequenceKeypoint.new(1, accent),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.7, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.028 * pScale),
		NumberSequenceKeypoint.new(0.5, 0.036 * pScale),
		NumberSequenceKeypoint.new(1, 0),
	})

	local baseRate = 0
	if idle == "frost" then
		emitter.Acceleration = Vector3.new(0, -0.35, 0)
		emitter.Speed = NumberRange.new(0.08 * vScale, 0.22 * vScale)
		emitter.Lifetime = NumberRange.new(0.55, 0.95)
		emitter.RotSpeed = NumberRange.new(-90, 90)
		baseRate = 4
	elseif idle == "ember" then
		emitter.Acceleration = Vector3.new(0, 1.4, 0)
		emitter.Speed = NumberRange.new(0.25 * vScale, 0.55 * vScale)
		emitter.Lifetime = NumberRange.new(0.30, 0.55)
		emitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 110)),
			ColorSequenceKeypoint.new(0.55, accent),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 28, 12)),
		})
		baseRate = 6
	elseif idle == "electric" then
		emitter.Speed = NumberRange.new(0.45 * vScale, 0.95 * vScale)
		emitter.Lifetime = NumberRange.new(0.14, 0.26)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.032 * pScale),
			NumberSequenceKeypoint.new(1, 0),
		})
		baseRate = 6
	elseif idle == "plasma" or idle == "glitch" then
		emitter.Speed = NumberRange.new(0.22 * vScale, 0.55 * vScale)
		emitter.Lifetime = NumberRange.new(0.22, 0.42)
		baseRate = 4.5
	elseif idle == "mist" then
		emitter.Acceleration = Vector3.new(0, 0.45, 0)
		emitter.Speed = NumberRange.new(0.12 * vScale, 0.28 * vScale)
		emitter.Lifetime = NumberRange.new(0.50, 0.85)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.040 * pScale),
			NumberSequenceKeypoint.new(1, 0.008 * pScale),
		})
		baseRate = 4.5
	elseif idle == "crimson" or idle == "goldglint" or idle == "heartbeat" then
		emitter.Speed = NumberRange.new(0.15 * vScale, 0.35 * vScale)
		emitter.Lifetime = NumberRange.new(0.30, 0.52)
		baseRate = 3
	elseif idle == "neon" then
		emitter.Speed = NumberRange.new(0.14 * vScale, 0.30 * vScale)
		emitter.Lifetime = NumberRange.new(0.28, 0.48)
		baseRate = if def.rarity == "Legendary" then 4 elseif def.rarity == "Epic" then 3 else 2
	end

	emitter.Rate = baseRate
	emitter.Parent = parent
	return emitter, baseRate
end

local function refreshCounterUi(st: State)
	if st.scoreLabel then
		local capped = math.clamp(math.floor(st.kills), 0, 99)
		st.scoreLabel.Text = string.format("%02d", capped)
	end
	if st.radarDots then
		local count = math.clamp(math.floor(st.kills), 0, 6)
		for i = 1, 6 do
			local dot = st.radarDots:FindFirstChild("Dot" .. i)
			if dot and dot:IsA("GuiObject") then
				dot.Visible = i <= count
			end
		end
	end
end

local function buildScreenUi(
	st: State,
	screenPart: BasePart,
	kind: "counter" | "radar",
	scale: number
)
	local plate = Instance.new("Part")
	plate.Name = "ScreenPlate"
	plate.Size = Vector3.new(
		math.max(0.01, screenPart.Size.X * 0.92),
		math.max(0.01, screenPart.Size.Y * 0.92),
		0.003
	)
	plate.Transparency = 1
	plate.CanCollide = false
	plate.CanQuery = false
	plate.CanTouch = false
	plate.Massless = true
	plate.CastShadow = false
	plate.Anchored = (st.mode == "anchored")
	local relScreen = st.pivot.CFrame:ToObjectSpace(screenPart.CFrame)
		* CFrame.new(0, 0, -(screenPart.Size.Z * 0.5 + math.max(0.002, 0.006 * scale)))
	plate.CFrame = st.pivot.CFrame * relScreen
	plate.Parent = st.model
	if st.mode == "world" then
		local w = Instance.new("WeldConstraint")
		w.Part0 = st.pivot
		w.Part1 = plate
		w.Parent = plate
	end
	table.insert(st.parts, plate)
	table.insert(st.staticParts, {
		part = plate,
		rel = relScreen,
		neon = false,
		baseColor = plate.Color,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Name = "CharmScreenGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = math.clamp(math.round(900 / math.max(scale, 0.2)), 800, 2400)
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.AlwaysOnTop = false
	gui.Adornee = plate
	gui.Parent = plate
	st.screenGui = gui

	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.fromRGB(11, 15, 22)
	root.BorderSizePixel = 0
	root.Parent = gui

	if kind == "counter" then
		local rim = Instance.new("UIStroke")
		rim.Color = Color3.fromRGB(40, 220, 140)
		rim.Thickness = 2
		rim.Parent = root

		local tag = Instance.new("TextLabel")
		tag.Size = UDim2.fromScale(1, 0.28)
		tag.Position = UDim2.fromScale(0, 0.04)
		tag.BackgroundTransparency = 1
		tag.Font = Enum.Font.Code
		tag.Text = "KILLS"
		tag.TextScaled = true
		tag.TextColor3 = Color3.fromRGB(120, 240, 180)
		tag.Parent = root

		local num = Instance.new("TextLabel")
		num.Size = UDim2.fromScale(0.92, 0.68)
		num.Position = UDim2.fromScale(0.04, 0.28)
		num.BackgroundTransparency = 1
		num.Font = Enum.Font.Code
		num.Text = "00"
		num.TextScaled = true
		num.TextColor3 = Color3.fromRGB(60, 255, 158)
		num.Parent = root
		st.scoreLabel = num
	else
		local circle = Instance.new("Frame")
		circle.Size = UDim2.fromScale(0.84, 0.84)
		circle.Position = UDim2.fromScale(0.5, 0.5)
		circle.AnchorPoint = Vector2.new(0.5, 0.5)
		circle.BackgroundColor3 = Color3.fromRGB(10, 28, 30)
		circle.BorderSizePixel = 0
		circle.Parent = root

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = circle

		local ring = Instance.new("UIStroke")
		ring.Color = Color3.fromRGB(48, 224, 180)
		ring.Thickness = 2
		ring.Parent = circle

		local beamPivot = Instance.new("Frame")
		beamPivot.Size = UDim2.fromScale(1, 1)
		beamPivot.BackgroundTransparency = 1
		beamPivot.Parent = circle
		st.radarBeam = beamPivot

		local beam = Instance.new("Frame")
		beam.Size = UDim2.fromScale(0.08, 0.46)
		beam.Position = UDim2.fromScale(0.46, 0.04)
		beam.BackgroundColor3 = Color3.fromRGB(90, 255, 210)
		beam.BorderSizePixel = 0
		beam.Parent = beamPivot

		local ping = Instance.new("Frame")
		ping.Size = UDim2.fromScale(0.22, 0.22)
		ping.Position = UDim2.fromScale(0.65, 0.30)
		ping.AnchorPoint = Vector2.new(0.5, 0.5)
		ping.BackgroundColor3 = Color3.fromRGB(255, 68, 92)
		ping.BorderSizePixel = 0
		ping.Visible = false
		ping.Parent = circle
		local pCorner = Instance.new("UICorner")
		pCorner.CornerRadius = UDim.new(1, 0)
		pCorner.Parent = ping
		st.radarPing = ping

		local dots = Instance.new("Frame")
		dots.Size = UDim2.fromScale(0.86, 0.14)
		dots.Position = UDim2.fromScale(0.07, 0.84)
		dots.BackgroundTransparency = 1
		dots.Parent = root
		st.radarDots = dots
		for i = 1, 6 do
			local d = Instance.new("Frame")
			d.Name = "Dot" .. i
			d.Size = UDim2.fromScale(0.11, 0.75)
			d.Position = UDim2.fromScale((i - 1) * 0.17, 0.12)
			d.BackgroundColor3 = Color3.fromRGB(255, 198, 52)
			d.BorderSizePixel = 0
			d.Visible = false
			d.Parent = dots
		end
	end
	refreshCounterUi(st)
end

function CharmRig.attach(
	gunModel: Model,
	charmId: string?,
	gunScale: number?,
	opts: Options?
): State?
	if not charmId or charmId == "" then
		return nil
	end
	local def = CharmsConfig.get(charmId)
	local template = CharmsConfig.model(charmId)
	if not def or not template then
		return nil
	end
	local cp = gunModel:FindFirstChild("CharmPoint", true)
	if not (cp and cp:IsA("Attachment")) then
		return nil
	end
	local handle = gunModel.PrimaryPart
	local localSideX = if handle then handle.CFrame:PointToObjectSpace(cp.WorldPosition).X else -1
	local bias = (opts and opts.viewYawBias) or 0
	local mountRot = if localSideX < 0
		then CFrame.Angles(0, math.pi / 2 + bias, 0)
		else CFrame.Angles(0, -math.pi / 2 - bias, 0)

	local mode: Mode = (opts and opts.mode) or "anchored"
	local o = opts or {}
	local gunMult = CharmsConfig.scaleFor(o.gunId, gunModel)
	local scale = (gunScale or 1) * CharmsConfig.CHARM_SCALE * (def.scale or 1) * gunMult

	local clone = template:Clone()
	clone.Name = "EquippedCharm"
	clone:PivotTo(CFrame.new())
	if math.abs(scale - 1) > 1e-4 then
		clone:ScaleTo(scale)
	end

	local pivot = clone.PrimaryPart
	if not pivot then
		clone:Destroy()
		return nil
	end
	local pivotCf = pivot.CFrame

	local parts: { BasePart } = {}
	local staticParts: { StaticPart } = {}
	local animParts: { AnimPart } = {}

	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d.CastShadow = o.castShadow == true
			d.Anchored = (mode == "anchored")
			if d ~= pivot then
				local animRole = d:GetAttribute("CharmAnimRole")
				local animOrigin = d:GetAttribute("CharmAnimOrigin")
				if typeof(animRole) == "string" and typeof(animOrigin) == "Vector3" then
					local originScaled = animOrigin * scale
					local restFromOrigin = CFrame.new(originScaled):Inverse()
						* pivotCf:ToObjectSpace(d.CFrame)
					table.insert(animParts, {
						part = d,
						role = animRole,
						originRel = originScaled,
						restFromOrigin = restFromOrigin,
						motor = d:FindFirstChild("AnimMotor") :: Motor6D?,
					})
				else
					table.insert(staticParts, {
						part = d,
						rel = pivotCf:ToObjectSpace(d.CFrame),
						neon = d:GetAttribute("CharmNeon") == true,
						baseColor = d.Color,
					})
				end
			end
		end
	end

	local holder: Instance = gunModel:FindFirstChild("Buddy") or gunModel
	clone.Parent = holder

	local mountMotor: Motor6D? = nil
	if mode == "world" and cp.Parent and cp.Parent:IsA("BasePart") then
		pivot.Anchored = false
		local m = Instance.new("Motor6D")
		m.Name = "CharmMount"
		m.Part0 = cp.Parent
		m.Part1 = pivot
		m.C0 = cp.CFrame * mountRot
		m.C1 = CFrame.new()
		m.Parent = pivot
		mountMotor = m
	else
		pivot.CFrame = cp.WorldCFrame * mountRot
		for _, sp in staticParts do
			sp.part.CFrame = pivot.CFrame * sp.rel
		end
		for _, ap in animParts do
			ap.part.CFrame = pivot.CFrame * CFrame.new(ap.originRel) * ap.restFromOrigin
		end
	end

	local fxAtt = pivot:FindFirstChild("CharmFx")
	if not (fxAtt and fxAtt:IsA("Attachment")) then
		fxAtt = Instance.new("Attachment")
		fxAtt.Name = "CharmFx"
		fxAtt.Parent = pivot
	end
	local emitter, baseRate = makeEmitter(fxAtt, def, scale)

	local light: PointLight? = nil
	local lightBase = 0
	if def.rarity == "Epic" or def.rarity == "Legendary" then
		local pl = Instance.new("PointLight")
		pl.Color = def.accent
		pl.Range = 1.6 * scale
		pl.Brightness = if def.rarity == "Legendary" then 0.55 else 0.35
		pl.Shadows = false
		pl.Parent = fxAtt
		light = pl
		lightBase = pl.Brightness
	end

	local st: State = {
		id = charmId,
		def = def,
		mode = mode,
		model = clone,
		pivot = pivot,
		point = cp,
		mountRot = mountRot,
		mountMotor = mountMotor,
		parts = parts,
		staticParts = staticParts,
		animParts = animParts,
		emitters = { { emitter = emitter, baseRate = baseRate } },
		light = light,
		lightBase = lightBase,
		pitch = 0,
		pitchVel = 0,
		roll = 0.04,
		rollVel = 0,
		twist = 0,
		twistVel = 0,
		lastPos = nil,
		lastVel = Vector3.zero,
		lastRight = nil,
		elapsed = 0,
		spinAngle = 0,
		spinBoost = 0,
		stickX = 0,
		stickZ = 0,
		stickSpin = 0,
		pulse = 0,
		pulseKind = "fire",
		kills = o.kills or 0,
		screenGui = nil,
		scoreLabel = nil,
		radarBeam = nil,
		radarPing = nil,
		radarDots = nil,
		hiddenNow = false,
	}

	if def.fx.screen then
		for _, d in clone:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("CharmScreen") == true then
				buildScreenUi(st, d, def.fx.screen, scale)
				break
			end
		end
	end

	return st
end

function CharmRig.setKills(st: State?, kills: number)
	if not st then
		return
	end
	st.kills = kills
	refreshCounterUi(st)
end

function CharmRig.onFire(st: State?, kickScale: number?)
	if not st then
		return
	end
	local k = math.clamp(kickScale or 1, 0.25, 2.5) / math.sqrt(st.def.weight)
	st.pitchVel += (4.2 + math.random() * 1.4) * k
	st.rollVel += (3.2 + math.random() * 1.6) * k
	st.twistVel += (math.random() - 0.5) * 7.5 * k
	st.pulse = math.max(st.pulse, 0.72)
	st.pulseKind = "fire"
	st.spinBoost += 10.0 * k
	st.stickX = math.clamp(st.stickX + (math.random() - 0.5) * 0.5, -0.42, 0.42)
	st.stickZ = math.clamp(st.stickZ + 0.35 * k, -0.42, 0.42)

	local burstCount = if st.def.rarity == "Legendary"
		then 6
		elseif st.def.rarity == "Epic" then 4
		elseif st.def.rarity == "Rare" then 3
		else 2
	for _, e in st.emitters do
		if e.emitter.Enabled then
			e.emitter:Emit(burstCount)
		end
	end
end

function CharmRig.onKill(st: State?, totalKills: number?, headshot: boolean?)
	if not st then
		return
	end
	if totalKills then
		st.kills = totalKills
	else
		st.kills += 1
	end
	refreshCounterUi(st)

	local mult = if headshot then 1.35 else 1.0
	st.rollVel += 9.5 * mult
	st.twistVel += (if math.random() < 0.5 then -1 else 1) * 18.0 * mult
	st.pulse = 1.0
	st.pulseKind = "kill"
	st.spinBoost += 22.0 * mult
	st.stickSpin += math.pi * 2

	local burst = if st.def.rarity == "Legendary"
		then 22
		elseif st.def.rarity == "Epic" then 16
		elseif st.def.rarity == "Rare" then 12
		else 8
	if headshot then
		burst += 6
	end
	for _, e in st.emitters do
		if e.emitter.Enabled then
			e.emitter:Emit(burst)
		end
	end
end

function CharmRig.step(
	st: State?,
	dt: number,
	worldAnchorCf: CFrame?,
	hidden: boolean?,
	adsAlpha: number?
)
	if not st or not st.model.Parent then
		return
	end
	local h = hidden == true
	local ads = adsAlpha or 0
	if h ~= st.hiddenNow then
		st.hiddenNow = h
		local ltm = if h then 1 else 0
		for _, p in st.parts do
			setPartHidden(p, ltm)
		end
		if st.screenGui then
			st.screenGui.Enabled = not h
		end
		if st.light then
			st.light.Enabled = not h
		end
		for _, e in st.emitters do
			e.emitter.Enabled = not h
			if h then
				e.emitter:Clear()
			end
		end
	end

	local cdt = math.min(dt, MAX_DT)
	if cdt <= 0 then
		return
	end
	st.elapsed += cdt

	local anchorCf = worldAnchorCf or st.point.WorldCFrame
	local restCf = anchorCf * st.mountRot
	local pos = anchorCf.Position

	local accel = Vector3.zero
	if st.lastPos and dt <= 0.12 and (pos - st.lastPos).Magnitude < TELEPORT_DIST then
		local vel = (pos - st.lastPos) / cdt
		local rawAccel = (vel - st.lastVel) / cdt
		local mag = rawAccel.Magnitude
		if mag > 65 then
			rawAccel = rawAccel * (65 / mag)
		end
		accel = rawAccel
		st.lastVel = st.lastVel:Lerp(vel, math.min(1, cdt * 18))
	else
		st.lastVel = Vector3.zero
	end
	st.lastPos = pos

	local rVec = Vector3.new(restCf.RightVector.X, 0, restCf.RightVector.Z)
	if rVec.Magnitude > 0.05 then
		rVec = rVec.Unit
		if st.lastRight then
			local crossY = st.lastRight:Cross(rVec).Y
			st.twistVel += math.clamp(crossY / cdt, -14, 14) * 0.30
		end
		st.lastRight = rVec
	end

	local pull = Vector3.new(0, -1, 0) - accel * 0.012
	local localDown = restCf:VectorToObjectSpace(pull)
	local targetPitch =
		math.clamp(math.atan2(localDown.X, math.max(0.25, -localDown.Y)), -0.55, 0.55)
	local targetRoll =
		math.clamp(math.atan2(-localDown.Z, math.max(0.25, -localDown.Y)), -0.04, 0.55)

	local omega = 16.5 / math.sqrt(st.def.weight)
	local k = omega * omega
	local damp = 2 * 0.38 * omega

	st.pitchVel += ((targetPitch - st.pitch) * k - st.pitchVel * damp) * cdt
	st.rollVel += ((targetRoll - st.roll) * k - st.rollVel * damp) * cdt
	st.twistVel += (-st.twist * (k * 0.65) - st.twistVel * (damp * 1.15)) * cdt

	st.pitch = math.clamp(st.pitch + st.pitchVel * cdt, -0.62, 0.62)
	st.roll = math.clamp(st.roll + st.rollVel * cdt, -0.04, 0.62)
	st.twist = math.clamp(st.twist + st.twistVel * cdt, -0.42, 0.42)
	if st.roll <= -0.035 and st.rollVel < 0 then
		st.rollVel = -st.rollVel * 0.2
	end

	local swingCf = CFrame.fromEulerAnglesYXZ(st.roll, st.twist, st.pitch)

	st.spinBoost = math.max(0, st.spinBoost - cdt * 12.0)
	local spinRate = (st.def.fx.spinSpeed or 0) + st.spinBoost
	st.spinAngle = (st.spinAngle + spinRate * cdt) % (math.pi * 200)
	st.stickSpin = math.max(0, st.stickSpin - cdt * 10.0)
	local decay = math.exp(-cdt * 10)
	st.stickX = st.stickX * decay + math.clamp(st.pitch * 0.45, -0.35, 0.35) * (1 - decay)
	st.stickZ = st.stickZ * decay + math.clamp(st.roll * 0.45, -0.35, 0.35) * (1 - decay)

	local animCf = CFrame.new()
	if #st.animParts > 0 then
		if st.def.fx.stickTilt then
			animCf = CFrame.Angles(st.stickZ, st.stickSpin, -st.stickX)
		elseif st.id == "ReactorCore" then
			animCf = CFrame.Angles(st.spinAngle * 0.65, st.spinAngle, st.spinAngle * 0.35)
		elseif st.def.fx.spinAxis then
			animCf = CFrame.fromAxisAngle(st.def.fx.spinAxis, st.spinAngle)
		end
	end

	if st.mode == "world" and st.mountMotor then
		st.mountMotor.Transform = swingCf
		for _, ap in st.animParts do
			if ap.motor then
				ap.motor.Transform = animCf
			end
		end
	else
		local pivotCf = restCf * swingCf
		st.pivot.CFrame = pivotCf
		for _, sp in st.staticParts do
			sp.part.CFrame = pivotCf * sp.rel
		end
		for _, ap in st.animParts do
			ap.part.CFrame = pivotCf * CFrame.new(ap.originRel) * animCf * ap.restFromOrigin
		end
	end

	st.pulse = math.max(0, st.pulse - cdt * (if st.pulseKind == "kill" then 1.8 else 4.5))
	local idleWave = if st.def.fx.idle == "heartbeat"
		then (0.5 + 0.5 * math.sin(st.elapsed * 5.2)) ^ 3
		else 0.5 + 0.5 * math.sin(st.elapsed * 2.8)

	if not h then
		local adsFactor = math.clamp(1 - ads * 1.4, 0.15, 1)
		for _, e in st.emitters do
			e.emitter.Rate = e.baseRate * adsFactor
		end
		local flashColor = if st.pulseKind == "kill"
			then Color3.fromRGB(255, 224, 96)
			else Color3.new(1, 1, 1)
		local mix = st.pulse * 0.65 + idleWave * 0.12
		for _, sp in st.staticParts do
			if sp.neon then
				sp.part.Color = sp.baseColor:Lerp(flashColor, math.clamp(mix, 0, 0.85))
			end
		end
		if st.light then
			st.light.Brightness = st.lightBase * (0.85 + idleWave * 0.25 + st.pulse * 1.8)
		end
		if st.radarBeam then
			st.radarBeam.Rotation = (st.elapsed * 160) % 360
		end
		if st.radarPing then
			st.radarPing.Visible = st.pulse > 0.15
		end
		if st.scoreLabel then
			st.scoreLabel.TextColor3 = if st.pulseKind == "kill" and st.pulse > 0.2
				then Color3.fromRGB(255, 224, 90)
				else Color3.fromRGB(60, 255, 158)
		end
	end
end

function CharmRig.destroy(st: State?)
	if not st then
		return
	end
	st.model:Destroy()
end

return CharmRig
