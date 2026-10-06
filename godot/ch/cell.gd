extends "res://chapter.gd"
## Immunity: you are a white blood cell. Engulf bacteria; tag viruses with antibodies first.
const TOP := 120.0
const BOT := 610.0
const GOAL := 30
var ents: Array = []
var shots: Array = []
var rbc: Array = []
var p := Vector2(260, 360)
var pulse := 0.0
var eaten := 0
var inf := 0
var spawn := 1.0
var cd := 0.0

func begin() -> void:
	title = "XVII · THE CELL"; max_hp = 4; hp = 4
	for i in 14: rbc.append([Vector2(randf() * W, TOP + 30.0 + randf() * (BOT - TOP - 60.0)), 0.6 + randf() * 0.6, randf() * TAU])

func tick(d: float) -> void:
	pulse = maxf(0.0, pulse - d * 3.0); cd -= d
	p.x = clampf(p.x + ax() * 320.0 * d, 60.0, W - 200.0); p.y = clampf(p.y + ay() * 320.0 * d, TOP + 44.0, BOT - 44.0)
	if (Input.is_action_pressed("attack") or Input.is_action_pressed("jump")) and cd <= 0.0:
		cd = 0.28; shots.append(p + Vector2(40, 0)); m.snd("throw", -8.0)
	var k := clampf(float(eaten) / GOAL, 0.0, 1.0)
	spawn -= d
	if spawn <= 0.0:
		spawn = lerpf(1.05, 0.55, k) * (0.7 + randf() * 0.6); var v := randf() < 0.38
		ents.append({"v": v, "p": Vector2(W + 50.0, TOP + 50.0 + randf() * (BOT - TOP - 100.0)), "vx": -(120.0 + randf() * 70.0 + k * 50.0), "ph": randf() * TAU, "tag": false, "r": 22.0 if v else 20.0})
	for i in range(shots.size() - 1, -1, -1):
		shots[i] += Vector2(760.0 * d, 0)
		if shots[i].x > W + 20.0: shots.remove_at(i); continue
		for e in ents:
			if e["v"] and not e["tag"] and (e["p"] as Vector2).distance_to(shots[i]) < e["r"] + 12.0:
				e["tag"] = true; e["vx"] *= 0.6; shots.remove_at(i); m.snd("hit", -4.0); m.fx.burst(e["p"], 8, GOLD, 300.0, 0.0); break
	for i in range(ents.size() - 1, -1, -1):
		var e: Dictionary = ents[i]; e["ph"] += d * 2.0
		var q: Vector2 = e["p"]; q.x += e["vx"] * d; q.y = clampf(q.y + sin(e["ph"]) * 40.0 * d, TOP + 26.0, BOT - 26.0); e["p"] = q
		if q.distance_to(p) < e["r"] + 38.0:
			if not e["v"] or e["tag"]:
				eaten += 1; pulse = 1.0; score(q); m.snd("phi"); m.fx.burst(q, 10, Color("b58cff") if e["v"] else Color("6fe08a"), 320.0, 0.0); ents.remove_at(i); continue
			elif inv <= 0.0:
				m.fx.burst(q, 14, RED); ents.remove_at(i); hurt(); continue
		if q.x < -40.0: ents.remove_at(i); inf += 2 if e["v"] else 1; m.shake = 5.0; m.snd("hurt", -8.0)
	for r in rbc:
		r[0].x -= 90.0 * r[1] * d; r[2] += d * 0.6
		if r[0].x < -60.0: r[0] = Vector2(W + 60.0, TOP + 30.0 + randf() * (BOT - TOP - 60.0))
	info = "white blood cell (phagocyte)     engulfed %d / %d     infection %d / 10" % [eaten, GOAL, inf]
	if inf >= 10: hp = 0; m._finish(false); return
	if eaten >= GOAL: m._finish(true)

func _draw() -> void:
	draw_rect(Rect2(0, TOP - 20, W, BOT - TOP + 40), Color(0.1, 0.03, 0.04, 0.8))
	for yy in [TOP, BOT]:
		var pts := PackedVector2Array()
		for x in range(0, 1300, 20): pts.append(Vector2(x, yy + sin(x * 0.02 + t * 1.5) * 8.0 * (1.0 if yy == TOP else -1.0)))
		draw_polyline(pts, Color(1, 0.54, 0.44), 3.0, true)
	for r in rbc:
		draw_set_transform(r[0], r[2], Vector2(r[1], r[1] * 0.47))
		draw_arc(Vector2.ZERO, 30.0, 0, TAU, 24, Color(1, 0.35, 0.29, 0.3), 3.0, true); draw_arc(Vector2.ZERO, 12.0, 0, TAU, 16, Color(1, 0.35, 0.29, 0.3), 3.0, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	for e in ents:
		var q: Vector2 = e["p"]
		if e["v"]:
			var col := GOLD if e["tag"] else Color("b58cff")
			for k in 10:
				var a: float = k * TAU / 10.0 + e["ph"] * 0.5
				draw_line(q + Vector2.from_angle(a) * 14.0, q + Vector2.from_angle(a) * 24.0, col, 2.0)
			draw_circle(q, 14.0, Color(0.04, 0.04, 0.05)); draw_arc(q, 14.0, 0, TAU, 20, col, 2.0, true)
			if e["tag"]: txt("Y", q + Vector2(-6, 6), 16, GOLD)
		else:
			draw_set_transform(q, sin(e["ph"]) * 0.5, Vector2.ONE)
			draw_rect(Rect2(-24, -10, 48, 20), Color(0.04, 0.04, 0.05)); draw_rect(Rect2(-24, -10, 48, 20), Color("6fe08a"), false, 2.5)
			draw_set_transform_matrix(Transform2D.IDENTITY)
	for s in shots:
		draw_line(s + Vector2(-12, 0), s, GOLD, 2.5); draw_line(s, s + Vector2(9, -8), GOLD, 2.5); draw_line(s, s + Vector2(9, 8), GOLD, 2.5)
	if not (inv > 0.0 and int(inv * 14.0) % 2 == 1):
		var pts := PackedVector2Array(); var r := 40.0 + pulse * 10.0
		for k in 24: pts.append(p + Vector2.from_angle(k * TAU / 24.0) * (r + sin(k * TAU / 24.0 * 3.0 + t * 3.0) * 4.0))
		draw_colored_polygon(pts, Color(0.75, 0.9, 1.0, 0.1)); draw_polyline(pts, Color(0.87, 0.95, 1.0), 2.5, true)
	hero_at(p + Vector2(0, 26), "surf"); skin.scale *= 0.62
	draw_rect(Rect2(750, 64, 160, 12), Color(1, 1, 1, 0.3), false, 1.0); draw_rect(Rect2(750, 64, 16.0 * inf, 12), RED)
	txt("infection", Vector2(680, 75), 13, Color(1, 0.54, 0.44))
