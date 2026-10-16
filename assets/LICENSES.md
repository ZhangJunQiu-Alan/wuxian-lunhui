# 素材授权台账

每使用一个外部素材，都在这里记录一行。自己团队原创的素材写「原创」。

| 文件 | 来源 | 作者 | 授权 | 链接 | 凭证 / 备注 |
| --- | --- | --- | --- | --- | --- |
| fonts/NotoSansSC-Regular.otf | Noto CJK 开源字体 | Google、Adobe | SIL OFL 1.1（可免费商用、可随游戏分发，不可单独售卖字体） | https://github.com/notofonts/noto-cjk | 授权全文：fonts/NotoSansSC-OFL.txt |
| source/norse_2026-10-16/（23 张原图） | AI 生成：ChatGPT 网页版（生成记录见该目录 manifest.json） | AI 生成 | 按 OpenAI 使用条款，输出归用户所有；**纯 AI 生成内容的版权保护各国尚不确定；上架 Steam 须披露 AI 生成内容** | 见 manifest.json 中的 chat_url | 2026-10-16 生成 |
| source/norse_pixel_2026-10-16/ 与 sprites/enemies、sprites/bosses 中第 1 关的 10 张 | 由上面的 AI 原图经 Pixel Asset Studio 转换为像素风 | 同上 | 同上；Pixel Asset Studio 允许商用（用户已确认，2026-10-16） | https://pixel-asset-studio.com/ | 2026-10-16 转换 |
| （示例）sprites/enemies/draugr.png | 外包定制 | 某某画师 | 著作权转让 | 合同编号 2026-001 | 合同存于网盘 /合同/ |

## 2026-10-16 新六批制作：工具核查

以下为本轮实际读取官方页面的结果；工具核查不代表已生成素材，也不代表素材通过自检。

| 工具 / 范围 | 来源及授权依据 | 商用与输出权利 | 日期 | 使用状态 |
| --- | --- | --- | --- | --- |
| ChatGPT 网页版 / 第 1 批拟用 | https://openai.com/policies/terms-of-use/ ，2026-01-01 生效，内容所有权条款 | 在用户与 OpenAI 之间且在适用法律允许范围内，用户保留输入并拥有输出；OpenAI 转让其可能拥有的输出权利。用于本项目商业素材；不承诺纯 AI 内容必然受版权保护 | 2026-10-16 | 条款已读，当前 Chrome 已登录；仅使用现有账户，不升级、不付费 |
| Piskel / 第 1 批拟用修帧与导出 | https://www.piskelapp.com/terms/ ，2025-06-01 更新，Cost of use / Intellectual Property | 免费；用户保留所创作品全部权利，署名工具为可选；自有输入制作的商业作品权利归用户 | 2026-10-16 | 条款已读；不使用示例素材 |
| PixelLab / 候选工具，尚未用于制作 | https://www.pixellab.ai/termsofservice ，2025-11-23 更新，1.3、3.3 | 明确允许商业用途，用户保留创作所有权；禁止未经许可用输出训练其他模型；2.2 限定程序化使用通过官方 API | 2026-10-16 | 仅比较功能和条款。需要账号，未注册、未登录、未生成、未付费 |
| Pixel Asset Studio / 本轮仅比较 | https://pixel-asset-studio.com/about/ | 页面说明免费、本地处理；本轮所读页面未明确写出输出所有权，沿用旧批次用户商用确认记录但不扩展为新的授权证明 | 2026-10-16 | 本轮暂不用于制作；不把免费或本地处理等同于明确授权 |
| Pillow 11.1.0 / 本地 PNG 元数据检查与验收预览 | 已读安装包 LICENSE：`/opt/anaconda3/lib/python3.13/site-packages/pillow-11.1.0.dist-info/LICENSE`；https://pillow.readthedocs.io/en/stable/about.html#license | MIT-CMU，允许为任何目的免费使用、复制、修改与分发软件。仅作本地检查/预览，不提供第三方美术内容；作品权利不转移给工具 | 2026-10-16 | 已核查本地许可证；检查脚本为本项目原创，放在第 1 批 records/ |

### 第 1 批剑士（musashi）：实际产出（进行中）

| 文件 / 范围 | 来源与工具 | 授权 / 所有权 | 来源链接 | 日期与凭证 |
| --- | --- | --- | --- | --- |
| source/batch01_musashi_2026-10-16/originals/（8 张原图） | 已登录的 Chrome ChatGPT 图像生成；站姿用既有北欧素材总览作画风参考，动作与特写均上传同一剑士参考 | OpenAI 内容所有权条款：在双方之间且在适用法律允许范围内，输出归用户；用于商业项目。不承诺纯 AI 内容必然获得版权保护 | https://openai.com/policies/terms-of-use/ | 2026-10-16；逐张会话与实际提示词见该批 manifest.json、records/ |
| source/batch01_musashi_2026-10-16/candidates/musashi_piskel_v01.png、.piskel | 上述站姿经 Piskel 导入、最近邻缩小、扩展画布及导出；只有候选，没有采用其颜色过多的版本 | Piskel 免费，用户保留作品全部权利；未使用网站示例素材 | https://www.piskelapp.com/terms/ | 2026-10-16；浏览器证据及实际 PNG 自检在该批 records/ |
| sprites/characters/musashi.png、musashi_hurt.png、musashi_death.png、musashi_cutin.png；对应 approved/、previews/ | 上述自有 AI 原图经本地 Pillow 规范化、统一调色板、切帧与预览导出；脚本为项目原创 | 原图权利同上；Pillow MIT-CMU 不取得作品权利，允许商业目的使用。仅四项美术自检通过；idle/move 未通过，未放进最终目录 | https://pillow.readthedocs.io/en/stable/about.html#license | 2026-10-16；该批 manifest.json 记录哈希、颜色数、自检与非游戏验收边界 |

### 2026-10-16：第 1 批 Piskel 免费逐帧修复补记

剑士待机 v05、跑步 v06 在 Chrome 的 Piskel 免费网页编辑器中逐像素修正并导出 PNG、可编辑 .piskel 与 GIF；未使用 PixelLab API。沿用上文已核查的 Piskel 商用及输出权利条款。Pillow 仅用于读取导出文件、比对像素计划、切帧和生成最近邻预览/调整 GIF 计时。人工修正计划、失败候选、验证结果和网页截图均保存在 `source/batch01_musashi_2026-10-16/records/`。

### 2026-10-16：第 2 批工具与原图补记

继续使用前文已核验的 Chrome ChatGPT 网页和免费 Piskel。第 2 批上传的参考图均为本项目现有耶梦加得、苏尔特原图及其像素版本，未引入第三方作品角色。当前终端实际 Pillow 版本为 12.1.1，已核对 `/opt/homebrew/lib/python3.14/site-packages/pillow-12.1.1.dist-info/licenses/LICENSE`：MIT-CMU，允许为任何目的使用、复制、修改和分发；同样可用于商业素材的确定性尺寸、透明度和调色板处理。Piskel 两张有效的 92×92 中间导出已保留；火巨人的 Piskel PNG 为零字节，作废并从已归档高清源图重新采样；异常宽度导入未导出为交付素材。

### 第 2 批续作记录（2026-10-16）

耶梦加得头、身、尾 v04 由 Chrome Piskel 界面实际逐像素修正并导出，Pillow 仅用于差异核对、拼接审核图和预览。三份实际 PNG 与保存计划均为零像素差异。苏尔特补画 v01 由已登录的 Chrome ChatGPT 网页下载，因右脚遮挡退回；v02 继续上传现有素材参考修正。沿用本台账已核查的工具与商用条款，未注册账号、付款或调用 PixelLab API。

苏尔特 v02 已从同一 Chrome ChatGPT 会话下载并归档，以既有素材参考修复武器遮挡，经过已许可的 Pillow 做确定性最近邻与 48 色规范化后通过单图审核。本批没有采用外部现成角色设计或不明授权素材。

### 第 3 批第 1 关 Boss 动作（2026-10-16，进行中）

继续使用已核查商用条款的 Chrome ChatGPT 网页版：上传项目现有静态精灵与确定性排版模板生成动作，生成记录保存在 `assets/source/batch03_stage01_boss_actions_2026-10-16/records/`。第一轮四张原图及六条规范化候选因质量问题退回。Pillow 用于二值透明、切帧、固定色板、尺寸规范化、差异核对和预览；斯库尔待机的实际像素修改、复制帧、排序与 PNG／工程导出均通过 Chrome Piskel 界面完成。未注册、付费或使用 PixelLab API。

第 3 批第三、四轮原图共 8 张已经通过 Chrome ChatGPT 网页下载并完整解码验证；均重新上传本项目角色及定位模板，提示词与会话链接见 `records/generation_jobs_wave03.json`、`generation_jobs_wave04.json`。哈提嚎叫 v02 使用已许可的 Piskel 免费网页实际选区复制固定躯干，PNG 与 .piskel 已导出。沿用上述 OpenAI、Piskel、Pillow 商用条款，无新账户、付款或外部角色素材。通过与退回状态以该批当前 manifest.json 为准，生成数量不代表验收数量。

第 3 批交付补记（2026-10-16）：本批21张ChatGPT原图已归档，15条Boss动作自检通过并复制至 `sprites/bosses/`，来源、实际提示词及会话链接见该批 `manifest.json` 与 `records/generation_jobs_*.json`。待机/嚎叫/抬爪通过Chrome Piskel实际编辑，其他动作由带参考生成原图作完整轮廓切帧、48色与透明规范化；哈提移动v05、v07为失败中间稿，不在成品清单。最终采用v08。全部继续沿用上述已核验的OpenAI、Piskel与Pillow商用依据，未使用新工具或第三方美术。状态为美术自检通过，待代码代理游戏验收。

### 第7批战斗动作与三位角色（2026-10-16，制作中）

独立工作目录 `source/batch07_combat_characters_2026-10-16/`，由用户指定本分支负责，第4批由另一代理制作。沿用上文同日已读官方条款的Chrome ChatGPT（OpenAI输出所有权）、Piskel（免费、用户保留作品权利）与Pillow（MIT-CMU）。只上传项目自有参考与原创排版模板；不引入第三方角色图。逐项来源、生成会话、实际检查与失败稿保存在本批records及manifest中。此项登记不代表素材已通过验收。

### 第4批地图与场景物件（2026-10-16，制作中）

本任务仅负责第4批，沿用前文已核验商用条款的Chrome ChatGPT生成、Piskel修整与Pillow确定性切图/颜色/尺寸/平铺检查。上传参考为本项目既有原创AI像素素材；不引入外部作品造型。提示词、生成会话、原图及逐项验收将记录在`source/batch04_maps_2026-10-16/`。地面为完整不透明RGBA，物件为0/255透明PNG；当前准备提示词不代表生成或验收完成。

第4批交付补记（2026-10-16）：共10张ChatGPT原图已完整解码归档，43张静态PNG（20地块、23物件）通过本批美术自检并复制至`sprites/ground/<level>/`和`sprites/props/<level>/`。逐项来源、上传参考、提示词与9个生成会话见`source/batch04_maps_2026-10-16/manifest.json`。实际使用Chrome ChatGPT网页版生成、Pillow12.1.1与项目原创脚本裁切、去底去杂色、最近邻尺寸、周期接缝修正和共享色板；本批没有实际使用Piskel修图。商用与输出权利沿用本台账已核验的OpenAI内容所有权及Pillow MIT-CMU条款，未引入第三方美术、注册、升级或付款。43张最终文件与approved快照SHA256一致，每关地面与物件合计47/48/45个不透明RGB颜色；地块完整不透明、物件alpha0/255。交付预览含单图1×/4×、20张4×4平铺、3份基础混铺、三关本地合成轮播GIF和平铺滚动检查GIF。状态为美术自检通过，未在Godot运行，待代码代理游戏验收。第7批不在本任务范围。

第7批生成路线变更（2026-10-16）：用户明确允许从连续掉线的Chrome生成路线改用本对话内置图像工具。仍为OpenAI图像输出，沿用上文已核查的OpenAI商用与输出所有权条款（https://openai.com/policies/terms-of-use/）；只使用项目自有输入。未调用另行收费API、未注册或输入付款信息。实际生成来源和工具在第7批manifest/records中逐项记录；该变更不代表候选通过审核。

### 第7批 A/B 实际制作补记（2026-10-16）

剑士及7种敌人攻击已完成美术自检，来源与工具逐项见 `source/batch07_combat_characters_2026-10-16/manifest.json`。后半B实际使用内置图像工具10次（4份初稿、3份紧凑姿势修正、2份落点修正、1份普通巨人第三帧修正），继续沿用本台账的OpenAI输出权利及商用条款；用户已明确批准路线变更。Chrome Piskel实际修帧工程及导出归档；Pillow仅用于尺寸、透明度、既有调色板、裁帧/排帧、预览和自检。输入参考均为项目已有或本批生成的原图，没有上传外部作品角色图。无注册、无付款、无收费API调用。

第7批 C 进行中补记（2026-10-16）：用户批准内置生成路线后三位角色静态、待机、攻击与受击采用内置image_gen并上传本项目原图和精灵参考，沿用本台账的OpenAI商业输出使用与所有权依据。逐轮实际提示词/原图/失败候选存于batch07/records/builtin_C_*.json及originals。Pillow仅做固定RGB色板、二值透明、尺寸/整帧定位、裁排与预览，未在Python重画角色。无新增第三方角色素材、注册、付款或收费API；各项是否通过以manifest为准，当前20/29项通过美术自检。

第7批交付补记（2026-10-16）：29项完成美术自检（23条动画、3张静态、3张特写），未游戏实测。A/B的Chrome ChatGPT原图与Piskel实际修帧、C的内置image_gen带项目自有参考生成，以及Pillow尺寸/二值透明/固定色板/整帧定位/裁排/预览均逐项列入batch07 manifest。实际提示词及原图保留；C未使用Piskel手工绘制。继续沿用上文已核查的OpenAI内容所有权及商用条款、Piskel用户保留作品权利、Pillow MIT-CMU，无新增工具、第三方角色美术、注册、付费或收费API。29个成品与approved和候选SHA256一致，技术核对见source/batch07_combat_characters_2026-10-16/records/final_audit.json；美术自检不替代游戏验收。

### 角色文件改名（2026-10-16）

角色素材的文件名从原型人物名改为职业名：`musashi_*` → `swordsman_*`，`annie_*` → `gunslinger_*`，`lanling_*` → `assassin_*`，`merlin_*` → `mage_*`。图片内容没有变化，上文各批记录里的旧文件名对应这些新文件。`assets/source/` 里的原稿保留当时的文件名。
