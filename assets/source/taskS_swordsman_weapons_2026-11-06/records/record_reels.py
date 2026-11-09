"""Encode the rendered Godot PNG sequence and the timeline's original WAV cues."""
from concurrent.futures import ThreadPoolExecutor
from math import ceil
from pathlib import Path
import json
import shutil
import subprocess
import sys
import wave

import numpy as np
from catalog import B, SFX

capture = Path(sys.argv[1])
rows = json.loads((B/'godot_preview/runtime/timelines.json').read_text())
single = sys.argv[2] if len(sys.argv)>2 else None
if single:
    rows = [row for row in rows if row['id']==single]
    assert rows,single
ready = capture/'ready'
ready.mkdir()
fps, rate = 24, 44100
expected = sum(row['seconds'] for row in rows)*fps
actual = sorted(p.name for p in (capture/'frames').glob('*.png'))
assert actual == [f'{i:05d}.png' for i in range(expected)],len(actual)
assert all((capture/'stills'/f"{row['id']}.png").is_file() for row in rows)

def timeline_audio(row, path):
    audio = np.zeros(round(row['seconds']*rate),dtype=np.float32)
    cues = row['cues']
    start_sample = lambda seconds: round(ceil(seconds*fps-1e-6)*rate/fps)
    for i,cue in enumerate(cues):
        name = cue.get('sound')
        if not name:
            continue
        with wave.open(str(SFX/f'{name}.wav'),'rb') as stream:
            assert (stream.getframerate(),stream.getnchannels(),stream.getsampwidth())==(rate,1,2)
            clip=np.frombuffer(stream.readframes(stream.getnframes()),dtype='<i2').astype(np.float32)
        start = start_sample(cue['start'])
        later = cues[i+1:]
        if name=='qinglong_spin_loop':
            stop = start_sample(next((c['start'] for c in later if not c.get('spin')),row['seconds']))
            audio[start:stop] += np.resize(clip,stop-start)
        else:
            stop = min(start+len(clip),start_sample(next((c['start'] for c in later if c.get('sound')),row['seconds'])))
            audio[start:stop] += clip[:stop-start]
    with wave.open(str(path),'wb') as stream:
        stream.setparams((1,2,rate,0,'NONE','not compressed'))
        stream.writeframes(np.clip(audio,-32768,32767).astype('<i2').tobytes())

def encode(row, offset):
    name = row['id']
    shutil.copyfile(capture/'stills'/f'{name}.png',ready/f'{name}.png')
    if name=='katana':
        return
    wav = capture/f'{name}.wav'
    timeline_audio(row,wav)
    subprocess.run(['ffmpeg','-nostdin','-v','error','-n','-framerate',str(fps),'-start_number',str(offset),
        '-i',str(capture/'frames/%05d.png'),'-i',str(wav),'-t',str(row['seconds']),'-vf','format=yuv420p',
        '-c:v','libvpx-vp9','-threads','2','-deadline','good','-cpu-used','5','-row-mt','1','-crf','23',
        '-b:v','0','-c:a','libopus','-b:a','96k',str(ready/f'{name}.webm')],check=True)
    print(name,flush=True)

offset=0
with ThreadPoolExecutor(max_workers=3) as pool:
    jobs=[]
    for row in rows:
        jobs.append(pool.submit(encode,row,offset))
        offset+=row['seconds']*fps
    for job in jobs:
        job.result()
for file in sorted(ready.iterdir()):
    file.replace(B/'previews'/file.name)
log=(capture/'run.log').read_text()
with (B/'records/godot-recording.log').open('a' if single else 'w') as out:
    out.write(log+f'Published {expected} actual rendered 1280x720 frames at 24 fps. Audio uses the existing WAV cue assets.\n')
