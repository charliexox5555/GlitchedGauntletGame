--!strict
-- Client side of the weapon system. Reads input, fires instantly for feel
-- (spread, recoil, effects, predicted hit marker) and sends what it saw to
-- the server, which re-checks everything and applies damage. Ammo and
-- loadout are mirrored from the server's WeaponState.
--
-- Fire modes mirror WeaponService.onFire: Semi/Pump/Bolt (one per press),
-- Auto, Burst (one press = burst.count shots) and Melee.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Health = require(Shared.Health)
local Accuracy = require(Shared.Util.Accuracy)
local Ammo = require(Shared.Util.Ammo)
local DashMod = require(Shared.Mods.Dash)
local Status = require(Shared.Mods.Status)
local Teams = require(Shared.Mods.Teams)
local Animations = require(Shared.Config.Animations)
local Audio = require(Shared.Config.Audio)
local Combat = require(Shared.Config.Combat)
local HitFx = require(Shared.Config.HitFx)
local Juice = require(Shared.Config.Juice)
local MeleeSkins = require(Shared.Config.MeleeSkins)
local GunSounds = require(Shared.Config.GunSounds)
local Fighters = require(Shared.Util.Fighters)
local FireRate = require(Shared.Util.FireRate)
local MatchState = require(Shared.MatchState)
local Net = require(Shared.Net)
local ShadowMistAudio = require(Shared.Config.ShadowMistAudio)
local TempestAudio = require(Shared.Config.TempestAudio)
local SkinPreviewConfig = require(Shared.Config.SkinPreview)
local Sounds = require(Shared.Config.Sounds)
local Spread = require(Shared.Util.Spread)
local Penetration = require(ReplicatedStorage.Shared.Util.Penetration)
local Types = require(Shared.Types)
local VM = require(Shared.Config.Viewmodel)
local Weapons = require(Shared.Config.Weapons)

local AudioController = require(script.Parent.AudioController)
local BottomHud = require(script.Parent.Parent.Util.BottomHud)
local GunAudio = require(script.Parent.Parent.Util.GunAudio)
local LocalHide = require(script.Parent.Parent.Util.LocalHide)
local CameraController = require(script.Parent.CameraController)
local EffectsController = require(script.Parent.EffectsController)
local HudController = require(script.Parent.HudController)
local InputController = require(script.Parent.InputController)
local MovementController = require(script.Parent.MovementController)
local PickerController = require(script.Parent.PickerController)
local ViewmodelController = require(script.Parent.ViewmodelController)
local ShotLog = require(script.Parent.Parent.Util.ShotLog)

local HitFeedback = require(script.Parent.Parent.Util.HitFeedback)

local studioSkinPreview = RunService:IsStudio() and game.PlaceId == SkinPreviewConfig.PLACE_ID

type Slot = Types.Slot
type WeaponConfig = Types.WeaponConfig

type LocalSlot = {
	id: string,
	config: WeaponConfig,
	ammo: number,
	reserve: number?,
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
	slow: number, -- each phase's time is multiplied by this (a status at the start)
}

type Reload = { start: number, duration: number, token: number, shell: ShellState? }

local WeaponController = {}

local player = Players.LocalPlayer

local slots: { [Slot]: LocalSlot } = {}
local equipped: Slot? = nil
local equipReadyAt = 0
local reloading: Reload? = nil
local reloadToken = 0
local meleeEpoch = 0
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
-- When our own shot last showed a hit (the hit sound plays then, not on the
-- server's confirm a round trip later; owner 2026-11-14: "fires way too late").
local lastPredictedHit = -math.huge
local lastPredictedHead = -math.huge
local lastAimSent = 0
local nextAimAt = 0 -- the next Aim send slot (a schedule: 30 Hz stays 30 Hz, not every third frame)
local nextLookAt = 0 -- the next Look stream slot (Services/LookStream)
local LOOK_PHASES = table.freeze({ Live = true, SuddenDeath = true, RoundEnd = true })
local lastPitchSent = 0
local lastAimingSent = false
local lastStateSent = ""
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

-- Our status effects (Mods/Status: Hinder slows fire, reload, swap and
-- recoil recovery); the server enforces the same.
local function statusMults(): Status.Mults
	return Status.mults(player.Character, Workspace:GetServerTimeNow())
end

-- Stim's boost and our statuses: shots per second, relative.
local function fireRateMult(): number
	return FireRate.boost(player) * statusMults().fireRate
end

local function current(): LocalSlot?
	return if equipped then slots[equipped] else nil
end

local function isHolstered(): boolean
	return next(holstered) ~= nil
end

-- The gun can't be used: a held Mod, or a stun (Frozen: no shots, reloads
-- or swaps; the server refuses them too).
local function gunBlocked(): boolean
	return isHolstered() or Status.stunned(player.Character, Workspace:GetServerTimeNow())
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
	return Health.isAlive(h)
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
	-- Match the server's friendly-fire rule before predicting contact feedback.
	for _, fighter in Fighters.all(player) do
		if Teams.isAlly(player, fighter.holder) then
			table.insert(exclude, fighter.body)
		end
	end
	params.FilterDescendantsInstances = exclude
	return params
end

-- What we're doing right now, for the spread (the server recomputes the same
-- from its own simulation: WeaponService spreadBand).
local landedAt = -math.huge -- os.clock() of our last landing (update() spots it)
local lastMoveState = "Idle"
-- Dash (Mods/Dash.stepGate), on our own clock like the server's copy
-- (WeaponService sampleMotion): the gun is down while dashing and for
-- DashFireDelay after; then the first shot until focusUntil has no movement
-- spread (Dash Focus).
local dashGate = DashMod.newGate()
-- Recall's wind-up: no shots until this (the gun stays up).
local fireBlockedUntil = 0

local function dashBlocked(): boolean
	local now = os.clock()
	return now < dashGate.readyAt or now < fireBlockedUntil
end

local function focusNow(): boolean
	local now = os.clock()
	return dashGate.focusOpen and now >= dashGate.readyAt and now <= dashGate.focusUntil
end

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
	local motion = motionNow()
	if focusNow() then
		-- No movement spread, but a crouch still steadies the gun.
		motion = {
			state = if motion.state == "Crouch" then "Crouch" else "Idle",
			speed = 0,
			aim = motion.aim,
			sinceLanding = math.huge,
		}
	end
	return Accuracy.cone(s.config, heat, motion)
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
	CameraController.kick(up, side, r.recover, r.recoverTime / statusMults().recoil)
	-- Which way this shot pulls sideways (-1 left .. 1 right): the viewmodel's
	-- kick follows it (ViewmodelController.fire).
	return if r.side > 0 then math.clamp(side / r.side, -1, 1) else 0
end

local function playLocal(id: string?, group: AudioController.Group, volume: number, pitch: number?)
	AudioController.play(id, { group = group, volume = volume, pitch = pitch })
end

local function usesRuinBlighted(): boolean
	return studioSkinPreview and ViewmodelController.hasShadowMist()
end

-- The Tempest-Strike Vandal: its own designed shots and handling
-- (Config/TempestAudio.guns; owner approved the Vandal's v2 set 2026-11-22, the line 2026-11-22).
local function tempestSet(config: WeaponConfig): any
	if ViewmodelController.hasTempest() then
		return TempestAudio.guns[config.id]
	end
	return nil
end

-- A sound from the gun's Config/GunSounds entry, played on our side (2D).
local function playGun(
	config: WeaponConfig,
	name: string,
	group: AudioController.Group?,
	pitchScale: number?
): AudioController.Handle?
	local tempest = tempestSet(config)
	if tempest and tempest[name] then
		local custom =
			AudioController.playSound(tempest[name], group or "Foley", nil, nil, pitchScale)
		if custom then
			return custom
		end
	end
	if name == "rack" and config.id == "Vandal" and usesRuinBlighted() then
		local custom = AudioController.playSound(ShadowMistAudio.rack, group or "Foley")
		if custom then
			return custom
		end
	end
	local set = GunSounds.get(config.id) :: any
	return AudioController.playSound(set[name], group or "Foley", nil, nil, pitchScale)
end

-- Clip beats (ViewmodelController clipBeats) to GunSounds names.
local BEAT_SOUNDS: { [string]: string } = {
	MagOut = "magOut",
	MagIn = "magIn",
	Rack = "rack",
	Open = "open",
	Eject = "eject",
	ShellIn = "shellIn",
	Close = "close",
}

local function updateHudWeapon()
	local s = current()
	if s then
		HudController.setWeapon(
			s.config.displayName,
			math.floor(s.ammo),
			s.config.magSize,
			s.config.id,
			s.reserve
		)
	end
	-- The bottom HUD's hotbar shows every slot, the held one lit.
	local entries: { BottomHud.LoadoutEntry } = {}
	for _, slot in CYCLE do
		local ls = slots[slot]
		if ls then
			table.insert(entries, {
				slot = slot,
				id = ls.config.id,
				ammo = math.floor(ls.ammo),
				mag = ls.config.magSize,
			})
		end
	end
	BottomHud.setLoadout(entries, equipped)
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
	local needed = Ammo.toLoad(s.config.magSize, s.ammo, s.reserve)
	local slow = 1 / statusMults().reload
	reloadToken += 1
	reloading = {
		start = os.clock(),
		duration = (shell.start + shell.insert * needed + shell.finish) * slow,
		token = reloadToken,
		shell = {
			phase = "Start",
			doneAt = os.clock() + shell.start * slow,
			inserted = 0,
			needed = needed,
			wasEmpty = s.ammo == 0,
			slow = slow,
		},
	}
	Net.event("Reload"):FireServer()
	playShellClip(s.config, "ReloadStart", shell.start * slow)
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
		s.ammo, s.reserve = Ammo.load(s.config.magSize, s.ammo, s.reserve, 1)
		updateHudWeapon()
	end
	if st.phase ~= "End" and st.inserted < st.needed then
		st.phase = "Insert"
		st.doneAt = now + shell.insert * st.slow
		playShellClip(s.config, "ReloadInsert", shell.insert * st.slow)
	elseif st.phase ~= "End" then
		st.phase = "End"
		st.doneAt = now + shell.finish * st.slow
		playShellClip(s.config, "ReloadEnd", shell.finish * st.slow)
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
	st.doneAt = now + shell.finish * st.slow
	pressHoldUntil = st.doneAt
	Net.event("Reload"):FireServer("stop")
	playShellClip(s.config, "ReloadEnd", shell.finish * st.slow)
end

local function startReload()
	local s = current()
	if not s or reloading or not alive or gunBlocked() then
		return
	end
	local config = s.config
	if Ammo.toLoad(config.magSize, s.ammo, s.reserve) == 0 then
		return
	end
	burstQueue = 0
	if config.shellReload then
		startShellReload(s)
		return
	end
	local empty = s.ammo == 0
	local duration = (if empty then config.emptyReloadTime else config.reloadTime)
		/ statusMults().reload
	reloadToken += 1
	local token = reloadToken
	reloading = { start = os.clock(), duration = duration, token = token }
	Net.event("Reload"):FireServer()
	-- Foley (Config/GunSounds) lands on the clip's own beats.
	local shadow = usesRuinBlighted()
	for _, beat in ViewmodelController.reload(duration, empty) do
		if shadow and (beat.sound == "MagOut" or beat.sound == "MagIn") then
			continue -- ShadowMistActions owns the animated mag and its sound
		end
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
	if alive and s and not reloading and os.clock() >= equipReadyAt and not gunBlocked() then
		if ViewmodelController.inspect() then
			local reaver = ViewmodelController.hasRuinedReaver()
			-- (the Tempest-Strike Katana's inspect sounds are its own timeline)
			local katana = s.config.fireMode == "Melee" and tempestSet(s.config) ~= nil
			if not usesRuinBlighted() and not reaver and not katana then
				playGun(s.config, "inspect")
			end
			-- The knife's flips click as it's caught (Config/Viewmodel InspectMelee).
			if s.config.fireMode == "Melee" and not reaver and not katana then
				for _, at in Animations.KNIFE_FEEL.inspectFlips do
					task.delay(at, function()
						if ViewmodelController.isInspecting() then
							playGun(s.config, "inspectFlip")
						end
					end)
				end
			end
		end
	end
end

-- Equip ----------------------------------------------------------------------

local function applyEquip(slot: Slot)
	meleeEpoch += 1
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
	local duration = (config.drawTime or config.equipTime) / statusMults().equip
	equipReadyAt = os.clock() + duration
	updateHudWeapon()
	local beats = ViewmodelController.equip(config, duration)
	local shadow = usesRuinBlighted()
	playGun(config, "draw")
	if not shadow and not ViewmodelController.hasRuinedReaver() then
		playGun(config, "drawWhoosh")
	end
	local token = reloadToken
	for _, beat in beats do
		if shadow and beat.sound == "Rack" then
			continue -- the shards lock on the draw track
		end
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
	local budget = Penetration.budget(config.penetration)
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
			-- A wall: through it if the round has the budget (Util/Penetration).
			local passThrough = Penetration.pass(budget, part, result.Position, dir)
			if not passThrough then
				-- A Mod object (a placed Mod object) takes the hit: report it.
				if StateValues.get(part, "MaxHp") ~= nil and part:IsA("BasePart") then
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
			EffectsController.localWallImpact(
				config,
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
		/ fireRateMult()
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
		s.altReadyAt = now + altFire.fireInterval / fireRateMult()
	end

	local spread, centred = currentSpread(s)
	dashGate.focusOpen = false -- only the first shot after a dash
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
			EffectsController.ownImpact(h.position, -dir, h.part)
		end
		table.insert(ends, result.finish)
		if result.impact then
			EffectsController.localWallImpact(
				config,
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
		seedBase = seedBase,
		spread = spread,
		centred = centred,
		alt = altFire ~= nil,
		hits = hits,
		ends = ends,
	})
	ShotLog.own(config.id, origin, ends)

	-- Feel.
	if scoped then
		HudController.scopeShot() -- no flash or casing in the scope picture: it jolts
	else
		EffectsController.localShot(config, side, muzzleName)
	end
	-- The shot's sounds (Util/GunAudio: first shot, random takes, a tail
	-- with every shot faded by the next, the last round), per gun slot.
	GunAudio.shot(s, config, {
		lastRound = config.magSize > 0 and s.ammo <= 0,
		shadowMist = usesRuinBlighted(),
		tempest = tempestSet(config) ~= nil,
	})
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
	local recoilLean = kickRecoil(s, sinceLast, now)
	if altFire then
		-- The burst kicks harder than a single shot.
		CameraController.kick(
			config.recoil.up,
			0,
			config.recoil.recover,
			config.recoil.recoverTime / statusMults().recoil
		)
	end
	local feel = Juice.SHOT_FEEL
	local feelScale = 1 - (1 - feel.adsScale) * adsAlpha
	-- Low-recoil automatics still get some weight per shot (upFloor).
	local feelUp = math.max(config.recoil.up, feel.upFloor)
	CameraController.shake((feel.shakeBase + feelUp * feel.shakePerUp) * feelScale)
	CameraController.punchFov(
		math.min(feelUp * feel.fovPerUp, feel.fovMax) * feelScale,
		feel.fovTime
	)
	CameraController.rollKick(
		math.min(feelUp * feel.rollPerUp, feel.rollMax)
			* feelScale
			* (if math.random() < 0.5 then -1 else 1),
		feel.rollTime
	)
	HudController.crosshairShot(feelUp * (if altFire then 1.6 else 1))
	ViewmodelController.fire(
		(1 - 0.5 * adsAlpha) * (if altFire then 1.6 else 1) * (config.viewmodelKick or 1),
		side,
		config.magSize > 0 and s.ammo <= 0,
		recoilLean
	)
	if predictedHit then
		HudController.hitMarker(predictedHead)
		-- The hit sound right away (LihFolk: predict the neutral contact); the
		-- kill tone still waits for the server.
		local hitAt = os.clock()
		lastPredictedHit = hitAt
		if predictedHead then
			lastPredictedHead = hitAt
			task.delay(Audio.HIT_DELAY, playLocal, Sounds.HitHead, "Feedback", Audio.HEAD_VOLUME)
		else
			-- Just after the shot's crack, not under it (Audio.HIT_DELAY).
			task.delay(Audio.HIT_DELAY, playLocal, Sounds.HitBody, "Feedback", Audio.HIT_VOLUME)
		end
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

-- Knife on a wall: the GunSounds entry per surface (EffectsController.surfaceOf),
-- falling back to `hitWall`.
local KNIFE_WALL_SOUND: { [string]: string } = {
	Metal = "hitMetal",
	Wood = "hitWood",
	Soft = "hitSoft",
	Glass = "hitMetal",
	Hard = "hitWall",
}

-- The last light attack's place in the Slash1 -> 2 -> 3 chain.
local comboStep = 0

-- Behind the barrier and between rounds (the server refuses shots too).
local function combatLocked(): boolean
	return StateValues.get(player, MatchState.COMBAT_LOCKED) == true
end

-- Heavy attacks query the current aim and reach when the blade lands. Light
-- combo input keeps its immediate hit query and times presentation to the clip.
local function swingContact(
	s: LocalSlot,
	attack: string,
	heavy: boolean,
	reaver: boolean,
	delay: number
)
	local config = s.config
	local melee = config.melee
	local cam = Workspace.CurrentCamera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not melee or not cam or not root or not root:IsA("BasePart") then
		return
	end
	local heavyStats = if heavy then melee.heavy else nil
	local feel = Animations.KNIFE_FEEL
	local look = (feel :: any)[attack]
	local path = Animations.KNIFE_MARK.paths[attack] or Vector2.new(-1, 0)
	local epoch = meleeEpoch
	local function atImpact(callback: () -> ())
		if delay <= 0 then
			callback()
		else
			task.delay(delay, function()
				if alive and meleeEpoch == epoch then
					callback()
				end
			end)
		end
	end
	local function punch(size: number)
		CameraController.kick(-path.Y * size * 0.5, -path.X * size, 1, feel.recover)
	end

	local origin = cam.CFrame.Position
	local aim = cam.CFrame.LookVector
	local params = rayParams()
	if reaver and heavy then
		atImpact(function()
			if not ViewmodelController.hasRuinedReaver() or not root.Parent then
				return
			end
			local forward = Vector3.new(aim.X, 0, aim.Z)
			if forward.Magnitude < 0.01 then
				return
			end
			local floor =
				Workspace:Raycast(root.Position + forward.Unit * 2.0, Vector3.new(0, -7, 0), params)
			if floor and floor.Normal.Y > 0.65 and not combatantOf(floor.Instance) then
				EffectsController.slashMark(floor.Position, floor.Normal, forward, true, true)
			end
		end)
	end
	local result = Workspace:Spherecast(origin, 1.3, aim * melee.range, params)
	local hits = {}
	if result and result.Instance:IsA("BasePart") then
		local model = combatantOf(result.Instance)
		if model and aliveHumanoid(model) then
			table.insert(hits, { part = result.Instance, position = result.Position, pellet = 1 })
			local hit = result
			atImpact(function()
				-- Contact (predicted, cosmetic; the server decides the damage):
				-- the impact sound at the start of the hit-stop, a small flash,
				-- the punch, then a little shake once the stop lets go.
				lastPredictedHit = os.clock()
				playGun(config, "hitBody")
				EffectsController.impact(hit.Position, -aim, hit.Instance, nil, nil, true, reaver)
				EffectsController.knifeContact(hit.Position - aim * 0.3, reaver)
				HudController.hitMarker(false)
				if look then
					ViewmodelController.hitStop(look.stop)
					punch(look.kick.Y)
					CameraController.rollKick(path.X * look.roll, feel.recover * 1.4)
					if look.fov then
						CameraController.punchFov(look.fov, 0.2)
					end
					task.delay(look.stop, CameraController.shake, feel.hitShake)
				end
			end)
			-- Lunge toward the target on hit.
			local flat = (aim * Vector3.new(1, 0, 1))
			if flat.Magnitude > 0.01 then
				local lunge = if heavyStats then heavyStats.lunge else melee.lunge
				root.AssemblyLinearVelocity = flat.Unit * (lunge / 0.15)
					+ Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
			end
		end
	end
	-- The world: a gouge where the blade actually lands, i.e. where the aim
	-- ray meets the surface (not the reach sphere's contact point, which sits
	-- off the crosshair on angled walls and catches nearby edges first), laid
	-- along this swing's path as seen on screen (Config/Animations KNIFE_MARK).
	if #hits == 0 then
		local wall = Workspace:Raycast(origin, aim * melee.range, params)
		if wall and wall.Instance:IsA("BasePart") and not combatantOf(wall.Instance) then
			local along = cam.CFrame.RightVector * path.X + cam.CFrame.UpVector * path.Y
			local at, n = wall.Position, wall.Normal
			local surface = EffectsController.surfaceOf(wall.Instance, wall.Material)
			local part, material = wall.Instance, wall.Material
			atImpact(function()
				playGun(config, KNIFE_WALL_SOUND[surface] or "hitWall")
				EffectsController.slashMark(at, n, along, heavy, reaver)
				EffectsController.impact(at, n, part, material, nil, true)
				ViewmodelController.hitStop(feel.wallStop)
				if look then
					punch(look.kick.Y * 0.5)
				end
			end)
		end
	end
	-- A whiff (and every slash): the streak, and a punch as the blade goes.
	if #hits == 0 and look then
		atImpact(function()
			punch(look.kick.X)
		end)
	end
	if not heavy and not reaver and look and look.swipe then
		EffectsController.knifeSwipe(
			look.swipe,
			math.max(delay - feel.swipeSweep * 0.45, 0),
			feel.swipeSweep,
			if #hits > 0 then 1 else feel.swipeWhiff
		)
	end
	shotIndex += 1
	Net.event("Fire"):FireServer({
		origin = origin,
		direction = aim,
		shot = shotIndex,
		seedBase = seedBase,
		spread = 0,
		hits = hits,
		ends = {},
		alt = heavy == true,
	})
	ShotLog.own(s.config.id, origin, {})
end

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
	dashGate.focusOpen = false
	local now = os.clock()
	local readyAt = s.lastFire + config.fireInterval / fireRateMult()
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
		s.altReadyAt = now + altFire.fireInterval / fireRateMult()
	end
	local attack = if heavy then "HeavyStab" else "Slash" .. comboStep
	local reaver = ViewmodelController.hasRuinedReaver()
	local hitDelay = ViewmodelController.swing(attack)
	local epoch = meleeEpoch
	local step = comboStep
	local feel = Animations.KNIFE_FEEL
	-- The whoosh peaks on the strike (its file peaks `whooshPeak` in), and each
	-- light slash in a chain climbs a semitone (LihFolk Combat Sound Design).
	local peakAt = if heavy then feel.whooshPeak.heavy else feel.whooshPeak.light
	local function currentSwing(): boolean
		return alive and meleeEpoch == epoch and current() == s and not combatLocked()
	end
	task.delay(math.max(hitDelay - peakAt - feel.whooshLead, 0), function()
		if currentSwing() then
			playGun(
				config,
				if heavy then "heavy" else "fire",
				"Gun",
				if heavy then 1 else 1.059 ^ (step - 1)
			)
		end
	end)
	local path = Animations.KNIFE_MARK.paths[attack] or Vector2.new(-1, 0)
	-- A knife-slot skin with its own motion leads by its own amount (Config/MeleeSkins FEEL).
	local lead = MeleeSkins.FEEL[ViewmodelController.meleeMotion() or ""] or feel
	task.delay(math.max(hitDelay - lead.leadEarly, 0), function()
		if currentSwing() then
			CameraController.rollKick(
				path.X * lead.leadRoll * (if heavy then 0.6 else 1),
				lead.leadTime
			)
		end
	end)
	if heavy then
		local look = (feel :: any)[attack]
		if look and look.swipe and not reaver then
			EffectsController.knifeSwipe(
				look.swipe,
				math.max(hitDelay - feel.swipeSweep * 0.45, 0),
				feel.swipeSweep,
				feel.swipeWhiff
			)
		end
		Net.event("Fire"):FireServer({ windup = true })
		task.delay(math.max(hitDelay, Combat.HEAVY_WINDUP_MIN), function()
			if currentSwing() and not gunBlocked() and not dashBlocked() then
				swingContact(s, attack, true, reaver, 0)
			end
		end)
	else
		swingContact(s, attack, false, reaver, hitDelay)
	end
end

local function canShoot(s: LocalSlot): boolean
	if
		not alive
		or os.clock() < equipReadyAt
		or reloading
		or PickerController.isBusy()
		or combatLocked()
		or gunBlocked()
		or dashBlocked()
	then
		return false
	end
	if s.config.magSize > 0 and s.ammo < 1 then
		return false
	end
	return true
end

local function onFirePressed()
	if PickerController.isBusy() or gunBlocked() or combatLocked() then
		return -- a click in the weapon picker, or a held Mod's use
	end
	local recoverInspect = ViewmodelController.isFinishingShadowMistInspect()
	ViewmodelController.cancelInspect()
	triggerHeld = true
	local s = current()
	pressQueued = not s or s.config.fireMode ~= "Auto" or recoverInspect
	if recoverInspect then
		pressHoldUntil = os.clock() + VM.CANCEL_TIME
	end
	if not s then
		return
	end
	if s.config.magSize > 0 and s.ammo < 1 and not reloading then
		pressQueued = false
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

-- While you spectate, the viewmodel and the zoom show someone else's gun
-- (SpectateController), so this stands down.
local spectating = false
function WeaponController.setSpectating(on: boolean)
	spectating = on
end

local function update(dt: number)
	if spectating then
		return
	end
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
			s.ammo, s.reserve = Ammo.load(s.config.magSize, s.ammo, s.reserve)
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

	-- Dash: the gun gate (Mods/Dash.stepGate).
	local body = player.Character
	if body then
		DashMod.stepGate(dashGate, body, now, time())
	end

	-- Aim down sights.
	local aimingWanted = s ~= nil
		and alive
		and s.config.fireMode ~= "Melee"
		and not s.config.noAds
		and (InputController.isDown("Aim") or devAim)
		and not MovementController.isSprinting()
		and not PickerController.isOpen()
		and not gunBlocked()
		and not dashBlocked()
		-- Reloading drops the sights and keeps them down (owner, 2026-11-08);
		-- a bolt or lever gun drops them while it cycles after a shot, and a
		-- scoped gun with nothing left in it (the Outlaw after both barrels).
		and not reloading
		and not (s.config.fireMode == "Bolt" and now < s.lastFire + s.config.fireInterval)
		and not (s.config.scope ~= nil and s.config.magSize > 0 and s.ammo <= 0)
	-- Into and out of the sights: a cloth flick (a scope's lens on scoped guns).
	if s and aimingWanted ~= aiming then
		playGun(s.config, if aimingWanted then "aimIn" else "aimOut")
	end
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
		if scope then CameraController.scopeFov(scope.zoom) elseif s then s.config.adsFov else nil,
		-- The zoom trails the gun (ViewmodelController: VM.ADS_FEEL).
		ViewmodelController.adsZoom(),
		scope ~= nil
	)
	HudController.setAim(ViewmodelController.adsBlend())
	setScoped(scope ~= nil and adsAlpha >= VM.SCOPE_AT)
	HudController.setCrosshairVisible(adsAlpha < 0.5, MovementController.isSprinting())
	local crossMove = MovementController.getState()
	HudController.setCrosshairState(crossMove == "Slide", crossMove == "Air", adsAlpha)

	-- Trigger.
	if s and alive then
		HudController.setSpread(currentSpread(s) + s.config.pelletSpread * 0.6)
		local mode = s.config.fireMode
		if mode == "Melee" then
			if combatLocked() then
				-- Behind the barrier: no swings, and nothing saved up for GO.
				pressQueued = false
				altQueuedAt = -math.huge
			elseif pressQueued and now >= equipReadyAt and not dashBlocked() then
				pressQueued = false
				swing(s)
			elseif now - altQueuedAt < 0.2 and now >= equipReadyAt and not dashBlocked() then
				altQueuedAt = -math.huge
				swing(s, true)
			end
		elseif mode == "Auto" then
			if
				(triggerHeld or pressQueued)
				and canShoot(s)
				and not ViewmodelController.isFinishingShadowMistInspect()
			then
				pressQueued = false
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
				and now >= s.lastFire + s.config.fireInterval / fireRateMult()
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
					/ fireRateMult()
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
						LocalHide.set(d, 1)
					end
				end
			end
		end
	end

	-- Tell the server where we're aiming (third-person pose for others) and,
	-- with Server Authority off, what we're doing (shared/Authority: the
	-- server publishes it for everyone else's footsteps, dust and spectating).
	-- Juice SPECTATE: aimSendHz slots on a real move, one settle send once the
	-- aim stops (so the last value lands), and a keepalive (a dropped packet
	-- can't leave a stale Aiming / MoveState behind).
	local aimFeel = Juice.SPECTATE
	local sinceAim = now - lastAimSent
	if cam and now >= nextAimAt then
		local pitch = math.asin(math.clamp(cam.CFrame.LookVector.Y, -1, 1))
		local moving = MovementController.getState()
		local moved = math.abs(pitch - lastPitchSent)
		if
			moved > aimFeel.aimDeadband
			or aimingWanted ~= lastAimingSent
			or moving ~= lastStateSent
			or (sinceAim >= aimFeel.aimSettle and moved > 1e-4)
			or sinceAim >= aimFeel.aimKeepalive
		then
			-- On schedule: keep the cadence; after a quiet spell: one interval from now.
			local interval = 1 / aimFeel.aimSendHz
			nextAimAt = if now - nextAimAt < interval then nextAimAt + interval else now + interval
			lastAimSent = now
			lastPitchSent = pitch
			lastAimingSent = aimingWanted
			lastStateSent = moving
			Net.unreliable("Aim"):FireServer(pitch, aimingWanted, moving)
		end
	end

	-- The look stream (Services/LookStream): our view's yaw and pitch on the
	-- server's clock, Juice SPECTATE lookHz, in a fight. Spectators draw it a
	-- little in the past, interpolated, and the final-kill replay reads it.
	if cam and alive and now >= nextLookAt and LOOK_PHASES[MatchState.phase() or ""] then
		local interval = 1 / aimFeel.lookHz
		nextLookAt = if now - nextLookAt < interval then nextLookAt + interval else now + interval
		local look = cam.CFrame.LookVector
		local b = buffer.create(16)
		buffer.writef64(b, 0, Workspace:GetServerTimeNow())
		buffer.writef32(b, 8, math.atan2(-look.X, -look.Z))
		buffer.writef32(b, 12, math.asin(math.clamp(look.Y, -1, 1)))
		Net.unreliable("Look"):FireServer(b)
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

-- No shots for `seconds` (0 lifts it) without lowering the gun: Recall's
-- wind-up, so you arrive ready to fire.
function WeaponController.blockFire(seconds: number)
	fireBlockedUntil = os.clock() + math.max(seconds, 0)
end

function WeaponController.isHolstered(): boolean
	return isHolstered()
end

-- The server rewound the ammo (the old Rollback; nothing sends this now): drop a reload in progress so the
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
	if
		typeof(state.shotIndex) == "number"
		and (state.resync == true or state.shotIndex > shotIndex)
	then
		shotIndex = state.shotIndex
	end
	local changedEquip = false
	for _, slot in CYCLE do
		local incoming = state.slots[slot]
		if not incoming then
			slots[slot] = nil
		else
			local config = Weapons.get(incoming.id)
			if config then
				local existing = slots[slot]
				if not existing or existing.id ~= incoming.id then
					slots[slot] = {
						id = incoming.id,
						config = config,
						ammo = incoming.ammo,
						reserve = incoming.reserve,
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
					if not (r and equipped == slot) or stopped or state.equipped ~= equipped then
						existing.ammo = incoming.ammo
						existing.reserve = incoming.reserve
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

-- Can the camera see `point`? A ray from the camera; a hit short of the point
-- is cover, unless it is a body (a Humanoid's model never counts as cover).
local function canSee(point: Vector3): boolean
	local cam = Workspace.CurrentCamera
	if not cam then
		return false
	end
	local from = cam.CFrame.Position
	local offset = point - from
	local dist = offset.Magnitude
	if dist < 1e-3 then
		return true
	end
	local params = rayParams()
	local slack = HitFx.SIGHT.slack
	for _ = 1, 8 do -- step past bodies; bounded
		local result = Workspace:Raycast(from, offset.Unit * (dist - slack), params)
		if not result then
			return true
		end
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		if model and model:FindFirstChildOfClass("Humanoid") then
			local list = params.FilterDescendantsInstances
			table.insert(list, model)
			params.FilterDescendantsInstances = list
		else
			return false
		end
	end
	return false
end

-- A hit to show: your own (the server's HitConfirm) or, `relayed`, one by
-- the fighter you spectate (SpectateController, the SpectateFeed): drawn the
-- same, its sounds a little quieter and never skipped as already predicted.
local function onHitConfirm(confirm: Types.HitConfirm, relayed: boolean?)
	if typeof(confirm) ~= "table" then
		return
	end
	if
		typeof(confirm.damage) ~= "number"
		or confirm.damage ~= confirm.damage
		or typeof(confirm.zone) ~= "string"
	then
		return
	end
	local at: Vector3? = if typeof(confirm.position) == "Vector3" then confirm.position else nil
	-- A Mod dealt it (the server says so): the marker, no numbers, and nothing
	-- drawn on a victim the attacker can't see (HitFx.SOURCE_DEFAULT / SOURCES).
	local rule: HitFx.SourceRule? = nil
	if typeof(confirm.source) == "string" then
		rule = HitFx.SOURCES[confirm.source] or HitFx.SOURCE_DEFAULT
	end
	local worldFx = true
	if rule and at then
		worldFx = rule.worldFx == "always" or (rule.worldFx == "visible" and canSee(at))
	end
	-- A guard took the hit (a Barrier, a Ghost dash): BLOCKED, no damage.
	if confirm.blocked == true then
		HitFeedback.blocked(if worldFx then at else nil)
		return
	end
	local head = confirm.zone == "Head"
	if not rule or rule.marker then
		HudController.hitMarker(head)
	end
	if at and worldFx then
		EffectsController.hitFlash(at, head, confirm.killed == true)
	end
	if not rule or rule.numbers then
		local victim = confirm.victim
		local target = if typeof(victim) == "Instance" and victim:IsA("Model") then victim else nil
		HudController.damageNumber(confirm.damage, head, at, confirm.killed == true, target)
	end
	-- One contact cue for a hit. The kill tone plays from the server's Killed
	-- event (Util/KillFeed), so it climbs per kill in the round.
	-- Hits our own shot already sounded (just above in fireShot) stay quiet
	-- here; a hit the client didn't see (a wallbang) sounds on the confirm.
	local now = os.clock()
	local volume = if relayed then Juice.SPECTATE.relayHitVolume else 1
	if head then
		if relayed or now - lastPredictedHead > Audio.HIT_PREDICT_WINDOW then
			playLocal(Sounds.HitHead, "Feedback", Audio.HEAD_VOLUME * volume)
		end
	elseif relayed or now - lastPredictedHit > Audio.HIT_PREDICT_WINDOW then
		playLocal(Sounds.HitBody, "Feedback", Audio.HIT_VOLUME * volume)
	end
	if confirm.killed and (not rule or rule.marker) then
		HudController.killMarker()
	end
end

-- A hit by the fighter you spectate, drawn like your own (SpectateController).
function WeaponController.presentHit(confirm: Types.HitConfirm)
	onHitConfirm(confirm, true)
end

-- The server sends a fresh WeaponState for every new character, so the
-- loadout is rebuilt from that; here we only track life and death.
-- The end of a life: dying, or a respawn without dying (LoadCharacter). The
-- next life's WeaponState then equips (and first-draws) from scratch.
local function endLife()
	meleeEpoch += 1
	alive = false
	DashMod.resetGate(dashGate)
	table.clear(holstered)
	ViewmodelController.setLowered(false)
	triggerHeld = false
	burstQueue = 0
	cancelReload()
	equipped = nil
	table.clear(slots)
	if spectating then
		return -- the viewmodel, zoom and scope show who you're watching
	end
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
	Health.onDowned(humanoid, endLife)
end

-- Going down is also polled: in Studio tests (2026-11-07) the Downed
-- attribute's change signal didn't fire on our own simulated character, so
-- the gun stayed up after death.
local function pollDowned()
	if alive and Health.isDowned(player.Character) then
		endLife()
	end
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
			and not combatLocked()
			and not gunBlocked()
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
		-- Behind the barrier (the select, the 3-2-1) quick melee does nothing.
		if combatLocked() then
			return
		end
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
	RunService.Heartbeat:Connect(pollDowned)
	-- Studio only: the Workspace attribute DevAction ("inspect", "reload",
	-- "draw" = draw again, "fire" = one shot, or a slot name to switch to)
	-- runs that action, DevHold (true) holds the trigger, and DevAim (true)
	-- holds aim down sights, so scripts can review
	-- the animations (MCP key presses are unreliable).
	if RunService:IsStudio() then
		if studioSkinPreview then
			AudioController.preload({ SkinPreviewConfig.SHADOW_MIST.SHOT_PREVIEW })
		end
		StateValues.changed(Workspace, "DevAim"):Connect(function()
			devAim = StateValues.get(Workspace, "DevAim") == true
		end)
		-- DevHold (true): hold the trigger until it's cleared (sprays, by script).
		StateValues.changed(Workspace, "DevHold"):Connect(function()
			if StateValues.get(Workspace, "DevHold") == true then
				onFirePressed()
			else
				onFireReleased()
			end
		end)
		StateValues.changed(Workspace, "DevAction"):Connect(function()
			local action = StateValues.get(Workspace, "DevAction")
			if action == nil then
				return
			end
			StateValues.set(Workspace, "DevAction", nil)
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
					swing(s, StateValues.get(Workspace, "DevHeavy") == true)
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
