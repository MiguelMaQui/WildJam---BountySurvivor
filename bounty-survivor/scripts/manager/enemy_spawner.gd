extends Node2D

@export var enemy_scene: PackedScene
@export var boss_scene: PackedScene 
@export var spawn_radius: float = 400.0
@export var max_enemies: int = 30

var spawn_interval: float = 2.0
var timer := 0.0
var player: Node2D = null

var wave := 1
var wave_timer := 0.0
const WAVE_DURATION = 20.0
var wave_announcing := false

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _process(delta: float) -> void:
	if player == null:
		return

	wave_timer += delta
	if wave_timer >= WAVE_DURATION:
		wave_timer = 0.0
		wave += 1
		_announce_wave()
		
		if wave % 6 == 0:
			_spawn_boss()

	_adjust_difficulty()

	timer += delta
	if timer >= spawn_interval:
		timer = 0.0
		_spawn_enemy()

func _spawn_enemy() -> void:
	if enemy_scene == null: return
	if get_tree().get_nodes_in_group("enemy").size() >= max_enemies: return

	var spawn_count := 1
	if wave >= 3: spawn_count = 2
	if wave >= 5: spawn_count = 3
	if wave >= 8: spawn_count = 4

	for i in spawn_count:
		var attempt := 0
		var max_attempts := 10
		var spawned := false
		
		while attempt < max_attempts and not spawned:
			attempt += 1
			var angle := randf() * TAU
			var offset := Vector2(cos(angle), sin(angle)) * spawn_radius
			var spawn_pos := player.global_position + offset

			var space_state = get_world_2d().direct_space_state
			var query = PhysicsPointQueryParameters2D.new()
			query.position = spawn_pos
			query.collision_mask = 1 
			
			var result = space_state.intersect_point(query)
			
			if result.is_empty():
				var enemy = enemy_scene.instantiate()
				get_tree().current_scene.add_child(enemy)
				enemy.global_position = spawn_pos
				if enemy.has_method("set_wave"):
					enemy.set_wave(wave)
				spawned = true

func _spawn_boss() -> void:
	if boss_scene == null: return

	var attempt := 0
	var max_attempts := 10
	var spawned := false
	
	while attempt < max_attempts and not spawned:
		attempt += 1
		var angle := randf() * TAU
		var offset := Vector2(cos(angle), sin(angle)) * (spawn_radius + 150)
		var spawn_pos := player.global_position + offset

		var space_state = get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = spawn_pos
		query.collision_mask = 1 
		
		var result = space_state.intersect_point(query)
		
		if result.is_empty():
			var boss = boss_scene.instantiate()
			boss.add_to_group("enemy") 
			boss.add_to_group("boss") # Nuevo grupo para la flecha indicadora
			get_tree().current_scene.add_child(boss)
			boss.global_position = spawn_pos
			if boss.has_method("set_wave"):
				boss.set_wave(wave)
			spawned = true

func _adjust_difficulty() -> void:
	spawn_interval = max(0.5, 2.0 - (wave - 1) * 0.2)
	max_enemies = min(9999, 30 + (wave - 1) * 5)

func _announce_wave() -> void:
	var gm = get_tree().root.get_node_or_null("GameManager")
	if gm: gm.new_wave(wave)
