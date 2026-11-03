"""Bundle a match map's Studio scripts.

Prints MapKit.luau followed by the named bodies from tools/studio/maps/<Map>/, each
in its own do-block, so the result can be pasted into the Studio Command Bar of the
match place or sent through the Studio MCP. With -o it writes a file instead.

    python tools/studio/maps/bundle.py Metro Greybox
    python tools/studio/maps/bundle.py Metro Greybox Art Lighting -o metro.luau

Bodies must not `return` (that would end the bundle early); they call report().
"""

import argparse
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent


def body(path: pathlib.Path) -> str:
    text = path.read_text(encoding="utf-8")
    # The kit already carries the --!strict line.
    return "\n".join(line for line in text.splitlines() if line.strip() != "--!strict")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("map", help="the map id (folder name under tools/studio/maps)")
    ap.add_argument("names", nargs="+", help="script bodies in that folder, without .luau")
    ap.add_argument("-o", "--out", help="write the bundle here instead of stdout")
    args = ap.parse_args()
    parts = [(HERE / "MapKit.luau").read_text(encoding="utf-8")]
    for name in args.names:
        parts.append(f"do -- {args.map}/{name}\n{body(HERE / args.map / f'{name}.luau')}\nend")
    parts.append("return table.concat(REPORT, \"\\n\")")
    out = "\n\n".join(parts) + "\n"
    if args.out:
        pathlib.Path(args.out).write_text(out, encoding="utf-8")
    else:
        sys.stdout.write(out)


if __name__ == "__main__":
    main()
