--!strict
-- What others see when someone fires: the recoil goes through the body, not
-- only the gun (vault/01 Design/Third Person Overhaul.md §23). Called by
-- Controllers/EffectsController for every shot of another player, bot or
-- range dummy, beside the gun's own kick in the hand.
--
-- Each hold pose (hip and sights, long gun and pistol, looking up / level /
-- down) has a recoil pose: the gun pulled into the shoulder, its muzzle up,
-- the chest rocked back and its gun-side shoulder turned back, the head still
-- (Config/Animations RECOIL; made by tools/anim/tp_clips.py). A shot pushes a
-- spring; while it is live, every hold track playing on that character gets
-- its recoil track played over it (Action2) at the hold's own weight times
-- the spring. So the body moves hold + spring x (recoil - hold), at any pitch
-- and any blend of hip and sights, with nothing restarted per shot.
--
-- Why clips and not code (measured 2026-11-15): a joint Transform written
-- from a script does not stick on these AnimationConstraint rigs, and an
-- IKControl pulling the arm back jumped the hand 2.5 studs in a frame.
--
-- The tracks are played on this client only (local tracks on someone else's
-- Animator don't replicate). Your own character is skipped: its tracks would
-- replicate, and every watcher already plays this for you.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animations = require(ReplicatedStorage.Shared.Config.Animations)
local Juice = require(ReplicatedStorage.Shared.Config.Juice)
local Types = require(ReplicatedStorage.Shared.Types)

local ViewmodelMotion = require(script.Parent.ViewmodelMotion)

type WeaponConfig = Types.WeaponConfig

local BodyRecoil = {}

local B = Juice.BODY_KICK
local OFF = 0.001 -- a playing track's lowest weight (0 would drop it)

-- The asset number of an animation id ("rbxassetid://123" and the like).
local function assetNumber(id: string): string
	return string.match(id, "%d+$") or id
end

-- A hold's asset number -> its recoil pose's animation id.
local recoilOf: { [string]: string } = {}
for hold, recoilId in Animations.RECOIL do
	local holdId = (Animations.POSES :: { [string]: string })[hold]
		or (Animations.COMBAT :: { [string]: string })[hold]
	if holdId and holdId ~= "" and recoilId ~= "" then
		recoilOf[assetNumber(holdId)] = recoilId
	end
end

local animations: { [string]: Animation } = {}

type Rig = {
	animator: Animator,
	x: number, -- the spring: 0 at rest, about the gun's weight at one shot's peak
	v: number,
	cap: number,
	tracks: { [string]: AnimationTrack }, -- by recoil animation id
	used: { [string]: boolean },
}

local rigs: { [Animator]: Rig } = {}

local function trackFor(rig: Rig, recoilId: string): AnimationTrack
	local track = rig.tracks[recoilId]
	if not track then
		local animation = animations[recoilId]
		if not animation then
			animation = Instance.new("Animation")
			animation.Name = "BodyRecoil"
			animation.AnimationId = recoilId
			animations[recoilId] = animation
		end
		track = rig.animator:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Action2
		track.Looped = true
		rig.tracks[recoilId] = track
	end
	return track
end

local function rest(rig: Rig)
	rig.x = 0
	rig.v = 0
	for _, track in rig.tracks do
		if track.IsPlaying then
			track:Stop(0)
		end
	end
end

-- One shot from `character` with `config`.
function BodyRecoil.shot(character: Model?, config: WeaponConfig)
	if not character or config.melee then
		return
	end
	if Players:GetPlayerFromCharacter(character) == Players.LocalPlayer then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local rig = rigs[animator]
	if not rig then
		local new: Rig = { animator = animator, x = 0, v = 0, cap = 0, tracks = {}, used = {} }
		rig = new
		rigs[animator] = new
		animator.Destroying:Once(function()
			rigs[animator] = nil
		end)
	end
	local active = rig :: Rig
	local peak = B.gun[config.id] or B.weight[config.class] or B.default
	-- A push, not a jump: this spring, pushed by v from rest, swells to
	-- v / (frequency x e) about 1 / frequency seconds later.
	active.v += peak * B.frequency * math.exp(1)
	active.cap = math.min(peak * B.hold, B.max)
end

function BodyRecoil.step(dt: number)
	for animator, rig in rigs do
		if rig.x == 0 and rig.v == 0 then
			continue
		end
		if not animator.Parent then
			rigs[animator] = nil
			continue
		end
		local x, v = ViewmodelMotion.spring(rig.x, rig.v, 0, B.frequency, dt)
		if x > rig.cap then
			-- Held fire: ride at the cap instead of winding up.
			x = rig.cap
			v = math.min(v, 0)
		end
		rig.x, rig.v = x, v
		if x < 2e-3 and math.abs(v) < 2e-2 then
			rest(rig)
			continue
		end
		-- Over every hold that is playing, its recoil pose at the same share.
		table.clear(rig.used)
		for _, hold in animator:GetPlayingAnimationTracks() do
			local animation = hold.Animation
			local recoilId = animation and recoilOf[assetNumber(animation.AnimationId)]
			if recoilId and hold.WeightCurrent > 0.01 then
				local track = trackFor(rig, recoilId)
				if not track.IsPlaying then
					track:Play(0, OFF)
				end
				track:AdjustWeight(math.max(hold.WeightCurrent * x, OFF), 0)
				rig.used[recoilId] = true
			end
		end
		for recoilId, track in rig.tracks do
			if not rig.used[recoilId] and track.IsPlaying then
				track:AdjustWeight(OFF, 0)
			end
		end
	end
end

return BodyRecoil
