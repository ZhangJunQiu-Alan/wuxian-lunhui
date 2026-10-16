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

### 第 1 批剑士（swordsman）：实际产出（进行中）

| 文件 / 范围 | 来源与工具 | 授权 / 所有权 | 来源链接 | 日期与凭证 |
| --- | --- | --- | --- | --- |
| source/batch01_swordsman_2026-10-16/originals/（8 张原图） | 已登录的 Chrome ChatGPT 图像生成；站姿用既有北欧素材总览作画风参考，动作与特写均上传同一剑士参考 | OpenAI 内容所有权条款：在双方之间且在适用法律允许范围内，输出归用户；用于商业项目。不承诺纯 AI 内容必然获得版权保护 | https://openai.com/policies/terms-of-use/ | 2026-10-16；逐张会话与实际提示词见该批 manifest.json、records/ |
| source/batch01_swordsman_2026-10-16/candidates/swordsman_piskel_v01.png、.piskel | 上述站姿经 Piskel 导入、最近邻缩小、扩展画布及导出；只有候选，没有采用其颜色过多的版本 | Piskel 免费，用户保留作品全部权利；未使用网站示例素材 | https://www.piskelapp.com/terms/ | 2026-10-16；浏览器证据及实际 PNG 自检在该批 records/ |
| sprites/characters/swordsman.png、swordsman_hurt.png、swordsman_death.png、swordsman_cutin.png；对应 approved/、previews/ | 上述自有 AI 原图经本地 Pillow 规范化、统一调色板、切帧与预览导出；脚本为项目原创 | 原图权利同上；Pillow MIT-CMU 不取得作品权利，允许商业目的使用。仅四项美术自检通过；idle/move 未通过，未放进最终目录 | https://pillow.readthedocs.io/en/stable/about.html#license | 2026-10-16；该批 manifest.json 记录哈希、颜色数、自检与非游戏验收边界 |

### 2026-10-16：第 1 批 Piskel 免费逐帧修复补记

剑士待机 v05、跑步 v06 在 Chrome 的 Piskel 免费网页编辑器中逐像素修正并导出 PNG、可编辑 .piskel 与 GIF；未使用 PixelLab API。沿用上文已核查的 Piskel 商用及输出权利条款。Pillow 仅用于读取导出文件、比对像素计划、切帧和生成最近邻预览/调整 GIF 计时。人工修正计划、失败候选、验证结果和网页截图均保存在 `source/batch01_swordsman_2026-10-16/records/`。

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

早期文件名用了原型人物名，已统一改为职业名。历史提示词只遮盖人物名，未改写成新的生成提示词。

### 第5批第1关7种敌人行走（2026-10-16，制作中）

用户明确授权本任务完成第1关7条行走动画，沿用已批准的内置image_gen路线及本台账同日核验的OpenAI输出所有权/商业使用条款（https://openai.com/policies/terms-of-use/）。仅上传本项目既有原创敌人精灵；若需修帧，沿用已核查的免费Piskel用户保留作品权利。Pillow继续按MIT-CMU用于尺寸、原图RGB固定色板、二值透明、整帧定位/排帧和预览，不在Python重画角色。实际原图、Prompt、候选与自检记录放在source/batch05_enemy_walk_2026-10-16。无新增工具、注册、付款或收费API；本条不代表验收完成。

第5批第1关交付补记（2026-10-16）：7条行走完成美术自检，共36帧（四种双足6帧、冬狼及两种精魂4帧）；15张内置image_gen原图、实际Prompt、上传参考与失败候选均已归档。继续沿用本台账已核验OpenAI输出商业使用与所有权条款、Pillow MIT-CMU；Pillow另绘制原创四肢姿势线稿仅作提示参考，精灵改动由内置图像工具完成，未在Python重画身体。本批没有实际用Piskel修帧，没有新增第三方素材、登录注册、付费或收费API。7个PNG均使用原图RGB固定色板，与第7批攻击一致；7份GIF逐帧像素与PNG深色背景4倍合成完全相同。来源、自检和哈希见source/batch05_enemy_walk_2026-10-16/manifest.json及records/final_audit.json。状态为美术自检通过，尚未Godot实测；第2/3关另外7种敌人本次未做。

Claude 验收（2026-10-16）：7 个帧条已在 Godot 内实测，切帧、朝向翻转、落脚线均正常，验收通过。

### 第4批第1关补做（2026-10-16，进行中）

按新版任务书补做边界、过渡、地标物件及贴花。沿用已批准内置image_gen及此前核查OpenAI内容所有权/商业使用条款（https://openai.com/policies/terms-of-use/），仅上传本项目自有素材作风格参考，不引入外部作品造型。沿用Pillow MIT-CMU作尺寸、透明、色板、裁切排版与预览。原图、提示词和通过/退回记录保存于source/batch04_midgard_expansion_2026-10-16；本条不代表已验收。无新增登录注册、付费或API。

### 第6批特效、拾取物与支线物件：开工（2026-10-16）

用户指定本任务制作第6批，继续使用用户已批准的内置 image_gen 与本台账同日核查的 OpenAI 输出商业使用及所有权条款（https://openai.com/policies/terms-of-use/）。仅上传本项目自有素材作为风格或身份参考；不使用第三方作品角色图。Pillow 12.1.1 沿用 MIT-CMU，用于尺寸、二值透明、限定调色板、裁帧排帧与预览，不重画角色或特效。实际提示词、参考、原图、失败候选与自检记录放在 source/batch06_effects_pickups_quests_2026-10-16/。无新增工具、注册、付费或收费 API；本项为工具使用登记，不代表美术验收。

第6批交付补记（2026-10-16）：34项完成美术自检（14条四帧动画、20张静态，共76个输出单元），成品位于sprites/effects/、pickups/、quests/及enemies/ice_block.png。实际使用已批准内置image_gen共43次，原始PNG、真实Prompt和上传参考保存在source/batch06_effects_pickups_quests_2026-10-16；Chrome免费Piskel实际修正篝火、铁火盆固定部分及英灵攻击残刃，三个可编辑工程和导出归档。Pillow仅作裁帧排版、最近邻尺寸、二值透明、共享调色板、整帧锚点定位及预览/像素核验，不重画角色/特效。渡鸦为3张独立姿势按上拍/平翼/下拍/平翼构成4相，参考一致；保留原图白眼RGB到色板，不伪称4张独立原画。商用依据沿用本台账同日核查OpenAI内容输出所有权与商业使用条款、Piskel用户保留作品权利及Pillow MIT-CMU。预览标题使用本项目OFL字体NotoSansSC。无外部作品人物参考、新注册、付费或收费API。34个PNG与approved和候选SHA256一致；14份8fps4倍GIF与PNG逐帧像素完全一致，实际逐项结果见该批records/final_audit.json。无地块，4×4平铺不适用。尚未本代理Godot实测，待Claude接入审核。

第4批第1关补做交付补记（2026-10-16）：17张内置image_gen原图、实际Prompt和生成文件路径归档于`source/batch04_midgard_expansion_2026-10-16/records/generation_records.json`；仅使用项目自有素材参考。112张成品（8边界、26地块/过渡、62物件、16贴花）通过本批美术自检并复制到对应`sprites/*/midgard/`，未覆盖旧成品。继续沿用上文已核查的OpenAI输出所有权和商用依据（https://openai.com/policies/terms-of-use/），以及Pillow12.1.1 MIT-CMU，用于尺寸、alpha、色板、原像素重叠裁切、排版与预览；未重画角色。Chrome Piskel仅实际导入长屋检查，未手工改图或导出。本批未注册新账户、付款、使用第三方美术或收费API。原图、退回稿、来源和自检以本批manifest为准；状态为美术自检通过，尚未Godot游戏验收。普通资产沿用Midgard既有色表，三张血迹统一1种低饱和暗红，单图最多47色，本批环境合计48色；GIF是静态地图的平移/滚动检查，不是新游戏动画。

Claude 验收（2026-10-16）：第 4 批补做已接入第 1 关地图并在 Godot 内实测：四边屏障、冰面和雪路过渡、各地标物件与贴花显示正常，验收通过。

Claude 验收（2026-10-16）：第 6 批 34 项已接入并在 Godot 内实测，验收通过。霜冻冲击波环用在霜巨人和赫列姆砸地的起手冲击；赫列姆带缺口的扩散冲击波仍由程序绘制，因为完整的环看不出缺口方向。

### 任务 C：第2关美术开工（2026-10-17）

用户明确分配本任务负责C+D。C的原图、实际Prompt、参考、自检和失败稿单独放在source/taskC_helheim_enemies_2026-10-17/。继续使用用户已批准的内置image_gen，沿用本台账已核查的OpenAI输出商业使用及所有权条款（https://openai.com/policies/terms-of-use/）；只上传本项目自有参考。若需逐帧修正，使用已核验免费Piskel（https://www.piskelapp.com/terms/），用户保留作品权利。Pillow沿用MIT-CMU用于尺寸、原图色板、二值透明、裁排、整帧定位及预览，不重画角色。旧素材格式不符时先备份再规范化；不引入第三方作品造型、新账号、付款或收费API。本项为工具使用登记，不代表通过自检。

### 任务 D：第2关美术开工（2026-10-17）

用户明确分配本任务负责C+D。D的原图、实际Prompt、参考、自检和失败稿单独放在source/taskD_helheim_bosses_2026-10-17/。继续使用用户已批准的内置image_gen，沿用本台账已核查的OpenAI输出商业使用及所有权条款（https://openai.com/policies/terms-of-use/）；只上传本项目自有参考。若需逐帧修正，使用已核验免费Piskel（https://www.piskelapp.com/terms/），用户保留作品权利。Pillow沿用MIT-CMU用于尺寸、原图色板、二值透明、裁排、整帧定位及预览，不重画角色。旧素材格式不符时先备份再规范化；不引入第三方作品造型、新账号、付款或收费API。本项为工具使用登记，不代表通过自检。


### 任务A：历史标识清理（2026-10-17）

按最新版任务书将历史源目录、文件名、记录标识和内部引用统一为职业名；历史Prompt只遮盖人物名，未重写其余内容。78份文字记录修改、491个路径改名，清理前530个游戏素材文件SHA256不变；没有新增美术来源、修改游戏图像、注册或付款。逐项审计见`source/taskA_cleanup_2026-10-17/`。历史原图授权依据沿用原记录，本项不改变其授权状态。


### 任务B：音效与音乐来源核验（2026-10-17，制作中）

已在官方页面核对Kenney Impact Sounds、RPG Audio、Interface Sounds及OpenGameArt的rubberduck「80 CC0 RPG SFX」、Emma_MA「Determined Pursuit」、nene「Opening Theme」为CC0，可商用、改编和随游戏分发、无需署名；只从这些明确授权的页面取得候选，是否采用以本任务manifest为准。来源链接分别为https://kenney.nl/assets/impact-sounds 、https://kenney.nl/assets/rpg-audio 、https://kenney.nl/assets/interface-sounds 、https://opengameart.org/content/80-cc0-rpg-sfx 、https://opengameart.org/content/determined-pursuit-epic-orchestra-loop 、https://opengameart.org/content/opening-theme-actionsuspense 。CC0依据：https://creativecommons.org/publicdomain/zero/1.0/ 。本机FFmpeg8.1.1的`ffmpeg -L`确认此安装按GPLv3或以后版本许可，允许商业使用；仅用其离线处理音频，不把程序包含进游戏，音频本身的权利取决于输入源授权。任务自编脚本不引入外部音频。未登录注册、付费或使用AI音乐服务；此条不代表候选已通过试听或验收。


任务B音源核验续记（2026-10-17）：官网来源另核对TokyoGeisha「Dream 2 Ambience」、nene「Mysterious」与「New Sunrise」、RandomMind「Fantasy: Rising Moon」与「Fantasy: Lament for a Warrior’s Soul」、Eldritch Grim「War Horns」均标注CC0，无需注册即可取得其公开音频链接；允许商业使用与改编，署名非强制。来源分别为https://opengameart.org/content/dream-2-ambience 、https://opengameart.org/content/mysterious 、https://opengameart.org/content/new-sunrise 、https://opengameart.org/content/fantasy-rising-moon 、https://opengameart.org/content/fantasy-lament-for-a-warriors-soul 、https://opengameart.org/content/war-horns 。另核对The Free Firearm Sound Library官方归档页https://opengameart.org/content/the-free-firearm-sound-library ：团队明确CC0、商业或专业应用免版税且无需署名。候选原件会保存作者与链接；是否入选以manifest为准。Freesound原文件需登录，已向用户询问，在答复前不登录、注册或下载其需登录原件。


任务B处理工具核验（2026-10-17）：本机NumPy2.4.3随附LICENSE.txt为BSD三条款，允许商业使用与修改；用于离线波形分析、混音、削波/起音检查和包络处理，不随游戏分发程序。许可文件已读：`/opt/homebrew/lib/python3.14/site-packages/numpy-2.4.3.dist-info/licenses/LICENSE.txt`。音频输入仍按各自CC0来源记录，不把库软件许可误当作音源授权。

任务B Freesound原件补记（2026-10-17）：用户手动激活并登录后，实际通过Chrome页面的Download sound按钮下载NaturesTemper「Wolf howl」https://freesound.org/people/NaturesTemper/sounds/398430/ 和Nox_Sound「Weapon_Revolver_Hammer_Mono.wav」https://freesound.org/people/Nox_Sound/sounds/540065/ 。两页均明确CC0，允许商用、改编与分发，无需署名。前者为作者自制狼嚎音效，不伪称野生狼实录；后者为击锤机械声，不伪称开枪或转轮装弹。原件与SHA256存于本任务originals/freesound及records/freesound_downloads.json。另已从前述CC0枪械库提取Ruger Single Six和Smith & Wesson 642四份原WAV及说明CSV；归档未保存，文件来源见records/firearm_download.json。当前仅为候选音频制作，未声称通过听感或游戏验收。

任务B换弹来源补记（2026-10-17）：tkane0512「Revolver Reload Break 2」https://freesound.org/people/tkane0512/sounds/722902/ ，页面明确CC0、可商用和改编，无需署名；作者说明为自己在半声学处理房间录制并编辑的开膛、快速装弹与闭合声。用户已手动登录，原WAV由Chrome下载。用于替换机械锁扣占位候选，不把击锤声冒充转轮装弹。原件与来源哈希存本任务originals/freesound和records/freesound_downloads.json。

任务B候选制作与检查记录（2026-10-17）：已实际导出54条WAV音效及6首OGG Vorbis音乐候选，并生成7份一分钟音效连播和4份三遍音乐循环FLAC。候选来源、每条授权页、改编配方、哈希和测量值见source/taskB_audio_2026-10-17/manifest.json；全部采用已登记CC0输入，音效含自编DSP层，音乐为授权曲目剪辑，不宣称独占原创。文件格式、起音、样本峰值/尾零、同组RMS和音乐响度/时长已做技术核验；本会话未实际听辨，主观自检全部pending，未放入assets/audio自动接入目录，未宣称完成听感或Godot验收。下载归档在内存或匿名临时文件中解包后关闭，仅保留原音频、文本许可和来源记录，没有保存压缩包。


### 任务 C 交付补记（2026-10-17）

第2关小怪、精英、箭和支线物件31项完成美术自检（18条动画、101个帧格），来源、实际Prompt、参考、失败稿和最终版本见`source/taskC_helheim_enemies_2026-10-17/manifest.json`及records。新造型/动作实际使用用户已批准的OpenAI内置图像工具，输入仅为项目自有参考和原创动作线稿，沿用本台账已核查的OpenAI输出商业使用与所有权条款：https://openai.com/policies/terms-of-use/ 。亡者和普通弓手复用项目既有源图并逐项记录；小傀儡静态/最终行走从同族素材按共同尺度缩小。Pillow按MIT-CMU仅做尺寸、固定静态RGB色板、二值透明、裁排、透明边缘残片清理、整帧定位与预览，没有在Python重画角色；本任务C未用Piskel手绘角色。31项正式文件、approved与候选SHA256一致，RGBA/尺寸/alpha0或255/2px留白/角色色板/GIF像素与8fps时序检查全部通过，记录在`source/taskC_helheim_enemies_2026-10-17/records/final_audit.json`。无地块，4×4平铺不适用。无新增第三方角色素材、账号、付款或收费API；未在Godot测试，仍需Claude审核接入与实测。


### 任务 D 交付补记（2026-10-17）

第2关三位Boss及专属物件/特效28项完成美术自检（19条动画、77个帧格）。逐项原图、实际Prompt、项目自有上传参考、失败候选、加工来源与最终版本见`source/taskD_helheim_bosses_2026-10-17/manifest.json`及records。实际使用用户已批准的OpenAI内置图像工具，沿用本台账已核查的OpenAI输出商业使用与所有权条款：https://openai.com/policies/terms-of-use/ 。巨船展帆版实际在免费Chrome Piskel中逐区域复制原船身，只保留中央帆布变化；工程、导出和截图已归档，Piskel依据：https://www.piskelapp.com/terms/ ，用户保留作品权利。Pillow按MIT-CMU仅做尺寸、固定静态RGB色板、二值透明、裁排、透明边缘残片清理、整帧定位和预览，没有在Python重画Boss或巨船。28项正式文件/approved/候选SHA256一致，RGBA/尺寸/alpha0或255/2px留白/角色色板/GIF像素与平均8fps时序检查全部通过；船体固定区域逐像素一致，见final_audit.json和ship_state_audit.json。三相位PNG仍是3格，预览GIF重复两次以兼容10ms时基并保持平均8fps。无地块，4×4平铺不适用。没有引入第三方作品造型、新账号、付款或收费API；未在Godot测试，待Claude审核、接入并实测。
