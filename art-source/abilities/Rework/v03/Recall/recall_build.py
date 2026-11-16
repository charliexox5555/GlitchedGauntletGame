"""Recall anchor (ability rework v03). Run through the LIVE Blender MCP only:

    exec(open(r"<repo>/tools/blender/rework/rw_core.py").read())
    S = rw_scene("RW_Recall")
    exec(open(r"<repo>/art-source/abilities/Rework/v03/Recall/recall_build.py").read())
    recall_build(S)

Rebuilds everything from scratch (deterministic). RECALL_SEATS is the audit whitelist.
Axes: +X forward, +Y left, +Z up, 1 unit = 1 stud. Kind "placed": origin = floor centre, faces +X.
"""
import math
import bmesh
from mathutils import Vector, Matrix

RC_COREZ = 0.70          # core centre (its origin)
RC_COREUP = 0.08         # armed travel straight up
RC_HR = 0.19             # prong hinge radius from the axis
RC_HZ = 0.42             # prong hinge height
# (index, azimuth deg, path, sections): back prong is the tall one, the front two leave the front open
RC_PATH_FRONT = [(0, 0), (0.012, 0.07), (0.014, 0.12), (-0.012, 0.20), (-0.040, 0.29), (-0.058, 0.38), (-0.072, 0.44)]
RC_PATH_BACK = [(0, 0), (0.012, 0.07), (0.016, 0.13), (-0.012, 0.23), (-0.042, 0.34), (-0.064, 0.46), (-0.094, 0.55), (-0.128, 0.595)]
RC_SECS_BACK = [(0.026, 0.036), (0.028, 0.036), (0.032, 0.05), (0.03, 0.048), (0.026, 0.044), (0.022, 0.038),
                (0.018, 0.03), (0.011, 0.018)]
RC_SECS = [(0.026, 0.036), (0.028, 0.036), (0.032, 0.05), (0.03, 0.048), (0.026, 0.042), (0.02, 0.032), (0.011, 0.018)]
RC_PRONGS = [(1, 180.0, RC_PATH_BACK), (2, 60.0, RC_PATH_FRONT), (3, -60.0, RC_PATH_FRONT)]

# housing plan (CCW): pointed prow with a flat nose for the status light, cut back corners
RC_HOUSE = [(-0.24, -0.21), (0.08, -0.21), (0.265, -0.055), (0.285, -0.035), (0.285, 0.035), (0.265, 0.055),
            (0.08, 0.21), (-0.24, 0.21), (-0.27, 0.18), (-0.27, -0.18)]
RC_LEAN = 0.02                         # flanks lean in by this much from foot to shoulder
RC_RAKE_P = (0.16, 0.0, 0.36)          # raked front deck plane
RC_RAKE_N = Vector((1.0, 0.0, 1.5)).normalized()

RECALL_SEATS = [
    ("Housing", "Base"), ("Legs", "Base"), ("Legs", "Pads"), ("SidePanels", "Housing"), ("Fixings", "SidePanels"),
    ("Collar", "Housing"), ("Ring_Violet", "Collar"), ("CradlePin", "Housing"), ("Core", "CradlePin"),
    ("Sockets", "Housing"), ("HingePins", "Sockets"), ("HingePins", "Prong"), ("Bezel", "Housing"),
    ("Light", "Bezel"), ("Light", "Housing"), ("Strips", "Housing"), ("Handle", "Housing"), ("Deck", "Housing"),
    ("Collar", "Deck"), ("Sockets", "Deck"), ("CradlePin", "Deck"),
]


# --- small geometry helpers ------------------------------------------------------------------------
def rc_offset(pts, d):
    """Offset a simple polygon inward by d (negative = outward), mitred corners, same point order."""
    n = len(pts)
    area = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n))
    s = 1.0 if area > 0 else -1.0
    lines = []
    for i in range(n):
        p, q = Vector(pts[i]), Vector(pts[(i + 1) % n])
        e = (q - p).normalized()
        nrm = Vector((-e.y, e.x)) * s
        lines.append((p + nrm * d, e))
    out = []
    for i in range(n):
        (p, u), (q, v) = lines[i - 1], lines[i]
        cr = u.x * v.y - u.y * v.x
        if abs(cr) < 1e-9:
            out.append((q.x, q.y))
            continue
        w = q - p
        t = (w.x * v.y - w.y * v.x) / cr
        r = p + u * t
        out.append((r.x, r.y))
    return out


def rc_slab(name, pts, rings):
    """Loft a (possibly concave) plan through [(z, inset)] rings."""
    return rw_loft(name, [(z, rc_offset(pts, ins) if ins else list(pts)) for z, ins in rings])


def rc_tube(name, rings):
    """Faceted ring/collar: rings = [(z, outer_pts, inner_pts)], same point count everywhere."""
    bm = bmesh.new()
    vo = [[bm.verts.new((x, y, z)) for x, y in o] for z, o, _i in rings]
    vi = [[bm.verts.new((x, y, z)) for x, y in i] for z, _o, i in rings]
    n = len(vo[0])
    for a, b in zip(vo, vo[1:]):
        for k in range(n):
            j = (k + 1) % n
            bm.faces.new((a[k], a[j], b[j], b[k]))
    for a, b in zip(vi, vi[1:]):
        for k in range(n):
            j = (k + 1) % n
            bm.faces.new((b[k], b[j], a[j], a[k]))
    for o, i in ((vo[0], vi[0]), (vo[-1], vi[-1])):
        for k in range(n):
            j = (k + 1) % n
            bm.faces.new((o[k], o[j], i[j], i[k]))
    return _rw_finish(bm, name)


def rc_sweep(name, path, secs, chamf=0.4):
    """Bar swept along a path in the local XZ plane; sections (half thickness in-plane, half width Y)."""
    P = [Vector((x, 0.0, z)) for x, z in path]
    n = len(P)
    bm = bmesh.new()
    rings = []
    for i, p in enumerate(P):
        t = (P[min(i + 1, n - 1)] - P[max(i - 1, 0)]).normalized()
        nrm = Vector((t.z, 0.0, -t.x))
        a, b = secs[i]
        c = min(a, b) * chamf
        rings.append([bm.verts.new(p + nrm * u + Vector((0, v, 0))) for u, v in rw_cham_rect(2 * a, 2 * b, c)])
    m = len(rings[0])
    for a, b in zip(rings, rings[1:]):
        for k in range(m):
            j = (k + 1) % m
            bm.faces.new((a[k], a[j], b[j], b[k]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    return _rw_finish(bm, name)


def rc_bar(name, p0, p1, w0, h0, w1, h1, c):
    """Straight tapered bar between two points, chamfered cross-sections (hull)."""
    p0, p1 = Vector(p0), Vector(p1)
    d = (p1 - p0).normalized()
    side = d.cross(Vector((0, 0, 1)))
    side = side.normalized() if side.length > 1e-6 else Vector((0, 1, 0))
    up = side.cross(d).normalized()
    pts = []
    for p, w, h in ((p0, w0, h0), (p1, w1, h1)):
        for u, v in rw_cham_rect(w, h, c):
            pts.append(p + side * u + up * v)
    return rw_hull(name, [tuple(q) for q in pts])


def rc_join(name, meshes, mats=None):
    bm = bmesh.new()
    for me, M in meshes:
        if M is not None:
            me.transform(M)
        bm.from_mesh(me)
    for me, _M in meshes:
        bpy.data.meshes.remove(me)
    out = bpy.data.meshes.new(name)
    bm.to_mesh(out)
    bm.free()
    for p in out.polygons:
        p.use_smooth = False
    return out


def rc_hinge_matrix(az):
    a = math.radians(az)
    return Matrix.Translation((RC_HR * math.cos(a), RC_HR * math.sin(a), RC_HZ)) @ Matrix.Rotation(a, 4, "Z")


def rc_fix(o, role):
    """One material, index 0 (rw_bool leaves an empty slot), and drop zero-area slivers."""
    me = o.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-5, edges=bm.edges)
    bm.to_mesh(me)
    bm.free()
    me.materials.clear()
    me.materials.append(rw_mat(role))
    for p in me.polygons:
        p.material_index = 0
        p.use_smooth = False
    me.update()


ROT_Z_TO_X = Matrix.Rotation(math.radians(90), 4, "Y")    # loft axis z -> +x
ROT_Z_TO_Y = Matrix.Rotation(math.radians(-90), 4, "X")   # loft axis z -> +y


# --- the build ---------------------------------------------------------------------------------------
def recall_build(S):
    rw_clear("Recall_")
    col = rw_col(S, "Recall")
    roles = {}

    def add(name, me, role, loc=(0, 0, 0), rot=(0, 0, 0)):
        o = rw_obj(col, name, me, role, loc=loc, rot=rot)
        roles[name] = role
        return o

    # 1. base plate: battered dark keel, prow forward
    base_plan = rc_offset(RC_HOUSE, -0.05)
    add("Recall_Base", rc_slab("Recall_Base", base_plan, [(0.05, 0.025), (0.075, 0), (0.11, 0), (0.13, 0.02)]), "Dark")

    # 2. legs + pads: four splayed outriggers
    legs, pads = [], []
    for (ix, iy), (px, py) in (((0.06, 0.19), (0.22, 0.33)), ((0.06, -0.19), (0.22, -0.33)),
                                ((-0.20, 0.19), (-0.31, 0.33)), ((-0.20, -0.19), (-0.31, -0.33))):
        legs.append((rc_bar("tmp", (ix, iy, 0.08), (px, py, 0.028), 0.10, 0.052, 0.072, 0.032, 0.012), None))
        pads.append((rw_loft("tmp", [(0.0, rw_ngon(0.056, 6)), (0.008, rw_ngon(0.062, 6)), (0.032, rw_ngon(0.062, 6)),
                                      (0.046, rw_ngon(0.046, 6))]), Matrix.Translation((px, py, 0))))
    add("Recall_Legs", rc_join("Recall_Legs", legs), "Panel")
    add("Recall_Pads", rc_join("Recall_Pads", pads), "Grip")

    # 3. housing: tapered body, raked front deck
    hme = rc_slab("Recall_Housing", RC_HOUSE, [(0.12, 0), (0.33, RC_LEAN), (0.36, RC_LEAN + 0.025)])
    rw_plane_cut(hme, RC_RAKE_P, RC_RAKE_N)
    add("Recall_Housing", hme, "Body")
    # 3b. deck plate: lighter slate cap on the flat top, carved front edge where the rake starts
    dme = rc_slab("Recall_Deck", RC_HOUSE, [(0.352, RC_LEAN + 0.03), (0.368, RC_LEAN + 0.03), (0.376, RC_LEAN + 0.038)])
    rw_plane_cut(dme, (0.15, 0, 0.36), (1.0, 0, 0.7))
    add("Recall_Deck", dme, "Panel")

    # 4. side panels with fixings
    pan, fix = [], []
    wall = lambda z: 0.21 - RC_LEAN * (z - 0.12) / 0.21       # leaning flank: y of the wall at height z
    tilt = math.atan2(RC_LEAN, 0.21)
    for s in (1, -1):
        outline = [(-0.20, 0.17), (0.04, 0.17), (0.06, 0.19), (0.06, 0.29), (0.035, 0.31), (-0.20, 0.31)]
        pts = []
        for x, z in outline:
            pts += [(x, s * (wall(z) - 0.011), z), (x, s * (wall(z) + 0.004), z)]
        for x, z in rc_offset(outline, 0.006):
            pts.append((x, s * (wall(z) + 0.009), z))
        pan.append((rw_hull("tmp", pts), None))
        for x, z in ((-0.175, 0.195), (-0.175, 0.285), (0.025, 0.205), (0.02, 0.28)):
            bolt = rw_loft("tmp", [(0.0, rw_ngon(0.012, 6)), (0.007, rw_ngon(0.012, 6)), (0.011, rw_ngon(0.008, 6))])
            M = (Matrix.Translation((x, s * (wall(z) + 0.004), z)) @ Matrix.Rotation(-s * tilt, 4, "X")
                 @ Matrix.Rotation(math.radians(-90 * s), 4, "X"))
            fix.append((bolt, M))
    add("Recall_SidePanels", rc_join("Recall_SidePanels", pan), "Panel")
    add("Recall_Fixings", rc_join("Recall_Fixings", fix), "Metal")

    # 5. back carry handle (the owner picks the anchor up by it)
    hpath = [(-0.245, 0.165), (-0.305, 0.178), (-0.322, 0.235), (-0.305, 0.292), (-0.242, 0.305)]
    add("Recall_Handle", rc_sweep("Recall_Handle", hpath, [(0.016, 0.075)] * 5), "Metal")

    # 6. status light on the nose, in a dark bezel
    bez = rw_loft("tmp", [(0.0, rw_ngon(0.032, 6, 0)), (0.008, rw_ngon(0.032, 6, 0)), (0.012, rw_ngon(0.027, 6, 0))])
    bez.transform(Matrix.Translation((0.270, 0, 0.20)) @ ROT_Z_TO_X)
    add("Recall_Bezel", rc_join("Recall_Bezel", [(bez, None)]), "Dark")
    lens = rw_loft("tmp", [(0.0, rw_ngon(0.021, 6, 0)), (0.024, rw_ngon(0.021, 6, 0)), (0.031, rw_ngon(0.014, 6, 0))])
    lens.transform(Matrix.Translation((0.262, 0, 0.20)) @ ROT_Z_TO_X)
    add("Recall_Light_Energy", rc_join("Recall_Light_Energy", [(lens, None)]), "Energy")

    # 7. facing chevron inlaid on the raked deck (violet guide strip)
    chev = [(0.055, 0.0), (-0.03, 0.085), (-0.066, 0.085), (0.019, 0.0), (-0.066, -0.085), (-0.03, -0.085)]
    cme = rc_slab("tmp", chev, [(-0.006, 0), (0.004, 0), (0.007, 0.004)])
    u = Vector((1.5, 0, -1.0)).normalized()
    origin = Vector((0.222, 0, 0.36 - 0.062 / 1.5))
    M = Matrix(((u.x, 0, RC_RAKE_N.x, origin.x), (0, 1, 0, 0), (u.z, 0, RC_RAKE_N.z, origin.z), (0, 0, 0, 1)))
    add("Recall_Strips_Violet", rc_join("Recall_Strips_Violet", [(cme, M)]), "Violet")

    # 8. core cradle: collar, violet ring, centre pin
    o8 = lambda r: rw_ngon(r, 8)
    add("Recall_Collar", rc_tube("Recall_Collar", [(0.335, o8(0.15), o8(0.115)), (0.43, o8(0.15), o8(0.115)),
                                                    (0.45, o8(0.132), o8(0.115))]), "Dark")
    add("Recall_Ring_Violet", rc_tube("Recall_Ring_Violet", [(0.40, o8(0.118), o8(0.098)), (0.46, o8(0.118), o8(0.098))]),
        "Violet")
    add("Recall_CradlePin", rw_loft("Recall_CradlePin", [(0.33, rw_ngon(0.032, 6)), (0.48, rw_ngon(0.032, 6)),
                                                         (0.515, rw_ngon(0.02, 6))]), "Metal")

    # 9. the core: elongated hex bipyramid, origin at its centre
    h6 = lambda r: rw_ngon(r, 6, 0)
    core = rw_loft("Recall_Core_Violet", [(-0.20, h6(0.014)), (-0.07, h6(0.10)), (0.03, h6(0.10)), (0.20, h6(0.014))])
    add("Recall_Core_Violet", core, "Violet", loc=(0, 0, RC_COREZ))

    # 10. prongs, sockets, hinge pins
    socks, pins = [], []
    ear = [(-0.035, -0.08), (0.035, -0.08), (0.035, 0.012), (0.014, 0.04), (-0.014, 0.04), (-0.035, 0.012)]
    ear_in = rc_offset(ear, 0.004)
    for idx, az, path in RC_PRONGS:
        M = rc_hinge_matrix(az)
        for s in (1, -1):
            y0 = s * 0.050
            pts = [(x, y0 + dy, z) for x, z in ear for dy in (-0.007, 0.007)]
            pts += [(x, y0 + dy, z) for x, z in ear_in for dy in (-0.011, 0.011)]
            socks.append((rw_hull("tmp", pts), M.copy()))
        pin = rw_loft("tmp", [(-0.07, rw_ngon(0.008, 6)), (-0.064, rw_ngon(0.012, 6)), (0.064, rw_ngon(0.012, 6)),
                              (0.07, rw_ngon(0.008, 6))])
        pins.append((pin, M @ ROT_Z_TO_Y))
        # the prong: swept arm unioned with its hinge knuckle, origin on the hinge
        arm = rc_sweep(f"Recall_Prong{idx}", path, RC_SECS_BACK if len(path) == len(RC_SECS_BACK) else RC_SECS)
        po = add(f"Recall_Prong{idx}", arm, "Metal")
        kn = rw_loft("tmp", [(-0.035, rw_ngon(0.024, 8)), (-0.03, rw_ngon(0.03, 8)), (0.03, rw_ngon(0.03, 8)),
                             (0.035, rw_ngon(0.024, 8))])
        kn.transform(ROT_Z_TO_Y)
        ko = rw_obj(col, "Recall_tmpKnuckle", kn)
        rw_bool(po, ko, "UNION")
        po.matrix_world = M
        rw_empty(col, f"Recall_Prong{idx}Pivot", loc=M.to_translation(), rot=(0, 0, az), size=0.06)
    add("Recall_Sockets", rc_join("Recall_Sockets", socks), "Metal")
    add("Recall_HingePins", rc_join("Recall_HingePins", pins), "Accent")

    # locators
    rw_empty(col, "Recall_Floor", loc=(0, 0, 0), size=0.08)
    rw_empty(col, "Recall_Top", loc=(0, 0, 1.0), size=0.08)
    rw_empty(col, "Recall_CoreUp", loc=(0, 0, RC_COREZ + RC_COREUP), size=0.06)

    for name, role in roles.items():
        rc_fix(bpy.data.objects[name], role)
    return sorted(roles)


def recall_pose(open_deg=0.0, core_up=0.0):
    """Open the prongs about their pivots (local Y) and lift the core; (0, 0) = rest."""
    for idx, az, _p in RC_PRONGS:
        o = bpy.data.objects[f"Recall_Prong{idx}"]
        o.matrix_world = rc_hinge_matrix(az) @ Matrix.Rotation(math.radians(open_deg), 4, "Y")
    bpy.data.objects["Recall_Core_Violet"].location = (0, 0, RC_COREZ + core_up)
    bpy.context.view_layer.update()


def recall_render(S, out_dir, names, res=(700, 500)):
    """names: list of (file tag, view, zoom, target, ortho)."""
    out = []
    for tag, view, zoom, target, ortho in names:
        out.append(rw_render(S, "Recall_", os.path.join(out_dir, f"Recall_{tag}.jpg"), view=view, res=res, zoom=zoom,
                             target=target, ortho=ortho))
    return out
