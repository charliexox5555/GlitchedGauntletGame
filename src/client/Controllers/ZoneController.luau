--!strict
-- Renders the synchronized sudden-death radius and warns the local fighter.
-- ZoneService owns the circle and all damage.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Health = require(ReplicatedStorage.Shared.Health)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local Z = require(ReplicatedStorage.Shared.Config.Juice).ZONE
local Zone = require(ReplicatedStorage.Shared.Zone)

local MatchHudController = require(script.Parent.MatchHudController)
local OvertimeZoneVfx = require(script.Parent.Parent.Util.OvertimeZoneVfx)
local UiSound = require(script.Parent.Parent.Util.UiSound)

local ZoneController = {}
local player = Players.LocalPlayer
local current: Zone.State? = nil
local preview: Zone.State? = nil
local visual: OvertimeZoneVfx.Visual? = nil
local visualId: number? = nil
local tint: ColorCorrectionEffect? = nil
local tintTween: Tween? = nil
local wasOutside = false
local nextWarn = 0
local nextAlert = 0

local PREVIEW_FIELD = "PreviewOvertime"
local PREVIEW_HOLD = 8

local function updatePreview()
	preview = nil
	if current or typeof(StateValues.get(workspace, PREVIEW_FIELD)) ~= "number" then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local position = if root and root:IsA("BasePart") then root.Position else camera.CFrame.Position
	local flat = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
	local direction = if flat.Magnitude > 0.01 then flat.Unit else -Vector3.zAxis
	local target = position + direction * 14
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	if character then
		params.FilterDescendantsInstances = { character }
	end
	local floor = workspace:Raycast(target + Vector3.yAxis * 3, -Vector3.yAxis * 48, params)
	local now = workspace:GetServerTimeNow()
	preview = {
		id = -1,
		centre = if floor then floor.Position else position - Vector3.yAxis * 3,
		fromRadius = 34,
		toRadius = 4,
		startAt = now,
		endAt = now + 12,
	}
end

local function clearWall()
	if visual then
		visual.root:Destroy()
		visual = nil
	end
	visualId = nil
end

local function setTint(on: boolean)
	local effect = tint
	if not effect then
		if not on then
			return
		end
		effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "ZoneTint"
		effect.Parent = Lighting
		tint = effect
	end
	if tintTween then
		tintTween:Cancel()
	end
	local goal = if on
		then { TintColor = Z.tint, Saturation = -0.15 }
		else { TintColor = Color3.new(1, 1, 1), Saturation = 0 }
	local tween = TweenService:Create(effect, TweenInfo.new(Z.tintTime), goal)
	tintTween = tween
	if not on then
		tween.Completed:Once(function(playback)
			if tintTween == tween and playback == Enum.PlaybackState.Completed and tint then
				tint:Destroy()
				tint = nil
				tintTween = nil
			end
		end)
	end
	tween:Play()
end

local function fighterPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root
			and root:IsA("BasePart")
			and Health.isAlive(character)
		then root.Position
		else nil
end

local function warnOutside(outside: boolean, now: number)
	if outside ~= wasOutside then
		wasOutside = outside
		setTint(outside)
		nextWarn, nextAlert = 0, 0
	end
	if outside then
		if now >= nextAlert then
			nextAlert = now + 0.18
			MatchHudController.alert(
				"OUTSIDE THE ZONE",
				"Get back inside the circle",
				"danger",
				0.4
			)
		end
		if now >= nextWarn then
			nextWarn = now + Z.warnEvery
			UiSound.play("ZoneWarn")
		end
	end
end

local function step()
	local now = workspace:GetServerTimeNow()
	if preview and now >= preview.endAt + PREVIEW_HOLD then
		preview = nil
	end
	local state = current or preview
	if not state then
		clearWall()
		warnOutside(false, 0)
		return
	end
	local fx = visual
	if not fx or visualId ~= state.id then
		clearWall()
		fx = OvertimeZoneVfx.new()
		visual = fx
		visualId = state.id
	end
	local radius = Zone.radiusAt(state, now)
	OvertimeZoneVfx.draw(fx, state.centre, radius, math.max(now - state.startAt, 0))
	local position = fighterPosition()
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else position or state.centre
	OvertimeZoneVfx.sparksNear(fx, state.centre, radius, eye)
	if not fx.root.Parent then
		fx.root.Parent = workspace
	end
	warnOutside(current ~= nil and position ~= nil and Zone.outside(state, position, now) > 0, now)
end

function ZoneController.start()
	current = Zone.read()
	Zone.changed():Connect(function()
		current = Zone.read()
		if current then
			preview = nil
		end
	end)
	if RunService:IsStudio() then
		StateValues.changed(workspace, PREVIEW_FIELD):Connect(updatePreview)
		updatePreview()
	end
	RunService.RenderStepped:Connect(step)
end

return ZoneController
