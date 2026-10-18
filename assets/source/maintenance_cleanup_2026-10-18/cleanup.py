from pathlib import Path
import hashlib
import json
import re
import subprocess
from datetime import datetime

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
AUDIO = ROOT / 'assets/source/taskB_audio_2026-10-17'
STAMP = datetime.now().astimezone().isoformat()

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()

def snapshot(paths):
    return {str(p.relative_to(ROOT)): digest(p) for p in paths if p.is_file()}

def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')

preview_record = AUDIO / 'records/preview_manifest.json'
rows = json.loads(preview_record.read_text())
paths = [AUDIO / row['file'] for row in rows]
assert len(paths) == 11 and len(set(paths)) == 11
assert all(p.parent == AUDIO / 'previews' and not p.is_symlink() and p.is_file() for p in paths)
cache_paths = sorted((ROOT / 'assets/source').rglob('*.pyc'))
cache_paths = [p for p in cache_paths if '__pycache__' in p.parts and not p.is_symlink()]
paths += cache_paths
tracked = set(subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0'))
assert all(str(p.relative_to(ROOT)) not in tracked for p in paths)
ignored = subprocess.run(['git', 'check-ignore', '--stdin'], cwd=ROOT,
    input=''.join(str(p.relative_to(ROOT)) + '\n' for p in paths), text=True, capture_output=True, check=True)
assert set(ignored.stdout.splitlines()) == {str(p.relative_to(ROOT)) for p in paths}

protected_paths = [p for p in (ROOT / 'assets').rglob('*') if p.is_file() and 'source' not in p.relative_to(ROOT / 'assets').parts]
protected_paths += [ROOT / 'project.godot']
for folder in ['scripts', 'scenes', 'docs']:
    protected_paths += [p for p in (ROOT / folder).rglob('*') if p.is_file()]
before = snapshot(protected_paths)
originals = [p for p in (ROOT / 'assets/source').rglob('*') if p.is_file() and ('originals' in p.parts or 'references' in p.parts)]
original_hashes = snapshot(originals)
removed = [{'file': str(p.relative_to(ROOT)), 'bytes': p.stat().st_size,
            'allocated_bytes': p.stat().st_blocks * 512, 'sha256': digest(p),
            'reason': 'rebuildable long audition cache' if p in paths[:11] else 'Python bytecode cache'} for p in paths]
save(HERE / 'before.json', {'created_at': STAMP, 'protected_files': before, 'originals_and_references': original_hashes, 'planned_removals': removed})

gallery_path = AUDIO / 'gallery.html'
gallery = gallery_path.read_text()
for row in rows:
    src = row['file']
    audio = f'<audio controls preload="none" src="{src}"></audio><br><a href="{src}">打开文件</a>'
    assert gallery.count(audio) == 1, src
    gallery = gallery.replace(audio, '<span>长时试听缓存已清理；可按 README 重新生成。单条音频仍可试听。</span>')
gallery = gallery.replace('<table><thead>', '<p class="notice">2026-10-18：已清理 11 份可重建的长时试听缓存，以释放磁盘空间；单条音效、音乐候选与原始文件保留。见 README 的重建命令。</p><table><thead>', 1)
gallery_path.write_text(gallery)
for row in rows:
    row['cache_status'] = 'removed_rebuildable'
    row['cache_removed_at'] = STAMP
save(preview_record, rows)
manifest_path = AUDIO / 'manifest.json'
manifest = json.loads(manifest_path.read_text())
for row in manifest['previews']:
    row['cache_status'] = 'removed_rebuildable'
    row['cache_removed_at'] = STAMP
save(manifest_path, manifest)

readme_path = AUDIO / 'README.md'
readme = readme_path.read_text()
old = '- `previews/`：7 组一分钟连续音效预览、4 首循环曲三遍连播 FLAC。它们是供试听的测试文件，不代表已经实际听过。'
assert old in readme
readme = readme.replace(old, '- `previews/`：可重建的长时试听缓存目录。原有 7 组一分钟音效 WAV、4 份三遍循环 FLAC 已于 2026-10-18 清理；原图、音频原件、候选和单条试听均保留。')
readme += '''

## 2026-10-18 缓存清理

用户确认素材已载入游戏后，移除了 11 份长时试听缓存（309,125,070 字节）。它们不属于游戏引用文件。试听页已移除对应失效播放器，清单标为 `removed_rebuildable`；历史检查数据保留，未补写任何试听或游戏内验收结论。

需要再次做长时试听时，在项目根目录运行以下命令，只重建试听缓存及其清单，不重制正式音频：

```sh
python3 -c "import runpy; runpy.run_path('assets/source/taskB_audio_2026-10-17/make_delivery.py')['preview']()"
```

命令依赖本任务原有的 Python、NumPy 与 FFmpeg 环境。重建后现有试听页仍显示清理说明，可直接打开 `previews/` 中重建的文件；本次清理未改动历史交付脚本。
'''
readme_path.write_text(readme)

for path in paths:
    path.unlink()
for directory in sorted({p.parent for p in cache_paths}, reverse=True):
    if not any(directory.iterdir()):
        directory.rmdir()

after = snapshot(protected_paths)
assert before == after, 'A protected runtime/project file changed during cleanup'
assert snapshot(originals) == original_hashes, 'An original/reference changed during cleanup'
assert all(not p.exists() for p in paths)
dead_links = []
for target in re.findall(r'(?:href|src)="([^"]+)"', gallery):
    if ':' not in target and not target.startswith('#') and not (AUDIO / target).exists():
        dead_links.append(target)
assert not dead_links, dead_links
report = {'finished_at': datetime.now().astimezone().isoformat(), 'status': 'pass',
    'deleted_long_audition_files': 11, 'deleted_bytecode_files': len(cache_paths),
    'deleted_logical_bytes': sum(r['bytes'] for r in removed),
    'deleted_allocated_bytes': sum(r['allocated_bytes'] for r in removed),
    'protected_files_hash_checked': len(before), 'original_reference_hash_checked': len(original_hashes),
    'protected_files_unchanged': True, 'originals_and_references_unchanged': True,
    'audio_gallery_broken_local_links': dead_links, 'deleted_files': removed,
    'game_test': 'not_performed', 'git_commit_push': 'not_performed'}
save(HERE / 'report.json', report)
(HERE / 'README.md').write_text(f'''# 2026-10-18 素材目录清理

用户确认素材已载入游戏后，仅移除可重建的长时试听缓存和 Python 字节码缓存。

- 长时试听缓存：11 份，309,125,070 字节。
- Python 字节码：{len(cache_paths)} 份。
- 删除前分配大小合计：{report['deleted_allocated_bytes']:,} 字节；此数是文件块计数，不是整机空闲空间变化测量。
- {len(before)} 个正式素材、授权、游戏代码、场景、文档与项目配置文件清理前后 SHA256 一致。
- {len(original_hashes)} 个原件／参考文件清理前后 SHA256 一致。
- 音频试听页本地链接检查无失效项；游戏内测试未执行。

保留正式素材、原图、失败稿、参考图、缩小尺寸链、图像预览、manifest、授权和 Git 历史。不清理 Godot 正在使用的导入缓存，不修改代码或项目配置，不提交或推送。

逐文件删除记录及哈希见 `report.json`；清理前保护文件清单见 `before.json`。试听缓存重建命令见 `../taskB_audio_2026-10-17/README.md`。
''')
print(json.dumps({k: v for k, v in report.items() if k != 'deleted_files'}, ensure_ascii=False, indent=2))
