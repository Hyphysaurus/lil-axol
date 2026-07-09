"""Restyle the SeethingSwarm turtle into a Mexican mud turtle (Kinosternon integrum).

The shipped green/red-striped slider is itself an INVASIVE species in Mexico — the ally must
not be an invader (Living Watershed spec §4.1, pillar-blocker). Hue-window remap:
  greens (H 60-180, saturated)  -> drab olive-umber shell/skin, darker
  red/orange ear stripe (H<=25 or >=340, high sat) -> dark mud skin
Outline, alpha, and everything else untouched. Runs in place over assets/critters/turtle.
Run once from the repo root:  python tools/restyle_mud_turtle.py
(Git is the undo button: `git checkout -- assets/critters/turtle` restores the slider.)
"""
import colorsys
import pathlib

from PIL import Image

DIR = pathlib.Path(__file__).resolve().parent.parent / "assets" / "critters" / "turtle"


def remap(r: int, g: int, b: int) -> tuple[int, int, int]:
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    deg = h * 360
    if 60 <= deg <= 180 and s > 0.18:            # greens -> olive-umber, drabber + darker
        h, s, v = 40 / 360, min(1.0, s * 0.75), v * 0.82
    elif (deg <= 25 or deg >= 340) and s > 0.45:  # red ear stripe -> dark mud skin
        h, s, v = 30 / 360, s * 0.5, v * 0.55
    r2, g2, b2 = colorsys.hsv_to_rgb(h, s, v)
    return int(r2 * 255), int(g2 * 255), int(b2 * 255)


def main() -> None:
    pngs = sorted(DIR.glob("turtle_*.png"))
    assert pngs, f"no turtle strips found in {DIR}"
    for png in pngs:
        img = Image.open(png).convert("RGBA")
        px = img.load()
        for y in range(img.height):
            for x in range(img.width):
                r, g, b, a = px[x, y]
                if a == 0:
                    continue
                px[x, y] = (*remap(r, g, b), a)
        img.save(png)
        print("restyled", png.name)


if __name__ == "__main__":
    main()
