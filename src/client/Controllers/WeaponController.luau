--!strict
-- Client side of the weapon system. Reads input, fires instantly for feel
-- (spread, recoil, effects, predicted hit marker) and sends what it saw to
-- the server, which re-checks everything and applies damage. Ammo and
-- loadout are mirrored from the server's WeaponState.
--
-- Fire modes mirror WeaponService.onFire: Semi/Pump/Bolt (one per press),
-- Auto, Burst (one press = burst.count shots), Charge, Melee, Projectile
-- (the server flies the disc; we only send the direction) and Beam (held,
-- one "shot" per tick, battery instead of a magazine).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Audio = require(Shared.Config.Audio)
local Combat = require(Shared.Config.Combat)
local Dev = require(Shared.Config.Dev)
local FireRate = require(Shared.Util.FireRate)
local Net = require(Shared.Net)
local Sounds = require(Shared.Config.Sounds)
local Spread = require(Shared.Util.Spread)
local Types = require(Shared.Types)
local VM = require(Shared.Config.Viewmodel)
local Weapons = require(Shared.Config.Weapons)

local AudioController = require(script.Parent.AudioController)
local CameraController = require(script.Parent.CameraController)
local EffectsController = require(script.Parent.EffectsController)
local HudController = require(script.Parent.HudController)
local InputController = require(script.Parent.InputController)
local MovementController = require(script.Parent.MovementController)
local ViewmodelController = require(script.Parent.ViewmodelController)

type Slot = Types.Slot
type WeaponConfig = Types.WeaponConfig

type LocalSlot = {
	id: string,
	config: WeaponConfig,
	ammo: number, -- beam guns: battery in ticks (fractional while recharging)
	lastFire: number,
	spinStart: number?,
	burstShots: number, -- same counter as the server's (FireRate.nextBurstCount)
	rechargeFrom: number, -- beam battery: recharge counted from here
}

type Reload = { start: number, duration: number, token: number }

local WeaponController = {}

local player = Players.LocalPlayer

local slots: { [Slot]: LocalSlot } = {}
local equipped: Slot? = nil
local equipReadyAt = 0
local reloading: Reload? = nil
local reloadToken = 0
local triggerHeld = false
local pressQueued = false
local chargeStart: number? = nil
local burstQueue = 0 -- shots left in the current burst
local nextLeft = false -- Dual Boot: the next shot comes from the left gun
local beamOn = false
local aiming = false
local adsAlpha = 0
local bloom = 0
local lastShotAt = 0
local lastAimSent = 0
local lastPitchSent = 0
local lastAimingSent = false
local alive = false
-- Spread seeds come from the server's sequence (see Util/Spread.seedFor).
local seedBase = 0
local shotIndex = 0

local CYCLE: { Slot } = { "Primary", "Secondary", "Melee" }

-- Helpers ------------------------------------------------------------------

local function current(): LocalSlot?
	return if equipped then slots[equipped] else nil
end

local function combatantOf(part: Instance): Model?
	local node: Instance? = part.Parent
	while node and node ~= Workspace do
		if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function aliveHumanoid(model: Model): boolean
	local h = model:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0
end

local function rayParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	if player.Character then
		table.insert(exclude, player.Character)
	end
	local cam = Workspace.CurrentCamera
	if cam then
		table.insert(exclude, cam)
	end
	local fx = Workspace:FindFirstChild("Effects")
	if fx then
		table.insert(exclude, fx)
	end
	params.FilterDescendantsInstances = exclude
	return params
end

local function ease(t: number): number
	return t * t * (3 - 2 * t)
end

-- The server clamps the claimed spread to this range (WeaponService.onFire);
-- staying inside it keeps both sides' pellet rays identical.
local function spreadLimits(config: WeaponConfig): (number, number)
	local low = config.hipSpread * config.adsSpreadMultiplier * (config.crouchSpreadMultiplier or 1)
	local high = config.hipSpread
		+ config.maxBloom
		+ Combat.MOVE_SPREAD.Air * (config.moveSpreadMultiplier or 1)
	return low, high
end

local function currentSpread(config: WeaponConfig): number
	if config.beam then
		return 0
	end
	local move = MovementController.getState()
	local extra = ((Combat.MOVE_SPREAD :: any)[move] or 0) * (config.moveSpreadMultiplier or 1)
	local hip = config.hipSpread
	if move == "Crouch" then
		hip *= config.crouchSpreadMultiplier or 1
	end
	local adsMult = 1 + (config.adsSpreadMultiplier - 1) * ease(adsAlpha)
	local low, high = spreadLimits(config)
	return math.clamp((hip + extra + bloom) * adsMult, low, high)
end

-- Same as the server's rechargeBeam: the battery refills after a pause.
local function rechargeBeam(s: LocalSlot, now: number)
	local beam = s.config.beam
	if not beam then
		return
	end
	local from = math.max(s.lastFire + beam.rechargeDelay, s.rechargeFrom)
	if now > from then
		s.ammo = math.min(s.config.magSize, s.ammo + (now - from) * beam.rechargeRate / beam.tick)
		s.rechargeFrom = now
	end
end

local function playLocal(id: string?, group: AudioController.Group, volume: number, pitch: number?)
	AudioController.play(id, { group = group, volume = volume, pitch = pitch })
end

local function updateHudWeapon()
	local s = current()
	if s then
		HudController.setWeapon(
			s.config.displayName,
			math.floor(s.ammo),
			s.config.magSize,
			s.config.beam ~= nil
		)
	end
end

-- Reload ---------------------------------------------------------------------

local function cancelReload()
	if reloading then
		reloading = nil
		reloadToken += 1
		ViewmodelController.cancelReload()
		HudController.setReload(nil)
	end
end

local function startReload()
	local s = current()
	if not s or reloading or not alive then
		return
	end
	local config = s.config
	-- Beam guns have a self-charging battery, no reload.
	if config.magSize <= 0 or config.beam or s.ammo >= config.magSize then
		return
	end
	chargeStart = nil
	burstQueue = 0
	local duration = if s.ammo == 0 then config.emptyReloadTime else config.reloadTime
	reloadToken += 1
	local token = reloadToken
	reloading = { start = os.clock(), duration = duration, token = token }
	Net.event("Reload"):FireServer()
	ViewmodelController.reload(duration)
	-- Reload foley timed to the animation.
	task.delay(duration * 0.2, function()
		if reloadToken == token then
			playLocal(Sounds.MagOut, "Foley", Audio.FOLEY_VOLUME)
		end
	end)
	task.delay(duration * 0.65, function()
		if reloadToken == token then
			playLocal(config.sounds.reload or Sounds.MagIn, "Foley", Audio.FOLEY_VOLUME)
		end
	end)
	if s.ammo == 0 then
		task.delay(duration * 0.88, function()
			if reloadToken == token then
				playLocal(config.sounds.cycle or Sounds.Rack, "Foley", Audio.FOLEY_VOLUME)
			end
		end)
	end
end

-- Equip ----------------------------------------------------------------------

local function applyEquip(slot: Slot)
	local s = slots[slot]
	if not s then
		return
	end
	cancelReload()
	equipped = slot
	chargeStart = nil
	pressQueued = false
	burstQueue = 0
	nextLeft = false
	bloom = 0
	equipReadyAt = os.clock() + s.config.equipTime
	ViewmodelController.equip(s.config)
	updateHudWeapon()
	playLocal(s.config.sounds.equip, "Foley", Audio.FOLEY_VOLUME)
end

local function equip(slot: Slot)
	if not alive or equipped == slot or not slots[slot] then
		return
	end
	applyEquip(slot)
	Net.event("Equip"):FireServer(slot)
end

-- Firing ---------------------------------------------------------------------

-- Bullet-hole size for a gun's impacts (pellets leave small ones).
local function holeSize(config: WeaponConfig): number
	if config.beam then
		return 0.8
	elseif config.pellets > 1 then
		return 0.65
	elseif config.class == "Sniper" then
		return 1.3
	end
	return 1
end

type Cast = {
	hits: { { part: BasePart, position: Vector3 } },
	finish: Vector3,
	impact: { position: Vector3, normal: Vector3, part: BasePart, material: Enum.Material }?,
}

local function cast(
	origin: Vector3,
	dir: Vector3,
	config: WeaponConfig,
	params: RaycastParams
): Cast
	local out: Cast = { hits = {}, finish = origin + dir * config.range, impact = nil }
	local from = origin
	local remaining = config.range
	for _ = 1, 8 do
		local result = Workspace:Raycast(from, dir * remaining, params)
		if not result then
			return out
		end
		local part = result.Instance
		local model = combatantOf(part)
		if model then
			if aliveHumanoid(model) and part:IsA("BasePart") then
				table.insert(out.hits, { part = part, position = result.Position })
				if not config.pierceCharacters then
					out.finish = result.Position
					return out
				end
			end
			params:AddToFilter(model)
		else
			local passThrough = config.penetration == "All"
				or (
					config.penetration == "ThinWall"
					and CollectionService:HasTag(part, Combat.THIN_WALL_TAG)
				)
			if not passThrough then
				out.finish = result.Position
				out.impact = {
					position = result.Position,
					normal = result.Normal,
					part = part,
					material = result.Material,
				}
				return out
			end
			EffectsController.impact(
				result.Position,
				result.Normal,
				config.tracerColor,
				part,
				result.Material,
				holeSize(config)
			)
			params:AddToFilter(part)
		end
		remaining -= (result.Position - from).Magnitude
		from = result.Position
		if remaining <= 0 then
			return out
		end
	end
	return out
end

local function dryFire()
	playLocal(Sounds.DryFire, "Foley", Audio.FOLEY_VOLUME)
end

local function fireShot(s: LocalSlot)
	local config = s.config
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local now = os.clock()
	local interval = FireRate.interval(config, s.spinStart, s.lastFire, now, s.burstShots)
	if now < s.lastFire + interval then
		return
	end
	if not s.spinStart or now - s.lastFire > FireRate.SPIN_RESET then
		s.spinStart = now
	end
	s.burstShots = FireRate.nextBurstCount(config, s.burstShots, s.lastFire, now)
	s.lastFire = math.max(now, s.lastFire + interval)
	if config.magSize > 0 then
		s.ammo -= 1
	end

	local spread = currentSpread(config)
	bloom = math.min(bloom + config.bloomPerShot, config.maxBloom)
	lastShotAt = now

	local origin = cam.CFrame.Position
	local aim = cam.CFrame.LookVector
	shotIndex += 1
	local seed = Spread.seedFor(seedBase, shotIndex)
	local dirs = Spread.shot(aim, seed, config.pellets, spread, config.pelletSpread)

	-- Dual Boot alternates between its two guns.
	local side: ViewmodelController.Side = "Right"
	if config.models and config.models.left then
		side = if nextLeft then "Left" else "Right"
		nextLeft = not nextLeft
	end
	local muzzle = ViewmodelController.muzzleCFrame(side)
	local from = if muzzle then muzzle.Position else origin

	local hits = {}
	local ends = {}
	local predictedHit = false
	local predictedHead = false
	if config.projectile then
		-- The server flies the disc and applies its damage; `ends` only tells
		-- other clients which way it went.
		table.insert(ends, origin + dirs[1])
		EffectsController.disc(player.Character, origin, dirs[1], config, from)
	else
		local params = rayParams()
		for i, dir in dirs do
			local result = cast(origin, dir, config, params)
			for _, h in result.hits do
				table.insert(hits, { part = h.part, position = h.position, pellet = i })
				predictedHit = true
				if h.part.Name == "Head" then
					predictedHead = true
				end
				EffectsController.impact(h.position, -dir, config.tracerColor, h.part)
			end
			table.insert(ends, result.finish)
			if result.impact then
				EffectsController.impact(
					result.impact.position,
					result.impact.normal,
					config.tracerColor,
					result.impact.part,
					result.impact.material,
					holeSize(config)
				)
			end
			if config.beam then
				continue -- drawn every frame in update()
			elseif config.fireMode == "Charge" then
				EffectsController.beam(from, result.finish, config.tracerColor)
			elseif not config.suppressed then
				EffectsController.tracer(from, result.finish, config.tracerColor)
			end
		end
	end

	Net.event("Fire"):FireServer({
		origin = origin,
		direction = aim,
		shot = shotIndex,
		spread = spread,
		hits = hits,
		ends = ends,
	})

	-- Feel. The beam's light and sound are continuous (update()).
	if not config.beam then
		EffectsController.localShot(config, side)
		playLocal(
			config.sounds.fire,
			"Gun",
			Audio.SHOT_VOLUME * (config.sounds.fireVolume or 1),
			config.sounds.firePitch
		)
		-- A hollow tick from a near-empty mag, louder as it runs dry.
		local mag = config.magSize
		local low = math.ceil(mag * Audio.LOW_AMMO_FRACTION)
		if mag >= Audio.LOW_AMMO_MIN_MAG and s.ammo > 0 and s.ammo <= low then
			playLocal(Sounds.LowAmmo, "Foley", Audio.LOW_AMMO_VOLUME * (1.4 - 0.4 * s.ammo / low))
		end
		-- Pump and bolt guns work the action after every shot.
		local cycle = config.sounds.cycle
		if cycle and (config.fireMode == "Pump" or config.fireMode == "Bolt") and s.ammo > 0 then
			task.delay(config.fireInterval * Audio.CYCLE_DELAY, function()
				if current() == s and alive then
					playLocal(cycle, "Foley", Audio.FOLEY_VOLUME)
				end
			end)
		end
	end
	local adsKick = 1 - 0.35 * adsAlpha
	CameraController.kick(
		config.recoil.up * adsKick,
		(math.random() * 2 - 1) * config.recoil.side * adsKick,
		config.recoil.recover
	)
	CameraController.shake((0.04 + config.recoil.up * 0.1) * adsKick)
	ViewmodelController.fire((1 - 0.5 * adsAlpha) * (if config.beam then 0.25 else 1), side)
	if predictedHit then
		HudController.hitMarker(predictedHead)
	end
	updateHudWeapon()

	if config.magSize > 0 and s.ammo <= 0 and not config.beam then
		task.delay(0.25, function()
			local c = current()
			if c == s and s.ammo <= 0 then
				startReload()
			end
		end)
	end
end

local function swing(s: LocalSlot)
	local config = s.config
	local melee = config.melee
	local cam = Workspace.CurrentCamera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not melee or not cam or not root or not root:IsA("BasePart") then
		return
	end
	local now = os.clock()
	if now < s.lastFire + config.fireInterval then
		return
	end
	s.lastFire = now
	ViewmodelController.swing()
	playLocal(config.sounds.fire, "Gun", Audio.SHOT_VOLUME)

	local origin = cam.CFrame.Position
	local aim = cam.CFrame.LookVector
	local params = rayParams()
	local result = Workspace:Spherecast(origin, 1.3, aim * melee.range, params)
	local hits = {}
	if result and result.Instance:IsA("BasePart") then
		local model = combatantOf(result.Instance)
		if model and aliveHumanoid(model) then
			table.insert(hits, { part = result.Instance, position = result.Position, pellet = 1 })
			EffectsController.impact(result.Position, -aim, config.tracerColor, result.Instance)
			HudController.hitMarker(false)
			-- Lunge toward the target on hit.
			local flat = (aim * Vector3.new(1, 0, 1))
			if flat.Magnitude > 0.01 then
				root.AssemblyLinearVelocity = flat.Unit * (melee.lunge / 0.15)
					+ Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
			end
		end
	end
	shotIndex += 1
	Net.event("Fire"):FireServer({
		origin = origin,
		direction = aim,
		shot = shotIndex,
		spread = 0,
		hits = hits,
		ends = {},
	})
end

local function canShoot(s: LocalSlot): boolean
	if not alive or os.clock() < equipReadyAt or reloading or HudController.isDevMenuOpen() then
		return false
	end
	-- `< 1`: a beam battery is fractional while it recharges (server: ammo < 1).
	if s.config.magSize > 0 and s.ammo < 1 then
		return false
	end
	return true
end

local function onFirePressed()
	if HudController.isDevMenuOpen() then
		return
	end
	ViewmodelController.cancelInspect()
	triggerHeld = true
	pressQueued = true
	local s = current()
	if not s then
		return
	end
	if s.config.magSize > 0 and s.ammo < 1 and not reloading then
		dryFire()
		startReload()
		return
	end
	if s.config.fireMode == "Charge" and canShoot(s) then
		chargeStart = os.clock()
		Net.event("Charge"):FireServer()
		playLocal(s.config.sounds.charge, "Gun", Audio.SHOT_VOLUME * 0.8, Audio.CHARGE_PITCH)
	end
end

local function onFireReleased()
	triggerHeld = false
	local s = current()
	if s and s.config.fireMode == "Charge" and chargeStart then
		local held = os.clock() - chargeStart
		chargeStart = nil
		if held >= (s.config.chargeTime or 0) and canShoot(s) then
			fireShot(s)
		end
	end
end

-- Per frame --------------------------------------------------------------------

local function update(dt: number)
	local s = current()
	local now = os.clock()
	local cam = Workspace.CurrentCamera

	-- Bloom recovers once you stop firing.
	if now - lastShotAt > Combat.BLOOM_RECOVERY_DELAY then
		bloom = math.max(0, bloom - Combat.BLOOM_RECOVERY * dt)
	end

	-- Reload progress.
	local r = reloading
	if r and s then
		local t = (now - r.start) / r.duration
		if t >= 1 then
			s.ammo = s.config.magSize
			reloading = nil
			HudController.setReload(nil)
			updateHudWeapon()
		else
			HudController.setReload(t)
		end
	end

	-- Beam batteries recharge whether or not the gun is out.
	for _, slot in slots do
		if slot.config.beam then
			rechargeBeam(slot, now)
		end
	end
	if s and s.config.beam then
		updateHudWeapon()
	end

	-- Aim down sights.
	local menuOpen = HudController.isDevMenuOpen()
	CameraController.setCursorVisible(menuOpen)
	local aimingWanted = s ~= nil
		and alive
		and not menuOpen
		and s.config.fireMode ~= "Melee"
		and not s.config.noAds
		and InputController.isDown("Aim")
		and not MovementController.isSprinting()
	aiming = aimingWanted
	if s then
		local rate = 1 / math.max(s.config.adsTime, 0.05)
		adsAlpha = math.clamp(adsAlpha + (if aimingWanted then rate else -rate) * dt, 0, 1)
	else
		adsAlpha = 0
	end
	ViewmodelController.setAds(adsAlpha)
	CameraController.setZoom(if s then s.config.adsFov else nil, ease(adsAlpha))
	local scoped = s ~= nil and s.config.scope == true and adsAlpha > 0.9
	ViewmodelController.setHidden(scoped)
	HudController.setScope(scoped)
	HudController.setCrosshairVisible(
		not scoped and adsAlpha < 0.5 and not MovementController.isSprinting()
	)

	-- Trigger.
	if s and alive then
		HudController.setSpread(currentSpread(s.config) + s.config.pelletSpread * 0.6)
		local mode = s.config.fireMode
		if mode == "Melee" then
			if pressQueued and now >= equipReadyAt then
				pressQueued = false
				swing(s)
			end
		elseif mode == "Auto" or mode == "Beam" then
			if triggerHeld and canShoot(s) then
				fireShot(s)
			end
		elseif mode == "Burst" then
			local burst = s.config.burst :: Types.BurstStats
			-- A new burst needs the full gap since the last shot, which also
			-- resets the server's burst counter (FireRate.nextBurstCount).
			if
				burstQueue == 0
				and pressQueued
				and canShoot(s)
				and now >= s.lastFire + s.config.fireInterval
			then
				pressQueued = false
				-- Pulse fires single shots while aiming.
				burstQueue = if burst.singleWhenAiming and aiming then 1 else burst.count
			end
			if burstQueue > 0 then
				if not canShoot(s) then
					burstQueue = 0
				else
					local before = s.lastFire
					fireShot(s)
					if s.lastFire ~= before then
						burstQueue -= 1
					end
				end
			end
		elseif mode ~= "Charge" then
			if pressQueued and canShoot(s) then
				local interval = FireRate.interval(s.config, s.spinStart, s.lastFire, now)
				if now >= s.lastFire + interval then
					pressQueued = false
					fireShot(s)
				end
			end
		end
		-- A queued press only counts for a short moment.
		if pressQueued and not triggerHeld and now - lastShotAt > 0.2 and mode ~= "Melee" then
			pressQueued = false
		end
	end

	-- Ray Trace: energy gathers at the muzzle while it charges.
	if chargeStart and s and alive and s.config.fireMode == "Charge" then
		local held = now - chargeStart
		EffectsController.charge(
			ViewmodelController.muzzleCFrame(),
			held / math.max(s.config.chargeTime or 0, 0.05),
			s.config.tracerColor,
			s.config.viewmodelScale or VM.SCALE
		)
	else
		EffectsController.charge(nil, 0, Color3.new())
	end

	-- Null: a continuous beam from the muzzle to whatever the crosshair is on
	-- while it's firing (the damage itself comes from the ticks above).
	local wantBeam = s ~= nil
		and alive
		and s.config.beam ~= nil
		and triggerHeld
		and canShoot(s)
		and now - s.lastFire < s.config.fireInterval * 2
	if wantBeam and s and cam then
		local result = Workspace:Raycast(
			cam.CFrame.Position,
			cam.CFrame.LookVector * s.config.range,
			rayParams()
		)
		local finish = if result
			then result.Position
			else cam.CFrame.Position + cam.CFrame.LookVector * s.config.range
		local muzzle = ViewmodelController.muzzleCFrame()
		EffectsController.setBeam(
			"local",
			if muzzle then muzzle.Position else cam.CFrame.Position,
			finish,
			s.config,
			true
		)
		beamOn = true
	elseif beamOn then
		beamOn = false
		EffectsController.stopBeam("local")
	end

	-- Hide our own third-person gun(s) in first person.
	local character = player.Character
	if character then
		for _, name in { "WorldWeapon", "WorldWeaponLeft" } do
			local world = character:FindFirstChild(name)
			if world then
				for _, d in world:GetDescendants() do
					if d:IsA("BasePart") then
						d.LocalTransparencyModifier = 1
					end
				end
			end
		end
	end

	-- Tell the server where we're aiming (third-person pose for others).
	if cam and now - lastAimSent > 0.1 then
		local pitch = math.asin(math.clamp(cam.CFrame.LookVector.Y, -1, 1))
		if math.abs(pitch - lastPitchSent) > 0.03 or aimingWanted ~= lastAimingSent then
			lastAimSent = now
			lastPitchSent = pitch
			lastAimingSent = aimingWanted
			Net.unreliable("Aim"):FireServer(pitch, aimingWanted)
		end
	end
end

-- Server state ---------------------------------------------------------------

local function onWeaponState(state: Types.WeaponState)
	if typeof(state) ~= "table" or typeof(state.slots) ~= "table" then
		return
	end
	if typeof(state.seedBase) == "number" then
		seedBase = state.seedBase
	end
	if typeof(state.shotIndex) == "number" and state.shotIndex > shotIndex then
		shotIndex = state.shotIndex
	end
	local changedEquip = false
	for _, slot in CYCLE do
		local incoming = state.slots[slot]
		if incoming then
			local config = Weapons.get(incoming.id)
			if config then
				local existing = slots[slot]
				if not existing or existing.id ~= incoming.id then
					slots[slot] = {
						id = incoming.id,
						config = config,
						ammo = incoming.ammo,
						lastFire = -math.huge,
						spinStart = nil,
						burstShots = 0,
						rechargeFrom = 0,
					}
					if equipped == slot then
						changedEquip = true
					end
				elseif not (reloading and equipped == slot) and not config.beam then
					-- (A beam battery recharges here; the server's copy only
					-- catches up when it next fires, so keep ours.)
					existing.ammo = incoming.ammo
				end
			end
		end
	end
	if state.equipped and (state.equipped ~= equipped or changedEquip) then
		applyEquip(state.equipped)
	end
	updateHudWeapon()
end

local function onHitConfirm(confirm: Types.HitConfirm)
	if typeof(confirm) ~= "table" then
		return
	end
	local head = confirm.zone == "Head"
	HudController.hitMarker(head)
	HudController.damageNumber(
		confirm.damage,
		head,
		if typeof(confirm.position) == "Vector3" then confirm.position else nil,
		confirm.killed == true
	)
	if confirm.killed then
		HudController.killMarker()
		playLocal(if head then Sounds.KillHead else Sounds.Kill, "Feedback", Audio.KILL_VOLUME)
	elseif head then
		playLocal(Sounds.HitHead, "Feedback", Audio.HEAD_VOLUME)
	else
		playLocal(Sounds.HitBody, "Feedback", Audio.HIT_VOLUME)
	end
end

-- The server sends a fresh WeaponState for every new character, so the
-- loadout is rebuilt from that; here we only track life and death.
local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	alive = true
	humanoid.Died:Connect(function()
		alive = false
		triggerHeld = false
		chargeStart = nil
		burstQueue = 0
		cancelReload()
		equipped = nil
		table.clear(slots)
		ViewmodelController.unequip()
		HudController.setScope(false)
		CameraController.setZoom(nil, 0)
	end)
end

function WeaponController.start()
	InputController.onPressed("Fire", onFirePressed)
	InputController.onReleased("Fire", onFireReleased)
	InputController.onPressed("Reload", startReload)
	InputController.onPressed("Inspect", function()
		-- Fire, aim, reload and swapping cancel it (ViewmodelController).
		if alive and current() and not reloading and not HudController.isDevMenuOpen() then
			ViewmodelController.inspect()
		end
	end)
	InputController.onPressed("Primary", function()
		equip("Primary")
	end)
	InputController.onPressed("Secondary", function()
		equip("Secondary")
	end)
	InputController.onPressed("Melee", function()
		equip("Melee")
	end)
	InputController.onPressed("QuickMelee", function()
		equip("Melee")
		pressQueued = true
	end)
	InputController.onPressed("CycleWeapon", function()
		local index = table.find(CYCLE, equipped or "Primary") or 0
		equip(CYCLE[index % #CYCLE + 1])
	end)
	if RunService:IsStudio() and Dev.WEAPON_PICKER then
		-- Weapon menu: the server swaps the gun into its slot (Dev remote,
		-- Studio-gated there too) and we switch to that slot.
		HudController.onDevPick(function(id: string)
			local config = Weapons.get(id)
			if not config then
				return
			end
			Net.event("Dev"):FireServer(id)
			equip(config.slot)
		end)
		InputController.onPressed("DevMenu", function()
			local held: { [string]: boolean } = {}
			for _, slot in slots do
				held[slot.id] = true
			end
			HudController.toggleDevMenu(held)
			triggerHeld = false
			pressQueued = false
			burstQueue = 0
		end)
		InputController.onPressed("DevNextPrimary", function()
			Net.event("Dev"):FireServer("Primary")
		end)
		InputController.onPressed("DevNextSecondary", function()
			Net.event("Dev"):FireServer("Secondary")
		end)
	end

	Net.event("WeaponState").OnClientEvent:Connect(onWeaponState)
	Net.event("HitConfirm").OnClientEvent:Connect(onHitConfirm)

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	RunService:BindToRenderStep("GGWeapons", Enum.RenderPriority.Input.Value + 1, update)
end

return WeaponController
