from pathlib import Path
from PIL import Image,ImageSequence
import json,shutil,hashlib
r=Path(__file__).resolve().parents[1];j=json.loads((r/'records/candidates.json').read_text())[0];p=r/j['candidate'];im=Image.open(p).convert('RGBA');ref=Image.open(r/'references/musashi.png').convert('RGBA');last=im.crop((320,0,384,64));visible_diff=sum(1 for a,b in zip(last.get_flattened_data(),ref.get_flattened_data()) if (a[3]!=b[3] or (a[3] and a[:3]!=b[:3])));assert visible_diff==0
for i in range(6):
 f=im.crop((i*64,0,(i+1)*64,64));b=f.getbbox();assert b[0]>=2 and b[1]>=2 and b[2]<=62 and b[3]==60
assert set(im.getchannel('A').get_flattened_data())=={0,255}
out=Path('assets/sprites/characters/musashi_attack.png');backup=None
if out.exists():
 backup=r/'backups/musashi_attack_before_batch07.png';assert not backup.exists();shutil.copy2(out,backup)
shutil.copy2(p,r/'approved/musashi_attack.png');shutil.copy2(p,out);assert hashlib.sha256(out.read_bytes()).hexdigest()==j['sha256']
j.update(status='art_self_check_passed_pending_game_review',output='assets/sprites/characters/musashi_attack.png',approved='approved/musashi_attack.png',checks={'exact_dimensions_rgba_binary_alpha':True,'reference_palette_and_upper_left_light':True,'right_facing_full_silhouette_margin2':True,'all_feet_baseline_y59':True,'fixed_foot_center_anchor':32,'body_proportion_visual_review':True,'dark_background_1x_4x_readable':True,'no_text_watermarks_scene_effects':True,'six_distinct_attack_poses_frame3_clear':True,'one_shot_return_to_standing':True,'return_frame_visible_pixel_difference_vs_static':visible_diff,'browser_two_motion_phases_reviewed':True,'game_tested':False},previews={'contact_1x':'previews/musashi_attack_v03_contact_1x.png','contact_4x':'previews/musashi_attack_v03_contact_4x.png','attack16fps_one_shot':'previews/musashi_attack_v03_attack16fps.gif','attack16fps_QA_loop':'previews/musashi_attack_v03_attack16fps_QA_loop.gif','slow8fps':'previews/musashi_attack_v03_slow8fps.gif'},gif_timing_note='Game target 16fps. GIF 10ms quantization [60,60,70,60,60,70], total380ms,15.789fps. Slow review exactly8fps.',ground_tiling='not_applicable_character_animation',rejected_candidates=['v01 sword tip breached margin','f03_piskel_v02 flat blade end; v03 repainted actual pixels and verified zero difference vs plan'])
(r/'records/candidates.json').write_text(json.dumps([j],ensure_ascii=False,indent=2)+'\n');(r/'manifest.json').write_text(json.dumps({'batch':'07','date':'2026-10-16','status':'in_progress','planned_assets':29,'approved_assets':1,'assets':[j]},ensure_ascii=False,indent=2)+'\n');plan=json.loads((r/'records/production_plan.json').read_text());plan[0]['status']=j['status'];(r/'records/production_plan.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n')
(r/'README.md').write_text('''# 第7批：战斗动作与其余角色

状态：进行中，1/29项美术自检通过，待代码代理游戏验收。

## 已通过：A 武藏攻击

- `assets/sprites/characters/musashi_attack.png`：384×64，6帧64×64，游戏按16fps播放一次。朝右，无刀光等程序特效。
- 原图实际从Chrome ChatGPT下载，上传了现有武藏和六帧定位模板。来源链接、提示词、工具与哈希见manifest及records。
- 第③帧刀尖原先超出边距；Chrome Piskel逐像素重画后导出PNG与工程，和预定像素修改零差异。v02刀尖被截平退回，采用v03。
- 统一既有武藏调色板，实际44色；RGBA、alpha仅0/255；全部脚底y59、四周至少2像素。末帧采用现有静态站姿，可见像素零差异。
- 实际检查了深色背景1倍、4倍全帧、16fps近似GIF和8fps慢放的两个网页播放相位。挥刀、前倾、下落收刀可辨认。攻击为单次播放，不要求首尾循环衔接。
- GIF受10ms计时精度限制，攻击预览总380ms、约15.789fps；PNG帧条供游戏精确16fps播放。慢放GIF恰为8fps。
- 人物动画的4×4地块平铺检查不适用。此批未制作地图。

## 剩余

B：7种小怪/精英攻击；C：安妮、兰陵王、梅林各7项，共28项。按A→B→C制作，第4批由另一个代理负责。

只修改assets，未运行游戏、未提交或推送Git。通过美术自检不代表已通过游戏内验收。
''')
print('Published A:1/29; visible return-frame difference:',visible_diff)
