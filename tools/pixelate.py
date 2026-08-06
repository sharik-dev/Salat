"""Give the illustrations a light pixel grain, to match the pixel face.

    python3 tools/pixelate.py SalatKit/Resources/pos_*.png

The figure is reduced to a coarse grid and blown back up with nearest
neighbour, so the edges stair-step instead of staying vector-smooth. The grid
is deliberately generous (72 cells across a 512 image ≈ 7px blocks): the
silhouettes have to stay readable at 62pt in a list row and inside a widget,
and a truly chunky grid turns the ruku into a blob.

Alpha is quantised the same way and then hard-thresholded, otherwise the
downscale leaves a soft fringe and the pixel edge reads as a blur.
"""
import sys
from PIL import Image

GRID = 72           # cells across
OUT = 512           # final size


def pixelate(path, grid=GRID, out=OUT):
    im = Image.open(path).convert("RGBA")

    small = im.resize((grid, grid), Image.BOX)          # area-average, then snap
    r, g, b, a = small.split()
    a = a.point(lambda v: 255 if v > 110 else 0)        # hard edge, no fringe

    # Flatten the colour onto the figure's own tone so the averaged edge pixels
    # do not carry a halo of background from before the cutout.
    small = Image.merge("RGBA", (r, g, b, a))

    big = small.resize((out, out), Image.NEAREST)
    big.save(path)
    print(f"{path}  {grid}×{grid} → {out}")


if __name__ == "__main__":
    for p in sys.argv[1:]:
        pixelate(p)
