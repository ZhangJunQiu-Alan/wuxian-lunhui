# L1：道路及道路觉醒卡面：接入交接

文件交付 48/48。代码接入、真实Godot导入mipmap、实际Game卡牌UI受控验收已完成；完整战斗通关未测。

目标：`scripts/ui/level_up_panel.gd` 的 `_make_card()`（卡牌ID优先解析，当前140行）与 `_card_art()`（当前265行纹理展示）；`ART_DIR` 是正式目录。精确ID应优先于既有普通/觉醒画像或融合双神拼图回退。无需改变升级数据库、神术效果、数值或卡牌文字。

逐张保持 UI 正立、不旋转；720×1200 的中心为(360,600)，展示约260×433，保持3:5比例。按当前UI使用线性+mipmap过滤，并在新PNG导入中启用 `mipmaps/generate=true`，由接入者修改和验证导入设置。下45%渐变文字遮罩保持现有逻辑，不把离线遮罩图当正式纹理；左右40px安全区用于保护关键结构。

离线 mipmap 不会被当前单PNG解析器自动使用，也不替代 Godot 导入mipmap。请在实际卡牌选择界面逐项触发、检查缩放锯齿/清晰度/文字覆盖/ID回退/不同窗口宽度后，单独记录接入和游戏验收。

| 卡牌ID | 正式路径 | 替换的回退外观 | 纹理坐标/旋转/遮罩 | 接入状态 |
| --- | --- | --- | --- | --- |
| `thor_mjolnir` | `assets/sprites/cards/thor_mjolnir.png` | 通用神明普通画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `thor_mjolnir_awaken` | `assets/sprites/cards/thor_mjolnir_awaken.png` | 通用神明觉醒画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `thor_cloud` | `assets/sprites/cards/thor_cloud.png` | 通用神明普通画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `thor_cloud_awaken` | `assets/sprites/cards/thor_cloud_awaken.png` | 通用神明觉醒画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `thor_static` | `assets/sprites/cards/thor_static.png` | 通用神明普通画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `thor_static_awaken` | `assets/sprites/cards/thor_static_awaken.png` | 通用神明觉醒画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `odin_gungnir` | `assets/sprites/cards/odin_gungnir.png` | 通用神明普通画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `odin_gungnir_awaken` | `assets/sprites/cards/odin_gungnir_awaken.png` | 通用神明觉醒画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `odin_ravens` | `assets/sprites/cards/odin_ravens.png` | 通用神明普通画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `odin_ravens_awaken` | `assets/sprites/cards/odin_ravens_awaken.png` | 通用神明觉醒画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `odin_nights` | `assets/sprites/cards/odin_nights.png` | 通用神明普通画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `odin_nights_awaken` | `assets/sprites/cards/odin_nights_awaken.png` | 通用神明觉醒画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `loki_wolf` | `assets/sprites/cards/loki_wolf.png` | 通用神明普通画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `loki_wolf_awaken` | `assets/sprites/cards/loki_wolf_awaken.png` | 通用神明觉醒画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `loki_shifter` | `assets/sprites/cards/loki_shifter.png` | 通用神明普通画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `loki_shifter_awaken` | `assets/sprites/cards/loki_shifter_awaken.png` | 通用神明觉醒画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `loki_road` | `assets/sprites/cards/loki_road.png` | 通用神明普通画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `loki_road_awaken` | `assets/sprites/cards/loki_road_awaken.png` | 通用神明觉醒画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `freyja_hawk` | `assets/sprites/cards/freyja_hawk.png` | 通用神明普通画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `freyja_hawk_awaken` | `assets/sprites/cards/freyja_hawk_awaken.png` | 通用神明觉醒画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `freyja_brisingamen` | `assets/sprites/cards/freyja_brisingamen.png` | 通用神明普通画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `freyja_brisingamen_awaken` | `assets/sprites/cards/freyja_brisingamen_awaken.png` | 通用神明觉醒画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `freyja_cats` | `assets/sprites/cards/freyja_cats.png` | 通用神明普通画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `freyja_cats_awaken` | `assets/sprites/cards/freyja_cats_awaken.png` | 通用神明觉醒画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `baldr_spear` | `assets/sprites/cards/baldr_spear.png` | 通用神明普通画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `baldr_spear_awaken` | `assets/sprites/cards/baldr_spear_awaken.png` | 通用神明觉醒画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `baldr_daylight` | `assets/sprites/cards/baldr_daylight.png` | 通用神明普通画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `baldr_daylight_awaken` | `assets/sprites/cards/baldr_daylight_awaken.png` | 通用神明觉醒画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `baldr_oath` | `assets/sprites/cards/baldr_oath.png` | 通用神明普通画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `baldr_oath_awaken` | `assets/sprites/cards/baldr_oath_awaken.png` | 通用神明觉醒画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `ran_waves` | `assets/sprites/cards/ran_waves.png` | 通用神明普通画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `ran_waves_awaken` | `assets/sprites/cards/ran_waves_awaken.png` | 通用神明觉醒画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `ran_andvari` | `assets/sprites/cards/ran_andvari.png` | 通用神明普通画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `ran_andvari_awaken` | `assets/sprites/cards/ran_andvari_awaken.png` | 通用神明觉醒画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `ran_drowned` | `assets/sprites/cards/ran_drowned.png` | 通用神明普通画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `ran_drowned_awaken` | `assets/sprites/cards/ran_drowned_awaken.png` | 通用神明觉醒画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `freyr_boar` | `assets/sprites/cards/freyr_boar.png` | 通用神明普通画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `freyr_boar_awaken` | `assets/sprites/cards/freyr_boar_awaken.png` | 通用神明觉醒画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `freyr_field` | `assets/sprites/cards/freyr_field.png` | 通用神明普通画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `freyr_field_awaken` | `assets/sprites/cards/freyr_field_awaken.png` | 通用神明觉醒画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `freyr_sun` | `assets/sprites/cards/freyr_sun.png` | 通用神明普通画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `freyr_sun_awaken` | `assets/sprites/cards/freyr_sun_awaken.png` | 通用神明觉醒画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `skadi_hunter` | `assets/sprites/cards/skadi_hunter.png` | 通用神明普通画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `skadi_hunter_awaken` | `assets/sprites/cards/skadi_hunter_awaken.png` | 通用神明觉醒画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `skadi_snowshoes` | `assets/sprites/cards/skadi_snowshoes.png` | 通用神明普通画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `skadi_snowshoes_awaken` | `assets/sprites/cards/skadi_snowshoes_awaken.png` | 通用神明觉醒画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `skadi_winter` | `assets/sprites/cards/skadi_winter.png` | 通用神明普通画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |
| `skadi_winter_awaken` | `assets/sprites/cards/skadi_winter_awaken.png` | 通用神明觉醒画像 | 中心360,600；0°；260×433；下45%遮罩 | 受控卡牌UI通过 |

剩余问题：本批卡牌接入没有已知阻塞；完整战斗通关、其他系统/DPI/语言未测。

## 实际接入与验收

60张PNG对应.import均启用mipmaps/generate=true；实际导入纹理逐张检查720×1200及10级mipmap。沿用已有_make_card精确ID优先解析，新增图能替换普通/通用觉醒/双神拼图回退。_card_art继续线性+mipmap。修复文字区：标题24px、说明14px、间隔6px，保留260×450当前卡框、原渐变、边框、悬停、数值与选择逻辑。

实际Game中逐张渲染60张卡面，1280×720、960×540、1600×900；全部文字边界通过。键盘选道路、按钮选觉醒/融合、奖励队列结束后恢复、四选一及缺图回退通过。隔离提交副本与当前工作区各1901项0失败、61截图，详见[报告](../taskL1_paths_2026-10-20/integration_2026-10-20/RESULTS.md)。测试专用存档，未接触用户存档。
