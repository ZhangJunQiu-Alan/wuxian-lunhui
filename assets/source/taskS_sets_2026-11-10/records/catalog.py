from datetime import datetime
from hashlib import file_digest
from pathlib import Path
import json
from zoneinfo import ZoneInfo

from PIL import Image

from effects import FX
from guardian import ACTIONS
from revision_pixels import ARMOR, EFFECTS
from pixels import BASE, PALETTES, SLOTS

ROOT = BASE.parents[2]
ASSET = ROOT / 'assets'
BRIEF = ROOT / 'docs/Codex_套装防具美术任务.md'
DESIGN = ROOT / 'docs/装备系统_已确认.md'
ORDER = ['thornoath','lotus','xingtian','nightcount','nemean','dragonslayer','yellowwind','grail','valhalla','bearskin']
DEST = {'armor': 'sprites/items/armor', 'status': 'sprites/ui/sets', 'effects': 'sprites/effects/sets', 'actors': 'sprites/allies'}
GROUNDS = {
    '雪地': 'sprites/ground/midgard/snow_01.png',
    '冥界': 'sprites/ground/helheim/stone_01.png',
    '焦土': 'sprites/ground/vigrid/scorched_01.png',
}
SAMPLE = ['katana', 'muramasa', 'chunyang', 'riyue']
PLAYER = 'sprites/characters/swordsman_bare_idle.png'


def rel(p):
    from os.path import relpath
    return relpath(p, BASE)


def rows(text):
    for line in text.splitlines():
        if line.startswith('|'):
            yield [x.strip() for x in line.strip('|').split('|')]


def sha(p):
    with p.open('rb') as f:
        return file_digest(f,'sha256').hexdigest()


def record(path, kind, **spec):
    logical_id = Path(path).stem
    previous = BASE / 'approved' / kind / path
    revised = logical_id in (ARMOR if kind=='armor' else EFFECTS if kind=='effects' else ())
    if revised:
        path = logical_id + '_r2.png'
    approved = BASE / 'approved' / kind / path
    if not approved.exists():
        return None
    target = ASSET / DEST[kind] / path
    with Image.open(approved) as im:
        entry = {'id': logical_id, 'file': rel(approved), 'runtime': target.relative_to(ROOT).as_posix(),
                 'size': list(im.size), 'sha256': sha(approved), 'kind': kind, **spec}
    if revised and previous.exists():
        entry['previous'] = rel(previous)
    return entry


def collect():
    design = DESIGN.read_text()
    sets = {}
    items = {}
    for row in rows(design):
        if len(row) == 5 and row[2].startswith('`'):
            area, name, key, effect, rule = row
            key = key.strip('`')
            sets[key] = {'id':key,'name':name,'area':area,'effect':effect,'rule':rule,'items':[]}
        elif len(row) == 4 and row[2].startswith('`'):
            part, name, key, desc = row
            items[key.strip('`')] = {'part':part,'name':name,'description':desc.replace('<br>','\n')}
    source = BRIEF.read_text()
    motif = {}
    visuals = {}
    for row in rows(source):
        if len(row) == 6 and row[1].startswith('`'):
            _, key, _, _, theme, origin = row
            motif[key.strip('`')] = {'theme':theme,'origin':origin}
        elif len(row) == 4 and row[0].startswith('`'):
            key, _, look, silhouette = row
            visuals[key.strip('`')] = {'look':look,'silhouette':silhouette}
    records = []
    for key, kit in sets.items():
        kit.update(motif[key])
        kit['stage'] = 1 if key in ORDER[:2] else (2 if key in ORDER[2:5] else (3 if key in ORDER[5:8] else 4))
        kit['palette'] = PALETTES[key].split()
        concept = BASE/'originals'/f'{key}.png'
        if key=='xingtian' and (BASE/'originals/xingtian-r2.png').exists():
            kit['concept_previous'] = rel(concept)
            concept = BASE/'originals/xingtian-r2.png'
        kit['concept'] = rel(concept) if concept.exists() else None
        if concept.exists():
            kit['concept_sha256'] = sha(concept)
        for slot in SLOTS:
            id = f'{key}_{slot}'
            entry = record(id+'.png','armor',slot=slot,frames=1,kit=key)
            if entry:
                records.append(entry)
            kit['items'].append({'id':id,'slot':slot,**items[id],**visuals[id],'asset':entry})
        status = record(key+'.png','status',frames=1,kit=key)
        if status:
            records.append(status)
        kit['status'] = status
        kit['effects'] = []
        for id, fx in FX.items():
            if fx['kit'] != key:
                continue
            spec = {**fx, 'frame_size': fx['size']}
            del spec['size']
            asset = record(id+'.png','effects',**spec)
            kit['effects'].append({'id':id, **spec, 'asset':asset})
            if asset:
                records.append(asset)
    guardian = {}
    for action, meta in ACTIONS.items():
        actor = record(f'valhalla_guardian_{action}.png', 'actors', kit='valhalla',
                       frame_size=[64,64], anchor=[32,55], facing='right', **meta)
        if actor:
            records.append(actor)
            guardian[action] = actor
    notes = json.loads((BASE/'records/review-r2.json').read_text())
    for note in notes:
        asset = next((f for f in records if f['id']==note['id']),None)
        if asset and asset.get('previous'):
            note['previous'] = asset['previous']
    timestamp = datetime.now(ZoneInfo('Asia/Singapore')).isoformat(timespec='minutes')
    phase = next((s for s in range(1,5) if any(k['stage']==s and not k['status'] for k in sets.values())),5)
    return {
        'updated': timestamp, 'batch': phase, 'sets': list(sets.values()), 'files': records,
        'revision': 2, 'reviewNotes': notes, 'guardian': guardian,
        'guardianConcept': 'originals/valhalla-guardian-r2.png',
        'grounds': {k:rel(ASSET/v) for k,v in GROUNDS.items()},
        'weaponSamples': [rel(ASSET/'sprites/weapons/swordsman'/f'{k}_icon.png') for k in SAMPLE],
        'player': rel(ASSET/PLAYER),
        'comparison': [
            ['nemean_helm','bearskin_helm'],['dragonslayer_chest','valhalla_chest'],
            ['nemean_legs','grail_legs'],['yellowwind_legs','bearskin_legs'],
        ],
    }


def build():
    data = collect()
    (BASE/'manifest.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    template = (BASE/'records/page.html').read_text()
    inline = json.dumps(data,ensure_ascii=False).replace('</','<\\/')
    tmp = BASE/'index.tmp'
    tmp.write_text(template.replace('/*DATA*/',inline))
    tmp.replace(BASE/'index.html')


if __name__ == '__main__':
    build()
