--!strict
-- Aim assist and auto shoot for controllers and phones, never mouse
-- (Config/AimAssist; Settings AIM ASSIST + STRENGTH, AUTO SHOOT + REACTION
-- TIME; plan and research: vault/02 Art/UI Settings.md → Chunk 3).
--
-- Aim assist bends the camera's turn inside CameraController's step (after
-- the sensitivity scale): near an enemy the turn slows (friction), and while
-- the player moves their aim it bends a little toward the enemy and follows a
-- strafe (pull, tracking). Nothing happens while the aim is still, there is
-- no snap on ADS, no assist through walls, point-blank or while blinded.
--
-- Auto shoot casts the crosshair ray each frame: a live enemy in the gun's
-- reach (a sniper only when scoped) for the reaction time presses the trigger
-- (held for automatic guns, tapped for the rest; the gun's fire rate and the
-- server's checks still apply). The phone FIRE button keeps working.
--
-- In the shooting range (owner 2026-11-26) both work on the training bots only
-- (tag RangeBot): other players there are never a target and the sight rays
-- pass through them.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Avatar = require(Shared.Config.Avatar)
local BallisticGlass = require(Shared.Util.BallisticGlass)
local CameraConfig = require(Shared.Config.Camera)
local Config = require(Shared.Config.AimAssist)
local Fighters = require(Shared.Util.Fighters)
local Health = require(Shared.Health)
local InputMode = require(Shared.InputMode)
local PlayZone = require(Shared.PlayZone)
local SettingsApply = require(Shared.SettingsApply)
local StateValues = require(Shared.StateValues)
local StatusEffects = require(Shared.Config.StatusEffects)
local Teams = require(Shared.Mods.Teams)
local SmokeBlock = require(Shared.Mods.Blocks.Smoke)

local CameraController = require(script.Parent.CameraController)
local WeaponController = require(script.Parent.WeaponController)

local AimAssistController = {}

local player = Players.LocalPlayer
local SAMPLES = 5 -- points along a body (hip to head) the aim can be nearest to
local RANGE_BOT_TAG = "RangeBot" -- the range's training bots (LobbyServer Range/RangeBots)

type Target = { body: Model, lastDir: Vector3? }

local target: Target? = nil
local enemies: { [Model]: boolean } = {}
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local exclude: { Instance } = {}
local nextPick = 0
local onTargetSince: number? = nil

-- Helpers ----------------------------------------------------------------------

local function deviceAllowed(): boolean
	return InputMode.touch() or InputMode.gamepad()
end

local function blinded(): boolean
	local body = player.Character
	local untilAt = body and StateValues.get(body, StatusEffects.blinded.attribute)
	return typeof(untilAt) == "number" and untilAt > Workspace:GetServerTimeNow()
end

local function alive(): boolean
	local body = player.Character
	return body ~= nil and Health.isAlive(body:FindFirstChildOfClass("Humanoid"))
end

-- Turns `from` toward `to` by at most `maxAngle` radians.
local function rotateToward(from: Vector3, to: Vector3, maxAngle: number): Vector3
	local angle = math.acos(math.clamp(from:Dot(to), -1, 1))
	if angle < 1e-6 or maxAngle <= 0 then
		return if maxAngle > 0 and angle < 1e-6 then to else from
	end
	local axis = from:Cross(to)
	if axis.Magnitude < 1e-6 then
		return from
	end
	return CFrame.fromAxisAngle(axis.Unit, math.min(maxAngle, angle)):VectorToWorldSpace(from)
end

local function angleBetween(a: Vector3, b: Vector3): number
	return math.acos(math.clamp(a:Dot(b), -1, 1))
end

local function refreshParams()
	table.clear(exclude)
	if player.Character then
		table.insert(exclude, player.Character)
	end
	local cam = Workspace.CurrentCamera
	if cam then
		table.insert(exclude, cam)
	end
	for _, name in { "Effects", Avatar.LIMB_FOLDER, Avatar.LIMB_FOLDER .. "Local" } do
		local f = Workspace:FindFirstChild(name)
		if f then
			table.insert(exclude, f)
		end
	end
	table.clear(enemies)
	if PlayZone.get(player) == "Range" then
		-- the range: bots only; other players are see-through to the assist
		for _, p in Players:GetPlayers() do
			if p ~= player and p.Character then
				table.insert(exclude, p.Character)
			end
		end
		for _, bot in CollectionService:GetTagged(RANGE_BOT_TAG) do
			if
				bot:IsA("Model")
				and bot:IsDescendantOf(Workspace)
				and Health.isAlive(bot:FindFirstChildOfClass("Humanoid"))
			then
				enemies[bot] = true
			end
		end
		return
	end
	for _, fighter in Fighters.all(player) do
		if Teams.isAlly(player, fighter.holder) then
			table.insert(exclude, fighter.body)
		elseif Health.isAlive(fighter.body:FindFirstChildOfClass("Humanoid")) then
			enemies[fighter.body] = true
		end
	end
end

local function sightRay(origin: Vector3, direction: Vector3): RaycastResult?
	params.FilterDescendantsInstances = exclude
	local config = WeaponController.currentConfig()
	if config and not config.melee then
		return BallisticGlass.raycast(origin, direction, params)
	end
	return Workspace:Raycast(origin, direction, params)
end

-- The point on `body` (hip to head) nearest the crosshair, as a direction
-- from the camera, its angle off the crosshair and its distance.
local function aimPoint(body: Model, origin: Vector3, look: Vector3): (Vector3?, number, number)
	local head = body:FindFirstChild("Head")
	local root = body:FindFirstChild("HumanoidRootPart")
	if not (head and head:IsA("BasePart") and root and root:IsA("BasePart")) then
		return nil, math.huge, math.huge
	end
	local a, b = root.Position, head.Position
	local bestDir: Vector3? = nil
	local bestAngle, bestDist = math.huge, math.huge
	for i = 0, SAMPLES - 1 do
		local p = a:Lerp(b, i / (SAMPLES - 1))
		local offset = p - origin
		local dist = offset.Magnitude
		if dist > 1e-3 then
			local dir = offset / dist
			local angle = angleBetween(look, dir)
			if angle < bestAngle then
				bestAngle, bestDist, bestDir = angle, dist, dir
			end
		end
	end
	return bestDir, bestAngle, bestDist
end

local function visible(origin: Vector3, dir: Vector3, dist: number, body: Model): boolean
	-- no assist or auto shoot through a Smoke dome (Mods/Blocks/Smoke)
	if SmokeBlock.blocks(origin, origin + dir * dist) then
		return false
	end
	local hit = sightRay(origin, dir * dist)
	if not hit then
		return true
	end
	return Fighters.bodyOfPart(hit.Instance) == body or hit.Distance >= dist - 0.5
end

-- The gun's reach for the assist and auto shoot (studs).
local function reachOf(): number
	local config = WeaponController.currentConfig()
	if not config then
		return 0
	end
	local reach = if config.melee then config.melee.range else config.range
	return math.min(reach, Config.MAX_DISTANCE)
end

local function cone(cam: Camera): number
	return math.rad(Config.CONE) * cam.FieldOfView / CameraConfig.DEFAULT_FOV
end

local function weight(angle: number, coneAngle: number): number
	local inner = coneAngle * Config.INNER / Config.CONE
	if angle <= inner then
		return 1
	end
	return math.clamp(1 - (angle - inner) / (coneAngle - inner), 0, 1)
end

-- Picks the enemy nearest the crosshair inside the cone, with line of sight.
local function pick(cam: Camera)
	refreshParams()
	local origin, look = cam.CFrame.Position, cam.CFrame.LookVector
	local reach = reachOf()
	local coneAngle = cone(cam)
	local best: Model? = nil
	local bestScore = math.huge
	for body in enemies do
		local dir, angle, dist = aimPoint(body, origin, look)
		if
			dir
			and angle < coneAngle
			and dist >= Config.MIN_DISTANCE
			and dist <= reach
			and visible(origin, dir, dist, body)
		then
			local score = angle + dist * 0.0005
			if score < bestScore then
				best, bestScore = body, score
			end
		end
	end
	if not best then
		target = nil
	elseif not target or target.body ~= best then
		target = { body = best, lastDir = nil }
	end
end

local function assistOn(): boolean
	return SettingsApply.get("aimAssist") ~= false
		and (SettingsApply.get("aimAssistStrength") or 0) > 0
		and deviceAllowed()
		and alive()
		and not blinded()
		and WeaponController.currentConfig() ~= nil
end

-- Aim assist (CameraController calls this each frame) --------------------------

local function assistStep(cam: Camera, lastLook: Vector3, _dt: number)
	if not assistOn() then
		target = nil
		return
	end
	local now = os.clock()
	if now >= nextPick then
		nextPick = now + 1 / Config.PICK_RATE
		pick(cam)
	end
	local t = target
	if
		not t
		or not t.body.Parent
		or not Health.isAlive(t.body:FindFirstChildOfClass("Humanoid"))
	then
		target = nil
		return
	end
	local cf = cam.CFrame
	local origin, look = cf.Position, cf.LookVector
	local dir, angle, dist = aimPoint(t.body, origin, look)
	local coneAngle = cone(cam)
	if not dir or angle >= coneAngle or dist < Config.MIN_DISTANCE then
		t.lastDir = nil
		return
	end
	local strength = math.clamp((SettingsApply.get("aimAssistStrength") or 0) / 100, 0, 1)
	local w = weight(angle, coneAngle) * strength
	local turn = angleBetween(lastLook, look)
	local moving = turn > Config.MOVING_TURN

	-- Friction: keep only part of this frame's turn near the target.
	local newLook = rotateToward(lastLook, look, turn * (1 - Config.FRICTION * w))
	if moving then
		-- Pull: a share of the turn bends toward the target (more in ADS).
		local zoom = CameraController.zoomAlpha()
		local pull = Config.PULL_HIP + (Config.PULL_ADS - Config.PULL_HIP) * zoom
		newLook = rotateToward(newLook, dir, turn * pull * w)
		-- Tracking: follow part of the target's own motion across the view.
		local last = t.lastDir
		if last then
			local drift = angleBetween(last, dir)
			if drift > 1e-5 then
				local follow = CFrame.fromAxisAngle(last:Cross(dir).Unit, drift * Config.TRACK * w)
				newLook = follow:VectorToWorldSpace(newLook)
			end
		end
	end
	t.lastDir = dir
	if newLook ~= look then
		cam.CFrame = CFrame.lookAt(origin, origin + newLook)
	end
end

-- Auto shoot -----------------------------------------------------------------------

local function reactionTime(): number
	local mode = SettingsApply.get("autoShoot")
	if mode == "Custom" then
		local ms = SettingsApply.get("autoShootReaction")
		return math.max(if typeof(ms) == "number" then ms / 1000 else 0, Config.CUSTOM_MIN)
	end
	local config = WeaponController.currentConfig()
	local interval = if config then config.fireInterval else 0.1
	return math.clamp(
		Config.DYNAMIC_BASE + interval * Config.DYNAMIC_SHARE,
		Config.DYNAMIC_MIN,
		Config.DYNAMIC_MAX
	)
end

local function stopAuto()
	onTargetSince = nil
	WeaponController.autoTrigger(false)
end

local function autoShootStep()
	local mode = SettingsApply.get("autoShoot")
	local config = WeaponController.currentConfig()
	local cam = Workspace.CurrentCamera
	if
		mode == "Disabled"
		or not config
		or not cam
		or not deviceAllowed()
		or not alive()
		or blinded()
		or (config.scope ~= nil and not WeaponController.isScoped()) -- no noscopes
	then
		stopAuto()
		return
	end
	if os.clock() >= nextPick then
		refreshParams() -- (the assist refreshes it when it runs)
		nextPick = os.clock() + 1 / Config.PICK_RATE
	end
	local reach = reachOf()
	local hit = sightRay(cam.CFrame.Position, cam.CFrame.LookVector * reach)
	local body = hit and Fighters.bodyOfPart(hit.Instance)
	local onEnemy = body ~= nil
		and enemies[body] == true
		and Health.isAlive(body:FindFirstChildOfClass("Humanoid"))
	if not onEnemy then
		stopAuto()
		return
	end
	local now = os.clock()
	onTargetSince = onTargetSince or now
	if now - (onTargetSince :: number) < reactionTime() or not WeaponController.readyToFire() then
		return
	end
	if config.fireMode == "Auto" then
		WeaponController.autoTrigger(true)
	else
		WeaponController.autoTap()
	end
end

function AimAssistController.start()
	CameraController.setAssist(assistStep)
	-- after the camera (and the assist) has placed this frame's view
	RunService:BindToRenderStep("GGAutoShoot", Enum.RenderPriority.Camera.Value + 5, autoShootStep)
	player.CharacterRemoving:Connect(function()
		target = nil
		stopAuto()
	end)
end

return AimAssistController
