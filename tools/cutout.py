"""Turn a generated square render into a transparent, tightly-cropped figure.

    python3 tools/cutout.py /tmp/pos_ruku.png      # -> /tmp/pos_ruku_cut.png

The generator paints a beige field behind the silhouette and stamps a small
sparkle watermark in a corner. Both have to go, and the watermark has to go
*before* the crop is computed — otherwise it drags the bounding box into the
corner and the figure ends up off-centre. So: background to alpha, drop every
speck that is too small to be a body part, then crop to what is left.
"""
import sys
from collections import deque
from PIL import Image

NEAR, FAR = 26, 70          # colour distance: fully background ↔ fully figure


def alpha_from_background(im):
    w, h = im.size
    bg = im.getpixel((4, 4))
    px = im.load()
    alpha = Image.new("L", (w, h), 0)
    ap = alpha.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            d = abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2])
            ap[x, y] = 0 if d <= NEAR else (255 if d >= FAR else
                                            int(255 * (d - NEAR) / (FAR - NEAR)))
    return alpha


def drop_small_specks(alpha, min_share=0.02):
    """Keep only blobs worth at least `min_share` of the largest one."""
    w, h = alpha.size
    ap = alpha.load()
    solid = [[ap[x, y] > 40 for x in range(w)] for y in range(h)]
    seen = [[False] * w for _ in range(h)]
    blobs = []

    for y0 in range(h):
        for x0 in range(w):
            if not solid[y0][x0] or seen[y0][x0]:
                continue
            queue, cells = deque([(x0, y0)]), []
            seen[y0][x0] = True
            while queue:
                x, y = queue.popleft()
                cells.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and solid[ny][nx] and not seen[ny][nx]:
                        seen[ny][nx] = True
                        queue.append((nx, ny))
            blobs.append(cells)

    if not blobs:
        return alpha
    biggest = max(len(b) for b in blobs)
    for cells in blobs:
        if len(cells) < biggest * min_share:
            for x, y in cells:
                ap[x, y] = 0
    return alpha


def cutout(path, out, side=512):
    im = Image.open(path).convert("RGB")
    # Half size: the blob pass is O(pixels) in pure Python, and the result is
    # downscaled to 512 anyway.
    im = im.resize((im.width // 2, im.height // 2), Image.LANCZOS)

    alpha = drop_small_specks(alpha_from_background(im))

    rgba = im.convert("RGBA")
    rgba.putalpha(alpha)

    box = alpha.point(lambda v: 255 if v > 40 else 0).getbbox()
    if box:
        pad = int(0.03 * max(im.size))
        box = (max(box[0] - pad, 0), max(box[1] - pad, 0),
               min(box[2] + pad, im.width), min(box[3] + pad, im.height))
        rgba = rgba.crop(box)

    # Square it out, so the app never has to reason about aspect ratio.
    edge = max(rgba.size)
    canvas = Image.new("RGBA", (edge, edge), (0, 0, 0, 0))
    canvas.paste(rgba, ((edge - rgba.width) // 2, (edge - rgba.height) // 2))
    canvas.resize((side, side), Image.LANCZOS).save(out)
    print(f"{out}  {side}×{side}")


if __name__ == "__main__":
    for p in sys.argv[1:]:
        cutout(p, p.replace(".png", "_cut.png"))
