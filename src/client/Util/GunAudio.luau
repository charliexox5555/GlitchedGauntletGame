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

	local last = o.lastRound == true and set.fireLast ~= nil
	local shot = if last
		then set.fireLast
		elseif first and set.fireFirst then set.fireFirst
		elseif o.at then set.fireFar
		else set.fire
	-- 3D: suppressed guns carry a shorter way (Config/Audio SUPPRESSED_RANGE).
	local range = if o.at and config.suppressed then Audio.SUPPRESSED_RANGE else nil
	AudioController.playSound(shot, group, o.at, nil, nil, range)
	if set.tail and not last then
		st.tail = AudioController.playSound(set.tail, group, o.at, nil, nil, range)
	end
end

-- Forget a shooter's state (e.g. on weapon swap the old tail rings out).
function GunAudio.reset(key: any)
	shooters[key] = nil
end

return GunAudio
