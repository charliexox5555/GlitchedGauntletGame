"""Design Sundial's subtle close-shot and handling accents from the licensed ProPack.

Run with Python 3, numpy, scipy and soundfile. Produces solo 48 kHz WAVs in
art-source/audio/sundial/, a stock-versus-layered audition reel (_audition.wav),
and measured cue lengths (_cues.json). Distinct horological brass identity:
crisp antique-brass escapement ticks and warm resonant bronze harmonic shimmer
layered lightly under the stock weapon report and tail (first person only).
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
OUT = ROOT / "art-source/audio/sundial"
STOCK_REEL = PACK / "audition/v9/Guns"

SHEET = "metal_sheet_impacts"
METAL = "metal_small_movement"
SWITCH = "switch_button_push_on_off"
FAST = "whoosh_swish_high_fast"

# (family, take, low_hz, high_hz, speed, duration_s, offset_s, gain_db)
SHOT_LAYERS = {
    "Ghost": [
        (METAL, 2, 1300, 6800, 1.18, 0.056, 0.000, -1),
        (SHEET, 3, 1250, 6400, 1.24, 0.068, 0.002, -5),
        (SWITCH, 4, 1500, 7200, 1.20, 0.036, 0.000, -7),
    ],
    "Guardian": [
        (SHEET, 1, 980, 6200, 1.06, 0.088, 0.001, 0),
        (METAL, 1, 1180, 6800, 1.04, 0.062, 0.000, -3),
        (SWITCH, 2, 1350, 7000, 1.08, 0.042, 0.002, -6),
    ],
    "Marshal": [
        (SHEET, 2, 920, 6000, 1.00, 0.095, 0.001, 0),
        (METAL, 4, 1100, 6500, 0.98, 0.070, 0.000, -3),
    ],
    "Operator": [
        (SHEET, 4, 760, 5600, 0.88, 0.112, 0.001, 0),
        (METAL, 5, 980, 6000, 0.90, 0.082, 0.000, -4),
        (SWITCH, 1, 1150, 6400, 0.92, 0.048, 0.003, -6),
    ],
    "Outlaw": [
        (SHEET, 5, 840, 5800, 0.94, 0.102, 0.001, 0),
        (METAL, 3, 1080, 6400, 0.96, 0.074, 0.000, -3),
    ],
    "Sheriff": [
        (SHEET, 3, 1020, 6400, 1.08, 0.086, 0.001, 0),
        (METAL, 2, 1240, 6900, 1.10, 0.060, 0.000, -2),
        (SWITCH, 3, 1400, 7200, 1.12, 0.038, 0.002, -5),
    ],
}

HANDLING = {
    "draw": [
        (METAL, 1, 1120, 6800, 1.06, 0.072, 0.000, -2),
        (SHEET, 2, 1180, 6600, 1.14, 0.105, 0.016, 0),
        (SWITCH, 2, 1380, 7200, 1.10, 0.042, 0.028, -5),
    ],
    "mag_out": [
        (SWITCH, 3, 1320, 7000, 1.12, 0.044, 0.000, -2),
        (METAL, 4, 1150, 6600, 1.08, 0.082, 0.014, 0),
    ],
    "mag_seat": [
        (METAL, 3, 1060, 6500, 1.02, 0.068, 0.000, -2),
        (SHEET, 1, 1040, 6400, 1.10, 0.098, 0.010, 0),
    ],
    "inspect": [
        (SWITCH, 4, 1420, 7200, 1.14, 0.042, 0.000, -2),
        (METAL, 2, 1200, 6800, 1.04, 0.088, 0.018, -1),
        (SHEET, 3, 1180, 6600, 1.16, 0.115, 0.038, -2),
    ],
    "knife_slash": [
        (FAST, 1, 920, 6800, 1.12, 0.086, 0.000, -3),
        (SHEET, 3, 1260, 6800, 1.22, 0.092, 0.008, 0),
        (METAL, 1, 1400, 7200, 1.16, 0.048, 0.006, -4),
    ],
}

AUDITION_FIRE = {
    "Ghost": 3.0,
    "Guardian": 3.0,
    "Marshal": 3.0,
    "Operator": 3.0,
    "Outlaw": 3.0,
    "Sheriff": 3.0,
}
SHOT_VOLUMES = {
    "Ghost": 0.20,
    "Guardian": 0.18,
    "Marshal": 0.19,
    "Operator": 0.18,
    "Outlaw": 0.19,
    "Sheriff": 0.20,
}


def normalized(samples, db=0.0):
    return samples * (10 ** (db / 20) / max(np.abs(samples).max(), 1e-9))


def recording(family, take):
    path = PACK / "audition" / f"bonus {family}" / f"{family}_{take:02}.wav"
    audio, rate = sf.read(path, always_2d=True)
    x = audio.mean(axis=1)
    return x if rate == RATE else resample(x, RATE / rate)


def cut(record):
    family, take, low, high, speed, duration, offset, db = record
    x = recording(family, take)
    peak = np.abs(x).max()
    start = max(0, int(np.argmax(np.abs(x) > peak * 0.10)) - round(0.003 * RATE))
    x = x[start:start + round(duration * speed * RATE)]
    x = hp(lp(resample(x, 1 / speed), high, 2), low, 2)
    x = fade(x[:, None], 0.001, min(0.028, duration * 0.36))[:, 0]
    return round(offset * RATE), normalized(x, db)


def mix(records):
    layers = [cut(record) for record in records]
    out = np.zeros(max(i + len(x) for i, x in layers))
    for offset, x in layers:
        out[offset:offset + len(x)] += x
    return normalized(out, -5)


def rms(x):
    return np.sqrt(np.mean(x ** 2))


def overlay(base, cue, volume):
    result = base.copy()
    n = min(len(result), len(cue))
    result[:n] += (cue[:n] * volume)[:, None]
    return result


def audition(cues):
    pieces = [np.zeros((round(0.20 * RATE), 2))]
    timings = []
    time = 0.20
    for gun, marker in AUDITION_FIRE.items():
        gun_wav = STOCK_REEL / f"{gun}.wav"
        if not gun_wav.exists():
            continue
        raw, rate = sf.read(gun_wav, always_2d=True)
        raw = raw if rate == RATE else resample(raw, RATE / rate)
        clean = raw[round(marker * RATE):round((marker + 0.75) * RATE), :2]
        if len(clean) < round(0.2 * RATE):
            clean = raw[:round(0.75 * RATE), :2]
        first_peak = min(len(clean), round(0.14 * RATE))
        onset = int(np.argmax(np.abs(clean[:first_peak]) > np.abs(clean[:first_peak]).max() * 0.11) // clean.shape[1])
        start = max(0, onset - round(0.002 * RATE))
        cue = cues[f"{gun.lower()}_shot"]
        layered = clean.copy()
        layered[start:] = overlay(clean[start:], cue, SHOT_VOLUMES[gun])
        n = min(len(cue), len(clean) - start)
        tag = f"{time:.2f}  {gun}  stock, then Sundial"
        print(tag, f"layer {20*np.log10(rms(cue[:n]*SHOT_VOLUMES[gun])/max(rms(clean[start:start+n]), 1e-9)):+.1f} dB")
        timings.append(tag)
        for x in (clean, layered):
            pieces += [x, np.zeros((round(0.31 * RATE), 2))]
            time += len(x) / RATE + 0.31
    for key in HANDLING:
        timings.append(f"{time:.2f}  {key.replace('_', ' ')}")
        cue = np.repeat(cues[key][:, None], 2, axis=1) * 0.46
        pieces += [cue, np.zeros((round(0.5 * RATE), 2))]
        time += len(cue) / RATE + 0.5
    reel = np.concatenate(pieces)
    reel *= min(1.0, 0.89 / max(np.abs(reel).max(), 1e-9))
    sf.write(OUT / "_audition.wav", reel, RATE, subtype="PCM_16")
    (OUT / "_audition.txt").write_text("\n".join(timings) + "\n", encoding="utf-8")


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
    audition(cues)


if __name__ == "__main__":
    main()
