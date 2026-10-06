extends "res://chapter.gd"
## Gravitation: thrust through nine rings around three masses.
var pl := [[Vector2(900, 360), 90.0, 9e6], [Vector2(2100, 200), 120.0, 1.6e7], [Vector2(3300, 500), 70.0, 7e6]]
var rings := [Vector2(520, 360), Vector2(900, 110), Vector2(1180, 400), Vector2(1560, 300), Vector2(2100, -130), Vector2(2440, 240), Vector2(2860, 440), Vector2(3300, 270), Vector2(3720, 500)]
var p := Vector2(200, 360)
var v := Vector2.ZERO
var ri := 0

func begin() -> void:
	title = "IX · THE ORBIT"; max_hp = 3; hp = 3; cam_z = 0.85; cam_p = Vector2(300, 360)

func grav(x: Vector2) -> Vector2:
	var a := Vector2.ZERO
	for b in pl:
		var dx: Vector2 = b[0] - x
		var d: float = maxf(dx.length(), b[1] * 0.8)
		a += dx / d * minf(b[2] / (d * d), 900.0)
	return a

func respawn() -> void:
	p = rings[ri - 1] if ri > 0 else Vector2(200, 360); v = Vector2.ZERO

func tick(d: float) -> void:
	var th := Vector2(ax(), ay())
	v += (grav(p) + th * 420.0) * d; p += v * d
	if th != Vector2.ZERO and randf() < d * 50.0: m.fx.burst(p + Vector2(0, -20), 1, GOLD, 200.0, 0.0)
	for b in pl:
		if (b[0] as Vector2).distance_to(p + Vector2(0, -25)) < b[1] + 16.0:
			if hurt(): respawn()
			return
	var r: Vector2 = rings[ri]
	if r.distance_to(p + Vector2(0, -25)) < 52.0:
		ri += 1; score(r); m.snd("phi"); hap(20)
		if ri >= rings.size(): m._finish(true); return
	elif r.distance_to(p) > 2300.0:
		if hurt(): respawn()
	cam_p = cam_p.lerp(p + v * 0.35 + Vector2(0, -20), d * 4.0)
	var bd := 1e9; var bb = pl[0]
	for b in pl:
		var dd: float = (b[0] as Vector2).distance_to(p)
		if dd < bd: bd = dd; bb = b
	info = "v = %.2f m/s    r = %.2f m    g = GM/r² = %.2f m/s²    orbit speed √(GM/r) = %.2f m/s" % [v.length() / 100.0, bd / 100.0, bb[2] / (bd * bd) / 100.0, sqrt(bb[2] / bd) / 100.0]

func _draw() -> void:
	world_xf()
	for b in pl:
		var c: Vector2 = b[0]; var r: float = b[1]
		for k in range(1, 6): draw_arc(c, r + k * k * 22.0, 0, TAU, 64, Color(1, 1, 1, 0.16 / k + 0.02), 1.0, true)
		draw_circle(c, r, Color(0.12, 0.1, 0.05)); draw_arc(c, r, 0, TAU, 48, Color.WHITE, 2.0, true)
		foe("hex", c, r * 0.45, Color(1, 0.82, 0.23, 0.8))
	var path := PackedVector2Array([Vector2(200, 360)]); path.append_array(PackedVector2Array(rings))
	for i in path.size() - 1: draw_dashed_line(path[i], path[i + 1], Color(1, 1, 1, 0.2), 1.0, 8.0)
	for i in rings.size():
		if i < ri: continue
		var curr := i == ri
		draw_arc(rings[i], 46.0 + (sin(t * 6.0) * 3.0 if curr else 0.0), 0, TAU, 40, GOLD if curr else Color(1, 1, 1, 0.45), 3.0 if curr else 1.5, true)
		if i == rings.size() - 1: phi(rings[i], 36.0, GOLD, 0.3)
		else: txt(str(i + 1), rings[i] + Vector2(-5, 6), 18, GOLD if curr else Color(1, 1, 1, 0.5))
	var x := p; var vv := v    # predicted free-fall path
	for i in 60:
		vv += grav(x) * 0.04; x += vv * 0.04
		if i % 2 == 1: draw_circle(x + Vector2(0, -25), 2.5, Color(1, 1, 1, 0.55 * (1.0 - i / 60.0)))
	screen_xf()
	hero_at(p, "surf", clampf(v.x / 900.0, -0.5, 0.5))
	var r: Vector2 = rings[mini(ri, rings.size() - 1)]; var sp := scr(r)
	if sp.x < 20.0 or sp.x > 1260.0 or sp.y < 20.0 or sp.y > 700.0:
		var a := (sp - Vector2(640, 360)).angle(); var c := Vector2(640, 360) + Vector2.from_angle(a) * 300.0
		draw_colored_polygon(PackedVector2Array([c + Vector2.from_angle(a) * 16.0, c + Vector2.from_angle(a + 2.4) * 12.0, c + Vector2.from_angle(a - 2.4) * 12.0]), GOLD)
	txt("ring %d / %d" % [mini(ri + 1, rings.size()), rings.size()], Vector2(640, 46), 15, Color(1, 1, 1, 0.75), true)
