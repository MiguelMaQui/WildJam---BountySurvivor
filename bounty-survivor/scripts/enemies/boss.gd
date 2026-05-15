extends CharacterBody2D

const SPEED = 55.0 
const HEALTH = 500.0 
const POINTS = 100 

var player: Node2D = null
var _player_in_detection := false
var _player_in_attack := false
var current_health := HEALTH
var last_direction := "down"

var freeze_timer := 0.0
var is_frozen := false

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
	
	modulate = Color(0.8, 0.5, 0.5, 1)
	
	await get_tree().process_frame
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0: player = players[0]

# --- NUEVO: Vida del Boss Escala ---
func set_wave(wave_num: int) -> void:
	if wave_num >= 7:
		var bonus = floor((wave_num - 7) / 2.0) + 1
		current_health = HEALTH + (bonus * 150.0) # Gana muchísima vida extra
	else:
		current_health = HEALTH

func _physics_process(delta: float) -> void:
	state_machine.update(delta)
	if state_machine.current_state != EnemyStateMachine.State.DEAD:
		_update_animations()
		
		# --- NUEVO: Teletransporte del Boss si te alejas mucho ---
		if player and global_position.distance_to(player.global_position) > 2000.0:
			var angle = randf() * TAU
			global_position = player.global_position + Vector2(cos(angle), sin(angle)) * 600.0

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
	modulate = Color(10, 10, 10, 1)
	await get_tree().create_timer(0.05).timeout
	if not is_frozen: modulate = Color(0.8, 0.5, 0.5, 1)
	else: modulate = Color(0.4, 0.6, 0.9, 1.0)
	
	if current_health <= 0:
		state_machine.transition_to(EnemyStateMachine.State.DEAD)

func apply_freeze(duration: float) -> void:
	is_frozen = true
	freeze_timer = duration
	modulate = Color(0.4, 0.6, 0.9, 1.0)

func die() -> void:
	set_physics_process(false)
	detection_area.monitoring = false
	attack_area.monitoring = false
	
	if sfx_death:
		sfx_death.pitch_scale = randf_range(0.5, 0.7)
		sfx_death.play()

	var final_points = POINTS
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p = players[0]
		if p.has_method("has_ability"):
			if p.has_ability("bounty_hunter"): final_points *= 2
			if p.has_ability("life_steal"): p.heal(20) 

	var gm = get_tree().root.get_node_or_null("GameManager")
	if gm: gm.add_score(final_points)

	if floating_text_scene:
		var ft = floating_text_scene.instantiate()
		get_tree().current_scene.add_child(ft)
		ft.global_position = global_position
		ft.init("+" + str(final_points))

	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
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
