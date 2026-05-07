extends Area2D


signal cutscene_started
signal cutscene_finished

@export var boss_path: NodePath
@export var lock_player_during_opening: bool = true

@export_category("Camera Pan")
@export var pan_camera: bool = true
@export var pan_to_boss_duration: float = 0.8
@export var hold_on_boss_duration: float = 0.3
@export var pan_back_duration: float = 0.6
@export var camera_focus_offset: Vector2 = Vector2(0, -100)

var triggered: bool = false


func _on_body_entered(body: Node2D) -> void:
	print('body entering')
	if triggered:
		return
	if not body.is_in_group("player"):
		return
	triggered = true

	var boss: Node = get_node_or_null(boss_path)
	print('boss', boss)
	if boss == null or not boss.has_method("start_opening"):
		return

	if lock_player_during_opening and "is_input_locked" in body:
		body.is_input_locked = true

	cutscene_started.emit()

	var cam: Camera2D = body.get_node_or_null("Camera2D") as Camera2D
	var prev_top_level: bool = false
	var prev_smoothing: bool = false
	if pan_camera and cam != null:
		prev_top_level = cam.top_level
		prev_smoothing = cam.position_smoothing_enabled
		cam.position_smoothing_enabled = false
		cam.top_level = true
		await _tween_camera(cam, boss.global_position + camera_focus_offset, pan_to_boss_duration)
		if hold_on_boss_duration > 0.0:
			await get_tree().create_timer(hold_on_boss_duration).timeout

	await boss.start_opening()

	if pan_camera and cam != null:
		await _tween_camera(cam, body.global_position + camera_focus_offset, pan_back_duration)
		cam.top_level = prev_top_level
		cam.position_smoothing_enabled = prev_smoothing

	cutscene_finished.emit()

	if lock_player_during_opening and "is_input_locked" in body:
		body.is_input_locked = false

	monitoring = false


func _tween_camera(cam: Camera2D, target: Vector2, duration: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(cam, "global_position", target, duration) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN_OUT)
	await tween.finished
