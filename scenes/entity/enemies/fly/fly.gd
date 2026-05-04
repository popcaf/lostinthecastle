extends CharacterBody2D


enum State { IDLE, CHASE, ATTACK, STUNNED, DEAD }

@export var speed: float = 110.0
@export var hitpoints: int = 60
@export var detect_range: float = 480.0
@export var attack_range: float = 200.0
@export var min_attack_range: float = 120.0
@export var attack_cooldown: float = 1.6
@export var hover_amplitude: float = 8.0
@export var hover_speed: float = 3.0
@export var projectile_scene: PackedScene = preload("res://scenes/entity/enemies/fly/projectile.tscn")

@export_category("Hit Reaction")
@export var knockback_force: float = 420.0
@export var knockback_friction: float = 6.0
@export var stun_duration: float = 0.6

var state: State = State.IDLE
var is_under_attack: bool = false
var is_stunned: bool = false
var can_attack: bool = true
var time_alive: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO

@onready var player: Node2D = get_tree().get_first_node_in_group("player")
@onready var body: Polygon2D = $Body
@onready var attack_timer: Timer = $AttackCooldown


func _physics_process(delta: float) -> void:
	time_alive += delta
	if state == State.DEAD:
		return

	if is_stunned:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * knockback_velocity.length() * delta)
		move_and_slide()
		return

	if player == null:
		player = get_tree().get_first_node_in_group("player")
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()

	if dist <= attack_range and dist >= min_attack_range:
		state = State.ATTACK
		velocity = Vector2.ZERO
		if can_attack:
			attack()
	elif dist <= detect_range:
		state = State.CHASE
		velocity = to_player.normalized() * speed
	else:
		state = State.IDLE
		velocity = Vector2.ZERO

	velocity.y += sin(time_alive * hover_speed) * hover_amplitude

	move_and_slide()

	if player.global_position.x < global_position.x:
		body.scale.x = -1
	else:
		body.scale.x = 1


func attack() -> void:
	can_attack = false
	attack_timer.start(attack_cooldown)
	var proj: Node2D = projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position
	proj.launch_at(player.global_position)


func take_damage(damage_taken: int, source_position: Vector2 = global_position) -> void:
	print('fly taken damage', damage_taken)
	hitpoints -= damage_taken
	is_under_attack = true
	if hitpoints <= 0:
		death()
		return
	apply_knockback(source_position)
	flash_hurt()
	stun()


func apply_knockback(source_position: Vector2) -> void:
	var dir: float = sign(global_position.x - source_position.x)
	if dir == 0 and player != null:
		dir = sign(global_position.x - player.global_position.x)
	if dir == 0:
		dir = 1.0
	knockback_velocity.x = dir * knockback_force
	knockback_velocity.y = 0.0


func stun() -> void:
	is_stunned = true
	state = State.STUNNED
	can_attack = false
	attack_timer.stop()
	await get_tree().create_timer(stun_duration).timeout
	if state == State.DEAD:
		return
	is_stunned = false
	is_under_attack = false
	knockback_velocity = Vector2.ZERO
	can_attack = true
	state = State.IDLE


func flash_hurt() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(body, "modulate", Color(1, 0.3, 0.3, 1), 0.05)
	tween.tween_property(body, "modulate", Color(1, 1, 1, 1), 0.1)
	


func death() -> void:
	state = State.DEAD
	queue_free()


func _on_attack_cooldown_timeout() -> void:
	can_attack = true
