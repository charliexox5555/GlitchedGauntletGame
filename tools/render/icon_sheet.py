"""Cut item icons out of a pair of icon-sheet captures.

tools/studio/RenderItemIcons.luau lays out up to 5 x 4 guns / skins on a flat
background; Studio is captured once on black and once on white. Per pixel:
    alpha = 1 - (white - black) / 255      (the background shows through)
    color = black / alpha                  (un-premultiplied)
so soft edges come out right without a colour key. Each cell is cropped to its
visible pixels (plus a margin) and saved as a PNG named after the item.

usage: python icon_sheet.py BLACK.jpg WHITE.jpg OUT_DIR "Weapons/Vandal;WeaponSkins/Prism/Vandal;..."
"""
import os
import sys

from PIL import Image

COLS, ROWS = 5, 4
PAD = 6
MAX_W = 512


def name_for(path):
    parts = path.split('/')
    if parts[0] == 'Weapons':
        return parts[1] + '_Stock'
    return parts[2] + '_' + parts[1]  # WeaponSkins/<Line>/<Gun> -> Gun_Line


def main(black_path, white_path, out_dir, items):
    os.makedirs(out_dir, exist_ok=True)
    b = Image.open(black_path).convert('RGB')
    w = Image.open(white_path).convert('RGB').resize(b.size)
    W, H = b.size
    bp, wp = b.load(), w.load()
    out = Image.new('RGBA', (W, H))
    op = out.load()
    for y in range(H):
        for x in range(W):
            br, bg_, bb = bp[x, y]
            wr, wg, wb = wp[x, y]
            a = 1 - ((wr - br) + (wg - bg_) + (wb - bb)) / (3 * 255)
            a = max(0.0, min(1.0, a))
            if a < 0.04:
                op[x, y] = (0, 0, 0, 0)
                continue
            op[x, y] = (min(255, round(br / a)), min(255, round(bg_ / a)), min(255, round(bb / a)), round(a * 255))
    cw, ch = W / COLS, H / ROWS
    saved = []
    for i, path in enumerate(items):
        col, row = i % COLS, i // COLS
        cell = out.crop((round(col * cw), round(row * ch), round((col + 1) * cw), round((row + 1) * ch)))
        box = cell.getbbox()
        if not box:
            continue
        l, t, r, btm = box
        cell = cell.crop((max(0, l - PAD), max(0, t - PAD), min(cell.width, r + PAD), min(cell.height, btm + PAD)))
        if cell.width > MAX_W:
            cell = cell.resize((MAX_W, round(cell.height * MAX_W / cell.width)), Image.LANCZOS)
        fn = os.path.join(out_dir, name_for(path) + '.png')
        cell.save(fn)
        saved.append(fn)
    print(len(saved), 'icons')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4].split(';'))
