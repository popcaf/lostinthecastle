extends CharacterBody2D


signal hitpoints_changed(current: int, max_value: int)

#const SPEED = 350.0
const JUMP_VELOCITY = -600.00
const DASH_SPEED = 1000

@export_category("Related Scenes")
@export var attack_damage: int = 45
@export var speed = 350
@export var max_hitpoints: int = 100
@export var hitpoints: int = 100
@export var game_over_scene: PackedScene = preload("res://scenes/ui/game_over.tscn")
@export var hud_scene: PackedScene = preload("res://scenes/ui/hud.tscn")


@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_playback: AnimationNodeStateMachinePlayback = $AnimationTree["parameters/playback"]
@onready var timer: Timer = %Timer
@onready var dash_duration: Timer = %DashDuration
@onready var camera: Camera2D = $Camera2D
#@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

var lockcamara: bool = false

var jumpsecond: bool = false
var combo_attack: int = 0
var can_dash = true
var is_dashing = false
var is_attacking = false
var is_hurt: bool = false

const KNOCKBACK_FORCE_X: float = 350.0
const HURT_FLASH_DURATION: float = 0.4

enum State {
	IDLE,
	RUN,
	JUMP,
	DOUBLE_JUMP,
	ATTACK,
	DASH
}

var state: State = State.IDLE

func _ready() -> void:
	animation_tree.set_active(true)
	can_dash = true
	#camera_2d.position = Vector2(200,-200)
	if hud_scene != null and not _hud_already_added():
		var hud: CanvasLayer = hud_scene.instantiate()
		get_tree().root.add_child.call_deferred(hud)
	hitpoints_changed.emit(hitpoints, max_hitpoints)


func _hud_already_added() -> bool:
	for child in get_tree().root.get_children():
		if child.name == "HUD":
			return true
	return false

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	if is_on_floor():
		jumpsecond = false
		#is_dash = false
		state = State.IDLE
		update_animation()
		
		
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
		
	var direction := Input.get_axis("move_left", "move_right")
	if !is_dashing and !is_attacking:
			if direction:
				velocity.x = direction * speed
			else:
				velocity.x = move_toward(velocity.x, 0, speed)
			
			if direction > 0:
				sprite_2d.flip_h = false
				if velocity.y == 0:
					state = State.RUN
				update_animation()
			
			elif direction < 0:
				sprite_2d.flip_h = true
				if velocity.y == 0:
					state = State.RUN
				update_animation()
				
			if velocity.y > 0 and !jumpsecond:
				animation_playback.travel("jump_down")
			elif velocity.y > 0 and jumpsecond:
				animation_playback.travel("doublejump_down")

	# Handle jump.
	if Input.is_action_just_pressed("jump"):
		print('ew')
	
	#print("Input.is_action_just_pressedd",Input.is_action_just_pressed("jump"))
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			state = State.JUMP
			
		elif !is_on_floor() and jumpsecond == false:
			velocity.y = JUMP_VELOCITY
			jumpsecond = true
			state = State.DOUBLE_JUMP
		update_animation()
	
	
	if Input.is_action_just_pressed("attack"):
		attack()
		
	if Input.is_action_just_pressed("dash") and can_dash:
		print('test dash')
		dash()
		
	move_and_slide()
	
	
func attack() -> void:
	velocity = Vector2.ZERO
	is_attacking = true
	state = State.ATTACK
	update_animation()
	
func dash() -> void:
	if can_dash == true:
		is_dashing = true
		velocity.x = 0
		velocity.y = 0
		state = State.DASH
		update_animation()
		if !sprite_2d.flip_h:
			print('ttt', DASH_SPEED)
			velocity.x = 1.0 * DASH_SPEED
		else:
			print('ttt2', DASH_SPEED)
			velocity.x = -1.0 * DASH_SPEED
		
			
		can_dash = false
		dash_duration.start()
		

func update_animation() -> void:
	match state:
		State.IDLE:
			animation_playback.travel('idle')
		State.RUN:
			animation_playback.travel('run')
		State.ATTACK:
			var dir_pos: Vector2
			if $Sprite2D.flip_h:
				dir_pos = Vector2(-1, 0)
			else:
				dir_pos = Vector2(1, 0)
				
			var attack_dir: Vector2 = (dir_pos - global_position).normalized()
			if combo_attack == 0:
				attack_damage = 30
				animation_tree.set("parameters/attack1/blend_position", dir_pos)
				animation_playback.travel("attack1")
	
			elif combo_attack == 1:
				attack_damage = 40
				animation_tree.set("parameters/attack2/blend_position", dir_pos)
				animation_playback.travel("attack2")
				
			elif combo_attack == 2:
				attack_damage = 50
				velocity.y = -100
				animation_tree.set("parameters/attack3/blend_position", dir_pos)
				animation_playback.travel("attack3")
		State.JUMP:
			animation_playback.travel("jump")
		State.DOUBLE_JUMP:
			animation_playback.travel("double_jump")
		
		State.DASH:
			combo_attack = 0
			animation_playback.travel("dash")
			
			
func _on_timer_timeout() -> void:
	combo_attack = 0
	
func _on_dash_duration_timeout() -> void:
	can_dash = true

func _on_animation_tree_animation_finished(anim_name: StringName) -> void:
	print('animname', anim_name)
	if anim_name == "attack" or anim_name == "attack_flip":
		combo_attack = 1
		is_attacking = false
		timer.start()
		
	elif anim_name == "attack2" or anim_name == "attack2_flip":
		combo_attack = 2
		is_attacking = false
		timer.start()
		
	elif anim_name == "attack3" or anim_name == "attack3_flip":
		is_attacking = false
		combo_attack = 0
	
	elif anim_name == "dash":
		is_dashing = false


func _on_animation_tree_animation_started(anim_name: StringName) -> void:
	if anim_name == "dash":
		is_attacking = false


func _on_hit_box_area_entered(area: Area2D) -> void:
	print('atk')
	area.owner.take_damage(attack_damage, global_position)
	pass


func take_damage(damage_taken: int, source_position: Vector2 = global_position) -> void:
	print('player taken damage', damage_taken)
	hitpoints -= damage_taken
	hitpoints_changed.emit(hitpoints, max_hitpoints)
	if hitpoints <= 0:
		die()
		return
	apply_knockback(source_position)
	flash_hurt()


func apply_knockback(source_position: Vector2) -> void:
	var dir: float = sign(global_position.x - source_position.x)
	if dir == 0:
		dir = -1.0 if sprite_2d.flip_h else 1.0
	velocity.x = dir * KNOCKBACK_FORCE_X
	velocity.y = 0.0


func flash_hurt() -> void:
	is_hurt = true
	var tween: Tween = create_tween()
	tween.tween_property(sprite_2d, "modulate", Color(1, 0.3, 0.3, 1), 0.05)
	tween.tween_property(sprite_2d, "modulate", Color(1, 1, 1, 1), 0.08)
	tween.tween_property(sprite_2d, "modulate", Color(1, 0.3, 0.3, 1), 0.05)
	tween.tween_property(sprite_2d, "modulate", Color(1, 1, 1, 1), 0.08)
	await get_tree().create_timer(HURT_FLASH_DURATION).timeout
	sprite_2d.modulate = Color(1, 1, 1, 1)
	is_hurt = false


func die() -> void:
	for child in get_tree().root.get_children():
		if child.name == "HUD":
			child.queue_free()
	var game_over: CanvasLayer = game_over_scene.instantiate()
	get_tree().root.add_child(game_over)
	game_over.show_game_over()
	queue_free()
