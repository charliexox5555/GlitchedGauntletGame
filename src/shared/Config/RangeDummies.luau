--!strict
-- The lobby range's training bots (vault/01 Design/Range v5.md). Owner, 2026-11-25: "they need animations for
-- getting hit", "I want more of them"; then, after a glowing gold/blue pass: "glowing way too much. I want it to just
-- be the regular roblox r15 blocky character. And the whole thing should be the same blue. and have a better idle
-- animation". Used by shared/RangeDummyLook (the look, server), LobbyServer Range/RangeBots (the clips, strafing,
-- the damage dummy, the moving carriage) and the client's DummyLifeController (hit reactions, the pulse). Times are
-- seconds, distances studs, angles degrees.

local Animations = require(script.Parent.Animations)

local RangeDummies = {}

-- Every body part, head included: one matte blue (SmoothPlastic, no glow).
RangeDummies.COLOR = Color3.fromRGB(52, 118, 226)

-- The clips the server plays on every bot: the game's own third-person set, so a dummy moves like a player in the
-- lobby (Config/Animations: the Core idle under the unarmed upper body; the strafers' side runs).
RangeDummies.CLIPS = table.freeze({
	idle = Animations.ANIMATE.idle, -- the whole-body Core idle
	upper = Animations.POSES.UnarmedIdle, -- arms and chest, nothing in hand
	runL = Animations.LOCOMOTION.RunL,
	runR = Animations.LOCOMOTION.RunR,
	upperRun = Animations.POSES.UnarmedRun,
	runSpeed = Animations.RUN_SPEED, -- studs/s the run clips are made for
})

-- Life on top of the idle clip (client): each bot looks about now and then, on its own timer.
RangeDummies.IDLE = table.freeze({
	look = { 2.5, 6 }, -- s between head turns (min, max)
	lookYaw = 22, -- deg at most
	lookPitch = 5,
	lookSpeed = 4, -- 1/s the head follows its target
})

-- Hit reactions (client). Each axis is a damped spring kicked by a hit
-- (Animation Oomph: snap, brake, overshoot, settle). `frequency` in Hz,
-- `damping` 0..1 (1 = no overshoot). Kicks are degrees per hit at
-- `fullDamage` damage, clamped at `maxScale` of that.
export type SpringSpec = { frequency: number, damping: number }
RangeDummies.REACT = table.freeze({
	fullDamage = 40,
	maxScale = 1.6,
	minScale = 0.45, -- a 5-damage tap still reads
	torso = table.freeze({ frequency = 2.4, damping = 0.4 }) :: SpringSpec,
	head = table.freeze({ frequency = 3.2, damping = 0.36 }) :: SpringSpec,
	arms = table.freeze({ frequency = 2.2, damping = 0.36 }) :: SpringSpec,
	legs = table.freeze({ frequency = 3.0, damping = 0.5 }) :: SpringSpec,
	-- Body shot: the chest is pushed away from the shooter and twists toward
	-- the side that was hit; the arms fly up a little and the knees give.
	bodyPitch = 22,
	bodyTwist = 16,
	bodyRoll = 10,
	bodyHead = 10, -- the head lags the chest
	bodyArms = 24,
	bodyKnees = 12,
	-- Headshot: the head snaps back hard, the chest follows a bit.
	headPitch = 46,
	headTwist = 22,
	headChest = 10,
	headArms = 30,
	-- Repeated hits stack, but never past this many degrees on any joint.
	limit = 70,
	-- Measured in play (2026-11-25): at head 4.8 Hz a headshot's whole swing
	-- was over in ~0.2 s, too quick to read; these frequencies give ~0.35 s.
})

-- The pulse on every hit (client): the body flashes toward white, then settles back (ease out). A headshot flashes
-- harder; a kill flashes white.
RangeDummies.PULSE = table.freeze({
	body = 0.45, -- mix toward white at the hit
	head = 0.7,
	kill = 1,
	time = 0.2,
	killTime = 0.3,
})

-- A bot coming back (server stamps `Respawned`): it materialises from white
-- and pops up out of a crouch.
RangeDummies.SPAWN = table.freeze({
	time = 0.45,
	drop = 0.9, -- studs it starts sunk
})

-- Strafers (`Behaviour = "Strafe"` on the bot): walk left and right of their
-- spot, ADAD-style, like a player.
RangeDummies.STRAFE = table.freeze({
	speed = 12,
	sway = 6, -- default; a bot's `Sway` attribute overrides
	turnAfter = { 0.45, 1.3 },
	blend = 8, -- 1/s the run clips fade in and out with the ground speed (server)
})

-- The damage dummy (tag RangeDamageDummy): never falls, counts damage up. The
-- board above it resets after `resetAfter` seconds without a hit.
RangeDummies.DAMAGE_DUMMY = table.freeze({
	resetAfter = 4,
	dpsWindow = 3, -- seconds of hits the DPS figure averages
	floorHp = 1, -- it never drops below this
})

-- The moving dummy (tag RangeMovingDummy on its carriage; From/To/Speed
-- attributes are world X). Server and clients both place it from the server
-- clock, so it glides on every screen and hits are checked where it is.
RangeDummies.CARRIAGE = table.freeze({
	pause = 0.6, -- s it waits at each end (each run eases in and out)
})

RangeDummies.RESPAWN = 2.5 -- s a downed bot stays down

return table.freeze(RangeDummies)
