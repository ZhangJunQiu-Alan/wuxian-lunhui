# K1：耶梦加得动作与复用交付

3张正式PNG、11帧：head_idle 4帧8fps循环；head_windup 3帧8fps单次末帧保持；head_attack 4帧16fps单次。新文件只发布此前不存在的三个动作，既有头/身/尾不覆盖。

实际使用已批准内置image_gen生成3张原图，实际Prompt、输入图、工具结果及SHA保留records/originals/references；无失败生成，全部v01。Pillow只固定格裁排、最近邻128、原图48色表/二值alpha规范化和预览检查，没有程序绘制新动作。三条动画共6份原速/8fps慢放GIF；GIF末帧600ms只是检查停顿，不是游戏动作延时。

自检见records/final_audit.json。所有帧尺寸、alpha、颜色、非颈部边距、独立帧、颈口连通与GIF像素核对通过。已实际查看逐帧/静态参考对照、直线接缝、独立Godot R240/R128曲线和毒息叠加。身体/尾巴原图不变，采用连续UV带；body_repeat_4x4仅为已有身体重复纹理检查，不是新地面图。

独立Godot素材场景实际保存22张截图，不是实际Game场景、不代表第三关已接入。原代码、场景、docs、根项目设置未改；没有Git提交推送。平台输入法mach-port诊断保留，未混称GDScript错误。

毒雾喷吐/持续区域、撞击、托尔援助复用既有资源和程序表现，未重复做图；动作本体不含毒雾。毒息纹理是薄雾，实际危险边界必须保留清楚的程序预警，不能由alpha猜范围。实际判伤、仅蛇头可被瞄准、90秒命运条件、350怪场景及第三关通关均未测。

逐文件接入见integration.md；规范源为../taskK_contract_2026-10-20/contract.json，冻结的是资产接口，不是已实现玩法。图库gallery.html，原图originals/，批准副本approved/，帧条正式位于assets/sprites/bosses/。
