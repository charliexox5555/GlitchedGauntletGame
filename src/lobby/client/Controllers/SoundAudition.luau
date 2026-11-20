--!strict
-- Studio only: an audition board for the lobby UI sounds (vault/02 Art/UI
-- Polish Pass.md → Sounds, round 4). Press F4 in a Studio play test; click a
-- numbered button to hear that sound at the planned volume. Candidates are
-- Roblox's licensed Pro Sound Effects library (creator "ProSoundEffects", no
-- upload needed), picked by role; the current sound is first in each row for
-- comparison. Tell Claude "click 3, tab 2, ..." and Config/UiSounds is set.
-- Never runs outside Studio.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local SoundAudition = {}

type Cand = { id: number, note: string }
type Role = { name: string, volume: number, list: { Cand } }

local CURRENT = 112177281704509 -- the soft tap (Kenney drop_002) everything uses now

local ROLES: { Role } = {
	{
		name = "CLICK (any button)",
		volume = 0.3,
		list = {
			{ id = CURRENT, note = "now: soft tap" },
			{ id = 9119717523, note = "Toggle Button 2" },
			{ id = 9119717529, note = "Toggle Button 1" },
			{ id = 9119727934, note = "Plastic Switch 14" },
			{ id = 9119727796, note = "Plastic Switch 12" },
			{ id = 9117279995, note = "Pen Click 1" },
		},
	},
	{
		name = "HOVER (big items, very quiet)",
		volume = 0.12,
		list = {
			{ id = CURRENT, note = "now: soft tap" },
			{ id = 9120232246, note = "Trackball Mouse 7" },
			{ id = 9120232133, note = "Trackball Mouse 4" },
			{ id = 9120232166, note = "Trackball Mouse 6" },
			{ id = 9114651748, note = "Pulsing Fuzzy 2" },
		},
	},
	{
		name = "CONFIRM (queue a mode)",
		volume = 0.35,
		list = {
			{ id = CURRENT, note = "now: soft tap" },
			{ id = 9126038721, note = "Thuddy select A" },
			{ id = 9126040335, note = "Thuddy select B" },
			{ id = 9126038468, note = "Thuddy select C" },
			{ id = 9126040452, note = "Thuddy select D" },
		},
	},
	{
		name = "BACK / CLOSE",
		volume = 0.3,
		list = {
			{ id = CURRENT, note = "now: soft tap" },
			{ id = 9119703221, note = "Soft swish 14" },
			{ id = 9120708588, note = "Dull whoosh 1" },
			{ id = 9126041965, note = "Thuddy, buzzy A" },
			{ id = 9126041441, note = "Thuddy, buzzy B" },
			{ id = 9119727950, note = "Plastic Switch 15" },
		},
	},
	{
		name = "TAB SWITCH",
		volume = 0.25,
		list = {
			{ id = CURRENT, note = "now: soft tap" },
			{ id = 9119705099, note = "Paddle swish 10" },
			{ id = 9119704482, note = "Paddle swish 1" },
			{ id = 9119702705, note = "Soft swish 1" },
			{ id = 9119703087, note = "Soft swish 10" },
			{ id = 9120130564, note = "Synth switch 17" },
		},
	},
	{
		name = "TOGGLE ON / OFF",
		volume = 0.3,
		list = {
			{ id = CURRENT, note = "now: soft tap" },
			{ id = 9119717523, note = "Toggle Button 2 (on)" },
			{ id = 9119717529, note = "Toggle Button 1 (off)" },
			{ id = 9119727934, note = "Plastic 14 (on)" },
			{ id = 9119727796, note = "Plastic 12 (off)" },
			{ id = 9117028600, note = "Moviola sharp 8" },
		},
	},
	{
		name = "ERROR / SOON",
		volume = 0.3,
		list = {
			{ id = 15675075163, note = "now: Roblox Delete" },
			{ id = 9114646885, note = "Fuzzy burst 11" },
			{ id = 9114646693, note = "Fuzzy burst 8" },
			{ id = 9114646415, note = "Fuzzy burst 2" },
			{ id = 9126042142, note = "Thuddy, buzzy C" },
		},
	},
	{
		name = "PAGE OPEN (soft whoosh)",
		volume = 0.25,
		list = {
			{ id = 15674975792, note = "now: Roblox Whoosh 03" },
			{ id = 9126014226, note = "Very soft swish A" },
			{ id = 9126014267, note = "Very soft swish B" },
			{ id = 9119702970, note = "Soft swish 8" },
			{ id = 9120709480, note = "Dull whoosh A" },
			{ id = 9120708843, note = "Dull whoosh 3" },
		},
	},
	{
		name = "MATCH FOUND (positive)",
		volume = 0.4,
		list = {
			{ id = 15675043410, note = "now: Roblox Stinger" },
			{ id = 9126132982, note = "Soft beeps 8" },
			{ id = 9126134197, note = "Soft beeps 10" },
			{ id = 9126134338, note = "Soft beeps 4" },
			{ id = 9126134526, note = "Soft beeps 9" },
		},
	},
}

local gui: ScreenGui? = nil
local player: Sound? = nil

local function play(id: number, volume: number)
	local s = player
	if not s then
		local made = Instance.new("Sound")
		made.Name = "AuditionSound"
		made.Parent = SoundService
		s = made
		player = made
	end
	local snd = s :: Sound
	snd:Stop()
	snd.SoundId = "rbxassetid://" .. tostring(id)
	snd.Volume = volume
	snd.TimePosition = 0
	snd:Play()
end

local function build(): ScreenGui
	local g = Instance.new("ScreenGui")
	g.Name = "DevSoundAudition"
	g.ResetOnSpawn = false
	g.DisplayOrder = 200
	g.Enabled = false
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(1180, 44 * #ROLES + 70)
	panel.BackgroundColor3 = Color3.fromHex("1C1C21")
	panel.BorderSizePixel = 0
	panel.Parent = g
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 8)
	title.Size = UDim2.new(1, -32, 0, 40)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text =
		"UI SOUND AUDITION (Studio only, F4 hides). Click to hear; tell Claude e.g. CLICK 3, TAB 2."
	title.Parent = panel
	for r, role in ROLES do
		local y = 54 + (r - 1) * 44
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(16, y)
		label.Size = UDim2.fromOffset(220, 36)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 14
		label.TextColor3 = Color3.fromHex("B8B8BB")
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = role.name
		label.Parent = panel
		for i, c in role.list do
			local b = Instance.new("TextButton")
			b.Name = "Cand"
			b:SetAttribute("UiSound", "none") -- the board itself makes no UI clicks
			b.AutoButtonColor = true
			b.Position = UDim2.fromOffset(240 + (i - 1) * 154, y)
			b.Size = UDim2.fromOffset(148, 36)
			b.BackgroundColor3 = if i == 1
				then Color3.fromHex("3A3A42")
				else Color3.fromHex("2A2A31")
			b.BorderSizePixel = 0
			b.Font = Enum.Font.Gotham
			b.TextSize = 12
			b.TextColor3 = Color3.new(1, 1, 1)
			b.TextWrapped = true
			b.Text = string.format("%d. %s", i, c.note)
			b.Parent = panel
			b.Activated:Connect(function()
				play(c.id, role.volume)
			end)
		end
	end
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return g
end

function SoundAudition.start()
	if not RunService:IsStudio() then
		return
	end
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or input.KeyCode ~= Enum.KeyCode.F4 then
			return
		end
		local g = gui or build()
		gui = g
		g.Enabled = not g.Enabled
	end)
end

return SoundAudition
