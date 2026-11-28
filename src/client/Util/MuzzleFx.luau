--!strict
-- Muzzle flashes, split out of Controllers/EffectsController (which forwards
-- EffectsController.muzzleFlash here and calls step() every frame). Owns the
-- per-muzzle emitter rigs (flash, side flame, embers, smoke puff, barrel
-- wisps), the light pops and barrel heat, and the effects clock they run on.
--
-- Each muzzle gets a rig of emitters the first time it fires: the front burst
-- and side flame (locked to the gun), a hot core, embers, a smoke puff, a
-- barrel wisp and a light. Suppressed and muzzle-device guns (`puff`) get a
-- subtle grey puff instead of the flare, as in Valorant.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)
local ViewmodelConfig = require(ReplicatedStorage.Shared.Config.Viewmodel)
local Slipframe = require(ReplicatedStorage.Shared.Config.Slipframe)
local SkinPreview = require(ReplicatedStorage.Shared.Config.SkinPreview)
local SettingsApply = require(ReplicatedStorage.Shared.SettingsApply) -- Optimized VFX

local Kit = require(script.Parent.ShotFxKit)

type WeaponConfig = Types.WeaponConfig
type FlashStyle = "Slipframe" | "Moltframe" | "Playback" | "Sundial" | "Riftforge" | "Frostbite"

local MuzzleFx = {}

local WHITE = Kit.WHITE
local FIRE = Kit.FIRE
local EMBER = Color3.fromHex("FFC070")
local SMOKE = Color3.fromHex("C9C7C2")
local PUFF = Color3.fromHex("EEEDEA") -- suppressed / muzzle-device puff: light, reads on grey floors
local SLIPFRAME_ICE = Color3.fromHex("E2F3FF")
local SLIPFRAME_BLUE = Color3.fromHex("77C5FF")
local MF = SkinPreview.CHAMBER_FLOW
local PB = SkinPreview.PLAYBACK
local SD = SkinPreview.SUNDIAL
local RF = SkinPreview.RIFTFORGE

local LIGHT_TIME = 0.05
-- The flash sprites' Brightness: over 1 so they hold their colour against a
-- bright floor or sky, under the place's Bloom threshold (2) so a spray
-- doesn't white the view out.
local FLASH_BRIGHTNESS = 1.7
-- First-person flashes are this much smaller again than the viewmodel's scale
-- (the gun sits right in front of the camera).
local FP_FLASH = 0.75
local FLASH_AHEAD = 0.32 -- the flash rig sits this far (x flash size) in front of the Muzzle
-- Barrel heat: +1 per shot, cools at HEAT_COOL per second; above HEAT_WISP
-- the barrel smokes for a moment after you stop firing.
local HEAT_COOL = 2.5
local HEAT_WISP = 4
local HEAT_MAX = 12

local emitter = Kit.emitter
local fire = Kit.fire
local flipbook = Kit.flipbook
local curve = Kit.curve

-- Effects clock (seconds, scaled by the effects time scale), advanced in step().
local fxClock = 0

-- Light pops -------------------------------------------------------------------
-- A light switched on for LIGHT_TIME and faded out (no tweens per shot).

local lightStart: { [PointLight]: number } = {}
local lightBase: { [PointLight]: number } = {}

local function popLight(light: PointLight, brightness: number)
	light.Brightness = brightness
	light.Enabled = true
	lightStart[light] = fxClock
	lightBase[light] = brightness
end

local function stepLights(now: number)
	for light, t0 in lightStart do
		local k = (now - t0) / LIGHT_TIME
		if k >= 1 or not light.Parent then
			light.Enabled = false
			lightStart[light] = nil
			lightBase[light] = nil
		else
			light.Brightness = lightBase[light] * (1 - k) * (1 - k)
		end
	end
end

-- Muzzle rigs --------------------------------------------------------------------

type MuzzleRig = {
	front: ParticleEmitter,
	side: ParticleEmitter?,
	core: ParticleEmitter?,
	darkFlame: ParticleEmitter?,
	forks: { ParticleEmitter }?,
	embers: ParticleEmitter?,
	smoke: ParticleEmitter,
	wisp: ParticleEmitter,
	light: PointLight,
	brightness: number,
	smokeCount: number,
	heat: number,
	lastShot: number,
}

local rigs: { [Attachment]: MuzzleRig } = setmetatable({}, { __mode = "k" }) :: any

local function flashSize(config: WeaponConfig): number
	local class = config.class
	if class == "Shotgun" then
		return 1.3
	elseif class == "Sniper" then
		return 1.25
	elseif class == "MachineGun" then
		return 1.1
	elseif class == "Sidearm" or class == "SMG" then
		return 0.8
	end
	return 1
end

local function slipframeFlash(
	holder: Attachment,
	scale: number,
	spread: number
): (ParticleEmitter, { ParticleEmitter })
	local core = emitter(holder, VFX.GLOW, SLIPFRAME_ICE)
	core.Name = "SlipframeFlashCore"
	fire(core)
	core.Brightness = 1.58
	core.LockedToPart = true
	core.Lifetime = NumberRange.new(0.052)
	core.Size = curve({ 0, 0.48 * scale, 0.20, 0.56 * scale, 1, 0.19 * scale })
	core.Transparency = curve({ 0, 0.03, 0.4, 0.24, 1, 1 })
	core.Rotation = NumberRange.new(0)
	core.ZOffset = 0.07 * scale

	local forks = {}
	for _, side in { -1, 1 } do
		local anchor = Instance.new("Attachment")
		anchor.Name = "SlipframeFlashEdge"
		anchor.CFrame = holder.CFrame
			* CFrame.new(side * 0.105 * scale * spread, 0.046 * scale, -0.05 * scale)
		anchor.Parent = holder.Parent
		local flare = emitter(anchor, VFX.SPARK, SLIPFRAME_BLUE)
		fire(flare)
		flare.Color = ColorSequence.new(SLIPFRAME_ICE, SLIPFRAME_BLUE)
		flare.LightEmission = 0.86
		flare.Brightness = 1.75
		flare.LockedToPart = true
		flare.Rotation = NumberRange.new(-side * 36 * spread)
		flare.Lifetime = NumberRange.new(0.068)
		flare.Size = curve({ 0, 0.43 * scale, 0.25, 0.58 * scale, 1, 0.19 * scale })
		flare.Transparency = curve({ 0, 0, 0.52, 0.15, 1, 1 })
		flare.ZOffset = 0.045 * scale
		table.insert(forks, flare)
	end
	return core, forks
end

local function moltframeFlash(
	holder: Attachment,
	scale: number
): (ParticleEmitter, ParticleEmitter, { ParticleEmitter })
	local burst = emitter(holder, VFX.FLASH_FRONT_2x2, MF.MUZZLE_OUTER)
	burst.Name = "MoltframeFlashFront"
	fire(burst)
	flipbook(burst)
	burst.Color = ColorSequence.new(MF.MUZZLE_CORE, MF.MUZZLE_OUTER)
	burst.Brightness = FLASH_BRIGHTNESS
	burst.LockedToPart = true
	burst.Lifetime = NumberRange.new(0.052)
	burst.Size = curve({ 0, 0.54 * scale, 0.3, 0.88 * scale, 1, 0.56 * scale })
	burst.Transparency = curve({ 0, 0.02, 0.52, 0.16, 1, 1 })
	burst.ZOffset = 0.13 * scale

	local core = emitter(holder, VFX.GLOW, MF.MUZZLE_CORE)
	core.Name = "MoltframeFlashCore"
	fire(core)
	core.Brightness = 1.62
	core.LockedToPart = true
	core.Lifetime = NumberRange.new(0.048)
	core.Size = curve({ 0, 0.42 * scale, 0.25, 0.48 * scale, 1, 0.16 * scale })
	core.Transparency = curve({ 0, 0.08, 0.45, 0.35, 1, 1 })
	core.ZOffset = 0.15 * scale

	local forks = {}
	for _, side in { -1, 1 } do
		local anchor = Instance.new("Attachment")
		anchor.Name = "MoltframeFlashFang"
		anchor.CFrame = holder.CFrame
			* CFrame.new(side * 0.095 * scale, 0.032 * scale, -0.04 * scale)
		anchor.Parent = holder.Parent
		local flare = emitter(anchor, VFX.SPARK, MF.MUZZLE_OUTER)
		fire(flare)
		flare.Color = ColorSequence.new(MF.MUZZLE_CORE, MF.MUZZLE_DEEP)
		flare.LightEmission = 0.85
		flare.Brightness = 1.7
		flare.LockedToPart = true
		flare.Rotation = NumberRange.new(-side * 32)
		flare.Lifetime = NumberRange.new(0.062)
		flare.Size = curve({ 0, 0.36 * scale, 0.25, 0.50 * scale, 1, 0.15 * scale })
		flare.Transparency = curve({ 0, 0.04, 0.5, 0.2, 1, 1 })
		flare.ZOffset = 0.06 * scale
		table.insert(forks, flare)
	end
	return burst, core, forks
end

local function playbackFlash(
	holder: Attachment,
	scale: number
): (ParticleEmitter, ParticleEmitter, { ParticleEmitter })
	local burst = emitter(holder, VFX.FLASH_FRONT_2x2, PB.MUZZLE_OUTER)
	burst.Name = "PlaybackFlashFront"
	fire(burst)
	flipbook(burst)
	burst.Color = ColorSequence.new(PB.MUZZLE_CORE, PB.MUZZLE_OUTER)
	burst.Brightness = FLASH_BRIGHTNESS
	burst.LockedToPart = true
	burst.Lifetime = NumberRange.new(0.05)
	burst.Size = curve({ 0, 0.52 * scale, 0.3, 0.84 * scale, 1, 0.50 * scale })
	burst.Transparency = curve({ 0, 0.02, 0.52, 0.16, 1, 1 })
	burst.ZOffset = 0.13 * scale

	local core = emitter(holder, VFX.GLOW, PB.MUZZLE_CORE)
	core.Name = "PlaybackFlashCore"
	fire(core)
	core.Brightness = 1.58
	core.LockedToPart = true
	core.Lifetime = NumberRange.new(0.045)
	core.Size = curve({ 0, 0.38 * scale, 0.25, 0.44 * scale, 1, 0.15 * scale })
	core.Transparency = curve({ 0, 0.08, 0.45, 0.32, 1, 1 })
	core.ZOffset = 0.15 * scale

	local forks = {}
	for _, side in { -1, 1 } do
		local anchor = Instance.new("Attachment")
		anchor.Name = "PlaybackFlashSpark"
		anchor.CFrame = holder.CFrame
			* CFrame.new(side * 0.09 * scale, 0.024 * scale, -0.035 * scale)
		anchor.Parent = holder.Parent
		local flare = emitter(anchor, VFX.SPARK, PB.MUZZLE_ACCENT)
		fire(flare)
		flare.Color = ColorSequence.new(PB.MUZZLE_ACCENT, PB.MUZZLE_DEEP)
		flare.LightEmission = 0.88
		flare.Brightness = 1.65
		flare.LockedToPart = true
		flare.Rotation = NumberRange.new(-side * 24)
		flare.Lifetime = NumberRange.new(0.056)
		flare.Size = curve({ 0, 0.30 * scale, 0.25, 0.42 * scale, 1, 0.12 * scale })
		flare.Transparency = curve({ 0, 0.04, 0.5, 0.22, 1, 1 })
		flare.ZOffset = 0.06 * scale
		table.insert(forks, flare)
	end
	return burst, core, forks
end

local function sundialFlash(
	holder: Attachment,
	scale: number
): (ParticleEmitter, ParticleEmitter, { ParticleEmitter })
	local burst = emitter(holder, VFX.FLASH_FRONT_2x2, SD.MUZZLE_OUTER)
	burst.Name = "SundialFlashFront"
	fire(burst)
	flipbook(burst)
	burst.Color = ColorSequence.new(SD.MUZZLE_CORE, SD.MUZZLE_OUTER)
	burst.Brightness = FLASH_BRIGHTNESS
	burst.LockedToPart = true
	burst.Lifetime = NumberRange.new(0.054)
	burst.Size = curve({ 0, 0.56 * scale, 0.3, 0.90 * scale, 1, 0.54 * scale })
	burst.Transparency = curve({ 0, 0.02, 0.52, 0.15, 1, 1 })
	burst.ZOffset = 0.13 * scale

	local core = emitter(holder, VFX.GLOW, SD.MUZZLE_CORE)
	core.Name = "SundialFlashCore"
	fire(core)
	core.Brightness = 1.65
	core.LockedToPart = true
	core.Lifetime = NumberRange.new(0.05)
	core.Size = curve({ 0, 0.44 * scale, 0.25, 0.50 * scale, 1, 0.16 * scale })
	core.Transparency = curve({ 0, 0.06, 0.45, 0.30, 1, 1 })
	core.ZOffset = 0.15 * scale

	-- 4-ray compass solar flares (angled gold sun-spikes)
	local forks = {}
	for _, spec in
		{ { -1, 0.036, 36 }, { 1, 0.036, -36 }, { -1, -0.036, 144 }, { 1, -0.036, -144 } }
	do
		local anchor = Instance.new("Attachment")
		anchor.Name = "SundialSolarRay"
		anchor.CFrame = holder.CFrame
			* CFrame.new(spec[1] * 0.088 * scale, spec[2] * scale, -0.035 * scale)
		anchor.Parent = holder.Parent
		local flare = emitter(anchor, VFX.SPARK, SD.MUZZLE_OUTER)
		fire(flare)
		flare.Color = ColorSequence.new(SD.MUZZLE_CORE, SD.MUZZLE_DEEP)
		flare.LightEmission = 0.88
		flare.Brightness = 1.7
		flare.LockedToPart = true
		flare.Rotation = NumberRange.new(spec[3])
		flare.Lifetime = NumberRange.new(0.064)
		flare.Size = curve({ 0, 0.32 * scale, 0.25, 0.46 * scale, 1, 0.13 * scale })
		flare.Transparency = curve({ 0, 0.04, 0.5, 0.2, 1, 1 })
		flare.ZOffset = 0.06 * scale
		table.insert(forks, flare)
	end
	return burst, core, forks
end

local function buildRig(
	muzzle: Attachment,
	config: WeaponConfig,
	scale: number,
	firstPerson: boolean,
	spectral: Color3?,
	style: FlashStyle?
): MuzzleRig?
	local parent = muzzle.Parent
	if not parent or not parent:IsA("BasePart") then
		return nil
	end
	local suppressed = config.suppressed == true
	local puff = suppressed or config.muzzleDevice == true
	local frostbite = firstPerson and style == "Frostbite"
	local profile = if firstPerson and (style == "Slipframe" or frostbite)
		then (Slipframe[config.id] or { flashScale = 1.05, flashSpread = 1.05 })
		else nil
	local moltframe = firstPerson and style == "Moltframe"
	local playback = firstPerson and style == "Playback"
	local sundial = firstPerson and style == "Sundial"
	local riftforge = firstPerson and style == "Riftforge"
	local coolFlash = profile ~= nil and not puff
	local violetFlash = moltframe and not puff
	local playbackFlashOn = playback and not puff
	local sundialFlashOn = sundial and not puff
	local riftforgeFlashOn = riftforge and not puff
	local styledFlash = coolFlash
		or violetFlash
		or playbackFlashOn
		or sundialFlashOn
		or riftforgeFlashOn
	local styledSkin = profile ~= nil or moltframe or playback or sundial or riftforge
	local s = scale
		* flashSize(config)
		* (if suppressed then 0.6 else 1)
		* (if profile then profile.flashScale else 1)

	-- The flash is a billboard: centred on the opening, the barrel (or a
	-- suppressor) hides its back half from first person and it seems to
	-- burst inside the muzzle. Start it just ahead of the opening instead.
	-- ZOffset (studs, toward the camera) must stay under that lead, or it
	-- pulls the quad back behind the muzzle face: a fixed 0.2 put a small
	-- suppressed flash inside the Phantom's can.
	local holder = Instance.new("Attachment")
	holder.Name = "FxMuzzle"
	holder.CFrame = muzzle.CFrame * CFrame.new(0, 0, -FLASH_AHEAD * s)
	holder.Parent = parent

	local front: ParticleEmitter
	local core: ParticleEmitter? = nil
	local forks: { ParticleEmitter }? = nil
	if profile and not puff then
		front, forks = slipframeFlash(holder, s, profile.flashSpread)
	elseif violetFlash then
		front, core, forks = moltframeFlash(holder, s)
	elseif playbackFlashOn then
		front, core, forks = playbackFlash(holder, s)
	elseif sundialFlashOn then
		front, core, forks = sundialFlash(holder, s)
	elseif riftforgeFlashOn then
		front, core, forks = moltframeFlash(holder, s * 1.08)
	elseif puff then
		-- Styled suppressed guns keep a tight tinted forward puff + subtle glint.
		front = emitter(
			holder,
			VFX.SMOKE_2x2,
			if profile
				then SLIPFRAME_ICE
				elseif moltframe then MF.MUZZLE_CORE
				elseif playback then PB.MUZZLE_CORE
				elseif sundial then SD.MUZZLE_CORE
				elseif riftforge then RF.MUZZLE_CORE
				else PUFF
		)
		if profile then
			front.Name = "SlipframeSuppressedPuff"
			front.Color = ColorSequence.new(SLIPFRAME_ICE, SLIPFRAME_BLUE)
			front.LightEmission = 0.18
		elseif moltframe then
			front.Name = "MoltframeSuppressedPuff"
			front.Color = ColorSequence.new(MF.MUZZLE_CORE, MF.MUZZLE_OUTER)
			front.LightEmission = 0.28
			local glint = emitter(holder, VFX.GLOW, MF.MUZZLE_CORE)
			glint.Name = "MoltframeSuppressedGlint"
			fire(glint)
			glint.Brightness = 1.35
			glint.LockedToPart = true
			glint.Lifetime = NumberRange.new(0.042)
			glint.Size = curve({ 0, 0.24 * s, 0.3, 0.30 * s, 1, 0.10 * s })
			glint.Transparency = curve({ 0, 0.28, 1, 1 })
			glint.ZOffset = 0.08 * s
			core = glint
		elseif playback then
			front.Name = "PlaybackSuppressedPuff"
			front.Color = ColorSequence.new(PB.MUZZLE_CORE, PB.MUZZLE_ACCENT)
			front.LightEmission = 0.24
			local glint = emitter(holder, VFX.GLOW, PB.MUZZLE_ACCENT)
			glint.Name = "PlaybackSuppressedGlint"
			fire(glint)
			glint.Brightness = 1.3
			glint.LockedToPart = true
			glint.Lifetime = NumberRange.new(0.04)
			glint.Size = curve({ 0, 0.22 * s, 0.3, 0.28 * s, 1, 0.10 * s })
			glint.Transparency = curve({ 0, 0.30, 1, 1 })
			glint.ZOffset = 0.08 * s
			core = glint
		elseif sundial then
			front.Name = "SundialSuppressedPuff"
			front.Color = ColorSequence.new(SD.MUZZLE_CORE, SD.MUZZLE_OUTER)
			front.LightEmission = 0.26
			local glint = emitter(holder, VFX.GLOW, SD.MUZZLE_OUTER)
			glint.Name = "SundialSuppressedGlint"
			fire(glint)
			glint.Brightness = 1.38
			glint.LockedToPart = true
			glint.Lifetime = NumberRange.new(0.044)
			glint.Size = curve({ 0, 0.24 * s, 0.3, 0.32 * s, 1, 0.10 * s })
			glint.Transparency = curve({ 0, 0.26, 1, 1 })
			glint.ZOffset = 0.08 * s
			core = glint
		elseif riftforge then
			front.Name = "RiftforgeSuppressedPuff"
			front.Color = ColorSequence.new(RF.MUZZLE_CORE, RF.MUZZLE_OUTER)
			front.LightEmission = 0.38
			local glint = emitter(holder, VFX.GLOW, RF.MUZZLE_CORE)
			glint.Name = "RiftforgeSuppressedGlint"
			fire(glint)
			glint.Brightness = 1.55
			glint.LockedToPart = true
			glint.Lifetime = NumberRange.new(0.048)
			glint.Size = curve({ 0, 0.30 * s, 0.28, 0.40 * s, 1, 0.12 * s })
			glint.Transparency = curve({ 0, 0.16, 1, 1 })
			glint.ZOffset = 0.09 * s
			core = glint
			-- Twin crackling plasma forks snapping out of the baffled suppressor crown
			local rfForks = {}
			for _, side in { -1, 1 } do
				local anchor = Instance.new("Attachment")
				anchor.Name = "RiftforgePlasmaFork"
				anchor.CFrame = holder.CFrame * CFrame.new(side * 0.08 * s, 0.015 * s, -0.025 * s)
				anchor.Parent = holder.Parent
				local flare = emitter(anchor, VFX.SPARK, RF.MUZZLE_OUTER)
				fire(flare)
				flare.Color = ColorSequence.new(RF.MUZZLE_CORE, RF.MUZZLE_DEEP)
				flare.LightEmission = 0.92
				flare.Brightness = 1.72
				flare.LockedToPart = true
				flare.Rotation = NumberRange.new(-side * 28)
				flare.Lifetime = NumberRange.new(0.056)
				flare.Size = curve({ 0, 0.28 * s, 0.25, 0.42 * s, 1, 0.10 * s })
				flare.Transparency = curve({ 0, 0.06, 0.5, 0.24, 1, 1 })
				flare.ZOffset = 0.06 * s
				table.insert(rfForks, flare)
			end
			forks = rfForks
		end
		flipbook(front)
		front.LockedToPart = true
		front.EmissionDirection = Enum.NormalId.Front
		front.Speed = NumberRange.new(2 * s, 4 * s)
		front.Drag = 6
		front.Lifetime = if styledSkin
			then NumberRange.new(0.08, 0.14)
			else NumberRange.new(0.14, 0.22)
		front.Size = curve({ 0, 0.5 * s, 1, (if styledSkin then 1.24 else 1.5) * s })
		front.Transparency = curve({ 0, 0.3, 0.4, 0.6, 1, 1 })
		front.Rotation = NumberRange.new(0, 360)
		front.ZOffset = 0.1 * s
	else
		-- Down the barrel: a star burst, two frames long.
		front = emitter(
			holder,
			if spectral then VFX.T_FLASH else VFX.FLASH_FRONT_2x2,
			spectral or WHITE
		)
		fire(front)
		if not spectral then
			flipbook(front)
		end
		front.LockedToPart = true
		-- 2026-11-10: the stylised sheet; a touch bigger, brighter and a frame
		-- longer than the old one, which washed out over bright floors.
		front.Brightness = FLASH_BRIGHTNESS
		front.Lifetime = if spectral then NumberRange.new(0.05) else NumberRange.new(0.045, 0.06)
		local frontScale = if spectral then 0.86 * s else s
		front.Size = curve({ 0, 0.6 * frontScale, 0.35, 0.95 * frontScale, 1, 0.8 * frontScale })
		front.Transparency = curve({ 0, 0, 0.55, 0.15, 1, 1 })
		front.ZOffset = 0.15 * s

		local c = emitter(holder, VFX.GLOW, spectral or FIRE)
		fire(c)
		c.LockedToPart = true
		c.Lifetime = NumberRange.new(if spectral then 0.05 else 0.04)
		c.Size = curve({ 0, 0.35 * s, 1, 0.2 * s })
		c.Transparency = curve({ 0, 0.5, 1, 1 })
		core = c
	end

	-- From the side: a ragged tongue of flame out of the muzzle. Seen nearly
	-- down the barrel in first person it shrinks to a short flick, so it's
	-- smaller there.
	local side: ParticleEmitter? = nil
	local embers: ParticleEmitter? = nil
	local darkFlame: ParticleEmitter? = nil
	if not puff and not styledFlash then
		local sideSize = (if firstPerson then 0.8 else 1.15) * s
		-- The side flame's texture starts at its bottom edge, so it sits half
		-- its size ahead of the muzzle.
		local ahead = Instance.new("Attachment")
		ahead.Name = "FxMuzzleSide"
		ahead.CFrame = muzzle.CFrame * CFrame.new(0, 0, -sideSize * 0.47)
		ahead.Parent = parent
		local e = emitter(
			ahead,
			if spectral then VFX.FLAME_SHEET_4x4 else VFX.FLASH_SIDE_2x2,
			spectral or WHITE
		)
		fire(e)
		if spectral then
			e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
			e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
			e.LightEmission = 0.62
		else
			flipbook(e)
		end
		e.LockedToPart = true
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.EmissionDirection = Enum.NormalId.Front
		e.Speed = NumberRange.new(0.01)
		e.Rotation = NumberRange.new(0)
		e.Brightness = FLASH_BRIGHTNESS
		e.Lifetime = if spectral then NumberRange.new(0.05) else NumberRange.new(0.045, 0.06)
		e.Size = curve({ 0, sideSize * 0.75, 0.4, sideSize * 1.1, 1, sideSize })
		e.Transparency = curve({ 0, 0, 0.55, 0.15, 1, 1 })
		side = e
		if spectral then
			local shade = emitter(ahead, VFX.T_FLASH, Color3.fromRGB(12, 32, 32))
			shade.Name = "ShadowMistDarkFlame"
			shade.LockedToPart = true
			shade.Lifetime = NumberRange.new(0.05)
			shade.LightInfluence = 0
			shade.Rotation = NumberRange.new(-20, 20)
			shade.Size = curve({ 0, 0.64 * s, 0.35, 1.28 * s, 1, 0.97 * s })
			shade.Transparency = curve({ 0, 0.15, 0.45, 0.27, 1, 1 })
			darkFlame = shade
		end

		local em = Kit.sparkEmitter(holder, 0.07 * s)
		em.Color = ColorSequence.new(
			spectral or EMBER,
			if spectral then Color3.fromRGB(34, 118, 101) else Kit.SPARK_COOL
		)
		em.Speed = NumberRange.new(35 * s, 60 * s)
		em.SpreadAngle = Vector2.new(9, 9)
		em.Lifetime = NumberRange.new(0.04, 0.1)
		em.Drag = 5
		embers = em
	elseif frostbite and not puff then
		local em = Kit.sparkEmitter(holder, 0.068 * s)
		em.Name = "FrostbiteMuzzleShards"
		em.Texture = VFX.FROST_SHARD
		em.Color = ColorSequence.new(Color3.fromHex("ECFDFF"), Color3.fromHex("3FB8F0"))
		em.Speed = NumberRange.new(24 * s, 48 * s)
		em.SpreadAngle = Vector2.new(12, 12)
		em.Lifetime = NumberRange.new(0.05, 0.11)
		em.Drag = 6
		embers = em
	elseif violetFlash then
		local em = Kit.sparkEmitter(holder, 0.068 * s)
		em.Name = "MoltframeMuzzleEmbers"
		em.Color = ColorSequence.new(MF.MUZZLE_CORE, MF.MUZZLE_DEEP)
		em.Speed = NumberRange.new(28 * s, 52 * s)
		em.SpreadAngle = Vector2.new(11, 11)
		em.Lifetime = NumberRange.new(0.045, 0.10)
		em.Drag = 5
		embers = em
	elseif playbackFlashOn then
		local em = Kit.sparkEmitter(holder, 0.064 * s)
		em.Name = "PlaybackMuzzleEmbers"
		em.Color = ColorSequence.new(PB.MUZZLE_ACCENT, PB.MUZZLE_OUTER)
		em.Speed = NumberRange.new(26 * s, 48 * s)
		em.SpreadAngle = Vector2.new(10, 10)
		em.Lifetime = NumberRange.new(0.04, 0.095)
		em.Drag = 5
		embers = em
	elseif sundialFlashOn then
		local em = Kit.sparkEmitter(holder, 0.072 * s)
		em.Name = "SundialMuzzleEmbers"
		em.Color = ColorSequence.new(SD.MUZZLE_CORE, SD.MUZZLE_DEEP)
		em.Speed = NumberRange.new(30 * s, 56 * s)
		em.SpreadAngle = Vector2.new(11, 11)
		em.Lifetime = NumberRange.new(0.045, 0.105)
		em.Drag = 5
		embers = em
	elseif riftforge then
		local em = Kit.sparkEmitter(holder, 0.068 * s)
		em.Name = "RiftforgeMuzzleEmbers"
		em.Color = ColorSequence.new(RF.MUZZLE_CORE, RF.MUZZLE_DEEP)
		em.Speed = NumberRange.new(28 * s, 52 * s)
		em.SpreadAngle = Vector2.new(12, 12)
		em.Lifetime = NumberRange.new(0.045, 0.10)
		em.Drag = 5
		embers = em
	end

	-- One grey puff per shot, drifting forward and up.
	local smokeColor = if profile
		then Color3.fromHex("BBCBDA")
		elseif moltframe then MF.MUZZLE_SMOKE
		elseif playback then PB.MUZZLE_SMOKE
		elseif sundial then SD.MUZZLE_SMOKE
		elseif riftforge then RF.MUZZLE_SMOKE
		elseif spectral then Color3.fromRGB(109, 161, 153)
		else SMOKE
	local smoke = emitter(holder, VFX.SMOKE_2x2, smokeColor)
	flipbook(smoke)
	smoke.Lifetime = if styledSkin or spectral
		then NumberRange.new(0.21, 0.43)
		else NumberRange.new(0.6, 1.1)
	smoke.Speed = NumberRange.new(2 * s, 5 * s)
	smoke.SpreadAngle = Vector2.new(18, 18)
	smoke.EmissionDirection = Enum.NormalId.Front
	smoke.Acceleration = Vector3.new(0, 1.6 * s, 0)
	smoke.Drag = 3
	smoke.RotSpeed = NumberRange.new(-50, 50)
	smoke.Size = curve({ 0, 0.18 * s, 1, 1.1 * s })
	smoke.Transparency = curve({ 0, 1, 0.1, 0.82, 1, 1 })

	-- Thin wisps curling off a hot barrel: continuous, rate set each frame.
	local wisp = emitter(holder, VFX.SMOKE_2x2, smokeColor)
	flipbook(wisp)
	wisp.Rate = 0
	wisp.Enabled = true
	wisp.Lifetime = NumberRange.new(0.9, 1.5)
	wisp.Speed = NumberRange.new(0.3 * s, 0.8 * s)
	wisp.SpreadAngle = Vector2.new(25, 25)
	wisp.EmissionDirection = Enum.NormalId.Top
	wisp.Acceleration = Vector3.new(0.4 * s, 2.2 * s, 0)
	wisp.Drag = 1.5
	wisp.RotSpeed = NumberRange.new(-30, 30)
	wisp.Size = curve({ 0, 0.06 * s, 1, 0.55 * s })
	wisp.Squash = curve({ 0, -0.6, 1, -0.2 }) -- taller than wide
	wisp.Transparency = curve({ 0, 1, 0.2, 0.86, 1, 1 })

	local light = Instance.new("PointLight")
	light.Color = if coolFlash
		then SLIPFRAME_BLUE
		elseif moltframe then MF.MUZZLE_LIGHT
		elseif playback then PB.MUZZLE_LIGHT
		elseif sundial then SD.MUZZLE_LIGHT
		elseif riftforge then RF.MUZZLE_LIGHT
		else spectral or FIRE
	light.Range = if coolFlash or spectral
		then 4.4
		elseif violetFlash then MF.MUZZLE_LIGHT_RANGE
		elseif playbackFlashOn then PB.MUZZLE_LIGHT_RANGE
		elseif sundialFlashOn then SD.MUZZLE_LIGHT_RANGE
		elseif riftforge then RF.MUZZLE_LIGHT_RANGE
		elseif puff then 4
		else 10
	light.Shadows = false
	light.Enabled = false
	light.Parent = holder

	local rig: MuzzleRig = {
		front = front,
		side = side,
		core = core,
		darkFlame = darkFlame,
		forks = forks,
		embers = embers,
		smoke = smoke,
		wisp = wisp,
		light = light,
		-- Fast guns pop a dimmer light, or the room strobes.
		brightness = if coolFlash
			then 1.65
			elseif violetFlash then MF.MUZZLE_LIGHT_BRIGHTNESS
			elseif playbackFlashOn then PB.MUZZLE_LIGHT_BRIGHTNESS
			elseif sundialFlashOn then SD.MUZZLE_LIGHT_BRIGHTNESS
			elseif riftforgeFlashOn then RF.MUZZLE_LIGHT_BRIGHTNESS
			elseif riftforge and suppressed then 0.85
			elseif (moltframe or playback or sundial) and suppressed then 0.55
			elseif spectral then 2.4
			elseif puff then (if suppressed then 0 else 0.5)
			elseif config.fireInterval < 0.1 then 1.6
			else 2.4,
		smokeCount = if not styledSkin
				and (config.class == "Shotgun" or config.class == "Sniper")
			then 3
			else 1,
		heat = 0,
		lastShot = -math.huge,
	}
	rigs[muzzle] = rig
	muzzle.Destroying:Once(function()
		rigs[muzzle] = nil
	end)
	return rig
end

-- Flash at a gun's Muzzle attachment. `firstPerson`: our viewmodel (scaled to
-- the viewmodel). `smoke`: false skips the smoke (far away).
function MuzzleFx.flash(
	muzzle: Attachment,
	config: WeaponConfig,
	firstPerson: boolean,
	smoke: boolean?,
	spectral: Color3?,
	style: FlashStyle?
)
	local scale = if firstPerson
		then (config.viewmodelScale or ViewmodelConfig.SCALE) * FP_FLASH
		else 1
	local rig = rigs[muzzle] or buildRig(muzzle, config, scale, firstPerson, spectral, style)
	if not rig then
		return
	end
	if rig.darkFlame then
		rig.darkFlame:Emit(SettingsApply.vfxCount(1))
	end
	rig.front:Emit(1)
	if rig.forks then
		for _, flare in rig.forks do
			flare:Emit(1)
		end
	end
	if rig.core then
		rig.core:Emit(1)
	end
	if rig.side then
		rig.side:Emit(SettingsApply.vfxCount(1))
	end
	if rig.embers and math.random() < 0.6 then
		rig.embers:Emit(SettingsApply.vfxCount(math.random(1, 3)))
	end
	if smoke ~= false then
		rig.smoke:Emit(SettingsApply.vfxCount(rig.smokeCount))
		if not spectral then
			rig.heat = math.min(rig.heat + 1, HEAT_MAX)
		end
	end
	rig.lastShot = fxClock
	popLight(rig.light, rig.brightness)
end

-- Hot barrels smoke for a moment once the shooting stops.
local function stepWisps(dt: number)
	for _, rig in rigs do
		if rig.heat > 0 then
			rig.heat = math.max(0, rig.heat - HEAT_COOL * dt)
			local resting = fxClock - rig.lastShot > 0.12
			local amount = math.clamp((rig.heat - HEAT_WISP) / (HEAT_MAX - HEAT_WISP), 0, 1)
			rig.wisp.Rate = if resting then 4 + 18 * amount else 0
			if rig.heat <= HEAT_WISP * 0.5 then
				rig.wisp.Rate = 0
			end
		end
	end
end

-- Every frame, with `dt` already scaled by the effects time scale: advances
-- the effects clock, cools barrels and fades the light pops.
function MuzzleFx.step(dt: number)
	fxClock += dt
	stepWisps(dt)
	stepLights(fxClock)
end

return MuzzleFx
