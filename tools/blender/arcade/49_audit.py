"""Audit each live Arcade master against its exact RemasterV2 stock contract."""

import json
from itertools import combinations
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree


MASTER = Path(bpy.data.filepath)
VERSION = MASTER.stem.split("_")[-1]
ROOT = MASTER.parents[6]
GUN = MASTER.stem.split("_")[0]
ADS_DISTANCE = {"Guardian": 0.33, "Vandal": 0.36, "Spectre": 0.37, "Operator": 0.70}[GUN] if GUN != "Classic" else None
STOCK = ROOT / f"art-source/weapons/RemasterV2/{GUN}/{GUN}_RemasterV2_v05.blend"
OUT = ROOT / f"vault/02 Art/Skins/Arcade/out/{GUN}_{VERSION}_views"
OUT.mkdir(parents=True, exist_ok=True)
helpers = {}
exec((ROOT / "tools/blender/export_roblox_flat.py").read_text(encoding="utf-8"), helpers)


def visible():
    groups = [bpy.data.collections.get(n) for n in (GUN, "COL_Arcade")]
    return [o for group in groups if group for o in group.objects if o.type == "MESH" and not o.hide_render]


def world_mesh(obj, depsgraph):
    eval_obj = obj.evaluated_get(depsgraph)
    mesh = eval_obj.to_mesh()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.transform(eval_obj.matrix_world)
    bm.normal_update()
    eval_obj.to_mesh_clear()
    return bm


def part_bounds(verts):
    return [tuple(round(fn(v.co[i] for v in verts), 6) for i in range(3)) for fn in (min, max)]


def components(bm):
    unseen = set(bm.verts)
    while unseen:
        seed = min(unseen, key=lambda v: v.index)
        unseen.remove(seed)
        group = [seed]
        for v in group:
            for edge in v.link_edges:
                other = edge.other_vert(v)
                if other in unseen:
                    unseen.remove(other)
                    group.append(other)
        yield group


def pack_matrix(matrix):
    return tuple(round(value, 7) for row in matrix for value in row)


def contract(rig):
    locators = {o.name: (o.parent_bone, pack_matrix(o.matrix_world))
                for o in bpy.data.collections[GUN].objects if o.type == "EMPTY"}
    bones = {b.name: (b.parent.name if b.parent else None, pack_matrix(b.matrix_local), round(b.length, 7))
             for b in rig.data.bones}
    actions = {}
    for action in bpy.data.actions:
        curves = []
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        keys = [(tuple(k.co), tuple(k.handle_left), tuple(k.handle_right), k.interpolation)
                                for k in curve.keyframe_points]
                        curves.append((curve.data_path, curve.array_index, keys))
        actions[action.name] = curves
    result = {"locators": locators, "bones": bones, "actions": actions}
    lens = bpy.data.objects.get(f"{GUN}_ScopeLens")
    if lens:
        result["lenses"] = (pack_matrix(lens.matrix_world), tuple(tuple(v.co) for v in lens.data.vertices),
                            tuple((tuple(p.vertices), p.material_index) for p in lens.data.polygons),
                            tuple(m.name if m else None for m in lens.data.materials))
    return result


def in_box(a, b, margin=0.0016):
    return all(a[0][i] <= b[1][i] + margin and b[0][i] <= a[1][i] + margin for i in range(3))


def point_inside(tree, point):
    direction = Vector((0.683, 0.327, 0.653)).normalized()
    origin = point.copy()
    count = 0
    for _ in range(32):
        hit = tree.ray_cast(origin, direction)
        if hit[0] is None:
            return count % 2 == 1
        count += 1
        origin = hit[0] + direction * 0.00001
    return False


def seats(first, second):
    if not in_box(first[2], second[2]):
        return False
    if first[1].overlap(second[1]):
        return True
    for source, target in ((first, second), (second, first)):
        for v in source[0].verts:
            if target[1].find_nearest(v.co, 0.0015)[0] is not None:
                return True
        if target[3] and point_inside(target[1], source[0].verts[0].co):
            return True
    return False


def measure():
    rig = bpy.data.objects[f"{GUN}_Rig"]
    rig.data.pose_position = "REST"
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    meshes, shells, raw = {}, {}, []
    triangles, bounds, faults, stock_open_lenses = {}, {}, {}, {}
    for obj in visible():
        bm = world_mesh(obj, deps)
        bm.verts.index_update()
        bm.faces.index_update()
        triangles[obj.name] = sum(len(f.verts) - 2 for f in bm.faces)
        bounds[obj.name] = part_bounds(bm.verts)
        meshes[obj.name] = BVHTree.FromBMesh(bm)
        snapshot_mesh = bpy.data.meshes.new(obj.name + " audit")
        snapshot = bpy.data.objects.new(obj.name + " audit", snapshot_mesh)
        for material in obj.data.materials:
            snapshot_mesh.materials.append(material)
        bm.to_mesh(snapshot_mesh)
        raw.append(snapshot)
        crossed = []
        for f in bm.faces:
            if len(f.verts) > 3 and f.normal.length > 1e-8:
                u = f.normal.orthogonal().normalized()
                v = f.normal.cross(u)
                if helpers["_first_cross"]([(vert.co.dot(u), vert.co.dot(v)) for vert in f.verts]):
                    crossed.append(f.index)
        for index, group in enumerate(components(bm)):
            group_faces = {f for v in group for f in v.link_faces}
            island = bmesh.new()
            verts = {v: island.verts.new(v.co) for v in sorted(group, key=lambda v: v.index)}
            duplicates = []
            for face in sorted(group_faces, key=lambda f: f.index):
                loop = [verts[v] for v in face.verts]
                if island.faces.get(loop):
                    duplicates.append(face.index)
                    continue
                island.faces.new(loop)
            island.verts.ensure_lookup_table()
            island.faces.ensure_lookup_table()
            island.normal_update()
            open_edges = sum(edge.is_boundary for edge in island.edges)
            nonmanifold = sum(not edge.is_manifold and not edge.is_boundary for edge in island.edges)
            volume = island.calc_volume(signed=True)
            tree = BVHTree.FromBMesh(island)
            folded = {(a, b) for a, b in tree.overlap(tree) if a < b
                      and not set(island.faces[a].verts) & set(island.faces[b].verts)}
            degenerate = sum(f.calc_area() < 1e-9 for f in island.faces)
            label = f"{obj.name}:{index}"
            shells[label] = (island, tree, part_bounds(island.verts), not open_edges and not nonmanifold)
            inverted = not open_edges and not nonmanifold and volume < -1e-8
            if obj.name == f"{GUN}_ScopeLens" and open_edges and not (nonmanifold or folded or degenerate):
                stock_open_lenses[label] = open_edges
            elif open_edges or nonmanifold or inverted or folded or degenerate or duplicates:
                faults[label] = {"open": open_edges, "nonmanifold": nonmanifold, "inverted": inverted,
                                 "self_intersections": sorted(folded), "degenerate": degenerate, "duplicates": duplicates,
                                 "bounds": shells[label][2]}
        if crossed:
            faults[obj.name] = {"crossed_polygon_indices": crossed}
        bm.free()

    contacts = {label: set() for label in shells}
    for a, b in combinations(shells, 2):
        if seats(shells[a], shells[b]):
            contacts[a].add(b)
            contacts[b].add(a)
    anchor = min((label for label in shells if label.startswith((f"{GUN}_Receiver:", f"{GUN}_Frame:", "AR_ControlDeck_Left:"))),
                 key=lambda label: shells[label][2][0][2])
    reached = {anchor}
    todo = [anchor]
    for label in todo:
        next_parts = sorted(contacts[label] - reached)
        reached.update(next_parts)
        todo.extend(next_parts)
    floaters = {label: shells[label][2] for label in sorted(set(shells) - reached)}
    for shell, *_ in shells.values():
        shell.free()

    coplanar = helpers["resolve_coplanar"](raw, dry=True)
    for snapshot in raw:
        mesh = snapshot.data
        bpy.data.objects.remove(snapshot)
        bpy.data.meshes.remove(mesh)

    # Match the eye-to-sight segment and spread in findOccluders at scale 0.8.
    ads_hits, post_hits, physical_iron_hits = None, None, None
    if ADS_DISTANCE is not None:
        aim = bpy.data.objects[f"{GUN}_AimPoint"].matrix_world.translation
        eye = aim - Vector((ADS_DISTANCE / 0.8, 0, 0))
        offset = 0.012 / 0.8
        forward = Vector((1, 0, 0))
        rays = [eye + Vector((0, y, z)) for y, z in ((0, 0), (offset, 0), (-offset, 0), (0, offset), (0, -offset))]
        ads_hits = [sorted(name for name, tree in meshes.items()
                           if tree.ray_cast(origin, forward, (ADS_DISTANCE - 0.02) / 0.8)[0] is not None) for origin in rays]
        post_hits = sorted(name for name, tree in meshes.items() if tree.ray_cast(eye, forward, 4)[0] is not None)
    else:
        # Classic's alternate input is burst fire. Check the physical notch and post.
        eye = Vector((-0.565, 0, 0.509))
        forward = Vector((1, 0, 0))
        physical_iron_hits = sorted(name for name, tree in meshes.items()
                                    if tree.ray_cast(eye, forward, 2)[0] is not None)
    return {"tris": sum(triangles.values()), "part_triangles": triangles, "bounds": bounds, "faults": faults,
            "coplanar": coplanar, "floating": floaters, "stock_open_lenses": stock_open_lenses, "new_part_contacts": {
                label: sorted(neighbors) for label, neighbors in contacts.items() if label.startswith("AR_")
            }, "ads_eye_segment_hits": ads_hits, "post_ray_hits": post_hits, "physical_iron_hits": physical_iron_hits}


def clips():
    rig = bpy.data.objects[f"{GUN}_Rig"]
    rig.data.pose_position = "POSE"
    parts = visible()
    moving = [o for o in visible() if o.parent_bone != "Root" and o.parent_bone]
    pairs = [(o, fixed) for o in moving for fixed in parts
             if fixed.parent_bone == "Root" and (o.name.startswith("AR_") or fixed.name.startswith("AR_"))]
    pairs.extend((a, b) for a, b in combinations(moving, 2)
                 if a.parent_bone != b.parent_bone and any(o.name.startswith("AR_") for o in (a, b)))
    collision_parts = {o for pair in pairs for o in pair}
    contact_frames = {}
    sampled = {}
    for action in sorted(bpy.data.actions, key=lambda a: a.name):
        if not action.name.startswith(f"{GUN}_"):
            continue
        rig.animation_data_create()
        rig.animation_data.action = action
        if action.slots:
            rig.animation_data.action_slot = action.slots[0]
        start, last = (round(value) for value in action.frame_range)
        bpy.context.scene.frame_set(start)
        origins = {o.name: o.matrix_world.translation.copy() for o in moving}
        travel = dict.fromkeys(origins, 0.0)
        for frame in range(start, last + 1):
            bpy.context.scene.frame_set(frame)
            deps = bpy.context.evaluated_depsgraph_get()
            geometry = {}
            for obj in collision_parts:
                mesh = world_mesh(obj, deps)
                geometry[obj] = BVHTree.FromBMesh(mesh), part_bounds(mesh.verts)
                mesh.free()
            for obj in moving:
                travel[obj.name] = max(travel[obj.name], (obj.matrix_world.translation - origins[obj.name]).length)
            for a, b in pairs:
                a_tree, a_bounds = geometry[a]
                b_tree, b_bounds = geometry[b]
                if in_box(a_bounds, b_bounds, 0) and a_tree.overlap(b_tree):
                    contact_frames.setdefault(action.name, {}).setdefault(f"{a.name} → {b.name}", []).append(frame)
        sampled[action.name] = {"frames": [start, last], "max_travel": {n: round(v, 5) for n, v in travel.items()}}
    return contact_frames, sampled


def get_contract():
    rig = bpy.data.objects[f"{GUN}_Rig"]
    rig.data.pose_position = "REST"
    bpy.context.view_layer.update()
    return contract(rig)


candidate_contract = get_contract()
candidate = measure()
motion, sampled = clips()
bpy.ops.wm.open_mainfile(filepath=str(STOCK))
stock_contract = get_contract()
stock = measure()
bpy.ops.wm.open_mainfile(filepath=str(MASTER))
report = {
    "stock": stock, "candidate": candidate,
    "contract_equal": {key: candidate_contract[key] == stock_contract[key] for key in stock_contract},
    "bone_names": sorted(candidate_contract["bones"]), "locator_frames": candidate_contract["locators"],
    "clips": sampled, "animated_intersections": motion,
}
path = OUT / "audit.json"
path.write_text(json.dumps(report, indent=2), encoding="utf-8")
result = {"report": str(path), "stock_tris": stock["tris"], "candidate_tris": candidate["tris"],
          "faults": len(candidate["faults"]), "floating": len(candidate["floating"]),
          "coplanar": len(candidate["coplanar"]), "contract": report["contract_equal"], "animated_pairs": {action: {pair: len(frames) for pair, frames in pairs.items()}
                             for action, pairs in motion.items()}}
