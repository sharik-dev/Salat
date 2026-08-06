#!/usr/bin/env python3
"""Fetch the recitation clips the app plays, one file per *line* of a step.

Only the Qur'anic steps can be sourced this way: everyayah.com publishes the
Qur'an ayah by ayah, which is exactly the granularity the step cards use
(`fatiha` line 3 == 1:4). The rest of the salat — the takbir, the tasbih of the
ruku, the tashahhud — is not Qur'an and has no equivalent openly-licensed,
verse-segmented corpus. Those steps ship without a reciter rather than with an
amateur clip standing in for one; see AUDIO_SOURCES.md.

    python3 tools/fetch-recitations.py            # download what is missing
    python3 tools/fetch-recitations.py --force    # re-download everything

Writes Salat/Resources/audio/*.mp3 (flat — XcodeGen flattens resources anyway,
so the file name has to carry the whole key) plus recitations.json, the
manifest Recitations.swift reads.

The clips live under `Salat/`, not `SalatKit/`: SalatKit is compiled into the
widget too, and the widget never plays a sound — putting 3.7 MB of mp3 there
would ship it twice.
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "SalatKit" / "Resources"          # steps.base.json lives here
RESOURCES = ROOT / "Salat" / "Resources"           # audio ships in the app only
AUDIO = RESOURCES / "audio"
MANIFEST = RESOURCES / "recitations.json"

BASE = "https://everyayah.com/data"

# Reciter id -> (everyayah folder, display name, one-line description key).
# Husary's *Muallim* set is the teaching recording: slow, each ayah detached,
# which is what someone repeating after it needs. The two others are there so
# the ear does not lock onto a single voice.
RECITERS = [
    {
        "id": "husary_muallim",
        "folder": "Husary_Muallim_128kbps",
        "name": "Mahmoud Khalil Al-Husary",
        "style": "muallim",
    },
    {
        "id": "husary",
        "folder": "Husary_128kbps",
        "name": "Mahmoud Khalil Al-Husary",
        "style": "murattal",
    },
    {
        "id": "alafasy",
        "folder": "Alafasy_128kbps",
        "name": "Mishary Rashid Alafasy",
        "style": "murattal",
    },
]

# Step id -> the ayahs its lines are, in order. The lengths are asserted
# against steps.base.json below: if someone splits a line differently, the
# clips would silently drift one verse off, which is the worst kind of bug in
# an app that teaches by pairing line to line.
STEP_AYAHS = {
    "fatiha": [(1, n) for n in range(1, 8)],
    "surah": [(112, n) for n in range(1, 5)],
}


def ayah_url(folder: str, surah: int, ayah: int) -> str:
    return f"{BASE}/{folder}/{surah:03d}{ayah:03d}.mp3"


def clip_name(reciter_id: str, step_id: str, line: int) -> str:
    return f"rec_{reciter_id}_{step_id}_{line}"


def check_line_counts() -> None:
    base = json.loads((CONTENT / "steps.base.json").read_text(encoding="utf-8"))
    by_id = {s["id"]: s for s in base["steps"]}
    for step_id, ayahs in STEP_AYAHS.items():
        step = by_id.get(step_id)
        if step is None:
            sys.exit(f"steps.base.json has no step '{step_id}'")
        lines = len(step["arabic"].split("\n"))
        if lines != len(ayahs):
            sys.exit(
                f"'{step_id}' has {lines} arabic lines but {len(ayahs)} ayahs are "
                f"mapped — the audio would be off by a verse. Fix STEP_AYAHS."
            )


def download(url: str, dest: Path, force: bool) -> int:
    if dest.exists() and not force:
        return dest.stat().st_size
    request = urllib.request.Request(url, headers={"User-Agent": "Salat/1.0 (learning app)"})
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read()
    if len(data) < 1024:
        raise RuntimeError(f"suspiciously small file ({len(data)} B)")
    dest.write_bytes(data)
    return len(data)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="re-download existing clips")
    parser.add_argument("--only", help="restrict to one reciter id")
    args = parser.parse_args()

    check_line_counts()
    AUDIO.mkdir(parents=True, exist_ok=True)

    reciters = [r for r in RECITERS if not args.only or r["id"] == args.only]
    manifest: dict = {"reciters": [], "clips": {}}
    total = 0

    for reciter in reciters:
        clips: dict[str, list[str]] = {}
        for step_id, ayahs in STEP_AYAHS.items():
            names = []
            for line, (surah, ayah) in enumerate(ayahs):
                name = clip_name(reciter["id"], step_id, line)
                url = ayah_url(reciter["folder"], surah, ayah)
                try:
                    size = download(url, AUDIO / f"{name}.mp3", args.force)
                except (urllib.error.URLError, RuntimeError) as error:
                    sys.exit(f"{url}: {error}")
                total += size
                names.append(name)
                print(f"  {name}.mp3  {size // 1024} KB")
            clips[step_id] = names
        manifest["reciters"].append(
            {
                "id": reciter["id"],
                "name": reciter["name"],
                "style": reciter["style"],
                "source": f"{BASE}/{reciter['folder']}/",
            }
        )
        manifest["clips"][reciter["id"]] = clips

    MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"\n{len(reciters)} reciters, {total / 1_000_000:.1f} MB → {AUDIO}")
    print(f"manifest → {MANIFEST}")


if __name__ == "__main__":
    main()
