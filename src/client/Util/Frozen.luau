--!strict
-- What a stun (Config/StatusEffects Frozen: Frost's Freeze Frame) does on
-- this client, on top of what the server enforces (no moving, shooting or
-- Mods):
--   - us, when it lands: a held Mod, a reload and an inspect are dropped
--     (the server drops its reload too: WeaponService), and the view turns
--     no faster than the effect's `turn` (CameraController.setTurnCap);
--   - every frozen body we see (players and dummies): its animations pause
--     mid-pose (Animator tracks at speed 0, put back when it thaws).
-- Started and stepped by UpgradeFx/Frost; the look is drawn there.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Status = require(ReplicatedStorage.Shared.Mods.Status)
local StatusEffects = require(ReplicatedStorage.Shared.Config.StatusEffects)

local Controllers = script.Parent.Parent.Controllers
local CameraController = require(Controllers.CameraController)
local ModController = require(Controllers.ModController)
local ViewmodelController = require(Controllers.ViewmodelController)
local WeaponController = require(Controllers.WeaponController)

local Frozen = {}

local player = Players.LocalPlayer
local mine = false

-- The tightest turn cap among the stuns on `model` (nil: none).
local function turnCap(model: Instance?, now: number): number?
	local cap: number? = nil
	for name, e in StatusEffects.effects do
		local turn = e.turn
		if e.stun and turn and Status.active(model, name, now) then
			cap = math.min(cap or math.huge, turn)
		end
	end
	return cap
end

-- Track speeds from before a freeze, per Animator (weak: bodies go away).
local paused: { [Animator]: { [AnimationTrack]: number } } = setmetatable({}, { __mode = "k" }) :: any

local function animatorOf(model: Instance): Animator?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid:FindFirstChildOfClass("Animator")
end

local function pause(animator: Animator)
	local saved = paused[animator]
	if not saved then
		saved = {}
		paused[animator] = saved
	end
	-- Every frame: a track started (or re-sped by its owner) since stops too.
	for _, track in animator:GetPlayingAnimationTracks() do
		if track.Speed ~= 0 then
			if saved[track] == nil then
				saved[track] = track.Speed
			end
			track:AdjustSpeed(0)
		end
	end
end

local function resume(animator: Animator)
	local saved = paused[animator]
	paused[animator] = nil
	if saved then
		for track, speed in saved do
			if track.IsPlaying and track.Speed == 0 then
				track:AdjustSpeed(speed)
			end
		end
	end
end

-- The bodies a freeze can land on (as Util/FrostFx: players and dummies).
function Frozen.bodies(): { Model }
	local out = {}
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if character then
			table.insert(out, character)
		end
	end
	local dummies = Workspace:FindFirstChild("Dummies")
	if dummies then
		for _, d in dummies:GetChildren() do
			if d:IsA("Model") then
				table.insert(out, d)
			end
		end
	end
	return out
end

-- Before the animation step, so the pose holds on this frame already.
local function preAnimation()
	local now = Workspace:GetServerTimeNow()
	local seen: { [Animator]: boolean } = {}
	for _, body in Frozen.bodies() do
		if Status.stunned(body, now) then
			local animator = animatorOf(body)
			if animator then
				seen[animator] = true
				pause(animator)
			end
		end
	end
	for animator in paused do
		if not seen[animator] then
			resume(animator)
		end
	end
end

local function setMine(on: boolean, now: number)
	mine = on
	if on then
		if ModController.heldSlot() ~= 0 then
			ModController.cancel()
		end
		WeaponController.cancelReload()
		ViewmodelController.cancelInspect()
	end
	CameraController.setTurnCap(if on then turnCap(player.Character, now) else nil)
end

-- Per frame (UpgradeFx/Frost.step).
function Frozen.step()
	local now = Workspace:GetServerTimeNow()
	local on = Status.stunned(player.Character, now)
	if on ~= mine then
		setMine(on, now)
	end
end

function Frozen.start()
	RunService.PreAnimation:Connect(preAnimation)
	player.CharacterAdded:Connect(function()
		if mine then
			setMine(false, Workspace:GetServerTimeNow())
		end
	end)
end

return Frozen
