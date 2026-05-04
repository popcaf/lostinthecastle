extends Area2D


@export var damage: int = 15
@export var atk_gravity: float = 2000.0
@export var travel_time: float = 0.9
@export var lifetime: float = 4.0

var velocity: Vector2 = Vector2.ZERO
var alive_time: float = 0.0


func launch_at(target: Vector2) -> void:
	var delta_pos: Vector2 = target - global_position
	velocity.x = delta_pos.x / travel_time
	velocity.y = (delta_pos.y - 0.5 * atk_gravity * travel_time * travel_time) / travel_time


func _physics_process(delta: float) -> void:
	velocity.y += atk_gravity * delta
	global_position += velocity * delta
	rotation += 6.0 * delta
	alive_time += delta
	if alive_time >= lifetime:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area.owner != null and area.owner.has_method("take_damage"):
		area.owner.take_damage(damage, global_position)
	queue_free()
