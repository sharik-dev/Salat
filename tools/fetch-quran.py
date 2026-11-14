#!/usr/bin/env python3
"""Fetch the text the *Qur'an* tab scrolls: the Arabic, and one translation per
language the app speaks.

    python3 tools/fetch-quran.py            # download what is missing
    python3 tools/fetch-quran.py --force    # re-download everything

Writes, under Salat/Resources/ (the app only: the widget never shows the
Qur'an, and SalatKit is compiled into it):

    quran.base.json     the 114 surahs (number, Arabic name, Latin name, where
                        it was revealed) and every verse in Arabic
    quran.<code>.json   the same 114 lists of verses, translated

Source: api.alquran.cloud, which republishes the Tanzil project's texts. The
Arabic is Tanzil's *simple* text (full tashkeel, standard letters) rather than
the Uthmani one: it is the script the rest of the app already uses for the
Fatiha, and it renders in a system font. **It is never edited here**, with one
exception that is a cut, not a change: Tanzil glues the basmala to the first
verse of every surah but the Fatiha (where it *is* verse 1) and at-Tawba (which
has none). The reciters' files do not: `002001.mp3` is "Alif Lam Mim" alone. So
the prefix is removed, the app shows the basmala as its own page, and what is
on screen is what is being recited.

The script refuses to write anything if a count is off: 114 surahs, 6236
verses, 112 basmalas removed, and every translation verse for verse with the
Arabic. A feed that is one verse out of step would show the meaning of verse 4
under verse 5 without anything crashing.
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Salat" / "Resources"
CACHE = ROOT / "tools" / ".cache" / "quran"
API = "https://api.alquran.cloud/v1/quran/"

ARABIC = "quran-simple"

# App language -> (edition, translator as credited in the settings).
# Arabic has no entry: the Arabic *is* the text.
TRANSLATIONS = {
    "en": ("en.sahih", "Saheeh International"),
    "fr": ("fr.hamidullah", "Muhammad Hamidullah"),
    "id": ("id.indonesian", "Kementerian Agama RI"),
    "ms": ("ms.basmeih", "Abdullah Muhammad Basmeih"),
    "ur": ("ur.jalandhry", "Fateh Muhammad Jalandhry"),
    "bn": ("bn.bengali", "Muhiuddin Khan"),
    "tr": ("tr.diyanet", "Diyanet İşleri"),
    "ru": ("ru.kuliev", "Elmir Kuliev"),
    "es": ("es.cortes", "Julio Cortés"),
    "pt": ("pt.elhayek", "Samir El-Hayek"),
    "de": ("de.bubenheim", "Bubenheim & Elyas"),
    "it": ("it.piccardo", "Hamza Roberto Piccardo"),
    "nl": ("nl.siregar", "Sofjan Siregar"),
}

SURAHS = 114
VERSES = 6236


def edition(name: str, force: bool) -> list[dict]:
    """The 114 surahs of one edition, cached on disk (each is 1 to 4 MB)."""
    path = CACHE / f"{name}.json"
    if force or not path.exists():
        request = urllib.request.Request(API + name, headers={"User-Agent": "quran-fetch"})
        with urllib.request.urlopen(request, timeout=120) as response:
            body = response.read()
        CACHE.mkdir(parents=True, exist_ok=True)
        path.write_bytes(body)
    data = json.loads(path.read_text())
    if data.get("code") != 200:
        sys.exit(f"{name}: the API answered {data.get('code')}")
    return data["data"]["surahs"]


def check(surahs: list[dict], name: str) -> None:
    total = sum(len(s["ayahs"]) for s in surahs)
    if len(surahs) != SURAHS or total != VERSES:
        sys.exit(f"{name}: {len(surahs)} surahs, {total} verses "
                 f"(expected {SURAHS} and {VERSES})")


def clean(text: str) -> str:
    return text.replace("﻿", "").strip()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true")
    force = parser.parse_args().force

    arabic = edition(ARABIC, force)
    check(arabic, ARABIC)

    # The basmala is read from the source (verse 1:1), never typed here: the
    # same letters can be encoded with their marks in another order, and a
    # typed copy then matches nothing.
    BASMALA = clean(arabic[0]["ayahs"][0]["text"])
    if len(BASMALA.split()) != 4:
        sys.exit(f"verse 1:1 is not the basmala: {BASMALA!r}")

    surahs, verses, removed = [], [], 0
    for surah in arabic:
        lines = [clean(a["text"]) for a in surah["ayahs"]]
        number = surah["number"]
        if number not in (1, 9):
            if not lines[0].startswith(BASMALA + " "):
                sys.exit(f"surah {number}: verse 1 does not open on the basmala")
            lines[0] = lines[0][len(BASMALA) + 1:]
            removed += 1
        if any(not line for line in lines):
            sys.exit(f"surah {number}: an empty verse")
        surahs.append({
            "number": number,
            "name": clean(surah["name"]),
            "latin": surah["englishName"],
            "meccan": surah["revelationType"] == "Meccan",
            "verses": len(lines),
        })
        verses.append(lines)
    if removed != SURAHS - 2:
        sys.exit(f"{removed} basmalas removed, expected {SURAHS - 2}")

    OUT.mkdir(parents=True, exist_ok=True)
    dump(OUT / "quran.base.json", {"basmala": BASMALA, "surahs": surahs, "verses": verses})

    for code, (name, translator) in TRANSLATIONS.items():
        translated = edition(name, force)
        check(translated, name)
        lists = []
        for source, surah in zip(arabic, translated):
            if len(surah["ayahs"]) != len(source["ayahs"]):
                sys.exit(f"{name}: surah {surah['number']} has {len(surah['ayahs'])} verses, "
                         f"the Arabic has {len(source['ayahs'])}")
            lists.append([clean(a["text"]) for a in surah["ayahs"]])
        empty = sum(1 for verses_ in lists for v in verses_ if not v)
        if empty:
            sys.exit(f"{name}: {empty} empty verses")
        dump(OUT / f"quran.{code}.json",
             {"edition": name, "translator": translator, "verses": lists})

    print(f"{SURAHS} surahs, {VERSES} verses, {len(TRANSLATIONS)} translations")


def dump(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
    print(f"{path.relative_to(ROOT)}  {path.stat().st_size / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
