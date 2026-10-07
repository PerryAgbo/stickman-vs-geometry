extends "res://chapter.gd"
## Free fall: steer past the triangles for 38 seconds, or cut them down, then land.
const T_END := 38.0
var tris: Array = []
var phis: Array = []
var lines: Array = []
var p := Vector2(640, 340)
var vel := Vector2.ZERO
var tilt := 0.0
var spawn := 1.2
var gy := 920.0
var landed := false

func begin() -> void:
	title = "IV · THE VOID"; btn = [["attack", "CUT"]]; max_hp = 3; hp = 3
	for i in 40: lines.append([randf() * W, randf() * H, 20.0 + randf() * 60.0])

func corners(o: Dictionary) -> Array:
	var c: Array = []
	for a in o["a"]: c.append(o["p"] + Vector2.from_angle(o["rot"] + a) * o["r"])
	return c

func dseg(q: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a; var k := clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0); return (q - a - ab * k).length()

func tick(d: float) -> void:
	var k := clampf(t / T_END, 0.0, 1.0); var vs := 430.0 + k * 260.0
	atk_tick(d)
	if atk_t > atk_dur * 0.9 and not landed:
		for i in range(tris.size() - 1, -1, -1):
			var o: Dictionary = tris[i]
			if (o["p"] as Vector2).distance_to(p + Vector2(0, -30)) < o["r"] + 125.0: kill_fx(o["p"]); tris.remove_at(i)
	if not landed:
		var sv := stick()
		vel = vel.lerp(Vector2(sv.x * 480.0, sv.y * 330.0), d * 9.0)
		p.x = clampf(p.x + vel.x * d, 40.0, minf(W - 40.0, safe_x() - 40.0)); p.y = clampf(p.y + vel.y * d, 90.0, H - 150.0); tilt = lerpf(tilt, vel.x / 480.0 * 0.5, d * 8.0)
	spawn -= d
	if spawn <= 0.0 and t < T_END:
		spawn = lerpf(0.8, 0.36, k) * (0.7 + randf() * 0.6)
		var r := 45.0 + randf() * (60.0 + k * 70.0); var a0 := randf() * TAU
		tris.append({"p": Vector2(p.x + (randf() - 0.5) * 200.0 if randf() < 0.35 else 60.0 + randf() * (W - 120.0), H + r + 20.0), "r": r, "rot": 0.0, "vr": (randf() - 0.5) * 2.4, "a": [a0, a0 + 1.6 + randf() * 0.9, a0 + 3.6 + randf() * 1.2], "vx": (randf() - 0.5) * 90.0})
		if randf() < 0.45: phis.append({"p": Vector2(80.0 + randf() * (W - 160.0), H + 40.0), "got": false})
	for i in range(tris.size() - 1, -1, -1):
		var o: Dictionary = tris[i]; o["p"] += Vector2(o["vx"] * d, -vs * d); o["rot"] += o["vr"] * d
		if o["p"].y < -o["r"] - 40.0: tris.remove_at(i); continue
		if inv <= 0.0 and not landed:
			var q := corners(o)
			for j in 3:
				if dseg(p + Vector2(0, -30), q[j], q[(j + 1) % 3]) < 15.0: m.fx.burst(p + Vector2(0, -30), 16, Color.WHITE, 320.0, 0.0); hurt(); break
	for f in phis:
		f["p"].y -= vs * d
		if not f["got"] and (f["p"] as Vector2).distance_to(p + Vector2(0, -30)) < 44.0: f["got"] = true; score(f["p"]); m.snd("phi")
	for l in lines:
		l[1] -= vs * 1.5 * d
		if l[1] < -80.0: l[1] = H + 40.0; l[0] = randf() * W
	if t > T_END + 2.2:
		gy = maxf(600.0, gy - vs * d)
		if not landed and gy - p.y < 4.0: landed = true; m.shake = 12.0; m.snd("boom", -6.0); m.fx.burst(Vector2(p.x, gy), 24, Color.WHITE, 400.0)
		if landed:
			p.y = gy; tilt = lerpf(tilt, 0.0, d * 10.0)
			if gy <= 600.0 and t > T_END + 4.2: m._finish(true)
		elif gy <= 600.0: p.y += 500.0 * d
	info = "v = g · t     a falling body gains 9.8 m/s every second     fall speed %.0f m/s" % (vs / 100.0 * 9.8)

func _draw() -> void:
	if not landed:
		for l in lines: draw_line(Vector2(l[0], l[1]), Vector2(l[0], l[1] + l[2]), Color(1, 1, 1, 0.16), 1.0)
	foe("hex", Vector2(W - 170.0, 130.0 + sin(t) * 20.0), 40.0, Color(1, 1, 1, 0.3))
	for o in tris:
		var q := corners(o); draw_polyline(PackedVector2Array([q[0], q[1], q[2], q[0]]), Color.WHITE, 2.0, true)
		for c in q: dot(c, 4.5)
	for f in phis:
		if not f["got"]: phi(f["p"], 26.0)
	if gy < H + 100.0:
		draw_line(Vector2(0, gy), Vector2(W, gy), Color.WHITE, 2.0)
		var pts := PackedVector2Array()
		for i in 6: pts.append(Vector2(640, gy + 340.0) + Vector2.from_angle(-PI / 2.0 + i * TAU * 2.0 / 5.0) * 330.0)
		draw_polyline(pts, Color(GOLD, 0.5), 1.0)
	if atk_t > 0.0 and not landed: draw_arc(p + Vector2(0, -30), 150.0 * (1.0 - atk_t / atk_dur) + 20.0, 0, TAU, 48, Color(GOLD, atk_t / atk_dur), 5.0, true)
	if not landed:
		draw_set_transform(p, tilt + PI / 2.0 + 0.1, Vector2.ONE); phi(Vector2(0, 6), 44.0, Color.WHITE, 0.0); draw_set_transform_matrix(Transform2D.IDENTITY)
	hero_at(p, "idle" if landed else hero_pose("surf"), tilt)
	draw_line(Vector2(30, 120), Vector2(30, H - 120), Color(1, 1, 1, 0.4), 1.0); dot(Vector2(30, 120 + (H - 240.0) * clampf(t / T_END, 0.0, 1.0)), 5.0)
