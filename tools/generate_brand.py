"""Render the original ASCEND rising-plane vector mark, shared with AscendMark.swift."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
BANDS = [
    [(0.16, 0.78), (0.43, 0.24), (0.53, 0.24), (0.26, 0.78)],
    [(0.36, 0.78), (0.60, 0.30), (0.69, 0.48), (0.54, 0.78)],
    [(0.64, 0.78), (0.75, 0.56), (0.86, 0.78)],
]
COLORS = ['#EFEFF8', '#B8AEF3', '#8572DD']
svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">\n<rect width="1024" height="1024" fill="#0D0E15"/>\n'
for band, color in zip(BANDS, COLORS):
    svg += '<polygon points="' + ' '.join(f'{x*1024:g},{y*1024:g}' for x, y in band) + f'" fill="{color}"/>\n'
svg += '</svg>\n'
source = ROOT / 'ASCEND/Resources/Brand'; source.mkdir(exist_ok=True)
(source / 'AscendMark.svg').write_text(svg, encoding='utf-8')
icon = ROOT / 'ASCEND/Resources/Assets.xcassets/AppIcon.appiconset'
size = 4096
image = Image.new('RGB', (size, size), '#0D0E15'); draw = ImageDraw.Draw(image)
for band, color in zip(BANDS, COLORS): draw.polygon([(round(x * size), round(y * size)) for x, y in band], fill=color)
image.resize((1024, 1024), Image.Resampling.LANCZOS).save(icon / 'AppIcon.png')
(icon / 'Contents.json').write_text(json.dumps({'images': [{'filename': 'AppIcon.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}], 'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n', encoding='utf-8')
print('Generated original vector source and opaque 1024px iOS app icon.')
