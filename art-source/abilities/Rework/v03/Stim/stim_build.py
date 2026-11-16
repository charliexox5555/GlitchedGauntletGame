"""Stim beacon (ability rework v03). Run inside the live Blender MCP after rw_core:

    exec(open(r"<repo>/tools/blender/rework/rw_core.py").read())
    S = rw_scene("RW_Stim")
    exec(open(r"<repo>/art-source/abilities/Rework/v03/Stim/stim_build.py").read())
    stim_build(S)

Placed prop: origin = floor centre, +X forward, +Z up, 1 unit = 1 stud. Legs are authored OPEN.
"""
import bpy, bmesh, math
from mathutils import Vector, Matrix

C8 = math.cos(math.radians(22.5))

# --- housing taper (circumradius rings) ---------------------------------------------------------------
HZ0, HZ1 = 0.065, 0.350
HR0, HR1 = 0.395, 0.345
HA0, HA1 = HR0 * C8, HR1 * C8
HK = (HA0 - HA1) / (HZ1 - HZ0)          # apothem loss per unit height (face lean)

# --- legs ---------------------------------------------------------------------------------------------
LEG_AZ = (45.0, 135.0, 225.0, 315.0)
LEG_AH = 0.3675                          # hinge axis distance from the centre (along the diagonal)
LEG_ZH = 0.105                           # hinge axis height
LEG_OPEN = 13.0                          # deg about pivot local Y (+ = open, tips outward and down)
LEG_CLOSED = -(90.0 + math.degrees(math.atan(HK)))   # folded up flat against the housing face
BAY_DEPTH = 0.012

# --- coil ---------------------------------------------------------------------------------------------
COIL_R = 0.17          # centreline corner radius
COIL_Z0 = 0.785        # centreline height at the start
COIL_PITCH = 0.07
COIL_TURNS = 3
COIL_W, COIL_H, COIL_C = 0.048, 0.042, 0.011
COIL_A0 = 22.5         # start / end angle (both terminals on the rib at 22.5 deg)
TOP_Z = 1.158

STIM_SEATS = [
    ("Housing", "Foot"), ("Shoulder", "Housing"), ("Collar", "Shoulder"), ("Mast", "Collar"),
    ("CoilCollar", "Mast"), ("CoilRibs", "Mast"), ("CoilRibs", "CoilCollar"), ("CoilRibs", "Coil_Yellow"),
    ("CoilRibs", "Crown"), ("Mast", "Crown"), ("CoilClamps", "Coil_Yellow"), ("CoilClamps", "CoilRibs"),
    ("Emitter", "Crown"), ("HingeEars", "Foot"), ("HingeEars", "Housing"), ("HingePins", "HingeEars"),
    ("HingePins", "Leg"), ("FrontBezel", "Housing"), ("Hazard", "Housing"), ("Light_Energy", "FrontBezel"),
    ("SidePanels", "Housing"), ("BackHatch", "Housing"),
]


# --- helpers ------------------------------------------------------------------------------------------
def st_inset(pts, d):
    """Offset a CCW polygon inward by d (negative = outward)."""
    n = len(pts)
    lines = []
    for i in range(n):
        p = Vector(pts[i]); q = Vector(pts[(i + 1) % n]); e = (q - p).normalized()
        lines.append((p + Vector((-e.y, e.x)) * d, e))
    out = []
    for i in range(n):
        p1, e1 = lines[i - 1]; p2, e2 = lines[i]
        den = e1.x * e2.y - e1.y * e2.x
        if abs(den) < 1e-9:
            out.append((p2.x, p2.y)); continue
        dd = p2 - p1
        t = (dd.x * e2.y - dd.y * e2.x) / den
        v = p1 + e1 * t
        out.append((v.x, v.y))
    return out


def st_slab(name, outline, z0, z1, ch=0.0, chb=0.0):
    rings = []
    if chb > 0:
        rings += [(z0, st_inset(outline, chb)), (z0 + chb, outline)]
    else:
        rings.append((z0, outline))
    if ch > 0:
        rings += [(z1 - ch, outline), (z1, st_inset(outline, ch))]
    else:
        rings.append((z1, outline))
    return rw_loft(name, rings)


def st_cutter(name, outline, depth, mouth=0.004, out=0.05):
    """Recess cutter in a face frame: floor at -depth, 45 deg chamfered mouth at the face."""
    return rw_loft(name, [(-depth, outline), (-mouth, outline), (0.0, st_inset(outline, -mouth)),
                          (out, st_inset(outline, -mouth - out))])


def st_oct(name, zr, n=8, rot=None):
    return rw_loft(name, [(z, rw_ngon(r, n, rot)) for z, r in zr])


def st_hA(z):
    return HA0 - HK * (z - HZ0)


def st_face(az, zc, depth_ofs=0.0):
    """Frame on a housing face: x = u (across), y = v (up the face), z = n (out)."""
    a = math.radians(az)
    n = Vector((math.cos(a), math.sin(a), HK)).normalized()
    u = Vector((-math.sin(a), math.cos(a), 0.0))
    v = n.cross(u).normalized()
    o = Vector((st_hA(zc) * math.cos(a), st_hA(zc) * math.sin(a), zc)) + n * depth_ofs
    return Matrix(((u.x, v.x, n.x, o.x), (u.y, v.y, n.y, o.y), (u.z, v.z, n.z, o.z), (0, 0, 0, 1)))


def st_radial(az, origin=(0, 0, 0)):
    """x = radial out, y = up, z = x cross y (radial plane frame)."""
    a = math.radians(az)
    r = Vector((math.cos(a), math.sin(a), 0)); up = Vector((0, 0, 1)); t = r.cross(up)
    o = Vector(origin)
    return Matrix(((r.x, up.x, t.x, o.x), (r.y, up.y, t.y, o.y), (r.z, up.z, t.z, o.z), (0, 0, 0, 1)))


def st_hinge(az):
    a = math.radians(az)
    return Matrix.Translation((LEG_AH * math.cos(a), LEG_AH * math.sin(a), LEG_ZH)) @ Matrix.Rotation(a, 4, "Z")


def st_merge(name, meshes):
    """Join several meshes (disjoint shells) into one mesh."""
    bm = bmesh.new()
    for me in meshes:
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    out = bpy.data.meshes.new(name)
    bm.to_mesh(out); bm.free()
    for p in out.polygons:
        p.use_smooth = False
    return out


def st_tmp(col, mesh):
    return rw_obj(col, mesh.name + "_cut", mesh)


def st_hull_local(name, pts, M):
    me = rw_hull(name, pts)
    me.transform(M)
    return me


def st_prism_y(name, ring, y0, y1, c):
    """Prism along local Y with chamfered ends; ring is (x, z) points."""
    me = rw_loft(name, [(y0, st_inset(ring, c)), (y0 + c, ring), (y1 - c, ring), (y1, st_inset(ring, c))])
    me.transform(Matrix.Rotation(math.radians(-90), 4, "X"))   # (x, y, z) -> (x, z, -y)
    me.transform(Matrix.Scale(-1, 4, (0, 1, 0)) @ Matrix.Scale(-1, 4, (0, 0, 1)))  # keep x, flip y and z: rotation by 180 about X
    return me


def st_finish(o, role):
    me = o.data
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-5, edges=bm.edges)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    me.materials.clear()
    me.materials.append(rw_mat(role))
    for p in me.polygons:
        p.material_index = 0
        p.use_smooth = False
    me.update()


# --- parts --------------------------------------------------------------------------------------------
def st_coil_mesh(name):
    w, h, c = COIL_W / 2, COIL_H / 2, COIL_C       # (radial, z): outer corners chamfered, inner corners square (against the ribs)
    sec = [(-w, -h), (w - c, -h), (w, -h + c), (w, h - c), (w - c, h), (-w, h)]
    n_seg = 8 * COIL_TURNS
    pts = [(COIL_A0, COIL_R * C8, 1.0)]
    for k in range(n_seg):
        pts.append((COIL_A0 + 22.5 + 45.0 * k, COIL_R, 1.0 / C8))
    pts.append((COIL_A0 + 360.0 * COIL_TURNS, COIL_R * C8, 1.0))
    bm = bmesh.new()
    rings = []
    for ang, rad, s in pts:
        a = math.radians(ang)
        rh = Vector((math.cos(a), math.sin(a), 0))
        zc = COIL_Z0 + COIL_PITCH * (ang - COIL_A0) / 360.0
        P = rh * rad + Vector((0, 0, zc))
        rings.append([bm.verts.new(P + rh * (su * s) + Vector((0, 0, sv))) for su, sv in sec])
    m = len(sec)
    for a_, b_ in zip(rings, rings[1:]):
        for i in range(m):
            j = (i + 1) % m
            bm.faces.new((a_[i], a_[j], b_[j], b_[i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    return _rw_finish(bm, name)


def st_leg_mesh(col, name):
    """Leg in hinge-local space: hinge axis = local Y through the origin, blade along +X."""
    knuck = st_prism_y(name + "_k", rw_ngon(0.021, 6, 0), -0.040, 0.040, 0.005)
    blade_ol = [(0.010, -0.036), (0.050, -0.036), (0.085, -0.098), (0.262, -0.092), (0.300, -0.056),
                (0.300, 0.056), (0.262, 0.092), (0.085, 0.098), (0.050, 0.036), (0.010, 0.036)]
    blade = st_slab(name, blade_ol, -0.015, 0.015, ch=0.006, chb=0.006)
    # toe pad: flat on the floor in the OPEN pose
    th = math.radians(LEG_OPEN)
    Ry = Matrix.Rotation(th, 3, "Y")
    Ryi = Ry.inverted()
    top = []
    for x in (0.222, 0.292):
        for y in (-0.074, 0.074):
            top.append(Ry @ Vector((x, y, -0.011)))
    xb = min(p.x for p in top) + 0.012
    xf = max(p.x for p in top) - 0.014
    bot = [Vector((x, y, -LEG_ZH)) for x in (xb, xf) for y in (-0.062, 0.062)]
    mid = [Vector((x, y, -LEG_ZH + 0.008)) for x in (xb - 0.008, xf + 0.006) for y in (-0.070, 0.070)]
    toe = rw_hull(name + "_toe", [tuple(Ryi @ p) for p in top + bot + mid])
    o = rw_obj(col, name, blade)
    for me in (knuck, toe):
        c = rw_obj(col, me.name, me)
        rw_bool(o, c, "UNION")
    # lengthwise machined slot on the top face (faces the housing when folded)
    slot = st_slab(name + "_slot", rw_cham_rect(0.13, 0.040, 0.013), 0.006, 0.05)
    slot.transform(Matrix.Translation((0.180, 0, 0)))
    rw_bool(o, rw_obj(col, slot.name, slot))
    return o


def stim_build(S):
    rw_clear("Stim_")
    col = rw_col(S, "Stim")
    made = {}

    def part(name, mesh, role, loc=(0, 0, 0)):
        o = rw_obj(col, name, mesh, role, loc=loc)
        made[name] = role
        return o

    # floor flange: battered octagon, chamfered top
    part("Stim_Foot", st_oct("Stim_Foot", [(0.0, 0.445), (0.040, 0.445), (0.070, 0.418)]), "Dark")

    # housing: tapered octagon on the flange
    hous = part("Stim_Housing", st_oct("Stim_Housing", [(HZ0 - 0.006, HR0 - 0.004), (HZ0, HR0), (HZ1, HR1)]), "Body")

    # recess cutters (one combined object): front window, two side panels, back hatch, four leg bays
    front_ol = rw_cham_rect(0.170, 0.214, 0.012)               # u x v
    side_ol = [(0.085 - 0.012, -0.101), (0.085, -0.101 + 0.012), (0.085, 0.101 - 0.012), (0.085 - 0.012, 0.101),
               (-0.085 + 0.046, 0.101), (-0.085, 0.101 - 0.046), (-0.085, -0.101 + 0.012), (-0.085 + 0.012, -0.101)]
    back_ol = rw_cham_rect(0.160, 0.200, 0.014)
    cut_meshes = []
    m = st_cutter("Stim_cutF", front_ol, 0.014); m.transform(st_face(0, 0.220)); cut_meshes.append(m)
    for az, flip in ((90, 1), (270, -1)):
        ol = [(-x * flip, y) for x, y in side_ol]                # big cut corner faces forward-up
        if flip < 0:
            ol = list(reversed(ol))
        ol = [(x, y) for x, y in ol]
        m = st_cutter("Stim_cutS%d" % az, ol, 0.014); m.transform(st_face(az, 0.215)); cut_meshes.append(m)
    m = st_cutter("Stim_cutB", back_ol, 0.014); m.transform(st_face(180, 0.215)); cut_meshes.append(m)
    for az in LEG_AZ:
        bay = rw_hull("Stim_cutBay", [(sx * w, sy * 0.30, n) for sx in (-1, 1) for sy in (-1, 1)
                                      for (w, n) in ((0.108, -BAY_DEPTH), (0.116, -0.004), (0.18, 0.06))])
        bay.transform(st_face(az, 0.20)); cut_meshes.append(bay)
    bays = [m.copy() for m in cut_meshes[-4:]]
    cut = st_merge("Stim_cutAll", cut_meshes)
    rw_bool(hous, rw_obj(col, "Stim_cutAll", cut))

    # shoulder cap: overhanging lip (the seam), hip roof, deck
    part("Stim_Shoulder", st_oct("Stim_Shoulder", [(0.338, 0.333), (0.346, 0.360), (0.371, 0.360), (0.384, 0.346),
                                                   (0.430, 0.214), (0.445, 0.200)]), "Panel")
    # leg stowage notches: the bays continue through the shoulder lip so the folded leg tips tuck in
    rw_bool(bpy.data.objects["Stim_Shoulder"], rw_obj(col, "Stim_cutNotch", st_merge("Stim_cutNotch", bays)))
    # mast collar, mast, coil collar
    part("Stim_Collar", st_oct("Stim_Collar", [(0.436, 0.128), (0.462, 0.128), (0.480, 0.108), (0.492, 0.094)]), "Dark")
    part("Stim_Mast", st_oct("Stim_Mast", [(0.470, 0.077), (0.600, 0.077), (0.607, 0.066), (0.627, 0.066),
                                           (0.634, 0.077), (0.680, 0.077), (0.696, 0.066), (1.040, 0.066)]), "Metal")
    part("Stim_CoilCollar", st_oct("Stim_CoilCollar", [(0.690, 0.086), (0.702, 0.106), (0.728, 0.106), (0.742, 0.090)]), "Dark")

    # coil
    part("Stim_Coil_Yellow", st_coil_mesh("Stim_Coil_Yellow"), "Yellow")

    # insulator ribs at the coil's mid-faces
    r_out = COIL_R * C8 - COIL_W / 2 + 0.005
    ribs = []
    for k in range(4):
        az = COIL_A0 + 90.0 * k
        r_in, zb, zt, cb, ct = 0.050, 0.735, 1.034, 0.030, 0.010
        ol = [(r_in, zb), (r_out - cb, zb), (r_out, zb + cb), (r_out, zt - ct), (r_out - ct, zt), (r_in, zt)]
        me = st_slab("Stim_rib%d" % k, ol, -0.013, 0.013, ch=0.005)
        me.transform(st_radial(az))
        ribs.append(me)
    part("Stim_CoilRibs", st_merge("Stim_CoilRibs", ribs), "Dark")

    # terminal clamps over both coil ends (on the rib at COIL_A0)
    cl = []
    for zc in (COIL_Z0, COIL_Z0 + COIL_PITCH * COIL_TURNS):
        ra, rb = 0.122, COIL_R * C8 + COIL_W / 2 + 0.013
        me = rw_cham_box("Stim_clamp", rb - ra, 0.060, 0.066, 0.010)
        me.transform(Matrix.Rotation(math.radians(COIL_A0), 4, "Z") @ Matrix.Translation(((ra + rb) / 2, 0, zc)))
        cl.append(me)
    part("Stim_CoilClamps", st_merge("Stim_CoilClamps", cl), "Metal")

    # crown + emitter
    part("Stim_Crown", st_oct("Stim_Crown", [(1.025, 0.085), (1.045, 0.176), (1.062, 0.176), (1.080, 0.128),
                                             (1.095, 0.100)]), "Panel")
    part("Stim_Emitter", st_oct("Stim_Emitter", [(1.088, 0.050), (1.118, 0.050), (1.128, 0.036), (TOP_Z, 0.014)]), "Accent")

    # front: light bezel + lens, hazard plate
    bez_ol = rw_cham_rect(0.155, 0.076, 0.012)
    bez = st_slab("Stim_FrontBezel", bez_ol, -0.016, 0.005, ch=0.004)
    bez.transform(Matrix.Translation((0, 0.059, 0)))
    bez.transform(st_face(0, 0.220))
    bo = part("Stim_FrontBezel", bez, "Dark")
    lens_ol = rw_cham_rect(0.066, 0.030, 0.008)
    lc = st_cutter("Stim_cutLens", st_inset(lens_ol, -0.006), 0.008)
    lc.transform(Matrix.Translation((0, 0.059, 0.005))); lc.transform(st_face(0, 0.220))
    rw_bool(bo, rw_obj(col, "Stim_cutLens", lc))
    lens = st_slab("Stim_Light_Energy", lens_ol, -0.005, 0.013, ch=0.005)
    lens.transform(Matrix.Translation((0, 0.059, 0))); lens.transform(st_face(0, 0.220))
    part("Stim_Light_Energy", lens, "Energy")

    hz_ol = rw_cham_rect(0.155, 0.096, 0.012)
    hz = st_slab("Stim_Hazard", hz_ol, -0.016, 0.005, ch=0.004)
    hz.transform(Matrix.Translation((0, -0.047, 0))); hz.transform(st_face(0, 0.220))
    ho = part("Stim_Hazard", hz, "Hazard")
    sl = []
    vb, vt, wsl = -0.081, -0.013, 0.032
    L = (vt - vb) * math.tan(math.radians(30))          # stripes at 60 deg
    for u0 in (-0.065, -0.008):
        quad = [(u0, vb), (u0 + wsl, vb), (u0 + wsl + L, vt), (u0 + L, vt)]
        me = rw_hull("Stim_hzs", [(x, y, z) for x, y in quad for z in (-0.03, 0.03)])
        me.transform(st_face(0, 0.220)); sl.append(me)
    rw_bool(ho, rw_obj(col, "Stim_cutHz", st_merge("Stim_cutHz", sl)))

    # side panels (big cut corner forward-up) and back hatch with vent slots
    sp = []
    for az, flip in ((90, 1), (270, -1)):
        ol = [(-x * flip, y) for x, y in st_inset(side_ol, 0.007)]
        if flip < 0:
            ol = list(reversed(ol))
        me = st_slab("Stim_sp", ol, -0.016, 0.005, ch=0.004)
        me.transform(st_face(az, 0.215)); sp.append(me)
    part("Stim_SidePanels", st_merge("Stim_SidePanels", sp), "Panel")
    bh = st_slab("Stim_BackHatch", st_inset(back_ol, 0.007), -0.016, 0.005, ch=0.004)
    bh.transform(st_face(180, 0.215))
    bho = part("Stim_BackHatch", bh, "Panel")
    vs = []
    for v in (0.030, 0.056):
        me = st_slab("Stim_vs", rw_cham_rect(0.090, 0.012, 0.005), -0.008, 0.05)
        me.transform(Matrix.Translation((0, v, 0))); me.transform(st_face(180, 0.215)); vs.append(me)
    rw_bool(bho, rw_obj(col, "Stim_cutVent", st_merge("Stim_cutVent", vs)))

    # hinge ears + pins (static), legs (moving)
    ears, pins = [], []
    ring = rw_ngon(0.026, 6, 0)                                    # around the axis, (x, z)
    for az in LEG_AZ:
        Mh = st_hinge(az)
        for s in (-1, 1):
            y0, y1 = s * 0.044, s * 0.074
            lo, hi = min(y0, y1), max(y0, y1)
            pts = []
            for y, sh in ((lo, 0.0), (hi, 0.0)):
                pts += [(x * (1 - sh / 0.026), y, z * (1 - sh / 0.026)) for x, z in ring]
                pts += [(-0.030 + sh, y, -LEG_ZH + 0.060 - 0.005), (0.022 - sh, y, -LEG_ZH + 0.060 - 0.005)]
            ears.append(st_hull_local("Stim_ear", pts, Mh))
        pr = [(-0.085, 0.009), (-0.081, 0.013), (0.081, 0.013), (0.085, 0.009)]
        me = rw_loft("Stim_pin", [(y, rw_ngon(r, 6, 0)) for y, r in pr])
        me.transform(Matrix.Rotation(math.radians(-90), 4, "X"))
        me.transform(Mh)
        pins.append(me)
    part("Stim_HingeEars", st_merge("Stim_HingeEars", ears), "Metal")
    part("Stim_HingePins", st_merge("Stim_HingePins", pins), "Accent")

    leg0 = st_leg_mesh(col, "Stim_Leg1")
    for i, az in enumerate(LEG_AZ):
        name = "Stim_Leg%d" % (i + 1)
        if i == 0:
            o = leg0
        else:
            me = leg0.data.copy(); me.name = name
            o = rw_obj(col, name, me)
        o.location = st_hinge(az).to_translation()
        o.rotation_euler = (0.0, math.radians(LEG_OPEN), math.radians(az))
        made[name] = "Panel"
        rw_empty(col, name + "Pivot", loc=tuple(o.location), rot=(0, 0, az), size=0.04)

    rw_empty(col, "Stim_Floor", (0, 0, 0), size=0.08)
    rw_empty(col, "Stim_Top", (0, 0, TOP_Z), size=0.05)

    for n, role in made.items():
        st_finish(bpy.data.objects[n], role)
    # leftovers from temporary meshes
    for me in [m for m in bpy.data.meshes if m.name.startswith("Stim_") and m.users == 0]:
        bpy.data.meshes.remove(me)
    return sorted(made)


def stim_pose(angle_deg):
    """Set every leg to angle_deg about its pivot's local Y (LEG_OPEN = open, LEG_CLOSED = folded)."""
    for i, az in enumerate(LEG_AZ):
        o = bpy.data.objects["Stim_Leg%d" % (i + 1)]
        o.rotation_euler = (0.0, math.radians(angle_deg), math.radians(az))
    bpy.context.view_layer.update()
