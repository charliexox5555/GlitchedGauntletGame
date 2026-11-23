"""Cut item icons out of a pair of icon-sheet captures.

The Studio render scripts lay out guns / skins on a flat
background; Studio is captured once on black and once on white. Per pixel:
    alpha = 1 - (white - black) / 255      (the background shows through)
    color = black / alpha                  (un-premultiplied)
so soft edges come out right without a colour key. Each cell is cropped to its
visible pixels (plus a margin) and saved as a PNG named after the item.

usage: python icon_sheet.py BLACK.jpg WHITE.jpg OUT_DIR "Weapons/Vandal;WeaponSkins/Prism/Vandal;..."
       [--cols 2 --rows 2 --centered --square --minw 768 --maxw 1024] (portraits)
       [--cols 2 --rows 2 --centered --cell-aspect 1.4222222222 --minw 1024 --maxw 1024] (side)
       [--viewport X,Y,WIDTH,HEIGHT]    (native viewport rectangle in both full-window captures)
"""
import argparse
import os

from PIL import Image

try:
    import numpy as np
except ImportError:
    np = None

COLS, ROWS = 5, 4
PAD = 6
MAX_W = 512


def name_for(path, portrait=False):
    parts = path.split('/')
    if parts[0] == 'Weapons':
        return parts[1] + '_Stock'
    gun = parts[2]
    if portrait and parts[1:] == ['PopCircuit', 'Bat']:
        gun = 'Knife'
    return gun + '_' + parts[1]


def recover_alpha(black, white):
    if np is not None:
        b = np.asarray(black)
        difference = np.asarray(white, dtype=np.int16) - b
        alpha = np.clip(1 - difference.sum(axis=2, dtype=np.int16) / (3 * 255), 0, 1)
        substantial = alpha >= 0.04
        rgb = np.zeros_like(b, dtype=np.float32)
        np.divide(b, alpha[:, :, None], out=rgb, where=substantial[:, :, None])
        out = np.zeros((*alpha.shape, 4), dtype=np.uint8)
        out[:, :, :3] = np.minimum(255, np.rint(rgb)).astype(np.uint8)
        out[:, :, 3] = np.where(substantial, np.rint(alpha * 255), 0).astype(np.uint8)
        return Image.fromarray(out)

    out = Image.new('RGBA', black.size)
    pixels = []
    for original, against_white in zip(black.getdata(), white.getdata()):
        alpha = 1 - sum(w - b for b, w in zip(original, against_white)) / (3 * 255)
        alpha = max(0.0, min(1.0, alpha))
        if alpha < 0.04:
            pixels.append((0, 0, 0, 0))
        else:
            pixels.append(tuple(min(255, round(channel / alpha)) for channel in original) + (round(alpha * 255),))
    out.putdata(pixels)
    return out


def main(black_path, white_path, out_dir, items, cols=COLS, rows=ROWS, centered=False,
         max_w=MAX_W, min_w=0, square=False, cell_aspect=1.0, viewport=None):
    if len(items) > cols * rows:
        raise ValueError("More item paths than grid cells")
    if min_w > max_w:
        raise ValueError("--minw cannot exceed --maxw")
    os.makedirs(out_dir, exist_ok=True)
    b = Image.open(black_path).convert('RGB')
    w = Image.open(white_path).convert('RGB')
    if b.size != w.size:
        raise ValueError(f"Black and white captures have different sizes: {b.size} and {w.size}")
    if viewport:
        x, y, width, height = viewport
        box = (x, y, x + width, y + height)
        if min(x, y) < 0 or min(width, height) <= 0 or box[2] > b.width or box[3] > b.height:
            raise ValueError("Viewport rectangle is outside the captures")
        b, w = b.crop(box), w.crop(box)
    W, H = b.size
    ox, oy, gw, gh = 0, 0, W, H
    if centered:  # the grid keeps cols:rows square cells, centred on the screen
        aspect = cell_aspect * cols / rows
        if W / H > aspect:
            gw = H * aspect
            ox = (W - gw) / 2
        else:
            gh = W / aspect
            oy = (H - gh) / 2
    cw, ch = gw / cols, gh / rows
    images = []
    for i, path in enumerate(items):
        col, row = i % cols, i // cols
        bounds = (
            round(ox + col * cw),
            round(oy + row * ch),
            round(ox + (col + 1) * cw),
            round(oy + (row + 1) * ch),
        )
        cell = recover_alpha(b.crop(bounds), w.crop(bounds))
        box = cell.getchannel("A").getbbox()
        if not box:
            if min_w:
                raise ValueError(f"{path}: empty render cell")
            continue
        if min_w and (box[0] == 0 or box[1] == 0 or box[2] == cell.width or box[3] == cell.height):
            raise ValueError(f"{path}: artwork touches the render cell edge")
        l, t, r, btm = box
        cell = cell.crop((max(0, l - PAD), max(0, t - PAD), min(cell.width, r + PAD), min(cell.height, btm + PAD)))
        if square:
            side = max(cell.size)
            padded = Image.new("RGBA", (side, side))
            padded.alpha_composite(cell, ((side - cell.width) // 2, (side - cell.height) // 2))
            cell = padded
        if cell.width < min_w:
            raise ValueError(f"{path}: only {cell.width}px native artwork, expected at least {min_w}px")
        if cell.width > max_w:
            cell = cell.resize((max_w, round(cell.height * max_w / cell.width)), Image.LANCZOS)
        images.append((name_for(path, portrait=square), cell))
    for name, cell in images:
        cell.save(os.path.join(out_dir, name + '.png'))
    print(len(images), 'icons')


def viewport_box(value):
    try:
        coords = tuple(int(part) for part in value.split(","))
        if len(coords) == 4:
            return coords
    except ValueError:
        pass
    raise argparse.ArgumentTypeError("Use X,Y,WIDTH,HEIGHT")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("black")
    parser.add_argument("white")
    parser.add_argument("out")
    parser.add_argument("items", help="Semicolon-separated Studio model paths")
    parser.add_argument("--cols", type=int, default=COLS)
    parser.add_argument("--rows", type=int, default=ROWS)
    parser.add_argument("--maxw", type=int, default=MAX_W)
    parser.add_argument("--minw", type=int, default=0)
    parser.add_argument("--centered", action="store_true")
    parser.add_argument("--square", action="store_true")
    parser.add_argument("--cell-aspect", type=float, default=1.0)
    parser.add_argument("--viewport", type=viewport_box)
    args = parser.parse_args()
    main(args.black, args.white, args.out, [path for path in args.items.split(";") if path],
         args.cols, args.rows, args.centered, args.maxw, args.minw, args.square,
         args.cell_aspect, args.viewport)
