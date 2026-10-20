# H6 制作交付

7 个 PNG 已复制到正式目录。逐帧静态检查已做，原速和8fps慢放GIF已生成并解码核对；浏览器播放检查另记，不冒充游戏实测。

制作：完成；文件与美术自检：通过；代码接入：已执行；游戏验收：已完成受控技能验证，完整手动通关未测。

## 逐文件实际观察

- `assets/sprites/effects/bosses/hel_life_ground.png`：已看128px与4×4：很淡的灰绿细纹、标记间透明，无浓绿地毯/中心徽章；未见明显直线硬接缝。角色叠加和两侧对照另见range预览。
- `assets/sprites/effects/bosses/hel_death_ground.png`：已看128px与4×4：很淡的灰紫细裂纹、间隙透明，无不透明底板；低亮度接近生侧，不替代死亡领域判伤。
- `assets/sprites/effects/bosses/hel_domain_edge.png`：已看4格：窄灰紫领域边界水平流动，外侧向上，左右源端口相同，不烘焙完整圆；上下透明，供动态半径圆周裁切。
- `assets/sprites/effects/bosses/hel_shift.png`：已看4格：中性灰绿/灰紫细粒聚拢、竖向分散、两侧烟丝和低密度消散，没有身体或实心传送门，允许代码按进出侧染色。
- `assets/sprites/effects/bosses/hel_heal.png`：已看4格：淡灰绿流光向上，细丝与颗粒稀薄；没有加号/心形/金羽/苹果，不和玩家拾取回复造型混淆。
- `assets/sprites/effects/bosses/hel_army_summon.png`：已看4格：薄冥土裂隙、短暂亮边与两侧低雾、裂隙变暗和零星余粒，无亡者身体或永久大地坑。
- `assets/sprites/effects/bosses/hel_board_ship.png`：已看4格：两侧稀薄冥雾柱升起/裂散/消退，中间大幅留白，无船体或全屏浓雾；后续须在实际船帆与弹幕叠加场景确认。

## 来源与限制

使用已批准的内置 image_gen，只上传本项目参考图。原图、失败稿、实际提示词和输入路径存 originals/ 与 records/。商用依据沿用项目已核验的 OpenAI 输出条款：https://openai.com/policies/terms-of-use/ 。Pillow MIT-CMU 仅用于原像素裁排、统一尺度、色表与透明、预览和检查，未用 Python 重画角色或特效。

原图工具未提供公开生成会话链接，保留实际返回路径和工具记录，不伪造URL。

本批新特效已接入；见 integration.md 与后续运行报告。没有执行 Godot 测试、修改代码/场景/项目设置或 Git 提交推送。


## 浏览器与范围检查边界

Chrome实际打开的抽样GIF和观察见 `records/browser_review.json`。所有帧条已逐格看原图与1倍/4倍深色底，GIF已解码核对像素和平均时序；这不等于逐条浏览器长时间播放或Godot游戏验收。范围合成只使用项目地面/角色与脚本参数，不能据此宣称游戏判伤或节点性能已验收。

## 代码接入收尾（2026-10-19，后续授权）

用户本轮授权同时完成素材与代码。当前正式PNG全部哈希不变，代码已接入，Godot实际Game场景受控触发与画面检查完成。最终572项专项、997项既有回归均无断言失败；40张实际场景截图和短时压力测试见[运行报告](../taskH0_critical_2026-10-19/integration_2026-10-19/README.md)。制作阶段的未接入/未实测叙述保留为历史，不代表当前状态。完整关卡手动通关、长期平衡和其他设备表现未测，不扩大验收范围。未接管G6/I/J/K/L，未提交推送。
