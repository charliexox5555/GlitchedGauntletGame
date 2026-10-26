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
local Audio = require(Shared.Config.Audio)
local Combat = require(Shared.Config.Combat)
local FireRate = require(Shared.Util.FireRate)
local Net = require(Shared.Net)
local Sounds = require(Shared.Config.Sounds)
local Spread = require(Shared.Util.Spread)
local Types = require(Shared.Types)
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
	ammo: number,
	lastFire: number,
	spinStart: number?,
	burstShots: number, -- same counter as the server's (FireRate.nextBurstCount)
	drawn: boolean, -- had its first draw this life (racked)
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
local burstQueue = 0 -- shots left in the current burst
local nextLeft = false -- akimbo: the next shot comes from the left gun
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

local function playLocal(id: string?, group: AudioController.Group, volume: number, pitch: number?)
	AudioController.play(id, { group = group, volume = volume, pitch = pitch })
end

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

local function startReload()
	local s = current()
	if not s or reloading or not alive then
		return
	end
	local config = s.config
	if config.magSize <= 0 or s.ammo >= config.magSize then
		return
	end
	burstQueue = 0
	local empty = s.ammo == 0
	local duration = if empty then config.emptyReloadTime else config.reloadTime
	reloadToken += 1
	local token = reloadToken
	reloading = { start = os.clock(), duration = duration, token = token }
	Net.event("Reload"):FireServer()
	-- Foley lands on the clip's own beats (Config/Viewmodel CLIP_SOUNDS).
	for _, beat in ViewmodelController.reload(duration, empty) do
		local id = if beat.sound == "MagOut"
			then Sounds.MagOut
			elseif beat.sound == "MagIn" then config.sounds.reload or Sounds.MagIn
			else config.sounds.cycle or Sounds.Rack
		task.delay(duration * beat.at, function()
			if reloadToken == token then
				playLocal(id, "Foley", Audio.FOLEY_VOLUME)
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
	pressQueued = false
	burstQueue = 0
	nextLeft = false
	bloom = 0
	-- The first draw of a life racks the action; later swaps just raise the gun.
	local first = not s.drawn
	s.drawn = true
	local config = s.config
	local duration = if first then config.firstEquipTime or config.equipTime else config.equipTime
	equipReadyAt = os.clock() + duration
	updateHudWeapon()
	playLocal(config.sounds.equip, "Foley", Audio.FOLEY_VOLUME)
	local token = reloadToken
	for _, beat in ViewmodelController.equip(config, first, duration) do
		local id = if beat.sound == "Rack" then config.sounds.cycle or Sounds.Rack else Sounds.MagIn
		task.delay(duration * beat.at, function()
			if reloadToken == token and current() == s then
				playLocal(id, "Foley", Audio.FOLEY_VOLUME)
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

	-- Akimbo guns alternate between their two guns.
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
		if not config.suppressed then
			EffectsController.tracer(from, result.finish, config, true)
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

	-- Feel.
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
	local adsKick = 1 - 0.35 * adsAlpha
	CameraController.kick(
		config.recoil.up * adsKick,
		(math.random() * 2 - 1) * config.recoil.side * adsKick,
		config.recoil.recover
	)
	CameraController.shake((0.04 + config.recoil.up * 0.1) * adsKick)
	ViewmodelController.fire(1 - 0.5 * adsAlpha, side)
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
			EffectsController.impact(result.Position, -aim, result.Instance)
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
	if not alive or os.clock() < equipReadyAt or reloading then
		return false
	end
	if s.config.magSize > 0 and s.ammo < 1 then
		return false
	end
	return true
end

local function onFirePressed()
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
end

local function onFireReleased()
	triggerHeld = false
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

	-- Aim down sights.
	local aimingWanted = s ~= nil
		and alive
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
	HudController.setCrosshairVisible(adsAlpha < 0.5 and not MovementController.isSprinting())

	-- Trigger.
	if s and alive then
		HudController.setSpread(currentSpread(s.config) + s.config.pelletSpread * 0.6)
		local mode = s.config.fireMode
		if mode == "Melee" then
			if pressQueued and now >= equipReadyAt then
				pressQueued = false
				swing(s)
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
		else
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
						drawn = false,
					}
					if equipped == slot then
						changedEquip = true
					end
				elseif not (reloading and equipped == slot) then
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
-- The end of a life: dying, or a respawn without dying (LoadCharacter). The
-- next life's WeaponState then equips (and first-draws) from scratch.
local function endLife()
	alive = false
	triggerHeld = false
	burstQueue = 0
	cancelReload()
	equipped = nil
	table.clear(slots)
	ViewmodelController.unequip()
	CameraController.setZoom(nil, 0)
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
	InputController.onPressed("Inspect", function()
		-- Fire, aim, reload and swapping cancel it (ViewmodelController).
		if alive and current() and not reloading and os.clock() >= equipReadyAt then
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
end

return WeaponController
