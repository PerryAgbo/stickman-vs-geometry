extends Node2D
## Particles and the thrown φ: sparks, geometry shards, landing dust, shock rings, floating text and dash ghosts.
## burst() keeps its original signature because the chapter scripts call it.

const GOLD := Color("ffd23a")

var parts: Array = []
var bolts: Array = []
var hero: Node2D          # for dash afterimages; set by juice.gd
var font: Font

func _ready() -> void:
	font = ThemeDB.fallback_font

## Line sparks flying out from `pos`.
func burst(pos: Vector2, n: int, col: Color, speed := 320.0, grav := 500.0) -> void:
	for i in n:
		parts.append({"k": "spark", "p": pos, "v": Vector2.from_angle(randf() * TAU) * speed * (0.3 + randf()), "l": 0.0, "m": 0.35 + randf() * 0.5,
			"len": 4.0 + randf() * 12.0, "r": randf() * TAU, "c": col, "g": grav})

## Sparks biased in one direction, for a blade landing: `dir` is +1 / -1 along x.
func slash_sparks(pos: Vector2, dir: float, n := 10, col := Color.WHITE) -> void:
	for i in n:
		var a := randf_range(-0.9, 0.9) + (0.0 if dir > 0.0 else PI)
		parts.append({"k": "spark", "p": pos, "v": Vector2.from_angle(a) * randf_range(260.0, 620.0), "l": 0.0, "m": 0.18 + randf() * 0.25,
			"len": 8.0 + randf() * 16.0, "r": a, "c": col, "g": 300.0, "fixed": true})

## Spinning polygon fragments, as if the shape shattered.
func shards(pos: Vector2, n: int, col: Color, size := 14.0, speed := 420.0) -> void:
	for i in n:
		var sides := 3 + randi() % 2
		var pts := PackedVector2Array()
		var s := size * randf_range(0.5, 1.3)
		for k in sides:
			pts.append(Vector2.from_angle(k * TAU / sides + randf() * 0.4) * s * randf_range(0.6, 1.0))
		parts.append({"k": "shard", "p": pos, "v": Vector2.from_angle(randf() * TAU) * speed * randf_range(0.25, 1.0) + Vector2(0, -120), "l": 0.0,
			"m": 0.55 + randf() * 0.55, "pts": pts, "r": randf() * TAU, "w": randf_range(-14.0, 14.0), "c": col, "g": 900.0})

## Soft puffs at the feet.
func dust(pos: Vector2, dir := 0.0, n := 7, col := Color(1, 1, 1, 0.55)) -> void:
	for i in n:
		var side := (randf() - 0.5) * 2.0 if dir == 0.0 else -dir * randf()
		parts.append({"k": "dust", "p": pos + Vector2(side * 10.0, -2.0), "v": Vector2(side * randf_range(60.0, 200.0), randf_range(-90.0, -20.0)), "l": 0.0,
			"m": 0.3 + randf() * 0.3, "r0": 3.0 + randf() * 4.0, "r1": 12.0 + randf() * 10.0, "c": col, "g": -40.0})

## Expanding ring.
func ring(pos: Vector2, col: Color, r0 := 10.0, r1 := 90.0, dur := 0.3, width := 4.0) -> void:
	parts.append({"k": "ring", "p": pos, "v": Vector2.ZERO, "l": 0.0, "m": dur, "r0": r0, "r1": r1, "c": col, "w": width, "g": 0.0})

## Text that pops up and drifts.
func pop(pos: Vector2, text: String, col := GOLD, size := 22, rise := 70.0) -> void:
	parts.append({"k": "pop", "p": pos + Vector2(randf_range(-6, 6), 0), "v": Vector2(randf_range(-20, 20), -rise), "l": 0.0, "m": 0.9, "s": text, "sz": size, "c": col, "g": 60.0})

func _process(delta: float) -> void:
	for p in parts:
		p["l"] += delta
		p["v"].y += p["g"] * delta
		p["p"] += p["v"] * delta
		if p["k"] == "spark" and not p.has("fixed"):
			p["r"] += delta * 6.0
		elif p["k"] == "shard":
			p["r"] += p["w"] * delta
			p["v"].x = move_toward(p["v"].x, 0.0, 180.0 * delta)
	parts = parts.filter(func(p): return p["l"] < p["m"])
	queue_redraw()

func _draw() -> void:
	if hero and is_instance_valid(hero) and hero.ghosts.size() > 0:
		var tint: Color = hero.skin.tint
		for g in hero.ghosts:
			var a: float = clampf(g["a"], 0.0, 0.5)
			var c := Color(tint.r, tint.g, tint.b, a * 0.6)
			var o: Vector2 = g["p"] - global_position
			draw_circle(o + Vector2(0, -70), 11.0, c)
			draw_rect(Rect2(o + Vector2(-11, -70), Vector2(22, 48)), c)
			draw_circle(o + Vector2(0, -22), 11.0, c)
			for k in 3:
				var y := -78.0 + k * 22.0
				draw_line(o + Vector2(-g["f"] * 18.0, y), o + Vector2(-g["f"] * (46.0 + k * 10.0), y), Color(1, 1, 1, a * 0.5), 2.0, true)
	for p in parts:
		var u: float = p["l"] / p["m"]
		var c: Color = p["c"]
		match p["k"]:
			"spark":
				var d: Vector2 = Vector2.from_angle(p["r"]) * p["len"] * 0.5
				c.a = c.a * (1.0 - u)
				draw_line(p["p"] - d, p["p"] + d, c, 1.8 if not p.has("fixed") else 2.4, true)
			"shard":
				c.a = 1.0 - u * u
				draw_set_transform(p["p"], p["r"], Vector2.ONE)
				draw_colored_polygon(p["pts"], c)
				draw_polyline(p["pts"] + PackedVector2Array([p["pts"][0]]), Color(1, 1, 1, (1.0 - u) * 0.7), 1.5, true)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"dust":
				c.a = c.a * (1.0 - u) * 0.8
				draw_circle(p["p"], lerpf(p["r0"], p["r1"], u), c)
			"ring":
				c.a = c.a * (1.0 - u)
				var e := 1.0 - (1.0 - u) * (1.0 - u)
				draw_arc(p["p"], lerpf(p["r0"], p["r1"], e), 0.0, TAU, 40, c, p["w"] * (1.0 - u * 0.6), true)
			"pop":
				c.a = 1.0 if u < 0.6 else 1.0 - (u - 0.6) / 0.4
				var k := 1.0 + 0.6 * maxf(0.0, 1.0 - u * 6.0)   # punch in
				draw_set_transform(p["p"], 0.0, Vector2(k, k))
				draw_string(font, Vector2(-200, 0), p["s"], HORIZONTAL_ALIGNMENT_CENTER, 400, p["sz"], Color(0, 0, 0, c.a * 0.6))
				draw_string(font, Vector2(-200, -2), p["s"], HORIZONTAL_ALIGNMENT_CENTER, 400, p["sz"], c)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for b in bolts:
		var o: Vector2 = b["p"]
		var a: float = b["l"] * 30.0
		draw_circle(o, 14.0, Color(1, 0.82, 0.23, 0.18))
		draw_arc(o, 9.0, 0.0, TAU, 20, GOLD, 4.0, true)
		draw_line(o - Vector2.from_angle(a) * 18.0, o + Vector2.from_angle(a) * 18.0, GOLD, 2.5, true)
