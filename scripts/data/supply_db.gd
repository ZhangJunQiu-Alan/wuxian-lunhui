class_name SupplyDB
extends RefCounted

const PICKUP_DISTANCE := 26.0
const LIFETIME := 120.0
const HEAL := 8.0
const RULES := {
	"healing_mead": {"first": 20.0, "cooldown": 35.0, "pity_time": 75.0, "pity_kills": 40, "chance": 0.025, "cap": 2},
	"soul_magnet": {"first": 60.0, "cooldown": 90.0, "pity_time": 150.0, "pity_kills": 120, "chance": 0.008, "cap": 1},
}
