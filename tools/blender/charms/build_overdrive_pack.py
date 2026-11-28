"""Build, validate, save (.blend), and render all 12 Overdrive Pack charms on Blender port 9100."""

import importlib
import math
import sys
import traceback

import bmesh
from mathutils import Euler, Matrix, Vector

HERE = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame\tools\blender\charms"
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import charm_kit as K  # noqa: E402
importlib.reload(K)

OVERDRIVE_ORDER = [
    "HazardSign",
    "BatteryCell",
    "CompassRose",
    "Keycard",
    "DashWing",
    "FrostCrystal",
    "ClockworkGear",
    "MiniTsuba",
    "PlasmaPrism",
    "PhantomLantern",
    "ReactorCore",
    "KillRadar",
]


def build_HazardSign(coll):
    mat_yel = K.make_material("Hazard_Yellow", "#F5C428", "SmoothPlastic", roughness=0.35)
    mat_dark = K.make_material("Hazard_Dark", "#282E3B", "SmoothPlastic", roughness=0.44)
    mat_chain = K.make_material("Chain_Metal", "#9AA4B4", "Metal", roughness=0.28, metallic=0.85)
    K.add_chain(coll, "HazardSign", mat_chain, bottom_z=-0.106)

    bm = bmesh.new()
    # Chamfered equilateral hazard triangle
    tri = [
        (-0.016, -0.140), (0.016, -0.140),
        (0.114, -0.312), (0.098, -0.336),
        (-0.098, -0.336), (-0.114, -0.312),
    ]
    K.add_layered_prism_y(bm, tri, y_half=0.019, cham_y=0.004, cham_in=0.04, mat_idx=0, center_xz=(0.0, -0.258))
    # Dark inner recessed triangle
    inner = [(0.0, -0.172), (0.074, -0.312), (-0.074, -0.312)]
    K.add_prism_y(bm, inner, -0.022, 0.022, mat_idx=1)
    # Proud yellow exclamation bar + diamond dot
    K.add_prism_y(bm, [(-0.012, -0.210), (0.012, -0.210), (0.008, -0.268), (-0.008, -0.268)], -0.026, 0.026, mat_idx=0)
    K.add_prism_y(bm, K.ngon_pts(0, -0.292, 0.012, 4, math.pi / 4), -0.026, 0.026, mat_idx=0)

    K.add_frustum_z(bm, K.cham_rect_pts(0, 0, 0.020, 0.015, 0.005), -0.148, K.cham_rect_pts(0, 0, 0.016, 0.012, 0.004), -0.124, mat_idx=2)
    K.add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=2)
    K.bm_to_object("HazardSign_Body", bm, [mat_yel, mat_dark, mat_chain], coll, union=True)


def build_BatteryCell(coll):
    mat_dark = K.make_material("Cell_Dark", "#363F52", "Metal", roughness=0.35, metallic=0.82)
    mat_steel = K.make_material("Cell_Steel", "#9AA4B4", "Metal", roughness=0.28, metallic=0.88)
    mat_neon = K.make_material("Cell_Neon", "#3FE0F2", "Neon", roughness=0.2, emission_strength=3.4)
    K.add_chain(coll, "BatteryCell", mat_steel, bottom_z=-0.106)

    bm = bmesh.new()
    # Hexagonal top & bottom armored end caps + 3 vertical armor spine rails + 2 cell divider rings
    K.add_frustum_z(bm, K.ngon_pts(0, 0, 0.064, 6), -0.185, K.ngon_pts(0, 0, 0.044, 6), -0.142, mat_idx=0)
    K.add_frustum_z(bm, K.ngon_pts(0, 0, 0.040, 6), -0.376, K.ngon_pts(0, 0, 0.064, 6), -0.330, mat_idx=0)
    K.add_prism_z(bm, K.ngon_pts(0, 0, 0.048, 6), -0.283, -0.271, mat_idx=0)
    K.add_prism_z(bm, K.ngon_pts(0, 0, 0.048, 6), -0.233, -0.221, mat_idx=0)
    # Positive terminal collar at top
    K.add_frustum_z(bm, K.ngon_pts(0, 0, 0.026, 6), -0.146, K.ngon_pts(0, 0, 0.018, 6), -0.124, mat_idx=1)
    for k in range(3):
        rot = Matrix.Rotation(math.pi / 6 + k * 2 * math.pi / 3, 4, "Z")
        K.add_box(bm, 0.044, 0.066, -0.010, 0.010, -0.340, -0.175, mat_idx=1, xform=rot)
    K.add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=1)
    K.bm_to_object("BatteryCell_Body", bm, [mat_dark, mat_steel], coll, union=True)

    # Separate segmented cyan Neon energy core inside
    bm_neon = bmesh.new()
    for sz0, sz1 in ((-0.332, -0.282), (-0.272, -0.232), (-0.222, -0.183)):
        K.add_prism_z(bm_neon, K.ngon_pts(0, 0, 0.045, 6), sz0, sz1, mat_idx=0)
    K.bm_to_object("BatteryCell_Neon", bm_neon, [mat_neon], coll, union=False)


def build_CompassRose(coll):
    mat_steel = K.make_material("Comp_Steel", "#B8C2D6", "Metal", roughness=0.24, metallic=0.90)
    mat_gold = K.make_material("Comp_Gold", "#F5C238", "Metal", roughness=0.25, metallic=0.90)
    mat_dark = K.make_material("Comp_Dark", "#3B4458", "Metal", roughness=0.36, metallic=0.80)
    K.add_chain(coll, "CompassRose", mat_steel, bottom_z=-0.106)

    bm = bmesh.new()
    cz = -0.252
    # Clean crisp octagonal backing ring (cham=0 keeps total tris well under 600!)
    K.add_ring_y(bm, 0.0, cz, r_in=0.044, r_out=0.070, n=8, y_half=0.011, cham=0.0, rot=math.pi / 8, mat_idx=2)
    # 4 sharp faceted diamond-ridge cardinal blades
    for k, m_idx in ((0, 1), (1, 0), (2, 1), (3, 0)):
        rot = Matrix.Translation((0, 0, cz)) @ Matrix.Rotation(k * math.pi / 2, 4, "Y")
        v_tip = bm.verts.new(rot @ Vector((0.0, 0.0, 0.116)))
        v_base = bm.verts.new(rot @ Vector((0.0, 0.0, -0.016)))
        v_l = bm.verts.new(rot @ Vector((-0.025, 0.0, 0.0)))
        v_r = bm.verts.new(rot @ Vector((0.025, 0.0, 0.0)))
        v_f = bm.verts.new(rot @ Vector((0.0, -0.020, 0.0)))
        v_b = bm.verts.new(rot @ Vector((0.0, 0.020, 0.0)))
        for tri in (
            [v_tip, v_f, v_r], [v_tip, v_l, v_f], [v_tip, v_r, v_b], [v_tip, v_b, v_l],
            [v_base, v_r, v_f], [v_base, v_f, v_l], [v_base, v_b, v_r], [v_base, v_l, v_b],
        ):
            f = bm.faces.new(tri)
            f.material_index = m_idx
            f.smooth = False
    # Central gold bezel diamond & machined North mounting collar clasping the North blade shoulder
    K.add_prism_y(bm, K.ngon_pts(0, cz, 0.024, 4), -0.024, 0.024, mat_idx=1)
    K.add_prism_z(bm, K.cham_rect_pts(0, 0, 0.017, 0.015, 0.004), -0.160, -0.138, mat_idx=0)
    K.add_frustum_z(bm, K.cham_rect_pts(0, 0, 0.018, 0.014, 0.004), -0.145, K.cham_rect_pts(0, 0, 0.015, 0.012, 0.004), -0.122, mat_idx=0)
    K.add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=0)
    K.bm_to_object("CompassRose_Body", bm, [mat_steel, mat_gold, mat_dark], coll, union=True)


def build_Keycard(coll):
    mat_slate = K.make_material("Card_Slate", "#4A556B", "SmoothPlastic", roughness=0.38)
    mat_gold = K.make_material("Card_Gold", "#F2BE38", "Metal", roughness=0.25, metallic=0.90)
    mat_dark = K.make_material("Card_Dark", "#232834", "SmoothPlastic", roughness=0.45)
    K.add_chain(coll, "Keycard", mat_gold, bottom_z=-0.106)

    bm = bmesh.new()
    z_top, z_bot = -0.138, -0.355
    card = [
        (-0.078, z_bot + 0.014), (0.064, z_bot + 0.014), (0.078, z_bot + 0.028),
        (0.078, z_top - 0.032), (0.046, z_top), (-0.078, z_top),
    ]
    K.add_layered_prism_y(bm, card, y_half=0.016, cham_y=0.004, cham_in=0.05, mat_idx=0, center_xz=(0.0, (z_top + z_bot) * 0.5))
    # Dark magnetic stripe bar across upper card + subtle bottom access bar
    K.add_box(bm, -0.070, 0.064, -0.019, 0.019, z_top - 0.062, z_top - 0.036, mat_idx=2)
    K.add_box(bm, 0.008, 0.064, -0.019, 0.019, z_bot + 0.036, z_bot + 0.054, mat_idx=2)
    # Proud beveled gold smart-chip + heavy machined gold top lanyard clip gripping the card edge
    K.add_prism_y(bm, K.cham_rect_pts(-0.034, -0.252, 0.024, 0.024, 0.006), -0.021, 0.021, mat_idx=1)
    K.add_prism_z(bm, K.cham_rect_pts(0, 0, 0.025, 0.021, 0.006), -0.156, -0.134, mat_idx=1)
    K.add_frustum_z(bm, K.cham_rect_pts(0, 0, 0.020, 0.015, 0.005), -0.138, K.cham_rect_pts(0, 0, 0.016, 0.012, 0.004), -0.122, mat_idx=1)
    K.add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=1)
    K.bm_to_object("Keycard_Body", bm, [mat_slate, mat_gold, mat_dark], coll, union=True)


def build_DashWing(coll):
    mat_dark = K.make_material("Wing_Dark", "#2E3545", "Metal", roughness=0.35, metallic=0.84)
    mat_steel = K.make_material("Wing_Steel", "#9AA4B4", "Metal", roughness=0.28, metallic=0.88)
    mat_neon = K.make_material("Wing_Neon", "#3FE0F2", "Neon", roughness=0.2, emission_strength=3.2)
    K.add_chain(coll, "DashWing", mat_steel, bottom_z=-0.106)

    bm = bmesh.new()
    # Forged dark-steel leading spar centered cleanly at (0,0) top root
    spar = [(-0.022, -0.138), (0.022, -0.138), (-0.055, -0.285), (-0.088, -0.355), (-0.092, -0.270)]
    K.add_layered_prism_y(bm, spar, y_half=0.018, cham_y=0.004, cham_in=0.10, mat_idx=0, center_xz=(-0.036, -0.23))
    # Machined steel root mounting cuff hugging the top spar cleanly under X=0
    K.add_prism_z(bm, K.cham_rect_pts(0, 0, 0.026, 0.021, 0.006), -0.158, -0.134, mat_idx=1)
    K.add_frustum_z(bm, K.cham_rect_pts(0, 0, 0.022, 0.016, 0.005), -0.140, K.cham_rect_pts(0, 0, 0.016, 0.012, 0.004), -0.122, mat_idx=1)
    K.add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=1)
    K.bm_to_object("DashWing_Body", bm, [mat_dark, mat_steel], coll, union=True)

    # 3 swept cyan faceted feather blades seated cleanly into the spar (separate Neon object)
    bm_neon = bmesh.new()
    feathers = [
        [(-0.010, -0.175), (0.105, -0.205), (0.075, -0.238), (-0.028, -0.215)],
        [(-0.028, -0.220), (0.085, -0.258), (0.052, -0.292), (-0.048, -0.262)],
        [(-0.048, -0.268), (0.056, -0.310), (0.024, -0.342), (-0.068, -0.312)],
    ]
    for fpoly in feathers:
        K.add_prism_y(bm_neon, fpoly, -0.011, 0.011, mat_idx=0)
    K.bm_to_object("DashWing_Neon", bm_neon, [mat_neon], coll, union=False)


def build_FrostCrystal(coll):
    mat_ice = K.make_material("Frost_Ice", "#88E6FF", "SmoothPlastic", roughness=0.14, alpha=0.66, rbx_transparency=0.28)
    mat_neon = K.make_material("Frost_Neon", "#B5F5FF", "Neon", roughness=0.2, emission_strength=3.0)
    mat_chain = K.make_material("Chain_Metal", "#9AA4B4", "Metal", roughness=0.28, metallic=0.85)
    K.add_chain(coll, "FrostCrystal", mat_chain, bottom_z=-0.106)

    bm = bmesh.new()
    # 3 tightly clustered pointed ice spires emerging seamlessly from a slim crown socket
    spires = [
        (0.0, 0.0, -0.156, -0.392, 0.036, 0.0),
        (-0.028, 0.003, -0.166, -0.334, 0.025, math.radians(-20)),
        (0.028, -0.003, -0.166, -0.322, 0.024, math.radians(20)),
    ]
    for sx, sy, z0, z1, rad, tilt in spires:
        xf = Matrix.Translation((sx, sy, z0)) @ Matrix.Rotation(tilt, 4, "Y")
        dz = z1 - z0
        K.add_frustum_z(bm, K.ngon_pts(0, 0, rad, 6), 0.0, K.ngon_pts(0, 0, rad * 0.85, 6), dz * 0.70, mat_idx=0, xform=xf)
        K.add_frustum_z(bm, K.ngon_pts(0, 0, rad * 0.85, 6), dz * 0.68, K.ngon_pts(0, 0, 0.004, 6), dz, mat_idx=0, xform=xf)
    K.bm_to_object("FrostCrystal_Body", bm, [mat_ice], coll, union=True)

    # Slim faceted metallic crown ferrule + 3 tapered claw tabs hugging the crystal shoulders cleanly
    bm_cap = bmesh.new()
    K.add_frustum_z(bm_cap, K.ngon_pts(0, 0, 0.048, 6, math.pi / 6), -0.172, K.ngon_pts(0, 0, 0.022, 6, math.pi / 6), -0.124, mat_idx=0)
    for ang in (0.0, 2 * math.pi / 3, 4 * math.pi / 3):
        xf_c = Matrix.Rotation(ang, 4, "Z") @ Matrix.Translation((0.038, 0.0, -0.168)) @ Matrix.Rotation(math.radians(-16), 4, "Y")
        K.add_frustum_z(bm_cap, K.cham_rect_pts(0, 0, 0.006, 0.011, 0.002), -0.036, K.cham_rect_pts(0, 0, 0.008, 0.013, 0.002), 0.012, mat_idx=0, xform=xf_c)
    K.add_eyelet(bm_cap, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=0)
    K.bm_to_object("FrostCrystal_Clasp", bm_cap, [mat_chain], coll, union=True)

    bm_neon = bmesh.new()
    K.add_faceted_gem(bm_neon, Vector((0, 0, -0.255)), 0.022, 0.022, 0.052, n_sides=6, mat_idx=0)
    K.bm_to_object("FrostCrystal_Neon", bm_neon, [mat_neon], coll, union=False)


def build_ClockworkGear(coll):
    mat_brass = K.make_material("Gear_Brass", "#EBB842", "Metal", roughness=0.25, metallic=0.90)
    mat_slate = K.make_material("Gear_Slate", "#363E50", "Metal", roughness=0.36, metallic=0.82)
    mat_chain = K.make_material("Chain_Metal", "#9AA4B4", "Metal", roughness=0.28, metallic=0.85)
    K.add_chain(coll, "ClockworkGear", mat_chain, bottom_z=-0.106)

    cz = -0.245
    bm = bmesh.new()
    K.add_ring_y(bm, 0.0, cz, r_in=0.082, r_out=0.108, n=8, y_half=0.022, cham=0.004, rot=math.pi / 8, mat_idx=0)
    K.add_box(bm, -0.090, 0.090, 0.006, 0.022, cz - 0.010, cz + 0.010, mat_idx=0)
    K.add_frustum_z(bm, K.cham_rect_pts(0, 0, 0.022, 0.016, 0.005), -0.145, K.cham_rect_pts(0, 0, 0.017, 0.013, 0.004), -0.122, mat_idx=1)
    K.add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=1)
    K.bm_to_object("ClockworkGear_Body", bm, [mat_slate, mat_chain], coll, union=True)

    # Single-contour 8-tooth brass gear wheel (no boolean union splits -> ~130 tris, total <= 550!)
    bm_wheel = bmesh.new()
    gear_pts = []
    r_root, r_tip = 0.048, 0.074
    for k in range(8):
        a0 = k * math.pi / 4
        gear_pts.append((r_root * math.cos(a0 - 0.22), cz + r_root * math.sin(a0 - 0.22)))
        gear_pts.append((r_tip * math.cos(a0 - 0.11), cz + r_tip * math.sin(a0 - 0.11)))
        gear_pts.append((r_tip * math.cos(a0 + 0.11), cz + r_tip * math.sin(a0 + 0.11)))
        gear_pts.append((r_root * math.cos(a0 + 0.22), cz + r_root * math.sin(a0 + 0.22)))
    K.add_prism_y(bm_wheel, gear_pts, -0.013, 0.013, mat_idx=0)
    # Center axle cap
    K.add_prism_y(bm_wheel, K.ngon_pts(0, cz, 0.020, 6), -0.020, 0.020, mat_idx=0)
    K.bm_to_object("ClockworkGear_Wheel", bm_wheel, [mat_brass], coll, union=True, origin=Vector((0.0, 0.0, cz)))


def build_MiniTsuba(coll):
    mat_dark = K.make_material("Hilt_Dark", "#2C3344", "SmoothPlastic", roughness=0.42)
    mat_steel = K.make_material("Hilt_Steel", "#A6B0C2", "Metal", roughness=0.26, metallic=0.90)
    mat_neon = K.make_material("Hilt_Neon", "#48D8FF", "Neon", roughness=0.2, emission_strength=3.2)
    K.add_chain(coll, "MiniTsuba", mat_steel, bottom_z=-0.106)

    bm = bmesh.new()
    # Pommel cap -> faceted wrapped grip -> notched octagonal tsuba guard -> short tapered blade stub
    K.add_frustum_z(bm, K.cham_rect_pts(0, 0, 0.024, 0.018, 0.006), -0.158, K.cham_rect_pts(0, 0, 0.017, 0.013, 0.004), -0.124, mat_idx=1)
    K.add_prism_z(bm, K.cham_rect_pts(0, 0, 0.021, 0.016, 0.006), -0.258, -0.154, mat_idx=0)
    # Notched octagonal tsuba guard
    K.add_frustum_z(bm, K.ngon_pts(0, 0, 0.068, 8, math.pi / 8), -0.278, K.ngon_pts(0, 0, 0.074, 8, math.pi / 8), -0.256, mat_idx=1)
    # Short faceted katana stub below guard (angled chisel end, no blunt cutoff!)
    blade = [(-0.018, -0.274), (0.018, -0.274), (0.018, -0.342), (-0.002, -0.376), (-0.018, -0.352)]
    K.add_layered_prism_y(bm, blade, y_half=0.010, cham_y=0.005, cham_in=0.35, mat_idx=1, center_xz=(0.0, -0.32))
    K.add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=1)
    K.bm_to_object("MiniTsuba_Body", bm, [mat_dark, mat_steel], coll, union=True)

    # Separate Neon cyan diamond wrap pips along front & back of grip
    bm_neon = bmesh.new()
    for gz in (-0.178, -0.206, -0.234):
        K.add_prism_y(bm_neon, K.ngon_pts(0, gz, 0.012, 4), -0.020, 0.020, mat_idx=0)
    K.bm_to_object("MiniTsuba_Neon", bm_neon, [mat_neon], coll, union=False)


def build_PlasmaPrism(coll):
    mat_dark = K.make_material("Rift_Dark", "#2C3242", "Metal", roughness=0.35, metallic=0.84)
    mat_steel = K.make_material("Rift_Steel", "#9AA4B4", "Metal", roughness=0.28, metallic=0.88)
    mat_neon = K.make_material("Rift_Neon", "#C84BFF", "Neon", roughness=0.2, emission_strength=3.8)
    K.add_chain(coll, "PlasmaPrism", mat_steel, bottom_z=-0.106)

    cz = -0.268
    bm_neon = bmesh.new()
    # Align 6-sided gem facets (rot=pi/6) symmetrically with the 3 outer magnetic claws!
    K.add_faceted_gem(bm_neon, Vector((0, 0, cz)), 0.048, 0.048, 0.088, n_sides=6, mat_idx=0)
    K.bm_to_object("PlasmaPrism_Neon", bm_neon, [mat_neon], coll, union=False)

    bm = bmesh.new()
    # Chamfered top crown + 3 forged magnetic claws with chamfered elbow collars
    K.add_frustum_z(bm, K.ngon_pts(0, 0, 0.052, 6, math.pi / 6), -0.172, K.ngon_pts(0, 0, 0.024, 6, math.pi / 6), -0.124, mat_idx=1)
    for k in range(3):
        rot = Matrix.Rotation(math.pi / 6 + k * 2 * math.pi / 3, 4, "Z")
        claw = [(0.026, -0.156), (0.046, -0.156), (0.094, -0.245), (0.068, -0.348),
                (0.056, -0.340), (0.074, -0.248), (0.034, -0.173)]
        K.add_prism_y(bm, claw, -0.011, 0.011, mat_idx=0, xform=rot)
        K.add_prism_z(bm, K.cham_rect_pts(0.086, 0, 0.014, 0.013, 0.004), -0.256, -0.234, mat_idx=1, xform=rot)
    K.add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=1)
    K.bm_to_object("PlasmaPrism_Body", bm, [mat_dark, mat_steel], coll, union=True)


def build_PhantomLantern(coll):
    mat_dark = K.make_material("Lantern_Dark", "#252B38", "Metal", roughness=0.38, metallic=0.82)
    mat_trim = K.make_material("Lantern_Trim", "#8692A6", "Metal", roughness=0.28, metallic=0.88)
    mat_neon = K.make_material("Mist_Neon", "#5DE4CC", "Neon", roughness=0.2, emission_strength=3.5)
    K.add_chain(coll, "PhantomLantern", mat_trim, bottom_z=-0.106)

    cz = -0.258
    bm_neon = bmesh.new()
    K.add_faceted_gem(bm_neon, Vector((0, 0, cz)), 0.045, 0.045, 0.064, n_sides=4, mat_idx=0)
    K.bm_to_object("PhantomLantern_Neon", bm_neon, [mat_neon], coll, union=False)

    bm = bmesh.new()
    # Stepped angular lantern roof hood + eaves trim collar + top pagoda cap + bottom plinth + 4 tapered corner pillars
    rot = math.pi / 4
    K.add_frustum_z(bm, K.ngon_pts(0, 0, 0.092, 4, rot), -0.186, K.ngon_pts(0, 0, 0.086, 4, rot), -0.174, mat_idx=1)
    K.add_frustum_z(bm, K.ngon_pts(0, 0, 0.086, 4, rot), -0.176, K.ngon_pts(0, 0, 0.030, 4, rot), -0.128, mat_idx=0)
    K.add_frustum_z(bm, K.ngon_pts(0, 0, 0.024, 4, rot), -0.132, K.ngon_pts(0, 0, 0.017, 4, rot), -0.122, mat_idx=1)
    K.add_frustum_z(bm, K.ngon_pts(0, 0, 0.084, 4, rot), -0.338, K.ngon_pts(0, 0, 0.086, 4, rot), -0.328, mat_idx=1)
    K.add_frustum_z(bm, K.ngon_pts(0, 0, 0.012, 4, rot), -0.386, K.ngon_pts(0, 0, 0.084, 4, rot), -0.336, mat_idx=0)
    for k in range(4):
        a = rot + k * math.pi / 2
        px, py = 0.064 * math.cos(a), 0.064 * math.sin(a)
        K.add_frustum_z(bm, K.ngon_pts(px, py, 0.011, 4, rot), -0.334, K.ngon_pts(px, py, 0.012, 4, rot), -0.180, mat_idx=1)
    K.add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=1)
    K.bm_to_object("PhantomLantern_Body", bm, [mat_dark, mat_trim], coll, union=True)


def build_ReactorCore(coll):
    mat_dark = K.make_material("Core_Dark", "#2E3546", "Metal", roughness=0.34, metallic=0.84)
    mat_gold = K.make_material("Core_Gold", "#F5BE38", "Metal", roughness=0.24, metallic=0.92)
    mat_neon = K.make_material("Core_Neon", "#3FE0F2", "Neon", roughness=0.2, emission_strength=3.8)
    K.add_chain(coll, "ReactorCore", mat_gold, bottom_z=-0.106)

    cz = -0.252
    bm = bmesh.new()
    # Outer dark octagonal armored housing ring + gold mounting lugs
    K.add_ring_y(bm, 0.0, cz, r_in=0.088, r_out=0.114, n=8, y_half=0.022, cham=0.004, rot=math.pi / 8, mat_idx=0)
    for sx in (-1, 1):
        K.add_box(bm, sx * 0.085, sx * 0.120, -0.016, 0.016, cz - 0.014, cz + 0.014, mat_idx=1)
    K.add_frustum_z(bm, K.cham_rect_pts(0, 0, 0.024, 0.018, 0.005), -0.150, K.cham_rect_pts(0, 0, 0.018, 0.014, 0.004), -0.124, mat_idx=1)
    K.add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=1)
    K.bm_to_object("ReactorCore_Body", bm, [mat_dark, mat_gold], coll, union=True)

    # Separate rotatable inner faceted gold gyro ring (origin at center)
    bm_ring = bmesh.new()
    K.add_ring_y(bm_ring, 0.0, cz, r_in=0.056, r_out=0.076, n=8, y_half=0.016, cham=0.003, rot=0.0, mat_idx=0)
    # Tilt slightly around Z+X in local coords so it reads as a 3D gyro gimbal!
    tilt = Matrix.Translation((0, 0, cz)) @ Euler((math.radians(24), math.radians(-18), 0), "XYZ").to_matrix().to_4x4() @ Matrix.Translation((0, 0, -cz))
    bmesh.ops.transform(bm_ring, matrix=tilt, verts=bm_ring.verts)
    K.bm_to_object("ReactorCore_Ring", bm_ring, [mat_gold], coll, union=False, origin=Vector((0.0, 0.0, cz)))

    # Glowing Neon crystal heart
    bm_neon = bmesh.new()
    K.add_faceted_gem(bm_neon, Vector((0, 0, cz)), 0.042, 0.042, 0.048, n_sides=6, mat_idx=0)
    K.bm_to_object("ReactorCore_Neon", bm_neon, [mat_neon], coll, union=False)


def build_KillRadar(coll):
    mat_body = K.make_material("Radar_Body", "#3C4558", "SmoothPlastic", roughness=0.40)
    mat_gold = K.make_material("Radar_Gold", "#F2BE38", "Metal", roughness=0.25, metallic=0.90)
    mat_neon = K.make_material("Radar_Neon", "#3CFF9E", "Neon", roughness=0.2, emission_strength=3.2)
    K.add_chain(coll, "KillRadar", mat_gold, bottom_z=-0.106)

    cz = -0.258
    bm = bmesh.new()
    # Octagonal chamfered tactical radar housing + side armor brackets + top gold antenna stub
    K.add_layered_prism_y(bm, K.ngon_pts(0, cz, 0.106, 8, math.pi / 8), y_half=0.028, cham_y=0.006, cham_in=0.08, mat_idx=0, center_xz=(0.0, cz))
    # Proud front bezel ring around the octagonal screen
    K.add_ring_y(bm, 0.0, cz, r_in=0.072, r_out=0.094, n=8, y_half=0.035, cham=0.003, rot=math.pi / 8, mat_idx=0)
    for sx in (-1, 1):
        K.add_box(bm, sx * 0.088, sx * 0.114, -0.020, 0.020, cz - 0.032, cz + 0.032, mat_idx=1)
    # Top antenna stub + collar + eyelet
    K.add_frustum_z(bm, K.cham_rect_pts(0, 0, 0.024, 0.018, 0.005), -0.162, K.cham_rect_pts(0, 0, 0.017, 0.013, 0.004), -0.124, mat_idx=1)
    K.add_eyelet(bm, z_top=-0.094, z_bot=-0.134, half_w=0.0145, tube_r=0.0052, mat_idx=1)
    K.bm_to_object("KillRadar_Body", bm, [mat_body, mat_gold], coll, union=True)

    # Flat unobstructed screen face for SurfaceGui sweeping radar + kill ping
    bm_scr = bmesh.new()
    K.add_prism_y(bm_scr, K.ngon_pts(0, cz, 0.074, 8, math.pi / 8), -0.030, -0.020, mat_idx=0)
    K.bm_to_object("KillRadar_Screen", bm_scr, [mat_body], coll, union=False)

    # Separate emerald Neon status pip on top bezel + antenna beacon tip
    bm_neon = bmesh.new()
    K.add_box(bm_neon, -0.016, 0.016, -0.038, -0.028, cz + 0.076, cz + 0.088, mat_idx=0)
    K.add_box(bm_neon, 0.052, 0.068, -0.038, -0.028, cz + 0.044, cz + 0.056, mat_idx=0)
    K.bm_to_object("KillRadar_Neon", bm_neon, [mat_neon], coll, union=False)


OVERDRIVE_BUILDERS = {
    "HazardSign": build_HazardSign,
    "BatteryCell": build_BatteryCell,
    "CompassRose": build_CompassRose,
    "Keycard": build_Keycard,
    "DashWing": build_DashWing,
    "FrostCrystal": build_FrostCrystal,
    "ClockworkGear": build_ClockworkGear,
    "MiniTsuba": build_MiniTsuba,
    "PlasmaPrism": build_PlasmaPrism,
    "PhantomLantern": build_PhantomLantern,
    "ReactorCore": build_ReactorCore,
    "KillRadar": build_KillRadar,
}

try:
    result = {"ok": True, "report": K.build_and_render_set(OVERDRIVE_BUILDERS, OVERDRIVE_ORDER)}
except Exception as e:
    result = {"ok": False, "error": str(e), "traceback": traceback.format_exc()}
