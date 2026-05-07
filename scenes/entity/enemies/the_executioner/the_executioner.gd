extends CharacterBody2D


signal opening_started
signal opening_finished
signal defeated

enum State {ASLEEP, OPENING, IDLE, CLOSING_IN, ATTACK, PRE_RUSH, RUSH_ATTACK, JUMP_ATTACK, SHOUTING, DEAD}

@export var hitpoints: int = 600
@export var attack_damage: int = 30

@export_category("AI Ranges")
@export var melee_range: float = 150.0
@export var shout_range: float = 260.0

@export_category("Timing")
@export var attack_cooldown: float = 0.75
@export var opening_duration: float = 1.3
@export var attack_anim_duration: float = 0.9
@export var pre_rush_duration: float = 1.7
@export var rush_duration: float = 0.55
@export var jump_attack_duration: float = 0.7
@export var shout_anim_duration: float = 1.0
@export var shout_landing_delay: float = 0.6
@export var shout_stun_duration: float = 2.0

@export_category("Movement")
@export var rush_speed: float = 700.0
@export var jump_attack_speed: float = 280.0
@export var jump_attack_height: float = -750.0
@export var close_in_speed: float = 220.0
@export var close_in_max_duration: float = 0.6
@export var melee_swing_range: float = 90.0

var state: State = State.ASLEEP
var facing: float = -1.0
var attack_variant: int = 1
var last_attack: String = ""
var attack_knockback: float = 350.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_playback: AnimationNodeStateMachinePlayback = $AnimationTree["parameters/playback"]
@onready var attack_cd: Timer = $AttackCooldown
@onready var player: Node2D = get_tree().get_first_node_in_group("player")
@onready var attack_1: Area2D = $Attack1


func _ready() -> void:
	state = State.IDLE
	sprite.frame = 0
	if attack_1 != null:
		attack_1.monitoring = false
	if state == State.ASLEEP:
		animation_tree.active = false
	else:
		animation_tree.active = true
		animation_playback.start("idle")


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0

	match state:
		State.IDLE:
			velocity.x = 0
			_update_facing()
			_try_attack()
		State.CLOSING_IN:
			velocity.x = facing * close_in_speed
		State.RUSH_ATTACK:
			velocity.x = facing * rush_speed
		State.JUMP_ATTACK:
			pass
		_:
			velocity.x = 0

	move_and_slide()


func start_opening() -> void:
	if state != State.ASLEEP:
		return
	state = State.OPENING
	opening_started.emit()
	animation_tree.active = true
	update_animation()
	await get_tree().create_timer(opening_duration).timeout
	if state == State.OPENING:
		state = State.IDLE
		update_animation()
		opening_finished.emit()


func update_animation() -> void:
	match state:
		State.OPENING:
			animation_playback.travel("openning")
		State.IDLE:
			animation_playback.travel("idle")
		State.ATTACK:
			if attack_variant == 2:
				animation_playback.travel("attack_2")
				attack_damage = 15
				attack_knockback = 250.0
			else:
				animation_playback.travel("attack_1")
				attack_damage = 15
				attack_knockback = 300.0
		State.PRE_RUSH:
			animation_playback.travel("pre_rush")
		State.RUSH_ATTACK:
			animation_playback.travel("rush_attack")
			attack_damage = 40
			attack_knockback = 700.0
		State.JUMP_ATTACK:
			animation_playback.travel("jump_attack")
			attack_damage = 50
			attack_knockback = 900.0
		State.SHOUTING:
			animation_playback.travel("Shout")
			attack_damage = 0
			attack_knockback = 0.0


func _update_facing() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	var dx: float = player.global_position.x - global_position.x
	if abs(dx) > 1.0:
		facing = sign(dx)
	_apply_facing()


func _apply_facing() -> void:
	sprite.flip_h = facing < 0
	var pos: Vector2 = Vector2(facing, 0)
	animation_tree.set("parameters/Shout/blend_position", pos)
	animation_tree.set("parameters/attack_1/blend_position", pos)
	animation_tree.set("parameters/attack_2/blend_position", pos)
	animation_tree.set("parameters/jump_attack/blend_position", pos)
	animation_tree.set("parameters/rush_attack/blend_position", pos)
	# if attack_1 != null:
	# 	attack_1.scale.x = facing


func _try_attack() -> void:
	if not attack_cd.is_stopped():
		return
	if player == null:
		return
	var dist: float = global_position.distance_to(player.global_position)
	print("[boss] try_attack dist=", dist, " melee=", melee_range)
	var pool: Array[String]
	if dist <= melee_range:
		pool = ["attack_1", "attack_2", "rush", "shout"]
	else:
		pool = ["rush", "jump_attack"]
	var choices: Array[String] = pool.filter(func(option: String) -> bool: return option != last_attack)
	if choices.is_empty():
		choices = pool
	var pick: String = choices[randi() % choices.size()]
	last_attack = pick
	print("[boss] picked=", pick)
	match pick:
		"attack_1":
			_perform_attack(1)
		"attack_2":
			_perform_attack(2)
		"rush":
			_perform_rush()
		"jump_attack":
			_perform_jump_attack()
		"shout":
			_perform_shout()


func _perform_attack(variant: int = 1) -> void:
	attack_variant = variant
	_apply_facing()
	await _close_in_to_swing_range()
	if state == State.DEAD:
		return
	state = State.ATTACK
	_apply_facing()
	update_animation()
	await get_tree().create_timer(attack_anim_duration).timeout
	if state == State.ATTACK:
		state = State.IDLE
		update_animation()
	attack_cd.start(attack_cooldown)


func _close_in_to_swing_range() -> void:
	if player == null:
		return
	state = State.CLOSING_IN
	var elapsed: float = 0.0
	while elapsed < close_in_max_duration:
		if state != State.CLOSING_IN or player == null:
			return
		var dx: float = player.global_position.x - global_position.x
		if abs(dx) > 1.0:
			facing = sign(dx)
			_apply_facing()
		if abs(dx) <= melee_swing_range:
			break
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	velocity.x = 0


func _perform_rush() -> void:
	state = State.PRE_RUSH
	_apply_facing()
	update_animation()
	await get_tree().create_timer(pre_rush_duration).timeout
	if state != State.PRE_RUSH:
		return
	state = State.RUSH_ATTACK
	update_animation()
	await get_tree().create_timer(rush_duration).timeout
	if state == State.RUSH_ATTACK:
		state = State.IDLE
		velocity.x = 0
		update_animation()
	attack_cd.start(attack_cooldown)


func _perform_jump_attack() -> void:
	state = State.JUMP_ATTACK
	_apply_facing()

	# Phase 1: launch — projectile arc up + toward player
	animation_playback.travel("jump")
	velocity.x = facing * jump_attack_speed
	velocity.y = jump_attack_height

	# Wait until we start descending (apex reached)
	await get_tree().physics_frame
	while state == State.JUMP_ATTACK and velocity.y < 0:
		await get_tree().physics_frame

	# Phase 2: falling
	if state != State.JUMP_ATTACK:
		return
	animation_playback.travel("jump_down")
	while state == State.JUMP_ATTACK and not is_on_floor():
		await get_tree().physics_frame

	# Phase 3: landing strike
	if state != State.JUMP_ATTACK:
		return
	animation_playback.travel("jump_attack")
	velocity.x = 0
	await get_tree().create_timer(jump_attack_duration).timeout

	if state == State.JUMP_ATTACK:
		state = State.IDLE
		velocity.x = 0
		update_animation()
	attack_cd.start(attack_cooldown)


func _perform_shout() -> void:
	state = State.SHOUTING
	_apply_facing()
	update_animation()
	await get_tree().create_timer(shout_landing_delay).timeout
	# if state == State.SHOUTING and player != null:
	# 	# var dist: float = global_position.distance_to(player.global_position)
	# 	# if dist <= shout_range and player.has_method("stun"):
	# 	player.stun(shout_stun_duration)
	await get_tree().create_timer(max(shout_anim_duration - shout_landing_delay, 0.0)).timeout
	if state == State.SHOUTING:
		state = State.IDLE
		update_animation()
	attack_cd.start(attack_cooldown)


func take_damage(damage_taken: int, _source_position: Vector2 = global_position) -> void:
	if state == State.ASLEEP or state == State.OPENING or state == State.DEAD:
		return
	hitpoints -= damage_taken
	_wink()
	if hitpoints <= 0:
		defeat()


func _wink() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(3, 3, 3, 1), 0.05)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.1)


func defeat() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	if attack_1 != null:
		attack_1.monitoring = false
	defeated.emit()
	queue_free()


# func _on_attack_1_area_entered(area: Area2D) -> void:
# 	if area.owner == null or not area.owner.has_method("take_damage"):
# 		return
# 	area.owner.take_damage(attack_damage, global_position)


func _on_attack_1_area_entered(area: Area2D) -> void:
	if area.owner == null or not area.owner.has_method("take_damage"):
		return
	area.owner.take_damage(attack_damage, global_position, attack_knockback)
func _on_jump_attack_area_entered(area: Area2D) -> void:
	if area.owner == null or not area.owner.has_method("take_damage"):
		return
	area.owner.take_damage(attack_damage, global_position, attack_knockback)
func _on_rush_attack_area_entered(area: Area2D) -> void:
	if area.owner == null or not area.owner.has_method("take_damage"):
		return
	area.owner.take_damage(attack_damage, global_position, attack_knockback)
func _on_shout_area_entered(area: Area2D) -> void:
	if area.owner == null or not area.owner.has_method("stun"):
		return
	print('shout hit area=', area)
	area.owner.stun(shout_stun_duration)
