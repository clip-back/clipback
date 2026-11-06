"""Rebuild the home-only crop/shadow from the shared, unmodified Figma PNG.

Run from any directory with Python 3 and Pillow installed. No source upscaling,
recoloring or background removal: the 1254px original is sampled down to 4x.
"""

from hashlib import sha256
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter

ASSETS = Path(__file__).resolve().parents[1] / 'assets' / 'figma'
SOURCE = ASSETS / 'content-empty-original.png'
assert sha256(SOURCE.read_bytes()).hexdigest() == (
    '73b529416f2232b612211dc37a918af8691f05ccc29e3239061bf662a40ea693'
)
SCALE = 4
# Existing 67x78 crop ratios; the old 71x82 export adds 2px either side
# and 4px below for its silhouette shadow. Preserve that white export canvas.
sx = 67 * 1.6118 / 1254
sy = 78 * 1.3918 / 1254
tx = 2 - 67 * .3072
ty = -78 * .172
source = Image.open(SOURCE).convert('RGBA')
art = source.transform(
    (71 * SCALE, 82 * SCALE), Image.Transform.AFFINE,
    (1 / sx / SCALE, 0, -tx / sx, 0, 1 / sy / SCALE, -ty / sy),
    Image.Resampling.BICUBIC,
)
clip = Image.new('L', art.size)
clip.paste(255, (2 * SCALE, 0, 69 * SCALE, 78 * SCALE))
art.putalpha(ImageChops.darker(art.getchannel('A'), clip))
# Same silhouette shadow as the other empty boxes: black 31/255, dy=2,
# Gaussian sigma=1 (Figma/CSS blur radius=2).
shadow = Image.new('RGBA', art.size)
shadow.putalpha(art.getchannel('A').point(lambda a: round(a * 31 / 255)))
shadow = shadow.filter(ImageFilter.GaussianBlur(SCALE))
shifted = Image.new('RGBA', art.size)
shifted.paste(shadow, (0, 2 * SCALE))
result = Image.new('RGBA', art.size, 'white')
result.alpha_composite(shifted)
result.alpha_composite(art)
result.save(ASSETS / 'home-empty.png')
