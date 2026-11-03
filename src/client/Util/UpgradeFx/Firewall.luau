--!strict
-- Firewall's upgrade levels on the client (vault/01 Design/Abilities/Upgrade
-- Paths.md): what the A / B / glitch levels look and sound like.
--
-- A (Short Wall) and B (Long Wall) only change numbers: Util/WallFx dresses
-- any length, the HUD shows the recharge. G (Frost Wall) is ice: the wall
-- itself is Util/FrostWallFx (WallFx hands it the WallKind "Frost" pieces);
-- here, the cast reads cold (a cold blast at the caster instead of the
-- fire whoosh) and our own first-person hand frosts over instead of burning
-- (ViewmodelController's HandFlame, restyled while the Firewall we have is
-- the ice wall).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Mods)
local ModSounds = require(ReplicatedStorage.Shared.Config.ModSounds)
local VFX = require(ReplicatedStorage.Shared.Config.VfxTextures)

local FrostWallFx = require(script.Parent.Parent.FrostWallFx)
local ModAudio = require(script.Parent.Parent.ModAudio)
local ModVfx = require(script.Parent.Parent.ModVfx)
local Types = require(script.Parent.Types)

local player = Players.LocalPlayer

local ICE = FrostWallFx.ICE
local FIRE_LIGHT = Color3.fromRGB(255, 150, 70) -- ViewmodelController's hand light

local handler: Types.Handler = {}

-- Whether a slot of ours holds the Firewall's ice wall.
local function frostOurs(): boolean
	for slot = 1, Config.SLOTS do
		if
			player:GetAttribute("Mod" .. slot .. "Id") == "Firewall"
			and FrostWallFx.isFrost(player:GetAttribute("Mod" .. slot .. "Level"))
		then
			return true
		end
	end
	return false
end

handler.onFx = function(kind: string, data: { [string]: any }): boolean
	if kind ~= "FirewallCast" or data.id ~= "Firewall" or not FrostWallFx.isFrost(data.level) then
		return false
	end
	-- Ours is played on the press (ModController).
	if data.caster ~= player and typeof(data.at) == "Vector3" then
		ModAudio.play(ModSounds.FirewallFrost.cast, data.at)
		ModVfx.burst(data.at, ICE, 8, "Sparkle")
	end
	return true
end

-- Our hand: the flame emitter becomes cold vapour falling off the hand,
-- with glints, and the warm light goes icy (back to fire otherwise).
local styled: ParticleEmitter? = nil
local glints: ParticleEmitter? = nil

local function restyle(e: ParticleEmitter, frost: boolean)
	local part = e.Parent
	local light = part and part:FindFirstChildOfClass("PointLight")
	if frost then
		e.Texture = VFX.FROST_MIST_2x2
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		e.Color = ColorSequence.new(ICE)
		e.Acceleration = Vector3.new(0, -1.2, 0)
		e.LightEmission = 0.3
		if light then
			light.Color = ICE
		end
		if part and not glints then
			local g = Instance.new("ParticleEmitter")
			g.Name = "FrostGlints"
			g.Texture = VFX.FROST_SHARD
			g.Color = ColorSequence.new(Color3.new(1, 1, 1), ICE)
			g.Lifetime = NumberRange.new(0.2, 0.45)
			g.Speed = NumberRange.new(0.2, 0.6)
			g.SpreadAngle = Vector2.new(180, 180)
			g.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.3, 0.18),
				NumberSequenceKeypoint.new(1, 0),
			})
			g.Rotation = NumberRange.new(0, 360)
			g.LightEmission = 1
			g.LightInfluence = 0
			g.LockedToPart = true
			g.Rate = 0
			g.Parent = part
			glints = g
		end
	else
		e.Texture = VFX.MOLLY_FLAME_4x4
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		e.FlipbookMode = Enum.ParticleFlipbookMode.Loop
		e.Color = ColorSequence.new(Color3.new(1, 1, 1))
		e.Acceleration = Vector3.zero
		e.LightEmission = 0.7
		if light then
			light.Color = FIRE_LIGHT
		end
		local g = glints
		if g then
			g:Destroy()
			glints = nil
		end
	end
end

handler.step = function(_dt: number)
	local cam = Workspace.CurrentCamera
	local part = cam and cam:FindFirstChild("HandFlame")
	local found = part and part:FindFirstChild("ParticleEmitter") -- the flame (not our glints)
	local e = if found and found:IsA("ParticleEmitter") then found else nil
	if not e then
		styled = nil
		glints = nil
		return
	end
	local frost = frostOurs()
	local isStyled = styled == e
	if frost ~= isStyled then
		restyle(e, frost)
		styled = if frost then e else nil
	end
	local g = glints
	if g then
		g.Rate = if e.Rate > 0 then 14 else 0
	end
end

return handler
