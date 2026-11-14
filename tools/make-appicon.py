#!/usr/bin/env python3
"""Compose l'icône d'app : la mosquée 3D du bandeau, posée sur le vert de l'app.

    B=/Applications/Blender.app/Contents/MacOS/Blender
    $B -b -P tools/blender/icons.py -- --appicon     # Design/appicon-render/mosque.png
    python3 tools/make-appicon.py                    # AppIcon.png, 1024×1024 sans alpha

Quatrième icône (14/11/2026). La troisième, une arche dorée sur fond nuit
générée par NanoBanana, ne ressemblait plus à rien de ce qu'on voit une fois
l'app ouverte après la refonte « Jardin ». Sharik a demandé la mosquée du
bandeau d'*Apprendre* : l'icône est désormais le même objet, rendu par le même
script Blender, sur le même vert et le même treillis que le bandeau. Ouvrir
l'app, c'est retrouver ce qu'on a touché sur l'écran d'accueil.

Rien n'est dessiné à la main ici : le fond (dégradé vert, treillis d'étoiles à
**huit** branches, halo) est calculé, la mosquée vient du rendu. iOS refuse une
icône transparente, d'où la sortie en RGB.
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "Design" / "appicon-render" / "mosque.png"
OUT = ROOT / "Salat" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"

SIZE = 1024
SS = 2                      # suréchantillonnage du fond, pour des traits nets
TOP = (0x3D, 0xBB, 0x82)    # un cran plus clair que Theme.primary
BOTTOM = (0x23, 0x8E, 0x5D) # un cran plus sombre
SUBJECT = 0.80              # part de la largeur occupée par la mosquée


def khatam(cx: float, cy: float, r: float) -> list[list[tuple[float, float]]]:
    """Deux carrés à 45° : l'étoile à huit branches du treillis de l'app."""
    squares = []
    for rot in (0.0, math.pi / 4):
        squares.append([(cx + r * math.cos(rot + k * math.pi / 2),
                         cy + r * math.sin(rot + k * math.pi / 2)) for k in range(4)])
    return squares


def background() -> Image.Image:
    n = SIZE * SS
    bg = Image.new("RGB", (n, n))
    px = bg.load()
    for y in range(n):
        t = y / (n - 1)
        row = tuple(round(TOP[c] + (BOTTOM[c] - TOP[c]) * t) for c in range(3))
        for x in range(n):
            px[x, y] = row

    # Le treillis, en blanc très léger, décalé d'une demi-maille une ligne sur deux.
    lattice = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    draw = ImageDraw.Draw(lattice)
    step = 150 * SS
    row = 0
    y = 0.0
    while y < n + step:
        x = 0.0 if row % 2 == 0 else step / 2
        while x < n + step:
            for square in khatam(x, y, step * 0.30):
                draw.line(square + [square[0]], fill=(255, 255, 255, 34), width=3 * SS, joint="curve")
            x += step
        y += step
        row += 1
    bg.paste(lattice, (0, 0), lattice)

    # Un halo clair derrière la coupole : c'est lui qui détache la mosquée du fond.
    halo = Image.new("L", (n, n), 0)
    ImageDraw.Draw(halo).ellipse((n * 0.14, n * 0.10, n * 0.86, n * 0.82), fill=120)
    halo = halo.filter(ImageFilter.GaussianBlur(n * 0.09))
    bg.paste(Image.new("RGB", (n, n), (255, 255, 255)), (0, 0), halo)
    return bg.resize((SIZE, SIZE), Image.LANCZOS)


def strip_shadow(img: Image.Image) -> Image.Image:
    """Retire l'ombre au sol du rendu : c'est du noir pur à alpha partiel, coupé net par le
    bord de l'image, et l'icône pose la sienne. L'objet et son liseré ont une couleur, on
    les reconnaît à ça (même test que `pack_icons.clean` du kit icon3d)."""
    import numpy as np

    px = np.asarray(img.convert("RGBA")).astype(np.float32)
    shadow = np.clip((48 - px[..., :3].max(-1)) / 32, 0, 1)   # 1 = ombre pure
    px[..., 3] *= 1 - shadow
    return Image.fromarray(px.round().astype(np.uint8), "RGBA")


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"rendu manquant : {SRC} (lancer icons.py -- --appicon)")
    icon = background()

    mosque = strip_shadow(Image.open(SRC))
    mosque = mosque.crop(mosque.getbbox())
    scale = SIZE * SUBJECT / max(mosque.size)
    mosque = mosque.resize((round(mosque.width * scale), round(mosque.height * scale)), Image.LANCZOS)
    x = (SIZE - mosque.width) // 2
    y = (SIZE - mosque.height) // 2 - round(SIZE * 0.012)

    # L'ombre de contact : la silhouette elle-même, écrasée, floutée, glissée vers le bas.
    alpha = mosque.getchannel("A")
    shadow = Image.new("L", (SIZE, SIZE), 0)
    shadow.paste(alpha.point(lambda a: a * 0.42), (x, y + round(SIZE * 0.035)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(SIZE * 0.03))
    icon.paste(Image.new("RGB", (SIZE, SIZE), (0x12, 0x4A, 0x30)), (0, 0), shadow)

    icon.paste(mosque, (x, y), mosque)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    icon.convert("RGB").save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
