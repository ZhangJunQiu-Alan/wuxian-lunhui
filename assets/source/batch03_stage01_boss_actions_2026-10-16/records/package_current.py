from pathlib import Path
from PIL import Image
import json,html,hashlib
r=Path(__file__).resolve().parents[1]
old=json.loads((r/'manifest.json').read_text());latest={}
for name in ['wolf_candidates_metadata_v02.json','wave03_candidates_metadata.json','wave04_candidates_metadata.json']:
 for a in json.loads((r/'records'/name).read_text()):latest[a['id']]=a
assets=[]
for a in old['assets']:
 id=a['id'];entry={k:a[k] for k in ['id','frame_size','expected_frames']};entry.update(final_copied=False,status='not_started')
 if id in latest:entry.update(latest[id])
 rev=r/f'records/{id}_review.json'
 if rev.exists():
  review=json.loads(rev.read_text())
  if review['status'].startswith('self_check_passed'):
   entry.update(review);im=Image.open(r/review['candidate']).convert('RGBA');entry.update(size=list(im.size),frames=im.width//im.height,colors=len({p[:3] for p in im.get_flattened_data() if p[3]}),approved_file=f'approved/{id}.png',review_record=f'records/{id}_review.json',final_copied=False)
 assets.append(entry)
manifest=dict(batch=r.name,status='in_progress',approved_count=sum(a['status'].startswith('self_check_passed') for a in assets),required_count=15,final_copied_count=0,assets=assets,generation_records=[f'records/generation_jobs_{x}.json' for x in ['v01','v02','wave03','wave04']],game_test='not_performed',terrain_4x4='not_applicable_no_terrain_in_batch_3',notes=['只将逐项自检通过稿放进本批approved；未完成整批，未新增正式动作目录文件。','GIF为8FPS名义时序，三帧GIF受10ms时间粒度限制，实际时长与平均帧率逐项记录。','此前v02固定色板补零引入第49色；已记录退回，后续补齐为重复首色，输出不超过48色。'])
(r/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
page=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>第 3 批 Boss 动作 · {manifest['approved_count']}/15 自检通过</title><style>body{{background:#121721;color:#e4eaf3;padding:24px;font:15px/1.6 system-ui}}a{{color:#9dccff}}img{{image-rendering:pixelated}}article{{border-top:1px solid #455066;margin-top:24px;padding-top:12px}}details{{overflow:auto}}.row{{display:flex;align-items:end;gap:20px}}.passed{{color:#a9e7b6}}.pending{{color:#ffd29d}}</style><h1>第 3 批 Boss 动作 · {manifest['approved_count']} / 15 自检通过</h1><p>整批仍在制作中。通过稿保存在 approved/，尚未复制到正式 sprites/ 动作目录，未进行游戏实测。</p><p><a href="manifest.json">manifest.json</a> · <a href="README.md">README</a> · <a href="../../LICENSES.md">授权台账</a></p>'''
for a in assets:
 passed=a['status'].startswith('self_check_passed');n=a['frame_size'][0];path=a.get('candidate');gif=a.get('preview') or a.get('preview_gif')
 page+='<article><h2 class="'+('passed' if passed else 'pending')+'">'+html.escape(a['id'])+' · '+('自检通过，待整批交付' if passed else html.escape(a['status']))+'</h2>'
 if path:
  im=Image.open(r/path);count=im.width//n;page+=f'<div class="row"><div>参考<br><img width="{n}" src="references/{a["id"].split("_")[0]}_48color.png"></div><div>实际 1× 横向帧条<br><img width="{im.width}" height="{im.height}" src="{path}"></div></div><details><summary>4× 最近邻逐帧查看</summary><img width="{im.width*4}" height="{im.height*4}" src="{path}"></details>'
  if gif:page+=f'<p>实际 PNG 帧的 4× GIF；名义 8 FPS</p><img width="{n*4}" height="{n*4}" src="{gif}">'
 if a.get('rejection_reasons'):page+='<p>退回原因：'+html.escape('；'.join(a['rejection_reasons']))+'</p>'
 if a.get('review_record'):page+='<p><a href="'+a['review_record']+'">逐项审核记录</a></p>'
 page+='</article>'
page+='<p>本批不含地块，4×4 地块平铺不适用。第 4 至第 6 批尚未开始。</p></html>';(r/'gallery.html').write_text(page)
(r/'README.md').write_text(f'''# 第 3 批：第 1 关 Boss 动作（制作中）

当前 {manifest['approved_count']} / 15 条美术自检通过。尚未完成整批交付，未新增正式 sprites/ 动作文件，未进行游戏实测。不要运行旧版 records/package_progress.py，它只记录早期一条待机。

- 原图：originals/；原角色参考与定位模板：references/。
- 原提示词、Chrome 会话、下载文件名：records/generation_jobs_*.json 与对应 prompt 文件。
- 通过稿：approved/；全部候选及失败版本：candidates/；GIF 与 1×/4× 审核图：previews/。
- 逐项门槛、来源、哈希、实际 GIF 时长、未通过原因：manifest.json 与 records/*_review.json。
- 本批不含地块，4×4 平铺不适用。

已通过：{', '.join(a['id'] for a in assets if a['status'].startswith('self_check_passed'))}。

斯库尔待机通过 Chrome Piskel 实际逐像素修改。哈提嚎叫 v02 通过 Chrome Piskel 选区复制固定四肢、尾巴和躯干，实际导出的 y>=62 与 x<=62,y<62 区域逐帧 RGBA 差异均为零；PNG 与可编辑 .piskel 均已归档。

退回记录：第一轮狼类动作比例偏离；第二轮实际49色（补零引入额外黑色），并有步态或头部轮廓问题；斯库尔移动 v03 仍缺乏清晰交替迈步；赫列姆横砸 v01 跨格导致武器切断。失败版本没有放入 approved/。

第四轮两条待机完成原图下载与规范化，正在判断是否需要局部冻结减少纹理闪烁；不得当成已批准稿。所有新动作均使用本项目现有角色上传作参考，没有采用第三方作品形象。

Chrome 旧空页、重复工具页、已归档生成页已关闭，当前只保留审核页；继续制作时按需开页，完成保存即关闭。
''')
print({'approved_count':manifest['approved_count'],'assets':len(assets)})
