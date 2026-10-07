extends "res://chapter.gd"
## Waves: platforms ride a travelling wave, a standing wave, then two waves added together.
const Y0 := 430.0
const OM := 1.5
var kk := TAU / 1680.0
var segs: Array = []
var pads: Array = []
var secs: Array = []
var cps: Array = []
var foes: Array = []
var phis: Array = []
var endx := 0.0
var p := {}
var cp := Vector2.ZERO

func F(i: int, x: float, tt: float) -> float:
	match i:
		0: return 70.0 * sin(kk * x - OM * tt)
		1: return 115.0 * sin(kk * x) * cos(OM * tt)
	return 62.0 * sin(kk * x - OM * tt) + 46.0 * sin(1.6 * kk * x + 1.3 * OM * tt)

func begin() -> void:
	title = "X · THE SINE WAVE"; btn = [["attack", "ATK"], ["jump", "JUMP"], ["dash", "DASH"]]; can_dash = true; max_hp = 3; hp = 3
	var x := -200.0
	var rest := func(wd: float) -> void:
		segs.append({"x1": x, "y1": Y0, "x2": x + wd, "y2": Y0, "rest": true}); cps.append(Vector2(x + wd / 2.0, Y0)); x += wd
	rest.call(530.0)
	for i in 3:
		var x0 := x
		for j in 10:
			x += 90.0; var s := {"x1": x, "y1": Y0, "x2": x + 120.0, "y2": Y0, "sec": i, "rise": 0.0}; segs.append(s); pads.append(s)
			if j % 3 == 1: phis.append({"s": s, "got": false})
			if j % 3 == 2: foes.append({"s": s, "p": Vector2(x + 60.0, Y0 - 150.0), "t": randf() * 6.0, "dead": false, "riv": false})
			x += 120.0
		x += 90.0; secs.append([i, x0, x]); rest.call(700.0 if i == 2 else 320.0)
	for s in segs:
		if s.has("rest") and s["x1"] > 0.0 and s["x2"] - s["x1"] < 500.0: foes.append({"s": s, "p": Vector2((s["x1"] + s["x2"]) / 2.0 + 60.0, Y0), "t": 0.0, "dead": false, "riv": true})
	endx = x - 350.0; p = new_plat(0.0, Y0); cp = cps[0]; cam_p = Vector2(300, 330)

func tick(d: float) -> void:
	for s in pads:
		var y := Y0 + F(s["sec"], s["x1"] + 60.0, t); s["rise"] = maxf(0.0, s["y1"] - y); s["y1"] = y; s["y2"] = y
	atk_tick(d); plat_step(p, segs, d, false)
	var hp_ := Vector2(p["x"], p["y"])
	for e in foes:
		if e["dead"]: continue
		e["t"] += d
		var ep: Vector2 = Vector2(e["p"].x, e["s"]["y1"] - 150.0 + sin(e["t"] * 2.2) * 12.0) if not e["riv"] else e["p"]
		var r := 46.0 if e["riv"] else 22.0
		if atk_hits(hp_, p["face"], ep + (Vector2(0, -r) if e["riv"] else Vector2.ZERO), r): e["dead"] = true; kill_fx(ep)
		elif p["stun"] <= 0.0 and dash_t <= 0.0 and (ep + (Vector2(0, -r) if e["riv"] else Vector2.ZERO)).distance_to(hp_ + Vector2(0, -44)) < r + 18.0:
			e["dead"] = true; p["stun"] = 0.3; p["vx"] = -p["face"] * 200.0; m.combo = 0; m.snd("hurt", -4.0); m.fx.burst(ep, 14, Color.WHITE)
	if p["g"] != null and p["g"].has("rest"):
		for q in cps:
			if q.x >= p["g"]["x1"] and q.x <= p["g"]["x2"]: cp = q
	for f in phis:
		if not f["got"] and hp_.distance_to(Vector2(f["s"]["x1"] + 60.0, f["s"]["y1"] - 36.0)) < 44.0: f["got"] = true; score(Vector2(f["s"]["x1"] + 60.0, f["s"]["y1"] - 70.0)); m.snd("phi")
	if p["y"] > 1200.0:
		if hurt(): p = new_plat(cp.x, cp.y)
		return
	if p["x"] > endx: m._finish(true)
	cam_p = Vector2(lerpf(cam_p.x, p["x"] + 170.0, d * 6.0), lerpf(cam_p.y, clampf(p["y"] - 80.0, 250.0, 420.0), d * 3.0))
	info = "λ = 16.8 m   ω = 1.5 rad/s   T = 2π/ω = %.2f s   wave speed v = ω/k = %.2f m/s" % [TAU / OM, OM / kk / 100.0]

func _draw() -> void:
	rivals_begin(); world_xf()
	draw_dashed_line(Vector2(cam_p.x - 700, Y0), Vector2(cam_p.x + 700, Y0), Color(1, 1, 1, 0.15), 1.0, 7.0)
	var LBL := ["travelling wave      y = A·sin(kx − ωt)", "standing wave      y = 2A·sin(kx)·cos(ωt)", "superposition      y = y₁ + y₂"]
	for q in secs:
		if q[2] < cam_p.x - 700.0 or q[1] > cam_p.x + 700.0: continue
		var pts := PackedVector2Array(); var xx: float = q[1]
		while xx <= q[2]: pts.append(Vector2(xx, Y0 + F(q[0], xx, t))); xx += 12.0
		draw_polyline(pts, Color(GOLD, 0.45), 1.5, true); txt(LBL[q[0]], Vector2(q[1] + 60.0, Y0 - 250.0), 17, Color(1, 1, 1, 0.8))
		var c := Vector2(q[1] - 70.0, Y0 - 150.0); var a := -OM * t
		draw_arc(c, 44.0, 0, TAU, 32, Color(1, 1, 1, 0.7), 1.2, true); draw_line(c + Vector2(-54, 0), c + Vector2(54, 0), Color(1, 1, 1, 0.7), 1.0); draw_line(c + Vector2(0, -54), c + Vector2(0, 54), Color(1, 1, 1, 0.7), 1.0)
		draw_line(c, c + Vector2.from_angle(a) * 44.0, GOLD, 1.5); draw_line(c + Vector2.from_angle(a) * 44.0, Vector2(c.x + cos(a) * 44.0, c.y), GOLD, 1.5); dot(c + Vector2.from_angle(a) * 44.0, 4.0)
	for s in segs:
		if s["x2"] < cam_p.x - 700.0 or s["x1"] > cam_p.x + 700.0: continue
		draw_line(Vector2(s["x1"], s["y1"]), Vector2(s["x2"], s["y2"]), Color.WHITE, 3.0 if s.has("sec") else 2.0, true); dot(Vector2(s["x1"], s["y1"]), 4.5); dot(Vector2(s["x2"], s["y2"]), 4.5)
		if s.has("sec"): draw_line(Vector2(s["x1"] + 60.0, s["y1"]), Vector2(s["x1"] + 60.0, Y0), Color(1, 1, 1, 0.2), 1.0)
	for f in phis:
		if not f["got"]: phi(Vector2(f["s"]["x1"] + 60.0, f["s"]["y1"] - 70.0), 24.0)
	for e in foes:
		if e["dead"] or absf(e["p"].x - cam_p.x) > 800.0: continue
		var hot: bool = absf(e["p"].x - p["x"]) < 180.0
		if e["riv"]: rival_at(e["p"], -1 if e["p"].x > p["x"] else 1, "throw" if hot else "idle")
		else: foe("dia", Vector2(e["p"].x, e["s"]["y1"] - 150.0 + sin(e["t"] * 2.2) * 12.0), 22.0, Color(1, 0.3, 0.22) if hot else Color.WHITE)
	phi(Vector2(endx + 120.0, Y0 - 80.0 + sin(t * 2.0) * 6.0), 56.0)
	screen_xf(); plat_draw(p)
