"""Spectre's compact Slipframe shell, long faceted suppressor and canted stock."""

from pathlib import Path

GUN = "Spectre"
VERSION = globals().get("VERSION", "r01")
exec(Path("tools/blender/rework_slipframe/roster_lib.py").read_text(encoding="utf-8"))

replace("Handguard", "Suppressor", "Neon", "Pins", "Stock")
dress("Receiver")
dress("Grip", slots={"Body": GRIP, "Dark": GRIP})
dress("Sights", slots={"Body": FRAME, "Metal": SHELL})
for name in ("Bolt", "CharmLoop", "Trigger"):
    dress(name)


def carrier_foot(point):
    if point.y < 0.075:
        point.y -= 0.001


def mag_heel(point):
    if point.z > 0.04 and abs(point.y) > 0.052:
        point.y += math.copysign(0.0032, point.y)
    if point.z < -0.40:
        point.x += (-0.40 - point.z) * 0.24


def selector_seat(point):
    if point.y < 0.085 and point.x > 0.19:
        point.x += 0.0029
        point.z -= 0.0028


dress("ChargingHandle", shape=carrier_foot, slots={"Metal": FRAME})
dress("Mag", slots={"Panel": FACE, "Accent": SHELL}, shape=mag_heel)
dress("FireSelector", shape=selector_seat)

receiver = folded("SF_ReceiverMantle", (
    (-0.315, 0.263, 0.425, 0.071, 0.405, 0.281, 0.046),
    (-0.264, 0.260, 0.452, 0.087, 0.427, 0.297, 0.047),
    (0.108, 0.264, 0.452, 0.087, 0.427, 0.297, 0.047),
    (0.261, 0.263, 0.447, 0.086, 0.426, 0.292, 0.046),
    (0.541, 0.264, 0.447, 0.089, 0.425, 0.301, 0.046),
    (0.670, 0.303, 0.453, 0.089, 0.425, 0.333, 0.052),
    (0.736, 0.337, 0.458, 0.076, 0.434, 0.352, 0.043),
), SHELL)
recess(receiver, "SF_CarrierClearance_Left", [
    (0.129, 0.318), (0.179, 0.313), (0.820, 0.313), (0.820, 0.414), (0.149, 0.414),
], 0.065, 0.16)
recess(receiver, "SF_EjectionClearance_Right", [
    (0.104, 0.343), (0.140, 0.340), (0.492, 0.345), (0.510, 0.430), (0.471, 0.439),
    (0.142, 0.439), (0.104, 0.419),
], -0.053, -0.16)
seat = [(-0.232, 0.346), (-0.193, 0.404), (0.102, 0.404), (0.079, 0.346)]
recess(receiver, "SF_ReceiverInsertSeat_Left", seat, 0.076, 0.13)
slide = side("SF_InspectSlidingPanel_Left", [(-0.217, 0.355), (-0.185, 0.393),
             (0.089, 0.393), (0.073, 0.360)], 0.073, 0.084, FACE, bevel=0.0012)
slide["flat_group"] = "SFInspectPanel"
inlay = side("SF_SeamInlay_Left", [(-0.200, 0.350), (-0.178, 0.355), (0.065, 0.354), (0.058, 0.350)],
             0.074, 0.081, SEAM, bevel=0.0005)
inlay["flat_group"] = "SFSeam"
recess(receiver, "SF_ServiceSeat_Right", seat, -0.076, -0.13)
side("SF_ServicePanel_Right", [(-0.217, 0.354), (-0.185, 0.392), (0.087, 0.392), (0.071, 0.355)],
     -0.073, -0.084, FACE, bevel=0.0012)

fore = folded("SF_ForeEnd", (
    (0.659, 0.275, 0.440, 0.074, 0.408, 0.297, 0.044),
    (0.727, 0.233, 0.469, 0.092, 0.432, 0.285, 0.056),
    (0.988, 0.229, 0.473, 0.092, 0.432, 0.281, 0.056),
    (1.070, 0.233, 0.473, 0.092, 0.432, 0.288, 0.052),
    (1.151, 0.274, 0.450, 0.069, 0.423, 0.301, 0.040),
    (1.189, 0.292, 0.414, 0.055, 0.398, 0.310, 0.030),
), [FRAME, SHELL, SHELL, SHELL, FRAME])
recess(fore, "SF_FrontCarrierClearance", [
    (0.635, 0.313), (0.707, 0.312), (0.723, 0.335), (0.723, 0.417), (0.634, 0.417),
], 0.065, 0.16)
paired_faces(fore, "ForeEndPanel", [(0.743, 0.337), (0.790, 0.410), (1.096, 0.410), (1.060, 0.322), (0.747, 0.315)],
             [(0.755, 0.340), (0.798, 0.401), (1.080, 0.401), (1.050, 0.332), (0.757, 0.327)],
             0.072, 0.069, 0.086)
for sign, label in ((1, "Left"), (-1, "Right")):
    recess(fore, f"SF_LowerRelief_{label}", [(0.786, 0.294), (0.809, 0.308), (1.027, 0.308), (1.006, 0.294)],
           0.073 * sign, 0.15 * sign)

stock = side("SF_StockFrame", [
    (-0.970, 0.381), (-0.478, 0.388), (-0.359, 0.402), (-0.293, 0.365),
    (-0.296, 0.291), (-0.419, 0.258), (-0.598, 0.180), (-0.904, -0.085), (-0.972, -0.113),
], -0.062, 0.062, SHELL, bevel=0.006)
recess(stock, "SF_StockWindow", [
    (-0.901, 0.038), (-0.654, 0.233), (-0.465, 0.304), (-0.893, 0.286), (-0.908, 0.252),
], -0.11, 0.11)
side("SF_StockShoe", [
    (-1.067, 0.366), (-1.045, 0.399), (-0.948, 0.397), (-0.935, 0.354),
    (-0.944, -0.094), (-0.984, -0.117), (-1.044, -0.105), (-1.066, -0.071),
], -0.073, 0.073, GRIP, bevel=0.008)

folded("SF_Suppressor", (
    (1.129, 0.302, 0.406, 0.056, 0.389, 0.319, 0.038),
    (1.218, 0.288, 0.422, 0.067, 0.403, 0.308, 0.041),
    (1.273, 0.263, 0.441, 0.089, 0.419, 0.292, 0.059),
    (1.351, 0.260, 0.443, 0.091, 0.419, 0.289, 0.058),
    (1.400, 0.271, 0.432, 0.084, 0.409, 0.299, 0.057),
    (1.812, 0.271, 0.432, 0.084, 0.411, 0.298, 0.057),
    (1.859, 0.262, 0.441, 0.090, 0.418, 0.291, 0.060),
    (1.9012, 0.285, 0.422, 0.071, 0.405, 0.308, 0.048),
    (1.9012, 0.325, 0.380, 0.027, 0.371, 0.333, 0.018),
    (1.268, 0.326, 0.379, 0.025, 0.370, 0.335, 0.017),
    (1.129, 0.326, 0.379, 0.025, 0.370, 0.335, 0.017),
), [FRAME, SHELL, SHELL, FRAME, FRAME, FRAME, SHELL, SHELL, FRAME, FRAME, FRAME], loop=True)

result = finish_master(fore)
