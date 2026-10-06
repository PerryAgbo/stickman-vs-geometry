extends "res://chapter.gd"
## The boss: the polytope. Sword up close, φ at range, dash through its beams and shockwaves.
const GY := 560.0
var segs: Array = []
var blocks := [Rect2(280, 470, 150, 90), Rect2(720, 425, 160, 135), Rect2(1170, 470, 150, 90)]
var p := {}
var B := {"p": Vector2(1250, 210), "r": 100.0, "hp": 40, "max": 40, "st": "intro", "t": 0.0, "flash": 0.0, "vy": 0.0, "beams": [], "fired": false}
var proj := {}
var waves: Array = []
var shards: Array = []
var dying := 0.0
var cd := 0.0

func begin() -> void:
	title = "XXI · THE PENTAGON"; max_hp = 5; hp = 5
	segs = [{"x1": -100.0, "y1": GY, "x2": 1700.0, "y2": GY}]
	for b in blocks: segs.append({"x1": b.position.x, "y1": b.position.y, "x2": b.end.x, "y2": b.position.y})
	p = new_plat(180.0, GY)

func phase() -> int:
	return 1 if B["hp"] > 26 else (2 if B["hp"] > 13 else 3)

func dmg(n: int) -> void:
	if B["st"] in ["intro", "slamA", "slamB", "slamC"]:   # armoured while it winds up and dives; strike it when it hovers or lands
		m.snd("tick", -4.0); m.fx.burst(B["p"], 6, Color.WHITE, 260.0, 0.0); return
	B["hp"] -= n; B["flash"] = 0.15; m.shake = 10.0; m.snd("hit"); hap(25); m.fx.burst(B["p"], 16, GOLD, 420.0, 200.0); score()
	if B["hp"] <= 0:
		dying = 0.001; m.shake = 30.0; m.snd("boom"); waves.clear(); shards.clear(); B["beams"] = []
		for i in 160: m.fx.burst(B["p"] + Vector2(randf() - 0.5, randf() - 0.5) * 140.0, 1, GOLD, 700.0, 300.0)

func tick(d: float) -> void:
	cd -= d
	if dying > 0.0:
		dying += d; plat_step(p, segs, d)
		if dying > 2.6: m._finish(true)
		return
	var hp_ := Vector2(p["x"], p["y"])
	var far: bool = (B["p"] as Vector2).distance_to(hp_ + Vector2(0, -45)) > 150.0
	if Input.is_action_just_pressed("attack") and far and cd <= 0.0 and proj.is_empty() and B["st"] != "intro":
		cd = 0.5; p["face"] = 1 if B["p"].x > p["x"] else -1; m.snd("throw")
		proj = {"p": hp_ + Vector2(0, -45), "l": 0.0}
	else: atk_tick(d)
	plat_step(p, segs, d); p["x"] = clampf(p["x"], 20.0, 1580.0)
	if not proj.is_empty():
		var to: Vector2 = B["p"] - proj["p"]; proj["p"] += to.normalized() * 980.0 * d; proj["l"] += d
		if to.length() < B["r"] + 6.0: dmg(1); proj = {}
		elif proj["l"] > 1.2: proj = {}
	if atk_hits(hp_, p["face"], B["p"], B["r"]) and B.get("hid", -1) != atk_id and B["st"] != "intro": B["hid"] = atk_id; dmg(2 if combo_n == 3 else 1)
	if dying > 0.0: return
	var ph := phase(); B["t"] += d; B["flash"] -= d
	var hurt_dir := func(dir: float) -> void:
		if hurt(): p["vy"] = -430.0; p["vx"] = dir * 380.0; p["g"] = null; m.fx.burst(hp_ + Vector2(0, -30), 14, m.HEROES[m.hero_i])
	match B["st"]:
		"intro":
			B["p"].x = lerpf(B["p"].x, 1150.0, d * 2.0)
			if B["t"] > 1.6: B["st"] = "hover"; B["t"] = 0.0
		"hover":
			B["p"].x = lerpf(B["p"].x, 800.0 + sin(t * 0.55) * 540.0, d * 1.6); B["p"].y = lerpf(B["p"].y, 215.0 + sin(t * 1.1) * 60.0, d * 2.0)
			if B["t"] > [0.0, 2.3, 1.7, 1.15][ph]:
				var q := randf(); B["t"] = 0.0
				if q < 0.42:
					B["st"] = "beam"; var n: int = [0, 1, 3, 5][ph]; var a: float = (hp_ + Vector2(0, -35) - B["p"]).angle(); B["beams"] = []
					for i in n: B["beams"].append(a + (i - (n - 1) / 2.0) * 0.3)
				elif q < 0.75 or ph == 1: B["st"] = "slamA"
				else:
					B["st"] = "shards"
					for i in 5 + ph * 2: shards.append({"p": Vector2(60.0 + randf() * 1480.0, -200.0 - randf() * 500.0), "rot": randf() * TAU, "v": 520.0 + randf() * 160.0})
		"beam":
			if B["t"] > 0.8 and not B["fired"]: B["fired"] = true; m.snd("boom", -10.0); m.shake = 6.0
			if B["t"] > 0.8 and B["t"] < 1.1:
				for a in B["beams"]:
					var dx: float = p["x"] - B["p"].x; var dy: float = p["y"] - 32.0 - B["p"].y
					var al := dx * cos(a) + dy * sin(a); var pe := absf(-dx * sin(a) + dy * cos(a))
					if al > 0.0 and pe < 22.0: hurt_dir.call(signf(dx) if dx != 0.0 else 1.0)
			if B["t"] > 1.25: B["st"] = "hover"; B["t"] = 0.0; B["fired"] = false; B["beams"] = []
		"shards":
			if B["t"] > 0.9: B["st"] = "hover"; B["t"] = 0.0
		"slamA":
			B["p"].x += clampf(p["x"] - B["p"].x, -760.0 * d, 760.0 * d); B["p"].y = lerpf(B["p"].y, 130.0, d * 5.0)
			if B["t"] > 0.75: B["st"] = "slamB"; B["t"] = 0.0
		"slamB":
			if B["t"] > 0.38: B["st"] = "slamC"; B["vy"] = 300.0
		"slamC":
			B["vy"] += 5200.0 * d; B["p"].y += B["vy"] * d
			if B["p"].y >= GY - B["r"] * 0.8:
				B["p"].y = GY - B["r"] * 0.8; B["st"] = "slamD"; B["t"] = 0.0; m.shake = 22.0; m.snd("boom", -4.0); hap(60)
				m.fx.burst(Vector2(B["p"].x, GY), 36, Color.WHITE, 620.0)
				waves.append([B["p"].x, 560.0]); waves.append([B["p"].x, -560.0])
				if ph == 3: waves.append([B["p"].x, 330.0]); waves.append([B["p"].x, -330.0])
				if absf(p["x"] - B["p"].x) < 140.0 and p["y"] > GY - 30.0: hurt_dir.call(signf(p["x"] - B["p"].x) if p["x"] != B["p"].x else 1.0)
		"slamD":
			if B["t"] > [0.0, 1.5, 1.2, 0.9][ph]: B["st"] = "hover"; B["t"] = 0.0
	if (B["p"] as Vector2).distance_to(hp_ + Vector2(0, -32)) < B["r"] and atk_t <= 0.0: hurt_dir.call(signf(p["x"] - B["p"].x) if p["x"] != B["p"].x else 1.0)
	for i in range(waves.size() - 1, -1, -1):
		waves[i][0] += waves[i][1] * d
		if waves[i][0] < -50.0 or waves[i][0] > 1650.0: waves.remove_at(i); continue
		if absf(waves[i][0] - p["x"]) < 24.0 and p["y"] > GY - 44.0: hurt_dir.call(signf(waves[i][1]))
	for i in range(shards.size() - 1, -1, -1):
		var s: Dictionary = shards[i]; s["p"].y += s["v"] * d; s["rot"] += d * 5.0
		if (s["p"] as Vector2).distance_to(hp_ + Vector2(0, -32)) < 30.0: hurt_dir.call(signf(p["x"] - s["p"].x) if p["x"] != s["p"].x else 1.0)
		if s["p"].y > GY: m.fx.burst(Vector2(s["p"].x, GY), 8, GOLD, 300.0); shards.remove_at(i)
	cam_p = Vector2(800, 300); cam_z = 0.8
	info = "diagonal / side = φ     armoured while it dives: strike when it hovers or lands     boss %d / %d" % [maxi(0, B["hp"]), B["max"]]

func _draw() -> void:
	world_xf()
	var pv := PackedVector2Array()
	for i in 5: pv.append(Vector2(800, 60) + Vector2.from_angle(-PI / 2.0 + i * TAU / 5.0) * 640.0)
	draw_colored_polygon(pv, Color(0.43, 0.35, 0.07, 0.35))
	var star := PackedVector2Array()
	for i in 6: star.append(pv[i * 2 % 5])
	draw_polyline(star, Color(1, 1, 1, 0.3), 1.0); pv.append(pv[0]); draw_polyline(pv, Color(1, 1, 1, 0.45), 1.0)
	draw_line(Vector2(-400, GY), Vector2(2000, GY), Color.WHITE, 2.0)
	for b in blocks:
		draw_rect(b, Color(0.55, 0.44, 0.12)); draw_rect(b, Color.WHITE, false, 1.5)
		for c in [b.position, b.position + Vector2(b.size.x, 0), b.end, b.position + Vector2(0, b.size.y)]: dot(c, 4.0)
	for a in B["beams"]:
		var e: Vector2 = B["p"] + Vector2.from_angle(a) * 2400.0
		if B["t"] < 0.8: draw_dashed_line(B["p"], e, Color(GOLD, 0.35 + 0.5 * B["t"] / 0.8), 1.5, 10.0)
		elif B["t"] < 1.1: draw_line(B["p"], e, Color(1, 0.97, 0.76), 26.0 * (1.0 - (B["t"] - 0.8) / 0.3) + 6.0)
	for q in waves: draw_polyline(PackedVector2Array([Vector2(q[0] - 16.0, GY), Vector2(q[0], GY - 46.0), Vector2(q[0] + 16.0, GY)]), Color.WHITE, 3.0, true)
	for s in shards:
		draw_line(s["p"], Vector2(s["p"].x, GY), Color(GOLD, 0.3), 1.0)
		draw_set_transform_matrix(_xf * Transform2D(s["rot"], s["p"])); draw_colored_polygon(PackedVector2Array([Vector2(0, -24), Vector2(21, 14), Vector2(-21, 14)]), Color(0.79, 0.64, 0.15)); draw_set_transform_matrix(_xf)
	if dying <= 0.0:
		var wob := sin(B["t"] * 90.0) * 6.0 if B["st"] == "slamB" else 0.0
		foe("hex", B["p"] + Vector2(wob, 0), B["r"] * 0.9, GOLD if B["flash"] > 0.0 else (Color(1, 0.6, 0.3) if phase() == 3 else Color.WHITE))
		if B["st"] == "beam" and B["t"] < 0.8: draw_circle(B["p"], 6.0 + B["t"] * 16.0, GOLD)
	if not proj.is_empty(): phi(proj["p"], 30.0, GOLD, proj["l"] * 30.0)
	screen_xf(); plat_draw(p)
	draw_rect(Rect2(430, 676, 420, 8), Color.WHITE, false, 1.5); draw_rect(Rect2(430, 676, 420.0 * maxf(0.0, B["hp"]) / B["max"], 8), GOLD); dot(Vector2(430, 680)); dot(Vector2(850, 680))
