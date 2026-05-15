extends Control

@onready var play_button: Button = $PlayButton
@onready var tutorial_button: Button = $TutorialButton
@onready var credits_button: Button = $CreditsButton

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	credits_button.pressed.connect(_on_credits_pressed)

	if has_node("/root/BGM"):
		get_node("/root/BGM").play(0)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_tutorial_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/tutorial.tscn")

func _on_credits_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/credits.tscn")
