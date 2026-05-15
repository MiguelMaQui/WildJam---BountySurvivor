extends CanvasLayer

@onready var score_label: Label = $ScoreLabel
@onready var health_bar: ProgressBar = $HealthBar
@onready var ability_panel: Panel = $AbilityPanel
@onready var game_over_panel: Panel = $GameOverPanel
@onready var final_score_label: Label = $GameOverPanel/FinalScoreLabel
@onready var restart_button: Button = $GameOverPanel/RestartButton
@onready var btn1: Button = $AbilityPanel/CenterContainer/VBoxContainer/Ability1Button
@onready var btn2: Button = $AbilityPanel/CenterContainer/VBoxContainer/Ability2Button
@onready var btn3: Button = $AbilityPanel/CenterContainer/VBoxContainer/Ability3Button
@onready var shield_label: Label = $ShieldLabel
@onready var highscore_label: Label = $GameOverPanel/HighscoreLabel
@onready var wave_label: Label = $WaveLabel
@onready var xp_label: Label = $XPLabel
@onready var xp_bar_fill: ColorRect = $XPBarFill
@onready var pause_panel: Panel = $PausePanel
@onready var resume_button: Button = $PausePanel/ResumeButton
@onready var quit_button: Button = $PausePanel/QuitButton

@onready var sfx_level_up: AudioStreamPlayer = $SfxLevelUp
@onready var sfx_select: AudioStreamPlayer = $SfxSelect

var player: Node = null

const ABILITY_NAMES := {
	"rapid_fire": "🔥 Disparo Rápido\nDispara el doble de rápido",
	"shield":     "🛡️ Escudo\nBloquea 3 golpes",
	"area_burst": "💥 Explosión\nDaña enemigos cercanos cada 5s",
	"magnet":     "🧲 Imán\nLas balas buscan enemigos",
	"triple_shot": "🔱 Triple Disparo\nDispara 3 balas en abanico",
	"piercing_shot": "🏹 Bala Perforante\nAtraviesa a los enemigos",
	"movement_speed": "👢 Botas\n+50% velocidad",
	"bounty_hunter": "💰 Cazarrecompensas\nDobles puntos",
	"explosive_bullets": "💣 Balas Explosivas\nExplotan al impactar",
	"freeze_shot": "❄️ Disparo Helado\nRalentiza enemigos",
	"dash": "💨 Dash\nMantén SHIFT para esquivar",
	"extra_life": "❤️ Vida Extra\n+50 de vida máxima",
}

func _ready() -> void:
	# IMPORTANTE: Permite que todo el CanvasLayer detecte inputs en pausa
	process_mode = Node.PROCESS_MODE_ALWAYS 
	
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0: player = players[0]

	var gm = get_tree().root.get_node_or_null("GameManager")
	if gm:
		gm.score_changed.connect(_on_score_changed)
		gm.health_changed.connect(_on_health_changed)
		gm.game_over.connect(_on_game_over)
		gm.ability_unlocked.connect(_on_ability_unlocked)
		gm.wave_started.connect(_on_wave_started)
		gm.xp_changed.connect(_on_xp_changed)
		gm.shield_changed.connect(_on_shield_changed)

	ability_panel.visible = false
	game_over_panel.visible = false
	pause_panel.visible = false

	btn1.pressed.connect(_on_ability_chosen.bind(0))
	btn2.pressed.connect(_on_ability_chosen.bind(1))
	btn3.pressed.connect(_on_ability_chosen.bind(2))
	restart_button.pressed.connect(_on_restart)
	resume_button.pressed.connect(_on_resume)
	quit_button.pressed.connect(_on_quit)

func _on_score_changed(new_score: int) -> void:
	score_label.text = str(new_score)

func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current

func _on_game_over() -> void:
	var gm = get_tree().root.get_node_or_null("GameManager")
	final_score_label.text = "Puntos: " + str(gm.score if gm else 0)
	highscore_label.text = "Mejor puntuación: " + str(gm.highscore if gm else 0)
	game_over_panel.visible = true
	get_tree().paused = true

func _on_restart() -> void:
	var gm = get_tree().root.get_node_or_null("GameManager")
	if gm: gm.reset() # Llama al reset real del GameManager
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit() -> void:
	var gm = get_tree().root.get_node_or_null("GameManager")
	if gm: gm.reset() # Llama al reset real del GameManager
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_ability_unlocked() -> void: 
	get_tree().paused = true
	if sfx_level_up: sfx_level_up.play()

	var available_abilities: Array = []
	for ability in ABILITY_NAMES.keys():
		if player and player.has_method("has_ability"):
			if not player.has_ability(ability):
				available_abilities.append(ability)

	available_abilities.shuffle() 
	var options = available_abilities.slice(0, 3)

	btn1.visible = false
	btn2.visible = false
	btn3.visible = false

	if options.size() > 0:
		btn1.visible = true
		btn1.text = ABILITY_NAMES[options[0]]
		btn1.set_meta("ability", options[0])
	if options.size() > 1:
		btn2.visible = true
		btn2.text = ABILITY_NAMES[options[1]]
		btn2.set_meta("ability", options[1])
	if options.size() > 2:
		btn3.visible = true
		btn3.text = ABILITY_NAMES[options[2]]
		btn3.set_meta("ability", options[2])

	if options.size() == 0:
		get_tree().paused = false
		return

	ability_panel.visible = true
	
func _on_ability_chosen(btn_index: int) -> void:
	if sfx_select: sfx_select.play()
	
	var ability := ""
	match btn_index:
		0: ability = btn1.get_meta("ability")
		1: ability = btn2.get_meta("ability")
		2: ability = btn3.get_meta("ability")

	if player and player.has_method("unlock_ability"):
		player.unlock_ability(ability)

	ability_panel.visible = false
	get_tree().paused = false

func _on_shield_changed(charges: int) -> void:
	if charges > 0:
		shield_label.visible = true
		shield_label.text = "🛡️".repeat(charges)
	else:
		shield_label.visible = false

func _on_wave_started(wave_number: int) -> void:
	wave_label.text = "¡Oleada " + str(wave_number) + "!"
	wave_label.modulate = Color(1, 0.3, 0.3, 1)
	var tween = create_tween()
	tween.tween_property(wave_label, "modulate", Color(1, 1, 1, 1), 1.0)

func _on_xp_changed(current: int, needed: int) -> void:
	var fill_width := 300.0 * (float(current) / float(needed))
	xp_bar_fill.size.x = clamp(fill_width, 0, 300)

	var gm = get_tree().root.get_node_or_null("GameManager")
	if gm:
		var next_threshold := -1
		for threshold in gm.ABILITY_THRESHOLDS:
			if gm.score < threshold:
				if next_threshold == -1 or threshold < next_threshold:
					next_threshold = threshold
		if next_threshold == -1:
			xp_label.text = "¡Máximo nivel alcanzado!"
			xp_bar_fill.size.x = 300
		else:
			xp_label.text = "Próxima habilidad: " + str(next_threshold) + " pts"

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"): # La tecla Escape
		_toggle_pause()

func _toggle_pause() -> void:
	if ability_panel.visible or game_over_panel.visible: return
	
	var is_paused = not get_tree().paused
	get_tree().paused = is_paused
	pause_panel.visible = is_paused

func _on_resume() -> void:
	get_tree().paused = false
	pause_panel.visible = false
