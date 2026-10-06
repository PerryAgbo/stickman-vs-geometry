extends Node2D
## The hero's body: Blender-rendered parts hung on a skeleton whose joints are blended every frame.

const PS := 1.0 / 4.8          # rendered pixels -> game units
const LEG := 24.0              # thigh and shin length
const ARM := 17.0              # upper and lower arm length
const TORSO := 28.0            # shoulder line to hip, as rendered
const GOLD := Color("ffd23a")

var tex: Texture2D
var pose := "idle"
var ph := 0.0
var swing := 0.0
var combo := 1
var tint := Color("3aa0ff")
var band := GOLD
var armed := true
var flying := false
var flash := 0.0
var shadow := true
var _j := {}
var _t := 0.0
var _poses := {}
var _atk := {}

static func J(hip: Vector2, neck: Vector2, head: Vector2, f0: Vector2, f1: Vector2, h0: Vector2, h1: Vector2, blade := NAN) -> Dictionary:
	return {"hip": hip, "neck": neck, "head": head, "f0": f0, "f1": f1, "h0": h0, "h1": h1, "blade": blade}

func _ready() -> void:
	# Upright poses. Hip sits at -46 so the legs stand nearly straight; shoulders at -74, head centre at -90.
	_poses = {
		"jump": J(Vector2(0, -50), Vector2(4, -79), Vector2(6, -93), Vector2(12, -22), Vector2(-10, -8), Vector2(-16, -82), Vector2(18, -80)),
		"fall": J(Vector2(0, -48), Vector2(-2, -77), Vector2(-4, -91), Vector2(-12, -4), Vector2(14, -12), Vector2(-24, -72), Vector2(24, -70)),
		"land": J(Vector2(0, -36), Vector2(5, -64), Vector2(8, -78), Vector2(-16, 0), Vector2(16, 0), Vector2(-14, -40), Vector2(18, -42)),
		"dash": J(Vector2(-2, -42), Vector2(18, -64), Vector2(30, -72), Vector2(-28, -10), Vector2(-8, -2), Vector2(40, -54), Vector2(-8, -50)),
		"surf": J(Vector2(-2, -42), Vector2(5, -70), Vector2(9, -84), Vector2(-16, 0), Vector2(16, 0), Vector2(-26, -62), Vector2(28, -68)),
		"throw": J(Vector2(1, -46), Vector2(5, -75), Vector2(8, -89), Vector2(-15, 0), Vector2(14, 0), Vector2(32, -78), Vector2(-12, -54)),
		"hurt": J(Vector2(-3, -45), Vector2(-10, -72), Vector2(-16, -84), Vector2(-6, 0), Vector2(14, -4), Vector2(-24, -66), Vector2(6, -76)),
	}
	# three-hit combo: wind-up, strike with a stepping lunge, held follow-through
	_atk = {
		1: [[0.22, J(Vector2(-4, -45), Vector2(-3, -74), Vector2(0, -88), Vector2(-15, 0), Vector2(15, 0), Vector2(-14, -70), Vector2(6, -64), -2.6)],
			[0.5, J(Vector2(7, -43), Vector2(16, -70), Vector2(21, -83), Vector2(-18, 0), Vector2(26, 0), Vector2(36, -60), Vector2(2, -56), 0.15)],
			[0.78, J(Vector2(8, -43), Vector2(16, -70), Vector2(20, -83), Vector2(-18, 0), Vector2(26, 0), Vector2(28, -46), Vector2(0, -56), 0.95)]],
		2: [[0.22, J(Vector2(-3, -40), Vector2(1, -68), Vector2(4, -82), Vector2(-16, 0), Vector2(14, 0), Vector2(8, -34), Vector2(4, -60), 1.9)],
			[0.5, J(Vector2(5, -46), Vector2(12, -74), Vector2(17, -88), Vector2(-16, 0), Vector2(22, 0), Vector2(30, -80), Vector2(0, -58), -0.9)],
			[0.78, J(Vector2(5, -47), Vector2(11, -75), Vector2(15, -89), Vector2(-16, 0), Vector2(22, 0), Vector2(18, -96), Vector2(-2, -60), -1.7)]],
		3: [[0.3, J(Vector2(-3, -48), Vector2(-1, -77), Vector2(1, -91), Vector2(-12, 0), Vector2(12, -7), Vector2(-4, -104), Vector2(-8, -98), -1.95)],
			[0.52, J(Vector2(8, -36), Vector2(20, -58), Vector2(27, -70), Vector2(-22, 0), Vector2(28, 0), Vector2(42, -42), Vector2(36, -40), 0.45)],
			[0.82, J(Vector2(8, -35), Vector2(20, -57), Vector2(27, -69), Vector2(-22, 0), Vector2(28, 0), Vector2(40, -34), Vector2(35, -34), 0.7)]],
	}

func _stance(t: float) -> Dictionary:
	# fighting stance: feet apart, weight centred, spine upright, fists up by the chin
	var s := sin(t * 2.4)
	return J(Vector2(1, -45 + s * 1.0), Vector2(3, -73 + s * 1.4), Vector2(4, -87 + s * 1.6), Vector2(-14, 0), Vector2(16, 0),
		Vector2(21, -66 + sin(t * 2.4 + 1.0) * 1.4), Vector2(9, -70 + s * 1.4), -0.55)

func _run(p: float) -> Dictionary:
	# forward lean, legs reaching, arms pumping opposite the legs
	var b := absf(sin(p)) * 3.0
	return J(Vector2(2, -46 + b), Vector2(9, -74 + b), Vector2(14, -87 + b),
		Vector2(sin(p) * 26, -maxf(0, cos(p)) * 20), Vector2(sin(p + PI) * 26, -maxf(0, cos(p + PI)) * 20),
		Vector2(8 + sin(p + PI) * 19, -58 - maxf(0, sin(p + PI)) * 9), Vector2(8 + sin(p) * 19, -58 - maxf(0, sin(p)) * 9))

func _lerpj(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var o := {}
	for key in ["hip", "neck", "head", "f0", "f1", "h0", "h1"]:
		o[key] = (a[key] as Vector2).lerp(b[key], k)
	o["blade"] = b["blade"] if is_nan(a["blade"]) or is_nan(b["blade"]) else lerpf(a["blade"], b["blade"], k)
	return o

func _target() -> Dictionary:
	if pose == "run":
		return _run(ph)
	if pose == "slash":
		var s0 := _stance(0.0)
		var ks: Array = [[0.0, s0]]
		ks.append_array(_atk.get(combo, _atk[1]))
		ks.append([1.0, s0])
		var i := 0
		while i < ks.size() - 2 and swing > ks[i + 1][0]:
			i += 1
		var u := clampf((swing - ks[i][0]) / (ks[i + 1][0] - ks[i][0]), 0.0, 1.0)
		return _lerpj(ks[i][1], ks[i + 1][1], u * u * (3.0 - 2.0 * u))
	if pose == "idle":
		return _stance(_t)
	return _poses.get(pose, _poses["fall"])

func _process(delta: float) -> void:
	_t += delta
	flash = maxf(0.0, flash - delta)
	var tg := _target()
	if _j.is_empty():
		_j = tg
	else:   # ease from the last pose into this one, so actions blend instead of snapping
		_j = _lerpj(_j, tg, 1.0 - exp(-delta * (30.0 if pose in ["slash", "run", "dash"] else 15.0)))
	queue_redraw()

func _ik(a: Vector2, b: Vector2, l: float, dir: float) -> Vector2:
	var d := b - a
	var dist := minf(d.length(), 2.0 * l - 0.01)
	if dist < 0.01:
		dist = 0.01
	var h := sqrt(l * l - dist * dist / 4.0)
	return a + d / 2.0 + Vector2(-d.y, d.x) / dist * h * dir

func _part(i: int, a: Vector2, b: Vector2, col: Color, sy := 1.0) -> void:
	draw_set_transform(a, (b - a).angle() - PI / 2.0, Vector2(PS, PS * sy))
	draw_texture_rect_region(tex, Rect2(-96, -40, 192, 192), Rect2(i * 192, 0, 192, 192), col)

func _foot(f: Vector2, col: Color) -> void:
	draw_set_transform(f + Vector2(0, -2.8), 0.0, Vector2(PS, PS))
	draw_texture_rect_region(tex, Rect2(-60, -96, 192, 192), Rect2(384, 0, 192, 192), col)

func _draw() -> void:
	if _j.is_empty() or tex == null:
		return
	var hip: Vector2 = _j["hip"]
	var neck: Vector2 = _j["neck"]
	var head: Vector2 = _j["head"]
	var f0: Vector2 = _j["f0"]
	var f1: Vector2 = _j["f1"]
	var h0: Vector2 = _j["h0"]
	var h1: Vector2 = _j["h1"]
	var sh := neck + Vector2(0, 4)
	var col := tint.lerp(Color.WHITE, clampf(flash * 6.0, 0.0, 1.0))
	var far := col.darkened(0.38)
	var k0 := _ik(hip, f0, LEG, -1.0)
	var k1 := _ik(hip, f1, LEG, -1.0)
	var e0 := _ik(sh, h0, ARM, 1.0)
	var e1 := _ik(sh, h1, ARM, 1.0)
	var blade: float = _j["blade"]
	var show_blade := armed and not is_nan(blade) and (pose == "slash" or pose == "idle")
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if shadow:   # grounds the figure
		draw_set_transform(Vector2(0, 1), 0.0, Vector2(1, 0.28))
		draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.45))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if flying:   # wings of light
		var fl := sin(_t * 22.0) * 10.0
		for q in 2:
			draw_colored_polygon(PackedVector2Array([Vector2(-4, -72), Vector2(-(58 + q * 14), -118 + fl - q * 18), Vector2(-(40 + q * 10), -84 + fl * 0.4), Vector2(-(66 + q * 10), -66 + fl * 0.3 + q * 14)]), Color(1, 0.85, 0.3, 0.28))
	if armed and not show_blade:   # sheathed on the back
		draw_line(neck + Vector2(-12, -10), hip + Vector2(8, 10), Color("e8eef5"), 3.0, true)
		draw_line(neck + Vector2(-12, -10), neck + Vector2(-8, -3), GOLD, 4.0, true)
	_part(3, sh, e1, far); _part(4, e1, h1, far)
	_part(0, hip, k1, far); _part(1, k1, f1, far); _foot(f1, far)
	_part(5, sh, hip, col, hip.distance_to(sh) / TORSO)
	draw_set_transform(head, 0.0, Vector2(PS, PS))
	draw_texture_rect_region(tex, Rect2(-96, -96, 192, 192), Rect2(1152, 0, 192, 192), col)
	_part(0, hip, k0, col); _part(1, k0, f0, col); _foot(f0, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if show_blade:
		var dir := Vector2.from_angle(blade)
		draw_line(h0, h0 + dir * 52.0, Color(1, 1, 1, 0.35), 8.0, true)
		draw_line(h0, h0 + dir * 52.0, Color("f4f8ff"), 3.6, true)
		draw_line(h0 + dir.orthogonal() * 6.0, h0 - dir.orthogonal() * 6.0, GOLD, 4.5, true)
	_part(3, sh, e0, col); _part(4, e0, h0, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# headband, glowing eyes, flowing tails
	draw_line(head + Vector2(-11, -3), head + Vector2(11.5, -5), band, 4.2, true)
	for q in [[3.0, 0.5], [8.6, -0.5]]:   # narrowed eyes
		var c := head + Vector2(q[0], q[1])
		draw_line(c + Vector2(-2.6, -1.4), c + Vector2(2.6, 0.6), Color.WHITE, 2.2, true)
	var flow := 1.0 if pose in ["run", "dash", "jump", "fall", "slash"] else 0.35
	for q in 2:
		var pts := PackedVector2Array([head + Vector2(-10.5, -4 + q * 3)])
		for k in range(1, 6):
			pts.append(head + Vector2(-10.5 - k * 5.2 * flow - (1.0 - flow) * k * 1.2, -4 + q * 3 + sin(_t * 10.0 + ph + k * 0.9 + q * 1.7) * (1.2 + k * 0.7) * flow + k * k * (1.6 - flow) * 0.45))
		draw_polyline(pts, band, 2.2, true)
	# blade trail while the sword is actually travelling
	if pose == "slash" and swing > 0.22 and swing < 0.82:
		var u := (swing - 0.22) / 0.6
		var a0 := 1.6 if combo == 2 else -2.4
		var a1 := lerpf(a0, -1.5 if combo == 2 else 0.9, u)
		var r := 96.0 if combo == 3 else 76.0
		for k in 3:
			draw_arc(Vector2(8, -68), r - k * 9.0, minf(a0, a1), maxf(a0, a1), 20, Color(1, 0.84, 0.25, 0.75 - k * 0.22), 6.0 - k * 1.6, true)
