extends "res://chapter.gd"
## Electric field: flip your charge to be pushed to the other plate.
const TOP := 130.0
const BOT := 600.0
const EF := 2200.0
var obs: Array = []
var phis: Array = []
var endx := 0.0
var p := Vector2(0, BOT - 30)
var vy := 0.0
var q := 1
var cp := 0.0
var flip_t := 0.0

func begin() -> void:
	title = "VIII · THE CHARGE"; max_hp = 3; hp = 3
	var rng := RandomNumberGenerator.new(); rng.seed = 41
	var x := 1000.0
	while x < 14500.0:
		var k := rng.randf(); var h := 130.0 + rng.randf() * 130.0
		if k < 0.4: obs.append(Rect2(x, BOT - h, 60, h))
		elif k < 0.8: obs.append(Rect2(x, TOP, 60, h))
		else: obs.append(Rect2(x, (TOP + BOT) / 2.0 - 70.0 + (rng.randf() - 0.5) * 60.0, 70, 140))
		if rng.randf() < 0.6: phis.append({"p": Vector2(x + 220.0, TOP + 50.0 if rng.randf() < 0.5 else BOT - 50.0), "got": false})
		x += 400.0 + rng.randf() * 160.0
	endx = x + 300.0
	cam_p = Vector2(530, 360)

func tick(d: float) -> void:
	flip_t -= d
	if act():
		q = -q; flip_t = 0.25; m.snd("tick"); hap(15); m.fx.burst(p, 8, GOLD if q > 0 else BLUE, 300.0, 0.0)
	var v := 340.0 + clampf(p.x / endx, 0.0, 1.0) * 100.0
	p.x += v * d; vy += q * EF * d; p.y += vy * d
	if p.y > BOT - 30.0: p.y = BOT - 30.0; vy = 0.0
	if p.y < TOP + 30.0: p.y = TOP + 30.0; vy = 0.0
	for o in obs:
		if Rect2(o.position - Vector2(9, 27), o.size + Vector2(18, 54)).has_point(p):
			if hurt():
				p = Vector2(cp, BOT - 30.0); vy = 0.0; q = 1
			break
	for f in phis:
		if not f["got"] and p.distance_to(f["p"]) < 50.0:
			f["got"] = true; score(f["p"]); m.snd("phi")
	if p.x > cp + 3500.0:
		var clear := true
		for o in obs:
			if o.position.x > p.x and o.position.x - p.x < 250.0: clear = false
		if clear: cp = p.x
	if p.x > endx: m._finish(true)
	cam_p.x = lerpf(cam_p.x, p.x + 330.0, d * 8.0)
	info = "q = %s e     F = q·E = %d N     v_y = %.2f m/s" % ["+1" if q > 0 else "−1", q * 22, vy / 100.0]

func _draw() -> void:
	world_xf()
	var x0 := int((cam_p.x - 700.0) / 80.0) * 80
	for gx in range(x0, int(cam_p.x + 700.0), 80):
		txt("+", Vector2(gx - 5, TOP - 14), 20, GOLD); txt("−", Vector2(gx - 6, BOT + 32), 22, BLUE)
		draw_line(Vector2(gx + 40, TOP + 12), Vector2(gx + 40, BOT - 12), Color(1, 1, 1, 0.09))
		var ay0 := TOP + 20.0 + fmod(t * 140.0 + gx, 60.0)
		var yy := ay0
		while yy < BOT - 30.0:
			draw_polyline(PackedVector2Array([Vector2(gx + 34, yy), Vector2(gx + 40, yy + 9), Vector2(gx + 46, yy)]), Color(1, 1, 1, 0.25), 1.0)
			yy += 150.0
	draw_line(Vector2(cam_p.x - 700, TOP), Vector2(cam_p.x + 700, TOP), GOLD, 3.0)
	draw_line(Vector2(cam_p.x - 700, BOT), Vector2(cam_p.x + 700, BOT), BLUE, 3.0)
	for o in obs:
		if o.position.x < cam_p.x - 760.0 or o.position.x > cam_p.x + 760.0: continue
		draw_rect(o, Color(1, 1, 1, 0.06)); draw_rect(o, Color.WHITE, false, 2.0)
		for c in [o.position, o.position + Vector2(o.size.x, 0), o.position + o.size, o.position + Vector2(0, o.size.y)]: dot(c, 4.0)
	for f in phis:
		if not f["got"]: phi(f["p"], 24.0)
	phi(Vector2(endx + 80.0, (TOP + BOT) / 2.0), 70.0)
	var col := GOLD if q > 0 else BLUE
	draw_arc(p, 44.0 + maxf(0.0, flip_t) * 60.0, 0, TAU, 32, col, 2.0, true)
	txt("+" if q > 0 else "−", p + Vector2(-66, 8), 26, col)
	screen_xf()
	hero_at(p + Vector2(0, 30.0 * q), "surf")
	skin.scale.y = cam_z * q
