"""Export Sunwell Works for the Studio build (run inside Blender MCP after sw_run.build_all()).

    import sw_export; sw_export.run()

Writes art-source/lobby/Exports/SW1_<Area>.fbx (one per collection group) and the build data in
art-source/lobby/Exports/SW1Data/: <Area>.json (parts with bounds and Roblox looks, lights) and
<Area>_col<n>.json (collider rows). Uploaded with tools/opencloud/upload_models.py --lobby and
tools/studio/sunwell_p1/upload_data.py, then built by tools/studio/sunwell_p1/Build_SW1.luau.
"""
import json
import os

import bpy

import lv3_core as C
import sw_core as S

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
FBX_DIR = os.path.join(REPO, "art-source", "lobby", "Exports")
DATA_DIR = os.path.join(FBX_DIR, "SW1Data")
SKIP = ("RenderAids", "Cameras", "Scale")


def areas():
	return [c.name for c in bpy.data.collections[S.ROOT].children if c.name not in SKIP and not c.name.endswith("_Ceil")]


def _objects(area):
	obs = []
	for cname in (area, area + "_Ceil"):
		col = bpy.data.collections.get(cname)
		if col:
			obs += [o for o in col.objects if o.type == "MESH" and not o.name.endswith("_Dummy")]
	return obs


def run(only=None):
	os.makedirs(DATA_DIR, exist_ok=True)
	dg = bpy.context.evaluated_depsgraph_get()
	summary = {}
	todo = only or areas()
	for area in todo:
		for f in os.listdir(DATA_DIR):
			if f == area + ".json" or f.startswith(area + "_col"):
				os.remove(os.path.join(DATA_DIR, f))
		obs = _objects(area)
		parts, tris = [], 0
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
			parts.append({"n": o.name, "mat": mname, "grp": o.name.split("_")[0] if o.name.startswith("Anim") else None, "look": S.LOOKS.get(mname, S._L("SmoothPlastic", "#FF00FF")),
				"c": [round((a + b) / 2, 4) for a, b in zip(lo, hi)], "s": [round(b - a, 4) for a, b in zip(lo, hi)],
				"ceil": 1 if o.users_collection[0].name.endswith("_Ceil") else 0, "t": n})
		bpy.ops.object.select_all(action="DESELECT")
		for o in obs:
			o.select_set(True)
		bpy.context.view_layer.objects.active = obs[0]
		fbx = os.path.join(FBX_DIR, f"SW1_{area}.fbx")
		bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, object_types={"MESH"},
			apply_scale_options="FBX_SCALE_UNITS", use_mesh_modifiers=True, bake_anim=False)
		lights = S.LIGHTS.get(area, [])
		with open(os.path.join(DATA_DIR, f"{area}.json"), "w") as f:
			groups = {g: v for g, v in S.ANIM.items() if any(q["grp"] == g for q in parts)}
			json.dump({"area": area, "parts": parts, "lights": lights, "groups": groups}, f, separators=(",", ":"))
		rows = C.COLLISION.get(area, [])
		per = 1400
		for k in range(0, len(rows), per):
			with open(os.path.join(DATA_DIR, f"{area}_col{k // per + 1}.json"), "w") as f:
				json.dump(rows[k:k + per], f, separators=(",", ":"))
		summary[area] = {"parts": len(parts), "tris": tris, "colliders": len(rows), "lights": len(lights),
			"fbx_mb": round(os.path.getsize(fbx) / 1e6, 2), "max_tris": max(p["t"] for p in parts)}
	# real gun displays: looks and part positions come from the weapon build data (same data as the V3 Locker)
	if S.GUNS and (only is None or "Guns" in only):
		import sw_locker
		guns = {}
		for row in S.GUNS:
			gid = row[0]
			if gid in guns:
				continue
			d = json.load(open(os.path.join(sw_locker.BUILD_DATA, gid + ".json")))
			guns[gid] = {"assetId": d["assetId"], "parts": [[q["name"], q["look"]["material"], q["look"]["color"]] + [round(v, 4) for v in q["center"]]
				+ [round(v, 4) for v in q["size"]] for q in d["parts"] if not q.get("option") and q.get("look")]}
		with open(os.path.join(DATA_DIR, "Guns.json"), "w") as f:
			json.dump({"guns": guns, "place": S.GUNS}, f, separators=(",", ":"))
		summary["Guns"] = {"models": len(guns), "placed": len(S.GUNS)}
	with open(os.path.join(DATA_DIR, "Anchors.json"), "w") as f:
		json.dump(S.ANCHORS, f, separators=(",", ":"))
	summary["Anchors"] = len(S.ANCHORS)
	with open(os.path.join(DATA_DIR, "Screens.json"), "w") as f:
		json.dump(S.SCREENS, f, separators=(",", ":"))
	summary["Screens"] = len(S.SCREENS)
	with open(os.path.join(DATA_DIR, "Sounds.json"), "w") as f:
		json.dump(S.SOUNDS, f, separators=(",", ":"))
	summary["Sounds"] = len(S.SOUNDS)
	return summary
