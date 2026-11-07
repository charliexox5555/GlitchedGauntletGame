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
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Match)
local Ease = require(ReplicatedStorage.Shared.Util.Ease)
local Fighters = require(ReplicatedStorage.Shared.Util.Fighters)
local Health = require(ReplicatedStorage.Shared.Health)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Net = require(ReplicatedStorage.Shared.Net)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local TestMode = require(ReplicatedStorage.Shared.TestMode)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local CameraController = require(script.Parent.CameraController)
local DeathFxController = require(script.Parent.DeathFxController)
local EffectsController = require(script.Parent.EffectsController)
local SpectateController = require(script.Parent.SpectateController)
local ViewmodelController = require(script.Parent.ViewmodelController)
local WeaponController = require(script.Parent.WeaponController)
local ShotLog = require(script.Parent.Parent.Util.ShotLog)
local BodyClone = require(script.Parent.Parent.Util.BodyClone)
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
}

type Shot = { t: number, body: Model, weaponId: string, origin: Vector3, ends: { Vector3 } }

local times: { number } = table.create(FRAMES, -math.huge)
local head = 0 -- the ring slot written last
local tracks: { [Model]: Track } = {}
local shots: { Shot } = {}
local killers: { [Model]: Instance } = setmetatable({}, { __mode = "k" }) :: any
local nextSample = 0
local playing = false
local recording = false

local function newTrack(body: Model): Track
	local parts: { BasePart } = {}
	for _, child in body:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	return {
		body = body,
		parts = parts,
		frames = table.create(FRAMES),
		stamps = table.create(FRAMES, -math.huge),
		downAt = nil,
		lastSeen = 0,
		yaw = table.create(FRAMES, 0),
		pitch = table.create(FRAMES, 0),
		aiming = table.create(FRAMES, false),
		weapon = table.create(FRAMES, ""),
	}
end

-- Where a fighter is looking now. Yours comes straight from your camera;
-- anyone else's from their body's facing and the AimPitch / Aiming
-- attributes (players: WeaponService's Aim remote; bots: Bots/Brain).
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
		local root = body:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local look = root.CFrame.LookVector
			yaw = math.atan2(-look.X, -look.Z)
		end
		local p = holder:GetAttribute("AimPitch")
		pitch = if typeof(p) == "number" and p == p then math.clamp(p, -1.45, 1.45) else 0
	end
	local world = body:FindFirstChild("WorldWeapon")
	local id = world and world:GetAttribute("WeaponId")
	return yaw,
		pitch,
		holder:GetAttribute("Aiming") == true,
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
	head = head % FRAMES + 1
	times[head] = t
	for _, body in Fighters.bodies() do
		local track = tracks[body]
		if not track then
			track = newTrack(body)
			tracks[body] = track
		end
		track.lastSeen = t
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

local function pose(actor: Actor, slots: { number }, t: number)
	local track = actor.track
	local a, b, alpha = bracket(track, slots, t)
	if not a then
		return
	end
	local fa, fb = track.frames[a], track.frames[b]
	for i, part in actor.parts do
		local cf = fa[i]
		if part and cf then
			local other = fb[i]
			part.CFrame = if other then cf:Lerp(other, alpha) else cf
		end
	end
end

-- Its fall at the moment it went down: the joints come back so DeathFx's
-- copy of it hangs together, and that copy goes with the replay's folder.
local function fallNow(actor: Actor, folder: Instance)
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
	DeathFxController.playFall(actor.copy, folder)
end

-- UI: letterbox bars and the FINAL KILL line.
local overlay: ScreenGui? = nil
local caption: TextLabel? = nil
local function buildUi()
	local gui = Ui.make("ScreenGui", {
		Name = "Replay",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
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

-- Recorded seconds → playback seconds: normal until `slowFrom` before the
-- kill, then `slowSpeed`.
local function recordedAt(elapsed: number, start: number, kill: number): number
	local normal = (kill - R.slowFrom) - start
	if elapsed <= normal then
		return start + elapsed
	end
	return start + normal + (elapsed - normal) * R.slowSpeed
end

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
	if session.tookCamera then
		ViewmodelController.setSubject(nil)
		ViewmodelController.setHidden(false)
		EffectsController.setSpectated(nil, nil)
		CameraController.setZoom(nil, 0)
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

local function play(session: Session, victim: Model, serverKill: number, startAt: number)
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
	local killer = killers[victim]
	local killerBody = bodyOf(killer)

	-- Copies of everyone recorded in the window who was still up at its start.
	local folder = Instance.new("Folder")
	folder.Name = "ReplayActors"
	session.folder = folder
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
	local killerActor = if killerBody then actorOf[killerBody] else nil
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
			if g:IsA("ScreenGui") and g ~= overlay and g.Name ~= "MatchHud" and g.Enabled then
				g.Enabled = false
				table.insert(session.guis, g)
			end
		end
	end
	local gui = overlay
	if gui then
		gui.Enabled = true
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
	-- spectating (SpectateController): their head, yaw and pitch (smoothed:
	-- others' pitch arrives 10 times a second), their gun, aim-down-sights
	-- and zoom; their own body is hidden (the camera is inside it).
	local viewPos: Vector3? = nil
	local viewYaw, viewPitch = 0, 0
	local vmWeapon = ""
	local vmConfig: any = nil
	local ads = 0
	local killerParts: { Instance } = {}
	if killerActor then
		for _, d in killerActor.copy:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				table.insert(killerParts, d)
			end
		end
		ViewmodelController.setSubject(killerActor.copy)
		EffectsController.setSpectated(killerActor.copy, function(config: any, left: boolean)
			if config.fireMode == "Melee" then
				ViewmodelController.swing()
			elseif left then
				ViewmodelController.fire(1 - 0.5 * ads, "Left", false)
			else
				ViewmodelController.fire(1 - 0.5 * ads, nil, false)
			end
		end)
	end

	local function killerView(c: Camera, dt: number, t: number)
		local actor = killerActor :: Actor
		for _, d in killerParts do
			(d :: any).LocalTransparencyModifier = 1
		end
		local track = actor.track
		local a, b, alpha = bracket(track, slots, t)
		local headPart = actor.copy:FindFirstChild("Head")
		if not a or not headPart or not headPart:IsA("BasePart") then
			return
		end
		local ya, yb = track.yaw[a], track.yaw[b]
		local yaw = ya + ((yb - ya + math.pi) % (2 * math.pi) - math.pi) * alpha
		local pitch = track.pitch[a] + (track.pitch[b] - track.pitch[a]) * alpha
		local pos = viewPos
		if pos == nil then
			viewPos = headPart.Position
			viewYaw, viewPitch = yaw, pitch
		else
			viewPos = pos:Lerp(headPart.Position, 1 - math.exp(-25 * dt))
			local dy = (yaw - viewYaw + math.pi) % (2 * math.pi) - math.pi
			viewYaw += dy * (1 - math.exp(-20 * dt))
			viewPitch += (pitch - viewPitch) * (1 - math.exp(-16 * dt))
		end
		c.CFrame = CFrame.new(viewPos :: Vector3) * CFrame.fromEulerAnglesYXZ(viewPitch, viewYaw, 0)

		-- Their gun (no draw: it's already in their hands).
		local weapon = track.weapon[a]
		if weapon ~= vmWeapon then
			vmWeapon = weapon
			vmConfig = if weapon ~= "" then Weapons.get(weapon) else nil
			if vmConfig then
				ViewmodelController.equip(vmConfig, 0.05)
			else
				ViewmodelController.unequip()
			end
		end
		local config = vmConfig
		local aiming = track.aiming[a]
			and config ~= nil
			and config.fireMode ~= "Melee"
			and not config.noAds
		local rate = 1 / math.max(if config then config.adsTime else 0.2, 0.05)
		ads = math.clamp(ads + (if aiming then rate else -rate) * dt, 0, 1)
		ViewmodelController.setAds(ads)
		local scope = config and config.scope
		local zoomFov: number? = nil
		if scope then
			local base = CameraController.getBaseFov()
			zoomFov = 2
				* math.deg(math.atan(math.tan(math.rad(base / 2)) / math.max(scope.zoom, 1)))
		elseif config then
			zoomFov = config.adsFov
		end
		CameraController.setZoom(zoomFov, Ease.smooth(ads))
		ViewmodelController.setHidden(scope ~= nil and ads > 0.85)
	end

	local function step(c: Camera, dt: number)
		local elapsed = math.min(os.clock() - began, length)
		local t = recordedAt(elapsed, from, kill)
		-- Bodies: posed from the recording; the death fall when they go down.
		for _, actor in actors do
			if actor.gone then
				continue
			end
			local down = actor.track.downAt
			if down and t >= down then
				fallNow(actor, folder)
				continue
			end
			pose(actor, slots, t)
		end
		-- Live bodies stay hidden (some effects write the same property).
		for _, d in session.hidden do
			(d :: any).LocalTransparencyModifier = 1
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

function ReplayController.isPlaying(): boolean
	return playing
end

function ReplayController.start()
	buildUi()
	local function updateRecording()
		local phase = MatchState.phase()
		recording = not TestMode.isOn() and (phase == "Live" or phase == "SuddenDeath")
	end
	MatchState.changed("Phase"):Connect(updateRecording)
	updateRecording()
	RunService.PreRender:Connect(record)
	Net.unreliable("ShotFx").OnClientEvent
		:Connect(function(shooter: unknown, weaponId: unknown, origin: unknown, ends: unknown)
			addShot(bodyOf(shooter), weaponId, origin, ends)
		end)
	ShotLog.listen(function(weaponId: string, origin: Vector3, ends: { Vector3 })
		addShot(player.Character, weaponId, origin, ends)
	end)
	Net.event("Killed").OnClientEvent:Connect(function(victim: unknown, attacker: unknown)
		if
			typeof(victim) == "Instance"
			and victim:IsA("Model")
			and typeof(attacker) == "Instance"
		then
			killers[victim] = attacker
		end
	end)
	Net.event("Replay").OnClientEvent
		:Connect(function(victim: unknown, killTime: unknown, startAt: unknown)
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
			playing = true -- the ring freezes from here
			task.spawn(function()
				local session: Session =
					{ folder = nil, tookCamera = false, hidden = {}, guis = {} }
				local ok, err = pcall(play, session, body, kill, start)
				if not ok then
					warn("[ReplayController]", err)
				end
				cleanup(session)
			end)
		end)
end

return ReplayController
