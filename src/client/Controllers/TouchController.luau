--!strict
-- Touch controls (vault/02 Art/UI Mobile Controls.md): drives the Studio-built
-- UI.Match.Touch screen (tools/studio/BuildTouchScreen.luau).
--   * Our own floating stick in the left zone (Roblox's thumbstick and jump
--     button are hidden). It moves the character with Player:Move, follows the
--     thumb past its ring, and pushing it well past the ring straight ahead
--     locks sprint. The stick zone is the one control that blocks the camera.
--   * Every other button lets the camera turn through it (owner: "you should
--     be able to fire and look around"): the buttons are not interactable, so
--     Roblox's camera module still pans the touch, and this controller
--     hit-tests touches itself and fires the input actions.
--   * Aim and Sprint are toggles (owner). Aim only shows for guns that can
--     aim; on a gun with an alt fire (Classic's right click) it holds the alt
--     fire instead. Sprint hides while Auto Sprint is on (Settings).
--   * Slide slides while running, else toggles crouch. Jump is held.
--   * A held button lights up.
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
local PlayerSettings = require(ReplicatedStorage.Shared.PlayerSettings)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Device = require(script.Parent.Parent.Util.Device)
local TouchHud = require(script.Parent.Parent.Util.TouchHud)
local InputController = require(script.Parent.InputController)
local ModController = require(script.Parent.ModController)
local MovementController = require(script.Parent.MovementController)

local TouchController = {}

local player = Players.LocalPlayer

local TABLET = 0.78 -- tablets: every cluster × this (mockup measure, vault note)
local DEADZONE = 0.12
local FOLLOW = 1.6 -- the stick follows the thumb past this x its ring
local LOCK_PUSH = 1.25 -- the stick pulled this far past its ring, straight ahead...
local LOCK_AHEAD = -0.9 -- ...(its direction's screen y at most this)...
local LOCK_HOLD = 0.25 -- ...for this long locks sprint
local UNLOCK_BACK = 0.35 -- pulling back past this (screen y) unlocks it
local SLIDE_PRESS = 0.25 -- s: how long a slide tap holds Crouch
local HIT = 1.2 -- a button's touch area: its circle × this (Soft Edge §7: +20%)
local GAP = 8 -- px between Roblox's buttons and ours
local HIDDEN_PHASES: { [string]: boolean } =
	{ Vote = true, Draft = true, Replay = true, MatchEnd = true }

local PLATE = Color3.fromHex("10141B")
local WHITE = Color3.fromHex("F4F6F9")
local PRESSED = Color3.fromHex("3B4454") -- a held button's lit plate
local REST = 0.45
local PRESS = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Buttons that simply hold an input action while touched.
local HOLD: { [string]: string } = {
	FireButton = "Fire",
	ReloadButton = "Reload",
	Mod1Button = "Mod1",
	Mod2Button = "Mod2",
	Mod3Button = "Mod3",
	PrimaryButton = "Primary",
	SecondaryButton = "Secondary",
	MeleeButton = "Melee",
	QuickMeleeButton = "QuickMelee",
	InspectButton = "Inspect",
}

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
local aimMode: "toggle" | "alt" | "none" = "toggle"
local autoSprint = true

local buttons: { GuiButton } = {}
local touching: { [InputObject]: string } = {} -- a touch → the button it started on

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

-- A button's look from its state: a toggle that's on = a solid light plate
-- with a dark icon; held down = a lit plate (owner: "buttons should have a
-- highlight while clicking them"); else the resting dark plate.
local toggled: { [string]: boolean } = {}
local pressed: { [string]: boolean } = {}
local function paint(name: string)
	local face, icon = faceOf(name)
	local on = toggled[name] == true
	if face then
		face.BackgroundColor3 = if on then WHITE elseif pressed[name] then PRESSED else PLATE
		face.BackgroundTransparency = if on
			then (if pressed[name] then 0.2 else 0.06)
			elseif pressed[name] then 0.12
			else REST
		local press = face:FindFirstChild("Press")
		if press and press:IsA("UIScale") then
			TweenService:Create(press, PRESS, { Scale = if pressed[name] then 0.94 else 1 }):Play()
		end
	end
	if icon and name ~= "FireButton" then
		icon.ImageColor3 = if on then PLATE else WHITE
	end
end

local function showOn(name: string, on: boolean)
	toggled[name] = on
	paint(name)
end

local function setAim(on: boolean)
	aimOn = on
	setAction("Aim", on)
	showOn("AimButton", on and aimMode == "toggle")
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

-- The stick ---------------------------------------------------------------------

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
	-- Past FOLLOW x the ring the stick slides along under the thumb, so a
	-- change of direction answers at once (no dead travel back to the ring).
	if dist > radius * FOLLOW then
		origin = at - delta.Unit * radius * FOLLOW
		delta = at - origin
		dist = delta.Magnitude
		local r0 = root
		if r0 then
			local p = origin - r0.AbsolutePosition
			s.Position = UDim2.fromOffset(p.X, p.Y)
		end
	end
	local clamped = if dist > radius then delta.Unit * radius else delta
	n.Position = UDim2.new(0.5, clamped.X, 0.5, clamped.Y)
	local v = clamped / radius
	moveVector = if v.Magnitude < DEADZONE then Vector2.zero else v
	-- Sprint lock (timed in step, so a thumb held still past the ring locks too).
	pushed = not autoSprint and dist > radius * LOCK_PUSH and delta.Unit.Y <= LOCK_AHEAD
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

-- Buttons -------------------------------------------------------------------------

local function down(name: string)
	pressed[name] = true
	paint(name)
	local action = HOLD[name]
	if action then
		setAction(action, true)
	elseif name == "AimButton" then
		if aimMode == "alt" then
			setAction("Aim", true) -- the gun's alt fire (Classic's right click)
		else
			setAim(not aimOn)
		end
	elseif name == "SprintButton" then
		setSprint(not sprintOn)
	elseif name == "SlideButton" then
		local state = MovementController.getState()
		if state ~= "Slide" then
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
		end
	elseif name == "JumpButton" then
		jumpHeld = true
	elseif name == "ModAltButton" then
		ModController.useAlt()
	end
end

local function up(name: string)
	pressed[name] = false
	paint(name)
	local action = HOLD[name]
	if action then
		setAction(action, false)
	elseif name == "AimButton" and aimMode == "alt" then
		setAction("Aim", false)
	elseif name == "JumpButton" then
		jumpHeld = false
	end
end

local function shown(o: GuiObject): boolean
	local g = gui
	local node: Instance? = o
	while node and node ~= g do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return node == g
end

-- The button under a screen point: the nearest centre within its touch circle.
local function buttonAt(p: Vector2): GuiButton?
	local best: GuiButton? = nil
	local bestD = math.huge
	for _, b in buttons do
		if shown(b) then
			local size = b.AbsoluteSize
			local c = b.AbsolutePosition + size / 2
			local d = (p - c).Magnitude
			if d <= math.min(size.X, size.Y) / 2 * HIT and d < bestD then
				best, bestD = b, d
			end
		end
	end
	return best
end

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch
		or (RunService:IsStudio() and input.UserInputType == Enum.UserInputType.MouseButton1)
end

-- Per-gun Aim: hidden on guns that can't aim; an alt-fire hold on guns whose
-- right click is an alt fire (noAds + altFire, e.g. Classic); else the toggle.
local function refreshAim()
	local id = TouchHud.heldWeaponId()
	local def = if id then Weapons.get(id) else nil
	local mode: "toggle" | "alt" | "none" = "toggle"
	if def and def.noAds then
		mode = if def.altFire then "alt" else "none"
	end
	if mode ~= aimMode then
		if aimOn then
			setAim(false)
		end
		aimMode = mode
	end
	local b = TouchHud.find("AimButton")
	if b then
		b.Visible = mode ~= "none"
	end
end

-- Auto Sprint (Settings, default on): the run is automatic, so there's no
-- Sprint button and no stick lock.
local function refreshSprintSetting()
	local values = PlayerSettings.read(player, 5)
	local v = values and values.autoSprint
	autoSprint = if typeof(v) == "boolean" then v else true
	local b = TouchHud.find("SprintButton")
	if b then
		b.Visible = not autoSprint
	end
	if lock then
		lock.Visible = not autoSprint
	end
	if autoSprint and sprintOn then
		setSprint(false)
	end
end

-- Layout ------------------------------------------------------------------------

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
	-- GuiService.TopbarInset is the free space between Roblox's left and right
	-- buttons: Min.X is the right edge of Roblox's left buttons.
	place("SettingsButton", Vector2.new(inset.Min.X + GAP + d / 2, inset.Min.Y + inset.Height / 2))
	-- The row under Roblox's buttons, from the safe area's left edge, skipping
	-- hidden buttons.
	local rowY = inset.Max.Y + GAP + d / 2
	local x = r.AbsolutePosition.X + GAP * 1.5 + d / 2
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

local function releaseAll()
	for input, name in touching do
		touching[input] = nil
		up(name)
	end
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
			releaseAll()
			resetToggles()
			moveVector = Vector2.zero
			if player.Character then
				player:Move(Vector3.zero, true)
			end
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

function TouchController.stop()
	local wasTouch = gui ~= nil and gui.Enabled
	if wasTouch then
		releaseAll()
		resetToggles()
		releaseStick()
		if player.Character then
			player:Move(Vector3.zero, true)
		end
	end
	InputController.clearTouchButtons(wasTouch)
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

	-- The buttons let touches through to the camera; we hit-test them here.
	for _, d in g:GetDescendants() do
		if d:IsA("GuiButton") and d.Name ~= "StickZone" then
			d.Interactable = false
			table.insert(buttons, d)
		end
	end
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		local gg = gui
		if processed or not gg or not gg.Enabled or not isPointer(input) then
			return
		end
		local b = buttonAt(guiPoint(input))
		if b then
			touching[input] = b.Name
			down(b.Name)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local name = touching[input]
		if name then
			touching[input] = nil
			up(name)
		end
		if input == stickInput then
			releaseStick()
		end
	end)

	-- The stick: touches that start in the zone (a button, so the camera skips them).
	local zone = TouchHud.find("StickZone")
	if zone then
		zone.InputBegan:Connect(function(input: InputObject)
			if stickInput or not isPointer(input) then
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

	-- The scoreboard isn't laid out for touch yet (ScoreboardController skips
	-- compact screens), and there's no match settings screen: hide both.
	for _, name in { "ScoreboardButton", "SettingsButton" } do
		local b = TouchHud.find(name)
		if b then
			b.Visible = false
		end
	end

	TouchHud.onLoadout(refreshAim)
	refreshAim()
	task.spawn(function()
		refreshSprintSetting()
		local values = player:FindFirstChild("Settings")
		if values and values:IsA("StringValue") then
			values.Changed:Connect(refreshSprintSetting)
		end
		layout()
	end)

	RunService:BindToRenderStep("TouchControls", Enum.RenderPriority.Input.Value + 1, step)
	player.CharacterAdded:Connect(function()
		releaseAll()
		resetToggles()
	end)
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
