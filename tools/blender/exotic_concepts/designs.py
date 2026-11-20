"""Offline concept queue and the fixed, exterior treatment for each stock model."""

LINES = {
    "Spindrift": ("202B36", "CADADD", "76E6DA", "D47C61", "314450"),
    "Kilnlock": ("282525", "D5C1A4", "FF793F", "9A5137", "51403A"),
    "Stacklight": ("20232E", "E4E1D7", "53E4D2", "927DAF", "344656"),
}

# Part, exterior x limits, exterior z limits, directing note.
GUNS = {
    ("Spindrift", "Vandal"): ("Receiver", (.22, .88), (.184, .268), "Two pearl folds frame a shutter channel. The tide ribbon recedes as the leaves seat."),
    ("Kilnlock", "Odin"): ("Receiver", (.331, .772), (.388, .477), "A low rectangular cage frames an indexed heat bar. The feed train remains stock."),
    ("Stacklight", "Phantom"): ("Receiver", (.19, .731), (.25, .335), "Three indicator cells sit above a short, clear shuttle that parks flush."),
    ("Spindrift", "Spectre"): ("Receiver", (.261, .58), (.202, .29), "Short paired shutters and a tight ribbon keep the suppressor quiet."),
    ("Spindrift", "Ghost"): ("Frame", (.49, .9), (.165, .214), "A single flush leaf under the slide makes one brief recovery wipe."),
    ("Spindrift", "Marshal"): ("Receiver", (.27, .74), (.075, .146), "Small ripples mark each seated round. Inspect opens the leaves fully."),
    ("Spindrift", "Guardian"): ("Receiver", (.24, 1.041), (.215, .303), "An extended pearl cheek carries one moving bead. Inspect reveals the slit."),
    ("Spindrift", "Bucky"): ("Receiver", (.14, .51), (.31, .385), "A short shell-count ripple stays on the fixed body above the pump travel."),
    ("Kilnlock", "Phantom"): ("Receiver", (.22, .76), (.245, .34), "Two ceramic faces frame a low heat cassette. Keep the suppressor dark."),
    ("Kilnlock", "Bulldog"): ("Receiver", (-.31, .27), (.358, .439), "A compact single hatch sits on the fixed shoulder, clear of the repaired bolt."),
    ("Kilnlock", "Shorty"): ("Frame", (.097, .275), (.258, .333), "The fixed frame gets one shallow ceramic hatch and a closing heat pulse."),
    ("Kilnlock", "Sheriff"): ("Frame", (.302, .665), (.338, .37), "An offset shroud vent opens above the swing path of the stock cylinder."),
    ("Kilnlock", "Judge"): ("Receiver", (.42, 1.169), (.343, .447), "Two jaws sit above the stock drum. A restrained enamel mark moves with the drum."),
    ("Stacklight", "Stinger"): ("Receiver", (-.2, .32), (.227, .3), "A short diagnostic strip sits behind the repaired handguard join."),
    ("Stacklight", "Classic"): ("Frame", (.463, .79), (.219, .268), "Two tiny fixed cells pulse below the moving slide seam."),
    ("Stacklight", "Outlaw"): ("Receiver", (.22, .685), (.222, .32), "Two short pulses follow the stock open and close cues below the scope."),
    ("Stacklight", "Ares"): ("Receiver", (.12, .66), (.371, .458), "A wide shoulder window sweeps independently of the drum status mark."),
    ("Stacklight", "Operator"): ("Receiver", (.213, .992), (.235, .311), "A long diagnostic strip below the optic seats its shuttle clear of bolt travel."),
}

HEROES = list(GUNS)[:3]
MELEES = [("Spindrift", "SoundingArc"), ("Kilnlock", "KilnCleaver"), ("Stacklight", "PatchTool")]
CHARMS = [("Spindrift", "StormglassBuoy"), ("Kilnlock", "FoundryStamp"), ("Stacklight", "KeycapTester")]
QUEUE = HEROES + MELEES + CHARMS + list(GUNS)[3:]
NAMES = dict(zip((key[1] for key in MELEES + CHARMS), (
    "Sounding Arc", "Kiln Cleaver", "Patch Tool", "Stormglass Buoy", "Foundry Stamp", "Keycap Tester",
)))

NOTES = {
    "SoundingArc": "Two split pearl arc segments rise around a sea-glass ribbon. A basalt handle sits below the crescent, off center.",
    "KilnCleaver": "A clipped foundry slab uses a low rear grip, a separate support grip, two jaws and a heat insert.",
    "PatchTool": "Three overlapping smoke-blue panels fan around an ivory handle. Side cheeks slide outward for the diagnostic sweep.",
    "StormglassBuoy": "A faceted navigation float carries a red-orange cap and a single bubble in its vertical sea-glass insert.",
    "FoundryStamp": "A square ceramic seal hangs below copper hinges. The two jaws part around an orange enamel core.",
    "KeycapTester": "An ivory cap on a smoke-blue frame presses down over a mint indicator. Three raised bars mark the cap.",
}
