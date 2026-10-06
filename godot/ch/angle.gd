extends "res://chapter.gd"
## Inclined plane: ride the φ down the 23° line, cut down what stands on it, outrun the polytope.
var SL := tan(deg_to_rad(23.0))
var segs: Array = []
var posts: Array = []
var phis: Array = []
var cps: Array = []
var foes: Array = []
var p := {}
var poly := Vector2(-950, 0)
var spin := 0.0
var far := 0.0
var endx := 0.0

func begin() -> void:
	title = "III · THE ANGLE"; max_hp = 3; hp = 3
	var rng := RandomNumberGenerator.new(); rng.seed = 23
	var x := -400.0; var y := 0.0
	var add := func(len: float, sl: float) -> Dictionary:
		var s := {"x1": x, "y1": y, "x2": x + len, "y2": y + len * sl, "sl": sl}; segs.append(s); x += len; y = s["y2"]; return s
	add.call(1700.0, SL); cps.append(Vector2(0, seg_y(segs[0], 0.0)))
	var n := 1
	while x < 21000.0:
		if rng.randf() < 0.35: add.call(150.0, -0.18)
		var gap := 150.0 + rng.randf() * 90.0
		phis.append({"p": Vector2(x + gap * 0.5, y + gap * SL * 0.5 - 80.0), "got": false})
		x += gap; y += gap * SL + rng.randf() * 40.0
		var len := 900.0 + rng.randf() * 900.0; var s: Dictionary = add.call(len, SL)
		if len > 1300.0: posts.append({"x": s["x1"] + 440.0 + rng.randf() * (len - 1040.0), "s": s, "hit": false})
		else: phis.append({"p": Vector2(s["x1"] + len * 0.5, seg_y(s, s["x1"] + len * 0.5) - 44.0), "got": false})
		var fx: float = s["x1"] + len * (0.25 if len > 1300.0 else 0.6); var k: String = "riv" if foes.size() % 2 == 1 else "tri"
		foes.append({"k": k, "hx": fx, "x": fx, "s": s, "r": 46.0 if k == "riv" else 26.0, "t": rng.randf() * 6.0, "dead": false})
		if n % 4 == 0: cps.append(Vector2(s["x1"] + 60.0, seg_y(s, s["x1"] + 60.0)))
		n += 1
	add.call(220.0, -0.25); endx = x
	respawn(cps[0])

func respawn(cp: Vector2) -> void:
	var g = null
	for s in segs:
		if cp.x >= s["x1"] and cp.x <= s["x2"]: g = s
	p = {"x": cp.x, "y": cp.y, "vx": 300.0, "vy": 0.0, "g": g, "stun": 0.0, "buf": 0.0, "coy": 0.0, "rot": 0.4, "lsl": SL, "rush": 0.0}
	poly = Vector2(cp.x - 800.0, cp.y); cam_p = Vector2(p["x"] + 250.0, p["y"] + 60.0)

func tick(d: float) -> void:
	p["stun"] -= d; p["rush"] -= d; atk_tick(d)
	p["buf"] = 0.12 if Input.is_action_just_pressed("jump") else p["buf"] - d
	p["coy"] = 0.1 if p["g"] != null else p["coy"] - d
	var hp_ := Vector2(p["x"], p["y"])
	for e in foes:
		if e["dead"] or absf(e["x"] - p["x"]) > 1000.0: continue
		e["t"] += d; e["x"] = e["hx"] + sin(e["t"] * 1.4) * 50.0
		var ep := Vector2(e["x"], seg_y(e["s"], clampf(e["x"], e["s"]["x1"], e["s"]["x2"])) - e["r"])
		if atk_hits(hp_, 1, ep, e["r"]):
			e["dead"] = true; kill_fx(ep); p["rush"] = 1.8; p["vx"] = minf(p["vx"] + 170.0, 800.0); poly.x -= 90.0
		elif p["stun"] <= 0.0 and ep.distance_to(hp_ + Vector2(0, -44)) < e["r"] + 18.0:
			e["dead"] = true; p["stun"] = 0.4; p["vx"] = 260.0; m.combo = 0; m.shake = 9.0; m.snd("hurt", -4.0); m.fx.burst(ep, 14, Color.WHITE)
	var px: float = p["x"]; var py: float = p["y"]
	if p["buf"] > 0.0 and p["coy"] > 0.0:
		var sl: float = p["g"]["sl"] if p["g"] != null else p["lsl"]
		p["vy"] = p["vx"] * sl - 740.0; p["g"] = null; p["coy"] = 0.0; p["buf"] = 0.0; m.snd("jump")
	if p["g"] != null:
		var s: Dictionary = p["g"]; var acc := 520.0 if s["sl"] > 0.0 else -150.0
		if ax() < 0.0: acc -= 800.0
		if ax() > 0.0: acc += 300.0
		p["vx"] = clampf(p["vx"] + acc * d, 260.0, (720.0 if ax() > 0.0 else 640.0) + (170.0 if p["rush"] > 0.0 else 0.0)); p["x"] += p["vx"] * d; p["lsl"] = s["sl"]
		if p["x"] > s["x2"]:
			var yy := seg_y(s, p["x"]); var q = null
			for o in segs:
				if o != s and p["x"] >= o["x1"] and p["x"] <= o["x2"] and absf(seg_y(o, p["x"]) - yy) < 16.0: q = o; break
			if q != null: p["g"] = q
			else: p["g"] = null; p["vy"] = p["vx"] * s["sl"]; p["y"] = yy
		if p["g"] != null: p["y"] = seg_y(p["g"], p["x"])
		if randf() < d * 30.0: m.fx.burst(Vector2(p["x"] - 10.0, p["y"]), 1, Color.WHITE, 200.0, 0.0)
	else:
		if not Input.is_action_pressed("jump") and p["vy"] < p["vx"] * SL - 200.0: p["vy"] += 2600.0 * d
		p["vy"] += GRAV * d; p["x"] += p["vx"] * d
		var ny: float = p["y"] + p["vy"] * d; var land = null; var ly := 1e9
		for s in segs:
			if p["x"] < s["x1"] or p["x"] > s["x2"]: continue
			var ys := seg_y(s, p["x"]); var yp := seg_y(s, px) if (px >= s["x1"] and px <= s["x2"]) else ys
			if py <= yp + 6.0 and ny >= ys and ys < ly: land = s; ly = ys
		if land != null: p["y"] = ly; p["g"] = land; p["vy"] = 0.0; m.fx.burst(Vector2(p["x"], p["y"]), 8, Color.WHITE, 260.0)
		else: p["y"] = ny
	far = maxf(far, p["x"])
	var nx = null
	for s in segs:
		if s["x2"] > p["x"]: nx = s; break
	for o in posts:
		var oy := seg_y(o["s"], o["x"])
		if not o["hit"] and absf(p["x"] - o["x"]) < 16.0 and p["y"] > oy - 34.0 and p["y"] < oy + 12.0:
			o["hit"] = true; p["stun"] = 0.5; p["vx"] = 260.0; m.combo = 0; m.snd("hurt", -4.0); m.shake = 9.0; m.fx.burst(Vector2(o["x"], oy - 20.0), 10, Color.WHITE)
	for f in phis:
		if not f["got"] and Vector2(p["x"], p["y"] - 34.0).distance_to(f["p"]) < 48.0: f["got"] = true; score(f["p"]); m.snd("phi")
	var gap: float = p["x"] - poly.x; var v := 440.0 + minf(far / 20000.0, 1.0) * 110.0
	if gap > 950.0: v = maxf(v, p["vx"] * 1.1)
	poly.x += v * d; spin += v * d / 160.0
	var gy := -1e9
	for s in segs:
		if poly.x + 90.0 >= s["x1"] and poly.x + 90.0 <= s["x2"]: gy = seg_y(s, poly.x + 90.0)
	poly.y = lerpf(poly.y, gy, d * 8.0) if gy > -1e8 else poly.y + v * SL * d
	if randf() < d * 40.0: m.fx.burst(Vector2(poly.x + 120.0, poly.y - randf() * 60.0), 2, Color.WHITE, 420.0, 0.0)
	m.shake = maxf(m.shake, clampf(1.0 - (gap - 150.0) / 400.0, 0.0, 1.0) * 5.0)
	var died: bool = gap < 130.0 or (p["g"] == null and nx != null and p["y"] > maxf(nx["y1"], nx["y2"]) + 600.0)
	if died:
		var cp: Vector2 = cps[0]
		for q in cps:
			if q.x <= far: cp = q
		if hurt(): respawn(cp)
		return
	if p["x"] > endx + 250.0: m._finish(true)
	p["rot"] = lerpf(p["rot"], atan(p["g"]["sl"]) if p["g"] != null else atan2(p["vy"], p["vx"]) * 0.5, d * 12.0)
	cam_p = cam_p.lerp(Vector2(p["x"] + 250.0, p["y"] + 60.0), d * 7.0)
	info = "a = g · sin θ     on 23° only sin 23° ≈ 39%% of gravity pulls you along the line     v = %.1f m/s" % (p["vx"] / 100.0)

func _draw() -> void:
	rivals_begin(); world_xf()
	var cut := poly.x + 110.0
	for s in segs:
		if s["x2"] < cut or s["x1"] > cam_p.x + 800.0: continue
		var a := maxf(s["x1"], cut)
		draw_line(Vector2(a, seg_y(s, a)), Vector2(s["x2"], s["y2"]), Color.WHITE, 2.0, true)
		if s["x1"] >= cut:
			if s["sl"] > 0.0:
				draw_dashed_line(Vector2(s["x1"], s["y1"]), Vector2(s["x1"] + 260.0, s["y1"]), Color(1, 1, 1, 0.4), 1.0, 7.0)
				draw_arc(Vector2(s["x1"], s["y1"]), 70.0, 0.0, atan(s["sl"]), 12, Color(1, 1, 1, 0.4), 1.0); txt("23°", Vector2(s["x1"] + 96.0, s["y1"] + 28.0), 15, Color(1, 1, 1, 0.8))
			dot(Vector2(s["x1"], s["y1"]))
		dot(Vector2(s["x2"], s["y2"]))
	for o in posts:
		if o["x"] < cut: continue
		var oy := seg_y(o["s"], o["x"]); draw_line(Vector2(o["x"], oy), Vector2(o["x"], oy - 30.0), Color.WHITE, 2.0); dot(Vector2(o["x"], oy - 34.0))
	for f in phis:
		if not f["got"] and f["p"].x > cut: phi(f["p"] + Vector2(0, sin(t * 3.0 + f["p"].x) * 4.0), 24.0)
	for e in foes:
		if e["dead"] or e["x"] < cut or absf(e["x"] - cam_p.x) > 800.0: continue
		var ep := Vector2(e["x"], seg_y(e["s"], clampf(e["x"], e["s"]["x1"], e["s"]["x2"])) - e["r"]); var hot := absf(e["x"] - p["x"]) < 180.0
		if e["k"] == "riv": rival_at(ep + Vector2(0, e["r"]), -1, "throw" if hot else "idle")
		else: foe("tri", ep, 26.0, Color(1, 0.3, 0.22) if hot else Color.WHITE)
	foe("hex", poly + Vector2(0, -150), 58.0)
	screen_xf()
	var pp := Vector2(p["x"], p["y"])
	hero_at(pp + Vector2(0, -14).rotated(p["rot"]), hero_pose("hurt" if p["stun"] > 0.0 else ("surf" if p["g"] != null else "jump")), p["rot"])
	var sp := scr(pp); draw_set_transform(sp, p["rot"] + PI / 2.0, Vector2(cam_z, cam_z)); phi(Vector2(0, 7), 40.0, Color.WHITE, 0.0); draw_set_transform_matrix(Transform2D.IDENTITY)
	if p["x"] - poly.x > 680.0: txt("◄", Vector2(20, 300), 30, Color(1, 1, 1, 0.5 + 0.5 * sin(t * 10.0)))
	var mm := clampf(p["x"] / endx, 0.0, 1.0); draw_line(Vector2(490, 36), Vector2(790, 96), Color(1, 1, 1, 0.4), 1.0); dot(Vector2(490 + 300.0 * mm, 36 + 60.0 * mm), 5.0)
