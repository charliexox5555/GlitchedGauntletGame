"""Design the Frostbite Legendary skin line's audio cues (Season 1 battle pass).

Combines high-passed licensed ProPack mechanical/impact transients with
crystalline FM glass-ice harmonics and cold air tails. Outputs 48 kHz PCM_16
WAVs in art-source/audio/frostbite/ (git-ignored) plus an audition reel.

    python tools/audio/design_frostbite.py
"""
import json
from pathlib import Path

import numpy as np
import soundfile as sf

from build_sound_atlas import hp, lp, resample
from build_gun_sfx import fade

RATE = 48000
ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "art-source/audio/ProPack"
OUT = ROOT / "art-source/audio/frostbite"


def normalized(x, db=0.0):
    return x * (10 ** (db / 20) / max(np.abs(x).max(), 1e-9))


def recording(family, take):
    audio, rate = sf.read(PACK / "audition" / f"bonus {family}" / f"{family}_{take:02}.wav", always_2d=True)
    x = audio.mean(axis=1)
    return x if rate == RATE else resample(x, RATE / rate)


def foley(family, take, low, high, speed, duration, db):
    x = recording(family, take)
    peak = np.abs(x).max()
    start = max(0, int(np.argmax(np.abs(x) > peak * 0.10)) - round(0.002 * RATE))
    x = x[start:start + round(duration * speed * RATE)]
    x = hp(lp(resample(x, 1 / speed), high, 2), low, 2)
    x = fade(x[:, None], 0.001, min(0.025, duration * 0.34))[:, 0]
    return normalized(x, db)


def ice_ping(freq, duration, db, mod_ratio=2.41, mod_index=1.8, attack=0.002):
    """Inharmonic crystalline FM chime with fast glassy decay."""
    t = np.arange(round(duration * RATE)) / RATE
    mod = mod_index * np.exp(-t / (duration * 0.16)) * np.sin(2 * np.pi * freq * mod_ratio * t)
    car = np.sin(2 * np.pi * freq * t + mod) + 0.35 * np.sin(2 * np.pi * freq * 1.503 * t)
    env = np.minimum(1.0, t / attack) * np.exp(-t / (duration * 0.32))
    x = hp(lp(car * env, 11000.0, 2), 900.0, 2)
    x = fade(x[:, None], 0.0005, min(0.02, duration * 0.30))[:, 0]
    return normalized(x, db)


def frost_air(duration, low_cut=3600.0, db=-14.0):
    """Cold filtered air breath for frost bloom and shatter exhale."""
    rng = np.random.default_rng(20261127)
    n = round(duration * RATE)
    t = np.arange(n) / RATE
    noise = rng.standard_normal(n)
    env = np.minimum(1.0, t / 0.012) * np.exp(-t / (duration * 0.38))
    x = hp(lp(noise * env, 11500.0, 2), low_cut, 2)
    x = fade(x[:, None], 0.002, min(0.03, duration * 0.35))[:, 0]
    return normalized(x, db)


def place(parts):
    out = np.zeros(max(round(at * RATE) + len(x) for at, x in parts))
    for at, x in parts:
        i = round(at * RATE)
        out[i:i + len(x)] += x
    return out


def cues():
    # 1. Vandal fire layer: tight metallic-wood crack + glassy crystal ping + crisp cold air tail
    fire_snap = foley("metal_small_movement", 4, 1600, 9500, 1.35, 0.055, -3)
    fire_tick = foley("wood_block_sticks_hit_clap", 2, 2200, 10500, 1.45, 0.035, -5)
    fire_ping = ice_ping(2180.0, 0.095, -6, mod_ratio=2.73, mod_index=2.1)
    fire_air = frost_air(0.115, 4200.0, -13)
    vandal_fire = place([
        (0.000, fire_snap),
        (0.000, fire_tick),
        (0.003, fire_ping),
        (0.006, fire_air),
    ])

    # 2. Inspect grow step: dry ice-creep crackle + resonant high crystal partial (pitched per stage)
    grow_crackle_a = foley("wood_block_sticks_hit_clap", 1, 2400, 11000, 1.40, 0.050, -4)
    grow_crackle_b = foley("switch_button_push_on_off", 3, 1800, 9200, 1.25, 0.045, -7)
    grow_ring = ice_ping(1760.0, 0.165, -4, mod_ratio=2.38, mod_index=1.4)
    grow_air = frost_air(0.18, 3800.0, -15)
    inspect_grow = place([
        (0.000, grow_crackle_a),
        (0.022, grow_crackle_b),
        (0.010, grow_ring),
        (0.005, grow_air),
    ])

    # 3. Inspect settle: cold crystalline triad shimmer when all three growth crowns lock
    inspect_settle = place([
        (0.000, foley("metal_small_movement", 2, 1800, 9000, 1.15, 0.055, -7)),
        (0.000, ice_ping(1318.51, 0.28, -5, mod_ratio=2.01, mod_index=0.8)),   # E6
        (0.030, ice_ping(1975.53, 0.25, -6, mod_ratio=2.02, mod_index=0.7)),   # B6
        (0.060, ice_ping(2959.96, 0.22, -7, mod_ratio=2.03, mod_index=0.6)),   # F#7
        (0.010, frost_air(0.24, 4600.0, -16)),
    ])

    # 4. Kill shatter: punchy fracture crack + cascading 5-shard ice chimes + cold exhale
    kill_crack = foley("metal_sheet_impacts", 2, 1100, 10500, 1.30, 0.085, -1)
    kill_snap = foley("wood_block_sticks_hit_clap", 3, 1800, 11500, 1.25, 0.060, -2)
    kill_shatter = place([
        (0.000, kill_crack),
        (0.002, kill_snap),
        (0.012, ice_ping(2489.02, 0.22, -4, mod_ratio=2.67, mod_index=2.2)),
        (0.045, ice_ping(3322.44, 0.20, -5, mod_ratio=2.41, mod_index=1.9)),
        (0.085, ice_ping(2793.83, 0.19, -6, mod_ratio=2.53, mod_index=1.7)),
        (0.130, ice_ping(4186.01, 0.17, -7, mod_ratio=2.19, mod_index=1.4)),
        (0.185, ice_ping(3729.31, 0.16, -9, mod_ratio=2.31, mod_index=1.2)),
        (0.010, frost_air(0.36, 3200.0, -11)),
    ])

    # 5. Class-tailored gun shot crystalline layers
    phantom_fire = place([
        (0.000, foley("switch_button_push_on_off", 2, 1900, 9000, 1.40, 0.032, -6)),
        (0.002, ice_ping(2620.0, 0.095, -5, mod_ratio=2.14, mod_index=1.3)),
        (0.004, frost_air(0.115, 5200.0, -10)),
    ])
    ghost_fire = place([
        (0.000, foley("switch_button_push_on_off", 1, 2200, 9500, 1.50, 0.028, -5)),
        (0.002, ice_ping(2880.0, 0.080, -4, mod_ratio=2.09, mod_index=1.1)),
        (0.004, frost_air(0.095, 5600.0, -12)),
    ])
    spectre_fire = place([
        (0.000, foley("wood_block_sticks_hit_clap", 1, 2100, 9800, 1.55, 0.030, -5)),
        (0.002, ice_ping(2520.0, 0.075, -5, mod_ratio=2.33, mod_index=1.4)),
        (0.004, frost_air(0.090, 4900.0, -12)),
    ])
    stinger_fire = place([
        (0.000, foley("switch_button_push_on_off", 3, 2400, 11000, 1.65, 0.026, -4)),
        (0.001, ice_ping(3050.0, 0.070, -4, mod_ratio=2.48, mod_index=1.6)),
        (0.003, frost_air(0.085, 5200.0, -13)),
    ])
    guardian_fire = place([
        (0.000, foley("metal_sheet_impacts", 1, 1000, 9000, 1.25, 0.075, -2)),
        (0.000, foley("wood_block_sticks_hit_clap", 3, 1800, 10000, 1.25, 0.045, -4)),
        (0.003, ice_ping(1650.0, 0.135, -3, mod_ratio=2.39, mod_index=2.2)),
        (0.006, frost_air(0.145, 3600.0, -11)),
    ])
    bulldog_fire = place([
        (0.000, foley("metal_small_movement", 2, 1800, 9800, 1.40, 0.045, -3)),
        (0.002, ice_ping(2340.0, 0.090, -5, mod_ratio=2.57, mod_index=1.8)),
        (0.005, frost_air(0.105, 4400.0, -13)),
    ])
    odin_fire = place([
        (0.000, foley("metal_sheet_impacts", 2, 850, 7800, 1.15, 0.075, -2)),
        (0.002, foley("metal_small_movement", 5, 1100, 8200, 1.15, 0.060, -4)),
        (0.004, ice_ping(1420.0, 0.115, -4, mod_ratio=2.61, mod_index=2.4)),
        (0.008, frost_air(0.130, 3200.0, -12)),
    ])
    operator_fire = place([
        (0.000, foley("metal_sheet_impacts", 2, 700, 9500, 0.95, 0.110, -1)),
        (0.002, foley("wood_block_sticks_hit_clap", 3, 1400, 10500, 1.10, 0.065, -3)),
        (0.005, ice_ping(980.0, 0.210, -3, mod_ratio=2.71, mod_index=2.6)),
        (0.012, ice_ping(1960.0, 0.175, -5, mod_ratio=2.18, mod_index=1.9)),
        (0.010, frost_air(0.240, 2800.0, -10)),
    ])
    marshal_fire = place([
        (0.000, foley("metal_small_movement", 4, 1500, 10500, 1.30, 0.060, -2)),
        (0.001, foley("wood_block_sticks_hit_clap", 2, 2000, 11000, 1.35, 0.045, -3)),
        (0.003, ice_ping(1920.0, 0.155, -3, mod_ratio=2.44, mod_index=2.1)),
        (0.008, frost_air(0.165, 3900.0, -11)),
    ])
    bucky_fire = place([
        (0.000, foley("metal_sheet_impacts", 1, 1100, 10000, 1.25, 0.075, -2)),
        (0.012, foley("wood_block_sticks_hit_clap", 1, 1900, 11000, 1.35, 0.050, -3)),
        (0.004, ice_ping(1780.0, 0.145, -4, mod_ratio=2.81, mod_index=2.3)),
        (0.016, ice_ping(2680.0, 0.130, -5, mod_ratio=2.37, mod_index=1.8)),
        (0.008, frost_air(0.180, 3400.0, -10)),
    ])
    shorty_fire = place([
        (0.000, foley("metal_small_movement", 5, 1300, 10200, 1.35, 0.060, -2)),
        (0.008, foley("wood_block_sticks_hit_clap", 2, 2200, 11000, 1.45, 0.040, -3)),
        (0.003, ice_ping(2040.0, 0.115, -4, mod_ratio=2.63, mod_index=2.1)),
        (0.014, ice_ping(2920.0, 0.105, -6, mod_ratio=2.29, mod_index=1.6)),
        (0.006, frost_air(0.135, 3800.0, -11)),
    ])
    classic_fire = place([
        (0.000, foley("switch_button_push_on_off", 3, 1800, 9500, 1.35, 0.035, -4)),
        (0.001, foley("metal_small_movement", 1, 1900, 9800, 1.40, 0.040, -5)),
        (0.002, ice_ping(2460.0, 0.090, -5, mod_ratio=2.24, mod_index=1.6)),
        (0.005, frost_air(0.100, 4500.0, -13)),
    ])
    sheriff_fire = place([
        (0.000, foley("metal_sheet_impacts", 2, 1200, 10200, 1.20, 0.080, -1)),
        (0.002, ice_ping(1740.0, 0.175, -3, mod_ratio=2.01, mod_index=1.9)),
        (0.014, ice_ping(3480.0, 0.135, -7, mod_ratio=2.03, mod_index=1.1)),
        (0.008, frost_air(0.180, 3500.0, -11)),
    ])

    # 6. Frostbite Knife cues
    knife_draw = place([
        (0.000, foley("metal_small_movement", 4, 1500, 9800, 1.15, 0.085, -3)),
        (0.018, foley("whoosh_swish_small", 1, 1400, 9600, 1.20, 0.160, -4)),
        (0.025, ice_ping(2200.0, 0.180, -5, mod_ratio=2.02, mod_index=1.2)),
        (0.065, ice_ping(3300.0, 0.170, -6, mod_ratio=2.04, mod_index=1.0)),
        (0.010, frost_air(0.240, 4000.0, -12)),
    ])
    knife_slash = place([
        (0.000, foley("whoosh_swish_high_fast", 1, 1600, 11000, 1.25, 0.135, -2)),
        (0.004, foley("metal_small_movement", 2, 2200, 10800, 1.45, 0.045, -5)),
        (0.010, ice_ping(2960.0, 0.135, -4, mod_ratio=2.41, mod_index=1.8)),
        (0.005, frost_air(0.155, 4400.0, -11)),
    ])
    knife_heavy = place([
        (0.000, foley("whoosh_swish_high_fast", 2, 1200, 10800, 1.05, 0.190, -1)),
        (0.008, foley("metal_sheet_impacts", 1, 1400, 10000, 1.25, 0.075, -3)),
        (0.014, ice_ping(1480.0, 0.210, -3, mod_ratio=2.33, mod_index=2.1)),
        (0.036, ice_ping(2220.0, 0.180, -5, mod_ratio=2.07, mod_index=1.5)),
        (0.012, frost_air(0.230, 3400.0, -10)),
    ])

    return {
        "vandal_fire": vandal_fire,
        "inspect_grow": inspect_grow,
        "inspect_settle": inspect_settle,
        "kill_shatter": kill_shatter,
        "phantom_fire": phantom_fire,
        "ghost_fire": ghost_fire,
        "spectre_fire": spectre_fire,
        "stinger_fire": stinger_fire,
        "guardian_fire": guardian_fire,
        "bulldog_fire": bulldog_fire,
        "odin_fire": odin_fire,
        "operator_fire": operator_fire,
        "marshal_fire": marshal_fire,
        "bucky_fire": bucky_fire,
        "shorty_fire": shorty_fire,
        "classic_fire": classic_fire,
        "sheriff_fire": sheriff_fire,
        "knife_draw": knife_draw,
        "knife_slash": knife_slash,
        "knife_heavy": knife_heavy,
    }


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    made = {k: normalized(v, -4) for k, v in cues().items()}
    minimum = round(0.13 * RATE)  # keep short clips cleanly decodable in Roblox
    made = {k: np.pad(x, (0, max(0, minimum - len(x)))) for k, x in made.items()}
    for key, x in made.items():
        sf.write(OUT / f"{key}.wav", x, RATE, subtype="PCM_16")
    (OUT / "_cues.json").write_text(
        json.dumps({k: round(len(x) / RATE, 4) for k, x in made.items()}, indent=2) + "\n",
        encoding="utf-8",
    )

    parts = [
        (0.10, made["vandal_fire"] * 0.8),
        (0.35, made["vandal_fire"] * 0.8),
        (0.90, resample(made["inspect_grow"], 1 / 0.94) * 0.75),
        (1.38, resample(made["inspect_grow"], 1 / 1.04) * 0.75),
        (1.86, resample(made["inspect_grow"], 1 / 1.16) * 0.75),
        (2.34, made["inspect_settle"] * 0.85),
        (3.10, made["kill_shatter"] * 0.9),
    ]
    reel = place(parts)
    sf.write(OUT / "_audition.wav", np.repeat(reel[:, None], 2, axis=1) * 0.9, RATE, subtype="PCM_16")
    print({k: round(len(x) / RATE, 3) for k, x in made.items()})


if __name__ == "__main__":
    main()
