--!strict
-- Touch controls (vault/02 Art/UI Mobile Controls.md, mockup v2): drives the
-- Studio-built UI.Match.Touch screen (tools/studio/BuildTouchScreen.luau).
--   * Our own floating stick in the left zone (Roblox's thumbstick and jump
--     button are hidden): it moves the character with Player:Move, and
--     pushing it past its ring straight ahead locks sprint.
--   * Fire, Reload, the Mods, the weapon slots, Quick Melee and Inspect are
--     linked to their input actions (Config/Input touch names).
--   * Aim and Sprint are always toggles on touch (owner); Slide slides while
--     running, else toggles crouch. These fire their input actions directly.
--   * Jump is held like Roblox's button.
-- Phones use the screen as built; tablets shrink every cluster (TABLET).
-- Layout rules: vault/04 Tech/UI Architecture.md §5.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Device = require(script.Parent.Parent.Util.Device)
local TouchHud = require(script.Parent.Parent.Util.TouchHud)
local InputController = require(script.Parent.InputController)
local MovementController = require(script.Parent.MovementController)

local TouchController = {}

local player = Players.LocalPlayer

local TABLET = 0.78 -- tablets: every cluster × this (mockup measure, vault note)
local DEADZONE = 0.12
local LOCK_PUSH = 1.25 -- the stick pulled this far past its ring, straight ahead...
local LOCK_AHEAD = -0.9 -- ...(its direction's screen y at most this)...
local LOCK_HOLD = 0.25 -- ...for this long locks sprint
local UNLOCK_BACK = 0.35 -- pulling back past this (screen y) unlocks it
local SLIDE_PRESS = 0.25 -- s: how long a slide tap holds Crouch
local GAP = 8 -- px between Roblox's buttons and ours
local HIDDEN_PHASES: { [string]: boolean } =
	{ Vote = true, Draft = true, Replay = true, MatchEnd = true }

local PLATE = Color3.fromHex("10141B")
local WHITE = Color3.fromHex("F4F6F9")
local REST = 0.45
local PRESS = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local gui: ScreenGui? = nil
local root: Frame? = nil
local stick: Frame? = nil
local nub: Frame? = nil
local lock: ImageLabel? = nil

local stickInput: InputObject? = nil -- the touch (or Studio mouse) driving the stick
local origin = Vector2.zero
local moveVector = Vector2.zero
local pushed = false -- the stick is past the lock distance, straight ahead
local wasMoving = false
local lockSince: number? = nil
local jumpHeld = false
local aimOn, sprintOn, crouchOn = false, false, false

local function setAction(name: string, value: boolean)
	local ok, action = pcall(InputController.action, name)
	if ok and action:GetState() ~= value then
		action:Fire(value)
	end
end

local function faceOf(name: string): (Frame?, ImageLabel?)
	local b = TouchHud.find(name)
	local face = b and b:FindFirstChild("Face")
	if not face or not face:IsA("Frame") then
		return nil, nil
	end
	local icon = face:FindFirstChild("Icon")
	return face, if icon and icon:IsA("ImageLabel") then icon else nil
end

-- A toggle that's on: a solid light plate with a dark icon.
local function showOn(name: string, on: boolean)
	local face, icon = faceOf(name)
	if face then
		face.BackgroundColor3 = if on then WHITE else PLATE
		face.BackgroundTransparency = if on then 0.06 else REST
	end
	if icon then
		icon.ImageColor3 = if on then PLATE else WHITE
	end
end

local function setAim(on: boolean)
	aimOn = on
	setAction("Aim", on)
	showOn("AimButton", on)
end

local function setSprint(on: boolean)
	sprintOn = on
	setAction("Sprint", on)
	showOn("SprintButton", on)
	if lock then
		lock.ImageTransparency = if on then 0 else 0.35
	end
end

local function setCrouch(on: boolean)
	crouchOn = on
	setAction("Crouch", on)
	showOn("SlideButton", on)
end

local function resetToggles()
	setAim(false)
	setSprint(false)
	setCrouch(false)
	jumpHeld = false
end

-- Screen point of an input, in the same space as GuiObject.AbsolutePosition.
local function guiPoint(input: InputObject): Vector2
	local inset = GuiService:GetGuiInset()
	return Vector2.new(input.Position.X, input.Position.Y) + inset
end

local function placeStick(at: Vector2, faint: boolean)
	local s, r = stick, root
	if not s or not r then
		return
	end
	local p = at - r.AbsolutePosition
	s.Position = UDim2.fromOffset(p.X, p.Y)
	s.BackgroundTransparency = if faint then 0.8 else 0.6
	local n = nub
	if n then
		n.Position = UDim2.fromScale(0.5, 0.5)
		n.BackgroundTransparency = if faint then 0.55 else 0.12
	end
end

local function restPoint(): Vector2?
	local rest = TouchHud.find("StickRest")
	return if rest then rest.AbsolutePosition + rest.AbsoluteSize / 2 else nil
end

local function releaseStick()
	stickInput = nil
	moveVector = Vector2.zero
	pushed = false
	lockSince = nil
	local at = restPoint()
	if at then
		placeStick(at, true)
	end
end

local function dragStick(at: Vector2)
	local s, n = stick, nub
	if not s or not n then
		return
	end
	local radius = s.AbsoluteSize.X / 2
	if radius <= 0 then
		return
	end
	local delta = at - origin
	local dist = delta.Magnitude
	local clamped = if dist > radius then delta.Unit * radius else delta
	n.Position = UDim2.new(0.5, clamped.X, 0.5, clamped.Y)
	local v = clamped / radius
	moveVector = if v.Magnitude < DEADZONE then Vector2.zero else v
	-- Sprint lock (timed in step, so a thumb held still past the ring locks too).
	pushed = dist > radius * LOCK_PUSH and delta.Unit.Y <= LOCK_AHEAD
	if not pushed and sprintOn and moveVector.Y > UNLOCK_BACK then
		setSprint(false)
	end
end

local function step()
	local g = gui
	if not g or not g.Enabled then
		return
	end
	local moving = moveVector.Magnitude > 0
	if moving or wasMoving then
		-- Camera-relative, like Roblox's own stick (screen y down = backwards).
		player:Move(Vector3.new(moveVector.X, 0, moveVector.Y), true)
	end
	wasMoving = moving
	if pushed then
		local now = os.clock()
		lockSince = lockSince or now
		if not sprintOn and now - lockSince >= LOCK_HOLD then
			setSprint(true)
		end
	else
		lockSince = nil
	end
	if jumpHeld then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Jump = true
		end
	end
end

-- Press motion on every button's face (the hit area never scales).
local function bindPress(button: GuiButton)
	local face = button:FindFirstChild("Face")
	local press = face and face:FindFirstChild("Press")
	if not press or not press:IsA("UIScale") then
		return
	end
	local function isPointer(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
	end
	button.InputBegan:Connect(function(input: InputObject)
		if isPointer(input) then
			TweenService:Create(press, PRESS, { Scale = 0.94 }):Play()
		end
	end)
	button.InputEnded:Connect(function(input: InputObject)
		if isPointer(input) then
			TweenService:Create(press, PRESS, { Scale = 1 }):Play()
		end
	end)
end

local function onTap(name: string, fn: () -> (), onRelease: (() -> ())?)
	local b = TouchHud.find(name)
	if not b or not b:IsA("GuiButton") then
		return
	end
	b.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			fn()
		end
	end)
	if onRelease then
		b.InputEnded:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				onRelease()
			end
		end)
	end
end

-- Phones: the clusters as built. Tablets: smaller (height-sized clusters get
-- too big on 4:3). Settings sits beside Roblox's buttons, the row under them.
local function layout()
	local r = root
	if not r then
		return
	end
	local scale = if Device.isPhone() then 1 else TABLET
	for _, c in r:GetChildren() do
		local side = c:GetAttribute("PhoneSide")
		if c:IsA("Frame") and typeof(side) == "number" then
			c.Size = UDim2.fromScale(side * scale, side * scale)
		end
	end
	local s = stick
	if s then
		s.Size = UDim2.fromScale(0.27 * scale, 0.27 * scale)
	end
	local inset = GuiService.TopbarInset
	local topLeft = r:FindFirstChild("TopLeft")
	if inset.Height <= 0 or not topLeft or not topLeft:IsA("Frame") then
		return
	end
	local box = topLeft.AbsoluteSize
	if box.X <= 0 then
		return
	end
	local function place(name: string, centre: Vector2)
		local b = topLeft:FindFirstChild(name)
		if b and b:IsA("GuiObject") then
			local p = (centre - topLeft.AbsolutePosition) / box
			b.Position = UDim2.fromScale(p.X, p.Y)
		end
	end
	local settings = topLeft:FindFirstChild("SettingsButton")
	local d = if settings and settings:IsA("GuiObject")
		then settings.AbsoluteSize.X
		else box.X * 0.16
	place("SettingsButton", Vector2.new(inset.Max.X + GAP + d / 2, inset.Min.Y + inset.Height / 2))
	-- The row under Roblox's buttons, left to right, skipping hidden buttons.
	local rowY = inset.Max.Y + GAP + d / 2
	local x = inset.Min.X + d / 2
	for _, name in { "ScoreboardButton", "InspectButton" } do
		local b = topLeft:FindFirstChild(name)
		if b and b:IsA("GuiObject") and b.Visible then
			place(name, Vector2.new(x, rowY))
			x += d + GAP
		end
	end
end

local function visible(): boolean
	if not TouchHud.enabled() then
		return false
	end
	local phase = MatchState.phase()
	return not (phase and HIDDEN_PHASES[phase])
end

local function refresh()
	local g = gui
	if not g then
		return
	end
	local on = visible()
	if g.Enabled ~= on then
		g.Enabled = on
		if on then
			TouchHud.refresh()
			releaseStick()
		else
			resetToggles()
			moveVector = Vector2.zero
			player:Move(Vector3.zero, true)
		end
	end
	-- Roblox's stick and jump button give way to ours (CoreUi saves and
	-- restores this around menus; the lobby host turns it back on).
	pcall(function()
		if on and GuiService.TouchControlsEnabled then
			GuiService.TouchControlsEnabled = false
		end
	end)
end

function TouchController.start()
	local g = TouchHud.screen()
	if not g then
		local pg = player:WaitForChild("PlayerGui")
		local found = pg:WaitForChild("Touch", 10)
		g = if found and found:IsA("ScreenGui") then found else nil
	end
	if not g then
		return
	end
	gui = g
	local r = g:FindFirstChild("Root")
	root = if r and r:IsA("Frame") then r else nil
	local s = TouchHud.find("Stick")
	stick = if s and s:IsA("Frame") then s else nil
	local n = s and s:FindFirstChild("Nub")
	nub = if n and n:IsA("Frame") then n else nil
	local l = s and s:FindFirstChild("SprintLock")
	lock = if l and l:IsA("ImageLabel") then l else nil

	-- Buttons wired to their input actions, and press motion on all of them.
	InputController.bindTouchButtons(g)
	for _, d in g:GetDescendants() do
		if d:IsA("GuiButton") and d.Name ~= "StickZone" then
			bindPress(d)
		end
	end

	-- The stick: touches that start in the zone (a button, so the camera skips them).
	local zone = TouchHud.find("StickZone")
	if zone then
		zone.InputBegan:Connect(function(input: InputObject)
			local kind = input.UserInputType
			if
				stickInput
				or (kind ~= Enum.UserInputType.Touch and kind ~= Enum.UserInputType.MouseButton1)
			then
				return
			end
			stickInput = input
			origin = guiPoint(input)
			placeStick(origin, false)
		end)
	end
	UserInputService.InputChanged:Connect(function(input: InputObject)
		local held = stickInput
		if not held then
			return
		end
		if
			input == held
			or (
				held.UserInputType == Enum.UserInputType.MouseButton1
				and input.UserInputType == Enum.UserInputType.MouseMovement
			)
		then
			dragStick(guiPoint(input))
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input == stickInput then
			releaseStick()
		end
	end)

	-- Toggles and Jump.
	onTap("AimButton", function()
		setAim(not aimOn)
	end)
	onTap("SprintButton", function()
		setSprint(not sprintOn)
	end)
	onTap("SlideButton", function()
		local state = MovementController.getState()
		if state == "Slide" then
			return
		end
		if state == "Sprint" and not crouchOn then
			-- A short press: the movement code slides from a run.
			setAction("Crouch", true)
			task.delay(SLIDE_PRESS, function()
				if not crouchOn then
					setAction("Crouch", false)
				end
			end)
		else
			setCrouch(not crouchOn)
		end
	end)
	onTap("JumpButton", function()
		jumpHeld = true
	end, function()
		jumpHeld = false
	end)

	-- The scoreboard isn't laid out for touch yet (ScoreboardController skips
	-- compact screens), and there's no match settings screen: hide both.
	for _, name in { "ScoreboardButton", "SettingsButton" } do
		local b = TouchHud.find(name)
		if b then
			b.Visible = false
		end
	end

	RunService:BindToRenderStep("TouchControls", Enum.RenderPriority.Input.Value + 1, step)
	player.CharacterAdded:Connect(resetToggles)
	pcall(function() -- the range has no match state
		MatchState.changed("Phase"):Connect(refresh)
	end)
	pcall(function()
		UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(refresh)
	end)
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	end
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layout)
	refresh()
	task.defer(function()
		layout()
		releaseStick()
	end)
end

return TouchController
