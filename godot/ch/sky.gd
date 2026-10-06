extends "res://chapter.gd"
## Flight: free flight through the swarm, then the gunship. You fire automatically.
const BT := 46.0
var en: Array = []
var bolts: Array = []
var p := Vector2(240, 360)
var v := Vector2.ZERO
var rot := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var dd := Vector2.RIGHT
var cd := 0.0
var spawn := 1.5
var boss := {}
var win_t := 0.0
var kills := 0

func begin() -> void:
	title = "XX · THE SKY"; max_hp = 6; hp = 6

func hit_e(e: Dictionary, n: int) -> void:
	if e["dead"]: return
	e["hp"] -= n; e["flash"] = 0.12; m.shake = maxf(m.shake, 5.0); m.snd("hit", -3.0); m.fx.burst(e["p"], 8, GOLD, 300.0, 0.0)
	if e["hp"] <= 0:
		e["dead"] = true; kills += 1; score(e["p"]); m.fx.burst(e["p"], 160 if e.get("boss", false) else 24, GOLD, 800.0 if e.get("boss", false) else 420.0, 200.0)
		if e.get("boss", false): m.snd("boom"); m.shake = 30.0

func shoot(x: Vector2, a: float, sp := 380.0) -> void:
	bolts.append({"p": x, "v": Vector2.from_angle(a) * sp, "mine": false})

func tick(d: float) -> void:
	dash_cd -= d; cd -= d; atk_tick(d)
	var axy := Vector2(ax(), ay())
	if Input.is_action_just_pressed("dash") and dash_cd <= 0.0:
		dash_t = 0.17; dash_cd = 0.5; dd = axy.normalized() if axy != Vector2.ZERO else Vector2.RIGHT; inv = maxf(inv, 0.25); m.snd("dash")
	if dash_t > 0.0: dash_t -= d; v = dd * 1050.0
	else: v = v.lerp(axy * Vector2(450.0, 410.0), d * 9.0)
	p.x = clampf(p.x + v.x * d, 60.0, W - 260.0); p.y = clampf(p.y + v.y * d, 110.0, H - 60.0); rot = lerpf(rot, v.y / 1400.0, d * 10.0)
	if cd <= 0.0: cd = 0.15; bolts.append({"p": p + Vector2(34, -34), "v": Vector2(1150, 0), "mine": true}); m.snd("tick", -14.0)
	if randf() < d * 40.0: m.fx.burst(p + Vector2(-30, -30), 1, GOLD, 300.0, 0.0)
	if boss.is_empty():
		if t < BT:
			spawn -= d
			if spawn <= 0.0:
				var k := clampf(t / BT, 0.0, 1.0); spawn = lerpf(1.05, 0.5, k) * (0.7 + randf() * 0.6); var q := randf()
				var kind := "dart" if q < 0.4 else ("dia" if q < 0.75 else "sq")
				en.append({"k": kind, "p": Vector2(W + 50.0, p.y - 34.0 + (randf() - 0.5) * 120.0 if kind == "dart" else 120.0 + randf() * (H - 240.0)), "hp": 3 if kind == "sq" else (2 if kind == "dia" else 1), "r": 24.0 if kind == "sq" else 20.0, "t": randf() * 3.0, "q": 0.0, "flash": 0.0, "st": "move", "hx": W - 180.0 - randf() * 260.0, "dead": false})
		elif en.is_empty():
			boss = {"boss": true, "k": "hex", "p": Vector2(W + 200.0, 360.0), "hp": 60, "max": 60, "r": 105.0, "t": 0.0, "q": 0.0, "flash": 0.0, "st": "move", "pat": 0, "dead": false}; m.snd("boom", -8.0)
	elif not boss["dead"]:
		var b := boss; b["t"] += d; b["q"] += d; b["flash"] -= d; b["p"].x = lerpf(b["p"].x, W - 200.0, d * 1.5)
		if b["st"] != "beam": b["p"].y = lerpf(b["p"].y, 360.0 + sin(b["t"] * 0.9) * 210.0, d * 2.5)
		if b["st"] == "move" and b["q"] > 1.7:
			b["q"] = 0.0; b["pat"] = (b["pat"] + 1) % 3; var a: float = (p + Vector2(0, -34) - b["p"]).angle()
			if b["pat"] == 0:
				for k in range(-3, 4): shoot(b["p"] - Vector2(60, 0), a + k * 0.17, 420.0)
			elif b["pat"] == 1:
				for k in 16: shoot(b["p"], k * TAU / 16.0 + b["t"], 300.0)
			else: b["st"] = "wind"
		elif b["st"] == "wind" and b["q"] > 0.95: b["st"] = "beam"; b["q"] = 0.0; m.snd("boom", -10.0); m.shake = 10.0
		elif b["st"] == "beam":
			if absf(p.y - 34.0 - b["p"].y) < 36.0 and p.x < b["p"].x and dash_t <= 0.0: hurt()
			if b["q"] > 0.55: b["st"] = "move"; b["q"] = 0.0
		if atk_hits(p, 1, b["p"] + Vector2(0, 34), b["r"]) and b.get("hid", -1) != atk_id: hit_e(b, 2); b["hid"] = atk_id
		if dash_t <= 0.0 and (b["p"] as Vector2).distance_to(p + Vector2(0, -34)) < b["r"] + 18.0: hurt()
	else:
		win_t += d
		if win_t > 2.2: m._finish(true)
	for i in range(en.size() - 1, -1, -1):
		var e: Dictionary = en[i]; e["t"] += d; e["q"] += d; e["flash"] -= d
		if e["k"] == "dart": e["p"].x -= 470.0 * d
		elif e["k"] == "dia": e["p"].x -= 240.0 * d; e["p"].y = clampf(e["p"].y + cos(e["t"] * 3.0) * 230.0 * d, 100.0, H - 60.0)
		else:
			e["p"].x = lerpf(e["p"].x, -200.0 if e["t"] > 9.0 else e["hx"], d * (0.6 if e["t"] > 9.0 else 1.6)); e["p"].y += sin(e["t"] * 1.5) * 40.0 * d
			if e["st"] == "move" and e["q"] > 1.9 and e["p"].x < W - 60.0: e["st"] = "wind"; e["q"] = 0.0
			elif e["st"] == "wind" and e["q"] > 0.5: e["st"] = "move"; e["q"] = 0.0; shoot(e["p"], (p + Vector2(0, -34) - e["p"]).angle()); m.snd("tick", -6.0)
		if atk_hits(p, 1, e["p"] + Vector2(0, 34), e["r"]) and e.get("hid", -1) != atk_id: hit_e(e, 2); e["hid"] = atk_id
		if not e["dead"] and dash_t <= 0.0 and (e["p"] as Vector2).distance_to(p + Vector2(0, -34)) < e["r"] + 20.0: hurt(); hit_e(e, 9)
		if e["dead"] or e["p"].x < -80.0: en.remove_at(i)
	for i in range(bolts.size() - 1, -1, -1):
		var b: Dictionary = bolts[i]; b["p"] += b["v"] * d; var gone: bool = b["p"].x < -40.0 or b["p"].x > W + 40.0 or b["p"].y < -40.0 or b["p"].y > H + 40.0
		if b["mine"]:
			var lst := en.duplicate()
			if not boss.is_empty() and not boss["dead"]: lst.append(boss)
			for e in lst:
				if not e["dead"] and (e["p"] as Vector2).distance_to(b["p"]) < e["r"] + 12.0: hit_e(e, 1); gone = true; break
		elif atk_t > 0.0 and absf(b["p"].x - p.x - 45.0) < 80.0 and absf(b["p"].y - (p.y - 40.0)) < 80.0: b["mine"] = true; b["v"] = Vector2(absf(b["v"].x) * 1.6 + 300.0, -b["v"].y); m.snd("hit", -4.0)
		elif dash_t <= 0.0 and (b["p"] as Vector2).distance_to(p + Vector2(0, -34)) < 20.0: hurt(); gone = true
		if gone: bolts.remove_at(i)
	info = "lift  L = ½·ρ·v²·S·C_L     level flight: lift = weight, thrust = drag     shot down %d" % kills

func _draw() -> void:
	for i in 26:
		var sp := 0.4 + (i % 5) * 0.3; var x := W - fmod(t * 900.0 * sp + i * 173.0, W + 300.0); var y := 90.0 + fmod(i * 97.0, 560.0)
		draw_line(Vector2(x, y), Vector2(x + 60.0 + sp * 120.0, y), Color(1, 1, 1, 0.05 + sp * 0.08), 1.0)
	for e in en:
		var col := Color(1, 0.85, 0.5) if e["flash"] > 0.0 else (Color(1, 0.3, 0.22) if e["st"] == "wind" else Color.WHITE)
		foe(e["k"], e["p"], e["r"], col)
	if not boss.is_empty() and not boss["dead"]:
		var b := boss
		if b["st"] == "wind": draw_dashed_line(Vector2(0, b["p"].y), b["p"], Color(GOLD, 0.3 + 0.6 * b["q"] / 0.95), 2.0, 12.0)
		if b["st"] == "beam": draw_line(Vector2(0, b["p"].y), b["p"], Color(1, 0.97, 0.76), 50.0 * (1.0 - b["q"] / 0.55) + 10.0)
		foe("hex", b["p"], b["r"] * 0.8, GOLD if b["flash"] > 0.0 else (Color(1, 0.4, 0.3) if b["hp"] < 20 else Color.WHITE))
		draw_rect(Rect2(430, 676, 420, 8), Color.WHITE, false, 1.5); draw_rect(Rect2(430, 676, 420.0 * maxf(0.0, b["hp"]) / b["max"], 8), GOLD)
	elif boss.is_empty():
		draw_line(Vector2(490, 36), Vector2(790, 36), Color(1, 1, 1, 0.4), 1.0); dot(Vector2(490 + 300.0 * clampf(t / BT, 0.0, 1.0), 36), 5.0)
	for b in bolts:
		if b["mine"]: draw_line(b["p"] - Vector2(18, 0), b["p"] + Vector2(8, 0), GOLD, 4.0, true)
		else: draw_circle(b["p"], 7.0, Color(1, 0.54, 0.44))
	skin.flying = true
	hero_at(p, hero_pose("dash"), rot)
