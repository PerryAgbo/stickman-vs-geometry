extends "res://chapter.gd"
## DNA base pairing: stand in the lane that pairs with the next base. Halfway through it becomes RNA.
const LY := [270.0, 360.0, 450.0, 540.0]
const PX := 300.0
const GAP := 330.0
const COL := {"A": Color("6fe08a"), "T": Color("ff5a4a"), "U": Color("ff9a3a"), "G": Color("ffd23a"), "C": Color("6fd0ff")}
var cols: Array = []
var lane := 0
var ly := LY[0]
var ok := 0
var msg := 0.0
var said := false

func begin() -> void:
	title = "XVIII · THE HELIX"; btn = []; max_hp = 5; hp = 5
	var rng := RandomNumberGenerator.new(); rng.seed = 71
	for i in 40: cols.append({"b": "ATGC"[rng.randi() % 4], "rna": i >= 22, "x": 1500.0 + i * GAP + (500.0 if i >= 22 else 0.0), "done": false, "got": ""})

func lanes(rna: bool) -> Array:
	return ["A", "U", "G", "C"] if rna else ["A", "T", "G", "C"]

func pair(b: String, rna: bool) -> String:
	return {"A": "U" if rna else "T", "T": "A", "G": "C", "C": "G"}[b]

func tick(d: float) -> void:
	msg -= d
	if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("jump"): lane = maxi(0, lane - 1); m.snd("tick")
	if Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("attack"): lane = mini(3, lane + 1); m.snd("tick")
	ly = lerpf(ly, LY[lane], d * 22.0)
	var v := 350.0 + clampf(float(ok) / cols.size(), 0.0, 1.0) * 150.0
	for q in cols:
		var ox: float = q["x"]; q["x"] -= v * d
		if not q["done"] and ox > PX and q["x"] <= PX:
			q["done"] = true; var mine: String = lanes(q["rna"])[lane]
			if mine == pair(q["b"], q["rna"]):
				q["got"] = mine; ok += 1; score(Vector2(PX, ly)); m.snd("phi"); m.fx.burst(Vector2(PX, ly), 6, COL[mine], 300.0, 0.0)
			else:
				m.fx.burst(Vector2(PX, ly), 14, RED); hurt()
	var first = cols[22]
	if first["x"] < W + 200.0 and not said: said = true; msg = 3.2; m.snd("clear")
	var nx = null
	for q in cols:
		if not q["done"]: nx = q; break
	info = ("TRANSCRIPTION  DNA → RNA:  A–U  T–A  G–C  C–G" if (nx and nx["rna"]) else "REPLICATION  DNA → DNA:  A–T  T–A  G–C  C–G") + "     paired %d / %d" % [ok, cols.size()]
	if cols[cols.size() - 1]["x"] < PX - 300.0: m._finish(true)

func _draw() -> void:
	var nx = null
	for q in cols:
		if not q["done"]: nx = q; break
	var rna: bool = nx["rna"] if nx else true; var LN := lanes(rna)
	for s in [0.0, PI]:
		var pts := PackedVector2Array()
		for x in range(0, 1300, 16): pts.append(Vector2(x, 130.0 + sin(x * 0.02 + t * 2.0 + s) * 22.0))
		draw_polyline(pts, Color(BLUE if s > 0.0 else GOLD, 0.5), 2.0, true)
	for x in range(8, 1300, 32):
		var a := x * 0.02 + t * 2.0
		draw_line(Vector2(x, 130.0 + sin(a) * 22.0), Vector2(x, 130.0 - sin(a) * 22.0), Color(1, 1, 1, 0.25), 1.0)
	draw_line(Vector2(0, 200), Vector2(W, 200), Color.WHITE, 2.0); txt("template strand", Vector2(16, 190), 11, Color(1, 1, 1, 0.6))
	for i in 4:
		var b: String = LN[i]
		draw_dashed_line(Vector2(0, LY[i]), Vector2(W, LY[i]), Color(COL[b], 0.22), 1.0, 8.0)
		draw_circle(Vector2(70, LY[i]), 22.0, Color(0.04, 0.04, 0.05)); draw_arc(Vector2(70, LY[i]), 22.0, 0, TAU, 24, COL[b], 3.0 if i == lane else 1.5, true)
		txt(b, Vector2(62, LY[i] + 8), 22, COL[b])
	for q in cols:
		if q["x"] < -60.0 or q["x"] > W + 60.0: continue
		var cb: Color = COL[q["b"]]; var r := Rect2(q["x"] - 24.0, 200.0, 48.0, 44.0)
		draw_rect(r, Color(0.04, 0.04, 0.05)); draw_rect(r, cb, false, 2.5); txt(q["b"], Vector2(q["x"] - 9.0, 232.0), 26, cb)
		if q["done"]:
			if q["got"] != "":
				var i: int = lanes(q["rna"]).find(q["got"]); var c: Color = COL[q["got"]]
				draw_line(Vector2(q["x"], 244), Vector2(q["x"], LY[i] - 20.0), c, 3.0)
				draw_circle(Vector2(q["x"], LY[i]), 20.0, Color(0.04, 0.04, 0.05)); draw_arc(Vector2(q["x"], LY[i]), 20.0, 0, TAU, 24, c, 2.5, true); txt(q["got"], Vector2(q["x"] - 8.0, LY[i] + 7.0), 20, c)
			else: txt("✗", Vector2(q["x"] - 9.0, 300.0), 26, RED)
		elif q == nx: draw_dashed_line(Vector2(q["x"], 244), Vector2(q["x"], 560), Color(cb, 0.5), 1.5, 6.0)
	draw_arc(Vector2(PX, ly), 34.0, 0, TAU, 32, COL[LN[lane]], 2.5, true)
	hero_at(Vector2(PX, ly + 26.0), "run"); skin.scale *= 0.62
	draw_line(Vector2(PX, 200), Vector2(PX, 590), Color(1, 1, 1, 0.3), 1.0)
	if msg > 0.0:
		draw_rect(Rect2(0, 330, W, 90), Color(0, 0, 0, 0.6 * clampf(msg, 0.0, 1.0)))
		txt("TRANSCRIPTION", Vector2(640, 364), 26, GOLD, true); txt("RNA has no T.  A now pairs with U.", Vector2(640, 400), 18, Color.WHITE, true)
