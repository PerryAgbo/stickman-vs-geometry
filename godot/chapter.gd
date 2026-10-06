extends Node2D
## Base for chapters that run their own rules (everything except the two free-running platform chapters).

const GOLD := Color("ffd23a")
const BLUE := Color("6fd0ff")
const RED := Color("ff5a3a")
const W := 1280.0
const H := 720.0

var m
var t := 0.0
var hp := 3
var max_hp := 3
var inv := 0.0
var title := ""
var info := ""
var skin: Node2D
var font: Font
var foe_tex: Texture2D

func setup(main) -> void:
	m = main
	font = ThemeDB.fallback_font
	foe_tex = m.foe_tex
	skin = preload("res://skin.gd").new()
	skin.tex = load("res://art/hero_parts.png")
	skin.tint = m.HEROES[m.hero_i]
	skin.z_index = 5
	skin.visible = false
	add_child(skin)
	begin()

func begin() -> void:
	pass

func tick(_d: float) -> void:
	pass

func _process(d: float) -> void:
	if m.state != "play":
		return
	t += d
	inv -= d
	tick(d)
	queue_redraw()

func act() -> bool:
	return Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("jump")

func ax() -> float:
	return Input.get_axis("move_left", "move_right")

func ay() -> float:
	return Input.get_axis("move_up", "move_down")

func hurt() -> bool:
	if inv > 0.0 or hp <= 0:
		return false
	hp -= 1
	inv = 1.1
	m.shake = 14.0
	m.combo = 0
	m.snd("hurt")
	if hp <= 0:
		m._finish(false)
	return true

func score(pos := Vector2.INF) -> void:
	m.combo += 1
	m.combo_t = 2.8
	m.best = maxi(m.best, m.combo)
	if pos != Vector2.INF:
		m.fx.burst(pos, 18, GOLD, 420.0, 200.0)

func txt(s: String, pos: Vector2, sz := 18, col := Color.WHITE, center := false) -> void:
	if center:
		draw_string(font, pos - Vector2(500, 0), s, HORIZONTAL_ALIGNMENT_CENTER, 1000, sz, col)
	else:
		draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

func phi(pos: Vector2, s: float, col := GOLD, rot := 0.35) -> void:
	draw_set_transform(pos, rot, Vector2.ONE)
	draw_arc(Vector2.ZERO, s * 0.4, 0, TAU, 24, col, s * 0.17, true)
	draw_line(Vector2(0, -s * 0.85), Vector2(0, s * 0.85), col, s * 0.09, true)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func dot(pos: Vector2, r := 5.0) -> void:
	draw_circle(pos, r, Color.BLACK)
	draw_arc(pos, r, 0, TAU, 16, Color.WHITE, 1.5, true)

func foe(kind: String, pos: Vector2, r: float, col := Color.WHITE) -> void:
	var d := r * 3.3
	var row: int = {"tri": 0, "sq": 1, "dia": 2, "hex": 3, "dart": 4}[kind]
	draw_texture_rect_region(foe_tex, Rect2(pos.x - d / 2.0, pos.y - d / 2.0, d, d), Rect2((int(t * 9.0) % 8) * 160, row * 160, 160, 160), col)

func hero_at(pos: Vector2, pose: String, rot := 0.0, face := 1) -> void:
	skin.visible = not (inv > 0.0 and int(inv * 14.0) % 2 == 1)
	skin.position = pos
	skin.pose = pose
	skin.rotation = rot
	skin.scale.x = face
	skin.ph = t * 13.0
