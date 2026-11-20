--!strict
-- Cosmetic staging. Gear simulation and the host's stock clip still own readiness.
export type Profile = {
	inspectTrack: string,
	cast: Vector3,
	rotation: Vector3,
	spread: number,
	form: number,
	grab: number,
	throw: number,
	seat: number,
}

local function profile(
	inspectTrack: string,
	cast: Vector3,
	rotation: Vector3,
	spread: number,
	form: number,
	grab: number,
	throw: number,
	seat: number
): Profile
	return table.freeze({
		inspectTrack = inspectTrack,
		cast = cast,
		rotation = rotation,
		spread = spread,
		form = form,
		grab = grab,
		throw = throw,
		seat = seat,
	})
end

return table.freeze({
	Vandal = profile(
		"InspectShadowMist",
		Vector3.new(-0.65, -0.31, -0.12),
		Vector3.new(0.22, -0.25, -0.18),
		1,
		0,
		0,
		0,
		0
	),
	Guardian = profile(
		"InspectRuinGuardian",
		Vector3.new(-0.63, -0.26, -0.19),
		Vector3.new(0.17, -0.13, -0.24),
		0.91,
		0.34,
		0.55,
		0.70,
		0.61
	),
	Spectre = profile(
		"InspectRuinSpectre",
		Vector3.new(-0.67, -0.38, 0.05),
		Vector3.new(0.34, -0.31, 0.19),
		0.73,
		0.30,
		0.51,
		0.64,
		0.59
	),
	Operator = profile(
		"InspectRuinOperator",
		Vector3.new(-0.49, -0.30, -0.34),
		Vector3.new(0.14, -0.41, -0.14),
		0.84,
		0.34,
		0.59,
		0.73,
		0.62
	),
	Ghost = profile(
		"InspectRuinGhost",
		Vector3.new(-0.57, -0.36, 0.06),
		Vector3.new(0.39, -0.12, 0.51),
		0.60,
		0.32,
		0.53,
		0.67,
		0.59
	),
} :: { [string]: Profile })
