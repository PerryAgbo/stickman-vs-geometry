extends "res://chapter.gd"
## The pendulum: hook a node, swing, let go on the upswing. Platforms are checkpoints.
const RANGE := 390.0
var nodes: Array = []
var segs: Array = []
var cps: Array = []
var foes: Array = []
var exit_s := {}
var p := {}
var rope := {}
var cp := Vector2.ZERO
var last_n := -1
var last_t := -9.0

func begin() -> void:
	title = "V · THE TESSERACT"; max_hp = 3; hp = 3
	var rng := RandomNumberGenerator.new(); rng.seed = 31
	var x := 300.0; var y := 600.0
	segs.append({"x1": -150.0, "y1": 600.0, "x2": 300.0, "y2": 600.0}); cps.append(Vector2(120, 600))
	for g in 9:
		for i in 3 + g % 2:
			x += 300.0 + rng.randf() * 40.0; y -= 25.0 + rng.randf() * 45.0; nodes.append(Vector2(x, y - 250.0))
		x += 240.0; y -= 10.0; segs.append({"x1": x, "y1": y, "x2": x + 260.0, "y2": y}); cps.append(Vector2(x + 70.0, y)); x += 260.0
	exit_s = segs[segs.size() - 1]; exit_s["x2"] += 420.0
	for i in range(1, nodes.size(), 2): foes.append({"p": Vector2((nodes[i - 1].x + nodes[i].x) / 2.0, maxf(nodes[i - 1].y, nodes[i].y) + 150.0), "t": randf() * 6.0, "dead": false})
	p = new_plat(120.0, 600.0); cp = cps[0]; cam_p = Vector2(270, 450)

func target() -> int:
	var best := -1; var bs := 1e9
	for i in nodes.size():
		var d: float = nodes[i].distance_to(Vector2(p["x"], p["y"] - 70.0))
		if d > RANGE or (i == last_n and t - last_t < 0.5): continue
		var sc := d - (260.0 if nodes[i].x > p["x"] + 20.0 else 0.0)
		if sc < bs: bs = sc; best = i
	return best

func tick(d: float) -> void:
	var tg := target()
	if rope.is_empty() and Input.is_action_just_pressed("attack") and tg >= 0:
		var dd: float = nodes[tg].distance_to(Vector2(p["x"], p["y"] - 70.0))
		rope = {"n": tg, "L": clampf(dd, 140.0, RANGE), "min": maxf(140.0, dd * 0.6)}; p["g"] = null; m.snd("throw")
	else: atk_tick(d)
	if not rope.is_empty() and not Input.is_action_pressed("attack"):
		last_n = rope["n"]; last_t = t; rope = {}
		if p["vy"] < 0.0: p["vx"] *= 1.12; p["vy"] *= 1.12
		m.snd("jump")
	if not rope.is_empty():
		var n: Vector2 = nodes[rope["n"]]; var py: float = p["y"]
		rope["L"] = maxf(rope["min"], rope["L"] - 170.0 * d)
		p["vy"] += GRAV * d; p["vx"] += ax() * 650.0 * d; p["x"] += p["vx"] * d; p["y"] += p["vy"] * d
		var dv := Vector2(p["x"], p["y"] - 70.0) - n; var dl := dv.length()
		if dl > rope["L"]:
			dv /= dl; p["x"] = n.x + dv.x * rope["L"]; p["y"] = n.y + dv.y * rope["L"] + 70.0
			var vr: float = p["vx"] * dv.x + p["vy"] * dv.y
			if vr > 0.0: p["vx"] -= vr * dv.x; p["vy"] -= vr * dv.y
		for s in segs:
			if p["x"] >= s["x1"] and p["x"] <= s["x2"] and py <= s["y1"] + 6.0 and p["y"] >= s["y1"] and p["vy"] > 0.0:
				p["y"] = s["y1"]; p["vy"] = 0.0; p["g"] = s; rope = {}; break
		if absf(p["vx"]) > 40.0: p["face"] = 1 if p["vx"] > 0.0 else -1
		p["ph"] += absf(p["vx"]) * d * 0.036; p["pose"] = "jump"
	else: plat_step(p, segs, d)
	var hp_ := Vector2(p["x"], p["y"])
	for e in foes:
		if e["dead"]: continue
		e["t"] += d; var ep: Vector2 = e["p"] + Vector2(0, sin(e["t"] * 2.2) * 16.0)
		if atk_hits(hp_, p["face"], ep, 22.0): e["dead"] = true; kill_fx(ep); p["dj"] = false; p["vy"] = minf(p["vy"], -560.0); p["g"] = null
		elif p["stun"] <= 0.0 and ep.distance_to(hp_ + Vector2(0, -44)) < 40.0: e["dead"] = true; p["stun"] = 0.2; p["vx"] *= 0.4; m.combo = 0; m.snd("hurt", -4.0); m.fx.burst(ep, 14, Color.WHITE)
	if p["g"] != null:
		for q in cps:
			if q.x >= p["g"]["x1"] and q.x <= p["g"]["x2"]: cp = q
	if p["y"] > cp.y + 1100.0:
		if hurt(): p = new_plat(cp.x, cp.y); rope = {}
		return
	if p["g"] == exit_s and p["x"] > exit_s["x1"] + 470.0: m._finish(true)
	cam_p = cam_p.lerp(Vector2(p["x"] + 150.0, p["y"] - 150.0), d * 5.0)
	info = "T = 2π · √(L / g)     a shorter rope swings faster     L = %.1f m" % ((rope["L"] if not rope.is_empty() else RANGE) / 100.0)

func _draw() -> void:
	foe("hex", Vector2(760 - cam_p.x * 0.05, 360 - cam_p.y * 0.05), 150.0, Color(1, 1, 1, 0.3))
	world_xf()
	var pts := PackedVector2Array(nodes); draw_polyline(pts, Color(1, 1, 1, 0.28), 1.0)
	for n in nodes: draw_line(n, n + Vector2(-380, -1400), Color(1, 1, 1, 0.1), 1.0); draw_line(n, n + Vector2(520, -1400), Color(1, 1, 1, 0.1), 1.0)
	var tg: int = rope["n"] if not rope.is_empty() else target()
	for i in nodes.size():
		dot(nodes[i], 7.0)
		if i == tg: draw_arc(nodes[i], 15.0 + sin(t * 8.0) * 2.0, 0, TAU, 24, GOLD, 2.0, true)
	for s in segs:
		draw_line(Vector2(s["x1"], s["y1"]), Vector2(s["x2"], s["y2"]), Color.WHITE, 2.5); dot(Vector2(s["x1"], s["y1"])); dot(Vector2(s["x2"], s["y2"]))
	phi(Vector2(exit_s["x1"] + 500.0, exit_s["y1"] - 80.0 + sin(t * 2.0) * 6.0), 56.0)
	for e in foes:
		if not e["dead"] and absf(e["p"].x - cam_p.x) < 800.0: foe("dia", e["p"] + Vector2(0, sin(e["t"] * 2.2) * 16.0), 22.0)
	if not rope.is_empty():
		var n: Vector2 = nodes[rope["n"]]; draw_line(Vector2(p["x"], p["y"] - 68.0), n, Color.WHITE, 2.5, true)
	screen_xf()
	if not rope.is_empty():
		var n: Vector2 = nodes[rope["n"]]
		hero_at(Vector2(p["x"], p["y"]), "jump", atan2(n.x - p["x"], p["y"] - 70.0 - n.y) * 0.5, p["face"])
	else: plat_draw(p)
	var mm := clampf(p["x"] / exit_s["x1"], 0.0, 1.0); draw_line(Vector2(490, 36), Vector2(790, 36), Color(1, 1, 1, 0.4), 1.0); dot(Vector2(490 + 300.0 * mm, 36), 5.0)
