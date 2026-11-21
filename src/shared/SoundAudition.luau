--!strict
-- Studio only: one audition board for every UI and event sound, in the lobby
-- AND the match (vault/02 Art/UI Polish Pass.md → Game-wide sound board).
-- Press F4 in a Studio play test. Tabs: SHARED (the theme both places use:
-- a pick here changes the lobby and the match), HITS
-- (hit marker, headshot, kill, damage; played after a rifle shot by default,
-- since hit sounds are judged in a fight), CUTSCENE (match only: the win
-- cutscene's sound accents, each heard on the song). Button 1 in each row is the
-- current sound; the others are level-matched to it by measured
-- PlaybackLoudness. Tell Claude e.g. "LOCK IN 3, KILL 1". Nothing here runs
-- outside Studio. Candidates: Roblox's licensed Pro Sound Effects library,
-- Roblox's own UI packs, APM Music, and our own hit takes (no user uploads).

local Players = game:GetService("Players")
local StateValues = require(script.Parent.StateValues)
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local SoundAudition = {}

type Layer = { id: number, vol: number, delay: number, pitch: number, from: number?, len: number? }
-- one sound (id + vol), or layers played together (a designed sound: a thump
-- under a tink, etc.; if picked, it gets baked into one asset)
type Cand = { note: string, id: number?, vol: number?, layers: { Layer }?, preview: boolean? }
type Row = { section: string, name: string, list: { Cand } }

local SHOT_ID = 128240759324250 -- the Vandal's first shot take (gun_semi_auto_rifle_shot_01)
local HIT_DELAY = 0.05 -- Config/Audio.HIT_DELAY: hits land just after the shot
local BODY_ID, BODY_VOL = 125235091454234, 0.8 -- the headshot plays on top of this

local SECTIONS = { "SHARED", "HITS" } -- MATCH rows all picked (2026-11-20)
local PER_LINE = 5 -- buttons per line; longer rows wrap

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
		name = "PURCHASE DENIED (not enough coins)",
		list = {
			{
				note = "now: Negative + low buzz",
				layers = {
					{ id = 17208353912, vol = 0.17, delay = 0, pitch = 1 },
					{ id = 9126041965, vol = 0.07, delay = 0, pitch = 1 },
				},
			},
			{ id = 17208353912, vol = 0.17, note = "Roblox GUI Negative" },
			{ id = 9126041965, vol = 0.142, note = "PSE Thuddy buzzy A" },
			{ id = 15675075163, vol = 0.315, note = "Roblox Delete (the SOON sound)" },
			{ id = 10066926605, vol = 1.027, note = "RBLX UI Delete" },
			{
				note = "Delete + low buzz",
				layers = {
					{ id = 15675075163, vol = 0.3, delay = 0, pitch = 1 },
					{ id = 9126041965, vol = 0.07, delay = 0, pitch = 1 },
				},
			},
		},
	},
	-- CASE (lobby, 2026-11-20): the in-world case opening (Config/CaseOpening). Lands,
	-- latches, shake, lid burst, Common / Rare / Epic reveals and Collect are picked
	-- (owner 2026-11-20).
	-- Volumes are the config's; button 1 is what the opening plays now.
	{
		section = "CASE",
		name = "REVEAL: LEGENDARY (bigger than Epic)",
		list = {
			{
				note = "now: APM Hustler Sting 2 (4.4 s, sports brass) + boom",
				layers = {
					{ id = 9047100306, vol = 0.4, delay = 0, pitch = 1 },
					{ id = 9113433423, vol = 0.5, delay = 0, pitch = 0.85 },
				},
			},
			{
				note = "APM Move to the Finish Line b (4.6 s, bold brass) + boom",
				layers = {
					{ id = 9043512647, vol = 0.4, delay = 0, pitch = 1 },
					{ id = 9113433423, vol = 0.5, delay = 0, pitch = 0.85 },
				},
			},
			{
				note = "APM 1812 Overture d (4.7 s, rousing) + boom",
				layers = {
					{ id = 9045751388, vol = 0.4, delay = 0, pitch = 1 },
					{ id = 9113433423, vol = 0.5, delay = 0, pitch = 0.85 },
				},
			},
			{
				note = "APM All It Takes Sting 2 (3.5 s) + boom",
				layers = {
					{ id = 9047103106, vol = 0.4, delay = 0, pitch = 1 },
					{ id = 9113433423, vol = 0.5, delay = 0, pitch = 0.85 },
				},
			},
			{
				note = "APM Run Forth b (2.7 s, drums) + boom",
				layers = {
					{ id = 9043511963, vol = 0.4, delay = 0, pitch = 1 },
					{ id = 9113433423, vol = 0.5, delay = 0, pitch = 0.85 },
				},
			},
			{ id = 9043151109, vol = 0.35, note = "Epic now, to compare: Get Up And Go - Hit" },
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
		section = "HITS",
		name = "HEADSHOT (RIVALS / Valorant: thump + tink)",
		list = {
			{
				note = "now: H18 pop",
				layers = { { id = 106431154366392, vol = 0.511, delay = 0, pitch = 1 } },
			},
			{
				note = "PSE Ricochet on plate 3",
				layers = { { id = 9119651814, vol = 1.85, delay = 0.0, pitch = 1.0 } },
			},
			{
				note = "PSE Head hit, metal",
				layers = { { id = 9113500009, vol = 0.959, delay = 0.0, pitch = 1.0 } },
			},
			{
				note = "Punch + ricochet tink",
				layers = {
					{ id = 9117969584, vol = 0.212, delay = 0, pitch = 1 },
					{ id = 9119651814, vol = 1.017, delay = 0, pitch = 1 },
				},
			},
			{
				note = "Deep thud + ricochet tink",
				layers = {
					{ id = 9113225986, vol = 0.251, delay = 0, pitch = 1 },
					{ id = 9119652215, vol = 2.264, delay = 0, pitch = 1 },
				},
			},
			{
				note = "Punch + glass ping",
				layers = {
					{ id = 9117969584, vol = 0.212, delay = 0, pitch = 1 },
					{ id = 9116682109, vol = 0.372, delay = 0, pitch = 1 },
				},
			},
		},
	},
	{
		section = "HITS",
		name = "KILL (a real kill sound, not a pop)",
		list = {
			{
				note = "now: K13 pop",
				layers = { { id = 97850971640091, vol = 0.524, delay = 0, pitch = 1 } },
			},
			{
				note = "Punch + deep boom",
				layers = {
					{ id = 9117969717, vol = 0.292, delay = 0, pitch = 1 },
					{ id = 9125404320, vol = 0.548, delay = 0, pitch = 1 },
				},
			},
			{
				note = "Giant thud + K13",
				layers = {
					{ id = 9113225986, vol = 0.373, delay = 0, pitch = 1 },
					{ id = 97850971640091, vol = 0.367, delay = 0, pitch = 1 },
				},
			},
			{
				note = "PSE Sledgehammer on beam",
				layers = { { id = 9125672726, vol = 0.913, delay = 0.0, pitch = 1.0 } },
			},
			{
				note = "Thud + punch-bass swell",
				layers = {
					{ id = 9113518281, vol = 0.855, delay = 0, pitch = 1 },
					{ id = 9043183024, vol = 0.277, delay = 0, pitch = 1 },
				},
			},
			{
				note = "PSE Deep rock thunk",
				layers = { { id = 9118598279, vol = 0.873, delay = 0.0, pitch = 1.0 } },
			},
			{
				note = "Punch + boom + ricochet",
				layers = {
					{ id = 9117969717, vol = 0.255, delay = 0, pitch = 1 },
					{ id = 9125404320, vol = 0.469, delay = 0, pitch = 1 },
					{ id = 9119652215, vol = 2.643, delay = 0.02, pitch = 1 },
				},
			},
		},
	},
	{
		section = "HITS",
		name = "DAMAGE TAKEN (similar options)",
		list = {
			{
				note = "now: muffled thud (current)",
				layers = { { id = 82753489298942, vol = 0.556, delay = 0, pitch = 1 } },
			},
			{
				note = "PSE Rubber-glove thud",
				layers = { { id = 9113518281, vol = 1.427, delay = 0.0, pitch = 1.0 } },
			},
			{
				note = "PSE Gut hit (glove)",
				layers = { { id = 9113514100, vol = 1.547, delay = 0.0, pitch = 1.0 } },
			},
			{
				note = "PSE Chin hit (rubber glove)",
				layers = { { id = 9113520887, vol = 1.056, delay = 0.0, pitch = 1.0 } },
			},
			{
				note = "PSE Cloth body hit",
				layers = { { id = 9113534108, vol = 2.759, delay = 0.0, pitch = 1.0 } },
			},
		},
	},
}

-- CUTSCENE (match only, 2026-11-20): sound accents under the win cutscene's
-- ending song (Config/WinCutscene cues). Each option plays the song from a
-- moment before its accent with the candidate started early so its measured
-- hit (the loudest point of the file) lands on the accent, the way the
-- cutscene plays it. Option 1 = what the cutscene uses now. Volumes are
-- level-matched to the song by measured PlaybackLoudness (impacts about 0.75
-- of the song's peak, whooshes 0.55, the spin swish 0.45, the final hit 0.85).
local SONG_ID, SONG_VOL = 9042702890, 0.296 -- Config/UiSounds MatchEnd
local LEAD, TAIL = 1.2, 1.6 -- song seconds played before / after the accent
type Accent = {
	name: string,
	t: number,
	list: { { note: string, id: number, vol: number, hit: number } },
}
local ACCENTS: { Accent } = {
	{
		name = "OPEN 0.12 (slam in from the replay)",
		t = 0.12,
		list = {
			{ note = "PSE Whoosh Impact 3", id = 9120729792, vol = 0.261, hit = 0.5 },
			{ note = "PSE Whoosh Impact 4", id = 9120729903, vol = 0.268, hit = 0.52 },
			{ note = "PSE Whoosh Combo 4", id = 9120704057, vol = 0.193, hit = 0.5 },
			{ note = "PSE Thick Swish Hit 3", id = 9120730294, vol = 0.399, hit = 0.37 },
		},
	},
	{
		name = "CUT B 1.48 (front angle slams in)",
		t = 1.48,
		list = {
			{ note = "PSE Whoosh Impact 5", id = 9120729925, vol = 0.238, hit = 0.56 },
			{ note = "PSE Whoosh Combo 3", id = 9120703361, vol = 0.192, hit = 0.8 },
			{ note = "PSE Whoosh Impact 1", id = 9120729732, vol = 0.24, hit = 0.81 },
			{ note = "PSE Thick Swish Hit 1", id = 9120729973, vol = 0.435, hit = 0.31 },
		},
	},
	{
		name = "CUT D 4.02 (wide orbit, gun swings)",
		t = 4.02,
		list = {
			{ note = "PSE Fast Swish By 4", id = 9120716440, vol = 0.234, hit = 0.3 },
			{ note = "PSE Fast Swish By 1", id = 9120718279, vol = 0.273, hit = 0.53 },
			{ note = "PSE Whoosh Combo 6", id = 9120703601, vol = 0.195, hit = 0.93 },
			{ note = "PSE Whoosh Combo 1", id = 9120703366, vol = 0.338, hit = 0.51 },
		},
	},
	{
		name = "SPIN 5.44 (the spin-hop)",
		t = 5.44,
		list = {
			{ note = "PSE Sharp Swish 13", id = 9126013644, vol = 0.262, hit = 0.14 },
			{ note = "PSE Sharp Swish 11", id = 9126013382, vol = 0.273, hit = 0.12 },
			{ note = "PSE Fast Swish By 4", id = 9120716440, vol = 0.19, hit = 0.3 },
			{ note = "APM Reverse Drum Swipe", id = 1837834170, vol = 0.129, hit = 0.14 },
		},
	},
	{
		name = "FINAL 6.14 (drop to the low hero shot)",
		t = 6.14,
		list = {
			{ note = "PSE Deep Hit Boom", id = 9125484367, vol = 0.24, hit = 0.11 },
			{ note = "APM Agents Of Deception Hit", id = 1835354496, vol = 0.297, hit = 0.3 },
			{ note = "APM Tyrant God Big Hits", id = 9045163407, vol = 0.266, hit = 0.32 },
			{ note = "PSE Whoosh Impact 3", id = 9120729792, vol = 0.285, hit = 0.5 },
		},
	},
}
table.insert(ROWS, {
	section = "CUTSCENE",
	name = "WHOLE CUTSCENE (current picks)",
	list = { { note = "play it (preview)", preview = true } },
})
for _, accent in ACCENTS do
	local from = math.max(accent.t - LEAD, 0)
	local list: { Cand } = {}
	for _, c in accent.list do
		local start = (accent.t - from) - c.hit -- when the candidate starts, excerpt time
		table.insert(list, {
			note = c.note,
			layers = {
				{
					id = SONG_ID,
					vol = SONG_VOL,
					delay = 0,
					pitch = 1,
					from = from,
					len = accent.t - from + TAIL,
				},
				{
					id = c.id,
					vol = c.vol,
					delay = math.max(start, 0),
					pitch = 1,
					from = math.max(-start, 0),
				},
			},
		})
	end
	table.insert(list, {
		note = "no accent",
		layers = {
			{
				id = SONG_ID,
				vol = SONG_VOL,
				delay = 0,
				pitch = 1,
				from = from,
				len = accent.t - from + TAIL,
			},
		},
	})
	table.insert(ROWS, { section = "CUTSCENE", name = accent.name, list = list })
end

local gui: ScreenGui? = nil
local afterShot = true

local live: { Sound } = {}

local function stopAll()
	for _, snd in live do
		snd:Destroy()
	end
	table.clear(live)
end

local function play(
	id: number,
	volume: number,
	delay: number?,
	pitch: number?,
	from: number?,
	len: number?
)
	local function go()
		local snd = Instance.new("Sound")
		snd.Name = "Audition"
		snd.SoundId = "rbxassetid://" .. tostring(id)
		snd.Volume = volume
		snd.PlaybackSpeed = pitch or 1
		snd.Parent = SoundService
		table.insert(live, snd)
		snd.Ended:Once(function()
			snd:Destroy()
		end)
		snd.TimePosition = from or 0
		snd:Play()
		if len then
			task.delay(len, function()
				if snd.Parent then
					snd:Destroy()
				end
			end)
		end
	end
	if delay and delay > 0 then
		task.delay(delay, go)
	else
		go()
	end
end

local function layersOf(c: Cand): { Layer }
	if c.layers then
		return c.layers
	end
	return { { id = c.id :: number, vol = c.vol :: number, delay = 0, pitch = 1 } }
end

local function audition(row: Row, c: Cand)
	stopAll()
	local base = 0
	if row.section == "HITS" and afterShot then
		play(SHOT_ID, 1)
		base = HIT_DELAY
		if string.find(row.name, "HEADSHOT", 1, true) then
			play(BODY_ID, BODY_VOL, HIT_DELAY)
		end
	end
	if c.preview then
		-- the whole win cutscene (MatchEndController's Studio preview)
		StateValues.set(workspace, "PreviewWinCutscene", false)
		StateValues.set(workspace, "PreviewWinCutscene", os.clock())
		return
	end
	for _, l in layersOf(c) do
		play(l.id, l.vol, base + l.delay, l.pitch, l.from, l.len)
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
			local lines = math.ceil(#row.list / PER_LINE)
			f.Size = UDim2.new(1, -12, 0, 40 * lines)
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
					UDim2.fromOffset(240 + ((i - 1) % PER_LINE) * 162, 2 + (i - 1) // PER_LINE * 40),
					UDim2.fromOffset(156, 36),
					if i == 1 then "3A3A42" else "2A2A31"
				)
				b.Activated:Connect(function()
					audition(row, c)
				end)
			end
			y += 40 * lines + 4
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
