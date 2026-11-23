"""Layer Slipframe Arc foley from the project's licensed ProPack."""

import json

import numpy as np
import soundfile as sf

from design_slipframe import METAL, OUT, RATE, SWITCH, SWISH, mix


# Recording, take, filter band, pitch, duration, start offset and relative gain.
LAYERS = {
    "draw": [(SWISH, 3, 380, 6100, 1.04, .185, 0, 0),
             (METAL, 2, 1450, 8200, 1.04, .078, .103, -4)],
    "release": [(SWITCH, 4, 920, 7600, 1.09, .067, 0, 0),
                (METAL, 4, 1250, 6700, .84, .162, .024, -4)],
    "seat": [(SWITCH, 2, 750, 7200, 1.15, .058, 0, -3),
             (METAL, 3, 970, 8100, 1.05, .094, .007, 0)],
    "slash": [(SWISH, 4, 570, 7600, 1.11, .157, 0, 0),
              (METAL, 5, 1950, 8600, 1.17, .087, .052, -7)],
    "heavy": [(SWISH, 1, 250, 6500, .85, .237, 0, 0),
              (METAL, 1, 960, 7500, .92, .135, .080, -5)],
}


def main():
    directory = OUT / "arc"
    directory.mkdir(parents=True, exist_ok=True)
    cues = {}
    for name, layers in LAYERS.items():
        sound = mix(layers)
        sound = np.pad(sound, (0, max(0, round(.12 * RATE) - len(sound))))
        sf.write(directory / f"{name}.wav", sound, RATE, subtype="PCM_16")
        cues[name] = {"duration": round(len(sound) / RATE, 5),
                      "peak": round(float(np.abs(sound).max()), 5)}
    (directory / "cues.json").write_text(json.dumps(cues, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
