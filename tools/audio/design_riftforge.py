"""Design Riftforge's Legendary first-person audio from the licensed ProPack.

Run with Python 3, numpy, scipy and soundfile. Produces solo 48 kHz WAVs in
art-source/audio/riftforge/, a stock-versus-layered audition reel (_audition.wav),
and measured cue lengths (_cues.json).

Prelude-to-Chaos-inspired heavy industrial identity: thunderous bass-metallic
suppressed railgun punch with controlled mid-band harmonic overdrive grit,
heavy mechanical prong-lock slams on draw/seat, pressurized vent hiss on
mag-out, and crackling containment hum on inspect (first person only).
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
OUT = ROOT / "art-source/audio/riftforge"
STOCK_REEL = PACK / "audition/v9/Guns"

SHEET = "metal_sheet_impacts"
METAL = "metal_small_movement"
WET = "punch_grit_wet_impact"
SLAP = "punch_slap_whack_hit"
SWITCH = "switch_button_push_on_off"
FAST = "whoosh_swish_high_fast"
SWISH = "whoosh_swish_small"

# (family, take, low_hz, high_hz, speed, duration_s, offset_s, gain_db, drive)
SHOT_LAYERS = {
    "Phantom": [
        # Deep sub-metallic railgun thump + controlled overdrive crunch + crisp mechanical snap
        (SHEET, 1, 140, 3200, 0.78, 0.115, 0.000, 0.0, 2.2),
        (SLAP, 2, 110, 1800, 0.82, 0.088, 0.000, -3.0, 1.8),
        (FAST, 4, 1400, 6800, 1.15, 0.058, 0.002, -7.5, 1.4),
        (METAL, 3, 950, 5600, 0.92, 0.052, 0.001, -6.0, 1.2),
    ],
}

HANDLING = {
    "draw": [
        (FAST, 2, 420, 4600, 0.86, 0.130, 0.000, -3.5, 1.4),
        (SHEET, 4, 240, 4200, 0.84, 0.110, 0.030, 0.0, 1.9),
        (SWITCH, 1, 900, 6400, 0.92, 0.055, 0.044, -4.0, 1.2),
    ],
    "mag_out": [
        (SWITCH, 3, 880, 6200, 0.94, 0.050, 0.000, -2.0, 1.3),
        (FAST, 3, 620, 6400, 0.92, 0.135, 0.010, 0.0, 1.6),
        (METAL, 2, 720, 4800, 0.88, 0.075, 0.022, -5.0, 1.3),
    ],
    "mag_seat": [
        (SLAP, 1, 110, 2200, 0.82, 0.095, 0.000, -2.0, 2.0),
        (SHEET, 2, 260, 4600, 0.86, 0.125, 0.006, 0.0, 2.2),
        (METAL, 5, 1100, 6600, 1.02, 0.068, 0.018, -4.5, 1.4),
    ],
    "inspect": [
        (SWITCH, 2, 920, 6400, 0.96, 0.048, 0.000, -2.5, 1.3),
        (SWISH, 4, 340, 4200, 0.82, 0.165, 0.016, -2.0, 1.7),
        (SHEET, 5, 420, 5200, 0.94, 0.110, 0.085, -1.0, 1.8),
    ],
}

SHOT_VOLUMES = {
    "Phantom": 0.28,
}


def normalized(samples, db=0.0):
    return samples * (10 ** (db / 20) / max(np.abs(samples).max(), 1e-9))


def recording(family, take):
    path = PACK / "audition" / f"bonus {family}" / f"{family}_{take:02}.wav"
    audio, rate = sf.read(path, always_2d=True)
    x = audio.mean(axis=1)
    return x if rate == RATE else resample(x, RATE / rate)


def cut(record):
    family, take, low, high, speed, duration, offset, db, drive = record
    x = recording(family, take)
    peak = np.abs(x).max()
    start = max(0, int(np.argmax(np.abs(x) > peak * 0.10)) - round(0.003 * RATE))
    x = x[start:start + round(duration * speed * RATE)]
    x = resample(x, 1 / speed)
    # Controlled soft-clipping overdrive on real ProPack metal/impact stems
    # yields the heavy industrial "electric-guitar metal" bite without harsh aliasing.
    if drive > 1.0:
        x = np.tanh(normalized(x, 0.0) * drive)
    x = hp(lp(x, high, 2), low, 2)
    x = fade(x[:, None], 0.001, min(0.032, duration * 0.36))[:, 0]
    return round(offset * RATE), normalized(x, db)


def mix(records):
    layers = [cut(record) for record in records]
    out = np.zeros(max(i + len(x) for i, x in layers))
    for offset, x in layers:
        out[offset:offset + len(x)] += x
    return normalized(out, -4.5)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    cues = {f"{gun.lower()}_shot": mix(records) for gun, records in SHOT_LAYERS.items()}
    cues.update({key: mix(records) for key, records in HANDLING.items()})
    minimum = round(0.12 * RATE)
    cues = {key: np.pad(x, (0, max(0, minimum - len(x)))) for key, x in cues.items()}
    for key, x in cues.items():
        sf.write(OUT / f"{key}.wav", x, RATE, subtype="PCM_16")
    (OUT / "_cues.json").write_text(
        json.dumps(
            {
                "length": {key: round(len(x) / RATE, 5) for key, x in cues.items()},
                "shotVolume": SHOT_VOLUMES,
            },
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )
    print("Generated Riftforge ProPack cues:", sorted(cues.keys()))


if __name__ == "__main__":
    main()
