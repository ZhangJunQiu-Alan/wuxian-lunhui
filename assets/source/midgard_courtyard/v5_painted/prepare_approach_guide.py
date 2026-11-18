"""Register the Blender render and the approved paint to the approach whitebox."""
from pathlib import Path
from PIL import Image

from prepare_stelae import STRUCTURE, layout, project

source = Path(__file__).parent
size = (1536, 1024)
guide = Image.open(source / '引导/approach-whitebox.png').convert('RGB').resize(size, Image.Resampling.LANCZOS)
east = Image.open(source / 'court-edge-paint.png').convert('RGB').resize((1152, 768), Image.Resampling.LANCZOS).crop((0, 0, 768, 768))
mask = Image.new('L', (768, 1))
mask.putdata([round(255 * min(1, max(0, (x - 156) / 70))) for x in range(768)])
guide.paste(east, (768, 0), mask.resize(east.size, Image.Resampling.NEAREST))
structure = Image.open(STRUCTURE).convert('RGBA')
data = layout()
guide = guide.convert('RGBA')
for stele in data["stelae"]:
    sprite, origin = project(structure, data, stele)
    guide.alpha_composite(sprite, origin)
guide.save(source / '引导/approach-stelev2-guide.png')
