--!strict
-- The lobby's main music (Config/Audio LOBBY_MUSIC, owner 2026-11-22): one
-- looped track while the player walks the lobby, faded out in the range and
-- pad duels (Shared/PlayZone) and back in when they return. Plays through
-- the Settings MUSIC group (Shared/SettingsApply), so MASTER and MUSIC set it.
-- The lobby client only runs in lobby servers, so match servers never hear it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Audio = require(ReplicatedStorage.Shared.Config.Audio)
local PlayZone = require(ReplicatedStorage.Shared.PlayZone)
local SettingsApply = require(ReplicatedStorage.Shared.SettingsApply)

local LobbyMusic = {}

local player = Players.LocalPlayer
local MUSIC = Audio.LOBBY_MUSIC

local sound: Sound? = nil
local fade: Tween? = nil

local function setPlaying(on: boolean)
	local s = sound
	if not s then
		return
	end
	if fade then
		fade:Cancel()
	end
	if on then
		if not s.IsPlaying then
			s.Volume = 0
			s:Resume()
		end
		fade = TweenService:Create(s, TweenInfo.new(MUSIC.fadeIn), { Volume = MUSIC.volume })
	else
		fade = TweenService:Create(s, TweenInfo.new(MUSIC.fadeOut), { Volume = 0 })
		local t = fade :: Tween
		t.Completed:Once(function(state: Enum.PlaybackState)
			if state == Enum.PlaybackState.Completed then
				s:Pause()
			end
		end)
	end
	local t = fade :: Tween
	t:Play()
end

local function refresh()
	setPlaying(not PlayZone.isArmed(player))
end

function LobbyMusic.init()
	local s = Instance.new("Sound")
	s.Name = "LobbyMusic"
	s.SoundId = MUSIC.id
	s.Looped = true
	s.Volume = 0
	s.SoundGroup = SettingsApply.musicGroup()
	s.Parent = SoundService
	sound = s
end

function LobbyMusic.start()
	player:GetAttributeChangedSignal(PlayZone.ATTRIBUTE):Connect(refresh)
	refresh()
end

return LobbyMusic
