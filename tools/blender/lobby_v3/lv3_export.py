"""Lobby V3 export for Studio (run through Blender MCP after lv3_run.build_all()).

Writes, per area (Hub, Duels, Market, Vault, Range):
  art-source/lobby/Exports/V3_<Area>.fbx        visible meshes (same FBX settings as export_lobby_kit.py)
  art-source/lobby/Exports/V3Data/<Area>.json          parts (name, look, centre, size), lights, moving groups
  art-source/lobby/Exports/V3Data/<Area>_col<N>.json   hidden opaque colliders (see lv3_core COLLISION)
Upload the meshes with tools/opencloud/upload_models.py --lobby and the data with tools/studio/lobby_v3/upload_data.py.
"""
import json
import os
from math import cos, sin, pi, radians
import bpy
from mathutils import Vector
import lv3_core as C

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
FBX_DIR = os.path.join(REPO, "art-source", "lobby", "Exports")
DATA_DIR = os.path.join(REPO, "art-source", "lobby", "Exports", "V3Data")
AREAS = ("Hub", "Duels", "Market", "Vault", "Range")
D = radians

# my material -> Roblox look: (Material, MaterialVariant, colour, extras)
def _L(material, variant, color, **kw):
	d = {"m": material, "v": variant, "c": color}
	d.update(kw)
	return d


LOOKS = {
	"Concrete": _L("Concrete", "Lobby_ConcreteBoard", "#8A8884"),
	"ConcreteHub": _L("Concrete", "Lobby_ConcreteBoard", "#8A8884"),
	"ConcreteRange": _L("Concrete", "Lobby_ConcreteBoard", "#737270"),
	"ConcreteDuels": _L("Concrete", "Lobby_ConcreteBoard", "#787774"),
	"ConcreteLight": _L("Concrete", "Bunker_Concrete", "#ABA79E"),
	"ConcreteDark": _L("Concrete", "Lobby_ConcreteDark", "#55524E"),
	"ConcreteCeil": _L("Concrete", "Bunker_Concrete", "#807C75"),
	"Baffle": _L("Fabric", "", "#2B3035"),
	"Plaster": _L("Plaster", "", "#BDB6A8"),
	"FloorHub": _L("Concrete", "Lobby_ConcretePolished", "#86847F"),
	"SunStone": _L("Concrete", "Lobby_Terrazzo", "#9C9483"),
	"FloorPale": _L("Concrete", "Lobby_Terrazzo", "#A8A092"),
	"FloorDark": _L("Slate", "Bunker_Floor", "#3C3E42"),
	"FloorMid": _L("Slate", "Bunker_Floor", "#57595D"),
	"FloorWarm": _L("Slate", "Bunker_Floor", "#6F6558"),
	"Rubber": _L("Concrete", "Lobby_ConcreteDark", "#2A2C2F"),
	"VaultFloor": _L("Concrete", "Lobby_ConcretePolished", "#33373C"),
	"Steel": _L("Metal", "Bunker_Metal", "#232528"),
	"SteelBlue": _L("Metal", "Bunker_Metal", "#2F3D48"),
	"Brushed": _L("Metal", "Bunker_Metal", "#7E8388"),
	"VaultPanel": _L("Metal", "Bunker_Metal", "#6C737A"),
	"Locker": _L("Metal", "Bunker_Metal", "#2E4252"),
	"Brass": _L("Metal", "", "#A57B3C", r=0.15),
	"Rock": _L("Slate", "Lobby_Rock", "#57534E"),
	"RockDark": _L("Slate", "Lobby_Rock", "#34332F"),
	"Oak": _L("Wood", "Lobby_Oak", "#9A8F84"),
	"OakApse": _L("Wood", "Lobby_Oak", "#9A8F84"),
	"OakDark": _L("Wood", "Lobby_Oak", "#6B625A"),
	"Hazard": _L("SmoothPlastic", "", "#B8862F"),
	"Screen": _L("SmoothPlastic", "", "#14171B"),
	"ScreenOn": _L("SmoothPlastic", "", "#131A24"),
	"Target": _L("SmoothPlastic", "", "#D8D2C4"),
	"P_White": _L("SmoothPlastic", "", "#DAD7CF"),
	"Glass": _L("Glass", "", "#BFD8E0", t=0.6),
	"SignCream": _L("SmoothPlastic", "", "#DDD8CB"),
	"HazardBlack": _L("SmoothPlastic", "", "#1E1F22"),
	"CaseOlive": _L("SmoothPlastic", "", "#5F7D4E"),
	"CaseSand": _L("SmoothPlastic", "", "#C4A869"),
	"CaseDark": _L("SmoothPlastic", "", "#2B3138"),
	"Sack": _L("Fabric", "", "#857557"),
	"ClothRed": _L("Fabric", "", "#A63A2E"),
	"ClothBlue": _L("Fabric", "", "#2F5F86"),
	"ClothGold": _L("Fabric", "", "#B88E36"),
	"Leaf": _L("SmoothPlastic", "", "#3B6E41"),
	"Pot": _L("Sandstone", "", "#9C5B3D"),
	"BottleG": _L("SmoothPlastic", "", "#2B5335", r=0.25),
	"BottleA": _L("SmoothPlastic", "", "#8A521C", r=0.25),
	"Crate": _L("WoodPlanks", "", "#8E8272"),
}
PAINT = {"P_Duels": "#D9542F", "P_Market": "#D9A238", "P_Vault": "#3BBBD0", "P_Range": "#4FC06C",
	"P_Gauntlet": "#9C2630", "P_1v1": "#E0702F", "P_2v2": "#2E9FD8", "P_3v3": "#8F58D8"}
GLOW = {"E_Warm": "#FFE6CC", "E_Cool": "#DCE8FF", "E_Cove": "#FFE6CC", "E_CoveCool": "#DCE8FF", "E_CoveSoft": "#FFE6CC",
	"E_Down": "#FFE9D0", "E_Lantern": "#FFD3A0", "E_HighBay": "#E6EEFF", "E_PadSpot": "#FFE9D0", "E_VaultLamp": "#E6F4FF",
	"E_RangeBar": "#E4EEF8", "E_RangeHall": "#EAF2FA", "E_Duels": C.ACCENT["Duels"], "E_Market": C.ACCENT["Market"],
	"E_Vault": C.ACCENT["Vault"], "E_Range": C.ACCENT["Range"], "E_Gauntlet": C.ACCENT["Gauntlet"],
	"L_1v1": "#FF7A2F", "L_2v2": "#27B7FF", "L_3v3": "#A15CFF"}


# Hub only: clean stylized surfaces (owner 2026-11-10: the concrete textures read dull and too realistic)
LOOKS_AREA = {"Hub": {  # neutral and tactical: no colour on the walls, colour only in signs, lamps and floor paint
	"ConcreteHub": _L("Plaster", "", "#767970"),
	"Concrete": _L("Plaster", "", "#767970"),
	"ConcreteDark": _L("SmoothPlastic", "", "#3F444A"),
	"ConcreteCeil": _L("Plaster", "", "#62655E"),
	"SteelBlue": _L("SmoothPlastic", "", "#353B42"),
	"Steel": _L("SmoothPlastic", "", "#1E2227"),
	"FloorHub": _L("Plaster", "", "#5F6266"),
	"SunStone": _L("Plaster", "", "#9E998C"),
	"Brass": _L("Metal", "", "#9C7A36", r=0.05),
	"FloorDark": _L("SmoothPlastic", "", "#33383E"),
	"FloorPale": _L("Plaster", "", "#A89F8D"),
	"Rubber": _L("SmoothPlastic", "", "#2C3137"),
	"Brushed": _L("SmoothPlastic", "", "#8A939C", r=0.08),
	"ConcreteLight": _L("Plaster", "", "#8F9189"),
	"OakDark": _L("Wood", "", "#4E3B2B"),
	"Hazard": _L("SmoothPlastic", "", "#A8842F"),
	"CaseSand": _L("SmoothPlastic", "", "#8F8468"),
	"CaseOlive": _L("SmoothPlastic", "", "#4B5A43"),
	"BenchPad": _L("SmoothPlastic", "", "#4C5A68"),
}}
LOOKS_AREA["Vault"] = {  # the Locker: clean, smooth, cool greys; cyan only in the hologram and thin lights
	"VaultPanel": _L("SmoothPlastic", "", "#56616D"),
	"VaultPier": _L("SmoothPlastic", "", "#65717E"),
	"VaultFloor": _L("SmoothPlastic", "", "#2B3138", r=0.06),
	"BayBack": _L("SmoothPlastic", "", "#A9B2BC"),
	"Cabinet": _L("SmoothPlastic", "", "#353D46"),
	"Concrete": _L("SmoothPlastic", "", "#56616D"),
	"ConcreteCeil": _L("SmoothPlastic", "", "#454D56"),
	"Steel": _L("SmoothPlastic", "", "#1E2227"),
	"Brushed": _L("SmoothPlastic", "", "#8A939C", r=0.08),
	"Rubber": _L("SmoothPlastic", "", "#2B3138"),
	"CaseOlive": _L("SmoothPlastic", "", "#4B5A43"),
	"CaseDark": _L("SmoothPlastic", "", "#2B3138"),
	"Holo": _L("ForceField", "", "#45DCFF"),
	"Glass": _L("Glass", "", "#D5E8F2", t=0.78, r=0.08),
	"E_Lens": _L("Neon", "", "#45DCFF", glow=True, pulse=True),
}
LOOKS_AREA["Duels"] = {  # dark and neutral: the pads and the holograms carry the colour
	"ConcreteDuels": _L("Plaster", "", "#3E4246"),
	"DuelPier": _L("SmoothPlastic", "", "#2B2F34"),
	"DuelUpper": _L("Plaster", "", "#2A2D31"),
	"DuelFloor": _L("SmoothPlastic", "", "#2A2E33", r=0.05),
	"DuelStage": _L("SmoothPlastic", "", "#34393F"),
	"FloorDark": _L("SmoothPlastic", "", "#2A2E33", r=0.05),
	"ConcreteCeil": _L("Plaster", "", "#1F2225"),
	"Steel": _L("SmoothPlastic", "", "#17191C"),
	"Brushed": _L("SmoothPlastic", "", "#6E7780"),
	"PortalPanel": _L("SmoothPlastic", "", "#0E1014"),
	"BenchPad": _L("SmoothPlastic", "", "#3A424B"),
	"BenchBase": _L("SmoothPlastic", "", "#24282D"),
	"PadInk": _L("SmoothPlastic", "", "#14161A"),
	"PadOff": _L("SmoothPlastic", "", "#3A3F45"),
	"N_TeamA": _L("Neon", "", "#FF6A3D", glow=True),
	"N_TeamB": _L("Neon", "", "#2A86FF", glow=True),
	"HoloLine": _L("Neon", "", "#7FD4FF", glow=True),
	"HoloGate": _L("Neon", "", "#7FD4FF", glow=True, pulse=True),
	"HoloPane": _L("Neon", "", "#1F6FA8", t=0.82, glow=True),
	"E_Spine": _L("Neon", "", "#E6EEFF", glow=True),
	"E_PierStrip": _L("Neon", "", "#CFE0FF", glow=True),
}
NEON = {"N_Duels": "#FF6A3D", "N_Market": "#FFC233", "N_Vault": "#45DCFF", "N_Range": "#5CFF8A", "N_White": "#FFF1DC", "E_Trophy": "#FFD9A0"}
EXTRA = {
	"Seam": _L("SmoothPlastic", "", "#726E67"),
	"SignFace": _L("SmoothPlastic", "", "#EFE8D8"),
	"SignPlate": _L("SmoothPlastic", "", "#15181D"),
	"GGold": _L("Metal", "", "#B8892E", r=0.05),
	"GSteel": _L("Metal", "", "#4A525B"),
	"GDark": _L("SmoothPlastic", "", "#2A313A"),
	"BenchBase": _L("SmoothPlastic", "", "#3A4654"),
	"BenchPad": _L("SmoothPlastic", "", "#3F86B5"),
}


def look_for(matname, area=None):
	if area in LOOKS_AREA and matname in LOOKS_AREA[area]:
		return LOOKS_AREA[area][matname]
	if matname in EXTRA:
		return EXTRA[matname]
	if matname in NEON:
		return _L("Neon", "", NEON[matname], glow=True)
	if matname.startswith("Trim_") and "P_" + matname[5:] in PAINT:
		return _L("SmoothPlastic", "", PAINT["P_" + matname[5:]])
	if matname in LOOKS:
		return LOOKS[matname]
	if matname in PAINT:
		return _L("SmoothPlastic", "", PAINT[matname])
	if matname in GLOW:
		return _L("Neon", "", GLOW[matname], glow=True)
	return _L("SmoothPlastic", "", "#FF00FF")


# ---------------------------------------------------------------- lights (Blender coordinates)
WARM, COOL, AMBER, SPOTW = "#FFF0DE", "#DCE8FF", "#FFD3A0", "#FFF0DE"


def _rot(rot, x, y):
	return (x * cos(rot) - y * sin(rot), x * sin(rot) + y * cos(rot))


def lights():
	L = {a: [] for a in AREAS}

	def pt(area, x, y, z, color, b, rng, rot=0.0):
		wx, wy = _rot(rot, x, y)
		L[area].append(["P", round(wx, 2), round(wy, 2), z, color, b, rng])

	def spot(area, x, y, z, color, b, rng, ang, rot=0.0):
		wx, wy = _rot(rot, x, y)
		L[area].append(["S", round(wx, 2), round(wy, 2), z, color, b, rng, ang])

	# hub
	for ax in (0, 90, 180, 270):
		for s in (-1, 1):
			a = D(ax + s * 27)
			pt("Hub", 32.9 * cos(a), 32.9 * sin(a), 7.4, WARM, 0.9, 14)
	for k in range(8):
		a = D(45 * k)
		spot("Hub", 33.4 * cos(a), 33.4 * sin(a), 20.5, SPOTW, 1.5, 28, 110)
	for k in range(6):
		a = D(60 * k + 30)
		pt("Hub", 26 * cos(a), 26 * sin(a), 22.4, WARM, 0.7, 20)
	for ax, col in ((90, NEON["N_Duels"]), (180, NEON["N_Market"]), (0, NEON["N_Vault"]), (270, NEON["N_Range"])):  # sign glow
		pt("Hub", 31.8 * cos(D(ax)), 31.8 * sin(D(ax)), 17.2, col, 0.24, 9)  # a faint glow only: no colour on the walls
	pt("Hub", 0, 0, 13.0, "#FFE2A8", 1.2, 26)  # trophy
	pt("Hub", 0, 41, 10.6, WARM, 1.0, 16)
	pt("Hub", -41, 0, 11.5, AMBER, 1.0, 16)
	pt("Hub", 41, 0, 12.5, COOL, 1.0, 16)
	pt("Hub", 0, -41, 10.6, COOL, 1.0, 16)
	# duels: an even spine down the aisle, a fill light and two pad lights at every station, and every corner lit
	import lv3_duels as DU
	y = 66
	while y < DU.YE - 6:
		spot("Duels", 0, y, 15.6, "#E6EEFF", 2.0, 44, 140)
		for sx in (-1, 1):  # soft fill high on each side so the upper walls and corners are never black
			pt("Duels", sx * 15, y + 10, 15.0, "#DCE6F5", 0.55, 30)
		y += 20
	for side, yc, mode, letter, live in DU.STATIONS:
		Ms = DU.local(side, yc)
		w = Ms @ Vector((0, 7.0, 0))
		spot("Duels", w.x, w.y, 9.8, "#EAF2FF", 1.5, 26, 120)
		w = Ms @ Vector((0, 1.6, 0))
		pt("Duels", w.x, w.y, 2.0, "#7FD4FF", 0.7, 12)  # glow of the hologram boards
	for row in DU.PADS:
		if row[8]:
			pt("Duels", row[2], row[3], row[4] + 2.6, "#FF6A3D" if row[0].endswith("W") else "#2E9BFF", 0.8, 11)
	for x, y2 in ((-18, 62), (18, 62), (20, 87.5), (20, 222.5), (-23, 239), (23, 239)):  # nooks and corners
		pt("Duels", x, y2, 3.0, "#E6EEFF", 1.0, 22)
	pt("Duels", 0, 56, 8.0, "#FFF0DE", 1.0, 18)
	spot("Duels", 0, 238, 14.0, "#FFF0DE", 2.2, 26, 110)
	for sx in (-1, 1):
		pt("Duels", sx * 16.5, 233, DU.ZS + 5.6, "#FFF0DE", 0.9, 12)
	# market (local frame, rotated +90)
	r = D(90)
	for x in (-19.0, 19.0):
		for y in (65.5, 82, 100):
			pt("Market", x, y, 11.5, AMBER, 1.3, 24, r)
	pt("Market", 0, 82, 7.4, AMBER, 1.2, 20, r)
	for y in (64, 82, 100):
		spot("Market", 33.2, y, 11.6, SPOTW, 1.6, 16, 90, r)
	for y in (76, 88):
		spot("Market", -33.0, y, 12.6, SPOTW, 1.8, 18, 90, r)
	spot("Market", -33.2, 103.5, 8.0, SPOTW, 1.4, 14, 90, r)
	for a in (D(55), D(90), D(125)):
		spot("Market", 11.5 * cos(a), 115 + 11.5 * sin(a), 16.8, SPOTW, 1.6, 22, 80, r)
	# locker (local frame, rotated -90): one soft fill, a spot on the hero gun, one light in each display bay
	r = D(-90)
	spot("Vault", 0, 76, 20.5, "#E6F4FF", 1.4, 40, 140, r)
	spot("Vault", 0, 76, 13.0, "#EAF6FF", 4.0, 13, 80, r)
	for m in (-45, 0, 45, 90, 135, 180, 225):
		pt("Vault", 26.4 * cos(D(m)), 76 + 26.4 * sin(D(m)), 9.6, "#F2F7FF", 1.0, 12, r)
	# range (local frame, rotated 180)
	r = D(180)
	for y in (60, 68, 76, 84):
		pt("Range", 0, y + 1.0, 14.6, "#E4EEF8", 1.0, 30, r)
		pt("Range", -25.6, y - 0.6, 7.0, "#E4EEF8", 0.7, 12, r)
	for x in (-16, 16):
		spot("Range", x, 91, 6.1, SPOTW, 1.5, 12, 110, r)
	pt("Range", 29.6, 75, 8.6, SPOTW, 0.8, 12, r)
	for y in (106, 118, 130, 142, 154):
		pt("Range", 0, y, 12.6, "#EAF2FA", 1.1, 42, r)
	mult = {"Hub": 1.25, "Duels": 1.0, "Market": 1.0, "Vault": 1.1, "Range": 0.7}  # tuned in Studio 2026-11-10
	for area, rows in L.items():
		for r in rows:
			r[5] = round(r[5] * mult[area], 2)
	return L


# ---------------------------------------------------------------- export
def _objects(area):
	obs = []
	for cname in (area, area + "_Ceil"):
		col = bpy.data.collections.get(cname)
		if col:
			obs += [o for o in col.objects if o.type == "MESH" and not o.name.endswith("_Dummy")]
	return obs


def run():
	os.makedirs(FBX_DIR, exist_ok=True)
	os.makedirs(DATA_DIR, exist_ok=True)
	for f in os.listdir(DATA_DIR):
		if f.endswith(".json"):
			os.remove(os.path.join(DATA_DIR, f))
	dg = bpy.context.evaluated_depsgraph_get()
	lts = lights()
	summary = {}
	for area in AREAS:
		obs = _objects(area)
		parts = []
		tris = 0
		for o in obs:
			e = o.evaluated_get(dg)
			me = e.to_mesh()
			me.calc_loop_triangles()
			xs = [v.co for v in me.vertices]
			lo = [min(c[i] for c in xs) for i in range(3)]
			hi = [max(c[i] for c in xs) for i in range(3)]
			n = len(me.loop_triangles)
			e.to_mesh_clear()
			tris += n
			mname = o.data.materials[0].name
			grp = o.name.split("_")[0] if o.name.startswith("Anim") else None
			parts.append({"n": o.name, "mat": mname, "look": look_for(mname, area), "grp": grp,
				"c": [round((a + b) / 2, 4) for a, b in zip(lo, hi)], "s": [round(b - a, 4) for a, b in zip(lo, hi)],
				"ceil": 1 if o.users_collection[0].name.endswith("_Ceil") else 0, "t": n})
		bpy.ops.object.select_all(action="DESELECT")
		for o in obs:
			o.select_set(True)
		bpy.context.view_layer.objects.active = obs[0]
		fbx = os.path.join(FBX_DIR, f"V3_{area}.fbx")
		bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, object_types={"MESH"},
			apply_scale_options="FBX_SCALE_UNITS", use_mesh_modifiers=True, bake_anim=False)
		with open(os.path.join(DATA_DIR, f"{area}.json"), "w") as f:
			import lv3_props
			groups = {g: v for g, v in lv3_props.ANIM.items() if any(p["grp"] == g for p in parts)}
			json.dump({"area": area, "parts": parts, "lights": lts[area], "groups": groups}, f, separators=(",", ":"))
		rows = C.COLLISION.get(area, [])
		per = 1400
		for k in range(0, len(rows), per):
			with open(os.path.join(DATA_DIR, f"{area}_col{k // per + 1}.json"), "w") as f:
				json.dump(rows[k:k + per], f, separators=(",", ":"))
		if area == "Duels":  # team pads for the queue zones: [id, mode, x, y, top z, width, depth, side, open]
			import lv3_duels
			d = json.load(open(os.path.join(DATA_DIR, f"{area}.json")))
			d["pads"] = lv3_duels.PADS
			json.dump(d, open(os.path.join(DATA_DIR, f"{area}.json"), "w"), separators=(",", ":"))
		if area == "Vault":  # motes rising through the hologram: [x, y, z, sx, sy, sz, colour, rate]
			d = json.load(open(os.path.join(DATA_DIR, f"{area}.json")))
			d["fx"] = [[76.0, 0.0, 3.0, 4.6, 0.3, 4.6, "#7FE6FF", 9]]
			json.dump(d, open(os.path.join(DATA_DIR, f"{area}.json"), "w"), separators=(",", ":"))
		summary[area] = {"parts": len(parts), "tris": tris, "colliders": len(rows), "lights": len(lts[area]),
			"fbx_mb": round(os.path.getsize(fbx) / 1e6, 2)}
	# real gun models for the Locker displays: looks and part positions come from the weapon build data
	import lv3_props
	guns = {}
	for row in lv3_props.GUNS:
		gid = row[0]
		if gid in guns:
			continue
		d = json.load(open(os.path.join(lv3_props.BUILD_DATA, gid + ".json")))
		guns[gid] = {"assetId": d["assetId"], "parts": [[q["name"], q["look"]["material"], q["look"]["color"]] + [round(v, 4) for v in q["center"]]
			+ [round(v, 4) for v in q["size"]] for q in d["parts"] if not q.get("option") and q.get("look")]}
	with open(os.path.join(DATA_DIR, "Guns.json"), "w") as f:
		json.dump({"guns": guns, "place": lv3_props.GUNS}, f, separators=(",", ":"))
	summary["Guns"] = {"models": len(guns), "placed": len(lv3_props.GUNS)}
	return summary
