# K5 接入契约

沿用 `assets/source/taskK0_vigrid_plan_2026-10-20/layout.json` 与 `assets/source/taskK_contract_2026-10-20/K5_reuse_addendum_v1.3.json`。原contract不改写。

1. 地图5120×5120、边界256、可走矩形[-2304,-2304,4608,4608]。出生(0,0)清空R384，中央R1280不放固定障碍；道路256宽，环路及五地标坐标从K0布局读取。预览map_context只是局部陈列，不是缩小后的完整地图。
2. 6块现有64地面通过地区权重组合；裂岩熔浆画面与伤害分离，装饰本身无伤害。地面为ground/vigrid，5旧物件为props/vigrid。脚印贴花放在巨人遗迹区域附近，中心锚点32,32，无碰撞、无额外任务。不要覆盖原地块或复制一套同内容贴图。
3. 草地过渡借用 `ground/midgard/path_edge_*.png` 的二值alpha，颜色来自vigrid/burnt_grass。MapLayer._make_edges可按遮罩派生；但现有_ready仅加载当前ground_dir，因此新VigridMap必须先明确加载12个跨目录遮罩，才能调用_make_edges。不能只把目录指向vigrid便声称过渡可用。records/reused_masks含12路径/hash，references/runtime_derived_*仅QA派生品，不作为新增正式素材。
4. NW/NE/SW/SE角点位为1/2/4/8；16组合见terrain_audit。12=n,5=e,3=s,10=w,4=outer_ne,8=outer_nw,1=outer_se,2=outer_sw,13=inner_ne,14=inner_nw,7=inner_se,11=inner_sw；9为outer_se+outer_nw，6为outer_sw+outer_ne，0无草、15全草。
5. 边界复用 `effects/bosses/surtr_firewall_band.png` 64×64×4/8fps。纹理上半部向外、下半部朝内透明，四边与四转角构成同一闭合路径，碰撞使用权威可走矩形。preview_project/render_boundary.gd只验证此纹理可沿连续路径连接，圆角是视觉带，不改变K0可走矩形。场景接入时直边UV按弧长推进、拐角共享顶点/法线；视觉与碰撞的接触误差须在实际相机检查。不可从火焰alpha反推伤害区域。
6. 环境火焰复用旧loki_fire_patch，实例/着色器HSV色相置0.04，保留S/V/A；不能仅RGB乘色把绿火变黄，也不能覆盖旧神术PNG。装饰火无伤害，危险火由另一个控制器明确标记。稀疏火焰声复用，不添加常驻环境声循环。
7. `assets/sprites/effects/environment/vigrid/distant_battle.png` 横排4帧，512×128，8fps循环，锚点左上(0,0)。北侧远景带世界矩形[-768,-2480,1536,128]，并排3段，起点x=-768,-256,256。0.5倍演员已烘焙，不要再缩放条带。禁止碰撞/伤害/Enemy组/索引和自动锁定，远景单独绘制层与clip范围；现有相机边缘露出效果仍待接入验证。色调处理已烘焙，避免二次灰化。
8. 神明周期援助复用已有八神特效及K1–3专门援助；不凭此新增八套神明人物。周期、附近判据、不同神实际效果目前没有完整玩法定义，交由代码/策划冻结。托尔救援、维达、弗雷的特殊条件遵循原contract，不能用一般周期援助触发改写命运。

文件检查、独立渲染已完成；正式地图代码、障碍密度、相机、实际伤害与第三关完整运行未验收。
