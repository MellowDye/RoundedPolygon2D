@tool
extends RoundedPolygon2D

@export var target_radius: int = 50

func _ready():
	if Engine.is_editor_hint(): return
	corner_radius = 5
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUART).set_loops()
	tween.tween_property(self, "corner_radius", target_radius, 2)
	tween.tween_property(self, "corner_radius", 5, 1.5)
