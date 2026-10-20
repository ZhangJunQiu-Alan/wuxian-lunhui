from pathlib import Path
import json,hashlib,shutil
V=Path(__file__).resolve().parent; H=V.parent; R=H.parents[2]
def save(p,data):p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
run=json.loads((V/'runtime_checks.json').read_text())
assert run['failures']==0
assert 'SCRIPT ERROR' not in (V/'runtime_checks_final.log').read_text()
assert 'ERROR:' not in (V/'runtime_checks_final.log').read_text()
assert '997 checks, 0 failures' in (V/'combat_regression_final.log').read_text()
assert 'ERROR:' not in (V/'combat_regression_final.log').read_text()
plan=json.loads((H/'records/plan_all_H.json').read_text())
scripts={str(p.relative_to(R)):p.read_text()for p in (R/'scripts').rglob('*.gd')}
items=[]
for a in plan:
 refs=[p for p,t in scripts.items() if a['target'] in t]
 if a['id'].startswith('thokk'):
  status='existing_naming_loader_verified';detail='普通/精英实际 Enemy 加载移动和攻击；静态为后备，不是新增显式代码接入'
 elif a['id']=='skoll_howl_body':
  status='loaded_but_state_not_mapped';detail='Boss 动作加载器发现 howl；state_actions.howl 仍为 windup'
 else:
  status='missing_integration';detail='当前代码无此正式路径引用，沿用程序表现；未验证新特效战斗表现'
 items.append({'task':a['task'],'id':a['id'],'path':a['target'],'sha256':sha(R/a['target']),'literal_references':refs,'status':status,'detail':detail,'required_hook':a['hook'],'game_acceptance':'not_accepted'})
save(V/'integration_inventory.json',{'files':items,'existing_loader_paths':3,'loaded_but_unmapped':1,'missing_integration':29,'new_visuals_not_used_in_game':30})
inv=json.loads((V/'snapshot_inventory.json').read_text());protected=[]
for a in inv['files']:
 if a['path'].startswith(('scripts/','scenes/')) or a['path']=='project.godot':
  protected.append({'path':a['path'],'before_sha256':a['sha256'],'after_sha256':sha(R/a['path']),'same':a['sha256']==sha(R/a['path'])})
save(V/'protected_files_check.json',{'scope':'compare originals at snapshot capture and report; read only','files':protected,'changed':sum(not x['same']for x in protected)})
shutil.copy2(V/'runtime_snapshot/tools/test_combat_regressions.gd',V/'test_combat_regressions_snapshot.gd')
# Correct only our current handoff; append-only licenses retain the prior historical statement.
old1='现有敌人加载器按radius×2.6计算52px显示高，精英倍率在height计算中抵消；若需要96px画布按1倍显示，应由集成Agent单独确认并配置显示高度，不修改碰撞半径。'
new1='2026-10-19 Godot隔离副本实测：radius×2.6传入52px期望高度，但SpriteVisual以maxf(1, round(height/tex_height))限制至少1倍；普通版96px画布、精英版1.2倍即115.2px画布。此前约52px实际显示的判断有误，已撤回；无需为此新增显示高度配置，不修改碰撞半径。'
p=H/'README.md';s=p.read_text().replace(old1,new1).replace('没有执行 Godot 测试、修改代码/场景/项目设置或 Git 提交推送。','制作阶段没有执行 Godot 测试；后续已在隔离的当前代码副本完成加载、播放及行为验证，见 verification_2026-10-19/README.md。未修改原项目代码/场景/项目设置，未 Git 提交推送。');p.write_text(s)
p=H/'integration.md';s=p.read_text().replace('`Enemy._ready()` 的height=radius×2.6/(精英倍率)使该类型显示约52px高。thokk文件按96px制作，若希望1倍巨人尺度请做类型专用显示高度；碰撞radius20、血量、速度、精英逻辑、逃跑与攻击判伤不改。','`Enemy._ready()` 传入的height=52只是期望值；`SpriteVisual` 的maxf(1, round(height/tex_height))使96px画布至少1倍显示。隔离副本实测普通scale1、精英scale1.2；此前“实际显示52px、需要专用高度”的建议有误，撤回。碰撞radius20、血量、速度、精英逻辑、逃跑与攻击判伤不改。');p.write_text(s)
p=H/'manifest.json';m=json.loads(p.read_text())
for a in m['files']:
 a['remaining_issues']=[x.replace('现有loader按radius×2.6算约52px显示高；由集成Agent确认96px显示，不改radius20','已实测现有loader普通scale1/精英scale1.2；此前52px实际显示判断撤回；真实关卡验收仍未执行')for x in a.get('remaining_issues',[])] if 'remaining_issues'in a else a.get('remaining_issues',[])
# Field name may differ; change the exact stale value wherever it appears.
def correct(o):
 if isinstance(o,dict):return {k:correct(v)for k,v in o.items()}
 if isinstance(o,list):return [correct(v)for v in o]
 if isinstance(o,str):return o.replace('现有loader按radius×2.6算约52px显示高；由集成Agent确认96px显示，不改radius20','隔离实测loader普通scale1/精英scale1.2；撤回52px实际显示判断；真实关卡验收仍未执行')
 return o
m=correct(m);m['runtime_verification']={'report':'verification_2026-10-19/README.md','scope':'isolated current-code snapshot','checks':run['count'],'failures':0,'game_acceptance':'not_performed'};save(p,m)
p=H/'handoff.md';s=p.read_text().replace('- thokk现有动作命名可被加载，但现有高度公式将96px画布显示约52px；由集成Agent确认显示尺度，碰撞半径不改。','- thokk普通/精英已在当前代码隔离副本实际加载、播放；画布分别96px和115.2px。此前52px显示判断撤回，不需要专用高度修复；碰撞半径不改。').replace('- 仍未测真实游戏视角、技能判伤对齐、密集战斗遮挡、节点清理和帧率；不能标记游戏验收通过。','- 当前代码的关键判伤边界与现有临时节点清理已经隔离测试；新特效尚未接入，真实战斗视角、与判伤对齐、密集遮挡、GPU帧率和新特效节点清理仍未测，不能标记游戏验收通过。')
s+='\n## 后续验证（2026-10-19）\n\n[完整验证报告](verification_2026-10-19/README.md)：现有战斗回归997项0断言失败；H专项'+str(run['count'])+'项0断言失败；不把“确认未接入”的断言当作接入验收通过。33张Godot可加载，30项新视觉未用于游戏。普通/精英女巨人四帧Godot渲染截图已看。加姆范围外也驱散增益的现有行为已复现，交代码Agent确认。Chrome在用户开启设置后复测仍禁用，见[排查步骤](verification_2026-10-19/browser_fix.md)。\n';p.write_text(s)
p=H/'handoff.html';s=p.read_text();s+='<p><a href="verification_2026-10-19/README.md">后续 Godot 验证及剩余问题</a> · <a href="verification_2026-10-19/browser_fix.md">Chrome 设置排查</a></p>';p.write_text(s)
report='''# H0～H6 剩余问题验证（2026-10-19）

原项目代码、场景、项目配置及导入设置未修改；所有测试副本、脚本和输出仅在本任务 assets 中。G6/I/J/K/L未操作，未执行commit/push。

## 实际文件与运行验证

|项目|结果|证据与限制|
|---|---|---|
|33 PNG 文件自检|重跑后见最终审计|RGBA、尺寸、帧差异、色数、alpha、留白/基线、重复端口、PNG/候选/approved/manifest哈希及GIF像素时序；不是游戏验收|
|33 PNG Godot加载|通过|当前代码隔离副本；正式尺寸全部正确|
|女巨人移动/攻击|通过加载和播放|6格8fps循环、4格16fps单次；实际触发攻击后返回移动；普通scale1、精英scale1.2|
|现有战斗回归|997检查，0断言失败|隔离当前代码，涵盖查询/技能/生成/结算；不代表新特效GPU帧率|
|H专项|COUNT检查，0断言失败|包含未接入状态确认；不能将全绿断言解释成美术接入完成|
|女巨人引擎渲染|四帧已查看|Apple M2 OpenGL Compatibility实际渲染；普通/精英与现有霜巨人并排；不是实际关卡战斗|
|浏览器控制|仍阻塞|用户开启设置后再次listTabs仍返回Work禁用；没有绕过设置|

## 已实测的当前 Boss 行为

- 斯库尔：半血进入嚎叫、召唤6狼、冲刺0.1秒位移95px；新howl动作会被加载，但状态仍映射windup。
- 哈提：75%血以下解锁分身，生成2个、同身体纹理/动作集合、过期节点释放；279/281px两侧恐惧边界。
- 赫列姆：前盾1.29rad挡、1.31rad及背后不挡；两处缺口±0.42rad边界/跨2π；同一波在缺口免伤、实体弧段受伤；冲击波700px结束释放；冰柱碰撞18px和3秒过期释放。
- 加姆：4锁桩，最后一个断后挣脱；速度×1.5、承伤×1.3；259/261px两侧伤害边界；两处位置都会驱散增益，见下方待确认问题。
- 尼德霍格：潜地隐藏并离开敌人组，破土恢复可见与索引；啃根累计6%伤害打断、2秒恢复；毒息±0.6rad与300+玩家半径14px边界；毒池椭圆内外及7秒释放。
- 海拉：安全圈0/50/100/150秒为1000/690/380/380px；生侧治疗15%、死侧召唤3、军团14；第一阶段5弹仍空纹理、过期释放；低于30%登船、第二阶段仍9指甲弹。

这些是对既有代码方法/节点的自动化触发与断言；没有游玩六场完整Boss战，没有确认每条完整状态循环或所有交互。脚本、日志、截图和哈希均保留。

## 所需代码接入与剩余问题

|项目|状态|下一步|
|---|---|---|
|thokk 3文件命名|现有加载可用|集成Agent在原项目正常导入后检查对应支线实际生成；无需新增52px缩放修复|
|斯库尔身体howl|发现动作，状态未使用|将state_actions.howl由windup改howl，并检查3格单次播放与召唤时间|
|海拉第一阶段弹体|仍为null|给第一阶段_fan传hel_death_bolt纹理；第二阶段指甲弹保留|
|其余28 Boss效果|无运行引用|按各integration逐文件接入、停止/释放、缺失回退，清理被替换的重复程序外观|
|赫列姆缺口/盾背、尼德霍格扇形、海拉分区/安全圈|旧几何边界已测试；新图对齐未测|接入后实际视角验证遮罩、朝向、锚点、边界可读性|
|加姆范围外驱散|当前行为已复现|_howl驱散语句位于HOWL_RADIUS分支外；伤害/击退有范围限制，增益移除没有。交代码Agent确认设计，素材Agent不改玩法|
|大量敌人+新特效的遮挡、帧率、新节点释放|无法验证|30项新视觉未运行；接入后GPU实际场景测量，不能以headless查询耗时代替FPS|
|Chrome全套连续播放复核|设置阻塞|见browser_fix；此前抽样记录不扩大成全套通过|

## 尺度更正

此前“女巨人实际显示52px，需要专用显示高度”的判断有误。Enemy传入height=52，而SpriteVisual通过maxf(1,round(height/tex_height))限制至少1倍；实测普通96px画布、精英1.2倍即115.2px画布。此次已修正README、integration、manifest及handoff，并在LICENSES末尾追加更正；原图与所有正式PNG未变。

素材脚底基线y92是单帧源像素坐标；它不等于Enemy节点局部y92。引擎中居中精灵、offset与position的共同变换后，普通脚底局部y44、精英y52.8。截图保留现有霜巨人的同加载方式作对照，不擅自改变全局锚点策略。

## 证据

- [H专项完整断言](runtime_checks.json)、[最终运行日志](runtime_checks_final.log)、[测试脚本](verify_h_runtime.gd)。早期试跑的测试脚本问题及退出警告保留在旧log；最终日志无Godot脚本错误/资源泄漏警告。
- [战斗回归最终日志](combat_regression_final.log)、[本次原回归脚本副本](test_combat_regressions_snapshot.gd)。最早试跑漏复制locale；补齐后最终997项无错误。
- [逐文件接入清单](integration_inventory.json)、[原代码/场景/项目配置前后哈希](protected_files_check.json)、[运行副本源文件哈希](snapshot_inventory.json)。
- 引擎攻击帧截图：[0](thokk_engine_frame_0.png)、[1](thokk_engine_frame_1.png)、[2](thokk_engine_frame_2.png)、[3](thokk_engine_frame_3.png)；[渲染脚本](render_thokk.gd)、[渲染日志](render_thokk_final.log)。日志含macOS输入法mach port诊断，PNG成功写出；不是素材或脚本错误。
- [浏览器诊断](browser_diagnostics.json)、[设置排查步骤](browser_fix.md)。

隔离副本只为保护原项目导入/存档而创建，完成后清理本任务自建副本和导入缓存，保留源哈希、测试脚本、最终与失败日志、结果和截图；不清理其他任务文件。
'''.replace('COUNT',str(run['count']))
(V/'README.md').write_text(report)
(V/'browser_fix.md').write_text('''# Chrome：Work设置禁用的排查

2026-10-19实测：用户答复已开启后，Chrome工具listTabs仍返回“Local browser use is disabled in Work settings”。本轮没有恢复成功，不是网页或素材错误。

只读检查：~/.codex/config.toml（含profiles）未找到browser/computer/work相关显式features；项目.codex/config.toml、/etc/codex/requirements.toml不存在。没有改任何配置。企业远程/MDM策略未检查，不能宣称没有管理员限制。

1. 已开启开关后仍失败：先保存工作，完全退出桌面应用和Chrome（macOS用⌘Q，关窗口不等于退出），再重新打开。官方建议连接异常时重启浏览器；若多份桌面应用，确认当前Chrome扩展连接的是正在使用的那份。
2. 在桌面应用Settings → Computer Use → Google Chrome确认显示Manage，使用安装ChatGPT扩展的同一Chrome配置。若本版本把本地浏览器使用总开关放在Work里，确认总开关开启；Chrome连接显示Manage并不能独立证明总开关可用。Settings → Browser是内置浏览器设置，与Chrome路径区分。
3. 重开本会话复测；若仍旧禁用，官方建议新建Work/Codex聊天并@Chrome测试，让浏览器连接重新建立。本轮已有素材和验证都已落盘，新聊天可以读取本README接续。
4. 若开关灰色、显示组织管理，或新会话仍返回同一Work禁用：管理员需检查Workspace settings → Permissions & roles及浏览器受管策略。features.browser_use=false会关浏览器控制；browser_use_external=false会关外部浏览器控制。用户开启不能覆盖管理员拒绝；不要强行改配置绕过。
5. 浏览器控制恢复后再检查文件导入：Chrome扩展“允许访问文件网址”只解决本地文件导入，不能解开Work总开关。此前已经授权过，无需为当前报错反复开启这项。

官方依据：
- https://learn.chatgpt.com/docs/chrome-extension （设置/Manage/配置/重启/新聊天排查）
- https://learn.chatgpt.com/docs/browser （内置Browser设置路径）
- https://learn.chatgpt.com/docs/enterprise/chatgpt-work-local-security （工作区权限、用户不能覆盖管理员拒绝）
- https://learn.chatgpt.com/docs/enterprise/managed-configuration#control-browser-and-computer-use （browser_use及browser_use_external受管开关）

“当前会话尚未刷新开关或连接”的解释是排查假设，不是已确认原因。恢复的判据是Chrome工具实际列出标签并成功打开/读取本批图库；只有设置截图或用户答复，不标记恢复通过。
''')
save(V/'verification_summary.json',{'date':'2026-10-19','engine':run['engine'],'file_checks':'see records/final_delivery_audit.json','godot_H_assertions':run['count'],'godot_H_assertion_failures':0,'combat_regression_assertions':997,'combat_regression_failures':0,'thokk_engine_frames_inspected':4,'formal_PNG_changed':False,'new_visuals_not_used_in_game':30,'game_acceptance':'not_performed_missing_integration','browser_recovery':'blocked_after_user_enabled','garm_out_of_range_dispel':'reproduced_existing_behavior_for_code_agent','protected_files_changed':sum(not x['same']for x in protected)})
print(json.dumps({'checks':run['count'],'protected_files':len(protected),'protected_changed':sum(not x['same']for x in protected),'unused_visuals':30},ensure_ascii=False))
