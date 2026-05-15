# floating_text.gd
extends Node2D

@onready var label: Label = $Label

func init(text: String) -> void:
	label.text = text
	var tween = create_tween()
	tween.tween_property(self, "position", position + Vector2(0, -50), 0.8)
	tween.parallel().tween_property(label, "modulate", Color(1, 1, 1, 0), 0.8)
	tween.tween_callback(queue_free)
