"""Giltfold Fan (Knife slot custom model). Exec after model_giltfold_kit.py with
the stock Knife open. Builds Fan_Rig (Root + 11 rib bones on one base pivot),
rigid ribs/guards parented to their bones, an ivory pleated leaf skinned to
the ribs, and actions Fan_Open / Fan_Close / Fan_InspectFan. Fan_Rig is a
child of the stock Knife rig's Root bone, so the stock Knife clips (draw,
slashes, heavy, inspect) still move the whole fan; the opening rides on top.

Layout: the fan lies in the knife blade's plane (XZ, flat faces +-Y), the
pivot sits just behind the fist (RightGrip at the origin), the closed stack
is the handle the hand holds, the open arc spreads +-52 degrees around the
blade direction (+X)."""
import math
from mathutils import Matrix, Euler

PIVOT = Vector((-.22, 0, -.02))
N = 11
SPREAD = math.radians(52)
R_HANDLE, R_LEAF0, R_TIP = .56, .58, 1.36       # radii from the pivot
ANG = [(-SPREAD + 2 * SPREAD * i / (N - 1)) for i in range(N)]   # open angles (about +Y)
LAYER = .0072                                   # rib thickness / stacking step in y

def dir_at(a):
    # rotate +X about +Y by -a so positive angles lift the arc upward (+Z)
    return Vector((math.cos(a), 0, math.sin(a)))

def build_rig():
    for o in [o for o in bpy.data.objects if o.name in ("Fan_Rig",)]:
        bpy.data.objects.remove(o)
    arm = bpy.data.armatures.new("Fan_Rig")
    rigo = bpy.data.objects.new("Fan_Rig", arm)
    col.objects.link(rigo)
    bpy.context.view_layer.objects.active = rigo
    rigo.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    root = arm.edit_bones.new("Root"); root.head = (0, 0, 0); root.tail = (0, .0, .12)
    for i, a in enumerate(ANG):
        b = arm.edit_bones.new(f"Rib_{i:02}")
        b.head = PIVOT; b.tail = PIVOT + dir_at(a) * .5
        b.align_roll(Vector((0, 1, 0)))
        b.parent = root
    bpy.ops.object.mode_set(mode="OBJECT")
    # follow the stock Knife clips
    rigo.parent = rig; rigo.parent_type = "BONE"; rigo.parent_bone = "Root"
    bpy.context.view_layer.update()
    rigo.matrix_world = Matrix.Identity(4)
    return rigo

def rib_mesh(i):
    """One rib or guard along its open direction: charcoal lower section
    (the handle stack), narrower upper stick under the leaf; guards are
    wider with foil edging and a carved tip."""
    a = ANG[i]; d = dir_at(a); nrm = Vector((-d.z, 0, d.x))       # in-plane normal
    guard = i in (0, N - 1)
    y0 = (i - (N - 1) / 2) * LAYER
    w_low, w_up = (.050, .030) if guard else (.030, .014)
    tip = R_TIP + (.04 if guard else 0)
    pts = [(-.03, -w_low / 2), (R_HANDLE, -w_low / 2), (R_HANDLE + .06, -w_up / 2), (tip - .05, -w_up / 2), (tip, 0),
           (tip - .05, w_up / 2), (R_HANDLE + .06, w_up / 2), (R_HANDLE, w_low / 2), (-.03, w_low / 2), (-.05, 0)]
    outline = []
    for r, w in pts:
        p = PIVOT + d * r + nrm * w
        outline.append((p.x, p.z))
    bm = solid_plate(outline, y0 - LAYER * .48, y0 + LAYER * .48, ch=.0015, mat=CORE)
    if guard:
        for f in bm.faces:
            c = f.calc_center_median()
            rr = (Vector((c.x, 0, c.z)) - PIVOT).dot(d)
            if rr > R_HANDLE + .06 and abs(f.normal.y) < .5:
                f.material_index = ACCENT          # foil edging on the guard's upper sides
    return bm

def build_ribs(rigo):
    obs = []
    for i in range(N):
        o = link(f"GFF_Rib{i:02}", rib_mesh(i), bone="Root")
        o.parent = rigo; o.parent_type = "BONE"; o.parent_bone = f"Rib_{i:02}"
        bpy.context.view_layer.update(); o.matrix_world = Matrix.Identity(4)
        obs.append(o)
    # pivot pin (pewter hex) through the stack
    st = [[(PIVOT.x + .026 * math.cos(math.radians(30 + 60 * k)), y, PIVOT.z + .026 * math.sin(math.radians(30 + 60 * k))) for k in range(6)]
          for y in (-(N / 2) * LAYER - .006, (N / 2) * LAYER + .006)]
    pin = loft3([[(p[0], p[1], p[2]) for p in ring] for ring in st], [STEEL] * 6, cap_mat=EDGE)
    # loft3 lofts along the ring order; rebuild rings as (x, y, z) stations along y
    pino = link("GFF_Pin", pin, bone="Root")
    pino.parent = rigo; pino.parent_type = "BONE"; pino.parent_bone = "Root"
    bpy.context.view_layer.update(); pino.matrix_world = Matrix.Identity(4)
    return obs, pino

def build_leaf(rigo):
    """Pleated leaf: per sector, an ivory face and a slate face meeting at a
    mid crease (ridges/valleys alternate in y). Skinned to the two ribs."""
    bm = bmesh.new()
    vg = []                                  # (vert, weights{rib: w})
    rows = [R_LEAF0, (R_LEAF0 + R_TIP) / 2, R_TIP - .02]
    grid = []
    for i in range(N):
        col_ = []
        for r in rows:
            p = PIVOT + dir_at(ANG[i]) * r
            v = bm.verts.new((p.x, 0.0, p.z)); col_.append(v); vg.append((v, {i: 1.0}))
        grid.append(col_)
    mids = []
    for i in range(N - 1):
        a = (ANG[i] + ANG[i + 1]) / 2
        yo = .012 if i % 2 == 0 else -.012
        col_ = []
        for r in rows:
            p = PIVOT + dir_at(a) * r
            v = bm.verts.new((p.x, yo * (r / R_TIP), p.z)); col_.append(v); vg.append((v, {i: .5, i + 1: .5}))
        mids.append(col_)
    for i in range(N - 1):
        for k in range(len(rows) - 1):
            f1 = bm.faces.new((grid[i][k], mids[i][k], mids[i][k + 1], grid[i][k + 1])); f1.material_index = ARM
            f2 = bm.faces.new((mids[i][k], grid[i + 1][k], grid[i + 1][k + 1], mids[i][k + 1])); f2.material_index = 1
    # give the leaf thickness so it reads from both sides (Roblox draws one side)
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=.004)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    leaf = link("GFF_Leaf", bm, bone="Root")
    leaf.parent = rigo; leaf.parent_type = "OBJECT"
    bpy.context.view_layer.update(); leaf.matrix_world = Matrix.Identity(4)
    # weights by nearest rib angle (solidify duplicated the verts)
    groups = [leaf.vertex_groups.new(name=f"Rib_{i:02}") for i in range(N)]
    for v in leaf.data.vertices:
        rel = Vector((v.co.x, 0, v.co.z)) - PIVOT
        a = math.atan2(rel.z, rel.x)
        t = (a + SPREAD) / (2 * SPREAD) * (N - 1)
        i0 = max(0, min(N - 2, int(math.floor(t)))); f = max(0.0, min(1.0, t - i0))
        groups[i0].add([v.index], 1 - f, "REPLACE"); groups[i0 + 1].add([v.index], f, "REPLACE")
    md = leaf.modifiers.new("Fan", "ARMATURE"); md.object = rigo
    return leaf

def pose_angles(rigo, scale):
    """scale 1 = open (rest), 0 = closed (every rib on the blade line)."""
    for i, a in enumerate(ANG):
        pb = rigo.pose.bones[f"Rib_{i:02}"]
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()
    for i, a in enumerate(ANG):
        pb = rigo.pose.bones[f"Rib_{i:02}"]
        rest = rigo.data.bones[pb.name].matrix_local
        # a rib at angle a points along (cos a, 0, sin a) = rotation by -a about +Y; closing rotates it back by +a
        rot = Matrix.Translation(PIVOT) @ Matrix.Rotation((1 - scale) * a, 4, "Y") @ Matrix.Translation(-PIVOT)
        pb.matrix = rot @ rest
    bpy.context.view_layer.update()

def make_actions(rigo):
    rigo.animation_data_create()
    acts = {}
    for name, keys in (("Fan_Open", [(1, 0.0), (5, .7), (8, 1.06), (11, .98), (13, 1.0)]),
                       ("Fan_Close", [(1, 1.0), (4, .35), (7, -.03), (9, 0.0)]),
                       ("Fan_InspectFan", [(1, 1.0), (10, 1.0), (14, .86), (18, 1.0), (22, .86), (26, 1.0), (34, 1.0)])):
        act = bpy.data.actions.get(name) or bpy.data.actions.new(name)
        act.use_fake_user = True
        rigo.animation_data.action = act
        for fr, sc_ in keys:
            pose_angles(rigo, sc_)
            for pb in rigo.pose.bones:
                if pb.name.startswith("Rib_"):
                    pb.keyframe_insert("rotation_euler", frame=fr)
        acts[name] = act
    rigo.animation_data.action = None
    pose_angles(rigo, 1.0)
    for pb in rigo.pose.bones:
        pb.rotation_euler = (0, 0, 0)
    return acts

def build_foil():
    """Paired foil accent near the base of the outer guards."""
    bars = []
    for i in (0, N - 1):
        d = dir_at(ANG[i]); nrm = Vector((-d.z, 0, d.x))
        y = (i - (N - 1) / 2) * LAYER
        y1 = y + (LAYER * .48 + .0025) * (1 if y > 0 else -1)
        for k, off in enumerate((.0, .03)):
            base = PIVOT + d * (R_HANDLE - .14 + off) + nrm * (-.012 + k * .006)
            pts = [base + d * s + nrm * t for s, t in ((0, 0), (.06, 0), (.064, .004), (.06, .008), (0, .008))]
            yy = sorted((y + LAYER * .48 * (1 if y > 0 else -1), y1))
            bars.append((i, solid_plate([(p.x, p.z) for p in pts], yy[0], yy[1], ch=.001, mat=ACCENT)))
    return bars

rigo = build_rig()
ribs, pin = build_ribs(rigo)
for i, bm in build_foil():
    o = link(f"GFF_Foil{i:02}_{len(col.objects)}", bm, bone="Root")
    o.parent = rigo; o.parent_type = "BONE"; o.parent_bone = f"Rib_{i:02}"
    bpy.context.view_layer.update(); o.matrix_world = Matrix.Identity(4)
leaf = build_leaf(rigo)
for o in col.objects:
    if o.type == "MESH":
        flat_uv(o)
acts = make_actions(rigo)

HARDWARE = []
STOCK_PARTS = ["Knife_Blade", "Knife_Hilt", "Knife_Neon"]

def set_skin(on):
    for n in STOCK_PARTS:
        o = bpy.data.objects[n]; o.hide_render = on; o.hide_set(on)
    col.hide_render = not on
    col.hide_viewport = not on

set_skin(True)
result = {"objects": [(o.name, o.type) for o in col.objects], "actions": list(acts)}
