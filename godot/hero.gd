extends CharacterBody2D
## Player: run, jump, double jump, flight, dash-strike and a three-hit sword combo.

signal hurt_taken
signal throw_phi(target: Node2D)
signal sound(name: String)

const RUN := 390.0
const JUMP := 820.0
const GRAV := 2300.0

var skin: Node2D
var face := 1
var hp := 6
var max_hp := 6
var inv := 0.0
var stun := 0.0
var coy := 0.0
var buf := 0.0
var dj := false
var fuel := 1.0
var flying := false
var dash_t := 0.0
var dash_cd := 0.0
var dash_dir := 1
var dash_id := 0
var atk_t := 0.0
var atk_dur := 0.27
var combo := 0
var combo_t := 0.0
var atk_id := 0
var throw_cd := 0.0
var throw_t := 0.0
var ph := 0.0
var land_t := 0.0
var rush := 0.0
var can_throw := true
var foes: Array = []
var ghosts: Array = []

func _ready() -> void:
	var cs := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 11.0
	cap.height = 82.0
	cs.shape = cap
	cs.position = Vector2(0, -41)
	add_child(cs)
	skin = preload("res://skin.gd").new()
	skin.tex = load("res://art/hero_parts.png")
	add_child(skin)
	floor_snap_length = 8.0

func _nearest() -> Array:
	var best: Node2D = null
	var bd := 1e9
	for f in foes:
		if not is_instance_valid(f) or f.dead:
			continue
		var d: float = (f.global_position - (global_position + Vector2(0, -48))).length() - f.r
		if d < bd:
			bd = d
			best = f
	return [best, bd]

func _attack() -> void:
	var n := _nearest()
	var near: Node2D = n[0]
	var nd: float = n[1]
	if near and nd < 280.0:
		face = 1 if near.global_position.x >= global_position.x else -1
	if near and nd > 150.0 and can_throw and throw_cd <= 0.0:   # out of sword reach: the φ flies instead
		throw_cd = 0.4
		throw_t = 0.16
		throw_phi.emit(near)
		return
	if Input.is_action_pressed("move_up"):
		combo = 2
	elif Input.is_action_pressed("move_down"):
		combo = 3
	else:
		combo = combo % 3 + 1 if combo_t > 0.0 else 1
	atk_dur = 0.42 if combo == 3 else 0.27
	atk_t = atk_dur
	combo_t = 0.75
	atk_id += 1
	sound.emit("slash")
	if is_on_floor():
		velocity.x += face * (340.0 if combo == 3 else 180.0)

## Damage this swing deals to something at `pos` with radius `r` (0 if it misses or already hit it).
func sword_hits(pos: Vector2, r: float, obj: Object) -> int:
	if atk_t <= 0.0 or atk_t > atk_dur * 0.82 or obj.get_meta("hit_id", -1) == atk_id:
		return 0
	var dx := (pos.x - global_position.x) * face
	var dy := pos.y - (global_position.y - 52.0)
	if dx > -28.0 and dx < 108.0 + r and absf(dy) < 90.0 + r:
		obj.set_meta("hit_id", atk_id)
		return 2 if combo == 3 else 1
	return 0

## A dash that passes through a target strikes it and is refunded, so dashes can be chained.
func dash_hits(pos: Vector2, r: float, obj: Object) -> int:
	if dash_t <= 0.0 or obj.get_meta("dash_id", -1) == dash_id:
		return 0
	if pos.distance_to(global_position + Vector2(0, -48)) < r + 44.0:
		obj.set_meta("dash_id", dash_id)
		dash_cd = 0.0
		dj = false
		fuel = minf(1.0, fuel + 0.35)
		return 2
	return 0

func hurt(dir: float) -> void:
	if inv > 0.0 or dash_t > 0.0 or hp <= 0:
		return
	hp -= 1
	inv = 1.1
	stun = 0.25
	velocity = Vector2(dir * 360.0, -380.0)
	skin.flash = 0.2
	hurt_taken.emit()

func _physics_process(delta: float) -> void:
	inv -= delta; stun -= delta; dash_cd -= delta; atk_t -= delta; combo_t -= delta
	throw_cd -= delta; throw_t -= delta; land_t -= delta; rush -= delta
	flying = false
	var ax := Input.get_axis("move_left", "move_right")
	var on := is_on_floor()
	var maxv := 140.0 if stun > 0.0 else RUN * (1.3 if rush > 0.0 else 1.0)
	if Input.is_action_just_pressed("attack") and atk_t <= 0.05 and stun <= 0.0:
		_attack()
	if Input.is_action_just_pressed("dash") and dash_cd <= 0.0 and stun <= 0.0:
		dash_id += 1
		dash_t = 0.17
		dash_cd = 0.55
		dash_dir = int(signf(ax)) if ax != 0.0 else face
		face = dash_dir
		inv = maxf(inv, 0.24)
		sound.emit("dash")
	if dash_t > 0.0:
		dash_t -= delta
		velocity = Vector2(dash_dir * 920.0, 0.0)
		ghosts.append({"p": global_position, "a": 0.5, "f": face})
		if dash_t <= 0.0:
			velocity.x = dash_dir * maxv
	else:
		if ax != 0.0:
			velocity.x = move_toward(velocity.x, ax * maxv, (3400.0 if on else 2400.0) * delta)
			if atk_t <= 0.0:
				face = 1 if ax > 0.0 else -1
		else:
			velocity.x = move_toward(velocity.x, 0.0, (3000.0 if on else 500.0) * delta)
		buf = 0.12 if Input.is_action_just_pressed("jump") else buf - delta
		coy = 0.1 if on else coy - delta
		if buf > 0.0 and coy > 0.0:
			velocity.y = -JUMP
			coy = 0.0
			buf = 0.0
			sound.emit("jump")
		elif Input.is_action_just_pressed("jump") and not on and not dj:
			dj = true
			velocity.y = -JUMP * 0.9
			sound.emit("djump")
		if on:
			dj = false
			fuel = minf(1.0, fuel + delta * 1.2)
		elif Input.is_action_pressed("jump") and dj and fuel > 0.0 and velocity.y > -300.0:
			flying = true
			fuel -= delta / 1.6
			velocity.y = lerpf(velocity.y, -250.0, delta * 9.0)
		else:
			if not Input.is_action_pressed("jump") and velocity.y < -280.0:
				velocity.y += 3200.0 * delta
			velocity.y = minf(velocity.y + GRAV * delta, 1500.0)
	var vy := velocity.y
	move_and_slide()
	if not on and is_on_floor() and vy > 420.0:
		land_t = 0.15
	ph += absf(velocity.x) * delta * 0.036
	for g in ghosts:
		g["a"] -= delta * 2.2
	ghosts = ghosts.filter(func(g): return g["a"] > 0.0)
	# hand the animation state to the skeleton
	var p := "idle"
	if stun > 0.0: p = "hurt"
	elif dash_t > 0.0: p = "dash"
	elif atk_t > 0.0: p = "slash"
	elif throw_t > 0.0: p = "throw"
	elif flying: p = "dash" if absf(velocity.x) > 200.0 else "jump"
	elif not is_on_floor(): p = "jump" if velocity.y < 0.0 else "fall"
	elif land_t > 0.0 and absf(velocity.x) < 140.0: p = "land"
	elif absf(velocity.x) > 30.0: p = "run"
	skin.pose = p
	skin.ph = ph
	skin.combo = maxi(combo, 1)
	skin.swing = 1.0 - atk_t / atk_dur if atk_t > 0.0 else 0.0
	skin.flying = flying
	skin.scale.x = face
	skin.visible = not (inv > 0.0 and dash_t <= 0.0 and int(inv * 14.0) % 2 == 1)
