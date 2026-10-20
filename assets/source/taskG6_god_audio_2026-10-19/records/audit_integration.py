from pathlib import Path
import array, hashlib, json, math, re, sys, wave

BATCH = Path(__file__).resolve().parents[1]
ROOT = BATCH.parents[2]
ASSETS = ROOT / 'assets'
manifest = json.loads((BATCH / 'manifest.json').read_text())
acceptance = json.loads((BATCH / 'records/listening_acceptance.json').read_text())
errors = []
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def db(value):
    return 20 * math.log10(max(value, 1e-12))

hooks = {}
script_hashes = {}
for path in sorted((ROOT / 'scripts/gods').glob('*.gd')):
    text = path.read_text()
    script_hashes[str(path.relative_to(ROOT))] = sha(path)
    function = ''
    for line_no, line in enumerate(text.splitlines(), 1):
        match = re.match(r'func (\w+)\(', line)
        if match:
            function = match[1]
        match = re.search(r'Audio\.sfx_or\("([^"]+)",\s*"([^"]*)"(.*?)\)', line)
        if match:
            values = [float(x.strip()) for x in match[3].split(',') if x.strip()]
            hooks[match[1]] = {'script': str(path.relative_to(ROOT)), 'function': function,
                'line': line_no, 'call': line.strip(), 'fallback': match[2],
                'volume_db': values[0] if values else 0.0,
                'pitch_range': values[1] if len(values) > 1 else 0.06,
                'verification': 'literal_source_call_present'}
game = ROOT / 'scripts/game.gd'
text = game.read_text()
script_hashes[str(game.relative_to(ROOT))] = sha(game)
function = ''
for line_no, line in enumerate(text.splitlines(), 1):
    match = re.match(r'func (\w+)\(', line)
    if match:
        function = match[1]
    if function == '_open_reward' and 'Audio.sfx_or(entry.kind' in line:
        kinds = ['god', 'path'] if '+ "_choose"' in line else ['awaken', 'fusion']
        for kind in kinds:
            sound = kind + '_choose' if kind in ['god', 'path'] else kind
            hooks[sound] = {'script': 'scripts/game.gd', 'function': function,
                'line': line_no, 'call': line.strip(), 'entry_kind': kind,
                'fallback': 'level_up', 'volume_db': 0.0, 'pitch_range': 0.06,
                'verification': 'dynamic_call_and_match_branch_present'}
for required in ['"god", "path":', '"awaken", "fusion":']:
    if required not in text:
        errors.append('Missing reward branch ' + required)
loader = ROOT / 'scripts/core/audio.gd'
loader_text = loader.read_text()
script_hashes[str(loader.relative_to(ROOT))] = sha(loader)
loader_checks = {
    'formal_directory': 'res://assets/audio/sfx/' in loader_text,
    'wav_then_ogg': '["wav", "ogg"]' in loader_text,
    'three_numbered_variants': all(x in loader_text for x in ['_01.', '_02.', '_03.']),
    'resource_loader_exists': 'ResourceLoader.exists' in loader_text,
    'random_variant_selection': '.pick_random()' in loader_text,
    'cache_exists': '_streams' in loader_text,
    'sfx_bus': '"SFX"' in loader_text,
}
for name, passed in loader_checks.items():
    if not passed:
        errors.append('Loader source check failed: ' + name)

files = []
for entry in manifest['files']:
    stem, sound = entry['stem'], entry['id']
    formal = ASSETS / entry['runtime_file']
    expected = entry['sha256']
    copies = [formal, BATCH / 'approved' / (stem + '.wav'), BATCH / entry['candidate']]
    hash_ok = all(p.exists() and sha(p) == expected for p in copies)
    accepted = acceptance['accepted_candidate_sha256'].get(stem) == expected
    with wave.open(str(formal), 'rb') as wav:
        channels, width, rate, compression = wav.getnchannels(), wav.getsampwidth(), wav.getframerate(), wav.getcomptype()
        samples = array.array('h', wav.readframes(wav.getnframes()))
    if sys.byteorder != 'little':
        samples.byteswap()
    peak = max(abs(x) for x in samples) / 32768
    onset = next((i / rate * 1000 for i,x in enumerate(samples) if abs(x) / 32768 > 0.001), None)
    tail = samples[-round(rate * 0.01):]
    tail_db = db(math.sqrt(sum((x/32768)**2 for x in tail) / len(tail)))
    checks = {'formal_approved_candidate_hash_match': hash_ok,
        'user_accepted_hash_match': accepted,
        'pcm16_mono44100': (channels, width, rate, compression) == (1, 2, 44100, 'NONE'),
        'peak_minus1dbfs': abs(db(peak) + 1) <= 0.01,
        'onset_within10ms': onset is not None and onset <= 10,
        'zero_boundaries': samples[0] == samples[-1] == 0,
        'no_fullscale_samples': all(abs(x) < 32767 for x in samples),
        'quiet_tail': tail_db <= -45,
        'call_entry_exists': sound in hooks}
    imp = Path(str(formal) + '.import')
    it = imp.read_text() if imp.exists() else ''
    imported = re.search(r'^path="res://([^"]+)"', it, re.M)
    cache_path = ROOT / imported[1] if imported else None
    sidecar = {'exists': imp.exists(),
        'source_path_matches': 'source_file="res://assets/' + entry['runtime_file'] + '"' in it,
        'loop_disabled_in_descriptor': 'edit/loop_mode=0' in it,
        'normalize_disabled_in_descriptor': 'edit/normalize=false' in it,
        'imported_cache_exists': cache_path.exists() if cache_path else False,
        'descriptor_sha256': sha(imp) if imp.exists() else None,
        'cache_sha256': sha(cache_path) if cache_path and cache_path.exists() else None,
        'runtime_load_verified': False}
    if not all(checks.values()):
        errors.append(stem + ': ' + ', '.join(k for k,v in checks.items() if not v))
    files.append({'stem': stem, 'sound_id': sound, 'formal_path': 'assets/' + entry['runtime_file'],
        'sha256': sha(formal), 'checks': checks, 'duration_seconds': len(samples)/rate,
        'peak_dbfs': db(peak), 'onset_ms': onset, 'tail10ms_rms_dbfs': tail_db,
        'import': sidecar, 'hook': hooks.get(sound)})
source_results = [{'file': s['file'], 'sha256_matches': (BATCH / s['file']).exists() and sha(BATCH / s['file']) == s['sha256']} for s in manifest['sources']]
if not all(s['sha256_matches'] for s in source_results):
    errors.append('Source hash mismatch')
groups = {}
for sound in sorted({e['id'] for e in manifest['files'] if e['variant'] is not None}):
    entries = [e for e in manifest['files'] if e['id'] == sound]
    lookup = []
    for ext in ['wav', 'ogg']:
        lookup = [str(p.relative_to(ROOT)) for suffix in ['', '_01', '_02', '_03'] if (p := ASSETS / 'audio/sfx' / (sound + suffix + '.' + ext)).exists()]
        if lookup:
            break
    expected = ['assets/' + e['runtime_file'] for e in entries]
    groups[sound] = {'files_found_by_filename_contract': lookup,
        'exact_three_variants': sorted(lookup) == sorted(expected) and len(lookup) == 3,
        'distinct_hashes': len({e['sha256'] for e in entries}) == 3,
        'all_within_0_3_seconds': all(e['measurement']['duration_seconds'] <= .3 for e in entries)}
    if not all(groups[sound][k] for k in ['exact_three_variants', 'distinct_hashes', 'all_within_0_3_seconds']):
        errors.append('Variant group failed: ' + sound)
report = {'task': 'G6', 'date': '2026-10-19', 'scope': 'existing assets and static source inspection only',
    'status': 'pass_static_handoff' if not errors else 'fail', 'formal_wav_count': len(files),
    'sound_types': len({e['sound_id'] for e in files}), 'hooks_present': len({e['sound_id'] for e in files if e['hook']}),
    'runtime_wavs_modified': False, 'sources_verified': len(source_results),
    'source_results': source_results, 'files': files, 'variant_groups': groups,
    'loader_checks': loader_checks, 'source_snapshot_sha256': script_hashes,
    'code_changes_required_for_current_filename_contract': [],
    'import_descriptor_count': sum(f['import']['exists'] for f in files),
    'imported_cache_count': sum(f['import']['imported_cache_exists'] for f in files),
    'game_test': 'not_performed', 'errors': errors}
(BATCH / 'records/integration_audit_2026-10-19.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({k: report[k] for k in ['status','formal_wav_count','sound_types','hooks_present','sources_verified','import_descriptor_count','imported_cache_count','errors']},ensure_ascii=False))
if errors:
    raise SystemExit(1)
