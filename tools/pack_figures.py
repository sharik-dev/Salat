#!/usr/bin/env python3
"""Range les postures rendues par Blender dans SalatKit/Resources/pos_<nom>.png.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/icons.py -- --figures
    python3 tools/pack_figures.py

Chaque rendu (Design/figures-render/<nom>/f0.png) passe par la retouche d'ombre du kit
icon3d (`pack_icons.clean` : l'ombre s'éteint avant les bords, le voile gris part), puis
sort en 512 × 512 sur transparence. Ce sont des PNG libres dans le kit, pas un Asset
Catalog : l'app ET le widget les lisent par `PositionAsset`.
"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path.home() / "Documents/tools/icon3d"))
from pack_icons import clean, resize  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "Design/figures-render"
DST = ROOT / "SalatKit/Resources"

for folder in sorted(p for p in SRC.iterdir() if (p / "f0.png").exists()):
    out = DST / f"pos_{folder.name}.png"
    resize(clean(Image.open(folder / "f0.png")), 512).save(out, optimize=True)
    print(out.relative_to(ROOT))
