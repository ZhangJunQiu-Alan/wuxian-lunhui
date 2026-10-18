# J6 素材交付

正式交付 1 PNG。实际原图、Prompt、参考图、候选、退回记录、approved与逐项自检均保留。本轮只制作assets，未修改代码、场景、docs、项目配置或导入设置，未提交或推送Git。

本轮实际检查：1倍总览、所有4倍逐帧、RGBA/精确尺寸/共享色表/alpha/2像素边距/独立帧、GIF逐帧像素往返与平均帧率。实体基线与特效中心留白另测。原速16fps的GIF用60/70ms组合表示平均16fps，8fps用120/130ms组合表示平均8fps；PNG及manifest为运行合同，GIF为预览。

浏览器播放因组件缺失及Work禁用未测，未更改权限。未运行Godot或游戏；遮挡、同屏性能、真实判伤边界与资源生命周期未测。静态素材无播放要求；本任务无地块，4×4平铺不适用。

[integration.md](integration.md)列逐文件函数、坐标、缩放、旋转、遮罩、替换内容与保留逻辑。[manifest.json](manifest.json)列来源/授权/输入与正式哈希。[gallery.html](gallery.html)提供逐帧、原速与慢放播放。[自检](records/self_audit.json)只代表离线资产检查。

生成工具为OpenAI内置image_gen（模型身份未暴露），许可依据[OpenAI条款](https://openai.com/policies/terms-of-use/)，详细记入项目assets/LICENSES.md。Pillow仅裁排、最近邻尺度、颜色/alpha规格处理和预览，没有用程序重画角色。


## 2026-10-19 代码接入与受控运行验收更新

用户追加授权后已完成本任务代码接入；全部14项在独立提交副本中完成626项专项检查和46张实际Godot Game截图复核，工作区现有战斗回归997项通过。正式PNG哈希未变。完整手动通关、长期平衡及其他设备未测。以[本轮验收记录](../taskJ1_dimension_2026-10-19/integration_2026-10-19/README.md)为当前状态；上文制作阶段的“尚未接入/未运行”保留为历史记录，不代表当前仍未接入。
