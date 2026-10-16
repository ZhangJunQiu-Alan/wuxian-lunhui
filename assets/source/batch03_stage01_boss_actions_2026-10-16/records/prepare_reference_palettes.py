from pathlib import Path
from PIL import Image
import json
r=Path(__file__).resolve().parents[1]
for name in ['skoll','hati','hrym']:
 im=Image.open(r/f'references/{name}.png').convert('RGBA');im.putalpha(im.getchannel('A').point(lambda a:255 if a>=128 else 0));colors=[p[:3] for p in im.get_flattened_data() if p[3]];sample=Image.new('RGB',(len(colors),1));sample.putdata(colors);pal=sample.quantize(colors=48,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE);q=im.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGBA');q.putalpha(im.getchannel('A'));q.save(r/f'references/{name}_48color.png');(r/f'records/{name}_reference_palette.json').write_text(json.dumps([pal.getpalette()[i:i+3] for i in range(0,144,3)]))
