--!strict
-- Projectile building block (Molly, Lag Field). A thrown object's whole path
-- is computed once, deterministically, with fixed steps and raycasts: the
-- server does it from its own head position, and sends the result (a few
-- ballistic segments) to clients, which replay positionAt() exactly. The
-- client's arc preview runs the same simulate() with its own raycasts.

export type Segment = {
	t: number, -- seconds after the throw this segment starts
	p: Vector3, -- position at t
	v: Vector3, -- velocity at t
	rest: boolean, -- came to rest: stays at p
}

export type Path = {
	segments: { Segment },
	gravity: number,
	duration: number,
}

export type Options = {
	gravity: number,
	size: number, -- radius: a hit stops the centre this far off the surface
	bounces: number, -- bounces before it stops on the next contact (-1: stops on the first)
	restitution: number?, -- share of normal speed kept on a bounce (default 0.45)
	friction: number?, -- share of along-surface speed kept (default 0.7)
	duration: number, -- seconds to simulate
	-- Molly: it stops on the first surface facing up (walls still bounce),
	-- and after `dropAfter` seconds in the air it stops flying forward and
	-- drops straight down.
	groundStop: boolean?,
	dropAfter: number?,
}

local STEP = 1 / 60
local MAX_SEGMENTS = 8
local REST_SPEED = 8 -- slower than this after a bounce: it stops
local GROUND_NORMAL = 0.7 -- a surface this flat (normal.Y) is ground for groundStop

local Projectile = {}

Projectile.STEP = STEP

-- Throw velocity from an aim direction: tilted up by `lift`, at `speed`.
function Projectile.launch(aim: Vector3, speed: number, lift: number): Vector3
	local dir = aim + Vector3.new(0, lift, 0)
	if dir.Magnitude < 1e-3 then
		dir = Vector3.new(0, 1, 0)
	end
	return dir.Unit * speed
end

local function ballistic(seg: Segment, gravity: number, dt: number): Vector3
	if seg.rest then
		return seg.p
	end
	return seg.p + seg.v * dt + Vector3.new(0, -0.5 * gravity * dt * dt, 0)
end

function Projectile.simulate(
	origin: Vector3,
	velocity: Vector3,
	options: Options,
	params: RaycastParams
): Path
	local gravity = options.gravity
	local restitution = options.restitution or 0.45
	local friction = options.friction or 0.7
	local segments: { Segment } = { { t = 0, p = origin, v = velocity, rest = false } }
	local bounces = 0
	local pos, vel = origin, velocity
	local t = 0
	local dropAfter = options.dropAfter
	local dropped = false
	local steps = math.ceil(options.duration / STEP)
	for _ = 1, steps do
		-- Too long in the air: drop straight down from here (a new segment).
		if dropAfter and not dropped and t >= dropAfter and #segments < MAX_SEGMENTS - 1 then
			dropped = true
			vel = Vector3.new(0, math.min(vel.Y, 0), 0)
			table.insert(segments, { t = t, p = pos, v = vel, rest = false })
		end
		local nextVel = vel + Vector3.new(0, -gravity * STEP, 0)
		local nextPos = pos + vel * STEP + Vector3.new(0, -0.5 * gravity * STEP * STEP, 0)
		local delta = nextPos - pos
		local hit = if delta.Magnitude > 1e-4 then workspace:Raycast(pos, delta, params) else nil
		if hit then
			local frac = math.clamp(hit.Distance / delta.Magnitude, 0, 1)
			local hitT = t + STEP * frac
			local hitVel = vel + Vector3.new(0, -gravity * STEP * frac, 0)
			local normal = hit.Normal
			local at = hit.Position + normal * options.size
			bounces += 1
			local into = hitVel:Dot(normal)
			local normalPart = normal * into
			local along = hitVel - normalPart
			local bounced = along * friction - normalPart * restitution
			local ground = options.groundStop == true and normal.Y >= GROUND_NORMAL
			local stop = ground
				or bounces > options.bounces
				or bounced.Magnitude < REST_SPEED
				or #segments >= MAX_SEGMENTS - 1
			if stop and options.groundStop and not ground then
				-- groundStop: only a floor ends it. A wall that would stop it
				-- drops it straight down instead (leaving a segment free for
				-- the floor); out of segments, the path just ends (no rest).
				if #segments >= MAX_SEGMENTS - 2 then
					break
				end
				local fall = Vector3.new(0, math.min(bounced.Y, 0), 0)
				table.insert(segments, { t = hitT, p = at, v = fall, rest = false })
				pos, vel, t = at, fall, hitT
				continue
			end
			table.insert(
				segments,
				{ t = hitT, p = at, v = if stop then Vector3.zero else bounced, rest = stop }
			)
			if stop then
				break
			end
			pos, vel, t = at, bounced, hitT
		else
			pos, vel, t = nextPos, nextVel, t + STEP
		end
	end
	return { segments = segments, gravity = gravity, duration = options.duration }
end

-- When it stops moving: the time it came to rest, else the end of the path.
function Projectile.endTime(path: Path): number
	local last = path.segments[#path.segments]
	return if last.rest then last.t else path.duration
end

local HAND_FORWARD = 1.5 -- studs in front of the head a throw starts
local HAND_DROP = 0.35

-- A held throw (Molly, Lag Field): where it leaves the hand and its
-- velocity, from the head and the aim. LMB ("Primary") throws with
-- `throwSpeed` / `throwLift`, RMB ("Alt") lobs with `lobSpeed` / `lobLift`.
-- `params` (world only) keeps the start out of a wall you're facing.
function Projectile.throw(
	head: Vector3,
	aim: Vector3,
	mode: "Primary" | "Alt",
	stats: { [string]: any },
	params: RaycastParams
): (Vector3, Vector3)
	local offset = aim * HAND_FORWARD - Vector3.new(0, HAND_DROP, 0)
	local hit = workspace:Raycast(head, offset, params)
	local origin = if hit
		then head + offset.Unit * math.max(hit.Distance - stats.size, 0)
		else head + offset
	local lob = mode == "Alt"
	local speed = if lob then stats.lobSpeed else stats.throwSpeed
	local lift = if lob then stats.lobLift else stats.throwLift
	return origin, Projectile.launch(aim, speed, lift)
end

-- Where the projectile is `t` seconds after the throw.
function Projectile.positionAt(path: Path, t: number): Vector3
	local segs = path.segments
	local seg = segs[1]
	for i = 2, #segs do
		if segs[i].t <= t then
			seg = segs[i]
		else
			break
		end
	end
	return ballistic(seg, path.gravity, math.max(t - seg.t, 0))
end

-- A path in a remote-safe shape (arrays of plain values) and back. The client
-- side checks every field: it comes from the server, but cheap to be strict.
function Projectile.pack(path: Path): { any }
	local out = {}
	for _, s in path.segments do
		table.insert(out, { s.t, s.p, s.v, s.rest })
	end
	return { out, path.gravity, path.duration }
end

function Projectile.unpack(data: unknown): Path?
	if typeof(data) ~= "table" then
		return nil
	end
	local d = data :: { any }
	local raw, gravity, duration = d[1], d[2], d[3]
	if typeof(raw) ~= "table" or typeof(gravity) ~= "number" or typeof(duration) ~= "number" then
		return nil
	end
	local segments: { Segment } = {}
	for _, s in ipairs(raw :: { any }) do
		if typeof(s) ~= "table" or #segments >= MAX_SEGMENTS then
			return nil
		end
		local t, p, v, rest = s[1], s[2], s[3], s[4]
		if
			typeof(t) ~= "number"
			or typeof(p) ~= "Vector3"
			or typeof(v) ~= "Vector3"
			or typeof(rest) ~= "boolean"
		then
			return nil
		end
		table.insert(segments, { t = t, p = p, v = v, rest = rest })
	end
	if #segments == 0 then
		return nil
	end
	return { segments = segments, gravity = gravity, duration = duration }
end

return Projectile
