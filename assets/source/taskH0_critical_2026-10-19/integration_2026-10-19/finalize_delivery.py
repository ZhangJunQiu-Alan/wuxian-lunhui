from pathlib import Path
import json,hashlib,re,html,shutil
from PIL import Image,ImageDraw
V=Path(__file__).resolve().parent;H=V.parent;R=H.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,j):p.write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n')
runtime=json.loads((V/'runtime_checks.json').read_text());assert runtime['count']==572 and runtime['failures']==0
assert 'RESULT: 997 checks, 0 failures' in(V/'combat_regression_final.log').read_text()
for name in ['boss_art_test_final.log','combat_regression_final.log','render_review.log','performance.log']:
 assert not re.search(r'SCRIPT ERROR|^ERROR:|^FAIL ',(V/name).read_text(),re.M),name
review=json.loads((V/'render_review.json').read_text());assert len(review['screenshots'])==40 and not review['image_write_errors']
performance=json.loads((V/'performance.json').read_text());assert performance['level']=='helheim';assert performance['measurements'][-1]['active_boss_effects']==0
rows=[]
for group in ['skoll','hati','hrym','garm','nidhogg','hel','thokk']:
 files=sorted(V.glob(group+'_*.png'));out=Image.new('RGB',(1280,385*((len(files)+1)//2)),(18,23,33));d=ImageDraw.Draw(out)
 for i,p in enumerate(files):
  im=Image.open(p).convert('RGB').resize((640,360),Image.Resampling.NEAREST);x=i%2*640;y=i//2*385;out.paste(im,(x,y+25));d.text((x+10,y+6),p.stem,fill='white')
 out.save(V/(group+'_contact_sheet.jpg'),quality=95)
code_paths=list((R/'scripts/bosses').glob('*.gd'))+[R/'scripts/effects/boss_fx.gd',R/'scripts/effects/fx_layer.gd']
code_hashes=[{'path':str(p.relative_to(R)),'sha256':sha(p)}for p in code_paths]
files=[]
for root in sorted((R/'assets/source').glob('taskH*_2026-10-19')):
 p=root/'manifest.json';m=json.loads(p.read_text());task=m['files'][0]['task'];link='integration_2026-10-19/README.md'if root==H else'../'+H.name+'/integration_2026-10-19/README.md'
 for a in m['files']:
  assert sha(R/a['target'])==a['sha256']
  a['code_integration']='integrated'
  a['game_acceptance']='controlled_runtime_verified'
  a['runtime_verification']={'report':link,'scope':'actual Godot Game scenes with controlled skill triggers; full playthrough and long-session balance not tested','automated_assertions':572,'failures':0,'formal_PNG_changed':False}
  for key in ['remaining_issues','unpassed_items','not_passed']:
   if key in a and isinstance(a[key],list):
    a[key]=[x for x in a[key]if not any(s in str(x)for s in ['代码接入未执行','游戏验收未执行','真实关卡验收仍未执行'])]
  files.append({'task':task,'id':a['id'],'path':a['target'],'sha256':a['sha256'],'code_integration':'integrated','runtime_review':'controlled_runtime_verified','hook':a['hook']})
 m['code_integration']='integrated';m['game_acceptance']='controlled_runtime_verified';m['runtime_verification']={'report':link,'scope':'controlled Game viewport and gameplay assertions; not a complete manual run'};save(p,m)
 p=root/'README.md';s=p.read_text();s=re.sub(r'代码接入[：:]\s*未执行','代码接入：已执行',s);s=re.sub(r'游戏验收[：:]\s*未执行','游戏验收：已完成受控技能验证，完整手动通关未测',s)
 s=s.replace('所有新特效仍需代码接入；见 integration.md。','本批新特效已接入；见 integration.md 与后续运行报告。')
 s+='\n## 代码接入收尾（2026-10-19，后续授权）\n\n用户本轮授权同时完成素材与代码。当前正式PNG全部哈希不变，代码已接入，Godot实际Game场景受控触发与画面检查完成。最终572项专项、997项既有回归均无断言失败；40张实际场景截图和短时压力测试见[运行报告]('+link+')。制作阶段的未接入/未实测叙述保留为历史，不代表当前状态。完整关卡手动通关、长期平衡和其他设备表现未测，不扩大验收范围。未接管G6/I/J/K/L，未提交推送。\n';p.write_text(s)
 p=root/'integration.md';s=p.read_text().replace('代码接入交接（未执行）','代码接入交接（已执行并完成受控验证）').replace('此文件是逐项交接，未改任何游戏代码。','此文件保留逐项交接约定；后续用户授权已执行代码接入。').replace('代码接入未执行；游戏验收未执行。','代码接入已执行；受控技能/画面验证见末尾，完整手动通关未测。')
 if task=='H3':s=s.replace('半径radius+12','显示半径取radius+12与身体半高+8的较大值（判伤只由原SHIELD_HALF_ANGLE决定）')
 s+='\n## 已执行接入与实际证据\n\n[最终运行报告]('+link+')记录当前代码、截图、专项边界断言、回归及压力测量。短时效果由BossFx/FxLayer集中绘制、最多96项、按源帧率自动释放；缺素材时返回回退信号。盾弧与啃根流光为随Boss释放的前景子层，避免192px身体遮住效果。赫列姆波带另保留宽26px的淡几何底带显示实际判伤厚度，两缺口共同裁切；盾弧动态显示尺寸随身体，仍仅裁切±1.3rad。斯库尔声波在0.6秒召唤点以8fps完整播0.5秒。尼德霍格流光只在gnaw时显示，显示调制(1.25,1.8,1.25,1)提高暗地面可读性，不改源PNG。加姆范围外驱散已修复，其余伤害、AI、冷却、血量、碰撞半径及第二阶段指甲弹保留。完整手动通关与长期平衡未测。\n';p.write_text(s)
 p=root/'gallery.html';s=p.read_text();s=s.replace('代码接入与游戏验收未执行','代码已接入；已完成Godot受控验证').replace('代码接入/游戏验收未执行','代码已接入；已完成Godot受控验证');s+='<p><a href="'+link+'">最新代码接入与 Godot 运行验证</a></p>';p.write_text(s)
 rows.append((task,len(m['files']),str(root.relative_to(R))))
save(V/'integrated_files.json',{'files':files,'count':len(files),'code_sha256':code_hashes,'game_acceptance_scope':'controlled runtime verification, full playthrough not tested'})
old=json.loads((H/'verification_2026-10-19/protected_files_check.json').read_text());allowed={a['path']for a in json.loads((V/'before_inventory.json').read_text())};unexpected=[]
for a in old['files']:
 if a['path']not in allowed and sha(R/a['path'])!=a['before_sha256']:unexpected.append(a['path'])
save(V/'scope_check.json',{'original_code_scene_project_files_compared':len(old['files']),'unexpected_changes':unexpected,'allowed_existing_script_changes':sorted(allowed),'new_script':'scripts/effects/boss_fx.gd','source_PNG_changes':0,'G6_source_and_audio':'not edited','git_commit_push':'not executed'})
assert not unexpected
# The production audit now checks the recorded runtime scope as well as historical unintegrated records.
p=H/'records/audit_delivery.py';s=p.read_text();s=s.replace("check(a['code_integration']=='not_performed'and a['game_acceptance']=='not_performed',id+' status boundary')","check((a['code_integration'],a['game_acceptance']) in [('not_performed','not_performed'),('integrated','controlled_runtime_verified')],id+' status boundary')\n  if a['code_integration']=='integrated':check(bool(a.get('runtime_verification',{}).get('scope')),id+' runtime scope missing')")
s=s.replace("'code_integration':'not_performed','game_acceptance':'not_performed'","'code_integration':manifest.get('code_integration','not_performed'),'game_acceptance':manifest.get('game_acceptance','not_performed')",1)
s=s.replace("'code_integration':'not_performed','game_acceptance':'not_performed'","'code_integration':'integrated'if all(g['code_integration']=='integrated'for g in groups)else'mixed','game_acceptance':'controlled_runtime_verified'if all(g['game_acceptance']=='controlled_runtime_verified'for g in groups)else'mixed'",1);p.write_text(s)
# Preserve the previous verification as a dated snapshot and link forward.
p=H/'verification_2026-10-19/README.md';s=p.read_text();p.write_text('> 此为代码接入前的验证快照；用户随后授权代码接入，当前状态见[收尾报告](../integration_2026-10-19/README.md)。\n\n'+s)
p=H/'handoff.md';s=p.read_text();s=s.replace('文件交付与素材自检完成；代码接入未执行；游戏验收未执行。只制作H0～H6，未接管G6，未执行I/J/K/L，未改代码、场景、设置、导入，未提交或推送。','文件交付、素材自检与代码接入完成；Godot受控技能/画面验证完成，完整手动通关未测。后续用户已授权本代理完成代码；仅处理H0～H6，G6/I/J/K/L不接管，未提交或推送。')
s=s.replace('|通过|未执行|未执行|','|通过|已接入|受控验证完成|')
start=s.index('## 所需代码接入与剩余问题');end=s.index('## 修正与来源')
s=s[:start]+'''## 接入结果与验证边界

- 33张正式PNG已用于运行加载或静态后备，30项此前未使用的新视觉已接入。
- 女巨人现有命名加载正常；斯库尔使用howl身体动作；海拉第一阶段使用冥界弹，第二阶段指甲弹保留。
- 六Boss专属效果已逐项挂接；赫列姆两缺口/盾背、尼德霍格扇形/潜地/啃根和海拉分区/安全圈/船帆弹幕已用实际Godot视角受控触发检查。
- 加姆范围外驱散增益已修复。短时效果96项上限，集中绘制、自动释放；盾弧和流光随Boss子节点释放。
- 最终572项专项、997项既有回归无断言失败，40张实际场景截图；350怪和40短效同屏短测无新增节点增长。完整手动通关、长期平衡和其他设备未测。
- [最终代码与运行证据](integration_2026-10-19/README.md)。原接入前报告和浏览器设置排查保留为历史；本次验证直接运行Godot。

'''+s[end:]
s+='\n## 最新收尾\n\n[代码接入与运行收尾报告](integration_2026-10-19/README.md) · [实际游戏画面图库](integration_2026-10-19/gallery.html)。本节为最新状态，前面制作阶段记录不作为当前未接入声明。\n';p.write_text(s)
p=H/'handoff.html';s=p.read_text().replace('代码接入与游戏验收未执行','代码已接入；Godot受控验证完成，完整手动通关未测');s+='<p><a href="integration_2026-10-19/README.md">最新收尾报告</a> · <a href="integration_2026-10-19/gallery.html">实际游戏截图</a></p>';p.write_text(s)
p=R/'docs/Codex美术任务书.md';s=p.read_text();s=s.replace('| 1 | H0：女巨人外观、海拉法术弹 | 待制作，优先补明确占位 | 4 个最终 PNG + 自检和接入说明 |','| 1 | H0：女巨人外观、海拉法术弹 | 已交付并接入；受控运行验证完成 | 4 PNG；完整手动通关未测，见下方收尾记录 |').replace('| 2 | H1～H6：六个现有 Boss 的专属效果 | 待制作；是现有技能的美术补强 | 按各表交付；保留原技能行为 |','| 2 | H1～H6：六个现有 Boss 的专属效果 | 已交付并接入；受控运行验证完成 | 29 PNG；保留原技能行为，加姆范围外驱散已修复 |')
s+='\n## H0～H6 收尾记录（2026-10-19）\n\n用户本轮追加授权由同一代理完成素材和代码。33张正式PNG与制作记录哈希一致；斯库尔嚎叫、海拉弹体及28专属效果已接入。572项专项、997项原回归无断言失败；已在实际Godot Game视角受控触发六Boss技能、查看40张截图并短测350怪+40效果。加姆范围外驱散修复，其他判伤/AI/冷却/半径保留。完整关卡手动通关、长时平衡及其他设备未测；未替G6或I/J/K/L改状态，未提交推送。证据：[收尾报告](../assets/source/taskH0_critical_2026-10-19/integration_2026-10-19/README.md)。\n';p.write_text(s)
body='''# H0～H6 素材与代码收尾（2026-10-19）

用户本轮授权同时完成素材和代码。33张正式PNG未改像素或哈希；斯库尔嚎叫动作、海拉第一阶段弹体及28项Boss效果已接入。制作/文件自检完成、代码接入完成、Godot受控运行验证完成。完整手动通关、长时平衡、其他设备表现未测；未将其标记通过。G6/I/J/K/L不接管，未commit/push。

## 文件与代码

- [逐文件接入清单与代码哈希](integrated_files.json)。原图/候选/失败稿/manifest/README/gallery/integration均保留原H目录。
- `scripts/effects/boss_fx.gd`：缓存纹理、按源fps绘制、扇形/圆形裁切、沿动态圆弧铺波带和逐节铁链；缺图返回回退信号。
- `scripts/effects/fx_layer.gd`：短时Boss效果集中绘制，最多96项，按动画寿命清空，不为每次效果增加Node。
- 六Boss及哈提分身/冲击波/冰柱的实际技能挂接；角色碰撞/血量/速度/AI/冷却不改。
- 加姆驱散检查使用击退前距离；范围外保留buff，范围内驱散。三段扑击每段只生成一次咬痕。
- 赫列姆两缺口由同一GAP_HALF几何裁切；26px淡底带显示判伤厚度。盾弧放到前景，显示半径随192px身体避免遮挡，仅±1.3rad。
- 尼德霍格喷口/300px扇形、潜地隐藏和啃根状态保留；啃根绿流光前景显示，打断后立即停止。
- 海拉两侧纹理按分界裁切并平铺；安全圈亮线和圈外压暗保留；第二阶段仍为9枚原指甲弹。

## 自检和实际运行

|检查|结果|证据|
|---|---|---|
|正式PNG、118帧、56GIF|最终文件审计见链接|[审计](../records/final_delivery_audit.json)|
|专项行为/范围/回退/清理|572项断言，0失败|[结果](runtime_checks.json)、[日志](boss_art_test_final.log)|
|既有战斗回归|997项断言，0失败|[日志](combat_regression_final.log)|
|实际游戏视角|40张受控技能截图已查看|[图库](gallery.html)、[捕获记录](render_review.json)|
|350怪与40短效|见下方短测；效果清空到0，节点数不增长|[性能记录](performance.json)、[日志](performance.log)|
|范围外修改保护|原代码/场景/配置96文件对比，非本轮范围零变更|[范围检查](scope_check.json)|

专项目标包含：女巨人6格8fps/4格16fps、普通1倍与精英1.2倍；隐藏支线接受、首次击倒后逃跑替身仍加载动作、第二次击倒完成；六Boss关键判伤边界、赫列姆半血双波和变化缺口、加姆三段/四锁桩/范围内外驱散、尼德霍格潜地/6%打断/2秒硬直、海拉生死侧与登船/弹体区分；360方向检查纹理弧段与判伤缺口一致；96项效果上限/到期清空/缺图回退。

所有断言不是完整游玩证据。实际截图运行的是当前项目Game场景，使用测试驱动冻结/定位并受控触发技能；未声称人工连续打完六场Boss战。首轮第2关未解锁被回退第1关，已退回并在`first_run_fixture_rejected/`保留；最终解锁隔离测试存档后重跑，正确第2关暗地面。身体遮挡的中间稿保留在`second_run_layer_fix/`，修正后最终截图重新渲染。新增波带厚度最后复核见[单独捕获记录](wave_review.json)。

## 短时性能

Apple M2、Godot4.7.2、OpenGL Compatibility、1280×720，第2关。每阶段预热1.5秒、采样5秒；只描述本次机器短测，不能当作长局保证。

'''
for row in performance['measurements']:
 if 'fps_over_interval'in row:body+='- '+row['phase']+'：平均帧间隔'+str(round(row['mean_frame_ms'],2))+'ms，期间帧率'+str(round(row['fps_over_interval'],1))+'，p95 '+str(round(row['p95_frame_ms'],2))+'ms；效果峰值'+str(row['peak_boss_effects'])+'，节点'+str(row['nodes'])+'。\n'
body+='\n各阶段有预热/调度波动，不解释成新效果提升帧率。动画精灵对照与活跃AI对照分开；40效果同时活跃，节点保持1589，结束效果归零。原首轮未预热且关卡错误的性能记录已作废保留。\n\n## 复跑\n\n使用独立存档/设置参数，避免修改真实进度：\n\n```sh\ngodot --headless --path . --script tools/test_boss_art.gd -- --save-file=res://assets/source/taskH0_critical_2026-10-19/integration_2026-10-19/test_save.json --settings-file=res://assets/source/taskH0_critical_2026-10-19/integration_2026-10-19/test_settings.cfg\ngodot --headless --path . --script tools/test_combat_regressions.gd -- --save-file=res://assets/source/taskH0_critical_2026-10-19/integration_2026-10-19/regression_save.json --settings-file=res://assets/source/taskH0_critical_2026-10-19/integration_2026-10-19/regression_settings.cfg\n```\n\n实际视角捕获工具`tools/review_boss_art.gd`（`--skip-stress`跳过旧首轮压力方式）；独立预热基准`tools/benchmark_boss_art.gd`。不需要浏览器运行这些Godot测试。\n\n## 剩余边界\n\n- 本轮素材/代码没有待接入文件；正式PNG均已Godot导入。静态女巨人PNG保留为后备，不替代已有行走/攻击动画。\n- 完整手动通关与长期平衡、其他设备帧率仍未测试；由后续整体游戏验收覆盖。\n- G6声音和I/J/K/L不在本轮；未修改其源码素材或接入代码。\n- 浏览器以后按用户偏好默认内置；当前内置控制组件缺失的问题未在本轮修改设置或绕过。\n'
(V/'README.md').write_text(body)
page='<!doctype html><meta charset="utf-8"><title>H0–H6 Godot实际画面</title><style>body{background:#121721;color:#e0e7ef;font:16px/1.7 system-ui;margin:24px}a{color:#a9d5ff}img{display:block;max-width:100%;image-rendering:pixelated}section{margin:32px 0}</style><h1>H0～H6：Godot实际游戏画面</h1><p>40张受控技能截图；原项目 Game 场景，完整手动通关未测。</p><p><a href="README.md">收尾报告</a> · <a href="runtime_checks.json">572项专项</a> · <a href="performance.json">短时性能</a></p>'
for row in review['screenshots']:
 f=row['file'];page+='<section><h2>'+html.escape(f[:-4])+'</h2><a href="'+f+'"><img loading="lazy" src="'+f+'"></a></section>'
(V/'gallery.html').write_text(page)
for row in review['screenshots']:row['sha256']=sha(V/row['file'])
review['visual_review']='inspected contact sheets of all40 and full-size critical wave/shield/flow/projectile views; full playthrough not tested';review['code_sha256']=code_hashes;save(V/'render_review.json',review)
save(V/'completion.json',{'date':'2026-10-19','scope':'H0-H6','formal_PNG':33,'formal_PNG_pixel_or_hash_changes':0,'code_integration':'complete','runtime_validation':'controlled_skill_and_viewport_verified','full_manual_playthrough':'not_tested','assertions':572,'regression_assertions':997,'failures':0,'screenshots':40,'art_effects_peak_measured':40,'effect_budget_tested':96,'unexpected_foreign_changes':unexpected,'commit_push':'not_executed'})
print('Updated seven manifests and handoffs; 33 formal PNG hashes unchanged; code scope clean')
