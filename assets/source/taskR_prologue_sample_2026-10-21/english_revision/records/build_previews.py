from pathlib import Path
import json
import subprocess
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
TASK = ROOT.parent
book = json.loads((TASK.parents[2] / "assets/cinematics/norse/sequences.json").read_text())
WORK = TASK / "work/english_preview"
WORK.mkdir(exist_ok=True)
for level, sequence in book.items():
    video = TASK / f"preview/{level}_story.mp4"
    contact = Image.new("RGB",(1280,816),(14,20,27))
    draw = ImageDraw.Draw(contact)
    for index in range(16):
        at = (index+0.5)*sequence["duration"]/16
        frame = WORK/f"{level}_{index:02d}.png"
        subprocess.run(["ffmpeg","-v","error","-y","-ss",str(at),"-i",str(video),"-frames:v","1","-vf","scale=320:180",str(frame)],check=True)
        x,y = index%4*320,index//4*204
        with Image.open(frame) as im: contact.paste(im,(x,y))
        draw.text((x+8,y+184),f"{at:05.2f}s",fill=(210,205,193))
    contact.save(TASK/f"preview/{level}_contact_4x4.jpg",quality=92)
    for i,shot in enumerate(sequence["shots"],1):
        at=(shot["caption_start"]+shot["caption_end"])/2
        subprocess.run(["ffmpeg","-v","error","-y","-ss",str(at),"-i",str(video),"-frames:v","1",str(TASK/f"preview/{level}_shot{i}.png")],check=True)
    command=["ffmpeg","-hide_banner","-y","-i",str(video),"-filter_complex","fps=4,scale=480:-1:flags=lanczos,split[v][p];[p]palettegen=max_colors=96[palette];[v][palette]paletteuse=dither=bayer:bayer_scale=3","-loop","0",str(TASK/f"preview/{level}_preview_4fps.gif")]
    with (ROOT/f"qa/gif_{level}.log").open("w") as log:subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,check=True)
    print("PREVIEWS",level,flush=True)
