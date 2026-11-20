"""Build the UI sound audition reel (vault/02 Art/UI Polish Pass.md -> Sounds).

    python -I tools/audio/ui_reel.py

Reads the two Kenney CC0 packs (Interface Sounds, UI Audio) as downloaded zips
in art-source/audio/downloads/kenney_ui/ (GitHub mirrors by Calinou; the
LICENSE.txt inside each says CC0), takes the candidates listed in ROLES,
and writes one reel, grouped by role, to art-source/audio/ui/UiReel.wav plus
UiReel.txt (time, role, number, file). Each role starts after a longer gap.
Nothing in the zips is ever run; only WAV data is read.
"""

import io
import os
import zipfile

import numpy as np
import soundfile as sf

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "art-source", "audio", "downloads", "kenney_ui")
OUT = os.path.join(ROOT, "art-source", "audio", "ui")
RATE = 44100
GAP, ROLE_GAP = 0.55, 1.6

IS = "kenney-interface-sounds.zip"
UA = "kenney-ui-audio.zip"

# role -> candidates (zip, file name). Kept short: a few per role.
ROLES = [
	("HoverBig (very quiet tick)", [(IS, "tick_001"), (IS, "tick_002"), (IS, "tick_004"), (UA, "rollover1"), (UA, "rollover2"), (IS, "select_001")]),
	("Click (press)", [(IS, "click_001"), (IS, "click_002"), (IS, "click_003"), (IS, "click_004"), (IS, "click_005"), (UA, "click1"), (UA, "click3"), (UA, "mouseclick1")]),
	("Confirm (queue, equip)", [(IS, "confirmation_001"), (IS, "confirmation_002"), (IS, "confirmation_003"), (IS, "confirmation_004"), (IS, "select_003"), (IS, "select_006")]),
	("Back / close", [(IS, "back_001"), (IS, "back_002"), (IS, "back_003"), (IS, "close_001"), (IS, "close_002"), (IS, "minimize_002")]),
	("Tab switch", [(IS, "switch_001"), (IS, "switch_002"), (IS, "switch_003"), (IS, "scroll_001"), (IS, "select_002")]),
	("Toggle on / off (pairs)", [(IS, "toggle_001"), (IS, "toggle_002"), (IS, "toggle_003"), (IS, "toggle_004"), (UA, "switch2"), (UA, "switch3")]),
	("Slider tick", [(IS, "tick_001"), (IS, "scroll_002"), (IS, "scroll_003"), (UA, "switch10")]),
	("Error / SOON", [(IS, "error_001"), (IS, "error_002"), (IS, "error_004"), (IS, "error_006"), (IS, "error_008")]),
	("Page open", [(IS, "open_001"), (IS, "open_002"), (IS, "open_003"), (IS, "maximize_001"), (IS, "maximize_003"), (IS, "maximize_006")]),
	("Queue join / match found", [(IS, "bong_001"), (IS, "glass_001"), (IS, "glass_002"), (IS, "glass_005"), (IS, "pluck_001"), (IS, "pluck_002")]),
	("Locker equip / skin switch", [(IS, "drop_001"), (IS, "drop_002"), (IS, "drop_003"), (IS, "drop_004"), (IS, "glitch_001"), (IS, "glitch_003")]),
]


def load(zips: dict, zip_name: str, name: str) -> np.ndarray:
	z = zips[zip_name]
	path = next(n for n in z.namelist() if n.endswith("/" + name + ".wav"))
	data, rate = sf.read(io.BytesIO(z.read(path)), dtype="float32", always_2d=True)
	mono = data.mean(axis=1)
	if rate != RATE:
		x = np.linspace(0, len(mono) - 1, int(len(mono) * RATE / rate))
		mono = np.interp(x, np.arange(len(mono)), mono).astype("float32")
	return mono


def main():
	zips = {n: zipfile.ZipFile(os.path.join(SRC, n)) for n in (IS, UA)}
	os.makedirs(OUT, exist_ok=True)
	parts, lines, t = [], [], 0.0
	for role, picks in ROLES:
		t += ROLE_GAP
		parts.append(np.zeros(int(ROLE_GAP * RATE), "float32"))
		lines.append(f"\n== {role} ==")
		for i, (zn, name) in enumerate(picks, 1):
			clip = load(zips, zn, name)
			pack = "IS" if zn == IS else "UA"
			lines.append(f"{t:7.2f}  {i}.  {pack}/{name}  ({len(clip) / RATE:.2f} s)")
			parts.append(clip)
			parts.append(np.zeros(int(GAP * RATE), "float32"))
			t += len(clip) / RATE + GAP
	reel = np.concatenate(parts)
	peak = float(np.max(np.abs(reel))) or 1.0
	reel = reel * min(1.0, 0.9 / peak)
	sf.write(os.path.join(OUT, "UiReel.wav"), reel, RATE, subtype="PCM_16")
	with open(os.path.join(OUT, "UiReel.txt"), "w", encoding="utf-8") as f:
		f.write("UI sound audition reel (Kenney CC0). IS = Interface Sounds, UA = UI Audio.\n")
		f.write("Pick one number per role. Roblox's own pack is auditioned in Studio.\n")
		f.write("\n".join(lines) + "\n")
	print(f"{t:.1f} s, {sum(len(p) for _, p in ROLES)} clips -> art-source/audio/ui/UiReel.wav")


if __name__ == "__main__":
	main()
