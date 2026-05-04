extends CanvasLayer


func _ready() -> void:
	visible = false
	$Panel/VBoxContainer/RestartButton.pressed.connect(_on_restart_pressed)


func show_game_over() -> void:
	visible = true
	get_tree().paused = true


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
	queue_free()
