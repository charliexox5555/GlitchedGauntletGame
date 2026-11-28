--!strict
-- The Season Pass (vault/02 Art/UI Battle Pass.md), desktop. Studio-built
-- StarterGui.BattlePass (backup tools/studio/archive/BuildBattlePass.luau), filled
-- from Lobby/SeasonCatalog. The server owns the player's pass: the state is the
-- player's "Season" StringValue (Shared/PlayerData.season), CLAIM asks
-- SeasonRequest (Services/SeasonService), UNLOCK PREMIUM and +5 LEVELS open the
-- Robux prompts (Services/RobuxService). The screen redraws whenever the state changes.
--
-- * Router "BattlePass" (the bar's PASS, the Shop's Season Pass card).
-- * Your season level, the bar to the next with what levels you up.
-- * FREE and PREMIUM tracks, 7 tiers a page (arrows page through 30). A
--   reached, untaken reward says CLAIM; a taken one is dimmed with a tick.
-- * Click a reward: it shows big on top (a skin in 3D, a case or coins as
--   its picture, a charm / emote as a card) with its tier, name and what it
--   is, and the actions that apply: CONTENTS (a case's odds), CLAIM, UNLOCK
--   PREMIUM, +5 LEVELS. The PREMIUM badge shows the premium pass itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)

local SeasonCatalog = require(ReplicatedStorage.Lobby.SeasonCatalog)
local LobbyNet = require(ReplicatedStorage.Lobby.LobbyNet)
local PlayerData = require(ReplicatedStorage.Shared.PlayerData)
local Season = require(ReplicatedStorage.Shared.Config.Season)
local SeasonPass = require(ReplicatedStorage.Shared.SeasonPass)
local ShopCatalog = require(ReplicatedStorage.Lobby.ShopCatalog)
local Locker = require(ReplicatedStorage.Shared.Locker)
local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local UiRoot = require(ReplicatedStorage.Shared.UiRoot)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Loadout = require(ReplicatedStorage.Shared.Config.Loadout)
local Mods = require(ReplicatedStorage.Shared.Config.Mods)
local SkinArt = require(ReplicatedStorage.Shared.SkinArt)
local CloseButton = require(script.Parent.Parent.Util.CloseButton)
local ItemStage = require(script.Parent.Parent.Util.ItemStage)
local CharmThumbnail = require(script.Parent.Parent.Util.CharmThumbnail)
local CharmsConfig = require(ReplicatedStorage.Shared.Config.Charms)
local OddsList = require(script.Parent.Parent.Util.OddsList)
local Pivot = require(script.Parent.Parent.Util.Pivot)
local Plates = require(script.Parent.Parent.Util.Plates)
local Router = require(script.Parent.Parent.Util.Router)
local LobbyHud = require(script.Parent.LobbyHud)
local UiMotion = require(game:GetService("ReplicatedStorage").Shared.UiMotion) -- the one motion module
local KM = UiMotion.M

local BattlePassController = {}

local player = Players.LocalPlayer
local QUINT = Enum.EasingStyle.Quint
local IN = Enum.EasingDirection.In
local WHITE, INK = Color3.new(1, 1, 1), Color3.fromHex("1A1A1D")
local CARD = Color3.fromHex("141417")
local REACHED = Color3.fromHex("3FD68A")
local NOT_REACHED = Color3.fromHex("333336")
local KIND_COLOR: { [string]: Color3 } = {
	Mod = Color3.fromHex("FFC83D"),
	Charm = Color3.fromHex("B58CFF"),
	Emote = Color3.fromHex("FF7AD9"),
	Ticket = Color3.fromHex("7FD4FF"),
	Title = Color3.fromHex("FFE28A"),
}

type Track = "free" | "premium"
type Pick = { tier: number, track: Track } | "pass"

local gui: ScreenGui
local canvas: Frame
local detail: Frame
local showBox: Frame
local stage: ItemStage.Stage
local tracks: Frame
local levelRow: Frame
local dim: Frame
local popCanvas: Frame
local oddsPanel: Frame

local isOpen = false
local page = 1
local pick: Pick? = nil
local resetClose: () -> () = function() end
-- the server's state for this player (redrawn on every change)
local state: SeasonPass.State = SeasonPass.new()
local claiming = false -- a claim is on its way: CLAIM waits for the answer
local seasonRequest: RemoteEvent
local robuxRequest: RemoteEvent

local tween = UiMotion.tween

local function child<T>(parent: Instance, name: string): T
	return (parent:WaitForChild(name) :: any) :: T
end

local function pop(obj: Instance): UIScale?
	local p = obj:FindFirstChild("Pop")
	return if p and p:IsA("UIScale") then p else nil
end

local function rest(p: UIScale?, scale: number)
	if p then
		UiMotion.rest(p, scale)
	end
end

local function press(p: UIScale?, _low: number?)
	if p then
		UiMotion.press(p)
	end
end

local function commas(n: number): string
	local s = string.reverse(tostring(math.floor(n))):gsub("(%d%d%d)", "%1,")
	return (string.gsub(string.reverse(s), "^,", ""))
end

--------------------------------------------------------------------------------
-- Rewards

local function reward(tier: number, track: Track): SeasonCatalog.Reward?
	local t = SeasonCatalog.TIERS[tier]
	return if t then t[track] else nil
end

local function rewardName(r: SeasonCatalog.Reward): string
	if r.kind == "Coins" then
		return string.format("%s COINS", commas(r.amount or 0))
	end
	return r.name
end

local function rewardDesc(r: SeasonCatalog.Reward): string
	if r.kind == "Coins" then
		return "COINS FOR THE SHOP"
	elseif r.kind == "Case" and r.case == "GoodieBag" then
		return "ONE PRIZE: COINS, TICKETS, A BOX, A PACK, A CASE OR A SKIN"
	elseif r.kind == "Case" then
		return "x1 CASE  ·  SEE ITS CONTENTS FOR THE ODDS"
	elseif r.kind == "Skin" and not r.gun then
		return string.format("%s SKIN  ·  FOR A RANDOM GUN YOU OWN", string.upper(r.rarity or ""))
	elseif r.kind == "Skin" then
		local cfg = r.gun and Weapons.get(r.gun)
		return string.format(
			"%s SKIN  ·  FOR THE %s",
			string.upper(r.rarity or ""),
			string.upper(if cfg then cfg.displayName else (r.gun or ""))
		)
	end
	return string.format("%s %s", string.upper(r.rarity or ""), string.upper(r.kind))
end

--------------------------------------------------------------------------------
-- Random-gun skin rewards (owner 2026-11-27: "spinning reel"): before the claim the tile
-- cycles the portraits of the guns this player could get (the same pool as
-- Lobby/SeasonRewards.rollGun: owned guns without the line first, else locked ones);
-- claiming spins it down onto the rolled gun, which the tile keeps (SeasonPass.got).

local REEL_STEP = 1.2 -- seconds per portrait while idle
type Reel = { art: ImageLabel, line: string, pool: { string }, i: number }
local reels: { [GuiObject]: Reel } = {}
local spinning: { [string]: boolean } = {} -- "<tier><track>" while a claim lands

local function reelPool(line: string): { string }
	local skins = PlayerData.skins(player)
	local guns = PlayerData.guns(player)
	local mine, others = {}, {}
	for _, list in { Loadout.PRIMARIES, Loadout.SECONDARIES } do
		for _, id in list do
			if
				not PlayerData.owns(skins, id, line)
				and Locker.hasSkin(id, line)
				and SkinArt.portrait(id, line)
			then
				table.insert(if guns.owned[id] then mine else others, id)
			end
		end
	end
	return if #mine > 0 then mine else others
end

local function reelSlide(art: ImageLabel, image: string, time: number)
	art.Image = image
	local home = UDim2.fromScale(0.5, 0.5)
	if art.AnchorPoint ~= Vector2.new(0.5, 0.5) then
		return
	end
	art.Position = home + UDim2.fromScale(0, 0.18)
	art.ImageTransparency = 0.5
	tween(art, time, { Position = home, ImageTransparency = 0 })
end

-- Every idle reel moves on one portrait (the pass ticks this while it's open).
local function stepReels()
	for cell, reel in reels do
		if cell.Parent and cell.Visible and #reel.pool > 1 then
			reel.i = reel.i % #reel.pool + 1
			reelSlide(reel.art, SkinArt.portrait(reel.pool[reel.i], reel.line) or "", 0.22)
		end
	end
end

local function claimable(tier: number, track: Track): boolean
	return reward(tier, track) ~= nil and SeasonPass.canClaim(state, tier, track)
end

-- A cell's picture: coins → the coin stack, a case → its art, a skin → the
-- gun's icon in the line's colour; charms / emotes / Mods → a coloured swatch.
local function paintCell(cell: GuiButton, r: SeasonCatalog.Reward?, tier: number?, track: Track?)
	local art = child(cell, "Art") :: ImageLabel
	reels[cell] = nil
	local swatch = child(cell, "Swatch") :: Frame
	local name = child(cell, "Name") :: TextLabel
	art.Image = ""
	art.ImageColor3 = WHITE
	CharmThumbnail.clear(art)
	swatch.Visible = false
	if not r then
		name.Text = ""
		return
	end
	name.Text = if r.kind == "Coins" then "x" .. commas(r.amount or 0) else r.name
	if r.kind == "Coins" then
		art.Image = ShopCatalog.ART.coinStack
	elseif r.kind == "Ticket" then
		art.Image = ShopCatalog.ART.ticket
	elseif r.kind == "Mod" and r.mod and Mods.defs[r.mod] then
		art.Image = Mods.defs[r.mod].icon or ""
	elseif r.kind == "Case" then
		local c = r.case and ShopCatalog.case(r.case)
		art.Image = if c then c.art or "" else ""
	elseif r.kind == "Skin" and r.gun then
		local portrait = if r.line then SkinArt.portrait(r.gun, r.line) else nil
		if portrait and portrait ~= "" then
			art.Image = portrait
			art.ImageColor3 = WHITE
		else
			art.Image = Theme.GUN[r.gun] or ""
			art.ImageColor3 = if r.line then (Locker.COLORS[r.line] or WHITE) else WHITE
		end
	elseif r.kind == "Skin" and r.line and tier and track then
		-- a random-gun skin: the rolled gun once claimed, else a reel over the player's pool
		local line = r.line
		local won = SeasonPass.got(state, tier, track)
		local pool = if won then { won } else reelPool(line)
		if spinning[tostring(tier) .. track] then
			return -- the landing spin owns this tile's picture
		elseif #pool > 0 then
			local first = tier % #pool + 1 -- tiles start on different guns
			art.Image = SkinArt.portrait(pool[first], line) or ""
			if not won then
				reels[cell] = { art = art, line = line, pool = pool, i = first }
			end
		else
			swatch.Visible = true
			swatch.BackgroundColor3 = Locker.COLORS[line] or WHITE;
			(child(swatch, "Kind") :: TextLabel).Text = "SKIN"
		end
	elseif r.kind == "Skin" then
		swatch.Visible = true
		swatch.BackgroundColor3 = if r.line then (Locker.COLORS[r.line] or WHITE) else WHITE;
		(child(swatch, "Kind") :: TextLabel).Text = "SKIN"
	elseif r.kind == "Charm" then
		local cid = r.charm or r.name
		if not CharmThumbnail.mount(art, cid, false) then
			local def = CharmsConfig.get(cid)
			swatch.Visible = true
			swatch.BackgroundColor3 = (if def then def.accent else nil) or KIND_COLOR.Charm or WHITE;
			(child(swatch, "Kind") :: TextLabel).Text = "CHARM"
		end
	else
		swatch.Visible = true
		swatch.BackgroundColor3 = KIND_COLOR[r.kind]
			or (if r.rarity then ShopCatalog.RARITY_COLOR[r.rarity] else nil)
			or WHITE;
		(child(swatch, "Kind") :: TextLabel).Text = string.upper(r.kind)
	end
end

--------------------------------------------------------------------------------
-- The page of tiers

local function pages(): number
	return math.ceil(#SeasonCatalog.TIERS / SeasonCatalog.PER_PAGE)
end

local function setSelect(cell: GuiObject, on: boolean)
	local sel = cell:FindFirstChild("Select")
	if not (sel and sel:IsA("GuiObject")) then
		return
	end
	if on and not sel.Visible then
		sel.Visible = true
		for _, b in sel:GetChildren() do
			if b:IsA("GuiObject") then
				local home = b.Position
				local x = if home.X.Scale > 0.5 then 1 else -1
				local y = if home.Y.Scale > 0.5 then 1 else -1
				b.Position = home + UDim2.fromOffset(x * 18, y * 18)
				tween(b, 0.2, { Position = home })
			end
		end
	elseif not on then
		sel.Visible = false
	end
end

local function renderPage()
	local per = SeasonCatalog.PER_PAGE
	for col = 1, per do
		local tier = (page - 1) * per + col
		local exists = SeasonCatalog.TIERS[tier] ~= nil
		for _, track in { "free", "premium" } :: { Track } do
			local cell =
				child(tracks, (if track == "free" then "Free" else "Premium") .. col) :: GuiButton
			cell.Visible = exists
			if exists then
				local r = reward(tier, track)
				paintCell(cell, r, tier, track)
				local taken = SeasonPass.claimed(state, tier, track);
				(child(cell, "Dim") :: GuiObject).Visible = taken;
				(child(cell, "Check") :: GuiObject).Visible = taken;
				(child(cell, "ClaimTag") :: GuiObject).Visible = claimable(tier, track)
				local p = pick
				setSelect(cell, typeof(p) == "table" and p.tier == tier and p.track == track)
			end
		end
		local num = child(tracks, "Tier" .. col) :: Frame
		num.Visible = exists
		if exists then
			(child(num, "Number") :: TextLabel).Text = tostring(tier);
			(child(num, "Bar") :: Frame).BackgroundColor3 = if state.tier >= tier
				then REACHED
				else NOT_REACHED
		end
	end
	for _, n in { "Prev", "Next" } do
		local b = child(levelRow, n) :: GuiButton
		local on = if n == "Prev" then page > 1 else page < pages()
		b.BackgroundColor3 = if on then WHITE else CARD
		b.BackgroundTransparency = if on then 0 else 0.4;
		(child(b, "Glyph") :: TextLabel).TextColor3 = if on then INK else Color3.fromHex("5A6488")
	end
end

-- "SEASON 1  ·  ENDS IN 24D 6H" (just the name while no end date is set)
local function renderSub()
	local sub = canvas:FindFirstChild("Sub")
	if not (sub and sub:IsA("TextLabel")) then
		return
	end
	local ends = Season.endsAt()
	if not ends then
		sub.Text = Season.NAME
		return
	end
	local left = math.max(ends - workspace:GetServerTimeNow(), 0)
	local days, hours = left // 86400, (left % 86400) // 3600
	sub.Text = string.format("%s  ·  ENDS IN %dD %dH", Season.NAME, days, hours)
end

-- The pass's buy buttons sit top-right at all times (owner 2026-11-27): PREMIUM until it's
-- owned, +5 LEVELS until the last tier.
local function renderStore()
	local store = canvas:FindFirstChild("Store")
	if not store then
		return
	end
	local unlock = store:FindFirstChild("Unlock")
	local skip = store:FindFirstChild("Skip")
	if unlock and unlock:IsA("GuiObject") then
		unlock.Visible = not state.premium
	end
	if skip and skip:IsA("GuiObject") then
		skip.Visible = state.tier < Season.TIERS
	end
end

local function renderLevel()
	local top = state.tier >= Season.TIERS;
	(child(child(levelRow, "Box"), "Value") :: TextLabel).Text = tostring(state.tier);
	(child(child(levelRow, "Tip"), "Text") :: TextLabel).Text = if top
		then "MAX LEVEL: EVERY REWARD IS UNLOCKED"
		else string.format(
			"%d / %d MIN  OR  %d / %d ROUNDS TO LEVEL UP",
			state.secs // 60,
			Season.TIER_SECONDS // 60,
			state.rounds,
			Season.TIER_ROUNDS
		)
	local bar = child(levelRow, "Bar") :: Frame
	local share = if top
		then 1
		else math.max(state.rounds / Season.TIER_ROUNDS, state.secs / Season.TIER_SECONDS)
	tween(child(bar, "Fill"), 0.4, { Size = UDim2.fromScale(math.clamp(share, 0.04, 1), 1) });
	(child(bar, "Next") :: TextLabel).Text = if top then "MAX" else "LEVEL " .. (state.tier + 1)
	local badge = child(tracks, "PremiumBadge") :: GuiObject;
	(child(badge, "Lock") :: GuiObject).Visible = not state.premium
	renderStore()
end

--------------------------------------------------------------------------------
-- The picked reward, big

local function showPicture(r: SeasonCatalog.Reward?, image: string?)
	local art = child(showBox, "Art") :: ImageLabel
	local card = child(showBox, "Card") :: Frame
	local model: Model? = nil
	local charmMode = false
	local p = pick
	local won = if r
			and r.kind == "Skin"
			and not r.gun
			and typeof(p) == "table"
		then SeasonPass.got(state, p.tier, p.track)
		else nil
	if r and r.kind == "Skin" and (r.gun or won) then
		local gun = (r.gun or won) :: string
		model = (if r.line then Locker.skinModel(gun, r.line) else nil) or Locker.gunModel(gun)
	elseif r and r.kind == "Skin" and r.line and not image then
		-- not claimed yet: one of the guns it could be, as on the reel
		local pool = reelPool(r.line)
		image = if #pool > 0 then SkinArt.portrait(pool[1], r.line) else nil
	elseif r and r.kind == "Charm" then
		model = CharmsConfig.model(r.charm or r.name)
		charmMode = model ~= nil
	end
	art.Image = ""
	card.Visible = false
	if model and r then
		if charmMode then
			stage:show(model, "charm")
		else
			local cfg = r.gun and Weapons.get(r.gun)
			stage:show(model, cfg ~= nil and cfg.class == "Melee")
		end
	else
		stage:show(nil)
		if image then
			art.Image = image
		elseif r then
			card.BackgroundColor3 = (
				if r.kind == "Skin" and r.line then Locker.COLORS[r.line] else nil
			)
				or KIND_COLOR[r.kind]
				or (if r.rarity then ShopCatalog.RARITY_COLOR[r.rarity] else nil)
				or WHITE;
			(child(card, "Kind") :: TextLabel).Text = string.upper(r.kind)
			card.Visible = true
		end
	end
	local sc = pop(showBox)
	if sc then
		sc.Scale = 0.92
		tween(sc, 0.28, { Scale = 1 })
	end
end

local function setActions(contents: boolean, claim: boolean)
	local actions = child(detail, "Actions") :: Frame;
	(child(actions, "Contents") :: GuiObject).Visible = contents;
	(child(actions, "Claim") :: GuiObject).Visible = claim
end

local function pickReward(p: Pick)
	pick = p
	local tierLabel = child(child(detail, "Tier"), "Label") :: TextLabel
	local name = child(detail, "Name") :: TextLabel
	local desc = child(detail, "Desc") :: TextLabel
	if p == "pass" then
		tierLabel.Text = SeasonCatalog.NAME .. "  ·  PREMIUM"
		name.Text = "PREMIUM PASS"
		desc.Text = table.concat(SeasonCatalog.PREMIUM_PERKS, "  ·  ")
		showPicture(nil, ShopCatalog.ART.seasonPass)
		setActions(false, false)
	else
		local r = reward(p.tier, p.track)
		tierLabel.Text = string.format("TIER %d  ·  %s", p.tier, string.upper(p.track))
		if r then
			name.Text = rewardName(r)
			desc.Text = rewardDesc(r)
			local image = if r.kind == "Coins"
				then ShopCatalog.ART.coinStack
				elseif r.kind == "Ticket" then ShopCatalog.ART.ticket
				elseif r.kind == "Mod" and r.mod and Mods.defs[r.mod] then Mods.defs[r.mod].icon
				elseif r.kind == "Case" then (function()
					local c = r.case and ShopCatalog.case(r.case)
					return if c then c.art else nil
				end)()
				else nil
			showPicture(r, image)
		else
			name.Text = "NOTHING HERE"
			desc.Text = "THIS TIER'S REWARD IS ON THE OTHER TRACK"
			showPicture(nil, nil)
		end
		setActions(r ~= nil and r.kind == "Case", claimable(p.tier, p.track))
	end
	renderPage()
end

-- Where the pass opens: the first reward waiting to be claimed, else the
-- next tier.
local function firstPick(): { tier: number, track: Track }
	for tier = 1, #SeasonCatalog.TIERS do
		for _, track in { "free", "premium" } :: { Track } do
			if claimable(tier, track) then
				return { tier = tier, track = track }
			end
		end
	end
	return { tier = math.min(state.tier + 1, #SeasonCatalog.TIERS), track = "free" }
end

-- The server pays it and the new state redraws the screen (onState); a lost answer
-- frees CLAIM again after a while.
local function claim()
	local p = pick
	if claiming or typeof(p) ~= "table" or not claimable(p.tier, p.track) then
		return
	end
	claiming = true
	seasonRequest:FireServer("claim", p.tier, p.track)
	task.delay(5, function()
		claiming = false
	end)
end

local function onSeasonEvent(payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end
	local e = payload :: LobbyNet.SeasonEventPayload
	claiming = false
	if e.kind == "claimed" and e.rewards then
		for _, r in e.rewards do
			local tier, track, gun, line = r.tier, r.track, r.gun, r.line
			if
				isOpen
				and r.kind == "Skin"
				and gun
				and line
				and tier
				and (track == "free" or track == "premium")
			then
				local col = tier - (page - 1) * SeasonCatalog.PER_PAGE
				local row =
					tracks:FindFirstChild((if track == "free" then "Free" else "Premium") .. col)
				local art = row and row:FindFirstChild("Art")
				if art and art:IsA("ImageLabel") then
					-- the landing: fast through the pool, slowing, then the rolled gun
					local key = tostring(tier) .. track
					spinning[key] = true
					reels[row :: GuiObject] = nil
					local pool = reelPool(line)
					if #pool == 0 then
						pool = { gun }
					end
					task.spawn(function()
						local gap = 0.05
						for i = 1, 12 do
							reelSlide(
								art,
								SkinArt.portrait(pool[(i - 1) % #pool + 1], line) or "",
								gap * 0.8
							)
							task.wait(gap)
							gap *= 1.22
						end
						reelSlide(art, SkinArt.portrait(gun, line) or "", 0.3)
						local sc = pop(row :: Instance)
						if sc then
							sc.Scale = 1.12
							tween(sc, 0.3, { Scale = 1 })
						end
						spinning[key] = nil
						if isOpen then
							renderPage()
						end
					end)
				end
			end
			LobbyHud.toast(
				"You've earned "
					.. (
						if r.kind == "Coins"
							then string.format("%s COINS", commas(r.amount or 0))
							elseif (r.amount or 1) > 1 then `x{r.amount} {r.name}`
							else "x1 " .. r.name
					),
				"info"
			)
		end
	elseif e.kind == "failed" then
		LobbyHud.toast(e.text or "Couldn't claim that, try again", "error")
	end
end

-- The server's state changed (a claim, a purchase, a match): redraw what's open.
local function onState()
	state = PlayerData.season(player)
	if not isOpen then
		return
	end
	renderLevel()
	local p = pick
	if p then
		pickReward(p)
	else
		renderPage()
	end
end

--------------------------------------------------------------------------------
-- Popups

local function showOdds(on: boolean)
	dim.Visible = on
	popCanvas.Visible = on
	if on then
		dim.BackgroundTransparency = 1
		tween(dim, 0.2, { BackgroundTransparency = 0.35 })
		local sc = pop(oddsPanel)
		if sc then
			sc.Scale = 0.92
			tween(sc, 0.24, { Scale = 1 })
		end
	end
end

local function openContents()
	local p = pick
	local r = if typeof(p) == "table" then reward(p.tier, p.track) else nil
	local c = r and r.case and ShopCatalog.case(r.case)
	if not c then
		return
	end
	(child(oddsPanel, "Sub") :: TextLabel).Text = c.name
	OddsList.fill(
		child(oddsPanel, "List") :: ScrollingFrame,
		c,
		child(oddsPanel, "Note") :: TextLabel
	)
	showOdds(true)
end

--------------------------------------------------------------------------------
-- Open / close

local function setPage(n: number, animate: boolean)
	page = math.clamp(n, 1, pages())
	renderPage()
	if animate then
		for col = 1, SeasonCatalog.PER_PAGE do
			for row, prefix in { "Free", "Premium" } do
				local cell = child(tracks, prefix .. col) :: GuiObject
				local art = cell:FindFirstChild("Art")
				local sc = pop(cell)
				local delay = math.min((col - 1) * 0.04 + (row - 1) * 0.02, 0.3)
				if sc then
					sc.Scale = 0.94
					task.delay(delay, function()
						tween(sc, 0.24, { Scale = 1 })
					end)
				end
				if art and art:IsA("ImageLabel") and art.Image ~= "" then
					local home = UDim2.new(0.5, 0, 0.44, 0)
					art.Position = home + UDim2.fromOffset(0, 12)
					art.ImageTransparency = 1
					task.delay(delay, function()
						tween(art, 0.24, { Position = home, ImageTransparency = 0 })
					end)
				end
			end
		end
	end
end

local function slideIn(o: GuiObject, dx: number, dy: number, delay: number)
	local h = StateValues.get(o, "Home")
	local home = if typeof(h) == "UDim2" then h else o.Position
	StateValues.set(o, "Home", home)
	o.Position = home + UDim2.fromOffset(dx, dy)
	task.delay(delay, function()
		if isOpen then
			tween(o, 0.42, { Position = home })
		end
	end)
end

local function open()
	if isOpen then
		return
	end
	isOpen = true
	gui.Enabled = true
	resetClose()
	showOdds(false)
	local wash = gui:FindFirstChild("Wash")
	if wash and wash:IsA("Frame") then
		wash.BackgroundTransparency = 1
		tween(wash, 0.25, { BackgroundTransparency = 0.3 })
	end
	renderSub()
	renderLevel()
	local first = firstPick()
	page = math.ceil(first.tier / SeasonCatalog.PER_PAGE)
	stage:run(true)
	pickReward(first)
	setPage(page, true)
	slideIn(detail, 0, -30, 0)
	slideIn(levelRow, 0, 30, 0.03)
	slideIn(tracks, 0, 40, 0.06)
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	stage:run(false)
	stage:show(nil)
	showOdds(false)
	local wash = gui:FindFirstChild("Wash")
	if wash and wash:IsA("Frame") then
		tween(wash, 0.16, { BackgroundTransparency = 1 }, QUINT, IN)
	end
	task.delay(0.17, function()
		if not isOpen then
			gui.Enabled = false
		end
	end)
end

--------------------------------------------------------------------------------

-- The page (~900 instances): copied in and wired on its first open, or when the bar's button is hovered
-- (Router.warm), not at join (Shared/UiRoot LAZY; loading pass 2026-11-27). New page parts get wired here.
local function build(): boolean
	if gui then
		return true
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local g = playerGui:FindFirstChild("BattlePass")
		or UiRoot.mount("Lobby", playerGui, "BattlePass")[1]
	if not g or not g:IsA("ScreenGui") then
		warn("[BattlePass] UI.Lobby.BattlePass missing (tools/studio/archive/BuildBattlePass.luau)")
		return false
	end
	gui = g
	gui.Enabled = false
	canvas = child(gui, "Canvas")
	detail = child(canvas, "Detail")
	showBox = child(detail, "Show")
	tracks = child(canvas, "Tracks")
	levelRow = child(canvas, "Level")
	dim = child(gui, "Dim")
	popCanvas = child(gui, "PopupCanvas")
	oddsPanel = child(popCanvas, "OddsPanel")
	stage =
		ItemStage.new(child(showBox, "Stage") :: Frame, { length = 7.8, height = 3, distance = 11 })
	stage:bindDrag(child(showBox, "DragArea") :: GuiButton)

	-- the cells: hover lifts, click picks
	for col = 1, SeasonCatalog.PER_PAGE do
		for _, track in { "free", "premium" } :: { Track } do
			local cell =
				child(tracks, (if track == "free" then "Free" else "Premium") .. col) :: GuiButton
			local sc = pop(cell)
			cell.MouseEnter:Connect(function()
				rest(sc, KM.hoverCard)
			end)
			cell.MouseLeave:Connect(function()
				rest(sc, 1)
			end)
			cell.Activated:Connect(function()
				press(sc)
				pickReward({ tier = (page - 1) * SeasonCatalog.PER_PAGE + col, track = track })
			end)
		end
	end
	local premiumBadge = child(tracks, "PremiumBadge") :: GuiButton
	premiumBadge.Activated:Connect(function()
		press(pop(premiumBadge))
		pickReward("pass")
	end)
	local freeBadge = child(tracks, "FreeBadge") :: GuiButton
	freeBadge.Activated:Connect(function()
		press(pop(freeBadge))
	end)
	for _, n in { "Prev", "Next" } do
		local b = child(levelRow, n) :: GuiButton
		b.Activated:Connect(function()
			local to = page + (if n == "Prev" then -1 else 1)
			if to >= 1 and to <= pages() then
				press(pop(b))
				setPage(to, true)
			end
		end)
	end
	local actions = child(detail, "Actions") :: Frame
	local store = canvas:FindFirstChild("Store") or actions
	local function hookButton(name: string, fn: () -> (), parent: Instance?)
		local b = child(parent or actions, name) :: GuiButton
		local sc = pop(b)
		b.MouseEnter:Connect(function()
			rest(sc, KM.hover)
		end)
		b.MouseLeave:Connect(function()
			rest(sc, 1)
		end)
		b.Activated:Connect(function()
			press(sc)
			fn()
		end)
	end
	hookButton("Contents", openContents)
	hookButton("Claim", claim)
	-- Robux: the server checks again and answers on ShopEvent (ShopController's popup)
	hookButton("Unlock", function()
		robuxRequest:FireServer("season")
	end, store)
	hookButton("Skip", function()
		robuxRequest:FireServer("seasonSkip")
	end, store)
	CloseButton.hook(child(oddsPanel, "Close") :: GuiButton, function()
		showOdds(false)
	end)
	resetClose = CloseButton.hook(child(canvas, "Close") :: GuiButton, function()
		if popCanvas.Visible then
			showOdds(false)
		else
			Router.close()
		end
	end)
	-- everything that pops grows from its own centre (owner rule)
	Plates.deepen(gui)
	Pivot.fix(gui)
	return true
end

function BattlePassController.init()
	if not SeasonCatalog.screenOn() then
		return -- closed for this update (shared/Config/Release; Studio: Workspace BattlePassTest)
	end
	Router.register("BattlePass", {
		open = function()
			if build() then
				open()
			end
		end,
		close = close,
		screen = "BattlePass",
		warm = function()
			build()
		end,
	})

	-- the season's state and claim answers: live from join (onState redraws only while the page is open)
	seasonRequest = LobbyNet.event("SeasonRequest")
	robuxRequest = LobbyNet.event("RobuxRequest")
	LobbyNet.event("SeasonEvent").OnClientEvent:Connect(onSeasonEvent)
	-- random-gun skin tiles turn over while the pass is open
	task.spawn(function()
		while true do
			task.wait(REEL_STEP)
			if isOpen then
				stepReels()
			end
		end
	end)
	-- the state value appears with the save and is rewritten on every change
	local function watch(v: Instance)
		if v.Name == PlayerData.SEASON and v:IsA("StringValue") then
			v.Changed:Connect(onState)
			onState()
		end
	end
	local existing = player:FindFirstChild(PlayerData.SEASON)
	if existing then
		watch(existing)
	else
		local conn: RBXScriptConnection
		conn = player.ChildAdded:Connect(function(v)
			if v.Name == PlayerData.SEASON then
				conn:Disconnect()
				watch(v)
			end
		end)
	end
end

return BattlePassController
