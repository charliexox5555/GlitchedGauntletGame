--!strict
-- The end of a match (vault/05 Production/Match Structure Revamp.md, phase
-- D): a victory scene on the map (copies of the winning side, side by side,
-- cheering, the camera in front pushing in) and the post-match screen in the
-- v1 style, laid out after the RIVALS reference: VICTORY / DEFEAT on top,
-- your stats card at the bottom, a table of everyone in team modes, and
-- Rematch / Play Again / Leave at the bottom right. The server decides
-- everything (Services/MatchEndService); the buttons only ask.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Animations = require(ReplicatedStorage.Shared.Config.Animations)
local Health = require(ReplicatedStorage.Shared.Health)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Net = require(ReplicatedStorage.Shared.Net)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local CameraController = require(script.Parent.CameraController)
local DeathFxController = require(script.Parent.DeathFxController)
local DraftController = require(script.Parent.DraftController)
local ReplayController = require(script.Parent.ReplayController)
local SpectateController = require(script.Parent.SpectateController)
local ViewmodelController = require(script.Parent.ViewmodelController)
local WeaponController = require(script.Parent.WeaponController)
local Ui = require(script.Parent.Parent.Util.Ui)
local UiSound = require(script.Parent.Parent.Util.UiSound)

local MatchEndController = {}

local C = Theme.COLORS
local player = Players.LocalPlayer

type Line = {
	id: string,
	name: string,
	userId: number?,
	team: number,
	eliminations: number,
	deaths: number,
	assists: number,
	dealt: number,
	taken: number,
	mvp: boolean?,
}

local summary: { Line } = {}
local summaryWinner = 0
local active = false
local scene: Folder? = nil
local hidden: { Instance } = {}
local hiddenGuis: { ScreenGui } = {}
local gui: ScreenGui? = nil
local rematchButton: ImageButton? = nil
local rematchSub: TextLabel? = nil
local countdown: TextLabel? = nil
local picked: string? = nil
local buttons: { [string]: GuiObject } = {}

-- Helpers ---------------------------------------------------------------------------

local function fighters(): { Model }
	local list: { Model } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	local dummies = Workspace:FindFirstChild("Dummies")
	if dummies then
		for _, m in dummies:GetChildren() do
			if m:IsA("Model") and m:GetAttribute("IsBot") == true then
				table.insert(list, m)
			end
		end
	end
	return list
end

local STRIP = {
	Script = true,
	LocalScript = true,
	ModuleScript = true,
	Sound = true,
	ParticleEmitter = true,
	Highlight = true,
	BillboardGui = true,
	ForceField = true,
}

-- A standing copy of a body that can play an animation on this client: the
-- joints stay, only the root is anchored.
local function standingCopy(body: Model): Model?
	local was = body.Archivable
	body.Archivable = true
	local ok, copy = pcall(function()
		return body:Clone()
	end)
	body.Archivable = was
	if not ok or not copy then
		return nil
	end
	for _, d in copy:GetDescendants() do
		if STRIP[d.ClassName] then
			d:Destroy()
		end
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d.Name == "HumanoidRootPart"
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.LocalTransparencyModifier = 0
		elseif d:IsA("Decal") then
			d.LocalTransparencyModifier = 0
		elseif d:IsA("Motor6D") then
			d.Transform = CFrame.identity
		end
	end
	for name in copy:GetAttributes() do
		copy:SetAttribute(name, nil)
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		for name in humanoid:GetAttributes() do
			humanoid:SetAttribute(name, nil)
		end
	end
	return copy
end

local function cheer(copy: Model)
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		local made = Instance.new("Animator")
		made.Parent = humanoid
		animator = made
	end
	local a = animator :: Animator
	for _, track in a:GetPlayingAnimationTracks() do
		track:Stop(0)
	end
	local clip = Instance.new("Animation")
	clip.AnimationId = Animations.COMBAT.Victory
	local ok, track = pcall(function()
		return a:LoadAnimation(clip)
	end)
	if ok and track then
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Action4
		track:Play(0.2)
	end
end

local function hideLive()
	for _, body in fighters() do
		for _, d in body:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = 1
				table.insert(hidden, d)
			end
		end
	end
	for _, copy in CollectionService:GetTagged(DeathFxController.COPY_TAG) do
		for _, d in copy:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = 1
			end
		end
	end
end

-- The scene -------------------------------------------------------------------------

-- Copies of the winners side by side where the first of them ended the match,
-- facing a clear spot for the camera. Returns the camera's start and end
-- positions and the point it looks at.
local function buildScene(winner: number): (Vector3?, Vector3?, Vector3?)
	local winners: { Model } = {}
	for _, body in fighters() do
		if Teams.of(body) == winner then
			table.insert(winners, body)
		end
	end
	-- The survivors first (the last one standing leads).
	table.sort(winners, function(a, b)
		return Health.isAlive(a) and not Health.isAlive(b)
	end)
	local lead = winners[1]
	local leadRoot = lead and lead:FindFirstChild("HumanoidRootPart")
	if not lead or not leadRoot or not leadRoot:IsA("BasePart") then
		return nil, nil, nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = {}
	for _, body in fighters() do
		table.insert(skip, body)
	end
	params.FilterDescendantsInstances = skip
	-- Stand them on the ground.
	local base = leadRoot.Position
	local down = Workspace:Raycast(base + Vector3.new(0, 3, 0), Vector3.new(0, -30, 0), params)
	local ground = if down then down.Position.Y else base.Y - 3
	-- The camera's side: their facing first, then round the circle, the first
	-- with room in front.
	local look = leadRoot.CFrame.LookVector
	local facing = Vector3.new(look.X, 0, look.Z)
	facing = if facing.Magnitude > 1e-3 then facing.Unit else Vector3.zAxis
	local eye = Vector3.new(base.X, ground + 3, base.Z)
	local dir = facing
	for i = 0, 7 do
		local d = CFrame.Angles(0, i * math.pi / 4, 0):VectorToWorldSpace(facing)
		if not Workspace:Raycast(eye, d * 11, params) then
			dir = d
			break
		end
	end
	local right = dir:Cross(Vector3.yAxis)
	local folder = Instance.new("Folder")
	folder.Name = "VictoryScene"
	local spacing = 3.6
	for i, body in winners do
		local copy = standingCopy(body)
		if copy then
			local offset = (i - 1 - (#winners - 1) / 2) * spacing
			local root = copy:FindFirstChild("HumanoidRootPart")
			local hip = if root and root:IsA("BasePart") then root.Size.Y / 2 + 2 else 3
			local at = Vector3.new(base.X, ground + hip, base.Z) + right * offset
			copy:PivotTo(CFrame.lookAt(at, at + dir))
			copy.Parent = folder
			cheer(copy)
		end
	end
	folder.Parent = Workspace
	scene = folder
	local focus = Vector3.new(base.X, ground + 3.2, base.Z)
	local far = focus + dir * 11 + Vector3.new(0, -0.6, 0)
	local near = focus + dir * 8 + Vector3.new(0, -0.9, 0)
	return far, near, focus
end

-- The screen ------------------------------------------------------------------------

local function statBox(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	value: number,
	label: string
)
	local box = Ui.cut(parent, {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, 74),
	}, { color = C.card, transparency = 0.1, corner = 10 })
	Ui.text(box, tostring(value), "displayM", {
		Size = UDim2.new(1, 0, 0, 46),
		Position = UDim2.fromOffset(0, 4),
		ZIndex = 4,
	})
	Ui.text(box, label, "label", {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 50),
		TextColor3 = C.textSecondary,
		ZIndex = 4,
	})
end

local function mine(): Line?
	local id = "p" .. player.UserId
	for _, line in summary do
		if line.id == id then
			return line
		end
	end
	return nil
end

local function setPicked(choice: string)
	picked = choice
	for name, b in buttons do
		local line = b:FindFirstChild("Line")
		if line and line:IsA("ImageLabel") then
			line.ImageColor3 = if name == choice then C.gold else C.lineStrong
		end
	end
end

local function button(
	parent: Instance,
	name: string,
	label: string,
	y: number,
	primary: boolean
): ImageButton
	local b = Ui.cut(parent, {
		Name = name,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, y),
		Size = UDim2.fromOffset(300, 74),
	}, {
		className = "ImageButton",
		color = if primary then C.gold else C.panel,
		transparency = if primary then 0 else 0.1,
		line = C.lineStrong,
		corner = 14,
	})
	Ui.text(b, label, "titleCard", {
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 6),
		TextSize = 36,
		TextColor3 = if primary then C.onAccent else C.text,
		ZIndex = 4,
	})
	buttons[name] = b
	b.Activated:Connect(function()
		if picked == "PlayAgain" or picked == "Leave" then
			return
		end
		if name == "Rematch" and MatchState.get("RematchOpen") ~= true then
			UiSound.play("Denied")
			return
		end
		UiSound.play("Select")
		setPicked(name)
		Net.event("MatchChoice"):FireServer(name)
	end)
	return b
end

local function buildScreen(winner: number)
	local old = gui
	if old then
		old:Destroy()
	end
	table.clear(buttons)
	picked = nil
	local screen = Ui.make("ScreenGui", {
		Name = "MatchEnd",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 15,
	}, player:WaitForChild("PlayerGui"))
	gui = screen
	-- Frees the mouse in first person while the screen is up.
	Ui.make("TextButton", {
		Modal = true,
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromOffset(0, 0),
	}, screen)
	local won = winner == Teams.of(player)
	local accent = if won then C.ally else C.enemy

	-- Top banner.
	local top = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(520, 120),
		BackgroundTransparency = 1,
	}, screen)
	Ui.cut(top, { Size = UDim2.fromScale(1, 1) }, {
		color = C.panel,
		transparency = 0.12,
		line = accent,
		corner = 16,
	})
	Ui.text(top, if won then "VICTORY" else "DEFEAT", "displayL", {
		Size = UDim2.new(1, 0, 0, 64),
		Position = UDim2.fromOffset(0, 12),
		TextColor3 = accent,
		ZIndex = 4,
	})
	local one, two = MatchState.get("Score1") or 0, MatchState.get("Score2") or 0
	local myTeam = Teams.of(player) or 1
	Ui.text(
		top,
		string.format(
			"%d  —  %d",
			if myTeam == 1 then one else two,
			if myTeam == 1 then two else one
		),
		"titleS",
		{
			Size = UDim2.new(1, 0, 0, 28),
			Position = UDim2.fromOffset(0, 78),
			TextColor3 = C.textSecondary,
			ZIndex = 4,
		}
	)
	Ui.fit(top)

	-- Your card.
	local me = mine()
	local card = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.fromOffset(440, 270),
		BackgroundTransparency = 1,
	}, screen)
	Ui.cut(card, { Size = UDim2.fromScale(1, 1) }, {
		color = C.panel,
		transparency = 0.12,
		line = C.lineStrong,
		corner = 16,
	})
	local plate = Ui.cut(card, {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 64),
	}, { color = accent, corner = 16 })
	Ui.text(plate, string.upper(player.DisplayName), "titleCard", {
		Size = UDim2.new(1, -24, 0, 44),
		Position = UDim2.fromOffset(12, 4),
		TextColor3 = C.onAccent,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 4,
	})
	Ui.text(plate, "@" .. player.Name .. (if me and me.mvp then "   ·   MVP" else ""), "label", {
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 44),
		TextColor3 = C.onAccent,
		ZIndex = 4,
	})
	if me then
		statBox(card, 20, 80, 124, me.eliminations, "ELIMINATIONS")
		statBox(card, 158, 80, 124, me.deaths, "DEATHS")
		statBox(card, 296, 80, 124, me.assists, "ASSISTS")
		statBox(card, 20, 170, 194, me.dealt, "DAMAGE DEALT")
		statBox(card, 226, 170, 194, me.taken, "DAMAGE TAKEN")
	end
	Ui.fit(card)

	-- Everyone (team modes).
	if #summary > 2 then
		local tableFrame = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 40, 1, -40),
			Size = UDim2.fromOffset(420, 40 + 34 * #summary),
			BackgroundTransparency = 1,
		}, screen)
		Ui.cut(tableFrame, { Size = UDim2.fromScale(1, 1) }, {
			color = C.panel,
			transparency = 0.15,
			corner = 12,
		})
		Ui.text(tableFrame, "PLAYER                         E     D     A     DMG", "label", {
			Size = UDim2.new(1, -24, 0, 18),
			Position = UDim2.fromOffset(12, 12),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.textSecondary,
			ZIndex = 4,
		})
		for i, line in summary do
			local y = 34 + (i - 1) * 34
			local row = Ui.make("Frame", {
				Position = UDim2.fromOffset(12, y),
				Size = UDim2.new(1, -24, 0, 30),
				BackgroundTransparency = 1,
				ZIndex = 4,
			}, tableFrame)
			local colour = if line.team == myTeam then C.ally else C.enemy
			Ui.text(row, (if line.mvp then "★ " else "") .. string.upper(line.name), "bodyM", {
				Size = UDim2.new(0, 190, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = colour,
				ZIndex = 4,
			})
			local values = { line.eliminations, line.deaths, line.assists, line.dealt }
			for j, v in values do
				Ui.text(row, tostring(v), "bodyM", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromOffset(222 + (j - 1) * 46 + (if j == 4 then 10 else 0), 0),
					Size = UDim2.fromOffset(60, 30),
					ZIndex = 4,
				})
			end
		end
		Ui.fit(tableFrame)
	end

	-- Buttons.
	local side = Ui.make("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -40, 1, -40),
		Size = UDim2.fromOffset(300, 290),
		BackgroundTransparency = 1,
	}, screen)
	countdown = Ui.text(side, "", "label", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(300, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.textSecondary,
	})
	local rematch = button(side, "Rematch", "REMATCH", 30, false)
	rematchButton = rematch
	rematchSub = Ui.text(rematch, "", "label", {
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 50),
		TextColor3 = C.textSecondary,
		ZIndex = 4,
	})
	button(side, "PlayAgain", "PLAY AGAIN", 116, true)
	button(side, "Leave", "LEAVE", 202, false)
	Ui.fit(side)
end

local function refreshScreen()
	local label = countdown
	if label then
		label.Text = string.format("BACK TO THE LOBBY IN %d", math.ceil(MatchState.timeLeft()))
	end
	local b = rematchButton
	local sub = rematchSub
	if b and sub then
		local openNow = MatchState.get("RematchOpen") == true
		local votes = MatchState.get("RematchVotes") or 0
		local needed = MatchState.get("RematchNeeded") or 0
		sub.Text = if openNow then string.format("%d / %d VOTED", votes, needed) else "UNAVAILABLE"
		b.ImageTransparency = if openNow then 0.1 else 0.6
		b.Active = openNow
	end
end

-- Start and end -------------------------------------------------------------------

-- The fighter body a part belongs to (a held gun is a Model inside it).
local function fighterOf(d: Instance): Model?
	local node = d.Parent
	while node and node ~= Workspace do
		if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function stop()
	if not active then
		return
	end
	active = false
	CameraController.setOverride(nil)
	if not DraftController.isOpen() then -- a rematch's draft may already want it
		CameraController.setCursorVisible(false)
	end
	local s = scene
	if s then
		s:Destroy()
		scene = nil
	end
	for _, d in hidden do
		local body = fighterOf(d)
		if d.Parent and body and Health.isAlive(body) then
			(d :: any).LocalTransparencyModifier = 0
		end
	end
	table.clear(hidden)
	for _, g in hiddenGuis do
		if g.Parent then
			g.Enabled = true
		end
	end
	table.clear(hiddenGuis)
	local screen = gui
	if screen then
		screen:Destroy()
		gui = nil
	end
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

local function begin()
	if active then
		return
	end
	active = true
	local winner = summaryWinner
	if winner == 0 then
		local w = MatchState.get("MatchWinner")
		winner = if typeof(w) == "number" then w else 0
	end
	SpectateController.stop()
	DeathFxController.clearGrade()
	WeaponController.setSpectating(true)
	ViewmodelController.unequip()
	CameraController.setZoom(nil, 0)
	CameraController.setCursorVisible(true)
	hideLive()
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		for _, g in playerGui:GetChildren() do
			if g:IsA("ScreenGui") and g.Name ~= "MatchEnd" and g.Enabled then
				g.Enabled = false
				table.insert(hiddenGuis, g)
			end
		end
	end
	local far, near, focus = buildScene(winner)
	buildScreen(winner)
	UiSound.play(if winner == Teams.of(player) then "Victory" else "RoundLost")
	local cam = Workspace.CurrentCamera
	if cam and far and near and focus then
		cam.CameraType = Enum.CameraType.Scriptable
		local began = os.clock()
		CameraController.setOverride(function(c: Camera, _dt: number)
			for _, d in hidden do
				(d :: any).LocalTransparencyModifier = 1
			end
			local t = math.clamp((os.clock() - began) / 6, 0, 1)
			local e = 1 - (1 - t) ^ 3
			c.CFrame = CFrame.lookAt((far :: Vector3):Lerp(near :: Vector3, e), focus :: Vector3)
		end)
	end
end

local function onPhase()
	if MatchState.phase() == "MatchEnd" then
		-- The replay hands its screen back first (it ends at the same moment).
		task.spawn(function()
			local deadline = os.clock() + 3
			while ReplayController.isPlaying() and os.clock() < deadline do
				task.wait(0.05)
			end
			if MatchState.phase() == "MatchEnd" then
				begin()
			end
		end)
	else
		stop()
	end
end

function MatchEndController.start()
	Net.event("MatchSummary").OnClientEvent:Connect(function(lines: unknown, winner: unknown)
		if typeof(lines) == "table" then
			summary = lines :: any
		end
		summaryWinner = if typeof(winner) == "number" then winner else 0
	end)
	MatchState.changed("Phase"):Connect(onPhase)
	player.CharacterAdded:Connect(stop)
	task.spawn(function()
		while true do
			task.wait(0.2)
			if active then
				refreshScreen()
			end
		end
	end)
	onPhase()
end

return MatchEndController
