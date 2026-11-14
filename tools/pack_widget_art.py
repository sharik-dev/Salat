#!/usr/bin/env python3
"""Range dans le kit les deux objets 3D que le WIDGET dessine hors posture.

    python3 tools/pack_widget_art.py

Les icônes 3D de l'app vivent dans `Salat/Assets.xcassets/Icons3D`, que le widget
ne voit pas : il ne lit que `SalatKit/Resources`. Il lui en faut pourtant deux,
le Coran (à côté d'un verset) et le cadenas (widget verrouillé sans Premium).
Ce script prend leur image de repos dans `Design/icons-render/<nom>/f0.png`
(rendue par `tools/blender/icons.py`), lui applique la même retouche d'ombre
que `pack_figures.py`, et sort du 512 x 512 sur transparence, lu par
`PositionAsset` comme les `pos_*.png`.
"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path.home() / "Documents/tools/icon3d"))
from pack_icons import clean, resize  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "Design/icons-render"
DST = ROOT / "SalatKit/Resources"

for icon, name in (("quran", "widget_quran"), ("lock", "widget_lock")):
    source = SRC / icon / "f0.png"
    if not source.exists():
        sys.exit(f"{source.relative_to(ROOT)} manque : rendre l'icône d'abord")
    out = DST / f"{name}.png"
    resize(clean(Image.open(source)), 512).save(out, optimize=True)
    print(out.relative_to(ROOT))
