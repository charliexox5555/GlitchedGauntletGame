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
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Mods)
local DashMod = require(ReplicatedStorage.Shared.Mods.Dash)
local Mods = require(ReplicatedStorage.Shared.Mods)
local Teams = require(ReplicatedStorage.Shared.Mods.Teams)

local TeamColor = require(script.Parent.Parent.TeamColor)
local WindStrokes = require(script.Parent.Parent.WindStrokes)

local DashGhost = {}

local player = Players.LocalPlayer

local AFTERIMAGE_EVERY = 0.06 -- seconds between Ghost afterimages
local AFTERIMAGE_LIFE = 0.3
local AFTERIMAGE_ALPHA = 0.55 -- transparency at birth
local SHIMMER_HZ = 9 -- the close-enemy flicker
local SHIMMER_DEPTH = 0.12 -- +- around cloakShimmerAlpha
local FADE_OUT = 0.15 -- seconds the cloak takes to come off
local REVEALED_MAX = 0.6 -- a revealed (Recon) dasher is never more see-through
local CLOAK_CUE = Config.WIND_FEEL.ghost.cloak

type Shown = {
	alpha: number,
	display: Enum.HumanoidDisplayDistanceType?, -- the name tag we hid
	nextImage: number,
}
local shown: { [Model]: Shown } = setmetatable({}, { __mode = "k" }) :: any

type Afterimage = { parts: { BasePart }, born: number }
local afterimages: { Afterimage } = {}

local folder: Folder? = nil
local cue: ColorCorrectionEffect? = nil

local function number(inst: Instance, name: string): number
	local v = inst:GetAttribute(name)
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
		if owner:GetAttribute("Mod" .. slot .. "Id") == "Dash" then
			local level = owner:GetAttribute("Mod" .. slot .. "Level")
			return if typeof(level) == "string" then Mods.stats("Dash", level) else nil
		end
	end
	return nil
end

local function setAlpha(character: Model, alpha: number)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = alpha
		end
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

-- A team-tinted ForceField copy of the body where it is now, fading out.
local function afterimage(character: Model, color: Color3)
	local parts: { BasePart } = {}
	local parent = fxFolder()
	for _, d in character:GetDescendants() do
		if not d:IsA("BasePart") or d.Transparency >= 1 or d.Name == "HumanoidRootPart" then
			continue
		end
		local ok, copy = pcall(d.Clone, d)
		if not ok or not copy then
			continue
		end
		local part = copy :: BasePart
		part:ClearAllChildren() -- welds would tie the copy to the body
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.ForceField
		part.Color = color
		part.Transparency = AFTERIMAGE_ALPHA
		part.LocalTransparencyModifier = 0
		part.CFrame = d.CFrame
		part.Parent = parent
		table.insert(parts, part)
	end
	table.insert(afterimages, { parts = parts, born = os.clock() })
end

local function stepAfterimages()
	local now = os.clock()
	for i = #afterimages, 1, -1 do
		local a = afterimages[i]
		local k = (now - a.born) / AFTERIMAGE_LIFE
		if k >= 1 then
			for _, p in a.parts do
				p:Destroy()
			end
			table.remove(afterimages, i)
		else
			local alpha = AFTERIMAGE_ALPHA + (1 - AFTERIMAGE_ALPHA) * k
			for _, p in a.parts do
				p.Transparency = alpha
			end
		end
	end
end

-- How see-through `character` (owned by `owner`) is to us right now, and
-- whether it's a cloak (name tag hidden).
local function alphaFor(owner: Player, character: Model, now: number): (number, boolean)
	local dodgeUntil = select(1, DashMod.windows(character))
	local cloakUntil = select(2, DashMod.windows(character))
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
			s = { alpha = 0, display = nil, nextImage = 0 }
			shown[character] = s
		end
		local state = s :: Shown
		setAlpha(character, alpha)
		state.alpha = alpha
		-- Ghost afterimages while the dodge window is open.
		if now < select(1, DashMod.windows(character)) and os.clock() >= state.nextImage then
			state.nextImage = os.clock() + AFTERIMAGE_EVERY
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
			shown[character] = nil
		end
	end
	stepAfterimages()
	stepCue(now)
end

return DashGhost
