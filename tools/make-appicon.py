#!/usr/bin/env python3
"""Imprime le corps JSON de l'icône d'app, pour NanoBanana.

    python3 tools/make-appicon.py > body.json
    curl -s --max-time 290 -X POST localhost:4747/generate \
         -H 'Content-Type: application/json' -d @body.json
    python3 tools/make-appicon.py --install /tmp/AppIcon.png

L'icône était fabriquée ici même, en polygones : étoile khatam sable, socle doré
extrudé, silhouette de `pos_sujud.png` posée dessus. Elle empilait trois idées
dans un carré qui se regarde à 20 mm — Sharik l'a remplacée par un dessin, une
seule forme : l'étoile en or, la prosternation dedans.

Le prompt reste ici parce que c'est lui, désormais, la source de l'icône. Deux
clauses ne sont pas décoratives : la tête sans aucun trait (pudeur, comme pour
les positions) et l'étoile **à huit branches** — un hexagramme est le symbole du
judaïsme et n'a rien à faire sur une app de salat, et le modèle y glisse tout
seul si on écrit juste « star ».

`--install` fait le service après-vente d'un rendu : il efface l'étincelle que
le générateur tamponne dans un coin (une icône n'a pas de marge à recadrer, il
faut la repeindre), force 1024×1024 sans alpha — iOS refuse une icône
transparente — et l'écrit dans l'`AppIcon.appiconset`.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Salat" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"

PROMPT = """ONE single square image, 1:1, FULL BLEED: the flat background colour touches all four edges. This is an iOS APP ICON, so: NO rounded corners, NO frame, NO border, NO drop shadow, NO transparency, NO device mockup, NO text, NO letter, NO word, NO number, NO signature, NO watermark, NO sparkle in the corner.

Subject: a single warm gold eight-pointed Islamic khatam star, centred and large, on a plain cream field, with a small brown-ink silhouette of a man prostrating in prayer (sujud, side view, forehead to the ground) resting inside the middle of the star. Only two elements: the gold star, the ink figure.

ART DIRECTION — the app is a calm, printed-book-looking prayer app:
- Palette, and nothing else: cream #FBF6EC, sand #EFE3CC, warm gold #C1962C, brown ink #2E2A22. No pure black, no white, no saturated colour, no blue, no red, no green, no purple.
- Flat vector, thick hand-cut ink outlines like a linocut stamp. No gradient, no glow, no bevel, no gloss, no 3D, no photo, no texture, no shading, no hatching.
- Big simple masses, readable when the icon is 20 mm wide on a phone home screen. Two or three shapes maximum. Generous empty margin all around, nothing touching the edges.
- If a human figure appears, THE HEAD IS COMPLETELY BLANK — no eyes, no nose, no mouth, no ear, no hair, no face contour, one uninterrupted mass of ink. Non-negotiable, religious modesty.
- Any star must be an EIGHT-POINTED ISLAMIC KHATAM star (two overlaid squares). NEVER a six-pointed star, never a hexagram, never a Star of David, never a crescent-and-star flag emblem.
"""

SIZE = 1024


def install(path: Path) -> None:
    from PIL import Image

    im = Image.open(path).convert("RGB")
    bg = im.getpixel((4, 4))
    w, h = im.size
    px = im.load()
    for y in range(int(h * 0.78), h):
        for x in range(int(w * 0.78), w):
            r, g, b = px[x, y]
            if abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2]) < 90:
                px[x, y] = bg
    OUT.parent.mkdir(parents=True, exist_ok=True)
    im.resize((SIZE, SIZE), Image.LANCZOS).save(OUT)
    print(OUT)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--install", type=Path, help="rendu NanoBanana à poser comme icône")
    args = ap.parse_args()
    if args.install:
        install(args.install)
    else:
        print(json.dumps({"prompt": PROMPT, "output": "/tmp/AppIcon.png"}))


if __name__ == "__main__":
    main()
