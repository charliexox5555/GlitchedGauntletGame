"""Design Slipframe's close foley from the project's licensed ProPack.

Run with Python 3, numpy, scipy and soundfile. The private outputs are solo
48 kHz WAVs, plus a stock-versus-layered audition and measured cue lengths.
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
OUT = ROOT / "art-source/audio/slipframe"
STOCK_REEL = PACK / "audition/v9/Guns"

METAL = "metal_small_movement"
SWITCH = "switch_button_push_on_off"
SWISH = "whoosh_swish_small"

# Each tuple gives the recording family/take, filter band, speed, duration,
# start offset in the new sound and gain relative to the primary layer.
SHOT_LAYERS = {
    "Guardian": [(METAL, 2, 1350, 8100, .96, .070, .002, 0),
                 (SWITCH, 3, 2100, 7500, 1.01, .038, .000, -5)],
    "Vandal": [(METAL, 3, 1800, 7800, 1.10, .054, .001, 0),
               (SWITCH, 4, 1450, 8200, 1.03, .036, .000, -6)],
    "Spectre": [(METAL, 5, 1250, 5900, 1.15, .046, .001, 0),
                (SWISH, 4, 900, 4100, 1.12, .049, .000, -9)],
    "Operator": [(METAL, 1, 850, 6200, .86, .100, .002, 0),
                 (SWITCH, 2, 1700, 7100, .93, .038, .000, -6)],
    "Classic": [(SWITCH, 1, 1500, 8500, 1.11, .041, .000, 0),
                (METAL, 4, 1600, 8100, 1.10, .055, .003, -5)],
}

HANDLING = {
    "draw": [(SWISH, 2, 420, 5200, 1.03, .118, .000, -3),
             (METAL, 2, 950, 7300, 1.03, .092, .041, 0)],
    "mag_seat": [(SWITCH, 2, 700, 6600, .88, .062, .000, 0),
                 (METAL, 5, 1400, 7400, .98, .067, .011, -6)],
    "inspect_open": [(SWITCH, 3, 850, 6900, .96, .056, .000, 0),
                     (METAL, 4, 1100, 6500, .91, .138, .027, -4)],
    "inspect_seat": [(SWITCH, 1, 820, 7800, .96, .063, .000, 0),
                     (METAL, 1, 850, 6500, 1.04, .086, .014, -7)],
}

# Baseline audition cues start at these marks in the project's matched mixes.
AUDITION_FIRE = {"Guardian": 4.1, "Vandal": 4.1, "Spectre": 4.1, "Operator": 4.1, "Classic": 3.0}
SHOT_VOLUMES = {"Guardian": .19, "Vandal": .16, "Spectre": .22, "Operator": .20, "Classic": .24}


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
    # Allow the small attack before the first movement of the recording.
    start = max(0, int(np.argmax(np.abs(x) > peak * .10)) - round(.003 * RATE))
    x = x[start:start + round(duration * speed * RATE)]
    x = hp(lp(resample(x, 1 / speed), high, 2), low, 2)
    x = fade(x[:, None], .001, min(.023, duration * .34))[:, 0]
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
    result[:len(cue)] += (cue * volume)[:, None]
    return result


def audition(cues):
    pieces = [np.zeros((round(.20 * RATE), 2))]
    timings = []
    time = .20
    for gun, marker in AUDITION_FIRE.items():
        raw, rate = sf.read(STOCK_REEL / f"{gun}.wav", always_2d=True)
        raw = raw if rate == RATE else resample(raw, RATE / rate)
        clean = raw[round(marker * RATE):round((marker + .75) * RATE), :2]
        first_peak = round(.14 * RATE)
        onset = int(np.argmax(np.abs(clean[:first_peak]) > np.abs(clean[:first_peak]).max() * .11) // clean.shape[1])
        start = max(0, onset - round(.002 * RATE))
        cue = cues[f"{gun.lower()}_shot"]
        layered = clean.copy()
        layered[start:] = overlay(clean[start:], cue, SHOT_VOLUMES[gun])
        n = len(cue)
        tag = f"{time:.2f}  {gun}  stock, then Slipframe"
        print(tag, f"layer {20*np.log10(rms(cue*SHOT_VOLUMES[gun])/rms(clean[start:start+n])):+.1f} dB against stock over first {n/RATE:.3f}s")
        timings.append(tag)
        for x in (clean, layered):
            pieces += [x, np.zeros((round(.31 * RATE), 2))]
            time += len(x) / RATE + .31
    for key in HANDLING:
        timings.append(f"{time:.2f}  {key.replace('_', ' ')}")
        cue = np.repeat(cues[key][:, None], 2, axis=1) * .46
        pieces += [cue, np.zeros((round(.5 * RATE), 2))]
        time += len(cue) / RATE + .5
    reel = np.concatenate(pieces)
    # Keep stock and layered takes at the same overall gain in the audition.
    reel *= min(1.0, .89 / np.abs(reel).max())
    sf.write(OUT / "_audition.wav", reel, RATE, subtype="PCM_16")
    (OUT / "_audition.txt").write_text("\n".join(timings) + "\n", encoding="utf-8")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    cues = {f"{gun.lower()}_shot": mix(records) for gun, records in SHOT_LAYERS.items()}
    cues.update({key: mix(records) for key, records in HANDLING.items()})
    # Keep the exported clips decodable as standalone assets even for the short ticks.
    minimum = round(.12 * RATE)
    cues = {key: np.pad(x, (0, max(0, minimum - len(x)))) for key, x in cues.items()}
    for key, x in cues.items():
        sf.write(OUT / f"{key}.wav", x, RATE, subtype="PCM_16")
    (OUT / "_cues.json").write_text(json.dumps({"length": {key: round(len(x)/RATE, 4) for key, x in cues.items()},
                                               "shotVolume": SHOT_VOLUMES}, indent=2) + "\n", encoding="utf-8")
    audition(cues)


if __name__ == "__main__":
    main()
