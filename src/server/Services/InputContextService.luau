--!strict
-- Builds the Input Action System context from Config/Input and gives every
-- player their own copy under the Player. Server Authority needs contexts
-- owned by a Player so that the inputs reach the server simulation (and are
-- replayed when the client resimulates).
--
-- Keybinds (Settings → KEYBINDS): an action with a `setting` row takes the
-- player's saved { keyboard, alt, controller } keys instead of Config/Input's.
-- The values come from the player's published "Settings" StringValue (Lobby
-- SettingsService, also running in match servers), already cleaned by
-- Shared/PlayerSettings (key names from Enum.KeyCode only); they're applied
-- here again whenever it changes. The client reads the bindings back for its
-- key hints (Shared/InputGlyphs).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bindings = require(ReplicatedStorage.Shared.Config.Input)
local PlayerSettings = require(ReplicatedStorage.Shared.PlayerSettings)
local Settings = require(ReplicatedStorage.Shared.Config.Settings)

local InputContextService = {}

local KEYBIND_ATTRIBUTE = "Keybind" -- marks the bindings this service made

local template: InputContext? = nil

local function addBinding(action: InputAction, key: Enum.KeyCode)
	local binding = Instance.new("InputBinding")
	binding.Name = key.Name
	binding.KeyCode = key
	binding:SetAttribute(KEYBIND_ATTRIBUTE, true)
	binding.Parent = action
end

local function build(): InputContext
	local ctx = Instance.new("InputContext")
	ctx.Name = "PlayContext"
	for name, b in Bindings do
		local action = Instance.new("InputAction")
		action.Name = name
		action.Type = if b.kind == "Direction1D"
			then Enum.InputActionType.Direction1D
			else Enum.InputActionType.Bool
		for _, key in b.keys do
			addBinding(action, key)
		end
		for _, key in b.gamepad do
			addBinding(action, key)
		end
		action.Parent = ctx
		if b.toggle then
			-- TOGGLE rows: the keys move here while the row is on
			local t = Instance.new("InputAction")
			t.Name = name .. "Toggle"
			t.Type = Enum.InputActionType.Bool
			t.Parent = ctx
		end
	end
	return ctx
end

-- A saved key name to a KeyCode ("" and unknown names give nil).
local function code(name: unknown): Enum.KeyCode?
	if typeof(name) ~= "string" or name == "" then
		return nil
	end
	local ok, found = pcall(function()
		return (Enum.KeyCode :: any)[name]
	end)
	return if ok and typeof(found) == "EnumItem" then found :: Enum.KeyCode else nil
end

-- The keys an action uses for this player: their saved row, else Config/Input.
local function keysFor(b: Bindings.Binding, values: PlayerSettings.Values?): { Enum.KeyCode }
	local saved = if values and b.setting then values[b.setting] else nil
	if typeof(saved) ~= "table" then
		local list = table.clone(b.keys)
		for _, k in b.gamepad do
			table.insert(list, k)
		end
		return list
	end
	local list: { Enum.KeyCode } = {}
	for i = 1, 3 do
		local k = code(saved[i])
		if k and not table.find(list, k) then
			table.insert(list, k)
		end
	end
	return list
end

-- Gives `action` exactly the keys `want` (the bindings this service made).
local function setKeys(action: InputAction, want: { Enum.KeyCode })
	local have: { Enum.KeyCode } = {}
	for _, c in action:GetChildren() do
		if c:IsA("InputBinding") and c:GetAttribute(KEYBIND_ATTRIBUTE) then
			table.insert(have, c.KeyCode)
		end
	end
	local same = #have == #want
	for _, k in want do
		same = same and table.find(have, k) ~= nil
	end
	if same then
		return
	end
	for _, c in action:GetChildren() do
		if c:IsA("InputBinding") and c:GetAttribute(KEYBIND_ATTRIBUTE) then
			c:Destroy()
		end
	end
	for _, k in want do
		addBinding(action, k)
	end
end

local function applyKeybinds(player: Player)
	local ctx = player:FindFirstChild("PlayContext")
	local replica = player:FindFirstChild(Settings.REPLICA)
	if not ctx or not (replica and replica:IsA("StringValue")) or replica.Value == "" then
		return
	end
	local values = PlayerSettings.decode(replica.Value)
	if not values then
		return
	end
	for name, b in Bindings do
		local action = ctx:FindFirstChild(name)
		if b.setting and action and action:IsA("InputAction") then
			local want = keysFor(b, values)
			-- TOGGLE AIM / CROUCH / SPRINT on: the keys drive the toggle action
			-- (the client flips this one, Controllers/InputController).
			local toggle = if b.toggle then ctx:FindFirstChild(name .. "Toggle") else nil
			if toggle and toggle:IsA("InputAction") then
				local toggled = values[b.toggle] == true
				setKeys(action, if toggled then {} else want)
				setKeys(toggle, if toggled then want else {})
			else
				setKeys(action, want)
			end
		end
	end
end

local function watchSettings(player: Player)
	local function hook(v: Instance)
		if v.Name == Settings.REPLICA and v:IsA("StringValue") then
			v.Changed:Connect(function()
				applyKeybinds(player)
			end)
			applyKeybinds(player)
		end
	end
	player.ChildAdded:Connect(hook)
	local existing = player:FindFirstChild(Settings.REPLICA)
	if existing then
		hook(existing)
	end
end

local function give(player: Player)
	if template and not player:FindFirstChild("PlayContext") then
		template:Clone().Parent = player
		watchSettings(player)
	end
end

function InputContextService.init()
	template = build()
end

function InputContextService.start()
	Players.PlayerAdded:Connect(give)
	for _, player in Players:GetPlayers() do
		give(player)
	end
end

return InputContextService
