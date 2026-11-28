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

local function makeProfile(o: {
	core: Vector3,
	fore: Vector3,
	muzzle: Vector3,
	stock: Vector3,
	magWell: Vector3,
	growParts: { string }?,
	growOffsets: { Vector3 }?,
	shardParts: { string }?,
	shardLat: number?,
	seams: { string },
	magGlow: string?,
	ribX: { number },
	ribY: number?,
	ribZ: { number }?,
	ribW: { number }?,
	arcSpan: { number }?,
}): Profile
	local gParts = o.growParts
		or { "SK_Root_FBGrowRear", "SK_Root_FBGrowMid", "SK_Root_FBGrowFront" }
	local gOff = o.growOffsets
		or {
			Vector3.new(0.020, 0.062, 0),
			Vector3.new(0.024, 0.072, 0),
			Vector3.new(0.020, 0.066, 0),
		}
	local sParts = o.shardParts
		or { "SK_Root_FBShard1", "SK_Root_FBShard2", "SK_Root_FBShard3", "SK_Root_FBShard4" }
	local lat = o.shardLat or 0.26
	local ry = o.ribY or 0.098
	local rz = o.ribZ or { o.core.Z, (o.core.Z + o.fore.Z) * 0.5, o.fore.Z, o.muzzle.Z }
	local rw = o.ribW or { 0.052, 0.044, 0.034, 0.020 }
	local x0, x1, x2, x3 = o.ribX[1], o.ribX[2], o.ribX[3], o.ribX[4]
	local ax0 = if o.arcSpan then o.arcSpan[1] else o.core.X - 0.18
	local ax1 = if o.arcSpan then o.arcSpan[2] else o.core.X + 0.22
	local af0 = if o.arcSpan then o.arcSpan[3] else (o.core.X + o.fore.X) * 0.52
	local af1 = if o.arcSpan then o.arcSpan[4] else math.min(o.fore.X + 0.24, o.muzzle.X - 0.18)

	return {
		bone = "Root",
		core = o.core,
		fore = o.fore,
		muzzle = o.muzzle,
		stock = o.stock,
		magWell = o.magWell,
		growStages = {
			{ part = gParts[1], from = 0.12, to = 0.34, offset = gOff[1] },
			{ part = gParts[2], from = 0.32, to = 0.54, offset = gOff[2] },
			{ part = gParts[3], from = 0.50, to = 0.72, offset = gOff[3] },
		},
		retractFrom = 0.84,
		retractTo = 0.98,
		shards = {
			{
				part = sParts[1],
				burst = Vector3.new(0.060, 0.092, lat),
				spin = Vector3.new(1.4, 2.2, -1.2),
			},
			{
				part = sParts[2],
				burst = Vector3.new(-0.045, 0.110, lat + 0.02),
				spin = Vector3.new(-1.6, 1.9, 1.1),
			},
			{
				part = sParts[3],
				burst = Vector3.new(0.060, 0.092, -lat),
				spin = Vector3.new(-1.4, -2.2, 1.2),
			},
			{
				part = sParts[4],
				burst = Vector3.new(-0.045, 0.110, -(lat + 0.02)),
				spin = Vector3.new(1.6, -1.9, -1.1),
			},
		},
		heart = "SK_Root_FBCoreHeart",
		seams = o.seams,
		magGlow = o.magGlow,
		ribbons = {
			{
				a = Vector3.new(x0, ry, rz[1]),
				b = Vector3.new(x1, ry * 0.96, rz[2]),
				w0 = rw[1],
				w1 = rw[2],
			},
			{
				a = Vector3.new(x1, ry * 0.96, rz[2]),
				b = Vector3.new(x2, ry * 0.88, rz[3]),
				w0 = rw[2],
				w1 = rw[3],
			},
			{
				a = Vector3.new(x2, ry * 0.88, rz[3]),
				b = Vector3.new(x3, ry * 0.62, rz[4]),
				w0 = rw[3],
				w1 = rw[4],
			},
		},
		arcs = {
			{
				Vector3.new(ax0, ry + 0.008, o.core.Z + 0.045),
				Vector3.new(ax1, ry + 0.006, o.core.Z - 0.030),
			},
			{
				Vector3.new(ax0, -(ry + 0.008), o.core.Z + 0.045),
				Vector3.new(ax1, -(ry + 0.006), o.core.Z - 0.030),
			},
			{
				Vector3.new(af0, ry * 0.92, o.fore.Z + 0.038),
				Vector3.new(af1, -ry * 0.92, o.fore.Z - 0.018),
			},
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
	Phantom = makeProfile({
		core = Vector3.new(0.460, 0, 0.238),
		fore = Vector3.new(1.300, 0, 0.309),
		muzzle = Vector3.new(1.949, 0, 0.352),
		stock = Vector3.new(-1.045, 0, 0.165),
		magWell = Vector3.new(0.749, 0, -0.104),
		seams = {
			"SK_Root_FBCoreFissure",
			"SK_Root_FBUpperSeam",
			"SK_Root_FBForeSeam",
			"SK_Root_FBMuzzleGlow",
			"SK_Root_FBStockGlow",
		},
		magGlow = "SK_Mag_FBMagGlow",
		ribX = { 0.22, 0.82, 1.38, 1.88 },
		ribY = 0.102,
	}),
	Spectre = makeProfile({
		core = Vector3.new(0.463, 0, 0.202),
		fore = Vector3.new(0.961, 0, 0.349),
		muzzle = Vector3.new(1.408, 0, 0.353),
		stock = Vector3.new(-1.000, 0, 0.125),
		magWell = Vector3.new(0.719, 0, -0.207),
		seams = {
			"SK_Root_FBCoreFissure",
			"SK_Root_FBUpperSeam",
			"SK_Root_FBForeSeam",
			"SK_Root_FBMuzzleGlow",
			"SK_Root_FBStockGlow",
		},
		magGlow = "SK_Mag_FBMagGlow",
		ribX = { -0.10, 0.45, 0.98, 1.36 },
		ribY = 0.098,
	}),
	Guardian = makeProfile({
		core = Vector3.new(0.445, 0, 0.255),
		fore = Vector3.new(1.740, 0, 0.310),
		muzzle = Vector3.new(2.839, 0, 0.368),
		stock = Vector3.new(-1.150, 0, 0.105),
		magWell = Vector3.new(0.689, 0, -0.122),
		seams = {
			"SK_Root_FBCoreFissure",
			"SK_Root_FBUpperSeam",
			"SK_Root_FBForeSeam",
			"SK_Root_FBMuzzleGlow",
			"SK_Root_FBStockGlow",
		},
		magGlow = "SK_Mag_FBMagGlow",
		ribX = { 0.20, 1.05, 1.95, 2.70 },
		ribY = 0.104,
	}),
	Bulldog = makeProfile({
		core = Vector3.new(-0.786, 0, 0.342),
		fore = Vector3.new(0.825, 0, 0.240),
		muzzle = Vector3.new(1.296, 0, 0.361),
		stock = Vector3.new(-1.325, 0, 0.175),
		magWell = Vector3.new(-0.648, 0, -0.095),
		seams = {
			"SK_Root_FBCoreFissure",
			"SK_Root_FBUpperSeam",
			"SK_Root_FBForeSeam",
			"SK_Root_FBMuzzleGlow",
			"SK_Root_FBStockGlow",
		},
		magGlow = "SK_Mag_FBMagGlow",
		ribX = { -0.92, -0.22, 0.62, 1.22 },
		ribY = 0.102,
		arcSpan = { -0.92, -0.48, 0.45, 0.95 },
	}),
	Odin = makeProfile({
		core = Vector3.new(0.577, 0, 0.295),
		fore = Vector3.new(1.745, 0, 0.312),
		muzzle = Vector3.new(3.088, 0, 0.371),
		stock = Vector3.new(-1.095, 0, 0.145),
		magWell = Vector3.new(0.955, 0, -0.205),
		seams = {
			"SK_Root_FBCoreFissure",
			"SK_Root_FBUpperSeam",
			"SK_Root_FBForeSeam",
			"SK_Root_FBMuzzleGlow",
			"SK_Root_FBStockGlow",
		},
		magGlow = "SK_AmmoBox_FBMagGlow",
		ribX = { 0.05, 1.05, 2.05, 2.92 },
		ribY = 0.122,
		ribW = { 0.062, 0.052, 0.042, 0.024 },
		shardLat = 0.30,
	}),
	Operator = makeProfile({
		core = Vector3.new(0.561, 0, 0.227),
		fore = Vector3.new(1.655, 0, 0.335),
		muzzle = Vector3.new(3.285, 0, 0.385),
		stock = Vector3.new(-1.205, 0, 0.095),
		magWell = Vector3.new(0.625, 0, 0.021),
		seams = {
			"SK_Root_FBCoreFissure",
			"SK_Root_FBForeSeam",
			"SK_Root_FBMuzzleGlow",
			"SK_Root_FBStockGlow",
		},
		magGlow = "SK_Mag_FBMagGlow",
		ribX = { 0.35, 1.25, 2.25, 3.15 },
		ribY = 0.106,
		ribW = { 0.058, 0.048, 0.038, 0.022 },
		shardLat = 0.28,
	}),
	Marshal = makeProfile({
		core = Vector3.new(0.574, 0, 0.113),
		fore = Vector3.new(1.360, 0, 0.101),
		muzzle = Vector3.new(3.151, 0, 0.205),
		stock = Vector3.new(-1.202, 0, -0.090),
		magWell = Vector3.new(1.525, 0, 0.010),
		seams = {
			"SK_Root_FBCoreFissure",
			"SK_Root_FBForeSeam",
			"SK_Root_FBMuzzleGlow",
			"SK_Root_FBStockGlow",
		},
		magGlow = "SK_Root_FBMagGlow",
		ribX = { 0.35, 1.20, 2.15, 3.02 },
		ribY = 0.084,
		ribW = { 0.046, 0.040, 0.030, 0.018 },
	}),
	Bucky = makeProfile({
		core = Vector3.new(0.550, 0, 0.250),
		fore = Vector3.new(1.725, 0, 0.204),
		muzzle = Vector3.new(2.787, 0, 0.369),
		stock = Vector3.new(-0.892, 0, 0.035),
		magWell = Vector3.new(2.370, 0, 0.165),
		seams = {
			"SK_Root_FBCoreFissure",
			"SK_Pump_FBForeSeam",
			"SK_Root_FBMuzzleGlow",
			"SK_Root_FBStockGlow",
		},
		magGlow = "SK_Root_FBMagGlow",
		ribX = { 0.30, 1.10, 1.95, 2.66 },
		ribY = 0.094,
	}),
	Stinger = makeProfile({
		core = Vector3.new(0.137, 0, 0.301),
		fore = Vector3.new(0.641, 0, 0.200),
		muzzle = Vector3.new(0.983, 0, 0.294),
		stock = Vector3.new(-1.442, 0, 0.095),
		magWell = Vector3.new(0.004, 0, -0.375),
		seams = {
			"SK_Root_FBCoreFissure",
			"SK_Root_FBForeSeam",
			"SK_Root_FBMuzzleGlow",
			"SK_Root_FBStockGlow",
		},
		magGlow = "SK_Mag_FBMagGlow",
		ribX = { -0.45, 0.15, 0.58, 0.94 },
		ribY = 0.096,
		ribW = { 0.046, 0.038, 0.030, 0.018 },
	}),
	Classic = makeProfile({
		core = Vector3.new(0.411, 0, 0.215),
		fore = Vector3.new(0.495, 0, 0.378),
		muzzle = Vector3.new(1.017, 0, 0.365),
		stock = Vector3.new(-0.080, 0, 0.140),
		magWell = Vector3.new(0.054, 0, -0.344),
		seams = {
			"SK_Root_FBCoreFissure",
			"SK_Slide_FBForeSeam",
			"SK_Slide_FBMuzzleGlow",
		},
		magGlow = "SK_Mag_FBMagGlow",
		ribX = { 0.02, 0.38, 0.72, 0.98 },
		ribY = 0.084,
		ribW = { 0.042, 0.036, 0.028, 0.018 },
		shardLat = 0.22,
		growOffsets = {
			Vector3.new(0.014, 0.048, 0),
			Vector3.new(0.016, 0.054, 0),
			Vector3.new(0.014, 0.050, 0),
		},
	}),
	Sheriff = makeProfile({
		core = Vector3.new(1.113, 0, 0.225),
		fore = Vector3.new(1.130, 0, 0.273),
		muzzle = Vector3.new(1.457, 0, 0.274),
		stock = Vector3.new(0.100, 0, 0.080),
		magWell = Vector3.new(0.650, 0, 0.140),
		seams = {
			"SK_Root_FBCoreFissure",
			"SK_Root_FBForeSeam",
			"SK_Root_FBMuzzleGlow",
		},
		magGlow = nil,
		ribX = { 0.25, 0.68, 1.08, 1.40 },
		ribY = 0.086,
		ribW = { 0.044, 0.038, 0.030, 0.018 },
		shardLat = 0.22,
		arcSpan = { 0.88, 1.24, 1.00, 1.38 },
		growOffsets = {
			Vector3.new(0.014, 0.050, 0),
			Vector3.new(0.018, 0.058, 0),
			Vector3.new(0.014, 0.052, 0),
		},
	}),
	Shorty = makeProfile({
		core = Vector3.new(0.267, 0, 0.240),
		fore = Vector3.new(1.038, 0, 0.034),
		muzzle = Vector3.new(1.405, 0, 0.260),
		stock = Vector3.new(0.020, 0, 0.050),
		magWell = Vector3.new(0.550, 0, 0.100),
		growParts = { "SK_Root_FBGrowRear", "SK_Root_FBGrowMid", "SK_Barrels_FBGrowFront" },
		shardParts = {
			"SK_Root_FBShard1",
			"SK_Barrels_FBShard2",
			"SK_Root_FBShard3",
			"SK_Barrels_FBShard4",
		},
		seams = {
			"SK_Root_FBCoreFissure",
			"SK_Barrels_FBForeSeam",
			"SK_Barrels_FBMuzzleGlow",
		},
		magGlow = nil,
		ribX = { 0.15, 0.55, 0.98, 1.35 },
		ribY = 0.098,
		ribW = { 0.046, 0.038, 0.030, 0.018 },
		shardLat = 0.23,
	}),
	Ghost = makeProfile({
		core = Vector3.new(0.517, 0, 0.183),
		fore = Vector3.new(0.460, 0, 0.302),
		muzzle = Vector3.new(1.405, 0, 0.296),
		stock = Vector3.new(0.050, 0, 0.080),
		magWell = Vector3.new(0.039, 0, -0.427),
		seams = {
			"SK_Root_FBCoreFissure",
			"SK_Slide_FBForeSeam",
			"SK_Root_FBMuzzleGlow",
		},
		magGlow = "SK_Mag_FBMagGlow",
		ribX = { 0.12, 0.68, 1.25, 1.80 },
		ribY = 0.084,
		ribW = { 0.044, 0.036, 0.028, 0.018 },
		shardLat = 0.22,
		growOffsets = {
			Vector3.new(0.014, 0.050, 0),
			Vector3.new(0.018, 0.056, 0),
			Vector3.new(0.014, 0.052, 0),
		},
	}),
}

return table.freeze(profiles)
