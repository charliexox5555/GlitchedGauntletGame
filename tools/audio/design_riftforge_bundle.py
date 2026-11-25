"""Riftforge Legendary Bundle Audio Suite (Operator, Sheriff, Spectre, Shorty).

100% real licensed/CC0 recordings ONLY:
- ProPack weapon cores + Sonniss GDC 2016 Pole Position mics (Remington 700, S&W M66 .357,
  HK MP7, SAIGA-12, SPAS-12) + steel bulkhead sub-thump + CC0 Freesound electric, zap,
  crackle, stun, lightning, sword, slide-lock, latch & metal click.
- Exact voice-safe cut lengths on auto guns (Spectre 0.140s + dedicated tail).

    python -I tools/audio/design_riftforge_bundle.py
"""
import json
import os
import sys

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(__file__))
import build_gun_sfx as B  # noqa: E402
import design_tempest_vandal as V  # noqa: E402
import design_tempest_line as L  # noqa: E402
from build_sound_atlas import eq, hp, lp, resample, soft_clip  # noqa: E402

RATE = V.RATE
OUT = os.path.join(B.ROOT, "art-source", "audio", "riftforge", "bundle_v1")
os.makedirs(OUT, exist_ok=True)

THUMP = L.THUMP


def _bulkhead(k, pitch_base=0.80, lp_hz=185.0, length=0.24):
    x = L.gdc(THUMP)
    i = V.onset(x)
    y = x[max(i - int(0.001 * RATE), 0) : i + int(length * RATE)]
    p = pitch_base + 0.025 * (k % 3)
    y = lp(resample(y, 1.0 / p), lp_hz, 2)
    return B.fade(y, 0.0, min(0.10, len(y) / RATE * 0.45))


def _plasma_bite(k, length=0.22, pitch_scale=1.0, heavy=False):
    e_src = V.fs(V.ELECTRICITY)
    z_src = V.fs(V.ZAP_EGO if (heavy or k % 2 == 1) else V.ZAP)
    c_src = V.fs(V.CRACKLE)

    e_t = (0.14 + 0.48 * k) % max(0.2, len(e_src) / RATE - length - 0.1)
    e_c = V.seg(e_src, e_t, length, fin=0.0, fout=0.05, lo=1300 if heavy else 1600, hi=12500, pitch=pitch_scale * (0.94 + 0.04 * (k % 3)), rel=-22.0)

    z_t = (0.04 + 0.16 * (k % 4)) % max(0.15, len(z_src) / RATE - 0.25)
    z_c = V.seg(z_src, z_t, min(length, 0.20), fin=0.0, fout=0.05, lo=750 if heavy else 1000, hi=11500, pitch=pitch_scale * (0.86 + 0.04 * (k % 3)), rel=-22.0)

    c_t = (0.20 + 0.35 * k) % max(0.3, len(c_src) / RATE - length - 0.1)
    c_c = V.seg(c_src, c_t, length, fin=0.005, fout=0.06, lo=2000, hi=12800, pitch=pitch_scale * 1.04)

    m_src = V.fs(V.SWORD if k % 2 == 0 else V.SLIDE_LOCK)
    m_c = V.seg(m_src, 0.0, 0.11, fin=0.0, fout=0.04, lo=1200, hi=7500, pitch=pitch_scale * 0.78, rel=-20.0)

    mix = V.stack(
        length + 0.02,
        (0.0, V.norm(e_c, 0.0)),
        (0.002, V.norm(z_c, -1.5)),
        (0.005, V.norm(m_c, -6.5)),
        (0.012, V.norm(c_c, -7.0)),
    )[: int(length * RATE)]
    return B.fade(mix, 0.0, 0.04)


def _mono(x, target_db):
    y = B.master_tp(x, target_db)
    return y.mean(axis=1)


def _glue(x, target_db, low_boost=3.0, pres_boost=2.8, fout=0.16, cut=None):
    y = eq(
        x,
        [
            ("low", 110, low_boost),
            ("peak", 330, -1.4, 0.9),
            ("peak", 1800, 2.2, 0.8),
            ("peak", 5200, pres_boost, 0.85),
            ("high", 10500, 1.0),
        ],
    )
    y = soft_clip(y * 1.42, 0.92)
    if cut is not None:
        y = y[: int(cut * RATE)]
    y = B.fade(y, 0.0, fout)
    return _mono(y, target_db)


# 1. OPERATOR v2: Clean Supersonic Dark-Matter Railgun Sniper Cannon (ZERO mid-band bark!)
def make_op_shot_v2(k, far=False):
    length = 1.55
    # Crisp natural-pitch ProPack rifle core (notched at 500/850 Hz to kill boxy throat resonance!)
    core = V.pro(f"{L.RF}shot_0{(k % 4) + 1}")[: int(length * RATE)]
    core = eq(hp(core, 170, 2), [("peak", 500, -3.5, 1.0), ("peak", 850, -2.5, 1.1)])
    # Natural-pitch Remington 700 supersonic crack (NO pitch-down stretch!)
    r700 = L.gdc_shot("Remington_700_7.62x51mm_1m_right", k, 0.78, lo=110, hi=13500, pitch=0.99 - 0.02 * (k % 2))
    r700 = eq(r700, [("peak", 520, -4.5, 1.0), ("peak", 860, -3.0, 1.2)])
    # Tight seismic sub-120 Hz railgun punch (zero mid-mud!)
    sub = _bulkhead(k, pitch_base=0.66, lp_hz=120.0, length=0.34)
    # Razor high-voltage railgun plasma snap (>2.2 kHz ONLY — zero ZAP_EGO/SWORD bark!)
    e_src = V.fs(V.ELECTRICITY)
    e_t = (0.18 + 0.44 * k) % max(0.2, len(e_src) / RATE - 0.35)
    elec = V.seg(e_src, e_t, 0.26, fin=0.0, fout=0.07, lo=2200, hi=14000, pitch=1.08 + 0.04 * k, rel=-22.0)
    c_src = V.fs(V.CRACKLE)
    c_t = (0.22 + 0.37 * k) % max(0.3, len(c_src) / RATE - 0.45)
    crk = V.seg(c_src, c_t, 0.36, fin=0.004, fout=0.12, lo=2600, hi=14500, pitch=1.12 + 0.03 * k)
    st_src = V.fs(V.STUN)
    st_c = V.seg(st_src, 0.04 + 0.08 * (k % 3), 0.18, fin=0.002, fout=0.08, lo=1700, hi=10500, pitch=1.24 + 0.04 * k)
    # Rolling dark-matter lightning thunder tail (offset +18ms so supersonic crack hits razor-clean first!)
    lt_src = V.fs(V.LIGHTNING)
    lt_t = (0.12 + 0.33 * k) % max(0.2, len(lt_src) / RATE - 1.38)
    lt = V.seg(lt_src, lt_t, 1.32, fin=0.008, fout=0.45, lo=75, hi=9000, pitch=0.94)

    layers = [
        (0.000, V.norm(core, -2.5)),
        (0.000, V.norm(r700, -0.5)),
        (0.000, V.norm(sub, -3.5 if not far else -8.5)),
        (0.001, V.norm(elec, -1.5 if not far else -9.5)),
        (0.005, V.norm(st_c, -6.8 if not far else -13.5)),
        (0.010, V.norm(crk, -4.5 if not far else -11.5)),
        (0.018, V.norm(lt, -5.0 if not far else -8.5)),
    ]
    mix = V.stack(length, *layers)
    y = eq(
        mix,
        [
            ("low", 95, 2.2),
            ("peak", 500, -4.5, 1.0),
            ("peak", 860, -2.8, 1.2),
            ("peak", 3400, 3.2, 0.9),
            ("high", 7200, 2.8),
        ],
    )
    y = soft_clip(y * 1.22, 0.94)
    y = B.fade(y, 0.0, 0.28)
    return _mono(y, -9.0 if not far else -11.8)


def make_op_shot(k, far=False):
    return make_op_shot_v2(k, far=far)


def make_op_cycle():
    """Pressurized magnetic rail-shroud recoil vent + heavy lock slam (0.68s)."""
    length = 0.68
    l1 = V.seg(V.fs(V.LATCH), 0.0, 0.14, fin=0.0, fout=0.04, lo=550, hi=11500, pitch=0.82, rel=-22.0)
    st = V.seg(V.fs(V.STUN), 0.05, 0.34, fin=0.02, fout=0.12, lo=280, hi=7500, pitch=0.86)
    cr = V.seg(V.fs(V.CRACKLE), 0.10, 0.38, fin=0.02, fout=0.14, lo=1600, hi=12000, pitch=0.96)
    sl = V.seg(V.fs(V.SLIDE_LOCK), 0.0, 0.18, fin=0.0, fout=0.05, lo=500, hi=11500, pitch=0.78, rel=-22.0)
    sub = _bulkhead(1, pitch_base=0.86, lp_hz=210.0, length=0.16)
    mix = V.stack(
        length,
        (0.00, V.norm(l1, -2.0)),
        (0.04, V.norm(st, -4.0)),
        (0.06, V.norm(cr, -4.5)),
        (0.36, V.norm(sl, 0.0)),
        (0.37, V.norm(sub, -2.0)),
    )
    return _mono(B.fade(mix, 0.0, 0.10), -12.0)


# 2. SHERIFF: Heavy Reactor Revolver (iconic heavy one-tap punch!)
def make_sh_shot(k, far=False):
    length = 0.95
    core = V.pro(f"{L.R}shot_0{(k % 4) + 1}")[: int(length * RATE)]
    core = lp(core, 8000, 2)
    m66 = L.gdc_shot("Smith_&_Wesson_M66_.357_Magnum_1m_left", k, 0.45, lo=100, hi=10000, pitch=0.94 - 0.02 * (k % 2))
    sub = _bulkhead(k, pitch_base=0.82, lp_hz=180.0, length=0.22)
    bite = _plasma_bite(k, length=0.22, pitch_scale=1.04, heavy=True)
    ring = V.seg(V.fs(V.SWORD), 0.0, 0.24, fin=0.0, fout=0.10, lo=1400, hi=9500, pitch=1.12 + 0.04 * k, rel=-22.0)
    mix = V.stack(
        length,
        (0.0, V.norm(core, -2.5)),
        (0.0, V.norm(m66, -1.5)),
        (0.0, V.norm(sub, -2.0 if not far else -6.5)),
        (0.002, V.norm(bite, -1.5 if not far else -9.0)),
        (0.006, V.norm(ring, -6.0 if not far else -12.0)),
    )
    return _glue(mix, -9.8 if not far else -12.5, low_boost=3.2, pres_boost=3.2, fout=0.16)


def make_sh_open():
    length = 0.46
    l1 = V.seg(V.fs(V.LATCH), 0.0, 0.14, fin=0.0, fout=0.04, lo=700, hi=12000, pitch=1.08, rel=-22.0)
    mc = V.seg(V.fs(V.METAL_CLICK), 0.0, 0.10, fin=0.0, fout=0.03, lo=1000, hi=12500, pitch=1.18, rel=-22.0)
    el = V.seg(V.fs(V.ELECTRICITY), 0.12, 0.22, fin=0.01, fout=0.08, lo=1600, hi=12500, pitch=1.12, rel=-22.0)
    mix = V.stack(length, (0.00, V.norm(l1, -1.5)), (0.08, V.norm(mc, -2.0)), (0.06, V.norm(el, -4.0)))
    return _mono(B.fade(mix, 0.0, 0.08), -12.5)


def make_sh_close():
    length = 0.44
    sl = V.seg(V.fs(V.SLIDE_LOCK), 0.0, 0.16, fin=0.0, fout=0.04, lo=700, hi=12000, pitch=1.06, rel=-22.0)
    sub = _bulkhead(0, pitch_base=0.96, lp_hz=230.0, length=0.14)
    zp = V.seg(V.fs(V.ZAP), 0.0, 0.16, fin=0.0, fout=0.06, lo=1100, hi=12000, pitch=1.10, rel=-22.0)
    mix = V.stack(length, (0.00, V.norm(sl, 0.0)), (0.005, V.norm(sub, -2.5)), (0.01, V.norm(zp, -3.5)))
    return _mono(B.fade(mix, 0.0, 0.08), -12.0)


# 3. SPECTRE: Tight High-ROF Suppressed Plasma SMG (CUT = 0.140s!)
SP_CUT = 0.140


def make_sp_shot(k, first=False, last=False, far=False):
    full_len = 1.45 if last else 0.32
    base_name = f"{L.M}shot_00_first_01" if first else (f"{L.M}shot_00_last_with_tail_01" if last else f"{L.M}shot_0{(k % 9) + 1}")
    core = V.pro(base_name)[: int(full_len * RATE)]
    core = lp(core, 7400, 2)
    mp7_on = L.gdc_shot("HK_MP7_4.6mm_on_gun", k, 0.12, lo=950, hi=12500, pitch=1.04 - 0.02 * (k % 2))
    mp7_1m = L.gdc_shot("HK_MP7_4.6mm_1m_left", k, 0.22, lo=130, hi=8500, pitch=1.02 - 0.02 * (k % 3))
    sub = _bulkhead(k, pitch_base=0.92, lp_hz=195.0, length=0.16)
    bite = _plasma_bite(k, length=0.14, pitch_scale=1.14, heavy=False)

    layers = [
        (0.0, V.norm(core, -3.0)),
        (0.0, V.norm(mp7_1m, -2.0)),
        (0.001, V.norm(mp7_on, -4.5)),
        (0.0, V.norm(sub, -3.5 if not far else -8.0)),
        (0.001, V.norm(bite, -2.5 if not far else -9.5)),
    ]
    if last:
        cr = V.seg(V.fs(V.CRACKLE), 0.15, 0.72, fin=0.02, fout=0.25, lo=1800, hi=12000, pitch=1.16)
        layers.append((0.08, V.norm(cr, -8.5)))
    mix = V.stack(full_len, *layers)
    return _glue(
        mix,
        -10.2 if not far else -13.0,
        low_boost=2.4,
        pres_boost=3.0,
        fout=0.22 if last else 0.028,
        cut=None if last else SP_CUT,
    )


def make_sp_tail():
    length = 1.40
    core = V.pro(f"{L.M}shot_00_tail_only_01")[: int(length * RATE)]
    cr = V.seg(V.fs(V.CRACKLE), 0.22, 0.85, fin=0.05, fout=0.30, lo=1800, hi=12000, pitch=1.14)
    st = V.seg(V.fs(V.STUN), 0.08, 0.65, fin=0.04, fout=0.25, lo=320, hi=7500, pitch=1.10)
    mix = V.stack(length, (0.0, V.norm(core, -1.5)), (0.04, V.norm(cr, -8.0)), (0.05, V.norm(st, -9.5)))
    return _mono(B.fade(mix, 0.0, 0.28), -13.5)


# 4. SHORTY: Massive Twin-Core Break-Action Plasma Pocket Shotgun
def make_so_shot(k, far=False):
    length = 1.25
    core = V.pro(f"{L.SG}shot_0{(k % 4) + 1}")[: int(length * RATE)]
    core = lp(core, 7500, 2)
    saiga = L.gdc_shot("SAIGA-12_12g_solid_slug_1m_left", k, 0.50, lo=85, hi=8500, pitch=0.92)
    spas = L.gdc_shot("SPAS-12_12g_solid_slug_1m_right", k, 0.35, lo=550, hi=11500, pitch=0.96)
    sub = _bulkhead(k, pitch_base=0.74, lp_hz=175.0, length=0.28)
    bite = _plasma_bite(k, length=0.26, pitch_scale=0.90, heavy=True)
    lt_src = V.fs(V.LIGHTNING)
    lt_t = (0.20 + 0.30 * k) % max(0.2, len(lt_src) / RATE - 0.95)
    lt = V.seg(lt_src, lt_t, 0.90, fin=0.005, fout=0.30, lo=110, hi=7000, pitch=0.88)

    mix = V.stack(
        length,
        (0.0, V.norm(core, -2.5)),
        (0.0, V.norm(saiga, -1.5)),
        (0.002, V.norm(spas, -4.0)),
        (0.0, V.norm(sub, -1.0 if not far else -6.0)),
        (0.002, V.norm(bite, -1.5 if not far else -9.0)),
        (0.012, V.norm(lt, -6.5 if not far else -10.5)),
    )
    return _glue(mix, -9.4 if not far else -12.2, low_boost=3.5, pres_boost=2.8, fout=0.22)


def make_so_open():
    length = 0.48
    l1 = V.seg(V.fs(V.LATCH), 0.0, 0.14, fin=0.0, fout=0.04, lo=550, hi=11500, pitch=0.88, rel=-22.0)
    el = V.seg(V.fs(V.ELECTRICITY), 0.20, 0.26, fin=0.01, fout=0.09, lo=1500, hi=12000, pitch=0.94, rel=-22.0)
    cr = V.seg(V.fs(V.CRACKLE), 0.18, 0.34, fin=0.01, fout=0.10, lo=1800, hi=12000, pitch=1.02)
    mix = V.stack(length, (0.00, V.norm(l1, -1.0)), (0.05, V.norm(el, -3.5)), (0.08, V.norm(cr, -4.5)))
    return _mono(B.fade(mix, 0.0, 0.08), -12.0)


def make_so_close():
    length = 0.46
    sl = V.seg(V.fs(V.SLIDE_LOCK), 0.0, 0.18, fin=0.0, fout=0.05, lo=500, hi=11500, pitch=0.86, rel=-22.0)
    sub = _bulkhead(2, pitch_base=0.88, lp_hz=210.0, length=0.18)
    zp = V.seg(V.fs(V.ZAP_EGO), 0.0, 0.18, fin=0.0, fout=0.06, lo=900, hi=12000, pitch=0.96, rel=-22.0)
    mix = V.stack(length, (0.00, V.norm(sl, 0.0)), (0.005, V.norm(sub, -1.5)), (0.01, V.norm(zp, -3.0)))
    return _mono(B.fade(mix, 0.0, 0.08), -11.5)


def write_wav(name, data):
    path = os.path.join(OUT, name + ".wav")
    sf.write(path, data.astype(np.float32), RATE, subtype="PCM_16")
    return {"name": name, "path": path, "length": round(len(data) / RATE, 3)}


def main():
    manifest = []
    # Operator v2 (5 crisp railgun shots + cycle)
    for k in range(3):
        manifest.append(write_wav(f"RFO_fire_v2_0{k + 1}", make_op_shot_v2(k, far=False)))
    for k in range(2):
        manifest.append(write_wav(f"RFO_fireFar_v2_0{k + 1}", make_op_shot_v2(k, far=True)))
    manifest.append(write_wav("RFO_cycle_01", make_op_cycle()))
    # Sheriff (7)
    for k in range(3):
        manifest.append(write_wav(f"RFS_fire_0{k + 1}", make_sh_shot(k, far=False)))
    for k in range(2):
        manifest.append(write_wav(f"RFS_fireFar_0{k + 1}", make_sh_shot(k, far=True)))
    manifest.append(write_wav("RFS_open_01", make_sh_open()))
    manifest.append(write_wav("RFS_close_01", make_sh_close()))
    # Spectre (9)
    for k in range(4):
        manifest.append(write_wav(f"RFSP_fire_0{k + 1}", make_sp_shot(k)))
    manifest.append(write_wav("RFSP_fireFirst_01", make_sp_shot(0, first=True)))
    manifest.append(write_wav("RFSP_fireLast_01", make_sp_shot(1, last=True)))
    manifest.append(write_wav("RFSP_tail_01", make_sp_tail()))
    for k in range(2):
        manifest.append(write_wav(f"RFSP_fireFar_0{k + 1}", make_sp_shot(k, far=True)))
    # Shorty (7)
    for k in range(3):
        manifest.append(write_wav(f"RFSH_fire_0{k + 1}", make_so_shot(k, far=False)))
    for k in range(2):
        manifest.append(write_wav(f"RFSH_fireFar_0{k + 1}", make_so_shot(k, far=True)))
    manifest.append(write_wav("RFSH_open_01", make_so_open()))
    manifest.append(write_wav("RFSH_close_01", make_so_close()))

    with open(os.path.join(OUT, "manifest.json"), "w", newline="\n") as f:
        json.dump(manifest, f, indent=2)
    print(f"Designed {len(manifest)} Riftforge Bundle WAVs -> {OUT}")


if __name__ == "__main__":
    main()
