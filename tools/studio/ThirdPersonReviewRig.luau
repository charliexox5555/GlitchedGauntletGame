-- ThirdPersonReviewRig.luau: see your own character the way other players do,
-- in a Studio playtest (vault/01 Design/Third Person Overhaul.md). Paste into
-- the Studio MCP's execute_luau on the CLIENT datamodel (or the command bar in
-- a running playtest). Nothing here ships: it only touches the camera and
-- LocalTransparencyModifier on this client.
--
-- How it works: the game is first person, so the body is hidden locally and
-- the character turns with the camera. A render step that runs last saves the
-- game's camera, shows the body and moves the camera to an orbit point; the
-- saved camera is put back before the next simulation step, and the character
-- is turned to the saved look by hand (AutoRotate off), so the game still
-- "looks" where it did.
--
-- Controls (shared.TPR, change from another execute_luau call):
--   yaw, pitch, dist, height, fov   the orbit (yaw 0 = straight in front)
--   fixed = { from, lookAt }        a fixed camera instead of the orbit
--   lookPitch                       degrees the game camera looks up (+) / down
--   move = Vector3                  camera-relative walk input (z = -1 forward)
--   on = false                      stop
-- Set Workspace attribute DevThirdPerson = true in Edit first: GripController
-- then puts your own left hand on the gun too, as other players see it.
-- For a state that passes quickly (slide, jump, a swing), clone the character
-- at that moment, anchor the copy and look at the copy instead.
-- Guns: ReplicatedStorage.Remotes.PickWeapon:FireServer(id). Actions:
-- Workspace attributes DevAction ("fire", "reload", "Melee"), DevHold, DevAim.
-- Crouch / slide: LocalPlayer.PlayContext.Crouch:Fire(true / false).

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local cam = workspace.CurrentCamera
local lp = Players.LocalPlayer

shared.TPR = shared.TPR or {}
local S = shared.TPR
pcall(function()
	RunService:UnbindFromRenderStep("TPReview")
end)
pcall(function()
	RunService:UnbindFromRenderStep("TPReviewMove")
end)
if S.conn then
	S.conn:Disconnect()
end
if S.conn2 then
	S.conn2:Disconnect()
end
S.on = true
S.yaw, S.pitch, S.dist, S.height, S.fov = 35, 8, 8, 0.3, 50
S.move = Vector3.zero
S.lookPitch = 0
S.fixed = nil

RunService:BindToRenderStep("TPReviewMove", Enum.RenderPriority.Input.Value + 5, function()
	if S.on and S.move.Magnitude > 0 then
		lp:Move(S.move, true)
	end
end)

RunService:BindToRenderStep("TPReview", Enum.RenderPriority.Last.Value + 50, function()
	if not S.on then
		return
	end
	local c = lp.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	for _, d in c:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = 0
		end
	end
	-- The first-person gun and arms sit at the game camera (your head):
	-- hide them, or they show as a stray block sticking out of the chest.
	for _, d in cam:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
		end
	end
	S.saved = cam.CFrame
	cam.FieldOfView = S.fov
	if S.fixed then
		cam.CFrame = CFrame.lookAt(S.fixed[1], S.fixed[2])
		return
	end
	local focus = root.Position + Vector3.new(0, S.height, 0)
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local base = CFrame.lookAt(focus, focus + look)
	local dir = (base * CFrame.Angles(0, math.rad(S.yaw), 0) * CFrame.Angles(
		math.rad(S.pitch),
		0,
		0
	)).LookVector
	cam.CFrame = CFrame.lookAt(focus + dir * S.dist, focus)
end)

S.conn = RunService.PreAnimation:Connect(function()
	if S.on and S.saved then
		local cf = S.saved
		if S.lookPitch then
			local l = cf.LookVector * Vector3.new(1, 0, 1)
			cf = CFrame.lookAt(cf.Position, cf.Position + l.Unit)
				* CFrame.Angles(math.rad(S.lookPitch), 0, 0)
		end
		cam.CFrame = cf
	end
end)

S.conn2 = RunService.PreSimulation:Connect(function()
	if not S.on then
		return
	end
	local c = lp.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not hum or not root then
		return
	end
	hum.AutoRotate = false
	if S.saved then
		local l = S.saved.LookVector * Vector3.new(1, 0, 1)
		if l.Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + l)
		end
	end
end)

-- A clean frame: no HUD.
for _, g in lp.PlayerGui:GetChildren() do
	if g:IsA("ScreenGui") then
		g.Enabled = false
	end
end
