extends Node2D
# Dev only: plays each acrobatic move on a bare floor and saves filmstrips (SVG_SHOT=<prefix>). Needs a real window.
const FLOOR := 560.0
const CW := 300
const CH := 320
const PER := 6
var cam: Camera2D
var hero: CharacterBody2D
var n := 0
var mi := -1
var t0 := 0
var shots: Array = []
var sheet: Image
var row := 0
var page := 0
# name, [[frame, action, strength (0 = release)], ...], first capture frame, frames between captures
var moves := [
	["roll", [[0, "move_right", 1.0], [22, "dash", 1.0], [24, "dash", 0.0]], 22, 4],
	["somersault", [[0, "move_right", 1.0], [10, "jump", 1.0], [14, "jump", 0.0], [30, "jump", 1.0], [33, "jump", 0.0]], 30, 5],
	["backflip", [[0, "move_down", 1.0], [10, "jump", 1.0], [14, "jump", 0.0]], 11, 7],
	["slide", [[0, "move_right", 1.0], [26, "move_down", 1.0]], 26, 6],
	["air spin", [[0, "move_right", 0.5], [10, "jump", 1.0], [26, "jump", 0.0], [24, "attack", 1.0], [26, "attack", 0.0]], 25, 4],
	["plunge", [[10, "jump", 1.0], [14, "jump", 0.0], [28, "jump", 1.0], [31, "jump", 0.0], [44, "move_down", 1.0], [46, "attack", 1.0], [48, "attack", 0.0]], 47, 3],
	["landing roll", [[0, "move_right", 1.0], [10, "jump", 1.0], [26, "jump", 0.0], [30, "jump", 1.0], [44, "jump", 0.0]], 75, 4],
	["roll, then jump", [[0, "move_right", 1.0], [22, "dash", 1.0], [24, "dash", 0.0], [32, "jump", 1.0], [44, "jump", 0.0]], 24, 5],
	["skid", [[0, "move_right", 1.0], [30, "move_right", 0.0], [30, "move_left", 1.0]], 30, 2],
	["slide, then strike", [[0, "move_right", 1.0], [26, "move_down", 1.0], [36, "attack", 1.0], [38, "attack", 0.0]], 30, 5],
	["rising and slam", [[4, "move_up", 1.0], [6, "attack", 1.0], [8, "attack", 0.0], [30, "move_up", 0.0], [30, "move_down", 1.0], [32, "attack", 1.0], [34, "attack", 0.0]], 9, 8],
	["combo", [[6, "attack", 1.0], [8, "attack", 0.0], [24, "attack", 1.0], [26, "attack", 0.0], [42, "attack", 1.0], [44, "attack", 0.0]], 10, 9],
]

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("0b1020"))
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "attack", "dash"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
	var fl := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(6000, 200)
	cs.shape = rs
	fl.position = Vector2(1000, FLOOR + 100)
	fl.add_child(cs)
	add_child(fl)
	var l := Line2D.new()
	l.points = PackedVector2Array([Vector2(-2000, FLOOR), Vector2(4000, FLOOR)])
	l.default_color = Color(1, 1, 1, 0.5); l.width = 2
	add_child(l)
	cam = Camera2D.new()
	cam.zoom = Vector2(1.6, 1.6)
	add_child(cam)
	_next()

func _next() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "attack", "dash"]:
		Input.action_release(a)
	if hero:
		hero.queue_free()
	mi += 1
	if mi >= moves.size():
		_save()
		get_tree().quit()
		return
	hero = preload("res://hero.gd").new()
	hero.position = Vector2(600, FLOOR)
	add_child(hero)
	t0 = n + 20      # let it settle on the floor first
	shots = []

func _save() -> void:
	if sheet:
		sheet.save_png("%s_%d.png" % [OS.get_environment("SVG_SHOT"), page])
		sheet = null

func _process(_d: float) -> void:
	n += 1
	if mi >= moves.size():
		return
	var f := n - t0
	cam.position = hero.position + Vector2(0, -56)
	var mv: Array = moves[mi]
	for e in mv[1]:
		if e[0] == f:
			if e[2] > 0.0: Input.action_press(e[1], e[2])
			else: Input.action_release(e[1])
	if f >= mv[2] and (f - mv[2]) % int(mv[3]) == 0 and shots.size() < PER:
		RenderingServer.force_draw(false)   # a window that is covered or on another desktop is not drawn otherwise
		var img := get_viewport().get_texture().get_image()
		shots.append(img.get_region(Rect2i(img.get_width() / 2 - CW / 2, img.get_height() / 2 - CH / 2, CW, CH)))
		if shots.size() == PER:
			if sheet == null:
				sheet = Image.create(CW * PER, CH * 4, false, shots[0].get_format())
				sheet.fill(Color("0b1020"))
				row = 0
			for i in PER:
				sheet.blit_rect(shots[i], Rect2i(0, 0, CW, CH), Vector2i(i * CW, row * CH))
			print("MOVE ", mv[0], " row ", row, " page ", page, "  x=", int(hero.position.x))
			row += 1
			if row == 4:
				_save()
				page += 1
			_next()
