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
import io
import json
import sys
import urllib.error
import urllib.request
import zipfile
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
    # Sowaid teaches tajwid: his set is articulated letter by letter, so it
    # reads as a second teaching voice next to Husary's Muallim rather than as
    # another performance.
    {
        "id": "sowaid",
        "folder": "Ayman_Sowaid_64kbps",
        "name": "Ayman Sowaid",
        "style": "muallim",
    },
    {
        "id": "minshawy",
        "folder": "Minshawy_Murattal_128kbps",
        "name": "Muhammad Siddiq Al-Minshawi",
        "style": "murattal",
    },
    {
        "id": "abdulbasit",
        "folder": "Abdul_Basit_Murattal_64kbps",
        "name": "Abdul Basit Abdus-Samad",
        "style": "murattal",
    },
    {
        "id": "shatri",
        "folder": "Abu_Bakr_Ash-Shaatree_64kbps",
        "name": "Abu Bakr Ash-Shatri",
        "style": "murattal",
    },
    {
        "id": "sudais",
        "folder": "Abdurrahmaan_As-Sudais_192kbps",
        "name": "Abdurrahman As-Sudais",
        "style": "murattal",
    },
    {
        "id": "shuraym",
        "folder": "Saood_ash-Shuraym_128kbps",
        "name": "Saud Ash-Shuraym",
        "style": "murattal",
    },
]

# Word-level timing comes from quran-align (Collin Fair, CC BY 4.0) — the one
# genuinely open piece of this pipeline. Each JSON maps every word of every
# ayah of one everyayah recording to [first_word, last_word_excl, start_ms,
# end_ms]. Reciter id -> file inside the release zip; None where the aligner
# never covered that recording (Sowaid), in which case the app simply does not
# highlight words for that voice.
#
# Two of the files were aligned against a different *bitrate* than the one we
# ship (Husary 64 vs 128, Shatri 128 vs 64). Same masters: the durations agree
# within ~80 ms, which is under one word, so the cursor stays honest.
TIMING_ZIP = (
    "https://github.com/cpfair/quran-align/releases/download/"
    "release-2016-11-24/quran-align-data-2016-11-24.zip"
)
TIMING_FILES = {
    "husary_muallim": "Husary_Muallim_128kbps.json",
    "husary": "Husary_64kbps.json",
    "alafasy": "Alafasy_128kbps.json",
    "sowaid": None,
    "minshawy": "Minshawy_Murattal_128kbps.json",
    "abdulbasit": "Abdul_Basit_Murattal_64kbps.json",
    "shatri": "Abu_Bakr_Ash-Shaatree_128kbps.json",
    "sudais": "Abdurrahmaan_As-Sudais_192kbps.json",
    "shuraym": "Saood_ash-Shuraym_128kbps.json",
}

# Step id -> the ayahs its lines are, in order. The lengths are asserted
# against steps.base.json below: if someone splits a line differently, the
# clips would silently drift one verse off, which is the worst kind of bug in
# an app that teaches by pairing line to line.
STEP_AYAHS = {
    "fatiha": [(1, n) for n in range(1, 8)],
    "surah": [(112, n) for n in range(1, 5)],
}


# The non-Qur'anic formulas. The salat's adhkar (istiftah, the tasbih of ruku
# and sujud, the tashahhud…) have no verse-segmented corpus, but the official
# site of Hisn al-Muslim publishes one mp3 per dhikr. Each recording carries a
# spoken chapter title and sometimes an annotation ("three times"), so every
# clip is CUT to the exact window of the formula — windows and word timings
# measured once with whisper DTW and checked in as tools/adhkar_cuts.json.
# The taawwudh comes from the Qur'an reciters' own audhubillah.mp3 instead.
# Cutting needs ffmpeg on PATH.
HISN_BASE = "http://www.hisnmuslim.com/audio/ar"
HISN_RECITER = {
    "id": "hisn",
    "name": "Hisn al-Muslim",
    "style": "murattal",
}
ADHKAR_CUTS = ROOT / "tools" / "adhkar_cuts.json"
# Step order for the hisn voice, mirroring the salat. sujud2 recites the same
# words as sujud and reuses its file.
HISN_STEP_ORDER = ["istiftah", "ruku", "itidal", "sujud", "sujud2", "jalsa",
                   "tashahhud", "salawat"]


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


def arabic_word_counts() -> dict[tuple[int, int], int]:
    """(surah, ayah) -> how many words our own arabic text has on that line.

    quran-align indexes words of the Tanzil text; our lines come from the same
    edition, so the counts must agree word for word. If they ever stop
    agreeing, the cursor would drift mid-verse — better to fail here.
    """
    base = json.loads((CONTENT / "steps.base.json").read_text(encoding="utf-8"))
    by_id = {s["id"]: s for s in base["steps"]}
    counts: dict[tuple[int, int], int] = {}
    for step_id, ayahs in STEP_AYAHS.items():
        lines = by_id[step_id]["arabic"].split("\n")
        for line, key in enumerate(ayahs):
            counts[key] = len(lines[line].split())
    return counts


def load_timing_package(cache: Path, force: bool) -> zipfile.ZipFile:
    cache.parent.mkdir(parents=True, exist_ok=True)
    if force or not cache.exists():
        request = urllib.request.Request(TIMING_ZIP, headers={"User-Agent": "Salat/1.0"})
        with urllib.request.urlopen(request, timeout=120) as response:
            cache.write_bytes(response.read())
    return zipfile.ZipFile(io.BytesIO(cache.read_bytes()))


def word_times(entry: dict, expected_words: int) -> list[list[float]] | None:
    """One ayah's segments -> [start, end] in seconds for each word.

    Segments are [first_word, last_word_excl, start_ms, end_ms] and may skip a
    word the aligner could not hear; a skipped word inherits the span between
    its neighbours so the cursor never freezes. If the aligner saw a different
    word count than our text, return None — no cursor is better than a lying
    one.
    """
    spans: list[list[float] | None] = [None] * expected_words
    for first, last, start_ms, end_ms in entry["segments"]:
        if last > expected_words:
            return None
        share = (end_ms - start_ms) / max(last - first, 1) / 1000.0
        for w in range(first, last):
            offset = start_ms / 1000.0 + (w - first) * share
            spans[w] = [round(offset, 3), round(offset + share, 3)]
    for w, span in enumerate(spans):
        if span is None:
            before = spans[w - 1][1] if w > 0 and spans[w - 1] else 0.0
            after = next((s[0] for s in spans[w + 1:] if s), before)
            spans[w] = [round(before, 3), round(max(after, before), 3)]
    return [s for s in spans if s is not None]


def cut(source: Path, dest: Path, window: list[float] | None, force: bool) -> int:
    """Re-encodes `source` (optionally trimmed to `window`) as mono mp3."""
    import subprocess
    if dest.exists() and not force:
        return dest.stat().st_size
    command = ["ffmpeg", "-loglevel", "error", "-y", "-i", str(source)]
    if window:
        command += ["-ss", str(window[0]), "-to", str(window[1])]
    command += ["-ac", "1", "-c:a", "libmp3lame", "-q:a", "4", str(dest)]
    subprocess.run(command, check=True)
    return dest.stat().st_size


def fetch_adhkar(manifest: dict, force: bool) -> int:
    """The hisn voice for the adhkar, and the reciters' own taawwudh.

    Word counts are asserted against steps.base.json exactly like the Qur'anic
    timings: a cursor that drifted by one word would lie under a sacred text.
    """
    base = json.loads((CONTENT / "steps.base.json").read_text(encoding="utf-8"))
    by_id = {s["id"]: s for s in base["steps"]}
    cuts = json.loads(ADHKAR_CUTS.read_text(encoding="utf-8"))
    cache = ROOT / "tools" / ".cache" / "adhkar"
    cache.mkdir(parents=True, exist_ok=True)
    total = 0

    hisn_clips: dict[str, list[str]] = {}
    hisn_times: dict[str, list] = {}

    for clip_data in cuts["clips"]:
        step_id, line = clip_data["step"], clip_data["line"]
        words = len(by_id[step_id]["arabic"].split("\n")[line].split())
        if words != len(clip_data["words"]):
            sys.exit(f"adhkar_cuts {step_id}/{line}: {len(clip_data['words'])} spans "
                     f"for {words} words — remeasure before shipping a lying cursor.")

        if reciter_id := clip_data.get("reciter"):
            # taawwudh, in that reciter's own voice — whole file, no cut.
            folder = clip_data["source"].split(":")[1].split("/")[0]
            raw = cache / f"audhu_{reciter_id}.mp3"
            download(f"{BASE}/{folder}/audhubillah.mp3", raw, force)
            name = clip_name(reciter_id, step_id, line)
            total += cut(raw, AUDIO / f"{name}.mp3", None, force)
            manifest["clips"].setdefault(reciter_id, {})[step_id] = [name]
            manifest["timings"].setdefault(reciter_id, {})[step_id] = [clip_data["words"]]
            print(f"  {name}.mp3  (taawwudh, {folder})")
        else:
            source_name = clip_data["source"].split("/")[-1]
            raw = cache / source_name
            download(f"{HISN_BASE}/{source_name}", raw, force)
            name = clip_name("hisn", step_id, line)
            total += cut(raw, AUDIO / f"{name}.mp3", clip_data["cut"], force)
            hisn_clips.setdefault(step_id, []).append(name)
            hisn_times.setdefault(step_id, []).append(clip_data["words"])
            print(f"  {name}.mp3  ({clip_data['cut'][1] - clip_data['cut'][0]:.1f}s)")

    # sujud2 says the same words as sujud; it reuses the same file.
    hisn_clips["sujud2"] = hisn_clips["sujud"]
    hisn_times["sujud2"] = hisn_times["sujud"]

    for step_id, names in hisn_clips.items():
        lines = len(by_id[step_id]["arabic"].split("\n"))
        if len(names) != lines:
            sys.exit(f"hisn/{step_id}: {len(names)} clips for {lines} lines.")

    manifest["reciters"].append({**HISN_RECITER, "source": f"{HISN_BASE}/"})
    manifest["clips"]["hisn"] = {s: hisn_clips[s] for s in HISN_STEP_ORDER}
    manifest["timings"]["hisn"] = {s: hisn_times[s] for s in HISN_STEP_ORDER}
    return total


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
    manifest: dict = {"reciters": [], "clips": {}, "timings": {}}
    total = 0

    counts = arabic_word_counts()
    package = load_timing_package(ROOT / "tools" / ".cache" / "quran-align.zip", False)

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

        # Word cursor, where the aligner covered this recording.
        if timing_file := TIMING_FILES.get(reciter["id"]):
            raw = package.read(timing_file)
            # The As-Sudais file in the 2016 package opens with a stray crash
            # log from the aligner before the JSON array; skip to the data.
            aligned = {
                (e["surah"], e["ayah"]): e
                for e in json.loads(raw[raw.index(b"[{"):])
                if e["surah"] in {s for s, _ in {a for v in STEP_AYAHS.values() for a in v}}
            }
            timings: dict[str, list] = {}
            for step_id, ayahs in STEP_AYAHS.items():
                lines = []
                for key in ayahs:
                    entry = aligned.get(key)
                    times = word_times(entry, counts[key]) if entry else None
                    if times is None:
                        sys.exit(
                            f"{timing_file}: {key} does not align with our arabic "
                            f"({counts[key]} words) — refusing a cursor that lies."
                        )
                    lines.append(times)
                timings[step_id] = lines
            manifest["timings"][reciter["id"]] = timings

    if not args.only:
        total += fetch_adhkar(manifest, args.force)

    MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"\n{len(manifest['reciters'])} voices, {total / 1_000_000:.1f} MB → {AUDIO}")
    print(f"manifest → {MANIFEST}")


if __name__ == "__main__":
    main()
