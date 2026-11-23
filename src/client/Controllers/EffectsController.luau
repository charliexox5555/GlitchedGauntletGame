--!strict
-- Shot effects, realistic and simple (new direction, Art Direction → VFX):
-- muzzle flash (a fiery star burst down the barrel, a side flame, embers, a
-- warm light pop), smoke (a puff per shot, and wisps curling off a hot barrel
-- after a burst), brass ejected from `Eject`, tracers, and impacts that depend
-- on the surface: sparks off metal, dust and chips off concrete, splinters
-- off wood, dirt off ground, plus a bullet hole. Other players' shots get the
-- same effects (ShotFx) and their gun plays its Fire clip.
--
-- This controller owns our own shots from the viewmodel, other players' shots
-- (the ShotFx remote, their gun's Fire clip and kick, spectate and replay
-- shots), the hit flash on bodies, the Studio time scale and the per-frame
-- step. The effects themselves live in Util modules, and the public functions
-- here forward to them: Util/MuzzleFx (flashes, smoke, light pops),
-- Util/ShellFx (casings), Util/TracerFx, Util/ImpactFx (impacts, surfaces,
-- bullet holes, knife gouges and contact) and Util/KnifeSwipeFx, with shared
-- builders in Util/ShotFxKit.
--
-- Textures come from tools/vfx/make_real_vfx.py (Config/VfxTextures).
-- Everything that fires often is pooled: tracers, shells and bullet holes are
-- recycled, and bursts use shared emitters that are moved and Emit()ed, so an
-- automatic gun creates no instances per shot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Fighters = require(ReplicatedStorage.Shared.Util.Fighters)
local GunSounds = require(ReplicatedStorage.Shared.Config.GunSounds)
local Net = require(ReplicatedStorage.Shared.Net)
local Spring = require(ReplicatedStorage.Shared.Util.Spring)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local Types = require(ReplicatedStorage.Shared.Types)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)
local ViewmodelConfig = require(ReplicatedStorage.Shared.Config.Viewmodel)
local ShadowMist = require(ReplicatedStorage.Shared.Config.SkinPreview).SHADOW_MIST
local Tempest = require(ReplicatedStorage.Shared.Config.SkinPreview).TEMPEST
local RuinBlightedPresentation = require(ReplicatedStorage.Shared.Config.RuinBlightedPresentation)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Juice = require(ReplicatedStorage.Shared.Config.Juice)

local AudioController = require(script.Parent.AudioController)
local GunAudio = require(script.Parent.Parent.Util.GunAudio)
local GunAnimator = require(script.Parent.Parent.Util.GunAnimator)
local HitFx = require(script.Parent.Parent.Util.HitFx)
local ImpactFx = require(script.Parent.Parent.Util.ImpactFx)
local KnifeSwipeFx = require(script.Parent.Parent.Util.KnifeSwipeFx)
local MuzzleFx = require(script.Parent.Parent.Util.MuzzleFx)
local TempestFx = require(script.Parent.Parent.Util.TempestFx)
local TempestAudio = require(ReplicatedStorage.Shared.Config.TempestAudio)
local ShellFx = require(script.Parent.Parent.Util.ShellFx)
local ShotFxKit = require(script.Parent.Parent.Util.ShotFxKit)
local TracerFx = require(script.Parent.Parent.Util.TracerFx)
local BodyRecoil = require(script.Parent.Parent.Util.BodyRecoil)

type WeaponConfig = Types.WeaponConfig
type Surface = ImpactFx.Surface

local EffectsController = {}

local player = Players.LocalPlayer

-- Other players' shells and smoke only within this range of the camera.
local DETAIL_RANGE = 90

local effectsFolder = ShotFxKit.effectsFolder

-- Fire animations on other players' third-person guns.
local worldAnimators: { [Model]: GunAnimator.GunAnimator } = {}

-- Effects (forwarded to the Util modules) ------------------------------------------

-- Flash at a gun's Muzzle attachment. `firstPerson`: our viewmodel (scaled to
-- the viewmodel). `smoke`: false skips the smoke (far away).
function EffectsController.muzzleFlash(
	muzzle: Attachment,
	config: WeaponConfig,
	firstPerson: boolean,
	smoke: boolean?
)
	MuzzleFx.flash(muzzle, config, firstPerson, smoke)
end

-- Pump and bolt guns throw the casing when they cycle, a moment after the shot.
function EffectsController.ejectShell(
	eject: Attachment,
	config: WeaponConfig,
	scale: number,
	inherit: Vector3?
)
	ShellFx.eject(eject, config, scale, inherit)
end

local function cameraSkinLine(): string?
	local cam = Workspace.CurrentCamera
	local model = cam and cam:FindFirstChild("Viewmodel")
	local line = model and StateValues.get(model, "SkinLine")
	return if typeof(line) == "string" then line else nil
end

local function shadowShot(config: WeaponConfig): Color3?
	return if RuinBlightedPresentation[config.id] ~= nil
			and cameraSkinLine() == ShadowMist.LINE
		then ShadowMist.SHOT_TINT
		else nil
end

-- Our own camera gun wears the Tempest-Strike line (first-person shot effects).
local function tempestShot(): boolean
	return cameraSkinLine() == Tempest.LINE
end

-- `own`: our own shot (a little fainter: it runs straight away from the eye;
-- fainter still from a suppressed gun, which shows enemies no tracer at all).
function EffectsController.tracer(from: Vector3, to: Vector3, config: WeaponConfig, own: boolean?)
	local tempest = own == true and tempestShot()
	local tint = if own then (if tempest then Tempest.SHOT_TINT else shadowShot(config)) else nil
	TracerFx.tracer(from, to, config, own, tint, if tempest then Tempest.TRACER_WAKE else nil)
end

-- A knife strike on the world: a long thin gouge along `along`, a short wide
-- tear for a heavy stab (Util/ImpactFx, Config/Animations KNIFE_MARK).
function EffectsController.slashMark(
	position: Vector3,
	normal: Vector3,
	along: Vector3,
	heavy: boolean?,
	spectral: boolean?
)
	ImpactFx.slashMark(position, normal, along, heavy, spectral)
end

-- Which family of surface a part is (knife wall sounds, impacts).
function EffectsController.surfaceOf(hit: BasePart, material: Enum.Material?): Surface
	return ImpactFx.surfaceOf(hit, material)
end

-- The knife's swipe streak in first person (Util/KnifeSwipeFx). `arc`: three
-- points in camera space (start, bend, end) of a quadratic curve, `delay`:
-- seconds until the head starts, `sweep`: seconds for the head to cross,
-- `strength` 0..1 (a hit is bolder).
function EffectsController.knifeSwipe(
	arc: { Vector3 },
	delay: number,
	sweep: number,
	strength: number
)
	KnifeSwipeFx.swipe(arc, delay, sweep, strength)
end

-- The blade landing on a body: a small white flash, one frame after contact.
function EffectsController.knifeContact(position: Vector3, spectral: boolean?)
	ImpactFx.knifeContact(position, spectral)
end

-- A shot landing at `position`. `hit` is the part it hit: characters get a
-- small puff (no blood); the world gets an impact for its surface and a
-- bullet hole. `size` scales the hole (pellets are smaller).
function EffectsController.impact(
	position: Vector3,
	normal: Vector3,
	hit: Instance?,
	material: Enum.Material?,
	size: number?,
	noHole: boolean?, -- the knife: its own gouge (slashMark), not a bullet hole
	spectral: boolean?
)
	ImpactFx.impact(position, normal, hit, material, size, noHole, spectral)
end

-- Our own shot passing through or into something on its path (penetration hits,
-- bodies): a Tempest-Strike shot draws its own strike there too, never the
-- orange flash.
function EffectsController.ownImpact(position: Vector3, normal: Vector3, hit: Instance?)
	local tempest = tempestShot()
	ImpactFx.impact(position, normal, hit, nil, nil, false, false, tempest)
	if tempest and hit and hit:IsA("BasePart") then
		local model = hit:FindFirstAncestorOfClass("Model")
		if not (model and model:FindFirstChildOfClass("Humanoid")) then
			TempestFx.splash(position, normal) -- a wall, not a body (bodies keep the hit puff)
		end
	end
end

function EffectsController.localWallImpact(
	config: WeaponConfig,
	position: Vector3,
	normal: Vector3,
	hit: BasePart,
	material: Enum.Material,
	size: number
)
	local tempest = tempestShot()
	ImpactFx.impact(
		position,
		normal,
		hit,
		material,
		size,
		false,
		shadowShot(config) ~= nil,
		tempest
	)
	if tempest then
		TempestFx.splash(position, normal)
		local set = TempestAudio.guns[config.id]
		if set then
			AudioController.playSound(set.impact, "Foley", position) -- under the surface sound
		end
	end
end

-- Our own shot -------------------------------------------------------------------
-- From the viewmodel: flash and casing. `side` is the left gun of an akimbo
-- pair.
local viewmodelPoints: { [Instance]: { [string]: Attachment } } = setmetatable({}, { __mode = "k" }) :: any

local function viewmodelPoint(side: string?, name: string): Attachment?
	local cam = Workspace.CurrentCamera
	local model = cam
		and cam:FindFirstChild(if side == "Left" then "ViewmodelLeft" else "Viewmodel")
	if not model then
		return nil
	end
	local points = viewmodelPoints[model]
	if not points then
		points = {}
		viewmodelPoints[model] = points
	end
	local a = points[name]
	if not a or not a.Parent then
		local found = model:FindFirstChild(name, true)
		if not found or not found:IsA("Attachment") then
			return nil
		end
		a = found
		points[name] = found
	end
	return a
end

local function rootVelocity(character: Model?): Vector3
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.AssemblyLinearVelocity else Vector3.zero
end

-- `muzzleName`: which muzzle fired (a double barrel's "MuzzleLower").
function EffectsController.localShot(config: WeaponConfig, side: string?, muzzleName: string?)
	local scale = config.viewmodelScale or ViewmodelConfig.SCALE
	local muzzle = viewmodelPoint(side, muzzleName or "Muzzle")
	if muzzle then
		local line = cameraSkinLine()
		if line == Tempest.LINE then
			TempestFx.flash(muzzle, scale)
		elseif line == "Slipframe" and config.id == "Guardian" then
			MuzzleFx.flash(muzzle, config, true, nil, nil, "Slipframe")
		else
			MuzzleFx.flash(muzzle, config, true, nil, shadowShot(config))
		end
	end
	local eject = if config.shellsOnFire ~= false then viewmodelPoint(side, "Eject") else nil
	if eject then
		ShellFx.updateFilter()
		EffectsController.ejectShell(eject, config, scale, rootVelocity(player.Character))
	end
end

-- Other players' shots ---------------------------------------------------------

-- Akimbo guns: which side each shooter fires next (weak keys, players leave).
local nextLeft: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local nextMuzzle: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local remoteParams = RaycastParams.new()
remoteParams.FilterType = Enum.RaycastFilterType.Exclude

-- A named attachment on a character's world weapon (`left`: the left gun).
local function worldPoint(character: Model?, name: string, left: boolean?): Attachment?
	local weapon = character
		and character:FindFirstChild(if left then "WorldWeaponLeft" else "WorldWeapon")
	if not weapon then
		return nil
	end
	local a = weapon:FindFirstChild(name, true)
	return if a and a:IsA("Attachment") then a else nil
end

local function animateWorldWeapon(character: Model?, modelName: string, clipId: string)
	local weapon = character and character:FindFirstChild(modelName)
	if not weapon or not weapon:IsA("Model") then
		return
	end
	local animator = worldAnimators[weapon]
	if not animator then
		animator = GunAnimator.new(weapon, clipId, 1)
		worldAnimators[weapon] = animator
		weapon.Destroying:Once(function()
			worldAnimators[weapon] = nil
		end)
	end
	animator:play("Fire")
end

-- Other players' guns kick in their hands on every shot: the grip's C1 is
-- offset on this client only (back along the barrel, muzzle up) by a spring
-- that each shot pushes (Config/Juice WORLD_KICK). Part1 = Part0 * C0 * T *
-- C1^-1, so moving Part1 by K in its own space is C1 = K^-1 * C1.
type GunKick = {
	motor: Motor6D,
	base: CFrame,
	forward: Vector3,
	spring: Spring.Spring, -- X = studs back, Y = radians muzzle up
	limit: Vector3,
	live: boolean,
}
local gunKicks: { [Motor6D]: GunKick } = {}

local function kickWorldGun(
	character: Model?,
	modelName: string,
	config: WeaponConfig,
	muzzle: Attachment?
)
	local weapon = character and character:FindFirstChild(modelName)
	local motor = weapon and weapon:FindFirstChild("WeaponGrip", true)
	if not motor or not motor:IsA("Motor6D") or not motor.Part1 then
		return
	end
	local w = Juice.WORLD_KICK
	local kick = gunKicks[motor]
	if not kick then
		local forward = Vector3.new(0, 0, -1)
		local handle = motor.Part1
		if muzzle and handle then
			local toMuzzle = handle.CFrame:PointToObjectSpace(muzzle.WorldPosition)
			if toMuzzle.Magnitude > 0.05 then
				forward = toMuzzle.Unit
			end
		end
		local new: GunKick = {
			motor = motor,
			base = motor.C1,
			forward = forward,
			spring = Spring.new(w.frequency * w.frequency, 2 * w.damping * w.frequency),
			limit = Vector3.zero,
			live = false,
		}
		kick = new
		gunKicks[motor] = new
		motor.Destroying:Once(function()
			gunKicks[motor] = nil
		end)
	end
	local recoil = config.recoil
	local up = if recoil then recoil.up else 0.4
	local peak = Vector3.new(w.back + w.backPerUp * up, math.rad(w.rise + w.risePerUp * up), 0)
	local active = kick :: GunKick
	-- A push, not a jump: a spring left alone after a push of v swells to
	-- about v / (frequency * e), so this one shot peaks at `peak`.
	active.spring:impulse(peak * w.frequency * math.exp(1))
	active.limit = peak * w.hold
	active.live = true
end

local function stepGunKicks(dt: number)
	for motor, kick in gunKicks do
		if not kick.live then
			continue
		end
		local spring = kick.spring
		local at = spring:update(dt)
		local limit = kick.limit
		if at.X > limit.X or at.Y > limit.Y then
			-- Held fire: ride at the cap instead of winding up.
			at = Vector3.new(math.min(at.X, limit.X), math.min(at.Y, limit.Y), 0)
			spring.position = at
			spring.velocity =
				Vector3.new(math.min(spring.velocity.X, 0), math.min(spring.velocity.Y, 0), 0)
		end
		if at.Magnitude < 1e-3 and spring.velocity.Magnitude < 1e-2 then
			spring.position = Vector3.zero
			spring.velocity = Vector3.zero
			kick.live = false
			motor.C1 = kick.base
			continue
		end
		local handle = motor.Part1
		if not handle then
			continue
		end
		-- Muzzle up: turn the barrel toward the world's up, seen from the gun.
		local upLocal = handle.CFrame:VectorToObjectSpace(Vector3.yAxis)
		local axis = kick.forward:Cross(upLocal)
		if axis.Magnitude < 1e-3 then
			continue
		end
		local offset = CFrame.new(-kick.forward * at.X) * CFrame.fromAxisAngle(axis.Unit, at.Y)
		motor.C1 = offset:Inverse() * kick.base
	end
end

-- The body you hit: a white-then-red flash over the whole body (limb meshes
-- too), a slash, and fire from the head on a headshot (Util/HitFx, numbers in
-- Config/HitFx).
function EffectsController.hitFlash(position: Vector3, head: boolean, killed: boolean)
	HitFx.hit(position, head, killed)
end

-- Where a remote shot from `origin` toward `finish` landed (for its impact).
local function remoteImpact(origin: Vector3, finish: Vector3, config: WeaponConfig)
	local offset = finish - origin
	local dist = offset.Magnitude
	if dist < 0.5 or dist > config.range + 1 then
		return
	end
	local result = Workspace:Raycast(origin, offset * ((dist + 0.5) / dist), remoteParams)
	if result then
		EffectsController.impact(
			result.Position,
			result.Normal,
			result.Instance,
			result.Material,
			if config.pellets > 1 then 0.65 else 1
		)
	end
end

-- `shooter` is another player, or a test range dummy model (its harmless
-- tracers use the same effects).
-- Spectating in first person (SpectateController): that fighter's shots are
-- drawn like your own, from the view gun, and `onSpectatedShot` plays the
-- view gun's fire clip.
local spectated: Instance? = nil
local onSpectatedShot: ((config: WeaponConfig, left: boolean) -> any)? = nil
-- Seconds the spectated fighter's shots wait before they're drawn: their view
-- is drawn a little in the past (SpectateController, the look stream), so
-- the shot waits until the crosshair is where they fired from.
local spectatedDelay = 0

function EffectsController.setSpectated(
	shooter: Instance?,
	onShot: ((config: WeaponConfig, left: boolean) -> any)?
)
	spectated = shooter
	onSpectatedShot = onShot
	spectatedDelay = 0
end

function EffectsController.setSpectatedDelay(seconds: number)
	spectatedDelay = if seconds == seconds then math.clamp(seconds, 0, 0.5) else 0
end

-- Impacts from `shooter`'s shot ignore them and their allies.
local function setImpactFilter(shooter: Instance, character: Model?)
	local exclude: { Instance } = { effectsFolder() }
	if character then
		table.insert(exclude, character)
	end
	for _, fighter in Fighters.all(nil) do
		if fighter.body ~= character and Teams.isAlly(shooter, fighter.holder) then
			table.insert(exclude, fighter.body)
		end
	end
	remoteParams.FilterDescendantsInstances = exclude
end

-- The spectated fighter's shot, drawn like your own from the view gun.
local function drawSpectated(
	shooter: Instance,
	config: WeaponConfig,
	weaponId: string,
	left: boolean,
	origin: Vector3,
	ends: { Vector3 }
)
	local hook = onSpectatedShot
	-- the hook returns the shot's sound options for the watched gun's skin (Controllers/SpectateController)
	local options = if hook then hook(config, left) else nil
	if config.melee then
		AudioController.playSound(GunSounds.get(weaponId).fire, "Gun")
		return
	end
	-- (Drawn a beat later than it arrived: another shot may have set the filter.)
	setImpactFilter(
		shooter,
		if shooter:IsA("Player")
			then shooter.Character
			elseif shooter:IsA("Model") then shooter
			else nil
	)
	-- The spectated player's gun, as your own sounds, their skin's included (Util/GunAudio).
	GunAudio.shot(shooter, config, if typeof(options) == "table" then options else nil)
	local muzzleName = "Muzzle"
	local muzzles = config.muzzles
	if muzzles and #muzzles > 1 then
		local n = (nextMuzzle[shooter] or 0) % #muzzles + 1
		nextMuzzle[shooter] = n
		muzzleName = muzzles[n]
	end
	local side = if left then "Left" else nil
	EffectsController.localShot(config, side, muzzleName)
	local muzzle = viewmodelPoint(side, muzzleName) or viewmodelPoint(side, "Muzzle")
	local from = if muzzle then muzzle.WorldPosition else origin
	local maxPellets =
		math.max(config.pellets, if config.altFire then config.altFire.pellets else 0)
	for i, e in ends do
		if typeof(e) ~= "Vector3" or i > maxPellets then
			continue
		end
		if not config.suppressed then
			EffectsController.tracer(from, e, config, true)
		end
		remoteImpact(origin, e, config)
	end
end

local function onShotFx(shooter: Instance, weaponId: string, origin: Vector3, ends: { Vector3 })
	if
		typeof(weaponId) ~= "string"
		or typeof(shooter) ~= "Instance"
		or typeof(origin) ~= "Vector3"
		or typeof(ends) ~= "table"
	then
		return
	end
	local config = Weapons.get(weaponId)
	if not config then
		return
	end
	local character: Model? = nil
	if shooter:IsA("Player") then
		character = shooter.Character
	elseif shooter:IsA("Model") then
		character = shooter
	end
	if not config.melee then
		setImpactFilter(shooter, character)
	end

	local left = false
	local models = config.models
	if models and models.left then
		left = nextLeft[shooter] == true
		nextLeft[shooter] = not left
	end
	if spectated ~= nil and shooter == spectated then
		if spectatedDelay > 0.005 then
			task.delay(spectatedDelay, function()
				if spectated == shooter then
					drawSpectated(shooter, config, weaponId, left, origin, ends)
				end
			end)
		else
			drawSpectated(shooter, config, weaponId, left, origin, ends)
		end
		return
	end
	if left and models and models.left then
		animateWorldWeapon(character, "WorldWeaponLeft", models.left)
	else
		animateWorldWeapon(character, "WorldWeapon", if models then models.right else weaponId)
	end
	if not config.melee then
		kickWorldGun(
			character,
			if left then "WorldWeaponLeft" else "WorldWeapon",
			config,
			worldPoint(character, "Muzzle", left)
		)
		-- ...and the body takes the rest of it (Util/BodyRecoil).
		BodyRecoil.shot(character, config)
	end
	-- Guns with several muzzles fire them in turn (we don't know their
	-- ammo, so just alternate per shooter).
	local muzzleName = "Muzzle"
	local muzzles = config.muzzles
	if muzzles and #muzzles > 1 then
		local n = (nextMuzzle[shooter] or 0) % #muzzles + 1
		nextMuzzle[shooter] = n
		muzzleName = muzzles[n]
	end
	local muzzle = worldPoint(character, muzzleName, left) or worldPoint(character, "Muzzle")
	local from = if muzzle then muzzle.WorldPosition else origin
	local sounds = GunSounds.get(weaponId)
	if config.melee then
		AudioController.playSound(sounds.fireFar, "Enemy", from)
		return
	end
	local cam = Workspace.CurrentCamera
	local near = cam ~= nil and (cam.CFrame.Position - from).Magnitude < DETAIL_RANGE
	if muzzle then
		EffectsController.muzzleFlash(muzzle, config, false, near)
	end
	if near and config.shellsOnFire ~= false then
		local eject = worldPoint(character, "Eject", left)
		if eject then
			ShellFx.updateFilter()
			EffectsController.ejectShell(eject, config, 1, rootVelocity(character))
		end
	end
	-- Their shot, 3D at the muzzle: first shot, random takes, a tail with every
	-- shot faded by the next (Util/GunAudio, per shooter).
	-- Always the stock sound for other players (owner 2026-11-23: skins sound different only on your own gun,
	-- or the one you spectate).
	GunAudio.shot(shooter, config, { at = from })
	local maxPellets =
		math.max(config.pellets, if config.altFire then config.altFire.pellets else 0)
	for i, e in ends do
		if typeof(e) ~= "Vector3" or i > maxPellets then
			continue
		end
		if not config.suppressed then
			EffectsController.tracer(from, e, config)
		end
		remoteImpact(origin, e, config)
	end
end

-- A recorded shot played again (Controllers/ReplayController): `shooter` is
-- the replay's copy of the body, drawn like anyone else's shot.
function EffectsController.playShot(
	shooter: Model,
	weaponId: string,
	origin: Vector3,
	ends: { Vector3 }
)
	onShotFx(shooter, weaponId, origin, ends)
end

function EffectsController.start()
	effectsFolder()
	-- AudioController preloads the recordings, and this primes the shot textures.
	task.spawn(function()
		local preload: { string } = {}
		for _, id in VFX do
			table.insert(preload, id)
		end
		game:GetService("ContentProvider"):PreloadAsync(preload)
	end)
	Net.unreliable("ShotFx").OnClientEvent:Connect(onShotFx)
	if RunService:IsStudio() then
		StateValues.changed(Workspace, "VfxTimeScale"):Connect(function()
			local value = StateValues.get(Workspace, "VfxTimeScale")
			local timeScale = if typeof(value) == "number" then math.clamp(value, 0, 1) else 1
			ShotFxKit.setTimeScale(timeScale)
			for _, root in { effectsFolder(), Workspace.Terrain, Workspace.CurrentCamera } do
				for _, d in root:GetDescendants() do
					if d:IsA("ParticleEmitter") then
						d.TimeScale = timeScale
					end
				end
			end
		end)
	end
	RunService.RenderStepped:Connect(function(frameDt)
		stepGunKicks(frameDt)
		BodyRecoil.step(frameDt)
		local dt = frameDt * ShotFxKit.getTimeScale()
		HitFx.step(dt)
		for _, animator in worldAnimators do
			animator:update(dt)
		end
		TracerFx.step(dt)
		ShellFx.step(dt)
		ImpactFx.step(dt)
		MuzzleFx.step(dt) -- advances the effects clock, then barrel wisps and light pops
		TempestFx.step(dt)
	end)
end

return EffectsController
