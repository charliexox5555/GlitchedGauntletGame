--!strict
-- Mod sound playback (Config/ModSounds). One-shots go through
-- AudioController (2D for you, 3D at a point for everyone else, in the Foley
-- group); hums (`loop` cues) are pooled Sounds parented to the thing that
-- hums (a pad, the healed player, the overclocked gun) and faded out.

local TweenService = game:GetService("TweenService")

local ModSounds = require(game:GetService("ReplicatedStorage").Shared.Config.ModSounds)

local AudioController = require(script.Parent.Parent.Controllers.AudioController)

local ModAudio = {}

export type Hum = { sound: Sound, holder: Attachment, id: string, stopped: boolean }

local FADE_IN = TweenInfo.new(0.2)
local FADE_OUT = TweenInfo.new(0.35)

local free: { [string]: { Sound } } = {}

-- A one-shot: 2D when `at` is nil, else 3D there. `pitch` multiplies the cue's.
function ModAudio.play(cue: ModSounds.Cue?, at: Vector3?, pitch: number?)
	if not cue then
		return
	end
	AudioController.play(cue.id, {
		group = if at then "Foley" else "Feedback",
		volume = cue.volume,
		pitch = (cue.pitch or 1) * (pitch or 1),
		at = at,
		range = cue.range,
		cut = cue.cut,
	})
end

-- A hum on `holder` (a BasePart or Attachment: 3D there) until stopHum.
function ModAudio.hum(cue: ModSounds.Cue?, holder: Instance?): Hum?
	if not cue or not holder then
		return nil
	end
	local list = free[cue.id]
	local sound = list and table.remove(list)
	if not sound then
		local s = Instance.new("Sound")
		s.SoundId = cue.id
		s.Looped = true
		s.RollOffMinDistance = 10
		s.RollOffMaxDistance = 120
		sound = s
	end
	local s = sound :: Sound
	s.PlaybackSpeed = cue.pitch or 1
	s.Volume = 0
	-- Our own Attachment on the holder: if the holder is destroyed, only the
	-- attachment and this Sound go (the Sound isn't returned to the pool).
	local a = Instance.new("Attachment")
	a.Name = "ModHum"
	a.Parent = holder
	s.Parent = a
	s:Play()
	TweenService:Create(s, FADE_IN, { Volume = cue.volume }):Play()
	return { sound = s, holder = a, id = cue.id, stopped = false }
end

function ModAudio.stopHum(hum: Hum?)
	if not hum or hum.stopped then
		return
	end
	hum.stopped = true
	local s = hum.sound
	local tween = TweenService:Create(s, FADE_OUT, { Volume = 0 })
	tween.Completed:Once(function()
		local ok = pcall(function()
			s:Stop()
			s.Parent = nil
		end)
		pcall(function()
			hum.holder:Destroy()
		end)
		if not ok then
			return -- destroyed with its holder
		end
		local list = free[hum.id]
		if not list then
			list = {}
			free[hum.id] = list
		end
		table.insert(list, s)
	end)
	tween:Play()
end

ModAudio.SOUNDS = ModSounds

return ModAudio
