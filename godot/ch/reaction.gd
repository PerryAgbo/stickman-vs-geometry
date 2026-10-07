extends "res://chapter.gd"
## Conservation of mass: balance six chemical equations.
const EL := {"H": Color.WHITE, "O": Color("ff5a4a"), "C": Color("9aa0a6"), "N": Color("6f9bff"), "Cl": Color("6fe08a"), "Fe": Color("d98a4a"), "Al": Color("c8d0d8")}
var EQ := [{"L": [["H₂", {"H": 2}], ["O₂", {"O": 2}]], "R": [["H₂O", {"H": 2, "O": 1}]], "tip": "hydrogen burns in oxygen to make water"},
	{"L": [["N₂", {"N": 2}], ["H₂", {"H": 2}]], "R": [["NH₃", {"N": 1, "H": 3}]], "tip": "the Haber process makes ammonia for fertiliser"},
	{"L": [["CH₄", {"C": 1, "H": 4}], ["O₂", {"O": 2}]], "R": [["CO₂", {"C": 1, "O": 2}], ["H₂O", {"H": 2, "O": 1}]], "tip": "burning methane, the main part of natural gas"},
	{"L": [["Fe", {"Fe": 1}], ["O₂", {"O": 2}]], "R": [["Fe₂O₃", {"Fe": 2, "O": 3}]], "tip": "iron rusting"},
	{"L": [["C₃H₈", {"C": 3, "H": 8}], ["O₂", {"O": 2}]], "R": [["CO₂", {"C": 1, "O": 2}], ["H₂O", {"H": 2, "O": 1}]], "tip": "burning propane"},
	{"L": [["Al", {"Al": 1}], ["HCl", {"H": 1, "Cl": 1}]], "R": [["AlCl₃", {"Al": 1, "Cl": 3}], ["H₂", {"H": 2}]], "tip": "a metal dissolving in acid releases hydrogen gas"}]
var ei := 0
var co: Array = []
var sel := 0
var solved := 0.0

func begin() -> void:
	title = "XVI · THE REACTION"; btn = []; max_hp = 1; hp = 1; begin_eq()

func terms() -> Array:
	var tt: Array = []; tt.append_array(EQ[ei]["L"]); tt.append_array(EQ[ei]["R"]); return tt

func nL() -> int:
	return EQ[ei]["L"].size()

func begin_eq() -> void:
	co = []
	for q in terms(): co.append(1)
	sel = 0; solved = 0.0

func tally() -> Dictionary:
	var T := {}; var ts := terms()
	for i in ts.size():
		for el in ts[i][1].keys():
			if not T.has(el): T[el] = [0, 0]
			T[el][0 if i < nL() else 1] += ts[i][1][el] * co[i]
	return T

func tick(d: float) -> void:
	if solved > 0.0:
		solved += d
		if solved > 1.5:
			if ei == EQ.size() - 1: m._finish(true); return
			ei += 1; begin_eq()
		return
	var n := co.size()
	if Input.is_action_just_pressed("move_right"): sel = (sel + 1) % n; m.snd("tick")
	if Input.is_action_just_pressed("move_left"): sel = (sel + n - 1) % n; m.snd("tick")
	if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("jump"): co[sel] = mini(9, co[sel] + 1); m.snd("tick")
	if Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("attack"): co[sel] = maxi(1, co[sel] - 1); m.snd("tick")
	var T := tally(); var ok := true; var a := 0; var b := 0
	for el in T.keys():
		a += T[el][0]; b += T[el][1]
		if T[el][0] != T[el][1]: ok = false
	info = "equation %d / %d     atoms in = %d     atoms out = %d     matter is never created or destroyed" % [ei + 1, EQ.size(), a, b]
	if ok: solved = 0.001; score(Vector2(640, 300)); m.combo += 1; m.snd("clear"); hap(40); m.fx.burst(Vector2(640, 300), 50, GOLD, 450.0, 0.0)

func _draw() -> void:
	var E: Dictionary = EQ[ei]; var TS := terms(); var n := TS.size(); var T := tally()
	txt(E["tip"], Vector2(640, 46), 17, Color(1, 1, 1, 0.75), true)
	for i in EQ.size(): draw_circle(Vector2(590 + i * 20, 70), 5.0 if i == ei else 3.5, GOLD if i < ei else Color(1, 1, 1, 0.9 if i == ei else 0.3))
	var sp := minf(250.0, 1040.0 / n); var EY := 330.0
	for i in n:
		var x := 640.0 + (i - (n - 1) / 2.0) * sp; var on := i == sel and solved <= 0.0
		if i > 0: txt("→" if i == nL() else "+", Vector2(x - sp / 2.0 - 12, EY + 14), 40, GOLD if i == nL() else Color.WHITE)
		txt(str(co[i]), Vector2(x - 70, EY + 22), 60, GOLD if (on or solved > 0.0) else Color.WHITE)
		txt(TS[i][0], Vector2(x - 24, EY + 16), 38)
		if on: txt("▲", Vector2(x - 60, EY - 46), 14, GOLD); txt("▼", Vector2(x - 60, EY + 62), 14, GOLD)
		var els: Array = []
		for el in TS[i][1].keys():
			for k in TS[i][1][el]: els.append(el)
		for k in co[i]:
			var bx: float = x - 70.0 + (k % 3) * 56.0
			var by: float = EY - 96.0 - int(k / 3) * 34.0
			for j in mini(els.size(), 6):
				draw_circle(Vector2(bx + (j % 4) * 11.0, by + int(j / 4) * 11.0), 5.5, Color(EL[els[j]], 0.9))
	var ks := T.keys(); var ty := 460.0
	txt("ATOMS IN", Vector2(430, ty), 11, Color(1, 1, 1, 0.6)); txt("ATOMS OUT", Vector2(790, ty), 11, Color(1, 1, 1, 0.6))
	for i in ks.size():
		var el: String = ks[i]; var y := ty + 34.0 + i * 36.0; var v: Array = T[el]; var ok: bool = v[0] == v[1]
		draw_circle(Vector2(624, y), 9.0, EL[el]); txt(el, Vector2(654, y + 6), 18)
		var col := GOLD if ok else Color(1, 0.54, 0.44)
		draw_rect(Rect2(580 - v[0] * 14.0, y - 7, v[0] * 14.0, 14), col); draw_rect(Rect2(700, y - 7, v[1] * 14.0, 14), col)
		txt(str(v[0]), Vector2(556 - v[0] * 14.0, y + 6), 16); txt(str(v[1]), Vector2(712 + v[1] * 14.0, y + 6), 16)
		txt("✓" if ok else "≠", Vector2(1050, y + 7), 20, col)
	hero_at(Vector2(640.0 + (sel - (n - 1) / 2.0) * sp - 60.0, EY + 150.0), "jump" if solved > 0.0 else "throw")
	if solved > 0.0: txt("balanced  ✓", Vector2(640, 208), 26, GOLD, true)
