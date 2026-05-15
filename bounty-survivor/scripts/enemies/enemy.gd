extends CharacterBody2D

const SPEED = 80.0
const HEALTH = 30.0 # 3 toques de base (bala = 10 daño)
const POINTS = 10

var player: Node2D = null
var _player_in_detection := false
var _player_in_attack := false
var current_health := HEALTH
var last_direction := "down"
var freeze_timer := 0.0
var is_frozen := false

# --- NUEVO: Temporizador de inactividad ---
var idle_timer := 0.0

@onready var state_machine: EnemyStateMachine = $EnemyStateMachine
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var sfx_death: AudioStreamPlayer2D = $SfxDeath
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@export var floating_text_scene: PackedScene

func _ready() -> void:
	detection_area.body_entered.connect(_on_detection_entered)
	detection_area.body_exited.connect(_on_detection_exited)
	attack_area.body_entered.connect(_on_attack_entered)
	attack_area.body_exited.connect(_on_attack_exited)
	state_machine.init(self)
	
	await get_tree().process_frame
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0: player = players[0]

func set_wave(wave_num: int) -> void:
	if wave_num >= 7:
		var vidas_extra = floor((wave_num - 7) / 2.0) + 1
		current_health = HEALTH + (vidas_extra * 10.0) 
	else:
		current_health = HEALTH

func _physics_process(delta: float) -> void:
	state_machine.update(delta)
	
	if state_machine.current_state != EnemyStateMachine.State.DEAD:
		_update_animations()
		
		# --- NUEVO: Control de inactividad ---
		if state_machine.current_state == EnemyStateMachine.State.IDLE:
			idle_timer += delta
		else:
			idle_timer = 0.0
		
		# --- NUEVO: Lógica de Teletransporte ---
		if player:
			var dist = global_position.distance_to(player.global_position)
			
			# Se teletransporta si está extremadamente lejos (>2000) 
			# O si lleva inactivo 15s y está lo suficientemente lejos como para no verlo aparecer (>1000)
			if dist > 2000.0 or (idle_timer > 15.0 and dist > 1000.0):
				var angle = randf() * TAU
				# Reaparece a 600 unidades del jugador (lo justo para estar fuera de la cámara)
				global_position = player.global_position + Vector2(cos(angle), sin(angle)) * 600.0
				idle_timer = 0.0 # Reseteamos el temporizador

	if freeze_timer > 0:
			freeze_timer -= delta
			if freeze_timer <= 0:
				is_frozen = false
				# Vuelve a aplicar el color correcto según lo que esté haciendo
				state_machine._enter_state(state_machine.current_state)

func _update_animations() -> void:
	var anim_type = "idle"
	var face_dir := Vector2.ZERO
	
	if state_machine.current_state == EnemyStateMachine.State.CHASE:
		anim_type = "run"
		face_dir = velocity
	else:
		anim_type = "idle"
		if player != null:
			face_dir = player.global_position - global_position

	if face_dir.length() > 0.1:
		if abs(face_dir.x) > abs(face_dir.y):
			last_direction = "right" if face_dir.x > 0 else "left"
		else:
			last_direction = "down" if face_dir.y > 0 else "up"

	var anim_name = anim_type + "_" + last_direction
	if anim_player.has_animation(anim_name) and anim_player.current_animation != anim_name:
		anim_player.play(anim_name)

func can_see_player() -> bool: return _player_in_detection
func is_in_attack_range() -> bool: return _player_in_attack

func move_towards_player(_delta: float) -> void:
	if player == null: return
	var direction := (player.global_position - global_position).normalized()
	var current_speed = SPEED * 0.6 if is_frozen else SPEED
	velocity = direction * current_speed
	move_and_slide()

func take_damage(amount: float) -> void:
	if current_health <= 0: return 
	current_health -= amount
	if current_health <= 0:
		state_machine.transition_to(EnemyStateMachine.State.DEAD)

func die() -> void:
	set_physics_process(false)
	detection_area.monitoring = false
	attack_area.monitoring = false
	
	if sfx_death:
		sfx_death.pitch_scale = randf_range(0.8, 1.2)
		sfx_death.play()

	var final_points = POINTS
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p = players[0]
		if p.has_method("has_ability"):
			if p.has_ability("bounty_hunter"): final_points *= 2
			if p.has_ability("life_steal"): p.heal(5)

	var gm = get_tree().root.get_node_or_null("GameManager")
	if gm: gm.add_score(final_points)

	if floating_text_scene:
		var ft = floating_text_scene.instantiate()
		get_tree().current_scene.add_child(ft)
		ft.global_position = global_position
		ft.init("+" + str(final_points))

	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		hide()
		if sfx_death and sfx_death.playing:
			await sfx_death.finished
		queue_free()
	)

func _on_detection_entered(body: Node2D) -> void:
	if body.is_in_group("player"): _player_in_detection = true
func _on_detection_exited(body: Node2D) -> void:
	if body.is_in_group("player"): _player_in_detection = false
func _on_attack_entered(body: Node2D) -> void:
	if body.is_in_group("player"): _player_in_attack = true
func _on_attack_exited(body: Node2D) -> void:
	if body.is_in_group("player"): _player_in_attack = false

func apply_freeze(duration: float) -> void:
	is_frozen = true
	freeze_timer = duration
	modulate = Color(0.5, 0.8, 1.0, 1.0)
