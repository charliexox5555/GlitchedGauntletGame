--!strict
-- Loading screen sound audition (2026-11-25, PowerDuels reveal; vault/02 Art/PowerDuels Logo.md → Sound audition).
-- Hears each candidate over the REAL reveal: it sets Studio-only Workspace attributes that
-- src/first/LoadingScreen.client.luau reads (LoadingAuditionSting / Bed / Whoosh / …Volume / Hold), then replays a
-- copy of ReplicatedFirst.Loading on this client. Licensed Roblox partner audio only (APMOfficial music,
-- ProSoundEffects).
--
-- How: press Play in Studio, switch the command bar to the CLIENT, set PASS (and ONLY to repeat one), paste, Enter.
-- The Output prints "[Audition] STING 3/8 ..." as each one plays. Pick numbers; the picks go in Config/Loading
-- (sting / whoosh / bed). Attributes are cleared at the end.
--   PASS = "stings": each sting on POWER's landing, over the current bed.
--   PASS = "whoosh": the current sting with each whoosh under POWER's swing (W0 = none).
--   PASS = "beds":   each bed under the reveal, held 9 s so it can be judged.
--   PASS = "combo":  one full combination (COMBO), held 9 s.

local PASS = "stings"
local ONLY: number? = nil -- e.g. 3 replays only the third candidate of the pass
local COMBO = { sting = 1, whoosh = 1, bed = 1 }

type Candidate = { name: string, id: string, volume: number }

local STINGS: { Candidate } = {
	{ name = "Outrunning - Hit (current)", id = "rbxassetid://9047207931", volume = 0.6 },
	{ name = "There's No Stopping Us - Tag3", id = "rbxassetid://9042539652", volume = 0.55 },
	{ name = "There's No Stopping Us - Tag1", id = "rbxassetid://9042539411", volume = 0.55 },
	{ name = "There's No Stopping Us - Tag5", id = "rbxassetid://9042539884", volume = 0.55 },
	{ name = "Automata Sting 2", id = "rbxassetid://9047064962", volume = 0.55 },
	{ name = "Mech Madness Stinger 1", id = "rbxassetid://127087932061391", volume = 0.55 },
	{ name = "Totally Go For It - Hit4", id = "rbxassetid://9038919815", volume = 0.6 },
	{ name = "Spinning Around (b)", id = "rbxassetid://1839881844", volume = 0.55 },
}

local WHOOSHES: { Candidate } = {
	{ name = "none", id = "none", volume = 0 },
	{ name = "Whoosh Fast Swish By 3 (PSE)", id = "rbxassetid://9120714219", volume = 0.35 },
	{ name = "Whoosh Fast Swish By 1 (PSE)", id = "rbxassetid://9120710054", volume = 0.35 },
	{ name = "Searing Bursts 15 (PSE)", id = "rbxassetid://9118883081", volume = 0.3 },
}

local BEDS: { Candidate } = {
	{ name = "Beginnings (current)", id = "rbxassetid://9042293789", volume = 0.18 },
	{
		name = "There's No Stopping Us - Alt2, DrumsBass",
		id = "rbxassetid://9042539083",
		volume = 0.16,
	},
	{
		name = "There's No Stopping Us - Alt1, NoLead",
		id = "rbxassetid://9042539080",
		volume = 0.16,
	},
	{ name = "Night Driver (a 30)", id = "rbxassetid://1842054459", volume = 0.16 },
	{ name = "Round About Now (no percussion)", id = "rbxassetid://9042294497", volume = 0.18 },
}

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")

assert(
	RunService:IsStudio() and RunService:IsClient(),
	"Run this in the CLIENT command bar during Play"
)
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ATTRS = { "Sting", "StingVolume", "Bed", "BedVolume", "Whoosh", "WhooshVolume", "Hold" }

local function set(kind: string, c: Candidate?)
	workspace:SetAttribute("LoadingAudition" .. kind, if c then c.id else nil)
	workspace:SetAttribute("LoadingAudition" .. kind .. "Volume", if c then c.volume else nil)
end

local function clear()
	for _, name in ATTRS do
		workspace:SetAttribute("LoadingAudition" .. name, nil)
	end
end

-- One replay of the real loading script with the attributes as set; returns once its screen has closed.
local function replay(label: string)
	print("[Audition] " .. label)
	local copy = ReplicatedFirst:WaitForChild("Loading"):Clone()
	copy.Name = "__LoadingAudition"
	copy.Parent = playerGui
	local started = os.clock()
	repeat
		task.wait(0.1)
	until not playerGui:FindFirstChild("DuelsLoading") and os.clock() - started > 1
		or os.clock() - started > 30
	task.wait(1.2)
	copy:Destroy()
end

local function run(list: { Candidate }, kind: string, each: (Candidate) -> ())
	for i, c in list do
		if ONLY == nil or ONLY == i then
			each(c)
			replay(string.format("%s %d/%d: %s  (%s)", string.upper(kind), i, #list, c.name, c.id))
		end
	end
end

clear()
if PASS == "stings" then
	run(STINGS, "sting", function(c)
		set("Sting", c)
	end)
elseif PASS == "whoosh" then
	run(WHOOSHES, "whoosh", function(c)
		set("Whoosh", c)
	end)
elseif PASS == "beds" then
	workspace:SetAttribute("LoadingAuditionHold", 9)
	run(BEDS, "bed", function(c)
		set("Bed", c)
	end)
elseif PASS == "combo" then
	set("Sting", STINGS[COMBO.sting])
	set("Whoosh", WHOOSHES[COMBO.whoosh])
	set("Bed", BEDS[COMBO.bed])
	workspace:SetAttribute("LoadingAuditionHold", 9)
	replay(
		string.format(
			"COMBO: sting %d %s, whoosh %d %s, bed %d %s",
			COMBO.sting,
			STINGS[COMBO.sting].name,
			COMBO.whoosh,
			WHOOSHES[COMBO.whoosh].name,
			COMBO.bed,
			BEDS[COMBO.bed].name
		)
	)
end
clear()
print("[Audition] done (" .. PASS .. ")")
