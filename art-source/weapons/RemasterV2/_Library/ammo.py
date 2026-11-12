# ammo.py: RemasterV2 cartridges, one shape per ammo family so every gun loads rounds that read as its own.
# Each builder returns a closed bmesh lathed along +X from the case head (x0) forward, centred on (y, z).
# dir=-1 builds it pointing -X (head at x0, nose toward -X).
# Families (sizes in studs, chosen so the round fills its chamber and reads at viewmodel distance):
#   sniper_round   long bottleneck case, rebated rim, long ogive (Outlaw, Operator, Marshal)   ~0.45 long
#   rifle_round    intermediate bottleneck (rifles, MGs)                                          ~0.24 long
#   pistol_round   straight case, round nose (pistols, SMGs, revolver)                           ~0.11 long
#   shotgun_shell  steel-blue hull, high brass head, rolled crimp (Shorty, Bucky, Judge)          ~0.20 long
# Materials: Brass case/head (new role), Metal projectile, Accent shell hull, Dark primer pocket.

import math
import bmesh
import v2kit as K


def lathe(x0, prof, y=0.0, z=0.0, segs=8, rot=None, sign=1):
	# prof: [(dx, r, mat)] from the head forward; r == 0 makes a single apex vertex. The band between point i and
	# i+1 takes point i's material. Closed when the first and last points are apexes.
	rot = math.pi / segs if rot is None else rot
	bm = bmesh.new()
	rings = []
	for dx, r, _m in prof:
		x = x0 + sign * dx
		if r <= 0:
			rings.append([bm.verts.new((x, y, z))])
		else:
			rings.append([bm.verts.new((x, y + r * math.cos(rot + 2 * math.pi * i / segs), z + r * math.sin(rot + 2 * math.pi * i / segs))) for i in range(segs)])
	for i in range(len(rings) - 1):
		a, b, m = rings[i], rings[i + 1], prof[i][2]
		for s in range(segs):
			t = (s + 1) % segs
			if len(a) == 1:
				vs = (a[0], b[t], b[s])
			elif len(b) == 1:
				vs = (a[s], a[t], b[0])
			else:
				vs = (a[s], a[t], b[t], b[s])
			f = bm.faces.new(vs)
			f.material_index = m
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return bm


def sniper_round(x0, y=0.0, z=0.0, scale=1.0, segs=8, sign=1):
	B_, M_, D_ = K.BRASS, K.METAL, K.DARK
	s = scale
	prof = [
		(0.003 * s, 0.0, D_), (0.0, 0.012 * s, B_),  # primer (recessed)
		(0.0, 0.041 * s, B_), (0.012 * s, 0.041 * s, B_),  # rim
		(0.016 * s, 0.034 * s, B_), (0.024 * s, 0.038 * s, B_),  # extractor groove, case body
		(0.27 * s, 0.036 * s, B_), (0.305 * s, 0.024 * s, B_),  # body taper, shoulder
		(0.34 * s, 0.023 * s, M_),  # neck mouth -> projectile
		(0.345 * s, 0.021 * s, M_), (0.405 * s, 0.013 * s, M_), (0.45 * s, 0.0, M_),
	]
	return lathe(x0, prof, y, z, segs, sign=sign)


def rifle_round(x0, y=0.0, z=0.0, scale=1.0, segs=6, sign=1):
	B_, M_ = K.BRASS, K.METAL
	s = scale
	prof = [
		(0.0, 0.0, B_), (0.0, 0.021 * s, B_), (0.008 * s, 0.021 * s, B_), (0.011 * s, 0.019 * s, B_),
		(0.14 * s, 0.018 * s, B_), (0.158 * s, 0.012 * s, M_), (0.165 * s, 0.011 * s, M_), (0.215 * s, 0.006 * s, M_), (0.24 * s, 0.0, M_),
	]
	return lathe(x0, prof, y, z, segs, sign=sign)


def pistol_round(x0, y=0.0, z=0.0, scale=1.0, segs=6, sign=1):
	B_, M_ = K.BRASS, K.METAL
	s = scale
	prof = [
		(0.0, 0.0, B_), (0.0, 0.017 * s, B_), (0.006 * s, 0.017 * s, B_), (0.008 * s, 0.016 * s, B_),
		(0.062 * s, 0.016 * s, M_), (0.08 * s, 0.014 * s, M_), (0.1 * s, 0.008 * s, M_), (0.11 * s, 0.0, M_),
	]
	return lathe(x0, prof, y, z, segs, sign=sign)


def shotgun_shell(x0, y=0.0, z=0.0, scale=1.0, segs=8, sign=1, length=0.2):
	B_, A_, D_ = K.BRASS, K.ACCENT, K.DARK
	s = scale
	L = length * s
	prof = [
		(0.002 * s, 0.0, D_), (0.0, 0.009 * s, B_),  # primer
		(0.0, 0.036 * s, B_), (0.008 * s, 0.036 * s, B_),  # rim
		(0.009 * s, 0.032 * s, B_), (0.05 * s, 0.032 * s, A_),  # high brass head -> hull
		(L - 0.008 * s, 0.032 * s, A_), (L, 0.027 * s, A_),  # rolled crimp
		(L - 0.006 * s, 0.0, A_),  # dished crimp face
	]
	return lathe(x0, prof, y, z, segs, sign=sign)
