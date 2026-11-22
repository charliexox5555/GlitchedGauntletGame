--!strict
-- Talking to lobby NPCs (owner 2026-11-16: "the guy like in RIVALS that you can go up to ... talk to him to open
-- up your locker"; then "resemble RIVALS more ... they go into this separate HUD"). RIVALS' DialogLobby /
-- DialogPage, in our kit. Every Model tagged `LobbyNPC` with a `Talk` attribute (the lobby builder sets it, e.g.
-- the ARMORER) gets a local ProximityPrompt drawn as our own card (an off-white slanted plate: key tile, his name,
-- "Talk"). Talking opens the Router page "Talk" (LobbyKit.page: the world blurred behind a dark violet wash):
-- StarterGui.NpcTalk (tools/studio/BuildNpcTalk.luau) shows his live portrait (a clone playing his idle) at the
-- bottom left, types his line into the speech plate beside him, then pops the reply bubbles in above it. A reply
-- goes to another line, opens a lobby menu ("Open my Locker" → Router "Locker") or closes. Lines:
-- lobby/shared/NpcTalk. Client UI only: opening a menu changes nothing on the server, so no remote is involved.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Lines = require(ReplicatedStorage.Lobby.NpcTalk)
local UiMotion = require(ReplicatedStorage.Shared.UiMotion)
local UiStyle = require(ReplicatedStorage.Shared.Config.UiStyle)
local LobbyKit = require(script.Parent.Parent.Util.LobbyKit)
local Router = require(script.Parent.Parent.Util.Router)

local NpcTalk = {}

local TAG = "LobbyNPC"
local PROMPT = "NpcTalkPrompt"
local TALK_RANGE = 12 -- studs
local TYPE_RATE = 48 -- characters a second
local KEY_ACTION = "NpcTalkKeys" -- 1-4 pick a reply (Backspace / B close: the Router)
local IDLE = "rbxassetid://507766388" -- Roblox's R15 idle, as LobbyNpcs plays it in the world
local PAPER = Color3.fromHex("FFFDFE")
local VIOLET = Color3.fromHex("6539D7")

local C = UiStyle.KIT.color
local FONT = LobbyKit.FONT

local gui: ScreenGui? = nil
local npcId: string? = nil
local typing: RBXScriptConnection? = nil
local token = 0
local replyButtons: { GuiButton } = {}
local replyActions: { () -> () } = {}
local prompts: { [Model]: ProximityPrompt } = {}

local function child<T>(parent: Instance?, name: string): T?
	local c = parent and parent:FindFirstChild(name, true)
	return (c :: any) :: T?
end

local function ui(): ScreenGui?
	if gui and gui.Parent then
		return gui
	end
	local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local g = pg and pg:WaitForChild("NpcTalk", 10)
	if g and g:IsA("ScreenGui") then
		gui = g
		LobbyKit.deepen(g) -- its plates follow their colour (PlateArt, Util/Plates)
		local tpl = child(g, "ReplyTemplate") :: GuiObject?
		if tpl then
			tpl.Visible = false
		end
		for _, n in { "Speech", "Name" } do
			local body = child(g, n) :: GuiObject?
			if body then
				LobbyKit.plate(body)
			end
		end
		return g
	end
	return nil
end

local function clearPortrait()
	local vp = child(ui(), "Portrait") :: ViewportFrame?
	if vp then
		for _, c in vp:GetChildren() do
			if c:IsA("WorldModel") or c:IsA("Camera") then
				c:Destroy()
			end
		end
	end
end

-- His live portrait: a clone in a WorldModel playing his idle, framed chest up, turned toward his words.
local function portrait(model: Model)
	local vp = child(ui(), "Portrait") :: ViewportFrame?
	if not vp then
		return
	end
	clearPortrait()
	local was = model.Archivable
	model.Archivable = true
	local copy = model:Clone()
	model.Archivable = was
	if not copy then
		return
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BillboardGui") or d:IsA("ProximityPrompt") or d:IsA("BaseScript") then
			d:Destroy()
		end
	end
	CollectionService:RemoveTag(copy, TAG)
	local world = Instance.new("WorldModel")
	world.Parent = vp
	copy:PivotTo(CFrame.new())
	copy.Parent = world
	local head = copy:FindFirstChild("Head")
	local root = copy:FindFirstChild("HumanoidRootPart")
	if not (head and head:IsA("BasePart") and root and root:IsA("BasePart")) then
		return
	end
	local _, size = copy:GetBoundingBox()
	local h = math.max(size.Y, 4)
	local look, right = root.CFrame.LookVector, root.CFrame.RightVector
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local eye = head.Position
	cam.CFrame = CFrame.lookAt(
		eye + look * h * 1.7 + right * h * 0.55 + Vector3.yAxis * h * 0.03,
		eye - Vector3.yAxis * h * 0.17 + right * h * 0.06
	)
	cam.Parent = vp
	vp.CurrentCamera = cam
	local humanoid = copy:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		local animator = humanoid:FindFirstChildWhichIsA("Animator")
		if not animator then
			local a = Instance.new("Animator")
			a.Parent = humanoid
			animator = a
		end
		local anim = Instance.new("Animation")
		local override = StateValues.get(model, "IdleAnim")
		anim.AnimationId = if typeof(override) == "string" and override ~= ""
			then override
			else IDLE
		local ok, track = pcall(function()
			return (animator :: Animator):LoadAnimation(anim)
		end)
		if ok and track then
			track.Looped = true
			track:Play(0)
		end
	end
end

local function stopTyping()
	if typing then
		typing:Disconnect()
		typing = nil
	end
end

local function clearReplies()
	for _, b in replyButtons do
		local holder = b.Parent
		if holder and StateValues.get(holder, "PivotHolder") == true then
			holder:Destroy()
		else
			b:Destroy()
		end
	end
	table.clear(replyButtons)
	table.clear(replyActions)
end

local show: (string) -> ()

local function showReplies(npcData: Lines.Npc, line: Lines.Line, mine: number)
	local g = ui()
	local list = child(g, "Replies") :: Frame?
	local tpl = child(g, "ReplyTemplate") :: TextButton?
	if not (g and list and tpl) then
		return
	end
	for i, r in line.replies do
		local b = tpl:Clone()
		b.Name = "Reply" .. i
		b.LayoutOrder = i
		b.Visible = true
		local colour = if r.close then C.red else VIOLET
		b.BackgroundColor3 = colour
		local label = b:FindFirstChild("Label")
		if label and label:IsA("TextLabel") then
			label.Text = r.text
		end
		b.Parent = list
		-- a bubble as wide as its words
		if label and label:IsA("TextLabel") then
			b.Size = UDim2.fromOffset(math.ceil(label.TextBounds.X) + 64, b.Size.Y.Offset)
		end
		LobbyKit.plate(b)
		local function act()
			if mine ~= token then
				return
			end
			if r.open then
				Router.open(r.open)
			elseif r.go and npcData.lines[r.go] then
				show(r.go)
			else
				Router.close()
			end
		end
		LobbyKit.button(b, act)
		table.insert(replyButtons, b)
		table.insert(replyActions, act)
		UiMotion.popIn(LobbyKit.pop(b), 0.08 * (i - 1), 0)
	end
end

show = function(key: string)
	local g = ui()
	local data = npcId and Lines[npcId]
	local line = data and data.lines[key]
	if not (g and data and line) then
		return
	end
	token += 1
	local mine = token
	stopTyping()
	clearReplies()
	local msg = child(g, "Message") :: TextLabel?
	local title = child(g, "Title") :: TextLabel?
	if title then
		title.Text = data.name
	end
	if not msg then
		return
	end
	msg.Text = line.say
	local total = utf8.len(line.say) or #line.say
	local function done()
		stopTyping()
		msg.MaxVisibleGraphemes = -1
		showReplies(data, line, mine)
	end
	if UiMotion.reduced() then
		done()
		return
	end
	msg.MaxVisibleGraphemes = 0
	local start = os.clock()
	typing = RunService.RenderStepped:Connect(function()
		local n = math.floor((os.clock() - start) * TYPE_RATE)
		if n >= total then
			done()
		else
			msg.MaxVisibleGraphemes = n
		end
	end)
	local skip = child(g, "Skip") :: TextButton?
	if skip then
		skip.Activated:Once(function()
			if mine == token and typing then
				done()
			end
		end)
	end
end

local function setPrompts(on: boolean)
	for _, p in prompts do
		p.Enabled = on
	end
end

local function keyIndex(code: Enum.KeyCode): number
	if code == Enum.KeyCode.One then
		return 1
	elseif code == Enum.KeyCode.Two then
		return 2
	elseif code == Enum.KeyCode.Three then
		return 3
	elseif code == Enum.KeyCode.Four then
		return 4
	end
	return 0
end

local function onOpen(arg: any?)
	if not (typeof(arg) == "Instance" and arg:IsA("Model")) then
		return
	end
	local id = StateValues.get(arg, "Talk")
	local data = if typeof(id) == "string" then Lines[id] else nil
	if not data then
		return
	end
	npcId = id :: string
	setPrompts(false)
	portrait(arg)
	local g = ui()
	UiMotion.slideIn(child(g, "Portrait") :: GuiObject?, -120, 0, 0, UiMotion.M.long)
	UiMotion.slideIn(child(g, "Speech") :: GuiObject?, 0, 50, 0.05, UiMotion.M.long)
	UiMotion.slideIn(child(g, "Name") :: GuiObject?, 0, 50, 0.08, UiMotion.M.long)
	UiMotion.slideIn(child(g, "Pointer") :: GuiObject?, 0, 50, 0.05, UiMotion.M.long)
	ContextActionService:BindActionAtPriority(
		KEY_ACTION,
		function(_, state, input)
			if state ~= Enum.UserInputState.Begin then
				return Enum.ContextActionResult.Pass
			end
			local act = replyActions[keyIndex(input.KeyCode)]
			if act then
				act()
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.One,
		Enum.KeyCode.Two,
		Enum.KeyCode.Three,
		Enum.KeyCode.Four
	)
	show(data.start)
end

local function onClose()
	token += 1
	stopTyping()
	ContextActionService:UnbindAction(KEY_ACTION)
	local mine = token
	task.delay(UiMotion.M.long, function()
		if mine == token then
			clearReplies()
			clearPortrait()
		end
	end)
	npcId = nil
	setPrompts(true)
end

-- The prompt, drawn as our card (ProximityPrompt Style Custom): an off-white slanted plate with a dark key tile,
-- his name and "Talk", a pointer under it. Click or tap it too.
local function keyText(): string
	if UserInputService.KeyboardEnabled then
		return "E"
	elseif UserInputService.GamepadEnabled then
		return "X"
	end
	return "TAP"
end

local function label(
	parent: Instance,
	name: string,
	pos: UDim2,
	size: UDim2,
	text: string,
	textSize: number,
	colour: Color3
): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Position = pos
	t.Size = size
	t.FontFace = FONT
	t.TextSize = textSize
	t.TextColor3 = colour
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = text
	t.Parent = parent
	return t
end

local function card(prompt: ProximityPrompt, model: Model): BillboardGui?
	local root = prompt.Parent
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	local _, size = model:GetBoundingBox()
	local top = model:GetPivot().Position.Y + size.Y / 2
	local bb = Instance.new("BillboardGui")
	bb.Name = "NpcTalkCard"
	bb.Adornee = root
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Size = UDim2.fromOffset(300, 96)
	bb.StudsOffsetWorldSpace = Vector3.new(0, top - root.Position.Y + 1.6, 0)
	bb.ResetOnSpawn = false
	local plate = Instance.new("TextButton")
	plate.Name = "Plate"
	plate.AutoButtonColor = false
	plate.Text = ""
	plate.AnchorPoint = Vector2.new(0.5, 0)
	plate.Position = UDim2.fromScale(0.5, 0)
	plate.Size = UDim2.fromOffset(240, 76)
	plate.BackgroundColor3 = PAPER
	plate.BorderSizePixel = 0
	plate.Parent = bb
	for _, side in { "CapL", "CapR" } do
		local cap = Instance.new("ImageLabel")
		cap.Name = side
		cap.BackgroundTransparency = 1
		cap.Size = UDim2.new(0, 18, 1, 0)
		cap.Parent = plate
	end
	local pointer = Instance.new("Frame")
	pointer.Name = "Pointer"
	pointer.AnchorPoint = Vector2.new(0.5, 0.5)
	pointer.Position = UDim2.new(0.5, 0, 1, -2)
	pointer.Size = UDim2.fromOffset(22, 22)
	pointer.Rotation = 45
	pointer.BackgroundColor3 = PAPER
	pointer.BorderSizePixel = 0
	pointer.Parent = plate
	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.AnchorPoint = Vector2.new(0, 0.5)
	key.Position = UDim2.new(0, 10, 0.5, 0)
	key.Size = UDim2.fromOffset(52, 52)
	key.BackgroundColor3 = C.ink
	key.BorderSizePixel = 0
	key.FontFace = FONT
	key.Text = keyText()
	key.TextSize = if key.Text == "TAP" then 18 else 32
	key.TextColor3 = C.white
	key.Parent = plate
	label(
		plate,
		"Who",
		UDim2.fromOffset(74, 9),
		UDim2.new(1, -82, 0, 22),
		prompt.ObjectText,
		20,
		Color3.fromHex("4A4A52")
	)
	label(
		plate,
		"Action",
		UDim2.fromOffset(74, 30),
		UDim2.new(1, -82, 0, 36),
		prompt.ActionText,
		34,
		C.ink
	)
	bb.Parent = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	LobbyKit.plate(plate)
	plate.Activated:Connect(function()
		Router.open("Talk", model)
	end)
	UiMotion.popIn(LobbyKit.pop(plate), 0, 0.7)
	return bb
end

local function attach(model: Instance)
	if not model:IsA("Model") or prompts[model] then
		return
	end
	local id = StateValues.get(model, "Talk")
	if typeof(id) ~= "string" or not Lines[id] then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not (root and root:IsA("BasePart")) then
		return
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = PROMPT
	p.ActionText = "Talk"
	local title = StateValues.get(model, "Title")
	p.ObjectText = if typeof(title) == "string" then title else Lines[id].name
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.HoldDuration = 0
	p.MaxActivationDistance = TALK_RANGE
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	local shown: BillboardGui? = nil
	p.PromptShown:Connect(function()
		if shown then
			shown:Destroy()
		end
		shown = card(p, model)
	end)
	p.PromptHidden:Connect(function()
		if shown then
			shown:Destroy()
			shown = nil
		end
	end)
	p.Triggered:Connect(function()
		Router.open("Talk", model)
	end)
	p.Parent = root
	prompts[model] = p
end

local function detach(model: Instance)
	local p = model:IsA("Model") and prompts[model :: Model]
	if p then
		p:Destroy()
		prompts[model :: Model] = nil
	end
end

function NpcTalk.start()
	local g = ui()
	local canvas = child(g, "Canvas") :: GuiObject?
	if g and canvas then
		LobbyKit.page({
			name = "Talk",
			gui = g,
			wash = child(g, "Wash") :: GuiObject?,
			focus = function(): GuiObject?
				return replyButtons[1]
			end,
			onOpen = onOpen,
			onClose = onClose,
		})
	end
	local function track(model: Instance)
		attach(model)
		-- StreamingEnabled: the root part can arrive after the tag
		if model:IsA("Model") and not prompts[model] then
			local conn: RBXScriptConnection? = nil
			conn = model.DescendantAdded:Connect(function(d)
				if d.Name == "HumanoidRootPart" then
					attach(model)
					if prompts[model] and conn then
						conn:Disconnect()
					end
				end
			end)
		end
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(detach)
	for _, m in CollectionService:GetTagged(TAG) do
		track(m)
	end
end

return NpcTalk
