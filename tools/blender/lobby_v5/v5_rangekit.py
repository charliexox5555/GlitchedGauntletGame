"""Range kit v2 (owner 2026-11-21): the jump pad remade with no overlapping parts, and a loadout terminal that replaces
the RIVALS-like loadout bins ("I don't really want it to be a bin ... made in Blender ... look professional").
Run in a live Blender MCP instance with v5_props importable:

    build()   rebuilds the V5RangeKit collection (JumpPad_<Role>, Terminal_<Role>)
    export()  writes art-source/lobby/v5/Exports/V5_RangeKit.fbx

Rules (props-crisp-connected): every piece either touches its neighbour on a face or sits in a groove cut for it with
a 0.02 margin; nothing passes through anything. Glow strips sit 0.03 under the surface they are set into.
Roles: Trim, Body, Rubber, Hardware, Accent (glow), Screen.
"""
import math
import os

import bmesh
import bpy
from mathutils import Matrix

import v5_props as K

OUT = os.path.join(K.ROOT, "art-source", "lobby", "v5", "Exports", "V5_RangeKit.fbx")
COLL = "V5RangeKit"
K.ROLES.setdefault("Screen", (0x16, 0x18, 0x1C))


def chev_pts(w=0.8, h=0.55, t=0.3):
	return [(-w, 0.0), (0.0, h), (w, 0.0), (w, t), (0.0, h + t), (-w, t)]


def placed(pts, r, ang):
	"""2D outline moved out to radius r on the axis at angle ang (its +y pointing outward)."""
	c, s = math.cos(ang - math.pi / 2), math.sin(ang - math.pi / 2)
	return [(x * c - (y + r) * s, x * s + (y + r) * c) for x, y in pts]


def inset(pts, d):
	"""Shrink a convex-ish outline toward its centre by d (good enough for the small glow pieces)."""
	cx = sum(p[0] for p in pts) / len(pts)
	cy = sum(p[1] for p in pts) / len(pts)
	out = []
	for x, y in pts:
		vx, vy = x - cx, y - cy
		L = math.hypot(vx, vy) or 1
		out.append((x - vx / L * d, y - vy / L * d))
	return out


# ---------------------------------------------------------------- jump pad v2
def jump_pad():
	K._prop[0] = "JumpPad"
	S, C = 5.0, 1.0
	B0, B1, R1 = 0.0, 0.3, 0.85  # base top, rim top
	D1 = 0.55  # deck top
	outer = K.cham_rect(-S, S, -S, S, C)
	inner = K.cham_rect(-S + 1.0, S - 1.0, -S + 1.0, S - 1.0, C - 0.45)
	K.add("Trim", K.prism(outer, "XY", B0, B1, cham=0.04, taper=(1.03, 1.0)))
	# rim: a frame (outer minus inner), vent notches cut in the middle of each side, a pocket in each corner
	rim = K.prism(K.cham_rect(-S + 0.12, S - 0.12, -S + 0.12, S - 0.12, C - 0.06), "XY", B1, R1, cham=0.04)
	rim = K.cut(rim, [K.prism(inner, "XY", B1 - 1, R1 + 1)])
	for ax in ((1, 0), (-1, 0), (0, 1), (0, -1)):
		if ax[0] == 0:
			x0, x1, y0, y1 = -0.9, 0.9, min(ax[1] * (S - 1.2), ax[1] * (S + 0.5)), max(ax[1] * (S - 1.2), ax[1] * (S + 0.5))
		else:
			y0, y1, x0, x1 = -0.9, 0.9, min(ax[0] * (S - 1.2), ax[0] * (S + 0.5)), max(ax[0] * (S - 1.2), ax[0] * (S + 0.5))
		rim = K.cut(rim, [K.box(x0, x1, y0, y1, R1 - 0.2, R1 + 1)])
	pockets = []
	for sx in (-1, 1):
		for sy in (-1, 1):
			cx, cy = sx * (S - 0.62), sy * (S - 0.62)
			pockets.append((cx, cy))
			rim = K.cut(rim, [K.prism(K.cham_rect(cx - 0.42, cx + 0.42, cy - 0.42, cy + 0.42, 0.14), "XY", R1 - 0.15, R1 + 1)])
	K.add("Body", rim)
	for cx, cy in pockets:  # steel inserts in the corner pockets, 0.02 margin, top 0.03 under the rim
		K.add("Hardware", K.prism(K.cham_rect(cx - 0.4, cx + 0.4, cy - 0.4, cy + 0.4, 0.13), "XY", R1 - 0.15, R1 - 0.03, cham=0.015))
	# deck fills the rim's hole; grooves cut for the ring, the core and four chevrons
	deck = K.prism(inner, "XY", B1, D1)
	G = D1 - 0.12  # groove floor
	deck = K.cut(deck, [K.annulus(8, 2.78, 2.22, G, D1 + 1, rot=math.pi / 8)])
	deck = K.cut(deck, [K.prism(K.ngon(0, 0, 1.22, 8, math.pi / 8), "XY", G, D1 + 1)])
	for i in range(4):
		deck = K.cut(deck, [K.prism(placed(chev_pts(), 2.95, i * math.pi / 2), "XY", G, D1 + 1)])
	K.add("Rubber", deck)
	K.add("Accent", K.annulus(8, 2.76, 2.24, G, D1 - 0.03, rot=math.pi / 8))
	K.add("Accent", K.prism(K.ngon(0, 0, 1.2, 8, math.pi / 8), "XY", G, D1 - 0.03))
	for i in range(4):
		K.add("Accent", K.prism(inset(placed(chev_pts(), 2.95, i * math.pi / 2), 0.02), "XY", G, D1 - 0.03))


# ---------------------------------------------------------------- loadout terminal
def terminal():
	"""A supply terminal: plinth, a tall body with a recessed lit bay (where the loadout menu lives), a screen head,
	grooves cut down the sides, a drawer seam with a cut pull. Front = -Y. 4.2 wide, 2.6 deep, 6.6 tall."""
	K._prop[0] = "Terminal"
	HX, HY = 1.8, 1.0
	K.add("Trim", K.box(-HX - 0.3, HX + 0.3, -HY - 0.3, HY + 0.3, 0.0, 0.45, 0.05))
	cuts = []
	cuts.append(K.box(-1.35, 1.35, -HY - 0.5, -HY + 0.55, 1.7, 4.5))  # the bay
	cuts.append(K.box(-1.35, 1.35, -HY - 0.5, -HY + 0.06, 0.75, 0.8))  # drawer seam (top)
	cuts.append(K.box(-0.5, 0.5, -HY - 0.5, -HY + 0.12, 1.12, 1.3))  # drawer pull slot
	for z in (1.4, 2.9, 4.4):  # side grooves
		for sx in (-1, 1):
			cuts.append(K.box(sx * HX - 0.08, sx * HX + 0.08, -HY + 0.4, HY - 0.4, z - 0.06, z + 0.06))
	body = K.box(-HX, HX, -HY, HY, 0.45, 5.6, 0.05)
	for c in cuts:
		body = K.cut(body, [c])
	K.add("Body", body)
	# inside the bay: a dark back panel, a light strip under the bay's head, a shelf at its foot
	K.add("Trim", K.box(-1.33, 1.33, -HY + 0.53, -HY + 0.55, 1.72, 4.48))
	K.add("Accent", K.box(-1.25, 1.25, -HY + 0.12, -HY + 0.42, 4.36, 4.48))
	K.add("Hardware", K.box(-1.33, 1.33, -HY - 0.12, -HY + 0.53, 1.7, 1.85, 0.02))
	# head: overhangs the body a little, a screen set into its sloped front
	head = K.loft([(K.cham_rect(-HX - 0.15, HX + 0.15, -HY - 0.15, HY + 0.15, 0.08), 5.6), (K.cham_rect(-HX - 0.15, HX + 0.15, -HY + 0.25, HY + 0.15, 0.08), 6.6)], cham=0.03)
	slope = math.atan2(0.4, 1.0)
	scr = K.box(-1.45, 1.45, -0.03, 0.2, -0.38, 0.38)
	m = Matrix.Translation((0, -HY - 0.15 + 0.2, 6.1)) @ Matrix.Rotation(-slope, 4, "X")
	head = K.cut(head, [K.xform(scr, m)])
	K.add("Body", head)
	panel = K.box(-1.42, 1.42, 0.0, 0.03, -0.35, 0.35)
	K.add("Screen", K.xform(panel, m @ Matrix.Translation((0, 0.17, 0))))
	# a light bar on top, set into a groove
	K.add("Accent", K.box(-1.2, 1.2, -0.12, 0.12, 6.58, 6.62))


def build():
	K.PIECES.clear()
	coll = bpy.data.collections.get(COLL)
	if coll:
		for o in list(coll.objects):
			me = o.data
			bpy.data.objects.remove(o)
			if me and me.users == 0:
				bpy.data.meshes.remove(me)
	else:
		coll = bpy.data.collections.new(COLL)
		bpy.context.scene.collection.children.link(coll)
	jump_pad()
	terminal()
	merged = {}
	for prop, role, bm in K.PIECES:
		key = (prop, role)
		if key not in merged:
			merged[key] = bmesh.new()
		me = bpy.data.meshes.new("_tmp")
		bm.to_mesh(me)
		merged[key].from_mesh(me)
		bpy.data.meshes.remove(me)
		bm.free()
	stats = {}
	for (prop, role), bm in merged.items():
		me = bpy.data.meshes.new(prop + "_" + role)
		bm.to_mesh(me)
		bm.free()
		for p in me.polygons:
			p.use_smooth = False
		me.materials.append(K.mat(role))
		ob = bpy.data.objects.new(prop + "_" + role, me)
		ob.location = (0 if prop == "JumpPad" else 9, 50, 0)
		coll.objects.link(ob)
		stats[prop + "_" + role] = len(me.polygons)
	return stats


def export():
	bpy.ops.object.select_all(action="DESELECT")
	coll = bpy.data.collections[COLL]
	saved = {}
	for ob in coll.objects:
		saved[ob.name] = ob.location.copy()
		ob.location.y = 0
		ob.select_set(True)
	bpy.context.view_layer.objects.active = coll.objects[0]
	bpy.ops.export_scene.fbx(filepath=OUT, use_selection=True, object_types={"MESH"}, apply_scale_options="FBX_SCALE_UNITS", bake_anim=False)
	for ob in coll.objects:
		ob.location = saved[ob.name]
	return {"path": OUT}
