extends Node2D
# Renders every pose large, saves a screenshot, quits. Dev only.
var skins := []
func _ready() -> void:
	var poses := [["idle",0.0,0],["run",0.0,0],["run",1.2,0],["run",2.4,0],["run",3.6,0],["jump",0.0,0],["fall",0.0,0],["land",0.0,0],
		["dash",0.0,0],["slash",0.5,1],["slash",0.8,1],["slash",0.5,2],["slash",0.55,3],["throw",0.0,0],["hurt",0.0,0],["idle",0.0,0]]
	for i in poses.size():
		var s = preload("res://skin.gd").new()
		s.tex = load("res://art/hero_parts.png")
		s.position = Vector2(90 + (i % 8) * 155, 300 + (i / 8) * 330)
		s.scale = Vector2(3, 3)
		s.pose = poses[i][0]; s.ph = poses[i][1]; s.swing = poses[i][2]; s.combo = poses[i][2] if poses[i][2] > 0 else 1
		if i == 15: s.tint = Color("ff4a6a")
		add_child(s)
		skins.append(s)
	var l := Line2D.new(); l.points = PackedVector2Array([Vector2(0, 300), Vector2(1280, 300)]); l.default_color = Color(1,1,1,.4); l.width = 2; add_child(l)
	var l2 := Line2D.new(); l2.points = PackedVector2Array([Vector2(0, 630), Vector2(1280, 630)]); l2.default_color = Color(1,1,1,.4); l2.width = 2; add_child(l2)
var n := 0
func _process(_d: float) -> void:
	n += 1
	for s in skins: s._t = 0.6   # freeze the breathing
	if n == 90:
		get_viewport().get_texture().get_image().save_png(OS.get_environment("SVG_SHOT"))
		get_tree().quit()
