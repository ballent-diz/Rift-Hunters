#!/usr/bin/env python3
"""Mesure le tempo (BPM) et le décalage du premier temps de chaque musique, et l'écrit dans la section « bpm »
de assets/audio/audio_manifest.json (clé : chemin res://). Le jeu s'en sert pour pulser l'interface en rythme.

Usage : python3 tools/audio/detect_bpm.py [--min 120 --max 200] [--force]
Nécessite ffmpeg (décodage) et numpy. Les morceaux déjà mesurés sont ignorés sauf avec --force.
Un résultat peu fiable n'est pas écrit (le morceau joue alors sans pulsation)."""
import argparse
import json
import os
import subprocess
import sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
MUSIC = os.path.join(REPO, "assets", "audio", "music")
MANIFEST = os.path.join(REPO, "assets", "audio", "audio_manifest.json")
SR = 22050
HOP = 128
FPS = SR / HOP
EXTENSIONS = (".mp3", ".ogg", ".wav")
NO_BEAT = ("victory", "defeat")


def decode(path, start=15.0, duration=75.0):
    cmd = ["ffmpeg", "-v", "quiet", "-ss", str(start), "-t", str(duration), "-i", path, "-ac", "1", "-ar", str(SR),
           "-f", "f32le", "-"]
    data = subprocess.run(cmd, capture_output=True, check=True).stdout
    return np.frombuffer(data, dtype=np.float32)


def onset_envelope(signal):
    """Flux spectral : hausse d'énergie d'une trame à l'autre (attaques des percussions)."""
    frame = 1024
    count = 1 + (len(signal) - frame) // HOP
    if count < 50:
        return None
    idx = np.arange(frame)[None, :] + HOP * np.arange(count)[:, None]
    frames = signal[idx] * np.hanning(frame)[None, :]
    mag = np.log1p(np.abs(np.fft.rfft(frames, axis=1)) * 10.0)
    flux = np.maximum(np.diff(mag, axis=0), 0.0).sum(axis=1)
    kernel = np.ones(int(FPS * 0.5)) / int(FPS * 0.5)
    flux = flux - np.convolve(flux, kernel, mode="same")
    return np.maximum(flux, 0.0)


def tempo(envelope, low, high):
    """Autocorrélation + peigne de multiples ; retourne (bpm, confiance)."""
    env = envelope - envelope.mean()
    ac = np.correlate(env, env, mode="full")[len(env) - 1:]
    ac = ac / max(ac[0], 1e-9)
    best, best_score = 0.0, -1.0
    scores = []
    for bpm in np.arange(low, high + 0.01, 0.25):
        lag = 60.0 * FPS / bpm
        score = 0.0
        for k, weight in ((1, 1.0), (2, 0.6), (3, 0.4), (4, 0.3)):
            pos = lag * k
            i = int(pos)
            if i + 1 >= len(ac):
                break
            frac = pos - i
            score += weight * (ac[i] * (1 - frac) + ac[i + 1] * frac)
        scores.append(score)
        if score > best_score:
            best, best_score = bpm, score
    scores = np.array(scores)
    confidence = (best_score - np.median(scores)) / max(scores.std(), 1e-9)
    return float(best), float(confidence)


def phase(envelope, bpm, start):
    """Décalage (secondes depuis le début du fichier) qui aligne la grille des temps sur les attaques."""
    period = 60.0 * FPS / bpm
    best, best_sum = 0.0, -1.0
    for offset in np.arange(0.0, period, 0.5):
        positions = np.arange(offset, len(envelope) - 1, period).astype(int)
        total = envelope[positions].sum()
        if total > best_sum:
            best, best_sum = offset, total
    seconds = (start + best / FPS) % (60.0 / bpm)
    return round(float(seconds), 3)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--min", type=float, default=120.0)
    parser.add_argument("--max", type=float, default=200.0)
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--confidence", type=float, default=3.0)
    args = parser.parse_args()
    with open(MANIFEST, encoding="utf-8") as f:
        manifest = json.load(f)
    table = manifest.setdefault("bpm", {})
    for folder in sorted(os.listdir(MUSIC)):
        if folder in NO_BEAT or not os.path.isdir(os.path.join(MUSIC, folder)):
            continue
        for name in sorted(os.listdir(os.path.join(MUSIC, folder))):
            if not name.lower().endswith(EXTENSIONS):
                continue
            res = f"res://assets/audio/music/{folder}/{name}"
            if res in table and not args.force:
                continue
            path = os.path.join(MUSIC, folder, name)
            start = 15.0
            envelope = onset_envelope(decode(path, start))
            if envelope is None:
                print(f"trop court : {folder}/{name}")
                continue
            bpm, confidence = tempo(envelope, args.min, args.max)
            if confidence < args.confidence:
                print(f"incertain ({confidence:.1f}) : {folder}/{name} ~{bpm:.1f} BPM, ignoré")
                continue
            table[res] = {"bpm": round(bpm, 2), "offset": phase(envelope, bpm, start)}
            print(f"{bpm:6.2f} BPM  (confiance {confidence:4.1f})  {folder}/{name}")
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent="\t", ensure_ascii=False)
        f.write("\n")


if __name__ == "__main__":
    sys.exit(main())
