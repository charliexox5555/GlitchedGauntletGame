--!strict
-- Lobby hub camera height smoothing (2026-11-28, owner: "I just want the movement in the lobby to feel nicer";
-- vault/01 Design/Movement Feel 2026-11-27.md → Lobby movement). Roblox's third-person camera tracks the root
-- exactly, so every step up or down (the Duels deck's one-stud step, stair runs, crate lips) pops the view by
-- that step in one frame. After the camera module (and Shared/SettingsApply's lobby step) this moves the camera
-- by a height offset that soaks up those jumps and eases home (Config/Camera LOBBY_*). Height only: turning,
-- zoom and the look are untouched, and the offset is rebuilt from the root each frame, so it never builds up.
-- Stands down outside the hub (the Range and matches have their own camera) and for any scripted camera
-- (Locker, cases, NPC talk, cutscenes).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraConfig = require(ReplicatedStorage.Shared.Config.Camera)
local Movement = require(ReplicatedStorage.Shared.Config.Movement)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)

local LobbyCameraFollow = {}

local BIND = "GGLobbyCameraFollow"

local player = Players.LocalPlayer
local lastRoot: BasePart? = nil
local lastY = 0
local climb = 0 -- studs/s: the root's low-passed vertical speed
local offset = 0 -- studs: camera height minus the root's (the soaked-up step)
local airSince: number? = nil -- os.clock() this stretch off the floor began
local wasInAir = false -- last frame was a real jump or fall (not a step down)

local function reset()
	lastRoot = nil
	climb = 0
	offset = 0
	airSince = nil
	wasInAir = false
end

local function step(dt: number)
	local cam = Workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if
		not cam
		or not humanoid
		or not root
		or not root:IsA("BasePart")
		or dt <= 0
		or dt ~= dt
		or cam.CameraType ~= Enum.CameraType.Custom
		or cam.CameraSubject ~= humanoid
		or PlayZone.get(player) ~= "Lobby"
	then
		reset()
		return
	end
	local y = root.Position.Y
	if lastRoot ~= root then
		lastRoot = root
		lastY = y
		climb = 0
		offset = 0
		return
	end
	local rise = y - lastY
	lastY = y
	-- A teleport or respawn move: follow at once.
	if math.abs(rise) > CameraConfig.FOLLOW_SNAP then
		climb = 0
		offset = 0
		return
	end
	-- A real jump or fall, read like the movement state (Movement.AIR_RISE / AIR_GRACE): a step down a stair
	-- (about 0.08 s off the floor) is still the ground, so it's smoothed too.
	local now = os.clock()
	local onFloor = humanoid.FloorMaterial ~= Enum.Material.Air
	airSince = if onFloor then nil else airSince or now
	-- (The floor reading lags a takeoff by about 60 ms and a landing settles for a frame or two; the Humanoid's
	-- Jumping / Freefall / Landed states don't. Measured: without them the camera soaked up the first 1.3-1.7
	-- studs of every jump and caught up with a jerk, and floated 0.4 studs on the landing.)
	local humanoidState = humanoid:GetState()
	local vy = root.AssemblyLinearVelocity.Y
	local inAir = humanoidState == Enum.HumanoidStateType.Jumping
		or humanoidState == Enum.HumanoidStateType.Landed
		or (humanoidState == Enum.HumanoidStateType.Freefall and vy > Movement.AIR_RISE)
		or (
			not onFloor
			and (vy > Movement.AIR_RISE or now - (airSince or now) >= Movement.AIR_GRACE)
		)
	local landed = wasInAir and not inAir
	wasInAir = inAir
	if landed then
		-- The landing frame's drop is followed in full (the landing dip stays), and the fall's speed is no
		-- climb to keep following.
		climb = 0
		offset *= math.exp(-CameraConfig.LOBBY_AIR_RATE * dt)
	elseif not inAir then
		-- The camera climbs at the low-passed rate; whatever the root did beyond that this frame (a step)
		-- goes into the offset, which then eases back to zero.
		climb += (rise / dt - climb) * (1 - math.exp(-CameraConfig.LOBBY_CLIMB_RATE * dt))
		offset -= rise - climb * dt
		offset *= math.exp(-CameraConfig.LOBBY_SETTLE_RATE * dt)
	else
		climb = rise / dt
		offset *= math.exp(-CameraConfig.LOBBY_AIR_RATE * dt)
	end
	offset = math.clamp(offset, -CameraConfig.LOBBY_MAX_LAG, CameraConfig.LOBBY_MAX_LAG)
	if math.abs(offset) > 1e-4 then
		cam.CFrame += Vector3.new(0, offset, 0)
	end
end

function LobbyCameraFollow.start()
	-- After the camera module (Camera) and SettingsApply's lobby sensitivity step (Camera + 1).
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 2, step)
	player.CharacterAdded:Connect(reset)
end

return LobbyCameraFollow
