"""Icônes 3D et postures de Salat, modélisées en code dans Blender.

    B=/Applications/Blender.app/Contents/MacOS/Blender
    $B -b -P tools/blender/icons.py -- [--still] [nom ...]        # icônes, 7 images chacune
    $B -b -P tools/blender/icons.py -- --figures [--still] [nom]  # les neuf postures, 1 image
    python3 ~/Documents/tools/icon3d/pack_icons.py Design/icons-render Salat/Assets.xcassets/Icons3D
    python3 tools/pack_figures.py                                 # → SalatKit/Resources/pos_*.png

Les briques (slab, loft, lathe, tube, ball, box, upright…), l'éclairage, les animations et
le rendu viennent du kit partagé ~/Documents/tools/icon3d (voir son README). Ici, seulement
les modèles. Palette = celle de `Theme` : vert jardin, crème, beige, or.

Le personnage des postures n'a AUCUN trait de visage (ni yeux, ni bouche, ni nez) : une
tête lisse sous un kufi, c'est la règle du projet (voir CLAUDE.md, « Illustrations »).
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path.home() / "Documents/tools/icon3d"))
import icon3d  # noqa: E402
from icon3d import *  # noqa: E402,F403

ROOT = Path(__file__).resolve().parents[2]

G, GD, GL, MINT = 0x2FA56F, 0x1E7A50, 0x7FD3A6, 0xDDF3E6
CREAM, BEIGE, SAND = 0xFFF6E3, 0xEAD9B8, 0xD4BC8E
GOLD, GOLDD, PALE = 0xF2B93B, 0xC98A1C, 0xFFE7A0
INK, WHITE, CORAL, STEEL, STEELD = 0x23402F, 0xFFFFFF, 0xEB5B4B, 0xC9C2B2, 0x9C937F
SHINY = dict(rough=0.25, coat=0.7)


# ================================================================ petites formes

def khatam(r, cx=0, cy=0):
    """L'étoile à huit branches : deux carrés à 45°. Jamais un hexagramme."""
    return [(cx + (r if k % 2 == 0 else r * 0.765) * math.cos(R(22.5 * k)),
             cy + (r if k % 2 == 0 else r * 0.765) * math.sin(R(22.5 * k))) for k in range(16)]


def arch(w, h, cx=0, y0=0):
    """Rectangle coiffé d'un demi-disque, hauteur totale `h`."""
    r = w / 2
    return [(cx - r, y0), (cx + r, y0)] + arc(cx, y0 + h - r, r, 0, 180, 16)


def ring(r, radius, color, z=0.0, **kw):
    return tube(arc(0, 0, r, 0, 360, 64)[:-1], radius, color, cyclic=True, loc=(0, 0, z), **kw)


def check_mark(color, scale=1.0, z=0.0):
    pts = [(-0.5, 0.02), (-0.14, -0.34), (0.52, 0.32)]
    tube([(x * scale, y * scale, z) for x, y in pts], 0.11 * scale, color)


def sparkle4(r, color, loc, **kw):
    pts = [((r if k % 2 == 0 else r * 0.3) * math.cos(R(45 * k)), (r if k % 2 == 0 else r * 0.3) * math.sin(R(45 * k)))
           for k in range(8)]
    return slab(fillet(pts, [r * 0.1, r * 0.14] * 4), r * 0.45, color, bevel=r * 0.16, loc=loc, **kw)


# ================================================================ onglets

def book():
    """Livre ouvert, penché vers le lecteur ; un signet doré pend de la reliure."""
    with upright(1.25, 62):
        slab(rrect(2.9, 2.0, 0.14), 0.16, G, bevel=0.06)
        for side in (-1, 1):
            with group(loc=(0, 0, 0.1), rot=(0, R(-8 * side), 0)):
                page = [(0, -0.88), (side * 1.32, -0.88), (side * 1.32, 0.88), (0, 0.88)]
                slab(fillet(page, [0, 0.1, 0.1, 0]), 0.22, CREAM, bevel=0.05)
                for k, w in enumerate((0.8, 0.8, 0.8, 0.5)):
                    cx = side * 0.68 - (0.8 - w) / 2
                    slab(rrect(w, 0.085, 0.04, cx, 0.5 - k * 0.3), 0.03, GL if k == 0 and side < 0 else SAND,
                         bevel=0.01, loc=(0, 0, 0.12))
        slab(rrect(0.2, 0.75, 0.05, 0, -1.18), 0.05, GOLD, bevel=0.02, loc=(0, 0, 0.16), **SHINY)


def quran():
    """Mushaf fermé : couverture verte, cadre et étoile d'or, tranche crème, signet."""
    with upright(1.3, 66):
        slab(rrect(2.0, 2.7, 0.12), 0.12, GD, bevel=0.05)
        slab(rrect(1.84, 2.56, 0.05, 0.06, 0), 0.42, CREAM, bevel=0.03, loc=(0, 0, 0.27))
        slab(rrect(0.2, 2.7, 0.08, -0.9, 0), 0.66, G, bevel=0.05, loc=(0, 0, 0.27))
        slab(rrect(2.0, 2.7, 0.12), 0.12, G, bevel=0.05, loc=(0, 0, 0.54), rough=0.3, coat=0.5)
        slab(rrect(1.5, 2.2, 0.1, 0.08, 0), 0.03, GOLD, bevel=0.01, holes=[rrect(1.34, 2.04, 0.07, 0.08, 0)],
             loc=(0, 0, 0.61), **SHINY)
        slab(fillet(khatam(0.4, 0.08, 0), 0.03), 0.06, GOLD, bevel=0.02, loc=(0, 0, 0.62), **SHINY)
        slab(rrect(0.18, 0.6, 0.05, 0.45, -1.5), 0.04, GOLD, bevel=0.015, loc=(0, 0, 0.27), **SHINY)


def bulb():
    """Ampoule allumée : ça fait tilt."""
    lathe([(0.001, 0), (0.3, 0), (0.42, 0.1), (0.44, 0.62), (0.001, 0.62)], STEEL, rough=0.25)
    for z in (0.22, 0.42):
        ring(0.45, 0.045, STEELD, z=z)
    lathe([(0.4, 0.6), (0.5, 0.85), (0.8, 1.25), (1.0, 1.7), (1.02, 2.05), (0.9, 2.4), (0.62, 2.68),
           (0.3, 2.82), (0.001, 2.86)], 0xFFD45E, rough=0.2, coat=0.8, emit=0.35)
    with group(loc=(0, 0, 1.9), rot=(R(84), 0, 0)) as rays:
        for a in (-25, 15, 52, 90, 128, 165, 205):
            with group(rot=(0, 0, R(a))):
                puck(0.09, 0.42, PALE, edge=0.085, axis="x", loc=(1.62, 0, 0), emit=0.2)
    animate(rays, scale=[1, 1.06, 1.13, 1.05, 0.95, 1.02, 1])


def gear():
    with upright(1.25, 84):
        with group() as cog:                                             # 8 dents : 45° en 7 images, la boucle est invisible
            pts = []
            for k in range(8):
                a = 45 * k
                for da, r in ((-13, 0.84), (-8, 1.14), (8, 1.14), (13, 0.84)):
                    pts.append((r * math.cos(R(a + da)), r * math.sin(R(a + da))))
            slab(fillet(pts, 0.06), 0.42, STEEL, bevel=0.14, holes=[arc(0, 0, 0.34, 0, 360, 40)[:-1]])
            ring(0.58, 0.05, STEELD, z=0.2)
        animate(cog, rot=about("z", [-45 * i / 7 for i in range(7)]))


# ================================================================ décor de la prière

def mosque():
    """Petite mosquée : salle crème, coupole verte, deux minarets, fenêtres allumées."""
    box((2.5, 1.5, 1.25), CREAM, loc=(0, 0, 0.625), bevel=0.12)
    box((2.7, 1.7, 0.16), BEIGE, loc=(0, 0, 1.3), bevel=0.06)
    puck(0.86, 0.3, BEIGE, loc=(0, 0, 1.5), edge=0.06)
    lathe([(0.8, 1.6), (0.96, 1.8), (1.0, 2.05), (0.9, 2.35), (0.66, 2.62), (0.34, 2.84), (0.1, 2.98),
           (0.05, 3.1), (0.001, 3.14)], G, rough=0.28, coat=0.6)
    ball(0.1, GOLD, loc=(0, 0, 3.2), **SHINY)
    with group(loc=(0, -0.76, 0), rot=(R(90), 0, 0)):
        slab(arch(0.62, 0.9), 0.08, GD, bevel=0.03)
        for x in (-0.82, 0.82):
            slab(arch(0.3, 0.5, x, 0.45), 0.06, GOLD, bevel=0.02, emit=0.25)
    for side in (-1, 1):
        x = side * 1.62
        puck(0.24, 2.5, CREAM, loc=(x, 0, 1.25), edge=0.06)
        puck(0.34, 0.16, BEIGE, loc=(x, 0, 2.1), edge=0.05)
        lathe([(0.3, 2.5), (0.26, 2.62), (0.14, 3.0), (0.001, 3.3)], G, loc=(x, 0, 0))
        ball(0.07, GOLD, loc=(x, 0, 3.34), **SHINY)


def mat():
    """Tapis de prière : niche claire, étoile d'or, franges aux deux bouts."""
    with upright(1.6, 64):
        slab(rrect(1.9, 2.9, 0.1), 0.12, G, bevel=0.05)
        slab(rrect(1.62, 2.62, 0.08), 0.03, GOLD, bevel=0.01, holes=[rrect(1.46, 2.46, 0.06)], loc=(0, 0, 0.07))
        niche = fillet([(-0.52, -0.95), (0.52, -0.95), (0.52, 0.25), (0, 0.98), (-0.52, 0.25)], [0.06, 0.06, 0.3, 0.05, 0.3])
        slab(niche, 0.04, MINT, bevel=0.015, loc=(0, 0, 0.075))
        slab(fillet(khatam(0.26, 0, -0.2), 0.02), 0.05, GOLD, bevel=0.02, loc=(0, 0, 0.1), **SHINY)
        for end in (-1, 1):
            for k in range(9):
                x = -0.84 + k * 0.21
                tube([(x, end * 1.45, 0), (x, end * 1.68, 0)], 0.035, CREAM)


def lantern():
    """Fanous : verre allumé, armature dorée, chapeau vert."""
    lathe([(0.001, 0), (0.62, 0), (0.68, 0.1), (0.6, 0.24), (0.5, 0.3)], GOLD, **SHINY)
    lathe([(0.48, 0.28), (0.74, 0.95), (0.74, 1.45), (0.5, 2.05)], 0xFFE9A8, rough=0.2, coat=0.8, emit=0.45)
    for k in range(6):
        a = R(60 * k + 30)
        tube([(r * math.cos(a), r * math.sin(a), z) for r, z in ((0.5, 0.28), (0.76, 0.95), (0.76, 1.45), (0.52, 2.05))],
             0.045, GOLD, **SHINY)
    lathe([(0.58, 2.02), (0.66, 2.12), (0.5, 2.32), (0.3, 2.62), (0.1, 2.82), (0.001, 2.86)], G, rough=0.28, coat=0.6)
    tube([(0.2 * math.cos(R(a)), 0, 3.04 + 0.2 * math.sin(R(a))) for a in range(0, 360, 20)], 0.05, GOLD, cyclic=True, **SHINY)


def star():
    """Khatam d'or : la récompense, et le motif de la maison."""
    with upright(1.3, 84):
        slab(fillet(khatam(1.2), 0.07), 0.42, GOLD, bevel=0.16, rough=0.3, coat=0.6)
        slab(fillet(khatam(0.62), 0.04), 0.12, PALE, bevel=0.04, loc=(0, 0, 0.2))


def moon():
    """Croissant d'or et deux étincelles, pour le décor des bandeaux."""
    with upright(1.35, 84):
        outer = arc(0, 0, 1.1, 58, 302, 48)
        inner = arc(0.62, 0, 0.86, 262, 98, 36)
        slab(outer + inner, 0.36, 0xFFD45E, bevel=0.07, rot=(0, 0, R(-20)), rough=0.3, coat=0.6)
        for x, y, r in ((0.55, 0.4, 0.3), (0.95, -0.3, 0.18)):
            with group(loc=(x, y, 0)) as tw:
                sparkle4(r, PALE, (0, 0, 0))
            animate(tw, scale=[1, 0.6, 1.3, 0.8, 1.15, 0.95, 1] if x < 0.9 else [1, 1.3, 0.7, 1.2, 0.85, 1.05, 1])


def sparkle():
    with upright(1.0, 72):
        sparkle4(1.0, 0xFFD45E, (0, 0, 0), rough=0.3, coat=0.6, emit=0.15)


# ================================================================ outils de mémorisation

def quiz():
    """Bulle verte, point d'interrogation : on te pose la question."""
    with upright(1.3, 84):
        pts = [(-1.1, -0.5), (-0.62, -0.5), (-0.86, -0.98), (-0.22, -0.5), (1.1, -0.5), (1.1, 0.95), (-1.1, 0.95)]
        slab(fillet(pts, [0.32, 0.02, 0.06, 0.02, 0.32, 0.32, 0.32]), 0.36, G, bevel=0.13)
        text("?", 1.3, WHITE, loc=(0, 0.2, 0.19), depth=0.05)


def cards():
    """Deux cartes mémoire en éventail ; celle du dessus se balance."""
    with upright(1.5, 82):
        with group(loc=(0.3, 0.05, -0.14), rot=(0, 0, R(-12))):
            slab(rrect(1.5, 2.1, 0.2), 0.12, GL, bevel=0.05)
        with group(loc=(-0.12, 0, 0.06), rot=(0, 0, R(7))) as front:
            slab(rrect(1.5, 2.1, 0.2), 0.12, WHITE, bevel=0.05)
            slab(fillet(khatam(0.34, 0, 0.42), 0.02), 0.05, GOLD, bevel=0.02, loc=(0, 0, 0.08), **SHINY)
            for k, w in enumerate((0.9, 0.9, 0.55)):
                slab(rrect(w, 0.1, 0.05, 0, -0.2 - k * 0.24), 0.03, BEIGE, bevel=0.01, loc=(0, 0, 0.075))
        animate(front, rot=about("z", [0, -4, -9, -5, 3, 5, 2]))


def eraser():
    """Gomme qui passe sur une ligne : les mots s'effacent."""
    for x, w, c in ((-1.0, 0.8, INK), (0.0, 0.8, INK), (1.05, 0.9, SAND)):
        puck(0.12, w, c, axis="x", loc=(x, -0.95, 0.12), edge=0.11)
    with group(loc=(0.35, 0.15, 0.8), rot=(0, R(-26), R(14))) as gum:
        box((2.3, 1.05, 0.8), CREAM, bevel=0.2)
        box((1.2, 1.1, 0.85), G, loc=(-0.4, 0, 0), bevel=0.14)
    animate(gum, loc=[(0, 0, 0), (-0.25, 0, 0), (0.2, 0, 0), (-0.2, 0, 0), (0.15, 0, 0), (-0.08, 0, 0), (0, 0, 0)])


def mic():
    """Micro de studio sur son pied."""
    puck(0.8, 0.22, INK, loc=(0, 0, 0.11), edge=0.08)
    tube([(0, 0, 0.2), (0, 0, 0.95)], 0.09, STEEL)
    tube([(0.78 * math.cos(R(a)), 0, 1.72 + 0.78 * math.sin(R(a))) for a in range(180, 361, 10)], 0.08, STEEL)
    for side in (-1, 1):
        puck(0.1, 0.3, STEEL, axis="x", loc=(side * 0.66, 0, 1.72), edge=0.05)
    with group(loc=(0, 0, 2.0)) as head:
        puck(0.56, 1.8, G, edge=0.55)
        for z in (-0.2, 0.1, 0.4):
            ring(0.565, 0.035, GD, z=z)
        puck(0.585, 0.3, GOLD, loc=(0, 0, -0.55), edge=0.05, **SHINY)
    animate(head, rot=about("y", [0, -6, 5, -3, 2, -1, 0]))


def phone():
    """Téléphone dont l'écran d'accueil porte le widget."""
    with upright(1.5, 82):
        slab(rrect(1.5, 2.7, 0.34), 0.22, INK, bevel=0.08)
        slab(rrect(1.3, 2.5, 0.25), 0.04, CREAM, bevel=0.015, loc=(0, 0, 0.11))
        slab(rrect(0.42, 0.13, 0.065, 0, 1.06), 0.04, INK, bevel=0.015, loc=(0, 0, 0.13))
        with group(loc=(0, 0.28, 0.13)) as tile:
            slab(rrect(1.02, 1.02, 0.2), 0.08, G, bevel=0.03)
            slab(fillet(khatam(0.19, -0.24, 0.22), 0.015), 0.04, GOLD, bevel=0.015, loc=(0, 0, 0.06))
            for k, w in enumerate((0.72, 0.5)):
                slab(rrect(w, 0.09, 0.045, -0.37 + w / 2, -0.12 - k * 0.2), 0.03, WHITE, bevel=0.01, loc=(0, 0, 0.055))
        for col in range(3):
            slab(rrect(0.3, 0.3, 0.09, -0.36 + col * 0.36, -0.74), 0.05, (GL, GOLD, BEIGE)[col], bevel=0.02, loc=(0, 0, 0.13))
        animate(tile, scale=[1, 1.04, 1.1, 1.05, 0.97, 1.01, 1])


def headphones():
    tube([(1.02 * math.cos(R(a)), 0, 0.95 + 1.02 * math.sin(R(a))) for a in range(0, 181, 8)], 0.12, INK)
    for side in (-1, 1):
        puck(0.6, 0.46, G, axis="x", loc=(side * 1.06, 0, 0.72), edge=0.16)
        puck(0.48, 0.26, CREAM, axis="x", loc=(side * 0.8, 0, 0.72), edge=0.12)
        puck(0.26, 0.52, GD, axis="x", loc=(side * 1.1, 0, 0.72), edge=0.08)


# ================================================================ statuts et progression

def check():
    with upright(1.15, 84):
        n = 16
        badge = [((1.05 if i % 2 == 0 else 0.9) * math.cos(2 * math.pi * i / n),
                  (1.05 if i % 2 == 0 else 0.9) * math.sin(2 * math.pi * i / n)) for i in range(n)]
        slab(fillet(badge, 0.08), 0.32, 0x4FC98A, bevel=0.12)
        puck(0.7, 0.36, G, edge=0.05)
        check_mark(WHITE, 0.8, z=0.22)


def sprout():
    """Pousse en pot : l'étape qu'on est en train d'apprendre."""
    lathe([(0.001, 0), (0.55, 0), (0.6, 0.06), (0.82, 0.95), (0.9, 0.98), (0.9, 1.18), (0.8, 1.2), (0.001, 1.14)], 0xE0966A)
    puck(0.76, 0.1, 0x6B4A2F, loc=(0, 0, 1.16), edge=0.04, rough=0.8, coat=0)
    with group(loc=(0, 0, 1.15)) as plant:
        tube([(0, 0, 0), (0.04, 0, 0.5), (0, 0, 0.95)], 0.07, G)
        for side in (-1, 1):
            with group(loc=(0, 0, 0.95), rot=(0, R(-38 * side), 0)):
                ball((0.52, 0.1, 0.27), G if side > 0 else GL, loc=(0.5 * side, 0, 0))
    animate(plant, scale=[(1, 1, 1), (1, 1, 0.92), (1, 1, 1.08), (1, 1, 1.13), (1, 1, 1.04), (1, 1, 0.98), (1, 1, 1)])


def flame():
    with upright(1.45, 84):
        outer = [(0, -1.25), (0.8, -0.85), (0.98, -0.1), (0.62, 0.6), (0.32, 1.0), (0.12, 1.6), (-0.28, 0.95),
                 (-0.74, 0.45), (-0.98, -0.2), (-0.74, -0.9)]
        slab(fillet(outer, [0.4, 0.4, 0.4, 0.3, 0.2, 0.06, 0.3, 0.3, 0.4, 0.4]), 0.42, 0xFF8A3C, bevel=0.16)
        inner = [(x * 0.52, y * 0.55 - 0.42) for x, y in outer]
        slab(fillet(inner, [0.2, 0.2, 0.2, 0.15, 0.1, 0.04, 0.15, 0.15, 0.2, 0.2]), 0.2, 0xFFD45E, bevel=0.07,
             loc=(0, 0, 0.2), emit=0.2)


def calendar():
    with upright(1.3, 82):
        slab(rrect(2.2, 2.2, 0.28), 0.34, WHITE, bevel=0.1)
        top = fillet([(-1.1, 0.42), (1.1, 0.42), (1.1, 1.1), (-1.1, 1.1)], [0, 0, 0.28, 0.28])
        slab(top, 0.38, G, bevel=0.1)
        for x in (-0.55, 0.55):
            puck(0.1, 0.5, STEEL, edge=0.08, loc=(x, 1.08, 0.12), rot=(R(90), 0, 0))
        for row in range(3):
            for col in range(4):
                today = (row, col) == (1, 2)
                slab(rrect(0.34, 0.34, 0.09, -0.69 + col * 0.46, 0.08 - row * 0.44), 0.08 if today else 0.05,
                     GOLD if today else BEIGE, bevel=0.02, loc=(0, 0, 0.18))


def chart():
    """Trois barres qui montent : la page de progression."""
    box((2.6, 1.0, 0.2), BEIGE, loc=(0, 0, 0.1), bevel=0.08)
    for x, h, c in ((-0.8, 0.9, GL), (0, 1.5, GOLD), (0.8, 2.2, G)):
        with group(loc=(x, 0, 0.2)) as bar:
            box((0.6, 0.6, h), c, loc=(0, 0, h / 2), bevel=0.12)
        animate(bar, scale=[(1, 1, 1), (1, 1, 0.9), (1, 1, 1.08), (1, 1, 1.12), (1, 1, 1.04), (1, 1, 0.98), (1, 1, 1)])


def trophy():
    wood = 0x7A4A2A
    box((1.3, 1.3, 0.4), wood, loc=(0, 0, 0.2), bevel=0.1)
    lathe([(0.5, 0.4), (0.42, 0.52), (0.16, 0.66), (0.14, 1.0), (0.3, 1.14), (0.72, 1.5), (0.92, 2.1), (0.96, 2.6),
           (0.86, 2.6), (0.8, 2.15), (0.001, 1.6)], GOLD, **SHINY)
    for side in (-1, 1):
        tube([(side * (0.86 + 0.42 * math.sin(R(a))), 0, 2.0 + 0.4 * math.cos(R(a))) for a in range(0, 181, 12)], 0.08, GOLD, **SHINY)
    with group(loc=(0, -0.66, 0.2), rot=(R(90), 0, 0)):
        slab(fillet(khatam(0.16), 0.01), 0.04, GOLD, bevel=0.015, **SHINY)


# ================================================================ réglages

def globe():
    blue = 0x4AA8E0
    lathe([(0.001, 0), (0.75, 0), (0.82, 0.06), (0.8, 0.14), (0.3, 0.22), (0.12, 0.3), (0.1, 0.42)], GOLDD)
    with group(loc=(0, 0, 1.62), rot=(0, R(18), 0)):
        tube([(1.27 * math.cos(R(a)), 0, 1.27 * math.sin(R(a))) for a in range(-100, 101, 8)], 0.07, GOLD)
        for z in (-1.27, 1.27):
            ball(0.12, GOLD, loc=(0, 0, z))
        with group() as earth:
            ball(1.1, blue, rough=0.3, coat=0.6)
            for lat, lon, r in ((35, -100, 0.42), (10, -85, 0.3), (-20, -70, 0.36), (45, 10, 0.4), (5, 15, 0.42),
                                (-25, 25, 0.3), (40, 80, 0.46), (55, 120, 0.34), (-28, 135, 0.3), (60, -40, 0.22)):
                d = 1.1 - r * 0.72
                ball(r, 0x4FC98A, loc=(d * math.cos(R(lat)) * math.cos(R(lon)), d * math.cos(R(lat)) * math.sin(R(lon)),
                                       d * math.sin(R(lat))), rough=0.5)
        animate(earth, rot=about("z", [0, 22, 48, 76, 50, 24, 6]))


def bell():
    lathe([(0.0, 0.3), (0.95, 0.3), (1.1, 0.35), (1.14, 0.44), (1.02, 0.54), (0.84, 0.72),
           (0.74, 1.1), (0.68, 1.5), (0.56, 1.82), (0.36, 2.02), (0.0, 2.1)], GOLD, rough=0.24, coat=0.7)
    animate(ball(0.22, GOLDD, loc=(0, 0, 0.22)),
            loc=[(0, 0, 0), (0.32, 0, 0.04), (-0.32, 0, 0.04), (0.22, 0, 0.02), (-0.14, 0, 0), (0.06, 0, 0), (0, 0, 0)])
    tube(arc(0, 0, 0.13, 0, 360, 24)[:-1], 0.05, GOLDD, cyclic=True, loc=(0, 0, 2.2), rot=(R(90), 0, 0))
    ball(0.3, CORAL, loc=(0.72, -0.5, 1.9))


def scroll():
    """Parchemin : à propos, sources, crédits."""
    with upright(1.5, 82):
        slab(rrect(1.8, 2.3, 0.05), 0.08, CREAM, bevel=0.03)
        for y in (1.15, -1.15):
            puck(0.2, 2.15, BEIGE, axis="x", loc=(0, y, 0.06), edge=0.12)
            for x in (-1.12, 1.12):
                ball(0.13, GOLD, loc=(x, y, 0.06), **SHINY)
        for k, w in enumerate((1.2, 1.2, 1.2, 0.7)):
            slab(rrect(w, 0.09, 0.045, -0.6 + w / 2, 0.62 - k * 0.3), 0.03, SAND, bevel=0.01, loc=(0, 0, 0.055))
        puck(0.24, 0.08, G, loc=(0.48, -0.62, 0.07), edge=0.03)


def shield():
    with upright(1.3, 84):
        pts = [(0, 1.2), (1.0, 0.85), (1.0, 0.0), (0.62, -0.8), (0, -1.25), (-0.62, -0.8), (-1.0, 0.0), (-1.0, 0.85)]
        slab(fillet(pts, [0.1, 0.2, 0.3, 0.3, 0.12, 0.3, 0.3, 0.2]), 0.4, G, bevel=0.15)
        check_mark(WHITE, 0.85, z=0.22)


def lock():
    shackle = [(0.55 * math.cos(R(a)), 0, 1.45 + 0.6 * math.sin(R(a))) for a in range(0, 181, 8)]
    anse = tube([(0.55, 0, 0.9)] + shackle + [(-0.55, 0, 0.9)], 0.15, STEEL)
    animate(anse, loc=[(0, 0, 0), (0, 0, 0.12), (0, 0, 0.3), (0, 0, 0.3), (0, 0, 0.14), (0, 0, 0), (0, 0, 0)])
    box((1.7, 0.8, 1.35), GOLD, loc=(0, 0, 0.75), bevel=0.24)
    with group(loc=(0, -0.41, 0.8), rot=(R(90), 0, 0)):
        puck(0.14, 0.06, 0x7A4A00)
        slab(fillet([(-0.07, 0), (0.07, 0), (0.1, -0.36), (-0.1, -0.36)], 0.04), 0.06, 0x7A4A00, bevel=0.02)


def trash():
    deep = 0xD23A33
    lathe([(0.001, 0), (0.68, 0), (0.74, 0.06), (0.9, 1.86), (0.8, 1.86), (0.001, 1.8)], CORAL)
    for a in (-52, -18, 16, 50):
        r0, r1 = 0.77, 0.9
        tube([(r0 * math.cos(R(a - 90)), r0 * math.sin(R(a - 90)), 0.35), (r1 * math.cos(R(a - 90)), r1 * math.sin(R(a - 90)), 1.6)], 0.05, deep)
    with group(loc=(0, 0, 1.98)) as lid:
        puck(1.02, 0.22, deep, edge=0.09)
        tube([(0.24 * math.cos(R(a)), 0, 0.1 + 0.2 * math.sin(R(a))) for a in range(0, 181, 15)], 0.06, deep)
    animate(lid, loc=[(0, 0, 0), (0, 0, 0.15), (0, 0, 0.42), (0, 0, 0.5), (0, 0, 0.3), (0, 0, 0.06), (0, 0, 0)],
            rot=about("y", [0, 4, 14, 16, 9, 2, 0]))


ICONS = {
    "book": (book, SWING, -10),
    "quran": (quran, SWING, -24),
    "bulb": (bulb, PULSE, -8),
    "gear": (gear, STILL, -12),
    "mosque": (mosque, HOP, -22),
    "mat": (mat, SWING, -14),
    "lantern": (lantern, SWING, -10),
    "star": (star, TURN, -10),
    "moon": (moon, STILL, -8, AIR),
    "sparkle": (sparkle, PULSE, 0, AIR),
    "quiz": (quiz, HOP, -12),
    "cards": (cards, STILL, -10),
    "eraser": (eraser, STILL, -18),
    "mic": (mic, STILL, -14),
    "phone": (phone, STILL, -14),
    "headphones": (headphones, HOP, -16),
    "check": (check, TURN, -14),
    "sprout": (sprout, STILL, -10),
    "flame": (flame, PULSE, -8),
    "calendar": (calendar, HOP, -14),
    "chart": (chart, STILL, -24),
    "trophy": (trophy, HOP, -16),
    "globe": (globe, STILL, -10),
    "bell": (bell, SWING, -12),
    "scroll": (scroll, SWING, -12),
    "shield": (shield, HOP, -16),
    "lock": (lock, SWING, -14),
    "trash": (trash, STILL, -14),
}


# ================================================================ le personnage des postures
# Devant = −y. « Droite » du personnage = x négatif quand il fait face à la caméra.
# Formes en boudins de pâte à modeler : un thobe crème, un kufi vert, une tête SANS visage.

THOBE, SKIN = 0xFFFBF0, 0xD9A77C
SOFT = dict(rough=0.5, coat=0.15)
HEAD = 0.34


def limb(points, r, color=THOBE):
    """Boudin qui passe par `points`, une boule à chaque articulation."""
    tube(points, r, color, **SOFT)
    for p in points:
        ball(r, color, loc=p, **SOFT)


def head(loc, rot=(0, 0, 0)):
    """Tête lisse sous un kufi. Le devant est un simple méplat de la même couleur, sans aucun
    trait : il donne un sens à la tête (on voit de quel côté elle est tournée) sans dessiner
    de visage."""
    with group(loc=loc, rot=tuple(R(a) for a in rot)):
        ball((HEAD, HEAD, HEAD * 1.04), SKIN, **SOFT)
        ball((HEAD * 0.84, HEAD * 0.62, HEAD * 0.88), SKIN, loc=(0, -HEAD * 0.5, -HEAD * 0.1), **SOFT)
        lathe([(HEAD + 0.012, 0.13), (HEAD + 0.015, 0.22), (0.27, 0.34), (0.12, 0.39), (0.001, 0.395)], G, rough=0.45, coat=0.2)


def hand(loc, flat=False, scale=None):
    ball(scale or ((0.13, 0.17, 0.08) if flat else 0.13), SKIN, loc=loc, **SOFT)


def feet(y=-0.16, z=0.09, spread=0.2):
    for s in (-1, 1):
        ball((0.14, 0.23, 0.09), SKIN, loc=(s * spread, y, z), **SOFT)


ARM = 0.15


def robe_standing():
    with group(scale=(1, 0.66, 1)):
        lathe([(0.001, 0.14), (0.5, 0.14), (0.54, 0.2), (0.5, 0.6), (0.43, 1.2), (0.44, 1.6), (0.5, 1.84),
               (0.44, 2.0), (0.2, 2.1), (0.001, 2.12)], THOBE, **SOFT)
    feet()


def fig_itidal():
    robe_standing()
    head((0, 0, 2.46))
    for s in (-1, 1):
        limb([(s * 0.5, 0, 1.84), (s * 0.64, 0, 1.4), (s * 0.66, 0, 1.0)], ARM)
        hand((s * 0.66, 0, 0.84))


def fig_qiyam():
    """Debout, main droite posée sur la gauche."""
    robe_standing()
    head((0, 0, 2.46))
    limb([(0.5, 0, 1.84), (0.68, -0.1, 1.38), (0.08, -0.42, 1.36)], ARM)
    hand((-0.07, -0.46, 1.37))
    limb([(-0.5, 0, 1.84), (-0.68, -0.1, 1.42), (-0.14, -0.5, 1.45)], ARM)
    hand((0.03, -0.57, 1.46))


def fig_takbir():
    """Debout, mains levées à hauteur des oreilles, paumes vers l'avant."""
    robe_standing()
    head((0, 0, 2.46))
    for s in (-1, 1):
        limb([(s * 0.5, 0, 1.84), (s * 0.88, -0.05, 1.74), (s * 0.78, -0.12, 2.2)], ARM)
        hand((s * 0.78, -0.15, 2.42), scale=(0.13, 0.075, 0.18))


def fig_ruku():
    """Incliné, dos à plat, mains sur les genoux."""
    with group(scale=(1, 0.66, 1)):
        lathe([(0.001, 0.14), (0.48, 0.14), (0.52, 0.2), (0.46, 0.7), (0.42, 1.2), (0.3, 1.44), (0.001, 1.48)], THOBE, **SOFT)
    feet()
    with group(scale=(1.3, 1, 1)):
        limb([(0, 0.04, 1.22), (0, -0.55, 1.38), (0, -1.02, 1.38)], 0.36)
    head((0, -1.58, 1.36), rot=(62, 0, 0))
    for s in (-1, 1):
        limb([(s * 0.5, -0.98, 1.3), (s * 0.44, -0.62, 0.98), (s * 0.32, -0.36, 0.72)], ARM)
        hand((s * 0.32, -0.36, 0.62))


def fig_sujud():
    """Prosterné : front, mains, genoux et pointes des pieds au sol."""
    with group(scale=(1.35, 1, 1)):
        limb([(0, 0.1, 0.92), (0, -0.25, 0.34), (0, 0.78, 0.3)], 0.3)
    with group(scale=(1.3, 1, 1)):
        limb([(0, 0.08, 0.92), (0, -0.55, 0.74), (0, -1.0, 0.54)], 0.34)
    head((0, -1.42, 0.37), rot=(105, 0, 0))
    for s in (-1, 1):
        limb([(s * 0.5, -0.92, 0.58), (s * 0.82, -0.86, 0.5), (s * 0.64, -1.3, 0.18)], ARM)
        hand((s * 0.62, -1.44, 0.08), flat=True)
        ball((0.13, 0.11, 0.2), SKIN, loc=(s * 0.22, 1.0, 0.2), **SOFT)


def sitting(right_hand="flat", head_rot=(0, 0, 0)):
    """Assis sur les talons. `right_hand` : flat (à plat), fist (poing), index (index tendu)."""
    for s in (-1, 1):                                                       # les cuisses, genoux vers l'avant
        limb([(s * 0.24, 0.3, 0.42), (s * 0.3, -0.62, 0.33)], 0.31)
    with group(scale=(1.3, 1, 1)):
        limb([(0, 0.22, 0.6), (0, 0.16, 1.1), (0, 0.12, 1.56)], 0.34)
    head((0, 0.1, 2.2), rot=head_rot)
    for s in (-1, 1):
        ball((0.12, 0.18, 0.1), SKIN, loc=(s * 0.2, 0.68, 0.1), **SOFT)     # pointes des pieds, derrière
        limb([(s * 0.5, 0.12, 1.6), (s * 0.64, -0.02, 1.1), (s * 0.36, -0.36, 0.76)], ARM)
        if s > 0 or right_hand == "flat":
            hand((s * 0.3, -0.5, 0.68), flat=True)
        else:
            # la main REPOSE sur le genou : poing fermé, et l'index part vers l'avant, à l'horizontale
            ball((0.13, 0.14, 0.12), SKIN, loc=(s * 0.3, -0.48, 0.72), **SOFT)
            if right_hand == "index":
                tube([(s * 0.3, -0.56, 0.74), (s * 0.3, -0.9, 0.73)], 0.045, SKIN, **SOFT)
                ball(0.045, SKIN, loc=(s * 0.3, -0.9, 0.73), **SOFT)


def fig_jalsa():
    sitting()


def fig_tashahhud():
    sitting("fist")


def fig_tashahhud_index():
    sitting("index")


def fig_salam():
    """Assis, la tête tournée vers la droite."""
    sitting(head_rot=(0, 0, -62))


# nom du fichier pos_<nom>.png : (modèle, lacet). Lacet > 0 : le personnage regarde vers la droite.
FIGURES = {
    "qiyam": (fig_qiyam, -14),
    "takbir": (fig_takbir, -14),
    "itidal": (fig_itidal, -14),
    "ruku": (fig_ruku, -66),
    "sujud": (fig_sujud, -66),
    "jalsa": (fig_jalsa, -58),
    "tashahhud": (fig_tashahhud, 60),
    "tashahhud_index": (fig_tashahhud_index, 60),
    "salam": (fig_salam, -12),
}


def render_figure(name, still, out):
    """Une seule image par posture, cadrée à échelle presque constante pour que la tête
    garde la même taille d'un dessin à l'autre."""
    build, yaw = FIGURES[name]
    icon3d.SIZE = 384 if still else 640
    icon3d.reset(16 if still else 96)
    icon3d._materials.clear()
    icon3d.MOVERS.clear()
    icon3d.PARENT = None
    cam = icon3d.studio()
    with group() as rig:
        build()
    bpy.context.view_layer.update()
    icon3d.frame_camera(cam, rig, yaw, [REST])
    cam.data.ortho_scale = max(cam.data.ortho_scale, 3.3)
    icon3d.pose(rig, yaw, REST)
    folder = Path(out) / name
    folder.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.filepath = str(folder / "f0.png")
    bpy.ops.render.render(write_still=True)
    print("rendered figure", name)


def render_appicon(out):
    """La mosquée du bandeau, seule et en grand (1024 px, fond transparent) : la matière
    première de l'icône d'app, que `tools/make-appicon.py` pose ensuite sur son fond vert."""
    build, _anim, yaw = ICONS["mosque"][:3]
    icon3d.SIZE = 1024
    icon3d.reset(160)
    icon3d._materials.clear()
    icon3d.MOVERS.clear()
    icon3d.PARENT = None
    cam = icon3d.studio()
    with group() as rig:
        build()
    bpy.context.view_layer.update()
    icon3d.frame_camera(cam, rig, yaw, [REST])
    icon3d.pose(rig, yaw, REST)
    Path(out).mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.filepath = str(Path(out) / "mosque.png")
    bpy.ops.render.render(write_still=True)
    print("rendered app icon mosque")


if __name__ == "__main__":
    import bpy  # noqa: F811
    from mathutils import Vector  # noqa: F811
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--appicon" in argv:
        render_appicon(ROOT / "Design/appicon-render")
    elif "--figures" in argv:
        names = [a for a in argv if not a.startswith("--")] or list(FIGURES)
        for n in names:
            render_figure(n, "--still" in argv, ROOT / "Design/figures-render")
    else:
        main(ICONS, ROOT / "Design/icons-render")
