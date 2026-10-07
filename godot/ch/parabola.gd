extends "res://chapter.gd"
## Projectile motion: aim and launch from island to island.
const GR := 980.0
var isl := [[0.0, 500.0, 260.0], [760.0, 500.0, 200.0], [1650.0, 380.0, 190.0], [2500.0, 560.0, 180.0], [3500.0, 300.0, 180.0], [4350.0, 520.0, 170.0], [5500.0, 420.0, 280.0]]
var walls := [[2150.0, 210.0], [3960.0, 110.0]]
var th := 45.0
var pw := 700.0
var cur := 0
var p := Vector2(130, 500)
var flying := false
var fp := Vector2.ZERO
var fv := Vector2.ZERO
var trail := PackedVector2Array()
var phis: Array = []

func begin() -> void:
	title = "VII · THE PARABOLA"; btn = [["jump", "LAUNCH"]]; max_hp = 3; hp = 3
	for i in isl.size() - 1:
		var a = isl[i]; var b = isl[i + 1]
		phis.append({"p": Vector2((a[0] + a[2] / 2.0 + b[0] + b[2] / 2.0) / 2.0, minf(a[1], b[1]) - (b[0] - a[0]) * 0.3), "got": false})
	cam_p = Vector2(500, 330); cam_z = 0.8

func tick(d: float) -> void:
	var nxt = isl[mini(cur + 1, isl.size() - 1)]
	var tx: float = nxt[0] + nxt[2] / 2.0
	if not flying:
		th = clampf(th - ay() * 40.0 * d, 5.0, 88.0)
		pw = clampf(pw + ax() * 320.0 * d, 200.0, 1500.0)
		var v := pw / 100.0
		info = "θ = %d°    v₀ = %.1f m/s    R = v₀²·sin2θ/g = %.1f m" % [int(th), v, v * v * sin(2.0 * deg_to_rad(th)) / 9.8]
		if act():
			var r := deg_to_rad(th)
			flying = true; fp = p; fv = Vector2(cos(r), -sin(r)) * pw; trail = PackedVector2Array(); m.snd("jump")
	else:
		for k in 4:
			var h := d / 4.0
			var o := fp
			fv.y += GR * h; fp += fv * h
			for w in walls:
				if (o.x - w[0]) * (fp.x - w[0]) <= 0.0 and fp.y > w[1]:
					fp.x = o.x; fv.x *= -0.25; m.shake = 8.0; m.snd("hit")
			if fv.y > 0.0:
				for i in isl.size():
					var a = isl[i]
					if o.y <= a[1] and fp.y >= a[1] and fp.x >= a[0] and fp.x <= a[0] + a[2]:
						p = Vector2(fp.x, a[1]); cur = i; flying = false; m.shake = 6.0; m.snd("tick"); hap(20)
						m.fx.burst(p, 12, Color.WHITE, 260.0)
						if i == isl.size() - 1: m._finish(true)
						break
			if not flying: break
		if flying:
			trail.append(fp)
			if fp.y > 1600.0:
				hurt(); flying = false; var a = isl[cur]; p = Vector2(a[0] + a[2] / 2.0, a[1])
	var q := fp if flying else p
	for f in phis:
		if not f["got"] and q.distance_to(f["p"] + Vector2(0, 34)) < 60.0:
			f["got"] = true; score(f["p"]); m.snd("phi")
	cam_z = lerpf(cam_z, clampf(1050.0 / (absf(tx - p.x) + 350.0), 0.5, 1.0), d * 3.0)
	var target := Vector2(fp.x + 150.0, minf(fp.y, p.y) - 60.0) if flying else Vector2((p.x + tx) / 2.0, minf(p.y, nxt[1]) - 150.0)
	cam_p = cam_p.lerp(target, d * 4.0)

func _draw() -> void:
	world_xf()
	for gx in range(int((cam_p.x - 1400.0) / 100.0) * 100, int(cam_p.x + 1400.0), 100):
		draw_line(Vector2(gx, cam_p.y - 900), Vector2(gx, cam_p.y + 900), Color(1, 1, 1, 0.07))
	for gy in range(int((cam_p.y - 900.0) / 100.0) * 100, int(cam_p.y + 900.0), 100):
		draw_line(Vector2(cam_p.x - 1400, gy), Vector2(cam_p.x + 1400, gy), Color(1, 1, 1, 0.07))
	for i in isl.size():
		var a = isl[i]
		draw_line(Vector2(a[0], a[1]), Vector2(a[0] + a[2], a[1]), GOLD if i == isl.size() - 1 else Color.WHITE, 3.0, true)
		dot(Vector2(a[0], a[1])); dot(Vector2(a[0] + a[2], a[1]))
		draw_polyline(PackedVector2Array([Vector2(a[0], a[1]), Vector2(a[0] + a[2] / 2.0, a[1] + 1200), Vector2(a[0] + a[2], a[1])]), Color(1, 1, 1, 0.2), 1.0)
	for w in walls:
		draw_line(Vector2(w[0], w[1]), Vector2(w[0], w[1] + 1500), Color.WHITE, 3.0); dot(Vector2(w[0], w[1]), 6.0)
	for f in phis:
		if not f["got"]: phi(f["p"], 26.0)
	var L = isl[isl.size() - 1]
	phi(Vector2(L[0] + L[2] / 2.0, L[1] - 90.0 + sin(t * 2.0) * 6.0), 56.0)
	if trail.size() > 1: draw_polyline(trail, Color(m.HEROES[m.hero_i], 0.5), 2.0)
	if not flying:
		var r := deg_to_rad(th); var vx := cos(r) * pw; var vy := -sin(r) * pw
		for i in range(1, 15):
			var tt := i * 0.06
			draw_circle(p + Vector2(vx * tt, vy * tt + 0.5 * GR * tt * tt), 4.0, Color(1, 0.82, 0.23, 1.0 - i / 16.0))
		draw_line(p, p + Vector2(110, 0), Color.WHITE, 1.5); draw_arc(p, 80.0, -r, 0.0, 24, Color.WHITE, 1.5)
		var al := pw * 0.14
		draw_line(p, p + Vector2(cos(r), -sin(r)) * al, GOLD, 3.0); dot(p + Vector2(cos(r), -sin(r)) * al)
		txt("%d°" % int(th), p + Vector2(100, -20), 18)
		var nxt = isl[mini(cur + 1, isl.size() - 1)]; var tx: float = nxt[0] + nxt[2] / 2.0
		draw_dashed_line(p + Vector2(0, 40), Vector2(tx, p.y + 40), Color(1, 1, 1, 0.45), 1.0, 8.0)
		txt("Δx = %.1f m" % ((tx - p.x) / 100.0), Vector2((p.x + tx) / 2.0, p.y + 70), 18, Color.WHITE, true)
	screen_xf()
	hero_at(fp if flying else p, "surf" if flying else "throw", (atan2(fv.y, fv.x) * 0.5) if flying else 0.0)
	txt("y = x·tanθ − g·x² / (2·v₀²·cos²θ)", Vector2(640, 46), 17, Color(1, 1, 1, 0.7), true)
