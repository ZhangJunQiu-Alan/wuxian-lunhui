class_name QuestDB
## 支线登记表：关卡数据里写支线 id，这里把 id 变成对应的支线
## 新做一个支线：写好它的脚本（参考 bonfire_quest.gd），然后在这里加一行


static func create(id: String) -> SideQuest:
	var quest := _new(id)
	if quest:
		quest.quest_id = id
	return quest


static func _new(id: String) -> SideQuest:
	match id:
		"bonfire":
			return BonfireQuest.new()
		"ravens":
			return RavensQuest.new()
		"valkyrie":
			return ValkyrieQuest.new()
		"nails":
			return NailsQuest.new()
		"ice_warriors":
			return IceWarriorsQuest.new()
		"priests":
			return PriestsQuest.new()
		"cold_wave":
			return ColdWaveQuest.new()
		"fate":
			return FateQuest.new()
		"ember":
			return EmberQuest.new()
		"fishing":
			return FishingQuest.new()
		"sea_giant":
			return SeaGiantQuest.new()
		"einherjar":
			return EinherjarQuest.new()
		"runes":
			return RunesQuest.new()
		"soul_lamps":
			return SoulLampsQuest.new()
		"bridge_guard":
			return BridgeGuardQuest.new()
		"anchor_chains":
			return AnchorChainsQuest.new()
		"baldr":
			return BaldrQuest.new()
		"ratatoskr":
			return RatatoskrQuest.new()
		"nail_heaps":
			return NailHeapsQuest.new()
		"hoof_tracks":
			return HoofTracksQuest.new()
		"river_sword":
			return RiverSwordQuest.new()
		"thokk":
			return ThokkQuest.new()
	push_error("未知的支线：" + id)
	return null
