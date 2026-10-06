extends RefCounted
## Progress and settings on disk: user://svg.cfg. Best time, best combo and cleared flag per chapter,
## plus hero colour, sound and haptics. Everything is read once and written whenever it changes.

const PATH := "user://svg.cfg"

var cf := ConfigFile.new()

func _init() -> void:
	cf.load(PATH)   # a missing file just means a fresh start

func flush() -> void:
	cf.save(PATH)

func get_hero() -> int:
	return int(cf.get_value("set", "hero", 0))

func set_hero(i: int) -> void:
	cf.set_value("set", "hero", i)
	flush()

func sound() -> bool:
	return bool(cf.get_value("set", "sound", true))

func set_sound(on: bool) -> void:
	cf.set_value("set", "sound", on)
	flush()

func haptics() -> bool:
	return bool(cf.get_value("set", "haptics", true))

func set_haptics(on: bool) -> void:
	cf.set_value("set", "haptics", on)
	flush()

func cleared(lv: String) -> bool:
	return bool(cf.get_value("clear", lv, false))

func best_time(lv: String) -> float:
	return float(cf.get_value("time", lv, 0.0))

func best_combo(lv: String) -> int:
	return int(cf.get_value("combo", lv, 0))

func plays(lv: String) -> int:
	return int(cf.get_value("plays", lv, 0))

## Records a finished run. Returns true when the time is a new best (only wins count for time).
func record(lv: String, won: bool, t: float, combo: int) -> bool:
	cf.set_value("plays", lv, plays(lv) + 1)
	cf.set_value("combo", lv, maxi(best_combo(lv), combo))
	var new_best := false
	if won:
		cf.set_value("clear", lv, true)
		var old := best_time(lv)
		if old <= 0.0 or t < old:
			cf.set_value("time", lv, t)
			new_best = true
	flush()
	return new_best

func cleared_count(levels: Array) -> int:
	var n := 0
	for l in levels:
		if cleared(l[1]):
			n += 1
	return n
