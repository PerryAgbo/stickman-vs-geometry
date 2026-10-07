extends CharacterBody2D
## Player: run, jump, somersault, flight, roll, slide, backflip, and a sword with ground combos, an air spin and a plunging strike.

signal hurt_taken
signal throw_phi(target: Node2D)
signal sound(name: String)
signal slammed            # a plunge has just hit the ground

const RUN := 390.0
const JUMP := 820.0
const GRAV := 2300.0

var skin: Node2D
var face := 1
var hp := 6
var max_hp := 6
var inv := 0.0
var safe := 0.0          # untouchable without the hurt blink (rolls, flips)
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
var roll := false        # the dash under way is a roll along the ground
var atk_t := 0.0
var atk_dur := 0.27
var combo := 0           # 1-3 ground chain, 4 air spin
var combo_t := 0.0
var atk_id := 0
var throw_cd := 0.0
var throw_t := 0.0
var ph := 0.0
var land_t := 0.0
var lroll_t := 0.0       # rolling out of a long fall
var rush := 0.0
var can_throw := true
var atk_buf := 0.0      # a tap slightly too early still comes out
var dash_buf := 0.0
var jump_hold := 0.0    # how long jump has been held since the last press
var slide_t := 0.0
var slide_cd := 0.0
var slide_id := 0
var slide_ok := true     # the stick has come back up since the last slide
var bflip_t := 0.0       # a backflip keeps its backward speed for this long
var plunging := false
var pogo := false        # the plunge struck something in the air: bounce off it
var boom := 0.0          # the plunge's shockwave is live
var stall := true        # one small hang per jump for the air spin
var spin := 0.0          # whole-body turn shown by the skeleton
var spin_left := 0.0
var spin_rate := 0.0
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

## Start a whole-body turn of `total` radians lasting `dur`; a turn already under way is folded into it.
func turn(total: float, dur: float) -> void:
	spin_left += total
	spin_rate = absf(spin_left) / maxf(dur, 0.05)

## Contact with enemies is harmless while dashing, rolling or sliding.
func evading() -> bool:
	return dash_t > 0.0 or slide_t > 0.0 or plunging or boom > 0.0

## Which way a hit from the hero throws something at `pos`.
func knock(pos: Vector2) -> float:
	if boom > 0.0 or plunging or (atk_t > 0.0 and combo == 4):
		return 1.0 if pos.x >= global_position.x else -1.0
	return float(face)

## Put every move back to rest (respawn after a fall).
func reset_moves() -> void:
	plunging = false; roll = false; pogo = false
	dash_t = 0.0; slide_t = 0.0; bflip_t = 0.0; lroll_t = 0.0; boom = 0.0
	spin = 0.0; spin_left = 0.0

func _attack(ax: float) -> void:
	var up := Input.get_action_strength("move_up") > 0.7 and absf(ax) < 0.35
	var down := Input.get_action_strength("move_down") > 0.7 and absf(ax) < 0.35
	var air := not is_on_floor()
	# Plunge: straight down in the air, with room to fall. Close to the ground it is the heavy slam instead.
	if air and down and not test_move(global_transform, Vector2(0, 70)):
		plunging = true
		atk_id += 1
		atk_t = 0.0
		combo_t = 0.0
		bflip_t = 0.0
		velocity = Vector2(0.0, maxf(velocity.y, 200.0))
		sound.emit("dash")
		return
	var n := _nearest()
	var near: Node2D = n[0]
	var nd: float = n[1]
	# Turn to the nearest enemy, but never against the way the player is steering.
	if near and nd < 280.0:
		var want := 1 if near.global_position.x >= global_position.x else -1
		if ax == 0.0 or signf(ax) == want:
			face = want
	elif ax != 0.0:
		face = 1 if ax > 0.0 else -1
	# The blade always swings, so the button always answers. If the enemy ahead is beyond its reach, the φ flies as well.
	if near and nd > 150.0 and nd < 700.0 and can_throw and throw_cd <= 0.0 and (near.global_position.x - global_position.x) * face > 0.0:
		throw_cd = 0.6
		throw_phi.emit(near)
	# Rising slash and heavy slam need a deliberate straight up or down, not a thumb resting on a diagonal.
	if up:
		combo = 2
	elif down or slide_t > 0.0:   # out of a slide the blade comes round low and heavy
		combo = 3
	elif air:
		combo = 4                 # air spin: one full turn with the blade out, hitting on both sides
	else:
		combo = combo % 3 + 1 if (combo_t > 0.0 and combo < 4) else 1
	slide_t = 0.0
	atk_dur = 0.42 if combo == 3 else (0.34 if combo == 4 else 0.27)
	atk_t = atk_dur
	combo_t = 0.75
	atk_id += 1
	sound.emit("slash")
	if combo == 4:
		turn(TAU, atk_dur)
		if stall:                 # a single short hang, so an air strike has time to land
			stall = false
			velocity.y = minf(velocity.y, -210.0)
	elif is_on_floor() and (ax == 0.0 or signf(ax) == face):   # the lunge never fights the stick
		velocity.x += face * (340.0 if combo == 3 else 180.0)

## Damage this swing deals to something at `pos` with radius `r` (0 if it misses or already hit it).
func sword_hits(pos: Vector2, r: float, obj: Object) -> int:
	if obj.get_meta("hit_id", -1) == atk_id:
		return 0
	var hit := false
	var dmg := 1
	if plunging:              # the falling blade
		hit = absf(pos.x - global_position.x) < 40.0 + r and pos.y > global_position.y - 80.0 - r and pos.y < global_position.y + 44.0 + r
		dmg = 2
	elif boom > 0.0:          # the shockwave where it lands
		hit = absf(pos.x - global_position.x) < 170.0 + r and absf(pos.y - (global_position.y - 30.0)) < 84.0 + r
		dmg = 2
	elif atk_t <= 0.0 or atk_t > atk_dur * 0.82:
		return 0
	elif combo == 4:
		hit = pos.distance_to(global_position + Vector2(0, -48)) < 98.0 + r
	else:
		var dx := (pos.x - global_position.x) * face
		var dy := pos.y - (global_position.y - 52.0)
		hit = dx > -28.0 and dx < 108.0 + r and absf(dy) < 90.0 + r
		dmg = 2 if combo == 3 else 1
	if hit:
		obj.set_meta("hit_id", atk_id)
		pogo = plunging
		return dmg
	return 0

## A dash or roll that passes through a target strikes it and is refunded, so dashes can be chained.
func dash_hits(pos: Vector2, r: float, obj: Object) -> int:
	if dash_t <= 0.0 or obj.get_meta("dash_id", -1) == dash_id:
		return 0
	if pos.distance_to(global_position + Vector2(0, -26.0 if roll else -48.0)) < r + 44.0:
		obj.set_meta("dash_id", dash_id)
		dash_cd = 0.0
		dj = false
		fuel = minf(1.0, fuel + 0.35)
		return 2
	return 0

## A slide kicks whatever it passes on the ground, once each.
func slide_hits(pos: Vector2, r: float, obj: Object) -> int:
	if slide_t <= 0.0 or obj.get_meta("slide_id", -1) == slide_id:
		return 0
	var dx := (pos.x - global_position.x) * face
	if dx > -16.0 and dx < 50.0 + r and pos.y > global_position.y - 64.0 - r:
		obj.set_meta("slide_id", slide_id)
		return 1
	return 0

func hurt(dir: float) -> void:
	if inv > 0.0 or safe > 0.0 or dash_t > 0.0 or hp <= 0:
		return
	hp -= 1
	inv = 1.1
	stun = 0.25
	velocity = Vector2(dir * 360.0, -380.0)
	reset_moves()
	skin.flash = 0.2
	hurt_taken.emit()

func _physics_process(delta: float) -> void:
	inv -= delta; stun -= delta; dash_cd -= delta; atk_t -= delta; combo_t -= delta
	throw_cd -= delta; throw_t -= delta; land_t -= delta; rush -= delta
	slide_cd -= delta; bflip_t -= delta; lroll_t -= delta; boom -= delta; safe -= delta
	flying = false
	if pogo:                           # the plunge met an enemy before the ground: spring off it, ready to strike again
		pogo = false
		if plunging:
			plunging = false
			dj = false
			stall = true
			velocity.y = -660.0
			turn(TAU, 0.46)
			sound.emit("djump")
	var ax := Input.get_axis("move_left", "move_right")
	var dn := Input.get_action_strength("move_down")
	var on := is_on_floor()
	var maxv := 140.0 if stun > 0.0 else RUN * (1.3 if rush > 0.0 else 1.0)
	var real := delta / maxf(Engine.time_scale, 0.05)   # buffers run on real time, so hit-stop never eats a tap
	var rolling := roll and dash_t > 0.0
	atk_buf = 0.18 if Input.is_action_just_pressed("attack") else (atk_buf if rolling else atk_buf - real)   # a strike asked for mid-roll comes out as the roll ends
	dash_buf = 0.15 if Input.is_action_just_pressed("dash") else dash_buf - real
	buf = 0.12 if Input.is_action_just_pressed("jump") else buf - real
	jump_hold = jump_hold + real if (Input.is_action_pressed("jump") and not Input.is_action_just_pressed("jump")) else 0.0
	if dn < 0.4:
		slide_ok = true
	if atk_buf > 0.0 and atk_t <= 0.05 and stun <= 0.0 and not plunging and not rolling:
		atk_buf = 0.0
		_attack(ax)
	if dash_buf > 0.0 and dash_cd <= 0.0 and stun <= 0.0 and not plunging:
		dash_buf = 0.0
		dash_id += 1
		roll = on                      # on the ground the dash is a roll, in the air a straight burst
		dash_t = 0.3 if roll else 0.17
		dash_cd = 0.62 if roll else 0.55
		dash_dir = int(signf(ax)) if ax != 0.0 else face
		face = dash_dir
		safe = maxf(safe, dash_t + 0.07)
		slide_t = 0.0
		bflip_t = 0.0
		if roll:
			turn(TAU, dash_t)
		sound.emit("dash")
	# slide: pull the stick down while running
	if on and slide_ok and slide_t <= 0.0 and slide_cd <= 0.0 and dash_t <= 0.0 and stun <= 0.0 and atk_t <= 0.0 and dn > 0.75 and absf(velocity.x) > 250.0:
		slide_ok = false
		slide_id += 1
		slide_t = 0.46
		face = 1 if velocity.x > 0.0 else -1
		velocity.x = face * maxf(absf(velocity.x), 470.0)
		sound.emit("dash")
	if dash_t > 0.0:
		dash_t -= delta
		if roll and not on:            # rolled off an edge: it carries on as an air dash, so gaps are still crossed
			roll = false
			dash_t = minf(dash_t, 0.14)
		if roll:
			velocity = Vector2(dash_dir * 680.0, minf(velocity.y + GRAV * delta, 1500.0))
			if buf > 0.0 and dash_t < 0.2:   # jump out of a roll: a long, low leap
				buf = 0.0
				coy = 0.0
				dash_t = 0.0
				roll = false
				velocity = Vector2(dash_dir * 520.0, -JUMP * 0.92)
				rush = maxf(rush, 0.5)       # keeps the roll's speed through the leap
				sound.emit("jump")
		else:
			velocity = Vector2(dash_dir * 920.0, 0.0)
		ghosts.append({"p": global_position, "a": 0.5, "f": face})
		if dash_t <= 0.0 and roll:
			velocity.x = dash_dir * maxv
			roll = false
		elif dash_t <= 0.0 and velocity.y == 0.0:
			velocity.x = dash_dir * maxv
	elif plunging:
		velocity.x = move_toward(velocity.x, ax * 140.0, 2400.0 * delta)
		velocity.y = minf(velocity.y + 9000.0 * delta, 1400.0)
	elif slide_t > 0.0:
		slide_t -= delta
		velocity.x = move_toward(velocity.x, face * 170.0, 640.0 * delta)
		velocity.y = minf(velocity.y + GRAV * delta, 1500.0)
		if not on or buf > 0.0:        # off an edge, or jumping out of it
			slide_t = 0.0
		if slide_t <= 0.0:
			slide_cd = 0.35
	else:
		if ax != 0.0:
			bflip_t = 0.0
			velocity.x = move_toward(velocity.x, ax * maxv, (3400.0 if on else 2400.0) * delta)
			if atk_t <= 0.0:
				face = 1 if ax > 0.0 else -1
		elif bflip_t <= 0.0:
			velocity.x = move_toward(velocity.x, 0.0, (3000.0 if on else 1500.0) * delta)   # letting go in the air stops you
		coy = 0.1 if on else coy - delta
		if buf > 0.0 and coy > 0.0:
			coy = 0.0
			buf = 0.0
			if dn > 0.7 and absf(ax) < 0.35 and absf(velocity.x) < 150.0 and slide_cd <= 0.0:   # backflip: standing, straight down and jump. Away from danger without turning your back
				velocity = Vector2(-face * 330.0, -JUMP * 0.86)
				bflip_t = 0.42
				safe = maxf(safe, 0.3)
				turn(-TAU, 0.5)
				sound.emit("djump")
			else:
				velocity.y = -JUMP
				sound.emit("jump")
		elif Input.is_action_just_pressed("jump") and not on and not dj:
			dj = true
			velocity.y = -JUMP * 0.9
			turn(TAU, 0.44)                # the second jump is a somersault
			sound.emit("djump")
		if on:
			dj = false
			stall = true
			fuel = minf(1.0, fuel + delta * 1.2)
		elif Input.is_action_pressed("jump") and dj and fuel > 0.0 and jump_hold > 0.28 and velocity.y > -300.0:   # flight is a deliberate hold, not a side effect of a double jump
			flying = true
			fuel -= delta / 1.6
			velocity.y = lerpf(velocity.y, -250.0, delta * 9.0)
		else:
			if not Input.is_action_pressed("jump") and velocity.y < -280.0 and bflip_t <= 0.0:
				velocity.y += 3200.0 * delta
			velocity.y = minf(velocity.y + GRAV * delta, 1500.0)
	var vy := velocity.y
	var skid := on and ax != 0.0 and signf(ax) != signf(velocity.x) and absf(velocity.x) > 150.0
	move_and_slide()
	if not on and is_on_floor():
		if plunging:
			plunging = false
			atk_id += 1
			boom = 0.12
			land_t = 0.26
			velocity.x = 0.0
			slammed.emit()
		else:
			if vy > 1000.0 and absf(ax) > 0.4 and dash_t <= 0.0 and atk_t <= 0.0 and absf(spin_left) < 2.0:
				spin_left += TAU           # a long fall taken at a run is rolled out, keeping the speed
			if absf(spin_left) > 0.6 and atk_t <= 0.0:   # so is a flip that meets the ground early
				lroll_t = 0.28
				spin_rate = absf(spin_left) / lroll_t
			elif vy > 420.0:
				land_t = 0.15
	ph += absf(velocity.x) * delta * 0.036
	if spin_left != 0.0:
		# a turn cut short by the ground is finished quickly instead of snapping upright
		var hurry := 3.0 if (is_on_floor() and dash_t <= 0.0 and lroll_t <= 0.0) else 1.0
		var st := minf(absf(spin_left), spin_rate * hurry * delta)
		spin += signf(spin_left) * st
		spin_left -= signf(spin_left) * st
		if absf(spin_left) < 0.001:
			spin_left = 0.0
			spin = 0.0
	for g in ghosts:
		g["a"] -= delta * 2.2
	ghosts = ghosts.filter(func(g): return g["a"] > 0.0)
	# hand the animation state to the skeleton
	var p := "idle"
	if stun > 0.0: p = "hurt"
	elif dash_t > 0.0: p = "roll" if roll else "dash"
	elif plunging: p = "plunge"
	elif slide_t > 0.0: p = "slide"
	elif atk_t > 0.0: p = "slash"
	elif throw_t > 0.0: p = "throw"
	elif lroll_t > 0.0: p = "roll"
	elif absf(spin_left) > 0.9 and not is_on_floor(): p = "back" if spin_left < 0.0 else "flip"
	elif flying: p = "dash" if absf(velocity.x) > 200.0 else "jump"
	elif not is_on_floor(): p = "jump" if velocity.y < 0.0 else "fall"
	elif land_t > 0.0 and absf(velocity.x) < 140.0: p = "land"
	elif skid: p = "skid"
	elif absf(velocity.x) > 30.0: p = "run"
	skin.pose = p
	skin.ph = ph
	skin.combo = maxi(combo, 1)
	skin.swing = 1.0 - atk_t / atk_dur if atk_t > 0.0 else 0.0
	skin.flying = flying
	skin.spin = spin
	skin.shadow = is_on_floor()
	skin.scale.x = face
	skin.visible = not (inv > 0.0 and dash_t <= 0.0 and int(inv * 14.0) % 2 == 1)
