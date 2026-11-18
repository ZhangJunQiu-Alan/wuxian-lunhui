const originalModels = [
  {
    "id": "midgard_longhouse_material",
    "name": "雪村长屋",
    "category": "建筑",
    "description": "此前制作的木板、旧瓦与积雪长屋，可作为雪村房的建筑样板。",
    "rooms": "雪村长屋",
    "status": "材质样板，游戏内试摆已验证",
    "triangles": 13484,
    "dimensions_blender_xyz": [
      2.726,
      1.87,
      1.828
    ],
    "blend": "assets/source/task3d_midgard_2026-11-13/midgard_longhouse_material.blend",
    "glb": "assets/models/midgard/midgard_longhouse_material.glb",
    "preview": "assets/source/task3d_midgard_2026-11-13/previews/midgard-longhouse-material-detail.png"
  },
  {
    "id": "snow_floor",
    "name": "积雪石板地面",
    "category": "场地",
    "description": "可拼接的冻土与积雪地块，边缘石材用于区分通路。",
    "rooms": "雪村、墓丘、石阵",
    "status": "静态模型",
    "expected_clip": "static",
    "blend": "assets/source/task3d_rooms_2026-11-14/snow_floor.blend",
    "glb": "assets/models/midgard/rooms/snow_floor.glb",
    "preview": "assets/source/task3d_rooms_2026-11-14/previews/snow_floor.png",
    "dimensions_blender_xyz": [
      3.0,
      3.0,
      0.465
    ],
    "triangles": 4792,
    "animations": [],
    "sha256": "7cc5e86bf06c325130f4468b7663f46af0877325bcb551423135c7c0602cc604",
    "bytes": 1079700
  },
  {
    "id": "void_causeway",
    "name": "虚空断台与石桥",
    "category": "虚空",
    "description": "两侧断台围出真实空洞，中间保留一条窄桥。用于限制横向走位。",
    "rooms": "墓丘、精英房",
    "status": "需要接入边界碰撞与坠落判定",
    "expected_clip": "static",
    "blend": "assets/source/task3d_rooms_2026-11-14/void_causeway.blend",
    "glb": "assets/models/midgard/rooms/void_causeway.glb",
    "preview": "assets/source/task3d_rooms_2026-11-14/previews/void_causeway.png",
    "dimensions_blender_xyz": [
      4.812,
      3.296,
      1.075
    ],
    "triangles": 4428,
    "bytes": 1065032,
    "animations": [],
    "sha256": "fa7e17311a64682346d7ff4160e7b08b02f562ccf51f2f18936a4d70302d6b06"
  },
  {
    "id": "spike_trap",
    "name": "伸缩地刺",
    "category": "陷阱",
    "description": "金属基座与九根可伸缩尖刺。预警后升起，再回落。",
    "rooms": "雪村侧巷、码头",
    "status": "已导出伸缩动画，Godot 动画名 spike；伤害与预警待接",
    "expected_clip": "spike_cycle",
    "blend": "assets/source/task3d_rooms_2026-11-14/spike_trap.blend",
    "glb": "assets/models/midgard/rooms/spike_trap.glb",
    "preview": "assets/source/task3d_rooms_2026-11-14/previews/spike_trap.png",
    "dimensions_blender_xyz": [
      1.62,
      1.62,
      0.94
    ],
    "triangles": 2648,
    "bytes": 921748,
    "animations": [
      "spike_cycle"
    ],
    "sha256": "541ae60f36256ac2cff385141bba4350dcd99647e5e3d7bb00fe3c6dfce81d94",
    "godot_clip": "spike"
  },
  {
    "id": "rune_trap",
    "name": "符文喷发陷阱",
    "category": "陷阱",
    "description": "凹陷的法阵槽和环绕的立石，中央发光用于提示即将喷发。",
    "rooms": "墓丘、奥丁石阵",
    "status": "发光材质已导出，技能与范围预警待接",
    "expected_clip": "static",
    "blend": "assets/source/task3d_rooms_2026-11-14/rune_trap.blend",
    "glb": "assets/models/midgard/rooms/rune_trap.glb",
    "preview": "assets/source/task3d_rooms_2026-11-14/previews/rune_trap.png",
    "dimensions_blender_xyz": [
      1.88,
      1.88,
      0.619
    ],
    "triangles": 2428,
    "bytes": 919072,
    "animations": [],
    "sha256": "3d960ee96f068463466d250b1e1aaf1583bc910b8f985353088c9381102f2be2"
  },
  {
    "id": "pressure_plate",
    "name": "石质压力踏板",
    "category": "机关",
    "description": "可下压的独立踏板与外圈框架，作为门或陷阱的触发器。",
    "rooms": "普通房、机关房",
    "status": "已导出 press 动画，触发与联动待接",
    "expected_clip": "press",
    "blend": "assets/source/task3d_rooms_2026-11-14/pressure_plate.blend",
    "glb": "assets/models/midgard/rooms/pressure_plate.glb",
    "preview": "assets/source/task3d_rooms_2026-11-14/previews/pressure_plate.png",
    "dimensions_blender_xyz": [
      1.36,
      1.36,
      0.419
    ],
    "triangles": 540,
    "bytes": 786372,
    "animations": [
      "press"
    ],
    "sha256": "e1023295bda2a511ff32b6c0d858c49102af40173eb16dcf52078068dcf43e2b"
  },
  {
    "id": "rune_gate",
    "name": "升降符文门",
    "category": "出口",
    "description": "雕纹石柱支撑带铆钉的木闸，顶部徽记可对应出口奖励。",
    "rooms": "战斗房出口",
    "status": "已导出 open 动画，清场解锁与奖励门标待接",
    "expected_clip": "open",
    "blend": "assets/source/task3d_rooms_2026-11-14/rune_gate.blend",
    "glb": "assets/models/midgard/rooms/rune_gate.glb",
    "preview": "assets/source/task3d_rooms_2026-11-14/previews/rune_gate.png",
    "dimensions_blender_xyz": [
      2.87,
      0.727,
      2.48
    ],
    "triangles": 5248,
    "bytes": 1117676,
    "animations": [
      "open"
    ],
    "sha256": "ba61595b92a4d7feb2821b2b2df4dcfcec5a86c6f04deebfe540b3a11e21435f"
  },
  {
    "id": "lever",
    "name": "铁木拉杆",
    "category": "机关",
    "description": "石基上的可转动手柄，保留独立枢轴用于控制门或陷阱。",
    "rooms": "安全侧道、支路",
    "status": "已导出 activate 动画，交互逻辑待接",
    "expected_clip": "activate",
    "blend": "assets/source/task3d_rooms_2026-11-14/lever.blend",
    "glb": "assets/models/midgard/rooms/lever.glb",
    "preview": "assets/source/task3d_rooms_2026-11-14/previews/lever.png",
    "dimensions_blender_xyz": [
      0.72,
      0.769,
      1.1
    ],
    "triangles": 820,
    "bytes": 806112,
    "animations": [
      "activate"
    ],
    "sha256": "7d76e27f9344f494e558c0e6390ddffd1b841c36c41bdb4343396f21df9d885a"
  },
  {
    "id": "brazier",
    "name": "北欧铁制火盆",
    "category": "道具",
    "description": "带支脚、铆钉与燃炭的火盆，标记出口和安全区域。",
    "rooms": "雪村、营火房",
    "status": "火光为静态发光几何，粒子与实时灯光待接",
    "expected_clip": "static",
    "blend": "assets/source/task3d_rooms_2026-11-14/brazier.blend",
    "glb": "assets/models/midgard/rooms/brazier.glb",
    "preview": "assets/source/task3d_rooms_2026-11-14/previews/brazier.png",
    "dimensions_blender_xyz": [
      0.74,
      0.74,
      1.038
    ],
    "triangles": 1792,
    "bytes": 876576,
    "animations": [],
    "sha256": "b1b4b1faaf69e053708fa8d7c760de5052b2aeddd038739bbaf752e5ca142eb7"
  }
];
let models = originalModels;
