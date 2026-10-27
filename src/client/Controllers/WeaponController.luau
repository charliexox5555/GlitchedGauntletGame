--!strict
-- Client side of the weapon system. Reads input, fires instantly for feel
-- (spread, recoil, effects, predicted hit marker) and sends what it saw to
-- the server, which re-checks everything and applies damage. Ammo and
-- loadout are mirrored from the server's WeaponState.
--
-- Fire modes mirror WeaponService.onFire: Semi/Pump/Bolt (one per press),
-- Auto, Burst (one press = burst.count shots) and Melee.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Accuracy = require(Shared.Util.Accuracy)
local Audio = require(Shared.Config.Audio)
local Combat = require(Shared.Config.Combat)
local GunSounds = require(Shared.Config.GunSounds)
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
local PickerController = require(script.Parent.PickerController)
local ViewmodelController = require(script.Parent.ViewmodelController)

type Slot = Types.Slot
type WeaponConfig = Types.WeaponConfig

type LocalSlot = {
	id: string,
	config: WeaponConfig,
	ammo: number,
	lastFire: number,
	spinStart: number?,
	burstShots: number, -- same counter as the server's (FireRate.nextBurstCount)
	heat: number, -- spray heat after the last shot (Util/Accuracy), as the server counts it
	lastShotAt: number,
	-- Recoil pattern (Config/Weapons recoil): shots in this spray, the side
	-- the climb drifts to, and when it last swapped.
	sprayShots: number,
	sideDir: number,
	lastSwitch: number,
	altReadyAt: number, -- alt-fire's cooldown (as WeaponService counts it)
}

-- A shell-by-shell reload's progress (config shellReload): Start into the
-- loading pose, one Insert per shell, then End back to the hold.
type ShellPhase = "Start" | "Insert" | "End"
type ShellState = {
	phase: ShellPhase,
	doneAt: number,
	inserted: number,
	needed: number,
	wasEmpty: boolean,
}

type Reload = { start: number, duration: number, token: number, shell: ShellState? }

local WeaponController = {}

local player = Players.LocalPlayer

local slots: { [Slot]: LocalSlot } = {}
local equipped: Slot? = nil
local equipReadyAt = 0
local reloading: Reload? = nil
local reloadToken = 0
local triggerHeld = false
local pressQueued = false
local pressHoldUntil = -math.huge -- a queued press waits at least until this (a stopped shell reload)
local altQueuedAt = -math.huge -- alt-fire press (Aim input on a gun with altFire)
local burstQueue = 0 -- shots left in the current burst
local nextLeft = false -- akimbo: the next shot comes from the left gun
local aiming = false
local devAim = false -- Studio only: Workspace DevAim holds ADS for scripted reviews
local adsAlpha = 0
local scoped = false -- a scoped gun aimed past Viewmodel.SCOPE_AT: the scope overlay is up
local lastShotAt = 0
local lastAimSent = 0
local lastPitchSent = 0
local lastAimingSent = false
local alive = false
-- Spread seeds come from the server's sequence (see Util/Spread.seedFor).
local seedBase = 0
local shotIndex = 0
-- Why the gun is lowered and can't fire (a held Mod: ModController). The
-- server refuses shots while a Mod is held too (WeaponService.setHolstered).
local holstered: { [string]: boolean } = {}
local UNHOLSTER_TIME = 0.25 -- the gun comes back up before it can fire

local CYCLE: { Slot } = { "Primary", "Secondary", "Melee" }

-- Helpers ------------------------------------------------------------------

local function current(): LocalSlot?
	return if equipped then slots[equipped] else nil
end

local function isHolstered(): boolean
	return next(holstered) ~= nil
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

-- What we're doing right now, for the spread (the server recomputes the same
-- from its own simulation: WeaponService spreadBand).
local landedAt = -math.huge -- os.clock() of our last landing (update() spots it)
local lastMoveState = "Idle"

local function motionNow(): Accuracy.Motion
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return {
		state = MovementController.getState(),
		speed = if root and root:IsA("BasePart")
			then (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
			else 0,
		aim = adsAlpha,
		sinceLanding = os.clock() - landedAt,
	}
end

-- Gunplay v2 spread for the next shot: the gun's cone at its cooled spray
-- heat plus the movement penalty, and whether it's centre-biased.
local function currentSpread(s: LocalSlot): (number, boolean)
	local heat = Accuracy.cool(s.config, s.heat, os.clock() - s.lastShotAt)
	return Accuracy.cone(s.config, heat, motionNow())
end

-- Camera recoil for one shot, following the gun's pattern: pure vertical for
-- the protected shots, then a smaller climb drifting to one side, now and
-- then swapping sides.
local function kickRecoil(s: LocalSlot, sinceLast: number, now: number)
	local r = s.config.recoil
	if sinceLast > r.recoverTime + s.config.fireInterval then
		s.sprayShots = 0
		s.sideDir = if math.random() < 0.5 then -1 else 1
		s.lastSwitch = now
	end
	s.sprayShots += 1
	local up, side = r.up, 0
	if s.sprayShots > r.protected then
		if now - s.lastSwitch >= r.switchMinTime and math.random() < r.switchChance then
			s.sideDir = -s.sideDir
			s.lastSwitch = now
		end
		up = r.upAfter
		side = r.side * s.sideDir
		if MovementController.getState() == "Crouch" then
			side *= Combat.CROUCH_SIDE_RECOIL
		end
	end
	CameraController.kick(up, side, r.recover, r.recoverTime)
end

local function playLocal(id: string?, group: AudioController.Group, volume: number, pitch: number?)
	AudioController.play(id, { group = group, volume = volume, pitch = pitch })
end

-- A sound from the gun's Config/GunSounds entry, played on our side (2D).
local function playGun(config: WeaponConfig, name: string, group: AudioController.Group?)
	local set = GunSounds.get(config.id) :: any
	AudioController.playSound(set[name], group or "Foley")
end

-- Clip beats (ViewmodelController clipBeats) to GunSounds names.
local BEAT_SOUNDS: { [string]: string } =
	{ MagOut = "magOut", MagIn = "magIn", Rack = "rack", Open = "open", ShellIn = "shellIn" }

local function updateHudWeapon()
	local s = current()
	if s then
		HudController.setWeapon(s.config.displayName, math.floor(s.ammo), s.config.magSize)
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

-- Plays one clip of a shell-by-shell reload with its foley.
local function playShellClip(config: WeaponConfig, clip: string, duration: number)
	local token = reloadToken
	for _, beat in ViewmodelController.playClip(clip, duration) do
		task.delay(duration * beat.at, function()
			if reloadToken == token then
				playGun(config, BEAT_SOUNDS[beat.sound])
			end
		end)
	end
end

local function startShellReload(s: LocalSlot)
	local shell = s.config.shellReload :: Types.ShellReload
	local needed = s.config.magSize - s.ammo
	reloadToken += 1
	reloading = {
		start = os.clock(),
		duration = shell.start + shell.insert * needed + shell.finish,
		token = reloadToken,
		shell = {
			phase = "Start",
			doneAt = os.clock() + shell.start,
			inserted = 0,
			needed = needed,
			wasEmpty = s.ammo == 0,
		},
	}
	Net.event("Reload"):FireServer()
	playShellClip(s.config, "ReloadStart", shell.start)
end

-- Steps a shell-by-shell reload: each finished insert puts a shell in the
-- gun (the server counts the same way, from when the reload started).
local function stepShellReload(s: LocalSlot, r: Reload, now: number)
	local st = r.shell :: ShellState
	local shell = s.config.shellReload :: Types.ShellReload
	if now < st.doneAt then
		return
	end
	if st.phase == "Insert" then
		st.inserted += 1
		s.ammo = math.min(s.ammo + 1, s.config.magSize)
		updateHudWeapon()
	end
	if st.phase ~= "End" and st.inserted < st.needed then
		st.phase = "Insert"
		st.doneAt = now + shell.insert
		playShellClip(s.config, "ReloadInsert", shell.insert)
	elseif st.phase ~= "End" then
		st.phase = "End"
		st.doneAt = now + shell.finish
		playShellClip(s.config, "ReloadEnd", shell.finish)
		if st.wasEmpty then
			playGun(s.config, "rack") -- chamber a round
		end
	else
		reloading = nil
		HudController.setReload(nil)
	end
end

-- The trigger was pulled mid shell-by-shell reload: keep what's loaded and
-- bring the gun back to the hands (the shot follows once it's there).
local function stopShellReload(s: LocalSlot, r: Reload, now: number)
	local st = r.shell :: ShellState
	local shell = s.config.shellReload :: Types.ShellReload
	if st.phase == "End" then
		return
	end
	reloadToken += 1
	r.token = reloadToken
	st.phase = "End"
	st.doneAt = now + shell.finish
	pressHoldUntil = st.doneAt
	Net.event("Reload"):FireServer("stop")
	playShellClip(s.config, "ReloadEnd", shell.finish)
end

local function startReload()
	local s = current()
	if not s or reloading or not alive or isHolstered() then
		return
	end
	local config = s.config
	if config.magSize <= 0 or s.ammo >= config.magSize then
		return
	end
	burstQueue = 0
	if config.shellReload then
		startShellReload(s)
		return
	end
	local empty = s.ammo == 0
	local duration = if empty then config.emptyReloadTime else config.reloadTime
	reloadToken += 1
	local token = reloadToken
	reloading = { start = os.clock(), duration = duration, token = token }
	Net.event("Reload"):FireServer()
	-- Foley (Config/GunSounds) lands on the clip's own beats.
	for _, beat in ViewmodelController.reload(duration, empty) do
		task.delay(duration * beat.at, function()
			if reloadToken == token then
				playGun(config, BEAT_SOUNDS[beat.sound])
			end
		end)
	end
end

-- Fire, aim, reload and swapping cancel it (ViewmodelController).
local function inspect()
	local s = current()
	if alive and s and not reloading and os.clock() >= equipReadyAt and not isHolstered() then
		if ViewmodelController.inspect() then
			playGun(s.config, "inspect")
		end
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
	pressQueued = false
	burstQueue = 0
	nextLeft = false
	-- Every equip plays the full draw (Valorant): raise and rack the action.
	local config = s.config
	local duration = config.drawTime or config.equipTime
	equipReadyAt = os.clock() + duration
	updateHudWeapon()
	playGun(config, "draw")
	local token = reloadToken
	for _, beat in ViewmodelController.equip(config, duration) do
		task.delay(duration * beat.at, function()
			if reloadToken == token and current() == s then
				playGun(config, BEAT_SOUNDS[beat.sound])
			end
		end)
	end
end

-- Returns whether `slot` is now the equipped one.
local function equip(slot: Slot): boolean
	if not alive or not slots[slot] then
		return false
	end
	if equipped ~= slot then
		applyEquip(slot)
		Net.event("Equip"):FireServer(slot)
	end
	return true
end

-- Firing ---------------------------------------------------------------------

-- Bullet-hole size for a gun's impacts (pellets leave small ones).
local function holeSize(config: WeaponConfig): number
	if config.pellets > 1 then
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
				-- A Mod object (Firewall, Launch Pad) takes the hit: report it.
				if part:GetAttribute("MaxHp") ~= nil and part:IsA("BasePart") then
					table.insert(out.hits, { part = part, position = result.Position })
				end
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
	local s = current()
	if s then
		playGun(s.config, "dryFire")
		ViewmodelController.dryFire()
	end
end

-- A scope's FOV: `zoom`x magnification of the player's own FOV.
local function scopeFov(zoom: number): number
	local base = CameraController.getBaseFov()
	return 2 * math.deg(math.atan(math.tan(math.rad(base / 2)) / math.max(zoom, 1)))
end

-- Scoped in, the gun and arms hide behind the HUD scope overlay (set every
-- frame: a new gun's viewmodel starts shown).
local function setScoped(value: boolean)
	ViewmodelController.setHidden(value)
	if scoped ~= value then
		scoped = value
		HudController.setScope(value)
	end
end

-- `alt`: the gun's alt-fire (Config/Weapons altFire), if it has one.
local function fireShot(s: LocalSlot, alt: boolean?)
	local config = s.config
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local altFire = if alt and config.noAds then config.altFire else nil
	-- Same rule as the server: one pellet per round the alt shot uses.
	local altRounds = if altFire
		then (if config.magSize > 0 then math.min(altFire.ammo, s.ammo) else altFire.ammo)
		else 1
	local pellets = if altFire
		then math.max(1, math.floor(altFire.pellets * altRounds / altFire.ammo))
		else config.pellets
	local pelletSpread = if altFire then altFire.pelletSpread else config.pelletSpread
	local now = os.clock()
	local interval = FireRate.interval(config, s.spinStart, s.lastFire, now, s.burstShots)
		/ FireRate.boost(player)
	if now < s.lastFire + interval or now < s.altReadyAt then
		return
	end
	if not s.spinStart or now - s.lastFire > FireRate.SPIN_RESET then
		s.spinStart = now
	end
	s.burstShots = FireRate.nextBurstCount(config, s.burstShots, s.lastFire, now)
	s.lastFire = math.max(now, s.lastFire + interval)
	if config.magSize > 0 then
		s.ammo -= altRounds
	end
	if altFire then
		s.altReadyAt = now + altFire.fireInterval
	end

	local spread, centred = currentSpread(s)
	local sinceLast = now - s.lastShotAt
	s.heat = Accuracy.cool(config, s.heat, sinceLast) + altRounds
	s.lastShotAt = now
	lastShotAt = now

	local origin = cam.CFrame.Position
	local aim = cam.CFrame.LookVector
	shotIndex += 1
	local seed = Spread.seedFor(seedBase, shotIndex)
	local dirs = Spread.shot(aim, seed, pellets, spread, pelletSpread, centred)

	-- Akimbo guns alternate between their two guns.
	local side: ViewmodelController.Side = "Right"
	if config.models and config.models.left then
		side = if nextLeft then "Left" else "Right"
		nextLeft = not nextLeft
	end
	-- Several muzzles (a double barrel) fire in turn through the mag.
	local muzzleName: string? = nil
	local muzzles = config.muzzles
	if muzzles and #muzzles > 0 and config.magSize > 0 then
		local fired = math.max(config.magSize - (s.ammo + altRounds), 0)
		muzzleName = muzzles[fired % #muzzles + 1]
	end
	local muzzle = ViewmodelController.muzzleCFrame(side, muzzleName)
	local from = if muzzle then muzzle.Position else origin

	local hits = {}
	local ends = {}
	local predictedHit = false
	local predictedHead = false
	local params = rayParams()
	for i, dir in dirs do
		local result = cast(origin, dir, config, params)
		for _, h in result.hits do
			table.insert(hits, { part = h.part, position = h.position, pellet = i })
			predictedHit = true
			if h.part.Name == "Head" then
				predictedHead = true
			end
			EffectsController.impact(h.position, -dir, h.part)
		end
		table.insert(ends, result.finish)
		if result.impact then
			EffectsController.impact(
				result.impact.position,
				result.impact.normal,
				result.impact.part,
				result.impact.material,
				holeSize(config)
			)
		end
		-- Suppressed guns: a faint tracer for the shooter only (none for enemies).
		EffectsController.tracer(from, result.finish, config, true)
	end

	Net.event("Fire"):FireServer({
		origin = origin,
		direction = aim,
		shot = shotIndex,
		spread = spread,
		centred = centred,
		alt = altFire ~= nil,
		hits = hits,
		ends = ends,
	})

	-- Feel.
	if not scoped then -- no flash or casing in the scope picture
		EffectsController.localShot(config, side, muzzleName)
	end
	playGun(config, "fire", "Gun")
	playGun(config, "tail", "Gun")
	-- A hollow tick from a near-empty mag, louder as it runs dry.
	local mag = config.magSize
	local low = math.ceil(mag * Audio.LOW_AMMO_FRACTION)
	if mag >= Audio.LOW_AMMO_MIN_MAG and s.ammo > 0 and s.ammo <= low then
		playLocal(Sounds.LowAmmo, "Foley", Audio.LOW_AMMO_VOLUME * (1.4 - 0.4 * s.ammo / low))
	end
	-- Pump and bolt guns work the action after every shot.
	if (config.fireMode == "Pump" or config.fireMode == "Bolt") and s.ammo > 0 then
		task.delay(config.fireInterval * Audio.CYCLE_DELAY, function()
			if current() == s and alive then
				playGun(config, "rack")
			end
		end)
	end
	kickRecoil(s, sinceLast, now)
	if altFire then
		-- The burst kicks harder than a single shot.
		CameraController.kick(config.recoil.up, 0, config.recoil.recover, config.recoil.recoverTime)
	end
	CameraController.shake((0.04 + config.recoil.up * 0.1) * (1 - 0.35 * adsAlpha))
	ViewmodelController.fire(
		(1 - 0.5 * adsAlpha) * (if altFire then 1.6 else 1),
		side,
		config.magSize > 0 and s.ammo <= 0
	)
	if predictedHit then
		HudController.hitMarker(predictedHead)
	end
	updateHudWeapon()

	if config.magSize > 0 and s.ammo <= 0 then
		task.delay(0.25, function()
			local c = current()
			if c == s and s.ammo <= 0 then
				startReload()
			end
		end)
	end
end

-- The last light attack's place in the Slash1 -> 2 -> 3 chain.
local comboStep = 0
-- Gouge angle per slash (radians around the wall normal): the blade's path.
local SLASH_ANGLES = { 0.35, -0.4, 1.35 }

-- A knife attack. Light attacks chain Slash1 -> 2 -> 3 when each comes within
-- the knife's comboWindow of the last one's cooldown; `heavy` is the
-- right-click two-handed stab (its own cooldown, altFire.fireInterval). The
-- server checks reach, facing, cooldowns and damage as for any shot.
local function swing(s: LocalSlot, heavy: boolean?)
	local config = s.config
	local melee = config.melee
	local cam = Workspace.CurrentCamera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not melee or not cam or not root or not root:IsA("BasePart") then
		return
	end
	local heavyStats = if heavy then melee.heavy else nil
	local altFire = config.altFire
	if heavy and not (heavyStats and altFire) then
		return
	end
	local now = os.clock()
	local readyAt = s.lastFire + config.fireInterval
	if now < readyAt or now < s.altReadyAt then
		return
	end
	if heavy then
		comboStep = 0
	elseif comboStep < 3 and now - math.max(readyAt, s.altReadyAt) <= (melee.comboWindow or 0) then
		comboStep += 1
	else
		comboStep = 1
	end
	s.lastFire = now
	if heavy and altFire then
		s.altReadyAt = now + altFire.fireInterval
	end
	ViewmodelController.swing(if heavy then "HeavyStab" else "Slash" .. comboStep)
	playGun(config, if heavy then "heavy" else "fire", "Gun")

	local origin = cam.CFrame.Position
	local aim = cam.CFrame.LookVector
	local params = rayParams()
	local result = Workspace:Spherecast(origin, 1.3, aim * melee.range, params)
	local hits = {}
	if result and result.Instance:IsA("BasePart") then
		local model = combatantOf(result.Instance)
		if model and aliveHumanoid(model) then
			table.insert(hits, { part = result.Instance, position = result.Position, pellet = 1 })
			EffectsController.impact(result.Position, -aim, result.Instance)
			HudController.hitMarker(false)
			playGun(config, "hitBody")
			-- Lunge toward the target on hit.
			local flat = (aim * Vector3.new(1, 0, 1))
			if flat.Magnitude > 0.01 then
				local lunge = if heavyStats then heavyStats.lunge else melee.lunge
				root.AssemblyLinearVelocity = flat.Unit * (lunge / 0.15)
					+ Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
			end
		elseif not model then
			-- The world: a gouge along the blade's path and a steel tick.
			local angle = if heavy then math.random() * math.pi else SLASH_ANGLES[comboStep]
			-- Each strike lands a little apart, as a real blade would.
			local n = result.Normal
			local side = n:Cross(if math.abs(n.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis).Unit
			local up = side:Cross(n)
			local jitter = side * (math.random() - 0.5) * 0.6 + up * (math.random() - 0.5) * 0.4
			EffectsController.slashMark(result.Position + jitter, n, angle, heavy)
			playGun(config, "hitWall")
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
		alt = heavy == true,
	})
end

local function canShoot(s: LocalSlot): boolean
	if
		not alive
		or os.clock() < equipReadyAt
		or reloading
		or PickerController.isBusy()
		or isHolstered()
	then
		return false
	end
	if s.config.magSize > 0 and s.ammo < 1 then
		return false
	end
	return true
end

local function onFirePressed()
	if PickerController.isBusy() or isHolstered() then
		return -- a click in the weapon picker, or a held Mod's use
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
	-- Mid shell-by-shell reload with a shell in: stop and fire.
	local r = reloading
	if r and r.shell and s.ammo >= 1 then
		stopShellReload(s, r, os.clock())
	end
end

local function onFireReleased()
	triggerHeld = false
end

-- Per frame --------------------------------------------------------------------

local function update(dt: number)
	local s = current()
	local now = os.clock()
	local cam = Workspace.CurrentCamera

	-- Reload progress.
	local r = reloading
	if r and s and r.shell then
		stepShellReload(s, r, now)
		HudController.setReload(
			if reloading then math.clamp((now - r.start) / r.duration, 0, 1) else nil
		)
	elseif r and s then
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

	-- Landing (for the landing spread), on our own clock like the server's.
	local moveState = MovementController.getState()
	if lastMoveState == "Air" and moveState ~= "Air" then
		landedAt = now
	end
	lastMoveState = moveState

	-- Aim down sights.
	local aimingWanted = s ~= nil
		and alive
		and s.config.fireMode ~= "Melee"
		and not s.config.noAds
		and (InputController.isDown("Aim") or devAim)
		and not MovementController.isSprinting()
		and not PickerController.isOpen()
		and not isHolstered()
	aiming = aimingWanted
	if s then
		local rate = 1 / math.max(s.config.adsTime, 0.05)
		adsAlpha = math.clamp(adsAlpha + (if aimingWanted then rate else -rate) * dt, 0, 1)
	else
		adsAlpha = 0
	end
	ViewmodelController.setAds(adsAlpha)
	local scope = s and s.config.scope
	CameraController.setZoom(
		if scope then scopeFov(scope.zoom) elseif s then s.config.adsFov else nil,
		ease(adsAlpha)
	)
	setScoped(scope ~= nil and adsAlpha >= VM.SCOPE_AT)
	HudController.setCrosshairVisible(adsAlpha < 0.5 and not MovementController.isSprinting())

	-- Trigger.
	if s and alive then
		HudController.setSpread(currentSpread(s) + s.config.pelletSpread * 0.6)
		local mode = s.config.fireMode
		if mode == "Melee" then
			if pressQueued and now >= equipReadyAt then
				pressQueued = false
				swing(s)
			elseif now - altQueuedAt < 0.2 and now >= equipReadyAt then
				altQueuedAt = -math.huge
				swing(s, true)
			end
		elseif mode == "Auto" then
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
				and now >= s.lastFire + s.config.fireInterval / FireRate.boost(player)
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
		else
			if pressQueued and canShoot(s) then
				local interval = FireRate.interval(s.config, s.spinStart, s.lastFire, now)
					/ FireRate.boost(player)
				if now >= s.lastFire + interval then
					pressQueued = false
					fireShot(s)
				end
			end
		end
		-- Alt-fire: one press, one burst (a press only counts for a moment).
		if s.config.altFire and mode ~= "Melee" and now - altQueuedAt < 0.2 and canShoot(s) then
			local before = s.lastFire
			fireShot(s, true)
			if s.lastFire ~= before then
				altQueuedAt = -math.huge
			end
		end
		-- A queued press only counts for a short moment.
		if
			pressQueued
			and not triggerHeld
			and now - math.max(lastShotAt, pressHoldUntil) > 0.2
			and mode ~= "Melee"
		then
			pressQueued = false
		end
	end

	-- Hide our own third-person gun(s) in first person.
	local character = player.Character
	if character then
		for _, name in { "WorldWeapon", "WorldWeaponLeft", "ModHeldItem" } do
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

-- Holster (held Mods) -----------------------------------------------------------

-- Lowers the gun and stops it firing, aiming, reloading and inspecting while
-- any reason holds it down. A reload in progress is cancelled. When the last
-- reason goes, the gun comes back up before it can fire.
function WeaponController.setHolstered(reason: string, on: boolean)
	local was = isHolstered()
	holstered[reason] = if on then true else nil
	local now = isHolstered()
	if was == now then
		return
	end
	triggerHeld = false
	pressQueued = false
	burstQueue = 0
	altQueuedAt = -math.huge
	if now then
		cancelReload()
		ViewmodelController.cancelInspect()
	else
		equipReadyAt = math.max(equipReadyAt, os.clock() + UNHOLSTER_TIME)
	end
	ViewmodelController.setLowered(now)
end

function WeaponController.isHolstered(): boolean
	return isHolstered()
end

-- Rollback rewound the ammo on the server: drop a reload in progress so the
-- server's count (WeaponState) is the one that counts.
function WeaponController.cancelReload()
	cancelReload()
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
						heat = 0,
						lastShotAt = -math.huge,
						sprayShots = 0,
						sideDir = 1,
						lastSwitch = 0,
						altReadyAt = -math.huge,
					}
					if equipped == slot then
						changedEquip = true
					end
				else
					-- During a reload our own count leads, except when a shell-by-
					-- shell reload was stopped: then the server's count (sent on
					-- the stop) is the one that counts.
					local r = reloading
					local stopped = r ~= nil and r.shell ~= nil and r.shell.phase == "End"
					if not (r and equipped == slot) or stopped then
						existing.ammo = incoming.ammo
					end
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
-- The end of a life: dying, or a respawn without dying (LoadCharacter). The
-- next life's WeaponState then equips (and first-draws) from scratch.
local function endLife()
	alive = false
	table.clear(holstered)
	ViewmodelController.setLowered(false)
	triggerHeld = false
	burstQueue = 0
	cancelReload()
	equipped = nil
	table.clear(slots)
	ViewmodelController.unequip()
	CameraController.setZoom(nil, 0)
	setScoped(false)
end

local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	alive = true
	humanoid.Died:Connect(endLife)
end

function WeaponController.start()
	InputController.onPressed("Fire", onFirePressed)
	InputController.onReleased("Fire", onFireReleased)
	InputController.onPressed("Reload", startReload)
	-- Guns with no ADS use the Aim input for their alt-fire.
	InputController.onPressed("Aim", function()
		local s = current()
		if
			s
			and s.config.altFire
			and s.config.noAds
			and not PickerController.isBusy()
			and not isHolstered()
		then
			ViewmodelController.cancelInspect()
			altQueuedAt = os.clock()
			if s.config.magSize > 0 and s.ammo < 1 and not reloading then
				dryFire()
				startReload()
			end
		end
	end)
	InputController.onPressed("Inspect", inspect)
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
		-- No melee in the loadout: nothing happens (never a shot from the gun).
		if equip("Melee") then
			pressQueued = true
		end
	end)
	InputController.onPressed("CycleWeapon", function()
		-- The next slot that holds something, skipping empty ones.
		local index = table.find(CYCLE, equipped or "Primary") or 0
		for step = 1, #CYCLE - 1 do
			local slot = CYCLE[(index + step - 1) % #CYCLE + 1]
			if slots[slot] then
				equip(slot)
				return
			end
		end
	end)
	Net.event("WeaponState").OnClientEvent:Connect(onWeaponState)
	Net.event("HitConfirm").OnClientEvent:Connect(onHitConfirm)

	player.CharacterAdded:Connect(onCharacter)
	player.CharacterRemoving:Connect(endLife)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	RunService:BindToRenderStep("GGWeapons", Enum.RenderPriority.Input.Value + 1, update)
	-- Studio only: the Workspace attribute DevAction ("inspect", "reload",
	-- "draw" = draw again, "fire" = one shot, or a slot name to switch to)
	-- runs that action, and DevAim (true) holds aim down sights, so scripts can review
	-- the animations (MCP key presses are unreliable).
	if RunService:IsStudio() then
		Workspace:GetAttributeChangedSignal("DevAim"):Connect(function()
			devAim = Workspace:GetAttribute("DevAim") == true
		end)
		Workspace:GetAttributeChangedSignal("DevAction"):Connect(function()
			local action = Workspace:GetAttribute("DevAction")
			if action == nil then
				return
			end
			Workspace:SetAttribute("DevAction", nil)
			local s = current()
			if action == "inspect" then
				inspect()
			elseif action == "reload" then
				startReload()
			elseif action == "draw" and s and equipped then
				applyEquip(equipped)
			elseif action == "Primary" or action == "Secondary" or action == "Melee" then
				equip(action)
			elseif action == "fire" and s and alive then
				if s.config.fireMode == "Melee" then
					swing(s, Workspace:GetAttribute("DevHeavy") == true)
				else
					-- A real press and release, so it interrupts a shell reload too.
					onFirePressed()
					task.delay(0.05, onFireReleased)
				end
			end
		end)
	end
end

return WeaponController
