from pathlib import Path
from shutil import copyfileobj

from catalog import BASE, ROOT, collect, sha


def publish():
    data = collect()
    expected = {'armor': 40, 'status': 10, 'effects': 10, 'actors': 2}
    for group, count in expected.items():
        assert len([f for f in data['files'] if f['kind']==group]) == count, group
    assert all(s['concept'] for s in data['sets'])
    for file in data['files']:
        target = ROOT/file['runtime']
        if target.exists() and sha(target)!=file['sha256']:
            raise FileExistsError(f'已有资源，保留原文件 {target}')
    for file in data['files']:
        target = ROOT/file['runtime']
        if target.exists():
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        with (BASE/file['file']).open('rb') as source, target.open('xb') as dest:
            copyfileobj(source,dest)

    base = '''# S–SET 套装防具接入

## 物品与状态图标

正式图标放入 `assets/sprites/items/armor/`。部位依次为 `helm`、`chest`、`legs`、`boots`。第二轮返修图使用 `_r2.png` 后缀，以表和 manifest 的路径为准。装备掉地及背包使用同一张 32×32 图。底框和光柱由装备系统绘制。

套装集齐四件后，血条旁使用 `assets/sprites/ui/sets/<套装id>.png`。12×12，中心锚点 (6,6)，近邻采样。猛志层数、龙鳞冷却和无瑕变灰由代码控制。

| 套装 | 掉落 | 头盔 | 胸甲 | 护腿 | 鞋子 | 血条图标 |
| --- | --- | --- | --- | --- | --- | --- |
'''
    rows = []
    for kit in data['sets']:
        items = [f"`{Path(i['asset']['runtime']).name}` {i['name']}" for i in kit['items']]
        rows.append('| '+' | '.join([kit['name'],kit['area'],*items,f"`{kit['id']}.png`"])+' |')
    base += '\n'.join(rows)+'\n\n'
    base += '''## 特效帧条

正式目录 `assets/sprites/effects/sets/`。帧从左至右，坐标以每帧左上为原点，锚点是贴到世界位置的整数像素。按 1× 最近邻采样，不自动缩放、旋转或镜像。保持帧条本身的透明区域。

| 文件 | 触发 | 每帧尺寸 | 帧数 / fps | 播放 | 锚点 | 图层 |
| --- | --- | --- | --- | --- | --- | --- |
'''
    rows=[]
    for f in data['files']:
        if f['kind'] != 'effects':
            continue
        size='×'.join(map(str,f['frame_size']))
        anchor=', '.join(map(str,f['anchor']))
        play='循环' if f['play']=='loop' else '单次'
        rows.append('| '+' | '.join([f"`{Path(f['runtime']).name}`",f['event'],size,f"{f['frames']} / {f['fps']}",play,f"({anchor})",f['layer']])+' |')
    base += '\n'.join(rows)+'\n\n'
    base += '''- 荆棘反刺以玩家位置为圆心，第四帧刺尖达到 120 px。攻击者身上的刺用另一条帧条，锚点放在目标地面投影处。
- 黄风沙尘暴三条帧条共用 (48, 62) 锚点。生成时播放卷起，随 4 秒效果计时播放循环。伤害结束后转消散，地面中心始终对齐。三段素材均是无地环的风柱。48 px 是玩法判定半径，预览只在手动打开判定开关时显示。帧条整体绘制在地面特效层。
- 屠龙者两条身体叠加层使用 64×64 角色帧中心。「龙鳞已备」只在胸腰与身侧显示。猛志叠层与莲花绽放在角色身体后方绘制。
- 表内素材已按任务尺寸输出。正式装备系统仍需接入装备选择、伤害和冷却；本批的 Godot 图形验证只运行独立画面。
'''
    base += '''
## 英灵分身形象

`assets/sprites/allies/` 下两张帧条为独立、空手的英灵本体。每帧 64×64，默认朝右，脚底点 (32, 55)。`valhalla_ring_r2.png` 的 (32, 19) 对齐这个脚底点。环在身后。角色朝左时，镜像身体和持武器挂点，光环保持原朝向。

| 帧条 | 帧数 / fps | 播放 | 主手挂点 |
| --- | --- | --- | --- |
'''
    for action, actor in data['guardian'].items():
        coords = ' → '.join(f'({x},{y})' for x,y in actor['hand'])
        loop = '循环' if actor['play']=='loop' else '单次'
        base += f"| `{Path(actor['runtime']).name}` | {actor['frames']} / {actor['fps']} | {loop} | {coords} |\n"
    base += '''
挂点和建议角度也逐帧记录在 manifest 的 `guardian` 条目。英灵仍按原设计使用玩家当前基础武器。正式接入时将武器挂在英灵手上。像素素材和独立预览已交付，攻击逻辑与伤害数值由装备系统接入。
'''
    (BASE/'integration.md').write_text(base)


if __name__=='__main__':
    publish()
