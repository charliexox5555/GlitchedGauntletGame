--!strict
-- Cosmetic mesh welds ride the stock rig. Playback and Sundial Epic lines run
-- live first-person motion and subtle deck/solar VFX on idle, fire, slash,
-- reload, draw and inspect; other lines (e.g. Breakwater) drive only inspect.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkinPreview = require(ReplicatedStorage.Shared.Config.SkinPreview)
local SettingsApply = require(ReplicatedStorage.Shared.SettingsApply)
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local PB = SkinPreview.PLAYBACK
local SD = SkinPreview.SUNDIAL

local CosmeticInspect = {}

export type PulseKind = "Fire" | "Heavy" | "Draw" | "MagOut" | "Seat" | "Inspect"

type Part = {
	mesh: MeshPart,
	weld: Weld,
	rest: CFrame,
	pivot: Vector3,
	axis: Vector3,
	kind: string,
	distance: number,
}

type LiveMode = "Playback" | "Sundial"

export type State = {
	parts: { Part },
	active: boolean,
	liveMode: LiveMode?,
	scale: number,
	clock: number,
	surge: number,
	-- Playback live state
	reelFrontAngle: number,
	reelRearAngle: number,
	reelFrontVel: number,
	reelRearVel: number,
	meterLevel: number,
	-- Sundial live state (damped-spring escapement)
	dialAngle: number,
	dialTarget: number,
	dialVel: number,
	-- Optional first-person subtle VFX (owned by this state, destroyed on teardown)
	anchor: Attachment?,
	light: PointLight?,
	motes: ParticleEmitter?,
}

local function ease(progress: number, from: number, to: number): number
	local t = math.clamp((progress - from) / (to - from), 0, 1)
	return t * t * (3 - 2 * t)
end

local function attachLiveFx(
	parts: { Part },
	mode: LiveMode,
	scale: number
): (Attachment?, PointLight?, ParticleEmitter?)
	local host: MeshPart? = nil
	for _, p in parts do
		if mode == "Playback" and (p.kind == "ReelFront" or p.kind == "MeterSweep") then
			host = p.mesh
			if p.kind == "ReelFront" then
				break
			end
		elseif mode == "Sundial" and p.kind == "Dial" then
			host = p.mesh
			break
		end
	end
	if not host then
		host = parts[1].mesh
	end
	if not host or not host.Parent then
		return nil, nil, nil
	end

	local anchor = Instance.new("Attachment")
	anchor.Name = if mode == "Playback" then "PlaybackDeckFx" else "SundialSolarFx"
	anchor.Parent = host

	local light = Instance.new("PointLight")
	light.Name = if mode == "Playback" then "PlaybackDeckLight" else "SundialSolarLight"
	light.Color = if mode == "Playback" then PB.LIGHT_COLOR else SD.LIGHT_COLOR
	light.Brightness = if mode == "Playback" then PB.LIGHT_IDLE else SD.LIGHT_IDLE
	light.Range = (if mode == "Playback" then PB.LIGHT_RANGE else SD.LIGHT_RANGE)
		* math.max(scale, 0.25)
	light.Shadows = false
	light.Parent = anchor

	local motes = Instance.new("ParticleEmitter")
	motes.Name = if mode == "Playback" then "PlaybackDeckMotes" else "SundialSolarMotes"
	motes.Texture = if mode == "Playback" then PB.MOTE_TEXTURE else SD.MOTE_TEXTURE
	local c0 = if mode == "Playback" then PB.MOTE_COLOR else SD.MOTE_COLOR
	local c1 = if mode == "Playback" then PB.MOTE_PEAK_COLOR else SD.MOTE_PEAK_COLOR
	motes.Color = ColorSequence.new(c0, c1)
	motes.LightEmission = 0.9
	motes.LightInfluence = 0
	motes.Brightness = 1.45
	local sz = (if mode == "Playback" then PB.MOTE_SIZE else SD.MOTE_SIZE) * math.max(scale, 0.25)
	motes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, sz * 0.4),
		NumberSequenceKeypoint.new(0.4, sz),
		NumberSequenceKeypoint.new(1, 0),
	})
	motes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.28),
		NumberSequenceKeypoint.new(0.75, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	motes.Lifetime = NumberRange.new(0.35, 0.72)
	motes.Speed = NumberRange.new(0.18 * scale, 0.48 * scale)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.Drag = 3
	motes.LockedToPart = true
	motes.Rate = if SettingsApply.lowVfx()
		then 0
		else (if mode == "Playback" then PB.MOTE_RATE else SD.MOTE_RATE)
	motes.Parent = anchor

	return anchor, light, motes
end

function CosmeticInspect.new(model: Model, skinLine: string?, firstPerson: boolean?): State?
	local parts: { Part } = {}
	local scale = model:GetScale()
	for _, part in model:GetChildren() do
		if not part:IsA("MeshPart") then
			continue
		end
		local kind = StateValues.get(part, "CosmeticInspect")
		local pivot = StateValues.get(part, "CosmeticInspectPivot")
		local axis = StateValues.get(part, "CosmeticInspectAxis")
		local travel = StateValues.get(part, "CosmeticInspectTravel")
		local weld = part:FindFirstChild("SkinCosmeticWeld")
		if
			type(kind) == "string"
			and typeof(pivot) == "Vector3"
			and typeof(axis) == "Vector3"
			and axis.Magnitude > 0.001
			and weld
			and weld:IsA("Weld")
		then
			table.insert(parts, {
				mesh = part,
				weld = weld,
				rest = weld.C0,
				pivot = pivot * scale,
				axis = axis.Unit,
				kind = kind,
				distance = if typeof(travel) == "number" then travel * scale else 0,
			})
		end
	end
	if #parts == 0 then
		return nil
	end

	local line = skinLine
	if line == nil then
		local v = StateValues.get(model, "SkinLine")
		line = if typeof(v) == "string" then v else nil
	end
	local liveMode: LiveMode? = nil
	if firstPerson then
		if line == PB.LINE then
			liveMode = "Playback"
		elseif line == SD.LINE then
			liveMode = "Sundial"
		end
	end

	local anchor: Attachment? = nil
	local light: PointLight? = nil
	local motes: ParticleEmitter? = nil
	if liveMode then
		anchor, light, motes = attachLiveFx(parts, liveMode, scale)
	end

	return {
		parts = parts,
		active = false,
		liveMode = liveMode,
		scale = scale,
		clock = 0,
		surge = 0,
		reelFrontAngle = 0,
		reelRearAngle = 0,
		reelFrontVel = 0,
		reelRearVel = 0,
		meterLevel = 0,
		dialAngle = 0,
		dialTarget = 0,
		dialVel = 0,
		anchor = anchor,
		light = light,
		motes = motes,
	}
end

function CosmeticInspect.pulse(state: State, kind: PulseKind)
	local mode = state.liveMode
	if not mode then
		return
	end
	if mode == "Playback" then
		if kind == "Fire" then
			state.reelFrontVel = math.max(state.reelFrontVel, PB.REEL_FIRE_FRONT)
			state.reelRearVel = math.max(state.reelRearVel, PB.REEL_FIRE_REAR)
			state.meterLevel = math.max(state.meterLevel, PB.METER_FIRE_KICK)
			state.surge = math.max(state.surge, 0.85)
			if state.motes and state.motes.Parent then
				state.motes:Emit(SettingsApply.vfxCount(PB.MOTE_BURST_FIRE))
			end
		elseif kind == "Heavy" then
			state.reelFrontVel = PB.REEL_HEAVY_FRONT
			state.reelRearVel = PB.REEL_HEAVY_REAR
			state.meterLevel = PB.METER_HEAVY_KICK
			state.surge = 1
			if state.motes and state.motes.Parent then
				state.motes:Emit(SettingsApply.vfxCount(PB.MOTE_BURST_SEAT))
			end
		elseif kind == "Draw" then
			state.reelFrontVel = PB.REEL_DRAW_FRONT
			state.reelRearVel = PB.REEL_DRAW_REAR
			state.meterLevel = math.max(state.meterLevel, PB.METER_DRAW_KICK)
			state.surge = math.max(state.surge, 0.65)
		elseif kind == "MagOut" then
			state.reelFrontVel = PB.REEL_REWIND_FRONT
			state.reelRearVel = PB.REEL_REWIND_REAR
			state.surge = math.max(state.surge, 0.55)
		elseif kind == "Seat" then
			state.reelFrontVel = PB.REEL_SEAT_FRONT
			state.reelRearVel = PB.REEL_SEAT_REAR
			state.meterLevel = math.max(state.meterLevel, PB.METER_SEAT_KICK)
			state.surge = 1
			if state.motes and state.motes.Parent then
				state.motes:Emit(SettingsApply.vfxCount(PB.MOTE_BURST_SEAT))
			end
		elseif kind == "Inspect" then
			state.reelFrontVel = math.max(state.reelFrontVel, PB.REEL_DRAW_FRONT * 0.8)
			state.reelRearVel = math.max(state.reelRearVel, PB.REEL_DRAW_REAR * 0.8)
			state.surge = math.max(state.surge, 0.6)
		end
	elseif mode == "Sundial" then
		if kind == "Fire" then
			state.dialTarget += SD.DIAL_FIRE_STEP
			state.surge = math.max(state.surge, 0.85)
			if state.motes and state.motes.Parent then
				state.motes:Emit(SettingsApply.vfxCount(SD.MOTE_BURST_FIRE))
			end
		elseif kind == "Heavy" then
			state.dialTarget += SD.DIAL_HEAVY_STEP
			state.surge = 1
			if state.motes and state.motes.Parent then
				state.motes:Emit(SettingsApply.vfxCount(SD.MOTE_BURST_SEAT))
			end
		elseif kind == "Draw" then
			state.dialTarget += SD.DIAL_DRAW_STEP
			state.surge = math.max(state.surge, 0.7)
		elseif kind == "MagOut" then
			state.dialTarget += SD.DIAL_MAGOUT_STEP
			state.surge = math.max(state.surge, 0.5)
		elseif kind == "Seat" then
			state.dialTarget += SD.DIAL_SEAT_STEP
			state.surge = 1
			if state.motes and state.motes.Parent then
				state.motes:Emit(SettingsApply.vfxCount(SD.MOTE_BURST_SEAT))
			end
		elseif kind == "Inspect" then
			state.surge = math.max(state.surge, 0.65)
		end
	end
end

local function stepLive(state: State, dt: number, progress: number?)
	local stepDt = math.clamp(dt, 0, 0.1)
	state.clock += stepDt
	local mode = state.liveMode

	if mode == "Playback" then
		state.surge *= math.exp(-PB.SURGE_DECAY * stepDt)
		local drag = math.exp(-PB.REEL_DRAG * stepDt)
		state.reelFrontVel *= drag
		state.reelRearVel *= drag
		state.reelFrontAngle = (
			state.reelFrontAngle + (PB.REEL_IDLE_FRONT + state.reelFrontVel) * stepDt
		) % (math.pi * 2)
		state.reelRearAngle = (
			state.reelRearAngle + (PB.REEL_IDLE_REAR + state.reelRearVel) * stepDt
		) % (math.pi * 2)
		state.meterLevel *= math.exp(-PB.METER_DECAY * stepDt)

		local idleMeter = PB.METER_IDLE_BASE
			+ PB.METER_IDLE_AMP * (0.5 + 0.5 * math.sin(state.clock * PB.METER_IDLE_FREQ))
		local inspectMeter = if progress ~= nil
			then ease(progress, 0.20, 0.58) - ease(progress, 0.58, 0.80)
			else 0
		local meterTravel = math.clamp(math.max(idleMeter, state.meterLevel, inspectMeter), 0, 1)

		local inspectFront = if progress ~= nil
			then math.rad(240) * ease(progress, 0.18, 0.78)
			else 0
		local inspectRear = if progress ~= nil
			then math.rad(330) * ease(progress, 0.18, 0.78)
			else 0

		for _, p in state.parts do
			if not p.weld.Parent then
				continue
			end
			if p.kind == "MeterSweep" then
				p.weld.C0 = p.rest + p.axis * (p.distance * meterTravel)
			elseif p.kind == "ReelFront" then
				local angle = state.reelFrontAngle + inspectFront
				p.weld.C0 = CFrame.new(p.pivot)
					* CFrame.fromAxisAngle(p.axis, angle)
					* CFrame.new(-p.pivot)
					* p.rest
			elseif p.kind == "ReelRear" then
				local angle = state.reelRearAngle + inspectRear
				p.weld.C0 = CFrame.new(p.pivot)
					* CFrame.fromAxisAngle(p.axis, angle)
					* CFrame.new(-p.pivot)
					* p.rest
			end
		end

		if state.light and state.light.Parent then
			local breathe = 0.5 + 0.5 * math.sin(state.clock * 2.8)
			local s = math.clamp(math.max(state.surge, inspectMeter * 0.8), 0, 1)
			state.light.Brightness = PB.LIGHT_IDLE + PB.LIGHT_PULSE * breathe + PB.LIGHT_SURGE * s
			state.light.Color = PB.LIGHT_COLOR:Lerp(PB.LIGHT_SURGE_COLOR, s)
		end
	elseif mode == "Sundial" then
		state.surge *= math.exp(-SD.SURGE_DECAY * stepDt)
		state.dialTarget += SD.DIAL_IDLE_SPEED * stepDt
		-- Critically/under-damped horological escapement spring
		local omega = SD.DIAL_SPRING_FREQ
		local disp = state.dialTarget - state.dialAngle
		local accel = disp * omega * omega - state.dialVel * (2 * SD.DIAL_SPRING_DAMP * omega)
		state.dialVel += accel * stepDt
		state.dialAngle += state.dialVel * stepDt

		local inspectDial = if progress ~= nil
			then (math.pi / 2) * ease(progress, 0.18, 0.68)
			else 0
		local angle = state.dialAngle + inspectDial

		for _, p in state.parts do
			if not p.weld.Parent then
				continue
			end
			if p.kind == "Dial" then
				p.weld.C0 = CFrame.new(p.pivot)
					* CFrame.fromAxisAngle(p.axis, angle)
					* CFrame.new(-p.pivot)
					* p.rest
			end
		end

		if state.light and state.light.Parent then
			local breathe = 0.5 + 0.5 * math.sin(state.clock * 2.1)
			local inspectGlow = if progress ~= nil
				then ease(progress, 0.15, 0.5) - ease(progress, 0.6, 0.9)
				else 0
			local s = math.clamp(math.max(state.surge, inspectGlow * 0.75), 0, 1)
			state.light.Brightness = SD.LIGHT_IDLE + SD.LIGHT_PULSE * breathe + SD.LIGHT_SURGE * s
			state.light.Color = SD.LIGHT_COLOR:Lerp(SD.LIGHT_SURGE_COLOR, s)
		end
	end
end

function CosmeticInspect.step(state: State, dt: number, progress: number?)
	if state.liveMode then
		stepLive(state, dt, progress)
		return
	end
	if progress == nil then
		if state.active then
			for _, p in state.parts do
				if p.weld.Parent then
					p.weld.C0 = p.rest
				end
			end
			state.active = false
		end
		return
	end
	state.active = true
	for _, p in state.parts do
		if not p.weld.Parent then
			continue
		end
		if p.kind == "MeterSweep" then
			local travel = ease(progress, 0.23, 0.60) - ease(progress, 0.60, 0.78)
			p.weld.C0 = p.rest + p.axis * (p.distance * travel)
			continue
		end
		local angle = 0
		if p.kind == "Latch" then
			angle = -1.05 * (ease(progress, 0.23, 0.53) - ease(progress, 0.53, 0.80))
		elseif p.kind == "Dial" then
			angle = math.pi / 4 * ease(progress, 0.23, 0.59)
		elseif p.kind == "ReelFront" then
			angle = math.rad(137) * ease(progress, 0.23, 0.73)
		elseif p.kind == "ReelRear" then
			angle = math.rad(197) * ease(progress, 0.23, 0.73)
		end
		p.weld.C0 = CFrame.new(p.pivot)
			* CFrame.fromAxisAngle(p.axis, angle)
			* CFrame.new(-p.pivot)
			* p.rest
	end
end

function CosmeticInspect.destroy(state: State)
	local anchor = state.anchor
	state.anchor = nil
	state.light = nil
	state.motes = nil
	if anchor and anchor.Parent then
		pcall(function()
			anchor:Destroy()
		end)
	end
end

return CosmeticInspect
