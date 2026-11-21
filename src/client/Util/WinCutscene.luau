--!strict
-- The end-of-match winner cutscene (vault/02 Art/Win Cutscene.md; data in
-- Config/WinCutscene, clips in Config/Animations WIN). Client only: copies of
-- the winners on the map's stage, each playing its slot's clip, and the
-- camera through the scene's shots, all on the ending song's clock (the song
-- is the timeline: a frame reads where the song is, so nothing drifts at a
-- low frame rate). It ends held on the final pose: the hold loop on the
-- copies, the last shot's camera breathing with a slow handheld drift.
--
--   WinCutscene.preload()                   load the clips and the song early
--   WinCutscene.play(winners, opts)         the live winner bodies, lead first
--   WinCutscene.copies()                    { { copy, body } } for name plates
--   WinCutscene.stop()
--
-- opts.onScreen() is called once, at Config SCREEN_AT or when the player
-- skips (a click / key after SKIP_AFTER), for the results screen.
-- opts.onFrame() runs every camera frame (the controller keeps live bodies
-- hidden). The caller owns the camera override's lifetime through stop().

local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Animations = require(ReplicatedStorage.Shared.Config.Animations)
local Config = require(ReplicatedStorage.Shared.Config.WinCutscene)
local Fighters = require(ReplicatedStorage.Shared.Util.Fighters)

local CameraController = require(script.Parent.Parent.Controllers.CameraController)
local BodyClone = require(script.Parent.BodyClone)
local UiSound = require(script.Parent.UiSound)

local WinCutscene = {}

export type Options = {
	onScreen: (() -> ())?,
	onFrame: (() -> ())?,
}

type Actor = {
	copy: Model,
	body: Model,
	clip: AnimationTrack?,
	hold: AnimationTrack?,
	holdKey: string,
	clipLength: number,
	base: CFrame, -- the copy's pivot on the stage
	root: { Config.RootKey }?,
	holding: boolean,
}

type Run = {
	scene: Config.Scene,
	stage: CFrame,
	folder: Folder,
	actors: { Actor },
	gui: ScreenGui,
	flash: Frame,
	bars: { Frame },
	grade: ColorCorrectionEffect,
	song: Sound?,
	songLate: boolean,
	songStarted: boolean,
	asked: number, -- when play() started the song
	began: number,
	offset: number, -- cutscene time = os.clock() - began + offset
	skipped: boolean,
	frozen: number?, -- Studio preview: held at this time (captures)
	screenShown: boolean,
	barsOut: boolean,
	opts: Options,
	connections: { RBXScriptConnection },
	cuesFired: { [number]: boolean },
	cueSounds: { Sound },
	seed: number,
}

local run: Run? = nil
local player = Players.LocalPlayer

-- The stage ------------------------------------------------------------------------

local function flat(look: Vector3): Vector3
	local f = Vector3.new(look.X, 0, look.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.new(0, 0, -1)
end

-- The anchor: the map's tagged part, else the fallback spot on the Baseplate.
-- Returns its point (on or above the floor), the winners' facing, and
-- whether it is the fallback.
local function anchor(): (Vector3, Vector3, boolean)
	local map = Workspace:FindFirstChild("ActiveMap")
	if map then
		for _, part in CollectionService:GetTagged(Config.STAGE_TAG) do
			if part:IsA("BasePart") and part:IsDescendantOf(map) then
				return part.Position, flat(part.CFrame.LookVector), false
			end
		end
	end
	local fb = Config.FALLBACK
	local face = CFrame.Angles(0, math.rad(fb.yaw), 0):VectorToWorldSpace(Vector3.new(0, 0, -1))
	local base = Workspace:FindFirstChild(fb.part)
	if base and base:IsA("BasePart") then
		local top = base.Position.Y + base.Size.Y / 2
		return Vector3.new(fb.at.X, top + fb.at.Y, fb.at.Z), face, true
	end
	return fb.at, face, true
end

-- The stage's frame: on the floor under the anchor, -Z = the winners' facing.
local function stageFrame(folder: Folder): CFrame
	local at, face, fallback = anchor()
	pcall(function()
		player:RequestStreamAroundAsync(at, 1)
	end)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = {}
	for _, body in Fighters.bodies() do
		table.insert(skip, body)
	end
	params.FilterDescendantsInstances = skip
	local probe = Config.GROUND_PROBE
	local hit =
		Workspace:Raycast(at + Vector3.new(0, probe, 0), Vector3.new(0, -2 * probe, 0), params)
	local ground = if hit then hit.Position else at
	if not hit and fallback then
		-- The Baseplate streamed out (it's far from the map): a floor of our own.
		local floor = Instance.new("Part")
		floor.Name = "StageFloor"
		floor.Anchored = true
		floor.CanCollide = false
		floor.CanQuery = false
		floor.CanTouch = false
		floor.Material = Enum.Material.Concrete
		floor.Color = Color3.fromRGB(99, 95, 98)
		floor.Size = Vector3.new(400, 2, 400)
		floor.CFrame = CFrame.new(at - Vector3.new(0, 1, 0))
		floor.Parent = folder
	end
	return CFrame.lookAt(ground, ground + face)
end

-- Stage space { right, up, forward } to world.
local function world(stage: CFrame, p: Vector3): Vector3
	return stage:PointToWorldSpace(Vector3.new(p.X, p.Y, -p.Z))
end

-- The actors -----------------------------------------------------------------------

local function animatorOf(copy: Model): Animator?
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		local made = Instance.new("Animator")
		made.Parent = humanoid
		animator = made
	end
	return animator
end

local function load(animator: Animator, key: string, looped: boolean): AnimationTrack?
	local id = Animations.WIN[key]
	if not id then
		warn("[WinCutscene] no clip", key)
		return nil
	end
	local clip = Instance.new("Animation")
	clip.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(clip)
	end)
	if not ok or not track then
		return nil
	end
	track.Looped = looped
	track.Priority = Enum.AnimationPriority.Action4
	return track
end

local function place(r: Run, body: Model, slot: Config.Slot, pos: Vector3)
	local copy = BodyClone.copy(body, "root")
	if not copy then
		return
	end
	-- Kinematic: the joints pose straight from the clip (no physics lag at a
	-- low frame rate) with the root anchored on the stage.
	BodyClone.kinematic(copy)
	local root = copy:FindFirstChild("HumanoidRootPart")
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	local hip = 3
	if root and root:IsA("BasePart") and humanoid then
		hip = humanoid.HipHeight + root.Size.Y / 2
	end
	local at = world(r.stage, pos) + Vector3.new(0, hip, 0)
	local facing = r.stage * CFrame.Angles(0, math.rad(slot.yaw), 0)
	copy:PivotTo(CFrame.lookAt(at, at + facing.LookVector))
	copy.Parent = r.folder
	local actor: Actor = {
		copy = copy,
		body = body,
		clip = nil,
		hold = nil,
		holdKey = slot.hold,
		clipLength = 0,
		base = copy:GetPivot(),
		root = slot.root,
		holding = false,
	}
	local animator = animatorOf(copy)
	if animator then
		for _, t in animator:GetPlayingAnimationTracks() do
			t:Stop(0)
		end
		actor.clip = load(animator, slot.clip, false)
		actor.hold = load(animator, slot.hold, true)
		local clip = actor.clip
		if clip then
			clip:Play(0)
		end
	end
	table.insert(r.actors, actor)
end

-- A slot's root move at song time t: (yaw degrees, lift studs), on a
-- Catmull-Rom through its keys that starts and ends at rest.
local function rootAt(keys: { Config.RootKey }, t: number): (number, number)
	local n = #keys
	if t <= keys[1].t then
		return keys[1].yaw, keys[1].lift
	end
	if t >= keys[n].t then
		return keys[n].yaw, keys[n].lift
	end
	local function tangent(i: number): Vector2
		if i == 1 or i == n then
			return Vector2.zero
		end
		local a, b = keys[i - 1], keys[i + 1]
		return Vector2.new(b.yaw - a.yaw, b.lift - a.lift) / (b.t - a.t)
	end
	for i = 1, n - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b.t then
			local h = b.t - a.t
			local s = (t - a.t) / h
			local s2, s3 = s * s, s * s * s
			local v = Vector2.new(a.yaw, a.lift) * (2 * s3 - 3 * s2 + 1)
				+ tangent(i) * h * (s3 - 2 * s2 + s)
				+ Vector2.new(b.yaw, b.lift) * (-2 * s3 + 3 * s2)
				+ tangent(i + 1) * h * (s3 - s2)
			return v.X, v.Y
		end
	end
	return keys[n].yaw, keys[n].lift
end

-- The camera -----------------------------------------------------------------------

-- Hermite on a time-parameterised Catmull-Rom through the shot's keys; the
-- values (eye, look-at, (fov, roll, 0)) are Vector3s.
local function curve(shot: Config.Shot, t: number, pick: (Config.Key) -> Vector3): Vector3
	local keys = shot.keys
	local n = #keys
	if n == 1 or t <= keys[1].t then
		return pick(keys[1])
	end
	if t >= keys[n].t then
		return pick(keys[n])
	end
	local function tangent(i: number): Vector3
		if i == 1 then
			if shot.startStill then
				return Vector3.zero
			end
			return (pick(keys[2]) - pick(keys[1])) / (keys[2].t - keys[1].t)
		elseif i == n then
			if shot.finishStill ~= false then
				return Vector3.zero
			end
			return (pick(keys[n]) - pick(keys[n - 1])) / (keys[n].t - keys[n - 1].t)
		end
		return (pick(keys[i + 1]) - pick(keys[i - 1])) / (keys[i + 1].t - keys[i - 1].t)
	end
	for i = 1, n - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b.t then
			local h = b.t - a.t
			local s = (t - a.t) / h
			local s2, s3 = s * s, s * s * s
			return pick(a) * (2 * s3 - 3 * s2 + 1)
				+ tangent(i) * h * (s3 - 2 * s2 + s)
				+ pick(b) * (-2 * s3 + 3 * s2)
				+ tangent(i + 1) * h * (s3 - s2)
		end
	end
	return pick(keys[n])
end

local function eyeOf(k: Config.Key): Vector3
	return k.eye
end
local function atOf(k: Config.Key): Vector3
	return k.at
end
local function lensOf(k: Config.Key): Vector3
	return Vector3.new(k.fov, k.roll or 0, 0)
end

local function shotAt(scene: Config.Scene, t: number): Config.Shot
	for _, shot in scene.shots do
		if t >= shot.from and t < shot.to then
			return shot
		end
	end
	return if t < scene.shots[1].from then scene.shots[1] else scene.shots[#scene.shots]
end

local function envelope(dt: number, decay: number): number
	if dt < 0 then
		return 0
	end
	local attack = Config.KICK_ATTACK
	if dt < attack then
		return dt / attack
	end
	return math.exp(-(dt - attack) / math.max(decay, 1e-3))
end

local function sway(spec: { number }, t: number, phase: number): number
	return spec[1] * math.sin(2 * math.pi * t / spec[2] + phase)
		+ spec[3] * math.sin(2 * math.pi * t / spec[4] + phase * 2.3)
end

local function cameraAt(r: Run, t: number): (CFrame, number)
	local scene = r.scene
	local shot = shotAt(scene, t)
	local eye = curve(shot, t, eyeOf)
	local at = curve(shot, t, atOf)
	local lens = curve(shot, t, lensOf)
	local fov, roll = lens.X, lens.Y
	local shake = 0
	for _, k in scene.kicks do
		local e = envelope(t - k.t, k.decay)
		if e > 0 then
			fov += (k.fov or 0) * e
			shake += (k.shake or 0) * e
		end
	end
	local hh = Config.HANDHELD
	local pitch = sway(hh.pitch, t, 0.3)
	local yaw = sway(hh.yaw, t, 1.7)
	local rollSway = sway(hh.roll, t, 2.9)
	if shake > 0 then
		local rate = Config.SHAKE_RATE * t
		pitch += shake * math.noise(rate, r.seed, 0.5) * 2
		yaw += shake * math.noise(r.seed, rate, 1.5) * 2
		rollSway += shake * 0.6 * math.noise(rate, 2.5, r.seed) * 2
	end
	local cf = CFrame.lookAt(world(r.stage, eye), world(r.stage, at))
	-- the held final shot floats a little once its last key is reached
	local last = shot.keys[#shot.keys].t
	if shot == scene.shots[#scene.shots] and t > last then
		local hf = Config.HOLD_FLOAT
		local w = math.clamp((t - last) / hf.fadeIn, 0, 1)
		w = w * w * (3 - 2 * w)
		local u = t - last
		cf *= CFrame.new(
			w * hf.x * math.sin(2 * math.pi * u / hf.xPeriod),
			w * hf.y * math.sin(2 * math.pi * u / hf.yPeriod + 1.1),
			0
		)
	end
	cf *= CFrame.Angles(math.rad(pitch), math.rad(yaw), math.rad(roll + rollSway))
	return cf, fov
end

-- The overlay (flash, bars) and grade ---------------------------------------------

local function overlay(): (ScreenGui, Frame, { Frame })
	local gui = Instance.new("ScreenGui")
	gui.Name = "WinCutscene"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local bars: { Frame } = {}
	for i, y in { 0, 1 } do
		local bar = Instance.new("Frame")
		bar.Name = if i == 1 then "BarTop" else "BarBottom"
		bar.AnchorPoint = Vector2.new(0, y)
		bar.Position = UDim2.fromScale(0, y)
		bar.Size = UDim2.fromScale(1, 0)
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.Parent = gui
		table.insert(bars, bar)
	end
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 2
	flash.Parent = gui
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	gui.Parent = playerGui
	return gui, flash, bars
end

local function moveBars(r: Run, open: boolean, time: number)
	local size = if open then Config.BARS.size else 0
	for _, bar in r.bars do
		TweenService:Create(
			bar,
			TweenInfo.new(
				time,
				Enum.EasingStyle.Quint,
				if open then Enum.EasingDirection.Out else Enum.EasingDirection.InOut
			),
			{ Size = UDim2.fromScale(1, size) }
		):Play()
	end
end

-- Sound accents ---------------------------------------------------------------------

-- Starts a cue so its hit lands on its time: `late` seconds past the start
-- (a cue fired after its start time joins part way in).
local function fireCue(r: Run, cue: Config.Cue, late: number)
	local snd = Instance.new("Sound")
	snd.Name = "WinCue" .. cue.name
	snd.SoundId = "rbxassetid://" .. tostring(cue.id)
	snd.Volume = cue.vol
	local song = r.song
	if song then
		snd.SoundGroup = song.SoundGroup -- the ending song's group (UI sounds)
	end
	snd.Parent = r.folder
	snd.TimePosition = math.max(late, 0)
	snd:Play()
	table.insert(r.cueSounds, snd)
end

local function cues(r: Run, t: number)
	if r.frozen then
		return
	end
	for i, cue in r.scene.cues do
		if not r.cuesFired[i] then
			local start = cue.t - cue.hit
			if t >= start then
				r.cuesFired[i] = true
				-- more than a beat late (a skip, a hitch): skip it
				if t - cue.t < 0.15 then
					fireCue(r, cue, t - start)
				end
			end
		end
	end
end

-- The clock ------------------------------------------------------------------------

local function clock(r: Run): number
	if r.frozen then
		return r.frozen :: number
	end
	local own = os.clock() - r.began + r.offset
	local song = r.song
	if r.skipped or r.songLate or not song then
		return own
	end
	if song.IsPlaying and song.TimePosition > 0 then
		r.songStarted = true
		local at = song.TimePosition
		if math.abs(at - own) > Config.SYNC_SNAP then
			r.offset += at - own
			return at
		end
		return own
	end
	if not r.songStarted then
		-- Not started yet (still loading): hold the first frame a moment,
		-- then go on alone (and don't jump back if it starts later).
		if os.clock() - r.asked < Config.SONG_WAIT then
			r.began = os.clock()
			r.offset = 0
			return 0
		end
		r.songLate = true
	end
	return own -- the song has ended: on our own clock through the hold
end

local function showScreen(r: Run)
	if r.screenShown then
		return
	end
	r.screenShown = true
	if not r.barsOut then
		r.barsOut = true
		moveBars(r, false, Config.BARS.outTime)
	end
	local fn = r.opts.onScreen
	if fn then
		task.spawn(fn)
	end
end

local function skip(r: Run)
	if r.skipped or r.screenShown then
		return
	end
	r.skipped = true
	r.offset = Config.SKIP_TO
	r.began = os.clock()
	for _, a in r.actors do
		local clip = a.clip
		if clip and clip.IsPlaying then
			clip.TimePosition = Config.SKIP_TO
		end
	end
	r.flash.BackgroundTransparency = 0.6
	-- the skip lands with the last accent before SKIP_TO, from its hit
	local landing: Config.Cue? = nil
	for i, cue in r.scene.cues do
		if cue.t <= Config.SKIP_TO then
			landing = cue
		end
		r.cuesFired[i] = r.cuesFired[i] or cue.t - cue.hit <= Config.SKIP_TO
	end
	if landing then
		fireCue(r, landing, landing.hit)
	end
	showScreen(r)
end

local function step(r: Run, cam: Camera, dt: number)
	local t = clock(r)
	local frozen = r.frozen
	cues(r, t)
	-- the copies: each clip on the song's clock, then its hold loop
	for _, a in r.actors do
		local clip = a.clip
		if frozen and clip then
			-- Studio preview: the clip parked on this frame (the hold if past it)
			a.holding = false
			if a.hold then
				(a.hold :: AnimationTrack):Stop(0)
			end
			if not clip.IsPlaying then
				clip:Play(0)
			end
			clip:AdjustSpeed(0)
			if clip.Length > 0 then
				clip.TimePosition = math.min(frozen, clip.Length - 0.02)
			end
			continue
		end
	end
	for _, a in r.actors do
		if frozen then
			break
		end
		local clip = a.clip
		if clip and not a.holding then
			if a.clipLength <= 0 and clip.Length > 0 then
				a.clipLength = clip.Length
			end
			local length = a.clipLength
			if length > 0 and t >= length - Config.HOLD_FADE then
				a.holding = true
				local hold = a.hold
				if hold and hold.Length <= 0 then
					-- not loaded (yet): load it again now the copy is in place
					local animator = animatorOf(a.copy)
					local again = animator and load(animator, a.holdKey, true)
					if again then
						hold:Destroy()
						a.hold = again
						hold = again
					end
				end
				if hold then
					hold:Play(Config.HOLD_FADE)
				end
				-- crossfade: the clip held on its last frames while it fades out
				clip:AdjustSpeed(0)
				clip:Stop(Config.HOLD_FADE)
			elseif clip.IsPlaying and length > 0 and math.abs(clip.TimePosition - t) > 0.1 then
				clip.TimePosition = math.clamp(t, 0, length)
			end
		end
	end
	-- whole-body root moves (a spin, a hop)
	for _, a in r.actors do
		local keys = a.root
		if keys then
			local yaw, lift = rootAt(keys, t)
			a.copy:PivotTo(a.base * CFrame.new(0, lift, 0) * CFrame.Angles(0, math.rad(yaw), 0))
		end
	end
	-- the camera
	local cf, fov = cameraAt(r, t)
	cam.CFrame = cf
	CameraController.setOverrideFov(fov)
	-- flashes
	local white = 0
	for _, f in r.scene.flashes do
		white = math.max(white, f.peak * envelope(t - f.t, f.decay))
	end
	local current = 1 - r.flash.BackgroundTransparency
	-- (a skip's flash fades on its own)
	if white < current then
		white = math.max(white, current - 3 * dt)
	end
	r.flash.BackgroundTransparency = 1 - math.clamp(white, 0, 1)
	if t >= Config.SCREEN_AT then
		showScreen(r)
	end
	local fn = r.opts.onFrame
	if fn then
		fn()
	end
end

-- API ------------------------------------------------------------------------------

function WinCutscene.preload()
	task.spawn(function()
		local list: { Instance } = {}
		for _, id in Animations.WIN do
			local a = Instance.new("Animation")
			a.AnimationId = id
			table.insert(list, a)
		end
		for _, scene in Config.SCENES do
			for _, cue in scene.cues do
				local snd = Instance.new("Sound")
				snd.SoundId = "rbxassetid://" .. tostring(cue.id)
				table.insert(list, snd)
			end
		end
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)
end

local function sceneFor(size: number): Config.Scene?
	local best: Config.Scene? = nil
	for n = 1, math.max(size, 1) do
		local s = Config.SCENES[n]
		if s then
			best = s
		end
	end
	return best
end

function WinCutscene.play(winners: { Model }, opts: Options): boolean
	WinCutscene.stop()
	local scene = sceneFor(#winners)
	local cam = Workspace.CurrentCamera
	if not scene or not cam or #winners == 0 then
		return false
	end
	local folder = Instance.new("Folder")
	folder.Name = "WinCutscene"
	local stage = stageFrame(folder)
	local gui, flash, bars = overlay()
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "WinCutsceneGrade"
	grade.Parent = Lighting
	TweenService:Create(grade, TweenInfo.new(Config.GRADE.fadeIn), {
		Contrast = Config.GRADE.contrast,
		Saturation = Config.GRADE.saturation,
	}):Play()
	local r: Run = {
		scene = scene,
		stage = stage,
		folder = folder,
		actors = {},
		gui = gui,
		flash = flash,
		bars = bars,
		grade = grade,
		song = nil,
		songLate = false,
		songStarted = false,
		asked = os.clock(),
		began = os.clock(),
		offset = 0,
		skipped = false,
		frozen = nil,
		screenShown = false,
		barsOut = false,
		opts = opts,
		connections = {},
		cuesFired = {},
		cueSounds = {},
		seed = math.random() * 100,
	}
	-- (in the DataModel before the clips load: a track loaded on a copy
	-- outside it never loads its asset)
	folder.Parent = Workspace
	for i, body in winners do
		local slot = scene.slots[i]
		if slot then
			place(r, body, slot, slot.pos)
		else
			local extra = Config.EXTRA_SLOTS[i - #scene.slots]
			if extra then
				place(r, body, scene.slots[1], extra)
			end
		end
	end
	run = r
	moveBars(r, true, Config.BARS.inTime)
	-- the song is the clock (one ending song for everyone)
	r.song = UiSound.play(Config.SONG)
	r.asked = os.clock()
	r.began = r.asked
	cam.CameraType = Enum.CameraType.Scriptable
	CameraController.setOverride(function(c: Camera, dt: number)
		if run == r then
			step(r, c, dt)
		end
	end)
	table.insert(
		r.connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed or run ~= r or os.clock() - r.began + r.offset < Config.SKIP_AFTER then
				return
			end
			local kind = input.UserInputType
			if
				kind == Enum.UserInputType.MouseButton1
				or kind == Enum.UserInputType.Touch
				or kind == Enum.UserInputType.Keyboard
				or kind == Enum.UserInputType.Gamepad1
			then
				skip(r)
			end
		end)
	)
	return true
end

function WinCutscene.copies(): { { copy: Model, body: Model } }
	local list = {}
	local r = run
	if r then
		for _, a in r.actors do
			table.insert(list, { copy = a.copy, body = a.body })
		end
	end
	return list
end

-- Studio preview: hold the cutscene at song time `t` (nil plays on from there).
function WinCutscene.freeze(t: number?)
	local r = run
	if not r then
		return
	end
	if t then
		r.frozen = t
		r.screenShown = true -- no screen while scrubbing
		return
	end
	local was = r.frozen
	r.frozen = nil
	if was then
		r.skipped = true -- on our own clock from here
		r.offset = was
		r.began = os.clock()
		for _, a in r.actors do
			local clip = a.clip
			if clip then
				clip:AdjustSpeed(1)
			end
		end
	end
end

function WinCutscene.isPlaying(): boolean
	return run ~= nil
end

function WinCutscene.stop()
	local r = run
	if not r then
		return
	end
	run = nil
	for _, c in r.connections do
		c:Disconnect()
	end
	for _, a in r.actors do
		for _, track in { a.clip, a.hold } do
			if track then
				track:Stop(0)
				track:Destroy()
			end
		end
	end
	r.folder:Destroy()
	r.gui:Destroy()
	r.grade:Destroy()
	CameraController.setOverrideFov(nil)
end

return WinCutscene
