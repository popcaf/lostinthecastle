extends Node


@export var player: CharacterBody2D

@export var Camera_AdvZone: PhantomCamera2D
@export var Camera_TheExecutinerZone: PhantomCamera2D
var current_camera_zone: int = 0

func _physics_process(delta: float) -> void:
	return
	#print('player',player.global_position)

func update_current_zone(body, zone_a, zone_b):
	if body == player:
		match current_camera_zone:
			zone_a:
				current_camera_zone = zone_b
			zone_b:
				current_camera_zone = zone_a
		update_camara()

func update_camara():
	print('current_camera_zone',current_camera_zone)
	var cameras = [Camera_AdvZone, Camera_TheExecutinerZone]
	for camara in cameras:
		if camara != null:
			camara.priority = 0
			
			
	#if is_active_interaction:
		#match active_interaction:
			#Interaction_Area1:
				#Interaction_Camera1.priority = 1
	#else:
	match current_camera_zone:
		0:
			Camera_AdvZone.priority = 1
		1:
			Camera_TheExecutinerZone.priority = 1



func _on_the_executoner_zone_body_entered(body: Node2D) -> void:
	print('...... enter')
	update_current_zone(body, 0, 1)


func _on_the_executoner_zone_area_entered(area: Area2D) -> void:
	print('...... enter2')
	pass # Replace with function body.
