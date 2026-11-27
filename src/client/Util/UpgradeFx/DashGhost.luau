--!strict
-- Dash Ghost and the Desync cloak on the client (vault/01 Design/Abilities/
-- Dash.md → Upgrades): how see-through each dasher is to this viewer.
--
--   B2/B3 Ghost: while the dodge window runs (Dash.windows) (damage passes through you, the
--   server's guard in Mods/Dash), everyone sees you half see-through, with
--   team-tinted afterimages peeling off behind you.
--   B3 Ghost, G3 Desync: while the cloak window runs you're nearly invisible
--   to enemies (a flickering shimmer to the ones within cloakShimmer studs,
--   half see-through to your team), name tag included. A Recon reveal's
--   outline still shows (the body never goes fully invisible under it).
--
-- Only LocalTransparencyModifier on other characters' parts and decals
-- (their world gun and held item are inside the character), put back to 0
-- when it ends. Your own character is left alone (first person): you get an
-- edge cue instead (Util/WindStrokes.ghost): thin strokes that shimmer along
-- the screen's side edges for exactly the dodge window, and a thin line down
-- each side with the colours turned down a little while you're cloaked. No
-- colour flash.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateValues = require(ReplicatedStorage.Shared.StateValues)
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Mods)
local DashMod = require(ReplicatedStorage.Shared.Mods.Dash)
local Mods = require(ReplicatedStorage.Shared.Mods)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)

local TeamColor = require(script.Parent.Parent.TeamColor)
local WindStrokes = require(script.Parent.Parent.WindStrokes)

local DashGhost = {}

local player = Players.LocalPlayer

local TRAIL = Config.DASH_FEEL.ghostTrail -- afterimage timing, look and caps
local SHIMMER_HZ = 9 -- the close-enemy flicker
local SHIMMER_DEPTH = 0.12 -- +- around cloakShimmerAlpha
local FADE_OUT = 0.15 -- seconds the cloak takes to come off
local REVEALED_MAX = 0.6 -- a revealed (Recon) dasher is never more see-through
local CLOAK_CUE = Config.WIND_FEEL.ghost.cloak

type Shown = {
	alpha: number,
	display: Enum.HumanoidDisplayDistanceType?, -- the name tag we hid
	nextImage: number,
	-- The parts and decals setAlpha writes, found once (not GetDescendants
	-- every frame: ~79 us a frame per dasher, measured 2026-11-27), again
	-- only when something is added to the body meanwhile.
	targets: { BasePart | Decal },
	dirty: boolean,
	added: RBXScriptConnection?,
}
local shown: { [Model]: Shown } = setmetatable({}, { __mode = "k" }) :: any

-- Afterimages: per dasher, a pool of body copies (one image = one copy of
-- every visible part, in `sources` order), shown by moving them into place
-- and fading them; a finished image is hidden (Transparency 1), not
-- destroyed, and reused by the next one. Pools of dashers that stopped
-- dashing are destroyed after TRAIL.keep seconds.
type Image = { parts: { BasePart }, born: number, live: boolean }
type Trail = { sources: { BasePart }, images: { Image }, lastUsed: number }
local trails: { [Model]: Trail } = {}
local liveImages = 0
local PER_DASHER = math.ceil(TRAIL.life / TRAIL.every) + 1

local folder: Folder? = nil
local cue: ColorCorrectionEffect? = nil

local function number(inst: Instance, name: string): number
	local v = StateValues.get(inst, name)
	return if typeof(v) == "number" then v else 0
end

local function fxFolder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "DashFx"
	made.Parent = Workspace
	folder = made
	return made
end

-- The dasher's resolved Dash stats (the loadout is public), or nil.
function DashGhost.statsOf(owner: Player): { [string]: any }?
	for slot = 1, 3 do
		if StateValues.get(owner, "Mod" .. slot .. "Id") == "Dash" then
			local level = StateValues.get(owner, "Mod" .. slot .. "Level")
			return if typeof(level) == "string" then Mods.stats("Dash", level) else nil
		end
	end
	return nil
end

local function findTargets(character: Model): { BasePart | Decal }
	local list: { BasePart | Decal } = {}
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			table.insert(list, d)
		end
	end
	return list
end

local function setAlpha(state: Shown, character: Model, alpha: number)
	if state.dirty then
		state.dirty = false
		state.targets = findTargets(character)
	end
	for _, d in state.targets do
		d.LocalTransparencyModifier = alpha
	end
end

-- Is a Recon reveal outlining this character (ModFxController's Highlights)?
local function revealed(character: Model): boolean
	local fx = Workspace:FindFirstChild("ModFx")
	if not fx then
		return false
	end
	for _, h in fx:GetChildren() do
		if h:IsA("Highlight") and h.Adornee == character and h.Enabled then
			return true
		end
	end
	return false
end

-- One pooled image: a team-tinted ForceField copy of each source part.
local function newImage(sources: { BasePart }, color: Color3): Image
	local parts: { BasePart } = {}
	local parent = fxFolder()
	for _, d in sources do
		local ok, copy = pcall(d.Clone, d)
		local part: BasePart
		if ok and copy then
			part = copy :: BasePart
		else
			-- (Keeps the copies in step with `sources`; too small to see.)
			part = Instance.new("Part")
			part.Size = Vector3.one * 0.001
		end
		part:ClearAllChildren() -- welds would tie the copy to the body
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.ForceField
		part.Color = color
		part.Transparency = 1
		part.LocalTransparencyModifier = 0
		part.CFrame = d.CFrame
		part.Parent = parent
		table.insert(parts, part)
	end
	return { parts = parts, born = 0, live = false }
end

local function hideImage(image: Image)
	image.live = false
	liveImages -= 1
	for _, p in image.parts do
		p.Transparency = 1
	end
end

local function dropTrail(character: Model, trail: Trail)
	for _, image in trail.images do
		if image.live then
			liveImages -= 1
		end
		for _, p in image.parts do
			p:Destroy()
		end
	end
	trails[character] = nil
end

-- A team-tinted copy of the body where it is now, fading out (pooled).
local cframes: { CFrame } = {}
local function afterimage(character: Model, color: Color3)
	local now = os.clock()
	local trail = trails[character]
	if not trail then
		-- The visible body, found once per pool (its copies match it by index).
		local sources: { BasePart } = {}
		for _, d in character:GetDescendants() do
			if
				d:IsA("BasePart")
				and d.Archivable
				and d.Transparency < 1
				and d.Name ~= "HumanoidRootPart"
			then
				table.insert(sources, d)
			end
		end
		trail = { sources = sources, images = {}, lastUsed = now }
		trails[character] = trail
	end
	local t = trail :: Trail
	t.lastUsed = now
	-- A free image of this dasher's, else a new one (up to PER_DASHER),
	-- else their oldest; nothing new past TRAIL.maxImages for everyone.
	local image: Image? = nil
	local oldest: Image? = nil
	for _, candidate in t.images do
		if not candidate.live then
			image = candidate
			break
		end
		if not oldest or candidate.born < (oldest :: Image).born then
			oldest = candidate
		end
	end
	if not image then
		if #t.images < PER_DASHER and liveImages < TRAIL.maxImages then
			image = newImage(t.sources, color)
			table.insert(t.images, image :: Image)
		elseif oldest then
			image = oldest
			hideImage(oldest)
		end
	end
	if not image or liveImages >= TRAIL.maxImages then
		return
	end
	local img = image :: Image
	table.clear(cframes)
	for i, src in t.sources do
		cframes[i] = src.CFrame
	end
	Workspace:BulkMoveTo(img.parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	for i, p in img.parts do
		-- (A part the body has lost since stays hidden.)
		p.Transparency = if t.sources[i].Parent then TRAIL.alpha else 1
	end
	img.born = now
	img.live = true
	liveImages += 1
end

local function stepAfterimages()
	local now = os.clock()
	for character, trail in trails do
		for _, image in trail.images do
			if not image.live then
				continue
			end
			local k = (now - image.born) / TRAIL.life
			if k >= 1 then
				hideImage(image)
			else
				local alpha = TRAIL.alpha + (1 - TRAIL.alpha) * k
				for _, p in image.parts do
					if p.Transparency < 1 then
						p.Transparency = alpha
					end
				end
			end
		end
		if not character.Parent or now - trail.lastUsed > TRAIL.keep then
			dropTrail(character, trail)
		end
	end
end

-- How see-through `character` (owned by `owner`) is to us right now, and
-- whether it's a cloak (name tag hidden).
local function alphaFor(owner: Player, character: Model, now: number): (number, boolean)
	local dodgeUntil, cloakUntil = DashMod.windows(character)
	local start = number(character, "DashStart")
	if now >= dodgeUntil and now >= cloakUntil then
		return 0, false
	end
	local stats = DashGhost.statsOf(owner)
	if not stats then
		return 0, false
	end
	local alpha = 0
	if now < dodgeUntil then
		alpha = (stats.ghostAlpha or 0.5) + 0.06 * math.sin(now * 2 * math.pi * SHIMMER_HZ)
	end
	local cloaked = false
	if now >= start and now < cloakUntil then
		local target: number
		if Teams.isAlly(owner, player) then
			target = stats.cloakAllyAlpha or 0.5
		else
			cloaked = true
			local mine = player.Character
			local myRoot = mine and mine:FindFirstChild("HumanoidRootPart")
			local root = character:FindFirstChild("HumanoidRootPart")
			local from = if myRoot and myRoot:IsA("BasePart")
				then myRoot.Position
				else (Workspace.CurrentCamera :: Camera).CFrame.Position
			local at = if root and root:IsA("BasePart") then root.Position else from
			if (at - from).Magnitude <= (stats.cloakShimmer or 10) then
				-- A shimmer: flickers around the close alpha.
				target = (stats.cloakShimmerAlpha or 0.75)
					+ SHIMMER_DEPTH * math.sin(now * 2 * math.pi * SHIMMER_HZ)
					+ SHIMMER_DEPTH * 0.5 * math.sin(now * 2 * math.pi * SHIMMER_HZ * 2.7)
			else
				target = stats.cloakAlpha or 0.95
			end
		end
		-- Fades in over the dash itself, off over the last FADE_OUT seconds.
		local untilT = number(character, "DashUntil")
		local ramp = math.clamp((now - start) / math.max(untilT - start, 0.08), 0, 1)
		ramp = math.min(ramp, math.clamp((cloakUntil - now) / FADE_OUT, 0, 1))
		alpha = math.max(alpha, target * ramp)
		if alpha > 0 and revealed(character) then
			alpha = math.min(alpha, REVEALED_MAX)
		end
	end
	return math.clamp(alpha, 0, 0.98), cloaked and alpha > 0.5
end

-- Our own screen while we're the ghost, so you know it's running: the edge
-- shimmer for exactly the dodge window (it's gone the frame the protection
-- is), and for the cloak a thin line down each side with the colours turned
-- down a little (no tint), coming off over the cloak's fade-out.
local function stepCue(now: number)
	local character = player.Character
	local dodge = character ~= nil and now < select(1, DashMod.windows(character))
	local amount = 0
	if character then
		local start = number(character, "DashStart")
		local cloakUntil = select(2, DashMod.windows(character))
		if now >= start and now < cloakUntil then
			amount = math.min(
				math.clamp((now - start) / CLOAK_CUE.fadeIn, 0, 1),
				math.clamp((cloakUntil - now) / FADE_OUT, 0, 1)
			)
		end
	end
	WindStrokes.ghost(dodge, amount)
	local c = cue
	if amount <= 0 then
		if c then
			c.Enabled = false
		end
		return
	end
	if not c or not c.Parent then
		local made = Instance.new("ColorCorrectionEffect")
		made.Name = "DashCloakCue"
		made.Parent = Lighting
		c = made
		cue = made
	end
	local effect = c :: ColorCorrectionEffect
	effect.Enabled = true
	effect.Saturation = CLOAK_CUE.saturation * amount
end

-- Every frame (UpgradeFx/Dash).
function DashGhost.step()
	local now = time()
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if not character or other == player then
			continue
		end
		local alpha, cloaked = alphaFor(other, character, now)
		local s = shown[character]
		if alpha <= 0 and not s then
			continue
		end
		if not s then
			local made: Shown = {
				alpha = 0,
				display = nil,
				nextImage = 0,
				targets = {},
				dirty = true,
				added = nil,
			}
			made.added = character.DescendantAdded:Connect(function()
				made.dirty = true
			end)
			s = made
			shown[character] = made
		end
		local state = s :: Shown
		setAlpha(state, character, alpha)
		state.alpha = alpha
		-- Ghost afterimages while the dodge window is open.
		if now < (DashMod.windows(character)) and os.clock() >= state.nextImage then
			state.nextImage = os.clock() + TRAIL.every
			afterimage(character, TeamColor.forOwner(other))
		end
		-- The name tag goes with the body.
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if cloaked and not state.display then
				state.display = humanoid.DisplayDistanceType
				humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			elseif not cloaked and state.display then
				humanoid.DisplayDistanceType = state.display :: Enum.HumanoidDisplayDistanceType
				state.display = nil
			end
		end
		if alpha <= 0 then
			local added = state.added
			if added then
				added:Disconnect()
			end
			shown[character] = nil
		end
	end
	stepAfterimages()
	stepCue(now)
end

return DashGhost
