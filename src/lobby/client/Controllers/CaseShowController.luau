--!strict
-- Other players' case openings (vault/01 Design/Case Opening.md): the server's
-- CaseShow (Services/ShopService) plays the in-world opening at that player,
-- quieter and with their name on the card (Util/CaseOpening). Your own opening is
-- started by the Backpack. Skipped when the opener is far away or has no character.
-- Studio only: the F4 board's CASE tab (Shared/SoundAudition) plays an opening at you
-- through the workspace StateValue "PreviewCaseOpening" (sample skins, nothing bought); a bundle
-- row plays a bought bundle's crates and the Backpack's EQUIP ALL strip (BackpackController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local OpeningConfig = require(ReplicatedStorage.Shared.Config.CaseOpening)
local SkinCases = require(ReplicatedStorage.Shared.SkinCases)
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local CaseOpening = require(script.Parent.Parent.Util.CaseOpening)
local ShopCatalog = require(ReplicatedStorage.Lobby.ShopCatalog)
local BackpackController = require(script.Parent.BackpackController)

local CaseShowController = {}

local PREVIEW_FIELD = "PreviewCaseOpening"
local PREVIEW_ANSWER = 0.35 -- seconds, about a server answer, so the toss plays as it does live

-- Sample results for a preview: `count` random skins of `tier` ("mixed" = any tier),
-- knives only or guns only.
local function sampleResults(tier: string, count: number, knife: boolean): { CaseOpening.Result }
	local pool: { SkinCases.Pair } = {}
	local any: { SkinCases.Pair } = {}
	for _, pair in SkinCases.all() do
		if (pair.gun == "Knife") == knife then
			table.insert(any, pair)
			if tier == "mixed" or pair.tier == tier then
				table.insert(pool, pair)
			end
		end
	end
	if #pool == 0 then
		pool = any
	end
	local out: { CaseOpening.Result } = {}
	local rng = Random.new()
	for _ = 1, count do
		if #pool == 0 then
			break
		end
		local pair = pool[rng:NextInteger(1, #pool)]
		table.insert(out, {
			gun = pair.gun,
			line = pair.line,
			tier = pair.tier,
			name = SkinCases.name(pair.gun, pair.line),
		})
	end
	return out
end

local function bindPreview(me: Player)
	local active: CaseOpening.Handle? = nil
	StateValues.changed(workspace, PREVIEW_FIELD):Connect(function()
		local value = StateValues.get(workspace, PREVIEW_FIELD)
		if typeof(value) ~= "string" then
			return
		end
		local crate, tier, count, kind = string.match(value, "^(%d+)|(%a+)|(%d+)|(%a+)|")
		if not (crate and tier and count and kind) then
			return
		end
		local busy = active
		if busy and not busy:isDead() then
			warn("[CaseShow] preview: wait for the opening to finish")
			return
		end
		if kind == "bundle" then
			-- a bought bundle (nothing bought): its items through the Backpack's own flow
			local bundle = ShopCatalog.bundle(tier)
			local results: { CaseOpening.Result } = {}
			for _, item in if bundle then bundle.items else {} do
				local gun, line = item.gun, item.line
				if gun and line then
					table.insert(results, {
						gun = gun,
						line = line,
						tier = SkinCases.tierOf(gun, line) or "Exclusive",
						name = item.name,
					})
				end
			end
			if not BackpackController.presentOpening(tonumber(crate) or 5, results) then
				warn("[CaseShow] preview: the Backpack isn't ready or an opening is playing")
			end
			return
		end
		local results = sampleResults(tier, tonumber(count) or 1, kind == "knife")
		if #results == 0 then
			warn("[CaseShow] preview: no skins loaded yet")
			return
		end
		local h = CaseOpening.start(me, tonumber(crate) or 1, true, #results)
		active = h
		if h then
			local handle: CaseOpening.Handle = h
			task.delay(PREVIEW_ANSWER, function()
				handle:reveal(results)
			end)
		end
	end)
end

function CaseShowController.start()
	local me = Players.LocalPlayer
	if RunService:IsStudio() then
		bindPreview(me)
	end
	local shows: { [Player]: CaseOpening.Handle } = setmetatable({}, { __mode = "k" }) :: any
	LobbyNet.event("CaseShow").OnClientEvent:Connect(function(p: LobbyNet.CaseShowPayload)
		if typeof(p) ~= "table" or typeof(p.userId) ~= "number" or p.userId == me.UserId then
			return
		end
		-- a case (1 or a batch) or a bought bundle (one crate per item, up to MAX_CRATES)
		if
			typeof(p.count) ~= "number"
			or p.count < 1
			or p.count > OpeningConfig.MAX_CRATES
			or typeof(p.results) ~= "table"
			or #p.results == 0
		then
			return
		end
		local owner = Players:GetPlayerByUserId(p.userId)
		local theirs = owner and owner.Character
		local mine = me.Character
		local a = theirs and theirs:FindFirstChild("HumanoidRootPart")
		local b = mine and mine:FindFirstChild("HumanoidRootPart")
		if not (owner and a and a:IsA("BasePart")) then
			return
		end
		if
			b
			and b:IsA("BasePart")
			and (a.Position - b.Position).Magnitude > OpeningConfig.VIEW_DISTANCE
		then
			return
		end
		-- at most MAX_ONLOOKER_SHOWS at once, one per player (the nearest come first: the rest just aren't shown)
		local live = 0
		for who, handle in shows do
			if handle:isDead() then
				shows[who] = nil
			else
				live += 1
			end
		end
		if shows[owner] or live >= OpeningConfig.MAX_ONLOOKER_SHOWS then
			return
		end
		local crateTier = if typeof(p.crate) == "number" then p.crate else 1
		local h = CaseOpening.start(owner, crateTier, false, p.count)
		if h then
			shows[owner] = h
			h:reveal(p.results)
		end
	end)
end

return CaseShowController
