"""Pad (dilate) baked skin atlases so Roblox mip levels never bleed the empty
black margins into the islands (origami / faceted skins unwrap into many small
islands; without padding the Giltfold Vandal v02 read flat grey in Studio).

    python tools/textures/pad_atlas.py <textures folder> [<textures folder> ...]

For every <Item>_Atlas_Color.png the empty texels (pure black in the colour
map) are filled outward from the nearest island over N passes, in the colour,
roughness and metal maps alike (the colour map's mask drives all three); the
chamber map is padded from its own mask. Files are rewritten in place; the
originals are kept once as *_unpadded.png.
"""
import os
import shutil
import sys

import numpy as np
from PIL import Image

PASSES = 48


def pad(arrays, mask, passes=PASSES):
    filled = mask.copy()
    arrs = [a.astype(np.float32) for a in arrays]
    for _ in range(passes):
        if filled.all():
            break
        acc = [np.zeros_like(a) for a in arrs]
        cnt = np.zeros(mask.shape, np.float32)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1), (1, -1), (1, 1)):
            sh = np.roll(np.roll(filled, dy, 0), dx, 1)
            cnt += sh
            for k, a in enumerate(arrs):
                s = np.roll(np.roll(a, dy, 0), dx, 1)
                acc[k] += s * (sh[..., None] if a.ndim == 3 else sh)
        grow = (~filled) & (cnt > 0)
        for k, a in enumerate(arrs):
            avg = acc[k] / np.maximum(cnt, 1)[..., None] if a.ndim == 3 else acc[k] / np.maximum(cnt, 1)
            a[grow] = avg[grow]
        filled |= grow
    return [np.clip(a, 0, 255).astype(np.uint8) for a in arrs]


def keep_original(path):
    orig = path[:-4] + "_unpadded.png"
    if not os.path.exists(orig):
        shutil.copy2(path, orig)
    return orig


def run(folder):
    done = []
    for name in os.listdir(folder):
        if name.endswith("_Atlas_Color.png"):
            stem = name[: -len("_Atlas_Color.png")]
            paths = [os.path.join(folder, f"{stem}_Atlas_{m}.png") for m in ("Color", "Rough", "Metal")]
            srcs = [keep_original(p) for p in paths if os.path.exists(p)]
            col = np.array(Image.open(srcs[0]).convert("RGB"))
            mask = col.max(axis=2) > 3
            arrays = [col] + [np.array(Image.open(s).convert("L")) for s in srcs[1:]]
            out = pad(arrays, mask)
            Image.fromarray(out[0], "RGB").save(paths[0])
            for p, a in zip(paths[1:], out[1:]):
                Image.fromarray(a, "L").save(p)
            done += paths
        elif name.endswith("_Chamber_Color.png"):
            p = os.path.join(folder, name)
            src = keep_original(p)
            col = np.array(Image.open(src).convert("RGB"))
            out = pad([col], col.max(axis=2) > 3)
            Image.fromarray(out[0], "RGB").save(p)
            done.append(p)
    return done


if __name__ == "__main__":
    for f in sys.argv[1:]:
        for p in run(f):
            print("padded", p)
