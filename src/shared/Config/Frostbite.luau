--!strict
-- Frostbite Legendary skin line (Season 1 battle pass): animated crystal growth on
-- inspect, shard fracture/shed on kill, cold shimmer at rest, and cryo shot/seat pulses.
-- Distances are unscaled studs in the imported cosmetic mesh's axes:
-- local -X points toward the muzzle, +Y up and +Z out of the left face.
export type GrowStage = {
	part: string,
	from: number, -- inspect progress 0..1 where growth starts
	to: number, -- inspect progress 0..1 where growth locks out
	offset: Vector3, -- unscaled translation at full bloom
}

export type ShardSpec = {
	part: string,
	burst: Vector3, -- unscaled outward drift on kill
	spin: Vector3, -- radians rotation during shed
}

export type Profile = {
	bone: string,
	growStages: { GrowStage },
	retractFrom: number,
	retractTo: number,
	shards: { ShardSpec },
	heart: string,
	seams: { string },
	magGlow: string?,
	shimmerPeriod: number,
	fireTime: number,
	seatTime: number,
	killFlashTime: number,
	killShedTime: number,
	killRegrowTime: number,
}

local function vandalLike(): Profile
	return {
		bone = "Root",
		growStages = {
			{
				part = "SK_Root_FBGrowRear",
				from = 0.14,
				to = 0.36,
				offset = Vector3.new(0.012, 0.032, 0),
			},
			{
				part = "SK_Root_FBGrowMid",
				from = 0.34,
				to = 0.56,
				offset = Vector3.new(0.014, 0.036, 0),
			},
			{
				part = "SK_Root_FBGrowFront",
				from = 0.52,
				to = 0.74,
				offset = Vector3.new(0.012, 0.034, 0),
			},
		},
		retractFrom = 0.84,
		retractTo = 0.98,
		shards = {
			{
				part = "SK_Root_FBShard1",
				burst = Vector3.new(0.035, 0.055, 0.14),
				spin = Vector3.new(0.9, 1.4, -0.8),
			},
			{
				part = "SK_Root_FBShard2",
				burst = Vector3.new(-0.025, 0.065, 0.15),
				spin = Vector3.new(-1.1, 1.2, 0.7),
			},
			{
				part = "SK_Root_FBShard3",
				burst = Vector3.new(0.035, 0.055, -0.14),
				spin = Vector3.new(-0.9, -1.4, 0.8),
			},
			{
				part = "SK_Root_FBShard4",
				burst = Vector3.new(-0.025, 0.065, -0.15),
				spin = Vector3.new(1.1, -1.2, -0.7),
			},
		},
		heart = "SK_Root_FBCoreHeart",
		seams = {
			"SK_Root_FBCoreFissure",
			"SK_Root_FBUpperSeam",
			"SK_Root_FBForeSeam",
			"SK_Root_FBMuzzleGlow",
			"SK_Root_FBStockGlow",
		},
		magGlow = "SK_Mag_FBMagGlow",
		shimmerPeriod = 2.6,
		fireTime = 0.10,
		seatTime = 0.24,
		killFlashTime = 0.06,
		killShedTime = 0.38,
		killRegrowTime = 0.90,
	}
end

local profiles: { [string]: Profile } = {
	Vandal = vandalLike(),
}

return table.freeze(profiles)
