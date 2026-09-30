#!/usr/bin/env python3
"""Imprime le corps JSON de l'icône d'app, pour NanoBanana.

    python3 tools/make-appicon.py > body.json
    curl -s --max-time 290 -X POST localhost:4747/generate \
         -H 'Content-Type: application/json' -d @body.json
    python3 tools/make-appicon.py --install /tmp/AppIcon.png

Troisième icône. La première était assemblée ici en polygones (étoile khatam
sable, socle doré, silhouette de sujud) ; la deuxième, dessinée par NanoBanana,
gardait l'étoile en or et la prosternation dedans, sur fond crème. Toutes deux se
perdaient à 60 px : la fiche ne récoltait que 6,4 % de clics sur ses affichages.
Depuis la 1.1 (01/10/2026), c'est une arche de mihrab dorée traversée par une
onde sonore, sur fond nuit — ce que fait l'app (on écoute, on répète), en une
forme qui contraste. Elle a été choisie parmi trois concepts dans App Store
Studio, qui n'a pas gardé son prompt : celui d'ici la décrit après coup, pour la
régénérer ou la décliner.

Les deux clauses de pudeur restent, même sans personnage : la tête sans aucun
trait si une silhouette réapparaît, et toute étoile **à huit branches** — un
hexagramme est le symbole du judaïsme et n'a rien à faire sur une app de salat,
et le modèle y glisse tout seul si on écrit juste « star ». Les points du ciel
sont de minuscules éclats à quatre branches, pas des étoiles dessinées.

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

PROMPT = """ONE single square image, 1:1, FULL BLEED: the background touches all four edges. This is an iOS APP ICON, so: NO rounded corners, NO frame, NO border, NO drop shadow, NO transparency, NO device mockup, NO text, NO letter, NO word, NO number, NO signature, NO watermark, NO sparkle in the corner.

Subject: the outline of a tall pointed Islamic mihrab arch, drawn as one thick glowing warm-gold line, centred, its two legs running off the bottom edge. Across the middle, from the left edge to the right edge, a glowing gold sound waveform crosses the arch, tallest at the centre and quieter towards the sides, with soft pale-cream vertical level bars behind it like an audio visualiser. Only two ideas: the arch, the voice.

ART DIRECTION:
- Background: deep night teal-blue gradient, #1E4550 at the top to #081820 at the bottom, a soft golden halo behind the tip of the arch, a few tiny four-point pinpoint sparkles in the sky.
- Gold #F5C542 to #E8A92E, glowing neon-like lines, smooth vector, gentle bloom. No other colour: no red, no green, no purple.
- Big simple masses, readable when the icon is 20 mm wide on a phone home screen. The arch fills about 70 % of the height.
- If a human figure ever appears, THE HEAD IS COMPLETELY BLANK — no eyes, no nose, no mouth, no ear, no hair, no face contour. Non-negotiable, religious modesty.
- Any star must be an EIGHT-POINTED ISLAMIC KHATAM star. NEVER a six-pointed star, never a hexagram, never a Star of David, never a crescent-and-star flag emblem.
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
