extends "res://chapter.gd"
## Number theory: only prime tiles hold you. Composites break and show their factorisation.
const TW := 50.0
const Y0 := 470.0
const NN := 89
var tiles: Array = []
var segs: Array = []
var notes: Array = []
var foes: Array = []
var start_s := {"x1": -300.0, "y1": Y0, "x2": 300.0, "y2": Y0}
var end_s := {"x1": 300.0 + NN * TW, "y1": Y0, "x2": 300.0 + NN * TW + 700.0, "y2": Y0}
var p := {}
var cp := Vector2(0, Y0)
var last_n := 0

func is_p(n: int) -> bool:
	if n < 2: return false
	var d := 2
	while d * d <= n:
		if n % d == 0: return false
		d += 1
	return true

func fac(n: int) -> String:
	if n == 1: return "1 is not prime"
	var f: Array = []; var mm := n; var d := 2
	while mm > 1:
		while mm % d == 0: f.append(str(d)); mm /= d
		d += 1
	return "%d = %s" % [n, " × ".join(f)]

func begin() -> void:
	title = "XI · THE PRIMES"; max_hp = 3; hp = 3
	for n in range(1, NN + 1): tiles.append({"n": n, "x1": 250.0 + n * TW, "y1": Y0, "x2": 250.0 + n * TW + TW, "y2": Y0, "prime": is_p(n), "gone": false, "lit": false})
	var a := 2
	for n in range(3, NN + 1):
		if is_p(n):
			if n - a >= 4: foes.append({"p": Vector2(250.0 + (a + n) / 2.0 * TW + TW / 2.0, Y0 - 150.0), "t": randf() * 6.0, "dead": false})
			a = n
	rebuild(); p = new_plat(0.0, Y0); cam_p = Vector2(300, 360)

func rebuild() -> void:
	segs = [start_s, end_s]
	for q in tiles:
		if not q["gone"]: segs.append(q)

func tick(d: float) -> void:
	atk_tick(d); plat_step(p, segs, d, false)
	var hp_ := Vector2(p["x"], p["y"])
	for e in foes:
		if e["dead"]: continue
		e["t"] += d; var ep: Vector2 = e["p"] + Vector2(0, sin(e["t"] * 2.2) * 16.0)
		if atk_hits(hp_, p["face"], ep, 22.0): e["dead"] = true; kill_fx(ep); p["dj"] = false
	var g = p["g"]
	if g != null and g.has("n"):
		last_n = g["n"]
		if g["prime"]:
			if not g["lit"]: g["lit"] = true; score(); m.snd("tick")
			cp = Vector2(g["x1"] + TW / 2.0, Y0)
		else:
			g["gone"] = true; rebuild(); p["g"] = null; p["vy"] = 120.0; m.snd("hurt", -6.0); m.shake = 6.0; m.combo = 0
			m.fx.burst(Vector2(g["x1"] + TW / 2.0, Y0), 14, Color.WHITE); notes.append({"p": Vector2(g["x1"] + TW / 2.0, Y0 - 60.0), "s": fac(g["n"]), "l": 0.0})
	for i in range(notes.size() - 1, -1, -1):
		notes[i]["l"] += d; notes[i]["p"].y -= 30.0 * d
		if notes[i]["l"] > 2.2: notes.remove_at(i)
	if p["y"] > 1100.0:
		if hurt():
			p = new_plat(cp.x, cp.y)
			for q in tiles: q["gone"] = false
			rebuild()
		return
	if p["g"] == end_s and p["x"] > end_s["x1"] + 250.0: m._finish(true)
	var nx := last_n + 1
	while not is_p(nx): nx += 1
	info = "a prime has exactly two divisors     last tile %d     gap to next prime %d" % [last_n, nx - last_n]
	cam_p.x = lerpf(cam_p.x, p["x"] + 170.0, d * 6.0)

func _draw() -> void:
	world_xf()
	for s in [start_s, end_s]: draw_line(Vector2(s["x1"], s["y1"]), Vector2(s["x2"], s["y2"]), Color.WHITE, 2.0); dot(Vector2(s["x1"], s["y1"])); dot(Vector2(s["x2"], s["y2"]))
	for q in tiles:
		if q["x2"] < cam_p.x - 700.0 or q["x1"] > cam_p.x + 700.0 or q["gone"]: continue
		var r := Rect2(q["x1"] + 3.0, Y0, TW - 6.0, TW - 6.0)
		draw_rect(r, Color(1, 0.82, 0.23, 0.22) if q["lit"] else Color(1, 1, 1, 0.05)); draw_rect(r, GOLD if q["lit"] else Color.WHITE, false, 2.5 if q["lit"] else 1.5)
		txt(str(q["n"]), Vector2(q["x1"] + (14.0 if q["n"] > 9 else 19.0), Y0 + 30.0), 17 if q["n"] > 9 else 19, GOLD if q["lit"] else Color.WHITE)
	for e in foes:
		if not e["dead"] and absf(e["p"].x - cam_p.x) < 800.0: foe("dia", e["p"] + Vector2(0, sin(e["t"] * 2.2) * 16.0), 22.0, Color(1, 0.3, 0.22) if absf(e["p"].x - p["x"]) < 180.0 else Color.WHITE)
	for q in notes: txt(q["s"], q["p"], 18, Color(1, 0.54, 0.44, clampf(2.2 - q["l"], 0.0, 1.0)), true)
	phi(Vector2(end_s["x1"] + 330.0, Y0 - 80.0 + sin(t * 2.0) * 6.0), 56.0)
	screen_xf(); plat_draw(p)
	txt("2 · 3 · 5 · 7 · 11 · 13 · …", Vector2(640, 46), 17, Color(1, 1, 1, 0.7), true)
