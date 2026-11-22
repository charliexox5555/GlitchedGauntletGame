"""Sniper scope mask (Util/ScopeOverlay): black outside a circle, with a
smoothstep feather from the edge inward (Config/Scope WINDOW: feather /
outer). A texture instead of a 4000 px UIStroke, which phones tessellate
into a not-quite-round window (owner 2026-11-22).

    python tools/ui/make_scope_mask.py   -> art-source/ui/hud/scope_mask.png
"""

from pathlib import Path

from PIL import Image

SIZE = 1024
OUTER, FEATHER = 0.97, 0.125  # Config/Scope.WINDOW
INNER = 1 - 2 * FEATHER / OUTER  # the feather's inner edge, as a share of the radius
SS = 2


def smoothstep(k: float) -> float:
    k = min(max(k, 0.0), 1.0)
    return k * k * (3 - 2 * k)


def main():
    n = SIZE * SS
    img = Image.new("L", (n, n), 0)
    px = img.load()
    c = (n - 1) / 2
    for y in range(n):
        dy = (y - c) / c
        for x in range(n):
            dx = (x - c) / c
            r = (dx * dx + dy * dy) ** 0.5
            if r >= 1:
                a = 1.0
            else:
                t = (1 - r) / (1 - INNER)  # 0 at the edge, 1 at the inner edge
                a = 1 - smoothstep(t)
            px[x, y] = int(round(a * 255))
    alpha = img.resize((SIZE, SIZE), Image.LANCZOS)
    out = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    out.putalpha(alpha)
    path = Path(__file__).resolve().parents[2] / "art-source" / "ui" / "hud" / "scope_mask.png"
    out.save(path)
    print(f"wrote {path}")


if __name__ == "__main__":
    main()
