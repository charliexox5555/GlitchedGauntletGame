--!strict
-- The battle pass card on the Shop's Home page (owner 2026-11-27: the pass sits next to the cases and looks like
-- the pass): the season and tier, a gold bar to the next tier, and the next four rewards with their art. The card
-- is Studio UI (Shop.Canvas.Scroll.Home.Top.SeasonPass.Card: Sub, Progress.Fill, Rewards.Tile1-4 with Strip,
-- Art, Name, Tier); this fills it from the published pass state and refreshes when it changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharmIcons = require(ReplicatedStorage.Shared.CharmIcons)
local Mods = require(ReplicatedStorage.Shared.Config.Mods)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local Season = require(ReplicatedStorage.Shared.Config.Season)
local SeasonCatalog = require(ReplicatedStorage.Lobby.SeasonCatalog)
local ShopCatalog = require(ReplicatedStorage.Lobby.ShopCatalog)
local SkinArt = require(ReplicatedStorage.Shared.SkinArt)

local ShopPassCard = {}

local GOLD = Color3.fromHex("FFC83D")
local FREE = Color3.fromHex("A9B2BF")
local TILES = 4

local function art(r: SeasonCatalog.Reward): string
	if r.kind == "Coins" then
		return ShopCatalog.ART.coinStack
	elseif r.kind == "Ticket" then
		return ShopCatalog.ART.ticket
	elseif r.kind == "Case" then
		local c = r.case and ShopCatalog.case(r.case)
		return if c then c.art or "" else ""
	elseif r.kind == "Mod" and r.mod and Mods.defs[r.mod] then
		return Mods.defs[r.mod].icon or ""
	elseif r.kind == "Charm" and r.charm then
		return CharmIcons.get(r.charm) or ""
	elseif r.kind == "Skin" and r.line then
		-- a random-gun skin shows the line on the Havoc
		return SkinArt.portrait(r.gun or "Vandal", r.line) or ""
	end
	return ""
end

local function words(r: SeasonCatalog.Reward): string
	if r.kind == "Coins" then
		return `{r.amount or 0} COINS`
	elseif r.kind == "Ticket" then
		return if (r.amount or 1) == 1 then "1 TICKET" else `{r.amount} TICKETS`
	end
	return r.name
end

-- the next rewards past the player's tier, premium first in each tier
local function upcoming(
	fromTier: number
): { { r: SeasonCatalog.Reward, tier: number, premium: boolean } }
	local list = {}
	local start = math.clamp(fromTier + 1, 1, math.max(Season.TIERS - TILES + 1, 1))
	for tier = start, Season.TIERS do
		for _, track in { "premium", "free" } :: { "premium" | "free" } do
			for _, r in SeasonCatalog.rewards(tier, track) do
				table.insert(list, { r = r, tier = tier, premium = track == "premium" })
				if #list >= TILES then
					return list
				end
			end
		end
	end
	return list
end

local function find(parent: Instance, path: { string }): Instance?
	local at: Instance? = parent
	for _, name in path do
		at = at and at:FindFirstChild(name)
	end
	return at
end

function ShopPassCard.bind(card: GuiObject)
	local player = Players.LocalPlayer
	local function render()
		local on = SeasonCatalog.screenOn()
		local s = PlayerData.season(player)
		local sub = card:FindFirstChild("Sub")
		if sub and sub:IsA("TextLabel") then
			sub.Text = if on
				then string.format("SEASON %d  ·  TIER %d / %d", Season.ID, s.tier, Season.TIERS)
				else string.format("SEASON %d  ·  COMING SOON", Season.ID)
		end
		local progress = card:FindFirstChild("Progress")
		if progress and progress:IsA("GuiObject") then
			progress.Visible = on
			local fill = progress:FindFirstChild("Fill")
			if fill and fill:IsA("GuiObject") then
				local share = if s.tier >= Season.TIERS
					then 1
					else math.max(s.secs / Season.TIER_SECONDS, s.rounds / Season.TIER_ROUNDS)
				fill.Size = UDim2.fromScale(math.clamp(share, 0.02, 1), 1)
			end
		end
		local next = upcoming(if on then s.tier else 0)
		for i = 1, TILES do
			local tile = find(card, { "Rewards", "Tile" .. i })
			if not (tile and tile:IsA("GuiObject")) then
				continue
			end
			local item = next[i]
			tile.Visible = item ~= nil
			if not item then
				continue
			end
			local pic = tile:FindFirstChild("Art")
			if pic and pic:IsA("ImageLabel") then
				pic.Image = art(item.r)
			end
			local name = tile:FindFirstChild("Name")
			if name and name:IsA("TextLabel") then
				name.Text = words(item.r)
			end
			local tierLabel = tile:FindFirstChild("Tier")
			if tierLabel and tierLabel:IsA("TextLabel") then
				tierLabel.Text = `TIER {item.tier}`
				tierLabel.TextColor3 = if item.premium then GOLD else FREE
			end
			local strip = tile:FindFirstChild("Strip")
			if strip and strip:IsA("GuiObject") then
				strip.BackgroundColor3 = if item.premium then GOLD else FREE
			end
		end
	end
	render()
	task.spawn(function()
		local value = player:WaitForChild(PlayerData.SEASON, 30)
		if value and value:IsA("StringValue") then
			value.Changed:Connect(render)
			render()
		end
	end)
end

return ShopPassCard
