from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import unquote, urlsplit
import json, hashlib, re, collections

ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT / 'assets/source/taskL1_paths_2026-10-20'
jobs = json.loads((BASE/'records/plan_all_L.json').read_text())

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []

    def handle_starttag(self, tag, attrs):
        self.links.extend(v for k, v in attrs if k in ['href', 'src'])

prohibited = ['Thor','Odin','Loki','Freyja','Freyr','Baldr','Skadi','Ran','Miyamoto','Musashi','Marvel','God of War','Fate','Vagabond','Nioh']
report = {'scope': 'file/provenance/HTML-link/offline-preview audits only; no browser render or game run', 'tasks': {}, 'prompt_violations': [], 'gameplay_line_changes': [], 'errors': []}
hashes = []
for task in ['L1', 'L2']:
    group = [j for j in jobs if j['task'] == task]
    root = ROOT/group[0]['root']
    manifest = json.loads((root/'manifest.json').read_text())
    assert len(manifest['assets']) == len(group) and manifest['pending'] == []
    genfiles = sorted((root/'records').glob('generation_*.json'))
    gens = [json.loads(f.read_text()) for f in genfiles]
    assert all(g['status'] in ['approved','rejected'] and g['review'] for g in gens)
    assert {g['original'] for g in gens} == {str(f.relative_to(root)) for f in (root/'originals').glob('*.png')}
    for g in gens:
        for word in prohibited:
            if re.search(r'\b'+re.escape(word)+r'\b',g['prompt'],re.I):
                report['prompt_violations'].append([g['id'],g['version'],word])
        assert sha(root/g['original']) == g['original_sha256']
        for ref in g['references']:
            assert sha(root/ref['archive']) == ref['sha256']
    levels = 0
    for x in manifest['assets']:
        assert sha(ROOT/x['formal']) == x['sha256']
        hashes.append(x['sha256'])
        for mip in x['offline_mipmaps']:
            assert sha(root/mip['path']) == mip['sha256']
            levels += 1
        assert (root/'previews'/f'comparison_{x["id"] if task=="L2" else x["id"].split("_")[0]}.png').exists()
    parser = Links()
    parser.feed((root/'gallery.html').read_text())
    for link in parser.links:
        if not urlsplit(link).scheme:
            assert (root/unquote(link.split('#')[0])).exists(), link
    for name in ['README.md','integration.md','manifest.json','gallery.html','records/file_audit.json','records/comparison_review.json']:
        assert (root/name).is_file()
    inventory = [{'path':str(f.relative_to(root)),'size_bytes':f.stat().st_size,'sha256':sha(f)} for f in sorted(root.rglob('*')) if f.is_file() and not any(part in ['__pycache__','runtime','runtime_current','runtime_commit'] for part in f.relative_to(root).parts) and f.name not in ['source_inventory.json','final_audit.json','publication.json','cleanup_result.json']]
    (root/'source_inventory.json').write_text(json.dumps({'inventory_scope':'task deliverables excluding this inventory, final audit, post-publication receipts, Python bytecode and rebuildable isolated runtime copies; re-run after final edits','files':inventory},ensure_ascii=False,indent=2)+'\n')
    report['tasks'][task] = {'final_files':len(manifest['assets']),'generation_outputs':len(gens),'version_status':dict(collections.Counter(g['status'] for g in gens)),'offline_mipmap_files':levels,'gallery_local_links_checked':len(parser.links),'inventory_files':len(inventory)}
for j in jobs:
    src=ROOT/('scripts/data/upgrade_db.gd' if j['task']=='L1' else 'scripts/data/gods.gd')
    key=j['id'] if j['task']=='L1' else j['id'].removeprefix('fusion_')
    m=re.search(r'^\s*"'+re.escape(key)+r'": (\{.*\}),?$',src.read_text(),re.M)
    if not m or m.group(0).strip()!=j['current_gameplay_source_line']:
        report['gameplay_line_changes'].append(j['id'])
baseline=json.loads((BASE/'records/code_baseline.json').read_text())
report['code_baseline_read_only_comparison']={'files_checked':len(baseline),'changed_since_start':[rel for rel,digest in baseline.items() if not (ROOT/rel).exists() or sha(ROOT/rel)!=digest],'interpretation':'Later user authorized Part L integration. Own production code changes are limited to scripts/ui/level_up_panel.gd. Shared workspace may contain concurrent agent edits; hashes alone do not attribute them.'}
assert len(hashes)==60 and len(set(hashes))==60
assert not report['prompt_violations'] and not report['gameplay_line_changes']
assert (ROOT/'assets/source/.gdignore').exists(), 'source snapshots should stay excluded from Godot import'
report['unique_formal_files'] = len(set(hashes))
acceptance=BASE/'integration_2026-10-20/acceptance.json'
report['game_acceptance'] = json.loads(acceptance.read_text()) if acceptance.exists() else 'untested'
(BASE/'records/final_audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
