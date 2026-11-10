"""Regenerates src/MarkdownEditor.App/Assets/app-icon.ico from app-icon.svg.

Renders the SVG once at high resolution with headless Microsoft Edge (transparent background),
then downsamples it to each Windows icon size with Pillow.

Usage: python tools/build-app-icon.py   (requires Microsoft Edge and `pip install pillow`)
"""

import subprocess
import tempfile
from pathlib import Path

from PIL import Image

EDGE = Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe")
ASSETS = Path(__file__).resolve().parent.parent / "src" / "MarkdownEditor.App" / "Assets"
SVG = ASSETS / "app-icon.svg"
ICO = ASSETS / "app-icon.ico"
RENDER_SIZE = 1024
# Sizes Windows picks from: Explorer lists/title bar, "Open with", taskbar/Start (incl. 125-200 % scaling), tiles.
ICON_SIZES = [16, 20, 24, 32, 40, 48, 64, 128, 256]


def render(svg: Path, out_png: Path, workdir: Path) -> None:
    page = workdir / "icon.html"
    page.write_text(
        "<!doctype html><style>html,body{margin:0;background:transparent}</style>"
        f'<img src="{svg.as_uri()}" width="{RENDER_SIZE}" height="{RENDER_SIZE}">',
        encoding="utf-8",
    )
    subprocess.run(
        [
            str(EDGE), "--headless=new", "--disable-gpu", "--hide-scrollbars",
            "--default-background-color=00000000", "--force-device-scale-factor=1",
            f"--window-size={RENDER_SIZE},{RENDER_SIZE}", f"--user-data-dir={workdir / 'profile'}",
            f"--screenshot={out_png}", page.as_uri(),
        ],
        check=True,
        capture_output=True,
    )


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        workdir = Path(tmp)
        png = workdir / "icon.png"
        render(SVG, png, workdir)
        master = Image.open(png).convert("RGBA").crop((0, 0, RENDER_SIZE, RENDER_SIZE))
        frames = [master.resize((s, s), Image.Resampling.LANCZOS) for s in ICON_SIZES]
        frames[-1].save(ICO, format="ICO", sizes=[(s, s) for s in ICON_SIZES], append_images=frames[:-1])
    print(f"Wrote {ICO} ({', '.join(map(str, ICON_SIZES))} px)")


if __name__ == "__main__":
    main()
