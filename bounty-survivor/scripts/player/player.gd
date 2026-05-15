extends CharacterBody2D

const SPEED = 200.0
const MAX_HEALTH = 100.0
const INVINCIBLE_TIME = 0.5

@export var bullet_scene: PackedScene
@export var burst_texture: Texture2D

@onready var gun_pivot: Node2D = $GunPivot
@onready var shoot_point: Marker2D = $GunPivot/ShootPoint
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D

@onready var sfx_shoot: AudioStreamPlayer2D = $SfxShoot
@onready var sfx_hurt: AudioStreamPlayer2D = $SfxHurt
@onready var sfx_shield: AudioStreamPlayer2D = $SfxShield 
@onready var sfx_burst: AudioStreamPlayer2D = $SfxBurst

var fire_rate := 0.3
var fire_timer := 0.0
var current_health := MAX_HEALTH
var is_dead := false
var is_attacking := false
var invincible_timer := 0.0
var last_direction := "down"

var unlocked_abilities: Array = []
var has_piercing := false
var speed_boost := 1.0
var has_bounty_hunter := false
var has_life_steal := false
var has_rapid_fire := false
var has_shield := false
var shield_charges := 0
var has_area_burst := false
var has_magnet := false
var has_triple_shot := false

var burst_timer := 0.0
const BURST_RATE = 5.0
const BURST_RADIUS = 150.0
const BURST_DAMAGE = 30.0

var has_explosive := false
var has_freeze := false
var has_extra_life := false
var max_health := MAX_HEALTH
var dash_timer := 0.0
var is_dashing := false
var dash_velocity := Vector2.ZERO
const DASH_SPEED = 600.0
const DASH_DURATION = 0.15
const DASH_COOLDOWN = 1.0

# --- NUEVO: Variable para la flecha del boss ---
var boss_pointer: Polygon2D

func _ready() -> void:
	# Dibujamos una flecha roja por código
	boss_pointer = Polygon2D.new()
	var points = PackedVector2Array([Vector2(15, 0), Vector2(-15, -10), Vector2(-5, 0), Vector2(-15, 10)])
	boss_pointer.polygon = points
	boss_pointer.color = Color(1, 0, 0, 0.7) 
	boss_pointer.z_index = 100 # <--- AÑADE ESTA LÍNEA: 100 es suficiente para estar sobre el gameplay
	boss_pointer.visible = false
	add_child(boss_pointer)

func _physics_process(delta: float) -> void:
	if is_dead: return
	_handle_movement()
	if not is_attacking: _update_animations()
	_aim_gun()
	_handle_shooting(delta)
	if invincible_timer > 0: invincible_timer -= delta
	if has_area_burst: _handle_burst(delta)
	if has_ability("dash"): _handle_dash(delta)
	
	# --- NUEVO: Lógica de la Flecha del Boss ---
	var bosses = get_tree().get_nodes_in_group("boss")
	if bosses.size() > 0:
		boss_pointer.visible = true
		var boss = bosses[0]
		var dir = (boss.global_position - global_position).normalized()
		# Mantiene la flecha orbitando al jugador a 80 píxeles de distancia
		boss_pointer.global_position = global_position + dir * 80.0
		boss_pointer.rotation = dir.angle()
	else:
		boss_pointer.visible = false

func _handle_movement() -> void:
	var direction := Vector2.ZERO
	direction.x = Input.get_axis("move_left", "move_right")
	direction.y = Input.get_axis("move_up", "move_down")
	if direction.length() > 0.05:
		velocity = direction.normalized() * SPEED * speed_boost
	else:
		velocity = Vector2.ZERO
	move_and_slide()

func _update_animations() -> void:
	if velocity.length() < 10.0:
		anim_player.play("idle_" + last_direction)
		return
	if abs(velocity.x) > abs(velocity.y):
		last_direction = "right" if velocity.x > 0 else "left"
	else:
		last_direction = "down" if velocity.y > 0 else "up"
	anim_player.play("run_" + last_direction)

func _aim_gun() -> void:
	gun_pivot.look_at(get_global_mouse_position())

func _handle_shooting(delta: float) -> void:
	fire_timer -= delta
	if Input.is_action_pressed("shoot") and fire_timer <= 0.0:
		_shoot()
		fire_timer = fire_rate

func _shoot() -> void:
	if bullet_scene == null: return
	var target_pos := get_global_mouse_position()
	
	if has_magnet:
		var enemies := get_tree().get_nodes_in_group("enemy")
		if enemies.size() > 0:
			var closest_enemy = null
			var min_dist = INF
			for e in enemies:
				var d = global_position.distance_to(e.global_position)
				if d < min_dist:
					min_dist = d
					closest_enemy = e
			if closest_enemy: target_pos = closest_enemy.global_position

	var shoot_dir := (target_pos - shoot_point.global_position).normalized()
	if abs(shoot_dir.x) > abs(shoot_dir.y):
		last_direction = "right" if shoot_dir.x > 0 else "left"
	else:
		last_direction = "down" if shoot_dir.y > 0 else "up"

	_play_attack_animation()
	if sfx_shoot:
		sfx_shoot.pitch_scale = randf_range(0.9, 1.1)
		sfx_shoot.play()

	if has_triple_shot:
		var angles = [-20.0, 0.0, 20.0]
		for angle in angles:
			var final_direction = shoot_dir.rotated(deg_to_rad(angle))
			_spawn_bullet(final_direction)
	else:
		_spawn_bullet(shoot_dir)

func _spawn_bullet(direction: Vector2) -> void:
	var bullet = bullet_scene.instantiate()
	get_tree().root.add_child(bullet)
	bullet.global_position = shoot_point.global_position
	if bullet.has_method("set_piercing"):
		bullet.set_piercing(has_piercing)
	bullet.init(direction)
	if bullet.has_method("set_explosive"):
		bullet.set_explosive(has_explosive)
	if bullet.has_method("set_freeze"):
		bullet.set_freeze(has_freeze)
	if bullet.has_method("set_burst_texture"):
		bullet.set_burst_texture(burst_texture)

func _play_attack_animation() -> void:
	if is_attacking: return
	var attack_anim = "attack_" + last_direction
	if anim_player.has_animation(attack_anim):
		is_attacking = true
		anim_player.play(attack_anim)
		await anim_player.animation_finished
		is_attacking = false

func _handle_burst(delta: float) -> void:
	burst_timer -= delta
	if burst_timer <= 0.0:
		burst_timer = BURST_RATE
		_do_area_burst()

func _do_area_burst() -> void:
	if sfx_burst: sfx_burst.play()
	if burst_texture:
		var burst_visual = Sprite2D.new()
		burst_visual.texture = burst_texture
		get_tree().current_scene.add_child(burst_visual)
		burst_visual.global_position = global_position
		burst_visual.scale = Vector2(0.1, 0.1)
		
		var tween = create_tween()
		tween.tween_property(burst_visual, "scale", Vector2(2, 2), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(burst_visual, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(burst_visual.queue_free)

	var enemies := get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if global_position.distance_to(e.global_position) <= BURST_RADIUS:
			if e.has_method("take_damage"):
				e.take_damage(BURST_DAMAGE)

func take_damage(amount: float) -> void:
	if invincible_timer > 0 or is_dead: return
	var gm = get_tree().root.get_node_or_null("GameManager")
	
	if has_shield and shield_charges > 0:
		shield_charges -= 1
		if sfx_shield: sfx_shield.play()
		_flash(Color(0, 1, 1, 1))
		
		invincible_timer = INVINCIBLE_TIME 
		
		if shield_charges <= 0: has_shield = false
		if gm: gm.update_shield(shield_charges)
		return

	current_health -= amount
	invincible_timer = INVINCIBLE_TIME
	if sfx_hurt: sfx_hurt.play()
	_flash(Color(1, 0, 0, 1)) 
	if gm: gm.update_health(current_health, max_health)
	if current_health <= 0: _die()

func _die() -> void:
	is_dead = true
	var gm = get_tree().root.get_node_or_null("GameManager")
	if gm: gm.player_died()

func heal(amount: float) -> void:
	current_health = min(current_health + amount, max_health)
	var gm = get_tree().root.get_node_or_null("GameManager")
	if gm: gm.update_health(current_health, max_health)

func unlock_ability(ability: String) -> void:
	if ability in unlocked_abilities: return
	unlocked_abilities.append(ability)
	match ability:
		"rapid_fire":
			has_rapid_fire = true
			fire_rate = 0.15
		"shield":
			has_shield = true
			shield_charges = 3
			var gm = get_tree().root.get_node_or_null("GameManager")
			if gm: gm.update_shield(shield_charges)
		"area_burst":
			has_area_burst = true
			burst_timer = BURST_RATE
		"magnet": has_magnet = true
		"triple_shot": has_triple_shot = true
		"piercing_shot": has_piercing = true
		"movement_speed": speed_boost = 1.5
		"bounty_hunter": has_bounty_hunter = true
		"life_steal": has_life_steal = true
		"explosive_bullets":
			has_explosive = true
		"freeze_shot":
			has_freeze = true
		"dash":
			pass 
		"extra_life":
			has_extra_life = true
			max_health = MAX_HEALTH + 50.0
			current_health = min(current_health + 50.0, max_health)
			var gm = get_tree().root.get_node_or_null("GameManager")
			if gm: gm.update_health(current_health, max_health)

func has_ability(ability: String) -> bool:
	return ability in unlocked_abilities

func _flash(color: Color) -> void:
	if sprite:
		for i in 5:
			sprite.modulate = color
			await get_tree().create_timer(0.05).timeout
			sprite.modulate = Color(1, 1, 1, 1)
			await get_tree().create_timer(0.05).timeout

func _handle_dash(delta: float) -> void:
	if dash_timer > 0: dash_timer -= delta
	if is_dashing:
		velocity = dash_velocity
		move_and_slide()
		return
	if Input.is_action_just_pressed("dash") and dash_timer <= 0:
		var dir := Vector2.ZERO
		dir.x = Input.get_axis("move_left", "move_right")
		dir.y = Input.get_axis("move_up", "move_down")
		if dir == Vector2.ZERO: dir = Vector2(1, 0)
		is_dashing = true
		dash_velocity = dir.normalized() * DASH_SPEED
		invincible_timer = DASH_DURATION
		await get_tree().create_timer(DASH_DURATION).timeout
		is_dashing = false
		dash_timer = DASH_COOLDOWN
