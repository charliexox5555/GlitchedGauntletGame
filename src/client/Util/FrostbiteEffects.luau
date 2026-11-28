--!strict
-- Frostbite Legendary skin line: first-person viewmodel effects.
--   - Rest: gentle cold blue-white shimmer across the cryo-core heart, seams and
--     subtle falling frost motes (auto-suppressed in ADS to keep sight picture clean).
--   - Inspect: staggered 3-stage ice crystal crown growth (Rear -> Mid -> Front) with
--     blooming frost mist puffs and seam energy surge.
--   - Kill: sharp ice-white flash, outer glacier crust shards (FBShard1..4) crack and
--     shed outward with ice chip particles, then smoothly refreeze back to rest.
--   - Fire / Seat: crisp cryo flare on shots and magazine seat.
-- Everything lives inside the camera clone and cleans up automatically on unequip.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalHide = require(script.Parent.LocalHide)
local Profiles = require(ReplicatedStorage.Shared.Config.Frostbite)

local FrostbiteEffects = {}

type Pulse = "Fire" | "Seat"
export type Event = "Grow" | "Settle"

type Moving = {
	part: MeshPart,
	motor: Motor6D,
}

type GrowItem = Moving & {
	spec: Profiles.GrowStage,
	triggered: boolean,
}

type ShardItem = Moving & {
	spec: Profiles.ShardSpec,
}

type Emissive = {
	part: MeshPart,
	baseColor: Color3,
}

export type State = {
	profile: Profiles.Profile,
	scale: number,
	grow: { GrowItem },
	shards: { ShardItem },
	heart: Emissive?,
	seams: { Emissive },
	magGlow: Emissive?,
	light: PointLight?,
	moteEmitter: ParticleEmitter?,
	chipEmitter: ParticleEmitter?,
	clock: number,
	fireLeft: number,
	seatLeft: number,
	killPhase: "None" | "Flash" | "Shed" | "Regrow",
	killElapsed: number,
	settled: boolean,
}

local COOL_CYAN = Color3.fromHex("68D4FF")
local ICE_WHITE = Color3.fromHex("ECF9FF")

local function moving(model: Model, name: string): Moving?
	local part = model:FindFirstChild(name)
	if not part or not part:IsA("MeshPart") then
		return nil
	end
	local weld = part:FindFirstChild("SkinCosmeticWeld")
	if not weld or not weld:IsA("Weld") or not weld.Part0 or weld.Part1 ~= part then
		return nil
	end
	local motor = Instance.new("Motor6D")
	motor.Name = "FrostbiteMotion"
	motor.Part0 = weld.Part0
	motor.Part1 = part
	motor.C0 = weld.C0
	motor.C1 = weld.C1
	weld:Destroy()
	motor.Parent = part
	return { part = part, motor = motor }
end

local function emissive(model: Model, name: string?): Emissive?
	local part = if name then model:FindFirstChild(name) else nil
	if not part or not part:IsA("MeshPart") then
		return nil
	end
	return { part = part, baseColor = part.Color }
end

local function easeOutBack(t: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	local u = t - 1
	return 1 + c3 * u * u * u + c1 * u * u
end

local function easeOutCubic(t: number): number
	local u = 1 - t
	return 1 - u * u * u
end

local function makeFrostEmitters(host: MeshPart, scale: number): (ParticleEmitter, ParticleEmitter)
	local motes = Instance.new("ParticleEmitter")
	motes.Name = "FrostbiteMotes"
	motes.Color = ColorSequence.new(ICE_WHITE, COOL_CYAN)
	motes.LightEmission = 0.6
	motes.LightInfluence = 0.3
	motes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.018 * scale),
		NumberSequenceKeypoint.new(0.5, 0.026 * scale),
		NumberSequenceKeypoint.new(1, 0),
	})
	motes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	motes.Lifetime = NumberRange.new(0.55, 0.9)
	motes.Rate = 5
	motes.Speed = NumberRange.new(0.08 * scale, 0.18 * scale)
	motes.SpreadAngle = Vector2.new(35, 35)
	motes.Acceleration = Vector3.new(0, -0.25 * scale, 0)
	motes.EmissionDirection = Enum.NormalId.Top
	motes.LockedToPart = true
	motes.Parent = host

	local chips = Instance.new("ParticleEmitter")
	chips.Name = "FrostbiteChips"
	chips.Color = ColorSequence.new(ICE_WHITE, Color3.fromHex("3FB8F0"))
	chips.LightEmission = 0.45
	chips.LightInfluence = 0.3
	chips.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.045 * scale),
		NumberSequenceKeypoint.new(0.6, 0.032 * scale),
		NumberSequenceKeypoint.new(1, 0),
	})
	chips.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.7, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	chips.Lifetime = NumberRange.new(0.28, 0.48)
	chips.Rate = 0
	chips.Speed = NumberRange.new(0.6 * scale, 1.4 * scale)
	chips.SpreadAngle = Vector2.new(75, 75)
	chips.Rotation = NumberRange.new(-180, 180)
	chips.RotSpeed = NumberRange.new(-320, 320)
	chips.Acceleration = Vector3.new(0, -3.5 * scale, 0)
	chips.EmissionDirection = Enum.NormalId.Front
	chips.LockedToPart = true
	chips.Parent = host

	return motes, chips
end

function FrostbiteEffects.new(model: Model, scale: number, gunId: string): State?
	local profile = Profiles[gunId]
	if not profile then
		return nil
	end
	local grow: { GrowItem } = {}
	for _, spec in profile.growStages do
		local m = moving(model, spec.part)
		if m then
			table.insert(grow, {
				part = m.part,
				motor = m.motor,
				spec = spec,
				triggered = false,
			})
		end
	end
	local shards: { ShardItem } = {}
	for _, spec in profile.shards do
		local m = moving(model, spec.part)
		if m then
			table.insert(shards, {
				part = m.part,
				motor = m.motor,
				spec = spec,
			})
		end
	end
	if #grow == 0 and #shards == 0 then
		return nil
	end
	local heart = emissive(model, profile.heart)
	local seams: { Emissive } = {}
	for _, name in profile.seams do
		local e = emissive(model, name)
		if e then
			table.insert(seams, e)
		end
	end
	local magGlow = emissive(model, profile.magGlow)

	local light: PointLight? = nil
	local motes: ParticleEmitter? = nil
	local chips: ParticleEmitter? = nil
	local fxHost = if heart then heart.part elseif #seams > 0 then seams[1].part else nil
	if fxHost then
		local pl = Instance.new("PointLight")
		pl.Name = "FrostbiteCoreLight"
		pl.Range = 1.8 * scale
		pl.Color = COOL_CYAN
		pl.Brightness = 0.35
		pl.Shadows = false
		pl.Parent = fxHost
		light = pl
		motes, chips = makeFrostEmitters(fxHost, scale)
	end

	return {
		profile = profile,
		scale = scale,
		grow = grow,
		shards = shards,
		heart = heart,
		seams = seams,
		magGlow = magGlow,
		light = light,
		moteEmitter = motes,
		chipEmitter = chips,
		clock = 0,
		fireLeft = 0,
		seatLeft = 0,
		killPhase = "None",
		killElapsed = 0,
		settled = false,
	}
end

function FrostbiteEffects.pulse(state: State, kind: Pulse)
	if kind == "Fire" then
		state.fireLeft = state.profile.fireTime
	else
		state.seatLeft = state.profile.seatTime
	end
end

function FrostbiteEffects.onKill(state: State)
	state.killPhase = "Flash"
	state.killElapsed = 0
	if state.chipEmitter then
		state.chipEmitter:Emit(14)
	end
end

function FrostbiteEffects.step(
	state: State,
	dt: number,
	inspect: number?,
	visible: boolean,
	adsAlpha: number
): (Event?, number?)
	local profile = state.profile
	local scale = state.scale
	state.clock += dt
	state.fireLeft = math.max(0, state.fireLeft - dt)
	state.seatLeft = math.max(0, state.seatLeft - dt)

	local event: Event? = nil
	local eventStage: number? = nil

	-- 1. Inspect: staggered 3-stage crystal growth Rear -> Mid -> Front
	local inspectGlow = 0
	if visible and inspect then
		local allLocked = true
		for i, item in state.grow do
			local spec = item.spec
			local amount = 0
			if inspect >= spec.from and inspect < profile.retractFrom then
				if not item.triggered then
					item.triggered = true
					event, eventStage = "Grow", i
					if state.chipEmitter then
						state.chipEmitter:Emit(4)
					end
				end
				local t = math.clamp((inspect - spec.from) / (spec.to - spec.from), 0, 1)
				amount = easeOutBack(t)
				if t < 1 then
					allLocked = false
				end
			elseif inspect >= profile.retractFrom then
				local rt = math.clamp(
					(inspect - profile.retractFrom) / (profile.retractTo - profile.retractFrom),
					0,
					1
				)
				amount = 1 - easeOutCubic(rt)
				allLocked = false
			else
				allLocked = false
			end
			item.motor.Transform = CFrame.new(spec.offset * (amount * scale))
			inspectGlow = math.max(inspectGlow, math.clamp(amount, 0, 1))
		end
		if allLocked and not state.settled then
			state.settled = true
			event = "Settle"
		end
	else
		state.settled = false
		for _, item in state.grow do
			item.triggered = false
			item.motor.Transform = CFrame.identity
		end
	end

	-- 2. Kill: flash -> crack/shed outward -> regrow/refreeze
	local killFlash = 0
	if state.killPhase ~= "None" then
		state.killElapsed += dt
		if state.killPhase == "Flash" then
			local t = math.clamp(state.killElapsed / profile.killFlashTime, 0, 1)
			killFlash = 1
			for _, shard in state.shards do
				shard.motor.Transform = CFrame.new(shard.spec.burst * (0.12 * t * scale))
				if visible then
					LocalHide.set(shard.part, 0)
				end
			end
			if state.killElapsed >= profile.killFlashTime then
				state.killPhase = "Shed"
				state.killElapsed = 0
			end
		elseif state.killPhase == "Shed" then
			local t = math.clamp(state.killElapsed / profile.killShedTime, 0, 1)
			local e = easeOutCubic(t)
			killFlash = 1 - t
			for _, shard in state.shards do
				local sp = shard.spec
				shard.motor.Transform = CFrame.new(sp.burst * ((0.12 + 0.88 * e) * scale))
					* CFrame.Angles(sp.spin.X * e, sp.spin.Y * e, sp.spin.Z * e)
				if visible then
					LocalHide.set(shard.part, math.clamp(e, 0, 1))
				end
			end
			if state.killElapsed >= profile.killShedTime then
				state.killPhase = "Regrow"
				state.killElapsed = 0
			end
		else
			local t = math.clamp(state.killElapsed / profile.killRegrowTime, 0, 1)
			local e = easeOutCubic(t)
			for _, shard in state.shards do
				-- Regrow gently from slightly inside the crystal bed back to rest
				local sink = shard.spec.burst.Unit * (-0.022 * (1 - e) * scale)
				shard.motor.Transform = CFrame.new(sink)
				if visible then
					LocalHide.set(shard.part, if e < 0.15 then 1 else 0)
				end
			end
			if state.killElapsed >= profile.killRegrowTime then
				state.killPhase = "None"
				state.killElapsed = 0
				for _, shard in state.shards do
					shard.motor.Transform = CFrame.identity
					if visible then
						LocalHide.set(shard.part, 0)
					end
				end
			end
		end
	end

	-- 3. Rest cold shimmer + fire/seat pulses + ADS-clean emitters
	local shimmer = 0.5 + 0.5 * math.sin(state.clock * (math.pi * 2 / profile.shimmerPeriod))
	local fireBoost = if state.fireLeft > 0 then state.fireLeft / profile.fireTime else 0
	local seatBoost = if state.seatLeft > 0 then state.seatLeft / profile.seatTime else 0
	local mixAmt = math.clamp(
		shimmer * 0.35 + inspectGlow * 0.45 + fireBoost * 0.65 + seatBoost * 0.60 + killFlash,
		0,
		1
	)

	if state.heart then
		local c = state.heart.baseColor
			:Lerp(COOL_CYAN, 0.28 * (1 - shimmer))
			:Lerp(ICE_WHITE, mixAmt * 0.75)
		state.heart.part.Color = c
	end
	for _, seam in state.seams do
		seam.part.Color =
			seam.baseColor:Lerp(COOL_CYAN, 0.35 * (1 - shimmer)):Lerp(ICE_WHITE, mixAmt * 0.65)
	end
	if state.magGlow then
		local magMix = math.clamp(shimmer * 0.30 + seatBoost * 0.85 + killFlash * 0.7, 0, 1)
		state.magGlow.part.Color = state.magGlow.baseColor:Lerp(ICE_WHITE, magMix * 0.75)
	end

	local showFx = visible and adsAlpha < 0.25
	if state.light then
		state.light.Enabled = showFx
		state.light.Brightness = 0.25 + mixAmt * 0.85
	end
	if state.moteEmitter then
		state.moteEmitter.Enabled = showFx
	end

	return event, eventStage
end

return FrostbiteEffects
