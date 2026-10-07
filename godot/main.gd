extends Node2D
## Game flow: menu, chapters, results, sound. The two free-running platform chapters are built here;
## every other chapter is a script in res://ch/ extending chapter.gd.

const GOLD := Color("ffd23a")
const HEROES := [Color("3aa0ff"), Color("ff6a0d"), Color("ff4a6a"), Color("5fe08a"), Color("b58cff"), Color("2ee6d6"), Color("f4f8ff"), Color("5a5478")]
const LEVELS := [["I  THE LINE", "line", "outrun the polytope"], ["II  THE GOLDEN SPIRAL", "spiral", "the golden ratio"], ["III  THE ANGLE", "angle", "inclined plane"],
	["IV  THE VOID", "void", "free fall"], ["V  THE TESSERACT", "tess", "the pendulum"], ["VI  THE GOLDEN BLOCKS", "blocks", "scaling"],
	["VII  THE PARABOLA", "parabola", "projectile motion"], ["VIII  THE CHARGE", "charge", "electric field"], ["IX  THE ORBIT", "orbit", "gravitation"],
	["X  THE SINE WAVE", "sine", "waves"], ["XI  THE PRIMES", "primes", "number theory"], ["XII  THE MIRROR", "mirror", "optics"],
	["XIII  THE COASTER", "coaster", "conservation of energy"], ["XIV  THE GALTON BOARD", "galton", "probability"], ["XV  THE MOLECULE", "molecule", "chemical bonding"],
	["XVI  THE REACTION", "reaction", "conservation of mass"], ["XVII  THE CELL", "cell", "immunity"], ["XVIII  THE HELIX", "helix", "DNA base pairing"],
	["XIX  THE ARENA", "arena", "momentum"], ["XX  THE SKY", "sky", "flight"], ["XXI  THE PENTAGON", "pentagon", "the boss"], ["XXII  THE DODECAHEDRON", "dodeca", "the ending"]]
const BGS := {"line": "void", "spiral": "void", "angle": "void", "void": "void", "tess": "void", "blocks": "lab", "parabola": "lab", "charge": "lab", "orbit": "void",
	"sine": "lab", "primes": "lab", "mirror": "lab", "coaster": "lab", "galton": "lab", "molecule": "lab", "reaction": "lab", "cell": "lab", "helix": "lab",
	"arena": "arena", "sky": "sky", "pentagon": "gold", "dodeca": "gold"}
const CALM := ["blocks", "parabola", "mirror", "reaction", "galton", "dodeca", "molecule"]
const WAVES := [["tri", "tri", "riv"], ["riv", "riv", "dia", "dia"], ["dia", "dia", "dia", "riv", "riv", "tri"], ["hex", "riv", "riv", "dia", "dia"]]

var state := "menu"
var level := ""
var sel := 0
var hero_i := 0
var world: Node2D
var hero: CharacterBody2D
var ch: Node2D
var cam: Camera2D
var fx: Node2D
var hud: Control
var juice: Node        # game feel, haptics, save file, phone glue (juice.gd)
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
var mute := false
var _shot := ""
var _frames := 0
var _bot := false
var _rand := false
var _sfx := {}
var _pool: Array = []
var _music: AudioStreamPlayer

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
	for n in ["jump", "djump", "dash", "slash", "hit", "hurt", "phi", "throw", "tick", "boom", "clear"]:
		_sfx[n] = load("res://sfx/%s.wav" % n)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -9.0
	add_child(_music)
	var bl := CanvasLayer.new()
	bl.layer = -10
	add_child(bl)
	bg = TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
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
	juice = preload("res://juice.gd").new()
	juice.m = self
	add_child(juice)
	_menu()
	# test hooks: SVG_LEVEL starts a chapter, SVG_SHOT saves a screenshot and quits, SVG_BOT / SVG_RAND drive input
	_shot = OS.get_environment("SVG_SHOT")
	_bot = OS.get_environment("SVG_BOT") != ""
	_rand = OS.get_environment("SVG_RAND") != ""
	var lv := OS.get_environment("SVG_LEVEL")
	if lv != "":
		start(lv)

func snd(n: String, vol := 0.0) -> void:
	if mute or not _sfx.has(n):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _sfx[n]
			p.volume_db = vol
			p.pitch_scale = randf_range(0.94, 1.06)   # no two hits sound identical
			p.play()
			return

func music(n: String) -> void:
	var st: AudioStreamWAV = load("res://sfx/music_%s.wav" % n)
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_end = st.data.size() / 2
	_music.stream = st
	_music.play()

func _menu() -> void:
	state = "menu"
	if world:
		world.queue_free()
		world = null
	hero = null
	ch = null
	foes.clear()
	_set_bg("void")
	cam.position = Vector2(640, 360)
	Engine.time_scale = 1.0
	music("calm")

func _set_bg(n: String) -> void:
	bg.texture = load("res://art/bg_%s.jpg" % n)
	bg.modulate = {"void": Color(0.26, 0.26, 0.26), "lab": Color(0.5, 0.5, 0.5), "arena": Color(0.42, 0.42, 0.42), "sky": Color(0.5, 0.5, 0.5), "gold": Color(0.4, 0.4, 0.4)}[n]

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
	if lv != "line" and lv != "arena":   # a chapter that isn't there yet (or doesn't compile) must not crash the phone
		var scr: Script = load("res://ch/%s.gd" % lv) if ResourceLoader.exists("res://ch/%s.gd" % lv) else null
		if scr == null or not scr.can_instantiate():
			juice.toast_show("coming soon")
			return
	if world:
		world.queue_free()
	world = Node2D.new()
	add_child(world)
	foes.clear()
	plats.clear()
	hero = null
	ch = null
	level = lv
	combo = 0; best = 0; time = 0.0; won = false; result_t = 0.0; wave = 0
	fx = preload("res://fx.gd").new()
	fx.z_index = 20
	world.add_child(fx)
	_set_bg(BGS.get(lv, "void"))
	music("calm" if lv in CALM else "action")
	cam.position = Vector2(640, 360)
	state = "play"
	if lv != "line" and lv != "arena":
		ch = load("res://ch/%s.gd" % lv).new()
		world.add_child(ch)
		ch.setup(self)
		return
	hero = preload("res://hero.gd").new()
	hero.z_index = 10
	world.add_child(hero)
	hero.skin.tint = HEROES[hero_i]
	hero.hurt_taken.connect(func(): combo = 0; shake = 14.0; snd("hurt"); fx.burst(hero.global_position + Vector2(0, -30), 14, HEROES[hero_i]))
	hero.throw_phi.connect(func(target): snd("throw"); fx.bolts.append({"p": hero.global_position + Vector2(hero.face * 22, -46), "t": target, "l": 0.0}))
	hero.sound.connect(snd)
	if lv == "arena":
		ground_y = 560.0
		_solid(-400, 560, 2700, 400)
		_solid(-60, -600, 80, 1200); _solid(1880, -600, 80, 1200)
		_solid(300, 420, 260, 14, true); _solid(820, 320, 260, 14, true); _solid(1340, 420, 260, 14, true)
		hero.position = Vector2(950, 560)
		queue = WAVES[0].duplicate()
		spawn_t = 1.6
	else:
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
				_spawn(k, Vector2(x + ln * 0.8, y - (46.0 if k == "riv" else 26.0)), true)
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

func hitstop(sec: float) -> void:
	if juice:
		juice.hitstop(sec)   # juice owns the clock, so a freeze and a slow-down never fight

func _on_foe_died(f: Node2D) -> void:
	foes.erase(f)
	combo += 1
	combo_t = 2.8
	best = maxi(best, combo)
	shake = maxf(shake, 28.0 if f.kind == "hex" else 8.0)
	snd("boom" if f.kind == "hex" else "hit")
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
	snd("hit", -4.0)
	fx.burst(f.global_position, 14, Color.WHITE, 300.0)
	if f.dead:
		foes.erase(f)
		combo = 0

## Test pilot for the two platform chapters. Automated runs only.
func _pilot() -> void:
	for a in ["move_left", "move_right", "attack"]: Input.action_release(a)
	var want_jump := false
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
			want_jump = near.global_position.y < hero.global_position.y - 150.0 and hero.is_on_floor()
	else:
		Input.action_press("move_right")
		var space := get_world_2d().direct_space_state
		var q := PhysicsRayQueryParameters2D.create(hero.global_position + Vector2(34, -20), hero.global_position + Vector2(34, 260))
		var ahead := not space.intersect_ray(q).is_empty()
		# play it like a person: hold jump through the air, let go for a moment while falling so the next press is the double jump, then keep holding to fly
		if hero.is_on_floor(): want_jump = not ahead
		else: want_jump = not (hero.velocity.y > 50.0 and not hero.dj and not ahead and _frames % 2 == 0)
	if want_jump: Input.action_press("jump")
	else: Input.action_release("jump")
	if _frames % 5 == 0 and near and bd < 240.0: Input.action_press("attack")

func _finish(win: bool) -> void:
	if state != "play":
		return
	if _bot or _rand:
		print("RESULT ", level, " ", "win" if win else "lose", " time=", snappedf(time, 0.1), " best_combo=", best, " wave=", wave + 1, " hp=", (hero.hp if hero else (ch.hp if ch else -1)), " x=", (int(hero.position.x) if hero else -1))
		get_tree().quit()
	won = win
	state = "result"
	result_t = 0.0
	Engine.time_scale = 1.0
	snd("clear" if win else "hurt")

func _process(delta: float) -> void:
	_frames += 1
	if _shot != "" and _frames == 240:
		get_viewport().get_texture().get_image().save_png(_shot)
		get_tree().quit()
	if _rand and state == "play":   # random mashing, to flush out runtime errors
		for a in ["move_left", "move_right", "move_up", "move_down", "jump", "attack", "dash"]:
			if randf() < 0.08: Input.action_press(a)
			elif randf() < 0.12: Input.action_release(a)
		if _frames > 1500: _finish(false)
	shake = maxf(0.0, shake - delta * 40.0)
	hud.queue_redraw()
	if state == "menu":
		if Input.is_action_just_pressed("move_down"): sel = mini(sel + 4, LEVELS.size() - 1)
		if Input.is_action_just_pressed("move_up"): sel = maxi(sel - 4, 0)
		if Input.is_action_just_pressed("move_right"): sel = mini(sel + 1, LEVELS.size() - 1)
		if Input.is_action_just_pressed("move_left"): sel = maxi(sel - 1, 0)
		if Input.is_action_just_pressed("dash"): hero_i = (hero_i + 1) % HEROES.size()
		if Input.is_action_just_pressed("ok"): start(LEVELS[sel][1])
		return
	if state == "result":
		result_t += delta
		if result_t > 0.8 and Input.is_action_just_pressed("ok"): _menu()
		return
	if Input.is_action_just_pressed("pause"):
		state = "pause" if state == "play" else "play"
		Engine.time_scale = 0.0 if state == "pause" else 1.0
	if state == "pause":
		if Input.is_action_just_pressed("ok"): _menu()
		return
	time += delta
	combo_t -= delta
	if combo_t <= 0.0: combo = 0
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	if ch:
		return
	if _bot: _pilot()
	for b in fx.bolts:   # thrown φ homes on its target
		b["l"] += delta
		if is_instance_valid(b["t"]) and not b["t"].dead:
			var to: Vector2 = b["t"].global_position - b["p"]
			b["p"] += to.normalized() * 1050.0 * delta
			if to.length() < b["t"].r + 16.0:
				b["t"].take(1, signf(to.x))
				snd("hit", -3.0)
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
				var edge: float = hud.size.x / 2.0 + 70.0   # just off screen, so they walk in instead of appearing under a thumb
				var px := clampf(cam.position.x + side * edge, 80, 1820)
				if absf(px - hero.position.x) < 420.0:
					px = clampf(cam.position.x - side * edge, 80, 1820)
				_spawn(k, Vector2(px, 560.0 - 46.0 if k in ["tri", "riv", "hex"] else randf_range(170, 340)))
		elif foes.is_empty():
			if wave < WAVES.size() - 1:
				wave += 1
				queue = WAVES[wave].duplicate()
				spawn_t = 1.8
				hero.hp = mini(hero.max_hp, hero.hp + 1)
				snd("clear", -6.0)
			else:
				_finish(true)
		# The camera moves only when the hero reaches the left thumb or the buttons, so he is never under a hand.
		var hw: float = hud.size.x / 2.0
		var lo: float = (280.0 if touch else 120.0) - hw
		var hi: float = ((hud.ctrl_left() - 70.0) if touch else (hud.size.x - 120.0)) - hw
		var want := clampf(clampf(cam.position.x, hw - 60.0, 1960.0 - hw), hero.position.x - hi, hero.position.x - lo)
		cam.position = Vector2(lerpf(cam.position.x, want, minf(1.0, delta * 14.0)), lerpf(cam.position.y, 300.0, delta * 5.0))
	else:
		var gap := hero.position.x - chaser_x
		var v := 292.0 + minf(hero.position.x / 12000.0, 1.0) * 66.0
		if gap > 820.0: v = 440.0
		if hero.position.x < 140.0 and time < 8.0: v = 0.0   # the wave waits for the first steps, so finding the stick is never fatal
		chaser_x += v * delta
		chaser.position = Vector2(chaser_x, lerpf(chaser.position.y if chaser.position != Vector2.ZERO else 320.0, hero.position.y - 150.0, delta * 3.0))
		chaser.rotation += delta * 2.0
		shake = maxf(shake, clampf(1.0 - (gap - 150.0) / 400.0, 0.0, 1.0) * 5.0)
		if randf() < delta * 40.0: fx.burst(Vector2(chaser_x + 120, hero.position.y - randf() * 60.0), 2, Color.WHITE, 420.0)
		if gap < 125.0: hero.hp = 0
		if hero.position.y > 1150.0:   # fell: back to the last platform, at the cost of a life
			hero.hp -= 1
			combo = 0
			snd("hurt")
			var cp: Vector2 = plats[0]
			for p in plats:
				if p.x <= hero.position.x: cp = p
			hero.position = cp
			hero.velocity = Vector2.ZERO
			chaser_x = minf(chaser_x, cp.x - 720.0)
		if hero.position.x > goal_x: _finish(true)
		# follow sideways quickly but only drift up and down, so every jump does not shake the view
		cam.position = Vector2(lerpf(cam.position.x, hero.position.x + 170.0, minf(1.0, delta * 6.0)), lerpf(cam.position.y, hero.position.y - 140.0, minf(1.0, delta * 2.6)))
	if hero.hp <= 0: _finish(false)

## Phone vibration; chapters call this guarded with has_method.
func haptic(ms: int) -> void:
	juice.haptic(ms)
