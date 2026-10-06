extends "res://chapter.gd"
## Conservation of energy: ride the hills on stored energy, boost with fuel, obey the speed gates.
const GR := 980.0
const BASE := 420.0
const ENDX := 9300.0
var HL := [[0.0, 270.0, 520.0], [1500.0, 120.0, 260.0], [2700.0, 175.0, 280.0], [4200.0, 300.0, 300.0], [5600.0, 210.0, 300.0], [6350.0, 120.0, 220.0], [7400.0, 330.0, 320.0], [8600.0, 150.0, 260.0]]
var gaps := [[6255.0, 6440.0]]
var gates := [{"x": 2100.0, "lim": 640.0, "ok": false}, {"x": 4900.0, "lim": 700.0, "ok": false}]
var cells := [{"x": 3400.0, "got": false}, {"x": 5050.0, "got": false}, {"x": 6900.0, "got": false}]
var cpx := [3300.0, 5000.0, 6700.0]
var x := 0.0
var v := 40.0
var fuel := 100.0
var air := false
var ap := Vector2.ZERO
var av := Vector2.ZERO
var cp := [0.0, 40.0, 100.0]

func begin() -> void:
	title = "XIII · THE COASTER"; max_hp = 3; hp = 3; cam_p = Vector2(200, 260)

func yT(xx: float) -> float:
	var y := BASE
	for h in HL: y -= h[1] * exp(-pow((xx - h[0]) / h[2], 2.0))
	return y

func sl(xx: float) -> float:
	return (yT(xx + 1.0) - yT(xx - 1.0)) / 2.0

func in_gap(xx: float) -> bool:
	for g in gaps:
		if xx > g[0] and xx < g[1]: return true
	return false

func pos() -> Vector2:
	return ap if air else Vector2(x, yT(x))

func respawn() -> void:
	x = cp[0]; v = cp[1]; fuel = maxf(cp[2], 50.0); air = false

func tick(d: float) -> void:
	var ox := x
	if not air:
		var s := sl(x); var q := sqrt(1.0 + s * s); var a := GR * s / q
		var boost := ax() > 0.0 and fuel > 0.0
		if boost:
			a += 300.0; fuel = maxf(0.0, fuel - 40.0 * d)
			if randf() < d * 40.0: m.fx.burst(Vector2(x - 14.0, yT(x) - 6.0), 1, GOLD, 240.0, 0.0)
		else: fuel = minf(100.0, fuel + 4.0 * d)
		if ax() < 0.0:
			var b := minf(absf(v), 520.0 * d); v -= signf(v) * b
		v += a * d; v *= 1.0 - 0.015 * d; x += v / q * d
		if x < -260.0: x = -260.0; v = absf(v) * 0.4
		for g in gaps:
			if (ox < g[0] and x >= g[0]) or (ox > g[1] and x <= g[1]):
				air = true; ap = Vector2(x, yT(x)); av = Vector2(v / q, v * s / q); m.snd("jump")
		for gt in gates:
			if (ox - gt["x"]) * (x - gt["x"]) < 0.0:
				if absf(v) > gt["lim"]:
					m.fx.burst(Vector2(x, yT(x) - 30.0), 30, RED)
					if hurt(): respawn()
					return
				elif not gt["ok"]: gt["ok"] = true; m.snd("phi")
		for q2 in cpx:
			if ox < q2 and x >= q2 and q2 > cp[0]: cp = [q2, v, fuel]
	else:
		av.y += GR * d; ap += av * d
		var ty := yT(ap.x)
		if not in_gap(ap.x) and ap.y >= ty - 2.0:
			if ap.y < ty + 34.0:
				var s := sl(ap.x); var q := sqrt(1.0 + s * s)
				x = ap.x; v = (av.x + av.y * s) / q; air = false; m.shake = 6.0; m.snd("tick"); m.fx.burst(Vector2(x, yT(x)), 10, Color.WHITE, 240.0)
			else:
				if hurt(): respawn()
				return
		elif ap.y > BASE + 500.0:
			if hurt(): respawn()
			return
	var p := pos()
	for c in cells:
		if not c["got"] and absf(p.x - c["x"]) < 40.0: c["got"] = true; fuel = minf(100.0, fuel + 35.0); score(Vector2(c["x"], yT(c["x"]) - 50.0)); m.snd("phi")
	if p.x > ENDX: m._finish(true)
	cam_p = cam_p.lerp(p + Vector2(200, -90), d * 6.0)
	var sp := av.length() if air else absf(v); var hh := (BASE - p.y) / 100.0
	info = "v = %.2f m/s   h = %.2f m   KE = %.1f   PE = %.1f   E = %.1f J/kg" % [sp / 100.0, hh, pow(sp / 100.0, 2) / 2.0, 9.8 * hh, pow(sp / 100.0, 2) / 2.0 + 9.8 * hh]

func _draw() -> void:
	world_xf()
	draw_dashed_line(Vector2(cam_p.x - 700, BASE), Vector2(cam_p.x + 700, BASE), Color(1, 1, 1, 0.25), 1.0, 7.0)
	var pts := PackedVector2Array()
	var xx := floorf((cam_p.x - 700.0) / 14.0) * 14.0
	while xx < cam_p.x + 700.0:
		if in_gap(xx) or xx < -270.0:
			if pts.size() > 1: draw_polyline(pts, Color.WHITE, 3.0, true)
			pts = PackedVector2Array()
		else: pts.append(Vector2(xx, yT(xx)))
		xx += 14.0
	if pts.size() > 1: draw_polyline(pts, Color.WHITE, 3.0, true)
	xx = floorf((cam_p.x - 700.0) / 70.0) * 70.0
	while xx < cam_p.x + 700.0:
		if not in_gap(xx): draw_line(Vector2(xx, yT(xx)), Vector2(xx, BASE + 400), Color(1, 1, 1, 0.16), 1.0)
		xx += 70.0
	for g in gaps: dot(Vector2(g[0], yT(g[0]))); dot(Vector2(g[1], yT(g[1])))
	for h in HL:
		if h[0] < cam_p.x - 760.0 or h[0] > cam_p.x + 760.0 or h[0] == 6350.0: continue
		var hy := yT(h[0])
		txt("h = %.1f m" % ((BASE - hy) / 100.0), Vector2(h[0], hy - 92), 15, Color.WHITE, true)
		txt("needs v ≥ %.1f m/s below" % (sqrt(2.0 * GR * (BASE - hy)) / 100.0), Vector2(h[0], hy - 70), 12, Color(1, 1, 1, 0.6), true)
	for gt in gates:
		var gy := yT(gt["x"]); var col := GOLD if gt["ok"] else Color(1, 0.54, 0.44)
		draw_set_transform_matrix(_xf * Transform2D(0.0, Vector2(1, 3.9), 0.0, Vector2(gt["x"], gy - 60.0)))
		draw_arc(Vector2.ZERO, 16.0, 0, TAU, 32, col, 1.0, true)
		draw_set_transform_matrix(_xf)
		txt("v ≤ %.1f m/s" % (gt["lim"] / 100.0), Vector2(gt["x"], gy - 136), 15, col, true)
	for c in cells:
		if not c["got"]: phi(Vector2(c["x"], yT(c["x"]) - 50.0 + sin(t * 3.0 + c["x"]) * 4.0), 26.0)
	phi(Vector2(ENDX + 60.0, yT(ENDX) - 80.0), 56.0)
	screen_xf()
	var p := pos(); var s := (av.y / (av.x if av.x != 0.0 else 1.0)) if air else sl(x)
	hero_at(p, "surf", atan(s), -1 if (av.x if air else v) < 0.0 else 1)
	var sp := av.length() if air else absf(v); var ke := sp * sp / 2.0; var pe := GR * (BASE - p.y); var scl := 150.0 / (GR * 340.0)
	draw_rect(Rect2(1066, 74, 196, 226), Color(0, 0, 0, 0.45)); draw_rect(Rect2(1066, 74, 196, 226), Color(1, 1, 1, 0.3), false, 1.0)
	var bars := [["KE", ke, m.HEROES[m.hero_i]], ["PE", pe, BLUE], ["E", ke + pe, GOLD]]
	for i in 3:
		var hh := clampf(bars[i][1] * scl, 0.0, 165.0)
		draw_rect(Rect2(1090 + i * 52, 250 - hh, 34, hh), bars[i][2]); txt(bars[i][0], Vector2(1096 + i * 52, 272), 13)
	draw_rect(Rect2(1080, 280, 160, 8), Color(1, 1, 1, 0.15)); draw_rect(Rect2(1080, 280, 160.0 * fuel / 100.0, 8), GOLD if fuel > 20.0 else RED)
	txt("fuel", Vector2(1246, 290), 11, Color(1, 1, 1, 0.6))
