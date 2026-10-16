"""Encode les captures natives de la vraie partie C1 ; aucune retouche d’image."""
from pathlib import Path
import argparse
import shutil
import subprocess

FOLDER = Path(__file__).resolve().parents[2] / "docs/previews/c5/live"

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--ffmpeg", default=shutil.which("ffmpeg"))
    args = parser.parse_args()
    if not args.ffmpeg:
        raise SystemExit("Indiquer un exécutable FFmpeg avec --ffmpeg.")
    if len(list(FOLDER.glob("frame_[0-9][0-9][0-9].png"))) != 75:
        raise SystemExit("75 captures attendues ; lancer c5_live_preview.tscn.")
    subprocess.run([args.ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
                    "-framerate", "30", "-i", str(FOLDER / "frame_%03d.png"),
                    "-an", "-c:v", "libx264", "-preset", "fast", "-crf", "16",
                    "-pix_fmt", "yuv420p", "-movflags", "+faststart",
                    str(FOLDER / "taille-fendante-en-partie.mp4")], check=True)
    print("Vidéo en partie : 1920 × 1080, 30 i/s, 2,5 secondes, sans montage ni audio capturé.")
