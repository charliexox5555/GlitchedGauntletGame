--!strict
-- Client side of the weapon system. Reads input, fires instantly for feel
-- (spread, recoil, effects, predicted hit marker) and sends what it saw to
-- the server, which re-checks everything and applies damage. Ammo and
-- loadout are mirrored from the server's WeaponState.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared.Config.Combat)
local Dev = require(Shared.Config.Dev)
local FireRate = require(Shared.Util.FireRate)
local Net = require(Shared.Net)
local Sounds = require(Shared.Config.Sounds)
local Spread = require(Shared.Util.Spread)
local Types = require(Shared.Types)
local Weapons = require(Shared.Config.Weapons)

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

local function currentSpread(config: WeaponConfig): number
	local move = MovementController.getState()
	local extra = (Combat.MOVE_SPREAD :: any)[move] or 0
	local hip = config.hipSpread + extra + bloom
	local adsMult = 1 + (config.adsSpreadMultiplier - 1) * ease(adsAlpha)
	return hip * adsMult
end

local function playLocal(id: string?, volume: number?, pitch: number?)
	if id then
		EffectsController.playSound(id, Workspace.CurrentCamera, volume, pitch)
	end
end

local function updateHudWeapon()
	local s = current()
	if s then
		HudController.setWeapon(s.config.displayName, s.ammo, s.config.magSize)
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
	chargeStart = nil
	local duration = if s.ammo == 0 then config.emptyReloadTime else config.reloadTime
	reloadToken += 1
	local token = reloadToken
	reloading = { start = os.clock(), duration = duration, token = token }
	Net.event("Reload"):FireServer()
	ViewmodelController.reload(duration)
	-- Reload foley timed to the animation.
	task.delay(duration * 0.2, function()
		if reloadToken == token then
			playLocal(Sounds.MagOut, 0.5)
		end
	end)
	task.delay(duration * 0.65, function()
		if reloadToken == token then
			playLocal(config.sounds.reload or Sounds.MagIn, 0.6)
		end
	end)
	if s.ammo == 0 then
		task.delay(duration * 0.88, function()
			if reloadToken == token then
				playLocal(Sounds.Cycle, 0.5)
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
	bloom = 0
	equipReadyAt = os.clock() + s.config.equipTime
	ViewmodelController.equip(s.config)
	updateHudWeapon()
	playLocal(s.config.sounds.equip, 0.5)
end

local function equip(slot: Slot)
	if not alive or equipped == slot or not slots[slot] then
		return
	end
	applyEquip(slot)
	Net.event("Equip"):FireServer(slot)
end

-- Firing ---------------------------------------------------------------------

type Cast = {
	hits: { { part: BasePart, position: Vector3 } },
	finish: Vector3,
	impact: { position: Vector3, normal: Vector3 }?,
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
				out.impact = { position = result.Position, normal = result.Normal }
				return out
			end
			EffectsController.impact(result.Position, result.Normal, config.tracerColor)
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
	playLocal(Sounds.DryFire, 0.4, 1.6)
end

local function fireShot(s: LocalSlot)
	local config = s.config
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local now = os.clock()
	local interval = FireRate.interval(config, s.spinStart, s.lastFire, now)
	if now < s.lastFire + interval then
		return
	end
	if not s.spinStart or now - s.lastFire > FireRate.SPIN_RESET then
		s.spinStart = now
	end
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
	local params = rayParams()

	local hits = {}
	local ends = {}
	local predictedHit = false
	local predictedHead = false
	local muzzle = ViewmodelController.muzzleCFrame()
	local from = if muzzle then muzzle.Position else origin
	for i, dir in dirs do
		local result = cast(origin, dir, config, params)
		for _, h in result.hits do
			table.insert(hits, { part = h.part, position = h.position, pellet = i })
			predictedHit = true
			if h.part.Name == "Head" then
				predictedHead = true
			end
			EffectsController.impact(h.position, -dir, config.tracerColor)
		end
		table.insert(ends, result.finish)
		if result.impact then
			EffectsController.impact(
				result.impact.position,
				result.impact.normal,
				config.tracerColor
			)
		end
		if config.fireMode == "Charge" then
			EffectsController.beam(from, result.finish, config.tracerColor)
		elseif not config.suppressed then
			EffectsController.tracer(from, result.finish, config.tracerColor)
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
	if muzzle then
		EffectsController.muzzleFlash(
			muzzle,
			config.tracerColor,
			if config.suppressed then 0.6 else 1
		)
	end
	playLocal(
		config.sounds.fire,
		config.sounds.fireVolume or 0.7,
		(config.sounds.firePitch or 1) * (0.96 + math.random() * 0.08)
	)
	local adsKick = 1 - 0.35 * adsAlpha
	CameraController.kick(
		config.recoil.up * adsKick,
		(math.random() * 2 - 1) * config.recoil.side * adsKick,
		config.recoil.recover
	)
	ViewmodelController.fire(1 - 0.5 * adsAlpha)
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
	playLocal(config.sounds.fire, 0.6, 1 + math.random() * 0.1)

	local origin = cam.CFrame.Position
	local aim = cam.CFrame.LookVector
	local params = rayParams()
	local result = Workspace:Spherecast(origin, 1.3, aim * melee.range, params)
	local hits = {}
	if result and result.Instance:IsA("BasePart") then
		local model = combatantOf(result.Instance)
		if model and aliveHumanoid(model) then
			table.insert(hits, { part = result.Instance, position = result.Position, pellet = 1 })
			EffectsController.impact(result.Position, -aim, config.tracerColor)
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
	if s.config.magSize > 0 and s.ammo <= 0 then
		return false
	end
	return true
end

local function onFirePressed()
	triggerHeld = true
	pressQueued = true
	local s = current()
	if not s then
		return
	end
	if s.config.magSize > 0 and s.ammo <= 0 and not reloading then
		dryFire()
		startReload()
		return
	end
	if s.config.fireMode == "Charge" and canShoot(s) then
		chargeStart = os.clock()
		Net.event("Charge"):FireServer()
		playLocal(s.config.sounds.charge, 0.5, 1.4)
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
		and InputController.isDown("Aim")
		and not MovementController.isSprinting()
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
	HudController.setCrosshairVisible(not scoped and adsAlpha < 0.6)

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

	-- Hide our own third-person gun in first person.
	local character = player.Character
	local world = character and character:FindFirstChild("WorldWeapon")
	if world then
		for _, d in world:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
			end
		end
	end

	-- Tell the server where we're aiming (third-person pose for others).
	local cam = Workspace.CurrentCamera
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
	HudController.damageNumber(confirm.damage, head)
	if head then
		playLocal(Sounds.HitHead, 0.45, 3.2)
	else
		playLocal(Sounds.HitBody, 0.35, 2.4)
	end
	if confirm.killed then
		HudController.killMarker()
		playLocal(Sounds.Kill, 0.5, 1.6)
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
