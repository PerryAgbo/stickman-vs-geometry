extends "res://chapter.gd"
## Probability: catch the φ falling through the pegs; the landed balls build a binomial histogram.
const N := 10
const BW := 80.0
const CX := 640.0
const TOPY := 96.0
const ROWH := 36.0
const FLOOR := 520.0
const STEP := 0.26
var RD := [{"gold": 40, "red": 0, "p": 0.5, "need": 17, "tip": "each peg is a coin flip:  left or right, 50 / 50"},
	{"gold": 40, "red": 0, "p": 0.68, "need": 17, "tip": "the pegs are biased:  68% go right  →  the peak moves to n·p"},
	{"gold": 34, "red": 20, "p": 0.5, "need": 12, "tip": "red balls cost 2 and fall from a source 3 bins to the right"}]
var ri := 0
var balls: Array = []
var queue: Array = []
var hist: Array = []
var sc := 0
var spawn := 0.8
var px := CX
var face := 1
var endt := 0.0

func begin() -> void:
	title = "XIV · THE GALTON BOARD"; max_hp = 3; hp = 3; start_round()

func start_round() -> void:
	var rd: Dictionary = RD[ri]; balls = []; hist = []; sc = 0; spawn = 0.8; endt = 0.0; queue = []
	for i in N + 1: hist.append(0)
	for i in rd["gold"]: queue.append(0)
	for i in rd["red"]: queue.append(1)
	queue.shuffle()

func C(n: int, k: int) -> float:
	var r := 1.0
	for i in range(1, k + 1): r = r * (n - k + i) / i
	return r

func pk(k: int, p: float) -> float:
	return C(N, k) * pow(p, k) * pow(1.0 - p, N - k)

func binx(k: float) -> float:
	return CX + (k - N / 2.0) * BW

func bpos(b: Dictionary) -> Vector2:
	var u: float = b["t"] / STEP; var sh := 3.0 if b["red"] else 0.0
	if u >= N:
		var f := clampf((b["t"] - N * STEP) / 0.38, 0.0, 1.0)
		return Vector2(binx(b["bin"]), lerpf(TOPY + N * ROWH, FLOOR - 12.0, f * f))
	var r := int(u); var f := u - r; var e := f * f * (3.0 - 2.0 * f)
	var xa: float = CX + (b["k"][r] - r / 2.0 + sh) * BW; var xb: float = CX + (b["k"][r + 1] - (r + 1) / 2.0 + sh) * BW
	return Vector2(clampf(lerpf(xa, xb, e), binx(0), binx(N)), TOPY + u * ROWH - sin(PI * f) * 9.0)

func tick(d: float) -> void:
	var rd: Dictionary = RD[ri]
	var a := ax()
	px = clampf(px + a * 440.0 * d, binx(0), binx(N))
	if a != 0.0: face = 1 if a > 0.0 else -1
	spawn -= d
	if spawn <= 0.0 and queue.size() > 0:
		spawn = 0.42; var red: bool = queue.pop_back() == 1; var k: Array = [0]
		for r in N: k.append(k[r] + (1 if randf() < rd["p"] else 0))
		balls.append({"k": k, "red": red, "t": 0.0, "bin": clampi(k[N] + (3 if red else 0), 0, N)})
	for i in range(balls.size() - 1, -1, -1):
		var b: Dictionary = balls[i]; b["t"] += d
		if b["t"] >= N * STEP + 0.38:
			balls.remove_at(i); var bx := binx(b["bin"])
			if not b["red"]: hist[b["bin"]] += 1
			if absf(px - bx) < BW / 2.0 + 2.0:
				if b["red"]: sc -= 2; m.shake = 8.0; m.combo = 0; m.snd("hurt"); hap(40); m.fx.burst(Vector2(bx, FLOOR - 40), 12, RED)
				else: sc += 1; score(Vector2(bx, FLOOR - 50)); m.snd("phi")
			else: m.fx.burst(Vector2(bx, FLOOR), 4, RED if b["red"] else Color.WHITE, 120.0)
	if queue.is_empty() and balls.is_empty():
		endt += d
		if endt > 0.9:
			if sc >= rd["need"]:
				if ri == RD.size() - 1: m._finish(true); return
				ri += 1; m.snd("clear"); start_round()
			else:
				if hurt(): start_round()
	var kk := clampi(int(round((px - CX) / BW + N / 2.0)), 0, N)
	info = "round %d / 3    n = %d  p = %.2f    μ = n·p = %.1f    σ = √(npq) = %.2f    P(bin %d) = %.1f%%" % [ri + 1, N, rd["p"], N * rd["p"], sqrt(N * rd["p"] * (1.0 - rd["p"])), kk, pk(kk, rd["p"]) * 100.0]

func _draw() -> void:
	var rd: Dictionary = RD[ri]
	for r in N:
		for i in r + 1:
			if rd["red"] > 0 and CX + (i - r / 2.0 + 3.0) * BW <= binx(N) + 1.0: dot(Vector2(CX + (i - r / 2.0 + 3.0) * BW, TOPY + r * ROWH + 10.0), 2.5)
			dot(Vector2(CX + (i - r / 2.0) * BW, TOPY + r * ROWH + 10.0), 3.5)
	draw_line(Vector2(binx(0) - BW / 2.0, FLOOR), Vector2(binx(N) + BW / 2.0, FLOOR), Color.WHITE, 2.0)
	for k in N + 2: draw_line(Vector2(binx(k) - BW / 2.0, FLOOR - 70), Vector2(binx(k) - BW / 2.0, FLOOR + 150), Color(1, 1, 1, 0.4), 1.0)
	var mx := 6.0
	for k in N + 1: mx = maxf(mx, maxf(hist[k], rd["gold"] * pk(int(round(N * rd["p"])), rd["p"])))
	var scl := 120.0 / mx
	for k in N + 1:
		draw_rect(Rect2(binx(k) - BW / 2.0 + 5.0, FLOOR + 6.0, BW - 10.0, hist[k] * scl), Color(1, 0.82, 0.23, 0.5))
		txt(str(k), Vector2(binx(k) - 5, FLOOR + 172), 13, Color(1, 1, 1, 0.6))
		if hist[k] > 0: txt(str(hist[k]), Vector2(binx(k) - 6, FLOOR + 22 + hist[k] * scl), 12)
	var curve := PackedVector2Array()
	for k in N + 1: curve.append(Vector2(binx(k), FLOOR + 6.0 + rd["gold"] * pk(k, rd["p"]) * scl))
	draw_polyline(curve, BLUE, 2.0, true)
	for q in curve: dot(q, 3.0)
	txt("expected (binomial)", Vector2(binx(N) + BW / 2.0 + 8.0, FLOOR + 44), 12, BLUE); txt("landed", Vector2(binx(N) + BW / 2.0 + 8.0, FLOOR + 64), 12, GOLD)
	for b in balls:
		var q := bpos(b)
		if b["red"]: draw_circle(q, 9.0, RED)
		else: phi(q, 20.0, GOLD, b["t"] * 5.0)
	draw_polyline(PackedVector2Array([Vector2(px - 30, FLOOR - 88), Vector2(px - 22, FLOOR - 70), Vector2(px + 22, FLOOR - 70), Vector2(px + 30, FLOOR - 88)]), GOLD, 2.5, true)
	hero_at(Vector2(px, FLOOR), "run" if ax() != 0.0 else "idle", 0.0, face)
	txt(rd["tip"], Vector2(640, 46), 17, Color(1, 1, 1, 0.75), true)
	txt("caught  %d  /  need %d        left  %d" % [sc, rd["need"], queue.size() + balls.size()], Vector2(640, 72), 16, GOLD if sc >= rd["need"] else Color.WHITE, true)
