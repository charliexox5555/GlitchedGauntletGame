--!strict
-- First-person Shadow Mist action effects, sampled from the viewmodel's tracks.
local StateValues = require(game:GetService("ReplicatedStorage").Shared.StateValues)

local Shared = game:GetService("ReplicatedStorage").Shared
local Workspace = game:GetService("Workspace")
local Ease = require(Shared.Util.Ease)
local GunSounds = require(Shared.Config.GunSounds)
local ShadowMistAudio = require(Shared.Config.ShadowMistAudio)
local Presentation = require(Shared.Config.RuinBlightedPresentation)
local Style = require(Shared.Config.SkinPreview).SHADOW_MIST
local VFX = require(Shared.Config.VfxTextures)
local UiMotion = require(Shared.UiMotion)
local LocalHide = require(script.Parent.LocalHide)
local MagDrop = require(script.Parent.MagDrop)
local ShotFxKit = require(script.Parent.ShotFxKit)
local ActionFx = require(script.Parent.ShadowMistActionFx)
local AudioController = require(script.Parent.Parent.Controllers.AudioController)

export type Frame = {
	assembly: number,
	spread: number,
	twist: number,
	inspectClamp: number,
	energy: number,
	mist: number,
	shot: number,
	shotAge: number,
	reload: number,
}

type DrawBeats = { heel: number, fore: number }
local DRAW_BEATS: { [string]: DrawBeats } = {
	Vandal = { heel = 0.28, fore = 0.44 },
	Guardian = { heel = 0.44, fore = 0.27 },
	Spectre = { heel = 0.32, fore = 0.35 },
	Operator = { heel = 0.24, fore = 0.48 },
	Ghost = { heel = 0.38, fore = 0.23 },
}

type Drop = {
	root: BasePart,
	parts: { BasePart },
	offsets: { CFrame },
	mist: ParticleEmitter,
	pose: CFrame,
	age: number,
	empty: boolean,
}

export type State = {
	model: Model,
	profile: Presentation.Profile,
	drawBeats: DrawBeats,
	stockSounds: GunSounds.GunSoundSet,
	hero: boolean,
	scale: number,
	mag: BasePart,
	magMotor: Motor6D,
	well: Attachment,
	magGrip: Attachment,
	frame: Frame,
	fore: ParticleEmitter?,
	heel: ParticleEmitter?,
	weave: ParticleEmitter,
	palmMist: ParticleEmitter,
	foreFx: ActionFx.Node?,
	heelFx: ActionFx.Node?,
	centerFx: ActionFx.Node?,
	wellFx: ActionFx.Node,
	magFx: ActionFx.Node,
	seatFx: ActionFx.Node,
	castTrail: Beam,
	castStrength: number,
	seatStrength: number,
	throwStrength: number,
	throwProgress: number,
	drop: Drop?,
	visible: boolean,
	drawAt: number?,
	inspectAt: number?,
	inspectStart: AudioController.Handle?,
	inspectBed: AudioController.Handle?,
	reloadAt: number?,
	castOffset: Vector3?,
	hand: number,
	handOnMag: number,
	handCast: number,
	shotAge: number,
	clock: number,
	fxVisible: boolean,
}

local ShadowMistActions = {}

local function burst(anchor: Attachment, scale: number, locked: boolean): ParticleEmitter
	local em = Instance.new("ParticleEmitter")
	em.Name = "ShadowMistActionVapor"
	em.Texture = VFX.FROST_MIST_2x2
	em.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	em.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	em.Color = ColorSequence.new(Color3.fromRGB(82, 169, 147), Color3.fromRGB(77, 117, 113))
	em.LightInfluence = 0
	em.LightEmission = 0.12
	em.EmissionDirection = Enum.NormalId.Back
	em.LockedToPart = locked
	em.Lifetime = NumberRange.new(0.22, 0.38)
	em.Speed = NumberRange.new(0.14 * scale, 0.55 * scale)
	em.Drag = 3.6
	em.SpreadAngle = Vector2.new(36, 36)
	em.Rotation = NumberRange.new(-24, 24)
	em.RotSpeed = NumberRange.new(-24, 24)
	em.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.14 * scale),
		NumberSequenceKeypoint.new(0.55, 0.36 * scale),
		NumberSequenceKeypoint.new(1, 0.49 * scale),
	})
	em.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.23, 0.52),
		NumberSequenceKeypoint.new(0.63, 0.73),
		NumberSequenceKeypoint.new(1, 1),
	})
	em.Enabled = false
	em.TimeScale = ShotFxKit.getTimeScale()
	em.Parent = anchor
	return em
end

local function anchor(model: Model, name: string): Attachment?
	local found = model:FindFirstChild(name, true)
	return if found and found:IsA("Attachment") then found else nil
end

function ShadowMistActions.new(model: Model, scale: number, id: string): State?
	local profile = Presentation[id]
	if StateValues.get(model, "SkinLine") ~= Style.LINE or not profile then
		return nil
	end
	local rig = model:FindFirstChild("Rig")
	local mag = rig and rig:FindFirstChild("Mag")
	local root = rig and rig:FindFirstChild("Root")
	local motors = rig and rig:FindFirstChild("Motors")
	local magMotor = motors and motors:FindFirstChild("Mag")
	local magGlow = anchor(model, "RuinMagGlow")
	local fore = anchor(model, "RuinMistFore")
	local heel = anchor(model, "RuinMistHeel")
	local center = anchor(model, "RuinReceiverGlow")
	if
		not mag
		or not mag:IsA("BasePart")
		or not root
		or not root:IsA("BasePart")
		or not magGlow
		or not magMotor
		or not magMotor:IsA("Motor6D")
	then
		return nil
	end
	local well = Instance.new("Attachment")
	well.Name = "ShadowMistChannel"
	well.Position = root.CFrame:PointToObjectSpace(
		magGlow.WorldPosition
			+ root.CFrame:VectorToWorldSpace(Vector3.new(-0.017, 0.32, 0.07) * scale)
	)
	well.Parent = root
	local seat = Instance.new("Attachment")
	seat.Name = "ShadowMistSeat"
	seat.Position = magMotor.C0.Position + Vector3.new(0.012, 0.04, -0.08) * scale
	seat.Parent = root
	local grip = Instance.new("Attachment")
	grip.Name = "ShadowMistMagazineGrip"
	grip.Position = magGlow.Position + Vector3.new(-0.02, 0.071, 0.12) * scale
	grip.Parent = mag
	local castTrail = Instance.new("Beam")
	castTrail.Name = "RuinMagazineCast"
	castTrail.Attachment0 = grip
	castTrail.Attachment1 = seat
	castTrail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 167, 144)),
		ColorSequenceKeypoint.new(0.40, Color3.fromRGB(168, 247, 217)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(51, 146, 126)),
	})
	castTrail.LightEmission = 0.66
	castTrail.LightInfluence = 0
	castTrail.FaceCamera = true
	castTrail.Enabled = false
	castTrail.Segments = 8
	castTrail.CurveSize0 = 0.11 * scale
	castTrail.CurveSize1 = -0.055 * scale
	castTrail.Parent = root
	return {
		model = model,
		profile = profile,
		drawBeats = DRAW_BEATS[id],
		stockSounds = GunSounds.get(id),
		hero = id == "Vandal",
		scale = scale,
		mag = mag,
		magMotor = magMotor,
		well = well,
		magGrip = grip,
		frame = {
			assembly = 1,
			spread = 0,
			twist = 0,
			inspectClamp = 0,
			energy = 0,
			mist = 0,
			shot = 0,
			shotAge = math.huge,
			reload = 0,
		},
		fore = if fore then burst(fore, scale * 1.1, true) else nil,
		heel = if heel then burst(heel, scale * 1.08, true) else nil,
		weave = burst(magGlow, scale, true),
		palmMist = burst(well, scale * 1.17, true),
		foreFx = if fore then ActionFx.new(fore, scale, 0.24, false) else nil,
		heelFx = if heel then ActionFx.new(heel, scale, 0.23, false) else nil,
		centerFx = if center then ActionFx.new(center, scale, 0.19, false) else nil,
		wellFx = ActionFx.new(well, scale, 0.26, true),
		magFx = ActionFx.new(magGlow, scale, 0.16, true),
		seatFx = ActionFx.new(seat, scale, 0.21, true),
		castTrail = castTrail,
		castStrength = 0,
		seatStrength = 0,
		throwStrength = 0,
		throwProgress = 0,
		drop = nil,
		visible = false,
		drawAt = nil,
		inspectAt = nil,
		reloadAt = nil,
		castOffset = nil,
		hand = 0,
		handOnMag = 0,
		handCast = 0,
		shotAge = math.huge,
		clock = 0,
		fxVisible = false,
	}
end

local function closeSound(volumeScale: number?)
	if AudioController.playSound(ShadowMistAudio.lock, "Foley", nil, volumeScale) then
		return
	end
	AudioController.play(
		Style.LOCK_SOUND,
		{ group = "Foley", volume = 0.45 * (volumeScale or 1), pitch = 0.81, cut = 0.25 }
	)
end

function ShadowMistActions.endInspect(state: State)
	AudioController.fadeOut(state.inspectStart, 0.1)
	AudioController.fadeOut(state.inspectBed, 0.14)
	state.inspectStart = nil
	state.inspectBed = nil
	state.inspectAt = nil
end

local function crossed(previous: number, now: number, at: number): boolean
	return previous < at and now >= at
end

local function emit(emitter: ParticleEmitter?, count: number)
	if emitter then
		emitter:Emit(count)
	end
end

function ShadowMistActions.fire(state: State)
	state.shotAge = 0
end

function ShadowMistActions.step(
	state: State,
	dt: number,
	visible: boolean,
	draw: number?,
	inspect: number?,
	ads: number
): Frame
	local f = state.frame
	local reduced = UiMotion.reduced()
	state.visible = visible
	state.shotAge += dt
	state.clock = (state.clock + dt) % 360
	f.shotAge = state.shotAge
	f.shot = if visible then (1 - math.min(1, state.shotAge / 0.18)) ^ 1.7 else 0

	if draw then
		local previous = state.drawAt or 0
		if visible and crossed(previous, draw, 0.26) then
			if not AudioController.playSound(ShadowMistAudio.drawAir, "Foley") then
				AudioController.playSound(state.stockSounds.drawWhoosh, "Foley")
			end
		end
		if visible and not reduced and crossed(previous, draw, state.drawBeats.heel) then
			emit(state.heel, 7)
			ActionFx.pop(state.heelFx, 7)
		end
		if visible and not reduced and crossed(previous, draw, state.drawBeats.fore) then
			emit(state.fore, 9)
			ActionFx.pop(state.foreFx, 6)
			ActionFx.pop(state.centerFx, 4)
		end
		if visible and crossed(previous, draw, Style.DRAW_LOCK) then
			closeSound()
			if not reduced then
				ActionFx.pop(state.centerFx, 11)
				ActionFx.pop(state.foreFx, 5)
			end
		end
		state.drawAt = draw
		f.assembly = Ease.smooth((draw - 0.26) / 0.40)
		f.energy = Ease.smooth((draw - 0.55) / 0.11) * (1 - Ease.smooth((draw - 0.66) / 0.23))
	else
		state.drawAt = nil
		f.assembly = Ease.approach(f.assembly, 1, 34, dt)
		f.energy = Ease.approach(f.energy, 0, 14, dt)
	end

	local open = 0
	local closing = inspect ~= nil and inspect >= Style.INSPECT_CLOSE
	if visible and inspect then
		local previous = state.inspectAt
		if not previous then
			state.inspectStart = AudioController.playSound(ShadowMistAudio.inspect, "Foley")
				or AudioController.playSound(state.stockSounds.inspect, "Foley")
		end
		if crossed(previous or 0, inspect, 0.22) then
			state.inspectBed = AudioController.playSound(ShadowMistAudio.inspectBed, "Foley")
		end
		if crossed(previous or 0, inspect, Style.INSPECT_LOCK) then
			closeSound(0.78)
			if not reduced then
				ActionFx.pop(state.centerFx, 8)
				f.energy = math.max(f.energy, 0.9)
			end
		end
	elseif state.inspectAt then
		ShadowMistActions.endInspect(state)
	end
	if inspect and not reduced then
		local close = math.clamp(
			(inspect - Style.INSPECT_CLOSE) / (Style.INSPECT_LOCK - Style.INSPECT_CLOSE),
			0,
			1
		)
		open = Ease.smooth((inspect - 0.12) / 0.17) * (1 - close ^ 2.3)
		f.inspectClamp = Ease.smooth((inspect - Style.INSPECT_LOCK + 0.036) / 0.036)
			* (1 - Ease.smooth((inspect - Style.INSPECT_LOCK) / 0.085))
		local previous = state.inspectAt or 0
		if visible and crossed(previous, inspect, 0.22) then
			emit(state.fore, 6)
			emit(state.heel, 7)
			ActionFx.pop(state.centerFx, 5)
		end
		if visible and crossed(previous, inspect, 0.47) then
			ActionFx.pop(state.heelFx, 7)
			ActionFx.pop(state.foreFx, 7)
		end
	else
		f.inspectClamp = Ease.approach(f.inspectClamp, 0, 30, dt)
	end
	state.inspectAt = inspect
	local aimAllowance = 1 - Ease.smooth(ads / 0.62)
	local spread = open * aimAllowance * state.profile.spread
	f.spread = if closing then spread else Ease.approach(f.spread, spread, 22, dt)
	local twist = (if inspect then (inspect - 0.35) * 0.58 else 0) * f.spread
	f.twist = if closing then twist else Ease.approach(f.twist, twist, 18, dt)
	f.mist = f.spread
	if reduced or not visible then
		f.assembly = 1
		f.spread, f.twist, f.mist = 0, 0, 0
	end
	return f
end

function ShadowMistActions.stepFx(state: State, ads: number)
	local f = state.frame
	local strength = if state.visible and not UiMotion.reduced()
		then 1 - Ease.smooth(ads / 0.52)
		else 0
	local draw = state.drawAt or 0
	local function gather(beat: number): number
		return Ease.smooth((draw - beat + 0.11) / 0.16) * (1 - Ease.smooth((draw - 0.68) / 0.15))
	end
	local open = f.spread * strength
	local clock = state.clock
	ActionFx.step(
		state.heelFx,
		clock + 0.23,
		math.max(open * 0.85, gather(state.drawBeats.heel) * strength),
		open,
		f.energy * strength * 0.48
	)
	ActionFx.step(
		state.foreFx,
		clock,
		math.max(open * 0.86, gather(state.drawBeats.fore) * strength),
		open,
		f.energy * strength * 0.66
	)
	ActionFx.step(
		state.centerFx,
		clock + 0.18,
		math.max(open * 0.79, gather(0.47) * strength * 0.70),
		open,
		f.energy * strength
	)
	local casting, seating = state.castStrength, state.seatStrength
	ActionFx.step(state.wellFx, clock, casting * strength, 0, casting * f.energy * strength)
	ActionFx.step(state.seatFx, clock, seating * strength, 0, seating * f.energy * strength)
	ActionFx.step(
		state.magFx,
		clock + 0.31,
		f.reload * strength * math.max(0.46, state.handOnMag),
		0,
		f.energy * strength * f.reload
	)
	local trail = state.castTrail
	local weight = state.throwStrength * strength
	trail.Enabled = weight > 0.025
	if trail.Enabled then
		local width = state.scale * (if state.hero then 0.78 else 1)
		local head = 0.18 + state.throwProgress * 0.64
		trail.Width0 = width * (0.018 + 0.020 * weight)
		trail.Width1 = width * 0.012
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(head - 0.16, 1 - 0.19 * weight),
			NumberSequenceKeypoint.new(head, 1 - 0.66 * weight),
			NumberSequenceKeypoint.new(head + 0.16, 1 - 0.23 * weight),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
	if strength == 0 and state.fxVisible then
		ActionFx.clear(state.foreFx)
		ActionFx.clear(state.heelFx)
		ActionFx.clear(state.centerFx)
		ActionFx.clear(state.wellFx)
		ActionFx.clear(state.magFx)
		ActionFx.clear(state.seatFx)
	end
	state.fxVisible = strength > 0
end

local function makeDrop(state: State, parts: { BasePart }): Drop
	local holder = Instance.new("Part")
	holder.Name = "ShadowMistReleasedMagazine"
	holder.Size = Vector3.one * 0.05
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.CastShadow = false
	holder.CFrame = state.mag.CFrame
	holder.Parent = state.model
	local origin = Instance.new("Attachment")
	origin.Position = Vector3.new(0.15, 0, -0.18) * state.scale
	origin.Parent = holder
	local drop: Drop = {
		root = holder,
		parts = {},
		offsets = {},
		mist = burst(origin, state.scale * 0.9, true),
		pose = holder.CFrame,
		age = math.huge,
		empty = false,
	}
	for _, part in parts do
		local copy = part:Clone()
		for _, child in copy:GetChildren() do
			if not child:IsA("SurfaceAppearance") and not child:IsA("Decal") then
				child:Destroy()
			end
		end
		copy.Anchored = true
		copy.CanCollide = false
		copy.CanTouch = false
		copy.CanQuery = false
		copy.CastShadow = false
		LocalHide.set(copy, 1)
		copy.Parent = holder
		table.insert(drop.parts, copy)
		table.insert(drop.offsets, state.mag.CFrame:ToObjectSpace(part.CFrame))
	end
	return drop
end

local function release(state: State, parts: { BasePart }, empty: boolean)
	local drop = state.drop
	if not drop then
		drop = makeDrop(state, parts)
		state.drop = drop
	end
	drop.pose = state.mag.CFrame
	drop.root.CFrame = drop.pose
	drop.age = 0
	drop.empty = empty
	drop.mist:Clear()
	if not UiMotion.reduced() then
		drop.mist:Emit(10)
	end
end

function ShadowMistActions.stepDrop(state: State, dt: number)
	local d = state.drop
	if not d or d.age == math.huge then
		return
	end
	d.age += dt
	local t = d.age
	local dtMove = math.min(t, 0.28)
	local offset = Vector3.new(-0.52 * dtMove, -1.25 * dtMove - 4.6 * dtMove * dtMove, 0)
	local cf = d.pose * CFrame.Angles(t * 2.4, 0, -t * 1.1) + offset
	d.root.CFrame = cf
	for i, part in d.parts do
		local band = StateValues.get(part, "RuinIdleGlow") ~= nil
		local fade = if band then Ease.smooth(t / 0.095) else Ease.smooth((t - i * 0.008) / 0.17)
		local loaded = StateValues.get(part, "SkinLoadedRound") == true
		LocalHide.set(part, if state.visible and (not loaded or not d.empty) then fade else 1)
		part.CFrame = cf * d.offsets[i]
	end
	if not state.visible or t > 0.55 then
		d.age = math.huge
		d.mist:Clear()
	end
end

function ShadowMistActions.reload(
	state: State,
	parts: { BasePart },
	t: number,
	timing: MagDrop.Timing,
	seat: number,
	empty: boolean
)
	local previous = state.reloadAt or 0
	state.reloadAt = t
	local outAt, inAt = timing.outAt, timing.inAt
	local span = seat - outAt
	local grab = if state.hero then Style.RELOAD_GRAB else outAt + span * state.profile.grab
	local throwAt = if state.hero then Style.RELOAD_THROW else outAt + span * state.profile.throw
	local reduced = UiMotion.reduced()
	local conjure = if state.hero then inAt - 0.09 else math.max(outAt, inAt - span * 0.10)
	local approach = math.max(seat - throwAt, 0.015)
	if state.hero then
		state.castStrength = Ease.smooth((t - 0.23) / 0.09)
			* (1 - Ease.smooth((t - throwAt) / 0.07))
		state.seatStrength = Ease.smooth((t - throwAt) / 0.11)
			* (1 - Ease.smooth((t - seat) / 0.13))
	else
		state.castStrength = Ease.smooth((t - conjure + 0.018) / 0.085)
			* (1 - Ease.smooth((t - throwAt) / 0.06))
		state.seatStrength = Ease.smooth((t - throwAt) / approach)
			* (1 - Ease.smooth((t - seat) / 0.11))
	end
	state.throwProgress = math.clamp((t - throwAt) / approach, 0, 1)
	state.throwStrength = math.sin(math.pi * state.throwProgress)
	local scale = state.scale
	local releasePose = CFrame.new(-0.022 * scale, -0.015 * scale, -0.215 * scale)
		* CFrame.Angles(-0.10, 0.11, 0.04)
	local aligned = CFrame.new(-0.008 * scale, 0.035 * scale, -0.245 * scale)
		* CFrame.Angles(0.024, -0.02, 0)
	local driver = state.magMotor
	local cam = Workspace.CurrentCamera
	local parent = driver.Part0
	if not state.castOffset and cam and parent and t >= outAt - 0.011 then
		local reach = cam.CFrame:VectorToWorldSpace(state.profile.cast * scale)
		state.castOffset = (parent.CFrame * driver.C0):VectorToObjectSpace(reach)
	end
	local hovering = CFrame.new(state.castOffset or Vector3.new(0.025, 0.51, -0.47) * scale)
		* CFrame.Angles(
			state.profile.rotation.X,
			state.profile.rotation.Y,
			state.profile.rotation.Z
		)
	local lifted = CFrame.new(-0.026 * scale, 0.035 * scale, 0.07 * scale)
		* CFrame.Angles(-0.08, 0.15, 0.05)
	state.well.Position = (driver.C0 * hovering):PointToWorldSpace(state.magGrip.Position)
	if t < outAt then
		driver.Transform =
			releasePose:Lerp(CFrame.identity, 1 - Ease.smooth((t - outAt + 0.082) / 0.082))
	elseif t < throwAt then
		local drift = Ease.smooth((t - inAt) / (throwAt - inAt))
		driver.Transform = hovering * lifted:Lerp(CFrame.identity, 1 - drift)
	elseif t < seat - 0.032 then
		local travel = math.clamp((t - throwAt) / math.max(seat - throwAt - 0.032, 0.001), 0, 1)
		local bend = Vector3.new(0.025, -0.06, 0.105) * scale * math.sin(math.pi * travel)
		driver.Transform = (hovering * lifted):Lerp(aligned, Ease.smooth(travel)) + bend
	else
		driver.Transform = aligned:Lerp(CFrame.identity, Ease.out((t - seat + 0.032) / 0.032))
	end
	if state.visible then
		if crossed(previous, t, outAt) then
			release(state, parts, empty)
			if not AudioController.playSound(ShadowMistAudio.magOut, "Foley") then
				AudioController.playSound(state.stockSounds.magOut, "Foley")
			end
			if not reduced then
				ActionFx.pop(state.seatFx, 9)
			end
		end
		if crossed(previous, t, conjure) then
			if not AudioController.playSound(ShadowMistAudio.magForm, "Foley") then
				AudioController.play(
					Style.COALESCE_SOUND,
					{ group = "Foley", volume = 0.28, pitch = 0.89, cut = 0.3 }
				)
			end
			if not reduced then
				state.palmMist:Emit(15)
				ActionFx.pop(state.wellFx, 7)
			end
		end
		if crossed(previous, t, grab) then
			AudioController.playSound(ShadowMistAudio.magThrow, "Foley")
		end
		if not reduced and crossed(previous, t, grab - 0.03) then
			state.weave:Emit(9)
			ActionFx.pop(state.magFx, 5)
		end
		if not reduced and crossed(previous, t, throwAt) then
			ActionFx.pop(state.magFx, 9)
			ActionFx.pop(state.seatFx, 6)
		end
		if crossed(previous, t, seat) then
			state.frame.energy = math.max(state.frame.energy, 1)
			if not AudioController.playSound(ShadowMistAudio.magIn, "Foley") then
				AudioController.playSound(state.stockSounds.magIn, "Foley")
			end
			closeSound(0.42)
			if not reduced then
				state.weave:Emit(7)
				ActionFx.pop(state.seatFx, 12)
				ActionFx.pop(state.centerFx, 9)
			end
		end
	end
	local snap = Ease.smooth((t - outAt + 0.03) / 0.03) * (1 - Ease.smooth((t - outAt) / 0.045))
	state.frame.energy = math.max(state.frame.energy, snap * 0.61)
	local channel = Ease.smooth((t - conjure + 0.028) / 0.092)
		* (1 - Ease.smooth((t - seat) / 0.13))
	state.frame.reload = math.max(channel * 0.95, snap * 0.66)
	state.hand = Ease.smooth((t - outAt + 0.021) / 0.104)
		* (1 - Ease.smooth((t - seat - 0.023) / 0.16))
	state.handOnMag = Ease.smooth((t - grab + 0.032) / 0.045)
		* (1 - Ease.smooth((t - throwAt) / 0.055))
	state.handCast = Ease.smooth((t - throwAt + 0.022) / 0.051)
		* (1 - Ease.smooth((t - throwAt - 0.026) / 0.10))
	for i, p in parts do
		local stagger = (i / #parts) * 0.052
		if StateValues.get(p, "RuinIdleGlow") ~= nil then
			stagger += 0.017
		end
		local fade = 1 - Ease.smooth((t - inAt + 0.027 - stagger) / 0.068)
		local opacity = if t < outAt then 0 else fade
		local concealsEmptyRound = empty
			and t < outAt
			and StateValues.get(p, "SkinLoadedRound") == true
		LocalHide.set(p, if state.visible and not concealsEmptyRound then opacity else 1)
	end
end

function ShadowMistActions.endReload(state: State)
	if state.reloadAt ~= nil then
		state.weave:Clear()
		state.palmMist:Clear()
	end
	state.reloadAt = nil
	state.castOffset = nil
	state.hand = 0
	state.handOnMag = 0
	state.handCast = 0
	state.frame.reload = 0
	state.castStrength = 0
	state.seatStrength = 0
	state.throwStrength = 0
	state.throwProgress = 0
end

return ShadowMistActions
