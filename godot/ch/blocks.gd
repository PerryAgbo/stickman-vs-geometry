extends "res://chapter.gd"
## Scaling: push the golden blocks, resize them by φ, climb the walls to the blue icosahedron.
const GY := 560.0
const S0 := 80.0
const MAXX := 4750.0
const PHI := 1.618033988749895
var walls: Array = []
var bl: Array = []
var allb: Array = []
var segs: Array = []
var p := {}
var goal := Vector2(4380, GY - 95)
var got := 0.0

func begin() -> void:
	title = "VI · THE GOLDEN BLOCKS"; acro = false; btn = [["attack", "SIZE"], ["jump", "JUMP"]]; max_hp = 1; hp = 1
	for w in [[800.0, 190.0, false], [1600.0, 250.0, false], [2300.0, 1160.0, true], [2750.0, 250.0, false], [3900.0, 330.0, false]]:
		walls.append({"x": w[0], "y": (GY - 100.0 - w[1]) if w[2] else GY - w[1], "w": 60.0, "h": w[1], "bar": w[2]})
	for x in [420.0, 1150.0, 1950.0, 3100.0, 3400.0]: bl.append({"cx": x + S0 / 2.0, "x": x, "y": GY - S0, "w": S0, "h": S0, "size": S0, "lv": 0, "flash": 0.0})
	allb = walls + bl
	segs = [{"x1": -300.0, "y1": GY, "x2": 5400.0, "y2": GY}]
	for b in allb:
		b["x1"] = b["x"]; b["y1"] = b["y"]; b["x2"] = b["x"] + b["w"]; b["y2"] = b["y"]; segs.append(b)
	p = new_plat(140.0, GY); cam_p = Vector2(640, 360)

func fits(b: Dictionary, cx: float, size: float) -> bool:
	var x1 := cx - size / 2.0; var x2 := cx + size / 2.0; var y1 := GY - size
	if x1 < 0.0 or x2 > MAXX: return false
	for o in allb:
		if o == b: continue
		if x2 > o["x"] + 0.01 and x1 < o["x"] + o["w"] - 0.01 and GY > o["y"] + 0.01 and y1 < o["y"] + o["h"] - 0.01: return false
	return true

func near() -> Dictionary:
	var best := {}; var bd := 47.0
	for b in bl:
		var d: float = maxf(maxf(b["x"] - p["x"] - 10.0, p["x"] - 10.0 - (b["x"] + b["w"])), 0.0)
		if d < bd and p["y"] > b["y"] - 8.0: bd = d; best = b
	return best

func tick(d: float) -> void:
	if got > 0.0:
		got += d
		if got > 1.4: m._finish(true)
		return
	if Input.is_action_just_pressed("attack"):
		var b := near()
		if not b.is_empty():
			var lv: int = (b["lv"] + 1) % 3; var ts := S0 * pow(PHI, lv); var dd := (ts - S0 * pow(PHI, b["lv"])) / 2.0; var ok := INF
			for cx in [b["cx"], b["cx"] - dd, b["cx"] + dd]:
				if fits(b, cx, ts): ok = cx; break
			if ok != INF: b["lv"] = lv; b["cx"] = ok; b["flash"] = 0.3; m.snd("phi"); m.fx.burst(Vector2(b["cx"], GY - ts / 2.0), 12, GOLD, 320.0, 0.0)
			else: m.snd("hurt", -6.0); m.shake = 5.0
	var pushing := false
	if p["g"] != null and ax() != 0.0:
		var dir := 1 if ax() > 0.0 else -1
		for b in bl:
			if p["y"] <= b["y"] + 6.0: continue
			var L: bool = absf(p["x"] + 10.0 - b["x"]) < 6.0; var R: bool = absf(p["x"] - 10.0 - (b["x"] + b["w"])) < 6.0
			if not L and not R: continue
			var push := (L and dir > 0) or (R and dir < 0); var drag := ay() > 0.5 and ((L and dir < 0) or (R and dir > 0))
			if push or drag:
				pushing = true; var nx: float = b["cx"] + dir * 150.0 * d
				if fits(b, nx, b["size"]): b["cx"] = nx
			break
	for b in bl:
		var ts := S0 * pow(PHI, b["lv"]); b["flash"] -= d
		b["size"] = move_toward(b["size"], ts, 420.0 * d); b["w"] = b["size"]; b["h"] = b["size"]; b["x"] = b["cx"] - b["size"] / 2.0; b["y"] = GY - b["size"]
		b["x1"] = b["x"]; b["x2"] = b["x"] + b["w"]; b["y1"] = b["y"]; b["y2"] = b["y"]
	var px: float = p["x"]
	plat_step(p, segs, d, true)
	if pushing: p["vx"] = clampf(p["vx"], -150.0, 150.0)
	p["x"] = clampf(p["x"], 20.0, MAXX)
	for b in allb:   # side collision with every block
		if p["y"] > b["y"] + 6.0 and p["y"] - 80.0 < b["y"] + b["h"] and p["x"] + 10.0 > b["x"] and p["x"] - 10.0 < b["x"] + b["w"]:
			p["x"] = b["x"] - 10.0 if px < b["x"] + b["w"] / 2.0 else b["x"] + b["w"] + 10.0; p["vx"] = 0.0
	if Vector2(p["x"], p["y"] - 40.0).distance_to(goal) < 95.0:
		got = 0.001; m.snd("clear"); m.combo += 5; m.fx.burst(goal, 60, BLUE, 500.0, 0.0)
	cam_p.x = lerpf(cam_p.x, clampf(p["x"] + 140.0, 640.0, MAXX - 560.0), d * 5.0)
	info = "φ² = φ + 1     scale a side by φ and the area grows by φ²     X resize · hold ↓ to drag"

func gold_block(b: Dictionary) -> void:
	var r := Rect2(b["x"], b["y"], b["w"], b["h"])
	draw_rect(r, Color(0.55, 0.44, 0.12)); draw_rect(Rect2(r.position, Vector2(r.size.x * 0.5, r.size.y)), Color(0.72, 0.58, 0.16, 0.5)); draw_rect(r, Color.WHITE, false, 1.5)
	for c in [r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]: dot(c, 4.0)

func _draw() -> void:
	world_xf()
	draw_line(Vector2(-300, GY), Vector2(5400, GY), Color.WHITE, 2.0)
	for o in walls:
		var r := Rect2(o["x"], o["y"], o["w"], o["h"])
		if o["bar"]: draw_rect(r, Color(0.6, 0.48, 0.16)); draw_rect(r, Color.WHITE, false, 1.5)
		else: draw_rect(r, Color(1, 1, 1, 0.04)); draw_rect(r, Color.WHITE, false, 1.5); dot(r.position, 4.0); dot(r.position + Vector2(r.size.x, 0), 4.0)
	var nb := near()
	for b in bl:
		gold_block(b)
		for i in 3: draw_circle(Vector2(b["cx"] - 10.0 + i * 10.0, b["y"] + 12.0), 2.5, GOLD if i <= b["lv"] else Color(1, 1, 1, 0.2))
		if b == nb: phi(Vector2(b["cx"], b["y"] - 34.0 + sin(t * 4.0) * 3.0), 22.0)
	if got < 0.6:
		var r := 70.0 + sin(t * 2.0) * 4.0
		draw_circle(goal, r * 0.8, Color(BLUE, 0.18)); draw_arc(goal, r * (1.0 + got * 3.0), 0, TAU, 40, Color(0.75, 0.91, 1.0), 1.6, true)
		var pts := PackedVector2Array()
		for i in 6: pts.append(goal + Vector2.from_angle(i * TAU / 6.0 + t * 0.7) * r)
		draw_polyline(pts, Color(0.75, 0.91, 1.0), 1.2); for q in pts: dot(q, 3.0); draw_line(goal, q, Color(0.75, 0.91, 1.0, 0.6), 1.0)
	screen_xf(); plat_draw(p)
