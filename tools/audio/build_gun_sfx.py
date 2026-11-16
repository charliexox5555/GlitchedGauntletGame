"""SUPERSEDED 2026-11-13: the gun atlas is now built from the bought pro pack
by tools/audio/build_pro_atlas.py (owner: "a fresh pack with all these
sounds"). This script is kept for the record; running it would overwrite
Config/GunAtlas with the old v2 slices, so don't (or use --no-luau).

Build the gun sound atlas (2026-11-08): every gun's shots and handling
foley in ONE audio asset, separate from the shared atlas (that one is at
360 s / 18 MB, close to Roblox's 7 min / 20 MB audio limits).

    python -I tools/audio/build_gun_sfx.py             # atlas + Luau tables
    python -I tools/audio/build_gun_sfx.py --preview   # also the audition reel

Real recordings only, polished (EQ, transient, trimmed tail, glue
compression, loudness, a baked base pitch). No synthesis, no layering.

Sources
  SNK  "Snake's SECOND Authentic Gun Sounds Pack" (SnakeF8 / F8 Studios,
       itch.io): 9mm, .308 and 20 gauge shots, pistol / revolver / mag /
       bipod foley. Free; "can be used commercially, and credit is not
       needed"; the author calls it public domain. In the vault at
       vault/06 Assets/GunSoundEffectLibrary (not committed).
  FFL  "The Free Firearm Sound Library" (CC0), art-source/audio/library.
  GAME the handling foley slices already in the shared atlas
       (art-source/audio/GameAtlas.flac; CC0 Freesound recordings, sources in
       the vault note "2026-11-05 Knife and Sound Pass"), re-levelled.

Loudness (LihFolk lihfolk-sfx: one-shots at one loudness, the mix in
`volume`), measured as the loudest 100 ms, K-weighted (short_max; handling
clicks are 50-300 ms, which a 400 ms momentary window under-reads): shots
-11.5 (pistols) to -8.5 (snipers), suppressed -13; handling -15 (it sat
about 6 dB lower before), draws and inspects -17; every slice under
-1 dBTP. A click that can't reach its target without more than 6 dB of
limiting gets up to 2x Sound.Volume in the generated sets instead. Automatic guns get a short shot plus a separate tail that the game
plays when the trigger is let go (the shot slice crossfades into it at
TAIL_AFTER x fireInterval), so sprays stay punchy instead of a smear.

Writes:
  art-source/audio/GunSfx.flac            48 kHz stereo 16-bit (uploaded as Sounds.GUN_ATLAS)
  art-source/audio/GunSfx.json            name -> [{start, length}]
  src/shared/Config/GunAtlas.luau         the same, for the game
  src/shared/Config/GunSoundSets.luau     every gun's sound set (Config/GunSounds reads it)
  art-source/audio/GunSfxPreview.wav      --preview: every gun's actions at game volumes
  art-source/audio/GunSfxPreview.txt      --preview: what plays when
"""

import argparse
import json
import os
import re
import sys

import numpy as np
import soundfile as sf
from scipy import signal

sys.path.insert(0, os.path.dirname(__file__))
from analyze_audio import k_weight, momentary_max  # noqa: E402
from build_sound_atlas import (  # noqa: E402
	compress,
	eq,
	hp,
	loudness,
	lp,
	mono,
	resample,
	soft_clip,
	stereo,
	tighten,
	transient,
)
from build_sfx import limit, true_peak_db  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SNK = os.path.join(ROOT, "vault", "06 Assets", "GunSoundEffectLibrary")
FFL = os.path.join(ROOT, "art-source", "audio", "library", "Prepared SFX Library")
GAME_AUDIO = os.path.join(ROOT, "art-source", "audio", "GameAtlas.flac")
GAME_JSON = os.path.join(ROOT, "art-source", "audio", "GameAtlas.json")
OUT_AUDIO = os.path.join(ROOT, "art-source", "audio", "GunSfx.flac")
OUT_JSON = os.path.join(ROOT, "art-source", "audio", "GunSfx.json")
OUT_ATLAS = os.path.join(ROOT, "src", "shared", "Config", "GunAtlas.luau")
OUT_SETS = os.path.join(ROOT, "src", "shared", "Config", "GunSoundSets.luau")
OUT_PREVIEW = os.path.join(ROOT, "art-source", "audio", "GunSfxPreview.wav")
OUT_CUES = os.path.join(ROOT, "art-source", "audio", "GunSfxPreview.txt")
WEAPONS = os.path.join(ROOT, "src", "shared", "Config", "Weapons.luau")
ANIMS = os.path.join(ROOT, "src", "shared", "WeaponAnimations")
RATE = 48000
GAP = 0.2
TAIL_AFTER = 1.5  # Config/Audio TAIL_AFTER: the tail starts this many fireIntervals after the last shot
XFADE = 0.03
TAIL_UNDER = 5.0

# Mix: the files are level-matched, so every gun uses the same volumes.
FIRE_VOL = 0.85
FAR_VOL = 0.9
FOLEY_VOL = 0.8
DRAW_VOL = 0.7
INSPECT_VOL = 0.6
GROUP = {"Gun": 0.9, "Foley": 0.75}  # Config/Audio GROUP_VOLUME, for the preview

S9 = "Full Sounds/9mm/WAV/9mm "
S308 = "Full Sounds/.308 (7.62x51)/WAV/308 "
S20 = "Full Sounds/20 Gauge/WAV/20 Gauge "
SP = "& More/Pistol/WAV/9mm Pistol "
SR32 = "& More/Revolver/32 SW Long/WAV/32 SW "
SR44 = "& More/Revolver/44 Magnum/WAV/44 Magnum "
SM = "& More/Mag Pack/WAV/"
SB = "& More/Bipod/WAV/Bipod "

# Shots ------------------------------------------------------------------------
# Class presets (as the old atlas, retuned: the old suppressed class sat 3.5 dB
# under the others behind a 2.6-3 kHz low-pass, which made those guns quiet and
# dull). length: semi-auto shot slice (s); hold/tau: tail kept, then decays;
# low/presence/air: shelf at 100 Hz, peak at 3.2 kHz, shelf at 10 kHz (dB);
# punch: transient boost (dB); target: loudest 100 ms (short_max, K-weighted
# dB; foley uses the same scale); lowpass/dark:
# suppressors (a gentle 1-pole roll-off and a high shelf, not a muffle).
CLASSES = {
	"pistol": dict(length=0.75, hold=0.07, tau=0.14, low=1, presence=2.5, air=2, punch=4, target=-11.5),
	"magnum": dict(length=1.0, hold=0.09, tau=0.2, low=3, presence=2, air=2, punch=4.5, target=-10.5),
	"small": dict(length=0.55, hold=0.04, tau=0.09, low=0.5, presence=3, air=2.5, punch=3.5, target=-12.0),
	"smg": dict(length=0.6, hold=0.05, tau=0.1, low=1.5, presence=3, air=2, punch=3.5, target=-11.5),
	"rifle": dict(length=0.85, hold=0.07, tau=0.15, low=2, presence=2.5, air=2, punch=4, target=-10.5),
	"marksman": dict(length=1.1, hold=0.1, tau=0.24, low=2.5, presence=2.5, air=2, punch=4.5, target=-9.5),
	"mg": dict(length=0.8, hold=0.06, tau=0.14, low=3, presence=2, air=1.5, punch=3.5, target=-10.5),
	"sniper": dict(length=1.8, hold=0.15, tau=0.42, low=3, presence=2.5, air=2, punch=5, target=-8.5),
	"shotgun": dict(length=1.1, hold=0.1, tau=0.22, low=3, presence=2, air=1.5, punch=4.5, target=-9.5),
	"suppressed": dict(
		length=0.5, hold=0.025, tau=0.06, low=2, presence=1, air=-1, punch=3, target=-13.0, lowpass=5500, dark=-4
	),
}

# Gun: fire recording(s). takes: (file, shot index; -1 = the last, clean-
# tailed shot of a burst); pitches: baked per take (pads to 3 variants);
# far: the mid-distance mic (FFL) or None (darkened near take, SNK).
# Each gun has its own recording or its own takes of one; see the vault
# note "2026-11-08 Gun Sound Overhaul" for the themes.
GUNS = {
	# Sidearms
	"Classic": dict(cls="pistol", pitch=1.0, takes=[(("SNK", S9 + "Single.wav"), 0), (("SNK", S9 + "Slow Burst.wav"), -1)]),
	"Ghost": dict(cls="suppressed", pitch=1.02, takes=[(("FFL", "Walther PPQ/X_39P.wav"), i) for i in (0, 1, 2)], far=("FFL", "Walther PPQ/X_31P.wav")),
	"Akimbo": dict(cls="small", pitch=1.06, takes=[(("FFL", "Bersa/F_47P.wav"), i) for i in (0, 1)], far=("FFL", "Bersa/F_41P.wav")),
	"Sheriff": dict(cls="magnum", pitch=0.92, takes=[(("FFL", "Smith & Wesson 642/V_27P.wav"), i) for i in (0, 1)], far=("FFL", "Smith & Wesson 642/V_22P.wav")),
	"Shorty": dict(cls="shotgun", pitch=1.05, takes=[(("FFL", "Mossberg/N_30P.wav"), i) for i in (0, 1)], far=("FFL", "Mossberg/N_26P.wav")),
	# SMGs and shotguns
	"Stinger": dict(cls="smg", pitch=1.05, takes=[(("SNK", S9 + "Burst.wav"), -1), (("SNK", S9 + "Spray.wav"), -1), (("SNK", S9 + "Slow Burst.wav"), 0), (("SNK", S9 + "Slow Burst.wav"), 1)]),
	"Spectre": dict(cls="suppressed", pitch=1.0, takes=[(("FFL", "Carl Gustav M45/G_31P.wav"), 0), (("FFL", "Carl Gustav M45/G_33P.wav"), "c0"), (("FFL", "Carl Gustav M45/G_33P.wav"), "c1"), (("FFL", "Carl Gustav M45/G_35P.wav"), -1)], far=("FFL", "Carl Gustav M45/G_20P.wav")),
	"Bucky": dict(cls="shotgun", pitch=0.94, takes=[(("SNK", S20 + "Single.wav"), 0)]),
	"Judge": dict(cls="shotgun", pitch=1.02, takes=[(("SNK", S20 + "Burst.wav"), -1), (("SNK", S20 + "Spray.wav"), -1), (("SNK", S20 + "Slow Burst.wav"), -1)]),
	# Rifles
	"Vandal": dict(cls="rifle", pitch=1.0, takes=[(("SNK", S308 + "Burst.wav"), -1), (("SNK", S308 + "Spray.wav"), -1)]),
	"Phantom": dict(cls="suppressed", pitch=1.0, takes=[(("FFL", "AR-15/D_32P.wav"), i) for i in (0, 1)], far=("FFL", "AR-15/D_24P.wav")),
	"Bulldog": dict(cls="rifle", pitch=1.03, takes=[(("FFL", "Savage 10 .300 Blackout/T_27P.wav"), i) for i in (0, 1)], far=("FFL", "Savage 10 .300 Blackout/T_17P.wav")),
	"Guardian": dict(cls="marksman", pitch=0.96, takes=[(("SNK", S308 + "Single.wav"), 0)]),
	# Snipers and machine guns
	"Marshal": dict(cls="marksman", pitch=1.0, takes=[(("FFL", "Marlin 336/I_22P.wav"), i) for i in (0, 1)], far=("FFL", "Marlin 336/I_17P.wav")),
	"Outlaw": dict(cls="sniper", pitch=0.96, takes=[(("FFL", "Mosin Nagant/M_21P.wav"), i) for i in (0, 1, 2)], far=("FFL", "Mosin Nagant/M_26P.wav")),
	"Operator": dict(cls="sniper", pitch=0.97, takes=[(("FFL", "Tikka/W_29P.wav"), i) for i in (0, 1)], far=("FFL", "Tikka/W_24P.wav")),
	"Ares": dict(cls="mg", pitch=0.95, takes=[(("FFL", "AK-47/C_27P.wav"), "c0"), (("FFL", "AK-47/C_27P.wav"), "c1"), (("FFL", "AK-47/C_29P.wav"), "c0"), (("FFL", "AK-47/C_29P.wav"), "c1")], far=("FFL", "AK-47/C_36P.wav")),
	"Odin": dict(cls="mg", pitch=0.97, takes=[(("FFL", "1917/B_24P.wav"), i) for i in (0, 1)], far=("FFL", "1917/B_16P.wav")),
}

# Foley -----------------------------------------------------------------------
# Slice name -> takes: (source, file or GAME slice, start s, max length s, kind).
# kind "hit": the head trimmed to 3 ms before the first transient (so it lands
# on the clip beat); "swell": keeps the build-up (slides, bipod legs, draws).
FOLEY = {
	"P9DryFire": [("SNK", SP + "Dry Fire.wav", 0, 0.3, "hit")],
	"P9RackPull": [("SNK", SP + "Rack Part 1.wav", 0, 0.45, "swell")],
	"P9RackRelease": [("SNK", SP + "Rack Part 2.wav", 0, 0.45, "hit")],
	"P9SlideLock": [("SNK", SP + "Slide Lock.wav", 0, 0.34, "hit")],
	"P9SlideRelease": [("SNK", SP + "Slide Release.wav", 0, 0.3, "hit")],
	"P9ChamberCheck": [("SNK", SP + "Chamber Check Full.wav", 0, 1.1, "swell")],
	"P9MagOut": [("SNK", SP + "Reload 1.wav", 0, 0.36, "hit")],
	"P9MagIn": [("SNK", SP + "Reload 2.wav", 0, 0.42, "hit")],
	"R32Open": [("SNK", SR32 + "Open Cylinder Full.wav", 0, 0.45, "swell")],
	"R32Close": [("SNK", SR32 + "Close Cylinder.wav", 0, 0.4, "hit")],
	"R32Cock": [("SNK", SR32 + "Hammer Cock.wav", 0, 0.5, "hit")],
	"R32Decock": [("SNK", SR32 + "Hammer Decock.wav", 0, 0.3, "hit")],
	"R32Rotate": [("SNK", SR32 + "Rotate Cylinder.wav", 0, 0.4, "hit")],
	"R32Eject": [("SNK", SR32 + "Eject One Casing.wav", 0.25, 0.8, "hit")],
	"R44Open": [("SNK", SR44 + "Open Cylinder.wav", 0.1, 0.45, "hit")],
	"R44Close": [("SNK", SR44 + "Close Cylinder.wav", 0, 0.3, "hit")],
	"R44Cock": [("SNK", SR44 + "Cock Hammer.wav", 0, 0.4, "hit")],
	"R44Decock": [("SNK", SR44 + "Decock Hammer.wav", 0, 0.28, "hit")],
	"R44Eject": [("SNK", SR44 + "Eject Part 1 With Floor Impact.wav", 0, 1.2, "hit")],
	"R44EjectFloor": [("SNK", SR44 + "Eject Floor Impact.wav", 0, 0.65, "swell")],
	"R44Load": [("SNK", SR44 + "Single Load.wav", 0, 0.32, "hit")],
	"ShellLoad": [("SNK", SM + "Single Shotgun Load.wav", 0, 0.42, "hit")],
	"RoundAR": [("SNK", SM + "AR PolyMag Pack.wav", 0, 0.5, "swell")],
	"RoundAK": [("SNK", SM + "AK PolyMag Pack.wav", 0, 0.34, "swell")],
	"RoundBolt": [("SNK", SM + "Bolt Mag Pack.wav", 0.1, 0.48, "hit")],
	"UnpackAR": [("SNK", SM + "AR PolyMag Unpack.wav", 0, 0.42, "swell")],
	"BipodDeploy": [("SNK", SB + "Deploy One Leg.wav", 0, 0.7, "swell")],
	"BipodRaise": [("SNK", SB + "Raise One Leg.wav", 0, 0.36, "hit")],
	"BipodImpact": [("SNK", SB + "Impact One Leg.wav", 0, 0.25, "hit")],
	"BipodImpact2": [("SNK", SB + "Impact Both Legs.wav", 0, 0.35, "hit")],
}
for slice_name, n in {
	"RifleMagOut": 2, "RifleMagIn": 2, "RifleRack": 3, "SmgMagOut": 1, "SmgMagIn": 1, "SmgRack": 1,
	"PistolMagOut": 2, "PistolMagIn": 2, "PistolRack": 3, "ShotgunPump": 3, "ShellIn": 3, "Bolt": 2,
	"Lever": 2, "RevolverRack": 3, "DrawPistol": 2, "DrawRifle": 2,
}.items():
	FOLEY[slice_name] = [("GAME", "Foley" + slice_name, i, 0, "game") for i in range(n)]

FOLEY_DEFAULT = -15.0  # loudest 100 ms (short_max): handling
FOLEY_TARGET = {"DrawPistol": -17, "DrawRifle": -17, "P9ChamberCheck": -17, "BipodDeploy": -17, "R32Rotate": -17}


# Field -> (slice, pitch lo, pitch hi) per gun. Fields: Config/GunSounds.
def F(slice_name, lo=0.97, hi=1.03):
	return (slice_name, lo, hi)


def P(c, d=0.025):
	return (c - d, c + d)


SETS = {
	# 9 mm duty pistol: the Snake pack's own pistol, slide snapping home.
	"Classic": dict(draw=F("DrawPistol"), rack=F("P9RackRelease"), magOut=F("P9MagOut"), magIn=F("P9MagIn"), inspect=F("P9ChamberCheck"), dryFire=F("P9DryFire")),
	# Quiet operator: a Glock's mag, the slide-release lever, a slide lock to show off.
	"Ghost": dict(draw=F("DrawPistol", *P(1.04)), rack=F("P9SlideRelease"), magOut=F("PistolMagOut"), magIn=F("PistolMagIn"), inspect=F("P9SlideLock"), dryFire=F("P9DryFire", *P(1.08))),
	# Two small pistols: everything a size smaller and quicker.
	"Akimbo": dict(draw=F("DrawPistol", *P(1.08)), rack=F("PistolRack", *P(1.08)), magOut=F("P9MagOut", *P(1.1)), magIn=F("P9MagIn", *P(1.1)), inspect=F("P9RackPull", *P(1.1)), dryFire=F("P9DryFire", *P(1.15))),
	# .44 hand cannon: the Magnum's cylinder, cases on the floor, a cylinder spin.
	"Sheriff": dict(draw=F("DrawPistol", *P(0.95)), rack=F("R44Cock"), open=F("R44Open"), eject=F("R44Eject"), shellIn=F("R44Load"), close=F("R44Close"), inspect=F("R32Rotate", *P(0.95)), dryFire=F("R44Decock")),
	# Coach-gun pocket shotgun: light action, a hard snap shut, hammers.
	"Shorty": dict(draw=F("DrawRifle", *P(1.06)), open=F("R32Open", *P(0.85)), shellIn=F("ShellLoad", *P(1.05)), close=F("BipodImpact", *P(0.9)), rack=F("R32Cock", *P(0.9)), inspect=F("R32Cock", *P(0.9)), dryFire=F("R32Decock", *P(0.9))),
	# Uzi: the Uzi session's own mag and bolt.
	"Stinger": dict(draw=F("DrawRifle", *P(1.08)), magOut=F("SmgMagOut"), magIn=F("SmgMagIn"), rack=F("SmgRack"), inspect=F("P9RackPull", *P(0.95)), dryFire=F("P9DryFire")),
	# Suppressed SMG: slim pistol-style mag, an HK-style slap.
	"Spectre": dict(draw=F("DrawRifle", *P(1.04)), magOut=F("PistolMagOut", *P(0.95)), magIn=F("PistolMagIn", *P(0.95)), rack=F("P9RackRelease", *P(0.9)), inspect=F("P9SlideLock", *P(0.9)), dryFire=F("P9DryFire", *P(1.04))),
	# Pump: the pump, real shells into the tube.
	"Bucky": dict(draw=F("DrawRifle", *P(0.97)), rack=F("ShotgunPump"), shellIn=F("ShellLoad"), inspect=F("ShotgunPump", *P(1.08)), dryFire=F("P9DryFire", *P(0.82))),
	# Drum shotgun: heavy drum, rattling shells.
	"Judge": dict(draw=F("DrawRifle", *P(0.94)), magOut=F("SmgMagOut", *P(0.8)), magIn=F("RifleMagIn", *P(0.85)), rack=F("SmgRack", *P(0.85)), inspect=F("RoundAK", *P(0.8)), dryFire=F("P9DryFire", *P(0.8))),
	# Battle rifle: AR / AK mag work and charging handle.
	"Vandal": dict(draw=F("DrawRifle"), magOut=F("RifleMagOut"), magIn=F("RifleMagIn"), rack=F("RifleRack"), inspect=F("RoundAK"), dryFire=F("P9DryFire", *P(0.9))),
	# Suppressed carbine: the same family, lighter and quicker.
	"Phantom": dict(draw=F("DrawRifle", *P(1.03)), magOut=F("RifleMagOut", *P(1.05)), magIn=F("RifleMagIn", *P(1.05)), rack=F("RifleRack", *P(1.06)), inspect=F("RoundAR"), dryFire=F("P9DryFire", *P(0.95))),
	# Budget bullpup: rifle mags, an SMG-style cocking handle.
	"Bulldog": dict(draw=F("DrawRifle"), magOut=F("RifleMagOut", *P(0.95)), magIn=F("RifleMagIn", *P(0.95)), rack=F("SmgRack", *P(0.95)), inspect=F("UnpackAR"), dryFire=F("P9DryFire", *P(0.92))),
	# DMR: heavier mag, a round pressed into a bolt-gun mag.
	"Guardian": dict(draw=F("DrawRifle", *P(0.97)), magOut=F("RifleMagOut", *P(0.92)), magIn=F("RifleMagIn", *P(0.92)), rack=F("RifleRack", *P(0.92)), inspect=F("RoundBolt"), dryFire=F("P9DryFire", *P(0.88))),
	# Lever gun: the lever, rounds through the gate, a hammer.
	"Marshal": dict(draw=F("DrawRifle", *P(0.98)), rack=F("Lever"), shellIn=F("ShellIn"), inspect=F("RoundBolt", *P(0.9)), dryFire=F("R32Decock", *P(0.9))),
	# Double rifle: the big action drops, big brass on the floor, a heavy clunk shut.
	"Outlaw": dict(draw=F("DrawRifle", *P(0.95)), open=F("R44Open", *P(0.8)), eject=F("R44EjectFloor", *P(0.9)), shellIn=F("R44Load", *P(0.82)), close=F("BipodImpact2", *P(0.85)), rack=F("BipodImpact2", *P(0.85)), inspect=F("R44Cock", *P(0.85)), dryFire=F("R44Decock", *P(0.85))),
	# Bolt sniper: the bolt, a mag in the stock.
	"Operator": dict(draw=F("DrawRifle", *P(0.94)), magOut=F("RifleMagOut", *P(0.9)), magIn=F("RifleMagIn", *P(0.9)), rack=F("Bolt"), inspect=F("RoundBolt", *P(0.95)), dryFire=F("P9DryFire", *P(0.78))),
	# LMG: bipod legs on the draw and the inspect, a heavy drum.
	"Ares": dict(draw=F("BipodRaise"), magOut=F("RifleMagOut", *P(0.86)), magIn=F("RifleMagIn", *P(0.86)), rack=F("RifleRack", *P(0.88)), inspect=F("BipodDeploy"), dryFire=F("P9DryFire", *P(0.85))),
	# HMG: ammo box, feed cover up and slammed shut, the deepest handle.
	"Odin": dict(draw=F("BipodRaise", *P(0.9)), magOut=F("RifleMagOut", *P(0.8)), magIn=F("RifleMagIn", *P(0.8)), open=F("R32Open", *P(0.9)), close=F("BipodImpact"), rack=F("RifleRack", *P(0.82)), inspect=F("BipodDeploy", *P(0.9)), dryFire=F("P9DryFire", *P(0.8))),
}
FIELD_VOL = {"draw": DRAW_VOL, "inspect": INSPECT_VOL}

# Loading ----------------------------------------------------------------------
_cache = {}


def path_of(src):
	kind, rel = src
	return os.path.join(SNK if kind == "SNK" else FFL, rel)


def load(src):
	p = path_of(src)
	if p not in _cache:
		x, sr = sf.read(p, always_2d=True)
		x = x[:, :2] if x.shape[1] >= 2 else np.repeat(x, 2, axis=1)
		if sr != RATE:
			x = signal.resample_poly(x, RATE, sr, axis=0)
		_cache[p] = x - x[:256].mean(axis=0)
	return _cache[p]


def shot_onsets(x):
	"""(onset sample, samples to the next shot) for every full-power shot.
	The Snake recordings have a strong slap 100 ms after each shot (6-8 dB
	down): the 0.5 threshold skips it."""
	m = np.abs(x).max(axis=1)
	hop = RATE // 1000
	n = len(m) // hop
	env = m[: n * hop].reshape(n, hop).max(axis=1)
	peaks, _ = signal.find_peaks(env, height=env.max() * 0.5, distance=70)
	out = []
	for k, p in enumerate(peaks):
		j = p
		lo = p - 15 if k == 0 else max(p - 15, (peaks[k - 1] + p) // 2)
		while j > lo and env[j - 1] < env[j] and env[j - 1] > env[p] * 0.02:
			j -= 1
		o = max(0, j * hop - int(RATE * 0.0008))
		if out and o - out[-1] < RATE * 0.09:
			continue  # the slap of the shot before (the .308 one comes 70 ms after)
		out.append(o)
	return [(o, (out[i + 1] - o) if i + 1 < len(out) else len(x) - o) for i, o in enumerate(out)]


def raw_shot(src, index, pitch, length):
	x = load(src)
	found = shot_onsets(x)
	if isinstance(index, str):  # "c<k>": the k-th clean-tailed shot (the last of a burst)
		found = [f for f in found if f[1] > RATE * 0.5]
		index = int(index[1:])
	onset, room = found[index]
	n = int(RATE * (length * pitch + 0.05))
	seg = x[onset : onset + min(n, room)]
	if pitch != 1:
		seg = resample(seg, 1 / pitch)
	return seg, room / RATE / pitch


# Polish -----------------------------------------------------------------------


def fade(x, fin, fout):
	x = x.copy()
	a, b = int(RATE * fin), int(RATE * fout)
	if a:
		x[:a] *= (0.5 - 0.5 * np.cos(np.linspace(0, np.pi, a)))[:, None]
	if b:
		x[-b:] *= (0.5 + 0.5 * np.cos(np.linspace(0, np.pi, b)))[:, None]
	return x


def pad_to(x, n):
	x = stereo(x)[:n]
	return np.pad(x, ((0, n - len(x)), (0, 0))) if len(x) < n else x


def tp_db(y):
	return max(true_peak_db(y[:, 0]), true_peak_db(y[:, 1]))


def tp_limit(y, ceiling=-1.0, release=0.04):
	"""True-peak limiter: inter-sample peaks found at 4x, 1 ms lookahead,
	the same gain on both channels."""
	if tp_db(y) <= ceiling:
		return y
	target = 10 ** ((ceiling - 0.15) / 20)
	n = len(y)
	up = np.abs(signal.resample_poly(y, 4, 1, axis=0)).max(axis=1)[: n * 4]
	up = np.pad(up, (0, n * 4 - len(up)))
	pk = up.reshape(n, 4).max(axis=1)
	need = np.minimum(1.0, target / np.maximum(pk, 1e-9))
	look = int(RATE * 0.001)
	need = np.lib.stride_tricks.sliding_window_view(np.pad(need, (0, look), mode="edge"), look + 1).min(axis=1)
	g = np.empty(n)
	cur, a = 1.0, np.exp(-1 / (release * RATE))
	for i, v in enumerate(need.tolist()):
		cur = v if v < cur else a * cur + (1 - a) * v
		g[i] = cur
	return y * g[:, None]


def master_tp(x, target):
	"""Match the loudest 100 ms after soft clipping (enough passes to converge
	on the peaky library shots, which the old 4 passes left 2-3 dB short),
	then a -1 dBTP limiter."""
	g = target - short_max(x)
	y = x
	for _ in range(12):
		y = soft_clip(x * 10 ** (g / 20))
		err = target - short_max(y)
		if abs(err) < 0.1:
			break
		g += err
	return tp_limit(y)


def polish_shot(x, c, length, auto=False):
	x = hp(x, 45, 4)
	if c.get("lowpass"):
		x = lp(x, c["lowpass"], 1)
	x = eq(x, [
		("low", 100, c["low"]),
		("peak", 330, -2.5, 0.9),
		("peak", 3200, c["presence"], 0.8),
		("high", 10000, c["air"]),
	] + ([("high", 6000, c["dark"])] if c.get("dark") else []))
	x = transient(x, c["punch"])
	# Automatic guns: during a spray the shot is cut at TAIL_AFTER x fireInterval
	# anyway, so the tail (heard only on release) keeps more of the recording's room.
	k = 2.2 if auto else 1.0
	x = tighten(x, c["hold"] * k, c["tau"] * k)
	x = compress(x, -18, 2.5, 0.004, 0.09)
	x = fade(pad_to(x, int(RATE * length)), 0.0015, length * 0.3)
	return master_tp(x, c["target"])


def polish_far(x, c, length):
	x = stereo(mono(x))
	x = hp(x, 110, 4)
	x = lp(x, min(c.get("lowpass", 99999), 4800), 2)
	x = eq(x, [("low", 160, -2.0), ("peak", 2500, 1.5, 0.8)])
	x = tighten(x, c["hold"] * 1.6, c["tau"] * 2.2)
	x = compress(x, -20, 2.0, 0.005, 0.12)
	x = fade(pad_to(x, int(RATE * length)), 0.0015, length * 0.35)
	return master_tp(x, c["target"] - 2.5)


def weapon_data():
	"""fireInterval, fireMode, reload times and shell reloads, read from Config/Weapons."""
	text = open(WEAPONS, encoding="utf-8").read()
	out = {}
	for m in re.finditer(r"\n\t(\w+) = \{\n(.*?)\n\t\},", text, re.S):
		body = m.group(2)

		def num(key, b=body):
			f = re.search(r"\b" + key + r" = ([0-9.]+)", b)
			return float(f.group(1)) if f else None

		mode = re.search(r'fireMode = "(\w+)"', body)
		shell = re.search(r"shellReload = \{ start = ([0-9.]+), insert = ([0-9.]+), finish = ([0-9.]+)", body)
		out[m.group(1)] = dict(
			fireInterval=num("fireInterval"),
			fireMode=mode.group(1) if mode else "Semi",
			magSize=num("magSize"),
			reloadTime=num("reloadTime"),
			emptyReloadTime=num("emptyReloadTime"),
			drawTime=num("drawTime") or num("equipTime"),
			shell=tuple(map(float, shell.groups())) if shell else None,
		)
	return out


# 2026-11-09: every gun's shot is designed (tools/audio/design_gun_sfx.py
# DESIGNS: layered real pro mics, Valorant-style). Set False to go back to the
# single polished recordings in GUNS (the 2026-11-08 overhaul).
USE_DESIGNS = True
_designs = None


def designs():
	global _designs
	if _designs is None:
		import design_gun_sfx

		_designs = design_gun_sfx
	return _designs


def split_auto(name, y, w, near, tails):
	"""An automatic gun's shot: a short slice (to TAIL_AFTER x fireInterval,
	crossfading) and the rest as its release tail, kept TAIL_UNDER dB under."""
	d = TAIL_AFTER * w["fireInterval"]
	n, xf = int(RATE * d), int(RATE * XFADE)
	near.append(fade(y[: n + xf], 0, XFADE))
	tail = fade(y[n:], XFADE, 0.2)
	over = short_max(tail) - (short_max(y) - TAIL_UNDER)
	tails.append(tail * 10 ** (-max(over, 0) / 20))


def gun_shots(name, w):
	"""Near shot variants, the auto tail variants (or []), far variants."""
	g = GUNS[name]
	c = CLASSES[g["cls"]]
	auto = w["fireMode"] == "Auto"
	if USE_DESIGNS and name in designs().DESIGNS:
		D = designs()
		full_len = max(c["length"], 0.9) if auto else c["length"]
		near, tails = [], []
		for k in range(3):
			y = D.designed(name, k, full_len, auto)
			if auto:
				split_auto(name, y, w, near, tails)
			else:
				near.append(y)
		far_len = min(1.9, c["length"] * 1.4 + 0.3)
		far = [polish_far(stereo(D.far_raw(name, far_len + 0.1)), dict(c, target=D.target(name)), far_len)]
		return near, tails, far, ["designed: " + ", ".join(sp[0] for sp in D.DESIGNS[name]["layers"])]
	takes = list(g["takes"])
	pitches = [1.0] * len(takes)
	while len(takes) < 3:  # too few separate shots: bake a small pitch change instead
		k = len(takes)
		takes.append(takes[k % len(g["takes"])])
		pitches.append((0.975, 1.025)[k % 2])
	full_len = max(c["length"], 0.9) if auto else c["length"]
	near, tails, info = [], [], []
	for (src, index), p in zip(takes, pitches):
		raw, room = raw_shot(src, index, g["pitch"] * p, full_len + 0.1)
		y = polish_shot(raw, c, full_len, auto)
		if auto:
			d = TAIL_AFTER * w["fireInterval"]
			if d + XFADE > room:
				print(f"  ! {name}: take {src[1]}#{index} only has {room:.3f}s before the next shot (need {d + XFADE:.3f})")
			n, xf = int(RATE * d), int(RATE * XFADE)
			near.append(fade(y[: n + xf], 0, XFADE))
			tail = fade(y[n:], XFADE, 0.2)
			# A boomy recording (the 1917) is louder after the crack than in it:
			# keep every tail at least TAIL_UNDER dB under its shot.
			over = short_max(tail) - (short_max(y) - TAIL_UNDER)
			tails.append(tail * 10 ** (-max(over, 0) / 20))
		else:
			near.append(y)
		info.append(f"{src[0]} {src[1]} #{index} x{g['pitch'] * p:.3f}")
	far = []
	far_len = min(1.9, c["length"] * 1.4 + 0.3)
	if g.get("far"):
		raw, _ = raw_shot(g["far"], 0, g["pitch"], far_len + 0.1)
		far.append(polish_far(raw, c, far_len))
	else:
		for (src, index), p in list(zip(takes, pitches))[:2]:
			raw, _ = raw_shot(src, index, g["pitch"] * p, far_len + 0.1)
			far.append(polish_far(raw, c, far_len))
	return near, tails, far, info


# Foley -----------------------------------------------------------------------
_game = None


def game_slice(name, i):
	global _game
	if _game is None:
		_game = (sf.read(GAME_AUDIO, always_2d=True)[0], json.load(open(GAME_JSON)))
	audio, regions = _game
	r = regions[name][i]
	a = int(round(r["start"] * RATE))
	return audio[a : a + int(round(r["length"] * RATE))].copy()


def env_db(x):
	m = mono(x)
	k = np.ones(48) / 48
	return 20 * np.log10(np.sqrt(np.convolve(m * m, k, mode="same")) + 1e-9)


def short_max(y, window=0.1):
	"""Loudest 100 ms (BS.1770 K-weighted): handling sounds are 50-300 ms
	clicks, which a 400 ms momentary window would read 5-10 dB too quiet."""
	k = k_weight(mono(y))
	w = int(window * RATE)
	if len(k) < w:
		k = np.pad(k, (0, w - len(k)))
	c = np.concatenate([[0.0], np.cumsum(k * k)])
	return float(-0.691 + 10 * np.log10(max(((c[w:] - c[:-w]) / w).max(), 1e-12)))


MAX_LIMIT = 6.0  # dB: a click that can only get there by more limiting stays quieter...
MAX_BOOST = 2.0  # ...and gets up to this much Sound.Volume instead (Config/GunSoundSets)
TARGETS = {}  # slice -> the loudness it was aimed at


def level(y, target):
	g = target - short_max(y)
	for _ in range(6):
		z = tp_limit(y * 10 ** (g / 20))
		err = target - short_max(z)
		if abs(err) < 0.2 or g - (target - short_max(y)) > MAX_LIMIT:
			break
		g += err
	return z


def foley_take(slice_name, t):
	kind, src, start, length, how = t
	target = FOLEY_TARGET.get(slice_name, FOLEY_DEFAULT)
	TARGETS[slice_name] = target
	if kind == "GAME":
		y = game_slice(src, start)
		return level(hp(y, 90, 2), target)
	x = load((kind, src))
	x = x[int(RATE * start) : int(RATE * (start + length))]
	e = env_db(x)
	if how == "hit":
		on = int(np.argmax(e > e.max() - 24))
		x, e = x[max(0, on - int(RATE * 0.003)) :], e[max(0, on - int(RATE * 0.003)) :]
	# the tail stops where it stays 60 dB under the peak
	above = np.nonzero(e > e.max() - 60)[0]
	end = min(len(x), int(above[-1]) + int(RATE * 0.02)) if len(above) else len(x)
	x = fade(hp(x[:end], 90, 2), 0.002, min(0.03, end / RATE * 0.25))
	return level(x, target)


# Hit feedback (2026-11-09) ----------------------------------------------------
# The owner wants Valorant-style hits: a solid body thwack, a headshot that
# sounds different (a bright metal "dink" over the thwack) and a kill tone that
# climbs a step with every kill in the round (the pitch ladder is the game's,
# Config/Audio KILL_LADDER). Real CC0 Freesound recordings (fetched with
# tools/audio/fetch_audio.py; sources in the vault note "2026-11-09 Hit and
# Shot Feel"), cut tight and layered: real layers only, no synthesis.
DL = os.path.join(ROOT, "art-source", "audio", "downloads")
OUT_HIT_PREVIEW = os.path.join(ROOT, "art-source", "audio", "HitSfxPreview.wav")


def fs(fid, start=0.0, length=0.4, hp_hz=90, fade_out=0.04, pitch=1.0):
	"""A Freesound take: trimmed to 2 ms before its first transient, `length` s."""
	x, sr = sf.read(os.path.join(DL, f"freesound-{fid}", f"{fid}.ogg"), always_2d=True)
	x = x[:, :2] if x.shape[1] >= 2 else np.repeat(x, 2, axis=1)
	if sr != RATE:
		x = signal.resample_poly(x, RATE, sr, axis=0)
	x = x[int(RATE * start) :]
	e = env_db(x)
	on = int(np.argmax(e > e.max() - 20))
	x = x[max(0, on - int(RATE * 0.002)) :][: int(RATE * length / pitch) + 1]
	if pitch != 1:
		x = resample(x, 1 / pitch)
	x = hp(x - x[:64].mean(axis=0), hp_hz, 2)
	return fade(x, 0.001, min(fade_out, len(x) / RATE * 0.5))


def mix(*layers):
	"""(take, gain dB, delay s) layers summed, aligned on their starts."""
	n = max(int(RATE * d) + len(t) for t, _, d in layers)
	out = np.zeros((n, 2))
	for t, g, d in layers:
		i = int(RATE * d)
		out[i : i + len(t)] += t * 10 ** (g / 20)
	return out


def thud(k):
	"""The body layer: a gloved hit, a fast collision, a chop on skin."""
	return [
		fs(276600, length=0.2, hp_hz=70),
		fs(332056, length=0.16, hp_hz=110),
		fs(321810, length=0.2, hp_hz=110),
	][k % 3]


HIT_TARGET = {"HitBody": -13.0, "HitHead": -10.5, "KillTone": -11.0, "KillHeadTone": -10.0}


def gd(name, pre=0.004, length=0.3, hp_hz=60, lp_hz=None, fade_out=0.05, pitch=1.0):
	"""A GDC 2016 take (design_gun_sfx loader): from `pre` s before its peak."""
	x = designs().load(name)
	m = np.abs(x).max(axis=1)
	pk = int(np.argmax(m))
	x = x[max(0, pk - int(RATE * pre)) :][: int(RATE * length / pitch) + 1]
	if pitch != 1:
		x = resample(x, 1 / pitch)
	x = hp(x, hp_hz, 2)
	if lp_hz:
		x = lp(x, lp_hz, 2)
	x = x / (np.abs(x).max() + 1e-9)
	return fade(x, 0.001, min(fade_out, len(x) / RATE * 0.5))


def hit_clips():
	"""2026-11-09 v2 (owner: the first set was "a ding", not punchy; RIVALS'
	headshot is a prominent slash, the body shot an impact, Valorant's kill
	a "whoa"). Real recorded / designed library sounds, layered: Sonniss GDC
	2016 (SoundBits Just Whoosh 3, SoundMorph RUPTURE, Bottle Rocket Impact
	Collection) and the CC0 Freesound takes above."""
	clips = {}
	slash = [
		gd("Swoosh_Rope_Whip_075", pre=0.03, length=0.26, hp_hz=400, fade_out=0.08),
		gd("Swoosh_Rope_Whip_075", pre=0.03, length=0.26, hp_hz=400, fade_out=0.08, pitch=1.08),
		gd("Swoosh_Rope_Whip_075", pre=0.03, length=0.26, hp_hz=400, fade_out=0.08, pitch=0.94),
	]
	crack = gd("Rupture - Marble_Impacts_06", pre=0.002, length=0.14, hp_hz=1500, fade_out=0.08)
	crunch = gd("Rupture - Concrete_Impact_B02", pre=0.003, length=0.16, hp_hz=250, fade_out=0.08)
	drum = gd("Impact_Drum Hit_03", pre=0.012, length=0.22, hp_hz=40, lp_hz=2500, fade_out=0.1)
	boom = gd("Impact_Boom_Distorted_02", pre=0.018, length=0.55, hp_hz=40, lp_hz=7000, fade_out=0.3)
	pop = gd("Rupture - Bulb_Impact_03", pre=0.002, length=0.18, hp_hz=1200, fade_out=0.1)
	tri = tighten(fs(349503, length=0.8, hp_hz=500, fade_out=0.3), 0.14, 0.28)
	# Body: an impact (crunch + drum thump + the gloved hit), 3 takes.
	clips["HitBody"] = [
		tighten(mix((drum, -2, 0), (crunch, -5, 0.002), (thud(k), -4, 0)), 0.05, 0.07) for k in range(3)
	]
	# Head: the slash on top, a bright crack, the body impact under it.
	clips["HitHead"] = [
		mix((slash[k], 0, 0), (crack, -5, 0.02), (drum, -6, 0.018), (thud(k), -8, 0.018)) for k in range(3)
	]
	# Kill: the boom, a glass pop, the triangle ringing out (the ladder pitches it all).
	clips["KillTone"] = [mix((boom, 0, 0), (pop, -7, 0.004), (tri, -3, 0.006), (drum, -5, 0))]
	clips["KillHeadTone"] = [mix((slash[0], -1, 0), (boom, 0, 0.02), (pop, -6, 0.024), (tri, -3, 0.026))]
	for name, vs in clips.items():
		TARGETS[name] = HIT_TARGET[name]
		clips[name] = [level(stereo(v), HIT_TARGET[name]) for v in vs]
	return clips


def hit_preview(clips):
	"""Hits in context: Vandal and Classic shots landing body / head hits, then
	a 5-kill round climbing the ladder, then head kills."""
	ladder = [1.0, 1.122, 1.26, 1.335, 1.498]  # Config/Audio KILL_LADDER
	out = np.zeros((int(RATE * 60), 2))
	cues, t = [], 0.5

	def put(name, at, vol, pitch=1.0, k=0, group=1.0):
		v = clips[name][k % len(clips[name])]
		if pitch != 1:
			v = resample(v, 1 / pitch)
		i = int(at * RATE)
		out[i : i + len(v)] += v * vol * boost(clips, name) * group

	gun, fb = GROUP["Gun"], 1.0
	for label, hit in (("body hits", "HitBody"), ("headshots", "HitHead")):
		cues.append(f"{t:6.2f}  Classic, {label}")
		for k in range(4):
			put("ClassicFire", t, FIRE_VOL, group=gun, k=k)
			put(hit, t + 0.035, 0.7, k=k, group=fb)
			t += 0.5
		t += 0.6
		cues.append(f"{t:6.2f}  Vandal spray, {label}")
		for k in range(6):
			put("VandalFire", t + k * 0.103, FIRE_VOL, group=gun, k=k)
			put(hit, t + k * 0.103 + 0.035, 0.7, k=k, group=fb)
		put("VandalTail", t + 5 * 0.103 + 0.155, FIRE_VOL, group=gun)
		t += 1.6
	cues.append(f"{t:6.2f}  kill tone alone, kills 1-5 in a round")
	for k in range(5):
		put("KillTone", t, 0.8, ladder[k], group=fb)
		t += 0.8
	t += 0.5
	cues.append(f"{t:6.2f}  headshot kill tone, kills 1-5")
	for k in range(5):
		put("KillHeadTone", t, 0.8, ladder[k], group=fb)
		t += 0.8
	t += 0.5
	cues.append(f"{t:6.2f}  in context: Vandal taps, two body hits then the kill (x3, climbing)")
	for k in range(3):
		for j in range(3):
			put("VandalFire", t + j * 0.18, FIRE_VOL, group=gun, k=j)
			put("KillTone" if j == 2 else "HitBody", t + j * 0.18 + 0.035, 0.8 if j == 2 else 0.7, ladder[k] if j == 2 else 1.0, k=j)
		put("VandalTail", t + 2 * 0.18 + 0.155, FIRE_VOL, group=gun)
		t += 1.4
	cues.append(f"{t:6.2f}  in context: Guardian headshot kill")
	put("GuardianFire", t, FIRE_VOL, group=gun)
	put("KillHeadTone", t + 0.04, 0.8)
	t += 2.0
	out = out[: int(RATE * t)]
	peak = np.abs(out).max()
	if peak > 0.98:
		out *= 0.98 / peak
	sf.write(OUT_HIT_PREVIEW, out.astype(np.float32), RATE, subtype="PCM_16")
	with open(OUT_HIT_PREVIEW.replace(".wav", ".txt"), "w", encoding="utf-8") as f:
		f.write("HitSfxPreview.wav (game volumes)" + chr(10) * 2 + chr(10).join(cues) + chr(10))
	print(f"hit preview: {OUT_HIT_PREVIEW} ({t:.0f} s)")


# Atlas ------------------------------------------------------------------------


def build():
	w = weapon_data()
	clips, notes = {}, {}
	for name in GUNS:
		near, tails, far, info = gun_shots(name, w[name])
		TARGETS[name + "Fire"] = (
			designs().target(name) if USE_DESIGNS and name in designs().DESIGNS else CLASSES[GUNS[name]["cls"]]["target"]
		)
		clips[name + "Fire"] = near
		clips[name + "FireFar"] = far
		if tails:
			clips[name + "Tail"] = tails
			TARGETS[name + "Tail"] = TARGETS[name + "Fire"]  # the tail plays with the shot's volume
		notes[name] = info
		print(f"{name:9s} {w[name]['fireMode']:5s} {len(near)} shots {'+ tails ' if tails else ''}| " + "; ".join(info))
	for slice_name, takes in FOLEY.items():
		clips[slice_name] = [foley_take(slice_name, t) for t in takes]
	clips.update(hit_clips())
	return clips, notes, w


def pack(clips):
	parts, regions, t = [np.zeros((int(RATE * GAP), 2))], {}, GAP
	for name, variants in clips.items():
		regions[name] = []
		for v in variants:
			# every slice starts on a whole millisecond (PlaybackRegion is in seconds)
			start = int(np.ceil(t * 1000 - 1e-6)) / 1000
			pad = int(round((start - t) * RATE))
			if pad > 0:
				parts.append(np.zeros((pad, 2)))
			regions[name].append({"start": start, "length": round(len(v) / RATE, 3)})
			parts.append(stereo(v))
			gap = int(RATE * GAP)
			parts.append(np.zeros((gap, 2)))
			t = start + (len(v) + gap) / RATE
	audio = np.concatenate(parts)
	return np.clip(audio, -0.98, 0.98), regions


def lua_num(v):
	s = f"{v:.3f}".rstrip("0").rstrip(".")
	return s if s else "0"


def write_atlas(regions):
	lines = [
		"--!strict",
		"-- Generated by tools/audio/build_gun_sfx.py. Do not edit by hand.",
		"-- Where each gun sound sits inside the gun atlas audio (Config/Sounds",
		'-- GUN_ATLAS), in seconds. Played as "gun:<Name>"; each name has one or',
		"-- more variants and the game picks one per play.",
		"",
		"export type Region = { start: number, length: number }",
		"",
		"local atlas: { [string]: { Region } } = {",
	]
	for name, rs in regions.items():
		items = ", ".join(f"{{ start = {lua_num(r['start'])}, length = {lua_num(r['length'])} }}" for r in rs)
		lines.append(f"\t{name} = {{ {items} }},")
	lines += ["}", "", "return table.freeze(atlas)", ""]
	with open(OUT_ATLAS, "w", encoding="utf-8", newline="\n") as f:
		f.write("\n".join(lines))


def boost(clips, name):
	"""Volume factor for a slice that fell short of its loudness target."""
	if name not in TARGETS:
		return 1.0
	got = float(np.mean([short_max(v) for v in clips[name]]))
	return float(min(MAX_BOOST, max(1.0, 10 ** ((TARGETS[name] - got) / 20))))


def write_sets(regions, clips):
	lines = [
		"--!strict",
		"-- Generated by tools/audio/build_gun_sfx.py from its GUNS and SETS",
		"-- tables. Do not edit by hand: change the table there and rebuild (or",
		"-- override one sound in Config/GunSounds OVERRIDES). Every gun's sounds",
		'-- as "gun:<slice>" ids into the gun atlas (Config/GunAtlas), level-',
		"-- matched in the files, so the volumes here are the mix.",
		"",
		"export type Sound = { id: string, volume: number, pitch: { number } }",
		"",
		"return table.freeze({",
	]

	def entry(field, sid, vol, lo, hi):
		vol *= boost(clips, sid)
		return f'\t\t{field} = {{ id = "gun:{sid}", volume = {lua_num(vol)}, pitch = {{ {lua_num(lo)}, {lua_num(hi)} }} }},'

	for name in GUNS:
		lines.append(f"\t{name} = {{")
		lines.append(entry("fire", name + "Fire", FIRE_VOL, 0.98, 1.02))
		lines.append(entry("fireFar", name + "FireFar", FAR_VOL, 0.97, 1.03))
		if name + "Tail" in regions:
			lines.append(entry("tail", name + "Tail", FIRE_VOL, 0.98, 1.02))
		for field, (sid, lo, hi) in SETS[name].items():
			lines.append(entry(field, sid, FIELD_VOL.get(field, FOLEY_VOL), lo, hi))
		lines.append("\t},")
	lines += ["} :: { [string]: { [string]: Sound } })", ""]
	with open(OUT_SETS, "w", encoding="utf-8", newline="\n") as f:
		f.write("\n".join(lines))


# Preview ----------------------------------------------------------------------


def clip_markers(gun):
	"""clip name -> markers {name: fraction} from WeaponAnimations/<gun>.luau."""
	path = os.path.join(ANIMS, gun + ".luau")
	out, clip = {}, None
	for line in open(path, encoding="utf-8"):
		m = re.match(r"^\t(\w+) = \{", line)
		if m:
			clip = m.group(1)
		mk = re.search(r"markers = \{([^}]*)\}", line)
		if mk and clip:
			out[clip] = {k: float(v) for k, v in re.findall(r"(\w+) = ([0-9.]+)", mk.group(1))}
	return out


# Beats from joints (not markers) at rough clip fractions: the game times
# them off the clip itself, this is only for listening.
JOINT_BEATS = {
	"Sheriff": {"Reload": [("open", 0.12), ("eject", 0.3), ("shellIn", 0.62), ("close", 0.86)]},
	"Shorty": {"Reload": [("open", 0.14), ("shellIn", 0.5), ("shellIn", 0.62), ("close", 0.86)]},
	"Odin": {"Reload": [("open", 0.08), ("magOut", 0.2), ("magIn", 0.5), ("close", 0.75)]},
}
MARKER_FIELD = {"MagOut": "magOut", "MagIn": "magIn", "Open": "open", "RoundOut": "eject", "RoundIn": "shellIn", "Close": "close", "ShellIn": "shellIn"}


def preview(clips, w):
	out = np.zeros((int(RATE * 1200), 2))
	cues = []
	t = 0.5

	def put(name, at, vol, pitch=1.0, variant=None, group="Foley"):
		vs = clips.get(name)
		if not vs:
			return
		v = vs[(variant if variant is not None else np.random.randint(len(vs))) % len(vs)]
		if pitch != 1:
			v = resample(v, 1 / pitch)
		i = int(at * RATE)
		out[i : i + len(v)] += v * vol * GROUP[group]

	def foley(gun, field, at):
		s = SETS[gun].get(field) or (SETS[gun].get("rack") if field == "close" else None)
		if s:
			put(s[0], at, FIELD_VOL.get(field, FOLEY_VOL) * boost(clips, s[0]), (s[1] + s[2]) / 2)

	rng = np.random.default_rng(3)
	for gun in GUNS:
		wd = w[gun]
		marks = clip_markers(gun)
		start = t
		cues.append(f"{t:7.2f}  {gun}: draw, inspect, shots, dry fire, reload, empty reload")
		draw = wd["drawTime"] or 0.8
		foley(gun, "draw", t)
		foley(gun, "rack", t + draw * 0.6)
		t += draw + 0.4
		foley(gun, "inspect", t)
		t += 1.4
		# shots: semi = 4 at its rate (at least 0.35 s apart), auto = a 10-shot string + the tail
		fi = wd["fireInterval"] or 0.2
		fire_vol = FIRE_VOL * boost(clips, gun + "Fire")
		if wd["fireMode"] == "Auto":
			for k in range(10):
				put(gun + "Fire", t + k * fi, fire_vol, rng.uniform(0.98, 1.02), group="Gun")
			put(gun + "Tail", t + 9 * fi + TAIL_AFTER * fi, fire_vol, group="Gun")
			t += 10 * fi + 1.2
			for k in range(3):
				put(gun + "Fire", t + k * fi, fire_vol, group="Gun")
			put(gun + "Tail", t + 2 * fi + TAIL_AFTER * fi, fire_vol, group="Gun")
			t += 3 * fi + 1.3
		else:
			gap = max(fi, 0.45 if wd["fireMode"] != "Semi" else 0.35)
			for k in range(4):
				put(gun + "Fire", t + k * gap, fire_vol, rng.uniform(0.98, 1.02), group="Gun", variant=k)
				if wd["fireMode"] in ("Pump", "Bolt") and k < 3:
					foley(gun, "rack", t + k * gap + fi * 0.35)
			t += 4 * gap + 1.4
		foley(gun, "dryFire", t)
		t += 0.6
		if wd["shell"]:
			s0, ins, fin = wd["shell"]
			t += s0
			for k in range(3):
				mk = marks.get("ReloadInsert", {}).get("ShellIn", 0.4)
				foley(gun, "shellIn", t + k * ins + mk * ins)
			t += 3 * ins
			foley(gun, "rack", t + fin * 0.6)
			t += fin + 1.0
		else:
			for clip, dur in (("Reload", wd["reloadTime"]), ("ReloadEmpty", wd["emptyReloadTime"])):
				if not dur:
					continue
				beats = [(MARKER_FIELD[k], v) for k, v in marks.get(clip, {}).items() if k in MARKER_FIELD]
				if not beats:
					beats = JOINT_BEATS.get(gun, {}).get("Reload", [])
				for field, frac in beats:
					foley(gun, field, t + frac * dur)
				if clip == "ReloadEmpty" and not any(f == "close" for f, _ in beats):
					foley(gun, "rack", t + 0.86 * dur)
				t += dur + 0.6
		t += 1.2
		cues[-1] += f"  (to {t:.1f})"
		del start
	out = out[: int(RATE * (t + 0.5))]
	peak = np.abs(out).max()
	if peak > 0.98:
		out *= 0.98 / peak
		cues.append(f"(reel scaled by {0.98 / peak:.2f} to avoid clipping)")
	sf.write(OUT_PREVIEW, out.astype(np.float32), RATE, subtype="PCM_16")
	with open(OUT_CUES, "w", encoding="utf-8") as f:
		f.write("GunSfxPreview.wav, at game volumes (gun x Gun group, foley x Foley group).\n")
		f.write("Reload beats sit on the clips' markers; joint beats (Sheriff, Shorty, Odin, racks) are approximate.\n\n")
		f.write("\n".join(cues) + "\n")
	print(f"preview: {OUT_PREVIEW} ({t:.0f} s)")


def report(clips):
	print("\nslice loudness (momentary max LUFS / loudest 100 ms / punch dB / worst true peak dBTP):")
	for name, vs in clips.items():
		v = vs[0]
		tp = max(max(true_peak_db(u[:, 0]), true_peak_db(u[:, 1])) for u in vs)
		print(f"  {name:16s} x{len(vs)}  {momentary_max(mono(v)):6.1f}  {short_max(v):6.1f}  {loudness(v):6.1f}  {tp:5.1f}  {len(v) / RATE:.2f}s")


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--preview", action="store_true")
	ap.add_argument("--report", action="store_true")
	ap.add_argument("--hits", action="store_true", help="also the hit feedback audition reel")
	ap.add_argument("--legacy", action="store_true", help="the 2026-11-08 single recordings, not DESIGNS")
	ap.add_argument(
		"--no-luau",
		action="store_true",
		help="audio and reels only: keep Config/GunAtlas + GunSoundSets matching the uploaded atlas",
	)
	args = ap.parse_args()
	global USE_DESIGNS
	USE_DESIGNS = not args.legacy
	clips, _, w = build()
	audio, regions = pack(clips)
	sf.write(OUT_AUDIO, audio, RATE, subtype="PCM_16")
	with open(OUT_JSON, "w") as f:
		json.dump(regions, f, indent=1)
	if args.no_luau:
		print("(--no-luau: Config/GunAtlas and GunSoundSets left as they are)")
	else:
		write_atlas(regions)
		write_sets(regions, clips)
	try:  # the project's formatter, so a rebuild leaves no diff noise
		import subprocess

		subprocess.run(["stylua", OUT_ATLAS, OUT_SETS], check=False)
	except OSError:
		pass
	size = os.path.getsize(OUT_AUDIO) / 1e6
	print(f"\natlas: {len(audio) / RATE:.1f} s, {size:.1f} MB, {sum(len(r) for r in regions.values())} slices in {len(regions)} names")
	if args.report:
		report(clips)
	if args.preview:
		preview(clips, w)
	if args.hits:
		hit_preview(clips)


if __name__ == "__main__":
	main()
