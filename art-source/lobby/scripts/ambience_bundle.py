"""Bundle the lobby ambience setup for Studio (phase 1, step 6).

    python art-source/lobby/scripts/ambience_bundle.py -o <scratch>/ambience.luau

Writes AmbienceSetup.luau with CLIENT_SOURCE (the exact text of AmbienceClient.luau)
defined above it, so one execute_luau call rebuilds Workspace.Lobby.Ambience, installs the
AmbienceClient Script with that source and re-tags the art. Re-run after any Art_* script.
"""

import argparse
import pathlib

HERE = pathlib.Path(__file__).resolve().parent


def main() -> None:
	ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	ap.add_argument("-o", "--out", required=True)
	args = ap.parse_args()
	client = (HERE / "AmbienceClient.luau").read_text(encoding="utf-8")
	setup = (HERE / "AmbienceSetup.luau").read_text(encoding="utf-8")
	level = 1
	while f"]{'=' * level}]" in client:
		level += 1
	eq = "=" * level
	# A long string drops a newline that directly follows the opening bracket, so add one.
	body = "\n".join(line for line in setup.splitlines() if line.strip() != "--!strict")
	# Every Studio MCP call into the Lobby place starts with the PlaceId guard.
	guard = 'assert(game.PlaceId == 133387545285290, "not the Lobby")'
	text = f"{guard}\nlocal CLIENT_SOURCE: string = [{eq}[\n{client}]{eq}]\n{body}\n"
	pathlib.Path(args.out).write_text(text, encoding="utf-8", newline="\n")
	print("wrote", args.out, len(text), "chars")


if __name__ == "__main__":
	main()
