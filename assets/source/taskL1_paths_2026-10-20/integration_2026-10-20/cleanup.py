from pathlib import Path
import os, json, hashlib, shutil, subprocess

ROOT=Path(__file__).resolve().parents[4]
BASE=Path(__file__).resolve().parent
FEATURE='c3fff1edc0731e3e159b85031dd40a439311a359'

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def run():
    credential=subprocess.check_output(['gh','auth','token','--hostname','github.com','--user','ZhangJunQiu-Alan'],text=True).strip()
    env=os.environ.copy();env['GH_TOKEN']=credential
    remote=subprocess.check_output(['git','-c','credential.helper=','-c','credential.helper=!gh auth git-credential','ls-remote','origin','refs/heads/main'],cwd=ROOT,env=env,text=True).split()[0]
    assert subprocess.run(['git','merge-base','--is-ancestor',FEATURE,remote],cwd=ROOT).returncode==0,('Published feature SHA must be included on the remote branch before deleting redundant copies',remote)
    processes=subprocess.check_output(['ps','-axo','command='],text=True).splitlines()
    assert not any(('godot ' in line.lower()) and any(str(BASE/name) in line for name in ['runtime_current','runtime_commit']) for line in processes if not line.startswith(('/bin/zsh','python3 -')))
    candidates=json.loads((BASE/'records/cleanup_candidates.json').read_text())['files']
    generated=Path('/Users/zhangjunqiu/.codex/generated_images/01a14093-604c-72e3-b0c2-585e428c4824').resolve()
    verified=[]
    for item in candidates:
        path=Path(item['path']);archive=Path(item['archive'])
        assert path.parent.resolve()==generated and path.suffix=='.png' and not path.is_symlink()
        assert archive.is_relative_to(ROOT/'assets/source') and archive.exists()
        assert sha(archive)==item['sha256']
        committed=subprocess.check_output(['git','show',FEATURE+':'+str(archive.relative_to(ROOT))],cwd=ROOT,text=True)
        assert 'oid sha256:'+item['sha256'] in committed
        if path.exists():
            assert sha(path)==item['sha256']
            verified.append(item)
    before=shutil.disk_usage(ROOT).free
    deleted=[]
    for item in verified:
        Path(item['path']).unlink()
        deleted.append({**item,'category':'external byte-identical generated output; original retained in published project'})
    for name in ['runtime_current','runtime_commit']:
        path=BASE/name
        if not path.exists():continue
        assert path.parent==BASE and not path.is_symlink()
        assert subprocess.run(['git','check-ignore','-q',str(path)],cwd=ROOT).returncode==0
        files=[p for p in path.rglob('*') if p.is_file()]
        size=sum(p.stat().st_size for p in files)
        count=len(files)
        shutil.rmtree(path)
        deleted.append({'path':str(path),'bytes':size,'file_count':count,'category':'rebuildable isolated Godot test project, imported cache and test saves; logs/screenshots/input hashes retained'})
    empty=BASE/'runtime'
    if empty.exists() and not any(empty.iterdir()):empty.rmdir()
    after=shutil.disk_usage(ROOT).free
    report={'date':'2026-10-20','feature_commit_verified_on_remote':FEATURE,'remote_commit_at_cleanup':remote,'remote_ref':'refs/heads/main','deleted':deleted,'deleted_logical_bytes':sum(item['bytes'] for item in deleted),'external_duplicate_count':len(verified),'disk_free_before':before,'disk_free_after':after,'observed_disk_free_delta':after-before,'measurement_note':'logical file bytes and filesystem free-space delta differ because APFS clones, metadata, caches and concurrent activity; free-space delta is observational','preserved':['all60 formal PNGs and imports','all100 project original generations including40 rejections','prompts/input references/hashes/manifests/gallery/mipmap','all verification logs and screenshots','personal saves and unrelated projects/files','other agents work','shared .godot and .git/LFS object store']}
    (BASE/'records/cleanup_result.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({key:report[key] for key in ['external_duplicate_count','deleted_logical_bytes','observed_disk_free_delta','disk_free_after']},ensure_ascii=False))

if __name__=='__main__':run()
