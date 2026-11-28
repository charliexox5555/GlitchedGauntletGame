--!strict
-- One gunshot's sounds, played the way the pro pack is built (its guide "How
-- To Setup Automatic Guns Sounds in Games", vault/02 Art/Sound Library Pick
-- §13). The same logic for your own gun (2D), a spectated player's (2D) and
-- everyone else's (3D at the muzzle):
--   - first shot: a sequence's opening shot (no shot for one fire interval +
--     Config/Audio FIRST_SHOT_GAP) plays the gun's `fireFirst` take;
--   - shots: every other shot plays one of the gun's numbered takes at random,
--     never the same twice in a row (AudioController), with a little random
--     pitch and level;
--   - tail: started WITH every shot, and the next shot fades the last one out
--     in a time set by the fire rate, so only the final tail rings on;
--   - last round: the shot that empties the mag plays `fireLast` (the pack's
--     last shot with its own tail) instead, and no separate tail.
-- State is kept per shooter (your gun slot, a character), so two guns or two
-- players never fade each other's tails.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Audio = require(ReplicatedStorage.Shared.Config.Audio)
local GunSounds = require(ReplicatedStorage.Shared.Config.GunSounds)
local ShadowMistAudio = require(ReplicatedStorage.Shared.Config.ShadowMistAudio)
local SlipframeAudio = require(ReplicatedStorage.Shared.Config.SlipframeAudio)
local FrostbiteAudio = require(ReplicatedStorage.Shared.Config.FrostbiteAudio)
local MoltframeAudio = require(ReplicatedStorage.Shared.Config.MoltframeAudio)
local PlaybackAudio = require(ReplicatedStorage.Shared.Config.PlaybackAudio)
local SundialAudio = require(ReplicatedStorage.Shared.Config.SundialAudio)
local RiftforgeAudio = require(ReplicatedStorage.Shared.Config.RiftforgeAudio)
local TempestAudio = require(ReplicatedStorage.Shared.Config.TempestAudio)
local SkinPreviewConfig = require(ReplicatedStorage.Shared.Config.SkinPreview)
local Types = require(ReplicatedStorage.Shared.Types)

local AudioController = require(script.Parent.Parent.Controllers.AudioController)

type WeaponConfig = Types.WeaponConfig

type Shooter = { lastShotAt: number, tail: AudioController.Handle? }

local GunAudio = {}

-- Per shooter (weak keys: a slot table or an Instance that goes away is dropped).
local shooters: { [any]: Shooter } = setmetatable({}, { __mode = "k" }) :: any

local function shooterOf(key: any): Shooter
	local s = shooters[key]
	if not s then
		s = { lastShotAt = -math.huge, tail = nil }
		shooters[key] = s
	end
	return s
end

-- How fast the last tail fades when the next shot comes: a share of the fire
-- interval, inside Config/Audio TAIL_FADE's limits.
local function tailFade(config: WeaponConfig): number
	local f = Audio.TAIL_FADE
	return math.clamp(config.fireInterval * f.share, f.min, f.max)
end

export type ShotOptions = {
	at: Vector3?, -- 3D at this point (other players); 2D when nil
	lastRound: boolean?, -- this shot empties the mag (only known for your own gun)
	shadowMist: boolean?, -- local Shadow Mist audition in Match Studio
	tempest: boolean?, -- the gun wears the Tempest-Strike line (its own designed shots)
	slipframe: boolean?, -- close action layer on the equipped player's camera gun
	moltframe: boolean?, -- subtle carapace / chamber layer on the equipped player's camera gun
	playback: boolean?, -- subtle cassette transport layer on the equipped player's camera gun
	sundial: boolean?, -- subtle brass escapement layer on the equipped player's camera gun
	riftforge: boolean?, -- heavy industrial plasma layer on the equipped player's camera gun
	frostbite: boolean?, -- crystalline ice layer on the equipped player's camera gun
}

-- Plays one shot of `config`'s gun for `key` (one per shooter).
function GunAudio.shot(key: any, config: WeaponConfig, options: ShotOptions?)
	local o: ShotOptions = options or {}
	local set = GunSounds.get(config.id)
	local st = shooterOf(key)
	local now = os.clock()
	local first = now - st.lastShotAt > config.fireInterval + Audio.FIRST_SHOT_GAP
	st.lastShotAt = now
	local group: AudioController.Group = if o.at then "Enemy" else "Gun"

	-- The next shot fades the last tail (the pack's "correct way").
	AudioController.fadeOut(st.tail, tailFade(config))
	st.tail = nil

	local skin = if o.shadowMist and not o.at then ShadowMistAudio.reports[config.id] else nil
	if skin then
		local last = o.lastRound == true and skin.fireLast ~= nil
		local skinShot = if last
			then skin.fireLast
			elseif first and skin.fireFirst then skin.fireFirst
			else skin.fire
		if AudioController.playSound(skinShot, "Gun") then
			if skin.tail and not last then
				st.tail = AudioController.playSound(skin.tail, "Gun")
			end
			return
		end
		local audition = SkinPreviewConfig.SHADOW_MIST.SHOT_PREVIEW
		if config.id == "Vandal" and AudioController.isPreloaded(audition) then
			AudioController.play(audition, { group = "Gun", volume = 1, jitter = false })
			return
		end
	end

	-- A Tempest-Strike gun (Config/TempestAudio.guns, design_tempest_vandal.py /
	-- design_tempest_line.py): its own designed takes; other players hear its far
	-- take with the stock tail. Sets without a first / last / tail take use the
	-- plain shot (those guns' shots carry their own decay).
	local tempest = if o.tempest then TempestAudio.guns[config.id] else nil
	if tempest and tempest.fire then
		if o.at then
			AudioController.playSound(tempest.fireFar or tempest.fire, group, o.at)
			if set.tail then
				st.tail = AudioController.playSound(set.tail, group, o.at)
			end
			return
		end
		local last = o.lastRound == true and tempest.fireLast ~= nil
		local skinShot = if last
			then tempest.fireLast
			elseif first and tempest.fireFirst then tempest.fireFirst
			else tempest.fire
		if AudioController.playSound(skinShot, "Gun") then
			if not last and tempest.tail then
				st.tail = AudioController.playSound(tempest.tail, "Gun")
			end
			return
		end
	end

	-- Riftforge Legendary line (Config/RiftforgeAudio.guns, design_riftforge_v2.py):
	-- full replacement heavy industrial dark-matter plasma shots + tail; other players
	-- hear its far take with the stock tail.
	local riftforge = if o.riftforge then RiftforgeAudio.guns[config.id] else nil
	if riftforge and riftforge.fire then
		if o.at then
			AudioController.playSound(riftforge.fireFar or riftforge.fire, group, o.at)
			if set.tail then
				st.tail = AudioController.playSound(set.tail, group, o.at)
			end
			return
		end
		local last = o.lastRound == true and riftforge.fireLast ~= nil
		local skinShot = if last
			then riftforge.fireLast
			elseif first and riftforge.fireFirst then riftforge.fireFirst
			else riftforge.fire
		if AudioController.playSound(skinShot, "Gun") then
			if not last and riftforge.tail then
				st.tail = AudioController.playSound(riftforge.tail, "Gun")
			end
			return
		end
	end

	local last = o.lastRound == true and set.fireLast ~= nil
	local shot = if last
		then set.fireLast
		elseif first and set.fireFirst then set.fireFirst
		elseif o.at then set.fireFar
		else set.fire
	-- 3D: suppressed guns carry a shorter way (Config/Audio SUPPRESSED_RANGE).
	local range = if o.at and config.suppressed then Audio.SUPPRESSED_RANGE else nil
	AudioController.playSound(shot, group, o.at, nil, nil, range)
	if o.slipframe and not o.at then
		AudioController.playSound(SlipframeAudio.shots[config.id], "Gun")
	elseif o.moltframe and not o.at then
		AudioController.playSound(MoltframeAudio.shots[config.id], "Gun")
	elseif o.playback and not o.at then
		AudioController.playSound(PlaybackAudio.shots[config.id], "Gun")
	elseif o.sundial and not o.at then
		AudioController.playSound(SundialAudio.shots[config.id], "Gun")
	elseif o.riftforge and not o.at then
		AudioController.playSound(RiftforgeAudio.shots[config.id], "Gun")
	elseif o.frostbite and not o.at then
		AudioController.playSound(FrostbiteAudio.shots[config.id], "Gun")
	end
	if set.tail and not last then
		st.tail = AudioController.playSound(set.tail, group, o.at, nil, nil, range)
	end
end

-- Forget a shooter's state (e.g. on weapon swap the old tail rings out).
function GunAudio.reset(key: any)
	shooters[key] = nil
end

return GunAudio
