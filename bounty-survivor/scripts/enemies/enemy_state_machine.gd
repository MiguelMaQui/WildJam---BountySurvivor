# enemy_state_machine.gd
class_name EnemyStateMachine
extends Node

enum State {
	IDLE,
	CHASE,
	ATTACK,
	DEAD
}

const ATTACK_DAMAGE = 5.0    # antes 10, ahora más suave
const ATTACK_RATE = 0.8      # antes 1.0, ahora un poco más frecuente

var current_state: State = State.IDLE
var enemy: CharacterBody2D
var attack_timer := 0.0

func init(enemy_node: CharacterBody2D) -> void:
	enemy = enemy_node
	_enter_state(State.IDLE)

func update(delta: float) -> void:
	if enemy == null:
		return
	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.CHASE:
			_state_chase(delta)
		State.ATTACK:
			_state_attack(delta)
		State.DEAD:
			_state_dead(delta)

func transition_to(new_state: State) -> void:
	if new_state == current_state:
		return
	_exit_state(current_state)
	current_state = new_state
	_enter_state(new_state)

func _enter_state(state: State) -> void:
	match state:
		State.IDLE:
			enemy.modulate = Color(0.6, 0.6, 0.6, 1)  # gris
		State.CHASE:
			enemy.modulate = Color(1, 0.3, 0.3, 1)    # rojo
		State.ATTACK:
			enemy.modulate = Color(1, 0, 0, 1)         # rojo intenso
		State.DEAD:
			enemy.die()

func _exit_state(state: State) -> void:
	match state:
		State.ATTACK:
			pass

func _state_idle(_delta: float) -> void:
	if enemy == null:
		return
	if enemy.can_see_player():
		transition_to(State.CHASE)

func _state_chase(delta: float) -> void:
	if enemy == null:
		return
	enemy.move_towards_player(delta)
	if enemy.is_in_attack_range():
		transition_to(State.ATTACK)
	if not enemy.can_see_player():
		transition_to(State.IDLE)

func _state_attack(delta: float) -> void:
	if not enemy.is_in_attack_range():
		transition_to(State.CHASE)
		return
	attack_timer -= delta
	if attack_timer <= 0.0:
		attack_timer = ATTACK_RATE
		if enemy.player and enemy.player.has_method("take_damage"):
			enemy.player.take_damage(ATTACK_DAMAGE)

func _state_dead(_delta: float) -> void:
	pass
