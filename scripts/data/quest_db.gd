class_name QuestDB
## 支线登记表：关卡数据里写支线 id，这里把 id 变成对应的支线
## 新做一个支线：写好它的脚本（参考 bonfire_quest.gd），然后在这里加一行


static func create(id: String) -> SideQuest:
	match id:
		"bonfire":
			return BonfireQuest.new()
		"ravens":
			return RavensQuest.new()
		"valkyrie":
			return ValkyrieQuest.new()
	push_error("未知的支线：" + id)
	return null
