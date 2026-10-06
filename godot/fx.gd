extends Node2D
## Sparks and the thrown φ.

var parts: Array = []
var bolts: Array = []

func burst(pos: Vector2, n: int, col: Color, speed := 320.0, grav := 500.0) -> void:
	for i in n:
		parts.append({"p": pos, "v": Vector2.from_angle(randf() * TAU) * speed * (0.3 + randf()), "l": 0.0, "m": 0.35 + randf() * 0.5,
			"len": 4.0 + randf() * 12.0, "r": randf() * TAU, "c": col, "g": grav})

func _process(delta: float) -> void:
	for p in parts:
		p["l"] += delta
		p["v"].y += p["g"] * delta
		p["p"] += p["v"] * delta
		p["r"] += delta * 6.0
	parts = parts.filter(func(p): return p["l"] < p["m"])
	queue_redraw()

func _draw() -> void:
	for p in parts:
		var d: Vector2 = Vector2.from_angle(p["r"]) * p["len"] * 0.5
		var c: Color = p["c"]
		c.a = 1.0 - p["l"] / p["m"]
		draw_line(p["p"] - d, p["p"] + d, c, 1.8, true)
	for b in bolts:
		var o: Vector2 = b["p"]
		var a: float = b["l"] * 30.0
		draw_arc(o, 9.0, 0.0, TAU, 20, Color("ffd23a"), 4.0, true)
		draw_line(o - Vector2.from_angle(a) * 18.0, o + Vector2.from_angle(a) * 18.0, Color("ffd23a"), 2.5, true)
