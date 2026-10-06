extends Node
## Game feel and phone glue. Watches the game from the outside so the hero, enemies and chapters stay untouched:
## haptics, hit sparks, death shards, landing dust, dash rings, screen flash, hurt vignette, camera punch,
## slow motion on the final blow, chapter and wave banners, saved progress, the Android back button and
## auto-pause when the app goes to the background. Also carries the headless test hooks (SVG_SIM).

const GOLD := Color("ffd23a")
const WORDS := {3: "NICE", 5: "SHARP", 8: "FIERCE", 12: "SAVAGE", 20: "LEGEND"}
const VERSION := "0.2"

var m: Node2D
var save: RefCounted
var haptics_on := true
var flash := 0.0          # white screen flash 0..1
var red := 0.0            # hurt vignette 0..1
var combo_pop := 0.0      # HUD combo counter punch 0..1
var banner := ""
var banner_sub := ""
var banner_t := 0.0
var banner_dur := 2.6
var toast := ""
var toast_t := 0.0
var new_best := false
var grade := ""
var best_time := 0.0
var zoom_k := 0.0
var _slow_t := 0.0
var _last_state := ""
var _last_hero: Node = null
var _last_wave := -1
var _last_combo := 0
var _last_hero_i := -1
var _last_land := 0.0
var _last_dash := 0
var _last_hp := 0
var _last_ms := 0
var _sim: Array = []
var _shot2 := ""
var _shot2_at := 0
var _frames := 0
var _menu_done := false

func _ready() -> void:
	process_priority = 100   # after main.gd's _process
	save = preload("res://save.gd").new()
	m.hero_i = clampi(save.get_hero(), 0, m.HEROES.size() - 1)
	m.mute = not save.sound()
	haptics_on = save.haptics()
	_last_hero_i = m.hero_i
	_last_ms = Time.get_ticks_msec()
	# headless test hooks: SVG_SIM="frame:action[:arg..];..."  SVG_SHOT2="path@frame"
	var sim := OS.get_environment("SVG_SIM")
	if sim != "":
		for item in sim.split(";", false):
			var f := item.split(":")
			_sim.append([int(f[0]), Array(f.slice(1))])
	var s2 := OS.get_environment("SVG_SHOT2")
	if s2 != "":
		_shot2 = s2.get_slice("@", 0)
		_shot2_at = int(s2.get_slice("@", 1))

func haptic(ms: int) -> void:
	if haptics_on and m.touch and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)

func title(text: String, sub := "", dur := 2.6) -> void:
	banner = text
	banner_sub = sub
	banner_t = dur
	banner_dur = dur

func toast_show(text: String) -> void:
	toast = text
	toast_t = 1.6
	haptic(20)

func toggle_sound() -> void:
	m.mute = not m.mute
	save.set_sound(not m.mute)
	if m._music:
		m._music.stream_paused = m.mute
	if not m.mute:
		m.snd("tick")

func toggle_haptics() -> void:
	haptics_on = not haptics_on
	save.set_haptics(haptics_on)
	haptic(30)

## True when a chapter can actually be started (the two built-in ones, or a script in res://ch/).
func has_chapter(id: String) -> bool:
	return id == "line" or id == "arena" or ResourceLoader.exists("res://ch/%s.gd" % id)

func level_index(id: String) -> int:
	for i in m.LEVELS.size():
		if m.LEVELS[i][1] == id:
			return i
	return -1

func next_id() -> String:
	var i := level_index(m.level)
	if i >= 0 and i + 1 < m.LEVELS.size() and has_chapter(m.LEVELS[i + 1][1]):
		return m.LEVELS[i + 1][1]
	return ""

func restart() -> void:
	var lv: String = m.level
	m._menu()
	m.start(lv)

func slowmo(sec: float, scale := 0.25) -> void:
	Engine.time_scale = scale
	_slow_t = sec

func _hero_pos() -> Vector2:
	return m.hero.global_position if m.hero else Vector2(640, 360)

func _on_hero_hurt() -> void:
	flash = 0.35
	red = 1.0
	zoom_k = 0.035
	haptic(70)
	m.fx.ring(_hero_pos() + Vector2(0, -44), Color(1, 0.4, 0.3, 0.8), 20.0, 110.0, 0.3, 5.0)

func _on_foe_died(f: Node2D) -> void:
	var big: bool = f.kind == "hex"
	m.fx.shards(f.global_position, 18 if big else 8, GOLD if big else Color.WHITE, 26.0 if big else 12.0, 620.0 if big else 380.0)
	m.fx.ring(f.global_position, GOLD, f.r, f.r + (180.0 if big else 70.0), 0.35 if big else 0.22, 6.0 if big else 3.0)
	zoom_k = maxf(zoom_k, 0.06 if big else 0.02)
	haptic(140 if big else 40)
	if big:
		flash = 0.45
		slowmo(0.45, 0.2)

func _hook_foes() -> void:
	for f in m.foes:
		if not is_instance_valid(f):
			continue
		if not f.has_meta("jhp"):
			f.set_meta("jhp", f.hp)
			f.died.connect(_on_foe_died)
		elif f.hp < int(f.get_meta("jhp")) and not f.dead:
			var dir: float = signf(f.global_position.x - _hero_pos().x)
			m.fx.slash_sparks(f.global_position - Vector2(dir * f.r * 0.6, 0), dir, 9, Color(1, 0.95, 0.7))
			m.fx.ring(f.global_position, Color(1, 1, 1, 0.6), 6.0, f.r + 24.0, 0.16, 3.0)
			haptic(22)
			f.set_meta("jhp", f.hp)

func _watch_hero(delta: float) -> void:
	var h: Node = m.hero
	if h != _last_hero:
		_last_hero = h
		if h:
			h.hurt_taken.connect(_on_hero_hurt)
			m.fx.hero = h
			_last_land = 0.0
			_last_dash = h.dash_id
			_last_hp = h.hp
	if h == null:
		return
	if h.land_t > 0.0 and _last_land <= 0.0:
		m.fx.dust(h.global_position, 0.0, 8)
		haptic(14)
	_last_land = h.land_t
	if h.dash_id != _last_dash:
		_last_dash = h.dash_id
		m.fx.ring(h.global_position + Vector2(0, -44), Color(1, 1, 1, 0.5), 8.0, 70.0, 0.2, 3.0)
		m.fx.dust(h.global_position, float(h.dash_dir), 5)
		haptic(18)
	if h.hp > _last_hp and _last_hp > 0:
		m.fx.pop(h.global_position + Vector2(0, -110), "+1 HP", Color(0.6, 1.0, 0.7), 20)
	_last_hp = h.hp
	# steady red pulse when nearly beaten
	if h.hp <= 2 and h.hp > 0:
		red = maxf(red, 0.22 + 0.12 * sin(Time.get_ticks_msec() * 0.006))

## Chapters that run their own rules expose hp; a drop is a hit on the hero.
func _watch_ch() -> void:
	if m.ch == null:
		return
	if not m.ch.has_meta("jhp"):
		m.ch.set_meta("jhp", m.ch.hp)
	elif m.ch.hp < int(m.ch.get_meta("jhp")):
		flash = 0.3
		red = 1.0
		zoom_k = 0.03
		haptic(70)
	m.ch.set_meta("jhp", m.ch.hp)
	if m.ch.hp == 1:
		red = maxf(red, 0.22 + 0.12 * sin(Time.get_ticks_msec() * 0.006))

func _watch_state(_delta: float) -> void:
	var st: String = m.state
	if st == _last_state:
		return
	var prev := _last_state
	_last_state = st
	if st == "play" and prev != "pause":
		var i := level_index(m.level)
		if i >= 0:
			title(m.LEVELS[i][0], m.LEVELS[i][2], 2.8)
		best_time = save.best_time(m.level)
		new_best = false
		grade = ""
		_last_wave = m.wave
		_last_combo = 0
		haptic(30)
	elif st == "result":
		var hp: int = m.hero.hp if m.hero else (m.ch.hp if m.ch else 0)
		var maxhp: int = m.hero.max_hp if m.hero else (m.ch.max_hp if m.ch else 1)
		new_best = save.record(m.level, m.won, m.time, m.best)
		if m.won:
			var score := float(hp) / float(maxi(maxhp, 1)) * 0.7 + minf(m.best / 10.0, 1.0) * 0.3
			grade = "S" if score >= 0.9 else ("A" if score >= 0.7 else ("B" if score >= 0.45 else "C"))
			flash = 0.5
			slowmo(0.7, 0.3)
			haptic(120)
			if m.hero:
				m.fx.shards(_hero_pos() + Vector2(0, -50), 24, GOLD, 16.0, 520.0)
		else:
			slowmo(0.6, 0.3)
			haptic(200)
	elif st == "pause":
		haptic(10)
	elif st == "menu":
		banner_t = 0.0

func _watch_combo() -> void:
	if m.combo > _last_combo:
		combo_pop = 1.0
		if WORDS.has(m.combo):
			m.fx.pop(_hero_pos() + Vector2(0, -120), WORDS[m.combo], GOLD, 26, 60.0)
			haptic(35)
	_last_combo = m.combo
	if m.level == "arena" and m.state == "play" and m.wave != _last_wave:
		if _last_wave >= 0:
			var last: bool = m.wave == m.WAVES.size() - 1
			title("THE CHAMPION" if last else "WAVE %d" % (m.wave + 1), "the hexagon enters" if last else "", 1.8)
			m.fx.ring(_hero_pos() + Vector2(0, -44), GOLD, 20.0, 160.0, 0.4, 4.0)
			haptic(50)
		_last_wave = m.wave

func _process(delta: float) -> void:
	_frames += 1
	var now := Time.get_ticks_msec()
	var real := clampf((now - _last_ms) / 1000.0, 0.0, 0.1)   # unscaled seconds, so effects keep moving in hitstop / pause
	_last_ms = now
	_run_sim()
	if m.hero_i != _last_hero_i:
		_last_hero_i = m.hero_i
		save.set_hero(m.hero_i)
		m.snd("tick", -6.0)
		haptic(12)
	flash = maxf(0.0, flash - real * 2.6)
	red = maxf(0.0, red - real * 1.8)
	combo_pop = maxf(0.0, combo_pop - real * 4.0)
	banner_t = maxf(0.0, banner_t - real)
	toast_t = maxf(0.0, toast_t - real)
	if _slow_t > 0.0:
		_slow_t -= real
		if _slow_t <= 0.0 and m.state != "pause":
			Engine.time_scale = 1.0
	zoom_k = lerpf(zoom_k, 0.0, 1.0 - exp(-real * 7.0))
	m.cam.zoom = Vector2.ONE * (1.0 + zoom_k)
	if m._music:
		var target := -20.0 if m.state == "pause" else (-11.0 if m.state == "result" else -9.0)
		m._music.volume_db = lerpf(m._music.volume_db, target, 1.0 - exp(-real * 6.0))
		m._music.stream_paused = m.mute
	_watch_state(delta)
	if m.state == "play" and m.fx:
		_watch_hero(delta)
		_watch_ch()
		_hook_foes()
		_watch_combo()
	if _shot2 != "" and _frames == _shot2_at:
		get_viewport().get_texture().get_image().save_png(_shot2)
		get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if m and m.state == "play" and OS.has_feature("mobile"):   # phone went to the home screen or a call came in
			m.state = "pause"
			Engine.time_scale = 0.0

## Android back: play -> pause, pause/result -> chapters, chapters -> leave the app.
func _back() -> void:
	if m.state == "play":
		m.state = "pause"
		Engine.time_scale = 0.0
	elif m.state == "pause" or m.state == "result":
		m._menu()
	else:
		get_tree().quit()

func _run_sim() -> void:
	for s in _sim:
		if s[0] != _frames:
			continue
		var a: Array = s[1]
		match a[0]:
			"pause": m.state = "pause"; Engine.time_scale = 0.0
			"back": _back()
			"hurt": if m.hero: m.hero.inv = 0.0; m.hero.hurt(1.0)
			"kill":
				for f in m.foes.duplicate():
					if is_instance_valid(f): f.take(99, 1.0)
			"win": m._finish(true)
			"lose": m._finish(false)
			"combo": m.combo = int(a[1]); m.combo_t = 2.8
			"hp": if m.hero: m.hero.hp = int(a[1])
			"tap":
				var ev := InputEventScreenTouch.new()
				ev.position = Vector2(float(a[1]), float(a[2]))
				ev.pressed = true
				ev.index = 0
				Input.parse_input_event(ev)
				var up := InputEventScreenTouch.new()
				up.position = ev.position
				up.pressed = false
				up.index = 0
				Input.parse_input_event.call_deferred(up)
			"press": Input.action_press(a[1])
			"release": Input.action_release(a[1])
			"shot":
				get_viewport().get_texture().get_image().save_png(a[1])
			"quit": get_tree().quit()
