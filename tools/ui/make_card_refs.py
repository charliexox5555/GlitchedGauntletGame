"""Reference sheets for the Mod card art (vault/02 Art/UI Art Brief (ChatGPT).md → Card art v2).

    python tools/ui/make_card_refs.py

For every Mod: its real in-game model (a clean Studio capture on a dark stage) and its in-game effect
(a capture cropped clear of the HUD), side by side with the name, so ChatGPT draws OUR abilities.
Writes art-source/ui/chatgpt/card_refs/<Id>.png (1024 x 448 each) and card_refs/All.png (the 12 in
one sheet, 3 across). The source captures are listed in SOURCES (paths in the repo).
"""

import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "art-source", "ui", "chatgpt", "card_refs", "src")
OUT = os.path.join(ROOT, "art-source", "ui", "chatgpt", "card_refs")

# (file in card_refs/src, crop box as shares of the image: left, top, right, bottom)
PROP = (0.30, 0.22, 0.70, 0.78)
GAME = (0.18, 0.12, 0.82, 0.74)
SOURCES = {
    "Dash": [("dash_effect.jpg", (0.0, 0.0, 1.0, 0.75), "in game: wind strokes rush past on a dash")],
    "Updraft": [("updraft_effect.jpg", (0.0, 0.0, 1.0, 0.75), "in game: wind strokes rush upward")],
    "Molly": [("molly_prop.jpg", PROP, "the canister"), ("molly_effect.jpg", GAME, "its fire pool")],
    "Firewall": [("firewall_effect.jpg", (0.0, 0.10, 1.0, 0.74), "the fire wall")],
    "Frost": [("frost_prop.jpg", PROP, "the canister"), ("frost_effect.jpg", GAME, "its ice burst")],
    "Recon": [("recon_prop.jpg", PROP, "the bow + sensor dart"), ("recon_effect.jpg", GAME, "its scan pulse")],
    "HealOrb": [("healorb_prop.jpg", (0.28, 0.18, 0.72, 0.82), "the heal orb")],
    "Stim": [("stim_prop.jpg", PROP, "the beacon"), ("stim_effect.jpg", (0.25, 0.30, 0.85, 0.85), "its zone")],
    "Recall": [("recall_prop.jpg", PROP, "the anchor beacon")],
    "ShockDart": [("shockdart_prop.jpg", PROP, "the bow + shock bolt"), ("shockdart_effect.jpg", GAME, "its lightning blast")],
    "Flash": [("flash_prop.jpg", PROP, "the flare canister"), ("flash_effect.jpg", (0.1, 0.1, 0.9, 0.9), "the burst a flashed player sees")],
    "Roller": [("roller_prop.jpg", PROP, "the bot"), ("roller_effect.jpg", GAME, "its fire blast")],
}
ORDER = ["Dash", "Updraft", "Molly", "Firewall", "Frost", "Recon", "HealOrb", "Stim", "Recall", "ShockDart", "Flash", "Roller"]
TW, TH = 1024, 448
BG = (20, 24, 30)


def font(size):
    for f in ("arialbd.ttf", "segoeuib.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            pass
    return ImageFont.load_default()


def crop(path, box):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    return im.crop((int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h)))


def tile(name):
    t = Image.new("RGB", (TW, TH), BG)
    d = ImageDraw.Draw(t)
    d.text((18, 12), name, fill=(255, 255, 255), font=font(30))
    items = SOURCES[name]
    slot_w = (TW - 18 * (len(items) + 1)) // len(items)
    slot_h = TH - 60 - 40
    for i, (fname, box, label) in enumerate(items):
        im = crop(os.path.join(SRC, fname), box)
        im.thumbnail((slot_w, slot_h), Image.LANCZOS)
        x = 18 + i * (slot_w + 18) + (slot_w - im.width) // 2
        t.paste(im, (x, 60 + (slot_h - im.height) // 2))
        d.text((18 + i * (slot_w + 18), TH - 34), label, fill=(190, 198, 210), font=font(20))
    return t


def main():
    os.makedirs(OUT, exist_ok=True)
    tiles = []
    for name in ORDER:
        t = tile(name)
        t.save(os.path.join(OUT, name + ".png"))
        tiles.append(t)
    cols, scale = 3, 0.5
    w, h = int(TW * scale), int(TH * scale)
    sheet = Image.new("RGB", (w * cols, h * ((len(tiles) + cols - 1) // cols)), BG)
    for i, t in enumerate(tiles):
        sheet.paste(t.resize((w, h), Image.LANCZOS), ((i % cols) * w, (i // cols) * h))
    sheet.save(os.path.join(OUT, "All.png"))
    print("ok", len(tiles))


if __name__ == "__main__":
    main()
