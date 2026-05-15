extends Node

signal score_changed(new_score: int)
signal health_changed(current: float, maximum: float)
signal shield_changed(charges: int)
signal ability_unlocked() 
signal game_over
signal xp_changed(current: int, needed: int)
signal wave_started(wave_number: int)

var score: int = 0
var highscore: int = 0

const SAVE_PATH = "user://highscore.save"
const ABILITY_THRESHOLDS: Array = [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1200]

func _ready() -> void:
	_load_highscore()

func add_score(points: int) -> void:
	var old_score := score
	score += points
	if score > highscore:
		highscore = score
		_save_highscore()
	score_changed.emit(score)
	_check_abilities(old_score, score)
	_update_xp()

func _update_xp() -> void:
	var next_threshold := -1
	for threshold in ABILITY_THRESHOLDS:
		if score < threshold:
			if next_threshold == -1 or threshold < next_threshold:
				next_threshold = threshold
	if next_threshold == -1:
		xp_changed.emit(100, 100)
	else:
		var prev_threshold := 0
		for threshold in ABILITY_THRESHOLDS:
			if threshold < next_threshold:
				if threshold > prev_threshold:
					prev_threshold = threshold
		var current_xp := score - prev_threshold
		var needed_xp := next_threshold - prev_threshold
		xp_changed.emit(current_xp, needed_xp)

func update_health(current: float, maximum: float) -> void:
	health_changed.emit(current, maximum)

func update_shield(charges: int) -> void:
	shield_changed.emit(charges)

func player_died() -> void:
	game_over.emit()

func _check_abilities(old: int, new_val: int) -> void:
	for threshold in ABILITY_THRESHOLDS:
		if old < threshold and new_val >= threshold:
			ability_unlocked.emit() 

func reset() -> void:
	score = 0
	score_changed.emit(0)
	_update_xp() # Obliga a la barra y al texto a volver a empezar

func _save_highscore() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_32(highscore)
		file.close()

func _load_highscore() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			highscore = file.get_32()
			file.close()

func new_wave(wave_number: int) -> void:
	wave_started.emit(wave_number)
