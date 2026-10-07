extends Control
## HUD, menus and the phone controls (floating thumb-stick on the left, three buttons on the right).
## Everything is laid out from `size` and the display safe area, so notches and wide phones work.

const GOLD := Color("ffd23a")
const RED := Color("ff8a70")
var m: Node2D
var font: Font
var joy_id := -1
var joy_o := Vector2.ZERO
var joy_v := Vector2.ZERO
var held := {}       # touch index -> action
const STICK_R := 72.0     # how far the knob travels, in canvas px (about 7 mm on a phone)
const SLOTS := [[112.0, 118.0, 84.0], [286.0, 96.0, 74.0], [122.0, 300.0, 60.0]]   # button offsets from the bottom-right corner, radius
var stick := Vector2.ZERO # analog stick with the dead zone removed, length 0..1; chapters that steer in any direction read this
var _dirs := {"move_left": false, "move_right": false, "move_up": false, "move_down": false}
var _sa: Array = [0.0, 0.0, 0.0, 0.0]
var _sb_on: StyleBoxFlat
var _sb_off: StyleBoxFlat
var preview: Node2D  # the hero standing on the chapter screen
var _last_state := ""
var _t := 0.0

func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview = preload("res://skin.gd").new()
	preview.tex = load("res://art/hero_parts.png")
	preview.scale = Vector2(1.5, 1.5)
	add_child(preview)
	_sb_on = StyleBoxFlat.new()
	_sb_on.set_border_width_all(2)
	_sb_on.set_corner_radius_all(14)
	_sb_off = StyleBoxFlat.new()
	_sb_off.bg_color = Color(0.03, 0.04, 0.06, 0.74)
	_sb_off.border_color = Color(1, 1, 1, 0.22)
	_sb_off.set_border_width_all(1)
	_sb_off.set_corner_radius_all(14)

func _j() -> Node:
	return m.get("juice")

## Safe-area insets in canvas pixels: [left, top, right, bottom]. Measured once per frame.
func _safe() -> Array:
	return _sa

func _calc_safe() -> Array:
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0 or win.y <= 0.0:
		return [0.0, 0.0, 0.0, 0.0]
	var sa := Rect2(DisplayServer.get_display_safe_area())
	var k := size.x / win.x
	return [clampf(sa.position.x * k, 0.0, 120.0), clampf(sa.position.y * k, 0.0, 120.0),
		clampf((win.x - sa.end.x) * k, 0.0, 120.0), clampf((win.y - sa.end.y) * k, 0.0, 120.0)]

## The action buttons this chapter actually uses, in slot order: [action, label].
func _acts() -> Array:
	if m.ch:
		return m.ch.btn
	return [["attack", "ATK"], ["jump", "JUMP"], ["dash", "DASH"]]

func _buttons() -> Array:    # [action, centre, radius, label, colour]
	var s := size
	var sa := _safe()
	var out: Array = []
	var acts := _acts()
	for i in mini(acts.size(), SLOTS.size()):
		var sl: Array = SLOTS[i]
		var a: String = acts[i][0]
		var col: Color = GOLD if a == "attack" else (m.HEROES[m.hero_i] if a == "jump" else Color.WHITE)
		out.append([a, Vector2(s.x - sa[2] - sl[0], s.y - sa[3] - sl[1]), sl[2], acts[i][1], col])
	out.append(["pause", Vector2(s.x - sa[2] - 60.0, sa[1] + 124.0), 38.0, "II", Color.WHITE])
	return out

## HUD x of the left edge of the action buttons, with a margin; the full width when there are none.
func ctrl_left() -> float:
	var x := size.x
	if not m.touch:
		return x
	for b in _buttons():
		if b[0] != "pause":
			x = minf(x, b[1].x - b[2] - 24.0)
	return x

func _stick_home() -> Vector2:
	var sa := _safe()
	return Vector2(sa[0] + 170.0, size.y - sa[3] - 170.0)

## Turn the knob offset into input: an analog strength per direction, pressed with hysteresis so a
## resting thumb does not flicker, and only the dominant axis within ~27 degrees of it.
func _set_stick(off: Vector2) -> void:
	joy_v = off / STICK_R
	var l := joy_v.length()
	stick = Vector2.ZERO if l < 0.2 else joy_v / l * clampf(inverse_lerp(0.2, 0.92, l), 0.0, 1.0)
	var comps := {"move_left": -joy_v.x, "move_right": joy_v.x, "move_up": -joy_v.y, "move_down": joy_v.y}
	for a in comps:
		var c: float = comps[a]
		var other: float = absf(joy_v.y) if (a == "move_left" or a == "move_right") else absf(joy_v.x)
		var was: bool = _dirs[a]
		var on: bool = c > 0.2 if was else (c > 0.36 and c > other * 0.5)
		_dirs[a] = on
		if on:
			Input.action_press(a, clampf(inverse_lerp(0.2, 0.9, c), 0.35, 1.0))
		elif was:
			Input.action_release(a)

# ---- chapter screen layout: 4 columns, room for the hero preview on the right ----
func _grid() -> Dictionary:
	var gx := 14.0
	var cw := minf(276.0, (size.x - 250.0 - 62.0 - gx * 3.0) / 4.0)
	return {"x": 62.0, "y": 112.0, "cw": cw, "ch": 68.0, "gx": gx, "gy": 12.0}

func _menu_rect(i: int) -> Rect2:
	var g := _grid()
	return Rect2(g.x + (i % 4) * (g.cw + g.gx), g.y + (i / 4) * (g.ch + g.gy), g.cw, g.ch)

func _chip_rects() -> Dictionary:
	var sa := _safe()
	var x: float = size.x - sa[2] - 62.0
	var d := {"sound": Rect2(x - 118, 30, 118, 36)}
	if m.touch:
		d["haptics"] = Rect2(x - 118 - 12 - 136, 30, 136, 36)
	return d

func _pause_rects() -> Dictionary:
	var cx := size.x / 2.0
	return {"panel": Rect2(cx - 240, 190, 480, 380), "resume": Rect2(cx - 200, 270, 400, 56), "restart": Rect2(cx - 200, 336, 400, 56),
		"menu": Rect2(cx - 200, 402, 400, 56), "sound": Rect2(cx - 200, 490, 192, 44), "haptics": Rect2(cx + 8, 490, 192, 44)}

func _result_rects() -> Dictionary:
	var cx := size.x / 2.0
	return {"panel": Rect2(cx - 300, 140, 600, 440), "retry": Rect2(cx - 282, 500, 176, 56), "next": Rect2(cx - 88, 500, 176, 56), "menu": Rect2(cx + 106, 500, 176, 56)}

func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		var p: Vector2 = ev.position
		if ev.pressed:
			if m.state == "menu":
				_menu_tap(p)
				return
			if m.state == "result":
				_result_tap(p)
				return
			if m.state == "pause":
				_pause_tap(p)
				return
			if not m.touch or m.state != "play":
				return
			# the nearest button wins, with generous finger slop, so there is no dead seam between two buttons
			var bs := _buttons()
			var best := -1
			var bd := 34.0
			for i in bs.size():
				var d: float = p.distance_to(bs[i][1]) - bs[i][2]
				if d < bd:
					bd = d
					best = i
			if best >= 0:
				held[ev.index] = bs[best][0]
				Input.action_press(bs[best][0])
				if _j(): _j().haptic(8)
				return
			if p.x < size.x * 0.55 and joy_id < 0:
				joy_id = ev.index
				joy_o = p
				_set_stick(Vector2.ZERO)
		else:
			if held.has(ev.index):
				var a: String = held[ev.index]
				held.erase(ev.index)
				if not held.values().has(a):   # another finger may still be on the same button
					Input.action_release(a)
			if ev.index == joy_id:
				_drop_stick()
	elif ev is InputEventScreenDrag:
		if not m.touch or m.state != "play":
			return
		if ev.index != joy_id:
			# a thumb that was already resting on the glass when play began becomes the stick
			if joy_id < 0 and not held.has(ev.index) and ev.position.x < size.x * 0.55:
				joy_id = ev.index
				joy_o = ev.position
			else:
				return
		var off: Vector2 = ev.position - joy_o
		if off.length() > STICK_R:   # the centre follows the thumb, so reversing never needs a long drag back
			joy_o = ev.position - off.limit_length(STICK_R)
			off = ev.position - joy_o
		_set_stick(off)

func _drop_stick() -> void:
	joy_id = -1
	joy_v = Vector2.ZERO
	stick = Vector2.ZERO
	for a in _dirs:
		if _dirs[a]:
			Input.action_release(a)
		_dirs[a] = false

func _release_all() -> void:
	for a in held.values(): Input.action_release(a)
	held.clear()
	_drop_stick()

func _menu_tap(p: Vector2) -> void:
	var j := _j()
	var chips := _chip_rects()
	if chips["sound"].has_point(p) and j:
		j.toggle_sound(); return
	if chips.has("haptics") and chips["haptics"].has_point(p) and j:
		j.toggle_haptics(); return
	for i in m.LEVELS.size():
		if _menu_rect(i).has_point(p):
			m.sel = i
			if j and not j.has_chapter(m.LEVELS[i][1]):
				j.toast_show("coming soon")
				return
			m.start(m.LEVELS[i][1])
			return
	if p.y > 618 and p.y < 668:
		var ci := int((p.x - 90) / 52.0)
		if ci >= 0 and ci < m.HEROES.size(): m.hero_i = ci

func _pause_tap(p: Vector2) -> void:
	var r := _pause_rects()
	var j := _j()
	if r["resume"].has_point(p) or not r["panel"].has_point(p):
		m.state = "play"; Engine.time_scale = 1.0
	elif r["restart"].has_point(p) and j:
		j.restart()
	elif r["menu"].has_point(p):
		m._menu()
	elif r["sound"].has_point(p) and j:
		j.toggle_sound()
	elif r["haptics"].has_point(p) and j and m.touch:
		j.toggle_haptics()

func _result_tap(p: Vector2) -> void:
	if m.result_t < 0.8:
		return
	var r := _result_rects()
	var j := _j()
	if r["retry"].has_point(p) and j:
		j.restart()
	elif r["next"].has_point(p) and j and m.won and j.next_id() != "":
		var nx: String = j.next_id()
		m._menu()
		m.start(nx)
	elif r["menu"].has_point(p):   # only a real button leaves the screen; stray taps after a defeat do nothing
		m._menu()

func _process(delta: float) -> void:
	_t += delta
	_sa = _calc_safe()
	if m.state != _last_state:
		_last_state = m.state
		_release_all()
	preview.visible = m.state == "menu"
	if preview.visible:
		preview.tint = m.HEROES[m.hero_i]
		preview.position = Vector2(size.x - _safe()[2] - 130.0, 600.0)
		preview.pose = "idle"

# ---- drawing helpers ----
func _panel(r: Rect2, on := false, col := GOLD) -> void:
	if on:
		_sb_on.bg_color = Color(col.r, col.g, col.b, 0.16)
		_sb_on.border_color = col
	draw_style_box(_sb_on if on else _sb_off, r)

func _text(s: String, pos: Vector2, sz: int, col := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	draw_string(font, pos, s, align, w, sz, col)

func _button(r: Rect2, label: String, col := Color.WHITE, on := false, sz := 18) -> void:
	_panel(r, on, col)
	_text(label, Vector2(r.position.x, r.position.y + r.size.y / 2.0 + sz * 0.36), sz, col if on else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)

func _toggle(r: Rect2, label: String, on: bool) -> void:
	_panel(r, on, Color(0.6, 1.0, 0.7) if on else Color.WHITE)
	_text(label + ("  ON" if on else "  OFF"), Vector2(r.position.x, r.position.y + r.size.y / 2.0 + 5), 14, Color.WHITE if on else Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)

func _tick(p: Vector2, col := GOLD) -> void:
	draw_polyline(PackedVector2Array([p + Vector2(-7, 0), p + Vector2(-2, 5), p + Vector2(8, -6)]), col, 3.0, true)

func _vignette(a: float) -> void:
	if a <= 0.0:
		return
	var s := size
	var w := 170.0
	var o := Color(0.9, 0.1, 0.08, a * 0.75)
	var i := Color(0.9, 0.1, 0.08, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x - w, w), Vector2(w, w)]), PackedColorArray([o, o, i, i]))
	draw_polygon(PackedVector2Array([Vector2(0, s.y), Vector2(w, s.y - w), Vector2(s.x - w, s.y - w), Vector2(s.x, s.y)]), PackedColorArray([o, i, i, o]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, w), Vector2(w, s.y - w), Vector2(0, s.y)]), PackedColorArray([o, i, i, o]))
	draw_polygon(PackedVector2Array([Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(s.x - w, s.y - w), Vector2(s.x - w, w)]), PackedColorArray([o, o, i, i]))

func _fmt(t: float) -> String:
	return "%d:%02d.%d" % [int(t) / 60, int(t) % 60, int(t * 10) % 10]

func _glyph(action: String, c: Vector2, col: Color) -> void:
	match action:
		"attack":   # sword
			draw_line(c + Vector2(-16, 16), c + Vector2(16, -16), col, 4.0, true)
			draw_line(c + Vector2(-4, -10), c + Vector2(8, 2), col, 3.0, true)
			draw_line(c + Vector2(-14, 10), c + Vector2(-8, 18), col, 3.0, true)
		"jump":
			draw_polyline(PackedVector2Array([c + Vector2(-14, 6), c + Vector2(0, -8), c + Vector2(14, 6)]), col, 4.0, true)
		"dash":
			draw_polyline(PackedVector2Array([c + Vector2(-14, -10), c + Vector2(-4, 0), c + Vector2(-14, 10)]), col, 3.5, true)
			draw_polyline(PackedVector2Array([c + Vector2(0, -10), c + Vector2(10, 0), c + Vector2(0, 10)]), col, 3.5, true)
		"pause":
			draw_rect(Rect2(c + Vector2(-7, -8), Vector2(4, 16)), col)
			draw_rect(Rect2(c + Vector2(3, -8), Vector2(4, 16)), col)

func _draw_controls() -> void:
	for b in _buttons():
		var on: bool = Input.is_action_pressed(b[0])
		var col: Color = b[4]
		var r: float = b[2] * (0.92 if on else 1.0)
		draw_circle(b[1], r, Color(col.r, col.g, col.b, 0.30 if on else 0.10))
		draw_arc(b[1], r, 0, TAU, 56, Color(col.r, col.g, col.b, 0.9 if on else 0.5), 2.5 if on else 2.0, true)
		var small: bool = b[2] < 50.0
		_glyph(b[0], b[1] + (Vector2.ZERO if small else Vector2(0, -10)), Color(1, 1, 1, 0.95 if on else 0.8))
		if not small:
			_text(b[3], b[1] + Vector2(-b[2], 32 if b[2] > 60 else 28), 15 if b[2] > 60 else 13, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, b[2] * 2)
	var tint: Color = m.HEROES[m.hero_i]
	if joy_id >= 0:
		draw_arc(joy_o, STICK_R, 0, TAU, 56, Color(1, 1, 1, 0.35), 2.0, true)
		draw_circle(joy_o, STICK_R, Color(1, 1, 1, 0.04))
		draw_circle(joy_o + joy_v * STICK_R, 38.0, Color(tint.r, tint.g, tint.b, 0.45))
		draw_arc(joy_o + joy_v * STICK_R, 38.0, 0, TAU, 40, Color(1, 1, 1, 0.6), 2.0, true)
	else:
		var h := _stick_home()
		var a := 0.22 + 0.08 * sin(_t * 2.0)
		draw_arc(h, STICK_R, 0, TAU, 56, Color(1, 1, 1, a), 2.0, true)
		draw_circle(h, 38.0, Color(1, 1, 1, 0.06))
		_glyph("dash", h + Vector2(54, 0), Color(1, 1, 1, a))
		draw_set_transform(h + Vector2(-54, 0), PI, Vector2.ONE)
		_glyph("dash", Vector2.ZERO, Color(1, 1, 1, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_text("MOVE", h + Vector2(-50, 6), 14, Color(1, 1, 1, a + 0.15), HORIZONTAL_ALIGNMENT_CENTER, 100)

func _draw_menu() -> void:
	var s := size
	var sa := _safe()
	var j := _j()
	_text("STICKMAN", Vector2(62, 72), 50)
	_text("vs", Vector2(318, 72), 24, m.HEROES[m.hero_i])
	_text("GEOMETRY", Vector2(356, 72), 50)
	var done: int = j.save.cleared_count(m.LEVELS) if j else 0
	_text("CHAPTERS      %d / %d cleared" % [done, m.LEVELS.size()], Vector2(62, 100), 12, Color(1, 1, 1, 0.55))
	for i in m.LEVELS.size():
		var r := _menu_rect(i)
		var id: String = m.LEVELS[i][1]
		var ok: bool = j == null or j.has_chapter(id)
		var cl: bool = j != null and j.save.cleared(id)
		_panel(r, i == m.sel)
		var tc := GOLD if i == m.sel else Color.WHITE
		if not ok:
			tc.a = 0.38
		_text(m.LEVELS[i][0], r.position + Vector2(14, 28), 15, tc)
		_text(m.LEVELS[i][2] if ok else "coming soon", r.position + Vector2(14, 52), 12, Color(1, 1, 1, 0.62 if ok else 0.3))
		if cl:
			_tick(r.position + Vector2(r.size.x - 20, 24))
			var bt: float = j.save.best_time(id)
			if bt > 0.0:
				_text(_fmt(bt), r.position + Vector2(r.size.x - 86, 52), 11, Color(1, 0.85, 0.45, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, 72)
	var chips := _chip_rects()
	_toggle(chips["sound"], "SOUND", not m.mute)
	if chips.has("haptics"):
		_toggle(chips["haptics"], "HAPTICS", j.haptics_on if j else true)
	# the hero
	var hx: float = s.x - sa[2] - 130.0
	draw_line(Vector2(hx - 90, 602), Vector2(hx + 90, 602), Color(1, 1, 1, 0.5), 2.0, true)
	draw_set_transform(Vector2(hx, 603), 0.0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 36.0, Color(0, 0, 0, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_text("HERO COLOUR", Vector2(90, 612), 12, Color(1, 1, 1, 0.6))
	for i in m.HEROES.size():
		var c := Vector2(112 + i * 52, 644)
		draw_circle(c, 17.0 if i == m.hero_i else 12.0, m.HEROES[i])
		if i == m.hero_i: draw_arc(c, 23.0, 0, TAU, 32, Color.WHITE, 2.0, true)
	_text("tap a chapter to play" if m.touch else "arrows  choose      SHIFT  colour      ENTER  play", Vector2(90, 700), 15, Color(1, 1, 1, 0.6))
	var ver: String = "v" + (j.VERSION if j else "0.2")
	_text(ver, Vector2(s.x - sa[2] - 160, 700), 12, Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_RIGHT, 100)

func _draw() -> void:
	var s := size
	var j := _j()
	if m.state == "menu":
		_draw_menu()
		if j and j.toast_t > 0.0:
			_text(j.toast, Vector2(0, 672), 16, Color(1, 0.85, 0.45, minf(1.0, j.toast_t * 2.0)), HORIZONTAL_ALIGNMENT_CENTER, s.x)
		return
	var h = m.hero if m.hero else m.ch
	if h == null:
		return
	var fuel: float = h.fuel if m.hero else 1.0
	var sa := _safe()
	if j:
		_vignette(j.red)
	# chapter chip, health, combo
	var nm: String = "THE ARENA   wave %d / %d" % [m.wave + 1, m.WAVES.size()] if m.level == "arena" else m.LEVELS[m.sel][0]
	if m.ch and m.ch.title != "": nm = m.ch.title
	var lx: float = 16.0 + sa[0]
	var ty: float = sa[1]
	_panel(Rect2(lx, ty + 16, 26 + nm.length() * 9.5, 38))
	_text(nm, Vector2(lx + 14, ty + 42), 15)
	var x0: float = s.x - sa[2] - 28.0 - h.max_hp * 31.0
	var hurt_k: float = (j.red if j else 0.0)
	_panel(Rect2(x0 - 52, ty + 22, h.max_hp * 31.0 + 66, 36), hurt_k > 0.6, RED)
	_text("HP", Vector2(x0 - 40, ty + 46), 13, Color(1, 1, 1, 0.7))
	for i in h.max_hp:
		var c: Color = m.HEROES[m.hero_i] if i < h.hp else Color(1, 1, 1, 0.1)
		if i == h.hp and hurt_k > 0.0:
			c = Color(1, 0.35, 0.3, hurt_k)
		draw_rect(Rect2(x0 + i * 31.0, ty + 32, 26, 16), c)
	if fuel < 0.99:
		draw_rect(Rect2(x0, ty + 66, h.max_hp * 31.0 - 5.0, 5), Color(1, 1, 1, 0.12))
		draw_rect(Rect2(x0, ty + 66, (h.max_hp * 31.0 - 5.0) * maxf(0.0, fuel), 5), GOLD)
	if m.ch and m.ch.info != "":
		_panel(Rect2(lx, ty + 62, 24 + m.ch.info.length() * 7.6, 30))
		_text(m.ch.info, Vector2(lx + 12, ty + 83), 13, Color(1, 1, 1, 0.85))
	if m.combo > 1:
		var k: float = 1.0 + 0.4 * (j.combo_pop if j else 0.0)
		var cp := Vector2(s.x - sa[2] - 200, ty + 190)
		draw_set_transform(cp, 0.0, Vector2(k, k))
		_text("x%d" % m.combo, Vector2(-80, 0), 62, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 160)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var w: String = ["", "", "NICE", "NICE", "SHARP", "SHARP", "FIERCE", "FIERCE", "FIERCE", "SAVAGE"][mini(m.combo, 9)]
		_text(w, Vector2(cp.x - 80, cp.y + 30), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 160)
		draw_rect(Rect2(cp.x - 60, cp.y + 42, 120.0 * clampf(m.combo_t / 2.8, 0, 1), 4), GOLD)
	# chapter / wave banner
	if j and j.banner_t > 0.0 and m.state == "play":
		var u: float = j.banner_t / j.banner_dur
		var a: float = clampf((1.0 - u) * 5.0, 0.0, 1.0) * clampf(u * 3.0, 0.0, 1.0)
		var yb := 250.0 - (1.0 - a) * 10.0
		draw_rect(Rect2(0, yb - 52, s.x, 112), Color(0, 0, 0, 0.5 * a))
		draw_line(Vector2(s.x * 0.25, yb - 52), Vector2(s.x * 0.75, yb - 52), Color(1, 0.82, 0.23, a * 0.8), 2.0, true)
		draw_line(Vector2(s.x * 0.25, yb + 60), Vector2(s.x * 0.75, yb + 60), Color(1, 0.82, 0.23, a * 0.8), 2.0, true)
		_text(j.banner, Vector2(0, yb + 12), 44, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, s.x)
		if j.banner_sub != "":
			_text(j.banner_sub, Vector2(0, yb + 46), 17, Color(1, 0.9, 0.6, a), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	if m.state == "pause":
		var r := _pause_rects()
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.7))
		_panel(r["panel"])
		_text("PAUSED", Vector2(r["panel"].position.x, 244), 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r["panel"].size.x)
		_button(r["resume"], "RESUME", GOLD, true)
		_button(r["restart"], "RESTART CHAPTER")
		_button(r["menu"], "CHAPTERS")
		_toggle(r["sound"], "SOUND", not m.mute)
		if m.touch:
			_toggle(r["haptics"], "HAPTICS", j.haptics_on if j else true)
		if not m.touch:
			_text("P  resume          ENTER  chapters", Vector2(r["panel"].position.x, 556), 13, Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_CENTER, r["panel"].size.x)
	elif m.state == "result":
		var r := _result_rects()
		var a := clampf(m.result_t / 0.5, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.72 * a))
		var p: Rect2 = r["panel"]
		_panel(p, m.won and a >= 1.0, GOLD if m.won else RED)
		_text("CHAPTER COMPLETE" if m.won else "DEFEATED", Vector2(p.position.x, 205), 34, Color(GOLD.r, GOLD.g, GOLD.b, a) if m.won else Color(RED.r, RED.g, RED.b, a), HORIZONTAL_ALIGNMENT_CENTER, p.size.x)
		var name_i: int = (j.level_index(m.level) if j else -1)
		_text(m.LEVELS[name_i][0] if name_i >= 0 else m.level.to_upper(), Vector2(p.position.x, 235), 15, Color(1, 1, 1, 0.6 * a), HORIZONTAL_ALIGNMENT_CENTER, p.size.x)
		if m.won and j and j.grade != "":
			var gk := 1.0 + 0.5 * maxf(0.0, 1.0 - m.result_t * 3.0)
			draw_set_transform(Vector2(p.position.x + 120, 380), 0.0, Vector2(gk, gk))
			_text(j.grade, Vector2(-80, 32), 110, Color(GOLD.r, GOLD.g, GOLD.b, a), HORIZONTAL_ALIGNMENT_CENTER, 160)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_text("GRADE", Vector2(p.position.x + 40, 430), 13, Color(1, 1, 1, 0.5 * a), HORIZONTAL_ALIGNMENT_CENTER, 160)
		var sx := p.position.x + (240.0 if m.won else 60.0)
		var sw := p.size.x - (280.0 if m.won else 120.0)
		_text("time", Vector2(sx, 310), 14, Color(1, 1, 1, 0.55 * a), HORIZONTAL_ALIGNMENT_LEFT, sw)
		_text(_fmt(m.time), Vector2(sx, 310), 22, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_RIGHT, sw)
		if j and j.best_time > 0.0:
			_text("best", Vector2(sx, 342), 14, Color(1, 1, 1, 0.55 * a), HORIZONTAL_ALIGNMENT_LEFT, sw)
			_text(_fmt(minf(j.best_time, m.time) if m.won else j.best_time), Vector2(sx, 342), 18, Color(1, 0.85, 0.45, a), HORIZONTAL_ALIGNMENT_RIGHT, sw)
		_text("best combo", Vector2(sx, 378), 14, Color(1, 1, 1, 0.55 * a), HORIZONTAL_ALIGNMENT_LEFT, sw)
		_text("x%d" % m.best, Vector2(sx, 378), 22, Color(GOLD.r, GOLD.g, GOLD.b, a), HORIZONTAL_ALIGNMENT_RIGHT, sw)
		if m.level == "arena":
			_text("wave", Vector2(sx, 414), 14, Color(1, 1, 1, 0.55 * a), HORIZONTAL_ALIGNMENT_LEFT, sw)
			_text("%d / %d" % [m.wave + 1, m.WAVES.size()], Vector2(sx, 414), 22, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_RIGHT, sw)
		if j and j.new_best and m.won:
			var pulse := 0.8 + 0.2 * sin(_t * 8.0)
			_panel(Rect2(sx, 440, 120, 30), true, Color(0.6, 1.0, 0.7))
			_text("NEW BEST", Vector2(sx, 461), 14, Color(0.7, 1.0, 0.8, pulse * a), HORIZONTAL_ALIGNMENT_CENTER, 120)
		if m.result_t > 0.8:
			_button(r["retry"], "RETRY")
			var nx: String = j.next_id() if (j and m.won) else ""
			if nx != "":
				_button(r["next"], "NEXT", GOLD, true)
			else:
				_button(r["next"], "NEXT", Color(1, 1, 1, 0.3), false)
			_button(r["menu"], "CHAPTERS")
			if not m.touch:
				_text("ENTER  chapters", Vector2(p.position.x, 572), 12, Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_CENTER, p.size.x)
	elif m.touch:
		_draw_controls()
	if j and j.toast_t > 0.0:
		_text(j.toast, Vector2(0, s.y - sa[3] - 30), 16, Color(1, 0.85, 0.45, minf(1.0, j.toast_t * 2.0)), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	if j and j.flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, j.flash))
