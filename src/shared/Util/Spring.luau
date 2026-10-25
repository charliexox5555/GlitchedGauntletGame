--!strict
-- Critically-damped-ish spring for Vector3 values (viewmodel sway, recoil kick).

export type Spring = {
	position: Vector3,
	velocity: Vector3,
	target: Vector3,
	stiffness: number,
	damping: number,
	update: (self: Spring, dt: number) -> Vector3,
	impulse: (self: Spring, v: Vector3) -> (),
}

local Spring = {}

local function update(self: Spring, dt: number): Vector3
	-- Sub-step so big frame hitches stay stable.
	local steps = math.max(1, math.ceil(dt / (1 / 120)))
	local h = dt / steps
	for _ = 1, steps do
		local force = (self.target - self.position) * self.stiffness - self.velocity * self.damping
		self.velocity += force * h
		self.position += self.velocity * h
	end
	return self.position
end

local function impulse(self: Spring, v: Vector3)
	self.velocity += v
end

function Spring.new(stiffness: number, damping: number): Spring
	return {
		position = Vector3.zero,
		velocity = Vector3.zero,
		target = Vector3.zero,
		stiffness = stiffness,
		damping = damping,
		update = update,
		impulse = impulse,
	}
end

return Spring
