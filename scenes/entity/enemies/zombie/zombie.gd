extends CharacterBody2D



enum State {
	IDLE,
	WALK,
	RUN,
	ATTACK,
	HURT,
	DEAD,
	CHASE,
	RETURN
}


@export var speed: int = 128
@export var hitpoints:int = 100
@export var attack_damage: int = 20
@export var aggro_range: float = 384.0
@export var attack_range: float = 50.0
@export_category("Related Scenes")

var state: State = State.IDLE

@onready var spawn_point: Vector2 = global_position
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_playback: AnimationNodeStateMachinePlayback = $AnimationTree["parameters/playback"]
@onready var player: CharacterBody2D = get_tree().get_first_node_in_group("player")
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var is_attacking: bool = false
@onready var enemies_player: AnimationPlayer = $AnimationPlayer
@onready var hit_box: Area2D = $HitBox

var is_under_attack : bool = false


func _ready() -> void:
	animation_tree.set_active(true)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if is_under_attack:
		return
	
	if is_attacking:
		return
	
	
	if state == State.DEAD:
		return
	if state == State.ATTACK:
		attack()
		
	if distance_to_player() <= attack_range:
		#print('in',"attack Here")
		state = State.ATTACK
		update_animation()
		
	elif distance_to_player() <= aggro_range:
		state = State.CHASE
		move()
	elif global_position.distance_to(spawn_point) > 32:
		state = State.RETURN
		move()
	elif state != State.IDLE:
		update_animation()
	

	move_and_slide()


func move() -> void:
	if state == State.CHASE:
		nav_agent.target_position = player.global_position
	elif state == State.RETURN:
		nav_agent.target_position = spawn_point
	var next_path_position: Vector2 = nav_agent.get_next_path_position()
	
	velocity = global_position.direction_to(nav_agent.target_position) * speed
	velocity.y = 0
	
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(velocity)
	else:
		_on_navigation_agent_2d_velocity_computed(velocity)
	move_and_slide()
	
	# Sprite flipping (only in idle/run)
	if state == State.IDLE or State.RUN:
		if velocity.x < -0.01:
			$Sprite2D.flip_h = true 
		elif velocity.x > 0.01:
			$Sprite2D.flip_h = false
	
	update_animation()


	
func distance_to_player()->float:
	return global_position.distance_to(player.global_position)
	

func attack()->void:
	velocity = Vector2(0,0)
	is_attacking = true
	
	var player_pos: Vector2 = player.global_position
	var attack_dir: Vector2 = (player_pos - global_position).normalized()
	$Sprite2D.flip_h = attack_dir.x < 0 and abs(attack_dir.x) >= abs(attack_dir.y)
	animation_tree.set("parameters/attack/blend_position",attack_dir)
	update_animation()

	await get_tree().create_timer(0.3).timeout
	is_attacking = false
	
	
	
func update_animation()-> void:
	match state:
		State.IDLE:
			animation_playback.travel("idle")
		State.WALK:
			animation_playback.travel("walk")
		State.CHASE:
			animation_playback.travel("run")
		State.ATTACK:
			animation_playback.travel("attack")
		State.DEAD:
			animation_playback.travel("death")
		State.HURT:
			animation_playback.travel("hurt")


func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	nav_agent.velocity = safe_velocity
	
	
func take_damage(damage_taken: int, source_position: Vector2 = global_position) -> void:
	print('taken damage', damage_taken)
	hitpoints -= damage_taken
	state = State.HURT

	is_under_attack = true
	if hitpoints <= 0:
		death()
	update_animation()

	await get_tree().create_timer(0.1).timeout
	var dir: float = sign(global_position.x - source_position.x)
	if dir == 0:
		dir = -1.0
	global_position.x += dir * 20

	await get_tree().create_timer(0.6).timeout
	is_under_attack = false


func death() -> void:
	state = State.DEAD
	update_animation()
	await get_tree().create_timer(2).timeout
	queue_free()


func _on_hit_box_area_entered(area: Area2D) -> void:
	area.owner.take_damage(attack_damage, global_position)
