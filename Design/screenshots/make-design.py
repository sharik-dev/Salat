#!/usr/bin/env python3
"""Writes the shotsmith designs for Salat's App Store screenshots (iPhone 6.9", EN + FR + AR).

    tools/store_shots.sh                         # raw captures, made by the app itself
    python3 Design/screenshots/make-design.py
    shotsmith Design/screenshots/design.json    --out fastlane/screenshots --fastlane
    shotsmith Design/screenshots/design.ar.json --out fastlane/screenshots --fastlane

The whole set is ONE continuous banner, in the app's own "Jardin" look: the green of the app, its
lattice of eight-pointed stars, and a golden garland of lights with lanterns that runs through
every slide. Anything placed with a *global* x (slide k spans [k, k+1]) is emitted into each slide
it touches, shifted by -k: that is how the two 3D phones straddle the seam between two slides,
with their magnifier on the next one.

Arabic gets its own file because the App Store lays the screenshots out right to left there: the
strip is mirrored (x → 1 − x, angles negated), otherwise the two halves of a phone would be shown
the wrong way round.
"""
import json
import math
from pathlib import Path

HERE = Path(__file__).parent
W, H = 1290, 2796                                # iPhone 6.9" portrait (shotsmith iphone69)
ASPECT = 1170 / 2532                             # the raw captures come from an iPhone 17e
ICON = "../icons-render/{}/f0.png"
RAW = "../../fastlane/screenshots_raw/{}/{}.png"

# ── palette = SalatKit/Theme.swift ────────────────────────────────────────────
GREEN_TOP, GREEN, GREEN_DEEP, NIGHT = "#35B57B", "#23875A", "#17633F", "#0F412B"
GOLD, GOLD_DEEP, SPARK = "#F2B632", "#B97A08", "#FFD45E"
FONT = "'SF Rounded', 'SF Arabic Rounded', system-ui, sans-serif"

# ── slides: id, copy (headline, subtitle). *word* = painted gold. ────────────
SLIDES = [
    ("learn", {
        "en": ("Learn to pray\n*step by step*", "The fourteen steps of the prayer, in order"),
        "fr": ("Apprends à prier\n*pas à pas*", "Les quatorze étapes de la prière, dans l'ordre"),
        "ar": ("تعلَّم الصلاة\n*خطوة بخطوة*", "خطوات الصلاة الأربع عشرة بالترتيب"),
    }),
    ("step", {
        "en": ("Every step\n*clearly explained*", "The posture, the gesture and the words"),
        "fr": ("Chaque étape\n*bien expliquée*", "La posture, le geste et les paroles"),
        "ar": ("كل خطوة\n*مشروحة بوضوح*", "الهيئة والحركة وما يُقال فيها"),
    }),
    ("lines", {
        "en": ("Arabic, sound\n*and meaning*", "How to say each line, and what it says"),
        "fr": ("L'arabe, le son\n*et le sens*", "Comment dire chaque ligne, et ce qu'elle dit"),
        "ar": ("النص العربي\n*سطرًا سطرًا*", "كل سطر واضحًا أمامك"),
    }),
    ("listen", {
        "en": ("Listen, then\n*say it yourself*", "The word being recited lights up"),
        "fr": ("Écoute, puis\n*dis-le toi-même*", "Le mot récité s'allume pendant que tu suis"),
        "ar": ("استمع ثم\n*ردِّد بنفسك*", "الكلمة المتلوّة تضيء وأنت تتابع"),
    }),
    ("quran", {
        "en": ("The whole Quran\n*verse by verse*", "Swipe, listen and keep the verses you love"),
        "fr": ("Tout le Coran\n*verset par verset*", "Fais défiler, écoute, garde tes versets"),
        "ar": ("القرآن كاملًا\n*آية بآية*", "مرِّر واستمع واحتفظ بالآيات التي تحبها"),
    }),
    ("drill", {
        "en": ("Quizzes that\n*make it stick*", "Questions taken from the prayer itself"),
        "fr": ("Des exercices\n*pour retenir*", "Des questions tirées de la prière elle-même"),
        "ar": ("تمارين\n*تثبِّت الحفظ*", "أسئلة مأخوذة من الصلاة نفسها"),
    }),
    ("fade", {
        "en": ("Recite\n*from memory*", "The same lines, with fewer and fewer words"),
        "fr": ("Récite\n*de mémoire*", "Les mêmes lignes, de moins en moins de mots"),
        "ar": ("اقرأ\n*من حفظك*", "السطور نفسها بكلمات أقل فأقل"),
    }),
    ("blanks", {
        "en": ("Words fade\n*as you learn*", "Until you can say it all by heart"),
        "fr": ("Les mots s'effacent\n*quand tu sais*", "Jusqu'à tout dire par cœur"),
        "ar": ("الكلمات تختفي\n*كلما حفظت*", "حتى تقرأها كلها عن ظهر قلب"),
    }),
    ("widget", {
        "en": ("Learn from your\n*home screen*", "A widget keeps the words in sight\nwith Salat Premium"),
        "fr": ("Apprends depuis\n*l'écran d'accueil*", "Un widget garde les paroles sous tes yeux\navec Salat Premium"),
        "ar": ("تعلَّم من\n*شاشتك الرئيسية*", "أداة تُبقي الكلمات أمام عينيك\nمع Salat Premium"),
    }),
    ("progress", {
        "en": ("See how far\n*you've come*", "Your steps, your days, your streak"),
        "fr": ("Vois le chemin\n*parcouru*", "Tes étapes, tes jours, ta série"),
        "ar": ("تابع\n*تقدُّمك*", "خطواتك وأيامك وسلسلتك"),
    }),
]
N = len(SLIDES)
IDX = {sid: i for i, (sid, _) in enumerate(SLIDES)}


def build(langs, mirror, out):
    """One design file. `langs` maps a language to its App Store locale."""

    def shot(capture):
        return {lang: RAW.format(lang, capture) for lang in langs}

    # ── per-slide phones (local x) ────────────────────────────────────────────
    def phone(capture, rot=0, w=0.74):
        return {"id": "phone", "type": "screenshot", "frame": "iphone", "src": shot(capture),
                "aspect": ASPECT, "at": {"x": 0.5, "y": 0.285, "w": w}, "anchor": "top",
                "rotate": rot, "shadow": {"y": 0.014, "blur": 0.04, "color": "rgba(6,40,24,0.55)"}, "z": 4}

    local_phones = {
        "learn": phone("learn", rot=-3),
        "step": phone("step", rot=3),
        "quran": phone("quran", rot=-3),
        "drill": phone("drill", rot=3),
        "widget": phone("widget", rot=-3),
        "progress": phone("progress", rot=3),
    }

    # ── global elements (x in slide units over the whole strip) ───────────────
    glob = []

    def g(gx, layer, span=0.7):
        glob.append((gx, span, layer))

    # Two 3D phones on the seams, magnifier on the following slide.
    def pano(seam, capture, spot, zoom_x, zoom_y, yaw, roll, scale=0.8, size=0.78):
        g(seam, {"id": f"pano{seam}", "type": "phone3d", "src": shot(capture),
                 "at": {"x": seam, "y": 0.64, "h": 0.74}, "anchor": "center",
                 "dist": 2.8, "yaw": yaw, "pitch": -6, "roll": roll, "body": "#12331f", "rim": "#bff3d6",
                 "spot": spot, "spotRadius": 0.05, "spotColor": GOLD, "dim": 0.12,
                 "zoom": {"x": zoom_x, "y": zoom_y, "size": size, "scale": scale, "color": GOLD},
                 "shadow": {"y": 0.02, "blur": 0.035, "color": "rgba(6,40,24,0.55)"}, "z": 4},
          span=1.2)

    # lines → listen : the line being recited (Arabic, how to say it, what it means), its
    # current word lit
    pano(IDX["lines"] + 1, "listen", [0.03, 0.612, 0.94, 0.165], IDX["listen"] + 0.6, 0.70, 22, -5, scale=0.74)
    # fade → blanks : a line with its words hidden
    pano(IDX["fade"] + 1, "fade", [0.03, 0.262, 0.94, 0.155], IDX["blanks"] + 0.6, 0.72, -22, 5, scale=0.8)

    # The garland: one golden cord through every slide, small lights along it.
    def cord_y(gx):
        return 0.258 + 0.018 * math.sin(gx * 2 * math.pi / 1.7 + 0.6) + 0.007 * math.sin(gx * 2 * math.pi / 0.55)

    def px(gx, k):
        x = (gx - k) * W
        return W - x if mirror else x

    def cord_layer(k):
        xs = [k - 0.05 + i * 0.005 for i in range(int(1.1 / 0.005) + 1)]
        pts = [(px(x, k), cord_y(x) * H) for x in xs]
        # the lights keep their rhythm across slides: arc length from the strip's origin
        s, ax, ay = 0.0, 0.0, cord_y(0) * H
        x = 0.0
        while x < k - 0.05:
            x += 0.005
            nx, ny = x * W, cord_y(x) * H
            s += math.hypot(nx - ax, ny - ay)
            ax, ay = nx, ny
        if mirror:
            pts.reverse()
            total = sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(pts, pts[1:]))
            s = -(s + total)
        d = "M" + " L".join(f"{a:.1f},{b:.1f}" for a, b in pts)
        dots = f'stroke-dasharray="0.1 92" stroke-dashoffset="{-s:.1f}"'
        svg = (f'<svg viewBox="0 0 {W} {H}" width="100%" height="100%" style="overflow:visible">'
               f'<path d="{d}" transform="translate(0,5)" fill="none" stroke="{NIGHT}" stroke-opacity="0.45" stroke-width="9" stroke-linecap="round"/>'
               f'<path d="{d}" fill="none" stroke="{GOLD_DEEP}" stroke-width="9" stroke-linecap="round"/>'
               f'<path d="{d}" transform="translate(0,-2)" fill="none" stroke="{GOLD}" stroke-width="5" stroke-linecap="round"/>'
               f'<path d="{d}" transform="translate(0,7)" fill="none" stroke="{GOLD_DEEP}" stroke-width="34" stroke-linecap="round" {dots}/>'
               f'<path d="{d}" transform="translate(0,3)" fill="none" stroke="{SPARK}" stroke-width="30" stroke-linecap="round" {dots}/>'
               f'<path d="{d}" transform="translate(-4,-2)" fill="none" stroke="#FFF6D6" stroke-width="11" stroke-linecap="round" {dots}/></svg>')
        return {"id": "cord", "type": "html", "content": svg, "at": {"x": 0, "y": 0, "w": 1, "h": 1}, "z": 2}

    def deco(gx, y, name, w, rot=0, z=1, opacity=None, shadow=True, anchor="center"):
        layer = {"id": f"{name}{gx}", "type": "sticker", "src": ICON.format(name),
                 "at": {"x": gx, "y": y, "w": w}, "anchor": anchor, "rotate": rot, "z": z}
        if opacity is not None:
            layer["opacity"] = opacity
        layer["shadow"] = {"y": 0.008, "blur": 0.012, "color": "rgba(6,40,24,0.35)"} if shadow else False
        g(gx, layer)

    # lanterns hanging from the cord, in the gaps between phones
    for gx in (1.0, 2.0, 4.0, 5.0, 6.0, 8.0, 9.0):
        deco(gx, cord_y(gx) - 0.006, "lantern", 0.2, z=3, anchor="top")
    deco(0.06, 0.035, "moon", 0.26, rot=-10, z=1, shadow=False)
    deco(N - 0.07, 0.04, "star", 0.2, rot=10, z=1, shadow=False)

    # 3D objects of the app, each one where its slide talks about it
    objects = [
        (0.075, 0.61, "mosque", 0.26, -8), (0.9, 0.84, "mat", 0.24, 10),
        (1.06, 0.62, "book", 0.24, -8), (1.9, 0.60, "bulb", 0.23, 8),
        (2.17, 0.44, "scroll", 0.25, -8), (2.16, 0.85, "globe", 0.24, 8),
        (3.87, 0.37, "headphones", 0.26, 8), (3.86, 0.93, "mic", 0.23, -8),
        (4.1, 0.80, "quran", 0.27, -10), (4.9, 0.52, "sparkle", 0.17, 10),
        (5.1, 0.56, "quiz", 0.27, -8), (5.9, 0.80, "check", 0.25, 8),
        (6.17, 0.50, "cards", 0.26, -8), (6.16, 0.86, "eraser", 0.25, 8),
        (7.87, 0.37, "trophy", 0.24, 8), (7.86, 0.94, "sprout", 0.22, -6),
        (8.1, 0.60, "phone", 0.25, -8), (8.9, 0.82, "bell", 0.24, 10),
        (9.1, 0.78, "chart", 0.27, -8), (9.9, 0.54, "flame", 0.23, 8),
    ]
    for gx, y, name, w, rot in objects:
        deco(gx, y, name, w * 1.15, rot=rot, z=6)
    for gx, y in [(2.45, 0.33), (3.5, 0.335), (6.5, 0.335), (7.5, 0.33)]:
        deco(gx, y, "sparkle", 0.075, rot=12, z=3, shadow=False)

    # ── backdrop: the app's green and its lattice of eight-pointed stars ──────
    def background():
        return {"id": "bg", "type": "background",
                "gradient": {"angle": 180, "stops": [GREEN_TOP, GREEN, GREEN_DEEP]}}

    def lattice():
        t = W / 5                                  # five tiles a slide: the seams line up
        c, r = t / 2, t * 0.30
        square = f"{c - r},{c - r} {c + r},{c - r} {c + r},{c + r} {c - r},{c + r}"
        star = (f'<polygon points="{square}"/>'
                f'<polygon points="{square}" transform="rotate(45 {c} {c})"/>')
        svg = (f'<svg viewBox="0 0 {W} {H}" width="100%" height="100%">'
               f'<defs><pattern id="k" width="{t}" height="{t}" patternUnits="userSpaceOnUse">'
               f'<g fill="none" stroke="#FFFFFF" stroke-opacity="0.085" stroke-width="5">{star}</g>'
               f'</pattern></defs><rect width="{W}" height="{H}" fill="url(#k)"/></svg>')
        return {"id": "lattice", "type": "html", "content": svg, "at": {"x": 0, "y": 0, "w": 1, "h": 1}, "z": 0}

    def copy_layers(copy):
        headline = {"id": "headline", "type": "headline",
                    "content": {lang: copy[lang][0] for lang in langs},
                    "font": FONT, "transform": "none", "weight": 900, "lineHeight": 1.06, "tracking": 0,
                    "size": 0.046, "align": "center", "color": "#FFFFFF", "accent": SPARK,
                    "outline": {"color": NIGHT, "width": 0.0035},
                    "extrude": {"color": NIGHT, "depth": 0.007},
                    "at": {"x": 0.5, "y": 0.05, "w": 0.94}, "anchor": "top", "z": 8}
        sub = {"id": "sub", "type": "subtitle", "content": {lang: copy[lang][1] for lang in langs},
               "font": FONT, "weight": 800, "size": 0.019, "align": "center", "color": "rgba(255,255,255,0.96)",
               "shadow": {"y": 0.002, "blur": 0.004, "color": "rgba(6,40,24,0.45)"},
               "at": {"x": 0.5, "y": 0.176, "w": 0.92}, "anchor": "top", "z": 8}
        return [headline, sub]

    def place(layer, k):
        """A global layer, seen from slide k (and from the other side in a mirrored strip)."""
        layer = json.loads(json.dumps(layer))
        x = layer["at"]["x"] - k
        layer["at"]["x"] = round(1 - x if mirror else x, 4)
        if "zoom" in layer:
            zx = layer["zoom"]["x"] - k
            layer["zoom"]["x"] = round(1 - zx if mirror else zx, 4)
        if mirror:
            for key in ("rotate", "yaw", "roll"):
                if key in layer:
                    layer[key] = -layer[key]
        return layer

    def slide(k, sid, copy):
        layers = [background(), lattice(), cord_layer(k), *copy_layers(copy)]
        if sid in local_phones:
            p = json.loads(json.dumps(local_phones[sid]))
            if mirror:
                p["rotate"] = -p["rotate"]
            layers.append(p)
        for gx, span, layer in glob:
            if k - span <= gx <= k + 1 + span:
                layers.append(place(layer, k))
        return {"id": sid, "layers": layers}

    design = {
        "assetRoot": ".",
        "devices": ["iphone69"],
        "orientation": "portrait",
        "locales": list(langs),
        "ascLocales": langs,
        "fonts": [
            {"family": "SF Rounded", "src": "/System/Library/Fonts/SFNSRounded.ttf", "weight": "100 900"},
            {"family": "SF Arabic Rounded", "src": "/System/Library/Fonts/SFArabicRounded.ttf", "weight": "100 900"},
        ],
        "fontTitle": "SF Rounded",
        "fontBody": "SF Rounded",
        "slides": [slide(k, sid, copy) for k, (sid, copy) in enumerate(SLIDES)],
    }
    (HERE / out).write_text(json.dumps(design, ensure_ascii=False, indent=1) + "\n")
    print(f"{out}: {N} slides × {len(langs)} languages")


for sid, copy in SLIDES:
    assert {"en", "fr", "ar"} <= set(copy), f"{sid}: missing language"
build({"en": "en-US", "fr": "fr-FR"}, mirror=False, out="design.json")
build({"ar": "ar-SA"}, mirror=True, out="design.ar.json")
