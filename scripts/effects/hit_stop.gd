class_name HitStop
## 命中顿帧：武器打中敌人的一瞬间整个游戏停住几十毫秒，让这一下有「砍进去」的分量。
## 只由玩家的武器触发（神术持续自动造成伤害，也顿帧的话画面会一直卡）。
## 新的一次顿帧直接接管：重新计时，由最后一次负责恢复，所以不会卡在慢速里。

const SLOW := 0.0  # 完全停住（参考视频的做法），刀光和粒子在恢复后接着播

static var _token := 0


static func hit(node: Node, seconds: float) -> void:
	if seconds <= 0.0 or not node.is_inside_tree():
		return
	_token += 1
	var mine := _token
	Engine.time_scale = SLOW
	await node.get_tree().create_timer(seconds, true, false, true).timeout  # 计时不受 time_scale 影响
	if mine == _token:
		Engine.time_scale = 1.0
