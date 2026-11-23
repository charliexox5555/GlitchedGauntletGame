"""Design Playback's subtle close-shot and handling accents from the licensed ProPack.

Run with Python 3, numpy, scipy and soundfile. Produces solo 48 kHz WAVs in
art-source/audio/playback/, a stock-versus-layered audition reel (_audition.wav),
and measured cue lengths (_cues.json). Distinct retro-cassette mechanical identity:
tactile transport button relays, warm Bakelite housing clicks, and crisp tape-reel
whirs layered lightly under the stock weapon report and tail (first person only).
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
OUT = ROOT / "art-source/audio/playback"
STOCK_REEL = PACK / "audition/v9/Guns"

SWITCH = "switch_button_push_on_off"
WOOD = "wood_block_sticks_hit_clap"
METAL = "metal_small_movement"
SWISH = "whoosh_swish_small"
FAST = "whoosh_swish_high_fast"

# (family, take, low_hz, high_hz, speed, duration_s, offset_s, gain_db)
SHOT_LAYERS = {
    "Ares": [
        (SWITCH, 1, 780, 5600, 0.88, 0.062, 0.000, 0),
        (WOOD, 2, 360, 2900, 0.90, 0.058, 0.002, -4),
        (SWISH, 2, 650, 4200, 0.94, 0.072, 0.006, -9),
    ],
    "Bulldog": [
        (SWITCH, 2, 920, 6200, 0.98, 0.056, 0.000, 0),
        (WOOD, 1, 420, 3400, 1.00, 0.052, 0.002, -5),
        (SWISH, 1, 820, 4800, 1.06, 0.060, 0.005, -9),
    ],
    "Classic": [
        (SWITCH, 3, 1050, 6600, 1.08, 0.048, 0.000, 0),
        (WOOD, 3, 480, 3800, 1.10, 0.044, 0.001, -5),
    ],
    "Ghost": [
        (SWITCH, 4, 1180, 6200, 1.14, 0.044, 0.000, -1),
        (SWISH, 3, 900, 5200, 1.18, 0.054, 0.002, -5),
        (WOOD, 4, 520, 3400, 1.16, 0.038, 0.001, -8),
    ],
    "Phantom": [
        (SWITCH, 2, 1080, 6000, 1.10, 0.048, 0.000, -1),
        (SWISH, 4, 860, 5000, 1.14, 0.058, 0.002, -5),
        (WOOD, 2, 490, 3500, 1.12, 0.042, 0.001, -8),
    ],
    "Stinger": [
        (SWITCH, 3, 1120, 6800, 1.18, 0.042, 0.000, 0),
        (WOOD, 4, 520, 4100, 1.18, 0.038, 0.001, -6),
        (SWISH, 1, 960, 5400, 1.24, 0.048, 0.003, -9),
    ],
}

HANDLING = {
    "draw": [
        (SWISH, 2, 540, 4600, 1.08, 0.095, 0.000, -4),
        (SWITCH, 1, 900, 6500, 0.96, 0.055, 0.024, 0),
        (WOOD, 1, 420, 3200, 1.02, 0.048, 0.036, -5),
    ],
    "mag_out": [
        (SWITCH, 4, 980, 6400, 1.06, 0.046, 0.000, -1),
        (FAST, 2, 820, 5800, 1.18, 0.110, 0.012, -3),
    ],
    "mag_seat": [
        (WOOD, 2, 340, 3100, 0.94, 0.068, 0.000, -2),
        (SWITCH, 2, 880, 6400, 0.96, 0.058, 0.008, 0),
        (METAL, 3, 1050, 6200, 1.04, 0.048, 0.016, -7),
    ],
    "inspect": [
        (SWITCH, 3, 940, 6600, 1.02, 0.052, 0.000, -1),
        (SWISH, 4, 620, 4800, 0.96, 0.135, 0.018, -3),
        (SWITCH, 1, 1020, 6800, 1.08, 0.048, 0.095, -2),
    ],
    "knife_slash": [
        (FAST, 3, 760, 6200, 1.08, 0.092, 0.000, -2),
        (SWITCH, 2, 1040, 6800, 1.12, 0.044, 0.008, 0),
        (WOOD, 3, 460, 3600, 1.08, 0.040, 0.012, -6),
    ],
}

AUDITION_FIRE = {
    "Ares": 4.1,
    "Bulldog": 4.1,
    "Classic": 3.0,
    "Ghost": 3.0,
    "Phantom": 4.1,
    "Stinger": 4.1,
}
SHOT_VOLUMES = {
    "Ares": 0.17,
    "Bulldog": 0.18,
    "Classic": 0.19,
    "Ghost": 0.21,
    "Phantom": 0.20,
    "Stinger": 0.18,
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
        tag = f"{time:.2f}  {gun}  stock, then Playback"
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
