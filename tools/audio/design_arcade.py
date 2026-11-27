"""Design the Arcade skin line's handling cues (Season 1 pass, 2026-11-27).

A real arcade-button click or coin clunk from the project's licensed ProPack,
layered with a soft synthesized 8-bit blip (square wave, low-passed so it stays
round, never harsh). Outputs are private 48 kHz WAVs in art-source/audio/arcade/
(git-ignored: they contain licensed recordings) plus an audition reel.

    python tools/audio/design_arcade.py
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
OUT = ROOT / "art-source/audio/arcade"

SWITCH = "switch_button_push_on_off"
METAL = "metal_small_movement"


def normalized(x, db=0.0):
    return x * (10 ** (db / 20) / max(np.abs(x).max(), 1e-9))


def recording(family, take):
    audio, rate = sf.read(PACK / "audition" / f"bonus {family}" / f"{family}_{take:02}.wav", always_2d=True)
    x = audio.mean(axis=1)
    return x if rate == RATE else resample(x, RATE / rate)


def foley(family, take, low, high, speed, duration, db):
    x = recording(family, take)
    peak = np.abs(x).max()
    start = max(0, int(np.argmax(np.abs(x) > peak * .10)) - round(.003 * RATE))
    x = x[start:start + round(duration * speed * RATE)]
    x = hp(lp(resample(x, 1 / speed), high, 2), low, 2)
    x = fade(x[:, None], .001, min(.02, duration * .34))[:, 0]
    return normalized(x, db)


def blip(freq, duration, db, attack=.003, cutoff=3600.0):
    """A soft square note: odd harmonics only up to `cutoff`, quick attack, exponential decay."""
    t = np.arange(round(duration * RATE)) / RATE
    x = np.zeros_like(t)
    k = 1
    while freq * k < cutoff:
        x += np.sin(2 * np.pi * freq * k * t) / k
        k += 2
    env = np.minimum(1, t / attack) * np.exp(-t / (duration * .45))
    x = lp(x * env, cutoff, 2)
    x = fade(x[:, None], .0005, min(.015, duration * .3))[:, 0]
    return normalized(x, db)


def place(parts):
    out = np.zeros(max(round(at * RATE) + len(x) for at, x in parts))
    for at, x in parts:
        i = round(at * RATE)
        out[i:i + len(x)] += x
    return out


B5, CS6, E6, GS6, B6 = 987.77, 1108.73, 1318.51, 1661.22, 1975.53


def cues():
    click = foley(SWITCH, 3, 900, 7600, 1.08, .045, -4)
    return {
        # One chase step: a button press and a short blip. Pitch is raised per button at playback.
        "chase": place([(0, click), (.004, blip(B5, .075, -2))]),
        # The inspect finale: all three lit, a quick rising arpeggio.
        "win": place([(0, foley(SWITCH, 1, 800, 7200, .96, .05, -6)),
                      (.000, blip(E6, .07, -3)), (.055, blip(GS6, .07, -3)), (.110, blip(B6, .16, -2))]),
        # The mag seats: a coin drops, the button clicks, two credit notes.
        "coin": place([(0, foley(METAL, 5, 1200, 7800, 1.15, .07, -2)),
                       (.030, foley(SWITCH, 2, 800, 7000, 1.0, .045, -6)),
                       (.045, blip(B5, .06, -4)), (.100, blip(E6, .13, -3))]),
    }


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    made = {k: normalized(v, -5) for k, v in cues().items()}
    minimum = round(.12 * RATE)  # keep short clips decodable as standalone assets
    made = {k: np.pad(x, (0, max(0, minimum - len(x)))) for k, x in made.items()}
    for key, x in made.items():
        sf.write(OUT / f"{key}.wav", x, RATE, subtype="PCM_16")
    (OUT / "_cues.json").write_text(json.dumps({k: round(len(x) / RATE, 4) for k, x in made.items()}, indent=2) + "\n",
                                    encoding="utf-8")
    # Audition: the inspect as heard in game (9 chase steps rising per button, then the win), then the coin.
    pitches = [1.0, 1.122, 1.26]
    parts, t = [], .2
    for step in range(9):
        p = pitches[step % 3]
        parts.append((t, resample(made["chase"], 1 / p) * .7))
        t += .12
    parts.append((t + .05, made["win"] * .8))
    parts.append((t + 1.0, made["coin"] * .8))
    reel = place(parts)
    sf.write(OUT / "_audition.wav", np.repeat(reel[:, None], 2, axis=1) * .9, RATE, subtype="PCM_16")
    print({k: round(len(x) / RATE, 3) for k, x in made.items()})


if __name__ == "__main__":
    main()
