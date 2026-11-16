# anim_outlaw_v2.py: Outlaw v02 reloads (Blender MCP only). The user's call (2026-11-08): the break-action opens
# further and the shooter picks the spent rounds out and loads new ones by hand.
#   Reload       (one round, upper barrel; plays over Weapons.Outlaw.reloadTime 2.3 s)  60 frames
#   ReloadEmpty  (both rounds; plays over emptyReloadTime 3.8 s, used when the gun has the clip)  92 frames
# Bones are bone-local: Barrels rotation y + tips the muzzles down about the hinge; a round's x - pulls it out of its
# chamber along the (tipped) barrel axis, z - is away from the rib side. A round is pulled out, then taken
# toward the shooter's lower left (out of frame: the hand takes it); the fresh one comes back from there, lines up
# behind the chamber, then is pushed home.
# Fire, Draw and Inspect are the original clips (anim_copy).

import bpy, math

ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2"
OPEN = 1.25  # rad, ~72 deg (the original opened 0.80)


def _load(name):
	ns = {}
	p = ROOT + "/_Library/" + name
	exec(compile(open(p).read(), p, "exec"), ns)
	return ns


def round_out_in(t_pop, t_swing, t_pull, t_gone, t_new, t_line, t_swing_in, t_home, pop=-0.08, yaw=0.55, out=0.3):
	# One round. The scope sits over the breech and the hinge is close under the lower barrel, so a long round can't
	# come straight out: the ejector pops it, it swings sideways about the chamber mouth (head to gun-left), then
	# slides out along that line, clear of the receiver, and the hand takes it away (out of frame, lower left).
	# The fresh round reverses the path: lined up at the mouth at the same angle, swung straight, pushed home.
	m = -pop
	sw = (pop + m * (1 - math.cos(yaw)), m * math.sin(yaw), 0.0)
	pl = (sw[0] - out * math.cos(yaw), sw[1] + out * math.sin(yaw), 0.0)
	r_sw = (0.0, 0.0, -yaw)
	loc = [(1, (0, 0, 0)), (t_pop - 3, (0, 0, 0)), (t_pop, (pop, 0, 0)), (t_swing, sw), (t_pull, pl), (t_gone, (-0.6, 0.6, -1.7)),
		(t_new, (-0.7, 0.5, -1.6)), (t_line - 2, (pl[0] - 0.06, pl[1] + 0.16, -0.06)), (t_line, pl), (t_swing_in, sw), (t_home - 2, (pop * 0.5, 0, 0)), (t_home, (0, 0, 0))]
	rot = [(1, (0, 0, 0)), (t_pop, (0, 0, 0)), (t_swing, r_sw), (t_pull, r_sw), (t_gone, (0.5, -0.7, 0.3)), (t_new, (-0.3, 0.9, -0.2)),
		(t_line, r_sw), (t_swing_in, r_sw), (t_home - 2, (0, 0, 0)), (t_home, (0, 0, 0))]
	return {"loc": loc, "rot": rot}


def gun_moves(t_open, t_close, end):
	latch = {"loc": [(1, (0, 0, 0)), (t_open - 4, (0, 0, 0)), (t_open - 1, (0.02, 0, 0)), (t_close - 1, (0.02, 0, 0)), (t_close + 2, (0, 0, 0))],
		"rot": [(1, (0, 0, 0)), (t_open - 4, (0, 0, 0)), (t_open - 1, (0.2094, 0, 0)), (t_close - 1, (0.2094, 0, 0)), (t_close + 2, (0, 0, 0))]}
	barrels = {"rot": [(1, (0, 0, 0)), (t_open, (0, 0, 0)), (t_open + 6, (0, OPEN, 0)), (t_open + 8, (0, OPEN - 0.03, 0)), (t_open + 10, (0, OPEN, 0)),
		(t_close - 4, (0, OPEN, 0)), (t_close, (0, 0, 0)), (t_close + 2, (0, 0.012, 0)), (t_close + 4, (0, 0, 0))]}  # shuts, tiny bounce off the face
	root = {"loc": [(1, (0, 0, 0)), (t_open, (0, 0, 0.005)), (t_open + 9, (0, 0, 0.024)), (t_close - 5, (0, 0, 0.024)),
		(t_close, (0.014, 0, 0.012)), (t_close + 4, (0, 0, 0.004)), (end - 4, (0, 0, 0)), (end, (0, 0, 0))],
		"rot": [(1, (0, 0, 0)), (t_open, (0.07, 0.05, -0.035)), (t_open + 9, (0.19, 0.17, -0.09)), (t_close - 5, (0.17, 0.15, -0.09)),
		(t_close, (0.1, -0.06, -0.05)), (t_close + 4, (0.035, 0.01, -0.017)), (end - 4, (0, 0, 0)), (end, (0, 0, 0))]}
	return latch, barrels, root


def build():
	an = _load("anim_copy.py")
	au = _load("anim_author.py")
	keep = [n for n in ("Fire", "Draw", "Inspect") if bpy.data.actions.get("REF_Outlaw_" + n)]
	out = {"copied": an["apply"]("Outlaw", keep)}

	# Reload: upper round only.
	latch, barrels, root = gun_moves(6, 50, 60)
	tracks = {"BreechLatch": latch, "Barrels": barrels, "Root": root,
		"RoundUpper": round_out_in(17, 20, 23, 27, 31, 35, 38, 42),
		"Charm": {"rot": au["sway"]([(14, 1.0), (22, 0.6), (50, 1.2)])}}
	out["Reload"] = au["author"]("Outlaw", "Reload", 60, tracks, markers={"Open": 14, "RoundOut": 21, "RoundIn": 41, "Close": 50})

	# ReloadEmpty: both rounds pop together, picked out one at a time, two fresh rounds loaded upper then lower.
	latch, barrels, root = gun_moves(6, 78, 92)
	up = round_out_in(17, 20, 23, 27, 38, 42, 45, 49)
	lo = round_out_in(17, 27, 30, 34, 54, 58, 61, 65, pop=-0.035, yaw=0.62)
	tracks = {"BreechLatch": latch, "Barrels": barrels, "Root": root, "RoundUpper": up, "RoundLower": lo,
		"Charm": {"rot": au["sway"]([(14, 1.0), (23, 0.5), (31, 0.5), (78, 1.2)])}}
	out["ReloadEmpty"] = au["author"]("Outlaw", "ReloadEmpty", 92, tracks, markers={"Open": 14, "RoundOut": 22, "RoundIn": 66, "Close": 78})
	return out


RESULT = build()
