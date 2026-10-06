extends "res://chapter.gd"
## The golden spiral: run inward; the view rotates and zooms with you.
const N := 17
const KK := 700.0
const AXX := 520.0
const AYY := 560.0
const PHI := 1.618033988749895
var arcs: Array = []
var obs: Array = []
var phis: Array = []
var u := 0.25
var h := 0.0
var vh := 0.0
var gap := 520.0
var slow := 0.0
var cp := 0.25
var ph := 0.0
var wxf := Transform2D.IDENTITY

func begin() -> void:
	title = "II · THE GOLDEN SPIRAL"; max_hp = 3; hp = 3
	var c := Vector2.ZERO; var r := 1000.0; var a0 := PI
	for i in N + 16:
		arcs.append({"c": c, "r": r, "a0": a0})
		var a1 := a0 - PI / 2.0; var e := c + Vector2.from_angle(a1) * r
		c = e + (c - e) / PHI; r /= PHI; a0 = a1
	var L: Vector2 = arcs[arcs.size() - 1]["c"]
	for a in arcs: a["c"] = a["c"] - L
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var uu := 1.3
	while uu < N - 0.7:
		var q := rng.randf()
		if q < 0.34: obs.append({"u": uu, "type": "spike", "hit": false})
		elif q < 0.62: obs.append({"u": uu, "type": "foe", "riv": rng.randf() < 0.5, "hit": false, "dead": false})
		elif q < 0.8: obs.append({"u": uu, "type": "bar", "hit": false})
		else: obs.append({"u": uu, "type": "spike", "hit": false}); obs.append({"u": uu + 0.055, "type": "spike", "hit": false})
		if rng.randf() < 0.7: phis.append({"u": uu + 0.17, "h": 34.0 if rng.randf() < 0.5 else 120.0, "got": false})
		uu += 0.37 + rng.randf() * 0.38

func pt(uu: float) -> Dictionary:
	var i := clampi(int(floor(uu)), 0, arcs.size() - 1); var f := uu - i; var A: Dictionary = arcs[i]; var a: float = A["a0"] - f * PI / 2.0
	return {"p": A["c"] + Vector2.from_angle(a) * A["r"], "a": a, "i": i, "f": f, "r": A["r"]}

func tick(d: float) -> void:
	slow = maxf(0.0, slow - d); atk_tick(d)
	var P := pt(u); var ppu: float = KK * pow(PHI, P["f"]) * PI / 2.0
	var v := (400.0 + minf(u / N, 1.0) * 70.0) * (0.55 if slow > 0.0 else 1.0)
	u += v * d / ppu; ph += v * d * 0.036
	if Input.is_action_just_pressed("jump") and h == 0.0: vh = 780.0; m.snd("jump")
	if h > 0.0 or vh > 0.0:
		if not Input.is_action_pressed("jump") and vh > 280.0: vh -= 3200.0 * d
		vh -= GRAV * d; h += vh * d
		if h <= 0.0: h = 0.0; vh = 0.0
	for o in obs:
		if o["hit"]: continue
		var dd: float = (o["u"] - u) * ppu
		if o["type"] == "foe" and atk_t > 0.0 and atk_t < atk_dur * 0.82 and dd > -24.0 and dd < 125.0 and h < 95.0:
			o["hit"] = true; o["dead"] = true; kill_fx(Vector2(AXX + dd, AYY - 30.0)); gap = minf(560.0, gap + 70.0); continue
		var col := false
		match o["type"]:
			"foe": col = absf(dd) < 22.0 and h < 46.0
			"spike": col = absf(dd) < 20.0 and h < 36.0
			"bar": col = absf(dd) < 14.0 and h > 24.0
		if col:
			o["hit"] = true
			if inv <= 0.0: gap -= 185.0; slow = 0.7; inv = 0.5; m.combo = 0; m.shake = 10.0; m.snd("hurt"); m.fx.burst(Vector2(AXX, AYY - 30), 12, Color.WHITE)
	for f in phis:
		if not f["got"] and absf((f["u"] - u) * ppu) < 30.0 and absf(h + 34.0 - f["h"]) < 48.0: f["got"] = true; score(Vector2(AXX, AYY - f["h"])); m.snd("phi")
	gap = minf(540.0, gap + 24.0 * d)
	m.shake = maxf(m.shake, clampf(1.0 - (gap - 150.0) / 260.0, 0.0, 1.0) * 5.0)
	if gap < 110.0:
		if hurt():
			u = cp; h = 0.0; vh = 0.0; gap = 500.0; slow = 0.0
			for o in obs: o["hit"] = o.get("dead", false)
	if u > cp + 5.0 and h == 0.0: cp = floor(u)
	if u >= N: m._finish(true)
	info = "φ = (1 + √5) / 2 ≈ 1.618     each square is 1/φ the size of the last     depth %d %%" % int(100.0 * u / N)

func place(uk: float, P: Dictionary) -> float:
	var Q := pt(uk); var sc: float = pow(PHI, u - uk)
	if sc < 0.04: return 0.0
	draw_set_transform_matrix(Transform2D(Q["a"] - P["a"], Vector2(sc, sc), 0.0, wxf * Q["p"]))
	return sc

func _draw() -> void:
	rivals_begin()
	var P := pt(u); var S: float = KK * pow(PHI, P["f"]) / P["r"]; var rho: float = PI / 2.0 - P["a"]
	wxf = Transform2D(rho, Vector2(S, S), 0.0, Vector2(AXX, AYY)) * Transform2D(0.0, -P["p"])
	draw_set_transform_matrix(wxf)
	for i in range(maxi(0, P["i"] - 5), mini(arcs.size(), P["i"] + 11)):
		var A: Dictionary = arcs[i]; var a1: float = A["a0"] - PI / 2.0
		var s: Vector2 = A["c"] + Vector2.from_angle(A["a0"]) * A["r"]; var e: Vector2 = A["c"] + Vector2.from_angle(a1) * A["r"]
		draw_polyline(PackedVector2Array([A["c"], s, s + e - A["c"], e, A["c"]]), Color(1, 1, 1, 0.3), 1.0 / S)
		draw_arc(A["c"], A["r"], a1, A["a0"], 40, Color.WHITE, 2.4 / S, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	for i in range(maxi(0, P["i"] - 2), mini(arcs.size(), P["i"] + 8)):
		var A: Dictionary = arcs[i]; dot(wxf * (A["c"] + Vector2.from_angle(A["a0"]) * A["r"]), 4.5)
	for o in obs:
		if o["u"] < u - 0.6 or o["u"] > u + 4.0: continue
		var sc := place(o["u"], P)
		if sc == 0.0: continue
		if o["type"] == "foe":
			if not o["dead"]:
				var hot: bool = o["u"] - u < 0.16
				if o["riv"]: rival_at(wxf * pt(o["u"])["p"], -1, "throw" if hot else "idle", 0.0, sc)
				else: foe("tri", Vector2(0, -26), 26.0, Color(1, 0.3, 0.22) if hot else Color.WHITE)
		elif o["type"] == "spike":
			draw_polyline(PackedVector2Array([Vector2(-17, 0), Vector2(0, -40), Vector2(17, 0)]), Color(1, 1, 1, 0.3 if o["hit"] else 1.0), 2.0, true); dot(Vector2(0, -40), 4.0)
		else:
			draw_dashed_line(Vector2(0, -100), Vector2(0, -420), GOLD, 2.0, 6.0); draw_circle(Vector2(0, -100), 9.0, Color.BLACK); draw_arc(Vector2(0, -100), 9.0, 0, TAU, 16, GOLD, 2.5, true)
			draw_line(Vector2(-26, -100), Vector2(26, -100), GOLD, 2.5)
	for f in phis:
		if not f["got"] and f["u"] > u - 0.3 and f["u"] < u + 4.0 and place(f["u"], P) > 0.0: phi(Vector2(0, -f["h"]), 24.0)
	if N < u + 5.0 and place(N, P) > 0.0: phi(Vector2(0, -70), 70.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var ppu: float = KK * pow(PHI, P["f"]) * PI / 2.0; var cu := maxf(0.0, u - gap / ppu); var Q := pt(cu); var q: Vector2 = wxf * Q["p"]
	var th: float = Q["a"] - P["a"]; var csc: float = pow(PHI, u - cu)
	foe("hex", q + Vector2(sin(th), -cos(th)) * 120.0 * csc, 46.0 * csc)
	if randf() < 0.5: m.fx.burst(q + Vector2(60, -10), 1, Color.WHITE, 300.0, 0.0)
	hero_at(Vector2(AXX, AYY - h), hero_pose("hurt" if slow > 0.0 else ("jump" if (h > 0.0 and vh > 0.0) else ("fall" if h > 0.0 else "run")))); skin.ph = ph
	draw_line(Vector2(490, 36), Vector2(790, 36), Color(1, 1, 1, 0.4), 1.0); dot(Vector2(490 + 300.0 * clampf(u / N, 0.0, 1.0), 36), 5.0); phi(Vector2(808, 36), 18.0)
