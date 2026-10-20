from pathlib import Path
from collections import Counter, deque
import hashlib
import html
import json
import math
import random
import wave
from PIL import Image, ImageDraw, ImageFont

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[2]
SPR = 'assets/sprites/'


def dump(name, data):
    (BASE / name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def write(name, text):
    (BASE / name).write_text(text.strip() + '\n')


assets = []


def reuse(rel, task, role, frames=1, fps=0, anchor=None, alpha='binary', decision='reuse_unchanged'):
    path = 'assets/' + rel if rel.startswith('audio/') else SPR + rel
    p = ROOT / path
    row = dict(id=Path(rel).stem, task=task, path=path, representation='existing_file', decision=decision,
               production_status='already_exists_do_not_reproduce', role=role, sha256=sha(p),
               integration_status='K_not_implemented', integration_dependencies=['level_registration', task])
    if p.suffix == '.png':
        im = Image.open(p).convert('RGBA')
        size = [im.width // frames, im.height]
        row.update(sheet_size=list(im.size), frame_size=size, frames=frames, fps=fps,
                   anchor_px=anchor or [size[0] // 2, size[1] // 2], alpha_policy=alpha,
                   direction='right_unless_static_ground', scale='1x; nearest; no fractional entity scale')
    else:
        row.update(frame_size=None, frames=None, fps=None, anchor_px=None, alpha_policy='not_applicable_audio')
    assets.append(row)
    return row


def new(rel, task, size, frames, fps, role, refs, anchor=None, loop=False, alpha='binary', gate='C2'):
    row = dict(id=Path(rel).stem, task=task, path=SPR + rel, representation='planned_file',
               decision='new_proposed', production_status='not_created', specification_status='K0_proposal_not_runtime_frozen',
               frame_size=size, sheet_size=[size[0] * frames, size[1]], frames=frames, fps=fps,
               loop=loop, anchor_px=anchor or [size[0] // 2, size[1] // 2], direction='right',
               alpha_policy=alpha, palette_rgb_max=48, transparent_margin_px=2,
               role=role, reference_paths=[SPR + x for x in refs], sha256=None,
               integration_status='not_implemented', integration_dependencies=[gate, task],
               approval_gate=gate, scale='1x for bodies; texture effects clipped to authoritative geometry')
    assets.append(row)
    return row


for name, sz, anchor in [('jormungandr_head', 128, [64, 64]), ('jormungandr_body', 64, [32, 30]),
                         ('jormungandr_tail', 64, [64, 30]), ('fenrir', 192, [96, 190]), ('surtr', 192, [96, 190])]:
    reuse('bosses/' + name + '.png', 'K1' if name.startswith('jorm') else 'K2' if name == 'fenrir' else 'K3',
          'existing character identity/reference; preserve original', anchor=anchor)
for name in ['fire_giant', 'frost_veteran']:
    reuse('enemies/' + name + '.png', 'K4', 'existing large enemy identity', anchor=[48, 94])
for name, n, fps in [('dead', 1, 0), ('dead_move', 6, 8), ('dead_attack', 4, 16)]:
    reuse('enemies/' + name + '.png', 'K4', 'remaining dead; use existing ordinary variant, no third-level redraw', n, fps, [32, 62])
for name in ['scorched_01', 'scorched_02', 'scorched_03', 'scorched_04', 'cracked_lava', 'burnt_grass']:
    reuse('ground/vigrid/' + name + '.png', 'K5', 'existing base terrain; decorative lava is not a damage collider', alpha='opaque_ground')
for name in ['bifrost_fragment', 'broken_weapons', 'burning_wreckage', 'fallen_shield', 'giant_remains']:
    row = reuse('props/vigrid/' + name + '.png', 'K5', 'existing static landmark dressing')
    row['anchor_px'] = [row['frame_size'][0] // 2, row['frame_size'][1]]
    row['anchor_convention'] = 'MapLayer.prop uses canvas bottom, not last nontransparent pixel'
for name in ['swordsman', 'gunslinger', 'assassin', 'mage']:
    reuse('characters/' + name + '.png', 'K0', 'scale/style reference only; no K production', anchor=[32, 60])
reuse('effects/bosses/nidhogg_poison_breath.png', 'K1', 'poison breath texture reused; new serpent cone collider/clip required', 4, 16, [4, 32], 'soft_effect')
reuse('effects/poison_pool.png', 'K1', 'poison area texture only; do not copy fixed-radius PoisonPool behavior', 8, 8, [24, 24], 'soft_effect')
reuse('effects/hit_bite.png', 'K1', 'body impact contact flash, generic existing effect', 4, 16, alpha='soft_effect')
reuse('effects/gods/thor_hammer.png', 'K1', 'optional existing aid symbol; lightning uses LightningFx, no new Thor body', anchor=[16, 16])
reuse('effects/gods/thor_cloud.png', 'K1', 'optional existing aid cloud', anchor=[64, 32], alpha='soft_effect')
reuse('effects/bosses/garm_chain_break.png', 'K2', 'short binding release flash; shader tint needs comparison, not new iron chain', 4, 16, alpha='soft_effect')
reuse('effects/gods/loki_fire_patch.png', 'K3', 'existing residual fire overlay; damage ownership belongs to Surtr hazard controller', alpha='soft_effect')
reuse('effects/gods/freyr_field.png', 'K3', 'existing healing field texture; aid healing is separate from player Freyr skill', alpha='soft_effect')
reuse('effects/bosses/hrym_ice_break.png', 'K4', 'existing cold impact fragments for frost veteran', 4, 16, alpha='soft_effect')
reuse('effects/death_shards.png', 'K4', 'generic ordinary enemy death feedback', 4, 16, alpha='soft_effect')
for name in ['dried_blood_01', 'dried_blood_02', 'drag_mark_01']:
    reuse('decals/helheim/' + name + '.png', 'K5', 'existing ground-neutral battle traces, reuse path directly; no duplicate Vigrid copy', alpha='soft_effect')
for name in ['boss', 'victory', 'defeat']:
    reuse('audio/music/' + name + '.ogg', 'K6', 'existing music, subjective/current-game mix acceptance still required')

head = ['bosses/jormungandr_head.png', 'bosses/jormungandr_body.png']
for action, n, fps, loop in [('idle', 4, 8, True), ('windup', 3, 8, False), ('attack', 4, 16, False)]:
    row = new('bosses/jormungandr_head_' + action + '.png', 'K1', [128, 128], n, fps,
              'same head; neck socket (0,62) fixed; no poison baked into body', head, [64, 64], loop)
    row['transparent_margin_exception'] = 'left neck socket intentionally open; all unrelated boundaries >=2px'

for action, n, fps, loop in [('idle', 4, 8, True), ('move', 6, 8, True), ('windup', 3, 8, False),
                              ('attack', 4, 16, False), ('swallow', 6, 16, False)]:
    new('bosses/fenrir_' + action + '.png', 'K2', [192, 192], n, fps,
        'same wolf, fixed paws; swallow body separated from enormous jaw overlay', ['bosses/fenrir.png'], [96, 190], loop)
new('effects/bosses/fenrir_maw.png', 'K2', [256, 256], 4, 8,
    'upper/lower jaw framing with open center; loop hold only, no opaque fatal-zone disk', ['bosses/fenrir.png'], loop=True, gate='C3')
new('effects/bosses/fenrir_bind.png', 'K2', [192, 192], 4, 8,
    'thin luminous braided restraint, transparent center; not Garm iron chain', ['bosses/fenrir.png', 'props/helheim/chain_stake.png'], loop=True, alpha='soft_effect', gate='C3')
new('pickups/gleipnir_fragment.png', 'K2', [24, 24], 1, 0,
    'small bright braided magical binding fragment; readable over corpses; no iron stake', ['props/helheim/chain_stake_broken.png'], gate='C3')

for action, n, fps, loop in [('idle', 4, 8, True), ('move', 6, 8, True), ('windup', 3, 8, False),
                              ('attack', 4, 16, False), ('plant', 4, 16, False), ('summon', 4, 16, False)]:
    row = new('bosses/surtr_' + action + '.png', 'K3', [256, 256], n, fps,
              'uniform action canvas enlarged for sword arc; body remains 192px source scale; not a larger giant',
              ['bosses/surtr.png'], [128, 254], loop, gate='C4')
    row['reference_placement_px'] = [32, 64]
    row['fallback_alignment'] = 'old static anchor (96,190), new anchor (128,254); custom visual adapter required'
new('effects/bosses/surtr_sword_arc.png', 'K3', [128, 128], 4, 16,
    'fiery cutting arc; cone clipping uses same angle/radius as damage', ['bosses/surtr.png'], alpha='soft_effect', gate='C4')
new('effects/bosses/surtr_gate.png', 'K3', [128, 128], 4, 8,
    'fire gateway behind summoned giants; loop while opening is active', ['bosses/surtr.png', 'enemies/fire_giant.png'], [64, 126], True, 'soft_effect', 'C4')
new('effects/bosses/surtr_firewall_band.png', 'K3', [64, 64], 4, 8,
    'repeatable band; horizontal tangent, outside/up is burning, lower inside edge stays transparent',
    ['bosses/surtr.png', 'ground/vigrid/cracked_lava.png'], [32, 32], True, 'soft_effect', 'C4')
new('effects/bosses/surtr_final_fire.png', 'K3', [64, 64], 4, 16,
    'one damaging grid cell burst, tiled only over actual unsafe cells; not a fullscreen opaque image',
    ['bosses/surtr.png'], alpha='soft_effect', gate='C4')
new('effects/bosses/surtr_safe_rune.png', 'K3', [64, 64], 1, 0,
    'thin nontextual geometric rune at safe cell perimeter, center clear; collision owned by same cell grid',
    ['effects/gods/odin_rune_circle.png'], alpha='soft_effect', gate='C4')

for name in ['fire_giant', 'frost_veteran']:
    for action, n, fps, loop in [('move', 6, 8, True), ('attack', 4, 16, False)]:
        new('enemies/' + name + '_' + action + '.png', 'K4', [96, 96], n, fps,
            'existing giant identity; fixed feet and torso; no ground effect baked in', ['enemies/' + name + '.png'], [48, 94], loop, gate='C5')
for action, n, fps, loop in [('charge', 4, 8, True), ('shield', 3, 8, False)]:
    new('enemies/frost_veteran_' + action + '.png', 'K4', [96, 96], n, fps,
        'charge cycle / raise and hold shield; do not obscure attackable back', ['enemies/frost_veteran.png'], [48, 94], loop, gate='C5')
for action, n, fps, loop in [('', 1, 0, False), ('move', 6, 8, True), ('attack', 4, 16, False), ('rage', 3, 8, False)]:
    new('enemies/wolf_berserker' + ('_' + action if action else '') + '.png', 'K4', [64, 64], n, fps,
        'human wolf-pelt warrior, distinct from quadruped wolves and dead; rage has a readable raised silhouette',
        ['enemies/dead.png', 'bosses/fenrir.png'], [32, 62], loop, gate='C5')
new('effects/bosses/fire_giant_explosion.png', 'K4', [96, 96], 4, 16,
    'death explosion only, no giant corpse baked in; persistent fire reuses existing patch', ['enemies/fire_giant.png'], alpha='soft_effect', gate='C5')

for who, size, task, action, n in [('vidar', 96, 'K2', 'pry', 6), ('freyr', 64, 'K3', 'heal', 4)]:
    refs = ['characters/swordsman.png', 'cards/' + ('odin.png' if who == 'vidar' else 'freyr.png')]
    for act, count, fps, loop in [('', 1, 0, False), ('idle', 4, 8, True), (action, n, 16, False)]:
        new('allies/' + who + ('_' + act if act else '') + '.png', task, [size, size], count, fps,
            'new world-space ally; portrait is color/identity reference only, never a world sprite; ' +
            ('heavy boot bracing lower jaw and hands lifting upper jaw' if who == 'vidar' else 'unarmed treatment gesture; no duplicate divine flying sword'),
            refs, [size // 2, size - 2], loop, gate='C6')

for suffix in ['n', 'e', 's', 'w', 'outer_ne', 'outer_nw', 'outer_se', 'outer_sw', 'inner_ne', 'inner_nw', 'inner_se', 'inner_sw']:
    row = new('ground/vigrid/grass_edge_' + suffix + '.png', 'K5', [64, 64], 1, 0,
              'burnt grass to scorched ground; 12 edge masks required by current MapLayer.EDGE_TILES; no redrawing base tile',
              ['ground/vigrid/burnt_grass.png', 'ground/vigrid/scorched_01.png'], gate='C7')
    row['transparent_margin_px'] = None
    row['transparent_margin_exception'] = 'terrain interface must reach tile edge; four-corner bitmask contract'
new('decals/vigrid/giant_tread.png', 'K5', [64, 64], 1, 0,
    'large boot scuff around frost remnant patch; neutral ash, not lava or damage warning',
    ['ground/vigrid/scorched_01.png', 'enemies/frost_veteran.png'], gate='C7')
new('props/vigrid/distant_battle.png', 'K5', [512, 128], 4, 8,
    'small low-contrast mythic warrior/giant silhouettes in northern unwalkable strip; does not assert a god death',
    ['bosses/surtr.png', 'enemies/frost_veteran.png', 'ground/vigrid/scorched_01.png'], [256, 128], True, 'soft_effect', 'C7')
assets.append(dict(id='vigrid_music', task='K6', path='assets/audio/music/vigrid.ogg', representation='planned_file',
                   decision='new_proposed', production_status='not_created', frame_size=None, frames=None, fps=None, anchor_px=None,
                   alpha_policy='not_applicable_audio', format='OGG Vorbis stereo 44100Hz, approximately -16 LUFS',
                   duration_seconds=None, duration_status='规格未定; choose complete musical phrase, not arbitrary crop',
                   role='Vigrid main theme; seamless three-loop listening required', reference_paths=['assets/audio/music/boss.ogg'],
                   source_license='not_chosen; verify commercial terms before source acquisition', sha256=None,
                   integration_dependencies=['C8', 'K6'], specification_status='music_source_and_duration_unfrozen'))

procedural = [
    dict(id='serpent_ribbon', task='K1', path=None, representation='procedural_with_existing_texture',
         sources=['bosses/jormungandr_body.png', 'bosses/jormungandr_tail.png'],
         role='arc-length UV ribbon with capped sockets; head only in enemy targeting; no full-snake PNG', gate='C3'),
    dict(id='swallow_field', task='K2', path=None, representation='procedural',
         role='attraction vectors, safe exit/time warning, fatal center outline; never baked into maw texture', gate='C3'),
    dict(id='surtr_safe_cells', task='K3', path=None, representation='procedural_with_planned_texture',
         role='64px grid cell set is authoritative for damage, safe rune and fire; whole-cell fire only', gate='C4'),
    dict(id='border_solution', task='K5', path=None, representation='procedural_with_existing_texture',
         role='256px unwalkable band: existing scorched tiles + outer props + new firewall segment/haze; no forced eight new borders', gate='C7'),
    dict(id='ambient_fire', task='K5', path=None, representation='reuse_planned_texture',
         sources=['effects/bosses/surtr_firewall_band.png', 'effects/gods/loki_fire_patch.png'],
         role='decorative only outside encounter masks; explicit damage=false; no new environment fire duplicate', gate='C7'),
    dict(id='ending', task='K7', path=None, representation='text_and_existing_ui',
         role='five text beats, optional existing Baldr card in UI; no new ending illustration until a separate art need is approved', gate='C8'),
    dict(id='general_god_assistance', task='K5', path=None, representation='specification_unresolved',
         role='world text only gives Thor example; list other god effects only after gameplay owner fixes nearby condition and cadence',
         file_count=None, frame_size=None, status='规格未定', gate='C6'),
]

landmarks = [
    dict(id='battlefield', name='中央燃烧平原', pos=[0, 0], radius=1088, role='open combat/readability reserve; no fixed fight lock', density='medium'),
    dict(id='bifrost', name='崩塌彩虹桥残端', pos=[-1536, -1408], radius=384, role='reuse bifrost fragments; no bridge crossing gameplay', density='low'),
    dict(id='giant_graveyard', name='诸神与巨人残骸带', pos=[1536, -1280], radius=384, role='reuse giant remains and shields; no identifiable god corpses', density='medium'),
    dict(id='frost_remnants', name='霜巨人残部', pos=[-1536, 1024], radius=384, role='burnt grass patch and tread; not a new quest', density='medium'),
    dict(id='muspel_edge', name='穆斯贝尔前线', pos=[1536, 1280], radius=448, role='wreckage and decorative fire, not permanent damage zone', density='high'),
    dict(id='dead_march', name='亡者残余行军带', pos=[0, 1792], radius=256, role='weapons, drag marks; reuse dead animations', density='high'),
]
props = []
for lm in landmarks[1:]:
    choices = {'bifrost': ['bifrost_fragment', 'broken_weapons'], 'giant_graveyard': ['giant_remains', 'fallen_shield'],
               'frost_remnants': ['giant_remains', 'broken_weapons'], 'muspel_edge': ['burning_wreckage', 'fallen_shield'],
               'dead_march': ['broken_weapons', 'fallen_shield']}[lm['id']]
    for i, name in enumerate(choices):
        side = (220 if i == 0 else -220) if lm['id'] == 'giant_graveyard' else (-220 if i == 0 else 220)
        props.append(dict(asset=SPR + 'props/vigrid/' + name + '.png', pos=[lm['pos'][0] + side, lm['pos'][1] + 140],
                          anchor='canvas_bottom_center', block_radius=20 if name in ['bifrost_fragment', 'giant_remains'] else 0,
                          role='layout sample placement; scattering seed and final population not frozen'))
routes = [[landmarks[0]['pos'], lm['pos']] for lm in landmarks[1:]]
ring_order = [1, 2, 4, 5, 3]
routes += [[landmarks[i]['pos'], landmarks[ring_order[(j+1) % len(ring_order)]]['pos']] for j,i in enumerate(ring_order)]
layout = dict(status='proposed_not_playable', coordinates='world pixels, origin spawn, +x east, +y south; tile=floor(world/64)',
              tile_size=64, view_rect=[-2560, -2560, 5120, 5120], border=256, walk_rect=[-2304, -2304, 4608, 4608],
              spawn=[0, 0], clear_spawn_radius=384, combat_no_fixed_obstacles_radius=1280,
              routes=routes, route_reserved_width=256, landmarks=landmarks, prop_examples=props,
              horizon_rect=[-768, -2480, 1536, 128], horizon_collision=False,
              density_note='relative composition/spawn emphasis proposal only; no new enemy cap, timing or numerical balance frozen',
              encounter_fixture=dict(center=[0, 0], max_radius=1024, min_radius=640, safe_cell_size=64,
                                     status='preview geometry only, final runtime center and shrink timings require C1/C3/C4',
                                     player_teleport=False, forced_walk_to_landmark=False),
              terrain=dict(base=['scorched_01', 'scorched_02', 'scorched_03', 'scorched_04'],
                           localized=['burnt_grass at frost_remnants', 'cracked_lava decorative at muspel_edge'],
                           damage='only runtime hazard geometry; cracked_lava image never implies standing damage'))
dump('layout.json', layout)

gates = [
    dict(id='C1', owner='关卡集成', decision='冻结地图尺寸、Boss活动中心和动态活动范围接口',
         proposal='5120 view / 256 border; dynamic encounter geometry supplied by controller; (0,0), R1024/640 are preview fixtures',
         reason='Game currently spawns every boss 520px around current player; no forced teleport or central arena contract exists'),
    dict(id='C2', owner='动画集成', decision='冻结各状态的动作、时长、关键帧与帧率',
         proposal='idle/move=8fps, attacks=16fps; windup holds last frame until gameplay release',
         reason='Boss._ready currently forces attack to 8fps; new boss adapters must override only their own animations'),
    dict(id='C3', owner='K1/K2战斗集成', decision='蛇身 ribbon 接口、巨口坐标、格莱普尼尔拾取/束缚契约',
         proposal='head neck (0,62), body sockets (0,30)/(64,30); Fenrir mouth 256 square; vector attraction remains procedural',
         reason='non-head body must not join enemy targeting/index/layer2; swallowing escape duration and instant-death API undefined'),
    dict(id='C4', owner='K3战斗集成', decision='苏尔特统一256画布及64格火焰判定契约',
         proposal='all body actions 256 square, source stays 192px at offset(32,64), foot(128,254); arc texture128; phase thresholds .60/.25',
         reason='current SpriteVisual does not implement per-character explicit anchors; generic poison/fire behavior cannot stand in for final mechanics'),
    dict(id='C5', owner='普通怪集成', decision='注册三个第三关敌人并冻结特殊动作触发',
         proposal='fire_giant/frost_veteran/wolf_berserker; special behaviors scoped to these types',
         reason='EnemyDB has no third-level entries; current default enemy actions do not auto-play charge/shield/rage'),
    dict(id='C6', owner='剧情/援助集成', decision='维达、弗雷世界内形象及援助触发接口；一般神明周期援助',
         proposal='new allies directory; runtime gods[odin/freyja].awakened; Thor condition faith and boss combat time<=90s',
         reason='do not conflate Freyja requirement with Freyr faith; other gods nearby/rates unspecified; no forced new eight sets'),
    dict(id='C7', owner='地图集成', decision='采用12角点地块接口和复用地面构成的屏障方案',
         proposal='grass_edge12 plus edge_masks for other soft patches; decorative flame has no damage; horizon outside walk rect',
         reason='MapLayer.border currently assumes eight border textures; custom reused-terrain border rendering needed'),
    dict(id='C8', owner='音频/结算集成', decision='逐事件音效身份、音乐源/乐句长度和结局流程',
         proposal='reuse existing audio where suitable; vigrid.ogg is new; ending text reuses UI and has three fate flags',
         reason='new fate flags/result fields/persistence not present; listening and game playback are separate gates'),
]
dump('decisions.json', gates)

audio_events = []


def sound(event, trigger, task, existing=None, note=''):
    files = []
    if existing:
        for name in existing:
            p = ROOT / 'assets/audio/sfx' / (name + '.wav')
            if p.exists(): files.append(p)
            else: files.extend(sorted((ROOT / 'assets/audio/sfx').glob(name + '_0[123].wav')))
    audio_events.append(dict(event=event, task=task, trigger=trigger, decision='reuse_candidate' if files else 'new_sound_identity_unfrozen',
                             proposed_call_id=None if not existing else existing[0],
                             files=[dict(path=str(p.relative_to(ROOT)), sha256=sha(p)) for p in files],
                             format='WAV PCM16 mono 44100Hz; peak about -1dBFS; short high-frequency variants <=0.3s',
                             subjective_and_runtime_acceptance='pending', note=note,
                             new_file_count=None if not files else 0, new_duration=None))

sound('jormungandr_windup', 'enter poison windup', 'K1', ['boss_windup'])
sound('jormungandr_poison_release', 'poison cone release frame', 'K1', note='poison hiss identity undefined; do not relabel wolf/fire recording')
sound('jormungandr_body_hit', 'body contact accepted by hit cooldown', 'K1', ['boss_slam'])
sound('thor_fate_rescued', 'Thor faith + serpent killed within 90s', 'K1', ['quest_done'])
sound('thor_final_aid', 'saved Thor actual lightning strike in Surtr battle', 'K1', ['lightning'])
sound('fenrir_maw_windup', 'mouth begins attraction warning', 'K2', ['boss_windup'])
sound('fenrir_gulp', 'actual swallow threshold/commit, after escape window', 'K2', note='dedicated low impact/gulp not acquired')
sound('fenrir_charge', 'run contact/cast start, not every frame', 'K2', ['boss_howl'])
sound('gleipnir_pickup', 'fragment actually collected', 'K2', ['chest_open'], 'reuse candidate; identity distinct from XP required')
sound('gleipnir_bind', 'binding activates', 'K2', note='braided magical tension and release identity not fixed')
sound('vidar_arrive', 'Odin faith and awakening; one actual arrival', 'K2', ['awaken'])
sound('vidar_pry', 'jaw release/contact frame', 'K2', ['boss_slam'])
sound('surtr_sword', 'sword damage active frame', 'K3', ['katana_slash'], 'compare weight; if too light, open explicit replacement after listening')
sound('surtr_residual_fire', 'new fire hazard begins', 'K3', ['fire_burn'])
sound('surtr_gate', 'summoning portal opens', 'K3', note='portal identity not fixed')
sound('surtr_phase60', 'cross .60 HP once', 'K3', ['boss_warning'])
sound('surtr_phase25', 'cross .25 HP once', 'K3', ['boss_warning'])
sound('surtr_final_fire', 'unsafe cells ignite together', 'K3', ['boss_slam', 'fire_burn'], 'one event batch, never one voice per cell')
sound('freyr_heal', 'actual granted healing, not each render frame', 'K3', ['heal_pickup'])
sound('fire_giant_explosion', 'one death explosion event', 'K4', ['big_death', 'fire_burn'])
sound('frost_veteran_charge', 'charge begins', 'K4', ['boss_windup'])
sound('frost_veteran_block', 'front shield actually blocks hit', 'K4', ['boss_block'])
sound('wolf_berserker_rage', 'first low-health rage transition', 'K4', ['boss_howl'], 'human battle cry may need replacement; not approved by filename')
sound('battlefield_ambience', 'optional sparse environment layer, off during key warnings', 'K5', note='optional; no always-on fire loop count assumed')
sound('chapter_clear', 'chapter ending begins after all three Boss deaths', 'K7', ['quest_done'])
dump('audio_events.json', dict(status='event_contract_proposal_not_audio_production', events=audio_events,
                               reuse_note='existing candidates are not automatically auditory identity approval; G6 already user accepted is not retested as new production',
                               new_sfx_total=None, reason='规格未定; decide identity, variants and event cadence before any fixed new sound count'))

for row in assets:
    task = row['task']
    rel = row['path']
    if rel.startswith('assets/audio/'):
        target = 'scripts/core/audio.gd:Audio.sfx/music; callers listed in audio_events.json'
        layer = 'Music/SFX bus'
    elif '/ground/' in rel:
        target = 'NEW scripts/world/vigrid_map.gd:_init/_layout; MapLayer.set_ground/_paint_edges'
        layer = 'MapLayer ground, below actors'
    elif '/props/' in rel or '/decals/' in rel:
        target = 'NEW scripts/world/vigrid_map.gd:_layout; MapLayer.prop/decal; custom horizon renderer for distant_battle'
        layer = 'MapLayer dressing; horizon outside walkable bounds'
    elif '/bosses/' in rel and '/effects/' not in rel:
        target = {'K1': 'NEW scripts/bosses/jormungandr.gd:_ready/_update_state; explicit head base path',
                  'K2': 'NEW scripts/bosses/fenrir.gd:_ready/_update_state; swallow action mapping',
                  'K3': 'NEW scripts/bosses/surtr.gd:_ready/_update_state; explicit 256px foot adapter'}[task]
        layer = 'actor; head/feet anchors explicitly adapted'
    elif '/enemies/' in rel:
        target = 'scripts/data/enemy_db.gd + scripts/entities/enemy.gd:_ready/_physics_process/_die; NEW K4 scoped state handlers'
        layer = 'actor'
    elif '/allies/' in rel:
        target = 'NEW scripts/allies/' + ('vidar_aid.gd' if task == 'K2' else 'freyr_aid.gd') + ': visual/phase adapter'
        layer = 'non-targetable world ally'
    elif '/pickups/' in rel:
        target = 'NEW scripts/bosses/fenrir.gd:fragment pickup lifecycle and binding trigger'
        layer = 'pickup, above decals, below warning'
    elif '/characters/' in rel:
        target = 'no production integration; K0 reference only'
        layer = 'reference only'
    else:
        target = {'K1': 'NEW scripts/bosses/jormungandr.gd:poison/contact/aid effect dispatcher',
                  'K2': 'NEW scripts/bosses/fenrir.gd:maw/bind dispatcher',
                  'K3': 'NEW scripts/bosses/surtr.gd:slash/gate/firewall/grid dispatcher',
                  'K4': 'NEW K4 death/shield dispatcher; existing generic FxLayer paths'}[task]
        layer = 'under actors for ground hazards; warnings and safe outlines above visual texture'
    row['integration_target'] = target
    row['draw_layer'] = layer
    row['rotation_contract'] = 'right-facing; rotate abstract directional FX only; mirror body and sockets together'
    row['collision_contract'] = 'texture never defines collider; controller shares geometry with visual clip'
    if row['representation'] == 'existing_file':
        row['runtime_sha256_must_remain'] = row['sha256']
counts = Counter((r['task'], r['representation']) for r in assets)
plan = dict(task='K0', date='2026-10-20', status='planning_delivery_only',
            basis=['docs/Codex美术任务书.md', 'docs/美术后续任务要求.md', 'docs/世界观设定.md', 'docs/美术素材规范.md'],
            final_production_frozen=False, final_production_gate='integration owner fixes C1-C8, then approve per-batch production matrix; no user approval presumed from elapsed time',
            no_duplicate_policy='existing files remain at original paths and hashes; references are not copied into runtime directories',
            assets=assets, non_file_representations=procedural,
            unresolved=dict(new_sfx_files=None, general_god_aid_files=None, ending_illustration_files=None,
                            reason='规格未定; do not count unapproved file sets'),
            counts=[dict(task=t, representation=k, count=n) for (t,k),n in sorted(counts.items())])
dump('asset_plan.json', plan)

lines = ['# K0：维格利德逐文件尺寸清单', '', '> 本表由 asset_plan.json 生成。新增文件为制作提案，尚未生成、未接入；复用文件不重新生产。', '',
         '|任务|处理|路径|单帧|帧数 / fps / 循环|锚点|依赖|', '|---|---|---|---|---|---|---|']
for r in assets:
    dim = '音频' if r['frame_size'] is None else '×'.join(map(str,r['frame_size']))
    lines.append('|%s|%s|`%s`|%s|%s / %s / %s|%s|%s|' % (r['task'], '复用' if r['representation']=='existing_file' else '新增提案',
                 r['path'], dim, r.get('frames'), r.get('fps'), r.get('loop','依原用途'), r['anchor_px'], ', '.join(r.get('integration_dependencies',[]))))
write('asset_matrix.md', '\n'.join(lines))

write('layout.md', '''
# K0：第三关「最后之战」布局提案

状态：前置设计交付，不是可玩地图，不是游戏截图。地图最终数值需关卡集成冻结 C1；坐标机器源见 layout.json，带坐标图见 previews/layout.svg 与 previews/layout.png。

## 世界观与范围

按世界观第三关：维格利德平原、崩塌彩虹桥、神与巨人的战争残骸；03:00 耶梦加得、06:00 芬里尔、09:00 苏尔特，前一 Boss 未败则下一 Boss 顺延。十分钟不强制结束。无新增地标支线、桥梁关卡、搬运任务、门钥匙或强制移动剧情。

命运条件逐字含义保留：信仰托尔且在耶梦加得战开始后90秒内击败它；信仰奥丁且奥丁觉醒触发维达援助；信仰弗蕾亚且弗蕾亚觉醒触发弗雷持续治疗。最后一条不是「信仰弗雷」。具体条件采样时点、一次性触发与存储需 C6 冻结。

## 尺寸与坐标

- 世界原点 (0,0) 是出生点，x右/y下。地块64px，按 floor(world/64) 取格；不可使用朝零取整处理负坐标。
- 镜头可见地图：(-2560,-2560) 到 (2560,2560)，5120×5120，80×80格。
- 可行走区域：(-2304,-2304) 到 (2304,2304)，4608×4608，72×72格；四周屏障256px，尺寸为提案。
- 出生384px内无实体碰撞；中央1280px半径内不放固定障碍。普通怪与Boss仍可进入。
- 五条辐射通道和五条地标环路，预留净宽256px。通道以现有焦土变化铺设，不为「道路」另造整套地块。
- 地标只是视觉布局与密度参考，均不带 quest/hidden 字段；没有自动剧情奖励。

|地标|中心|布局半径|相对普通怪密度|用途|
|---|---|---|---|---|
|中央燃烧平原|(0,0)|1088|中|三场战斗共同的开阔视觉参考，不把 Boss 锁在这里|
|崩塌彩虹桥残端|(-1536,-1408)|384|低|复用桥碎片、断兵；不是必须经过的独木桥|
|诸神与巨人残骸带|(1536,-1280)|384|中|复用巨人残骸、盾牌；不画死去的特定神明|
|霜巨人残部|(-1536,1024)|384|中|焦草和巨型脚痕，区分寒色巨人残军|
|穆斯贝尔前线|(1536,1280)|448|高|局部裂地和燃烧废墟；装饰火不自动造成伤害|
|亡者残余行军带|(0,1792)|256|高|复用亡者、兵器、拖痕，保留横向绕行空间|

密度高/中/低是美术留白和刷怪方向建议，不是已批准的数量或波次。本轮不填新增敌人数值、奖励倍率、刷怪权重或支线数量；运行上限沿用集成方的实测预算。

## Boss活动范围和视野

图上原点的R1024外圈/R640内圈仅用于纹理容量、收缩与蛇身曲率的设计样例，不是新增固定竞技场。当前Game把Boss刷在玩家周围520px，不能把这张图当作已经存在的原点战斗规则。实际场地中心、最大/最小活动半径、靠边裁切和玩家逃脱路径需由控制器统一提供；不得瞬移玩家或强制赶到地标。

耶梦加得身体按弧长UV带驱动，头/身体/尾使用原图，只有头可受击。分节数由实际长度/64和接缝重叠决定，不预渲染一整条蛇。蛇身可撞击范围取同一条路径及厚度，不能由贴图外接框随意扩大；内部安全区不铺装饰火。

芬里尔身体192×192保持原尺度；天地巨口单独256×256稀疏上下颚覆盖层，吸引和致死区域继续用几何/控制器表现。预览的吸引圈不是已经确定的伤害半径；实际逃脱时间、中心吸引规则与张口轴心需 C3。

苏尔特新动作提议统一256×256，原192×192人物按1倍放在(32,64)，脚锚(128,254)。多出的透明区给横向巨剑和插剑动作，不把Boss身体放大。所有动作统一画布以免动作切换跳脚；旧静态图不覆盖，回退时对齐旧锚(96,190)。这是C4待集成确认的规格，不能直接交给现有默认枢轴后声称已正确播放。

炎剑范围和火墙由动态几何裁切；终焉之火采用64px安全格提案。安全格集合、预警边框、火焰单元和判伤必须引用同一份格坐标。不能用完整圆火墙或全屏火焰覆盖安全格。

## 地块、边界和装饰

复用6张现有地块：四张焦土为大底，焦草局部斑块，裂地作为前线装饰。新增12张grass_edge对应当前MapLayer.EDGE_TILES四边、四外角、四内角。其他斑块优先借这套alpha轮廓生成运行时过渡，不为同一轮廓复制第二套文件。

屏障选择替代方案：在不可走的256px带复铺现有焦土，混入复用残骸、低对比远景和火墙短带，再叠程序灰雾。为此需要新的地图绘制适配，不能直接调用要求8张边界纹理的MapLayer.border并接受紫色占位。没有因为borders/vigrid目录不存在而强造8张图。

北侧远景矩形(-768,-2480,1536,128)，完全在可走区域外；512×128的四帧小剪影画三段，用于泛化神/巨人交战，不演出特定神明死亡。程序援助与背景剪影解耦，不能把「看见远景」直接视为命运条件。

已有五件物件以1倍重复组合，不新增大型桥建筑或神尸。样例摆位见layout.json；实体碰撞最大20px，小盾与断兵无碰撞。最终散布必须避开出生区、通道、当场Boss安全空间；固定物件不参与危害判定。

## 局限与自检

本轮验证了文件/哈希、尺寸、静态布局几何连通、边界和预览，不运行游戏、不验证真实碰撞/战斗帧率/吞噬逃脱/火墙判伤。蛇身直连接缝可逐像素检查；转弯只是几何预览，必须后续Godot纹理带实测。四倍和4×4预览是检查材料，不等于所有新素材已制作。
''')

write('integration.md', '''
# K0：第三关代码接入交接

本轮只写assets规划文件和LICENSES追加。以下路径中「新增」均为建议，不代表文件存在；代码实施属于关卡集成。逐文件路径/尺寸/播放/锚点/参考图以asset_plan.json与asset_matrix.md为唯一矩阵，触发/音频见audio_events.json。现有接口索引含行号和输入快照，见records/code_interfaces.json及records/input_snapshot.json。

## 当前代码事实

1. scripts/data/level_db.gd 的ORDER含vigrid，ALL只有midgard/helheim；is_built(vigrid)为false。BossDB.create只登记前两关六个Boss。EnemyDB.ALL没有fire_giant/frost_veteran/wolf_berserker。
2. Game._ready从map.size计算view_bounds，再grow(-border)得bounds，清理MapLayer.obstacles，再实例化map.layout。VigridMap需遵循这套生命周期。
3. Game._update_bosses按既定时间顺延，Boss由_point_around(player,520)生成。当前没有Boss专用活动区API，也没有第三关的围场、吞噬、命运控制器。地图示例中心不得直接替换这套行为。
4. Enemy._ready注册enemies组、空间索引和collision_layer=2，projectile只检测mask=2。蛇身/尾/远景/援助人物不能继承并保留这套敌人注册，否则会被自动武器瞄准/受伤。
5. SpriteVisual.create_actions按单帧高度切正方形横条。非方形效果必须走draw_frame/自有元数据。其默认枢轴按纹理高度推导，不能读取本方案anchor_px。显式锚点适配需由新Boss/盟友视图完成。
6. Boss.BOSS_ACTIONS现无swallow/plant；state_actions需新增对应映射。Boss._ready会把attack设成8fps，与本K提案16fps不同；只给新Boss定好速度，不能顺手改变前两关六个Boss。
7. BossFx元数据只有H的登记；新增贴图不能因文件名存在就自动播放。PoisonPool._inside固定椭圆与半径，不能复制到耶梦加得后声称覆盖大片毒雾的判定正确。
8. player.faith及player.gods[id].awakened可读；当前Game._finish_run返回elapsed/kills等，没有改写命运统计；_begin_ending会暂停SceneTree。新结局若用定时动画需明确PROCESS_MODE_ALWAYS并允许跳过。

## 需要新增/修改的接入点

|范围|目标|工作与约束|
|---|---|---|
|关卡注册|scripts/data/level_db.gd|新增NORSE_3并登记ALL.vigrid；配置music=vigrid、map.layout、waves/elite/events/bosses。Boss时间180/360/540沿用世界观，其余平衡字段由集成定稿。未设计的quests/hidden_quests保持空，不复用其他关任务填空|
|地图|新增scripts/world/vigrid_map.gd，继承MapLayer|按layout.json落地；ground_dir/props_dir指向vigrid；decals直接引用已有helheim中性痕迹或独立加载，禁止复制成新素材。自定义边界替代MapLayer.border缺图占位；动态活动区与装饰分层|
|Boss工厂|scripts/data/boss_db.gd|新增jormungandr/fenrir/surtr分支；所有需要的脚本齐全后才启用关卡|
|耶梦加得|新增scripts/bosses/jormungandr.gd及分节视图/危害组件|type_id=jormungandr，sprite_name=jormungandr_head；idle/windup/attack映射；移动由环绕路径驱动，不新增move帧条。头颈socket(0,62)对齐body(0,30)/(64,30)。主体只做一个可受伤Boss；身体用轻量路径碰撞，不进enemies索引/第2层；头部受击提示与身体接触击退区分别标识|
|蛇身绘制|建议新增scripts/effects/serpent_ribbon.gd|已有64pxbody沿弧长连续UV映射，头尾在切线方向接合；不能独立刚性旋转十几张矩形后忽略楔形空隙。路径、内侧边界、宽度需同时供绘制和接触查询；最近邻采样与遮罩检查|
|毒雾|新增可参数化危害组件或扩展专属组件|复用既有nidhogg_poison_breath/poison_pool图，按新权威cone/polygon裁切；毒雾范围/持续时间/伤害tick均由K1控制器，不能直接继承固定半径毒池。绘制在玩家之下，边界标记在纹理之上|
|芬里尔|新增scripts/bosses/fenrir.gd|idle/move/windup/attack/swallow；巨口256特效显式元数据，吸引与致死中心由同一几何数据供给；逃脱时长未定。碎片作为拾取物单独登记，绑定状态有开始/结束/增伤接口；不得增加EnemyDB锁桩冒充捡链|
|苏尔特|新增scripts/bosses/surtr.gd及火场组件|统一256动作，显式foot(128,254)，回退192静态foot(96,190)。attack/plant/summon分别切动作；60%/25%阶段只触发一次。剑扇区/火墙圆带/终焉格分别输出几何，贴图裁切不扩大实际伤害。特效四帧衰减与判伤窗口解耦|
|敌人|scripts/data/enemy_db.gd、scripts/entities/enemy.gd或专属行为组件|注册fire_giant/frost_veteran/wolf_berserker；fire death仅一次爆炸及余火；frost charge/shield与可绕背方向；berserker低血狂暴一次触发。普通move8/attack16，特殊状态显式加载；行为只限这些类型，不影响旧敌人|
|盟友|新增scripts/allies/vidar_aid.gd、freyr_aid.gd（路径建议）|非Enemy，不进敌人组/受伤层；世界内小像素人物，不把720×1200卡面缩小。维达96脚锚(48,94)，弗雷64脚锚(32,62)。维达与狼颚接触由事件提供坐标；弗雷治疗实际生效后再出光和声音，不能重复玩家已有Freyr神术计时器|
|命运与援助|新增scripts/world/vigrid_encounter.gd或局内专属控制器|每局保存thor_saved/vidar_intervened/freyr_assisted三标志；战斗计时从Jormungandr实际登场起，按暂停/结算门控；信仰判定读player.faith，觉醒读player.gods[id].awakened。数据最终字段名为提议，尚未加入保存|
|音频|scripts/core/audio.gd调用点、level.music|当前Audio已有24声部、同名50ms最短间隔及4同名上限。按事件播放，终焉格不能一格一声；零散怪死亡火焰须有场景级预算。复用已有入口不重做G6；新vigrid.ogg应在启动前有文件，当前缺曲会淡出旧曲，不是自动音乐回退|
|结局/结果|Game._on_boss_defeated/_finish_run/_on_level_cleared、HUD结果视图、Save.record_run|第三Boss败后五段文字演出，再结算现有存活/击杀及新增命运数；不要发明奖励公式。Loki彩蛋取「本关曾信仰过」事件记录，不能只在结算查当前技能节点。存档需可选字段兼容旧档；双次killed/defeated/跳过不重复发奖励|

## 状态/动作提议

|角色|状态→动作|单次动作关键帧提议|时序所有权|
|---|---|---|---|
|蛇头|环绕→idle；poison_windup→windup；喷吐→attack|attack第1帧开口，第2帧释放；结束回idle|喷吐判伤由控制器释放事件，不由动画finished猜测|
|芬里尔|chase→move；maw_windup→windup；swallow→swallow；charge→move；recover→idle|吞噬第2帧张颚，第3帧保持；逃脱阶段和关闭阶段需显式相位|巨口循环层与吞噬身体单次层分离；hold/release不硬挤进四帧|
|苏尔特|chase→move；slash_windup→windup；sweep→attack；plant→plant；summon→summon|挥剑第2帧接触；插剑第2帧触地；召唤第2帧开门|状态时长和伤害窗口不因16fps图条长度改变；动画末帧可保持|
|霜巨人精锐|chase→move；charge→charge；shield→shield；attack→attack|举盾第2帧到位并保持|后方免疫/伤害判定由朝向和代码，不由盾牌alpha|
|狂狼战士|move/attack；低血进入rage单次后恢复move|rage第1帧抬肩，第2帧咆哮|阈值与速度倍率未定，不在图稿中假定|

关键帧是待C2冻结的契约提案，未修改玩法。回退时使用现有静态图/清楚的程序预警，不用缺图静默掩盖危险。

## 绘制、坐标、遮罩

- 世界实体为脚底锚点；根位置和脚底之间的MapLayer.FOOT=20偏移应统一。地图prop使用画布底中点，贴花用中心；蛇/效果使用元数据socket，不套脚底。
- 实体1倍、最近邻；镜像必须同时镜像锚点和喷口。非正方形特效使用draw_frame，不能用默认正方形自动切条。
- 地面/贴花 < 危害薄纹理 < 角色/身体 < 清楚的预警/安全线 < HUD。巨口和火墙中心透明，不能盖掉玩家位置。
- 共用一份arena_center/radius、cone_angle、cell_set给判伤与绘制；外侧纹理超出区域必须裁切。装饰火标damage=false，素材本身不产生碰撞。
- 所有循环、音效、纹理缓存与辅助节点在Boss败亡/场景退出时有明确清理；身体段不按视觉段数新增Enemy节点。复用H/J集中绘制思路，但不假定现有硬编码元数据已经兼容K。

## 运行验收（全部未测）

- 三Boss全技能与全部阶段；每个命运条件的满足/不满足/边界90秒/暂停/重复事件路径。
- 蛇头唯一可受击、身体不会被自动瞄准，缩圈后仍有内部安全空间；蛇身在实际最小半径最近邻采样下无洞/接缝/反向鳞片。
- 巨口警告、逃脱、吞噬和绑定期可读；链片不与残骸混淆；维达真正对上上下颚。
- 苏尔特剑不裁边、不跳脚；60%/25%转阶段、火墙收缩、符文安全格与判伤一致；受火焰叠加后玩家可见。
- 普通怪特殊状态，死亡爆炸只一次，暂停/大招冻结/退出时无残留伤害。
- 地图80×80铺设、边界不可越、负坐标、所有通道连通、350怪负载及前台帧率；不能借用J隔离副本长测结论。
- 音频实际触发和混音、音乐连续三遍无缝；结局只结算一次、旧存档兼容、导出包资源路径齐全。
''')

write('story_and_ending.md', '''
# K7：改写命运与结局制作方案

来源：docs/世界观设定.md「第3关：最后之战」。本轮不添加支线或改变预言条件。

|事件|条件|表现资产归属|局内记录提议|
|---|---|---|---|
|托尔免于中毒|信仰托尔且实际开战后90秒内击败耶梦加得|K1已有LightningFx/雷云/战锤符号；后续苏尔特战雷击援助|thor_saved；不得以level_elapsed<=90替代|
|维达撕开巨口|信仰奥丁且奥丁觉醒；战斗中出现|K2新增世界内维达及撕颚动作；狼颚接触点统一|vidar_intervened；是否必须击败芬里尔才计命运由剧情集成冻结|
|弗雷参战治疗|信仰弗蕾亚且弗蕾亚觉醒|K3新增世界内弗雷与治疗动作；复用freyr_field，不新增第二套援助贴图|freyr_assisted；不是要求信仰弗雷|

一般周期援助与上述命运援助不是同一条件：世界观只明确「信仰的神在附近交战」和托尔额外落雷示例。其他七神的附近判据、间隔与效果未定义；先保留规格未定，不产生七套新人物/音效配额。

推荐结局：沿用现有文字叙述及结果UI，五段可跳过的短字幕，不新增独立插画。段落为：火焰熄灭/九界灰烬与海水 → 新大地升起 → 巴德尔归来 → 树干中的利弗与利弗特拉西尔走出 → 篇章完成与回主神空间。需要人物插画或场景动画时另定，当前没有隐含生产数量。

巴德尔现有卡面只可作为叙述UI可选肖像，不能变成世界内人物。结算显示存活时间、击杀和改写命运数；不擅自制定新奖励公式。曾信仰洛基时保留原文：「谢谢你，轮回者。锁链断了，我也该去看看别的世界了。」需记录曾信仰事件，不只检查结算瞬间现有节点。

状态：仅方案。三种命运、结束字幕、统计字段和存档接入都未实现、未测。辅助人物文件仅计在K2/K3，不重复计入K7。
''')


def font(size=15):
    return ImageFont.truetype('/System/Library/Fonts/Menlo.ttc', size)


def label(d, xy, s, size=15, fill='#dce5e9'):
    d.text(xy, s, font=font(size), fill=fill)


def tile_bg(size, name='scorched_01'):
    im = Image.new('RGB', size, '#121721')
    tex = Image.open(ROOT / SPR / 'ground/vigrid' / (name + '.png')).convert('RGBA')
    for y in range(0, size[1], 64):
        for x in range(0, size[0], 64): im.paste(tex, (x,y), tex)
    return im


def paste_asset(bg, rel, pos, factor=1, foot=False):
    im = Image.open(ROOT / SPR / rel).convert('RGBA')
    if factor != 1: im = im.resize((im.width * factor, im.height * factor), Image.Resampling.NEAREST)
    x, y = pos
    if foot: x -= im.width // 2; y -= im.height
    bg.paste(im, (int(x),int(y)), im)


# Scale comparison contains existing pixels only. Captions occupy separate bands.
scale = tile_bg((1400, 530))
sd = ImageDraw.Draw(scale)
sd.rectangle((0,0,1400,60), fill='#121721')
label(sd,(20,12),'K0 / EXISTING ART AT 1x - planning composite, not Godot',20)
sd.line((20,312,1380,312), fill='#8ad4bf', width=1)
subjects=[('bosses/jormungandr_head.png',100,'Head 128'),('bosses/fenrir.png',300,'Fenrir 192'),
          ('bosses/surtr.png',530,'Surtr 192'),('enemies/fire_giant.png',740,'Fire 96'),
          ('enemies/frost_veteran.png',890,'Frost 96')]
for rel,x,title in subjects:
    paste_asset(scale,rel,(x,312),foot=True)
    label(sd,(x-68,336),title,14)
for i,name in enumerate(['swordsman','gunslinger','assassin','mage']):
    x=1030+(i%2)*150;y=200+(i//2)*112
    paste_asset(scale,'characters/'+name+'.png',(x,y),foot=True)
    label(sd,(x-48,y+6),name,12)
sd.rectangle((0,390,1400,530),fill='#121721')
label(sd,(20,410),'Displayed art bbox: head 120x100; wolf 185x187; Surtr 167x184; giants about 90x92.',15)
label(sd,(20,445),'Bodies keep 1x pixels. Larger action canvas adds transparent room, not larger anatomy.',15)
label(sd,(20,480),'Four player references are 64px canvases. Feet line is a preview alignment, not runtime acceptance.',14)
scale.save(BASE/'previews/style_scale_1x.png')
scale.resize((2800,1060),Image.Resampling.NEAREST).save(BASE/'previews/style_scale_2x.png')
scale.resize((5600,2120),Image.Resampling.NEAREST).save(BASE/'previews/style_scale_4x.png')

# Validate the original interface rows and show rigid vs warped-body curve proposals.
headim=Image.open(ROOT/SPR/'bosses/jormungandr_head.png').convert('RGBA')
bodyim=Image.open(ROOT/SPR/'bosses/jormungandr_body.png').convert('RGBA')
tailim=Image.open(ROOT/SPR/'bosses/jormungandr_tail.png').convert('RGBA')
ports=dict(body_left_right_equal=bodyim.crop((0,0,1,64)).tobytes()==bodyim.crop((63,0,64,64)).tobytes(),
           body_tail_equal=bodyim.crop((0,14,1,46)).tobytes()==tailim.crop((63,14,64,46)).tobytes(),
           body_head_equal=bodyim.crop((63,14,64,46)).tobytes()==headim.crop((0,46,1,78)).tobytes(),
           body_sockets=[[0,30],[64,30]],head_neck=[0,62],tail_socket=[64,30],
           curve_status='preview_only; curved ribbon needs runtime implementation/inspection')
dump('records/snake_ports.json',ports)
joint=Image.new('RGB',(1280,760),'#121721');jd=ImageDraw.Draw(joint)
label(jd,(20,12),'SERPENT / unchanged textures + socket/curve study',20)
label(jd,(20,48),'Straight sockets: exact RGBA row checks. Curve pictures are texture reprojections, not new art.',13)
joint.paste(tailim,(24,110),tailim)
for i in range(7):joint.paste(bodyim,(88+64*i,110),bodyim)
joint.paste(headim,(536,78),headim)
label(jd,(700,120),'Body ports (0,30) / (64,30)',15)
label(jd,(700,150),'Head neck (0,62); tail (64,30)',15)
label(jd,(700,180),'Open connector edges are intentional.',15)
for panel,rigid in enumerate([True,False]):
    x0=30+panel*630;cx=x0+285;cy=500;r=180
    label(jd,(x0,265),'Rigid rectangles / gaps possible' if rigid else 'Arc-length ribbon / candidate',16)
    if rigid:
        for i in range(8):
            angle=-math.pi+0.5+(i+0.5)*64/r
            deg=-math.degrees(angle+math.pi/2)
            rotated=bodyim.rotate(deg,resample=Image.Resampling.NEAREST,expand=True)
            x=int(cx+r*math.cos(angle)-rotated.width/2);y=int(cy+r*math.sin(angle)-rotated.height/2)
            joint.paste(rotated,(x,y),rotated)
    else:
        pix=joint.load();bp=bodyim.load()
        for yy in range(cy-r-40,cy+r+40):
            for xx in range(cx-r-40,cx+r+40):
                dx=xx-cx;dy=yy-cy;rho=math.hypot(dx,dy);angle=math.atan2(dy,dx)
                t=angle-(-math.pi+0.5)
                if t<0:t+=2*math.pi
                u=t*r
                v=int(round(30+(r-rho)))
                if 0<=u<512 and 0<=v<64:
                    c=bp[int(u)%64,v]
                    if c[3]:pix[xx,yy]=c[:3]
    jd.ellipse((cx-r-1,cy-r-1,cx+r+1,cy+r+1),outline='#365364',width=1)
label(jd,(20,696),'Stress radius 180px is intentionally tighter than proposed R640; not a final boss arena.',14)
label(jd,(20,725),'Must test head/tail orientation, UV rhythm and collision thickness in Godot before K1 acceptance.',13)
joint.save(BASE/'previews/snake_connections.png')
joint.resize((2560,1520),Image.Resampling.NEAREST).save(BASE/'previews/snake_connections_2x.png')

# Empty canvas envelopes explicitly keep existing art at its own scale.
envelopes=Image.new('RGB',(1280,540),'#121721');ed=ImageDraw.Draw(envelopes)
label(ed,(20,12),'CANVAS CONTRACT STUDY / outlines are planned space, not generated actions',18)
for x,title in [(60,'FENRIR / 192 body + 256 jaw layer'),(700,'SURTR / 256 action canvas, 192 body')]:
    label(ed,(x,65),title,14)
    ed.rectangle((x,100,x+256,356),outline='#7aaabd',width=1)
    if x==60:
        paste_asset(envelopes,'bosses/fenrir.png',(x+32,164))
        ed.rectangle((x+32,164,x+224,356),outline='#495d6c',width=1)
        label(ed,(x,382),'Jaw pivot [128,128] proposed',14)
        label(ed,(x,410),'Fatal/attraction radii: not frozen',13)
    else:
        paste_asset(envelopes,'bosses/surtr.png',(x+32,164))
        ed.rectangle((x+32,164,x+224,356),outline='#495d6c',width=1)
        ed.ellipse((x+124,350,x+132,358),fill='#a9dfb4')
        ed.line((x+2,354,x+254,354),fill='#739f8d')
        label(ed,(x,382),'Foot [128,254]; reference at [32,64]',14)
        label(ed,(x,410),'Sword extremes must stay inside 2px margin',13)
label(ed,(20,480),'Visible weapon extremes: production must validate all poses; these blank envelopes alone do not prove fit.',14)
envelopes.save(BASE/'previews/action_envelopes.png')

tiles=Image.new('RGB',(3*296,2*318),'#121721');td=ImageDraw.Draw(tiles)
names=['scorched_01','scorched_02','scorched_03','scorched_04','cracked_lava','burnt_grass']
for i,name in enumerate(names):
    x=(i%3)*296+20;y=(i//3)*318+20
    tiles.paste(tile_bg((256,256),name),(x,y))
    label(td,(x,y+264),name+' / 4x4',13)
tiles.save(BASE/'previews/terrain_4x4.png')

# Layout SVG is a diagram; the PNG uses the same coordinates, with English diagram labels.
mx,my,extent=70,100,960
s=extent/5120


def pt(p):return (mx+(p[0]+2560)*s,my+(p[1]+2560)*s)


svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1460" height="1160" viewBox="0 0 1460 1160">',
     '<rect width="1460" height="1160" fill="#101720"/>',
     '<style>text{font-family:system-ui,sans-serif;fill:#d7e4ea;font-size:16px}.small{font-size:13px}.muted{fill:#9eafba}</style>',
     '<text x="40" y="40" font-size="25">K0 · 维格利德布局提案 / 5120 × 5120</text>',
     '<text x="40" y="70" class="small">世界原点出生 · x向右 / y向下 · 64px地块 · 坐标与尺寸仅为设计提案，非游戏截图</text>',
     f'<rect x="{mx}" y="{my}" width="{extent}" height="{extent}" fill="#463b35" stroke="#9b795c"/>']
for v in range(-2560,2561,512):
    x,y=pt([v,v]);svg.extend([f'<path d="M{x},{my}V{my+extent}" stroke="#736453" opacity=".25"/>',f'<path d="M{mx},{y}H{mx+extent}" stroke="#736453" opacity=".25"/>',f'<text x="{x-15}" y="{my+extent+25}" class="small">{v}</text>',f'<text x="12" y="{y+5}" class="small">{v}</text>'])
wx,wy=pt([-2304,-2304]);ww=4608*s
svg.append(f'<rect x="{wx}" y="{wy}" width="{ww}" height="{ww}" fill="#292b2c" stroke="#e3c099" stroke-width="2"/>')
for a,b in routes:
    x,y=pt(a);xx,yy=pt(b);svg.append(f'<path d="M{x},{y}L{xx},{yy}" stroke="#6e6556" stroke-width="{256*s}" opacity=".35"/>')
colors=['#5d8b91','#9ba4b4','#b29d7b','#89b6bc','#d98b5f','#aa9e86']
for i,lm in enumerate(landmarks):
    x,y=pt(lm['pos']);rr=lm['radius']*s
    svg.append(f'<circle cx="{x}" cy="{y}" r="{rr}" fill="{colors[i]}" fill-opacity=".12" stroke="{colors[i]}"/>')
    svg.append(f'<text x="{x}" y="{y-7}" text-anchor="middle">{i} {lm["name"]}</text>')
    svg.append(f'<text x="{x}" y="{y+16}" text-anchor="middle" class="small">{lm["pos"]} · R{lm["radius"]}</text>')
x,y=pt([0,0])
for r in [640,1024]:svg.append(f'<circle cx="{x}" cy="{y}" r="{r*s}" fill="none" stroke="#c99b62" stroke-dasharray="7 5"/>')
svg.append(f'<circle cx="{x}" cy="{y}" r="{384*s}" fill="none" stroke="#b4e4cc"/>')
hx,hy=pt([-768,-2480]);svg.append(f'<rect x="{hx}" y="{hy}" width="{1536*s}" height="{128*s}" fill="#566c7c"/><text x="{hx+6}" y="{hy+17}" class="small">北侧交战远景 · 不可走</text>')
notes=['01 地图可见边长5120 / 80格','02 行走边长4608 / 72格','03 四周屏障256 / 4格','04 出生留空R384','05 中央R1280无固定障碍','06 通道预留256净宽','07 Boss虚线圈仅是预览样例','   R1024 → R640，未冻结','08 三战活动区需控制器提供','09 远景和装饰火不造成伤害','10 03:00 / 06:00 / 09:00','11 旧Boss存活则下一场顺延','12 地标不添加支线任务','13 现有6地块 / 5物件复用']
for i,t in enumerate(notes):svg.append(f'<text x="1070" y="{140+i*39}" class="small">{t}</text>')
svg.append('<text x="40" y="1140" class="small muted">K0规划已交付 ≠ K1–K7素材制作完成 ≠ 第三关可玩或游戏验收通过</text></svg>')
write('previews/layout.svg','\n'.join(svg))
mp=Image.new('RGB',(1460,1160),'#101720');md=ImageDraw.Draw(mp)
label(md,(40,25),'K0 / VIGRID LAYOUT PROPOSAL / 5120 x 5120',24)
label(md,(40,64),'World pixels; origin spawn; +x east / +y south. Planning diagram, not a game capture.',15)
md.rectangle((mx,my,mx+extent,my+extent),fill='#463b35',outline='#9b795c',width=2)
md.rectangle((wx,wy,wx+ww,wy+ww),fill='#292b2c',outline='#e3c099',width=2)
for v in range(-2560,2561,512):
    xx,yy=pt([v,v]);md.line((xx,my,xx,my+extent),fill='#3c3d3b');md.line((mx,yy,mx+extent,yy),fill='#3c3d3b')
    label(md,(xx-18,my+extent+8),str(v),12);label(md,(4,yy-6),str(v),12)
for a,b in routes:md.line((*pt(a),*pt(b)),fill='#605b50',width=round(256*s))
eng=['Open battlefield','Bifrost remains','Giant remains','Frost remnants','Muspel front','Dead march']
for i,lm in enumerate(landmarks):
    x,y=pt(lm['pos']);r=lm['radius']*s
    md.ellipse((x-r,y-r,x+r,y+r),outline=colors[i],width=2)
    label(md,(x-75,y-12),str(i)+' '+eng[i],14)
    label(md,(x-75,y+12),str(lm['pos'])+' R'+str(lm['radius']),11)
for r in [640,1024]:md.ellipse((pt([0,0])[0]-r*s,pt([0,0])[1]-r*s,pt([0,0])[0]+r*s,pt([0,0])[1]+r*s),outline='#c99b62',width=1)
for i,t in enumerate(['View: 5120 / 80 cells','Walk: 4608 / 72 cells','Border: 256 / 4 cells','Spawn clear: R384','No fixed props: R1280','Paths: 256px reserved','Boss rings: fixture only','R1024 -> R640 proposed','No teleport / quest added','Reuse 6 tiles + 5 props','03:00 / 06:00 / 09:00','Next boss waits if alive','Runtime geometry: unfrozen']):label(md,(1060,140+i*40),t,14)
md.rectangle((hx,hy,hx+1536*s,hy+128*s),fill='#566c7c')
for item in props:
    px,py=pt(item['pos'])
    md.ellipse((px-3,py-3,px+3,py+3),fill='#d6c1a0')
label(md,(40,1125),'No third-level code, collision or playable scene is delivered by this plan.',16)
mp.save(BASE/'previews/layout.png')

# A deterministic static clearance check verifies only this proposed layout.
step=64;lo=-2304;hi=2304
cells=[(x,y) for x in range(72) for y in range(72)]
obstacles=[p for p in props if p['block_radius']]
blocked=set()
for x,y in cells:
    px=lo+(x+.5)*step;py=lo+(y+.5)*step
    if any(math.hypot(px-p['pos'][0],py-(p['pos'][1]-p['block_radius']*.5))<p['block_radius']+14+step*.71 for p in obstacles):blocked.add((x,y))
start=(36,36);seen={start};q=deque([start])
while q:
    x,y=q.popleft()
    for nxt in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
        if 0<=nxt[0]<72 and 0<=nxt[1]<72 and nxt not in seen and nxt not in blocked:seen.add(nxt);q.append(nxt)
connected={lm['id']:(int((lm['pos'][0]-lo)//64),int((lm['pos'][1]-lo)//64)) in seen for lm in landmarks}


def segment_distance(p, a, b):
    dx,dy=b[0]-a[0],b[1]-a[1]
    t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy)))
    return math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dy)


clearances=[dict(path=p['asset'],pos=p['pos'],clearance_px=min(segment_distance([p['pos'][0],p['pos'][1]-p['block_radius']*.5],a,b)-p['block_radius'] for a,b in routes)) for p in obstacles]
dump('records/layout_geometry_check.json',dict(status='static_layout_check_only',grid=[72,72],blocked_cells=len(blocked),
     reachable_cells=len(seen),all_unblocked_reachable=len(seen)==72*72-len(blocked),landmarks_reachable=connected,
     spawn_clear=all(math.hypot(*p['pos'])-p['block_radius']>=384 for p in obstacles),
     central_reserve_clear=all(math.hypot(*p['pos'])-p['block_radius']>=1280 for p in obstacles),
     horizon_outside_walk=layout['horizon_rect'][1]+layout['horizon_rect'][3]<-2304,
     corridor_clearances=clearances,corridors_allow_256px_plus_player_radius=all(p['clearance_px']>=128+14 for p in clearances),
     runtime_collision='not_tested',foot_offset_note='circle center follows MapLayer.prop pos+(0,-radius/2); player radius14 inflation included'))

# Associate all reused files with original manifests; do not count downstream reference copies as provenance authorship.
targets={r['sha256']:r['path'] for r in assets if r['representation']=='existing_file'}
for r in assets:
    for path in r.get('reference_paths',[]):
        p=ROOT/path
        if p.is_file():targets[sha(p)]=path
provenance={p:[] for p in targets.values()}
for p in (ROOT/'assets/source').rglob('manifest.json'):
    if BASE in p.parents:continue
    try:data=json.loads(p.read_text())
    except (ValueError,UnicodeError):continue
    def visit(v):
        if isinstance(v,dict):
            h=v.get('sha256')
            if isinstance(h,str) and h in targets:
                provenance[targets[h]].append(dict(manifest=str(p.relative_to(ROOT)),record=v))
            for sub in v.values():visit(sub)
        elif isinstance(v,list):
            for sub in v:visit(sub)
    visit(data)
dump('records/reuse_provenance.json',provenance)

newrows=[r for r in assets if r['representation']=='planned_file']
reuse_rows=[r for r in assets if r['representation']=='existing_file']
count=Counter(r['task'] for r in newrows)
write('README.md',f'''
# K0：第三关「最后之战」前置方案

2026-10-20。已阅读当前任务书、后续K要求、完整世界观、美术规范，核查现有加载器、关卡/Boss/敌人登记、地图、音频和结算接口。仅写本目录与assets/LICENSES.md追加，未覆盖正式素材、未修改代码/场景/docs/项目设置，未提交或推送。

本轮交付K0，并覆盖K1～K7的逐项生产/接入规划；没有生成新的最终角色、动作、地图纹理或音频。新增{len(newrows)}个文件是尺寸/用途提案，不是完成数量；其中PNG {sum(r['path'].endswith('.png') for r in newrows)}个，OGG {sum(r['path'].endswith('.ogg') for r in newrows)}个。另有{len(reuse_rows)}个逐项复用/参考文件，保持原路径和哈希。音效、一般神明援助及结局插画未定义的数量不计入提案总数。

- layout.md / layout.json：坐标布局、活动空间、地标、密度建议、边界与碰撞留白。
- asset_plan.json / asset_matrix.md：逐文件尺寸、帧数、帧率、锚点、alpha、参考、复用/新增、依赖。
- integration.md：现有代码事实、新接口建议、状态/动作、遮罩、命运条件及运行验收表。
- decisions.json：C1～C8需集成冻结的具体契约；不是要求用户逐条补设计。
- audio_events.json：25个事件触发提案，现有声音候选和未定身份；不等于25条新增音效。
- story_and_ending.md：三种命运与五段文字结局，不重复计K1～K3援助人物。
- gallery.html：本地规划图库；previews有坐标SVG/PNG、尺度、接缝、画布包络与4×4地块预览。
- records：输入哈希、原批次来源匹配、工具许可、静态检查、代码接口行号。

## 制作顺序

K0 → 集成方冻结C1～C8 → K1/K2/K3各一个关键姿势样张及实景尺寸试接 → 同角色动作批量 → K4 → K5 → K6 → K7 → 真实关卡验收。不要先批量做完整蛇身、8张边界、八神援助或结局插画。

苏尔特256动作画布、Fenrir256巨口、维达96/弗雷64为本轮明确提案，需要集成确认锚点/状态后才进入最终制作。正常实体依然1倍像素；无通过缩放原人物冒充新动画。

## 自检边界

实际自检结果见records/self_check.json。当前只有K0文件和静态设计检查，没有Godot实测、没有新动画逐帧验收、没有音乐试听，不标记K1～K7完成或第三关验收通过。现有蛇身端口开放是有记录的连接例外；转弯纹理带预览不代替真实运行验证。实际不足和后续依赖记录在integration.md/decisions.json。

复现：在项目内运行 `python3 assets/source/{BASE.name}/build_plan.py`；仅重建本目录设计文档与拼排预览，不生成或覆盖正式素材。核验：`python3 assets/source/{BASE.name}/audit_plan.py`。
''')

gallery='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>K0 维格利德规划</title><style>body{margin:0;background:#101720;color:#d7e4ea;font:16px/1.65 system-ui,sans-serif}main{max-width:1500px;margin:auto;padding:32px}h1{font-size:30px}h2{margin-top:48px}a{color:#8ed5ce}img{max-width:100%;height:auto;image-rendering:pixelated;border:1px solid #34424c}nav{display:flex;gap:24px;flex-wrap:wrap}.note{color:#b4c1ca}table{border-collapse:collapse}td,th{padding:9px 12px;border-bottom:1px solid #34424c;text-align:left}code{overflow-wrap:anywhere}details{margin:12px 0}summary{cursor:pointer}button,input{font:inherit}#mapbox{overflow:auto;max-height:78vh}#mapbox img{max-width:none;width:100%}</style><main><h1>K0 · 维格利德第三关规划</h1><p>本页是布局/规格和已有素材的本地检查材料。没有新最终素材，没有游戏截图，未接入或运行第三关。</p><nav><a href="layout.md">布局</a><a href="asset_matrix.md">逐文件清单</a><a href="asset_plan.json">机器清单</a><a href="integration.md">代码交接</a><a href="audio_events.json">音频事件</a><a href="story_and_ending.md">命运/结局</a><a href="records/self_check.json">实际自检</a></nav><h2>坐标布局</h2><p>可见5120²、行走4608²、屏障256，均为提案；虚线圈是容量示例，不代表固定原点竞技场。</p><label>缩放 <input id="zoom" type="range" min="60" max="200" value="100"> <span id="zv">100%</span></label><div id="mapbox"><img id="map" src="previews/layout.svg" alt="带坐标和尺寸的第三关布局提案"></div><h2>现有素材 1倍尺度</h2><img src="previews/style_scale_1x.png" alt="三Boss两巨人四玩家在现有地块的1倍尺度比较"><p><a href="previews/style_scale_2x.png">2倍最近邻预览</a> · 源像素不变。苏尔特动作的256画布只增加透明空间。</p><h2>蛇身端口与转弯</h2><img src="previews/snake_connections.png" alt="蛇身原图接缝与转弯投影比较"><p>直线接口做逐像素检查；弯曲是几何预览，实际纹理带与碰撞仍需Godot实现/验收。</p><h2>动作画布包络</h2><img src="previews/action_envelopes.png" alt="芬里尔巨口和苏尔特动作画布规格预览"><h2>现有地块4×4</h2><img src="previews/terrain_4x4.png" alt="六张现有地块各4乘4平铺"><h2>各批新增文件提案</h2>'''
gallery+='<table><tr><th>任务</th><th>文件数提案</th><th>完成状态</th></tr>'
for t,n in sorted(count.items()):gallery+=f'<tr><td>{t}</td><td>{n}</td><td>尚未制作；待对应接入契约冻结</td></tr>'
gallery+='<tr><td>K7</td><td>0（当前采用文字与既有UI方案）</td><td>方案已列，剧情代码未接入</td></tr></table><p>不含音效未定项、一般援助未定项及可选结局插画。复用文件不计入新增数。</p><p><a href="previews/style_scale_4x.png">4倍最近邻尺度预览</a></p><h2>逐文件提案/复用</h2>'
for r in assets:
    gallery+=f'<details><summary>{html.escape(r["task"]+" / "+r["decision"]+" / "+r["path"])}</summary><pre>'+html.escape(json.dumps(r,ensure_ascii=False,indent=2))+'</pre></details>'
gallery+='''<script>const z=document.getElementById('zoom');z.addEventListener('input',()=>{document.getElementById('map').style.width=z.value+'%';document.getElementById('zv').textContent=z.value+'%';});</script></main></html>'''
write('gallery.html',gallery)
print(json.dumps(dict(new_files_proposed=len(newrows),reuse_or_reference_files=len(reuse_rows),new_by_task=dict(count),
                      ports=ports,static_reachability=connected),ensure_ascii=False))
