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

    return {
        "vandal_fire": vandal_fire,
        "inspect_grow": inspect_grow,
        "inspect_settle": inspect_settle,
        "kill_shatter": kill_shatter,
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
