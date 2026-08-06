#!/usr/bin/env python3
"""Fabrique l'icône d'app (1024×1024) à partir d'une des illustrations de position.

L'icône reprend la DA de l'app : crème, sable, or, encre brune, contour épais et
face inférieure extrudée (le langage de formes de 5min/Design/Plate.swift). La
figure est la silhouette de `pos_sujud.png` — la posture la plus reconnaissable
de la salat, même à 60 pt.

    python3 tools/make-appicon.py [--position sujud]

Sortie : Salat/Assets.xcassets/AppIcon.appiconset/AppIcon.png
"""
from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "SalatKit" / "Resources"
OUT = ROOT / "Salat" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"

SIZE = 1024
CREAM = (251, 246, 236, 255)
SAND = (239, 227, 204, 255)
GOLD = (193, 150, 44, 255)
GOLD_DEEP = (154, 118, 30, 255)
INK = (46, 42, 34, 255)

# Rendu 4× puis réduit : les diagonales du khatam et le contour du socle sont
# tracés en polygones, ils crénellent sans supersampling.
SS = 4


def khatam(cx: float, cy: float, r: float) -> list[tuple[float, float]]:
    """Étoile à huit branches — le motif du fond, pas un hexagramme."""
    inner = r * 0.62
    pts = []
    for i in range(16):
        a = math.pi / 8 * i - math.pi / 2
        rad = r if i % 2 == 0 else inner
        pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
    return pts


def silhouette(name: str, height: int) -> Image.Image:
    """Charge une illustration et l'aplatit en encre brune, pixels conservés."""
    src = Image.open(RES / f"pos_{name}.png").convert("RGBA")
    src = src.crop(src.getbbox())
    w = round(src.width * height / src.height)
    src = src.resize((w, height), Image.NEAREST)  # NEAREST : la pixellisation est voulue
    flat = Image.new("RGBA", src.size, INK)
    flat.putalpha(src.getchannel("A"))
    return flat


def build(position: str) -> Image.Image:
    s = SIZE * SS
    img = Image.new("RGBA", (s, s), CREAM)
    d = ImageDraw.Draw(img)

    # Le motif du fond : une grande étoile sable, plus deux petites en écho.
    # Les petites restent à 17 % du bord : plus près, le masque arrondi d'iOS
    # les rogne.
    d.polygon(khatam(s * 0.5, s * 0.42, s * 0.36), fill=SAND)
    for cx, cy, r in ((0.17, 0.17, 0.07), (0.83, 0.17, 0.07)):
        d.polygon(khatam(s * cx, s * cy, s * r), fill=SAND)

    # Le socle : plaque dorée, contour d'encre, face inférieure extrudée.
    # La face du dessous se trace en premier ; la plaque du dessus recouvre
    # ensuite son arête haute, sinon un trait d'encre barre l'or.
    stroke = round(s * 0.011)
    x0, x1 = s * 0.11, s * 0.89
    top, bot = s * 0.735, s * 0.825
    depth = s * 0.032
    rad = s * 0.028
    d.rounded_rectangle(
        [x0, top + depth, x1, bot + depth], rad, fill=GOLD_DEEP, outline=INK, width=stroke
    )
    d.rounded_rectangle([x0, top, x1, bot], rad, fill=GOLD, outline=INK, width=stroke)

    # La figure, posée sur le socle (elle mord légèrement dessus).
    fig = silhouette(position, round(s * 0.30))
    img.alpha_composite(fig, (round(s * 0.5 - fig.width / 2), round(top - fig.height + stroke)))

    return img.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--position", default="sujud")
    args = ap.parse_args()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    build(args.position).save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
