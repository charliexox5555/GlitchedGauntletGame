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
-- Their view is rebuilt from what already replicates: head position, body
-- yaw, the `AimPitch` / `Aiming` attributes (players: WeaponService's Aim
-- remote; bots: Bots/Brain), the `WorldWeapon`'s `WeaponId`, `ReloadAt` /
-- `ReloadFor`, `ModHeld`, `MoveState` and their `ShotFx`. The server only
-- streams their surroundings to you (SpectateService, `Spectate` remote).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Health = require(ReplicatedStorage.Shared.Health)
local Ease = require(ReplicatedStorage.Shared.Util.Ease)
local Fighters = require(ReplicatedStorage.Shared.Util.Fighters)
local Juice = require(ReplicatedStorage.Shared.Config.Juice)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Net = require(ReplicatedStorage.Shared.Net)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Types = require(ReplicatedStorage.Shared.Types)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local CameraController = require(script.Parent.CameraController)
local DeathFxController = require(script.Parent.DeathFxController)
local EffectsController = require(script.Parent.EffectsController)
local HudController = require(script.Parent.HudController)
local InputController = require(script.Parent.InputController)
local ViewmodelController = require(script.Parent.ViewmodelController)
local WeaponController = require(script.Parent.WeaponController)
local Ui = require(script.Parent.Parent.Util.Ui)

type WeaponConfig = Types.WeaponConfig

local SpectateController = {}

local S = Juice.SPECTATE
local C = Theme.COLORS
local player = Players.LocalPlayer

type Mode = "Off" | "DeathCam" | "Watch"

-- A fighter: `holder` carries the attributes (a Player, or a bot's model);
-- `body` is the character model.
type Fighter = Fighters.Fighter

local mode: Mode = "Off"
local target: Fighter? = nil
local killer: Instance? = nil
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
local wasLowered = false
local targetDownAt: number? = nil
local hiddenConns: { RBXScriptConnection } = {}
local hiddenParts: { Instance } = {}
local lastFightAt = -math.huge -- when the phase was last Live / SuddenDeath -- the watched body's parts, kept hidden every frame
local sendAt: number? = nil -- the Spectate request goes once the choice settles
local sentTarget: Instance? = nil
local SEND_SETTLE = 0.25

-- UI.
local bar: Frame? = nil
local nameLabel: TextLabel? = nil
local healthFill: Frame? = nil
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
	local v = holder:GetAttribute(name)
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
		DisplayOrder = 5,
	}, player:WaitForChild("PlayerGui"))
	local holder = Ui.make("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(460, 78),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	Ui.cut(holder, { Size = UDim2.fromScale(1, 1) }, {
		color = C.panel,
		transparency = 0.15,
		line = C.lineStrong,
		lineTransparency = 0.3,
		corner = 14,
	})
	Ui.text(holder, "SPECTATING", "label", {
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 16),
		TextColor3 = C.textSecondary,
		ZIndex = 4,
	})
	nameLabel = Ui.text(holder, "", "titleS", {
		Position = UDim2.fromOffset(60, 24),
		Size = UDim2.new(1, -120, 0, 32),
		TextSize = 30,
		TextColor3 = C.ally,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 4,
	})
	local track = Ui.make("Frame", {
		Position = UDim2.new(0, 60, 1, -16),
		Size = UDim2.new(1, -120, 0, 4),
		BackgroundColor3 = C.lineSoft,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, holder)
	healthFill = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.text,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, track)
	local function arrow(text: string, x: number, step: number)
		local b = Ui.make("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(x, if x < 0.5 then 30 else -30, 0.5, 0),
			Size = UDim2.fromOffset(44, 56),
			BackgroundTransparency = 1,
			Text = text,
			FontFace = Theme.TEXT.titleS.font,
			TextSize = 30,
			TextColor3 = C.text,
			ZIndex = 4,
		}, holder)
		b.Activated:Connect(function()
			SpectateController.cycle(step)
		end)
	end
	arrow("<", 0, -1)
	arrow(">", 1, 1)
	Ui.fit(holder)
	bar = holder
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

local function setBar(f: Fighter?)
	local b = bar
	if not b then
		return
	end
	b.Visible = f ~= nil
	local label = nameLabel
	if f and label then
		label.Text = string.upper(nameOf(f.holder))
		label.TextColor3 = if Teams.of(f.holder) == Teams.of(player) then C.ally else C.enemy
	end
end

-- The watched view ----------------------------------------------------------------

local function unequip()
	equippedId = nil
	equippedConfig = nil
	ViewmodelController.unequip()
end

-- Their view, every frame (the camera override: runs before the viewmodel).
local function watchStep(cam: Camera, dt: number)
	local f = target
	if not f then
		return
	end
	local body, holder = f.body, f.holder
	local head = body:FindFirstChild("Head")
	local root = body:FindFirstChild("HumanoidRootPart")
	-- The camera: their head, their body's yaw, their reported pitch.
	if head and head:IsA("BasePart") and root and root:IsA("BasePart") then
		local look = root.CFrame.LookVector
		local yaw = math.atan2(-look.X, -look.Z)
		local pitch = math.clamp(numberAttr(holder, "AimPitch"), -1.45, 1.45)
		local pos = viewPos
		if pos == nil then
			viewPos = head.Position
			viewYaw, viewPitch = yaw, pitch
		else
			viewPos = pos:Lerp(head.Position, 1 - math.exp(-S.headRate * dt))
			viewYaw = Ease.approachAngle(viewYaw, yaw, S.yawRate, dt)
			viewPitch = Ease.approach(viewPitch, pitch, S.pitchRate, dt)
		end
		cam.CFrame = CFrame.new(viewPos :: Vector3)
			* CFrame.fromEulerAnglesYXZ(viewPitch, viewYaw, 0)
	end

	-- Their body stays out of view (other effects, like a dash ghost, write
	-- the same property every frame).
	for _, d in hiddenParts do
		(d :: any).LocalTransparencyModifier = 1
	end

	-- Their gun.
	local world = body:FindFirstChild("WorldWeapon")
	local idAttr = world and world:GetAttribute("WeaponId")
	local id = if typeof(idAttr) == "string" then idAttr else nil
	if id ~= equippedId then
		local config = id and Weapons.get(id)
		if config then
			equippedId, equippedConfig = id, config
			ViewmodelController.equip(config)
		else
			unequip()
		end
	end
	local config = equippedConfig

	-- Aiming down sights, zoom and the scope overlay.
	local aiming = holder:GetAttribute("Aiming") == true
		and config ~= nil
		and config.fireMode ~= "Melee"
		and not config.noAds
	local rate = 1 / math.max(if config then config.adsTime else 0.2, 0.05)
	adsAlpha = math.clamp(adsAlpha + (if aiming then rate else -rate) * dt, 0, 1)
	ViewmodelController.setAds(adsAlpha)
	local scope = config and config.scope
	CameraController.setZoom(
		if scope then CameraController.scopeFov(scope.zoom) elseif config then config.adsFov else nil,
		Ease.smooth(adsAlpha)
	)
	local scoped = scope ~= nil and adsAlpha > 0.85
	HudController.setScope(scoped)
	ViewmodelController.setHidden(scoped)
	HudController.setCrosshairVisible(adsAlpha < 0.5 and config ~= nil)

	-- A held Mod lowers the gun; a reload plays its clip.
	local lowered = numberAttr(holder, "ModHeld") ~= 0
	if lowered ~= wasLowered then
		wasLowered = lowered
		ViewmodelController.setLowered(lowered)
	end
	local reloadAt = numberAttr(holder, "ReloadAt")
	if reloadAt > lastReloadAt then
		lastReloadAt = reloadAt
		local duration = numberAttr(holder, "ReloadFor")
		local left = duration - (Workspace:GetServerTimeNow() - reloadAt)
		if config and left > 0.1 then
			ViewmodelController.reload(left)
		end
	end

	-- Their health on the bar.
	local fill = healthFill
	local humanoid = humanoidOf(body)
	if fill and humanoid then
		fill.Size = UDim2.fromScale(
			math.clamp(Health.get(humanoid) / math.max(Health.max(humanoid), 1), 0, 1),
			1
		)
	end
end

local function onSpectatedShot(config: WeaponConfig, left: boolean)
	if config.fireMode == "Melee" then
		ViewmodelController.swing()
		return
	end
	if left then
		ViewmodelController.fire(1 - 0.5 * adsAlpha, "Left", false)
	else
		ViewmodelController.fire(1 - 0.5 * adsAlpha, nil, false)
	end
end

local function watch(f: Fighter)
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
	-- Only reloads that start from now play (not one that finished earlier).
	lastReloadAt = numberAttr(f.holder, "ReloadAt")
	equippedId, equippedConfig = nil, nil
	DeathFxController.clearGrade()
	WeaponController.setSpectating(true)
	HudController.setSpectating(true)
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
	sendAt = nil
	if equippedId ~= nil then
		unequip()
	end
	CameraController.setOverride(nil)
	CameraController.setZoom(nil, 0)
	HudController.setScope(false)
	HudController.setSpectating(false)
	HudController.setCrosshairVisible(true)
	ViewmodelController.setHidden(false)
	ViewmodelController.setLowered(false)
	ViewmodelController.setSubject(nil)
	EffectsController.setSpectated(nil, nil)
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
	if mode ~= "Off" and (phase == "MatchEnd" or phase == "Waiting" or phase == "Replay") then
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
	Net.event("Killed").OnClientEvent:Connect(function(victim: unknown, attacker: unknown)
		if victim ~= nil and victim == myBody and typeof(attacker) == "Instance" then
			killer = attacker
		end
	end)
	InputController.onPressed("Fire", function()
		SpectateController.cycle(1)
	end)
	InputController.onPressed("Aim", function()
		SpectateController.cycle(-1)
	end)
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
