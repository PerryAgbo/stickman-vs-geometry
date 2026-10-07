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
var btn: Array = [["attack", "ATK"], ["jump", "JUMP"]]   # on-screen buttons this chapter uses: [action, label], most used first
var can_dash := false             # plat_step chapters that offer the dash
var dash_t := 0.0
var dash_cd := 0.0
var dash_buf := 0.0
var atk_buf := 0.0
var safe := 0.0                   # untouchable without the hurt blink (rolls, flips)
# acrobatics shared by the plat_step chapters, mirroring hero.gd
var acro := true                  # stick-down moves (slide, backflip, plunge); off where down means something else
var plat := false                 # plat_step is driving the hero
var aloft := false
var air_h := 0.0                  # clear height under the hero
var roll := false                 # the dash under way is a roll along the ground
var slide_t := 0.0
var slide_cd := 0.0
var slide_ok := true
var bflip_t := 0.0
var lroll_t := 0.0
var plunging := false
var plunge_cd := 0.0
var pogo := false
var boom := 0.0
var stall := true
var stall_req := false
var rush := 0.0
var tumble := 0.0
var tumble_left := 0.0
var tumble_rate := 0.0
var cam_p := Vector2(640, 360)    # world point shown at screen centre
var cam_z := 1.0
var _xf := Transform2D.IDENTITY

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
	# effects are spawned in this chapter's world coordinates, so their layer follows this chapter's camera
	m.fx.position = Vector2(640, 360) - cam_p * cam_z
	m.fx.scale = Vector2(cam_z, cam_z)
	queue_redraw()

func act() -> bool:
	return Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("jump")

func ax() -> float:
	return Input.get_axis("move_left", "move_right")

func ay() -> float:
	return Input.get_axis("move_up", "move_down")

## Free 360-degree steering: the analog thumb-stick on a phone, the arrow keys otherwise.
func stick() -> Vector2:
	if m.touch and m.hud.joy_id >= 0:
		return m.hud.stick
	return Vector2(ax(), ay()).limit_length(1.0)

## Canvas x just left of the on-screen buttons (the whole width on a keyboard), so the hero is never under a thumb.
func safe_x() -> float:
	if not m.touch or m.hud.size.x < 200.0:
		return W
	return m.hud.ctrl_left() - (m.hud.size.x - W) / 2.0

## Slide the camera only as far as needed to keep world x `hx` between the left thumb and the buttons.
func cam_keep(hx: float) -> void:
	var off: float = (m.hud.size.x - W) / 2.0
	var right := safe_x() - 70.0
	var left := (330.0 - off) if m.touch else 200.0
	cam_p.x = clampf(cam_p.x, hx - (right - 640.0) / cam_z, hx - (left - 640.0) / cam_z)

func hurt() -> bool:
	if inv > 0.0 or safe > 0.0 or hp <= 0:
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

func scr(p: Vector2) -> Vector2:
	return (p - cam_p) * cam_z + Vector2(640, 360)

func world_xf() -> void:
	_xf = Transform2D(0.0, Vector2(cam_z, cam_z), 0.0, Vector2(640, 360) - cam_p * cam_z)
	draw_set_transform_matrix(_xf)

func screen_xf() -> void:
	_xf = Transform2D.IDENTITY
	draw_set_transform_matrix(_xf)

func phi(pos: Vector2, s: float, col := GOLD, rot := 0.35) -> void:
	draw_set_transform_matrix(_xf * Transform2D(rot, pos))
	draw_arc(Vector2.ZERO, s * 0.4, 0, TAU, 24, col, s * 0.17, true)
	draw_line(Vector2(0, -s * 0.85), Vector2(0, s * 0.85), col, s * 0.09, true)
	draw_set_transform_matrix(_xf)

func dot(pos: Vector2, r := 5.0) -> void:
	draw_circle(pos, r, Color.BLACK)
	draw_arc(pos, r, 0, TAU, 16, Color.WHITE, 1.5, true)

func foe(kind: String, pos: Vector2, r: float, col := Color.WHITE) -> void:
	var d := r * 3.3
	var row: int = {"tri": 0, "sq": 1, "dia": 2, "hex": 3, "dart": 4}[kind]
	draw_texture_rect_region(foe_tex, Rect2(pos.x - d / 2.0, pos.y - d / 2.0, d, d), Rect2((int(t * 9.0) % 8) * 160, row * 160, 160, 160), col)

func hero_at(pos: Vector2, pose: String, rot := 0.0, face := 1) -> void:
	skin.visible = not (inv > 0.0 and int(inv * 14.0) % 2 == 1)
	skin.position = scr(pos)
	skin.pose = pose
	skin.rotation = rot
	skin.spin = 0.0
	skin.scale = Vector2(face * cam_z, cam_z)
	skin.ph = t * 13.0
	skin.combo = combo_n
	skin.swing = (1.0 - atk_t / atk_dur) if atk_t > 0.0 else 0.0

func hap(ms := 30) -> void:
	if m.has_method("haptic"):
		m.haptic(ms)

# ---- sword for chapters that run their own movement ----
var atk_t := 0.0
var atk_dur := 0.27
var combo_n := 1
var combo_t := 0.0
var atk_id := 0

func atk_tick(d: float) -> void:
	atk_t -= d; combo_t -= d; boom -= d; plunge_cd -= d
	var rolling := roll and dash_t > 0.0
	atk_buf = 0.18 if Input.is_action_just_pressed("attack") else (atk_buf if rolling else atk_buf - d / maxf(Engine.time_scale, 0.05))   # a tap slightly early still comes out
	if atk_buf > 0.0 and atk_t <= 0.05 and not plunging and not rolling:
		atk_buf = 0.0
		var a := ax()
		var up := plat and Input.get_action_strength("move_up") > 0.7 and absf(a) < 0.35
		var down := plat and acro and Input.get_action_strength("move_down") > 0.7 and absf(a) < 0.35
		if plat and aloft and down and air_h > 70.0 and plunge_cd <= 0.0:   # plunge: straight down from the air
			plunging = true; atk_id += 1; atk_t = 0.0; combo_t = 0.0; bflip_t = 0.0; m.snd("dash"); return
		if up: combo_n = 2
		elif down or slide_t > 0.0: combo_n = 3
		elif plat and aloft: combo_n = 4       # air spin, hitting on both sides
		else: combo_n = combo_n % 3 + 1 if (combo_t > 0.0 and combo_n < 4) else 1
		slide_t = 0.0
		atk_dur = 0.42 if combo_n == 3 else (0.34 if combo_n == 4 else 0.27)
		atk_t = atk_dur; combo_t = 0.75; atk_id += 1; m.snd("slash")
		if combo_n == 4:
			turn(TAU, atk_dur)
			stall_req = stall; stall = false

## Start a whole-body turn of `total` radians lasting `dur`; a turn already under way is folded into it.
func turn(total: float, dur: float) -> void:
	tumble_left += total
	tumble_rate = absf(tumble_left) / maxf(dur, 0.05)

## Contact is harmless while dashing, rolling, sliding or plunging.
func evading() -> bool:
	return dash_t > 0.0 or slide_t > 0.0 or plunging or boom > 0.0

## How hard the strike that atk_hits() just reported lands.
func atk_power() -> int:
	return 2 if (combo_n == 3 or plunging or boom > 0.0 or dash_t > 0.0) else 1

func acro_reset() -> void:
	roll = false; plunging = false; pogo = false; stall_req = false
	dash_t = 0.0; slide_t = 0.0; bflip_t = 0.0; lroll_t = 0.0; boom = 0.0
	tumble = 0.0; tumble_left = 0.0

func atk_hits(origin: Vector2, face: int, pos: Vector2, r: float) -> bool:
	var dx := (pos.x - origin.x) * face
	if dash_t > 0.0 and pos.distance_to(origin + Vector2(0, -26.0 if roll else -48.0)) < r + 44.0: return true   # a dash or roll through a target strikes it
	if slide_t > 0.0 and dx > -16.0 and dx < 50.0 + r and pos.y > origin.y - 64.0 - r and pos.y < origin.y + 20.0 + r: return true   # so does a slide
	if plunging:
		if absf(pos.x - origin.x) < 40.0 + r and pos.y > origin.y - 80.0 - r and pos.y < origin.y + 44.0 + r:
			pogo = true; return true
		return false
	if boom > 0.0: return absf(pos.x - origin.x) < 170.0 + r and absf(pos.y - (origin.y - 30.0)) < 84.0 + r
	if atk_t <= 0.0 or atk_t > atk_dur * 0.82: return false
	if combo_n == 4: return pos.distance_to(origin + Vector2(0, -48)) < 98.0 + r
	var dy := pos.y - (origin.y - 52.0)
	return dx > -28.0 and dx < 108.0 + r and absf(dy) < 90.0 + r

func hero_pose(base: String) -> String:
	return "slash" if atk_t > 0.0 else base

func kill_fx(pos: Vector2) -> void:
	score(pos); m.snd("hit"); m.shake = maxf(m.shake, 7.0); hap(25); m.hitstop(0.04)
	m.fx.burst(pos, 22, GOLD, 420.0, 300.0)

# ---- red rival swordsmen, drawn with a small pool of skins ----
var _rivs: Array = []
var _riv_n := 0

func rivals_begin() -> void:
	_riv_n = 0
	for r in _rivs: r.visible = false

func rival_at(pos: Vector2, face: int, pose: String, ph := 0.0, z := -1.0) -> void:
	if _riv_n >= _rivs.size():
		var s = preload("res://skin.gd").new()
		s.tex = skin.tex; s.tint = Color("ff4a6a"); s.band = Color("f4f8ff"); s.z_index = 4
		add_child(s); _rivs.append(s)
	var s = _rivs[_riv_n]; _riv_n += 1
	var zz := cam_z if z < 0.0 else z
	s.visible = true; s.position = scr(pos) if z < 0.0 else pos; s.scale = Vector2(face * zz, zz); s.pose = pose; s.ph = ph

# ---- shared mini-platformer on line segments ----
const RUN := 390.0
const JUMPV := 820.0
const GRAV := 2300.0

func seg_y(s: Dictionary, x: float) -> float:
	return s["y1"] + (s["y2"] - s["y1"]) * (x - s["x1"]) / (s["x2"] - s["x1"])

func new_plat(x: float, y: float) -> Dictionary:
	acro_reset()
	return {"x": x, "y": y, "vx": 0.0, "vy": 0.0, "g": null, "face": 1, "coy": 0.0, "buf": 0.0, "dj": false, "ph": 0.0, "stun": 0.0, "pose": "idle"}

func plat_step(p: Dictionary, segs: Array, d: float, no_dj := false) -> void:
	var a := ax(); p["stun"] -= d
	var dn := Input.get_action_strength("move_down") if acro else 0.0
	var on: bool = p["g"] != null
	var real := d / maxf(Engine.time_scale, 0.05)
	plat = true
	dash_cd -= d; slide_cd -= d; bflip_t -= d; lroll_t -= d; safe -= d; rush -= d
	var maxv := 140.0 if p["stun"] > 0.0 else RUN * (1.3 if rush > 0.0 else 1.0)
	if dn < 0.4: slide_ok = true
	p["buf"] = 0.12 if Input.is_action_just_pressed("jump") else p["buf"] - real
	if p["stun"] > 0.0 and (plunging or slide_t > 0.0 or tumble_left != 0.0): acro_reset()
	if pogo:                           # the plunge met something before the ground: spring off it
		pogo = false
		if plunging:
			plunging = false; plunge_cd = 0.4; p["dj"] = false; stall = true
			p["vy"] = -660.0; p["g"] = null; on = false; turn(TAU, 0.46); m.snd("djump")
	if stall_req:                      # the air spin hangs for a moment, once per jump
		stall_req = false
		if not on: p["vy"] = minf(p["vy"], -210.0)
	dash_buf = 0.15 if (can_dash and Input.is_action_just_pressed("dash")) else dash_buf - real
	if dash_buf > 0.0 and dash_cd <= 0.0 and p["stun"] <= 0.0 and not plunging:
		dash_buf = 0.0; roll = on      # on the ground the dash is a roll, in the air a straight burst
		dash_t = 0.3 if roll else 0.17; dash_cd = 0.62 if roll else 0.55
		safe = maxf(safe, dash_t + 0.07); slide_t = 0.0; bflip_t = 0.0; atk_id += 1
		if roll: turn(TAU, dash_t)
		m.snd("dash"); hap(18)
		if a != 0.0: p["face"] = 1 if a > 0.0 else -1
	if on and slide_ok and slide_t <= 0.0 and slide_cd <= 0.0 and dash_t <= 0.0 and p["stun"] <= 0.0 and atk_t <= 0.0 and dn > 0.75 and absf(p["vx"]) > 250.0:
		slide_ok = false; slide_t = 0.46; atk_id += 1   # slide: pull the stick down while running
		p["face"] = 1 if p["vx"] > 0.0 else -1; p["vx"] = p["face"] * maxf(absf(p["vx"]), 470.0); m.snd("dash", -6.0)
	var leapt := false
	if dash_t > 0.0:
		dash_t -= d
		if roll and not on: roll = false; dash_t = minf(dash_t, 0.14)   # rolled off an edge: carries on as an air dash
		if roll:
			p["vx"] = p["face"] * 680.0
			if p["buf"] > 0.0 and dash_t < 0.2:   # jump out of a roll: a long, low leap
				p["buf"] = 0.0; p["coy"] = 0.0; dash_t = 0.0; roll = false; leapt = true
				p["vx"] = p["face"] * 520.0; p["vy"] = -JUMPV * 0.92; p["g"] = null; rush = maxf(rush, 0.5); m.snd("jump")
		else: p["vx"] = p["face"] * 920.0; p["vy"] = 0.0
		if dash_t <= 0.0 and not leapt: p["vx"] = p["face"] * maxv; roll = false
	elif plunging:
		p["vx"] = move_toward(p["vx"], a * 140.0, 2400.0 * d); p["vy"] = minf(maxf(p["vy"], 200.0) + 9000.0 * d, 1400.0)
	elif slide_t > 0.0:
		slide_t -= d; p["vx"] = move_toward(p["vx"], p["face"] * 170.0, 640.0 * d)
		if not on or p["buf"] > 0.0: slide_t = 0.0
		if slide_t <= 0.0: slide_cd = 0.35
	elif a != 0.0:
		bflip_t = 0.0
		p["vx"] = move_toward(p["vx"], a * maxv, (3400.0 if on else 2400.0) * d)
		if atk_t <= 0.0: p["face"] = 1 if a > 0.0 else -1
	elif bflip_t <= 0.0: p["vx"] = move_toward(p["vx"], 0.0, (3000.0 if on else 1500.0) * d)
	p["coy"] = 0.1 if on else p["coy"] - d
	var free := dash_t <= 0.0 and not plunging and slide_t <= 0.0 and not leapt
	if free and p["buf"] > 0.0 and p["coy"] > 0.0:
		p["g"] = null; p["coy"] = 0.0; p["buf"] = 0.0
		if dn > 0.7 and absf(a) < 0.35 and absf(p["vx"]) < 150.0 and slide_cd <= 0.0:   # backflip: standing, straight down and jump
			p["vx"] = -p["face"] * 330.0; p["vy"] = -JUMPV * 0.86; bflip_t = 0.42; safe = maxf(safe, 0.3); turn(-TAU, 0.5); m.snd("djump")
		else: p["vy"] = -JUMPV; m.snd("jump")
	elif free and Input.is_action_just_pressed("jump") and not on and not p["dj"] and not no_dj:
		p["dj"] = true; p["vy"] = -JUMPV * 0.9; turn(TAU, 0.44); m.snd("djump")   # the second jump is a somersault
	var skid: bool = on and a != 0.0 and signf(a) != signf(p["vx"]) and absf(p["vx"]) > 150.0
	var px: float = p["x"]; var py: float = p["y"]
	p["x"] += p["vx"] * d
	if p["g"] != null:
		var s: Dictionary = p["g"]
		if p["x"] < s["x1"] - 2.0 or p["x"] > s["x2"] + 2.0:
			p["g"] = null
			for q in segs:
				if p["x"] >= q["x1"] and p["x"] <= q["x2"] and absf(seg_y(q, p["x"]) - p["y"]) < 14.0:
					p["g"] = q; break
		if p["g"] != null:
			p["y"] = seg_y(p["g"], clampf(p["x"], p["g"]["x1"], p["g"]["x2"])); p["vy"] = 0.0; p["dj"] = false; stall = true
	if p["g"] == null:
		if not Input.is_action_pressed("jump") and p["vy"] < -280.0 and bflip_t <= 0.0: p["vy"] += 3200.0 * d
		if dash_t <= 0.0 and not plunging: p["vy"] = minf(p["vy"] + GRAV * d, 1500.0)
		var ny: float = p["y"] + p["vy"] * d
		var land = null; var ly := 1e9
		if p["vy"] >= 0.0:
			for s in segs:
				if p["x"] < s["x1"] or p["x"] > s["x2"]: continue
				var ys := seg_y(s, p["x"])
				var yp := seg_y(s, px) if (px >= s["x1"] and px <= s["x2"]) else ys
				if py <= yp + 6.0 + s.get("rise", 0.0) and ny >= ys and ys < ly:
					land = s; ly = ys
		if land != null:
			var vl: float = p["vy"]
			if vl > 420.0: m.fx.burst(Vector2(p["x"], ly), 8, Color.WHITE, 170.0)
			p["y"] = ly; p["vy"] = 0.0; p["g"] = land; p["dj"] = false; stall = true
			if plunging:               # the plunge lands: a shockwave along the ground
				plunging = false; atk_id += 1; boom = 0.12; p["vx"] = 0.0
				m.snd("boom", -3.0); m.shake = maxf(m.shake, 22.0); m.hitstop(0.07); hap(45)
				m.fx.ring(Vector2(p["x"], ly - 6.0), Color(1, 0.84, 0.25, 0.8), 20.0, 190.0, 0.28, 6.0)
				m.fx.burst(Vector2(p["x"], ly), 26, GOLD, 520.0, 700.0)
			else:
				if vl > 1000.0 and absf(a) > 0.4 and dash_t <= 0.0 and atk_t <= 0.0 and absf(tumble_left) < 2.0: tumble_left += TAU   # a long fall taken at a run is rolled out
				if absf(tumble_left) > 0.6 and atk_t <= 0.0: lroll_t = 0.28; tumble_rate = absf(tumble_left) / lroll_t                 # so is a flip that meets the ground early
		else: p["y"] = ny
	aloft = p["g"] == null
	air_h = 0.0
	if aloft:
		air_h = 1e9
		for s in segs:
			if p["x"] >= s["x1"] and p["x"] <= s["x2"] and seg_y(s, p["x"]) >= p["y"]: air_h = minf(air_h, seg_y(s, p["x"]) - p["y"])
	if tumble_left != 0.0:
		var st := minf(absf(tumble_left), tumble_rate * (3.0 if (not aloft and dash_t <= 0.0 and lroll_t <= 0.0) else 1.0) * d)
		tumble += signf(tumble_left) * st; tumble_left -= signf(tumble_left) * st
		if absf(tumble_left) < 0.001: tumble_left = 0.0; tumble = 0.0
	p["ph"] += absf(p["vx"]) * d * 0.036
	var pose := "idle"
	if p["stun"] > 0.0: pose = "hurt"
	elif dash_t > 0.0: pose = "roll" if roll else "dash"
	elif plunging: pose = "plunge"
	elif slide_t > 0.0: pose = "slide"
	elif atk_t > 0.0: pose = "slash"
	elif lroll_t > 0.0: pose = "roll"
	elif aloft and absf(tumble_left) > 0.9: pose = "back" if tumble_left < 0.0 else "flip"
	elif aloft: pose = "jump" if p["vy"] < 0.0 else "fall"
	elif skid: pose = "skid"
	elif absf(p["vx"]) > 30.0: pose = "run"
	p["pose"] = pose

func plat_draw(p: Dictionary) -> void:
	hero_at(Vector2(p["x"], p["y"]), p["pose"], 0.0, p["face"]); skin.ph = p["ph"]; skin.spin = tumble; skin.shadow = p["g"] != null
