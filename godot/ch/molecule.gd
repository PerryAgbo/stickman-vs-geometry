extends "res://chapter.gd"
## Chemical bonding: catch only the atoms the molecule needs.
const EL := {"H": [Color.WHITE, 15.0, 1.0], "O": [Color("ff5a4a"), 20.0, 16.0], "C": [Color("9aa0a6"), 20.0, 12.0], "N": [Color("6f9bff"), 20.0, 14.0], "Na": [Color("b58cff"), 22.0, 23.0], "Cl": [Color("6fe08a"), 22.0, 35.5]}
const ALL := ["H", "O", "C", "N", "Na", "Cl"]
const GY := 600.0
const X0 := 60.0
var X1 := 1220.0
var MOL := [{"n": "H₂O", "name": "water", "geo": [["O", 0, -8], ["H", -36, 22], ["H", 36, 22]], "b": [[0, 1], [0, 2]]},
	{"n": "CO₂", "name": "carbon dioxide", "geo": [["C", 0, 0], ["O", -58, 0], ["O", 58, 0]], "b": [[0, 1], [0, 2]]},
	{"n": "NH₃", "name": "ammonia", "geo": [["N", 0, -12], ["H", -40, 20], ["H", 0, 34], ["H", 40, 20]], "b": [[0, 1], [0, 2], [0, 3]]},
	{"n": "CH₄", "name": "methane", "geo": [["C", 0, 0], ["H", -38, -30], ["H", 38, -30], ["H", -38, 30], ["H", 38, 30]], "b": [[0, 1], [0, 2], [0, 3], [0, 4]]},
	{"n": "NaCl", "name": "table salt", "geo": [["Na", -30, 0], ["Cl", 30, 0]], "b": [[0, 1]]},
	{"n": "C₂H₆", "name": "ethane", "geo": [["C", -28, 0], ["C", 28, 0], ["H", -62, -30], ["H", -70, 14], ["H", -36, 40], ["H", 62, -30], ["H", 70, 14], ["H", 36, 40]], "b": [[0, 1], [0, 2], [0, 3], [0, 4], [1, 5], [1, 6], [1, 7]]}]
var mi := 0
var have := {}
var atoms: Array = []
var px := 640.0
var py := GY
var vx := 0.0
var vy := 0.0
var face := 1
var ph := 0.0
var done_t := 0.0

func begin() -> void:
	title = "XV · THE MOLECULE"; btn = [["jump", "JUMP"]]; max_hp = 5; hp = 5; begin_mol()

func need() -> Dictionary:
	var n := {}
	for g in MOL[mi]["geo"]: n[g[0]] = n.get(g[0], 0) + 1
	return n

func left(el: String) -> int:
	return need().get(el, 0) - have.get(el, 0)

func spawn() -> void:
	var nd := need().keys().filter(func(e): return left(e) > 0)
	var on := atoms.filter(func(a): return left(a["el"]) > 0).size()
	var el: String = nd.pick_random() if nd.size() > 0 and on < 2 else ALL.pick_random()
	var x := X0 + 40.0 + randf() * (X1 - X0 - 80.0)
	while absf(x - px) < 170.0: x = X0 + 40.0 + randf() * (X1 - X0 - 80.0)
	var a := randf() * TAU; var sp := 90.0 + randf() * 70.0
	atoms.append({"el": el, "p": Vector2(x, 400.0 + randf() * 40.0), "v": Vector2(cos(a) * sp, sin(a) * sp * 0.8), "born": 0.0})

func begin_mol() -> void:
	have = {}; atoms = []; done_t = 0.0
	for i in 7: spawn()

func tick(d: float) -> void:
	var mol: Dictionary = MOL[mi]
	X1 = minf(1220.0, safe_x() - 10.0)   # the arena ends where the jump button begins
	var a := ax()
	vx = move_toward(vx, a * 390.0, 3400.0 * d); px = clampf(px + vx * d, X0 + 10.0, X1 - 10.0)
	if a != 0.0: face = 1 if a > 0.0 else -1
	if act() and py >= GY: vy = -820.0; m.snd("jump")
	vy += 2300.0 * d; py = minf(py + vy * d, GY)
	if py >= GY: vy = 0.0
	ph += absf(vx) * d * 0.036
	var mass := 0.0
	for g in mol["geo"]: mass += EL[g[0]][2]
	info = "molecule %d / %d    %s  (%s)    bonds: H 1 · O 2 · N 3 · C 4    M = %.1f g/mol" % [mi + 1, MOL.size(), mol["n"], mol["name"], mass]
	if done_t > 0.0:
		done_t += d
		if done_t > 1.6:
			if mi == MOL.size() - 1: m._finish(true); return
			mi += 1; begin_mol()
		return
	for i in range(atoms.size() - 1, -1, -1):
		var at: Dictionary = atoms[i]; var r: float = EL[at["el"]][1]
		at["born"] += d; var p: Vector2 = at["p"] + at["v"] * d; var v: Vector2 = at["v"]
		if p.x < X0 + r: p.x = X0 + r; v.x = absf(v.x)
		if p.x > X1 - r: p.x = X1 - r; v.x = -absf(v.x)
		if p.y < 385.0: p.y = 385.0; v.y = absf(v.y)
		if p.y > GY - r - 2.0: p.y = GY - r - 2.0; v.y = -absf(v.y)
		at["p"] = p; at["v"] = v
		if at["born"] > 0.8 and p.distance_to(Vector2(px, py - 50.0)) < r + 26.0:
			atoms.remove_at(i)
			if left(at["el"]) > 0:
				have[at["el"]] = have.get(at["el"], 0) + 1; score(p); m.snd("phi"); m.fx.burst(p, 10, EL[at["el"]][0], 320.0, 0.0)
			else:
				m.fx.burst(p, 14, RED); hurt()
			spawn()
	var ok := true
	for e in need().keys():
		if left(e) > 0: ok = false
	if ok: done_t = 0.001; m.snd("clear"); m.fx.burst(Vector2(640, 190), 40, GOLD, 400.0, 0.0)

func atom(p: Vector2, el: String, s := 1.0, ghost := false) -> void:
	var c: Color = EL[el][0]; var r: float = EL[el][1] * s
	if ghost: draw_arc(p, r, 0, TAU, 24, Color(c, 0.3), 1.5, true)
	else: draw_circle(p, r, Color(0.04, 0.04, 0.05)); draw_arc(p, r, 0, TAU, 24, c, 3.0 * s, true)
	txt(el, p + Vector2(-5.0 * s * el.length(), 5.0 * s), int(16 * s), Color(1, 1, 1, 0.4) if ghost else c)

func _draw() -> void:
	var mol: Dictionary = MOL[mi]
	draw_line(Vector2(X0, GY), Vector2(X1, GY), Color.WHITE, 2.0); draw_rect(Rect2(X0, 370, X1 - X0, GY - 370), Color(1, 1, 1, 0.3), false, 1.0)
	draw_rect(Rect2(310, 92, 660, 200), Color(0, 0, 0, 0.45)); draw_rect(Rect2(310, 92, 660, 200), Color(1, 1, 1, 0.3), false, 1.0)
	txt("BUILD", Vector2(350, 126), 12, GOLD); txt(mol["n"], Vector2(350, 182), 46); txt(mol["name"], Vector2(350, 212), 15, Color(1, 1, 1, 0.7))
	var sx := 350.0
	for el in need().keys():
		for i in need()[el]:
			atom(Vector2(sx + 12.0, 256.0), el, 0.6, i >= have.get(el, 0)); sx += 30.0
		sx += 14.0
	var cnt := {}; var got: Array = []
	for g in mol["geo"]:
		cnt[g[0]] = cnt.get(g[0], 0) + 1; got.append(cnt[g[0]] <= have.get(g[0], 0))
	var c0 := Vector2(810, 190)
	for b in mol["b"]:
		var A = mol["geo"][b[0]]; var B = mol["geo"][b[1]]; var on: bool = got[b[0]] and got[b[1]]
		draw_line(c0 + Vector2(A[1], A[2]), c0 + Vector2(B[1], B[2]), Color.WHITE if on else Color(1, 1, 1, 0.2), 3.0 if on else 1.5)
	for i in mol["geo"].size():
		var g = mol["geo"][i]; atom(c0 + Vector2(g[1], g[2]), g[0], 1.0, not got[i])
	for at in atoms:
		atom(at["p"], at["el"])
	hero_at(Vector2(px, py), "jump" if py < GY else ("run" if absf(vx) > 30.0 else "idle"), 0.0, face)
	skin.ph = ph
	if done_t > 0.0: txt(mol["n"] + "  ✓", Vector2(640, 345), 30, GOLD, true)
