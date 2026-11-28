"""Combine Strike Pack and Overdrive Pack charm review renders into 4x3 labeled contact sheets."""

import os
from PIL import Image, ImageDraw, ImageFont

REPO = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
ROOT = os.path.join(REPO, "art-source", "charms")

STRIKE = [
    ("DraftTicket", "DRAFT TICKET (Common)"),
    ("BrassBullet", "BRASS BULLET (Common)"),
    ("DogTags", "DOG TAGS (Common)"),
    ("FragPin", "FRAG PIN (Common)"),
    ("MiniHelmet", "MINI HELMET (Rare)"),
    ("TargetPlate", "TARGET PLATE (Rare)"),
    ("FragGrenade", "FRAG GRENADE (Rare)"),
    ("MicroBlade", "MICRO BLADE (Rare)"),
    ("MoltenCore", "MOLTEN CORE (Epic)"),
    ("GlitchDie", "GLITCH DIE (Epic)"),
    ("CrownTrophy", "CROWN TROPHY (Legendary)"),
    ("AceSkull", "ACE SKULL (Legendary)"),
]

OVERDRIVE = [
    ("HazardSign", "HAZARD SIGN (Common)"),
    ("BatteryCell", "BATTERY CELL (Common)"),
    ("CompassRose", "COMPASS ROSE (Common)"),
    ("Keycard", "KEYCARD (Common)"),
    ("DashWing", "DASH WING (Rare)"),
    ("FrostCrystal", "FROST CRYSTAL (Rare)"),
    ("ClockworkGear", "CLOCKWORK GEAR (Rare)"),
    ("MiniTsuba", "MINI TSUBA (Rare)"),
    ("PlasmaPrism", "PLASMA PRISM (Epic)"),
    ("PhantomLantern", "PHANTOM LANTERN (Epic)"),
    ("ReactorCore", "REACTOR CORE (Legendary)"),
    ("KillRadar", "KILL RADAR (Legendary)"),
]


def make_sheet(items, shot_name: str, out_name: str):
    cell_w, cell_h = 480, 520
    cols, rows = 4, 3
    canvas = Image.new("RGB", (cell_w * cols, cell_h * rows), (18, 21, 28))
    draw = ImageDraw.Draw(canvas)
    try:
        font = ImageFont.truetype("arialbd.ttf", 20)
    except Exception:
        font = ImageFont.load_default()

    for idx, (cid, label) in enumerate(items):
        r, c = divmod(idx, cols)
        x0, y0 = c * cell_w, r * cell_h
        img_path = os.path.join(ROOT, cid, "review", f"{shot_name}.png")
        if os.path.exists(img_path):
            im = Image.open(img_path).convert("RGB").resize((cell_w - 8, cell_w - 8), Image.Resampling.LANCZOS)
            canvas.paste(im, (x0 + 4, y0 + 4))
        draw.rectangle([x0 + 4, y0 + cell_w - 4, x0 + cell_w - 4, y0 + cell_h - 4], fill=(26, 30, 40))
        draw.text((x0 + 14, y0 + cell_w + 6), label, fill=(240, 244, 250), font=font)

    out_path = os.path.join(ROOT, out_name)
    canvas.save(out_path)
    return out_path


if __name__ == "__main__":
    p1 = make_sheet(STRIKE, "front_34", "review_strike_pack.png")
    p2 = make_sheet(STRIKE, "closeup_join", "review_strike_joins.png")
    p3 = make_sheet(OVERDRIVE, "front_34", "review_overdrive_pack.png")
    p4 = make_sheet(OVERDRIVE, "closeup_join", "review_overdrive_joins.png")
    print("WROTE", p1, p2, p3, p4)
