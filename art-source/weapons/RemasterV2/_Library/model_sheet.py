# model_sheet.py: renders the panels of a per-gun MODEL SHEET (2026-11-11, owner: "a whole 3d modeling page so I can
# plug that one gun into ChatGPT ... all angles, what the bullets look like, the mag"). Blender MCP only; the gun must be
# loaded with final_pass.load. The page itself is laid out by model_sheet_layout.py (plain Python + Pillow).
#   M["bind"](F); M["panels"](gun, out_dir) -> {"panels": {name: path}, "meta": {...}}
# Turnaround panels are rendered on a transparent film with lights that follow the camera, so every side is lit the
# same. The two first-person panels (held view, aim view) use the review range and its lights.

import bpy, math, os
from mathutils import Vector, Matrix

F = {}

AMMO = {
	"Vandal": ["Mag"], "Phantom": ["Mag"], "Bulldog": ["Mag"], "Guardian": ["Mag"], "Spectre": ["Mag"], "Stinger": ["Mag"],
	"Ares": ["Drum"], "Odin": ["AmmoBox", "FeedBelt"], "Sheriff": ["Cylinder", "Rounds"], "Classic": ["Magazine", "MagNeon"],
	"Ghost": ["Mag"], "Shorty": ["ShellUpper", "ShellLower"], "Bucky": ["Shell"], "Judge": ["Mag"], "Marshal": ["Shell"],
	"Outlaw": ["RoundUpper", "RoundLower"], "Operator": ["Magazine"], "Knife": [],
}
AMMO_LABEL = {
	"Ares": "Drum magazine", "Odin": "Ammo box and belt", "Sheriff": "Cylinder and rounds", "Shorty": "Shells (two, one per barrel)",
	"Bucky": "Shell (loaded one at a time)", "Judge": "Drum magazine", "Marshal": "Round (loaded one at a time)",
	"Outlaw": "Rounds (two, one per barrel)",
}
CLASS = {
	"Vandal": "Rifle", "Phantom": "Rifle, suppressed", "Bulldog": "Burst rifle, bullpup", "Guardian": "Marksman rifle", "Spectre": "SMG, suppressed",
	"Stinger": "SMG", "Ares": "Light machine gun", "Odin": "Heavy machine gun, belt fed", "Sheriff": "Revolver", "Classic": "Pistol",
	"Ghost": "Pistol, suppressed", "Shorty": "Sawed-off double shotgun", "Bucky": "Pump shotgun", "Judge": "Auto shotgun, drum",
	"Marshal": "Lever-action scoped rifle", "Outlaw": "Twin-barrel break-action sniper", "Operator": "Bolt-action sniper", "Knife": "Melee",
}


def bind(ns):
	F.update(ns)


def _pts(gun, parts=None, role=None):
	out = []
	for o in F["meshes"](gun):
		short = o.name[len(gun) + 1:]
		if parts is not None and short not in parts:
			continue
		mw = o.matrix_world
		if role is None:
			out += [mw @ v.co for v in o.data.vertices]
		else:
			idx = [i for i, s in enumerate(o.material_slots) if s.material and s.material.name == role]
			for p in o.data.polygons:
				if p.material_index in idx:
					out += [mw @ o.data.vertices[i].co for i in p.vertices]
	return out


def _cam(gun, name, pts, toward, up_hint=(0, 0, 1), ortho=False, lens=70.0, aspect=16 / 9, margin=1.1):
	# Camera looking along -toward (it sits on the `toward` side of the points), framed on the points.
	sc = F["scene"](gun)
	cname = gun + "_MS_" + name
	cam = bpy.data.objects.get(cname)
	if cam is None:
		cam = bpy.data.objects.new(cname, bpy.data.cameras.new(cname))
		cc = bpy.data.collections.get(gun + "_FP_Cams")
		if cc is None:
			cc = bpy.data.collections.new(gun + "_FP_Cams")
			sc.collection.children.link(cc)
		cc.objects.link(cam)
	fwd = -Vector(toward).normalized()
	right = fwd.cross(Vector(up_hint)).normalized()
	up = right.cross(fwd).normalized()
	lo = Vector([min(p[i] for p in pts) for i in range(3)])
	hi = Vector([max(p[i] for p in pts) for i in range(3)])
	c = (lo + hi) / 2
	xs = [(p - c).dot(right) for p in pts]
	ys = [(p - c).dot(up) for p in pts]
	zs = [(p - c).dot(-fwd) for p in pts]
	# re-centre on the projected extents so the subject sits in the middle of the frame
	c = c + right * ((max(xs) + min(xs)) / 2) + up * ((max(ys) + min(ys)) / 2)
	hw, hh = (max(xs) - min(xs)) / 2, (max(ys) - min(ys)) / 2
	d = cam.data
	d.clip_start, d.clip_end = 0.01, 500
	d.sensor_fit = "HORIZONTAL"
	d.sensor_width = 36
	if ortho:
		d.type = "ORTHO"
		d.ortho_scale = max(hw * 2, hh * 2 * aspect) * margin
		dist = max(zs) + 5.0
	else:
		d.type = "PERSP"
		d.lens = lens
		th = 18.0 / lens  # tan(half horizontal fov)
		tv = th / aspect
		dist = 0.0
		for p in pts:
			q = p - c
			x, y, z = abs(q.dot(right)), abs(q.dot(up)), q.dot(-fwd)
			dist = max(dist, z + x * margin / th, z + y * margin / tv)
	loc = c - fwd * dist
	cam.matrix_world = Matrix((
		(right.x, up.x, -fwd.x, loc.x),
		(right.y, up.y, -fwd.y, loc.y),
		(right.z, up.z, -fwd.z, loc.z),
		(0, 0, 0, 1)))
	return cam, c, max(hw, hh, (max(zs) - min(zs)) / 2)


def _lights(gun, cam, target, radius):
	# Four area lights placed from the camera's point of view, so each side of the gun is lit the same way.
	sc = F["scene"](gun)
	lc = bpy.data.collections.get(gun + "_MS_Lights")
	if lc is None:
		lc = bpy.data.collections.new(gun + "_MS_Lights")
		sc.collection.children.link(lc)
	mw = cam.matrix_world.to_3x3()
	right, up, back = mw @ Vector((1, 0, 0)), mw @ Vector((0, 1, 0)), mw @ Vector((0, 0, 1))
	dist = max(2.2, radius * 2.6)
	k = (dist / 3.9) ** 2
	spec = (
		("Key", -right * 0.75 + up * 0.9 + back * 1.0, 340 * k, 2.6),
		("Fill", right * 1.0 + up * 0.15 + back * 0.9, 150 * k, 3.0),
		("Rim", right * 0.5 + up * 0.7 - back * 1.0, 240 * k, 2.0),
		("Under", -right * 0.2 - up * 1.0 + back * 0.5, 80 * k, 3.0),
	)
	for name, v, energy, size in spec:
		oname = gun + "_MS_" + name
		ob = bpy.data.objects.get(oname)
		if ob is None:
			li = bpy.data.lights.new(oname, "AREA")
			ob = bpy.data.objects.new(oname, li)
			lc.objects.link(ob)
		ob.data.energy = energy
		ob.data.size = size * max(1.0, dist / 3.9)
		loc = Vector(target) + v.normalized() * dist
		ob.location = loc
		ob.rotation_euler = (Vector(target) - loc).to_track_quat("-Z", "Y").to_euler()
	return lc


def _shot(gun, cam, path, res, show=None, studio=True, samples=40):
	sc = F["scene"](gun)
	rv2 = bpy.data.collections.get(gun + "_RV2_Lights")
	ms = bpy.data.collections.get(gun + "_MS_Lights")
	hidden = []
	if show is not None:
		for o in F["meshes"](gun):
			if o.name[len(gun) + 1:] not in show and not o.hide_render:
				o.hide_render = True
				hidden.append(o)
	old = (sc.render.film_transparent, rv2.hide_render if rv2 else None, ms.hide_render if ms else None)
	sc.render.film_transparent = studio
	bgn = sc.world.node_tree.nodes.get("Background") if sc.world and sc.world.use_nodes else None
	old_bg = bgn.inputs["Strength"].default_value if bgn else None
	if bgn and studio:
		bgn.inputs["Strength"].default_value = 1.6
	sc.render.image_settings.color_mode = "RGBA"
	if rv2:
		rv2.hide_render = studio
	if ms:
		ms.hide_render = not studio
	try:
		F["shot"](gun, cam, path, res=res, rng=not studio, samples=samples)
	finally:
		sc.render.film_transparent = old[0]
		if bgn:
			bgn.inputs["Strength"].default_value = old_bg
		if rv2:
			rv2.hide_render = False
		if ms:
			ms.hide_render = True
		for o in hidden:
			o.hide_render = False
	return path


def panels(gun, out_dir, cell=(960, 540)):
	sc = F["scene"](gun)
	bpy.context.window.scene = sc
	F["rest"](gun)
	sc.view_layers[0].update()
	os.makedirs(out_dir, exist_ok=True)
	W, H = cell
	P = {}
	allp = _pts(gun)
	names = [o.name[len(gun) + 1:] for o in F["meshes"](gun)]

	def studio(name, pts, toward, up=(0, 0, 1), ortho=False, lens=70.0, res=None, show=None, margin=1.1):
		res = res or (W, H)
		cam, c, r = _cam(gun, name, pts, toward, up, ortho, lens, res[0] / res[1], margin)
		_lights(gun, cam, c, r)
		P[name] = _shot(gun, cam, "%s/%s.png" % (out_dir, name), res, show=show, studio=True)

	studio("hero", allp, (0.52, 0.72, 0.36), res=(W * 2, H * 2), lens=60)
	studio("left", allp, (0, 1, 0), ortho=True)
	studio("right", allp, (0, -1, 0), ortho=True)
	studio("top", allp, (0, 0, 1), up=(0, -1, 0), ortho=True)
	studio("bottom", allp, (0, 0, -1), up=(0, 1, 0), ortho=True)
	studio("rear34", allp, (-0.55, -0.7, 0.34), lens=60)
	studio("front", allp, (1, 0, 0), ortho=True, res=(W // 2, H), margin=1.25)
	studio("back", allp, (-1, 0, 0), ortho=True, res=(W // 2, H), margin=1.25)

	meta = {"gun": gun, "class": CLASS.get(gun, ""), "tris": F["tris"](gun), "labels": {}}
	ammo = [a for a in AMMO.get(gun, []) if a in names]
	if ammo:
		studio("ammo", _pts(gun, ammo), (0.45, 0.75, 0.4), show=ammo, lens=80, margin=1.25)
		brass = _pts(gun, ammo, "Brass")
		meta["labels"]["ammo"] = AMMO_LABEL.get(gun, "Magazine (out of the gun)")
		meta["labels"]["round"] = "Shell close-up" if gun in ("Shorty", "Bucky", "Judge") else "Round close-up"
		if gun == "Sheriff":
			studio("round", brass or _pts(gun, ammo), (-0.85, 0.4, 0.35), show=ammo, lens=90, margin=1.5)
			meta["labels"]["round"] = "Case heads in the cylinder (from behind)"
		elif brass:
			studio("round", brass, (0.3, 0.88, 0.3), show=ammo, lens=90, margin=2.3)
		else:
			studio("round", _pts(gun, ammo), (-0.45, -0.75, 0.4), show=ammo, lens=80, margin=1.25)
			meta["labels"]["round"] = meta["labels"]["ammo"].split(" (")[0] + ", other side"
	else:
		studio("ammo", _pts(gun, ["Blade"]), (0.2, 0.9, 0.4), lens=80, margin=1.2)
		studio("round", _pts(gun, ["Hilt"]), (-0.3, 0.85, 0.4), lens=80, margin=1.2)
		meta["labels"]["ammo"] = "Blade"
		meta["labels"]["round"] = "Handle"

	aim = F["locator"](gun, "AimPoint")
	sight_parts = [n for n in names if "Sight" in n or "Scope" in n]
	if gun in F["ADS"]:
		near = [p for p in _pts(gun, sight_parts) if (p - aim).length < 0.3] or _pts(gun, sight_parts)
		studio("sights", near, (-0.55, 0.6, 0.5), lens=80, margin=1.5)
		meta["labels"]["sights"] = "Rear sight"
		cam = F["ads_cam"](gun)
		lo_, hi_ = F["bounds"](gun)
		_lights(gun, cam, (lo_ + hi_) / 2, (hi_ - lo_).length / 2)
		P["aim"] = _shot(gun, cam, "%s/aim.png" % out_dir, (W, H), studio=True, samples=32)
		meta["labels"]["aim"] = "Aiming down the sights (in game)"
	else:
		if sight_parts:
			studio("sights", _pts(gun, sight_parts), (-0.5, 0.65, 0.5), lens=80, margin=1.25)
			meta["labels"]["sights"] = "Scope" if any("Scope" in n for n in sight_parts) else "Sights"
		else:
			top = [p for p in allp if p.z > max(q.z for q in allp) - 0.14]
			studio("sights", top, (-0.5, 0.65, 0.55), lens=80, margin=1.2)
			meta["labels"]["sights"] = "Top detail"
		studio("aim", allp, (-0.35, 0.5, 0.8), lens=60)
		meta["labels"]["aim"] = "Three-quarter from above"

	studio("held", allp, (-0.85, 0.34, 0.3), lens=50)
	meta["labels"]["held"] = "First-person angle (what the player sees most)"

	cp = F["locator"](gun, "CharmPoint")
	if cp is not None:
		box = [cp + Vector(v) for v in ((-0.1, 0, -0.07), (0.1, 0, 0.09), (0, 0.01, 0), (0, -0.01, 0))]
		studio("charm", box, (0.25, 0.9, 0.3), lens=80, margin=1.0)
		meta["labels"]["charm"] = "Charm stud (left side)" if gun in ("Classic", "Shorty") else "Charm mount (plate and ring, left side)"
	else:
		studio("charm", allp, (0.6, -0.6, 0.45), lens=60)
		meta["labels"]["charm"] = "Three-quarter, right side"
	meta["palette"] = [[m.name, m.get("rbx_color", "")] for m in (bpy.data.materials.get(r) for r in ("Body", "Panel", "Dark", "Grip", "Metal", "Accent", "Neon", "Brass", "Glass")) if m is not None]
	return {"panels": P, "meta": meta}
