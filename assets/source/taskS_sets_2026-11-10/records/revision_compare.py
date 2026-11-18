from PIL import Image, ImageDraw, ImageFont

from catalog import BASE, ASSET, PLAYER, GROUNDS, collect

INK='#e9dfcd'
PANEL='#182128'
FONT=ImageFont.truetype(str(ASSET/'fonts/NotoSansSC-Regular.otf'),14)
SMALL=ImageFont.truetype(str(ASSET/'fonts/NotoSansSC-Regular.otf'),12)


def armor(data):
    files=[f for f in data['files'] if f['kind']=='armor' and f.get('previous')]
    names={i['id']:i['name'] for kit in data['sets'] for i in kit['items']}
    image=Image.new('RGB',(112+len(files)*112,260),PANEL)
    d=ImageDraw.Draw(image)
    d.text((12,7),'S–SET · 防具返修 3×',fill=INK,font=FONT)
    for y,title in enumerate(('原稿','第 2 轮')):
        d.text((22,94+107*y),title,fill=INK,font=FONT)
    for x,asset in enumerate(files):
        at=112+x*112
        d.text((at+48,27),names[asset['id']],fill=INK,font=SMALL,anchor='mm')
        for y,version in enumerate(('previous','file')):
            d.rectangle((at,44+107*y,at+95,139+107*y),fill='#303c48')
            with Image.open(BASE/asset[version]) as src:
                sprite=src.resize((96,96),Image.Resampling.NEAREST)
                image.paste(sprite,(at,44+107*y),sprite)
    image.save(BASE/'previews/review-r2-icons.png',optimize=True)


def effects(data):
    title={
        'xingtian_mengzhi':'猛志叠层','dragonslayer_scale':'龙鳞已备',
        'yellowwind_storm':'三昧神风 · 循环','yellowwind_storm_start':'三昧神风 · 卷起',
        'yellowwind_storm_end':'三昧神风 · 消散','lotus_proc':'莲花绽放',
        'valhalla_ring':'英灵本体与符文环',
    }
    original={
        'dragonslayer_scale':(64,64,32,32),'yellowwind_storm':(96,112,48,62),
        'yellowwind_storm_start':(96,112,48,62),'yellowwind_storm_end':(96,112,48,62),
        'lotus_proc':(64,64,32,32),'valhalla_ring':(32,12,16,6),
    }
    files=sorted([f for f in data['files'] if f['id'] in title],
                 key=lambda f:list(title).index(f['id']))
    im=Image.new('RGB',(1024,322),PANEL)
    d=ImageDraw.Draw(im)
    d.text((12,7),'S–SET · 特效返修 1×',font=FONT,fill=INK)
    terrain=Image.open(ASSET/GROUNDS['冥界']).convert('RGBA')
    player=Image.open(ASSET/PLAYER).convert('RGBA').crop((0,0,64,64))
    guardian=Image.open(BASE/data['guardian']['idle']['file']).convert('RGBA').crop((0,0,64,64))
    for y,label in enumerate(('原稿','第 2 轮')):
        d.text((16,104+131*y),label,font=FONT,fill=INK)
    for x,f in enumerate(files):
        key=f['id']
        at=76+135*x
        d.text((at+64,25),title[key],fill=INK,font=SMALL,anchor='mm')
        for row,version in enumerate(('previous','file')):
            cell=Image.new('RGBA',(128,124),'#26313c')
            for dx in (0,64):
                for dy in (0,64):
                    cell.paste(terrain,(dx,dy))
            if version not in f:
                cd=ImageDraw.Draw(cell)
                cd.text((64,63),'本轮新增',font=SMALL,fill=INK,anchor='mm')
            else:
                w,h,ax,ay=original[key] if version=='previous' else (*f['frame_size'],*f['anchor'])
                n=1 if key.endswith(('_start','_end')) else 2
                body=key in ('dragonslayer_scale','lotus_proc','xingtian_mengzhi')
                if key=='dragonslayer_scale':
                    cell.alpha_composite(player,(32,34))
                with Image.open(BASE/f[version]) as src:
                    cell.alpha_composite(src.crop((n*w,0,(n+1)*w,h)),(64-ax,66-ay))
                if body and key!='dragonslayer_scale':
                    cell.alpha_composite(player,(32,34))
                if key=='valhalla_ring':
                    cell.alpha_composite(player if version=='previous' else guardian,(32,11))
            im.paste(cell.convert('RGB'),(at,42+131*row))
    im.save(BASE/'previews/review-r2-effects.png',optimize=True)


if __name__=='__main__':
    data=collect()
    armor(data)
    effects(data)
