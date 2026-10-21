# R01 北欧篇章序幕：12 秒样片

本次范围：实际制作“雪村 → 巨狼追日”两个镜头，验证原创叙事插画、运镜、分层动态与字幕的方向。不是已完成的 75 秒全片，不新增已批准世界观。

播放入口：

- `preview/prologue_R01.mp4`：1280×720、24fps、12 秒，含临时氛围和狼嚎混音。
- `gallery.html`：视频、镜头和原图对照。
- `run_demo.command`：在本机用已安装 Godot 打开独立可播放场景。Space 暂停/继续，R/Enter 重播，Esc 退出。

素材：

- `layers/village_bg.png`：雪村主画。
- `layers/village_fg.png`：透明木桩雪堆前景。
- `layers/sky_bg.png`：风暴天空与峡湾主画。
- `layers/skoll.png`：透明巨狼，沿用本项目斯库尔设定。
- `layers/sun.png`：透明绘画太阳。
- `originals/`：7 次真实生成输出，包括退稿；图像字节完整保留。
- `prompts/`：每次调用的实际 Prompt；内置 image_gen 路线。
- `records/generation_jobs.json`：逐次参考、源路径和选择/退回原因。
- `timeline.json`：镜头、字幕与时序。

本轮将项目像素素材中的建筑和角色翻译成高分辨率暗色绘本插画；不改变游戏中的精灵。原图为工具实际返回的尺寸，不声称原生 1080p 或 4K；样片采用 720p 输出。没有在 Pillow 中重画或修补生成图，只用于检查和预览排版；场景曝光、透明度、移动、粒子和字幕在 Godot 合成。

声音复用项目已有 CC0 音源；没有录制正式旁白。临时混音技术检查和用户听感必须分开，未标记听感通过。商业来源说明见 `records/license_review.json`、`records/audio_recipe.json` 及项目 assets/LICENSES.md，字体副本带 OFL 文本。
