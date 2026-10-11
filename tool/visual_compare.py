"""Builds side-by-side visual QA images: Stitch screen.png (left) vs Flutter render (right).

Usage: python tool/visual_compare.py [name ...]   (no args = every render found)
Renders come from `flutter test test/visual` (written to docs/visual-qa/flutter/<name>.png).
Output: docs/visual-qa/<name>_compare.png and a printed similarity score (1.0 = identical).
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STITCH = os.path.join(os.path.dirname(os.path.dirname(ROOT)), 'POC', 'stitch_nordic_ride_hailing_app')
QA = os.path.join(ROOT, 'docs', 'visual-qa')
RENDER = os.path.join(QA, 'flutter')
H = 1500


def fit(img, height):
    w = round(img.width * height / img.height)
    return img.resize((w, height), Image.LANCZOS)


def compare(name):
    # name may be "<stitch folder>" or "<stitch folder>@<variant>"
    folder = name.split('@')[0]
    ref_path = os.path.join(STITCH, folder, 'screen.png')
    out_path = os.path.join(RENDER, name + '.png')
    if not (os.path.exists(ref_path) and os.path.exists(out_path)):
        print('skip', name)
        return
    ref = Image.open(ref_path).convert('RGB')
    out = Image.open(out_path).convert('RGB')
    a, b = fit(ref, H), fit(out, H)
    gap = 24
    sheet = Image.new('RGB', (a.width + b.width + gap * 3, H + 56), (235, 238, 245))
    d = ImageDraw.Draw(sheet)
    d.text((gap, 8), 'STITCH design (screen.png)', fill=(0, 21, 47))
    d.text((a.width + gap * 2, 8), 'FLUTTER render (flutter test test/visual)', fill=(0, 21, 47))
    sheet.paste(a, (gap, 40))
    sheet.paste(b, (a.width + gap * 2, 40))
    os.makedirs(QA, exist_ok=True)
    sheet.save(os.path.join(QA, name + '_compare.png'))
    # Similarity on a common canvas (cheap, indicative only).
    w = min(a.width, b.width)
    diff = ImageChops.difference(a.crop((0, 0, w, H)), b.crop((0, 0, w, H))).convert('L')
    score = 1 - (sum(diff.get_flattened_data()) / (255 * w * H))
    print(f'{name}: similarity {score:.3f}  (stitch {ref.size}, render {out.size})')


if __name__ == '__main__':
    names = sys.argv[1:] or sorted(f[:-4] for f in os.listdir(RENDER) if f.endswith('.png'))
    for n in names:
        compare(n)
