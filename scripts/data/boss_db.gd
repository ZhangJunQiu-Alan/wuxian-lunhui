class_name BossDB
## Boss 登记表：关卡数据里写 Boss 的 id，这里负责把 id 变成对应的 Boss
## 新做一个 Boss：写好它的脚本（参考 skoll.gd），然后在这里加一行


static func create(id: String, hp_scale: float) -> Boss:
	var boss: Boss
	match id:
		"skoll":
			boss = Skoll.new()
		"hati":
			boss = Hati.new()
		"hrym":
			boss = Hrym.new()
		"garm":
			boss = Garm.new()
		"nidhogg":
			boss = Nidhogg.new()
		"hel":
			boss = Hel.new()
		"jormungandr":
			boss = Jormungandr.new()
		"fenrir":
			boss = Fenrir.new()
		"surtr":
			boss = Surtr.new()
		_:
			push_error("未知的 Boss：" + id)
			return null
	boss.init_stats(hp_scale)
	return boss
