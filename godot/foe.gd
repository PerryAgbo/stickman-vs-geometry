extends Node2D
## Enemies: tri (ground lunger), dia (diving flyer), riv (rival swordsman), hex (heavy champion).

signal died(foe: Node2D)
signal bumped(foe: Node2D)

const ROW := {"tri": 0, "sq": 1, "dia": 2, "hex": 3, "dart": 4}

var kind := "tri"
var r := 26.0
var hp := 2
var st := "move"
var q := 0.0
var t := 0.0
var vel := Vector2.ZERO
var dead := false
var flash := 0.0
var face := -1
var patrol := false          # stands guard on its platform instead of hunting
var home := Vector2.ZERO
var ground_y := 560.0
var min_x := 40.0
var max_x := 1860.0
var hero: CharacterBody2D
var tex: Texture2D
var skin: Node2D

func setup(k: String, pos: Vector2, h: CharacterBody2D, atlas: Texture2D) -> void:
	kind = k
	hero = h
	tex = atlas
	r = {"tri": 26.0, "dia": 22.0, "riv": 46.0, "hex": 62.0}.get(k, 24.0)
	hp = {"tri": 2, "dia": 1, "riv": 3, "hex": 18}.get(k, 2)
	position = pos
	home = pos
	t = randf() * 6.0
	if k == "riv":
		skin = preload("res://skin.gd").new()
		skin.tex = load("res://art/hero_parts.png")
		skin.tint = Color("ff4a6a")
		skin.band = Color("f4f8ff")
		skin.position = Vector2(0, r)
		add_child(skin)

func take(n: int, dir: float) -> void:
	if dead:
		return
	hp -= n
	flash = 0.12
	vel.x += dir * (70.0 if kind == "hex" else 340.0)
	if skin:
		skin.flash = 0.2
	if hp <= 0:
		dead = true
		died.emit(self)
		queue_free()

func _physics_process(delta: float) -> void:
	if dead or hero == null:
		return
	t += delta
	q += delta
	flash -= delta
	var to := hero.global_position + Vector2(0, -48) - global_position
	var dir := 1.0 if to.x >= 0.0 else -1.0
	face = int(dir)
	if patrol:
		if kind == "dia":
			position.y = home.y + sin(t * 2.2) * 16.0
		else:
			position.x = home.x + sin(t * 1.4) * 50.0
		st = "wind" if to.length() < 180.0 else "move"
	elif kind == "tri":
		if st == "move":
			vel.x = lerpf(vel.x, dir * 150.0, delta * 4.0)
			if absf(to.x) < 160.0 and absf(to.y) < 110.0 and q > 0.7:
				st = "wind"; q = 0.0
		elif st == "wind":
			vel.x = lerpf(vel.x, 0.0, delta * 10.0)
			if q > 0.45:
				st = "lunge"; q = 0.0; vel.x = dir * 580.0
		elif q > 0.34:
			st = "move"; q = 0.0
		position.x += vel.x * delta
		position.y = ground_y - r
	elif kind == "riv":
		if st == "move":
			vel.x = lerpf(vel.x, dir * 185.0 if absf(to.x) > 80.0 else 0.0, delta * 5.0)
			if absf(to.x) < 100.0 and absf(to.y) < 95.0 and q > 0.55:
				st = "wind"; q = 0.0
		elif st == "wind":
			vel.x = lerpf(vel.x, 0.0, delta * 12.0)
			if q > 0.36:
				st = "lunge"; q = 0.0; vel.x = dir * 240.0
				if absf(to.x) < 125.0 and absf(to.y) < 95.0 and not hero.evading():
					if hero.atk_t > 0.0:    # blades clash: both are thrown back
						hero.velocity.x = -dir * 260.0
						vel.x = -dir * 420.0
						st = "move"
						bumped.emit(self)
					else:
						hero.hurt(dir)
		elif q > 0.32:
			st = "move"; q = 0.0
		position.x += vel.x * delta
		position.y = ground_y - r
	elif kind == "dia":
		if st == "move":
			vel = vel.lerp(Vector2((hero.global_position.x + cos(t * 1.3) * 320.0 - position.x) * 2.0, (190.0 + sin(t * 2.0) * 60.0 - position.y) * 2.0), delta * 3.0)
			if q > 2.6:
				st = "wind"; q = 0.0
		elif st == "wind":
			vel *= 0.9
			if q > 0.4:
				st = "lunge"; q = 0.0; vel = to.normalized() * 640.0
		elif q > 0.6:
			st = "move"; q = 0.0
		position += vel * delta
		position.y = minf(position.y, ground_y - r)
	else:    # hex: leaps and slams
		if st == "move":
			vel.x = lerpf(vel.x, dir * 95.0, delta * 3.0)
			if q > 2.1:
				st = "lunge"; q = 0.0; vel = Vector2(dir * clampf(absf(to.x) * 0.9, 120.0, 520.0), -980.0)
		else:
			vel.y += 2400.0 * delta
			if position.y + vel.y * delta >= ground_y - r and vel.y > 0.0:
				position.y = ground_y - r
				vel.y = 0.0
				st = "move"; q = 0.0
				bumped.emit(self)
				if absf(to.x) < 190.0 and hero.is_on_floor():
					hero.hurt(dir)
		position.x += vel.x * delta
		position.y = minf(position.y + vel.y * delta, ground_y - r)
	if not patrol:
		position.x = clampf(position.x, min_x, max_x)
	if skin:
		skin.scale.x = face
		skin.pose = "slash" if st == "lunge" else ("throw" if st == "wind" else ("run" if absf(vel.x) > 60.0 else "idle"))
		skin.swing = clampf(q / 0.25, 0.0, 1.0) if st == "lunge" else 0.0
		skin.ph = t * 9.0
	# the hero's blade, dash, roll or slide
	var d: int = hero.sword_hits(global_position, r, self)
	if d == 0:
		d = hero.dash_hits(global_position, r, self)
	if d == 0:
		d = hero.slide_hits(global_position, r, self)
	if d > 0:
		take(d, hero.knock(global_position))
	elif not hero.evading() and hero.stun <= 0.0 and global_position.distance_to(hero.global_position + Vector2(0, -44)) < r + 16.0:
		if patrol:
			hero.stun = 0.26
			hero.velocity.x *= 0.5
			dead = true
			bumped.emit(self)
			queue_free()
		else:
			hero.hurt(-dir)
	queue_redraw()

func _draw() -> void:
	if kind == "riv" or tex == null:
		return
	var hot := st == "wind"
	var fr := int(t * 9.0) % 8
	var d: float = r * 3.3 * (1.15 if kind == "tri" else 1.0) * (1.0 + sin(t * 40.0) * 0.06 if hot else 1.0)
	var col: Color = Color(1, 0.85, 0.5) if flash > 0.0 else (Color(1, 0.3, 0.22) if hot else (Color("ffd23a") if kind == "hex" else Color.WHITE))
	draw_texture_rect_region(tex, Rect2(-d / 2.0, -d / 2.0, d, d), Rect2(fr * 160, ROW.get(kind, 0) * 160, 160, 160), col)
