extends Node2D
## Game flow: menu, two chapters (The Line, The Arena), results. Builds each level in code.

const GOLD := Color("ffd23a")
const HEROES := [Color("3aa0ff"), Color("ff6a0d"), Color("ff4a6a"), Color("5fe08a"), Color("b58cff"), Color("2ee6d6"), Color("f4f8ff"), Color("5a5478")]
const LEVELS := [["THE LINE", "line", "Cut through them and outrun the polytope"], ["THE ARENA", "arena", "Survive four waves and the champion"]]
const WAVES := [["tri", "tri", "riv"], ["riv", "riv", "dia", "dia"], ["dia", "dia", "dia", "riv", "riv", "tri"], ["hex", "riv", "riv", "dia", "dia"]]

var state := "menu"
var level := ""
var sel := 0
var hero_i := 0
var world: Node2D
var hero: CharacterBody2D
var cam: Camera2D
var fx: Node2D
var hud: Control
var bg: TextureRect
var foe_tex: Texture2D
var foes: Array = []
var combo := 0
var combo_t := 0.0
var best := 0
var time := 0.0
var shake := 0.0
var wave := 0
var queue: Array = []
var spawn_t := 0.0
var won := false
var result_t := 0.0
var chaser: Sprite2D
var chaser_x := 0.0
var goal_x := 0.0
var plats: Array = []
var ground_y := 560.0
var touch := false
var _shot := ""
var _frames := 0
var _bot := false

func _ready() -> void:
	for a in [["move_left", [KEY_LEFT, KEY_A]], ["move_right", [KEY_RIGHT, KEY_D]], ["move_up", [KEY_UP, KEY_W]], ["move_down", [KEY_DOWN, KEY_S]],
			["jump", [KEY_SPACE, KEY_UP, KEY_W]], ["attack", [KEY_Z, KEY_F, KEY_J]], ["dash", [KEY_SHIFT, KEY_C, KEY_K]], ["pause", [KEY_P, KEY_ESCAPE]], ["ok", [KEY_ENTER, KEY_SPACE]]]:
		if not InputMap.has_action(a[0]):
			InputMap.add_action(a[0])
			for k in a[1]:
				var e := InputEventKey.new()
				e.physical_keycode = k
				InputMap.action_add_event(a[0], e)
	foe_tex = load("res://art/foe_atlas.png")
	touch = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.get_environment("SVG_TOUCH") != ""
	var bl := CanvasLayer.new()
	bl.layer = -10
	add_child(bl)
	bg = TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(0.3, 0.3, 0.3)
	bl.add_child(bg)
	cam = Camera2D.new()
	add_child(cam)
	var hl := CanvasLayer.new()
	hl.layer = 10
	add_child(hl)
	hud = preload("res://hud.gd").new()
	hud.m = self
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hl.add_child(hud)
	_menu()
	# test hooks: SVG_LEVEL starts a chapter, SVG_SHOT saves a screenshot after a few seconds and quits
	_shot = OS.get_environment("SVG_SHOT")
	_bot = OS.get_environment("SVG_BOT") != ""
	var lv := OS.get_environment("SVG_LEVEL")
	if lv != "":
		start(lv)

func _menu() -> void:
	state = "menu"
	if world:
		world.queue_free()
		world = null
	hero = null
	foes.clear()
	bg.texture = load("res://art/bg_void.jpg")
	cam.position = Vector2(640, 360)
	Engine.time_scale = 1.0

func _solid(x: float, y: float, w: float, h: float, one_way := false) -> void:
	var b := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(w, h)
	cs.shape = sh
	cs.one_way_collision = one_way
	b.position = Vector2(x + w / 2.0, y + h / 2.0)
	b.add_child(cs)
	world.add_child(b)
	var ln := Line2D.new()
	ln.points = PackedVector2Array([Vector2(x, y), Vector2(x + w, y)])
	ln.width = 3.0
	ln.default_color = Color.WHITE
	world.add_child(ln)
	if not one_way and h > 40.0:
		var pg := Polygon2D.new()
		pg.polygon = PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + 260), Vector2(x, y + 260)])
		pg.color = Color(1, 1, 1, 0.04)
		world.add_child(pg)

func _spawn(kind: String, pos: Vector2, patrol := false) -> Node2D:
	var f = preload("res://foe.gd").new()
	world.add_child(f)
	f.setup(kind, pos, hero, foe_tex)
	f.patrol = patrol
	f.ground_y = ground_y
	f.died.connect(_on_foe_died)
	f.bumped.connect(_on_foe_bumped)
	foes.append(f)
	hero.foes = foes
	return f

func start(lv: String) -> void:
	if world:
		world.queue_free()
	world = Node2D.new()
	add_child(world)
	foes.clear()
	plats.clear()
	level = lv
	combo = 0; best = 0; time = 0.0; won = false; result_t = 0.0; wave = 0
	fx = preload("res://fx.gd").new()
	fx.z_index = 20
	world.add_child(fx)
	hero = preload("res://hero.gd").new()
	hero.z_index = 10
	world.add_child(hero)
	hero.skin.tint = HEROES[hero_i]
	hero.hurt_taken.connect(func(): combo = 0; shake = 14.0; fx.burst(hero.global_position + Vector2(0, -30), 14, HEROES[hero_i]))
	hero.throw_phi.connect(func(target): fx.bolts.append({"p": hero.global_position + Vector2(hero.face * 22, -46), "t": target, "l": 0.0}))
	if lv == "arena":
		bg.texture = load("res://art/bg_arena.jpg")
		bg.modulate = Color(0.42, 0.42, 0.42)
		ground_y = 560.0
		_solid(-400, 560, 2700, 400)
		_solid(-60, -600, 80, 1200); _solid(1880, -600, 80, 1200)
		_solid(300, 420, 260, 14, true); _solid(820, 320, 260, 14, true); _solid(1340, 420, 260, 14, true)
		hero.position = Vector2(950, 560)
		queue = WAVES[0].duplicate()
		spawn_t = 1.6
	else:
		bg.texture = load("res://art/bg_void.jpg")
		bg.modulate = Color(0.26, 0.26, 0.26)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var x := -300.0
		var y := 470.0
		_solid(x, y, 1500, 400); plats.append(Vector2(x + 300, y)); x += 1500
		while x < 12000.0:
			var gap := rng.randf_range(110, 190)
			y = clampf(y + rng.randf_range(-60, 60), 380, 560)
			x += gap
			var ln := rng.randf_range(430, 950)
			_solid(x, y, ln, 400)
			plats.append(Vector2(x + 50, y))
			ground_y = y
			if rng.randf() < 0.75:
				var k := "riv" if rng.randf() < 0.5 else "tri"
				_spawn(k, Vector2(x + ln * 0.8, y - (36.0 if k == "riv" else 26.0)), true)
			if gap > 150.0 and rng.randf() < 0.6:
				_spawn("dia", Vector2(x - gap / 2.0, y - 95.0), true)
			x += ln
		x += 140
		_solid(x, 470, 1700, 400); plats.append(Vector2(x + 50, 470))
		goal_x = x + 1150
		hero.position = Vector2(0, 470)
		chaser_x = -900.0
		chaser = Sprite2D.new()
		var at := AtlasTexture.new()
		at.atlas = foe_tex
		at.region = Rect2(0, 480, 160, 160)
		chaser.texture = at
		chaser.scale = Vector2(3.6, 3.6)
		world.add_child(chaser)
	cam.position = hero.position + Vector2(170, -140)
	state = "play"

func hitstop(sec: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(sec, true, false, true).timeout
	Engine.time_scale = 1.0

func _on_foe_died(f: Node2D) -> void:
	foes.erase(f)
	combo += 1
	combo_t = 2.8
	best = maxi(best, combo)
	shake = maxf(shake, 28.0 if f.kind == "hex" else 8.0)
	fx.burst(f.global_position, 90 if f.kind == "hex" else 24, GOLD, 700.0 if f.kind == "hex" else 420.0, 300.0)
	if level == "line":
		hero.rush = 2.2
		chaser_x -= 70.0
		if f.kind == "dia":   # flyers are stepping stones
			hero.velocity.y = minf(hero.velocity.y, -560.0)
			hero.dj = false
	hitstop(0.05)

func _on_foe_bumped(f: Node2D) -> void:
	shake = maxf(shake, 20.0 if f.kind == "hex" else 9.0)
	fx.burst(f.global_position, 14, Color.WHITE, 300.0)
	if f.dead:
		foes.erase(f)
		combo = 0

## Test pilot: walks at the nearest enemy and swings, jumps gaps. Used by automated runs only.
func _pilot() -> void:
	for a in ["move_left", "move_right", "jump", "attack"]: Input.action_release(a)
	var near: Node2D = null
	var bd := 1e9
	for f in foes:
		if is_instance_valid(f) and not f.dead:
			var d: float = f.global_position.distance_to(hero.global_position)
			if d < bd: bd = d; near = f
	if level == "arena":
		if near:
			var dx: float = near.global_position.x - hero.global_position.x
			if absf(dx) > 90.0: Input.action_press("move_right" if dx > 0.0 else "move_left")
			if near.global_position.y < hero.global_position.y - 150.0 and hero.is_on_floor(): Input.action_press("jump")
	else:
		Input.action_press("move_right")
		var ahead := false
		for p in plats:
			if absf(p.y - hero.position.y) < 90.0 and p.x - 50.0 > hero.position.x - 2000.0: pass
		var space := get_world_2d().direct_space_state
		var q := PhysicsRayQueryParameters2D.create(hero.global_position + Vector2(34, -20), hero.global_position + Vector2(34, 260))
		ahead = not space.intersect_ray(q).is_empty()
		if hero.is_on_floor() and not ahead: Input.action_press("jump")
		elif not hero.is_on_floor(): Input.action_press("jump")
	if _frames % 5 == 0 and near and bd < 240.0: Input.action_press("attack")

func _finish(win: bool) -> void:
	if _bot:
		print("RESULT ", level, " ", "win" if win else "lose", " time=", snappedf(time, 0.1), " hp=", hero.hp, " best_combo=", best, " wave=", wave + 1)
		get_tree().quit()
	won = win
	state = "result"
	result_t = 0.0
	Engine.time_scale = 1.0

func _process(delta: float) -> void:
	_frames += 1
	if _shot != "" and _frames == 240:
		get_viewport().get_texture().get_image().save_png(_shot)
		get_tree().quit()
	shake = maxf(0.0, shake - delta * 40.0)
	hud.queue_redraw()
	if state == "menu":
		if Input.is_action_just_pressed("move_down"): sel = (sel + 1) % LEVELS.size()
		if Input.is_action_just_pressed("move_up"): sel = (sel + LEVELS.size() - 1) % LEVELS.size()
		if Input.is_action_just_pressed("move_right"): hero_i = (hero_i + 1) % HEROES.size()
		if Input.is_action_just_pressed("move_left"): hero_i = (hero_i + HEROES.size() - 1) % HEROES.size()
		if Input.is_action_just_pressed("ok"): start(LEVELS[sel][1])
		return
	if state == "result":
		result_t += delta
		if result_t > 0.8 and Input.is_action_just_pressed("ok"): _menu()
		return
	if Input.is_action_just_pressed("pause"):
		state = "pause" if state == "play" else "play"
		get_tree().paused = false
		Engine.time_scale = 0.0 if state == "pause" else 1.0
	if state == "pause":
		if Input.is_action_just_pressed("ok"): _menu()
		return
	if _bot: _pilot()
	time += delta
	combo_t -= delta
	if combo_t <= 0.0: combo = 0
	# thrown φ homes on its target
	for b in fx.bolts:
		b["l"] += delta
		if is_instance_valid(b["t"]) and not b["t"].dead:
			var to: Vector2 = b["t"].global_position - b["p"]
			b["p"] += to.normalized() * 1050.0 * delta
			if to.length() < b["t"].r + 16.0:
				b["t"].take(1, signf(to.x))
				b["l"] = 9.0
		else:
			b["l"] = 9.0
	fx.bolts = fx.bolts.filter(func(b): return b["l"] < 1.2)
	if level == "arena":
		if queue.size() > 0:
			spawn_t -= delta
			if spawn_t <= 0.0:
				spawn_t = 0.9
				var k: String = queue.pop_front()
				var side := -1.0 if randf() < 0.5 else 1.0
				var px := clampf(hero.position.x + side * randf_range(520, 740), 80, 1820)
				_spawn(k, Vector2(px, 560.0 - 40.0 if k in ["tri", "riv", "hex"] else randf_range(170, 340)))
		elif foes.is_empty():
			if wave < WAVES.size() - 1:
				wave += 1
				queue = WAVES[wave].duplicate()
				spawn_t = 1.8
				hero.hp = mini(hero.max_hp, hero.hp + 1)
			else:
				_finish(true)
		cam.position = cam.position.lerp(Vector2(clampf(hero.position.x, 640, 1280), 300), delta * 5.0)
	else:
		var gap := hero.position.x - chaser_x
		var v := 292.0 + minf(hero.position.x / 12000.0, 1.0) * 66.0
		if gap > 820.0: v = 440.0
		chaser_x += v * delta
		chaser.position = Vector2(chaser_x, hero.position.y - 150.0).lerp(chaser.position, 0.9) if chaser.position != Vector2.ZERO else Vector2(chaser_x, 320)
		chaser.position.x = chaser_x
		chaser.rotation += delta * 2.0
		shake = maxf(shake, clampf(1.0 - (gap - 150.0) / 400.0, 0.0, 1.0) * 5.0)
		if randf() < delta * 40.0: fx.burst(Vector2(chaser_x + 120, hero.position.y - randf() * 60.0), 2, Color.WHITE, 420.0)
		if gap < 125.0: hero.hp = 0
		if hero.position.y > 1150.0:   # fell: back to the last platform, at the cost of a life
			hero.hp -= 1
			combo = 0
			var cp: Vector2 = plats[0]
			for p in plats:
				if p.x <= hero.position.x: cp = p
			hero.position = cp
			hero.velocity = Vector2.ZERO
			chaser_x = minf(chaser_x, cp.x - 720.0)
		if hero.position.x > goal_x: _finish(true)
		cam.position = cam.position.lerp(hero.position + Vector2(170, -140), delta * 6.0)
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	if hero.hp <= 0: _finish(false)
