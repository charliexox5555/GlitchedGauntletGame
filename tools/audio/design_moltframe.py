"""Design Moltframe's subtle close-shot and handling accents from the licensed ProPack.

Run with Python 3, numpy, scipy and soundfile. Produces solo 48 kHz WAVs in
art-source/audio/moltframe/, a stock-versus-layered audition reel (_audition.wav),
and measured cue lengths (_cues.json). Distinct from Slipframe's bright high-tech
ticks: Moltframe blends dark resonant alloy sheets with subtle viscous chamber
transients layered lightly under the stock weapon report and tail.
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
OUT = ROOT / "art-source/audio/moltframe"
STOCK_REEL = PACK / "audition/v9/Guns"

SHEET = "metal_sheet_impacts"
METAL = "metal_small_movement"
WET = "punch_grit_wet_impact"
SWITCH = "switch_button_push_on_off"
SWISH = "whoosh_swish_small"

# (family, take, low_hz, high_hz, speed, duration_s, offset_s, gain_db)
SHOT_LAYERS = {
    "Vandal": [
        (SHEET, 2, 460, 4800, 0.94, 0.082, 0.001, 0),
        (WET, 2, 170, 2100, 1.06, 0.068, 0.000, -5),
    ],
    "Phantom": [
        (SWISH, 3, 720, 4400, 1.08, 0.064, 0.000, 0),
        (WET, 3, 210, 2300, 1.12, 0.052, 0.002, -6),
        (METAL, 4, 1100, 5600, 1.04, 0.044, 0.001, -9),
    ],
    "Spectre": [
        (SWISH, 1, 880, 5100, 1.16, 0.054, 0.000, 0),
        (WET, 4, 240, 2500, 1.18, 0.044, 0.001, -7),
        (METAL, 3, 1200, 5800, 1.12, 0.040, 0.001, -8),
    ],
    "Judge": [
        (WET, 1, 125, 2000, 0.84, 0.105, 0.000, 0),
        (SHEET, 4, 340, 3600, 0.86, 0.095, 0.003, -4),
    ],
    "Ares": [
        (SHEET, 3, 400, 4100, 0.89, 0.088, 0.001, 0),
        (WET, 5, 150, 1900, 0.95, 0.072, 0.000, -5),
    ],
    "Sheriff": [
        (SHEET, 1, 520, 5600, 0.92, 0.092, 0.001, 0),
        (WET, 2, 180, 2200, 0.96, 0.070, 0.000, -6),
        (SWITCH, 2, 1200, 6800, 0.94, 0.040, 0.002, -7),
    ],
}

HANDLING = {
    "draw": [
        (SWISH, 2, 340, 4200, 0.94, 0.125, 0.000, -2),
        (WET, 3, 180, 2000, 1.02, 0.075, 0.025, -7),
        (METAL, 2, 780, 6200, 0.92, 0.088, 0.042, 0),
    ],
    "mag_seat": [
        (WET, 1, 160, 2200, 0.96, 0.085, 0.000, -3),
        (SHEET, 5, 580, 5200, 0.96, 0.072, 0.008, 0),
    ],
    "inspect": [
        (SWISH, 4, 320, 3800, 0.88, 0.140, 0.000, -2),
        (WET, 4, 190, 2100, 0.94, 0.090, 0.032, -5),
        (METAL, 1, 820, 5900, 0.95, 0.078, 0.048, -4),
    ],
}

AUDITION_FIRE = {
    "Vandal": 4.1,
    "Phantom": 4.1,
    "Spectre": 4.1,
    "Judge": 3.0,
    "Ares": 4.1,
    "Sheriff": 3.0,
}
SHOT_VOLUMES = {
    "Vandal": 0.16,
    "Phantom": 0.20,
    "Spectre": 0.21,
    "Judge": 0.18,
    "Ares": 0.17,
    "Sheriff": 0.19,
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
    x = fade(x[:, None], 0.001, min(0.026, duration * 0.36))[:, 0]
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
        tag = f"{time:.2f}  {gun}  stock, then Moltframe"
        print(tag, f"layer {20*np.log10(rms(cue[:n]*SHOT_VOLUMES[gun])/max(rms(clean[start:start+n]), 1e-9)):+.1f} dB against stock over first {n/RATE:.3f}s")
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
