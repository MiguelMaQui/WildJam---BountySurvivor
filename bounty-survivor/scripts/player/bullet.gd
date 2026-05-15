extends Area2D

const SPEED = 500.0
const DAMAGE = 10.0
const LIFETIME = 2.0
const EXPLOSION_RADIUS = 30.0
const EXPLOSION_DAMAGE = 10.0 
const FREEZE_DURATION = 2.0

var direction := Vector2.ZERO
var timer := 0.0
var piercing := false
var hit_count := 0
const MAX_HITS := 3
var explosive := false
var freeze := false
var burst_texture: Texture2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func init(shoot_direction: Vector2) -> void:
	direction = shoot_direction.normalized()
	rotation = direction.angle()

func set_piercing(value: bool) -> void:
	piercing = value

func set_explosive(value: bool) -> void:
	explosive = value

func set_freeze(value: bool) -> void:
	freeze = value

func _process(delta: float) -> void:
	position += direction * SPEED * delta
	timer += delta
	if timer >= LIFETIME:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(DAMAGE)

		if freeze and body.has_method("apply_freeze"):
			body.apply_freeze(FREEZE_DURATION)

		if explosive:
			_explode()

		if piercing:
			hit_count += 1
			if hit_count >= MAX_HITS:
				queue_free()
		else:
			queue_free()

func _explode() -> void:
	# Daño en área
	var enemies := get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if global_position.distance_to(e.global_position) <= EXPLOSION_RADIUS:
			if e.has_method("take_damage"):
				e.take_damage(EXPLOSION_DAMAGE)

	# Efecto visual
	if burst_texture:
		var burst_visual = Sprite2D.new()
		burst_visual.texture = burst_texture
		burst_visual.global_position = global_position
		burst_visual.scale = Vector2(0.1, 0.1)
		burst_visual.z_index = 10
		get_tree().current_scene.add_child(burst_visual)

		var tween = burst_visual.create_tween()
		# Reducido de 1.2 a 0.5 para que sea una explosión pequeñita y contenida
		tween.tween_property(burst_visual, "scale", Vector2(0.5, 0.5), 0.12)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(burst_visual, "modulate:a", 0.0, 0.12)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(burst_visual.queue_free)
	
func set_burst_texture(texture: Texture2D) -> void:
	burst_texture = texture
