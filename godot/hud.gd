extends Control
## HUD, menus and the phone controls (floating thumb-stick on the left, three buttons on the right).

const GOLD := Color("ffd23a")
var m: Node2D
var font: Font
var joy_id := -1
var joy_o := Vector2.ZERO
var joy_v := Vector2.ZERO
var held := {}       # touch index -> action

func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _buttons() -> Array:    # [action, centre, radius, label]
	var s := size
	return [["attack", Vector2(s.x - 150, s.y - 150), 88.0, "ATK"], ["jump", Vector2(s.x - 340, s.y - 110), 68.0, "JUMP"],
		["dash", Vector2(s.x - 120, s.y - 340), 58.0, "DASH"], ["pause", Vector2(s.x - 56, 118), 32.0, "II"]]

func _menu_rect(i: int) -> Rect2:
	return Rect2(90, 300 + i * 96, 520, 80)

func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		var p: Vector2 = ev.position
		if ev.pressed:
			if m.state == "menu":
				for i in m.LEVELS.size():
					if _menu_rect(i).has_point(p):
						m.sel = i
						m.start(m.LEVELS[i][1])
						return
				if p.y > 596 and p.y < 660:
					var ci := int((p.x - 90) / 52.0)
					if ci >= 0 and ci < m.HEROES.size(): m.hero_i = ci
				return
			if m.state == "result":
				if m.result_t > 0.8: m._menu()
				return
			if m.state == "pause":
				m.state = "play"; Engine.time_scale = 1.0
				return
			if not m.touch:
				return
			for b in _buttons():
				if p.distance_to(b[1]) < b[2] + 14.0:
					held[ev.index] = b[0]
					Input.action_press(b[0])
					return
			if p.x < size.x * 0.46 and joy_id < 0:
				joy_id = ev.index; joy_o = p; joy_v = Vector2.ZERO
		else:
			if held.has(ev.index):
				Input.action_release(held[ev.index]); held.erase(ev.index)
			if ev.index == joy_id:
				joy_id = -1; joy_v = Vector2.ZERO
				for a in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(a)
	elif ev is InputEventScreenDrag and ev.index == joy_id:
		var r := 100.0
		joy_v = (ev.position - joy_o).limit_length(r) / r
		_dir("move_left", joy_v.x < -0.32); _dir("move_right", joy_v.x > 0.32)
		_dir("move_up", joy_v.y < -0.55); _dir("move_down", joy_v.y > 0.55)

func _dir(a: String, on: bool) -> void:
	if on and not Input.is_action_pressed(a): Input.action_press(a)
	elif not on and Input.is_action_pressed(a): Input.action_release(a)

func _panel(r: Rect2, on := false) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.82, 0.23, 0.16) if on else Color(0.03, 0.04, 0.06, 0.74)
	sb.border_color = GOLD if on else Color(1, 1, 1, 0.22)
	sb.set_border_width_all(2 if on else 1)
	sb.set_corner_radius_all(14)
	draw_style_box(sb, r)

func _text(s: String, pos: Vector2, sz: int, col := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	draw_string(font, pos, s, align, w, sz, col)

func _draw() -> void:
	var s := size
	if m.state == "menu":
		_text("STICKMAN", Vector2(90, 150), 78)
		_text("vs", Vector2(92, 222), 30, m.HEROES[m.hero_i])
		_text("GEOMETRY", Vector2(140, 228), 78)
		for i in m.LEVELS.size():
			var r := _menu_rect(i)
			_panel(r, i == m.sel)
			_text(m.LEVELS[i][0], r.position + Vector2(28, 36), 26, GOLD if i == m.sel else Color.WHITE)
			_text(m.LEVELS[i][2], r.position + Vector2(28, 64), 15, Color(1, 1, 1, 0.7))
		_text("HERO COLOUR", Vector2(90, 586), 12, Color(1, 1, 1, 0.6))
		for i in m.HEROES.size():
			var c := Vector2(112 + i * 52, 628)
			draw_circle(c, 17.0 if i == m.hero_i else 12.0, m.HEROES[i])
			if i == m.hero_i: draw_arc(c, 23.0, 0, TAU, 32, Color.WHITE, 2.0, true)
		_text("tap a chapter to play" if m.touch else "up / down  choose      left / right  colour      ENTER  play", Vector2(90, 694), 15, Color(1, 1, 1, 0.6))
		return
	var h = m.hero
	if h == null:
		return
	# chapter chip, health, combo
	var nm: String = "THE ARENA   wave %d / %d" % [m.wave + 1, m.WAVES.size()] if m.level == "arena" else "THE LINE"
	_panel(Rect2(16, 16, 26 + nm.length() * 9.5, 38))
	_text(nm, Vector2(30, 42), 15)
	var x0: float = s.x - 28.0 - h.max_hp * 31.0
	_panel(Rect2(x0 - 52, 22, h.max_hp * 31.0 + 66, 36))
	_text("HP", Vector2(x0 - 40, 46), 13, Color(1, 1, 1, 0.7))
	for i in h.max_hp:
		draw_rect(Rect2(x0 + i * 31.0, 32, 26, 16), m.HEROES[m.hero_i] if i < h.hp else Color(1, 1, 1, 0.1))
	if h.fuel < 0.99:
		draw_rect(Rect2(x0, 66, h.max_hp * 31.0 - 5.0, 5), Color(1, 1, 1, 0.12))
		draw_rect(Rect2(x0, 66, (h.max_hp * 31.0 - 5.0) * maxf(0.0, h.fuel), 5), GOLD)
	if m.combo > 1:
		_text("x%d" % m.combo, Vector2(s.x - 230, 190), 62, GOLD)
		var w: String = ["", "", "NICE", "NICE", "SHARP", "SHARP", "FIERCE", "FIERCE", "FIERCE", "SAVAGE"][mini(m.combo, 9)]
		_text(w, Vector2(s.x - 226, 220), 18)
		draw_rect(Rect2(s.x - 230, 232, 120.0 * clampf(m.combo_t / 2.8, 0, 1), 4), GOLD)
	if m.state == "pause":
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.7))
		_panel(Rect2(s.x / 2 - 240, 250, 480, 190))
		_text("PAUSED", Vector2(s.x / 2 - 240, 320), 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 480)
		_text("P  resume          ENTER  chapters" if not m.touch else "tap to resume", Vector2(s.x / 2 - 240, 380), 16, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 480)
	elif m.state == "result":
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.72))
		_panel(Rect2(s.x / 2 - 280, 190, 560, 330))
		_text("CHAPTER COMPLETE" if m.won else "DEFEATED", Vector2(s.x / 2 - 280, 260), 34, GOLD if m.won else Color("ff8a70"), HORIZONTAL_ALIGNMENT_CENTER, 560)
		_text("time   %d:%02d" % [int(m.time) / 60, int(m.time) % 60], Vector2(s.x / 2 - 280, 330), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 560)
		_text("best combo   x%d" % m.best, Vector2(s.x / 2 - 280, 370), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 560)
		if m.result_t > 0.8:
			_text("tap to continue" if m.touch else "ENTER  continue", Vector2(s.x / 2 - 280, 460), 16, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 560)
	elif m.touch:
		for b in _buttons():
			var on: bool = Input.is_action_pressed(b[0])
			draw_circle(b[1], b[2], Color(1, 1, 1, 0.2 if on else 0.08))
			draw_arc(b[1], b[2], 0, TAU, 48, Color(1, 1, 1, 0.45), 2.0, true)
			_text(b[3], b[1] + Vector2(-b[2], 7), 20 if b[2] > 60 else 15, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, b[2] * 2)
		if joy_id >= 0:
			draw_arc(joy_o, 100.0, 0, TAU, 48, Color(1, 1, 1, 0.35), 2.0, true)
			draw_circle(joy_o + joy_v * 100.0, 42.0, Color(1, 1, 1, 0.3))
