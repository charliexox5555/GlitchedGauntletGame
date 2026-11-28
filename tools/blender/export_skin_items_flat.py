"""Flat-material export for whole skin lines (round two Studio pass, 2026-11-14).

Exec inside the Blender MCP session with ITEMS = [(line, item, version), ...].
For each item it opens art-source/weapons/Skins/<Line>/<Item>/<ver>/*.blend
(a saved final from fin_item / skin_final) and exports with
export_roblox_flat.export_flat():

  exported = every visible mesh of the skin collection(s)
           + every visible stock object that carries skin materials
             (retained stock parts are re-coloured per slot in Blender, so
             they are exported too and look exactly like the review renders)
  replaced = stock prefixes to remove in Studio: hidden + exported stock
  untouched = visible stock objects still on stock slot materials (scope
             lenses, loaded rounds, feed belts): Studio keeps them as they are

Writes <Item>_<Line>_RobloxFlat.fbx and manifest_flat.json next to the blend
(installer: tools/studio/InstallFlatSkin.luau). Knife items (Fan, Blade,
Dagger) skin the stock "Knife". Returns a compact report per item.
"""
import bmesh, bpy, json, os, re

ROOT = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
SKINS = os.path.join(ROOT, "art-source", "weapons", "Skins")
exec(open(os.path.join(ROOT, "tools", "blender", "export_roblox_flat.py")).read())

KNIVES = ("Fan", "Blade", "Dagger")
VANDAL_VER = {"Moltframe": "v05", "Arcade": "v08x"}
STOCK_MAT = re.compile(r"^(Body|Panel|Dark|Metal|Grip|Accent|Neon|Brass|Glass|Lens|Scope ?Lens)(\.\d+)?$")
NOT_SKIN = ("FP_Cams", "RV2_", "MFR_", "MS_Lights", "Review", "ADSRange")


def split_skinned(o):
    """A mesh deformed by an Armature modifier (the Fan's pleated leaf) can't
    be one rigid Roblox part: split its faces by their dominant vertex group
    into one object per bone, each parented to that bone, so every pleat half
    rides its own rib when the fan opens and closes. Returns the new objects
    (temporary, not saved)."""
    mod = next((m for m in o.modifiers if m.type == "ARMATURE" and m.object), None)
    if not mod or not o.vertex_groups:
        return [o]
    arm = mod.object
    names = {g.index: g.name for g in o.vertex_groups}
    me = o.data
    by_bone = {}
    for p in me.polygons:
        acc = {}
        for vi in p.vertices:
            for g in me.vertices[vi].groups:
                acc[g.group] = acc.get(g.group, 0) + g.weight
        bone = names[max(acc, key=acc.get)] if acc else "Root"
        by_bone.setdefault(bone if bone in arm.data.bones else "Root", []).append(p.index)
    out = []
    Mw = o.matrix_world.copy()
    for bone, faces in by_bone.items():
        bm = bmesh.new(); bm.from_mesh(me)
        keep = set(faces)
        bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keep], context="FACES")
        nm = bpy.data.meshes.new(f"{o.name}_{bone}")
        bm.to_mesh(nm); bm.free()
        for i, m in enumerate(me.materials):
            nm.materials.append(m)
        n = bpy.data.objects.new(f"{o.name}_{bone}", nm)
        bpy.context.scene.collection.objects.link(n)
        n.parent = arm; n.parent_type = "BONE"; n.parent_bone = bone
        bpy.context.view_layer.update()
        n.matrix_world = Mw
        out.append(n)
    bpy.context.view_layer.update()
    return out


def export_item(line, item, ver):
    d = os.path.join(SKINS, line, item, ver)
    blend = [f for f in os.listdir(d) if f.endswith(".blend")][0]
    bpy.ops.wm.open_mainfile(filepath=os.path.join(d, blend))
    gun = "Knife" if item in KNIVES else item
    # Export at the rest pose: Studio's rig motors sit at rest (Transform =
    # identity), and a final saved on a review frame (the Fan's ribs) would
    # otherwise weld its parts in that frame's pose.
    for a in bpy.data.objects:
        if a.type == "ARMATURE":
            a.data.pose_position = "REST"
    bpy.context.view_layer.update()
    stock = bpy.data.collections.get(gun)
    skin_cols = [c for c in bpy.data.collections if c is not stock and not any(e in c.name for e in NOT_SKIN)]
    objs, hidden, skinned, untouched = [], [], [], []
    for c in skin_cols:
        objs += [o for o in c.objects if o.type == "MESH" and not o.hide_render and o.data.polygons]
    if stock:
        for o in stock.objects:
            if o.type != "MESH":
                continue
            name = o.name[len(gun) + 1:]
            if o.hide_render:
                hidden.append(name)
            elif all(m is None or STOCK_MAT.match(m.name) for m in o.data.materials):
                untouched.append(name)
            else:
                skinned.append(name)
                objs.append(o)
    seen = set()
    objs = [o for o in objs if not (o.name in seen or seen.add(o.name))]
    objs = [s for o in objs for s in split_skinned(o)]
    fbx, rep = export_flat(objs, d, item, line)
    # One palette per line: the owner-approved Vandal's flat specs win over the
    # item blend's (items were finalled before later kit fixes, e.g. Giltfold's
    # warm Fold Slate), so every gun in a line matches its Vandal in Studio.
    vandal = os.path.join(SKINS, line, "Vandal", VANDAL_VER.get(line, "v02"), "manifest_flat.json")
    if os.path.exists(vandal) and item != "Vandal":
        palette = {v["blender_material"]: v for v in json.load(open(vandal))["parts"].values()}
        for spec in rep.values():
            ref = palette.get(spec["blender_material"])
            if ref:
                for k in ("color", "material", "reflectance", "pattern"):
                    spec[k] = ref[k]
    # Extra rigs (the Giltfold Fan's ribs): their bones become new Studio
    # joints under the stock Root, C0 = the bone's rest frame in Root's axes.
    joints = []
    stock_rig = bpy.data.objects.get(f"{gun}_Rig")
    if stock_rig:
        root_m = stock_rig.matrix_world @ stock_rig.data.bones["Root"].matrix_local
        used = {v["bone"] for v in rep.values()}
        for a in bpy.data.objects:
            if a.type != "ARMATURE" or a is stock_rig:
                continue
            for b in a.data.bones:
                if b.name in stock_rig.data.bones or b.name not in used:
                    continue
                m = root_m.inverted() @ a.matrix_world @ b.matrix_local
                c0 = [m[i][3] for i in range(3)] + [m[i][j] for i in range(3) for j in range(3)]
                joints.append({"name": b.name, "parent": "Root", "c0": [round(x, 6) for x in c0]})
    manifest = {
        "variant": f"{line} {item} {ver} (flat-material export)",
        "joints": joints,
        "date": "2026-11-14",
        "gun": gun,
        "source_blend": blend,
        "fbx": os.path.basename(fbx),
        "replaced_stock_prefixes": sorted(set(hidden + skinned)),
        "untouched_stock": untouched,
        "flipped_islands": dict(FLIPPED),
        "coplanar_lifted": list(COPLANAR_LIFTED),
        "crossed_faces_fixed": dict(CROSSED_FIXED),
        "crossed_faces_left": dict(CROSSED_LEFT),
        "parts": rep,
    }
    json.dump(manifest, open(os.path.join(d, "manifest_flat.json"), "w"), indent=1)
    mats = {}
    for v in rep.values():
        mats[v["blender_material"]] = (v["color"], v["material"], v["pattern"])
    return {"parts": len(rep), "tris": sum(v["triangles"] for v in rep.values()),
            "bones": sorted({v["bone"] for v in rep.values()}), "flipped": dict(FLIPPED), "mats": mats}


result = {f"{l}/{i}": export_item(l, i, v) for l, i, v in ITEMS}
