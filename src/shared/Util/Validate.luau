--!strict
-- Remote argument checks (roblox-security): every value from a client is
-- hostile until one of these says otherwise. Each returns the typed value, or
-- nil when it's the wrong type, NaN, infinite or out of range.

local Validate = {}

-- Coordinates beyond this are never legitimate (and catch +-inf).
Validate.MAX_COORD = 1e5

function Validate.number(v: unknown, min: number?, max: number?): number?
	if typeof(v) ~= "number" then
		return nil
	end
	local n = v :: number
	if n ~= n or n == math.huge or n == -math.huge then
		return nil
	end
	if (min and n < min) or (max and n > max) then
		return nil
	end
	return n
end

function Validate.integer(v: unknown, min: number?, max: number?): number?
	local n = Validate.number(v, min, max)
	if n and n == math.floor(n) then
		return n
	end
	return nil
end

-- A Vector3 with every component finite and within MAX_COORD.
function Validate.vector(v: unknown): Vector3?
	if typeof(v) ~= "Vector3" then
		return nil
	end
	local vec = v :: Vector3
	for _, c in { vec.X, vec.Y, vec.Z } do
		if c ~= c or math.abs(c) > Validate.MAX_COORD then
			return nil
		end
	end
	return vec
end

-- A direction of roughly unit length (0.9..1.1), returned normalised.
function Validate.unit(v: unknown): Vector3?
	local vec = Validate.vector(v)
	if not vec then
		return nil
	end
	local m = vec.Magnitude
	if m < 0.9 or m > 1.1 then
		return nil
	end
	return vec.Unit
end

function Validate.string(v: unknown, maxLength: number): string?
	if typeof(v) ~= "string" then
		return nil
	end
	local s = v :: string
	if #s == 0 or #s > maxLength then
		return nil
	end
	return s
end

-- One of a fixed set of strings ({ [value] = true }).
function Validate.enum(v: unknown, set: { [string]: boolean }): string?
	if typeof(v) ~= "string" or not set[v :: string] then
		return nil
	end
	return v :: string
end

function Validate.boolean(v: unknown): boolean?
	if typeof(v) ~= "boolean" then
		return nil
	end
	return v :: boolean
end

-- An Instance of class `className` that is still in the DataModel.
function Validate.instance(v: unknown, className: string): Instance?
	if typeof(v) ~= "Instance" then
		return nil
	end
	local inst = v :: Instance
	if not inst:IsA(className) or not inst:IsDescendantOf(game) then
		return nil
	end
	return inst
end

return Validate
