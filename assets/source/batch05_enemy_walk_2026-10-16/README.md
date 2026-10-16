# 第5批：第1关7种敌人行走

状态：第1关7/7项美术自检完成，待代码代理接入Godot并游戏验收。第2/3关另外7种敌人未在本次范围内制作。

本任务仅制作第1关draugr、wolf、ice_spirit、frost_giant、draugr_elite、ice_spirit_elite、frost_giant_elite的move横向帧条。两种巨人96×96，其余64×64；四种双足敌人6帧、冬狼4帧、两种精魂4帧，均8fps循环，共36帧。冬狼4帧符合任务书4～6帧范围，明确呈现前后两组对角腿交替。

仅使用现有敌人PNG作为角色参考；内置image_gen生成已获用户批准，Pillow用于尺寸/透明/既有RGB色板/整帧定位与预览，另绘制原创姿势线稿作为生成参考，没有在Python重画游戏精灵。实际Prompt和15张生成原图保留，候选不代表通过。四周至少2px，已在深色背景#121721作1倍/4倍全帧与Chrome播放、暂停逐帧审核；双足/四足可看出腿部交替，精魂的下部尾带实际形变，未采用仅整身上下移动的方案。

制作顺序与逐项状态见records/production_plan.json。最终只把通过的动画放入assets/sprites/enemies，并备份被覆盖旧文件。4×4地块平铺对敌人动画不适用。未运行Godot，未修改代码，未提交或推送Git。

## 最终文件

| 文件（assets/sprites/enemies/） | 帧条尺寸 | 帧数 | 颜色数 | 脚底/尾端基线 |
| --- | --- | --- | --- | --- |
| draugr_elite_move.png | 384×64 | 6 | 41 | y60 |
| draugr_move.png | 384×64 | 6 | 46 | y59 |
| frost_giant_elite_move.png | 576×96 | 6 | 48 | y93 |
| frost_giant_move.png | 576×96 | 6 | 48 | y93 |
| ice_spirit_elite_move.png | 256×64 | 4 | 47 | y59 |
| ice_spirit_move.png | 256×64 | 4 | 48 | y59 |
| wolf_move.png | 256×64 | 4 | 41 | y54 |

## 实际检查与交付

- records/final_audit.json已核对7个sprites成品、候选、approved快照SHA256完全相同，RGBA且alpha仅0/255、尺寸、全部帧2px边距及一致基线；每条动画颜色均来自对应原始精灵RGB固定色板，与第7批攻击共用。
- 7份4倍预览GIF均循环、8fps，120/130ms交替计时，4帧500ms、6帧750ms。GIF逐帧RGB与对应PNG在#121721背景上的4倍最近邻合成逐像素相同，无GIF另行改色或漏帧。
- 逐帧语义检查见records/review_decisions.json：膝踝/四肢交替、头部/体型/装备一致，精魂冠部保留、下部冰带改变弯曲。Chrome实际查看了8fps及暂停相位。游戏内测试尚未做。
- 冬狼采用统一等比尺度适配整个轮廓，4帧轮廓高42px、y13～54；原静态46px、y9～54。未逐帧改变尺度。原站姿与1倍/2倍行走对照见previews/wolf_v04_reference_compare.png；行走姿态略低，游戏中静态/行走/攻击切换仍需代码代理验收。
- 原图originals/、候选candidates/、通过快照approved/、预览previews/、Prompt与生成记录records/generation_*.json完整保存。旧准备色板和未采用48color准备PNG在backups/，权威参考为references/<id>.png。
- gallery.html含1倍/4倍、7份GIF和总览；records/motion_review.html可播放、暂停、逐帧；人物/敌人动画不适用地块4×4平铺检查。

## 退回与修正

普通精魂v01多画过长上背飘带，重生v02；精英尸鬼v01左边距1px，整帧统一右移1px采用v02；普通巨人v01第五帧右边距1px，整帧统一左移1px采用v02；精英巨人v01装备跨度过宽、左侧裁切，重新生成收拢肘部与盾牌v02，维持90px高度。冬狼v01/v02近侧前腿总在前方，且边距失败；分前后半循环后得到正确换腿，但初版双帧短腿/过宽，保留为失败参考；重新生成4帧原图后采用统一等比留边的v04。失败记录见candidates.json和wolf_half_v0*_rejected.json。一次无效参考路径派发未生成可验收图，已纠正，记录见path_failure_corrected.json。

当前7个最终文件没有未解决的美术自检失败。接入Godot、静态/攻击切换、同屏效果及移速匹配由代码代理实测；其他关卡7种敌人本次未做。未修改游戏代码、未执行Git提交/推送。
