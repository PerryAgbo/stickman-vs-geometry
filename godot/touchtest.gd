extends Node
# Dev-only: injects touch events the way the OS does and checks the control rules. Prints PASS/FAIL lines.
var m: Node
var n := 0
var fails := 0
var flew := false
var atk_seen := {}

func _ready() -> void:
	m = load("res://main.tscn").instantiate()
	add_child(m)

func _win(canvas: Vector2) -> Vector2:
	return get_window().get_final_transform() * canvas

func _touch(canvas: Vector2, pressed: bool, idx := 0) -> void:
	var ev := InputEventScreenTouch.new()
	ev.position = _win(canvas); ev.pressed = pressed; ev.index = idx
	Input.parse_input_event(ev)

func _drag(canvas: Vector2, idx := 0) -> void:
	var ev := InputEventScreenDrag.new()
	ev.position = _win(canvas); ev.index = idx
	Input.parse_input_event(ev)

func _ok(name: String, cond: bool, detail := "") -> void:
	if not cond: fails += 1
	print("T %-4d %s  %s  %s" % [n, "PASS" if cond else "FAIL", name, detail])

func _axis() -> float:
	return Input.get_axis("move_left", "move_right")

func _physics_process(_d: float) -> void:
	if m.hero and m.hero.flying: flew = true

func _process(_d: float) -> void:
	n += 1
	var hud = m.hud
	var h = m.hero
	var o := Vector2(220, 520)
	match n:
		20: _touch(o, true, 0)
		22: _drag(o + Vector2(12, 0))
		24: _ok("a 1 mm nudge does nothing (dead zone)", _axis() == 0.0, "axis=%.2f" % _axis())
		26: _drag(o + Vector2(30, 0))
		28: _ok("a light push walks, not sprints", _axis() > 0.3 and _axis() < 0.5, "axis=%.2f" % _axis())
		30: _drag(o + Vector2(48, 0))
		32: _ok("half deflection is a jog", _axis() > 0.55 and _axis() < 0.8, "axis=%.2f" % _axis())
		34: _drag(o + Vector2(70, 0))
		36: _ok("full deflection is a sprint", _axis() > 0.98, "axis=%.2f" % _axis())
		38: _drag(o + Vector2(300, 0))
		40: _ok("the centre follows the thumb", absf(hud.joy_o.x - (o.x + 300 - hud.STICK_R)) < 1.0, "joy_o.x=%.0f" % hud.joy_o.x)
		42: _drag(o + Vector2(300 - 100, 0))
		44: _ok("reversing takes about 1 cm of thumb travel, wherever the thumb is", _axis() < -0.3, "axis=%.2f after 100 px back" % _axis())
		46: _drag(o + Vector2(300 - 100, -22))
		48: _ok("a resting diagonal does not press up", not Input.is_action_pressed("move_up") and _axis() < 0.0, "up=%s" % Input.is_action_pressed("move_up"))
		50: _touch(o, false, 0)
		52: _ok("lifting the thumb stops everything", _axis() == 0.0 and hud.joy_id == -1)
		# buttons: nearest wins, slop covers the seam
		60:
			var bs = hud._buttons()
			var mid: Vector2 = (bs[0][1] + bs[1][1]) / 2.0
			_touch(mid, true, 1)
		62: _ok("a tap between ATK and JUMP still presses one of them", hud.held.has(1), "held=%s" % str(hud.held))
		64: _touch(Vector2.ZERO, false, 1)
		66:
			var b = hud._buttons()[0]
			_touch(b[1] + Vector2(0, b[2] + 22.0), true, 1)
		68: _ok("a tap 22 px outside the ATK ring still attacks", hud.held.get(1, "") == "attack", "held=%s" % str(hud.held))
		70: _touch(Vector2.ZERO, false, 1)
		# attack buffer: three taps 100 ms apart must give three swings
		90: Input.action_press("attack")
		91: Input.action_release("attack")
		96: Input.action_press("attack")
		97: Input.action_release("attack")
		102: Input.action_press("attack")
		103: Input.action_release("attack")
		160: _ok("three quick ATK taps give three swings", h.atk_id >= 3, "swings=%d" % h.atk_id)
		# double jump tapped: no flight
		170: Input.action_press("jump")
		173: Input.action_release("jump")
		185: Input.action_press("jump")
		189: Input.action_release("jump")
		240:
			_ok("a tapped double jump does not start flying", not flew and h.dj == false, "flew=%s" % flew)
			flew = false
		# double jump held: flight
		250: Input.action_press("jump")
		253: Input.action_release("jump")
		265: Input.action_press("jump")
		320:
			_ok("holding the second jump does fly", flew, "flew=%s fuel=%.2f" % [flew, h.fuel])
			Input.action_release("jump")
		330:
			print("T DONE fails=", fails)
			get_tree().quit()
