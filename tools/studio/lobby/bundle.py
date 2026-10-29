"""Bundle Lobby greybox scripts for Studio.

Prints GreyboxKit.luau followed by the named bodies (Hub, Wing_Duels, ...), so
the result can be pasted into the Studio Command Bar of the Lobby place or sent
through the Studio MCP. With -o it writes the bundle to a file instead.

    python tools/studio/lobby/bundle.py Hub
    python tools/studio/lobby/bundle.py Hub Wing_Duels Wing_Market Wing_Weapons Wing_Range -o all.luau
"""

import argparse
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent


def body(name: str) -> str:
    text = (HERE / f"{name}.luau").read_text(encoding="utf-8")
    # The kit already carries the --!strict line.
    return "\n".join(line for line in text.splitlines() if line.strip() != "--!strict")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("names", nargs="+", help="Hub, Wing_Duels, Wing_Market, Wing_Weapons, Wing_Range")
    ap.add_argument("-o", "--out", help="write the bundle here instead of stdout")
    args = ap.parse_args()
    parts = [(HERE / "GreyboxKit.luau").read_text(encoding="utf-8")]
    for name in args.names:
        # Each body runs in its own do-block so their locals don't collide.
        parts.append(f"do -- {name}\n{body(name)}\nend")
    # Bodies never return (that would end the bundle early); the kit's REPORT
    # collects one line per published section instead.
    parts.append("return REPORT")
    out = "\n\n".join(parts) + "\n"
    if args.out:
        pathlib.Path(args.out).write_text(out, encoding="utf-8")
    else:
        sys.stdout.write(out)


if __name__ == "__main__":
    main()
