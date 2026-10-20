from pathlib import Path
import json,hashlib,shutil

R=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
 evidence=R/'records/listening_acceptance.json'
 if not evidence.exists():raise SystemExit('No listening acceptance evidence; candidates remain unpublished.')
 acceptance=json.loads(evidence.read_text());manifest=json.loads((R/'manifest.json').read_text());audit=json.loads((R/'records/audio_audit.json').read_text());groups={e['id'] for e in manifest['files'] if e['frequent']}
 if not acceptance.get('all44_listened_and_accepted') or set(acceptance.get('minute_groups_accepted',[]))!=groups:raise SystemExit('Complete listening or minute-long group acceptance is missing; no publication.')
 if audit['status']!='pass' or len(manifest['files'])!=44:raise SystemExit('Technical audit incomplete; no publication.')
 for e in manifest['files']:
  if sha(R/e['candidate'])!=e['sha256']:raise SystemExit('Candidate changed since audit: '+e['stem'])
 published=[]
 for e in manifest['files']:
  source=R/e['candidate'];approved=R/'approved'/source.name;dest=R.parents[1]/'audio/sfx'/source.name
  if dest.exists() and sha(dest)!=e['sha256']:
   backup=R/'backups'/source.name
   if backup.exists() and sha(backup)!=sha(dest):backup=R/'backups'/(source.stem+'_'+sha(dest)[:12]+source.suffix)
   shutil.copy2(dest,backup)
  shutil.copy2(source,approved);shutil.copy2(source,dest)
  assert sha(dest)==sha(approved)==e['sha256'];published.append('audio/sfx/'+source.name);e['runtime_file']='audio/sfx/'+source.name;e['status']='user_listening_accepted_technical_pass';e['subjective_checks']={k:('not_applicable' if v=='not_applicable' else 'accepted_by_user') for k,v in e['subjective_checks'].items()};e['listening_evidence']='records/listening_acceptance.json'
 manifest.update(status='published_after_user_listening_acceptance',runtime_files_published=published,listening_acceptance=acceptance,game_test='not_performed');(R/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n');(R/'records/publication_audit.json').write_text(json.dumps({'published':len(published),'hashes_match':True,'audition_by':'user','assistant_subjectively_listened':False,'game_test':'not_performed'},indent=2)+'\n');print('Published',len(published),'WAVs; Godot test pending.')

if __name__=='__main__':main()
