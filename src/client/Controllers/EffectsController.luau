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
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GunSounds = require(ReplicatedStorage.Shared.Config.GunSounds)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Types = require(ReplicatedStorage.Shared.Types)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)
local ViewmodelConfig = require(ReplicatedStorage.Shared.Config.Viewmodel)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Juice = require(ReplicatedStorage.Shared.Config.Juice)

local AudioController = require(script.Parent.AudioController)
local GunAnimator = require(script.Parent.Parent.Util.GunAnimator)
local ImpactFx = require(script.Parent.Parent.Util.ImpactFx)
local KnifeSwipeFx = require(script.Parent.Parent.Util.KnifeSwipeFx)
local MuzzleFx = require(script.Parent.Parent.Util.MuzzleFx)
local ShellFx = require(script.Parent.Parent.Util.ShellFx)
local ShotFxKit = require(script.Parent.Parent.Util.ShotFxKit)
local TracerFx = require(script.Parent.Parent.Util.TracerFx)

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

-- `own`: our own shot (a little fainter: it runs straight away from the eye;
-- fainter still from a suppressed gun, which shows enemies no tracer at all).
function EffectsController.tracer(from: Vector3, to: Vector3, config: WeaponConfig, own: boolean?)
	TracerFx.tracer(from, to, config, own)
end

-- A knife strike on the world: a long thin gouge along `along`, a short wide
-- tear for a heavy stab (Util/ImpactFx, Config/Animations KNIFE_MARK).
function EffectsController.slashMark(
	position: Vector3,
	normal: Vector3,
	along: Vector3,
	heavy: boolean?
)
	ImpactFx.slashMark(position, normal, along, heavy)
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
function EffectsController.knifeContact(position: Vector3)
	ImpactFx.knifeContact(position)
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
	noHole: boolean? -- the knife: its own gouge (slashMark), not a bullet hole
)
	ImpactFx.impact(position, normal, hit, material, size, noHole)
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
		EffectsController.muzzleFlash(muzzle, config, true)
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
-- offset on this client only (back along the barrel, muzzle up) and springs
-- home (Config/Juice WORLD_KICK). Part1 = Part0 * C0 * T * C1^-1, so moving
-- Part1 by K in its own space is C1 = K^-1 * C1.
type GunKick = {
	motor: Motor6D,
	base: CFrame,
	forward: Vector3,
	back: number,
	rise: number,
	k: number,
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
		local new: GunKick =
			{ motor = motor, base = motor.C1, forward = forward, back = 0, rise = 0, k = 0 }
		kick = new
		gunKicks[motor] = new
		motor.Destroying:Once(function()
			gunKicks[motor] = nil
		end)
	end
	local w = Juice.WORLD_KICK
	local recoil = config.recoil
	local up = if recoil then recoil.up else 0.4
	local active = kick :: GunKick
	active.back = w.back + w.backPerUp * up
	active.rise = math.rad(w.rise + w.risePerUp * up)
	active.k = 1
end

local function stepGunKicks(dt: number)
	local decay = math.exp(-Juice.WORLD_KICK.recover * dt)
	for motor, kick in gunKicks do
		if kick.k <= 0 then
			continue
		end
		kick.k *= decay
		if kick.k < 0.01 then
			kick.k = 0
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
		local k = kick.k
		local offset = CFrame.new(-kick.forward * kick.back * k)
			* CFrame.fromAxisAngle(axis.Unit, kick.rise * k)
		motor.C1 = offset:Inverse() * kick.base
	end
end

-- The body you hit flashes for a moment (Config/Juice HIT_FLASH).
type Flash = { highlight: Highlight, startedAt: number, time: number, from: number }
local flashes: { [Model]: Flash } = {}

local function bodyAt(position: Vector3): Model?
	local params = OverlapParams.new()
	local own = Players.LocalPlayer.Character
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if own then { own } else {}
	for _, part in Workspace:GetPartBoundsInRadius(position, Juice.HIT_FLASH.search, params) do
		local node: Instance? = part.Parent
		while node and node ~= Workspace do
			if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then
				return node
			end
			node = node.Parent
		end
	end
	return nil
end

function EffectsController.hitFlash(position: Vector3, head: boolean, killed: boolean)
	local body = bodyAt(position)
	if not body then
		return
	end
	local f = Juice.HIT_FLASH
	local spec = if killed then f.kill elseif head then f.head else f.body
	local flash = flashes[body]
	if not flash then
		local highlight = Instance.new("Highlight")
		highlight.Name = "HitFlash"
		highlight.OutlineTransparency = 1
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Adornee = body
		highlight.Parent = body
		local new: Flash = { highlight = highlight, startedAt = 0, time = 0, from = 1 }
		flash = new
		flashes[body] = new
	end
	local active = flash :: Flash
	active.highlight.FillColor = spec.color
	active.highlight.FillTransparency = spec.transparency
	active.highlight.Enabled = true
	active.startedAt = os.clock()
	active.time = spec.time
	active.from = spec.transparency
end

local function stepFlashes()
	local now = os.clock()
	for body, flash in flashes do
		local t = (now - flash.startedAt) / flash.time
		if t >= 1 or not body.Parent then
			flash.highlight:Destroy()
			flashes[body] = nil
		else
			flash.highlight.FillTransparency = flash.from + (1 - flash.from) * t
		end
	end
end

-- Where a remote shot from `origin` toward `finish` landed (for its impact).
local function remoteImpact(
	character: Model?,
	origin: Vector3,
	finish: Vector3,
	config: WeaponConfig
)
	local offset = finish - origin
	local dist = offset.Magnitude
	if dist < 0.5 or dist > config.range + 1 then
		return
	end
	local exclude: { Instance } = { effectsFolder() }
	if character then
		table.insert(exclude, character)
	end
	remoteParams.FilterDescendantsInstances = exclude
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
local onSpectatedShot: ((config: WeaponConfig, left: boolean) -> ())? = nil

function EffectsController.setSpectated(
	shooter: Instance?,
	onShot: ((config: WeaponConfig, left: boolean) -> ())?
)
	spectated = shooter
	onSpectatedShot = onShot
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

	local left = false
	local models = config.models
	if models and models.left then
		left = nextLeft[shooter] == true
		nextLeft[shooter] = not left
	end
	if spectated ~= nil and shooter == spectated then
		local hook = onSpectatedShot
		if hook then
			hook(config, left)
		end
		local sounds = GunSounds.get(weaponId)
		AudioController.playSound(sounds.fire, "Gun")
		if config.melee then
			return
		end
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
			remoteImpact(character, origin, e, config)
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
	AudioController.playSound(sounds.fireFar, "Enemy", from)
	local maxPellets =
		math.max(config.pellets, if config.altFire then config.altFire.pellets else 0)
	for i, e in ends do
		if typeof(e) ~= "Vector3" or i > maxPellets then
			continue
		end
		if not config.suppressed then
			EffectsController.tracer(from, e, config)
		end
		remoteImpact(character, origin, e, config)
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
	-- Load the atlas and textures up front so the first shot isn't missing them.
	task.spawn(function()
		local probe = Instance.new("Sound")
		probe.SoundId = Sounds.ATLAS
		local preload: { Instance | string } = { probe }
		for _, id in VFX do
			table.insert(preload, id)
		end
		for _, id in GunSounds.allIds() do
			if string.sub(id, 1, 6) ~= "atlas:" then
				local s = Instance.new("Sound")
				s.SoundId = id
				table.insert(preload, s)
			end
		end
		game:GetService("ContentProvider"):PreloadAsync(preload)
		probe:Destroy()
	end)
	Net.unreliable("ShotFx").OnClientEvent:Connect(onShotFx)
	if RunService:IsStudio() then
		Workspace:GetAttributeChangedSignal("VfxTimeScale"):Connect(function()
			local value = Workspace:GetAttribute("VfxTimeScale")
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
		stepFlashes()
		local dt = frameDt * ShotFxKit.getTimeScale()
		for _, animator in worldAnimators do
			animator:update(dt)
		end
		TracerFx.step(dt)
		ShellFx.step(dt)
		ImpactFx.step(dt)
		MuzzleFx.step(dt) -- advances the effects clock, then barrel wisps and light pops
	end)
end

return EffectsController
