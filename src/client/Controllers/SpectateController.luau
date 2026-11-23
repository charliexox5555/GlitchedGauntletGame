--!strict
-- Death camera and first-person spectating (vault/05 Production/Match
-- Structure Revamp.md, phase B).
--
-- When you go down, the camera pulls up and back out of your head to watch
-- your body fall (DeathFxController draws the fall). Then you see through a
-- living teammate's eyes, with their gun and arms. Click / LT-RT / the bar's
-- arrows cycle teammates. In the round-end seconds with no teammate alive (or
-- in 1v1) you watch the enemy who killed you. A new life ends it all.
--
-- Their view is rebuilt from what already replicates: their root (the eye
-- sits where their own camera does, lowered by the crouch / slide spring of
-- shared/CameraDrop on `MoveState`), their look (Util/Fighters.lookOf: a
-- bot's `AimGunYaw` / `AimGunPitch` while it's watched, else body yaw and
-- `AimPitch`), `Aiming` (players: WeaponService's Aim remote; bots:
-- Bots/Brain), the `WorldWeapon`'s `WeaponId`, `ReloadAt` /
-- `ReloadFor`, `SwingAt` / `SwingStep` / `SwingHeavy`, `ModHeld`,
-- `MoveState` and their `ShotFx`. Their crosshair, aim vignette and ADS
-- sounds are rebuilt the same way. The server only streams their
-- surroundings to you (SpectateService, `Spectate` remote).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CameraDrop = require(ReplicatedStorage.Shared.CameraDrop)
local Health = require(ReplicatedStorage.Shared.Health)
local Mods = require(ReplicatedStorage.Shared.Mods)
local Accuracy = require(ReplicatedStorage.Shared.Util.Accuracy)
local Ease = require(ReplicatedStorage.Shared.Util.Ease)
local Fighters = require(ReplicatedStorage.Shared.Util.Fighters)
local PlayerTags = require(script.Parent.Parent.Util.PlayerTags)
local GunSounds = require(ReplicatedStorage.Shared.Config.GunSounds)
local Juice = require(ReplicatedStorage.Shared.Config.Juice)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Net = require(ReplicatedStorage.Shared.Net)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Types = require(ReplicatedStorage.Shared.Types)
local VM = require(ReplicatedStorage.Shared.Config.Viewmodel)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local AudioController = require(script.Parent.AudioController)
local CameraController = require(script.Parent.CameraController)
local DeathFxController = require(script.Parent.DeathFxController)
local EffectsController = require(script.Parent.EffectsController)
local HudController = require(script.Parent.HudController)
local InputController = require(script.Parent.InputController)
local ViewmodelController = require(script.Parent.ViewmodelController)
local WeaponController = require(script.Parent.WeaponController)
local DeathScreen = require(script.Parent.Parent.Util.DeathScreen)
local Ui = require(script.Parent.Parent.Util.Ui)
local Watched = require(script.Parent.Parent.Util.Watched)
local ModAudio = require(script.Parent.Parent.Util.ModAudio)
local ModProps = require(script.Parent.Parent.Util.ModProps)
local TeamColor = require(script.Parent.Parent.Util.TeamColor)
local ModsConfig = require(ReplicatedStorage.Shared.Config.Mods)

type WeaponConfig = Types.WeaponConfig

local SpectateController = {}

local S = Juice.SPECTATE
local player = Players.LocalPlayer

type Mode = "Off" | "DeathCam" | "Watch"

-- A fighter: `holder` carries the attributes (a Player, or a bot's model);
-- `body` is the character model.
type Fighter = Fighters.Fighter

local mode: Mode = "Off"
local target: Fighter? = nil
local killer: Instance? = nil
local killedWith = "" -- the gun or Mod id that killed you (the Killed event)
local killedHead = false
local myBody: Model? = nil

-- Death camera.
local deathFrom: CFrame = CFrame.identity
local deathGoal: Vector3 = Vector3.zero
local deathLook: Vector3 = Vector3.zero
local deathAt = 0

-- The watched view.
local viewPos: Vector3? = nil
local viewYaw = 0
local viewPitch = 0
local adsAlpha = 0
local equippedId: string? = nil
local equippedConfig: WeaponConfig? = nil
local lastReloadAt = 0
local lastStopAt = 0 -- the last shell-reload stop seen (ReloadStopAt)
local reloadToken = 0 -- bumps on every new reload / target / gun: stale foley stays quiet
-- Their shell-by-shell reload, played like your own (WeaponController):
-- Start into the loading pose, an Insert per shell, then End (a rack after
-- an empty one). `slow`: each phase's time times this (from ReloadFor).
type ShellRun = {
	config: WeaponConfig,
	phase: "Start" | "Insert" | "End",
	doneAt: number, -- os.clock() the current phase ends
	inserted: number,
	needed: number,
	empty: boolean,
	slow: number,
}
local shellRun: ShellRun? = nil
-- Their held Mod, drawn like your own (ModController): the item in the free
-- hand (or Firewall's flame hand), its pin pull, then the throw / place /
-- heal / bow release on their use, and back to the gun.
local heldSlot = 0 -- the slot they hold (ModHeld), 0 = the gun
local heldId: string? = nil
local lastUseAt = 0 -- their last Mod use (ModUseAt)
local usedAt = -math.huge -- os.clock() of the last use we played
local itemToken = 0 -- bumps on every take-out / put-away: stale delays do nothing
-- Their Dash / Updraft / Recall marks (on their character), for the gestures.
local lastDashAt = 0
local lastUpdraftAt = 0
local lastWindup = 0
local lastSwingAt = 0
local firstEquip = true -- the gun they already hold comes up with no draw
local wasAiming: boolean? = nil -- nil: not known yet (no flick on the first frame)
local drop = CameraDrop.new() -- their crouch / slide eye height
local wasAirborne = false
local fallSpeed = 0 -- the fastest they fell this time in the air
local landedAt = -math.huge -- os.clock() of their last landing (crosshair spread)
-- Their spray, for the crosshair (Util/Accuracy, like WeaponController's).
local heat = 0
local lastShotAt = -math.huge
local wasLowered = false
local targetDownAt: number? = nil
-- Who took each body down (the Killed event), so the view can follow the
-- kill when the fighter you watch goes down with no teammate left.
local killerOf: { [Model]: Instance } = setmetatable({}, { __mode = "k" }) :: any
local cutQueued = false -- a cut to the next fighter is on its way (this frame)
local downViewAt: number? = nil -- os.clock() the watched fighter went down with nobody to cut to
local hiddenConns: { RBXScriptConnection } = {}
local hiddenParts: { Instance } = {}
local lastFightAt = -math.huge -- when the phase was last Live / SuddenDeath -- the watched body's parts, kept hidden every frame
local sendAt: number? = nil -- the Spectate request goes once the choice settles
local sentTarget: Instance? = nil
local SEND_SETTLE = 0.25

-- The look stream (Services/LookStream): the watched fighter's aim samples
-- on the server's clock, drawn `lookDelay` in the past with a cubic Hermite
-- between them, so the view turns as smoothly as theirs did. Yaw is unwrapped
-- as it arrives (no jump at +-180 degrees).
local LOOK_KEEP = 64 -- samples kept (about 2 s)
local LOOK_PACKET = 16
local look = {
	holder = nil :: Instance?,
	t = {} :: { number },
	yaw = {} :: { number },
	pitch = {} :: { number },
	latency = nil :: number?, -- smoothed one-way delay (server time now - sample time on arrival)
}
local lookDelay = Juice.SPECTATE.lookDelayMin + Juice.SPECTATE.lookJitter
local streaming = false -- the view is on the stream (not the replicated look)
local shotDelay = 0 -- seconds their shots and hits wait for the drawn view (the stream's lag)
-- What their bottom HUD shows (gun, rounds, reload), so it's written only on a change.
local shownGun: string? = nil
local shownAmmo: number? = nil
local shownReserve: number? = nil
local shownReload: number? = nil

-- UI.
local blink: Frame? = nil

-- Helpers -----------------------------------------------------------------------

local function humanoidOf(body: Model?): Humanoid?
	return if body then body:FindFirstChildOfClass("Humanoid") else nil
end

local function alive(body: Model?): boolean
	return body ~= nil and body.Parent ~= nil and Health.isAlive(humanoidOf(body))
end

local function nameOf(holder: Instance): string
	if holder:IsA("Player") then
		return holder.DisplayName
	end
	return holder.Name
end

-- Living teammates, in a stable order (so cycling goes round).
local function teammates(): { Fighter }
	local mine = Teams.of(player)
	local list: { Fighter } = {}
	for _, f in Fighters.all(player) do
		if mine ~= nil and Teams.of(f.holder) == mine and alive(f.body) then
			table.insert(list, f)
		end
	end
	table.sort(list, function(a, b)
		return nameOf(a.holder) < nameOf(b.holder)
	end)
	return list
end

local function killerFighter(): Fighter?
	local k = killer
	if not k then
		return nil
	end
	local body: Model? = if k:IsA("Player") then k.Character elseif k:IsA("Model") then k else nil
	if body and alive(body) then
		return { holder = k, body = body }
	end
	return nil
end

-- Who to cut to the moment the fighter you watch goes down: another living
-- teammate, else whoever took them down (the round is over for your side;
-- the server allows it from the round end, which follows within a frame or two).
local function nextAfterDown(f: Fighter): Fighter?
	for _, other in teammates() do
		if other.body ~= f.body then
			return other
		end
	end
	local k = killerOf[f.body]
	if k then
		local body: Model? = if k:IsA("Player")
			then k.Character
			elseif k:IsA("Model") then k
			else nil
		if body and body ~= f.body and alive(body) then
			return { holder = k, body = body }
		end
	end
	return nil
end

-- Who to watch now: a living teammate, else (round end) your killer.
local function pickTarget(): Fighter?
	local team = teammates()
	if #team > 0 then
		return team[1]
	end
	if MatchState.phase() == "RoundEnd" then
		return killerFighter()
	end
	return nil
end

local function numberAttr(holder: Instance, name: string): number
	local v = StateValues.get(holder, name)
	return if typeof(v) == "number" and v == v then v else 0
end

-- Their body is out of view while you're in their head.
local function setBodyHidden(body: Model?, hide: boolean)
	for _, c in hiddenConns do
		c:Disconnect()
	end
	table.clear(hiddenConns)
	table.clear(hiddenParts)
	if not body then
		return
	end
	-- A downed body stays hidden: DeathFxController hid it for its fall.
	local value = if hide or not alive(body) then 1 else 0
	for _, d in body:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = value
			if hide then
				table.insert(hiddenParts, d)
			end
		end
	end
	if hide then
		table.insert(
			hiddenConns,
			body.DescendantAdded:Connect(function(d)
				if d:IsA("BasePart") or d:IsA("Decal") then
					d.LocalTransparencyModifier = 1
					table.insert(hiddenParts, d)
				end
			end)
		)
	end
end

-- UI ------------------------------------------------------------------------------

local function buildUi()
	local gui = Ui.make("ScreenGui", {
		Name = "Spectate",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None, -- full-bleed overlays, under the notch too
		SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
		ClipToDeviceSafeArea = false,
		DisplayOrder = 5,
	}, player:WaitForChild("PlayerGui"))
	blink = Ui.make("Frame", {
		Name = "Blink",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 10,
	}, gui)
end

local function doBlink()
	local b = blink
	if not b then
		return
	end
	b.BackgroundTransparency = 0
	TweenService:Create(b, TweenInfo.new(S.fadeTime * 2), { BackgroundTransparency = 1 }):Play()
end

-- What the death screen shows for a fighter (Util/DeathScreen).
local BOT_HEAD = "rbxassetid://119185654291939"
local function fighterView(holder: Instance): DeathScreen.Fighter
	return {
		name = nameOf(holder),
		ally = Teams.of(holder) == Teams.of(player),
		image = PlayerTags.headshot(
			if holder:IsA("Player")
				then holder.UserId
				else StateValues.get(holder, "PortraitUserId"),
			BOT_HEAD
		),
	}
end

-- Desktop: who killed you, with what, and their HP left.
local function showKilledBy()
	local k = killer
	if not k or k == player or k == myBody then
		return -- the zone, a fall, your own Molly
	end
	local view = fighterView(k) :: any
	local def = Mods.def(killedWith)
	local config = if def then nil else Weapons.get(killedWith)
	view.weapon = if def then def.icon else Theme.GUN[killedWith] or ""
	view.isMod = def ~= nil
	view.gun = if def then def.name elseif config then config.displayName else ""
	view.head = killedHead
	local body: Model? = if k:IsA("Player") then k.Character elseif k:IsA("Model") then k else nil
	view.hp = if body and alive(body) then Health.get(humanoidOf(body)) else nil
	DeathScreen.killedBy(view)
end

-- The Studio-built spectate bar (DeathScreen) on every device; the old
-- code-built bar is gone (owner 2026-11-22).
local function setBar(f: Fighter?)
	if f then
		DeathScreen.spectate(fighterView(f.holder))
	else
		DeathScreen.hide()
	end
end

-- The look stream ----------------------------------------------------------------

local function resetLook(holder: Instance?)
	look.holder = holder
	table.clear(look.t)
	table.clear(look.yaw)
	table.clear(look.pitch)
	look.latency = nil
	streaming = false
end

local function finiteNumber(v: number): boolean
	return v == v and v > -math.huge and v < math.huge
end

local function onLookRelay(holder: unknown, data: unknown)
	if
		typeof(holder) ~= "Instance"
		or holder ~= look.holder
		or typeof(data) ~= "buffer"
		or buffer.len(data) ~= LOOK_PACKET
	then
		return
	end
	local t = buffer.readf64(data, 0)
	local yaw = buffer.readf32(data, 8)
	local pitch = buffer.readf32(data, 12)
	if not (finiteNumber(t) and finiteNumber(yaw) and finiteNumber(pitch)) then
		return
	end
	local ts = look.t
	local n = #ts
	if n > 0 then
		if t <= ts[n] then
			return -- late (unreliable packets can swap)
		end
		local prev = look.yaw[n]
		yaw = prev + ((yaw - prev + math.pi) % (2 * math.pi) - math.pi)
	end
	local lag = Workspace:GetServerTimeNow() - t
	local smoothed = look.latency
	look.latency = if smoothed then smoothed + (lag - smoothed) * 0.1 else lag
	table.insert(ts, t)
	table.insert(look.yaw, yaw)
	table.insert(look.pitch, math.clamp(pitch, -1.45, 1.45))
	if n + 1 > LOOK_KEEP then
		table.remove(ts, 1)
		table.remove(look.yaw, 1)
		table.remove(look.pitch, 1)
	end
end

-- The slope at sample i (from its neighbours: a Catmull-Rom tangent).
local function slope(values: { number }, ts: { number }, i: number, n: number): number
	local a = math.max(i - 1, 1)
	local b = math.min(i + 1, n)
	local span = ts[b] - ts[a]
	return if span > 1e-4 then (values[b] - values[a]) / span else 0
end

local function hermite(values: { number }, ts: { number }, i: number, n: number, u: number): number
	local span = ts[i + 1] - ts[i]
	local u2, u3 = u * u, u * u * u
	return (2 * u3 - 3 * u2 + 1) * values[i]
		+ (u3 - 2 * u2 + u) * span * slope(values, ts, i, n)
		+ (-2 * u3 + 3 * u2) * values[i + 1]
		+ (u3 - u2) * span * slope(values, ts, i + 1, n)
end

-- Their look at server time `now - lookDelay`, or nil when the stream has
-- nothing fresh (then the replicated look takes over).
local function sampleLook(now: number): (number?, number?)
	local ts = look.t
	local n = #ts
	local latency = look.latency
	if n == 0 or latency == nil or now - latency - ts[n] > S.lookStale then
		return nil, nil
	end
	local at = now - lookDelay
	local yaws, pitches = look.yaw, look.pitch
	if at <= ts[1] then
		return yaws[1], pitches[1]
	end
	if at >= ts[n] then
		-- Past the newest: carry on its way briefly, then hold.
		if n >= 2 then
			local span = ts[n] - ts[n - 1]
			if span > 1e-3 then
				local over = math.min(at - ts[n], S.lookExtrapolate) / span
				return yaws[n] + (yaws[n] - yaws[n - 1]) * over,
					math.clamp(pitches[n] + (pitches[n] - pitches[n - 1]) * over, -1.45, 1.45)
			end
		end
		return yaws[n], pitches[n]
	end
	local i = n - 1
	while i > 1 and ts[i] > at do
		i -= 1
	end
	local u = (at - ts[i]) / math.max(ts[i + 1] - ts[i], 1e-4)
	return hermite(yaws, ts, i, n, u), math.clamp(hermite(pitches, ts, i, n, u), -1.45, 1.45)
end

-- The spectate feed (Weapon/Damage): the watched fighter's hits, drawn like
-- your own (hit marker, damage number, headshot flash, kill marker, sounds a
-- little quieter) at the moment their shot is drawn; and their hurts (the
-- damage arcs and the red edge pulse on your screen).
local function onFeed(kind: unknown, holder: unknown, a: unknown, b: unknown)
	local f = target
	if mode ~= "Watch" or not f or typeof(holder) ~= "Instance" or holder ~= f.holder then
		return
	end
	if kind == "Hit" and typeof(a) == "table" then
		local hit = a :: Types.HitConfirm
		local function show()
			if target == f then
				WeaponController.presentHit(hit)
			end
		end
		if shotDelay > 0.005 then
			task.delay(shotDelay, show)
		else
			show()
		end
	elseif kind == "Mods" and typeof(a) == "table" then
		-- Their Mod row (checked field by field; three slots at most).
		local list: { [number]: Watched.ModRow } = {}
		for slot = 1, 3 do
			local r = (a :: any)[slot]
			if typeof(r) == "table" then
				local charges = r.charges
				local rechargeAt = r.rechargeAt
				list[slot] = {
					id = if typeof(r.id) == "string" then r.id else nil,
					level = if typeof(r.level) == "string" then r.level else "L1",
					charges = if typeof(charges) == "number" and charges == charges
						then math.clamp(charges, 0, 99)
						else 0,
					rechargeAt = if typeof(rechargeAt) == "number"
							and rechargeAt == rechargeAt
						then rechargeAt
						else nil,
				}
			end
		end
		Watched.setModRows(list)
	elseif
		kind == "Hurt"
		and typeof(a) == "Vector3"
		and typeof(b) == "number"
		and b == b
		and b > 0
	then
		HudController.damageFrom(a)
		HudController.flinch(a, math.min(b, 500))
	end
end

-- The watched view ----------------------------------------------------------------

local function unequip()
	equippedId = nil
	equippedConfig = nil
	reloadToken += 1
	shellRun = nil
	ViewmodelController.unequip()
end

local function playGun(config: WeaponConfig, name: string)
	local set = GunSounds.get(config.id) :: any
	AudioController.playSound(set[name], "Foley")
end

-- Clip beats (ViewmodelController clipBeats) to GunSounds names, as
-- WeaponController plays them for your own draw.
local BEAT_SOUNDS: { [string]: string } = {
	MagOut = "magOut",
	MagIn = "magIn",
	Rack = "rack",
	Open = "open",
	Eject = "eject",
	ShellIn = "shellIn",
	Close = "close",
}

-- Their gun comes out: the first one (already in their hands) appears at
-- rest; a real swap plays the full draw at its real length, with its foley.
local function equipTheirs(config: WeaponConfig)
	if firstEquip then
		firstEquip = false
		ViewmodelController.equip(config, nil, { instant = true })
		return
	end
	local duration = config.drawTime or config.equipTime
	playGun(config, "draw")
	playGun(config, "drawWhoosh")
	local watched = target
	for _, beat in ViewmodelController.equip(config, duration) do
		task.delay(duration * beat.at, function()
			if target == watched and equippedConfig == config then
				playGun(config, BEAT_SOUNDS[beat.sound])
			end
		end)
	end
end

-- A clip of their gun with its foley on the clip's beats (stale ones stay
-- quiet once the reload, gun or target changes).
local function playReloadClip(config: WeaponConfig, beats: { any }, duration: number)
	local token = reloadToken
	for _, beat in beats do
		task.delay(duration * beat.at, function()
			if reloadToken == token and equippedConfig == config then
				local sound = BEAT_SOUNDS[beat.sound]
				if sound then
					playGun(config, sound)
				end
			end
		end)
	end
end

local function stepShells(now: number)
	local run = shellRun
	if not run or now < run.doneAt then
		return
	end
	if run.config ~= equippedConfig then
		shellRun = nil
		return
	end
	local shell = run.config.shellReload :: Types.ShellReload
	if run.phase == "Insert" then
		run.inserted += 1
	end
	if run.phase ~= "End" and run.inserted < run.needed then
		run.phase = "Insert"
		run.doneAt = now + shell.insert * run.slow
		playReloadClip(
			run.config,
			ViewmodelController.playClip("ReloadInsert", shell.insert * run.slow),
			shell.insert * run.slow
		)
	elseif run.phase ~= "End" then
		run.phase = "End"
		run.doneAt = now + shell.finish * run.slow
		playReloadClip(
			run.config,
			ViewmodelController.playClip("ReloadEnd", shell.finish * run.slow),
			shell.finish * run.slow
		)
		if run.empty then
			playGun(run.config, "rack") -- chamber a round
		end
	else
		shellRun = nil
	end
end

-- A reload they started `since` seconds ago, `duration` long: its clip (an
-- empty one when the mag was dry), or a shell-by-shell run; the part already
-- gone is skipped.
local function startTheirReload(
	config: WeaponConfig,
	duration: number,
	since: number,
	holder: Instance
)
	reloadToken += 1
	shellRun = nil
	local left = duration - since
	local empty = StateValues.get(holder, "ReloadEmpty") == true
	local shells = math.floor(numberAttr(holder, "ReloadShells"))
	local shell = config.shellReload
	if shell and shells > 0 then
		local total = shell.start + shell.insert * shells + shell.finish
		local slow = if total > 0 then duration / total else 1
		local now = os.clock()
		-- Into the phase it's in now.
		local t = since / slow
		if t < shell.start then
			local remaining = (shell.start - t) * slow
			shellRun = {
				config = config,
				phase = "Start",
				doneAt = now + remaining,
				inserted = 0,
				needed = shells,
				empty = empty,
				slow = slow,
			}
			playReloadClip(
				config,
				ViewmodelController.playClip("ReloadStart", remaining),
				remaining
			)
		else
			local inserted =
				math.min(math.floor((t - shell.start) / math.max(shell.insert, 1e-3)), shells)
			shellRun = {
				config = config,
				phase = "Insert",
				doneAt = now,
				inserted = inserted - 1,
				needed = shells,
				empty = empty,
				slow = slow,
			}
			stepShells(now)
		end
		return
	end
	if left > 0.1 then
		playReloadClip(config, ViewmodelController.reload(left, empty), left)
	end
end

-- Their held Mod -------------------------------------------------------------

local function modSounds(id: string): any
	return (ModAudio.SOUNDS :: any)[id]
end

local function putAway(soon: boolean)
	heldSlot, heldId = 0, nil
	itemToken += 1
	local token = itemToken
	ViewmodelController.setItemCharge(nil)
	ViewmodelController.setFreeHand(nil)
	-- After a throw the hand finishes its motion first; a cancel sinks fast.
	local wait = if soon then 0 elseif os.clock() - usedAt < 0.6 then 0.45 else 0.2
	if wait <= 0 then
		ViewmodelController.holdItem(nil)
		return
	end
	task.delay(wait, function()
		if token == itemToken then
			ViewmodelController.holdItem(nil)
		end
	end)
end

local function takeOut(holder: Instance, slot: number)
	local idValue = StateValues.get(holder, "Mod" .. slot .. "Id")
	local def = if typeof(idValue) == "string" then Mods.def(idValue) else nil
	heldSlot = slot
	heldId = if def then def.id else nil
	itemToken += 1
	if not def then
		return
	end
	if def.activation == "HeldSteer" then
		-- Nothing in the hand: the free hand ignites.
		ViewmodelController.holdItem(nil)
		ViewmodelController.setFreeHand("FirewallReady")
	else
		ViewmodelController.holdItem(ModProps.get(def.id, TeamColor.ALLY))
		ViewmodelController.itemParts(def.id)
	end
	local sounds = modSounds(def.id)
	if sounds and sounds.equip then
		ModAudio.play(sounds.equip)
	end
	if def.id == "Molly" or def.id == "Frost" then
		-- Canister out, then the free hand pulls the pin.
		local token = itemToken
		task.delay(ModsConfig.MOLLY_PIN_AT, function()
			if token == itemToken and usedAt < os.clock() - ModsConfig.MOLLY_PIN_AT then
				ViewmodelController.gesture(def.id .. "PinPull")
				ViewmodelController.hideItemPart("Pin", ModsConfig.MOLLY_PIN_GONE)
				if def.id == "Molly" and sounds and sounds.pinPull then
					ModAudio.play(sounds.pinPull)
				end
			end
		end)
	end
end

-- Their use of the Mod in hand: the same motion as your own use.
local function useHeld(holder: Instance)
	local id = heldId
	local def = if id then Mods.def(id) else nil
	usedAt = os.clock()
	if not def then
		return
	end
	if def.activation == "HeldSteer" then
		ViewmodelController.setFreeHand("FirewallGuide")
	elseif def.id == "Recon" or def.id == "ShockDart" then
		ViewmodelController.setItemPart("Dart", 1)
		ViewmodelController.releaseItem() -- the string snaps, the bow kicks
	else
		local kind = StateValues.get(holder, "ModUseKind")
		ViewmodelController.itemAction(
			if def.activation == "HeldThrow"
				then (if def.id == "Frost"
					then "Javelin"
					elseif kind == "Lob" then "Lob"
					else "Throw")
				elseif def.activation == "HeldPlace" then "Place"
				else "Heal"
		)
	end
end

-- Every frame while watching: their held Mod and gestures, from what
-- replicates (ModHeld / ModUseAt on them, Dash / Updraft / Recall marks on
-- their character).
local function stepHeld(holder: Instance, body: Model)
	local useAt = numberAttr(holder, "ModUseAt")
	if useAt > lastUseAt then
		lastUseAt = useAt
		if heldSlot ~= 0 then
			useHeld(holder)
		end
	end
	local held = math.floor(numberAttr(holder, "ModHeld"))
	if held ~= heldSlot then
		if heldSlot ~= 0 then
			putAway(false)
		end
		if held >= 1 and held <= 3 then
			takeOut(holder, held)
		end
	end
	local cam = Workspace.CurrentCamera
	local dashAt = numberAttr(body, "DashStart")
	if dashAt > lastDashAt + 0.05 then
		lastDashAt = dashAt
		local velocity = StateValues.get(body, "DashVelocity")
		if typeof(velocity) == "Vector3" and velocity.Magnitude > 0.1 and cam then
			local localDir = cam.CFrame:VectorToObjectSpace(velocity.Unit)
			ViewmodelController.gesture(
				if math.abs(localDir.X) > math.abs(localDir.Z)
					then (if localDir.X > 0 then "DashRight" else "DashLeft")
					else (if localDir.Z < 0 then "DashForward" else "DashBack"),
				"Dash"
			)
		end
	end
	local updraftAt = numberAttr(body, "UpdraftAt")
	if updraftAt > lastUpdraftAt + 0.05 then
		lastUpdraftAt = updraftAt
		ViewmodelController.gesture("UpdraftDown", "Updraft")
	end
	local windup = numberAttr(body, "RecallWindupUntil")
	if windup > lastWindup + 0.05 then
		lastWindup = windup
		if windup > Workspace:GetServerTimeNow() then
			ViewmodelController.gesture("RecallTwist", "Recall")
		end
	end
end

-- (Defined below: watchStep cuts to the next fighter the moment one goes down.)
local watch: (f: Fighter) -> ()

-- Their view, every frame (the camera override: runs before the viewmodel).
local function watchStep(cam: Camera, dt: number)
	local f = target
	if not f then
		return
	end
	local body, holder = f.body, f.holder
	local root = body:FindFirstChild("HumanoidRootPart")
	local humanoid = humanoidOf(body)
	-- They went down: cut straight to the next fighter (no frames of a dead
	-- body standing still); with nobody to cut to, their eye sinks and tips
	-- like a fall until the round end picks your killer.
	if not alive(body) and downViewAt == nil then
		local nextOne = nextAfterDown(f)
		if nextOne then
			if not cutQueued then
				cutQueued = true
				task.defer(function()
					cutQueued = false
					if target == f and mode == "Watch" then
						watch(nextOne)
					end
				end)
			end
		else
			downViewAt = os.clock()
			ViewmodelController.setHidden(true)
			HudController.setCrosshairVisible(false, false)
		end
	end
	local moveAttr = StateValues.get(body, "MoveState")
	local moveState = if typeof(moveAttr) == "string" then moveAttr else "Idle"
	-- The camera: where their own sits (over their root, lowered for a crouch
	-- or slide, dipped on a landing) and their look (a watched bot's gun
	-- look, else the body's facing and reported pitch), eased together.
	if root and root:IsA("BasePart") then
		-- The look stream when it's flowing (drawn lookDelay in the past: the
		-- measured delay plus a little buffer, eased so it never jumps), else
		-- the replicated look, eased.
		local now = Workspace:GetServerTimeNow()
		local latency = look.latency
		if latency then
			local want = math.clamp(latency + S.lookJitter, S.lookDelayMin, S.lookDelayMax)
			lookDelay = Ease.approach(lookDelay, want, 2, dt)
		end
		local sy, sp = sampleLook(now)
		if sy and sp then
			viewYaw, viewPitch = sy, sp
			streaming = true
		else
			local yaw, pitch = Fighters.lookOf(holder, body)
			if viewPos == nil then
				viewYaw, viewPitch = yaw, pitch
			else
				viewYaw = Ease.approachAngle(viewYaw, yaw, S.aimRate, dt)
				viewPitch = Ease.approach(viewPitch, pitch, S.aimRate, dt)
			end
			streaming = false
		end
		-- Their shots (and hits) wait for the drawn view to catch up with where
		-- they fired.
		shotDelay = if streaming and latency then math.max(lookDelay - latency, 0) else 0
		EffectsController.setSpectatedDelay(shotDelay)
		-- Landing: their feet, like the viewmodel's (Humanoid.FloorMaterial).
		local airborne = humanoid ~= nil and humanoid.FloorMaterial == Enum.Material.Air
		if airborne then
			fallSpeed = math.max(fallSpeed, -root.AssemblyLinearVelocity.Y)
		elseif wasAirborne then
			CameraDrop.land(drop, fallSpeed)
			fallSpeed = 0
			landedAt = os.clock()
		end
		wasAirborne = airborne
		local lowered = CameraDrop.step(drop, moveState, dt)
		local dying = 0
		local fellAt = downViewAt
		if fellAt then
			local k = math.clamp((os.clock() - fellAt) / S.downTime, 0, 1)
			dying = 1 - (1 - k) * (1 - k) * (1 - k) -- ease out
			viewPitch += (S.downPitch - viewPitch) * dying
		end
		local rotation = CFrame.fromEulerAnglesYXZ(viewPitch, viewYaw, 0)
		if dying > 0 then
			rotation *= CFrame.Angles(0, 0, S.downRoll * dying)
		end
		-- Roblox already interpolates their root: no extra smoothing here.
		local eye = root.Position
			+ Vector3.new(0, S.eyeHeight - lowered - S.downDrop * dying, 0)
			- rotation.LookVector * S.eyeBack
		viewPos = eye
		cam.CFrame = CFrame.new(eye) * rotation
	end

	-- Their body stays out of view (other effects, like a dash ghost, write
	-- the same property every frame).
	for _, d in hiddenParts do
		local part = d :: any
		if part.LocalTransparencyModifier ~= 1 then
			part.LocalTransparencyModifier = 1
		end
	end

	-- Their gun.
	local world = body:FindFirstChild("WorldWeapon")
	local idAttr = world and StateValues.get(world, "WeaponId")
	local id = if typeof(idAttr) == "string" then idAttr else nil
	if id ~= equippedId then
		local config = id and Weapons.get(id)
		heat, lastShotAt = 0, -math.huge -- a new gun, a cold spray
		if config then
			equippedId, equippedConfig = id, config
			equipTheirs(config)
		else
			unequip()
		end
	end
	local config = equippedConfig

	-- Aiming down sights, zoom and the scope overlay (as WeaponController
	-- does for yours: the zoom trails the gun, the edges darken, a cloth flick).
	local aiming = StateValues.get(holder, "Aiming") == true
		and config ~= nil
		and config.fireMode ~= "Melee"
		and not config.noAds
	if config and wasAiming ~= nil and aiming ~= wasAiming then
		playGun(config, if aiming then "aimIn" else "aimOut")
	end
	wasAiming = aiming
	local rate = 1 / math.max(if config then config.adsTime else 0.2, 0.05)
	adsAlpha = math.clamp(adsAlpha + (if aiming then rate else -rate) * dt, 0, 1)
	ViewmodelController.setAds(adsAlpha)
	local scope = config and config.scope
	CameraController.setZoom(
		if scope then CameraController.scopeFov(scope.zoom) elseif config then config.adsFov else nil,
		ViewmodelController.adsZoom()
	)
	HudController.setAim(ViewmodelController.adsBlend())
	local scoped = scope ~= nil and adsAlpha >= VM.SCOPE_AT
	HudController.setScope(scoped)
	-- (Down with nobody to cut to: no gun, no crosshair.)
	ViewmodelController.setHidden(scoped or downViewAt ~= nil)
	HudController.setCrosshairVisible(
		adsAlpha < 0.5 and config ~= nil and downViewAt == nil,
		moveState == "Sprint"
	)

	-- Their crosshair: the gun's cone at their cooled spray heat plus their
	-- movement (Util/Accuracy, like your own), and its slide / air reactions.
	HudController.setCrosshairState(moveState == "Slide", moveState == "Air", adsAlpha)
	if config then
		local h = Accuracy.cool(config, heat, os.clock() - lastShotAt)
		local speed = if root and root:IsA("BasePart")
			then (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
			else 0
		local cone = Accuracy.cone(config, h, {
			state = moveState,
			speed = speed,
			aim = adsAlpha,
			sinceLanding = os.clock() - landedAt,
		})
		HudController.setSpread(cone + config.pelletSpread * 0.6)
	end

	-- A held Mod lowers the gun; a reload plays its clip; a knife swing plays
	-- its step of the 1-2-3 chain (or the heavy).
	local lowered = numberAttr(holder, "ModHeld") ~= 0
	if lowered ~= wasLowered then
		wasLowered = lowered
		ViewmodelController.setLowered(lowered)
	end
	stepHeld(holder, body)
	local reloadAt = numberAttr(holder, "ReloadAt")
	if reloadAt > lastReloadAt then
		lastReloadAt = reloadAt
		local duration = numberAttr(holder, "ReloadFor")
		local since = Workspace:GetServerTimeNow() - reloadAt
		if config and duration - since > 0.1 then
			startTheirReload(config, duration, math.max(since, 0), holder)
		end
	end
	-- A shell reload they cut short (they fired): straight to its End.
	local stopAt = numberAttr(holder, "ReloadStopAt")
	if stopAt > lastStopAt then
		lastStopAt = stopAt
		local run = shellRun
		if run and run.phase ~= "End" then
			run.phase = "Insert"
			run.inserted = run.needed -- the next step plays End
			run.doneAt = 0
		end
	end
	stepShells(os.clock())
	local swingAt = numberAttr(holder, "SwingAt")
	if swingAt ~= lastSwingAt then
		lastSwingAt = swingAt
		if config and config.fireMode == "Melee" then
			local step = math.clamp(math.floor(numberAttr(holder, "SwingStep")), 1, 3)
			ViewmodelController.swing(
				if StateValues.get(holder, "SwingHeavy") == true
					then "HeavyStab"
					else "Slash" .. step
			)
		end
	end

	-- Their gun and rounds on the bottom HUD (WeaponService / BotGun publish
	-- `Ammo` / `AmmoReserve`), and their reload's progress.
	if config then
		local ammoValue = StateValues.get(holder, "Ammo")
		local reserveValue = StateValues.get(holder, "AmmoReserve")
		local ammo = if typeof(ammoValue) == "number" then math.floor(ammoValue) else config.magSize
		local reserve = if typeof(reserveValue) == "number" then math.floor(reserveValue) else nil
		if config.id ~= shownGun or ammo ~= shownAmmo or reserve ~= shownReserve then
			shownGun, shownAmmo, shownReserve = config.id, ammo, reserve
			HudController.setWeapon(config.displayName, ammo, config.magSize, config.id, reserve)
		end
	end
	local reloadFor = numberAttr(holder, "ReloadFor")
	local reloadSince = Workspace:GetServerTimeNow() - numberAttr(holder, "ReloadAt")
	local progress = if config
			and reloadFor > 0
			and reloadSince >= 0
			and reloadSince < reloadFor
		then reloadSince / reloadFor
		else nil
	if progress ~= shownReload then
		shownReload = progress
		HudController.setReload(progress)
	end

	-- Their health on the bar.
	if humanoid and DeathScreen.active() then
		DeathScreen.setHealth(Health.get(humanoid), Health.max(humanoid))
	end
end

-- The spectated fighter's shot. Returns the shot's sound options (Util/GunAudio): the view gun wears their
-- skin, so its line picks the skinned sound like your own gun's (owner 2026-11-23: spectating a Ruin-Blighted
-- gun should sound like one).
local function onSpectatedShot(config: WeaponConfig, left: boolean): { [string]: any }?
	local f = target
	if config.fireMode == "Melee" then
		-- A player's swings come from SwingAt / SwingStep (watchStep), which
		-- carries the chain step; a bot sets no SwingAt: its first slash.
		if f and not f.holder:IsA("Player") then
			ViewmodelController.swing("Slash1")
		end
		return nil
	end
	local now = os.clock()
	heat = Accuracy.cool(config, heat, now - lastShotAt) + 1
	lastShotAt = now
	local kick = (1 - 0.5 * adsAlpha) * (config.viewmodelKick or 1)
	ViewmodelController.fire(kick, if left then "Left" else nil, false)
	-- The crosshair blooms by the gun's kick (as for your own shots); a
	-- scope picture jolts.
	HudController.crosshairShot(math.max(config.recoil.up, Juice.SHOT_FEEL.upFloor))
	if config.scope ~= nil and adsAlpha >= VM.SCOPE_AT then
		HudController.scopeShot()
	end
	return {
		shadowMist = ViewmodelController.hasShadowMist(),
		tempest = ViewmodelController.hasTempest(),
		slipframe = ViewmodelController.hasSlipframe(),
		moltframe = ViewmodelController.hasMoltframe(),
		playback = ViewmodelController.hasPlayback(),
		sundial = ViewmodelController.hasSundial(),
		riftforge = ViewmodelController.hasRiftforge(),
	}
end

function watch(f: Fighter)
	local old = target
	if old and old.body ~= f.body then
		setBodyHidden(old.body, false)
	end
	doBlink()
	mode = "Watch"
	target = f
	viewPos = nil
	adsAlpha = 0
	wasLowered = false
	targetDownAt = nil
	downViewAt = nil
	cutQueued = false
	ViewmodelController.setHidden(false)
	-- Only reloads and swings that start from now play (not earlier ones).
	-- Their Mod: what they hold now comes up on the next frame; earlier uses
	-- and gestures don't replay.
	if heldSlot ~= 0 then
		putAway(true)
	end
	lastUseAt = numberAttr(f.holder, "ModUseAt")
	usedAt = -math.huge
	lastDashAt = numberAttr(f.body, "DashStart")
	lastUpdraftAt = numberAttr(f.body, "UpdraftAt")
	lastWindup = numberAttr(f.body, "RecallWindupUntil")
	lastReloadAt = numberAttr(f.holder, "ReloadAt")
	lastStopAt = numberAttr(f.holder, "ReloadStopAt")
	reloadToken += 1
	shellRun = nil
	lastSwingAt = numberAttr(f.holder, "SwingAt")
	equippedId, equippedConfig = nil, nil
	firstEquip = true -- the gun in their hands: no draw
	wasAiming = nil
	CameraDrop.reset(drop)
	local humanoid = humanoidOf(f.body)
	wasAirborne = humanoid ~= nil and humanoid.FloorMaterial == Enum.Material.Air
	fallSpeed = 0
	landedAt = -math.huge
	heat, lastShotAt = 0, -math.huge
	shownGun, shownAmmo, shownReserve, shownReload = nil, nil, nil, nil
	resetLook(f.holder)
	Watched.set(f.holder, f.body)
	DeathFxController.clearGrade()
	WeaponController.setSpectating(true)
	HudController.setSpectating(true)
	HudController.setSubject(f.body)
	ViewmodelController.setSubject(f.body)
	EffectsController.setSpectated(f.holder, onSpectatedShot)
	setBodyHidden(f.body, true)
	setBar(f)
	local cam = Workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Scriptable
	end
	CameraController.setOverride(watchStep)
	sendAt = os.clock() + SEND_SETTLE -- fast cycling sends only where it lands
end

-- Next (+1) or previous (-1) living teammate.
function SpectateController.cycle(step: number)
	if mode ~= "Watch" then
		return
	end
	local team = teammates()
	if #team == 0 then
		return
	end
	local current = target
	local index = 0
	for i, f in team do
		if current and f.body == current.body then
			index = i
		end
	end
	local nextIndex = (index - 1 + step) % #team + 1
	local f = team[nextIndex]
	if not current or f.body ~= current.body then
		watch(f)
	end
end

-- Death camera ------------------------------------------------------------------

local function deathStep(cam: Camera, _dt: number)
	local t = (os.clock() - deathAt) / S.pullTime
	local e = Ease.out(t)
	local pos = deathFrom.Position:Lerp(deathGoal, e)
	local from = deathFrom.Rotation
	local to = CFrame.lookAt(deathGoal, deathLook).Rotation
	cam.CFrame = CFrame.new(pos) * from:Lerp(to, e)
end

local function startDeathCam(body: Model)
	local cam = Workspace.CurrentCamera
	local root = body:FindFirstChild("HumanoidRootPart")
	if not cam or not root or not root:IsA("BasePart") then
		return
	end
	mode = "DeathCam"
	WeaponController.setSpectating(true) -- no crosshair, no Aim sends from the dead body
	-- Your gun and arms go (WeaponController stands down before its own
	-- end-of-life clean-up can run).
	ViewmodelController.unequip()
	CameraController.setZoom(nil, 0)
	HudController.setScope(false)
	HudController.setAim(0) -- WeaponController stood down mid-aim: the edges clear
	deathAt = os.clock()
	deathFrom = cam.CFrame
	local flat = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
	flat = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
	deathLook = root.Position - Vector3.new(0, 1.5, 0)
	local wanted = root.Position - flat * S.pullBack + Vector3.new(0, S.pullUp, 0)
	-- Don't pull back through a wall.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { body, cam }
	local start = deathFrom.Position
	local hit = Workspace:Raycast(start, wanted - start, params)
	deathGoal = if hit then hit.Position + hit.Normal * 1 else wanted
	cam.CameraType = Enum.CameraType.Scriptable
	CameraController.setOverride(deathStep)
	HudController.setSpectating(true)
	HudController.setCrosshairVisible(false)
	if DeathScreen.active() then
		showKilledBy()
	end
end

-- Ends everything: a new life plays from its own eyes.
local function stop()
	if mode == "Off" then
		return
	end
	local old = target
	if old then
		setBodyHidden(old.body, false)
	end
	mode = "Off"
	target = nil
	killer = nil
	killedWith, killedHead = "", false
	sendAt = nil
	if equippedId ~= nil then
		unequip()
	end
	CameraController.setOverride(nil)
	CameraController.setZoom(nil, 0)
	HudController.setScope(false)
	HudController.setAim(0)
	HudController.setCrosshairState(false, false, 0)
	HudController.setSpectating(false)
	HudController.setSubject(nil)
	if shownReload ~= nil then
		HudController.setReload(nil)
	end
	shownGun, shownAmmo, shownReserve, shownReload = nil, nil, nil, nil
	Watched.set(nil, nil)
	HudController.setCrosshairVisible(true)
	ViewmodelController.setHidden(false)
	ViewmodelController.setLowered(false)
	if heldSlot ~= 0 then
		putAway(true)
	end
	ViewmodelController.setSubject(nil)
	EffectsController.setSpectated(nil, nil)
	resetLook(nil)
	WeaponController.setSpectating(false)
	setBar(nil)
	local cam = Workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		local humanoid = humanoidOf(player.Character)
		if humanoid then
			cam.CameraSubject = humanoid
		end
	end
	if sentTarget ~= nil then
		sentTarget = nil
		Net.event("Spectate"):FireServer(nil)
	end
end

-- The final-kill replay takes the camera (ReplayController).
function SpectateController.stop()
	stop()
end

-- Every few frames: move on when there's someone (better) to watch.
local function tick()
	-- The Spectate request, once the choice has settled.
	local due = sendAt
	local watched = target
	if due and os.clock() >= due and watched then
		sendAt = nil
		if sentTarget ~= watched.holder then
			sentTarget = watched.holder
			Net.event("Spectate"):FireServer(watched.holder)
		end
	end
	-- The match is over (or restarting): nobody respawns to end this.
	local phase = MatchState.phase()
	if
		mode ~= "Off"
		and (phase == "MatchEnd" or phase == "Waiting" or phase == "Vote" or phase == "Replay")
	then
		stop()
		return
	end
	local body = myBody
	-- Only in the fight (not on a body left over from the last match), or
	-- just after it: the round-ending kill switches the phase within 0.1 s.
	if phase == "Live" or phase == "SuddenDeath" then
		lastFightAt = os.clock()
	end
	local fighting = phase == "Live"
		or phase == "SuddenDeath"
		or (phase == "RoundEnd" and os.clock() - lastFightAt < 1.2) -- never in Replay / MatchEnd
	if
		mode == "Off"
		and fighting
		and body
		and body == player.Character
		and Health.isDowned(body)
	then
		startDeathCam(body)
		return
	end
	if mode == "Off" then
		-- Joined mid-fight with no body yet (a bot keeps your seat until the
		-- next round): watch a teammate meanwhile.
		if
			player.Character == nil
			and (phase == "Live" or phase == "SuddenDeath" or phase == "RoundEnd")
		then
			local f = pickTarget()
			if f then
				watch(f)
			end
		end
	elseif mode == "DeathCam" then
		if os.clock() - deathAt >= S.pullTime + S.holdTime then
			local f = pickTarget()
			if f then
				watch(f)
			end
		end
	elseif mode == "Watch" then
		local f = target
		if not f then
			return
		end
		local mine = Teams.of(player)
		local isTeammate = mine ~= nil and Teams.of(f.holder) == mine
		if f.body.Parent == nil and pickTarget() == nil then
			stop() -- they left and there's nobody else to watch
			return
		end
		if alive(f.body) then
			-- Watching your killer while a teammate is still up shouldn't happen,
			-- but go back to the teammate if it does.
			if not isTeammate and #teammates() > 0 then
				watch(teammates()[1])
			end
			return
		end
		-- They went down: a beat on it, then the next one.
		local downAt = targetDownAt or os.clock()
		targetDownAt = downAt
		if os.clock() - downAt >= S.switchDelay then
			local nextOne = pickTarget()
			if nextOne and nextOne.body ~= f.body then
				watch(nextOne)
			end
		end
	end
end

-- A new life ends spectating. Going down is polled in tick() (like
-- DeathFxController): the Downed attribute's change signal doesn't fire on
-- your own simulated character in our Studio tests.
local function onCharacter(body: Model)
	stop()
	myBody = body
end

function SpectateController.start()
	buildUi()
	DeathScreen.start()
	DeathScreen.onCycle(SpectateController.cycle)
	-- Your combat report vs your killer (server: StatsService).
	Net.event("CombatReport").OnClientEvent:Connect(function(dealt: unknown, taken: unknown)
		if
			typeof(dealt) == "number"
			and typeof(taken) == "number"
			and dealt == dealt
			and taken == taken
		then
			DeathScreen.setReport(dealt, taken)
		end
	end)
	Net.event("Killed").OnClientEvent
		:Connect(function(victim: unknown, attacker: unknown, sourceId: unknown, headshot: unknown)
			if
				typeof(victim) == "Instance"
				and victim:IsA("Model")
				and typeof(attacker) == "Instance"
			then
				killerOf[victim] = attacker
			end
			if victim ~= nil and victim == myBody and typeof(attacker) == "Instance" then
				killer = attacker
				killedWith = if typeof(sourceId) == "string" then sourceId else ""
				killedHead = headshot == true
			end
		end)
	InputController.onPressed("Fire", function()
		if not DeathScreen.overKeys() then -- the keycap's own click cycles
			SpectateController.cycle(1)
		end
	end)
	InputController.onPressed("Aim", function()
		if not DeathScreen.overKeys() then
			SpectateController.cycle(-1)
		end
	end)
	Net.unreliable("LookRelay").OnClientEvent:Connect(onLookRelay)
	Net.event("SpectateFeed").OnClientEvent:Connect(onFeed)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	task.spawn(function()
		while true do
			task.wait(0.1)
			local ok, err = pcall(tick)
			if not ok then
				warn("[SpectateController]", err)
			end
		end
	end)
end

return SpectateController
