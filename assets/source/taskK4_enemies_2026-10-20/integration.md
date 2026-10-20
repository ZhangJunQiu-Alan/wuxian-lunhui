# K4 接入交接

本轮只制作assets，现EnemyDB尚无fire_giant／frost_veteran／wolf_berserker注册，不能说放入PNG即已生成。需集成Agent新增数据和行为，范围仅世界观第三关既定敌人；保留亡者复用。

|正式路径（assets/sprites/）|单帧／帧／播放|目标脚本／事件|
|---|---|---|
|enemies/fire_giant_move.png|96×96／6／8fps循环|EnemyDB.fire_giant+Enemy的SpriteVisual move|
|enemies/fire_giant_attack.png|96×96／4／16fps单次|同上attack；zero-based2近战接触姿势|
|enemies/frost_veteran_move.png|96×96／6／8fps循环|EnemyDB.frost_veteran+move|
|enemies/frost_veteran_attack.png|96×96／4／16fps单次|同上attack；zero-based2挥斧接触|
|enemies/frost_veteran_charge.png|96×96／4／8fps循环|新增charge状态明确映射，控制器负责冲锋位移／碰撞|
|enemies/frost_veteran_shield.png|96×96／3／8fps单次末帧保持|新增shield状态，zero-based2举盾保持；伤害减免方向仍读同一面向|
|enemies/wolf_berserker.png|64×64／1|新普通敌人静态回退，披狼皮的人类，不能误用狼AI或四足动画|
|enemies/wolf_berserker_move.png|64×64／6／8fps循环|同上move|
|enemies/wolf_berserker_attack.png|64×64／4／16fps单次|同上attack，zero-based2短斧接触|
|enemies/wolf_berserker_rage.png|64×64／3／8fps单次末帧保持|新增低血量狂暴事件与映射；姿势不代替触发条件／攻速变化|
|effects/bosses/fire_giant_explosion.png|96×96／4／16fps单次|新增火巨人死亡事件，只产生一次爆炸反馈，不画尸体；锚(48,48)|

全部右向3/4，最近邻整数1倍。身体脚锚：巨人(48,94)，人类(32,62)；镜像同步更新斧接触点和前方盾向，不围绕纹理中心误算身体落地。SpriteVisual当前正方帧加载可复用，但charge/shield/rage需显式加载和state_actions，不能假定会自动播放。角色全帧groundbaseline固定，冲锋时低姿势是弯腿与前倾，不能用控制器再额外缩小。

前方盾只覆盖控制器给定方向扇区，贴图没有360泡；保留背后可攻击线索。举盾未结束时是否可移动／蓄力由玩法定义，不靠动画文件新增行为。狂暴通过现有低血量条件单次进入，人物仍是人类，不新增变身或不在任务内的奖励。

死亡反馈：撤销敌人可瞄准／碰撞注册后在原死亡中心发一次爆炸，实际爆炸半径／预警／伤害由同一控制器几何负责，贴图缩放裁切到该区域；持续残火复用effects/gods/loki_fire_patch.png，不能继承玩家洛基技能归属。普通死亡碎片复用effects/death_shards.png，冰裂复用effects/bosses/hrym_ice_break.png；避免同一次死亡两套重复爆炸。集中FX／数量上限沿项目现有方案，不为每片火星建节点。

dead.png、dead_move.png、dead_attack.png继续原64px普通亡者，不复制到新目录；巨人原静态不覆盖。第三关生成表和密度接K0地图布局，但本轮没有新增敌人实际生成／AI实现。

独立44张截图只核对素材合成和方向，不覆盖真实近战伤害、冲锋、前盾减伤／绕背、低血量狂暴、死亡爆炸与残火判伤、350敌人压力、掉落或关卡平衡，均待集成后测。未运行实际第三关，不标游戏验收通过。

残火色相补充：loki_fire_patch原色偏绿，不直接用原色。复用纹理时只对该实例做HSV色相固定0.04（约橙红）、保留饱和度／明度／alpha；正式原PNG不改。独立预览已采用这项材质等效转换，生产需用同等shader／纹理实例，不能全局改洛基火焰。
