"""Shared compound-faceted sculpting, closed-manifold verification, export, and
Cycles render/icon/portrait kit for the Riftforge Legendary weapon bundle.

Runs inside live Blender 5.2 MCP (never headless/background).
Guarantees:
- Identical Riftforge material & tile palette across all 6 bundle weapons.
- Flat-shaded compound-faceted hard-surface geometry (zero smooth-shading artifacts).
- Closed-manifold animated parts -> FLIPPED: {}, OPEN_FLIPPED: {}, ray_backfaces: [].
- Multi-angle ray-cast backface check on the ACTUAL re-imported RobloxFlat FBX.
"""
import importlib
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = r"c:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
TILES_DIR = os.path.join(ROOT, "art-source", "weapons", "Skins", "_tiles")

OBS, SLT, DRK, STL, BRZ, GRP, COR, HOT = range(8)
MAT_TAG = ["Obs", "Slt", "Drk", "Stl", "Brz", "Grp", "Cor", "Hot"]


def _lin(h):
    h = h.lstrip("#")
    return tuple(((int(h[i:i + 2], 16) / 255.0) ** 2.2) for i in (0, 2, 4))


def _make_mat(name, hexcol, metallic=0.0, roughness=0.42, emit=0.0, tile_png=None):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    c = _lin(hexcol)
    bsdf.inputs["Base Color"].default_value = (*c, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emit > 0:
        bsdf.inputs["Emission Color"].default_value = (*c, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emit
    if tile_png and os.path.exists(tile_png):
        tex_coord = nt.nodes.new("ShaderNodeTexCoord")
        mapping = nt.nodes.new("ShaderNodeMapping")
        mapping.inputs["Scale"].default_value = (4.0, 4.0, 4.0)
        img_node = nt.nodes.new("ShaderNodeTexImage")
        img_node.image = bpy.data.images.load(tile_png, check_existing=True)
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.inputs["Factor"].default_value = 0.42 if emit == 0 else 0.55
        mix.inputs[6].default_value = (*c, 1.0)
        nt.links.new(tex_coord.outputs["Object"], mapping.inputs["Vector"])
        nt.links.new(mapping.outputs["Vector"], img_node.inputs["Vector"])
        nt.links.new(img_node.outputs["Color"], mix.inputs[7])
        nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        if emit > 0:
            nt.links.new(mix.outputs[2], bsdf.inputs["Emission Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    m["mf_hex"] = hexcol.lstrip("#").upper()
    return m


def set_flat(mesh):
    mesh.polygons.foreach_set("use_smooth", [False] * len(mesh.polygons))
    mesh.update()


def loft_rings_bm(rings, face_role=None, cap0=True, cap1=True, cap0_mat=0, cap1_mat=0, loop=False):
    bm = bmesh.new()
    vr = [[bm.verts.new(p) for p in r] for r in rings]
    n = len(vr[0])
    rows = len(vr) if loop else len(vr) - 1
    for row in range(rows):
        a = vr[row]
        b = vr[(row + 1) % len(vr)]
        for j in range(n):
            k = (j + 1) % n
            f = bm.faces.new((a[j], a[k], b[k], b[j]))
            f.material_index = face_role(j, row) if face_role else 0
    if not loop:
        if cap0:
            f = bm.faces.new(list(reversed(vr[0])))
            f.material_index = cap0_mat
        if cap1:
            f = bm.faces.new(vr[-1])
            f.material_index = cap1_mat
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def hull_bm(stations, face_role=None, cap0_mat=DRK, cap1_mat=DRK, ref_z=0.30):
    """12-sided compound-faceted sculpted armor hull."""
    side = [(0.54, 0.0), (0.82, 0.06), (1.0, 0.25), (0.98, 0.68), (0.82, 0.87), (0.56, 1.0)]
    rings = []
    for x, width, floor, top, rake in stations:
        prof = [(s * width, floor + v * (top - floor)) for s, v in side]
        yz = prof + [(-y, z) for y, z in reversed(prof)]
        rings.append([(x + rake * (z - ref_z), y, z) for y, z in yz])
    return loft_rings_bm(rings, face_role=face_role, cap0_mat=cap0_mat, cap1_mat=cap1_mat)


def facet_blade_bm(hand, stations, face_role=None, cap_mat=SLT, ref_z=0.30):
    """Sculpted 3D swept cheek-armor blade (5-point closed cross-section)."""
    rings = []
    for x, inset, crest, low, ridge, top, rake in stations:
        edge = min(0.011, (top - low) * 0.17)
        section = [
            (inset, low),
            (crest - edge, low + edge * 0.55),
            (crest, ridge),
            (crest - edge * 0.72, top - edge * 0.42),
            (inset, top),
        ]
        if hand < 0:
            section = list(reversed(section))
        rings.append([(x + rake * (z - ref_z), hand * y, z) for y, z in section])
    return loft_rings_bm(rings, face_role=face_role, cap0_mat=cap_mat, cap1_mat=cap_mat)


def prism_xz(outline, y0, y1, mat=DRK):
    bm = bmesh.new()
    lo = [bm.verts.new((x, y0, z)) for x, z in outline]
    hi = [bm.verts.new((x, y1, z)) for x, z in outline]
    n = len(outline)
    bm.faces.new(lo)
    bm.faces.new(hi)
    for i in range(n):
        bm.faces.new((lo[i], lo[(i + 1) % n], hi[(i + 1) % n], hi[i]))
    for f in bm.faces:
        f.material_index = mat
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def box_bm(x0, x1, y0, y1, z0, z1, ch=0.0, mat=DRK, bevel_mat=None):
    if bevel_mat is None:
        bevel_mat = mat
    bm = bmesh.new()
    cx, cy, cz = 0.5 * (x0 + x1), 0.5 * (y0 + y1), 0.5 * (z0 + z1)
    sx, sy, sz = (x1 - x0), (y1 - y0), (z1 - z0)
    bmesh.ops.create_cube(
        bm,
        size=1.0,
        matrix=Matrix.Translation((cx, cy, cz)) @ Matrix.Diagonal((sx, sy, sz, 1.0)),
    )
    for f in bm.faces:
        f.material_index = mat
    if ch > 0:
        res = bmesh.ops.bevel(
            bm,
            geom=list(bm.edges),
            offset=ch,
            offset_type="OFFSET",
            segments=1,
            profile=0.5,
            affect="EDGES",
            clamp_overlap=True,
        )
        for f in res["faces"]:
            f.material_index = bevel_mat
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def oct_ring_x(x, ry, rz=None, cy=0.0, cz=0.35, n=8, phase=math.pi / 8, rake=0.0):
    if rz is None:
        rz = ry
    pts = []
    for i in range(n):
        ang = phase + 2.0 * math.pi * i / n
        y = cy + ry * math.cos(ang)
        z = cz + rz * math.sin(ang)
        pts.append((x + rake * (z - cz), y, z))
    return pts


def crystal_bm(cx, cy, cz, rx, ry, rz, mat=COR):
    """16-face faceted dark-matter double-bipyramid plasma prism."""
    bm = bmesh.new()
    n = 8
    top = bm.verts.new((cx, cy, cz + rz))
    bot = bm.verts.new((cx, cy, cz - rz))
    eq_u = []
    eq_l = []
    for i in range(n):
        a = 2.0 * math.pi * i / n + math.pi / 8
        s = 1.0 if i % 2 == 0 else 0.84
        eq_u.append(bm.verts.new((cx + rx * s * math.cos(a), cy + ry * s * math.sin(a), cz + rz * 0.24)))
        eq_l.append(bm.verts.new((cx + rx * s * math.cos(a), cy + ry * s * math.sin(a), cz - rz * 0.24)))
    for i in range(n):
        k = (i + 1) % n
        bm.faces.new((top, eq_u[i], eq_u[k]))
        bm.faces.new((eq_u[i], eq_l[i], eq_l[k], eq_u[k]))
        bm.faces.new((bot, eq_l[k], eq_l[i]))
    for f in bm.faces:
        f.material_index = mat
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def ring_bm(cx, cy, cz, rad, thick, width, n=8, axis="Y", mat=BRZ):
    """Faceted octagonal/hexagonal gimbal containment ring (closed torus manifold)."""
    rings = []
    # Cross-section diamond/beveled bar
    sec = [
        (-thick * 0.5, -width * 0.35),
        (thick * 0.5, -width * 0.35),
        (thick * 0.65, 0.0),
        (thick * 0.5, width * 0.35),
        (-thick * 0.5, width * 0.35),
        (-thick * 0.65, 0.0),
    ]
    for i in range(n):
        a = 2.0 * math.pi * i / n + math.pi / n
        ca, sa = math.cos(a), math.sin(a)
        pts = []
        for dr, dw in sec:
            r = rad + dr
            if axis == "Y":
                pts.append((cx + r * ca, cy + dw, cz + r * sa))
            elif axis == "X":
                pts.append((cx + dw, cy + r * ca, cz + r * sa))
            else:
                pts.append((cx + r * ca, cy + r * sa, cz + dw))
        rings.append(pts)
    return loft_rings_bm(rings, face_role=lambda e, r: mat, loop=True)


def merge_bms(bm_list):
    out = bmesh.new()
    for b in bm_list:
        me = bpy.data.meshes.new("_tmp_m")
        b.to_mesh(me)
        b.free()
        out.from_mesh(me)
        bpy.data.meshes.remove(me)
    bmesh.ops.recalc_face_normals(out, faces=out.faces)
    return out


class RiftforgeScene:
    def __init__(self, gun, version="v01"):
        self.gun = gun
        self.version = version
        self.stock_blend = os.path.join(
            ROOT, "art-source", "weapons", "RemasterV2", gun, f"{gun}_RemasterV2_v05.blend"
        )
        self.out_dir = os.path.join(ROOT, "art-source", "weapons", "Skins", "Riftforge", gun, version)
        self.rev_dir = os.path.join(self.out_dir, "review")
        os.makedirs(self.rev_dir, exist_ok=True)

        bpy.ops.wm.open_mainfile(filepath=self.stock_blend)
        for o in list(bpy.data.objects):
            if o.name.startswith("Range") or o.name.startswith("Target"):
                bpy.data.objects.remove(o, do_unlink=True)
        bpy.context.view_layer.update()

        self.rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
        col_name = f"Riftforge {gun} {version}"
        if col_name in bpy.data.collections:
            old_c = bpy.data.collections[col_name]
            for o in list(old_c.objects):
                bpy.data.objects.remove(o, do_unlink=True)
            bpy.data.collections.remove(old_c)
        self.col = bpy.data.collections.new(col_name)
        bpy.context.scene.collection.children.link(self.col)

        self.mats = [
            _make_mat("RF_ObsidianForged", "1B1F2B", metallic=0.22, roughness=0.38,
                      tile_png=os.path.join(TILES_DIR, "Riftforge_Forged.png")),
            _make_mat("RF_Slate",          "3D485E", metallic=0.72, roughness=0.32),
            _make_mat("RF_Dark",           "0F1219", metallic=0.14, roughness=0.58),
            _make_mat("RF_Steel",          "8A9AB5", metallic=0.88, roughness=0.22),
            _make_mat("RF_Bronze",         "C99A50", metallic=0.92, roughness=0.24),
            _make_mat("RF_GripCarbon",     "1E212B", metallic=0.06, roughness=0.68,
                      tile_png=os.path.join(TILES_DIR, "Payload_Carbon.png")),
            _make_mat("RF_PlasmaCore",     "B438FF", metallic=0.0,  roughness=0.16, emit=2.8,
                      tile_png=os.path.join(TILES_DIR, "Riftforge_Plasma.png")),
            _make_mat("RF_PlasmaHot",      "EDC4FF", metallic=0.0,  roughness=0.10, emit=3.4),
        ]

    def link(self, name, bm, bone="Root", flat_group=None):
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        if flat_group:
            used_mats = {f.material_index for f in bm.faces}
            assert len(used_mats) == 1, f"{name} (flat_group={flat_group}) must be single-material closed manifold, got {used_mats}"
            non_man = [e for e in bm.edges if not e.is_manifold]
            assert not non_man, f"{name} (flat_group={flat_group}) has {len(non_man)} non-manifold edges!"
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for m in self.mats:
            me.materials.append(m)
        set_flat(me)
        o = bpy.data.objects.new(name, me)
        self.col.objects.link(o)
        o.parent = self.rig
        o.parent_type = "BONE"
        o.parent_bone = bone
        pb = self.rig.pose.bones[bone]
        tail_mat = self.rig.matrix_world @ pb.matrix @ Matrix.Translation((0.0, pb.length, 0.0))
        o.matrix_parent_inverse = tail_mat.inverted()
        o.matrix_basis = Matrix.Identity(4)
        if flat_group:
            o["flat_group"] = flat_group
        bpy.context.view_layer.update()
        return o

    def bool_cut(self, obj, cutter_bms):
        bpy.context.view_layer.update()
        for idx, cbm in enumerate(cutter_bms):
            me = bpy.data.meshes.new(f"_cut_{idx}")
            cbm.to_mesh(me)
            cbm.free()
            for m in self.mats:
                me.materials.append(m)
            co = bpy.data.objects.new(f"_cut_{idx}", me)
            self.col.objects.link(co)
            co.matrix_world = Matrix.Identity(4)
            md = obj.modifiers.new(f"cut_{idx}", "BOOLEAN")
            md.operation = "DIFFERENCE"
            md.solver = "EXACT"
            md.object = co
            with bpy.context.temp_override(object=obj, active_object=obj):
                bpy.ops.object.modifier_apply(modifier=md.name)
            bpy.data.objects.remove(co, do_unlink=True)
            bpy.data.meshes.remove(me)
        bm_fix = bmesh.new()
        bm_fix.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(bm_fix, faces=bm_fix.faces)
        bm_fix.to_mesh(obj.data)
        bm_fix.free()
        set_flat(obj.data)

    def hide_replaced_stock(self, replaced_prefixes):
        prefix = self.gun + "_"
        for o in list(bpy.data.objects):
            if o.type == "MESH" and o.name.startswith(prefix):
                suffix = o.name[len(prefix):]
                if any(suffix.startswith(p) for p in replaced_prefixes):
                    o.hide_render = True
                    o.hide_viewport = True
                else:
                    me = o.data
                    me.materials.clear()
                    me.materials.append(self.mats[SLT] if "Trigger" in suffix else self.mats[DRK])
                    set_flat(me)

    def finalize(self, replaced_prefixes, center_checks, cam_specs):
        self.hide_replaced_stock(replaced_prefixes)
        bpy.context.view_layer.update()

        for check_prefix in center_checks:
            ob = next(o for o in self.col.objects if o.name.startswith(check_prefix))
            pts = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
            ys = [p.y for p in pts]
            cy_err = 0.5 * (min(ys) + max(ys))
            assert abs(cy_err) < 0.003, f"{ob.name} off-center in Y: {cy_err:.5f}"

        blend_path = os.path.join(self.out_dir, f"{self.gun}_Riftforge_{self.version}.blend")
        bpy.ops.wm.save_as_mainfile(filepath=blend_path)

        sys.path.insert(0, os.path.join(ROOT, "tools", "blender"))
        import export_roblox_flat
        importlib.reload(export_roblox_flat)

        objs = [o for o in self.col.objects if o.type == "MESH"]
        fbx_path, report = export_roblox_flat.export_flat(objs, self.out_dir, self.gun, "Riftforge")

        manifest = {
            "gun": self.gun,
            "item": self.gun,
            "line": "Riftforge",
            "version": self.version,
            "replaced_stock_prefixes": list(replaced_prefixes),
            "parts": report,
        }
        with open(os.path.join(self.out_dir, "manifest_flat.json"), "w", newline="\n") as f:
            json.dump(manifest, f, indent=2)

        # Studio Cycles renders + Locker icon + Shop portrait
        sc = bpy.context.scene
        sc.render.engine = "CYCLES"
        sc.cycles.samples = 24
        sc.cycles.use_denoising = True
        sc.view_settings.view_transform = "AgX"
        if not sc.world:
            sc.world = bpy.data.worlds.new("RF_World")
        sc.world.use_nodes = True
        bg = sc.world.node_tree.nodes.get("Background")
        if bg:
            bg.inputs[0].default_value = (0.045, 0.052, 0.075, 1.0)
            bg.inputs[1].default_value = 0.80

        for o in list(bpy.data.objects):
            if o.name.startswith("RF_Rev"):
                bpy.data.objects.remove(o, do_unlink=True)

        ctr = Vector(cam_specs["center"])
        span = cam_specs["span"]

        def add_area(name, offset, energy, sx, sy, color=(1, 1, 1)):
            ld = bpy.data.lights.new(name, "AREA")
            ld.shape = "RECTANGLE"
            ld.energy = energy
            ld.size = sx
            ld.size_y = sy
            ld.color = color
            lo = bpy.data.objects.new(name, ld)
            sc.collection.objects.link(lo)
            loc = ctr + Vector(offset)
            lo.location = loc
            lo.rotation_euler = (ctr - loc).to_track_quat("-Z", "Y").to_euler()

        add_area("RF_RevKey",  (0.35 * span,  0.95 * span,  1.05 * span), 120 * span, 1.3 * span, 0.7 * span, (1.0, 0.96, 0.92))
        add_area("RF_RevRim",  (0.25 * span, -0.85 * span,  0.80 * span), 115 * span, 1.2 * span, 0.55 * span, (0.78, 0.88, 1.0))
        add_area("RF_RevFill", (0.50 * span,  0.75 * span, -0.45 * span),  35 * span, 1.0 * span, 0.8 * span, (0.88, 0.72, 1.0))

        def snap(name, loc, target, lens=50.0, ortho=None, res=(1280, 720), transparent=False):
            sc.render.film_transparent = transparent
            sc.render.image_settings.color_mode = "RGBA" if transparent else "RGB"
            cd = bpy.data.cameras.new("RF_RevCam_" + name)
            if ortho is not None:
                cd.type = "ORTHO"
                cd.ortho_scale = ortho
            else:
                cd.type = "PERSP"
                cd.lens = lens
            co = bpy.data.objects.new("RF_RevCam_" + name, cd)
            sc.collection.objects.link(co)
            co.location = loc
            co.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
            sc.camera = co
            sc.render.resolution_x, sc.render.resolution_y = res
            out = os.path.join(self.rev_dir, f"{name}.png")
            sc.render.filepath = out
            bpy.ops.render.render(write_still=True)
            bpy.data.objects.remove(co, do_unlink=True)
            bpy.data.cameras.remove(cd)
            return out

        snap("hero",    cam_specs["hero_loc"],    ctr, ortho=cam_specs["hero_ortho"])
        snap("side",    cam_specs["side_loc"],    ctr, ortho=cam_specs["side_ortho"])
        snap("fp",      cam_specs["fp_loc"],      cam_specs["fp_tgt"], lens=38.0)
        snap("closeup", cam_specs["close_loc"],   cam_specs["close_tgt"], lens=55.0)

        # Locker Icon (512x512 transparent, crisp elevated side/3/4 silhouette)
        icon_path = snap(
            f"{self.gun}_Riftforge_{self.version}_icon",
            cam_specs["icon_loc"],
            ctr,
            ortho=cam_specs["icon_ortho"],
            res=(512, 512),
            transparent=True,
        )
        # Shop Portrait (512x512 rich dark obsidian-violet backdrop)
        if bg:
            bg.inputs[0].default_value = (0.042, 0.024, 0.075, 1.0)
            bg.inputs[1].default_value = 0.85
        portrait_path = snap(
            f"{self.gun}_Riftforge_{self.version}_portrait",
            cam_specs["portrait_loc"],
            ctr,
            ortho=cam_specs["portrait_ortho"],
            res=(512, 512),
            transparent=False,
        )

        # Multi-angle ray-cast backface verification on the ACTUAL exported FBX!
        tmp_sc = bpy.data.scenes.new("RF_FBX_Check")
        win = bpy.context.window or bpy.data.window_managers[0].windows[0]
        win.scene = tmp_sc
        with bpy.context.temp_override(window=win, scene=tmp_sc):
            bpy.ops.import_scene.fbx(filepath=fbx_path)
        deps = bpy.context.evaluated_depsgraph_get()
        backfaces = set()
        check_cams = [
            Vector(cam_specs["hero_loc"]),
            Vector((cam_specs["hero_loc"][0], -cam_specs["hero_loc"][1], cam_specs["hero_loc"][2])),
            Vector(cam_specs["fp_loc"]),
        ]
        x0, x1 = cam_specs["ray_x"]
        z0, z1 = cam_specs["ray_z"]
        for cpos in check_cams:
            for xi in range(18):
                tx = x0 + (x1 - x0) * xi / 17.0
                for zi in range(8):
                    tz = z0 + (z1 - z0) * zi / 7.0
                    d = (Vector((tx, 0.0, tz)) - cpos).normalized()
                    ok, loc, n, idx, obj, mat = tmp_sc.ray_cast(deps, cpos, d)
                    if ok and n.dot(d) > 0:
                        backfaces.add(obj.name)
        win.scene = sc
        bpy.data.scenes.remove(tmp_sc)

        total_tris = sum(p["triangles"] for p in report.values())
        return {
            "gun": self.gun,
            "blend": blend_path,
            "fbx": fbx_path,
            "icon": icon_path,
            "portrait": portrait_path,
            "parts_count": len(report),
            "total_tris": total_tris,
            "part_names": sorted(report.keys()),
            "patterns": {k: v["pattern"] for k, v in report.items() if v.get("pattern")},
            "flipped": dict(export_roblox_flat.FLIPPED),
            "open_flipped": dict(export_roblox_flat.OPEN_FLIPPED),
            "ray_backfaces": sorted(backfaces),
        }
