extends "res://chapter.gd"
## Optics: rotate mirrors (and one emitter) to steer the beam onto the target. Five puzzles.
const ML := 110.0
const TR := 26.0
var PZ := [
	{"em": [120.0, 560.0, 0.0, false], "mir": [[700.0, 560.0, 20.0]], "walls": [], "glass": [], "tg": Vector2(700, 150), "tip": "law of reflection:  angle in = angle out"},
	{"em": [120.0, 160.0, 0.0, false], "mir": [[520.0, 160.0, 100.0], [520.0, 540.0, 10.0]], "walls": [], "glass": [], "tg": Vector2(1100, 540), "tip": "two mirrors make a periscope"},
	{"em": [120.0, 380.0, 0.0, false], "mir": [[400.0, 380.0, 80.0], [400.0, 120.0, 10.0], [900.0, 120.0, 70.0]], "walls": [[640.0, 200.0, 640.0, 620.0]], "glass": [], "tg": Vector2(900, 540), "tip": "light travels in straight lines, so go around the wall"},
	{"em": [140.0, 200.0, 8.0, true], "mir": [], "walls": [[900.0, 0.0, 900.0, 430.0]], "glass": [Rect2(470, 60, 260, 600)], "tg": Vector2(1120, 560), "tip": "refraction:  n₁·sin θ₁ = n₂·sin θ₂    (glass n = 1.5)"},
	{"em": [140.0, 600.0, -35.0, false], "mir": [[900.0, 137.0, 75.0], [900.0, 560.0, 15.0]], "walls": [], "glass": [Rect2(420, 150, 240, 420)], "tg": Vector2(1180, 560), "tip": "a glass slab shifts the beam sideways but keeps its direction"}]
var pi_ := 0
var sel := 0
var solved := 0.0
var hold := 0.0
var res := {}

func begin() -> void:
	title = "XII · THE MIRROR"; btn = []; max_hp = 1; hp = 1; res = trace(PZ[0])

func rots() -> Array:
	var P: Dictionary = PZ[pi_]; var r: Array = []
	if P["em"][3]: r.append(P["em"])
	r.append_array(P["mir"]); return r

func seg_hit(x: Vector2, dv: Vector2, a: Vector2, b: Vector2) -> float:
	var e := b - a; var den := dv.x * e.y - dv.y * e.x
	if absf(den) < 1e-9: return -1.0
	var tt := ((a.x - x.x) * e.y - (a.y - x.y) * e.x) / den; var u := ((a.x - x.x) * dv.y - (a.y - x.y) * dv.x) / den
	return tt if tt > 1e-3 and u >= 0.0 and u <= 1.0 else -1.0

func ends(mr: Array) -> Array:
	var c := Vector2.from_angle(deg_to_rad(mr[2])) * ML / 2.0; return [Vector2(mr[0], mr[1]) - c, Vector2(mr[0], mr[1]) + c]

func trace(P: Dictionary) -> Dictionary:
	var x := Vector2(P["em"][0], P["em"][1]); var dv := Vector2.from_angle(deg_to_rad(P["em"][2]))
	var inside := false; var hit := false; var pts := PackedVector2Array([x]); var marks: Array = []; var S: Array = []
	for mr in P["mir"]: var e := ends(mr); S.append([e[0], e[1], "m"])
	for w in P["walls"]: S.append([Vector2(w[0], w[1]), Vector2(w[2], w[3]), "w"])
	S.append_array([[Vector2(0, 0), Vector2(W, 0), "w"], [Vector2(W, 0), Vector2(W, H), "w"], [Vector2(W, H), Vector2(0, H), "w"], [Vector2(0, H), Vector2(0, 0), "w"]])
	for g in P["glass"]:
		var r: Rect2 = g; var c := [r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]
		for i in 4: S.append([c[i], c[(i + 1) % 4], "g"])
	for b in 16:
		var bt := 1e9; var bs: Array = []
		for sg in S:
			var tt := seg_hit(x, dv, sg[0], sg[1])
			if tt > 0.0 and tt < bt: bt = tt; bs = sg
		var f: Vector2 = P["tg"] - x; var pr := f.dot(dv); var d2 := f.length_squared() - pr * pr
		if pr > 0.0 and d2 < TR * TR:
			var tt := pr - sqrt(TR * TR - d2)
			if tt < bt: pts.append(x + dv * tt); hit = true; break
		if bs.is_empty(): break
		x += dv * bt; pts.append(x)
		if bs[2] == "w": break
		var n: Vector2 = (bs[1] - bs[0]).orthogonal().normalized()
		if dv.dot(n) > 0.0: n = -n
		var ci := -dv.dot(n); var ai := rad_to_deg(acos(clampf(ci, 0.0, 1.0)))
		if bs[2] == "m":
			dv = dv.reflect(n) * -1.0 if false else dv - 2.0 * dv.dot(n) * n
			marks.append([x, "%d° = %d°" % [int(ai), int(ai)]])
		else:
			var rr := 1.5 if inside else 1.0 / 1.5; var s2 := rr * rr * (1.0 - ci * ci)
			if s2 > 1.0: dv = dv - 2.0 * dv.dot(n) * n; marks.append([x, "total internal reflection"])
			else:
				var ct := sqrt(1.0 - s2); dv = rr * dv + (rr * ci - ct) * n; inside = not inside
				marks.append([x, "%d° → %d°" % [int(ai), int(rad_to_deg(asin(sqrt(s2))))]])
	return {"pts": pts, "hit": hit, "marks": marks}

func tick(d: float) -> void:
	var R := rots()
	if solved > 0.0:
		solved += d
		if solved > 1.2:
			if pi_ == PZ.size() - 1: m._finish(true); return
			pi_ += 1; sel = 0; solved = 0.0; res = trace(PZ[pi_])
		return
	if Input.is_action_just_pressed("move_right"): sel = (sel + 1) % R.size(); m.snd("tick")
	if Input.is_action_just_pressed("move_left"): sel = (sel + R.size() - 1) % R.size(); m.snd("tick")
	var dd := ay()
	if absf(dd) < 0.3: dd = 0.0
	if dd != 0.0:
		hold += d; R[sel][2] += dd * (10.0 if hold < 0.3 else 55.0) * d
	else: hold = 0.0
	res = trace(PZ[pi_])
	info = "puzzle %d / %d     selected angle = %.1f°" % [pi_ + 1, PZ.size(), fposmod(-R[sel][2], 360.0)]
	if res["hit"]:
		solved = 0.001; score(PZ[pi_]["tg"]); m.combo += 1; m.snd("clear"); hap(40); m.fx.burst(PZ[pi_]["tg"], 40, GOLD, 420.0, 0.0)

func _draw() -> void:
	var P: Dictionary = PZ[pi_]; var R := rots()
	for x in range(40, 1280, 80): draw_line(Vector2(x, 0), Vector2(x, H), Color(1, 1, 1, 0.05))
	for y in range(40, 720, 80): draw_line(Vector2(0, y), Vector2(W, y), Color(1, 1, 1, 0.05))
	for g in P["glass"]:
		draw_rect(g, Color(0.43, 0.82, 1.0, 0.14)); draw_rect(g, BLUE, false, 1.5); txt("glass  n = 1.5", (g as Rect2).position + Vector2((g as Rect2).size.x / 2.0, 26), 13, Color(0.75, 0.9, 1.0), true)
	for w in P["walls"]:
		draw_line(Vector2(w[0], w[1]), Vector2(w[2], w[3]), Color.WHITE, 5.0); dot(Vector2(w[0], w[1])); dot(Vector2(w[2], w[3]))
	var pts: PackedVector2Array = res["pts"]
	if pts.size() > 1:
		draw_polyline(pts, Color(1, 0.35, 0.22, 0.35), 9.0, true); draw_polyline(pts, Color(1, 0.97, 0.76) if solved > 0.0 else Color(1, 0.54, 0.44), 4.0 if solved > 0.0 else 2.5, true)
	for mk in res["marks"]: dot(mk[0], 3.0); txt(mk[1], mk[0] + Vector2(14, -12), 13, Color(1, 1, 1, 0.8))
	for mr in P["mir"]:
		var e := ends(mr); var on: bool = R[sel] == mr
		draw_line(e[0], e[1], GOLD if on else Color.WHITE, 5.0, true); dot(Vector2(mr[0], mr[1]))
		if on: draw_arc(Vector2(mr[0], mr[1]), ML / 2.0 + 10.0, 0, TAU, 40, Color(1, 0.82, 0.23, 0.4), 1.0)
	var em: Array = P["em"]
	draw_set_transform(Vector2(em[0], em[1]), deg_to_rad(em[2]), Vector2.ONE)
	draw_rect(Rect2(-34, -13, 40, 26), Color.BLACK); draw_rect(Rect2(-34, -13, 40, 26), GOLD if R[sel] == em else Color.WHITE, false, 2.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var T: Vector2 = P["tg"]
	draw_arc(T, TR, 0, TAU, 32, GOLD, 3.0, true); phi(T, 24.0, GOLD, 0.3)
	var o: Array = R[sel]
	hero_at(Vector2(o[0] - 46.0, minf(o[1] + 78.0, 712.0)), "jump" if solved > 0.0 else "throw")
	txt(P["tip"], Vector2(640, 46), 17, Color(1, 1, 1, 0.75), true)
	for i in PZ.size(): draw_circle(Vector2(600 + i * 20, 70), 5.0 if i == pi_ else 3.5, GOLD if i < pi_ else Color(1, 1, 1, 0.9 if i == pi_ else 0.3))
