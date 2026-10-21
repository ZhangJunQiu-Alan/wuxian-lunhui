class_name VigridTuning
## 第三关「最后之战」的集中数值表
## 世界观和 K 素材契约冻结的是规则（只有蛇头能受伤、托尔 90 秒、通道至少 64、64 格安全区、三个命运条件……），
## 冷却、伤害、逃脱时长、援助频率这些数字没有定稿。这里每一项都是【暂定】值，理由和待确认项见
## assets/source/taskK_code_integration_2026-10-20/design_decisions.md，改数值只改这里

# ———— 冻结的规则（来自世界观 / K 契约，不是暂定值）————
const THOR_DEADLINE := 90.0          # 托尔：巨蛇本场遭遇的未暂停时长 <= 90 秒
const MAW_GAP_MIN := 64.0            # 芬里尔吸引 / 逃脱阶段，上下颚之间给活动玩家留的通道
const FINAL_CELL := 64.0             # 终焉之火的格子，原点 (0,0)，格坐标 floor(world / 64)
const PHASE_FIREWALL := 0.6          # 苏尔特 60% 血量：九界燃烧（只触发一次）
const PHASE_FINAL := 0.25            # 苏尔特 25% 血量：终焉之火（只触发一次）

# ———— 耶梦加得【暂定】————
const SERPENT_HP := 3000.0 / (1.0 + 180.0 / 100.0)  # 基础值：03:00 出场时正好 3000（Boss 血量按 LevelDB NORSE_3 的 boss_hp_growth 100 随时间成长）
const SERPENT_CONTACT := 28.0
const SERPENT_SQUARE := 2048.0       # 环绕路径：玩家为中心的 2048 方区与 bounds 内缩 96 求交（契约）
const SERPENT_INSET := 96.0
const SERPENT_CORNER := 160.0        # 圆角（契约要求至少 128）
const SERPENT_SPEED := 230.0         # 蛇头沿路径游动的速度
const SERPENT_BODY := 2300.0         # 蛇身长度（不含头尾）
const SERPENT_BODY_HALF := 28.0      # 蛇身接触判定的半宽（贴图中线 y=30，上 30 下 34）
const SERPENT_BODY_DAMAGE := 24.0
const SERPENT_BODY_SHOVE := 520.0    # 撞飞的初速度
const SERPENT_BODY_COOLDOWN := 0.9
const SERPENT_CONTRACT_EVERY := 22.0 # 每隔多久收紧一次
const SERPENT_CONTRACT_STEP := 128.0 # 每次每边内缩（契约要求 <= 128）
const SERPENT_CONTRACT_TIME := 3.0   # 收紧过渡时长
const SERPENT_MIN_SIZE := 1024.0     # 收紧到这么大就不再收
const SERPENT_COIL_TIME := 3.8       # 两次毒息之间游动多久
const BREATH_WINDUP := 1.0
const BREATH_RANGE := 420.0
const BREATH_HALF := 0.55            # 扇形半角（弧度）
const BREATH_DAMAGE := 26.0
const BREATH_TURN := 1.2             # 吐息时蛇头最多偏离路径切线多少（弧度）
const MIST_LIFE := 5.0               # 毒雾留在地上的时间
const MIST_DPS := 12.0
const BREATH_LEAD := 0.35            # 毒息按玩家这么多秒后的位置瞄准
# 出招选择：游完一段后，玩家离蛇头近就喷毒息，远就猛噬；同一招不连出 3 次
const LUNGE_WINDUP := 0.9            # 猛噬：昂头瞄准，最后 LUNGE_LOCK 秒锁定方向
const LUNGE_LOCK := 0.3
const LUNGE_SPEED := 1400.0
const LUNGE_RANGE := 900.0           # 最远冲出多远（落点收在地图内缩 64 以内）
const LUNGE_MIN := 240.0
const LUNGE_HALF := 44.0             # 冲刺路线半宽：蛇头半径 40 + 余量；预警长条和命中用同一个宽度
const LUNGE_DAMAGE := 30.0
const LUNGE_SHOVE := 600.0
const LUNGE_STUCK := 1.6             # 咬进地里拔不出来：输出窗口
const LUNGE_WEAK_MULT := 1.5         # 咬进地里时受到的伤害倍率
const LUNGE_RETRACT := 0.6           # 缩回环绕路径
const SPIT_COUNT := 3                # 毒液弹：游动途中不停下，朝玩家预判位置吐出几团
const SPIT_LEAD := 0.6
const SPIT_SPREAD := 170.0           # 第一团正对预判点，其余散在这一圈上（比两倍落点半径大，中间留缝）
const SPIT_FLIGHT := 0.9             # 飞行时间 = 落点预警时间
const SPIT_STAGGER := 0.12
const SPIT_RADIUS := 70.0
const SPIT_DAMAGE := 18.0
const SPIT_MIST_LIFE := 3.0          # 落点留下的小片毒雾
const SERPENT_RAGE_AT := 0.5         # 血量低于一半：狂怒（只触发一次）
const SERPENT_RAGE_SPEED := 1.3      # 游速倍率
const SPIT_COUNT_RAGE := 5
const LUNGE_MIST_RADIUS := 110.0     # 狂怒后猛噬的落点留下毒雾

# ———— 芬里尔【暂定】————
const WOLF_HP := 5000.0 / (1.0 + 360.0 / 100.0)     # 06:00 出场时正好 5000
const WOLF_CONTACT := 26.0
const WOLF_CHASE := 1.8
const BITE_WINDUP := 0.55
const BITE_LUNGE := 260.0
const BITE_DAMAGE := 30.0
const MAW_WINDUP := 0.7
const MAW_ESCAPE := 2.6              # 逃脱窗口：从开始吸引到提交吞噬
const MAW_GAP := 112.0               # 吸引阶段的实际张口（>= MAW_GAP_MIN）
const MAW_PULL := 130.0              # 吸引速度，低于玩家基础移速 220，跑得掉
const MAW_ATTRACT_RADIUS := 460.0
const MAW_ATTRACT_HALF := 0.7
const MAW_FATAL := Rect2(40, -56, 160, 112)  # 巨口局部坐标（铰点为原点，x 沿轴线）的致死区；高度跟随 MAW_GAP
const MAW_FATAL_DAMAGE_MULT := 3.0   # 即死：最大生命的 3 倍，走玩家正常的受伤 / 无敌 / 复活流程
const RUN_WINDUP := 0.8
const RUN_SPEED := 760.0
const RUN_RADIUS_MIN := 260.0
const RUN_RADIUS_MAX := 420.0
const RUN_DAMAGE := 32.0
const RUN_HIT_COOLDOWN := 0.6
const FRAGMENT_START := 2            # 开场散落的锁链碎片
const FRAGMENT_EVERY := 20.0         # 场上少于 FRAGMENT_MAX 时每隔多久补一个
const FRAGMENT_MAX := 2
const BIND_TIME := 6.0               # 束缚时长
const BIND_DAMAGE_MULT := 1.5        # 束缚中受到的伤害倍率
const VIDAR_DAMAGE := 0.15           # 维达撕开巨口：芬里尔损失最大生命的比例
const VIDAR_STAGGER := 2.5

# ———— 苏尔特【暂定】————
const FIRE_HP := 12000.0 / (1.0 + 540.0 / 100.0)   # 09:00 出场时正好 12000
const FIRE_CONTACT := 32.0
const FIRE_CHASE := 2.0
const SWEEP_WINDUP := 0.9
const SWEEP_RADIUS := 290.0
const SWEEP_HALF := 1.05
const SWEEP_DAMAGE := 40.0
const GATE_COUNT := 2
const GATE_LIFE := 3.0
const GATE_GIANTS := 3               # 每扇门放出几个火焰巨人（受敌人上限约束）
const FIREWALL_START := 1000.0       # 九界燃烧的安全圆初始半径
const FIREWALL_MIN := 440.0
const FIREWALL_SHRINK := 36.0        # 从初始收缩到最小用多少秒
const FIREWALL_DPS := 20.0
const FINAL_WARN := 2.0              # 终焉之火：预警
const FINAL_BURN := 0.6              # 爆发持续（伤害只在爆发瞬间结算一次）
const FINAL_REST := 1.1
const FINAL_DAMAGE := 55.0
const FINAL_SAFE_BLOCKS := 5         # 每轮几块 2×2 安全格（第一块保证在玩家附近）
const FINAL_SAFE_REACH := 3          # 第一块安全格离玩家所在格最多几格
const RESIDUAL_LIFE := 5.0           # 横扫留下的残火
const RESIDUAL_DPS := 11.0

# ———— 普通敌人【暂定】————
const GIANT_BLAST_RADIUS := 56.0
const GIANT_BLAST_WARN := 0.4
const GIANT_BLAST_DAMAGE := 16.0
const GIANT_FIRE_LIFE := 4.0
const GIANT_FIRE_DPS := 6.0
const HAZARD_MAX := 60               # 场上同时存在的火焰 / 爆炸上限，超出时最早的先熄灭
const CHARGE_EVERY := 6.0
const CHARGE_WINDUP := 0.6
const CHARGE_TIME := 0.6
const CHARGE_MULT := 5.0
const CHARGE_RANGE := Vector2(110, 380)
const SHIELD_EVERY := 7.0
const SHIELD_TIME := 2.4
const SHIELD_HALF := 1.2             # 正面挡住的扇区半角
const SHIELD_BLOCK := 0.8            # 正面挡掉的伤害比例
const SHIELD_TURN := 1.5             # 举盾时转身速度（弧度/秒），绕到背后就能打
const RAGE_AT := 0.4                 # 狂狼战士低于这个血量比例时狂暴
const RAGE_SPEED := 1.6
const RAGE_ATTACK := 0.6             # 狂暴后攻击间隔倍率

# ———— 神明援助【暂定】————
const AID_EVERY := 14.0              # 一般周期援助：每隔多久一次（轮流换信仰的神）
const AID_NEAR := 420.0              # 「附近交战」：这个范围内的敌人数
const AID_MIN_ENEMIES := 6
const AID_BOSS_NEAR := 900.0         # 或 Boss 在这个距离内
const AID_DAMAGE := 26.0             # 基础伤害，乘玩家伤害加成和 (1 + 信仰 / 12)
const THOR_AID_EVERY := 6.0          # 托尔获救后在苏尔特战中落雷
const THOR_AID_DAMAGE := 0.02        # 每次落雷：苏尔特最大生命的比例
const FREYR_HEAL_EVERY := 4.0        # 弗雷持续治疗
const FREYR_HEAL := 0.06             # 每次回复最大生命的比例

# ———— 结算【暂定，未启用】————
const FATE_REWARD := 0               # 每改写一个命运额外奖励点。世界观要求命运参与评价但没给公式，先不加分
