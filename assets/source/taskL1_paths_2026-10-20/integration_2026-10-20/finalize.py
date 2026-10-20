from pathlib import Path
import json, hashlib, re

ROOT = Path(__file__).resolve().parents[4]
BASE = Path(__file__).resolve().parent

def save(path, data):
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')

def finalize():
    runs={}
    for name in ['commit','workspace']:
        result=json.loads((BASE/f'screenshots/{name}/results.json').read_text())
        assert result['failed']==0 and result['passed']==1901 and len(result['captures'])==61
        log=(BASE/f'records/{name}_console.log').read_text()
        assert not any(x in log for x in ['SCRIPT ERROR','ERROR:','ObjectDB instances leaked','resources still in use'])
        runs[name]={'passed':result['passed'],'failed':result['failed'],'captures':len(result['captures']),'engine':result['engine'],'result':f'screenshots/{name}/results.json'}
    acceptance={'status':'passed controlled actual-Game card UI acceptance','date':'2026-10-20','scope':'60 cards at1280x720/960x540/1600x900; imported texture mipmaps; exact ID loading; text bounds; keyboard road selection, button awakening/fusion, resume, hover, four regular choices and missing-image fallback','runs':runs,'production_changes':['60 PNG imports with mipmaps/generate=true','scripts/ui/level_up_panel.gd: title24, description14, separation6 to prevent long-awakening footer overflow'],'unchanged':'gameplay data, effects, faith thresholds and combat logic not modified in this task','not_tested':['full combat playthrough','other hardware/OS/DPI','other locales'],'early_failures':'first isolated import temporarily lacked font cache until reimport; test direct-class preloading before autoload bootstrap fixed with deferred dynamic loads; test fallback ID corrected from thor to thor_skill; early long-net footer overflow fixed and all checks rerun; records retained','platform_diagnostic':'macOS IMKCFRunLoopWakeUpReliable mach-port line observed; no final script/resource errors or exit leak warnings'}
    save(BASE/'acceptance.json',acceptance)
    for name in ['taskL1_paths_2026-10-20','taskL2_fusions_2026-10-20']:
        root=ROOT/'assets/source'/name
        manifest=json.loads((root/'manifest.json').read_text())
        manifest['game_acceptance']={'status':acceptance['status'],'report':'../taskL1_paths_2026-10-20/integration_2026-10-20/acceptance.json','not_tested':acceptance['not_tested']}
        for item in manifest['assets']:
            item['code_integration']='verified: actual Game LevelUpPanel selects exact card-ID texture, no generic portrait or split fusion'
            item['godot_import_mipmap']='verified by actual imported Texture2D.get_image(): 10 mip levels; linear+mipmap UI filter'
            item['game_acceptance']='passed controlled actual-Game card UI at1280/960/1600; full playthrough not tested'
            imp=ROOT/(item['formal']+'.import')
            assert 'mipmaps/generate=true' in imp.read_text()
            item['godot_import']={'path':str(imp.relative_to(ROOT)),'sha256':hashlib.sha256(imp.read_bytes()).hexdigest()}
        save(root/'manifest.json',manifest)
        link='../taskL1_paths_2026-10-20/integration_2026-10-20/RESULTS.md'
        original=(root/'README.md').read_text()
        marker='<!-- Part L integration update -->'
        if marker not in original:
            original=marker+'\n\n**2026-10-20 接入更新：已通过实际 Game 卡牌 UI 受控验收。** 60张卡面已导入并验证真实10级mipmap，三种窗口宽度检查通过；修复黄金网觉醒长说明底部标签溢出。工作区与隔离提交副本各1901项0失败、61截图。详见[接入验收报告]('+link+')。下文“未接入／未测”是此前素材制作阶段记录；以本更新及manifest接入状态为准。未做完整战斗通关或其他硬件验收。\n\n'+original
            (root/'README.md').write_text(original)
        integration=(root/'integration.md').read_text()
        integration=integration.replace('代码接入、Godot 导入 mipmap、实际游戏验收：本任务未执行。','代码接入、真实Godot导入mipmap、实际Game卡牌UI受控验收已完成；完整战斗通关未测。')
        integration=integration.replace('| 未测 |','| 受控卡牌UI通过 |').replace('剩余问题：实际Godot导入mipmap和游戏UI未测。','剩余问题：本批卡牌接入没有已知阻塞；完整战斗通关、其他系统/DPI/语言未测。')
        if '## 实际接入与验收' not in integration:
            integration+='\n## 实际接入与验收\n\n60张PNG对应.import均启用mipmaps/generate=true；实际导入纹理逐张检查720×1200及10级mipmap。沿用已有_make_card精确ID优先解析，新增图能替换普通/通用觉醒/双神拼图回退。_card_art继续线性+mipmap。修复文字区：标题24px、说明14px、间隔6px，保留260×450当前卡框、原渐变、边框、悬停、数值与选择逻辑。\n\n实际Game中逐张渲染60张卡面，1280×720、960×540、1600×900；全部文字边界通过。键盘选道路、按钮选觉醒/融合、奖励队列结束后恢复、四选一及缺图回退通过。隔离提交副本与当前工作区各1901项0失败、61截图，详见[报告]('+link+')。测试专用存档，未接触用户存档。\n'
        (root/'integration.md').write_text(integration)
        gallery=(root/'gallery.html').read_text().replace('离线自检，未运行游戏；遮罩仅用于评估。','静态自检及实际Game卡牌UI受控验收通过；遮罩预览仅用于离线评估。')
        (root/'gallery.html').write_text(gallery)
    report='''# Part L 卡面接入与受控验收

2026-10-20。60张卡面完成实际导入与Game升级界面受控验收。素材生成与静态审核保留在L1/L2原目录，不覆盖原图或退稿。

## 改动

- 60份正式PNG导入配置开启mipmaps/generate=true，实际引擎读取每张纹理确认720×1200、10级mipmap。
- 既有_make_card已支持卡牌ID优先加载，本次核实全部60张命中独立卡面，融合不再走双神拼接。
- _card_art保留线性+mipmap过滤。实际卡框为260×450，保持现有覆盖裁幅、渐变、边框和悬停。
- 首次全量检查发现安德瓦利黄金觉醒的长说明导致底部标签溢出。将标题26→24、说明15→14、行间隔10→6；所有文字边界复测通过。
- 新增tools/test_card_art.gd，可在隔离副本或显式--ids-file/--output/--save-file参数下复现；不会使用默认个人存档。

## 结果

| 验证对象 | 检查 | 失败 | 实际渲染截图 |
| --- | ---: | ---: | ---: |
| 当前共享工作区 | 1901 | 0 | 61 |
| 已提交HEAD代码加本批改动的隔离候选 | 1901 | 0 | 61 |

每次覆盖60个ID×3种窗口宽度：1280×720、960×540、1600×900。包含导入纹理尺寸/mipmap、精确ID与非拼接、线性过滤、文字边界、正常四选一、悬停、键盘选道路、按钮选觉醒及融合、奖励完成恢复、普通画像与缺图回退。全部60张1280渲染卡面裁图已并排目检；另查看960最长说明、1600融合及四选一原截图。缩小后主要面孔/道路/融合主题可辨，无文字越框。

隔离候选排除了其他代理28份尚未提交的脚本改动，表明本次提交不依赖它们。正式工作区导入前后全部既有追踪文件哈希未变；本次生产代码只改level_up_panel.gd三行排版。原图60张正式SHA与素材manifest不变。

原始结果：[候选 results](screenshots/commit/results.json)、[工作区 results](screenshots/workspace/results.json)、[视觉记录](records/visual_review.json)、[总状态](acceptance.json)。截图各存于对应screenshots目录；测试输入哈希与控制台日志保留在records。早期失败日志、文字越框截图保留，没有删去失败证据。首次无导入缓存产生字体错误，第二次导入正常；测试引导脚本的autoload时机及回退ID错误已修复。最终无SCRIPT ERROR、资源加载错误或退出泄漏提示；macOS输入法mach-port诊断单列记录。

## 验收范围

这是实际Game卡牌界面的受控运行验收。没有执行完整战斗通关、所有语言、其他操作系统/硬件/DPI验收，不把这些标记通过。测试所有存档位于本批隔离目录，个人存档未更改。

## 发布及清理

Git只提交Part L素材/来源记录、60份导入参数、level_up_panel.gd和卡面验收工具；LICENSES仅纳入本批段落，其他代理的工作区内容保留。发布状态以records/publication.json为准；推送成功后只清理本批可重建runtime副本及哈希一致的外部重复生成图。原图、退稿、Prompt、参考、预览、mipmap、验证日志和截图保留；清理结果见records/cleanup_result.json。
'''
    (BASE/'RESULTS.md').write_text(report)
    print('Part L integration metadata updated from actual passing runs')

if __name__=='__main__':finalize()
