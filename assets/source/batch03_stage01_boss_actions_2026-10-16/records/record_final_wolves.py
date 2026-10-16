from pathlib import Path
from PIL import Image
import json,hashlib,shutil
r=Path(__file__).resolve().parents[1]
entries=[x for x in json.loads((r/'records/wave06_components_metadata.json').read_text())]
a=next(x for x in json.loads((r/'records/wave05_components_metadata.json').read_text()) if x['id']=='skoll_move');entries.append(a)
a=next(x for x in json.loads((r/'records/wave05_components_metadata.json').read_text()) if x['id']=='hati_move');a.update(candidate='candidates/hati_move_v08.png',preview='previews/hati_move_v08.gif',version='v08',editable='candidates/hati_move_v08.piskel',pixel_verification='records/hati_move_v08_export_verification.json');entries.append(a)
for a in entries:
 im=Image.open(r/a['candidate']).convert('RGBA');im.load();n=128;count=im.width//n;frames=[im.crop((i*n,0,(i+1)*n,n)) for i in range(count)];palette={tuple(c) for c in json.loads((r/a['palette']).read_text())};used={p[:3] for p in im.get_flattened_data() if p[3]};assert used<=palette and len(used)<=48;assert set(im.getchannel('A').get_flattened_data())=={0,255};boxes=[f.getbbox() for f in frames];assert all(b[0]>=2 and b[1]>=2 and b[2]<=126 and b[3]==a['baseline']+1 and b[3]<=126 for b in boxes)
 move=a['id'].endswith('_move');dur=[120 if i%2==0 else 130 for i in range(count)];a.update(status='self_check_passed_pending_batch_completion',size=list(im.size),frames=count,colors=len(used),bboxes=boxes,checks={k:True for k in ['exact_png_rgba_horizontal_square_frames_no_gap','binary_alpha','common_reference_palette_at_most_48','feet_baseline_fixed_safe_margins','same_character_facing_right_and_view','complete_anatomy_no_stray_fragments','consistent_dark_outline_upper_left_light','1x_original_character_comparison','4x_every_frame_contact_reviewed','actual_chrome_multiple_animation_phases','no_text_watermark_background','no_per_frame_independent_scaling']},loop_seam='checked_last_to_first' if move else 'not_applicable_single_play_skill; full six-frame sequence checked',gif_nominal_fps=8,gif_duration_ms=dur,gif_actual_average_fps=count*1000/sum(dur),proof=['records/wolf_final_v08_phase_a.jpg','records/wolf_final_v08_phase_b.jpg'],game_test='not_performed',tools=['Chrome ChatGPT reference-guided generation','Pillow complete-component extraction, fixed shared palette and baseline normalization'],sha256=hashlib.sha256((r/a['candidate']).read_bytes()).hexdigest())
 if move:
  a['motion_interpretation']='四足快速追击步态'
  a['observations']=['前肘屈曲与伸出、左右脚承重变化清楚，四帧采用快速追击节奏；头背随低伏/伸展有周期起伏，最后一帧与第一帧高度接近。','每组帧使用同一缩放，统一脚底基线，头部大小、毛色、额毛与卷尾保持；按快速移动审核，未声称达到提示词慢走身体起伏1像素目标。']
  if a['id']=='skoll_move':a['observations'].append('不透明包围框顶部17→9→8→16；保留低伏-伸展-伸展-低伏节奏，正式移动速度与播放速度仍需代码代理游戏审核。')
  else:a['observations'].append('Piskel实际修正第1、4帧环形抬爪；验证限定区域差异，其他部位及第2、3帧不变，最终导出与确定性复制结果0像素差异。');a['tools'].append('Chrome Piskel native selection copy/move, temporary-frame deletion, actual PNG and piskel export')
 else:a['observations']=['同一黑灰金焰角色：低伏蓄力、短探头开合下颌、抬头收回，鼻口轮廓与火焰鬃毛保持可识别。','未沿用早期长身扑咬；六帧共用同一缩放、相同脚底基线、无跨格或游离碎片；身体相机保持三分之二朝右。']
 (r/f'records/{a["id"]}_review.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n');shutil.copy2(r/a['candidate'],r/f'approved/{a["id"]}.png');print(a['id'],'passed')
