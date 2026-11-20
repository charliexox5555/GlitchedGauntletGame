--!strict
-- Studio only: an audition board for the lobby UI sounds (vault/02 Art/UI
-- Polish Pass.md → Sounds, round 5). Press F4 in a Studio play test; click a
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

type Cand = { id: number, note: string, vol: number? }
type Role = { name: string, volume: number, list: { Cand } }

-- Round 5 (owner 2026-11-20): Click, Back, Tab, Toggles, Error and Page open
-- are picked and live in Config/UiSounds. These three rows are new. Each
-- candidate has its own volume, level-matched by measured PlaybackLoudness
-- (hover ~20, confirm ~50, match found ~100) so the comparison is fair.
local ROLES: { Role } = {
	{
		name = "HOVER (big items, quiet)",
		volume = 0.7,
		list = {
			{ id = 17208339919, note = "Roblox GUI Hover 01", vol = 0.6 },
			{ id = 17208343514, note = "Roblox GUI Hover 02", vol = 0.67 },
			{ id = 17208348006, note = "Roblox GUI Hover 03", vol = 0.7 },
			{ id = 10066931761, note = "RBLX UI Hover 01", vol = 0.65 },
			{ id = 10066936758, note = "RBLX UI Hover 02", vol = 1.25 },
			{ id = 10066942189, note = "RBLX UI Hover 03", vol = 0.9 },
		},
	},
	{
		name = "CONFIRM (queue a mode)",
		volume = 0.35,
		list = {
			{ id = 9126040335, note = "now: Thuddy select B", vol = 0.36 },
			{ id = 17208396156, note = "Roblox GUI Select", vol = 0.29 },
			{ id = 17208323435, note = "Roblox GUI Equip", vol = 0.32 },
			{ id = 10128760939, note = "RBLX UI Select 01", vol = 1.4 },
			{ id = 10066968815, note = "RBLX UI Select 02", vol = 1.3 },
			{ id = 16480556621, note = "Big plastic button", vol = 0.4 },
			{ id = 9120412125, note = "Game pad button (PSE)", vol = 0.65 },
		},
	},
	{
		name = "MATCH FOUND",
		volume = 0.4,
		list = {
			{ id = 15675043410, note = "now: Roblox stinger", vol = 0.4 },
			{ id = 17208361335, note = "Roblox GUI Notification High", vol = 0.3 },
			{ id = 17208372272, note = "Roblox GUI Notification Low", vol = 0.36 },
			{ id = 9043151109, note = "APM Get Up And Go (hit)", vol = 0.21 },
			{ id = 9045807338, note = "APM Scoundrels (brass + drum)", vol = 0.25 },
			{ id = 1848300577, note = "APM Raunch On (hit)", vol = 0.36 },
			{ id = 9042542887, note = "APM Universal Flip (hit)", vol = 0.23 },
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
	panel.Size = UDim2.fromOffset(1340, 44 * #ROLES + 70)
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
		"UI SOUND AUDITION round 5 (Studio only, F4 hides). Click to hear; tell Claude e.g. HOVER 2 (or none), CONFIRM 4."
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
				play(c.id, c.vol or role.volume)
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
