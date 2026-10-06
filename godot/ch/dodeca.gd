extends "res://chapter.gd"
## The ending: walk into the light.
const GY := 560.0
const DX := 1700.0
var p := {}
var inside := 0.0
var crowd: Array = []

func begin() -> void:
	title = "XXII · THE DODECAHEDRON"; max_hp = 1; hp = 1
	p = new_plat(120.0, GY); cam_p = Vector2(640, 360)
	var rng := RandomNumberGenerator.new(); rng.seed = 21
	for i in 18: crowd.append([Vector2(rng.randf() * W, 160.0 + rng.randf() * 500.0), 0.35 + rng.randf() * 0.6, rng.randf() * TAU, ["run", "jump", "idle", "fall"][i % 4]])

func tick(d: float) -> void:
	if inside <= 0.0:
		plat_step(p, [{"x1": -200.0, "y1": GY, "x2": 3000.0, "y2": GY}], d)
		cam_p.x = lerpf(cam_p.x, clampf(p["x"] + 150.0, 640.0, DX - 300.0), d * 4.0)
		if p["x"] > DX - 150.0: inside = 0.001; m.snd("clear"); m.music("calm")
	else:
		inside += d
		if inside > 2.5 and act(): m._finish(true)
	info = "the dodecahedron: 12 pentagons, 20 vertices, 30 edges"

func _draw() -> void:
	rivals_begin()
	if inside <= 0.0:
		var dd := clampf(1.0 - (DX - p["x"]) / 1500.0, 0.0, 1.0); var g := scr(Vector2(DX, 330))
		for k in range(8, 0, -1): draw_circle(g, k * 90.0, Color(1, 0.82, 0.23, (0.02 + 0.03 * dd)))
		world_xf()
		draw_line(Vector2(-200, GY), Vector2(3000, GY), Color.WHITE, 1.5)
		var pts := PackedVector2Array()
		for i in 6: pts.append(Vector2(DX, 330) + Vector2.from_angle(i * TAU / 5.0 + t * 0.3) * 250.0)
		draw_polyline(pts, Color.WHITE, 2.2, true)
		for i in 5: draw_line(pts[i], Vector2(DX, 330) + Vector2.from_angle(i * TAU / 5.0 + t * 0.3 + 0.63) * 120.0, Color(1, 1, 1, 0.6), 1.2)
		foe("hex", Vector2(DX, 330), 60.0, GOLD); draw_circle(Vector2(DX, 330), 10.0 + sin(t * 3.0) * 3.0, Color(1, 0.97, 0.76))
		screen_xf(); plat_draw(p)
	else:
		draw_rect(Rect2(0, 0, W, H), Color(0.2, 0.16, 0.04, 0.85))
		for k in range(1, 6):
			var r := k * 150.0; var pts := PackedVector2Array()
			for i in 6: pts.append(Vector2(640, 360) + Vector2.from_angle(i * TAU / 5.0 + t * 0.04 * (1 if k % 2 else -1) + k) * r)
			draw_polyline(pts, Color(1, 1, 1, 0.12 + 0.05 * k), 1.0)
		for q in crowd: rival_at(q[0], 1, q[3], q[2] + t * 6.0, q[1])
		foe("hex", Vector2(1090, 170), 40.0, GOLD)
		hero_at(Vector2(640, 610), "idle"); skin.scale *= 2.6
		var a := clampf((inside - 1.0) / 1.2, 0.0, 1.0)
		draw_rect(Rect2(0, 84, W, 150), Color(0, 0, 0, 0.55 * a))
		txt("YOU ARE GEOMETRY NOW", Vector2(640, 140), 44, Color(1, 1, 1, a), true)
		txt("time  %d:%02d        best combo  ×%d" % [int(m.time) / 60, int(m.time) % 60, m.best], Vector2(640, 190), 20, Color(GOLD, a), true)
		if inside > 2.5 and int(t * 2.0) % 2 == 0: txt("tap to finish" if m.touch else "ENTER  finish", Vector2(640, 222), 15, Color(1, 1, 1, 0.8), true)
