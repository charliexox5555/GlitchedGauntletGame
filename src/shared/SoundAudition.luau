--!strict
-- Studio only: one audition board for every UI and event sound, in the lobby
-- AND the match (vault/02 Art/UI Polish Pass.md → Game-wide sound board).
-- Press F4 in a Studio play test. Tabs: SHARED (the theme both places use:
-- a pick here changes the lobby and the match), MATCH (match events), HITS
-- (hit marker, headshot, kill, damage; played after a rifle shot by default,
-- since hit sounds are judged in a fight). Button 1 in each row is the
-- current sound; the others are level-matched to it by measured
-- PlaybackLoudness. Tell Claude e.g. "LOCK IN 3, KILL 1". Nothing here runs
-- outside Studio. Candidates: Roblox's licensed Pro Sound Effects library,
-- Roblox's own UI packs, APM Music, and our own hit takes (no user uploads).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local SoundAudition = {}

type Cand = { id: number, vol: number, note: string }
type Row = { section: string, name: string, list: { Cand } }

local SHOT_ID = 128240759324250 -- the Vandal's first shot take (gun_semi_auto_rifle_shot_01)
local HIT_DELAY = 0.05 -- Config/Audio.HIT_DELAY: hits land just after the shot
local BODY_ID, BODY_VOL = 125235091454234, 0.8 -- the headshot plays on top of this

local SECTIONS = { "SHARED", "MATCH", "HITS" }

-- Generated from measured loudness (2026-11-20); "vol" is the Sound.Volume
-- that matches the row's current sound (button 1).
local ROWS: { Row } = {
	{
		section = "SHARED",
		name = "CLICK (any button; match: draft pick)",
		list = {
			{ id = 9119717529, vol = 0.3, note = "now: Toggle Button 1" },
			{ id = 9119717523, vol = 0.3, note = "PSE Toggle Button 2" },
			{ id = 9119727934, vol = 0.967, note = "PSE Plastic Switch 14" },
			{ id = 9119727796, vol = 1.436, note = "PSE Plastic Switch 12" },
			{ id = 17208408337, vol = 0.564, note = "Roblox GUI Tab" },
		},
	},
	{
		section = "SHARED",
		name = "HOVER (big items)",
		list = {
			{ id = 17208343514, vol = 0.4, note = "now: Roblox GUI Hover 02" },
			{ id = 17208339919, vol = 0.353, note = "Roblox GUI Hover 01" },
			{ id = 17208348006, vol = 0.414, note = "Roblox GUI Hover 03" },
			{ id = 10066931761, vol = 0.387, note = "RBLX UI Hover 01" },
		},
	},
	{
		section = "SHARED",
		name = "CONFIRM (queue a mode)",
		list = {
			{ id = 17208396156, vol = 0.29, note = "now: Roblox GUI Select" },
			{ id = 17208323435, vol = 0.32, note = "Roblox GUI Equip" },
			{ id = 10128760939, vol = 1.386, note = "RBLX UI Select 01" },
			{ id = 9126040335, vol = 0.359, note = "PSE Thuddy select B" },
		},
	},
	{
		section = "SHARED",
		name = "BACK / CLOSE",
		list = {
			{ id = 9119703221, vol = 0.3, note = "now: PSE Soft swish 14" },
			{ id = 17208186900, vol = 0.101, note = "Roblox GUI Back" },
			{ id = 10066914500, vol = 0.324, note = "RBLX UI Back" },
			{ id = 9120708588, vol = 0.426, note = "PSE Dull whoosh 1" },
		},
	},
	{
		section = "SHARED",
		name = "TAB",
		list = {
			{ id = 9119704482, vol = 0.25, note = "now: PSE Paddle swish 1" },
			{ id = 17208408337, vol = 0.11, note = "Roblox GUI Tab" },
			{ id = 17208405682, vol = 0.14, note = "Roblox GUI Swipe" },
			{ id = 9119705099, vol = 0.043, note = "PSE Paddle swish 10" },
		},
	},
	{
		section = "SHARED",
		name = "TOGGLE (on)",
		list = {
			{ id = 9119717523, vol = 0.3, note = "now: PSE Toggle Button 2" },
			{ id = 9119727934, vol = 0.967, note = "PSE Plastic Switch 14" },
			{ id = 9119717529, vol = 0.3, note = "PSE Toggle Button 1" },
			{ id = 17208408337, vol = 0.564, note = "Roblox GUI Tab" },
		},
	},
	{
		section = "SHARED",
		name = "ERROR / DENIED (lobby SOON, draft not ready)",
		list = {
			{ id = 15675075163, vol = 0.315, note = "now: Roblox Delete" },
			{ id = 17208353912, vol = 0.144, note = "Roblox GUI Negative" },
			{ id = 10066926605, vol = 1.027, note = "RBLX UI Delete" },
			{ id = 9126041965, vol = 0.142, note = "PSE Thuddy buzzy A" },
		},
	},
	{
		section = "SHARED",
		name = "PAGE OPEN (soft whoosh)",
		list = {
			{ id = 15674975792, vol = 0.1, note = "now: Roblox Whoosh 03" },
			{ id = 9126014226, vol = 0.968, note = "PSE Very soft swish A" },
			{ id = 17208405682, vol = 0.323, note = "Roblox GUI Swipe" },
			{ id = 10128766965, vol = 0.687, note = "RBLX UI Swipe" },
		},
	},
	{
		section = "MATCH",
		name = "DRAFT OPENS",
		list = {
			{ id = 15675028888, vol = 0.315, note = "now: Roblox Whoosh 02" },
			{ id = 15675024286, vol = 0.277, note = "Roblox Whoosh 01" },
			{ id = 15675012262, vol = 0.299, note = "Roblox Whoosh 04" },
			{ id = 10128766965, vol = 1.717, note = "RBLX UI Swipe" },
			{ id = 17208405682, vol = 0.807, note = "Roblox GUI Swipe" },
		},
	},
	{
		section = "MATCH",
		name = "CARD IN (each card, very soft)",
		list = {
			{ id = 15674975792, vol = 0.126, note = "now: Roblox Whoosh 03" },
			{ id = 17208405682, vol = 0.407, note = "Roblox GUI Swipe" },
			{ id = 15675037413, vol = 0.202, note = "Roblox Paper Swipe" },
			{ id = 9126014267, vol = 1.917, note = "PSE Very soft swish B" },
		},
	},
	{
		section = "MATCH",
		name = "DRAFT CLOSES",
		list = {
			{ id = 15675046931, vol = 0.28, note = "now: Roblox Sweep" },
			{ id = 15675024286, vol = 0.207, note = "Roblox Whoosh 01" },
			{ id = 9119703221, vol = 1.473, note = "PSE Soft swish 14" },
			{ id = 9120708843, vol = 0.994, note = "PSE Dull whoosh 3" },
		},
	},
	{
		section = "MATCH",
		name = "LOCK IN",
		list = {
			{ id = 15675043410, vol = 0.42, note = "now: Roblox Tonal Stinger" },
			{ id = 17208396156, vol = 0.715, note = "Roblox GUI Select (= CONFIRM)" },
			{ id = 17208323435, vol = 0.789, note = "Roblox GUI Equip" },
			{ id = 17208380755, vol = 0.849, note = "Roblox GUI Purchase" },
			{ id = 10066947742, vol = 2.279, note = "RBLX UI Purchase" },
		},
	},
	{
		section = "MATCH",
		name = "CLOCK TICK (last seconds)",
		list = {
			{ id = 15675085146, vol = 0.28, note = "now: Roblox Indicator" },
			{ id = 9114216120, vol = 1.424, note = "PSE DVD menu click 9" },
			{ id = 17208408337, vol = 0.593, note = "Roblox GUI Tab" },
			{ id = 9113399918, vol = 0.412, note = "PSE Simple beep 4" },
			{ id = 9117060347, vol = 0.804, note = "PSE NASA beep 1" },
		},
	},
	{
		section = "MATCH",
		name = "LAST TICK (on 1)",
		list = {
			{ id = 15675085146, vol = 0.385, note = "now: Roblox Indicator, higher" },
			{ id = 9113399926, vol = 0.692, note = "PSE Simple beep 5" },
			{ id = 9117060368, vol = 1.105, note = "PSE NASA beep 3" },
			{ id = 17208396156, vol = 0.398, note = "Roblox GUI Select" },
		},
	},
	{
		section = "MATCH",
		name = "BANNER (sudden death, match point, draw)",
		list = {
			{ id = 15675012262, vol = 0.315, note = "now: Roblox Whoosh 04" },
			{ id = 17208372272, vol = 0.203, note = "Roblox GUI Notification Low" },
			{ id = 9045808545, vol = 0.149, note = "APM Swagger Ting (sting)" },
			{ id = 9038919815, vol = 0.159, note = "APM Totally Go For It (hit)" },
		},
	},
	{
		section = "MATCH",
		name = "FIGHT (barrier drops)",
		list = {
			{ id = 15675043410, vol = 0.385, note = "now: Roblox Tonal Stinger, higher" },
			{ id = 1848300577, vol = 0.412, note = "APM Raunch On (hit)" },
			{ id = 9045807338, vol = 0.281, note = "APM Scoundrels (brass + drum)" },
			{ id = 9043151109, vol = 0.235, note = "APM Get Up And Go (hit)" },
			{ id = 17208361335, vol = 0.341, note = "Roblox GUI Notification High" },
		},
	},
	{
		section = "MATCH",
		name = "ROUND WON",
		list = {
			{ id = 15675043410, vol = 0.42, note = "now: Roblox Tonal Stinger, brighter" },
			{ id = 17208361335, vol = 0.372, note = "Roblox GUI Notification High" },
			{ id = 9042542887, vol = 0.284, note = "APM Universal Flip (= match found)" },
			{ id = 1844442553, vol = 0.519, note = "APM Winner - Bingo" },
		},
	},
	{
		section = "MATCH",
		name = "ROUND LOST",
		list = {
			{ id = 15675062723, vol = 0.35, note = "now: Roblox Whistle Low" },
			{ id = 17208372272, vol = 0.399, note = "Roblox GUI Notification Low" },
			{ id = 17208214688, vol = 0.438, note = "Roblox GUI Call Decline" },
			{ id = 1844442622, vol = 0.356, note = "APM Loser - Sorry" },
		},
	},
	{
		section = "MATCH",
		name = "VICTORY",
		list = {
			{ id = 1837945707, vol = 0.35, note = "now: APM Strategic Victory" },
			{ id = 133000497392138, vol = 0.223, note = "APM Kinetic Victory" },
			{ id = 1842331985, vol = 0.56, note = "APM March to Victory (b)" },
			{ id = 9041815642, vol = 0.658, note = "APM Rise Of Champions" },
			{ id = 1846942308, vol = 0.227, note = "APM Winner Sting Four" },
		},
	},
	{
		section = "MATCH",
		name = "DEFEAT",
		list = {
			{ id = 15675062723, vol = 0.35, note = "now: Roblox Whistle Low" },
			{ id = 1839857692, vol = 0.361, note = "APM Loser (f)" },
			{ id = 1846251702, vol = 0.452, note = "APM Fortune Fun Lose" },
			{ id = 1839846554, vol = 0.347, note = "APM Loser Sting 1" },
			{ id = 17208372272, vol = 0.399, note = "Roblox GUI Notification Low" },
		},
	},
	{
		section = "MATCH",
		name = "ZONE WARNING (outside the circle)",
		list = {
			{ id = 15675085146, vol = 0.35, note = "now: Roblox Indicator, low" },
			{ id = 9117060548, vol = 1.005, note = "PSE NASA beep 4" },
			{ id = 9113400139, vol = 0.831, note = "PSE Simple beep 8" },
			{ id = 17208353912, vol = 0.38, note = "Roblox GUI Negative" },
		},
	},
	{
		section = "MATCH",
		name = "SCORE (your team's point)",
		list = {
			{ id = 15675055424, vol = 0.28, note = "now: Roblox Cute Pop, lower" },
			{ id = 17208319162, vol = 0.672, note = "Roblox GUI Pickup" },
			{ id = 17208323435, vol = 0.495, note = "Roblox GUI Equip" },
			{ id = 17208396156, vol = 0.449, note = "Roblox GUI Select" },
		},
	},
	{
		section = "MATCH",
		name = "MOD READY",
		list = {
			{ id = 9126076030, vol = 0.35, note = "now: PSE ready chime" },
			{ id = 17208323435, vol = 0.298, note = "Roblox GUI Equip" },
			{ id = 17208319162, vol = 0.405, note = "Roblox GUI Pickup" },
			{ id = 9126134338, vol = 0.656, note = "PSE Soft beeps 4" },
		},
	},
	{
		section = "MATCH",
		name = "MOD DENIED",
		list = {
			{ id = 17208353912, vol = 0.4, note = "now: Roblox GUI Negative" },
			{ id = 15675075163, vol = 0.875, note = "Roblox Delete (= ERROR)" },
			{ id = 9126041965, vol = 0.395, note = "PSE Thuddy buzzy A" },
		},
	},
	{
		section = "MATCH",
		name = "MOD CANCEL",
		list = {
			{ id = 15675032796, vol = 0.35, note = "now: Roblox Small Click" },
			{ id = 9119703221, vol = 0.596, note = "PSE Soft swish 14 (= BACK)" },
			{ id = 9119717529, vol = 0.102, note = "PSE Toggle Button 1 (= CLICK)" },
		},
	},
	{
		section = "HITS",
		name = "BODY HIT (every hit)",
		list = {
			{ id = 125235091454234, vol = 0.8, note = "now: hitmarker_2" },
			{ id = 9119717529, vol = 2.324, note = "PSE Toggle Button 1 (= CLICK)" },
			{ id = 9117969584, vol = 0.74, note = "PSE Beefy punch 1" },
			{ id = 9113263454, vol = 0.724, note = "PSE Balloon pop 1" },
		},
	},
	{
		section = "HITS",
		name = "HEADSHOT (on top of the hit)",
		list = {
			{ id = 106431154366392, vol = 0.511, note = "now: H18 pop" },
			{ id = 9113263454, vol = 0.259, note = "PSE Balloon pop 1" },
			{ id = 17208204604, vol = 1.238, note = "Roblox GUI Bubble" },
			{ id = 9117848644, vol = 0.385, note = "PSE Mouth pop 7" },
		},
	},
	{
		section = "HITS",
		name = "KILL",
		list = {
			{ id = 97850971640091, vol = 0.524, note = "now: K13 pop" },
			{ id = 9119669065, vol = 1.305, note = "PSE Suction pop 4" },
			{ id = 9113537815, vol = 0.612, note = "PSE Hollow pop blip" },
			{ id = 17208204604, vol = 2.068, note = "Roblox GUI Bubble" },
			{ id = 80157615235710, vol = 0.513, note = "kill C (older warm pop)" },
		},
	},
	{
		section = "HITS",
		name = "DAMAGE TAKEN",
		list = {
			{ id = 82753489298942, vol = 0.556, note = "now: muffled thud" },
			{ id = 9117969584, vol = 0.59, note = "PSE Beefy punch 1" },
			{ id = 9117969420, vol = 0.999, note = "PSE Punching bag thud" },
			{ id = 9117969717, vol = 0.487, note = "PSE Beefy punch 3" },
		},
	},
}

local gui: ScreenGui? = nil
local voices: { [string]: Sound } = {}
local afterShot = true

local function play(slot: string, id: number, volume: number, delay: number?)
	local s = voices[slot]
	if not s then
		local made = Instance.new("Sound")
		made.Name = "Audition" .. slot
		made.Parent = SoundService
		voices[slot] = made
		s = made
	end
	local snd = s :: Sound
	local function go()
		snd:Stop()
		snd.SoundId = "rbxassetid://" .. tostring(id)
		snd.Volume = volume
		snd.TimePosition = 0
		snd:Play()
	end
	if delay and delay > 0 then
		task.delay(delay, go)
	else
		go()
	end
end

local function audition(row: Row, c: Cand)
	if row.section == "HITS" and afterShot then
		play("shot", SHOT_ID, 1)
		if string.find(row.name, "HEADSHOT", 1, true) then
			play("body", BODY_ID, BODY_VOL, HIT_DELAY)
		end
		play("cand", c.id, c.vol, HIT_DELAY)
	else
		play("cand", c.id, c.vol)
	end
end

local function label(
	parent: Instance,
	text: string,
	pos: UDim2,
	size: UDim2,
	colour: Color3
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Font = Enum.Font.GothamBold
	l.TextSize = 13
	l.TextColor3 = colour
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = text
	l.Parent = parent
	return l
end

local function button(
	parent: Instance,
	text: string,
	pos: UDim2,
	size: UDim2,
	colour: string
): TextButton
	local b = Instance.new("TextButton")
	b:SetAttribute("UiSound", "none") -- the board makes no UI clicks of its own
	b:SetAttribute("UiHover", false)
	b.AutoButtonColor = true
	b.Position = pos
	b.Size = size
	b.BackgroundColor3 = Color3.fromHex(colour)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.Gotham
	b.TextSize = 12
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextWrapped = true
	b.Text = text
	b.Parent = parent
	return b
end

local function build(sections: { string }): ScreenGui
	local g = Instance.new("ScreenGui")
	g.Name = "DevSoundAudition"
	g.ResetOnSpawn = false
	g.DisplayOrder = 200
	g.IgnoreGuiInset = true
	g.Enabled = false
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0, 1070, 0.86, 0)
	panel.BackgroundColor3 = Color3.fromHex("1C1C21")
	panel.BorderSizePixel = 0
	panel.Parent = g
	-- a modal button frees the mouse while the board is open (the match
	-- locks it to the crosshair)
	local modal = Instance.new("TextButton")
	modal:SetAttribute("UiSound", "none")
	modal.Modal = true
	modal.BackgroundTransparency = 1
	modal.Text = ""
	modal.Size = UDim2.fromOffset(0, 0)
	modal.Parent = panel
	label(
		panel,
		"SOUND AUDITION (Studio only, F4 hides). Button 1 = current. Tell Claude e.g. LOCK IN 3, KILL 1.",
		UDim2.fromOffset(16, 8),
		UDim2.new(1, -32, 0, 22),
		Color3.new(1, 1, 1)
	)
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(0, 76)
	list.Size = UDim2.new(1, 0, 1, -84)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 8
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local tabs: { [string]: TextButton } = {}
	local shotToggle =
		button(panel, "", UDim2.new(1, -236, 0, 36), UDim2.fromOffset(220, 32), "2A2A31")
	local function paintShot()
		shotToggle.Text = if afterShot then "AFTER A RIFLE SHOT: ON" else "AFTER A RIFLE SHOT: OFF"
	end
	paintShot()
	shotToggle.Activated:Connect(function()
		afterShot = not afterShot
		paintShot()
	end)
	local function show(section: string)
		for _, c in list:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		for name, t in tabs do
			t.BackgroundColor3 = Color3.fromHex(if name == section then "4A4A55" else "2A2A31")
		end
		shotToggle.Visible = section == "HITS"
		local y = 0
		for _, row in ROWS do
			if row.section ~= section then
				continue
			end
			local f = Instance.new("Frame")
			f.BackgroundTransparency = 1
			f.Position = UDim2.fromOffset(0, y)
			f.Size = UDim2.new(1, -12, 0, 40)
			f.Parent = list
			label(
				f,
				row.name,
				UDim2.fromOffset(16, 2),
				UDim2.fromOffset(220, 36),
				Color3.fromHex("B8B8BB")
			)
			for i, c in row.list do
				local b = button(
					f,
					string.format("%d. %s", i, c.note),
					UDim2.fromOffset(240 + (i - 1) * 162, 2),
					UDim2.fromOffset(156, 36),
					if i == 1 then "3A3A42" else "2A2A31"
				)
				b.Activated:Connect(function()
					audition(row, c)
				end)
			end
			y += 44
		end
	end
	for i, name in sections do
		local t = button(
			panel,
			name,
			UDim2.fromOffset(16 + (i - 1) * 128, 36),
			UDim2.fromOffset(120, 32),
			"2A2A31"
		)
		t.Font = Enum.Font.GothamBold
		tabs[name] = t
		t.Activated:Connect(function()
			show(name)
		end)
	end
	show(sections[1])
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return g
end

-- sections: which tabs this place shows (default all three).
function SoundAudition.start(sections: { string }?)
	if not RunService:IsStudio() then
		return
	end
	local use = sections or SECTIONS
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or input.KeyCode ~= Enum.KeyCode.F4 then
			return
		end
		local g = gui or build(use)
		gui = g
		g.Enabled = not g.Enabled
	end)
end

return SoundAudition
