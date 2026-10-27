--!strict
-- Dropped mags: on a reload the gun's own mag is hidden as it leaves the gun
-- and a copy falls from where it was, bounces once, lies on the floor and
-- fades (Viewmodel.MAG_DROP). Copies are pooled per gun and flown by hand
-- (anchored, no physics ownership or collision groups needed), like casings.
--
-- When the mag leaves and the new one arrives is read off the reload clip
-- itself: it leaves at the first frame its bone is MAG_DROP.away from rest and
-- the new mag is the one at the bone's furthest point (agreed with the Blender
-- session: one clean out-then-back trip per clip).

local Workspace = game:GetService("Workspace")

local VM = require(game:GetService("ReplicatedStorage").Shared.Config.Viewmodel)

local MagDrop = {}

local GRAVITY = Vector3.new(0, -VM.MAG_DROP.gravity, 0)

type Clip = { frames: number, bones: { [string]: { number } } }

export type Timing = { outAt: number, inAt: number }

type Drop = {
	model: Model,
	parts: { BasePart },
	offsets: { CFrame }, -- each part relative to the drop's frame
	base: { number }, -- each part's own transparency
	active: boolean,
	age: number,
	position: Vector3,
	rotation: CFrame,
	velocity: Vector3,
	axis: Vector3,
	spin: number,
	bounced: boolean,
	resting: boolean,
}

local pools: { [string]: { Drop } } = {}
local active = 0
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true

local timingCache: { [Clip]: { [string]: Timing | false } } = {}

-- When (0..1 through `clip`) the mag on `bone` leaves and the new one shows.
-- nil if the bone never moves far enough (a tap, or no mag change).
function MagDrop.timing(clip: Clip, bone: string): Timing?
	local perClip = timingCache[clip]
	if not perClip then
		perClip = {}
		timingCache[clip] = perClip
	end
	local cached = perClip[bone]
	if cached ~= nil then
		return cached or nil
	end
	local data = clip.bones[bone]
	local result: Timing | false = false
	if data and clip.frames > 1 then
		local outFrame: number? = nil
		local peakFrame, peak = 0, 0
		for f = 0, clip.frames - 1 do
			local i = f * 7
			local d = Vector3.new(data[i + 1], data[i + 2], data[i + 3]).Magnitude
			if not outFrame and d > VM.MAG_DROP.away then
				outFrame = f
			end
			if d > peak then
				peak, peakFrame = d, f
			end
		end
		if outFrame and peakFrame > outFrame then
			local last = clip.frames - 1
			result = { outAt = outFrame / last, inAt = peakFrame / last }
		end
	end
	perClip[bone] = result
	return result or nil
end

local function build(parts: { BasePart }): Drop?
	local first = parts[1]
	if not first then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "DroppedMag"
	local copies: { BasePart } = {}
	local offsets: { CFrame } = {}
	local base: { number } = {}
	local origin = first.CFrame
	for _, p in parts do
		local c = p:Clone()
		for _, child in c:GetChildren() do
			if not child:IsA("DataModelMesh") and not child:IsA("SurfaceAppearance") then
				child:Destroy()
			end
		end
		c.Anchored = true
		c.CanCollide = false
		c.CanQuery = false
		c.CanTouch = false
		c.CastShadow = true
		c.LocalTransparencyModifier = 0
		c.Parent = model
		table.insert(copies, c)
		table.insert(offsets, origin:ToObjectSpace(p.CFrame))
		table.insert(base, p.Transparency)
	end
	return {
		model = model,
		parts = copies,
		offsets = offsets,
		base = base,
		active = false,
		age = 0,
		position = Vector3.zero,
		rotation = CFrame.identity,
		velocity = Vector3.zero,
		axis = Vector3.xAxis,
		spin = 0,
		bounced = false,
		resting = false,
	}
end

local function place(d: Drop)
	local cf = CFrame.new(d.position) * d.rotation
	for i, p in d.parts do
		p.CFrame = cf * d.offsets[i]
	end
end

-- Drops a copy of `parts` (the gun's mag, as they are now) for gun `key`.
-- `velocity`: the gun's own motion at that moment (studs/s), added to the fall.
function MagDrop.drop(key: string, parts: { BasePart }, velocity: Vector3?)
	local first = parts[1]
	if not first then
		return
	end
	local pool = pools[key]
	if not pool then
		pool = {}
		pools[key] = pool
	end
	-- A free copy, else a new one, else recycle the oldest.
	local d: Drop? = nil
	for _, candidate in pool do
		if not candidate.active then
			d = candidate
			break
		end
	end
	if not d then
		if #pool < VM.MAG_DROP.poolPerGun then
			d = build(parts)
			if d then
				table.insert(pool, d)
			end
		else
			local oldest = pool[1]
			for _, candidate in pool do
				if candidate.age > oldest.age then
					oldest = candidate
				end
			end
			d = oldest
			active -= 1
		end
	end
	if not d then
		return
	end
	-- Copies follow the live part sizes (the viewmodel's scale can differ).
	local origin = first.CFrame
	for i, p in parts do
		d.parts[i].Size = p.Size
		d.offsets[i] = origin:ToObjectSpace(p.CFrame)
	end
	d.active = true
	d.age = 0
	d.position = origin.Position
	d.rotation = origin.Rotation
	d.velocity = (velocity or Vector3.zero) + Vector3.new(0, -VM.MAG_DROP.kick, 0)
	d.axis = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
	d.spin = (math.random() * 2 - 1) * VM.MAG_DROP.spin
	d.bounced = false
	d.resting = false
	for i, p in d.parts do
		p.Transparency = d.base[i]
	end
	place(d)
	d.model.Parent = Workspace
	active += 1
end

function MagDrop.step(dt: number)
	if active <= 0 then
		return
	end
	local cfg = VM.MAG_DROP
	local character = game:GetService("Players").LocalPlayer.Character
	params.FilterDescendantsInstances = if character
		then { character, Workspace.CurrentCamera :: Instance }
		else { Workspace.CurrentCamera :: Instance }
	for _, pool in pools do
		for _, d in pool do
			if not d.active then
				continue
			end
			d.age += dt
			if d.age >= cfg.life then
				d.active = false
				active -= 1
				d.model.Parent = nil
				continue
			end
			if not d.resting then
				local v = d.velocity + GRAVITY * dt
				local move = v * dt
				local hit = Workspace:Raycast(d.position, move, params)
				if hit then
					local n = hit.Normal
					if d.bounced or v.Magnitude < 5 then
						-- Lie flat on its side, keeping the heading it fell with.
						d.resting = true
						local look = d.rotation.LookVector - n * d.rotation.LookVector:Dot(n)
						if look.Magnitude < 1e-3 then
							look = n:Cross(Vector3.xAxis)
						end
						d.rotation = CFrame.lookAt(Vector3.zero, look.Unit, n)
							* CFrame.Angles(0, 0, math.pi / 2)
						d.position = hit.Position + n * cfg.restLift
					else
						v = (v - 2 * v:Dot(n) * n) * cfg.bounce
						d.position = hit.Position + n * 0.05
						d.bounced = true
						d.spin *= 0.4
					end
				else
					d.position += move
				end
				d.velocity = v
				if not d.resting then
					d.rotation = CFrame.fromAxisAngle(d.axis, d.spin * dt) * d.rotation
				end
				place(d)
			end
			local fade = (d.age - (cfg.life - cfg.fade)) / cfg.fade
			if fade > 0 then
				for i, p in d.parts do
					p.Transparency = d.base[i] + (1 - d.base[i]) * math.min(fade, 1)
				end
			end
		end
	end
end

return MagDrop
