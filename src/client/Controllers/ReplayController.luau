--!strict
-- The final-kill replay (vault/05 Production/Match Structure Revamp.md,
-- phase C). Every client records the last few seconds of every fighter while
-- a round is being fought: the CFrame of each body part at Config/Match
-- REPLAY.rate in a fixed ring, stamped with server time, plus every shot
-- (others' from ShotFx, yours from Util/ShotLog) and who killed whom. When the
-- server says the match-winning kill happened (the `Replay` remote), every
-- client plays the same window on anchored copies of the bodies, with the
-- camera over the killer's shoulder and slow motion into the kill. Recording
-- locally costs no network (the vault note's research: limb CFrames, not
-- joint Transforms, which can't be written under Server Authority).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiRoot = require(ReplicatedStorage.Shared.UiRoot)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraDrop = require(ReplicatedStorage.Shared.CameraDrop)
local Config = require(ReplicatedStorage.Shared.Config.Match)
local Ease = require(ReplicatedStorage.Shared.Util.Ease)
local Fighters = require(ReplicatedStorage.Shared.Util.Fighters)
local GunSounds = require(ReplicatedStorage.Shared.Config.GunSounds)
local Health = require(ReplicatedStorage.Shared.Health)
local Juice = require(ReplicatedStorage.Shared.Config.Juice)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local Types = require(ReplicatedStorage.Shared.Types)
local TestMode = require(ReplicatedStorage.Shared.TestMode)
local Mods = require(ReplicatedStorage.Shared.Mods)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local VM = require(ReplicatedStorage.Shared.Config.Viewmodel)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local AudioController = require(script.Parent.AudioController)
local CameraController = require(script.Parent.CameraController)
local DeathFxController = require(script.Parent.DeathFxController)
local EffectsController = require(script.Parent.EffectsController)
local HudController = require(script.Parent.HudController)
local SpectateController = require(script.Parent.SpectateController)
local ViewmodelController = require(script.Parent.ViewmodelController)
local WeaponController = require(script.Parent.WeaponController)
local ShotLog = require(script.Parent.Parent.Util.ShotLog)
local ShotFxKit = require(script.Parent.Parent.Util.ShotFxKit)
local BodyClone = require(script.Parent.Parent.Util.BodyClone)
local ReplayModFx = require(script.Parent.Parent.Util.ReplayModFx)
local Ui = require(script.Parent.Parent.Util.Ui)

local ReplayController = {}

local R = Config.REPLAY
local C = Theme.COLORS
local FRAMES = math.ceil(R.buffer * R.rate)
local STEP = 1 / R.rate
local player = Players.LocalPlayer

-- Recording ---------------------------------------------------------------------

type Track = {
	body: Model,
	-- The player behind the body, taken when it was first recorded (after a
	-- respawn GetPlayerFromCharacter no longer knows the old body): the
	-- replay's gun wears their skins. nil for a bot.
	owner: Player?,
	parts: { BasePart }, -- the body's own parts (children of the model)
	frames: { { CFrame } }, -- per ring slot, one CFrame per part
	stamps: { number }, -- per ring slot, the time it was written (valid when it matches `times`)
	downAt: number?, -- server time it went down (as this client saw it)
	lastSeen: number,
	-- What they saw, per ring slot (the final kill plays from the killer's eyes):
	yaw: { number }, -- radians, where they faced
	pitch: { number }, -- radians, up / down
	aiming: { boolean }, -- down the sights
	weapon: { string }, -- the gun in hand ("" = none)
	state: { string }, -- MoveState (the eye's crouch / slide drop: shared/CameraDrop)
	-- Their reload and knife swing marks (the replay's viewmodel plays them):
	reloadAt: { number }, -- server time their last reload started (0: none)
	reloadFor: { number },
	swingAt: { number },
	swingStep: { number }, -- 1..3, the light chain
	swingHeavy: { boolean },
	dashing: boolean?,
	updrafting: boolean?,
}

type Shot = { t: number, body: Model, weaponId: string, origin: Vector3, ends: { Vector3 } }

local times: { number } = table.create(FRAMES, -math.huge)
local head = 0 -- the ring slot written last
local tracks: { [Model]: Track } = {}
local shots: { Shot } = {}
local killers: { [Model]: Instance } = setmetatable({}, { __mode = "k" }) :: any
-- What the final kill was made with (the Killed event), for its card.
local killedWith: { [Model]: { id: string, head: boolean } } = setmetatable({}, { __mode = "k" }) :: any
local nextSample = 0
local playing = false
local recording = false
local killerLag = 0 -- seconds the killer's look samples reached the server late (Replay event)
local decodeLook: (look: unknown) -> any
local decodeHits: (hits: unknown) -> { any }

local function sameMatch(holder: Instance): boolean
	return holder:GetAttribute("MatchId") == PlayZone.matchId(player)
		and (not holder:IsA("Player") or PlayZone.get(holder) == "Match")
end

local function newTrack(body: Model): Track
	local parts: { BasePart } = {}
	for _, child in body:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	return {
		body = body,
		owner = Players:GetPlayerFromCharacter(body),
		parts = parts,
		frames = table.create(FRAMES),
		stamps = table.create(FRAMES, -math.huge),
		downAt = nil,
		lastSeen = 0,
		yaw = table.create(FRAMES, 0),
		pitch = table.create(FRAMES, 0),
		aiming = table.create(FRAMES, false),
		weapon = table.create(FRAMES, ""),
		state = table.create(FRAMES, "Idle"),
		reloadAt = table.create(FRAMES, 0),
		reloadFor = table.create(FRAMES, 0),
		swingAt = table.create(FRAMES, 0),
		swingStep = table.create(FRAMES, 1),
		swingHeavy = table.create(FRAMES, false),
	}
end

local function numberOf(holder: Instance, name: string): number
	local v = StateValues.get(holder, name)
	return if typeof(v) == "number" and v == v then v else 0
end

-- Where a fighter is looking now. Yours comes straight from your camera;
-- anyone else's from Util/Fighters.lookOf (a watched bot's gun look, else
-- the body's facing and AimPitch) and the Aiming attribute (players:
-- WeaponService's Aim remote; bots: Bots/Brain).
local function viewOf(body: Model): (number, number, boolean, string)
	local owner = Players:GetPlayerFromCharacter(body)
	local holder: Instance = owner or body
	local yaw, pitch = 0, 0
	local cam = Workspace.CurrentCamera
	if owner == player and cam then
		local look = cam.CFrame.LookVector
		yaw = math.atan2(-look.X, -look.Z)
		pitch = math.asin(math.clamp(look.Y, -1, 1))
	else
		yaw, pitch = Fighters.lookOf(holder, body)
	end
	local world = body:FindFirstChild("WorldWeapon")
	local id = world and StateValues.get(world, "WeaponId")
	return yaw,
		pitch,
		StateValues.get(holder, "Aiming") == true,
		if typeof(id) == "string" then id else ""
end

local function record()
	if not recording or playing then
		return
	end
	local now = os.clock()
	if now < nextSample then
		return
	end
	nextSample = math.max(nextSample + STEP, now - STEP) -- steady rate, no drift
	local t = Workspace:GetServerTimeNow()
	ReplayModFx.sample(t, t - R.buffer, PlayZone.matchId(player))
	head = head % FRAMES + 1
	times[head] = t
	for _, fighter in Fighters.all() do
		if not sameMatch(fighter.holder) then
			continue
		end
		local body = fighter.body
		local track = tracks[body]
		if not track then
			track = newTrack(body)
			tracks[body] = track
		end
		track.lastSeen = t
		local root = body:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local dashing = StateValues.get(body, "Dashing") == true
			local updrafting = StateValues.get(body, "Updrafting") == true
			if dashing and not track.dashing then
				ReplayModFx.capture("Dash", { at = root.Position }, t)
			end
			if updrafting and not track.updrafting then
				ReplayModFx.capture("Updraft", { at = root.Position }, t)
			end
			track.dashing = dashing
			track.updrafting = updrafting
		end
		local frame = track.frames[head]
		if not frame then
			frame = table.create(#track.parts)
			track.frames[head] = frame
		end
		for i, part in track.parts do
			frame[i] = part.CFrame
		end
		track.stamps[head] = t
		track.yaw[head], track.pitch[head], track.aiming[head], track.weapon[head] = viewOf(body)
		local moveState = StateValues.get(body, "MoveState")
		track.state[head] = if typeof(moveState) == "string" then moveState else "Idle"
		local holder: Instance = track.owner or body
		track.reloadAt[head] = numberOf(holder, "ReloadAt")
		track.reloadFor[head] = numberOf(holder, "ReloadFor")
		track.swingAt[head] = numberOf(holder, "SwingAt")
		track.swingStep[head] = math.clamp(math.floor(numberOf(holder, "SwingStep")), 1, 3)
		track.swingHeavy[head] = StateValues.get(holder, "SwingHeavy") == true
		if track.downAt == nil and Health.isDowned(body) then
			track.downAt = t
		elseif track.downAt ~= nil and not Health.isDowned(body) then
			track.downAt = nil -- a new life in the same model
		end
	end
	-- Forget what fell out of the buffer.
	local oldest = t - R.buffer
	for body, track in tracks do
		if track.lastSeen < oldest then
			tracks[body] = nil
		end
	end
	while #shots > 0 and shots[1].t < oldest do
		table.remove(shots, 1)
	end
end

local function addShot(body: Model?, weaponId: unknown, origin: unknown, ends: unknown)
	if
		not recording
		or playing
		or not body
		or not sameMatch(Players:GetPlayerFromCharacter(body) or body)
		or typeof(weaponId) ~= "string"
		or typeof(origin) ~= "Vector3"
		or typeof(ends) ~= "table"
	then
		return
	end
	local list: { Vector3 } = {}
	for _, e in ends :: { unknown } do
		if typeof(e) == "Vector3" then
			table.insert(list, e)
		end
	end
	table.insert(shots, {
		t = Workspace:GetServerTimeNow(),
		body = body,
		weaponId = weaponId,
		origin = origin,
		ends = list,
	})
end

local function bodyOf(x: unknown): Model?
	if typeof(x) ~= "Instance" then
		return nil
	end
	if x:IsA("Player") then
		return x.Character
	elseif x:IsA("Model") then
		return x
	end
	return nil
end

-- Playback ------------------------------------------------------------------------

type Actor = {
	track: Track,
	copy: Model,
	parts: { [number]: BasePart? },
	joints: { Instance }, -- the body's joints, off while it's posed from the recording
	gone: boolean,
}

-- The ring slots inside [from, to], oldest first.
local function slotsBetween(from: number, to: number): { number }
	local list: { number } = {}
	for k = 1, FRAMES do
		local slot = (head + k - 1) % FRAMES + 1 -- oldest → newest
		local t = times[slot]
		if t >= from and t <= to then
			table.insert(list, slot)
		end
	end
	return list
end

-- Places an actor's parts at time `t` (lerped between the frames around it).
-- The recorded frames either side of time `t` on a track, and how far
-- between them `t` is (nil: nothing recorded for it).
local function bracket(track: Track, slots: { number }, t: number): (number?, number, number)
	local before: number? = nil
	local after: number? = nil
	for _, slot in slots do
		if track.stamps[slot] == times[slot] then
			if times[slot] <= t then
				before = slot
			elseif after == nil then
				after = slot
				break
			end
		end
	end
	local a = before or after
	if not a then
		return nil, 0, 0
	end
	local b = after or a
	local span = times[b] - times[a]
	return a, b, if span > 1e-4 then math.clamp((t - times[a]) / span, 0, 1) else 0
end

-- The valid recorded slot before `a` and after `b` (or themselves at the ends).
local function neighbours(track: Track, slots: { number }, a: number, b: number): (number, number)
	local before, after = a, b
	local prev: number? = nil
	local pastB = false
	for _, slot in slots do
		if track.stamps[slot] ~= times[slot] then
			continue
		end
		if pastB then
			after = slot -- the first valid slot past b
			break
		end
		if slot == a then
			before = prev or a
		end
		if slot == b then
			pastB = true
		end
		prev = slot
	end
	return before, after
end

-- Catmull-Rom between p1 and p2 (u 0..1), with p0 / p3 their neighbours:
-- curves through the recorded positions instead of corners at each sample
-- (slow motion stretches 30 samples a second a long way).
local function catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, u: number): Vector3
	local u2, u3 = u * u, u * u * u
	return 0.5
		* (
			2 * p1
			+ (p2 - p0) * u
			+ (2 * p0 - 5 * p1 + 4 * p2 - p3) * u2
			+ (3 * p1 - p0 - 3 * p2 + p3) * u3
		)
end

local function pose(actor: Actor, slots: { number }, t: number)
	local track = actor.track
	local a, b, alpha = bracket(track, slots, t)
	if not a then
		return
	end
	local p, n = neighbours(track, slots, a, b)
	local fa, fb, fp, fn = track.frames[a], track.frames[b], track.frames[p], track.frames[n]
	for i, part in actor.parts do
		local cf = fa[i]
		if part and cf then
			local other = fb[i]
			if other then
				local rot = cf:Lerp(other, alpha)
				local before = fp and fp[i] or cf
				local after = fn and fn[i] or other
				local pos =
					catmull(before.Position, cf.Position, other.Position, after.Position, alpha)
				part.CFrame = rot - rot.Position + pos
			else
				part.CFrame = cf
			end
		end
	end
end

-- Its fall at the moment it went down: the joints come back so DeathFx's
-- copy of it hangs together, and that copy goes with the replay's folder.
local function fallNow(actor: Actor, folder: Instance, opts: DeathFxController.FallOptions?)
	actor.gone = true
	local root = actor.copy:FindFirstChild("HumanoidRootPart")
	for _, j in actor.joints do
		(j :: any).Enabled = true
	end
	for _, part in actor.parts do
		if part and part ~= root then
			part.Anchored = false
		end
	end
	DeathFxController.playFall(actor.copy, folder, opts)
end

-- UI: letterbox bars and the FINAL KILL line.
local overlay: ScreenGui? = nil
local caption: TextLabel? = nil
-- The Studio-built card (UiTemplates.Replay.FinalKill), when it's there.
local card: Frame? = nil
local function buildUi()
	local gui = Ui.make("ScreenGui", {
		Name = "Replay",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None, -- full-bleed overlays, under the notch too
		SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
		ClipToDeviceSafeArea = false,
		DisplayOrder = 20,
		Enabled = false,
	}, player:WaitForChild("PlayerGui"))
	for _, y in { 0, 1 } do
		Ui.make("Frame", {
			AnchorPoint = Vector2.new(0, y),
			Position = UDim2.fromScale(0, y),
			Size = UDim2.fromScale(1, 0.1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
		}, gui)
	end
	-- The match UI's card: the gold FINAL KILL block, killer, weapon, victim.
	local templates = UiRoot.findTemplates(0)
	local folder = templates and templates:FindFirstChild("Replay")
	local template = folder and folder:FindFirstChild("FinalKill")
	if template and template:IsA("Frame") then
		local made = template:Clone()
		made.Parent = gui
		Ui.fit(made)
		card = made
		overlay = gui
		return
	end
	local holder = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(900, 80),
		BackgroundTransparency = 1,
	}, gui)
	Ui.text(holder, "FINAL KILL", "label", {
		Size = UDim2.new(1, 0, 0, 18),
		TextColor3 = C.gold,
	})
	caption = Ui.text(holder, "", "titleS", {
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 34,
		RichText = true,
	})
	Ui.fit(holder)
	overlay = gui
end

local function nameOf(x: Instance?): string
	if not x then
		return "THE ZONE"
	end
	if x:IsA("Player") then
		return string.upper(x.DisplayName)
	end
	return string.upper(x.Name)
end

local function teamColour(x: Instance?): Color3
	local mine = Teams.of(player)
	return if x and mine ~= nil and Teams.of(x) == mine then C.ally else C.enemy
end

-- Playback seconds → recorded seconds, and the speed there: normal, then an
-- eased ramp of `slowRamp` playback seconds down to `slowSpeed` that ends
-- `slowFrom` before the kill, then slow (MatchState.replayPlayback mirrors
-- this). Time stays continuous: no step into slow motion.
local function recordedAt(elapsed: number, start: number, kill: number): (number, number)
	local s, ramp = R.slowSpeed, R.slowRamp
	local slowAt = kill - R.slowFrom -- recorded time the ramp ends
	local rampFrom = slowAt - ramp * (1 + s) / 2 -- recorded time it starts
	local normal = rampFrom - start
	if elapsed <= normal then
		return start + elapsed, 1
	end
	local u = elapsed - normal
	if u <= ramp then
		return rampFrom + u - (1 - s) * u * u / (2 * ramp), 1 - (1 - s) * u / ramp
	end
	return slowAt + (u - ramp) * s, s
end

-- The killer's view as the server recorded it (the Replay event), on this
-- client's replay clock: times, unwrapped yaws, pitches.
type LookTrack = { t: { number }, yaw: { number }, pitch: { number } }

local function slopeAt(values: { number }, ts: { number }, i: number, n: number): number
	local a = math.max(i - 1, 1)
	local b = math.min(i + 1, n)
	local span = ts[b] - ts[a]
	return if span > 1e-4 then (values[b] - values[a]) / span else 0
end

-- Their yaw and pitch at `t` (cubic Hermite between samples; held at the ends).
local function lookAt(track: LookTrack, t: number): (number, number)
	local ts, yaws, pitches = track.t, track.yaw, track.pitch
	local n = #ts
	if t <= ts[1] then
		return yaws[1], pitches[1]
	elseif t >= ts[n] then
		return yaws[n], pitches[n]
	end
	local i = 1
	while i < n - 1 and ts[i + 1] < t do
		i += 1
	end
	local span = ts[i + 1] - ts[i]
	local u = if span > 1e-4 then (t - ts[i]) / span else 0
	local u2, u3 = u * u, u * u * u
	local function h(values: { number }): number
		return (2 * u3 - 3 * u2 + 1) * values[i]
			+ (u3 - 2 * u2 + u) * span * slopeAt(values, ts, i, n)
			+ (-2 * u3 + 3 * u2) * values[i + 1]
			+ (u3 - u2) * span * slopeAt(values, ts, i + 1, n)
	end
	return h(yaws), math.clamp(h(pitches), -1.45, 1.45)
end

type ServerHit = {
	t: number, -- this client's replay clock
	victim: Model?,
	damage: number,
	zone: string,
	killed: boolean,
	position: Vector3,
	source: string?,
	from: Vector3?, -- where the attacker stood (a hurt's damage arc)
}

-- Everything the replay changed, undone in one place (also after an error).
type Session = {
	folder: Folder?,
	tookCamera: boolean,
	hidden: { Instance },
	guis: { ScreenGui },
}

local function cleanup(session: Session)
	CameraController.setOverride(nil)
	local folder = session.folder
	if folder then
		folder:Destroy()
	end
	for _, d in session.hidden do
		local body = Fighters.bodyOfPart(d)
		if d.Parent and body and Health.isAlive(body) then
			(d :: any).LocalTransparencyModifier = 0
		end
	end
	for _, g in session.guis do
		if g.Parent then
			g.Enabled = true
		end
	end
	local gui = overlay
	if gui then
		gui.Enabled = false
	end
	ShotFxKit.setTimeScale(1)
	ViewmodelController.setTimeScale(1)
	if session.tookCamera then
		ViewmodelController.setSubject(nil)
		ViewmodelController.setHidden(false)
		EffectsController.setSpectated(nil, nil)
		CameraController.setZoom(nil, 0)
		HudController.setAim(0)
		HudController.setScope(false)
		HudController.setSubject(nil)
		HudController.setSpectating(false)
		HudController.setCrosshairVisible(true)
		WeaponController.setSpectating(false)
		local cam = Workspace.CurrentCamera
		if cam then
			cam.CameraType = Enum.CameraType.Custom
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				cam.CameraSubject = humanoid
			end
		end
	end
	playing = false
end

local function play(
	session: Session,
	victim: Model,
	serverKill: number,
	startAt: number,
	serverLook: LookTrack?,
	serverHits: { ServerHit },
	serverKiller: Instance?,
	serverPov: Instance?,
	serverHurts: { ServerHit }
)
	-- Centre on the kill as this client saw it (its frames lag the server's
	-- time by its latency), else the server's moment.
	local victimTrack = tracks[victim]
	local seen = victimTrack and victimTrack.downAt
	local kill = if seen
			and seen >= serverKill - 0.2
			and seen <= serverKill + 1
		then seen
		else serverKill
	local from, to = kill - R.before, kill + R.after
	local slots = slotsBetween(from - STEP, to + STEP)
	if #slots < 2 or not victimTrack then
		return -- joined too late, or never saw them
	end
	-- The killer (the server's word, else this client's Killed event) and whose
	-- eyes the replay plays from (the server picks: the killer for a gun or
	-- knife kill, else the victim). Always first person.
	local killer: Instance? = serverKiller or killers[victim]
	local killerBody = bodyOf(killer)
	local povBody: Model? = killerBody
	if serverPov then
		local victimOwner = Players:GetPlayerFromCharacter(victim)
		local isVictim = serverPov == victim or (victimOwner ~= nil and serverPov == victimOwner)
		povBody = if isVictim then victim else bodyOf(serverPov)
	end
	local povIsVictim = povBody == victim
	-- The server's look track and hits are on its clock, relative to the kill:
	-- they arrived as offsets (Replay event), so they line up with `kill` here.
	local lookTrack: LookTrack? = nil
	if serverLook and #serverLook.t >= 2 then
		local shifted: LookTrack = { t = {}, yaw = serverLook.yaw, pitch = serverLook.pitch }
		for i, dt in serverLook.t do
			shifted.t[i] = kill + dt
		end
		lookTrack = shifted
	end
	local windowHits: { ServerHit } = {}
	for _, hit in serverHits do
		local at = kill + hit.t
		if at >= from and at <= to + 0.5 then
			table.insert(windowHits, {
				t = at,
				victim = hit.victim,
				damage = hit.damage,
				zone = hit.zone,
				killed = hit.killed,
				position = hit.position,
				source = hit.source,
			})
		end
	end
	table.sort(windowHits, function(x: ServerHit, y: ServerHit): boolean
		return x.t < y.t
	end)
	local nextHit = 1
	-- From the victim's eyes: the hits they took (damage arcs, the red pulse).
	local windowHurts: { ServerHit } = {}
	if povIsVictim then
		for _, hurt in serverHurts do
			local at = kill + hurt.t
			if at >= from and at <= to + 0.5 then
				table.insert(windowHurts, {
					t = at,
					victim = hurt.victim,
					damage = hurt.damage,
					zone = hurt.zone,
					killed = hurt.killed,
					position = hurt.position,
					source = hurt.source,
					from = hurt.from,
				})
			end
		end
		table.sort(windowHurts, function(x: ServerHit, y: ServerHit): boolean
			return x.t < y.t
		end)
	end
	local nextHurt = 1

	-- Copies of everyone recorded in the window who was still up at its start.
	local folder = Instance.new("Folder")
	folder.Name = "ReplayActors"
	session.folder = folder
	local stepMods = ReplayModFx.stage(folder, from, to)
	local actors: { Actor } = {}
	local actorOf: { [Model]: Actor } = {}
	for body, track in tracks do
		if not body.Parent or (track.downAt ~= nil and track.downAt < from) then
			continue
		end
		local copy, joints = BodyClone.copy(body, "own", body.Name .. "_Replay")
		if copy then
			local parts: { [number]: BasePart? } = {}
			for i, part in track.parts do
				local twin = copy:FindFirstChild(part.Name)
				parts[i] = if twin and twin:IsA("BasePart") then twin else nil
			end
			copy.Parent = folder
			local actor: Actor =
				{ track = track, copy = copy, parts = parts, joints = joints, gone = false }
			table.insert(actors, actor)
			actorOf[body] = actor
		end
	end
	local victimActor = actorOf[victim]
	if not victimActor then
		return -- nothing to frame
	end
	-- `killerActor` is whoever we see through (the killer or, see above, the
	-- victim); `shooterActor` is the real killer (the victim tips away from them).
	local killerActor = if povBody then actorOf[povBody] else nil
	local shooterActor = if killerBody then actorOf[killerBody] else nil
	if not killerActor then
		-- Never third person: with no recording of whoever we'd see through,
		-- the victim's own eyes.
		killerActor = victimActor
		povIsVictim = true
	end
	local windowShots: { Shot } = {}
	for _, s in shots do
		if s.t >= from and s.t <= to then
			table.insert(windowShots, s)
		end
	end
	local nextShot = 1

	-- Wait for the common start (every client starts together).
	local waitFor = startAt - Workspace:GetServerTimeNow()
	if waitFor > 0 then
		task.wait(waitFor)
	end

	-- Take over the screen.
	SpectateController.stop()
	DeathFxController.clearGrade()
	session.tookCamera = true
	WeaponController.setSpectating(true)
	ViewmodelController.unequip() -- the match is over: no gun in the shot
	CameraController.setZoom(nil, 0)
	folder.Parent = Workspace
	for _, body in Fighters.bodies() do
		for _, d in body:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = 1
				table.insert(session.hidden, d)
			end
		end
	end
	for _, copy in CollectionService:GetTagged(DeathFxController.COPY_TAG) do
		if not copy:IsDescendantOf(folder) then
			for _, d in copy:GetDescendants() do
				if d:IsA("BasePart") or d:IsA("Decal") then
					d.LocalTransparencyModifier = 1
				end
			end
		end
	end
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		for _, g in playerGui:GetChildren() do
			-- the score and the notifications stay up during a replay
			-- (and the combat HUD: the killer's crosshair, hit markers and numbers)
			local keep = g.Name == "MatchHud"
				or g.Name == "TopBar"
				or g.Name == "Notify"
				or (g.Name == "CombatHud" and killerActor ~= nil)
			if g:IsA("ScreenGui") and g ~= overlay and not keep and g.Enabled then
				g.Enabled = false
				table.insert(session.guis, g)
			end
		end
	end
	local gui = overlay
	if gui then
		gui.Enabled = true
	end
	local made = card
	if made then
		local victimHolder: Instance = Players:GetPlayerFromCharacter(victim) or victim
		local strip = made:FindFirstChild("Strip")
		local function setText(name: string, text: string, color: Color3)
			local l = strip and strip:FindFirstChild(name)
			if l and l:IsA("TextLabel") then
				l.Text = text
				l.TextColor3 = color
			end
		end
		setText("Killer", nameOf(killer), teamColour(killer))
		setText("Victim", nameOf(victimHolder), teamColour(victimHolder))
		local with = killedWith[victim]
		local def = if with then Mods.def(with.id) else nil
		local weapon = strip and strip:FindFirstChild("Weapon")
		if weapon and weapon:IsA("ImageLabel") then
			weapon.Image = if def then def.icon elseif with then Theme.GUN[with.id] or "" else ""
			weapon.Size = if def then UDim2.fromOffset(30, 30) else UDim2.fromOffset(96, 30)
			weapon.Visible = weapon.Image ~= ""
		end
		local skull = strip and strip:FindFirstChild("Head")
		if skull and skull:IsA("GuiObject") then
			skull.Visible = with ~= nil and with.head
		end
	end
	local label = caption
	if label then
		local victimHolder: Instance = Players:GetPlayerFromCharacter(victim) or victim
		label.Text = string.format(
			'<font color="#%s">%s</font>   ›   <font color="#%s">%s</font>',
			teamColour(killer):ToHex(),
			nameOf(killer),
			teamColour(victimHolder):ToHex(),
			nameOf(victimHolder)
		)
	end
	local cam = Workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Scriptable
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = { folder }
	for _, body in Fighters.bodies() do
		table.insert(skip, body)
	end
	for _, copy in CollectionService:GetTagged(DeathFxController.COPY_TAG) do
		table.insert(skip, copy)
	end
	rayParams.FilterDescendantsInstances = skip

	-- The first offset from `anchor` with a clear line (a little past it too,
	-- so the camera isn't against a wall), else the one that gets furthest.
	local function clearSpot(anchor: Vector3, offsets: { Vector3 }): Vector3
		local best, bestLen = anchor + offsets[1], -1
		for _, off in offsets do
			local hit = Workspace:Raycast(anchor, off + off.Unit * 1.5, rayParams)
			if not hit then
				return anchor + off
			end
			local len = (hit.Position - anchor).Magnitude - 1.5
			if len > bestLen then
				bestLen = len
				best = anchor + off.Unit * math.max(len, 3)
			end
		end
		return best
	end

	local began = os.clock()
	local camPos: Vector3? = nil
	local camLook: Vector3? = nil
	local length = MatchState.replayPlayback()
	local warned = false
	local up = Vector3.yAxis

	-- The killer's first-person view, rebuilt from their recorded view like
	-- spectating (SpectateController): their eye over their root (lowered by
	-- the crouch / slide spring on their recorded MoveState), yaw and pitch
	-- (eased: Juice SPECTATE.aimRate), their gun in their skin, aim-down-sights
	-- and zoom; their own body is hidden (the camera is inside it).
	local S = Juice.SPECTATE
	local started = false
	local viewYaw, viewPitch = 0, 0
	local drop = CameraDrop.new()
	local vmWeapon = ""
	local vmConfig: any = nil
	local vmFirst = true -- the gun in their hands at the start: no draw
	local wasAiming: boolean? = nil
	local ads = 0
	local lastReload: number? = nil -- the reload / swing marks seen so far (nil: not yet)
	local lastSwing: number? = nil
	local swingMarks = false -- this body carries swing marks (a player's knife)
	local deathShown = false -- the victim's-eye view has gone down
	local killerParts: { Instance } = {}
	if killerActor then
		for _, d in killerActor.copy:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				table.insert(killerParts, d)
			end
		end
		-- Their skins: the killer (a Player, or a body that was theirs), else
		-- whoever the copied body belonged to when it was recorded.
		local killerPlayer: Player? = nil
		local seer: Instance? = if povIsVictim then (serverPov or victim) else killer
		if typeof(seer) == "Instance" then
			if seer:IsA("Player") then
				killerPlayer = seer
			elseif seer:IsA("Model") then
				killerPlayer = Players:GetPlayerFromCharacter(seer)
			end
		end
		ViewmodelController.setSubject(killerActor.copy, killerPlayer or killerActor.track.owner)
		-- Their HUD: crosshair, hit markers, damage numbers, scope (not yours).
		HudController.setSpectating(true)
		HudController.setSubject(killerActor.copy)
		EffectsController.setSpectated(killerActor.copy, function(config: any, left: boolean)
			if config.fireMode == "Melee" then
				-- A recorded swing mark plays the right step (killerView); a
				-- body with none (a bot) gets the first slash.
				if not swingMarks then
					ViewmodelController.swing("Slash1")
				end
			else
				local kick = (1 - 0.5 * ads) * (config.viewmodelKick or 1)
				ViewmodelController.fire(kick, if left then "Left" else nil, false)
				HudController.crosshairShot(math.max(config.recoil.up, Juice.SHOT_FEEL.upFloor))
				if config.scope ~= nil and ads >= VM.SCOPE_AT then
					HudController.scopeShot()
				end
			end
		end)
	end

	local function killerView(c: Camera, dt: number, t: number)
		local actor = killerActor :: Actor
		for _, d in killerParts do
			local part = d :: any
			if part.LocalTransparencyModifier ~= 1 then
				part.LocalTransparencyModifier = 1
			end
		end
		local track = actor.track
		local a, b, alpha = bracket(track, slots, t)
		local root = actor.copy:FindFirstChild("HumanoidRootPart")
		if not a or not root or not root:IsA("BasePart") then
			return
		end
		local serverTrack = lookTrack
		if serverTrack then
			-- The server's track: as smooth as they turned, no easing lag. Their
			-- samples reach the server a little late (`lag`): read that much earlier.
			viewYaw, viewPitch = lookAt(serverTrack, t - killerLag)
			started = true
		else
			local ya, yb = track.yaw[a], track.yaw[b]
			local yaw = ya + ((yb - ya + math.pi) % (2 * math.pi) - math.pi) * alpha
			local pitch = track.pitch[a] + (track.pitch[b] - track.pitch[a]) * alpha
			if not started then
				started = true
				viewYaw, viewPitch = yaw, pitch
			else
				viewYaw = Ease.approachAngle(viewYaw, yaw, S.aimRate, dt)
				viewPitch = Ease.approach(viewPitch, pitch, S.aimRate, dt)
			end
		end
		-- The root is posed from the recording (already interpolated): the eye
		-- sits on it like their own camera, no extra smoothing.
		local lowered = CameraDrop.step(drop, track.state[a], dt)
		-- Seen from the victim's eyes, their death stays first person: once
		-- they go down the eye sinks toward the floor, the view tips down and
		-- rolls, and the gun drops out (Config/Match REPLAY.deathView).
		local downAt = track.downAt
		local dying = 0
		if povIsVictim and downAt and t >= downAt then
			local dv = R.deathView
			local k = math.clamp((t - downAt) / dv.time, 0, 1)
			dying = 1 - (1 - k) * (1 - k) * (1 - k) -- ease out
			if not deathShown then
				deathShown = true
				ViewmodelController.setHidden(true)
				HudController.setCrosshairVisible(false, false)
			end
			viewPitch = viewPitch + (dv.pitch - viewPitch) * dying
		end
		local rotation = CFrame.fromEulerAnglesYXZ(viewPitch, viewYaw, 0)
		if dying > 0 then
			rotation *= CFrame.Angles(0, 0, R.deathView.roll * dying)
		end
		c.CFrame = CFrame.new(
			root.Position
				+ Vector3.new(0, S.eyeHeight - lowered - R.deathView.drop * dying, 0)
				- rotation.LookVector * S.eyeBack
		) * rotation

		-- Their gun: the one in their hands at the start comes up at rest; a
		-- swap in the window plays its real draw.
		local weapon = track.weapon[a]
		if weapon ~= vmWeapon then
			vmWeapon = weapon
			vmConfig = if weapon ~= "" then Weapons.get(weapon) else nil
			if vmConfig then
				if vmFirst then
					ViewmodelController.equip(vmConfig, nil, { instant = true })
				else
					ViewmodelController.equip(vmConfig, vmConfig.drawTime or vmConfig.equipTime)
				end
				vmFirst = false -- only once a gun is really in their hands
			else
				ViewmodelController.unequip()
			end
		end
		-- Their reloads and knife swings, from the recorded marks (those
		-- already going when the window starts don't replay).
		local reloadAt = track.reloadAt[a]
		if lastReload == nil then
			lastReload = reloadAt
		elseif reloadAt > lastReload then
			lastReload = reloadAt
			local left = track.reloadFor[a] - (t - reloadAt)
			if vmConfig and left > 0.1 then
				ViewmodelController.reload(left)
			end
		end
		local swingAt = track.swingAt[a]
		if swingAt ~= 0 then
			swingMarks = true
		end
		if lastSwing == nil then
			lastSwing = swingAt
		elseif swingAt ~= lastSwing then
			lastSwing = swingAt
			if vmConfig and vmConfig.fireMode == "Melee" then
				ViewmodelController.swing(
					if track.swingHeavy[a] then "HeavyStab" else "Slash" .. track.swingStep[a]
				)
			end
		end
		local config = vmConfig
		local aiming = track.aiming[a]
			and config ~= nil
			and config.fireMode ~= "Melee"
			and not config.noAds
		if config and wasAiming ~= nil and aiming ~= wasAiming then
			local set = GunSounds.get(config.id) :: any
			AudioController.playSound(set[if aiming then "aimIn" else "aimOut"], "Foley")
		end
		wasAiming = aiming
		local rate = 1 / math.max(if config then config.adsTime else 0.2, 0.05)
		ads = math.clamp(ads + (if aiming then rate else -rate) * dt, 0, 1)
		ViewmodelController.setAds(ads)
		local scope = config and config.scope
		CameraController.setZoom(
			if scope
				then CameraController.scopeFov(scope.zoom)
				elseif config then config.adsFov
				else nil,
			-- The zoom trails the gun, as for your own (VM.ADS_FEEL).
			ViewmodelController.adsZoom()
		)
		HudController.setAim(ViewmodelController.adsBlend())
		local scoped = scope ~= nil and ads >= VM.SCOPE_AT and not deathShown
		HudController.setScope(scoped)
		if not deathShown then
			ViewmodelController.setHidden(scoped)
			HudController.setCrosshairVisible(ads < 0.5 and config ~= nil, false)
		end
	end

	local function step(c: Camera, dt: number)
		local elapsed = math.min(os.clock() - began, length)
		local t, speed = recordedAt(elapsed, from, kill)
		stepMods(t)
		-- Tracers, impacts, the hit flash and the gun in hand run at the
		-- replay's speed too.
		ShotFxKit.setTimeScale(speed)
		ViewmodelController.setTimeScale(speed)
		-- Bodies: posed from the recording; the death fall when they go down.
		for _, actor in actors do
			if actor.gone then
				continue
			end
			local down = actor.track.downAt
			if down and t >= down then
				-- At the replay's speed, tipping away from the killer.
				local killerRoot = shooterActor
					and shooterActor.copy:FindFirstChild("HumanoidRootPart")
				fallNow(actor, folder, {
					timeScale = speed,
					awayFrom = if killerRoot and killerRoot:IsA("BasePart")
						then killerRoot.Position
						else nil,
				})
				continue
			end
			pose(actor, slots, t)
		end
		-- Live bodies stay hidden (some effects write the same property).
		for _, d in session.hidden do
			local part = d :: any
			if part.LocalTransparencyModifier ~= 1 then
				part.LocalTransparencyModifier = 1
			end
		end
		-- Shots up to now.
		while nextShot <= #windowShots and windowShots[nextShot].t <= t do
			local s = windowShots[nextShot]
			nextShot += 1
			local shooter = actorOf[s.body]
			if shooter and not shooter.gone and Weapons.get(s.weaponId) then
				EffectsController.playShot(shooter.copy, s.weaponId, s.origin, s.ends)
			end
		end
		-- The killer's hits (the server's), as they saw them: hit marker,
		-- damage number on the copy they hit, headshot flash, kill marker.
		while nextHit <= #windowHits and windowHits[nextHit].t <= t do
			local hit = windowHits[nextHit]
			nextHit += 1
			if killerActor then
				local victimActor2 = if hit.victim then actorOf[hit.victim] else nil
				WeaponController.presentHit({
					damage = hit.damage,
					zone = hit.zone :: any,
					killed = hit.killed,
					position = hit.position,
					source = hit.source,
					victim = if victimActor2 then victimActor2.copy else nil,
				} :: Types.HitConfirm)
			end
		end
		-- From the victim's eyes: the hits they took, as damage arcs and the
		-- red edge pulse.
		while nextHurt <= #windowHurts and windowHurts[nextHurt].t <= t do
			local hurt = windowHurts[nextHurt]
			nextHurt += 1
			local origin = hurt.from
			if origin then
				HudController.damageFrom(origin)
				HudController.flinch(origin, math.min(hurt.damage, 500))
			end
		end
		-- Camera: through the killer's eyes, as they saw it (their gun and
		-- arms in the viewmodel). With no killer (the zone), a slow orbit.
		if killerActor then
			killerView(c, dt, t)
			return
		end
		local victimRoot = victimActor.copy:FindFirstChild("HumanoidRootPart")
		if not victimRoot or not victimRoot:IsA("BasePart") then
			return
		end
		local target = victimRoot.Position + up
		local angle = elapsed * 0.35
		local wantPos = clearSpot(target, {
			Vector3.new(math.cos(angle) * 9, 4, math.sin(angle) * 9),
			Vector3.new(0, 9, 0),
		})
		local k = 1 - math.exp(-6 * dt)
		local pos = if camPos then camPos:Lerp(wantPos, k) else wantPos
		local look = if camLook then camLook:Lerp(target, k) else target
		camPos, camLook = pos, look
		c.CFrame = CFrame.lookAt(pos, look)
	end
	CameraController.setOverride(function(c: Camera, dt: number)
		local ok, err = pcall(step, c, dt)
		if not ok and not warned then
			warned = true
			warn("[ReplayController]", err)
		end
	end)

	task.wait(length + R.hold)
end

-- The server's look track (Replay event): f32 seconds from the kill, f32
-- yaw, f32 pitch per sample. Checked: whole samples, finite, in order; yaw
-- unwrapped. nil when missing or broken (the local recording is used).
local LOOK_SAMPLE = 12
local LOOK_MAX = 1024
function decodeLook(look: unknown): LookTrack?
	if typeof(look) ~= "buffer" then
		return nil
	end
	local size = buffer.len(look)
	if size < LOOK_SAMPLE * 2 or size % LOOK_SAMPLE ~= 0 or size > LOOK_SAMPLE * LOOK_MAX then
		return nil
	end
	local track: LookTrack = { t = {}, yaw = {}, pitch = {} }
	for i = 0, size // LOOK_SAMPLE - 1 do
		local at = i * LOOK_SAMPLE
		local dt = buffer.readf32(look, at)
		local yaw = buffer.readf32(look, at + 4)
		local pitch = buffer.readf32(look, at + 8)
		if
			dt ~= dt
			or yaw ~= yaw
			or pitch ~= pitch
			or math.abs(dt) > 30
			or math.abs(yaw) > 100
			or math.abs(pitch) > 2
		then
			return nil
		end
		local n = #track.t
		if n > 0 then
			if dt <= track.t[n] then
				continue
			end
			local prev = track.yaw[n]
			yaw = prev + ((yaw - prev + math.pi) % (2 * math.pi) - math.pi)
		end
		table.insert(track.t, dt)
		table.insert(track.yaw, yaw)
		table.insert(track.pitch, math.clamp(pitch, -1.45, 1.45))
	end
	return if #track.t >= 2 then track else nil
end

-- The killer's hits (Replay event), checked field by field (`t` = seconds
-- from the kill).
local HITS_MAX = 64
function decodeHits(hits: unknown): { ServerHit }
	local out: { ServerHit } = {}
	if typeof(hits) ~= "table" then
		return out
	end
	for _, h in hits :: { any } do
		if #out >= HITS_MAX then
			break
		end
		if typeof(h) ~= "table" then
			continue
		end
		local dt, damage, zone, position = h.dt, h.damage, h.zone, h.position
		if
			typeof(dt) == "number"
			and dt == dt
			and math.abs(dt) <= 30
			and typeof(damage) == "number"
			and damage == damage
			and typeof(zone) == "string"
			and typeof(position) == "Vector3"
		then
			local victim = h.victim
			table.insert(out, {
				t = dt,
				victim = if typeof(victim) == "Instance" and victim:IsA("Model")
					then victim
					else nil,
				damage = math.clamp(damage, 0, 10000),
				zone = zone,
				killed = h.killed == true,
				position = position,
				source = if typeof(h.source) == "string" then h.source else nil,
				from = if typeof(h.from) == "Vector3" then h.from else nil,
			})
		end
	end
	return out
end

function ReplayController.isPlaying(): boolean
	return playing
end

function ReplayController.start()
	buildUi()
	local function updateRecording()
		local phase = MatchState.phase()
		recording = R.enabled
			and not TestMode.isOn()
			and (phase == "Live" or phase == "SuddenDeath")
		if phase == "Countdown" or phase == "Waiting" then
			ReplayModFx.clear()
		end
	end
	MatchState.changed("Phase"):Connect(updateRecording)
	updateRecording()
	RunService.PreRender:Connect(record)
	Net.event("ModFx").OnClientEvent:Connect(function(kind: unknown, data: unknown)
		if not recording or playing or typeof(kind) ~= "string" or typeof(data) ~= "table" then
			return
		end
		local payload = data :: { [string]: any }
		local caster = payload.caster
		if typeof(caster) ~= "Instance" or not sameMatch(caster) then
			return
		end
		ReplayModFx.capture(kind, payload, Workspace:GetServerTimeNow())
	end)
	Net.unreliable("ShotFx").OnClientEvent
		:Connect(function(shooter: unknown, weaponId: unknown, origin: unknown, ends: unknown)
			addShot(bodyOf(shooter), weaponId, origin, ends)
		end)
	ShotLog.listen(function(weaponId: string, origin: Vector3, ends: { Vector3 })
		addShot(player.Character, weaponId, origin, ends)
	end)
	Net.event("Killed").OnClientEvent
		:Connect(function(victim: unknown, attacker: unknown, sourceId: unknown, headshot: unknown)
			if
				typeof(victim) == "Instance"
				and victim:IsA("Model")
				and typeof(attacker) == "Instance"
			then
				killers[victim] = attacker
				killedWith[victim] = {
					id = if typeof(sourceId) == "string" then sourceId else "",
					head = headshot == true,
				}
			end
		end)
	Net.event("Replay").OnClientEvent:Connect(
		function(
			victim: unknown,
			killTime: unknown,
			startAt: unknown,
			killerArg: unknown,
			look: unknown,
			lag: unknown,
			hits: unknown,
			povArg: unknown,
			hurts: unknown
		)
			if
				playing
				or typeof(victim) ~= "Instance"
				or not victim:IsA("Model")
				or typeof(killTime) ~= "number"
				or typeof(startAt) ~= "number"
			then
				return
			end
			local body: Model = victim
			local kill: number = killTime
			local start: number = startAt
			local serverLook = decodeLook(look)
			local serverHits = decodeHits(hits)
			local serverHurts = decodeHits(hurts)
			local serverKiller: Instance? = if typeof(killerArg) == "Instance"
				then killerArg
				else nil
			local serverPov: Instance? = if typeof(povArg) == "Instance" then povArg else nil
			killerLag = if typeof(lag) == "number" and lag == lag then math.clamp(lag, 0, 1) else 0
			playing = true -- the ring freezes from here
			task.spawn(function()
				local session: Session =
					{ folder = nil, tookCamera = false, hidden = {}, guis = {} }
				local ok, err = pcall(
					play,
					session,
					body,
					kill,
					start,
					serverLook,
					serverHits,
					serverKiller,
					serverPov,
					serverHurts
				)
				if not ok then
					warn("[ReplayController]", err)
				end
				cleanup(session)
			end)
		end
	)
end

return ReplayController
