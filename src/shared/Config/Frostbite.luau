--!strict
-- Frostbite Legendary skin line (Season 1 battle pass):
--   - Blender-space anchor points & volumetric flank cryo ribbon segments (converted via Handle -> Root)
--   - Staggered 3-stage inspect crystal eruption, 3D halo sweeps, per-shot barrel pulse,
--     and dramatic kill shard crack/shed + refreeze.
export type GrowStage = {
	part: string,
	from: number, -- inspect progress 0..1 where growth starts
	to: number, -- inspect progress 0..1 where growth locks out
	offset: Vector3, -- unscaled translation at full bloom (Part1/Root axes)
}

export type ShardSpec = {
	part: string,
	burst: Vector3, -- unscaled outward drift on kill
	spin: Vector3, -- radians rotation during shed
}

export type RibbonSeg = { a: Vector3, b: Vector3, w0: number, w1: number }

export type Profile = {
	bone: string,
	core: Vector3,
	fore: Vector3,
	muzzle: Vector3,
	stock: Vector3,
	magWell: Vector3,
	growStages: { GrowStage },
	retractFrom: number,
	retractTo: number,
	shards: { ShardSpec },
	heart: string,
	seams: { string },
	magGlow: string?,
	ribbons: { RibbonSeg },
	arcs: { { Vector3 } },
	shimmerPeriod: number,
	fireTime: number,
	seatTime: number,
	pulseTime: number,
	haloDrawDur: number,
	haloSeatDur: number,
	killFlashTime: number,
	killShedTime: number,
	killRegrowTime: number,
}

local function vandalLike(): Profile
	return {
		bone = "Root",
		-- Blender (x=muzzle, y=left, z=up) anchors matching Vandal_Frostbite_v10
		core = Vector3.new(0.46, 0, 0.22),
		fore = Vector3.new(1.40, 0, 0.30),
		muzzle = Vector3.new(2.50, 0, 0.285),
		stock = Vector3.new(-0.78, 0, 0.14),
		magWell = Vector3.new(0.74, 0, 0.02),
		growStages = {
			{
				part = "SK_Root_FBGrowRear",
				from = 0.12,
				to = 0.34,
				offset = Vector3.new(0.020, 0.062, 0),
			},
			{
				part = "SK_Root_FBGrowMid",
				from = 0.32,
				to = 0.54,
				offset = Vector3.new(0.024, 0.072, 0),
			},
			{
				part = "SK_Root_FBGrowFront",
				from = 0.50,
				to = 0.72,
				offset = Vector3.new(0.020, 0.066, 0),
			},
		},
		retractFrom = 0.84,
		retractTo = 0.98,
		shards = {
			{
				part = "SK_Root_FBShard1",
				burst = Vector3.new(0.065, 0.095, 0.26),
				spin = Vector3.new(1.4, 2.2, -1.2),
			},
			{
				part = "SK_Root_FBShard2",
				burst = Vector3.new(-0.045, 0.115, 0.28),
				spin = Vector3.new(-1.6, 1.9, 1.1),
			},
			{
				part = "SK_Root_FBShard3",
				burst = Vector3.new(0.065, 0.095, -0.26),
				spin = Vector3.new(-1.4, -2.2, 1.2),
			},
			{
				part = "SK_Root_FBShard4",
				burst = Vector3.new(-0.045, 0.115, -0.28),
				spin = Vector3.new(1.6, -1.9, -1.1),
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
		-- Paired flank ribbons mirrored +/- Y inside FrostbiteEffects
		ribbons = {
			{
				a = Vector3.new(0.22, 0.105, 0.225),
				b = Vector3.new(0.96, 0.102, 0.275),
				w0 = 0.056,
				w1 = 0.048,
			},
			{
				a = Vector3.new(0.96, 0.102, 0.275),
				b = Vector3.new(1.72, 0.092, 0.305),
				w0 = 0.048,
				w1 = 0.038,
			},
			{
				a = Vector3.new(1.72, 0.092, 0.305),
				b = Vector3.new(2.34, 0.064, 0.288),
				w0 = 0.038,
				w1 = 0.022,
			},
		},
		arcs = {
			{ Vector3.new(0.24, 0.112, 0.270), Vector3.new(0.68, 0.110, 0.195) },
			{ Vector3.new(0.24, -0.112, 0.270), Vector3.new(0.68, -0.110, 0.195) },
			{ Vector3.new(1.12, 0.096, 0.335), Vector3.new(1.66, -0.096, 0.280) },
		},
		shimmerPeriod = 2.6,
		fireTime = 0.11,
		seatTime = 0.28,
		pulseTime = 0.085,
		haloDrawDur = 0.42,
		haloSeatDur = 0.30,
		killFlashTime = 0.07,
		killShedTime = 0.42,
		killRegrowTime = 0.90,
	}
end

local profiles: { [string]: Profile } = {
	Vandal = vandalLike(),
}

return table.freeze(profiles)
