--!strict
-- The match avatar (vault/01 Design/Match Avatar.md, Third Person Overhaul.md):
-- one standard body for every combatant in the match place, so holds land and
-- hitboxes are equal. The Lobby keeps players' own avatars.

export type Block = {
	mesh: string,
	offset: Vector3, -- the block's centre in its R15 part's frame
	size: Vector3, -- its bounds
	cloth: { string }, -- clothing drawn on it, bottom layer first ("Pants", "Shirt")
	region: string, -- which CLOTH_REGIONS entry its faces use
	t0: number, -- how far down that region the block's top edge sits (0..1)...
	t1: number, -- ...and its bottom edge
	top: boolean, -- draw the region's Top square on the block's top face
	bottom: boolean, -- ...and its Bottom square underneath
	skin: Skin?, -- a whole limb as one skinned mesh (see LIMB_SKIN)
}

-- A skinned limb (tools/blender/make_skinned_limbs.py): one mesh from the
-- shoulder / hip to the fist / sole, welded to the upper part, bent by five
-- Bones that shared/MatchBody makes and Controllers/BodySkinController turns
-- each frame from the R15 parts. Heights are in the upper part's frame.
export type Skin = {
	lower: string, -- the forearm / shin part...
	joint: string, -- ...and the rig attachment it turns on (elbow / knee)
	tip: string, -- the hand / foot part...
	tipJoint: string, -- ...and its attachment (wrist / ankle)
	top: number, -- the "Upper" bone (shoulder top / hip)
	bend: number, -- the elbow / knee (bones Mid1, Lower)
	wrist: number, -- the wrist / ankle (bones Mid2, End)
	root: string?, -- legs: the pelvis part the thigh's top rides (bones Hip, HipMid)...
	rootJoint: string?, -- ...and the attachment it turns on
	twist: boolean?, -- keep the joint's twist (the torso: a turned chest)
	prefix: string, -- the mesh's bone names start with this ("RightArm" + "Upper")
}

local function id(n: number): string
	return "rbxassetid://" .. tostring(n)
end

local function block(
	n: number,
	offset: Vector3,
	size: Vector3,
	cloth: { string },
	region: string,
	t0: number,
	t1: number,
	top: boolean?,
	bottom: boolean?,
	skin: Skin?
): Block
	return table.freeze({
		mesh = id(n),
		offset = offset,
		size = size,
		cloth = cloth,
		region = region,
		t0 = t0,
		t1 = t1,
		top = top == true,
		bottom = bottom == true,
		skin = skin,
	})
end

local function skin(side: string, kind: "Arm" | "Leg"): Skin
	if kind == "Arm" then
		return table.freeze({
			prefix = side .. "Arm",
			lower = side .. "LowerArm",
			joint = side .. "ElbowRigAttachment",
			tip = side .. "Hand",
			tipJoint = side .. "WristRigAttachment",
			top = 0.5843,
			bend = -0.3341,
			wrist = -1.0937,
		})
	end
	return table.freeze({
		prefix = side .. "Leg",
		lower = side .. "LowerLeg",
		joint = side .. "KneeRigAttachment",
		tip = side .. "Foot",
		tipJoint = side .. "AnkleRigAttachment",
		top = 0.4208,
		bend = -0.401,
		wrist = -1.3272,
		root = "LowerTorso",
		rootJoint = side .. "HipRigAttachment",
	})
end

-- Arms and legs share a size per segment (left and right differ only in
-- where they sit on the clothing template).
local ARM = Vector3.new(1, 1.953, 1)
local LEG = Vector3.new(1, 2.1874, 1)
local ARM_CENTRE = Vector3.new(0, -0.3922, 0)
local LEG_CENTRE = Vector3.new(0, -0.4854, 0)
-- The torso: one mesh from the neck to the hips, welded to the hips; the
-- chest follows UpperTorso, the waist turns half way (twist kept: the rifle
-- stance turns the chest 38 degrees).
local TORSO_SKIN: Skin = table.freeze({
	prefix = "Torso",
	lower = "UpperTorso",
	joint = "WaistRigAttachment",
	tip = "UpperTorso",
	tipJoint = "WaistRigAttachment",
	top = 0.2,
	bend = 0.2,
	wrist = 0.2,
	twist = true,
})
local SHIRT = table.freeze({ "Shirt" })
local PANTS = table.freeze({ "Pants" })
local BOTH = table.freeze({ "Pants", "Shirt" })

return table.freeze({
	-- Which body fighters wear (owner 2026-11-21, after RIVALS: "their body is so smooth"; vault/01 Design/Match
	-- Avatar.md → Skinned classic body):
	--  "S15"    the classic blocky R15 proportions as one SKINNED mesh (smooth shoulders, elbows, hips, knees),
	--           with the player's own head, dynamic face, hair and hats, classic clothing and skin colours. The body
	--           parts are the public community body "S15 - Skinned Classic 1.0" (catalog bundle 209745; DevForum
	--           "Classic Blocky S15 Rigs [Skinned meshes]" by ellieflopper, offered for any R15 game, not for
	--           resale), set by id on the description so the engine builds the skinned rig itself.
	--  "Blocks" our sharp block body drawn over the engine's parts (BLOCK_BODY, BLOCKS below).
	BODY = "S15" :: "S15" | "Blocks",
	S15_PARTS = table.freeze({
		Torso = 15365012259,
		LeftArm = 15365010034,
		RightArm = 15365012263,
		LeftLeg = 15365010038,
		RightLeg = 15365010030,
	}),
	-- The head for bots, dummies and oversized own heads: Roblox's classic head (0) with the default face. (The
	-- bundle's dynamic head, 15365010165, rendered faceless on dummies, 2026-11-21.)
	STANDARD_HEAD = 0,
	-- The face for a standard head (bots, dummies, a swapped head): Roblox's default "Smile" face.
	DEFAULT_FACE = 144075659,
	-- The body's surface: soft and clean, no Plastic studs grain (owner 2026-11-22: the win cutscene body "was not
	-- SmoothPlastic"). Set on every body part, including parts an ApplyDescription rebuilds.
	BODY_MATERIAL = Enum.Material.SmoothPlastic,
	-- Own heads bigger than this (studs, any axis order) get the standard head instead (RIVALS swaps oversized
	-- heads too); the hitbox is the same for everyone either way (HEAD_HITBOX).
	HEAD_LIMIT = Vector3.new(1.7, 1.9, 1.7),
	-- Every fighter's head hitbox (an invisible part named HitboxHead welded at the head; the visible head and
	-- its hair don't take hits): a big head or a puffy hairdo never makes you easier to hit.
	HEAD_HITBOX = Vector3.new(1.2, 1.2, 1.2),

	-- Body scales written on the standard description (Humanoid NumberValues).
	SCALES = table.freeze({
		height = 1,
		width = 1,
		depth = 1,
		head = 1,
		bodyType = 0,
		proportion = 0,
	}),

	-- The block body (owner, 2026-11-12: regular-width arms, sharp flat-shaded
	-- blocks like the first-person arm, no detached hands or feet, no gaps at
	-- the elbows and knees). The engine's R15 parts stay as the rig and the
	-- hitboxes but are invisible; one of our blocks is welded over each
	-- (tools/blender/make_body_mesh.py → art-source/body/BlockBody.fbx, Model
	-- asset 103550484592616: v2, 2026-11-12, joints are a two-plate mitre and
	-- the faces are flat shaded; v1, 125998394949118, had four-plate joint
	-- ends that read as lumps). The classic Shirt and Pants are drawn on the
	-- blocks face by face (shared/MatchBody), Pants under Shirt on the torso.
	-- Hands and feet have no block of their own: the forearm block runs to the
	-- fingertips and the shin block to the sole. false = the engine's own
	-- blocky R15 parts.
	BLOCK_BODY = true,
	BLOCKS = table.freeze({
		-- Skinned body v4 (2026-11-12, Model asset 112809907225612): R15's own
		-- proportions (a 2 x 2 x 1 torso box, 2.0 legs tucked into the hips),
		-- checked beside the owner's R6 / R15 presets. Every mesh has its own
		-- bone names (Skin.prefix): with shared names the importer bound each
		-- mesh to another armature's bones, which drew the torso 2.5 tall up
		-- past the chin and stretched the legs (v3a-v3g, 2026-11-12).
		RightUpperArm = block(
			82702262302238,
			ARM_CENTRE,
			ARM,
			SHIRT,
			"RightLimb",
			0,
			1,
			true,
			false,
			skin("Right", "Arm")
		),
		LeftUpperArm = block(
			120325316822143,
			ARM_CENTRE,
			ARM,
			SHIRT,
			"LeftLimb",
			0,
			1,
			true,
			false,
			skin("Left", "Arm")
		),
		RightUpperLeg = block(
			115346389827680,
			LEG_CENTRE,
			LEG,
			PANTS,
			"RightLimb",
			-0.09375,
			1,
			false,
			false,
			skin("Right", "Leg")
		),
		LeftUpperLeg = block(
			81772806880478,
			LEG_CENTRE,
			LEG,
			PANTS,
			"LeftLimb",
			-0.09375,
			1,
			false,
			false,
			skin("Left", "Leg")
		),
		LowerTorso = block(
			121990847159383,
			Vector3.new(0, 0.8, 0),
			Vector3.new(2.012, 2, 1.012),
			BOTH,
			"Torso",
			0,
			1,
			true,
			true,
			TORSO_SKIN
		),
	} :: { [string]: Block }),
	-- The classic clothing template (585 x 559 px): where each face of a limb
	-- or the torso sits on it (top-left corner, px). Side faces are `down` px
	-- tall and 64 wide (`across` wide on the front and back); the Top and
	-- Bottom squares are 64 px deep. A Shirt uses the limb regions for arms,
	-- Pants for legs.
	CLOTH_TEMPLATE = Vector2.new(585, 559),
	CLOTH_REGIONS = table.freeze({
		RightLimb = table.freeze({
			across = 64,
			down = 128,
			Front = Vector2.new(217, 355),
			Right = Vector2.new(151, 355),
			Back = Vector2.new(85, 355),
			Left = Vector2.new(19, 355),
			Top = Vector2.new(217, 289),
			Bottom = Vector2.new(217, 485),
		}),
		LeftLimb = table.freeze({
			across = 64,
			down = 128,
			Front = Vector2.new(308, 355),
			Left = Vector2.new(374, 355),
			Back = Vector2.new(440, 355),
			Right = Vector2.new(506, 355),
			Top = Vector2.new(308, 289),
			Bottom = Vector2.new(308, 485),
		}),
		Torso = table.freeze({
			across = 128,
			down = 128,
			Front = Vector2.new(231, 74),
			Right = Vector2.new(165, 74),
			Left = Vector2.new(361, 74),
			Back = Vector2.new(427, 74),
			Top = Vector2.new(231, 8),
			Bottom = Vector2.new(231, 204),
		}),
	} :: { [string]: { [string]: any } }),
	-- R15 parts hidden with no block of their own.
	BLOCK_HIDDEN = table.freeze({
		"UpperTorso",
		"RightLowerArm",
		"LeftLowerArm",
		"RightHand",
		"LeftHand",
		"RightLowerLeg",
		"LeftLowerLeg",
		"RightFoot",
		"LeftFoot",
	}),
	BLOCK_NAME = "BodyBlock", -- the welded block, a child of its R15 part
	-- Skinned limbs: helper bones at the elbow / knee and wrist / ankle turn
	-- this much of the bend (0.5 = half: the outside of a bend is two equal
	-- plates). LIMB_TAG marks a limb mesh for Controllers/BodySkinController.
	-- twist: false = the visible forearm / shin takes only the bend (swing)
	-- of its joint, not the turn about the limb's own axis. A square block
	-- twisted at the elbow skews into a slab (the pistol hold turns the right
	-- elbow 66 degrees, all of it twist), and twist never changes where the
	-- forearm points. tip: false = the fist / foot stays rigid on the forearm
	-- / shin (the clips turn the hand parts for the gun, up to 35 degrees,
	-- which bent the block's end at the wrist).
	LIMB_SKIN = table.freeze({ mid = 0.5, twist = false, tip = false }),
	LIMB_TAG = "GGSkinLimb",
	-- Limb meshes live in Workspace[LIMB_FOLDER] (outside the character: its
	-- Animator would overwrite their bones). Each has an ObjectValue
	-- LIMB_OWNER -> its upper R15 part; that part has LIMB_LINK -> the mesh.
	LIMB_FOLDER = "GGBodyLimbs",
	LIMB_OWNER = "Owner",
	LIMB_LINK = "BodyLimb",
	-- While one Instance has to hold the whole body (a Highlight adorns one
	-- Instance and its descendants), client Util/LimbHold keeps a body's limb
	-- meshes in a Model of this name inside the character, re-checked for new
	-- limbs (streaming, a rebuild) every LIMB_HOLD_RESCAN seconds.
	LIMB_HOLD = "BodyLimbHold",
	LIMB_HOLD_RESCAN = 0.2,

	-- Accessories kept from the player's own avatar: "all" (every rigid
	-- accessory that passes the rule below), "hair" (hair only) or "none".
	-- Owner 2026-11-12: most back, so you can recognise a player, minus the
	-- ones that cause problems (was hair only, 2026-11-05).
	ACCESSORIES = "all" :: "hair" | "all" | "none",
	-- The rule (Third Person Overhaul.md §4), checked on the spawned
	-- accessory on the server. Layered clothing never comes through (only the
	-- rigid accessory lists are copied, and anything with a WrapLayer goes).
	-- Largest allowed size per type, studs, any way round (the three sides are
	-- compared largest to smallest). Head items: about Roblox's own limits for
	-- the classic body. Back, waist, shoulder and front items are cut down so
	-- wings, tails and oversized props can't hide a body. A type not listed
	-- here is removed.
	ACCESSORY_LIMITS = table.freeze({
		Hat = Vector3.new(3.2, 3.2, 3),
		Hair = Vector3.new(4.2, 3.5, 3),
		Face = Vector3.new(3, 2, 2),
		Eyebrow = Vector3.new(2, 1, 1),
		Eyelash = Vector3.new(2, 1, 1),
		Neck = Vector3.new(3, 3, 2),
		Shoulder = Vector3.new(3.5, 3, 2.5),
		Front = Vector3.new(3, 3, 2),
		Back = Vector3.new(4, 3.5, 2.5),
		Waist = Vector3.new(4, 3, 3),
	} :: { [string]: Vector3 }),
	-- Layered accessories (a WrapLayer) allowed, by type: head items only.
	-- They wrap the engine's own head, which the match body still draws;
	-- layered clothing would wrap the invisible R15 body under our blocks.
	-- Most hair on the catalogue today is layered (2026-11-12: the owner's is).
	ACCESSORY_LAYERED = table.freeze({ "Hair", "Hat", "Face", "Eyebrow", "Eyelash" }),
	-- Removed from inside any accessory that stays (the accessory keeps its
	-- shape, loses its effects): moving, glowing or noisy parts give a player
	-- away or hide them.
	ACCESSORY_STRIP = table.freeze({
		"ParticleEmitter",
		"Trail",
		"Beam",
		"Light",
		"Fire",
		"Smoke",
		"Sparkles",
		"Sound",
		"BaseScript",
		"Highlight",
		"BillboardGui",
		"SurfaceGui",
	}),

	-- What else is kept from the player's own avatar.
	KEEP_CLOTHING = true, -- classic Shirt, Pants, T-shirt
	KEEP_FACE = true,
	KEEP_SKIN = true, -- the six body colours

	-- How long to wait for a player's own description before falling back to
	-- the plain standard body (seconds), and how often to retry.
	FETCH_TIMEOUT = 6,
	-- A spawned body missing a skinned-body part (an asset that didn't load) is re-applied after these waits
	-- (seconds), then logged as failed (CharacterService, shared/HealthLog).
	BODY_RETRY = table.freeze({ 1, 3 }),
	-- Seconds after each failed lobby spawn before the next try (CharacterService.spawn; 3 tries 1 s apart until
	-- 2026-11-22). With CharacterAutoLoads off, giving up leaves the player with no character.
	SPAWN_RETRY = table.freeze({ 1, 2, 4, 8, 8 }),
})
